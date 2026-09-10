import 'package:flutter/material.dart';
import 'package:precise_metronome/precise_metronome.dart';

import '../design/accel_tokens.dart';
import '../formatting.dart';

/// One muted line summarising the ramp the current settings describe: the
/// tempi it will play, and how many steps, bars and minutes that adds up
/// to.
class RampPlan extends StatelessWidget {
  const RampPlan({super.key, required this.ramp, required this.beatsPerBar});

  final TempoRamp ramp;
  final int beatsPerBar;

  @override
  Widget build(BuildContext context) {
    return Text(
      describeRampPlan(ramp, beatsPerBar: beatsPerBar),
      style: AccelType.mono(size: 12, color: AccelColors.textMuted),
    );
  }
}

/// The text of a [RampPlan], straight from [TempoRamp.steps].
///
/// Long plans are elided in the middle so the shape stays readable; on a
/// round trip the elision keeps the turnaround tempo visible.
String describeRampPlan(TempoRamp ramp, {required int beatsPerBar}) {
  if (ramp.isOpenEnded) {
    final head = [ramp.startBpm, ramp.bpmAt(1), ramp.bpmAt(2)];
    return '${head.map(formatBpm).join(' → ')} → …  ·  open ended';
  }

  final steps = ramp.steps;
  final bars = ramp.totalBars(beatsPerBar: beatsPerBar)!;
  final length = ramp.totalDuration(beatsPerBar: beatsPerBar)!;
  return '${_elide(steps, roundTrip: ramp.returnToStart)}  ·  '
      '${ramp.totalSteps} steps  ·  $bars bars  ·  ~${formatClock(length)}';
}

/// Up to six tempi in full; beyond that the first two, the last one, and on
/// a round trip the goal in the middle.
String _elide(List<double> steps, {required bool roundTrip}) {
  if (steps.length <= 6) return steps.map(formatBpm).join(' → ');
  final head = '${formatBpm(steps.first)} → ${formatBpm(steps[1])}';
  final tail = formatBpm(steps.last);
  if (!roundTrip) return '$head → … → $tail';
  final goal = formatBpm(steps[(steps.length - 1) ~/ 2]);
  return '$head → … → $goal → … → $tail';
}
