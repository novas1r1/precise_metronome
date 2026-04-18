#pragma once

#include <oboe/Oboe.h>

#include <array>
#include <atomic>
#include <memory>
#include <mutex>
#include <vector>

#include "click_synth.h"

namespace precise_metronome {

class MetronomeEngine : public oboe::AudioStreamDataCallback,
                        public oboe::AudioStreamErrorCallback {
 public:
    MetronomeEngine();
    ~MetronomeEngine() override;

    bool initialize();
    void start();
    void stop();
    void dispose();

    void set_tempo(double bpm);
    void set_time_signature(int beats_per_bar, const bool* pattern, int length);
    void set_accent_pattern(const bool* pattern, int length);
    void set_voice(int voice_index);
    void set_volume(double volume);

    // oboe::AudioStreamDataCallback
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream* stream,
        void* audio_data,
        int32_t num_frames) override;

    // oboe::AudioStreamErrorCallback
    void onErrorAfterClose(oboe::AudioStream* stream,
                           oboe::Result result) override;

 private:
    static constexpr int kMaxPattern = 32;
    static constexpr int kMaxActiveClicks = 16;

    bool open_stream();
    void close_stream();
    void rebuild_buffers(double sample_rate);

    std::shared_ptr<oboe::AudioStream> stream_;
    int32_t sample_rate_ = 48000;
    int32_t channel_count_ = 2;

    // Parameters mutated from Flutter thread, read from audio thread.
    std::atomic<double> bpm_{120.0};
    std::atomic<int> beats_per_bar_{4};
    std::atomic<int> voice_index_{0};
    std::atomic<double> volume_{0.8};
    std::atomic<bool> playing_{false};
    std::atomic<bool> reset_requested_{false};

    // Accent pattern: fixed-size array + atomic length.
    // Writes from Flutter thread are not strictly atomic per-element, but the
    // worst case is a briefly incorrect accent on a single beat during an
    // update, which is acceptable for a metronome.
    std::array<bool, kMaxPattern> accent_pattern_{};
    std::atomic<int> pattern_length_{4};

    // Pre-rendered buffers, double-buffered: we mutate buffers_next_ from the
    // Flutter thread and have the audio thread swap to it when reset_requested_
    // is seen. Keeps the audio thread allocation-free.
    ClickBuffers buffers_current_[2];   // [voice_index]
    ClickBuffers buffers_next_[2];
    std::atomic<bool> buffers_pending_{false};

    // Audio-thread-only state.
    int64_t frames_rendered_ = 0;
    int64_t next_beat_frame_ = 0;
    int beat_index_in_bar_ = 0;
    bool has_anchor_ = false;

    struct ActiveClick {
        const float* samples;
        int total_frames;
        int cursor;
    };
    std::vector<ActiveClick> active_clicks_;

    // Guards stream lifecycle (open/close). Not held on the audio thread.
    std::mutex stream_mutex_;
};

}  // namespace precise_metronome
