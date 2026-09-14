#include "gap_plan.h"

#include <algorithm>
#include <cstddef>

namespace precise_metronome {

bool GapPlan::set_bars(int32_t segment, int32_t from, const uint8_t* silent,
                       int32_t count) {
    if (segment <= 0 || from < 0 || count < 0) return false;
    // A segment with no bars yet still needs one command to start it.
    const uint32_t commands =
        count == 0 ? 1
                   : static_cast<uint32_t>((count + kBarsPerCommand - 1) /
                                           kBarsPerCommand);
    const uint32_t write = command_write_.load(std::memory_order_relaxed);
    const uint32_t read = command_read_.load(std::memory_order_acquire);
    if (kCommandRingSize - (write - read) < commands) return false;

    for (uint32_t c = 0; c < commands; ++c) {
        const int32_t first = static_cast<int32_t>(c) * kBarsPerCommand;
        Command& command = commands_[(write + c) % kCommandRingSize];
        command.segment = segment;
        command.from = from + first;
        command.count = std::min(count - first, kBarsPerCommand);
        command.silent = 0;
        for (int32_t i = 0; i < command.count; ++i) {
            if (silent[first + i] != 0) command.silent |= uint64_t{1} << i;
        }
    }
    command_write_.store(write + commands, std::memory_order_release);
    return true;
}

void GapPlan::clear(int32_t segment) {
    if (segment <= 0) return;
    cleared_segment_.store(segment, std::memory_order_release);
}

void GapPlan::request_restart() {
    restart_requested_.store(true, std::memory_order_release);
}

void GapPlan::apply_commands() {
    if (restart_requested_.exchange(false, std::memory_order_acq_rel)) {
        active_ = Segment{};
    }
    // Segment ids only grow, so a clear() is newer than every command
    // pushed before it and older than every command pushed after it.
    // Taking it in before the ring keeps that order: older commands still
    // in the ring are then ignored, newer ones still start their segment.
    const int32_t cleared = cleared_segment_.load(std::memory_order_acquire);
    if (cleared > newest_segment_) {
        newest_segment_ = cleared;
        pending_ = Segment{};
        pending_.id = cleared;
    }
    const uint32_t write = command_write_.load(std::memory_order_acquire);
    uint32_t read = command_read_.load(std::memory_order_relaxed);
    for (; read != write; ++read) {
        apply(commands_[read % kCommandRingSize]);
    }
    command_read_.store(read, std::memory_order_release);
}

void GapPlan::apply(const Command& command) {
    Segment* segment = nullptr;
    if (command.segment > newest_segment_) {
        newest_segment_ = command.segment;
        pending_ = Segment{};
        pending_.id = command.segment;
        pending_.enabled = true;
        segment = &pending_;
    } else if (command.segment == pending_.id) {
        segment = &pending_;
    } else if (command.segment == active_.id) {
        segment = &active_;
    }
    // Bars have to arrive without holes; Dart resends from the first one
    // the engine is missing.
    if (segment == nullptr || !segment->enabled ||
        command.from > segment->available) {
        return;
    }
    for (int32_t i = 0; i < command.count; ++i) {
        const auto slot =
            static_cast<std::size_t>((command.from + i) % kKeptBars);
        segment->silent[slot] = ((command.silent >> i) & 1u) != 0;
    }
    segment->available =
        std::max(segment->available, command.from + command.count);
}

void GapPlan::reset() {
    active_ = Segment{};
    current_bar_ = -1;
    current_ = Bar{};
    previous_silent_ = false;
}

const GapPlan::Bar& GapPlan::at(int32_t bar) {
    if (bar == current_bar_) return current_;
    current_bar_ = bar;
    if (pending_.id != 0) {
        active_ = pending_;
        pending_ = Segment{};
        active_first_bar_ = bar;
    }
    Bar next;
    if (active_.enabled) {
        next.segment = active_.id;
        const int32_t index = bar - active_first_bar_;
        if (index >= 0 && index < active_.available &&
            index >= active_.available - kKeptBars) {
            next.index = index;
            next.silent =
                active_.silent[static_cast<std::size_t>(index % kKeptBars)];
        }
    }
    next.landing = !next.silent && previous_silent_;
    previous_silent_ = next.silent;
    current_ = next;
    return current_;
}

}  // namespace precise_metronome
