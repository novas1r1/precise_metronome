import 'dart:async';

import 'package:flutter/material.dart';

import 'accel_metronome.dart';
import 'screen/backdrop.dart';
import 'screen/dynamic_mode_card.dart';
import 'screen/engine_error_view.dart';
import 'screen/layout.dart';
import 'screen/meter_controls.dart';
import 'screen/metronome_header.dart';
import 'screen/settings_sheet.dart';
import 'screen/step_progress_bar.dart';
import 'screen/tempo_card.dart';
import 'screen/tempo_dial.dart';
import 'screen/transport_bar.dart';
import 'widgets/accel_surfaces.dart';

/// The Accel metronome screen: header, dial, meter controls, tempo and
/// dynamic-mode cards, and a transport bar pinned to the bottom.
///
/// This widget owns the [AccelMetronome]; [_MetronomeView] lays the screen
/// out from it and rebuilds on every notification. The sections in
/// `screen/` are plain widgets that take the values and callbacks they
/// show — except the dynamic-mode card and the settings sheet, which bind
/// whole forms and take the model itself.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final AccelMetronome _metronome = AccelMetronome();

  @override
  void initState() {
    super.initState();
    // The model reports readiness (or an error) through its notifications.
    unawaited(_metronome.init());
  }

  @override
  void dispose() {
    _metronome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _metronome,
      builder: (context, _) => _MetronomeView(metronome: _metronome),
    );
  }
}

/// The screen's layout for one snapshot of the model.
class _MetronomeView extends StatelessWidget {
  const _MetronomeView({required this.metronome});

  final AccelMetronome metronome;

  /// How far the backdrop glow bleeds past the top edge, so it sits
  /// behind the dial rather than the header.
  static const double _backdropOverhang = 120;

  /// Space between the safe area and the notice, clearing the header.
  static const double _noticeOffset = 68;

  @override
  Widget build(BuildContext context) {
    final m = metronome;
    final descending = m.direction == TempoDirection.down;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -_backdropOverhang,
            left: 0,
            right: 0,
            child: Backdrop(running: m.isPlaying, descending: descending),
          ),
          SafeArea(
            bottom: false,
            child: ContentWidth(
              child: Column(
                children: [
                  MetronomeHeader(
                    dynamicMode: m.dynamicMode,
                    running: m.isPlaying,
                    descending: descending,
                    stepBpm: m.stepBpm,
                    nextTempo: m.nextTempo,
                    onOpenSettings: m.isReady
                        ? () => SettingsSheet.show(context, m)
                        : null,
                  ),
                  Expanded(
                    child: switch (m.initError) {
                      null => _Sections(metronome: m, descending: descending),
                      final error => EngineErrorView(error: error),
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TransportBar(
              playing: m.isPlaying,
              enabled: m.isReady,
              onToggle: m.toggle,
              onReset: m.stop,
            ),
          ),
          if (m.notice case final notice?)
            Positioned(
              top: MediaQuery.paddingOf(context).top + _noticeOffset,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: AccelToast(message: notice),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The scrolling column of sections between the header and the transport
/// bar.
class _Sections extends StatelessWidget {
  const _Sections({required this.metronome, required this.descending});

  final AccelMetronome metronome;
  final bool descending;

  /// Bottom padding that keeps the last card clear of the transport bar.
  static const double _transportClearance = 164;

  @override
  Widget build(BuildContext context) {
    final m = metronome;
    final beat = m.lastBeat;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ScreenLayout.gutter,
        16,
        ScreenLayout.gutter,
        _transportClearance,
      ),
      children: [
        TempoDial(
          tempo: m.tempo,
          beatTick: m.beatTick,
          beatIndex: beat?.beatIndex,
          beatsPerBar: m.beatsPerBar,
          accent: beat?.accent ?? false,
          direction: m.direction,
          running: m.isPlaying,
          barsPerStep: m.barsPerStep,
          barInStep: m.barInStep,
          stepTimeLeft: m.stepTimeLeft,
        ),
        if (m.dynamicMode) ...[
          const SizedBox(height: 8),
          StepProgressBar(progress: m.stepProgress, descending: descending),
        ],
        const SizedBox(height: 16),
        MeterControls(
          signature: m.signature,
          subdivision: m.subdivision,
          accents: m.accents,
          beatsPerBar: m.beatsPerBar,
          pulsesPerBeat: m.pulsesPerBeat,
          currentSlot: m.currentSlot,
          onSignatureChanged: m.setSignature,
          onSubdivisionChanged: m.setSubdivision,
          onAccentChanged: m.setAccent,
        ),
        const SizedBox(height: 16),
        TempoCard(
          label: m.dynamicMode ? 'Start tempo' : 'Tempo',
          value: m.startBpm,
          onChanged: m.setTempo,
        ),
        const SizedBox(height: 16),
        DynamicModeCard(metronome: m),
      ],
    );
  }
}
