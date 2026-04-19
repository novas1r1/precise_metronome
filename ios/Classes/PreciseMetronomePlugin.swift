import Flutter
import UIKit

public class PreciseMetronomePlugin: NSObject, FlutterPlugin {

    private var engine: MetronomeEngine?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "precise_metronome",
            binaryMessenger: registrar.messenger()
        )
        let instance = PreciseMetronomePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "init":
            do {
                let e = MetronomeEngine()
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
            requireEngine(result)?.start()
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
