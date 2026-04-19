#include "click_synth.h"

#include <cmath>
#include <cstdint>

namespace precise_metronome {

namespace {

constexpr double kTwoPi = 6.283185307179586476925286766559;

// Deterministic xorshift32 → [-1, 1] so the click is reproducible.
struct Xorshift32 {
    uint32_t state;
    explicit Xorshift32(uint32_t seed) : state(seed) {}
    double next() {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        int32_t signed_state = static_cast<int32_t>(state);
        return static_cast<double>(signed_state) /
               static_cast<double>(INT32_MAX);
    }
};

// Tone voice: pitched burst, exponential decay ~30 ms, small soft attack.
std::vector<float> render_tone(double sample_rate,
                               double frequency,
                               float amplitude) {
    constexpr double kDurationSec = 0.040;
    constexpr double kTau = 0.012;
    constexpr double kAttackSec = 0.0008;

    const int frame_count =
        static_cast<int>(kDurationSec * sample_rate);
    const int attack_frames =
        std::max(1, static_cast<int>(kAttackSec * sample_rate));

    std::vector<float> out(static_cast<size_t>(frame_count), 0.0f);

    for (int i = 0; i < frame_count; ++i) {
        const double t = static_cast<double>(i) / sample_rate;
        const double phase = kTwoPi * frequency * t;
        const double sample =
            std::sin(phase) + 0.18 * std::sin(phase * 3.0 + 0.25);
        const double envelope = std::exp(-t / kTau);
        double attack_gain = 1.0;
        if (i < attack_frames) {
            attack_gain = static_cast<double>(i) /
                          static_cast<double>(attack_frames);
        }
        out[i] =
            static_cast<float>(sample * envelope * attack_gain) * amplitude;
    }
    return out;
}

// Click voice: pitched transient + bandpass-filtered noise burst.
std::vector<float> render_click(double sample_rate,
                                double transient_hz,
                                float amplitude) {
    constexpr double kDurationSec = 0.030;
    constexpr double kTauTransient = 0.004;
    constexpr double kTauNoise = 0.008;
    constexpr double kAttackSec = 0.0004;

    const int frame_count =
        static_cast<int>(kDurationSec * sample_rate);
    const int attack_frames =
        std::max(1, static_cast<int>(kAttackSec * sample_rate));

    std::vector<float> out(static_cast<size_t>(frame_count), 0.0f);

    // Biquad bandpass at 4 kHz, Q=2.
    constexpr double kCenterHz = 4000.0;
    constexpr double kQ = 2.0;
    const double w0 = kTwoPi * kCenterHz / sample_rate;
    const double alpha = std::sin(w0) / (2.0 * kQ);
    const double b0 = alpha;
    const double b1 = 0.0;
    const double b2 = -alpha;
    const double a0 = 1.0 + alpha;
    const double a1 = -2.0 * std::cos(w0);
    const double a2 = 1.0 - alpha;
    const double nb0 = b0 / a0;
    const double nb1 = b1 / a0;
    const double nb2 = b2 / a0;
    const double na1 = a1 / a0;
    const double na2 = a2 / a0;

    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    Xorshift32 rng{0x13579BDFu};

    for (int i = 0; i < frame_count; ++i) {
        const double t = static_cast<double>(i) / sample_rate;

        const double transient =
            std::sin(kTwoPi * transient_hz * t) * std::exp(-t / kTauTransient);

        const double noise = rng.next();
        const double filtered =
            nb0 * noise + nb1 * x1 + nb2 * x2 - na1 * y1 - na2 * y2;
        x2 = x1; x1 = noise;
        y2 = y1; y1 = filtered;
        const double noise_burst =
            filtered * std::exp(-t / kTauNoise) * 0.6;

        double attack_gain = 1.0;
        if (i < attack_frames) {
            attack_gain = static_cast<double>(i) /
                          static_cast<double>(attack_frames);
        }
        const double sample = (transient + noise_burst) * attack_gain;
        out[i] = static_cast<float>(sample) * amplitude;
    }
    return out;
}

}  // namespace

ClickBuffers render_click_buffers(ClickVoice voice, double sample_rate) {
    // Relative amplitude of subdivision pulses vs. a normal main-beat
    // click. Matches the iOS value so both platforms sound the same.
    constexpr float kSubAmplitudeScale = 0.5f;

    ClickBuffers out;
    switch (voice) {
        case ClickVoice::Tone:
            out.accent = render_tone(sample_rate, 1500.0, 0.85f);
            out.normal = render_tone(sample_rate, 1000.0, 0.55f);
            out.sub    = render_tone(sample_rate, 1000.0,
                                     0.55f * kSubAmplitudeScale);
            break;
        case ClickVoice::Click:
            out.accent = render_click(sample_rate, 2000.0, 0.85f);
            out.normal = render_click(sample_rate, 1500.0, 0.55f);
            out.sub    = render_click(sample_rate, 1500.0,
                                      0.55f * kSubAmplitudeScale);
            break;
    }
    return out;
}

}  // namespace precise_metronome
