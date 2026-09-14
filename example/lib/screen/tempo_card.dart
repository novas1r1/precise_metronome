import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_surfaces.dart';

/// The metronome's tempo in its own card, above the dynamic-mode box. It is
/// the tempo the metronome plays at and the tempo a ramp starts from, so it
/// stays visible whether dynamic mode is on or off.
class TempoCard extends StatelessWidget {
  const TempoCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// "Tempo", or "Start tempo" while dynamic mode is on.
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return AccelCard(
      padding: const EdgeInsets.all(16),
      child: AccelNumberField(
        label: label,
        unit: 'BPM',
        value: value,
        min: AccelMetronome.minBpm,
        max: AccelMetronome.maxBpm,
        large: true,
        onChanged: onChanged,
      ),
    );
  }
}
