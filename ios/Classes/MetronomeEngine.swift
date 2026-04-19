import Foundation
import AVFoundation

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
    private var accentPattern: [Bool] = [true, false, false, false]
    private var pulsesPerBeat: Int = 1

    private var currentVoice: ClickVoice = .tone
    private var buffers: ClickBuffers?

    private var isPlaying = false
    private var beatIndexInBar = 0
    private var pulseIndexInBeat = 0
    private var nextPulseSampleTime: AVAudioFramePosition = 0
    private var hasAnchor = false

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

    func start() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isPlaying else { return }
            self.isPlaying = true
            self.beatIndexInBar = 0
            self.pulseIndexInBeat = 0
            self.hasAnchor = false
            self.playerNode.play()
            self.startTimer()
        }
    }

    func stop() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isPlaying else { return }
            self.isPlaying = false
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
            // ahead of "now" so the first click is guaranteed schedulable.
            nextPulseSampleTime = currentSampleTime + AVAudioFramePosition(0.05 * sampleRate)
            hasAnchor = true
        }

        let horizon = currentSampleTime + AVAudioFramePosition(lookaheadSeconds * sampleRate)

        while nextPulseSampleTime < horizon {
            let buffer: AVAudioPCMBuffer
            if pulseIndexInBeat == 0 {
                // Main beat: pick accent or normal from the pattern.
                let accent: Bool = beatIndexInBar < accentPattern.count
                    ? accentPattern[beatIndexInBar]
                    : (beatIndexInBar == 0)
                buffer = accent ? buffers.accent : buffers.normal
            } else {
                // Off-beat subdivision pulse: softer sub click.
                buffer = buffers.sub
            }

            let when = AVAudioTime(sampleTime: nextPulseSampleTime, atRate: sampleRate)
            playerNode.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)

            // Advance pulse / beat counters.
            let ppb = max(pulsesPerBeat, 1)
            pulseIndexInBeat += 1
            if pulseIndexInBeat >= ppb {
                pulseIndexInBeat = 0
                beatIndexInBar = (beatIndexInBar + 1) % max(beatsPerBar, 1)
            }

            // framesPerPulse = (60 / bpm / pulsesPerBeat) * sampleRate.
            // Compute in double so triplet rates don't drift by integer-division
            // rounding; cast once at the end.
            let framesPerPulse = AVAudioFramePosition(
                (60.0 / bpm / Double(ppb)) * sampleRate
            )
            nextPulseSampleTime += max(framesPerPulse, 1)
        }
    }
}
