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

  static final List<TimeSignature> _presetSignatures = [
    TimeSignature(2, 4),
    TimeSignature(3, 4),
    TimeSignature(4, 4),
    TimeSignature(5, 4),
    TimeSignature(6, 8),   // compound: 2 beats
    TimeSignature(7, 8),
    TimeSignature(9, 8),   // compound: 3 beats
    TimeSignature(12, 8),  // compound: 4 beats
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
    setState(() => _playing = !_playing);
  }

  Future<void> _onTempoChanged(double v) async {
    setState(() => _bpm = v);
    if (_ready) await _metronome.setTempo(v);
  }

  Future<void> _onTempoChangeCommit(double v) async {
    // final push not needed — we push while dragging
  }

  Future<void> _pickSignature(TimeSignature s) async {
    setState(() {
      _sig = s;
      _accents = List<bool>.generate(s.beatsPerBar, (i) => i == 0);
    });
    if (_ready) {
      await _metronome.setTimeSignature(s);
    }
  }

  Future<void> _toggleAccent(int i) async {
    setState(() {
      _accents = List<bool>.from(_accents);
      _accents[i] = !_accents[i];
    });
    if (_ready) await _metronome.setAccentPattern(_accents);
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
                        backgroundColor: accented
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        foregroundColor: accented
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _ready ? () => _toggleAccent(i) : null,
                      child: Text('${i + 1}'),
                    ),
                  );
                }),
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
