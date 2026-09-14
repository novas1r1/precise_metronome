import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_surfaces.dart';
import 'ramp_plan.dart';

/// The dynamic-mode (tempo ramp) settings. Off, the card collapses to its
/// title row and switch.
///
/// This card binds a dozen settings and their setters, so it takes the
/// [AccelMetronome] itself rather than each value and callback.
class DynamicModeCard extends StatelessWidget {
  const DynamicModeCard({super.key, required this.metronome});

  final AccelMetronome metronome;

  @override
  Widget build(BuildContext context) {
    final m = metronome;
    final on = m.dynamicMode;

    return AccelCard(
      title: 'Dynamic mode',
      glow: on && m.isPlaying,
      expanded: on,
      // The two trainers take turns, so the switch waits while the gap
      // trainer plays rather than cutting it short.
      action: AccelSwitch(
        value: on,
        onChanged: m.isPlaying && m.gapEnabled ? null : m.setDynamicMode,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccelSegmented<StepMode>(
            label: 'Hold each tempo for',
            value: m.stepMode,
            options: const [
              AccelSegmentedOption(StepMode.bars, 'Bars'),
              AccelSegmentedOption(StepMode.time, 'Time'),
            ],
            onChanged: m.setStepMode,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StepLengthField(
                  stepMode: m.stepMode,
                  barsPerStep: m.barsPerStep,
                  stepDuration: m.stepDuration,
                  onBarsChanged: m.setBarsPerStep,
                  onDurationChanged: m.setStepDuration,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccelNumberField(
                  label: 'Increase by BPM',
                  value: m.stepBpm,
                  min: AccelMetronome.minStepBpm,
                  max: AccelMetronome.maxStepBpm,
                  onChanged: m.setStepBpm,
                ),
              ),
            ],
          ),
          if (m.stepMode == StepMode.time) ...[
            const SizedBox(height: 10),
            _StepDurationPresets(
              value: m.stepDuration,
              onChanged: m.setStepDuration,
            ),
          ],
          const SizedBox(height: 14),
          AccelSwitch(
            label: 'Stop at target',
            value: m.useTarget,
            onChanged: m.setUseTarget,
          ),
          if (m.useTarget) ...[
            const SizedBox(height: 14),
            AccelNumberField(
              label: 'Target tempo',
              unit: 'BPM',
              value: m.targetBpm,
              min: AccelMetronome.minBpm,
              max: AccelMetronome.maxBpm,
              step: 5,
              onChanged: m.setTargetBpm,
            ),
          ],
          const SizedBox(height: 14),
          // Ramping back needs a goal to turn around at, so the switch is
          // disabled (and reads off) without a target.
          AccelSwitch(
            label: 'Ramp back down',
            description: 'Step back to the start tempo at the top',
            value: m.returnToStart && m.useTarget,
            onChanged: m.useTarget ? m.setReturnToStart : null,
          ),
          const SizedBox(height: 16),
          RampPlan(ramp: m.buildRamp(), beatsPerBar: m.beatsPerBar),
        ],
      ),
    );
  }
}

/// How long each step is held: a bar count, or a duration, depending on
/// the step mode.
class _StepLengthField extends StatelessWidget {
  const _StepLengthField({
    required this.stepMode,
    required this.barsPerStep,
    required this.stepDuration,
    required this.onBarsChanged,
    required this.onDurationChanged,
  });

  final StepMode stepMode;
  final int barsPerStep;
  final Duration stepDuration;
  final ValueChanged<int> onBarsChanged;
  final ValueChanged<Duration> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    return switch (stepMode) {
      StepMode.bars => AccelNumberField(
        label: 'Bar count',
        value: barsPerStep.toDouble(),
        min: AccelMetronome.minBarsPerStep.toDouble(),
        max: AccelMetronome.maxBarsPerStep.toDouble(),
        onChanged: (bars) => onBarsChanged(bars.round()),
      ),
      StepMode.time => AccelDurationField(
        label: 'Time per step',
        value: stepDuration,
        min: AccelMetronome.minStepDuration,
        max: AccelMetronome.maxStepDuration,
        onChanged: onDurationChanged,
      ),
    };
  }
}

/// Quick picks for the step duration. A typed value that matches none of
/// them leaves all of them unselected.
class _StepDurationPresets extends StatelessWidget {
  const _StepDurationPresets({required this.value, required this.onChanged});

  final Duration value;
  final ValueChanged<Duration> onChanged;

  /// Whole minutes as `1m`, anything else in seconds.
  static String _label(Duration d) =>
      d.inSeconds % 60 == 0 ? '${d.inMinutes}m' : '${d.inSeconds}s';

  @override
  Widget build(BuildContext context) {
    const presets = AccelMetronome.stepDurationPresets;
    return AccelSegmented<Duration?>(
      value: presets.contains(value) ? value : null,
      labelStyle: AccelType.display(size: 13, weight: 600),
      options: [
        for (final preset in presets)
          AccelSegmentedOption(preset, _label(preset)),
      ],
      onChanged: (preset) {
        if (preset != null) onChanged(preset);
      },
    );
  }
}
