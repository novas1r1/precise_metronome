import Foundation
import AVFoundation

/// Progress of a running tempo ramp, reported after each tempo step and once
/// more when the ramp has finished (the engine stops itself then).
struct RampProgress {
    let stepIndex: Int
    let bpm: Double
    let finished: Bool
}

/// One audible pulse, reported roughly when it becomes audible.
struct BeatEvent {
    let bar: Int
    let beat: Int
    let pulse: Int
    let accent: Bool
}

/// Core audio engine. All audio scheduling happens on a dedicated serial
/// queue; all state mutations coming in from Flutter are dispatched onto
/// that queue so we never race the scheduler.
///
/// Scheduling model: classic lookahead. A DispatchSourceTimer wakes every
/// 25 ms and schedules any beats whose sample time falls within the next
/// 100 ms. Buffers are scheduled against AVAudioPlayerNode using
/// `AVAudioTime(sampleTime:atRate:)` — AVAudioEngine plays them back at
/// sample-accurate resolution.
final class MetronomeEngine {

    /// Called on an arbitrary queue whenever ramp progress changes.
    var onRampProgress: ((RampProgress) -> Void)?

    /// Called on the main queue for every rendered pulse (or main beat
    /// only), delayed so it lines up with the moment the click is heard.
    var onBeat: ((BeatEvent) -> Void)?

    // MARK: - Audio graph
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var sampleRate: Double = 48_000

