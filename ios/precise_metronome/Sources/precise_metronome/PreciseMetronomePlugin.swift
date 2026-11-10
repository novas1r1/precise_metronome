import Flutter
import UIKit

/// Flutter entry point: dispatches method calls to the engine and forwards
/// its ramp progress and beat events to Dart.
public class PreciseMetronomePlugin: NSObject, FlutterPlugin {

    private var engine: MetronomeEngine?
    private var rampSink: FlutterEventSink?
    private var beatSink: FlutterEventSink?
    private var rampStreamHandler: StreamSinkHandler?
    private var beatStreamHandler: StreamSinkHandler?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "precise_metronome",
            binaryMessenger: registrar.messenger()
        )
        let instance = PreciseMetronomePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let rampChannel = FlutterEventChannel(
            name: "precise_metronome/ramp",
            binaryMessenger: registrar.messenger()
        )
        let rampHandler = StreamSinkHandler { [weak instance] sink in instance?.rampSink = sink }
        instance.rampStreamHandler = rampHandler
        rampChannel.setStreamHandler(rampHandler)

        let beatChannel = FlutterEventChannel(
            name: "precise_metronome/beats",
            binaryMessenger: registrar.messenger()
        )
        let beatHandler = StreamSinkHandler { [weak instance] sink in instance?.beatSink = sink }
        instance.beatStreamHandler = beatHandler
        beatChannel.setStreamHandler(beatHandler)
    }

    // MARK: - Dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {

        case "init":
            initEngine(result)

        case "start":
            let initialDelayMs = args["initialDelayMs"] as? Int ?? 0
            withEngine(result) { $0.start(initialDelaySeconds: seconds(initialDelayMs)) }

        case "startRamp":
            guard let startBpm = args["startBpm"] as? Double,
                  let goalBpm = args["goalBpm"] as? Double,
                  let stopAtGoal = args["stopAtGoal"] as? Bool,
                  let stepBpm = args["stepBpm"] as? Double,
                  let barsPerStep = args["barsPerStep"] as? Int else {
                return result(argError("startBpm, goalBpm, stepBpm: Double, stopAtGoal: Bool, barsPerStep: Int"))
            }
            let initialDelayMs = args["initialDelayMs"] as? Int ?? 0
            // A timed step: the step length in ms, 0 for bars.
            let stepMs = args["stepMs"] as? Int ?? 0
            let returnToStart = args["returnToStart"] as? Bool ?? false
            guard barsPerStep >= 1 || stepMs >= 1 else {
                return result(argError("barsPerStep >= 1 or stepMs >= 1"))
            }
            withEngine(result) {
                $0.startRamp(
                    initialDelaySeconds: seconds(initialDelayMs),
                    startBpm: startBpm,
                    goalBpm: goalBpm,
                    stopAtGoal: stopAtGoal,
                    stepBpm: stepBpm,
                    barsPerStep: barsPerStep,
                    stepSeconds: seconds(stepMs),
                    returnToStart: returnToStart)
            }

        case "nudge":
            guard let deltaMs = args["deltaMs"] as? Int else {
                return result(argError("deltaMs: Int"))
            }
            withEngine(result) { $0.nudge(deltaSeconds: seconds(deltaMs)) }

        case "stop":
            withEngine(result) { $0.stop() }

        case "setTempo":
            guard let bpm = args["bpm"] as? Double else {
                return result(argError("bpm: Double"))
            }
            withEngine(result) { $0.setTempo(bpm) }

        case "setTimeSignature":
            guard let beatsPerBar = args["beatsPerBar"] as? Int,
                  let pattern = args["accentPattern"] as? [Bool] else {
                return result(argError("beatsPerBar: Int, accentPattern: [Bool]"))
            }
            withEngine(result) { $0.setTimeSignature(beatsPerBar: beatsPerBar, accentPattern: pattern) }

        case "setAccentPattern":
            guard let pattern = args["accentPattern"] as? [Bool] else {
                return result(argError("accentPattern: [Bool]"))
            }
            withEngine(result) { $0.setAccentPattern(pattern) }

        case "setSubdivision":
            guard let pulsesPerBeat = args["pulsesPerBeat"] as? Int else {
                return result(argError("pulsesPerBeat: Int"))
            }
            withEngine(result) { $0.setSubdivision(pulsesPerBeat: pulsesPerBeat) }

        case "setVoice":
            guard let voice = args["voice"] as? String else {
                return result(argError("voice: String"))
            }
            withEngine(result) { $0.setVoice(voice) }

        case "setBeatEvents":
            guard let enabled = args["enabled"] as? Bool else {
                return result(argError("enabled: Bool"))
            }
            let includeSubdivisions = args["includeSubdivisions"] as? Bool ?? false
            withEngine(result) {
                $0.setBeatEvents(enabled: enabled, includeSubdivisions: includeSubdivisions)
            }

        case "setVolume":
            guard let volume = args["volume"] as? Double else {
                return result(argError("volume: Double"))
            }
            withEngine(result) { $0.setVolume(volume) }

        case "setGapPlan":
            guard let segment = args["segment"] as? Int,
                  let from = args["from"] as? Int,
                  let silent = args["silent"] as? [Bool] else {
                return result(argError("segment: Int, from: Int, silent: [Bool]"))
            }
            withEngine(result) { $0.setGapBars(segment: segment, from: from, silent: silent) }

        case "clearGapPlan":
            guard let segment = args["segment"] as? Int else {
                return result(argError("segment: Int"))
            }
            withEngine(result) { $0.clearGapPlan(segment: segment) }

        case "enableBackgroundPlayback", "disableBackgroundPlayback":
            // Background playback on iOS is the audio session category
            // (`.playback`, set at init) plus `UIBackgroundModes: audio`
            // in the host app's Info.plist. There is nothing to switch.
            withEngine(result) { _ in }

        case "dispose":
            engine?.dispose()
            engine = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initEngine(_ result: FlutterResult) {
        let e = MetronomeEngine()
        e.onRampProgress = { [weak self] progress in
            DispatchQueue.main.async {
                self?.rampSink?([
                    "stepIndex": progress.stepIndex,
                    "bpm": progress.bpm,
                    "finished": progress.finished,
                ])
            }
        }
        e.onBeat = { [weak self] beat in
            // Already on the main queue.
            self?.beatSink?([
                "bar": beat.bar,
                "beat": beat.beat,
                "pulse": beat.pulse,
                "accent": beat.accent,
                "muted": beat.muted,
                "landing": beat.landing,
                "gapSegment": beat.gapSegment,
                "gapBar": beat.gapBar,
            ])
        }
        do {
            try e.initialize()
            engine = e
            result(nil)
        } catch {
            result(FlutterError(
                code: "init_failed",
                message: "Could not initialize audio engine: \(error.localizedDescription)",
                details: nil))
        }
    }

    /// Runs `body` on the engine and replies with success, or replies
    /// with `not_initialized` when there is no engine yet. Either way the
    /// result is sent exactly once.
    private func withEngine(_ result: FlutterResult, _ body: (MetronomeEngine) -> Void) {
        guard let engine = engine else {
            return result(FlutterError(code: "not_initialized",
                                       message: "Call init() first.",
                                       details: nil))
        }
        body(engine)
        result(nil)
    }

    private func argError(_ expected: String) -> FlutterError {
        FlutterError(code: "bad_arguments",
                     message: "Expected \(expected).",
                     details: nil)
    }

    private func seconds(_ milliseconds: Int) -> Double {
        Double(milliseconds) / 1000.0
    }
}

/// Minimal FlutterStreamHandler that hands the sink (or nil) to a closure.
final class StreamSinkHandler: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void

    init(_ onSink: @escaping (FlutterEventSink?) -> Void) {
        self.onSink = onSink
    }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSink(nil)
        return nil
    }
}
