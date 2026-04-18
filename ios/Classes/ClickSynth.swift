import Foundation
import AVFoundation

/// Pre-rendered click buffers for the two built-in voices, each in both
/// accent and normal variants. All buffers share the same sample rate and
/// are mono.
///
/// Clicks are synthesized once at startup (when the voice is first
/// selected) and then simply scheduled for playback — zero DSP happens
/// during the audio callback.
enum ClickVoice: String {
    case tone
    case click
}

struct ClickBuffers {
    let accent: AVAudioPCMBuffer
    let normal: AVAudioPCMBuffer
}

enum ClickSynth {

    /// Build both accent and normal buffers for the given voice at the
    /// given sample rate. The returned buffers are mono Float32.
    static func render(voice: ClickVoice, sampleRate: Double) -> ClickBuffers? {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        guard let format = format else { return nil }

        let accent: AVAudioPCMBuffer?
        let normal: AVAudioPCMBuffer?

        switch voice {
        case .tone:
            accent = renderTone(format: format, frequency: 1500.0, amplitude: 0.85)
            normal = renderTone(format: format, frequency: 1000.0, amplitude: 0.55)
        case .click:
            accent = renderClick(format: format, transientHz: 2000.0, amplitude: 0.85)
            normal = renderClick(format: format, transientHz: 1500.0, amplitude: 0.55)
        }

        guard let a = accent, let n = normal else { return nil }
        return ClickBuffers(accent: a, normal: n)
    }

    // MARK: - Tone voice: pitched burst, exponential decay ~30 ms.
    private static func renderTone(
        format: AVAudioFormat,
        frequency: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let durationSec = 0.040   // 40 ms tail gives audible decay without overlap risk.
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let ptr = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        let tau: Double = 0.012                   // 12 ms decay time constant
        let attackFrames = Int(0.0008 * sampleRate) // 0.8 ms soft attack to avoid click-at-start artifact

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let phase = twoPi * frequency * t
            // Sine + a touch of triangle-ish content (3rd harmonic, tiny amount).
            let sample = sin(phase) + 0.18 * sin(phase * 3.0 + 0.25)
            let envelope = exp(-t / tau)
            var attackGain: Double = 1.0
            if i < attackFrames {
                attackGain = Double(i) / Double(max(attackFrames, 1))
            }
            ptr[i] = Float(sample * envelope * attackGain) * amplitude
        }

        return buffer
    }

    // MARK: - Click voice: pitched transient + bandpassed noise burst, ~20 ms.
    private static func renderClick(
        format: AVAudioFormat,
        transientHz: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let durationSec = 0.030   // 30 ms tail
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let ptr = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        let tauTransient: Double = 0.004   // 4 ms — very short transient
        let tauNoise: Double = 0.008       // 8 ms noise body

        // Simple biquad bandpass state for the noise. Cheap & colored.
        // Centered around 4 kHz. Coefficients precomputed below.
        let f0: Double = 4000.0
        let q: Double = 2.0
        let w0 = twoPi * f0 / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let b0 =  alpha
        let b1 =  0.0
        let b2 = -alpha
        let a0 =  1.0 + alpha
        let a1 = -2.0 * cos(w0)
        let a2 =  1.0 - alpha
        let nB0 = b0 / a0
        let nB1 = b1 / a0
        let nB2 = b2 / a0
        let nA1 = a1 / a0
        let nA2 = a2 / a0

        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var rngState: UInt32 = 0x13579BDF // deterministic so the click is reproducible

        @inline(__always) func nextWhiteNoise() -> Double {
            // xorshift32 → [-1, 1]
            rngState ^= rngState << 13
            rngState ^= rngState >> 17
            rngState ^= rngState << 5
            let n = Double(Int32(bitPattern: rngState)) / Double(Int32.max)
            return n
        }

        let attackFrames = Int(0.0004 * sampleRate) // 0.4 ms attack, keeps the click feel

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate

            // Pitched transient
            let transient = sin(twoPi * transientHz * t) * exp(-t / tauTransient)

            // Bandpassed noise
            let noise = nextWhiteNoise()
            let filtered = nB0 * noise + nB1 * x1 + nB2 * x2 - nA1 * y1 - nA2 * y2
            x2 = x1; x1 = noise
            y2 = y1; y1 = filtered
            let noiseBurst = filtered * exp(-t / tauNoise) * 0.6

            var attackGain: Double = 1.0
            if i < attackFrames {
                attackGain = Double(i) / Double(max(attackFrames, 1))
            }
            let sample = (transient + noiseBurst) * attackGain
            ptr[i] = Float(sample) * amplitude
        }

        return buffer
    }
}
