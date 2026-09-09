import 'dart:math' as math;

/// Configuration for a progressive tempo ramp ("speed trainer").
///
/// The metronome starts at [startBpm], plays [barsPerStep] bars, then
/// moves [stepBpm] towards [goalBpm]. This repeats until [goalBpm] has been
/// played for [barsPerStep] bars, at which point the metronome stops
/// automatically. If the distance to the goal is not a whole multiple of
/// [stepBpm], the final step is shortened so the goal is hit exactly
/// (e.g. 80 → 120 in steps of 15 plays 80, 95, 110, 120).
///
/// [goalBpm] may be lower than [startBpm]; the ramp then descends.
///
/// With [holdAtGoal] the metronome does not stop once the goal has been
/// played out: it keeps clicking at [goalBpm] until `Metronome.stop()`, so a
/// musician who just reached target tempo can keep playing. The last
/// `RampProgress` is then the one for the goal step
/// (`RampProgress.isLastStep`); no `finished` event follows.
///
/// With [returnToStart] the ramp does not end at [goalBpm]: once the goal
/// has been played for its bars, the tempo steps back down to [startBpm] in
/// the same increments and the ramp ends there (60 → 65 → 70 → 65 → 60 for
/// a 60→70 ramp in steps of 5). The turnaround happens on the native side
/// exactly on the bar line, like every other step — the metronome never
/// stops and restarts in between. [returnToStart] requires a [goalBpm];
/// combined with [holdAtGoal] the metronome holds [startBpm] at the end of
/// the return leg instead of stopping.
///
/// If [goalBpm] is `null` the ramp is open-ended: the tempo keeps rising by
/// [stepBpm] every [barsPerStep] bars until it reaches [maxBpm] (400), where
/// it stays until the user calls `Metronome.stop()`. The metronome never
/// stops itself in that case.
class TempoRamp {
  /// Upper tempo limit of the engine; open-ended ramps level off here.
  static const double maxBpm = 400.0;

  /// Tempo of the first step, in BPM (20..400).
  final double startBpm;

  /// Tempo of the last step, in BPM (20..400), or `null` for an open-ended
  /// ramp that only ends when the metronome is stopped.
  final double? goalBpm;

  /// Tempo change between consecutive steps, in BPM. Must be > 0.
  final double stepBpm;

  /// How many bars each step is held before advancing. Must be >= 1.
  final int barsPerStep;

  /// Keep clicking at the ramp's final tempo after it is done instead of
  /// stopping. Has no effect on open-ended ramps, which never stop by
  /// themselves.
  final bool holdAtGoal;

  /// Step back down from [goalBpm] to [startBpm] after the goal has been
  /// played out, as one uninterrupted ramp. Requires a [goalBpm].
  final bool returnToStart;

  TempoRamp({
    required this.startBpm,
    this.goalBpm,
    required this.stepBpm,
    required this.barsPerStep,
    this.holdAtGoal = false,
    this.returnToStart = false,
  }) {
    _checkBpm(startBpm, 'startBpm');
    if (goalBpm != null) _checkBpm(goalBpm!, 'goalBpm');
    if (!(stepBpm > 0) || !stepBpm.isFinite) {
      throw ArgumentError.value(stepBpm, 'stepBpm', 'must be > 0');
    }
    if (barsPerStep < 1) {
      throw ArgumentError.value(barsPerStep, 'barsPerStep', 'must be >= 1');
    }
    if (returnToStart && goalBpm == null) {
      throw ArgumentError.value(
        returnToStart,
        'returnToStart',
        'requires a goalBpm — an open-ended ramp has nothing to return from',
      );
    }
  }

  static void _checkBpm(double bpm, String name) {
    if (bpm.isNaN || bpm < 20.0 || bpm > maxBpm) {
      throw ArgumentError.value(bpm, name, 'must be 20..400');
    }
  }

  /// `true` when the ramp has no [goalBpm] and runs until stopped.
  bool get isOpenEnded => goalBpm == null;

  /// `true` when the metronome stops itself after the goal has been played
  /// out: a ramp with a goal and without [holdAtGoal].
  bool get stopsAtGoal => !isOpenEnded && !holdAtGoal;

