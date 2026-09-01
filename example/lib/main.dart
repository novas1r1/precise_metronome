import 'dart:async';

import 'package:flutter/material.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  runApp(const MetronomeApp());
}

class MetronomeApp extends StatelessWidget {
  const MetronomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'precise_metronome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MetronomeScreen(),
    );
  }
}

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});
  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final Metronome _metronome = Metronome();
  final TapTempo _tap = TapTempo();

  bool _ready = false;
  bool _playing = false;
  double _bpm = 120;
  TimeSignature _sig = TimeSignature(4, 4);
  List<bool> _accents = [true, false, false, false];
  MetronomeVoice _voice = MetronomeVoice.tone;
  double _volume = 0.8;
  bool _background = false;

  // Tempo ramp ('speed trainer').
  double _rampStart = 80;
  double _rampGoal = 120;
  bool _rampOpenEnded = false;
  double _rampStep = 5;
  int _rampBars = 4;
  RampProgress? _rampProgress;
  StreamSubscription<RampProgress>? _rampSub;

  // Beat indicator.
  BeatEvent? _lastBeat;
  bool _showBeatNumber = false;
  StreamSubscription<BeatEvent>? _beatSub;

  static final List<TimeSignature> _presetSignatures = [
    TimeSignature(2, 4),
    TimeSignature(3, 4),
    TimeSignature(4, 4),
    TimeSignature(5, 4),
    TimeSignature(6, 8), // compound: 2 beats
    TimeSignature(7, 8),
    TimeSignature(9, 8), // compound: 3 beats
    TimeSignature(12, 8), // compound: 4 beats
  ];

  @override
  void initState() {
    super.initState();
    _initMetronome();
  }

  Future<void> _initMetronome() async {
    try {
      await _metronome.init();
      await _metronome.setTempo(_bpm);
      await _metronome.setTimeSignature(_sig);
      await _metronome.setAccentPattern(_accents);
      await _metronome.setVoice(_voice);
      await _metronome.setVolume(_volume);
      _rampSub = _metronome.rampProgress.listen((p) {
        if (!mounted) return;
        setState(() {
          _rampProgress = p;
          _bpm = p.bpm;
          if (p.finished) _playing = false;
        });
      });
      _beatSub = _metronome.beats.listen((b) {
        if (mounted) setState(() => _lastBeat = b);
      });
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize: $e')),
      );
    }
  }

  @override
  void dispose() {
    _rampSub?.cancel();
    _beatSub?.cancel();
    _metronome.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_playing) {
      await _metronome.stop();
    } else {
      await _metronome.start();
    }
    setState(() {
      _playing = !_playing;
      _rampProgress = null;
    });
  }

  Future<void> _startRamp() async {
    if (!_ready || _playing) return;
    final ramp = TempoRamp(
      startBpm: _rampStart,
      goalBpm: _rampOpenEnded ? null : _rampGoal,
      stepBpm: _rampStep,
      barsPerStep: _rampBars,
    );
    await _metronome.startRamp(ramp);
    setState(() {
      _playing = true;
      _bpm = _rampStart;
    });
  }

  Future<void> _onTempoChanged(double v) async {
    setState(() => _bpm = v);
    if (_ready) await _metronome.setTempo(v);
  }

  Future<void> _onTempoChangeCommit(double v) async {
    // final push not needed — we push while dragging
  }

  Future<void> _pickSignature(TimeSignature s) async {
    if (_ready) await _metronome.setTimeSignature(s);
    setState(() {
      _sig = s;
      // The plugin keeps accent-enabled state and accent beat across
      // time-signature changes — mirror its pattern instead of guessing.
      _accents = _ready
          ? List<bool>.from(_metronome.accentPattern)
          : List<bool>.generate(s.beatsPerBar, (i) => i == 0);
    });
  }

  Future<void> _toggleAccent(int i) async {
    setState(() {
      _accents = List<bool>.from(_accents);
      _accents[i] = !_accents[i];
    });
    if (_ready) await _metronome.setAccentPattern(_accents);
  }

  Future<void> _setAccentEnabled(bool enabled) async {
    if (_ready) await _metronome.setAccentEnabled(enabled);
    setState(() {
      _accents = _ready
          ? List<bool>.from(_metronome.accentPattern)
          : List<bool>.generate(_sig.beatsPerBar, (i) => enabled && i == 0);
    });
  }

  Future<void> _pickVoice(MetronomeVoice v) async {
    setState(() => _voice = v);
    if (_ready) await _metronome.setVoice(v);
  }

  Future<void> _onVolumeChanged(double v) async {
    setState(() => _volume = v);
    if (_ready) await _metronome.setVolume(v);
  }

  Future<void> _tapNow() async {
    final bpm = _tap.tap();
    if (bpm == null) return;
    final clamped = bpm.clamp(20.0, 400.0);
    setState(() => _bpm = clamped);
    if (_ready) await _metronome.setTempo(clamped);
  }

  Future<void> _toggleBackground(bool enable) async {
    if (!_ready) return;
    if (enable) {
      await _metronome.enableBackgroundPlayback();
    } else {
      await _metronome.disableBackgroundPlayback();
    }
    setState(() => _background = enable);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('precise_metronome'),
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bpmDisplay(cs),
              const SizedBox(height: 12),
              _beatIndicator(cs),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Dots')),
                    ButtonSegment(value: true, label: Text('Number')),
                  ],
                  selected: {_showBeatNumber},
                  onSelectionChanged: (s) =>
                      setState(() => _showBeatNumber = s.first),
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                min: 20,
                max: 400,
                divisions: 380,
                value: _bpm,
                label: '${_bpm.round()}',
                onChanged: _ready ? _onTempoChanged : null,
                onChangeEnd: _onTempoChangeCommit,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _ready ? _togglePlay : null,
                      icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                      label: Text(_playing ? 'Stop' : 'Start'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _ready ? _tapNow : null,
                      icon: const Icon(Icons.touch_app),
                      label: const Text('Tap'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _sectionLabel('Time signature'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetSignatures.map((s) {
                  final selected = s == _sig;
                  return ChoiceChip(
                    label: Text('${s.numerator}/${s.denominator}'),
                    selected: selected,
                    onSelected: _ready ? (_) => _pickSignature(s) : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _sectionLabel(
                'Accents  ·  ${_sig.beatsPerBar} beat${_sig.beatsPerBar == 1 ? '' : 's'} per bar',
              ),
              SwitchListTile(
                value: _accents.contains(true),
                onChanged: _ready ? _setAccentEnabled : null,
                title: const Text('Accent'),
                subtitle: const Text(
                  'Off: every beat sounds the same. Tap a beat below to '
                  'move or add accents.',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(_sig.beatsPerBar, (i) {
                  final accented = _accents[i];
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            accented ? cs.primary : cs.surfaceContainerHighest,
                        foregroundColor:
                            accented ? cs.onPrimary : cs.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _ready ? () => _toggleAccent(i) : null,
                      child: Text('${i + 1}'),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              _sectionLabel('Tempo ramp'),
              _rampField('Start BPM', _rampStart, 20, 400,
                  (v) => setState(() => _rampStart = v)),
              SwitchListTile(
                value: _rampOpenEnded,
                onChanged: _ready && !_playing
                    ? (v) => setState(() => _rampOpenEnded = v)
                    : null,
                title: const Text('Open-ended'),
                subtitle: const Text('Keep speeding up until stopped'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (!_rampOpenEnded)
                _rampField('Goal BPM', _rampGoal, 20, 400,
                    (v) => setState(() => _rampGoal = v)),
              _rampField('Step BPM', _rampStep, 1, 50,
                  (v) => setState(() => _rampStep = v)),
              _rampField('Bars per step', _rampBars.toDouble(), 1, 16,
                  (v) => setState(() => _rampBars = v.round())),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _ready && !_playing ? _startRamp : null,
                icon: const Icon(Icons.trending_up),
                label: const Text('Start ramp'),
              ),
              if (_rampProgress case final p?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    p.finished
                        ? 'Ramp finished at ${p.bpm.round()} BPM'
                        : 'Step ${p.stepIndex + 1}${p.totalSteps == null ? '' : '/${p.totalSteps}'}'
                            '  ·  ${p.bpm.round()} BPM',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 28),
              _sectionLabel('Voice'),
              Wrap(
                spacing: 8,
                children: MetronomeVoice.values.map((v) {
                  return ChoiceChip(
                    label: Text(v.name),
                    selected: _voice == v,
                    onSelected: _ready ? (_) => _pickVoice(v) : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Volume'),
              Slider(
                min: 0,
                max: 1,
                value: _volume,
                onChanged: _ready ? _onVolumeChanged : null,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                value: _background,
                onChanged: _ready ? _toggleBackground : null,
                title: const Text('Background playback'),
                subtitle: const Text(
                  'Keeps the metronome running when the app is backgrounded.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );

  Widget _beatIndicator(ColorScheme cs) {
    final beat = _playing ? _lastBeat : null;
    if (_showBeatNumber) return _beatNumber(cs, beat);
    return _beatDots(cs, beat);
  }

  /// Just the current beat number, 1-based, e.g. 1 2 3 4 in 4/4.
  Widget _beatNumber(ColorScheme cs, BeatEvent? beat) {
    final accent = beat != null && beat.accent;
    return SizedBox(
      height: 72,
      child: Center(
        // No transition: any animation reads as extra lag behind the click.
        child: Text(
          beat == null ? '–' : '${beat.beatIndex + 1}',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: beat == null
                    ? cs.onSurfaceVariant
                    : (accent ? cs.primary : cs.onSurface),
              ),
        ),
      ),
    );
  }

  /// One dot per beat; the current beat lights up as the click is heard.
  Widget _beatDots(ColorScheme cs, BeatEvent? beat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_sig.beatsPerBar, (i) {
        final active = beat != null && beat.beatIndex == i;
        final accent = _accents[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 16,
          height: active ? 22 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? (accent ? cs.primary : cs.secondary)
                : cs.surfaceContainerHighest,
          ),
        );
      }),
    );
  }

  Widget _rampField(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: (max - min).round(),
            value: value.clamp(min, max),
            label: '${value.round()}',
            onChanged: _ready && !_playing ? onChanged : null,
          ),
        ),
        SizedBox(width: 36, child: Text('${value.round()}')),
      ],
    );
  }

  Widget _bpmDisplay(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _bpm.round().toString(),
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'BPM',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
