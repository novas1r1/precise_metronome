#include "click_synth.h"

#include <cmath>
#include <cstdint>
#include <cstring>

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

// Normalized biquad bandpass coefficients (constant-skirt form).
struct Bandpass {
    double b0, b2, a1, a2;
    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    Bandpass(double center_hz, double q, double sample_rate) {
        const double w0 = kTwoPi * center_hz / sample_rate;
        const double alpha = std::sin(w0) / (2.0 * q);
        const double a0 = 1.0 + alpha;
        b0 = alpha / a0;
        b2 = -alpha / a0;
        a1 = (-2.0 * std::cos(w0)) / a0;
        a2 = (1.0 - alpha) / a0;
    }
    double run(double x) {
        const double y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
        x2 = x1; x1 = x;
        y2 = y1; y1 = y;
        return y;
    }
};

// Wood voice: modal synthesis of a struck wooden bar, ~90 ms. Three
// inharmonic decaying partials (free-bar ratios) plus a short band-passed
// stick-impact noise. Warm and hollow.
std::vector<float> render_wood(double sample_rate,
                               double fundamental_hz,
                               float amplitude) {
    constexpr double kDurationSec = 0.090;
    constexpr double kAttackSec = 0.0005;
    constexpr double kTauNoise = 0.003;
    constexpr double kNoiseGain = 0.35;
    // (frequency ratio, relative amplitude, decay time constant)
    constexpr double kModes[3][3] = {
        {1.00, 1.00, 0.030},
        {2.12, 0.50, 0.015},
        {3.75, 0.25, 0.008},
    };

    const int frame_count = static_cast<int>(kDurationSec * sample_rate);
    const int attack_frames =
        std::max(1, static_cast<int>(kAttackSec * sample_rate));

    std::vector<float> out(static_cast<size_t>(frame_count), 0.0f);

    Bandpass bp{2500.0, 1.5, sample_rate};
    Xorshift32 rng{0x13579BDFu};

    for (int i = 0; i < frame_count; ++i) {
        const double t = static_cast<double>(i) / sample_rate;
        double sample = 0.0;
        for (const auto& mode : kModes) {
            sample += mode[1] *
                      std::sin(kTwoPi * fundamental_hz * mode[0] * t) *
                      std::exp(-t / mode[2]);
        }
        sample += bp.run(rng.next()) * std::exp(-t / kTauNoise) * kNoiseGain;

        double attack_gain = 1.0;
        if (i < attack_frames) {
            attack_gain = static_cast<double>(i) /
                          static_cast<double>(attack_frames);
        }
        // 0.55: headroom for the summed modes.
        out[i] = static_cast<float>(sample * attack_gain * 0.55) * amplitude;
    }
    return out;
}

// Mechanical voice: pendulum-metronome tick. Broadband snap (band-passed
// noise) plus a low wooden-case resonance. The accent additionally rings
// with bell-like partials so it stands out clearly against the plain tick.
std::vector<float> render_mechanical(double sample_rate,
                                     bool is_accent,
                                     float amplitude) {
    const double duration_sec = is_accent ? 0.070 : 0.045;
    constexpr double kAttackSec = 0.0002;

    const int frame_count = static_cast<int>(duration_sec * sample_rate);
    const int attack_frames =
        std::max(1, static_cast<int>(kAttackSec * sample_rate));

    std::vector<float> out(static_cast<size_t>(frame_count), 0.0f);

    Bandpass bp{is_accent ? 3400.0 : 2800.0, 0.9, sample_rate};
    Xorshift32 rng{0x13579BDFu};

    for (int i = 0; i < frame_count; ++i) {
        const double t = static_cast<double>(i) / sample_rate;

        double sample = bp.run(rng.next()) * std::exp(-t / 0.0025) * 1.4;
        // Low wooden-case resonance.
        sample += 0.5 * std::sin(kTwoPi * 620.0 * t) * std::exp(-t / 0.010);
        if (is_accent) {
            // Bell ring, like the bell of an old mechanical metronome.
            sample += 0.6 * std::sin(kTwoPi * 1250.0 * t) *
                      std::exp(-t / 0.020);
            sample += 0.2 * std::sin(kTwoPi * 2500.0 * t) *
                      std::exp(-t / 0.008);
        }

        double attack_gain = 1.0;
        if (i < attack_frames) {
            attack_gain = static_cast<double>(i) /
                          static_cast<double>(attack_frames);
        }
        // 0.9: headroom — snap noise plus bell can peak just above 1.0.
        out[i] = static_cast<float>(sample * attack_gain * 0.9) * amplitude;
    }
    return out;
}

// Blip voice: soft marimba-like tone with a gentle 2 ms attack.
// Fundamental plus a quickly decaying 4th partial (marimba bar tuning).
std::vector<float> render_blip(double sample_rate,
                               double fundamental_hz,
                               float amplitude) {
    constexpr double kDurationSec = 0.090;
    constexpr double kAttackSec = 0.002;

    const int frame_count = static_cast<int>(kDurationSec * sample_rate);
    const int attack_frames =
        std::max(1, static_cast<int>(kAttackSec * sample_rate));

    std::vector<float> out(static_cast<size_t>(frame_count), 0.0f);

    for (int i = 0; i < frame_count; ++i) {
        const double t = static_cast<double>(i) / sample_rate;
        double sample =
            std::sin(kTwoPi * fundamental_hz * t) * std::exp(-t / 0.035);
        sample += 0.25 * std::sin(kTwoPi * fundamental_hz * 4.0 * t) *
                  std::exp(-t / 0.008);

        double attack_gain = 1.0;
        if (i < attack_frames) {
            attack_gain = static_cast<double>(i) /
                          static_cast<double>(attack_frames);
        }
        out[i] = static_cast<float>(sample * attack_gain) * amplitude;
    }
    return out;
}

}  // namespace

bool parse_click_voice(const char* name, ClickVoice* voice) {
    struct Entry {
        const char* name;
        ClickVoice voice;
    };
    // Mirrors the Dart `MetronomeVoice` enum and the Swift `ClickVoice`.
    static constexpr Entry kVoices[] = {
        {"tone", ClickVoice::Tone},
        {"click", ClickVoice::Click},
        {"wood", ClickVoice::Wood},
        {"mechanical", ClickVoice::Mechanical},
        {"blip", ClickVoice::Blip},
    };
    for (const Entry& entry : kVoices) {
        if (std::strcmp(name, entry.name) == 0) {
            *voice = entry.voice;
            return true;
        }
    }
    return false;
}

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
        case ClickVoice::Wood:
            out.accent = render_wood(sample_rate, 1080.0, 0.85f);
            out.normal = render_wood(sample_rate, 820.0, 0.55f);
            out.sub    = render_wood(sample_rate, 820.0,
                                     0.55f * kSubAmplitudeScale);
            break;
        case ClickVoice::Mechanical:
            out.accent = render_mechanical(sample_rate, true, 0.85f);
            out.normal = render_mechanical(sample_rate, false, 0.55f);
            out.sub    = render_mechanical(sample_rate, false,
                                           0.55f * kSubAmplitudeScale);
            break;
        case ClickVoice::Blip:
            out.accent = render_blip(sample_rate, 660.0, 0.85f);
            out.normal = render_blip(sample_rate, 523.0, 0.55f);
            out.sub    = render_blip(sample_rate, 523.0,
                                     0.55f * kSubAmplitudeScale);
            break;
    }
    return out;
}

}  // namespace precise_metronome
