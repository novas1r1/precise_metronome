import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';
import 'accel_controls.dart';

/// One toggle per audible pulse of the bar, so accents can sit on main
/// beats *and* on subdivision pulses. Accented cells are coral with a glow;
/// the pulse currently sounding shrinks slightly.
///
/// Cells are grouped by beat — a wider gap between beats than within one —
/// so a bar of 7/8 in sixteenths stays readable instead of turning into an
/// undifferentiated row of 28 slots.
class AccentGrid extends StatelessWidget {
  const AccentGrid({
    super.key,
    required this.accents,
    required this.beatsPerBar,
    required this.pulsesPerBeat,
    required this.currentSlot,
    required this.onChanged,
  });

  /// One flag per pulse, indexed `beat * pulsesPerBeat + pulse`.
  final List<bool> accents;
  final int beatsPerBar;
  final int pulsesPerBeat;
  final int? currentSlot;
  final void Function(int slot, bool accented) onChanged;

  @override
  Widget build(BuildContext context) {
    final count = accents.where((a) => a).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccelLabel(
          'Accents',
          trailing: Text(
            count == 0 ? 'none' : '$count',
            style: AccelType.mono(size: 12, color: AccelColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AccelColors.surfaceInput,
            borderRadius: AccelRadius.mdAll,
            border: Border.all(color: AccelColors.surfaceGlassBorder),
          ),
          child: Row(
            children: [
              for (var beat = 0; beat < beatsPerBar; beat++) ...[
                if (beat > 0) const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      for (var pulse = 0; pulse < pulsesPerBeat; pulse++) ...[
                        if (pulse > 0) const SizedBox(width: 3),
                        Expanded(
                          child: _AccentCell(
                            key: ValueKey('accent-slot-${beat * pulsesPerBeat + pulse}'),
                            slot: beat * pulsesPerBeat + pulse,
                            accents: accents,
                            onChanged: onChanged,
                            currentSlot: currentSlot,
                            mainBeat: pulse == 0,
                            beat: beat,
                            pulse: pulse,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentCell extends StatelessWidget {
  const _AccentCell({
    super.key,
    required this.slot,
    required this.accents,
    required this.onChanged,
    required this.currentSlot,
    required this.mainBeat,
    required this.beat,
    required this.pulse,
  });

  final int slot;
  final List<bool> accents;
  final void Function(int slot, bool accented) onChanged;
  final int? currentSlot;
  final bool mainBeat;
  final int beat;
  final int pulse;

  @override
  Widget build(BuildContext context) {
    // The grid can render a frame ahead of the pattern it describes when the
    // meter changes; treat a missing slot as unaccented.
    final accented = slot < accents.length && accents[slot];
    final live = currentSlot == slot;
    final dotColor = accented
        ? AccelColors.navy950
        : live
        ? AccelColors.textPrimary
        : AccelColors.ink400;
    final dotSize = accented
        ? (mainBeat ? 8.0 : 6.0)
        : (mainBeat ? 6.0 : 4.0);

    return Semantics(
      button: true,
      toggled: accented,
      label: mainBeat ? 'Beat ${beat + 1}' : 'Beat ${beat + 1}, pulse ${pulse + 1}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(slot, !accented),
        child: AnimatedScale(
          scale: live ? 0.9 : 1,
          duration: AccelMotion.fast,
          curve: AccelMotion.easeOut,
          child: AnimatedContainer(
            duration: AccelMotion.fast,
            curve: AccelMotion.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color: accented
                  ? AccelColors.accent
                  : mainBeat
                  ? AccelColors.surfaceGlassStrong
                  : AccelColors.surfaceGlass,
              borderRadius: AccelRadius.smAll,
              boxShadow: accented
                  ? [
                      const BoxShadow(
                        color: AccelColors.accentGlow,
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: AccelMotion.fast,
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
