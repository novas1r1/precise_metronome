import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:precise_metronome/precise_metronome.dart';

/// How the tempo is moving right now — drives the ring, dot and glow color
/// (coral climbing, sky blue on the way back down).
enum TempoDirection { up, down }

/// The screen's state, and the only place that talks to [Metronome].
///
/// Everything timing-critical happens natively; this class sends state
/// commands and republishes the native [Metronome.beats] and
/// [Metronome.rampProgress] streams as something the widgets can paint.
class AccelMetronome extends ChangeNotifier {
  AccelMetronome();

  final Metronome _metronome = Metronome();

  StreamSubscription<BeatEvent>? _beatSub;
  StreamSubscription<RampProgress>? _rampSub;

  bool _ready = false;
  bool _playing = false;
  Object? _initError;

  // Sound. `_startBpm` is what the user dialled in — the ramp's start
  // tempo, and the plain tempo when dynamic mode is off. `_liveBpm` is the
  // tempo a running ramp has reached; it never writes back to the setting.
  double _startBpm = 60;
  double? _liveBpm;
  TimeSignature _signature = TimeSignature(4, 4);
  /// One flag per audible pulse of the bar, indexed
  /// `beat * subdivision.pulsesPerBeat + pulse`.
  List<bool> _pulseAccents = [true, false, false, false];
  Subdivision _subdivision = Subdivision.none;
  MetronomeVoice _voice = MetronomeVoice.tone;
  double _volume = 0.8;

  // Dynamic mode (the ramp).
  bool _dynamic = true;
  int _barsPerStep = 4;
  double _stepBpm = 5;
  bool _useTarget = true;
  double _targetBpm = 120;
  bool _returnToStart = true;

  // Live feedback.
  BeatEvent? _lastBeat;
  BeatEvent? _lastPulse;
  int _beatTick = 0;
  RampProgress? _progress;
  TempoDirection _direction = TempoDirection.up;
  String? _notice;

  // ------------------------------------------------------------- getters

  bool get isReady => _ready;
  bool get isPlaying => _playing;
  Object? get initError => _initError;

  /// The tempo shown in the dial. While a ramp runs this follows the ramp.
  double get tempo => _liveBpm ?? _startBpm;

  /// The tempo the user set: the ramp's start tempo, and the plain tempo
  /// when dynamic mode is off. Unaffected by a running ramp.
  double get startBpm => _startBpm;
  TimeSignature get signature => _signature;
  int get beatsPerBar => _signature.beatsPerBar;
  /// One flag per audible pulse of the bar — the accent grid's cells.
  List<bool> get accents => List.unmodifiable(_pulseAccents);
  Subdivision get subdivision => _subdivision;
  int get pulsesPerBeat => _subdivision.pulsesPerBeat;
  MetronomeVoice get voice => _voice;
  double get volume => _volume;

  bool get dynamicMode => _dynamic;
  int get barsPerStep => _barsPerStep;
  double get stepBpm => _stepBpm;
  bool get useTarget => _useTarget;
  double get targetBpm => _targetBpm;
  bool get returnToStart => _returnToStart;

  /// `true` while the ramp is stepping back down towards the start tempo,
  /// or while a plain ramp counts downwards.
  TempoDirection get direction => _direction;
  RampProgress? get progress => _progress;
  BeatEvent? get lastBeat => _lastBeat;

  /// The accent-grid cell currently sounding, or `null` when stopped.
  int? get currentSlot {
    final pulse = _lastPulse;
    if (!_playing || pulse == null) return null;
    return pulse.beatIndex * pulsesPerBeat + pulse.pulseIndex;
  }

  /// Increments on every beat, so widgets can restart an animation even
  /// when two consecutive beats carry the same index.
  int get beatTick => _beatTick;

  /// A short transient message ("Back at 60 BPM"), or `null`.
  String? get notice => _notice;

  /// Bar within the current ramp step, 0-based. `null` when not running.
  int? get barInStep {
    final beat = _lastBeat;
    if (!_playing || beat == null) return null;
    return beat.barIndex % _barsPerStep;
  }

