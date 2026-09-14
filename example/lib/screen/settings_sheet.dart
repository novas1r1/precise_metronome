import 'package:flutter/material.dart';
import 'package:precise_metronome/precise_metronome.dart';

import '../accel_metronome.dart';
import '../widgets/accel_controls.dart';
import '../widgets/accel_surfaces.dart';

/// The settings sheet: volume and the click sound.
///
/// It lives in its own modal route, outside the screen's rebuild scope, so
/// it listens to the [AccelMetronome] itself.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.metronome});

  final AccelMetronome metronome;

  /// Opens the sheet over [context].
  static Future<void> show(BuildContext context, AccelMetronome metronome) {
    return AccelSheet.show(
      context: context,
      title: 'Settings',
      builder: (_) => SettingsSheet(metronome: metronome),
    );
  }

  /// The built-in voices, in the order they were added to the package.
  /// Descriptions are one line each — enough to pick without auditioning.
  static const List<AccelChoice<MetronomeVoice>> _voices = [
    AccelChoice(
      MetronomeVoice.tone,
      'Tone',
      description: 'A pitched electronic burst. Carries over a loud room.',
    ),
    AccelChoice(
      MetronomeVoice.click,
      'Click',
      description: 'A sharp rim click. Cuts through busy practice audio.',
    ),
    AccelChoice(
      MetronomeVoice.wood,
      'Wood',
      description: 'A warm, hollow wooden bar. Rounder and darker.',
    ),
    AccelChoice(
      MetronomeVoice.mechanical,
      'Mechanical',
      description: 'A pendulum tick, with a bell on the accent.',
    ),
    AccelChoice(
      MetronomeVoice.blip,
      'Blip',
      description: 'A soft marimba blip. The least tiring over long sessions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: metronome,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccelSlider(
            label: 'Volume',
            value: metronome.volume,
            readout: '${(metronome.volume * 100).round()}%',
            onChanged: metronome.setVolume,
          ),
          const SizedBox(height: 20),
          AccelChoiceList<MetronomeVoice>(
            label: 'Sound',
            value: metronome.voice,
            choices: _voices,
            onChanged: metronome.setVoice,
          ),
          const SizedBox(height: 24),
          AccelButton(
            label: 'Done',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
