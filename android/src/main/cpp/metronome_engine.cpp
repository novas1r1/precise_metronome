#include "metronome_engine.h"

#include <android/log.h>

#include <algorithm>
#include <cstring>

#define LOG_TAG "PreciseMetronome"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace precise_metronome {

MetronomeEngine::MetronomeEngine() {
    // Default accent pattern: beat 1 accented, rest unaccented.
    accent_pattern_[0] = true;
    for (int i = 1; i < kMaxPattern; ++i) accent_pattern_[i] = false;
    active_clicks_.reserve(kMaxActiveClicks);
}

MetronomeEngine::~MetronomeEngine() {
    dispose();
}

bool MetronomeEngine::initialize() {
    std::lock_guard<std::mutex> lock(stream_mutex_);
    if (!open_stream()) {
        return false;
    }
    // Build buffers before the audio callback can possibly fire.
    rebuild_buffers(static_cast<double>(sample_rate_));
    for (int v = 0; v < 2; ++v) {
        buffers_current_[v] = buffers_next_[v];
    }
    buffers_pending_.store(false, std::memory_order_release);

    // Only now do we start the stream — any callback from this point on
    // will see valid buffers.
    oboe::Result result = stream_->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("Failed to start stream: %s", oboe::convertToText(result));
        stream_->close();
        stream_.reset();
        return false;
    }
    LOGI("Engine initialized at %d Hz", sample_rate_);
    return true;
}

bool MetronomeEngine::open_stream() {
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Output)
           ->setSharingMode(oboe::SharingMode::Exclusive)
           ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
           ->setFormat(oboe::AudioFormat::Float)
           ->setChannelCount(oboe::ChannelCount::Stereo)
           ->setDataCallback(this)
           ->setErrorCallback(this)
           ->setUsage(oboe::Usage::Media)
           ->setContentType(oboe::ContentType::Music);

    oboe::Result result = builder.openStream(stream_);
    if (result != oboe::Result::OK) {
        LOGE("Failed to open stream (exclusive): %s",
             oboe::convertToText(result));
        // Fall back to shared mode if exclusive isn't available on this device.
        builder.setSharingMode(oboe::SharingMode::Shared);
        result = builder.openStream(stream_);
        if (result != oboe::Result::OK) {
            LOGE("Failed to open stream (shared): %s",
                 oboe::convertToText(result));
            return false;
        }
    }

    sample_rate_  = stream_->getSampleRate();
    channel_count_ = stream_->getChannelCount();

    // Reasonable default buffer size for low latency.
    stream_->setBufferSizeInFrames(stream_->getFramesPerBurst() * 2);

    LOGI("Stream opened: sampleRate=%d channels=%d framesPerBurst=%d",
         sample_rate_, channel_count_, stream_->getFramesPerBurst());
    return true;
}

void MetronomeEngine::close_stream() {
    if (stream_) {
        stream_->stop();
        stream_->close();
        stream_.reset();
    }
}

void MetronomeEngine::rebuild_buffers(double sample_rate) {
    buffers_next_[0] = render_click_buffers(ClickVoice::Tone,  sample_rate);
    buffers_next_[1] = render_click_buffers(ClickVoice::Click, sample_rate);
    buffers_pending_.store(true, std::memory_order_release);
}

void MetronomeEngine::start() {
    reset_requested_.store(true, std::memory_order_release);
    playing_.store(true, std::memory_order_release);
}

void MetronomeEngine::stop() {
    playing_.store(false, std::memory_order_release);
}

void MetronomeEngine::dispose() {
    stop();
    std::lock_guard<std::mutex> lock(stream_mutex_);
    close_stream();
}

void MetronomeEngine::set_tempo(double bpm) {
    bpm_.store(bpm, std::memory_order_relaxed);
}

void MetronomeEngine::set_time_signature(int beats_per_bar,
                                         const bool* pattern,
                                         int length) {
    beats_per_bar_.store(beats_per_bar, std::memory_order_relaxed);
    set_accent_pattern(pattern, length);
}

void MetronomeEngine::set_accent_pattern(const bool* pattern, int length) {
    const int clamped = std::min(length, kMaxPattern);
    for (int i = 0; i < clamped; ++i) {
        accent_pattern_[i] = pattern[i];
    }
    pattern_length_.store(clamped, std::memory_order_release);
}

void MetronomeEngine::set_voice(int voice_index) {
    if (voice_index < 0 || voice_index > 1) return;
    voice_index_.store(voice_index, std::memory_order_relaxed);
}

void MetronomeEngine::set_volume(double volume) {
    volume_.store(std::clamp(volume, 0.0, 1.0), std::memory_order_relaxed);
}

