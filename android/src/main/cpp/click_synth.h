#pragma once

#include <vector>
#include <cstdint>

namespace precise_metronome {

enum class ClickVoice : int {
    Tone  = 0,
    Click = 1,
};

// Renders accent + normal + sub click buffers for a voice at the given
// sample rate. Buffers are mono Float32 and reproducibly synthesized
// (no RNG seed drift). The `sub` buffer is the same waveform as
// `normal`, rendered at reduced amplitude for subdivision pulses.
struct ClickBuffers {
    std::vector<float> accent;  // mono samples
    std::vector<float> normal;
    std::vector<float> sub;
};

ClickBuffers render_click_buffers(ClickVoice voice, double sample_rate);

}  // namespace precise_metronome
