import Flutter
import UIKit

public class PreciseMetronomePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var engine: MetronomeEngine?
    private var rampSink: FlutterEventSink?

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
        rampChannel.setStreamHandler(instance)
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
            requireEngine(result)?.startRamp(
                initialDelaySeconds: Double(initialDelayMs) / 1000.0,
                startBpm: startBpm,
                goalBpm: goalBpm,
                stopAtGoal: stopAtGoal,
                stepBpm: stepBpm,
                barsPerStep: barsPerStep)
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

    // MARK: - FlutterStreamHandler (ramp progress)

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        rampSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        rampSink = nil
        return nil
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
