import Flutter
import UIKit

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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "init":
            do {
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
                    ])
                }
                try e.initialize()
                engine = e
                result(nil)
            } catch {
                result(FlutterError(
                    code: "init_failed",
                    message: "Could not initialize audio engine: \(error.localizedDescription)",
                    details: nil))
            }

        case "start":
            let args = call.arguments as? [String: Any]
            let initialDelayMs = args?["initialDelayMs"] as? Int ?? 0
            requireEngine(result)?.start(
                initialDelaySeconds: Double(initialDelayMs) / 1000.0)
            result(nil)

        case "startRamp":
            guard let args = call.arguments as? [String: Any],
                  let startBpm = args["startBpm"] as? Double,
                  let goalBpm = args["goalBpm"] as? Double,
                  let stopAtGoal = args["stopAtGoal"] as? Bool,
                  let stepBpm = args["stepBpm"] as? Double,
                  let barsPerStep = args["barsPerStep"] as? Int else {
                result(argError("startBpm, goalBpm, stepBpm: Double, stopAtGoal: Bool, barsPerStep: Int")); return
            }
            let initialDelayMs = args["initialDelayMs"] as? Int ?? 0
            let returnToStart = args["returnToStart"] as? Bool ?? false
            requireEngine(result)?.startRamp(
                initialDelaySeconds: Double(initialDelayMs) / 1000.0,
                startBpm: startBpm,
                goalBpm: goalBpm,
                stopAtGoal: stopAtGoal,
                stepBpm: stepBpm,
                barsPerStep: barsPerStep,
                returnToStart: returnToStart)
            result(nil)

        case "nudge":
            guard let args = call.arguments as? [String: Any],
                  let deltaMs = args["deltaMs"] as? Int else {
                result(argError("deltaMs: Int")); return
            }
            requireEngine(result)?.nudge(
                deltaSeconds: Double(deltaMs) / 1000.0)
            result(nil)

        case "stop":
            requireEngine(result)?.stop()
            result(nil)

        case "setTempo":
            guard let args = call.arguments as? [String: Any],
                  let bpm = args["bpm"] as? Double else {
                result(argError("bpm: Double")); return
            }
            requireEngine(result)?.setTempo(bpm)
            result(nil)

        case "setTimeSignature":
            guard let args = call.arguments as? [String: Any],
                  let beatsPerBar = args["beatsPerBar"] as? Int,
                  let pattern = args["accentPattern"] as? [Bool] else {
                result(argError("beatsPerBar: Int, accentPattern: [Bool]")); return
            }
            requireEngine(result)?.setTimeSignature(beatsPerBar: beatsPerBar, accentPattern: pattern)
            result(nil)

        case "setAccentPattern":
            guard let args = call.arguments as? [String: Any],
                  let pattern = args["accentPattern"] as? [Bool] else {
                result(argError("accentPattern: [Bool]")); return
            }
            requireEngine(result)?.setAccentPattern(pattern)
            result(nil)

        case "setSubdivision":
            guard let args = call.arguments as? [String: Any],
                  let ppb = args["pulsesPerBeat"] as? Int else {
                result(argError("pulsesPerBeat: Int")); return
            }
            requireEngine(result)?.setSubdivision(pulsesPerBeat: ppb)
            result(nil)

        case "setVoice":
            guard let args = call.arguments as? [String: Any],
                  let voice = args["voice"] as? String else {
                result(argError("voice: String")); return
            }
            requireEngine(result)?.setVoice(voice)
            result(nil)

        case "setBeatEvents":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["enabled"] as? Bool else {
                result(argError("enabled: Bool")); return
            }
            let includeSub = args["includeSubdivisions"] as? Bool ?? false
            requireEngine(result)?.setBeatEvents(enabled: enabled, includeSubdivisions: includeSub)
            result(nil)

        case "setVolume":
            guard let args = call.arguments as? [String: Any],
                  let volume = args["volume"] as? Double else {
                result(argError("volume: Double")); return
            }
            requireEngine(result)?.setVolume(volume)
            result(nil)

        case "enableBackgroundPlayback":
            requireEngine(result)?.enableBackgroundPlayback()
            result(nil)

        case "disableBackgroundPlayback":
            requireEngine(result)?.disableBackgroundPlayback()
            result(nil)

        case "dispose":
            engine?.dispose()
            engine = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requireEngine(_ result: FlutterResult) -> MetronomeEngine? {
        if let e = engine { return e }
        result(FlutterError(code: "not_initialized",
                            message: "Call init() first.",
                            details: nil))
        return nil
    }

    private func argError(_ expected: String) -> FlutterError {
        FlutterError(code: "bad_arguments",
                     message: "Expected \(expected).",
                     details: nil)
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
