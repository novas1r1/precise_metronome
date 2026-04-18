#pragma once

#include <vector>
#include <cstdint>

namespace precise_metronome {

enum class ClickVoice : int {
    Tone  = 0,
    Click = 1,
};

// Renders an accent + normal click buffer for a voice at the given sample rate.
// Buffers are mono Float32 and reproducibly synthesized (no RNG seed drift).
struct ClickBuffers {
    std::vector<float> accent;  // mono samples
    std::vector<float> normal;
};

ClickBuffers render_click_buffers(ClickVoice voice, double sample_rate);

}  // namespace precise_metronome
