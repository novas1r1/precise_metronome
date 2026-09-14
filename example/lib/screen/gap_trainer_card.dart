import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_select.dart';
import '../widgets/accel_surfaces.dart';
import '../widgets/gap_strip.dart';
import 'gap_presets_sheet.dart';

/// The gap trainer: which bars lose the click, what is coming up, and what
/// the trainer is doing right now. Off, the card collapses to its title row
/// and switch.
///
/// Like the dynamic-mode card this binds a whole form, so it takes the
/// [AccelMetronome] itself rather than each value and callback.
class GapTrainerCard extends StatelessWidget {
  const GapTrainerCard({super.key, required this.metronome});

  final AccelMetronome metronome;

  @override
  Widget build(BuildContext context) {
    final m = metronome;
    final on = m.gapEnabled;
    final ladderBars = m.gapLadderBars;
    final random = m.gapMode == GapMode.random;

    return AccelCard(
      title: 'Gap trainer',
      glow: on && m.isPlaying,
      expanded: on,
      // The two trainers take turns, so the switch waits while a ramp
      // plays rather than cutting it short.
      action: AccelSwitch(
        value: on,
        onChanged: m.isPlaying && m.dynamicMode ? null : m.setGapEnabled,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AccelSelect<GapPreset?>(
                  label: 'Preset',
                  value: m.selectedGapPreset,
                  options: [
                    // Settings that match no preset read as their own thing.
                    if (m.selectedGapPreset == null)
                      const AccelSegmentedOption(null, 'Custom'),
                    for (final preset in m.gapPresets)
                      AccelSegmentedOption(preset, preset.name),
                  ],
                  onChanged: (preset) {
                    if (preset != null) m.applyGapPreset(preset);
                  },
                ),
              ),
              const SizedBox(width: 10),
              AccelIconButton(
                icon: Icons.bookmark_add_rounded,
                tooltip: 'Save or manage presets',
                onPressed: () => GapPresetsSheet.show(context, m),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AccelSegmented<GapMode>(
            label: 'Pattern',
            value: m.gapMode,
            options: const [
              AccelSegmentedOption(GapMode.fixed, 'Fixed'),
              AccelSegmentedOption(GapMode.random, 'Random'),
              AccelSegmentedOption(GapMode.ladder, 'Ladder'),
            ],
            onChanged: m.setGapMode,
          ),
          const SizedBox(height: 14),
          _GapParameters(metronome: m),
          const SizedBox(height: 16),
          AccelLabel(
            'Coming up',
            trailing: ladderBars == null
                ? null
                : Text(
                    'gap ${ladderBars == 1 ? '1 bar' : '$ladderBars bars'}',
                    style: AccelType.mono(
                      size: 12,
                      color: AccelColors.textMuted,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          GapStrip(cells: m.gapStrip),
          const SizedBox(height: 12),
          _GapStatus(phase: m.gapPhase, silentBarsLeft: m.silentBarsLeft),
          const SizedBox(height: 16),
          AccelSwitch(
            label: 'Hide the beat in gaps',
            description: 'Leave the dial dark while the click rests',
            value: m.hideBeatWhenSilent,
            onChanged: m.setHideBeatWhenSilent,
          ),
          const SizedBox(height: 14),
          AccelSwitch(
            label: 'Count the silent bars',
            description: random
                ? 'A random pattern gives nothing away'
                : 'Show how many silent bars are left',
            value: m.showRemainingSilentBars && !random,
            onChanged: random ? null : m.setShowRemainingSilentBars,
          ),
        ],
      ),
    );
  }
}

/// The settings of the mode in play.
class _GapParameters extends StatelessWidget {
  const _GapParameters({required this.metronome});

  final AccelMetronome metronome;

  @override
  Widget build(BuildContext context) {
    final m = metronome;
    final clickBars = AccelNumberField(
      label: 'Click bars',
      value: m.gapClickBars.toDouble(),
      min: GapSettings.minBars.toDouble(),
      max: GapSettings.maxBars.toDouble(),
      onChanged: (bars) => m.setGapClickBars(bars.round()),
    );

    return switch (m.gapMode) {
      GapMode.fixed => Row(
        children: [
          Expanded(child: clickBars),
          const SizedBox(width: 10),
          Expanded(
            child: AccelNumberField(
              label: 'Silent bars',
              value: m.gapSilentBars.toDouble(),
              min: GapSettings.minBars.toDouble(),
              max: GapSettings.maxBars.toDouble(),
              onChanged: (bars) => m.setGapSilentBars(bars.round()),
            ),
          ),
        ],
      ),
      GapMode.random => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccelSlider(
            label: 'Chance of silence',
            value: m.gapSilentChance,
            min: GapSettings.minChance,
            max: GapSettings.maxChance,
            readout: '${(m.gapSilentChance * 100).round()}%',
            onChanged: m.setGapSilentChance,
          ),
          const SizedBox(height: 14),
          AccelNumberField(
            label: 'Most silent bars in a row',
            value: m.gapMaxSilentRun.toDouble(),
            min: GapSettings.minRun.toDouble(),
            max: GapSettings.maxRun.toDouble(),
            onChanged: (bars) => m.setGapMaxSilentRun(bars.round()),
          ),
        ],
      ),
      GapMode.ladder => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: clickBars),
              const SizedBox(width: 10),
              Expanded(
                child: AccelNumberField(
                  label: 'First gap',
                  value: m.gapStartSilentBars.toDouble(),
                  min: GapSettings.minBars.toDouble(),
                  max: GapSettings.maxBars.toDouble(),
                  onChanged: (bars) => m.setGapStartSilentBars(bars.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AccelNumberField(
                  label: 'Longest gap',
                  value: m.gapMaxSilentBars.toDouble(),
                  min: m.gapStartSilentBars.toDouble(),
                  max: GapSettings.maxLadderBars.toDouble(),
                  onChanged: (bars) => m.setGapMaxSilentBars(bars.round()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccelNumberField(
                  label: 'Cycles per step',
                  value: m.gapCyclesPerStep.toDouble(),
                  min: GapSettings.minCycles.toDouble(),
                  max: GapSettings.maxCycles.toDouble(),
                  onChanged: (cycles) => m.setGapCyclesPerStep(cycles.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    };
  }
}

/// The line under the strip: what the trainer is doing, read out to screen
/// readers as it changes.
class _GapStatus extends StatelessWidget {
  const _GapStatus({required this.phase, required this.silentBarsLeft});

  final GapPhase? phase;
  final int? silentBarsLeft;

  String get _text => switch (phase) {
    null => 'Ready',
    GapPhase.click => 'Click running',
    GapPhase.silent =>
      silentBarsLeft == null
          ? 'Silent — hold the tempo'
          : 'Silent — ${silentBarsLeft == 1 ? '1 bar' : '$silentBarsLeft bars'} to go',
    GapPhase.landing => 'Landing — were you on it?',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        _text,
        textAlign: TextAlign.center,
        style: AccelType.mono(
          size: 12,
          color: phase == GapPhase.landing
              ? AccelColors.positive
              : AccelColors.textSecondary,
        ),
      ),
    );
  }
}
