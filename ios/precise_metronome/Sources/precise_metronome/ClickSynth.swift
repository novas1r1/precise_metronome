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
    case wood
    case mechanical
    case blip
}

struct ClickBuffers {
    let accent: AVAudioPCMBuffer
    let normal: AVAudioPCMBuffer
    /// Soft click used for subdivision pulses between main beats.
    /// Same waveform as `normal`, rendered at reduced amplitude.
    let sub: AVAudioPCMBuffer
}

/// Relative amplitude of subdivision (sub) pulses compared to a normal
/// beat. 0.5 gives a clearly audible "and-a" without overpowering the
/// main beat.
private let kSubAmplitudeScale: Float = 0.5

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
        let sub: AVAudioPCMBuffer?

        switch voice {
        case .tone:
            accent = renderTone(format: format, frequency: 1500.0, amplitude: 0.85)
            normal = renderTone(format: format, frequency: 1000.0, amplitude: 0.55)
            sub    = renderTone(format: format, frequency: 1000.0,
                                amplitude: 0.55 * kSubAmplitudeScale)
        case .click:
            accent = renderClick(format: format, transientHz: 2000.0, amplitude: 0.85)
            normal = renderClick(format: format, transientHz: 1500.0, amplitude: 0.55)
            sub    = renderClick(format: format, transientHz: 1500.0,
                                 amplitude: 0.55 * kSubAmplitudeScale)
        case .wood:
            accent = renderWood(format: format, fundamentalHz: 1080.0, amplitude: 0.85)
            normal = renderWood(format: format, fundamentalHz: 820.0, amplitude: 0.55)
            sub    = renderWood(format: format, fundamentalHz: 820.0,
                                amplitude: 0.55 * kSubAmplitudeScale)
        case .mechanical:
            accent = renderMechanical(format: format, isAccent: true, amplitude: 0.85)
            normal = renderMechanical(format: format, isAccent: false, amplitude: 0.55)
            sub    = renderMechanical(format: format, isAccent: false,
                                      amplitude: 0.55 * kSubAmplitudeScale)
        case .blip:
            accent = renderBlip(format: format, fundamentalHz: 660.0, amplitude: 0.85)
            normal = renderBlip(format: format, fundamentalHz: 523.0, amplitude: 0.55)
            sub    = renderBlip(format: format, fundamentalHz: 523.0,
                                amplitude: 0.55 * kSubAmplitudeScale)
        }

        guard let a = accent, let n = normal, let s = sub else { return nil }
        return ClickBuffers(accent: a, normal: n, sub: s)
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

    // MARK: - Wood voice: modal synthesis of a struck wooden bar, ~90 ms.
    // Three inharmonic decaying partials (free-bar ratios) plus a short
    // band-passed stick-impact noise. Warm and hollow.
    private static func renderWood(
        format: AVAudioFormat,
        fundamentalHz: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let durationSec = 0.090
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let ptr = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        // (frequency ratio, relative amplitude, decay time constant)
        let modes: [(Double, Double, Double)] = [
            (1.00, 1.00, 0.030),
            (2.12, 0.50, 0.015),
            (3.75, 0.25, 0.008),
        ]

        // Stick-impact noise: band-passed around 2.5 kHz, very short.
        let f0 = 2500.0
        let q = 1.5
        let w0 = twoPi * f0 / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let a0 = 1.0 + alpha
        let nB0 = alpha / a0
        let nB2 = -alpha / a0
        let nA1 = (-2.0 * cos(w0)) / a0
        let nA2 = (1.0 - alpha) / a0
        let tauNoise = 0.003
        let noiseGain = 0.35

        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var rngState: UInt32 = 0x13579BDF

        @inline(__always) func nextWhiteNoise() -> Double {
            rngState ^= rngState << 13
            rngState ^= rngState >> 17
            rngState ^= rngState << 5
            return Double(Int32(bitPattern: rngState)) / Double(Int32.max)
        }

        let attackFrames = max(Int(0.0005 * sampleRate), 1)

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for (ratio, amp, tau) in modes {
                sample += amp * sin(twoPi * fundamentalHz * ratio * t) * exp(-t / tau)
            }

            let noise = nextWhiteNoise()
            let filtered = nB0 * noise + nB2 * x2 - nA1 * y1 - nA2 * y2
            x2 = x1; x1 = noise
            y2 = y1; y1 = filtered
            sample += filtered * exp(-t / tauNoise) * noiseGain

            var attackGain = 1.0
            if i < attackFrames {
                attackGain = Double(i) / Double(attackFrames)
            }
            // 0.55: headroom for the summed modes.
            ptr[i] = Float(sample * attackGain * 0.55) * amplitude
        }

        return buffer
    }

    // MARK: - Mechanical voice: pendulum-metronome tick.
    // Broadband snap (band-passed noise) plus a low wooden-case resonance.
    // The accent additionally rings with bell-like partials so it stands
    // out clearly against the plain tick.
    private static func renderMechanical(
        format: AVAudioFormat,
        isAccent: Bool,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let durationSec = isAccent ? 0.070 : 0.045
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let ptr = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        let snapHz = isAccent ? 3400.0 : 2800.0
        let q = 0.9
        let w0 = twoPi * snapHz / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let a0 = 1.0 + alpha
        let nB0 = alpha / a0
        let nB2 = -alpha / a0
        let nA1 = (-2.0 * cos(w0)) / a0
        let nA2 = (1.0 - alpha) / a0

        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var rngState: UInt32 = 0x13579BDF

        @inline(__always) func nextWhiteNoise() -> Double {
            rngState ^= rngState << 13
            rngState ^= rngState >> 17
            rngState ^= rngState << 5
            return Double(Int32(bitPattern: rngState)) / Double(Int32.max)
        }

        let attackFrames = max(Int(0.0002 * sampleRate), 1)

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate

            let noise = nextWhiteNoise()
            let filtered = nB0 * noise + nB2 * x2 - nA1 * y1 - nA2 * y2
            x2 = x1; x1 = noise
            y2 = y1; y1 = filtered
            var sample = filtered * exp(-t / 0.0025) * 1.4

            // Low wooden-case resonance.
            sample += 0.5 * sin(twoPi * 620.0 * t) * exp(-t / 0.010)

            if isAccent {
                // Bell ring, like the bell of an old mechanical metronome.
                sample += 0.6 * sin(twoPi * 1250.0 * t) * exp(-t / 0.020)
                sample += 0.2 * sin(twoPi * 2500.0 * t) * exp(-t / 0.008)
            }

            var attackGain = 1.0
            if i < attackFrames {
                attackGain = Double(i) / Double(attackFrames)
            }
            // 0.9: headroom — snap noise plus bell can peak just above 1.0.
            ptr[i] = Float(sample * attackGain * 0.9) * amplitude
        }

        return buffer
    }

    // MARK: - Blip voice: soft marimba-like tone, gentle 2 ms attack.
    // Fundamental plus a quickly decaying 4th partial (marimba bar tuning).
    private static func renderBlip(
        format: AVAudioFormat,
        fundamentalHz: Double,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let durationSec = 0.090
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let ptr = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        let attackFrames = max(Int(0.002 * sampleRate), 1)

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = sin(twoPi * fundamentalHz * t) * exp(-t / 0.035)
            sample += 0.25 * sin(twoPi * fundamentalHz * 4.0 * t) * exp(-t / 0.008)

            var attackGain = 1.0
            if i < attackFrames {
                attackGain = Double(i) / Double(attackFrames)
            }
            ptr[i] = Float(sample * attackGain) * amplitude
        }

        return buffer
    }
}