    // MARK: - State (mutated only on serialQueue)
    private let serialQueue = DispatchQueue(label: "com.repeatlab.precise_metronome.scheduler",
                                            qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    private var bpm: Double = 120.0
    private var beatsPerBar: Int = 4
    /// One flag per pulse of the bar: `beat * pulsesPerBeat + pulse`.
    private var accentPattern: [Bool] = [true, false, false, false]
    private var pulsesPerBeat: Int = 1

    private var currentVoice: ClickVoice = .tone
    private var buffers: ClickBuffers?

    private var isPlaying = false
    private var beatIndexInBar = 0
    private var pulseIndexInBeat = 0
    private var nextPulseSampleTime: AVAudioFramePosition = 0
    private var lastScheduledPulseTime: AVAudioFramePosition = 0
    private var hasAnchor = false
    private var initialDelayFrames: AVAudioFramePosition = 0

    // Tempo ramp (all on serialQueue).
    private var rampActive = false
    private var rampStopAtGoal = true
    private var rampStepBpm: Double = 0
    private var rampBarsPerStep = 1
    private var rampBarsInStep = 0
    private var rampStepIndex = 0
    private var rampCurrentBpm: Double = 120
    /// Tempo the ramp is currently heading for: the goal on the way up,
    /// `startBpm` after a `returnToStart` turnaround.
    private var rampEffectiveGoal: Double = 120
    private var rampReturnBpm: Double = 120
    private var rampReturnPending = false

    // Beat events (serialQueue).
    private var beatEventsEnabled = false
    private var beatEventsIncludeSub = false
    private var barIndex = 0

    // Scheduling constants.
    private let lookaheadSeconds: Double = 0.1   // schedule 100 ms ahead
    private let tickInterval: DispatchTimeInterval = .milliseconds(25)

    // Background audio support.
    private var backgroundEnabled = false

    // MARK: - Public API (all thread-safe; marshals onto serialQueue)

    func initialize() throws {
        try configureAudioSession()
        subscribeToInterruptions()

        engine.attach(playerNode)

        // Use the hardware output format for the connection so we match
        // the device's native rate; scheduled buffers are rendered at
        // whatever rate the synth used, and AVAudioEngine handles the
        // conversion if they differ — but we keep them aligned by
        // synthesizing at the same rate.
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate

        let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        engine.connect(playerNode, to: engine.mainMixerNode, format: monoFormat)

        // Pre-render the default voice so there's no first-click latency.
        buffers = ClickSynth.render(voice: currentVoice, sampleRate: sampleRate)

        try engine.start()
    }

    func start(initialDelaySeconds: Double = 0) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.rampActive = false
            self.beginSession(initialDelaySeconds: initialDelaySeconds)
        }
    }

    /// Like `start`, but steps the tempo from `startBpm` towards `goalBpm`
    /// by `stepBpm` every `barsPerStep` bars (last step clamped to the
    /// goal). With `returnToStart` the ramp turns around once the goal has
    /// been played out and steps back down to `startBpm` without
    /// interrupting scheduling. With `stopAtGoal` it stops itself after the
    /// final tempo has been played for `barsPerStep` bars; otherwise it
    /// holds that tempo until `stop()`.
    func startRamp(initialDelaySeconds: Double,
                   startBpm: Double,
                   goalBpm: Double,
                   stopAtGoal: Bool,
                   stepBpm: Double,
                   barsPerStep: Int,
                   returnToStart: Bool) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.bpm = startBpm
            self.rampCurrentBpm = startBpm
            self.rampEffectiveGoal = goalBpm
            self.rampReturnBpm = startBpm
            self.rampReturnPending = returnToStart
            self.rampStopAtGoal = stopAtGoal
            self.rampStepBpm = stepBpm
            self.rampBarsPerStep = max(barsPerStep, 1)
            self.rampBarsInStep = 0
            self.rampStepIndex = 0
            self.rampActive = true
            self.beginSession(initialDelaySeconds: initialDelaySeconds)
        }
    }

    /// Must be called on serialQueue.
    private func beginSession(initialDelaySeconds: Double) {
        guard !isPlaying else { return }
        isPlaying = true
        beatIndexInBar = 0
        pulseIndexInBeat = 0
        barIndex = 0
        hasAnchor = false
        initialDelayFrames =
            AVAudioFramePosition(max(0, initialDelaySeconds) * sampleRate)
        playerNode.play()
        startTimer()
    }

    /// Shifts the phase of all future pulses by `deltaSeconds` while playing.
    /// If the shifted position would collide with the last already-scheduled
    /// pulse or land in the past, rolls forward by whole pulse periods
    /// (phase-equivalent) so pulses never double-fire.
    func nudge(deltaSeconds: Double) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isPlaying, self.hasAnchor else { return }

            let framesPerPulse = self.currentFramesPerPulse()
            var candidate = self.nextPulseSampleTime
                + AVAudioFramePosition(deltaSeconds * self.sampleRate)

            // Never fire closer than a quarter pulse after the last pulse we
            // already handed to the player, and never in the past.
            var minNext = self.lastScheduledPulseTime + max(framesPerPulse / 4, 1)
            if let nodeTime = self.playerNode.lastRenderTime,
               let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                minNext = max(minNext, playerTime.sampleTime + AVAudioFramePosition(0.01 * self.sampleRate))
            }
            while candidate < minNext {
                candidate += max(framesPerPulse, 1)
            }
            self.nextPulseSampleTime = candidate
        }
    }

    func stop() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isPlaying else { return }
            self.isPlaying = false
            self.rampActive = false
            self.timer?.cancel()
            self.timer = nil
            self.playerNode.stop()
        }
    }

    func setTempo(_ bpm: Double) {
        serialQueue.async { [weak self] in self?.bpm = bpm }
    }

    func setTimeSignature(beatsPerBar: Int, accentPattern: [Bool]) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.beatsPerBar = beatsPerBar
            self.accentPattern = accentPattern
            if self.beatIndexInBar >= beatsPerBar {
                self.beatIndexInBar = 0
                self.pulseIndexInBeat = 0
            }
        }
    }

    func setAccentPattern(_ pattern: [Bool]) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            // Guard against race with setTimeSignature — only apply if lengths match.
            if pattern.count == self.beatsPerBar {
                self.accentPattern = pattern
            }
        }
    }

    func setSubdivision(pulsesPerBeat: Int) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            let p = max(1, min(pulsesPerBeat, 16))
            self.pulsesPerBeat = p
            // Reset the sub-beat cursor so the next pulse starts cleanly on
            // a beat boundary. Keeps the main-beat index stable so the
            // listener doesn't jump inside the bar.
            self.pulseIndexInBeat = 0
        }
    }

    func setVoice(_ name: String) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard let voice = ClickVoice(rawValue: name) else { return }
            self.currentVoice = voice
            self.buffers = ClickSynth.render(voice: voice, sampleRate: self.sampleRate)
        }
    }

    func setBeatEvents(enabled: Bool, includeSubdivisions: Bool) {
        serialQueue.async { [weak self] in
            self?.beatEventsEnabled = enabled
            self?.beatEventsIncludeSub = includeSubdivisions
        }
    }

    func setVolume(_ volume: Double) {
        // volume is safe to set from any thread on AVAudioMixing-conforming nodes,
        // but we keep everything on our queue for cleanliness.
        serialQueue.async { [weak self] in
            self?.playerNode.volume = Float(max(0.0, min(1.0, volume)))
        }
    }

    func enableBackgroundPlayback() {
        // On iOS, background playback is handled entirely by the audio session
        // category + `UIBackgroundModes: audio` in Info.plist. The session is
        // already .playback, so nothing further is required here — we just
        // flag state in case we need it later.
        backgroundEnabled = true
    }

    func disableBackgroundPlayback() {
        backgroundEnabled = false
    }

    func dispose() {
        serialQueue.sync {
            self.isPlaying = false
            self.timer?.cancel()
            self.timer = nil
        }
        playerNode.stop()
        engine.stop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try session.setActive(true, options: [])
    }

    private func subscribeToInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }
        if type == .began {
            // Stop cleanly. We do not auto-resume in v1.
            stop()
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // If headphones yank, iOS policy for .playback is to keep playing.
        // We don't need to do anything here, but this is where we'd react.
    }

    // MARK: - Scheduler

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: serialQueue)
        t.schedule(deadline: .now(), repeating: tickInterval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            self?.schedulerTick()
        }
        timer = t
        t.resume()
    }

    private func schedulerTick() {
        guard isPlaying else { return }
        guard let buffers = buffers else { return }

        // Acquire current render sample time from the player node's clock.
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return // Player not yet producing audio; try again next tick.
        }
        let currentSampleTime: AVAudioFramePosition = playerTime.sampleTime

        if !hasAnchor {
            // First scheduling opportunity: anchor the next pulse a little
            // ahead of "now" so the first click is guaranteed schedulable,
            // plus any caller-requested initial delay.
            nextPulseSampleTime = currentSampleTime
                + AVAudioFramePosition(0.05 * sampleRate)
                + initialDelayFrames
            lastScheduledPulseTime = nextPulseSampleTime - currentFramesPerPulse()
            hasAnchor = true
        }

        let horizon = currentSampleTime + AVAudioFramePosition(lookaheadSeconds * sampleRate)

        while nextPulseSampleTime < horizon {
            // The pattern carries one flag per pulse of the bar, so a
            // subdivision pulse can be accented too. An unaccented pulse
            // uses the normal click on a main beat and the softer sub
            // click in between.
            let slot = beatIndexInBar * pulsesPerBeat + pulseIndexInBeat
            let isAccent = accentPattern.isEmpty
                ? (slot == 0)
                : accentPattern[slot % accentPattern.count]
            let buffer: AVAudioPCMBuffer =
                isAccent
                    ? buffers.accent
                    : (pulseIndexInBeat == 0 ? buffers.normal : buffers.sub)

            let when = AVAudioTime(sampleTime: nextPulseSampleTime, atRate: sampleRate)
            playerNode.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
            lastScheduledPulseTime = nextPulseSampleTime

            if beatEventsEnabled, let onBeat = onBeat,
               pulseIndexInBeat == 0 || beatEventsIncludeSub {
                // The click is scheduled up to `lookaheadSeconds` ahead;
                // hold the event back until it is actually audible.
                let event = BeatEvent(bar: barIndex, beat: beatIndexInBar,
                                      pulse: pulseIndexInBeat, accent: isAccent)
                let secondsUntilAudible =
                    Double(nextPulseSampleTime - currentSampleTime) / sampleRate
                    + AVAudioSession.sharedInstance().outputLatency
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + max(0, secondsUntilAudible)
                ) { onBeat(event) }
            }

            // Advance pulse / beat counters.
            let ppb = max(pulsesPerBeat, 1)
            pulseIndexInBeat += 1
            if pulseIndexInBeat >= ppb {
                pulseIndexInBeat = 0
                beatIndexInBar = (beatIndexInBar + 1) % max(beatsPerBar, 1)
                if beatIndexInBar == 0 { barIndex += 1 }
                if beatIndexInBar == 0, rampActive, rampBarCompleted() {
                    finishRamp()
                    return
                }
            }

            nextPulseSampleTime += max(currentFramesPerPulse(), 1)
        }
    }

    // MARK: - Tempo ramp (serialQueue only)

    /// True when the current tempo has reached the tempo the ramp is
    /// heading for. serialQueue only.
    private var rampAtGoal: Bool {
        rampEffectiveGoal >= rampCurrentBpm
            ? rampCurrentBpm >= rampEffectiveGoal
            : rampCurrentBpm <= rampEffectiveGoal
    }

    /// Advances the ramp after a full bar. Returns true once the final
    /// tempo has been played for its full number of bars.
    private func rampBarCompleted() -> Bool {
        rampBarsInStep += 1
        guard rampBarsInStep >= rampBarsPerStep else { return false }
        rampBarsInStep = 0

        if rampStepBpm <= 0 { return rampStopAtGoal }
        if rampAtGoal {
            // The goal tempo has had its bars. Turn around once if a return
            // leg was requested; otherwise this is the end of the ramp.
            // Open-ended ramps just keep holding the limit tempo.
            guard rampReturnPending else { return rampStopAtGoal }
            rampReturnPending = false
            rampEffectiveGoal = rampReturnBpm
            // A ramp that never left its start has nothing to return from.
            if rampAtGoal { return rampStopAtGoal }
        }

        let ascending = rampEffectiveGoal >= rampCurrentBpm
        var next = ascending
            ? rampCurrentBpm + rampStepBpm
            : rampCurrentBpm - rampStepBpm
        next = ascending
            ? min(next, rampEffectiveGoal)
            : max(next, rampEffectiveGoal)
        rampCurrentBpm = next
        bpm = next
        rampStepIndex += 1
        onRampProgress?(RampProgress(stepIndex: rampStepIndex, bpm: next, finished: false))
        return false
    }

    /// Stops scheduling; buffers already handed to the player still play
    /// out (up to `lookaheadSeconds`), so the player node is stopped a
    /// little later.
    private func finishRamp() {
        rampActive = false
        isPlaying = false
        timer?.cancel()
        timer = nil
        onRampProgress?(RampProgress(stepIndex: rampStepIndex, bpm: rampCurrentBpm, finished: true))
        serialQueue.asyncAfter(deadline: .now() + lookaheadSeconds + 0.1) { [weak self] in
            guard let self = self, !self.isPlaying else { return }
            self.playerNode.stop()
        }
    }

    // framesPerPulse = (60 / bpm / pulsesPerBeat) * sampleRate.
    // Compute in double so triplet rates don't drift by integer-division
    // rounding; cast once at the end. Must only be called on serialQueue.
    private func currentFramesPerPulse() -> AVAudioFramePosition {
        AVAudioFramePosition(
            (60.0 / bpm / Double(max(pulsesPerBeat, 1))) * sampleRate
        )
    }
}
