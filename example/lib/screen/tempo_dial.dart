import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';
import '../formatting.dart';
import '../widgets/beat_ring.dart';

/// The dial: the beat ring around the live tempo, with the position within
/// the current ramp step underneath the number while a ramp runs.
class TempoDial extends StatelessWidget {
  const TempoDial({
    super.key,
    required this.tempo,
    required this.beatTick,
    required this.beatIndex,
    required this.beatsPerBar,
    required this.accent,
    required this.direction,
    required this.running,
    required this.barsPerStep,
    this.barInStep,
    this.stepTimeLeft,
  });

  final double tempo;
  final int beatTick;
  final int? beatIndex;
  final int beatsPerBar;
  final bool accent;
  final TempoDirection direction;
  final bool running;
  final int barsPerStep;

  /// Bar within the current ramp step, 0-based, while steps count bars.
  final int? barInStep;

  /// Time left in the current ramp step, while steps are timed.
  final Duration? stepTimeLeft;

  static const double _size = 250;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: BeatRing(
          beatTick: beatTick,
          beatIndex: beatIndex,
          beatsPerBar: beatsPerBar,
          accent: accent,
          direction: direction,
          running: running,
          size: _size,
          child: _DialReadout(
            tempo: tempo,
            barsPerStep: barsPerStep,
            barInStep: barInStep,
            stepTimeLeft: stepTimeLeft,
          ),
        ),
      ),
    );
  }
}

/// The number in the middle of the dial, its unit, and the step caption.
class _DialReadout extends StatelessWidget {
  const _DialReadout({
    required this.tempo,
    required this.barsPerStep,
    required this.barInStep,
    required this.stepTimeLeft,
  });

  final double tempo;
  final int barsPerStep;
  final int? barInStep;
  final Duration? stepTimeLeft;

  /// Where the ramp is within its current step, or `null` outside a ramp.
  String? get _stepCaption {
    if (barInStep case final bar?) return 'bar ${bar + 1} / $barsPerStep';
    if (stepTimeLeft case final left?) {
      // Once the time is up the step ends on the next bar line.
      return left == Duration.zero ? 'next bar' : '${formatClock(left)} left';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final caption = _stepCaption;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TempoReadout(tempo: tempo),
        const SizedBox(height: 2),
        Text(
          'BPM',
          style: AccelType.mono(
            size: 11,
            letterSpacing: 0.14 * 11,
            color: AccelColors.textMuted,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption, style: AccelType.mono(size: 12)),
        ],
      ],
    );
  }
}

/// The tempo figure. It counts in with a spring whenever the value steps:
/// keying on the tempo restarts the animation for each new value.
class _TempoReadout extends StatelessWidget {
  const _TempoReadout({required this.tempo});

  final double tempo;

  static const double _fontSize = 96;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(tempo),
      tween: Tween(begin: 0, end: 1),
      duration: AccelMotion.slow,
      curve: AccelMotion.spring,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Text(
        formatBpm(tempo),
        style: AccelType.display(
          size: _fontSize,
          weight: 800,
          height: 0.9,
          letterSpacing: -0.04 * _fontSize,
          tabularFigures: true,
        ),
      ),
    );
  }
}
