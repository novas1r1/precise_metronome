import 'dart:async';

import 'package:flutter/material.dart';
import 'package:precise_metronome/precise_metronome.dart';

import 'accel_metronome.dart';
import 'design/accel_tokens.dart';
import 'widgets/accel_controls.dart';
import 'widgets/accel_select.dart';
import 'widgets/accel_surfaces.dart';
import 'widgets/accent_grid.dart';
import 'widgets/beat_ring.dart';

/// The Accel metronome screen: header, dial, meter controls, dynamic-mode
/// card, and a transport bar pinned to the bottom.
class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final AccelMetronome _metronome = AccelMetronome();
  Timer? _noticeTimer;

  static final List<TimeSignature> _signatures = [
    TimeSignature(2, 4),
    TimeSignature(3, 4),
    TimeSignature(4, 4),
    TimeSignature(5, 4),
    TimeSignature(6, 8),
    TimeSignature(7, 8),
    TimeSignature(12, 8),
  ];

  @override
  void initState() {
    super.initState();
    _metronome.addListener(_onChanged);
    _metronome.init();
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _metronome.removeListener(_onChanged);
    _metronome.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_metronome.notice != null) {
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(milliseconds: 2600), _metronome.clearNotice);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final m = _metronome;
    final descending = m.direction == TempoDirection.down;

    return Scaffold(
      backgroundColor: AccelColors.bg,
      body: Stack(
        children: [
          _Backdrop(running: m.isPlaying, descending: descending),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                // Mobile-first at 390px; centered and capped on wider screens.
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _header(m, descending),
                    Expanded(child: _body(m, descending)),
                  ],
                ),
              ),
            ),
          ),
          _transport(m),
          if (m.notice != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 68,
              left: 0,
              right: 0,
              child: Center(child: AccelToast(message: m.notice!)),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- sections

  Widget _header(AccelMetronome m, bool descending) {
    final next = m.nextTempo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text('Accel', style: AccelType.display(size: 22, weight: 800, letterSpacing: -0.05 * 22)),
          const Spacer(),
          if (m.dynamicMode) ...[
            AccelBadge(
              label: m.isPlaying && next != null
                  ? '${descending ? '−' : '+'}${_bpm(m.stepBpm)} → ${_bpm(next)}'
                  : 'dynamic',
              tone: descending ? AccelBadgeTone.info : AccelBadgeTone.accent,
              dot: m.isPlaying,
            ),
            const SizedBox(width: 8),
          ],
          AccelIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            ghost: true,
            onPressed: m.isReady ? () => _openSettings(m) : null,
          ),
        ],
      ),
    );
  }

  Widget _body(AccelMetronome m, bool descending) {
    if (m.initError != null) return _error(m.initError!);

    final beat = m.lastBeat;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 164),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: BeatRing(
              beatTick: m.beatTick,
              beatIndex: beat?.beatIndex,
              beatsPerBar: m.beatsPerBar,
              accent: beat?.accent ?? false,
              direction: m.direction,
              running: m.isPlaying,
              size: 250,
              child: _dialContents(m),
            ),
          ),
        ),
        if (m.dynamicMode) ...[const SizedBox(height: 8), _stepProgress(m, descending)],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AccelSelect<TimeSignature>(
                label: 'Time signature',
                value: m.signature,
                valueStyle: AccelType.display(size: 24, weight: 600, tabularFigures: true),
                options: [
                  for (final s in _signatures)
                    AccelSegmentedOption(s, '${s.numerator}/${s.denominator}'),
                ],
                onChanged: m.setSignature,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccelSegmented<Subdivision>(
                label: 'Subdivision',
                value: m.subdivision,
                labelStyle: AccelType.display(size: 15, weight: 600),
                options: const [
                  AccelSegmentedOption(Subdivision.none, '♩'),
                  AccelSegmentedOption(Subdivision.duple, '♪♪'),
                  AccelSegmentedOption(Subdivision.triplet, '♪³'),
                  AccelSegmentedOption(Subdivision.quadruple, '♬♬'),
                ],
                onChanged: m.setSubdivision,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AccentGrid(
          accents: m.accents,
          beatsPerBar: m.beatsPerBar,
          pulsesPerBeat: m.pulsesPerBeat,
          currentSlot: m.currentSlot,
          onChanged: m.setAccent,
        ),
        const SizedBox(height: 16),
        _tempoCard(m),
        const SizedBox(height: 16),
        _dynamicCard(m),
      ],
    );
  }

  Widget _dialContents(AccelMetronome m) {
    final bar = m.barInStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The tempo counts in with a spring when it steps.
        TweenAnimationBuilder<double>(
          key: ValueKey(m.tempo),
          tween: Tween(begin: 0, end: 1),
          duration: AccelMotion.slow,
          curve: AccelMotion.spring,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
          ),
          child: Text(
            _bpm(m.tempo),
            style: AccelType.display(
              size: 96,
              weight: 800,
              height: 0.9,
              letterSpacing: -0.04 * 96,
              tabularFigures: true,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'BPM',
          style: AccelType.mono(size: 11, letterSpacing: 0.14 * 11, color: AccelColors.textMuted),
        ),
        if (m.isPlaying && m.dynamicMode && bar != null) ...[
          const SizedBox(height: 6),
          Text('bar ${bar + 1} / ${m.barsPerStep}', style: AccelType.mono(size: 12)),
        ],
      ],
    );
  }

  Widget _stepProgress(AccelMetronome m, bool descending) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: m.stepProgress,
        minHeight: 3,
        backgroundColor: AccelColors.surfaceGlassStrong,
        valueColor: AlwaysStoppedAnimation(descending ? AccelColors.info : AccelColors.accent),
      ),
    );
  }

  /// The metronome's tempo — its own card, above the dynamic-mode box.
  /// It is the tempo the metronome plays at, and the tempo a ramp starts
  /// from, so it stays visible whether dynamic mode is on or off.
  Widget _tempoCard(AccelMetronome m) {
    return AccelCard(
      padding: const EdgeInsets.all(16),
      child: AccelNumberField(
        label: m.dynamicMode ? 'Start tempo' : 'Tempo',
        unit: 'BPM',
        value: m.startBpm,
        min: 20,
        max: 400,
        large: true,
        onChanged: m.setTempo,
      ),
    );
  }

  Widget _dynamicCard(AccelMetronome m) {
    final on = m.dynamicMode;
    final ramp = on ? m.buildRamp() : null;

    return AccelCard(
      title: 'Dynamic mode',
      glow: on && m.isPlaying,
      // Off, the card collapses to its title row and switch.
      expanded: on,
      action: AccelSwitch(value: on, onChanged: m.setDynamicMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AccelNumberField(
                  label: 'Bar count',
                  value: m.barsPerStep.toDouble(),
                  min: 1,
                  max: 64,
                  onChanged: (v) => m.setBarsPerStep(v.round()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccelNumberField(
                  label: 'Increase by BPM',
                  value: m.stepBpm,
                  min: 1,
                  max: 50,
                  onChanged: m.setStepBpm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AccelSwitch(label: 'Stop at target', value: m.useTarget, onChanged: m.setUseTarget),
          if (m.useTarget) ...[
            const SizedBox(height: 14),
            AccelNumberField(
              label: 'Target tempo',
              unit: 'BPM',
              value: m.targetBpm,
              min: 20,
              max: 400,
              step: 5,
              onChanged: m.setTargetBpm,
            ),
          ],
          const SizedBox(height: 14),
          AccelSwitch(
            label: 'Ramp back down',
            description: 'Step back to the start tempo at the top',
            value: m.returnToStart && m.useTarget,
            onChanged: m.useTarget ? m.setReturnToStart : null,
          ),
          if (ramp != null) ...[const SizedBox(height: 16), _rampPlan(ramp)],
        ],
      ),
    );
  }

  /// The tempi the ramp will play, straight from `TempoRamp.steps`.
  /// Long plans are elided in the middle so the shape stays readable —
  /// on a round trip that keeps the turnaround visible.
  Widget _rampPlan(TempoRamp ramp) {
    final String text;
    if (ramp.isOpenEnded) {
      final head = [ramp.startBpm, ramp.bpmAt(1), ramp.bpmAt(2)];
      text = '${head.map(_bpm).join(' → ')} → …  ·  open ended';
    } else {
      final steps = ramp.steps;
      final bars = ramp.totalSteps * ramp.barsPerStep;
      final shown = steps.length <= 6
          ? steps.map(_bpm).join(' → ')
          : ramp.returnToStart
          // first, second, the goal in the middle, last two.
          ? '${_bpm(steps.first)} → ${_bpm(steps[1])} → … → '
                '${_bpm(steps[(steps.length - 1) ~/ 2])} → … → '
                '${_bpm(steps.last)}'
          : '${_bpm(steps.first)} → ${_bpm(steps[1])} → … → '
                '${_bpm(steps.last)}';
      text = '$shown  ·  ${ramp.totalSteps} steps  ·  $bars bars';
    }

    return Text(text, style: AccelType.mono(size: 12, color: AccelColors.textMuted));
  }

  Widget _transport(AccelMetronome m) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00070B18), AccelColors.bg],
            stops: [0, 0.55],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                // Extra top padding gives the gradient room to fade the
                // scrolling content out before it reaches the button.
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Row(
                  children: [
                    AccelIconButton(
                      icon: Icons.replay_rounded,
                      tooltip: 'Reset',
                      size: AccelControl.lg,
                      onPressed: m.isPlaying ? m.stop : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AccelButton(
                        label: m.isPlaying ? 'Stop' : 'Start',
                        icon: m.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: AccelButtonSize.xl,
                        fullWidth: true,
                        glow: !m.isPlaying,
                        variant: m.isPlaying
                            ? AccelButtonVariant.secondary
                            : AccelButtonVariant.primary,
                        onPressed: m.isReady ? m.toggle : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(Object error) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('The audio engine did not start', style: AccelType.display(size: 20, weight: 600)),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: AccelType.mono(size: 12, color: AccelColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- settings

  void _openSettings(AccelMetronome m) {
    AccelSheet.show(
      context: context,
      title: 'Settings',
      builder: (context) => ListenableBuilder(
        listenable: m,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccelSlider(
              label: 'Volume',
              value: m.volume,
              readout: '${(m.volume * 100).round()}%',
              onChanged: m.setVolume,
            ),
            const SizedBox(height: 20),
            AccelChoiceList<MetronomeVoice>(
              label: 'Sound',
              value: m.voice,
              choices: _voices,
              onChanged: m.setVoice,
            ),
            const SizedBox(height: 24),
            AccelButton(
              label: 'Done',
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
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

  static String _bpm(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
}

/// Flat navy with one large radial coral glow behind the dial, switching to
/// sky blue while the ramp steps back down.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.running, required this.descending});

  final bool running;
  final bool descending;

  @override
  Widget build(BuildContext context) {
    final color = descending ? AccelColors.beatDown : AccelColors.accent;
    return Positioned(
      top: -120,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 520,
            height: 520,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: running ? 0.28 : 0.14),
                  color.withValues(alpha: 0),
                ],
                stops: const [0, 0.62],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
