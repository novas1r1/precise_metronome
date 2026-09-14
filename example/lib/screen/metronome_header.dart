import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';
import '../formatting.dart';
import '../widgets/accel_controls.dart';
import 'layout.dart';

/// The app title, the badge of whichever trainer is on, and the settings
/// button.
class MetronomeHeader extends StatelessWidget {
  const MetronomeHeader({
    super.key,
    required this.dynamicMode,
    required this.running,
    required this.descending,
    required this.stepBpm,
    required this.nextTempo,
    required this.gapTrainer,
    required this.gapPhase,
    required this.silentBarsLeft,
    required this.onOpenSettings,
  });

  final bool dynamicMode;
  final bool running;
  final bool descending;
  final double stepBpm;

  /// The tempo the ramp moves to next, or `null` when there is none.
  final double? nextTempo;

  /// Whether the gap trainer is on. It and dynamic mode take turns, so at
  /// most one badge shows.
  final bool gapTrainer;

  /// What the gap trainer is doing, and how many silent bars are left.
  final GapPhase? gapPhase;
  final int? silentBarsLeft;

  /// `null` disables the settings button, e.g. before the engine is ready.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ScreenLayout.gutter,
        12,
        ScreenLayout.gutter,
        0,
      ),
      child: Row(
        children: [
          Text(
            'Accel',
            style: AccelType.display(
              size: 22,
              weight: 800,
              letterSpacing: -0.05 * 22,
            ),
          ),
          const Spacer(),
          if (dynamicMode) ...[
            _RampBadge(
              running: running,
              descending: descending,
              stepBpm: stepBpm,
              nextTempo: nextTempo,
            ),
            const SizedBox(width: 8),
          ] else if (gapTrainer) ...[
            _GapBadge(phase: gapPhase, silentBarsLeft: silentBarsLeft),
            const SizedBox(width: 8),
          ],
          AccelIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            ghost: true,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

/// Reads "dynamic" while idle, and the step being taken — `+5 → 70` —
/// while the ramp runs.
class _RampBadge extends StatelessWidget {
  const _RampBadge({
    required this.running,
    required this.descending,
    required this.stepBpm,
    required this.nextTempo,
  });

  final bool running;
  final bool descending;
  final double stepBpm;
  final double? nextTempo;

  @override
  Widget build(BuildContext context) {
    final next = nextTempo;
    final label = running && next != null
        ? '${descending ? '−' : '+'}${formatBpm(stepBpm)} → ${formatBpm(next)}'
        : 'dynamic';
    return AccelBadge(
      label: label,
      tone: descending ? AccelBadgeTone.info : AccelBadgeTone.accent,
      dot: running,
    );
  }
}

/// Reads "gap" while idle, and what the trainer is doing — `silent · 2` —
/// while it plays.
class _GapBadge extends StatelessWidget {
  const _GapBadge({required this.phase, required this.silentBarsLeft});

  final GapPhase? phase;
  final int? silentBarsLeft;

  @override
  Widget build(BuildContext context) {
    final left = silentBarsLeft;
    final label = switch (phase) {
      null => 'gap',
      GapPhase.click => 'click',
      GapPhase.silent => left == null ? 'silent' : 'silent · $left',
      GapPhase.landing => 'landing',
    };
    final tone = switch (phase) {
      GapPhase.silent => AccelBadgeTone.info,
      GapPhase.landing => AccelBadgeTone.positive,
      _ => AccelBadgeTone.accent,
    };
    return AccelBadge(label: label, tone: tone, dot: phase != null);
  }
}