  /// The tempo the ramp levels off at: [goalBpm], or [maxBpm] when
  /// open-ended.
  double get _limitBpm => goalBpm ?? maxBpm;

  /// `true` if the ramp goes from a slower to a faster tempo. Open-ended
  /// ramps always ascend.
  bool get ascending => _limitBpm >= startBpm;

  /// Number of steps in one leg: from [startBpm] up to (or down to) the
  /// limit tempo, including both ends.
  int get _legSteps => 1 + ((_limitBpm - startBpm).abs() / stepBpm).ceil();

  /// Number of tempo steps the ramp plays, including start and goal.
  /// `startBpm == goalBpm` counts as a single step. With [returnToStart]
  /// the return leg is counted too; the goal step is shared between the
  /// two legs and therefore counted once. For open-ended ramps this is the
  /// number of steps until [maxBpm] is reached — the tempo then holds
  /// there, so it is not a "total" in the sense of an end.
  int get totalSteps => returnToStart ? 2 * _legSteps - 1 : _legSteps;

  /// Tempo played at [stepIndex] (0-based), counting straight through both
  /// legs of a [returnToStart] ramp. Indices beyond [totalSteps] are
  /// clamped to the final tempo — [goalBpm] (or [maxBpm] when open-ended),
  /// or [startBpm] on a return leg.
  double bpmAt(int stepIndex) {
    if (stepIndex < 0) {
      throw RangeError.range(stepIndex, 0, null, 'stepIndex');
    }
    if (returnToStart && stepIndex >= _legSteps) {
      // Return leg: step away from the limit, back towards startBpm.
      final back = stepIndex - (_legSteps - 1);
      final raw = ascending
          ? _limitBpm - stepBpm * back
          : _limitBpm + stepBpm * back;
      return ascending ? math.max(raw, startBpm) : math.min(raw, startBpm);
    }
    final raw = ascending
        ? startBpm + stepBpm * stepIndex
        : startBpm - stepBpm * stepIndex;
    return ascending ? math.min(raw, _limitBpm) : math.max(raw, _limitBpm);
  }

  /// Every tempo in playing order, both legs included.
  List<double> get steps =>
      List<double>.generate(totalSteps, bpmAt, growable: false);

  Map<String, Object> toMap() => {
    'startBpm': startBpm,
    'goalBpm': _limitBpm,
    'stopAtGoal': stopsAtGoal,
    'stepBpm': stepBpm,
    'barsPerStep': barsPerStep,
    'returnToStart': returnToStart,
  };

  @override
  String toString() =>
      'TempoRamp($startBpm → ${goalBpm ?? '∞'}'
      '${returnToStart ? ' → $startBpm' : ''}, step $stepBpm, '
      '$barsPerStep bars/step${holdAtGoal ? ', hold at goal' : ''})';
}

/// Snapshot of a running [TempoRamp], delivered through
/// `Metronome.rampProgress` every time the tempo steps and once more when
/// the ramp has finished.
class RampProgress {
  /// 0-based index of the step now playing (or, if [finished], the last
  /// step that was played).
  final int stepIndex;

  /// Number of steps until the goal — see [TempoRamp.totalSteps]. `null`
  /// for open-ended ramps.
  final int? totalSteps;

  /// Tempo of the current step, in BPM.
  final double bpm;

  /// `true` once the goal tempo has been played for its full number of
  /// bars and the metronome has stopped itself. Never `true` for
  /// open-ended ramps or ramps with `TempoRamp.holdAtGoal`.
  final bool finished;

  const RampProgress({
    required this.stepIndex,
    required this.totalSteps,
    required this.bpm,
    required this.finished,
  });

  /// `true` while the goal step is playing (`stepIndex` is the last of
  /// [totalSteps]). For a ramp with `TempoRamp.holdAtGoal` this is the
  /// terminal state — no `finished` event follows. Always `false` for
  /// open-ended ramps.
  bool get isLastStep => totalSteps != null && stepIndex + 1 == totalSteps;

  @override
  String toString() =>
      'RampProgress(step ${stepIndex + 1}${totalSteps == null ? '' : '/$totalSteps'}, '
      '$bpm BPM${finished ? ', finished' : ''})';
}
