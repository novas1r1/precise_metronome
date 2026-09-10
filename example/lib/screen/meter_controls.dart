import 'package:flutter/material.dart';
import 'package:precise_metronome/precise_metronome.dart';

import '../design/accel_tokens.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_select.dart';
import '../widgets/accent_grid.dart';

/// The meter: time signature and subdivision side by side, with the accent
/// grid for the resulting pulses underneath.
class MeterControls extends StatelessWidget {
  const MeterControls({
    super.key,
    required this.signature,
    required this.subdivision,
    required this.accents,
    required this.beatsPerBar,
    required this.pulsesPerBeat,
    required this.currentSlot,
    required this.onSignatureChanged,
    required this.onSubdivisionChanged,
    required this.onAccentChanged,
  });

  final TimeSignature signature;
  final Subdivision subdivision;

  /// One flag per audible pulse, indexed `beat * pulsesPerBeat + pulse`.
  final List<bool> accents;
  final int beatsPerBar;
  final int pulsesPerBeat;

  /// The accent-grid cell currently sounding, or `null` when stopped.
  final int? currentSlot;
  final ValueChanged<TimeSignature> onSignatureChanged;
  final ValueChanged<Subdivision> onSubdivisionChanged;
  final void Function(int slot, bool accented) onAccentChanged;

  /// The time signatures on offer, in the dropdown's order.
  static final List<AccelSegmentedOption<TimeSignature>> _signatures = [
    for (final (numerator, denominator) in const [
      (2, 4),
      (3, 4),
      (4, 4),
      (5, 4),
      (6, 8),
      (7, 8),
      (12, 8),
    ])
      AccelSegmentedOption(
        TimeSignature(numerator, denominator),
        '$numerator/$denominator',
      ),
  ];

  static const List<AccelSegmentedOption<Subdivision>> _subdivisions = [
    AccelSegmentedOption(Subdivision.none, '♩'),
    AccelSegmentedOption(Subdivision.duple, '♪♪'),
    AccelSegmentedOption(Subdivision.triplet, '♪³'),
    AccelSegmentedOption(Subdivision.quadruple, '♬♬'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AccelSelect<TimeSignature>(
                label: 'Time signature',
                value: signature,
                valueStyle: AccelType.display(
                  size: 24,
                  weight: 600,
                  tabularFigures: true,
                ),
                options: _signatures,
                onChanged: onSignatureChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccelSegmented<Subdivision>(
                label: 'Subdivision',
                value: subdivision,
                labelStyle: AccelType.display(size: 15, weight: 600),
                options: _subdivisions,
                onChanged: onSubdivisionChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AccentGrid(
          accents: accents,
          beatsPerBar: beatsPerBar,
          pulsesPerBeat: pulsesPerBeat,
          currentSlot: currentSlot,
          onChanged: onAccentChanged,
        ),
      ],
    );
  }
}