  /// How far the current ramp step has progressed, 0..1, for the thin
  /// progress line under the dial.
  double get stepProgress {
    final beat = _lastBeat;
    if (!_playing || !_dynamic || beat == null) return 0;
    final bars = beat.barIndex % _barsPerStep;
    final within = (beat.beatIndex + 1) / beatsPerBar;
    return ((bars + within) / _barsPerStep).clamp(0.0, 1.0);
  }

  /// The tempo the ramp will move to next, or `null` when it is done or
  /// dynamic mode is off.
  double? get nextTempo {
    final ramp = _metronome.activeRamp;
    final progress = _progress;
    if (ramp == null || progress == null || progress.finished) return null;
    final next = ramp.bpmAt(progress.stepIndex + 1);
    return next == tempo ? null : next;
  }

  // -------------------------------------------------------------- set-up

  Future<void> init() async {
    try {
      await _metronome.init();
      await _metronome.setTempo(_startBpm);
      await _metronome.setTimeSignature(_signature);
      await _metronome.setAccentPattern(_pulseAccents);
      await _metronome.setSubdivision(_subdivision);
      // Subdivision pulses light up their own cell in the accent grid.
      await _metronome.setBeatEventOptions(includeSubdivisions: true);
      await _metronome.setVoice(_voice);
      await _metronome.setVolume(_volume);
      _beatSub = _metronome.beats.listen(_onBeat);
      _rampSub = _metronome.rampProgress.listen(_onRampProgress);
      _ready = true;
    } catch (error) {
      _initError = error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _beatSub?.cancel();
    _rampSub?.cancel();
    _metronome.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ commands

  Future<void> toggle() => _playing ? stop() : start();

  Future<void> start() async {
    if (!_ready || _playing) return;
    _lastBeat = null;
    _lastPulse = null;
    _notice = null;
    _direction = TempoDirection.up;
    if (_dynamic) {
      final ramp = buildRamp();
      _liveBpm = ramp.startBpm;
      await _metronome.startRamp(ramp);
    } else {
      _progress = null;
      _liveBpm = null;
      await _metronome.setTempo(_startBpm);
      await _metronome.start();
    }
    _playing = true;
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_ready || !_playing) return;
    await _metronome.stop();
    _playing = false;
    _lastBeat = null;
    _lastPulse = null;
    _liveBpm = null;
    _progress = null;
    _direction = TempoDirection.up;
    notifyListeners();
  }

  /// The ramp the current dynamic-mode settings describe. Also used by the
  /// UI to show the step count before anything is playing.
  TempoRamp buildRamp() {
    // `returnToStart` needs a goal to turn around at, and an open-ended
    // ramp has none — the UI disables the toggle to match.
    final withTarget = _useTarget;
    return TempoRamp(
      startBpm: _startBpm,
      goalBpm: withTarget ? _targetBpm : null,
      stepBpm: _stepBpm,
      barsPerStep: _barsPerStep,
      returnToStart: withTarget && _returnToStart,
    );
  }

  // ------------------------------------------------------------- setters

  Future<void> setTempo(double bpm) async {
    final clamped = bpm.clamp(20.0, 400.0);
    if (clamped == _startBpm) return;
    _startBpm = clamped;
    // While a ramp runs the ramp owns the tempo; the field edits the ramp's
    // start tempo for the next run instead.
    if (_ready && _playing && !_dynamic) await _metronome.setTempo(clamped);
    if (_targetBpm <= clamped) {
      _targetBpm = (clamped + _stepBpm).clamp(20.0, 400.0);
    }
    notifyListeners();
  }

  Future<void> setSignature(TimeSignature signature) async {
    if (signature == _signature) return;
    _signature = signature;
    // setTimeSignature resets the accents to "downbeat only"; mirror that.
    _pulseAccents = List<bool>.generate(
      signature.beatsPerBar * pulsesPerBeat,
      (i) => i == 0,
    );
    if (_ready) await _metronome.setTimeSignature(signature);
    notifyListeners();
  }

  /// Toggles one cell of the accent grid. [slot] is
  /// `beat * pulsesPerBeat + pulse`, so subdivision pulses can be accented
  /// as well as main beats.
  Future<void> setAccent(int slot, bool accented) async {
    if (slot < 0 || slot >= _pulseAccents.length) return;
    if (_pulseAccents[slot] == accented) return;
    _pulseAccents = List<bool>.of(_pulseAccents)..[slot] = accented;
    if (_ready) await _metronome.setAccentPattern(_pulseAccents);
    notifyListeners();
  }

  Future<void> setSubdivision(Subdivision subdivision) async {
    if (subdivision == _subdivision) return;
    // Main-beat accents survive; accents that sat on subdivision pulses no
    // longer line up and are cleared — the same rule the package applies.
    final perBeat = List<bool>.generate(
      beatsPerBar,
      (beat) => _pulseAccents[beat * pulsesPerBeat],
    );
    _subdivision = subdivision;
    _pulseAccents = List<bool>.generate(
      beatsPerBar * subdivision.pulsesPerBeat,
      (i) =>
          i % subdivision.pulsesPerBeat == 0 &&
          perBeat[i ~/ subdivision.pulsesPerBeat],
    );
    if (_ready) await _metronome.setSubdivision(subdivision);
    notifyListeners();
  }

  Future<void> setVoice(MetronomeVoice voice) async {
    if (voice == _voice) return;
    _voice = voice;
    if (_ready) await _metronome.setVoice(voice);
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped == _volume) return;
    _volume = clamped;
    if (_ready) await _metronome.setVolume(clamped);
    notifyListeners();
  }

