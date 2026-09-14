/// Which bars a gap pattern silences. Mirrors `gap_plan.h` on Android, so
/// both platforms play a pattern the same way. Everything here runs on the
/// engine's serial queue, so no locking is needed.
///
/// Dart decides the bars and sends them in segments, one segment per run of
/// a pattern. A new segment takes effect on the first bar the scheduler
/// starts after the segment arrived, so a pattern change always lands on a
/// bar line that has not been scheduled yet. Within a segment bars count
/// from 0, and Dart keeps sending bars ahead of the one playing. A bar that
/// has not arrived plays audible: a missing plan must never silence the
/// metronome.
struct GapPlan {
    /// Bars of a segment kept at once, counting back from the newest bar
    /// that arrived. Dart sends at most 27 bars ahead of the one playing.
    static let keptBars = 64

    /// How the scheduler plays one bar.
    struct Bar {
        var silent = false
        /// The first audible bar after a silent one.
        var landing = false
        /// Segment that planned the bar; 0 when no pattern is in effect.
        var segment = 0
        /// Bar within that segment, or -1 when the segment had not sent it.
        var index = -1
    }

    private struct Segment {
        var id = 0
        var enabled = false
        /// Bars 0 ..< available have arrived; the newest `keptBars` of them
        /// are kept.
        var available = 0
        /// Indexed by bar % `keptBars`.
        var silent = [Bool](repeating: false, count: GapPlan.keptBars)
    }

    private var newestSegment = 0
    private var active = Segment()
    private var pending = Segment()
    private var activeFirstBar = 0
    private var currentBar = -1
    private var current = Bar()
    private var previousSilent = false

    /// Stores whether bars `from` ..< `from + silent.count` of `segment`
    /// (> 0) are silent. A segment id above every id seen so far starts a
    /// new segment.
    mutating func setBars(segment: Int, from: Int, silent: [Bool]) {
        guard segment > 0, from >= 0 else { return }
        if segment > newestSegment {
            newestSegment = segment
            pending = Segment(id: segment, enabled: true)
        }
        if segment == pending.id {
            GapPlan.store(silent, from: from, in: &pending)
        } else if segment == active.id {
            GapPlan.store(silent, from: from, in: &active)
        }
    }

    /// Starts `segment` (> 0) as "no pattern": from the bar it takes effect
    /// on, nothing is silenced.
    mutating func clear(segment: Int) {
        guard segment > newestSegment else { return }
        newestSegment = segment
        pending = Segment(id: segment)
    }

    /// A play session starts. Forgets the segment in effect and the bar
    /// before it. A segment that arrived but has not taken effect is kept,
    /// so the new session starts with it.
    mutating func reset() {
        active = Segment()
        currentBar = -1
        current = Bar()
        previousSilent = false
    }

    /// How bar `bar` of the session plays. The first call for a bar decides
    /// it, and starts a newly arrived segment there; later calls for the
    /// same bar return the same answer.
    mutating func bar(_ bar: Int) -> Bar {
        if bar == currentBar { return current }
        currentBar = bar
        if pending.id != 0 {
            active = pending
            pending = Segment()
            activeFirstBar = bar
        }
        var next = Bar()
        if active.enabled {
            next.segment = active.id
            let index = bar - activeFirstBar
            if index >= 0, index < active.available,
               index >= active.available - GapPlan.keptBars {
                next.index = index
                next.silent = active.silent[index % GapPlan.keptBars]
            }
        }
        next.landing = !next.silent && previousSilent
        previousSilent = next.silent
        current = next
        return next
    }

    private static func store(_ silent: [Bool], from: Int, in segment: inout Segment) {
        // Bars have to arrive without holes; Dart resends from the first
        // one the engine is missing.
        guard segment.enabled, from <= segment.available else { return }
        for (offset, isSilent) in silent.enumerated() {
            segment.silent[(from + offset) % keptBars] = isSilent
        }
        segment.available = max(segment.available, from + silent.count)
    }
}
