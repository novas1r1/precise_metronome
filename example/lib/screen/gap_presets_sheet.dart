import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_surfaces.dart';

/// The gap presets: the ones Accel ships with, the ones you saved, and the
/// field that saves or renames one.
///
/// It lives in its own modal route, outside the screen's rebuild scope, so
/// it listens to the [AccelMetronome] itself.
class GapPresetsSheet extends StatefulWidget {
  const GapPresetsSheet({super.key, required this.metronome});

  final AccelMetronome metronome;

  /// Opens the sheet over [context].
  static Future<void> show(BuildContext context, AccelMetronome metronome) {
    return AccelSheet.show(
      context: context,
      title: 'Gap presets',
      builder: (_) => GapPresetsSheet(metronome: metronome),
    );
  }

  @override
  State<GapPresetsSheet> createState() => _GapPresetsSheetState();
}

class _GapPresetsSheetState extends State<GapPresetsSheet> {
  final TextEditingController _name = TextEditingController();

  /// The preset being renamed, or `null` while the field saves a new one.
  GapPreset? _renaming;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startRename(GapPreset preset) {
    setState(() {
      _renaming = preset;
      _name.text = preset.name;
    });
  }

  Future<void> _commit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final renaming = _renaming;
    if (renaming == null) {
      await widget.metronome.saveGapPreset(name);
    } else {
      await widget.metronome.renameGapPreset(renaming, name);
    }
    if (!mounted) return;
    setState(() {
      _renaming = null;
      _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.metronome,
      builder: (context, _) {
        final m = widget.metronome;
        final selected = m.selectedGapPreset;
        final custom = m.customGapPresets;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccelLabel('Built in'),
            const SizedBox(height: 8),
            for (final preset in builtInGapPresets)
              _PresetRow(
                preset: preset,
                selected: preset == selected,
                onApply: () => _apply(preset),
              ),
            const SizedBox(height: 20),
            AccelLabel(
              'Your presets',
              trailing: Text(
                custom.isEmpty ? 'none yet' : '${custom.length}',
                style: AccelType.mono(size: 12, color: AccelColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            if (custom.isEmpty)
              Text(
                'Save the settings you are on, and they turn up here.',
                style: AccelType.mono(size: 12, color: AccelColors.textMuted),
              ),
            for (final preset in custom)
              _PresetRow(
                preset: preset,
                selected: preset == selected,
                onApply: () => _apply(preset),
                onRename: () => _startRename(preset),
                onDelete: () => m.deleteGapPreset(preset),
              ),
            const SizedBox(height: 20),
            AccelInput(
              label: _renaming == null ? 'Save these settings as' : 'Rename to',
              controller: _name,
              hint: _renaming == null ? 'My warm-up' : null,
              maxLength: 40,
              onSubmitted: (_) => _commit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AccelButton(
                    label: _renaming == null ? 'Save' : 'Rename',
                    onPressed: _commit,
                  ),
                ),
                if (_renaming != null) ...[
                  const SizedBox(width: 10),
                  AccelButton(
                    label: 'Cancel',
                    variant: AccelButtonVariant.secondary,
                    onPressed: () => setState(() {
                      _renaming = null;
                      _name.clear();
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            AccelButton(
              label: 'Done',
              variant: AccelButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _apply(GapPreset preset) async {
    await widget.metronome.applyGapPreset(preset);
    if (mounted) Navigator.of(context).pop();
  }
}

/// One preset: tap it to play it, with rename and delete for your own.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onApply,
    this.onRename,
    this.onDelete,
  });

  final GapPreset preset;
  final bool selected;
  final VoidCallback onApply;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  /// The line under the name: what the preset actually plays.
  String get _summary {
    final settings = preset.settings;
    return switch (settings.mode) {
      GapMode.fixed =>
        '${settings.clickBars} click · ${settings.silentBars} silent',
      GapMode.random =>
        '${(settings.silentChance * 100).round()}% silent · '
            'max ${settings.maxSilentRun} in a row',
      GapMode.ladder =>
        '${settings.clickBars} click · gap '
            '${settings.startSilentBars}–${settings.maxSilentBars}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: preset.name,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onApply,
                child: AnimatedContainer(
                  duration: AccelMotion.fast,
                  curve: AccelMotion.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AccelColors.accentSoft
                        : AccelColors.surfaceInput,
                    borderRadius: AccelRadius.smAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: AccelType.display(
                          size: 15,
                          weight: 500,
                          color: selected
                              ? AccelColors.coral300
                              : AccelColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summary,
                        style: AccelType.mono(
                          size: 12,
                          color: AccelColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onRename != null) ...[
            const SizedBox(width: 6),
            AccelIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'Rename ${preset.name}',
              size: AccelControl.sm,
              ghost: true,
              onPressed: onRename,
            ),
          ],
          if (onDelete != null)
            AccelIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete ${preset.name}',
              size: AccelControl.sm,
              ghost: true,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
