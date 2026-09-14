#pragma once

#include <array>
#include <atomic>
#include <cstdint>

namespace precise_metronome {

// Which bars a gap pattern silences, handed from the Flutter thread to the
// audio thread without locks. Mirrored by GapPlan.swift on iOS.
//
// Dart decides the bars and sends them in segments, one segment per run of
// a pattern. A new segment takes effect on the first bar the audio thread
// starts after the segment arrived, so a pattern change always lands on a
// bar line that has not been scheduled yet, however late it comes in.
// Within a segment bars count from 0, and Dart keeps sending bars ahead of
// the one playing. A bar that has not arrived plays audible: a missing plan
// must never silence the metronome.
//
// The Flutter thread only writes commands into a single-producer,
// single-consumer ring, plus an atomic for clear(). The segments themselves
// belong to the audio thread.
class GapPlan {
 public:
    // Bars of a segment kept at once, counting back from the newest bar that
    // arrived. Dart sends at most 27 bars ahead of the one playing.
    static constexpr int32_t kKeptBars = 64;

    // How the audio thread plays one bar.
    struct Bar {
        bool silent = false;
        // The first audible bar after a silent one.
        bool landing = false;
        // Segment that planned the bar; 0 when no pattern is in effect.
        int32_t segment = 0;
        // Bar within that segment, or -1 when the segment had not sent it.
        int32_t index = -1;
    };

    // Flutter thread. Stores whether bars `from` .. `from + count - 1` of
    // `segment` (> 0) are silent; `silent` holds one byte per bar, nonzero
    // for silent. A segment id above every id seen so far starts a new
    // segment. Returns false, storing nothing, when the command ring is
    // full because the audio thread has not caught up.
    bool set_bars(int32_t segment, int32_t from, const uint8_t* silent,
                  int32_t count);

    // Flutter thread. Starts `segment` (> 0) as "no pattern": from the bar
    // it takes effect on, nothing is silenced. Never fails.
    void clear(int32_t segment);

    // Any thread. Drops the segment in effect before the next bar, so every
    // bar plays audible until Dart notices and sends a new segment.
    void request_restart();

    // Audio thread, once per callback: takes in what the other threads sent.
    void apply_commands();

    // Audio thread, when a play session starts. Forgets the segment in
    // effect and the bar before it. A segment that arrived but has not
    // taken effect is kept, so the new session starts with it.
    void reset();

    // Audio thread. How bar `bar` of the session plays. The first call for
    // a bar decides it, and starts a newly arrived segment there; later
    // calls for the same bar return the same answer.
    const Bar& at(int32_t bar);

 private:
    static constexpr uint32_t kCommandRingSize = 32;
    static constexpr int32_t kBarsPerCommand = 64;

    struct Command {
        int32_t segment;
        int32_t from;
        int32_t count;    // 0 .. kBarsPerCommand
        uint64_t silent;  // bit i: bar from + i is silent
    };

    struct Segment {
        int32_t id = 0;  // 0: none
        bool enabled = false;
        // Bars 0 .. available - 1 have arrived; the newest kKeptBars of
        // them are kept.
        int32_t available = 0;
        std::array<bool, kKeptBars> silent{};  // indexed by bar % kKeptBars
    };

    void apply(const Command& command);

    // Written by the Flutter thread (restart_requested_ by any thread).
    std::array<Command, kCommandRingSize> commands_{};
    std::atomic<uint32_t> command_write_{0};
    std::atomic<int32_t> cleared_segment_{0};
    std::atomic<bool> restart_requested_{false};
    // Written by the audio thread.
    std::atomic<uint32_t> command_read_{0};

    // Audio thread only.
    int32_t newest_segment_ = 0;
    Segment active_;
    Segment pending_;
    int32_t active_first_bar_ = 0;
    int32_t current_bar_ = -1;
    Bar current_;
    bool previous_silent_ = false;
};

}  // namespace precise_metronome