  void setDynamicMode(bool value) {
    if (value == _dynamic) return;
    _dynamic = value;
    notifyListeners();
  }

  void setBarsPerStep(int bars) {
    _barsPerStep = bars.clamp(1, 64);
    notifyListeners();
  }

  void setStepBpm(double step) {
    _stepBpm = step.clamp(1.0, 50.0);
    if (_targetBpm <= _startBpm) {
      _targetBpm = (_startBpm + _stepBpm).clamp(20.0, 400.0);
    }
    notifyListeners();
  }

  void setUseTarget(bool value) {
    _useTarget = value;
    notifyListeners();
  }

  void setTargetBpm(double bpm) {
    _targetBpm = bpm.clamp(20.0, 400.0);
    notifyListeners();
  }

  void setReturnToStart(bool value) {
    _returnToStart = value;
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  // -------------------------------------------------------- native events

  void _onBeat(BeatEvent beat) {
    _lastPulse = beat;
    // Only main beats drive the ring, so it does not flicker once per
    // subdivision pulse.
    if (beat.isMainBeat) {
      _lastBeat = beat;
      _beatTick++;
    }
    notifyListeners();
  }

  void _onRampProgress(RampProgress progress) {
    final ramp = _metronome.activeRamp;
    final previous = _progress;
    _progress = progress;
    _liveBpm = progress.bpm;

    if (ramp != null && progress.stepIndex > 0) {
      final before = ramp.bpmAt(progress.stepIndex - 1);
      if (progress.bpm != before) {
        _direction = progress.bpm < before
            ? TempoDirection.down
            : TempoDirection.up;
      }
    }

    if (progress.finished) {
      _playing = false;
      _lastBeat = null;
      _lastPulse = null;
      _notice = _returnToStart && _useTarget
          ? 'Back at ${_format(progress.bpm)} BPM'
          : 'Target reached — ${_format(progress.bpm)} BPM';
    } else if (previous != null &&
        _direction == TempoDirection.down &&
        previous.stepIndex < progress.stepIndex &&
        _noticeForTurnaround(ramp, progress)) {
      _notice = 'Ramping back down';
    }
    notifyListeners();
  }

  /// True exactly once, on the first step of the return leg.
  bool _noticeForTurnaround(TempoRamp? ramp, RampProgress progress) {
    if (ramp == null || !ramp.returnToStart) return false;
    final total = ramp.totalSteps;
    return progress.stepIndex == (total + 1) ~/ 2;
  }

  static String _format(double bpm) =>
      bpm == bpm.roundToDouble() ? bpm.round().toString() : bpm.toStringAsFixed(1);
}
