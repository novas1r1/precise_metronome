import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:precise_metronome/precise_metronome.dart';

import 'formatting.dart';

/// How the tempo is moving right now — drives the ring, dot and glow color
/// (coral climbing, sky blue on the way back down).
enum TempoDirection { up, down }

/// How long each ramp step is held: a number of bars, or a stretch of
/// time that ends at the next bar line.
enum StepMode { bars, time }

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

  // Dynamic mode (the ramp). Both step lengths are kept so switching the
  // mode back and forth does not lose either setting.
  bool _dynamic = true;
  StepMode _stepMode = StepMode.bars;
  int _barsPerStep = 4;
  Duration _stepDuration = const Duration(minutes: 1);
  double _stepBpm = 5;
  bool _useTarget = true;
  double _targetBpm = 120;
  bool _returnToStart = true;

  /// The tempo range the UI allows, for both the start and target tempo.
  static const double minBpm = 20;
  static const double maxBpm = 400;

  /// How much a ramp step may change the tempo by.
  static const double minStepBpm = 1;
  static const double maxStepBpm = 50;

  /// How many bars a ramp step may be held for.
  static const int minBarsPerStep = 1;
  static const int maxBarsPerStep = 64;

  /// Shortest and longest timed step the UI allows.
  static const Duration minStepDuration = Duration(seconds: 5);
  static const Duration maxStepDuration = Duration(minutes: 30);

  /// How long a transient [notice] stays up before it clears itself.
  static const Duration noticeDuration = Duration(milliseconds: 2600);

  /// The quick picks offered next to the time field.
  static const List<Duration> stepDurationPresets = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  // Live feedback.
  BeatEvent? _lastBeat;
  BeatEvent? _lastPulse;
  int _beatTick = 0;
  RampProgress? _progress;
  TempoDirection _direction = TempoDirection.up;
  String? _notice;
  Timer? _noticeTimer;
  // When the current timed step began (as seen from Dart) and the ticker
  // that keeps its countdown moving between beats.
  DateTime? _stepStartedAt;
  Timer? _clock;

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
  StepMode get stepMode => _stepMode;
  int get barsPerStep => _barsPerStep;
  Duration get stepDuration => _stepDuration;

  /// The step length the current mode describes.
  RampStepLength get stepLength => switch (_stepMode) {
    StepMode.bars => RampStepLength.bars(_barsPerStep),
    StepMode.time => RampStepLength.time(_stepDuration),
  };

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

  /// A short transient message ("Back at 60 BPM"), or `null`. It clears
  /// itself after [noticeDuration].
  String? get notice => _notice;

  /// Bar within the current ramp step, 0-based. `null` when no ramp is
  /// running or when steps are timed — a timed step has no fixed bar count.
  int? get barInStep {
    final beat = _lastBeat;
    if (!_playing || !_dynamic || _stepMode != StepMode.bars || beat == null) {
      return null;
    }
    return beat.barIndex % _barsPerStep;
  }

  /// Time left in the current timed step, or `null` when not running or
  /// when steps count bars. [Duration.zero] once the time is up and the
  /// ramp is waiting for the next bar line.
  Duration? get stepTimeLeft {
    final started = _stepStartedAt;
    if (!_playing ||
        !_dynamic ||
        _stepMode != StepMode.time ||
        started == null) {
      return null;
    }
    final left = _stepDuration - DateTime.now().difference(started);
    return left.isNegative ? Duration.zero : left;
  }

  /// How far the current ramp step has progressed, 0..1, for the thin
  /// progress line under the dial.
  double get stepProgress {
    if (!_playing || !_dynamic) return 0;
    if (_stepMode == StepMode.time) {
      final started = _stepStartedAt;
      if (started == null) return 0;
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      return (elapsed / _stepDuration.inMilliseconds).clamp(0.0, 1.0);
    }
    final beat = _lastBeat;
    if (beat == null) return 0;
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
    _clock?.cancel();
    _noticeTimer?.cancel();
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
    _progress = null;
    _direction = TempoDirection.up;
    _clearNotice();
    if (_dynamic) {
      final ramp = buildRamp();
      _liveBpm = ramp.startBpm;
      await _metronome.startRamp(ramp);
      _stepStarted();
    } else {
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
    _clearLive();
    notifyListeners();
  }

  /// Marks the start of a ramp step for the countdown, and keeps the
  /// countdown ticking between beats while steps are timed.
  void _stepStarted() {
    _stepStartedAt = DateTime.now();
    if (_stepMode == StepMode.time && _clock == null) {
      _clock = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
  }

  void _clearLive() {
    _clock?.cancel();
    _clock = null;
    _stepStartedAt = null;
    _lastBeat = null;
    _lastPulse = null;
    _liveBpm = null;
    _progress = null;
    _direction = TempoDirection.up;
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
      stepLength: stepLength,
      returnToStart: withTarget && _returnToStart,
    );
  }

  // ------------------------------------------------------------- setters

  Future<void> setTempo(double bpm) async {
    final clamped = bpm.clamp(minBpm, maxBpm);
    if (clamped == _startBpm) return;
    _startBpm = clamped;
    // While a ramp runs the ramp owns the tempo; the field edits the ramp's
    // start tempo for the next run instead.
    if (_ready && _playing && !_dynamic) await _metronome.setTempo(clamped);
    _keepTargetAboveStart();
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

  void setStepMode(StepMode mode) {
    if (mode == _stepMode) return;
    _stepMode = mode;
    notifyListeners();
  }

  void setBarsPerStep(int bars) {
    _barsPerStep = bars.clamp(minBarsPerStep, maxBarsPerStep);
    notifyListeners();
  }

  void setStepDuration(Duration duration) {
    _stepDuration = duration < minStepDuration
        ? minStepDuration
        : duration > maxStepDuration
        ? maxStepDuration
        : duration;
    notifyListeners();
  }

  void setStepBpm(double step) {
    _stepBpm = step.clamp(minStepBpm, maxStepBpm);
    _keepTargetAboveStart();
    notifyListeners();
  }

  void setUseTarget(bool value) {
    _useTarget = value;
    notifyListeners();
  }

  void setTargetBpm(double bpm) {
    _targetBpm = bpm.clamp(minBpm, maxBpm);
    notifyListeners();
  }

  void setReturnToStart(bool value) {
    _returnToStart = value;
    notifyListeners();
  }

  /// A ramp has to climb somewhere: when the start tempo catches up with
  /// the target, the target moves one step above it.
  void _keepTargetAboveStart() {
    if (_targetBpm <= _startBpm) {
      _targetBpm = (_startBpm + _stepBpm).clamp(minBpm, maxBpm);
    }
  }

  // ------------------------------------------------------------- notices

  /// Shows [message] until [noticeDuration] has passed or the next start.
  void _showNotice(String message) {
    _notice = message;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(noticeDuration, () {
      _notice = null;
      notifyListeners();
    });
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    _notice = null;
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

    if (previous != null && previous.stepIndex != progress.stepIndex) {
      _stepStarted();
    }

    if (progress.finished) {
      _playing = false;
      _clock?.cancel();
      _clock = null;
      _stepStartedAt = null;
      _lastBeat = null;
      _lastPulse = null;
      _showNotice(
        _returnToStart && _useTarget
            ? 'Back at ${formatBpm(progress.bpm)} BPM'
            : 'Target reached — ${formatBpm(progress.bpm)} BPM',
      );
    } else if (previous != null &&
        _direction == TempoDirection.down &&
        previous.stepIndex < progress.stepIndex &&
        _noticeForTurnaround(ramp, progress)) {
      _showNotice('Ramping back down');
    }
    notifyListeners();
  }

  /// True exactly once, on the first step of the return leg.
  bool _noticeForTurnaround(TempoRamp? ramp, RampProgress progress) {
    if (ramp == null || !ramp.returnToStart) return false;
    final total = ramp.totalSteps;
    return progress.stepIndex == (total + 1) ~/ 2;
  }
}