void MetronomeEngine::onErrorAfterClose(oboe::AudioStream* /*stream*/,
                                        oboe::Result result) {
    LOGE("Audio stream error after close: %s", oboe::convertToText(result));
    std::lock_guard<std::mutex> lock(stream_mutex_);
    stream_.reset();
    if (open_stream()) {
        rebuild_buffers(static_cast<double>(sample_rate_));
        for (int v = 0; v < 2; ++v) {
            buffers_current_[v] = buffers_next_[v];
        }
        buffers_pending_.store(false, std::memory_order_release);
        oboe::Result start_result = stream_->requestStart();
        if (start_result != oboe::Result::OK) {
            LOGE("Failed to restart after error: %s",
                 oboe::convertToText(start_result));
        }
    }
}

oboe::DataCallbackResult MetronomeEngine::onAudioReady(
    oboe::AudioStream* /*stream*/,
    void* audio_data,
    int32_t num_frames) {

    float* out = static_cast<float*>(audio_data);
    const int channels = channel_count_;
    const int total_samples = num_frames * channels;

    // Zero output.
    std::memset(out, 0, sizeof(float) * total_samples);

    // Adopt any pending newly-synthesized buffers between beats.
    if (buffers_pending_.load(std::memory_order_acquire)) {
        for (int v = 0; v < 2; ++v) {
            buffers_current_[v] = buffers_next_[v];
        }
        buffers_pending_.store(false, std::memory_order_release);
    }

    // Reset scheduling state on transitions into "playing".
    if (reset_requested_.exchange(false, std::memory_order_acq_rel)) {
        has_anchor_ = false;
        beat_index_in_bar_ = 0;
        active_clicks_.clear();
    }

    const float volume = static_cast<float>(
        volume_.load(std::memory_order_relaxed));
    const int voice = voice_index_.load(std::memory_order_relaxed);
    const auto& accent_buf = buffers_current_[voice].accent;
    const auto& normal_buf = buffers_current_[voice].normal;

    const bool is_playing = playing_.load(std::memory_order_acquire);

    // --- 1. Advance any clicks still playing from previous callbacks. ---
    for (auto it = active_clicks_.begin(); it != active_clicks_.end();) {
        const int remaining = it->total_frames - it->cursor;
        const int to_mix = std::min(remaining, num_frames);
        for (int i = 0; i < to_mix; ++i) {
            const float s = it->samples[it->cursor + i] * volume;
            for (int ch = 0; ch < channels; ++ch) {
                out[i * channels + ch] += s;
            }
        }
        it->cursor += to_mix;
        if (it->cursor >= it->total_frames) {
            it = active_clicks_.erase(it);
        } else {
            ++it;
        }
    }

    // --- 2. Schedule new beats falling within this callback's buffer. ---
    if (is_playing) {
        const int64_t buf_start = frames_rendered_;
        const int64_t buf_end   = frames_rendered_ + num_frames;

        if (!has_anchor_) {
            // First buffer of this play session: anchor the first beat
            // slightly ahead so we're guaranteed to fit it within the buffer
            // (but not so far that we feel delayed).
            next_beat_frame_ =
                buf_start +
                static_cast<int64_t>(0.010 * sample_rate_);
            has_anchor_ = true;
        }

        while (next_beat_frame_ < buf_end) {
            if (next_beat_frame_ >= buf_start) {
                const int offset =
                    static_cast<int>(next_beat_frame_ - buf_start);

                const int pattern_len =
                    pattern_length_.load(std::memory_order_acquire);
                const int idx = (pattern_len > 0)
                                    ? (beat_index_in_bar_ % pattern_len)
                                    : 0;
                const bool accent = (idx < kMaxPattern)
                                        ? accent_pattern_[idx]
                                        : (idx == 0);
                const auto& src = accent ? accent_buf : normal_buf;
                const int src_len = static_cast<int>(src.size());
                if (src_len > 0) {
                    const int fits_in_buffer =
                        std::min(src_len, num_frames - offset);
                    for (int i = 0; i < fits_in_buffer; ++i) {
                        const float s = src[i] * volume;
                        for (int ch = 0; ch < channels; ++ch) {
                            out[(offset + i) * channels + ch] += s;
                        }
                    }
                    if (fits_in_buffer < src_len &&
                        active_clicks_.size() < kMaxActiveClicks) {
                        active_clicks_.push_back(
                            {src.data(), src_len, fits_in_buffer});
                    }
                }
            }

            const int bpb = std::max(
                beats_per_bar_.load(std::memory_order_relaxed), 1);
            beat_index_in_bar_ = (beat_index_in_bar_ + 1) % bpb;

            const double bpm = bpm_.load(std::memory_order_relaxed);
            const int64_t frames_per_beat = static_cast<int64_t>(
                (60.0 / bpm) * static_cast<double>(sample_rate_));
            next_beat_frame_ += (frames_per_beat > 0 ? frames_per_beat : 1);
        }
    } else {
        // Not playing: make sure we'll re-anchor when we resume.
        has_anchor_ = false;
    }

    frames_rendered_ += num_frames;
    return oboe::DataCallbackResult::Continue;
}

}  // namespace precise_metronome
