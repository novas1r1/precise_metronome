#pragma once

#include <oboe/Oboe.h>

#include <array>
#include <cstdint>
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
    // First pulse fires `initial_delay_ms` later than it otherwise would.
    void start(int64_t initial_delay_ms = 0);
    // Like start(), but steps the tempo from start_bpm towards goal_bpm by
    // step_bpm every bars_per_step bars (last step clamped to goal_bpm). With
    // stop_at_goal it stops itself after goal_bpm has been played for
    // bars_per_step bars; otherwise it holds goal_bpm until stop().
    void start_ramp(int64_t initial_delay_ms, double start_bpm,
                    double goal_bpm, bool stop_at_goal, double step_bpm,
                    int bars_per_step);
    void stop();
    void dispose();

    // Shifts the phase of all future pulses while playing; rolls forward by
    // whole pulse periods if the shift would collide with an already-rendered
    // pulse or land in the past. No-op (and cleared) when stopped.
    void nudge(int64_t delta_ms);

    void set_tempo(double bpm);
    void set_time_signature(int beats_per_bar, const bool* pattern, int length);
    void set_accent_pattern(const bool* pattern, int length);
    void set_subdivision(int pulses_per_beat);
    void set_voice(int voice_index);
    void set_volume(double volume);

    // Beat events: when enabled, the audio thread records every rendered
    // pulse (or only main beats) into a small lock-free ring buffer that
    // the Flutter thread drains with drain_beat_events().
    struct BeatEvent {
        int32_t bar;
        int32_t beat;
        int32_t pulse;
        int32_t accent;
    };
    void set_beat_events(bool enabled, bool include_subdivisions);
    // Copies up to `max` pending events into `out`, oldest first, and
    // returns how many were copied. If the reader fell more than the ring
    // size behind, the oldest events are dropped. Flutter thread only.
    int drain_beat_events(BeatEvent* out, int max);

    // Ramp progress, readable from any thread. step_index is 0-based;
    // finished becomes true once the engine has stopped itself. All three
    // are updated together on the audio thread; a reader may observe them
    // one field apart, which is harmless for progress display.
    int ramp_step_index() const {
        return ramp_step_index_.load(std::memory_order_acquire);
    }
    double ramp_bpm() const {
        return ramp_bpm_.load(std::memory_order_acquire);
    }
    bool ramp_finished() const {
        return ramp_finished_.load(std::memory_order_acquire);
    }

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

    void begin_session(int64_t initial_delay_ms);
    bool on_ramp_bar_completed();
    bool open_stream();
    void close_stream();
    void rebuild_buffers(double sample_rate);

    std::shared_ptr<oboe::AudioStream> stream_;
    int32_t sample_rate_ = 48000;
    int32_t channel_count_ = 2;

    // Parameters mutated from Flutter thread, read from audio thread.
    std::atomic<double> bpm_{120.0};
    std::atomic<int> beats_per_bar_{4};
    std::atomic<int> pulses_per_beat_{1};
    std::atomic<int> voice_index_{0};
    std::atomic<double> volume_{0.8};
    std::atomic<bool> playing_{false};
    std::atomic<bool> reset_requested_{false};
    // Delay (in frames) applied to the anchor of the next play session.
    std::atomic<int64_t> initial_delay_frames_{0};
    // Accumulated phase shift (in frames) the audio thread has yet to apply.
    std::atomic<int64_t> pending_nudge_frames_{0};
    // Set to true when a subdivision change requires the audio thread to
    // snap to a clean beat boundary on its next pulse.
    std::atomic<bool> realign_pulse_requested_{false};

    // Tempo ramp parameters (Flutter thread writes before start_ramp() sets
    // reset_requested_; audio thread reads after seeing it).
    std::atomic<bool> ramp_enabled_{false};
    std::atomic<double> ramp_goal_bpm_{120.0};
    std::atomic<bool> ramp_stop_at_goal_{true};
    std::atomic<double> ramp_step_bpm_{0.0};
    std::atomic<int> ramp_bars_per_step_{1};
    // Ramp progress published by the audio thread.
    std::atomic<int> ramp_step_index_{0};
    std::atomic<double> ramp_bpm_{120.0};
    std::atomic<bool> ramp_finished_{false};

    // Beat event ring (single producer: audio thread; single consumer:
    // Flutter thread).
    static constexpr uint32_t kBeatRingSize = 64;
    std::atomic<bool> beat_events_enabled_{false};
    std::atomic<bool> beat_events_include_sub_{false};
    std::array<BeatEvent, kBeatRingSize> beat_ring_{};
    std::atomic<uint32_t> beat_write_count_{0};
    uint32_t beat_read_count_ = 0;  // Flutter thread only

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
    int64_t next_pulse_frame_ = 0;
    int64_t last_pulse_frame_ = 0;
    int beat_index_in_bar_ = 0;
    int bar_index_ = 0;
    int pulse_index_in_beat_ = 0;
    bool has_anchor_ = false;
    // Ramp state, audio-thread-only.
    bool ramp_active_ = false;
    int ramp_bars_in_step_ = 0;
    double ramp_current_bpm_ = 120.0;

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
