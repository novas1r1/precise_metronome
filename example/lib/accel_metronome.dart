import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:precise_metronome/precise_metronome.dart';

import 'formatting.dart';
import 'gap_settings.dart';
import 'settings_store.dart';

// The gap trainer's settings, its presets and GapMode travel with the
// model, so a widget that has the model has them too.
export 'gap_settings.dart';

/// How the tempo is moving right now — drives the ring, dot and glow color
/// (coral climbing, sky blue on the way back down).
enum TempoDirection { up, down }

/// How long each ramp step is held: a number of bars, or a stretch of
/// time that ends at the next bar line.
enum StepMode { bars, time }

/// What the gap trainer is doing at this moment.
enum GapPhase { click, silent, landing }

/// One cell of the gap trainer's bar strip.
class GapStripCell {
  const GapStripCell({required this.silent, required this.current});

  /// `null` when the bar is not known yet: a random pattern keeps what is
  /// coming to itself, and a pattern the engine has not started has no
  /// bars to show.
  final bool? silent;

  /// The bar playing right now.
  final bool current;
}

/// The screen's state, and the only place that talks to [Metronome].
///
/// Everything timing-critical happens natively; this class sends state
/// commands and republishes the native [Metronome.beats] and
/// [Metronome.rampProgress] streams as something the widgets can paint.
class AccelMetronome extends ChangeNotifier {
  /// [store] is injectable so tests can hand it an empty one.
  AccelMetronome({SettingsStore? store}) : _store = store ?? SettingsStore();

  final Metronome _metronome = Metronome();
  final SettingsStore _store;

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

  // Gap trainer: whether it is on, what it plays (see [GapSettings]), and
  // the presets the user saved. The built-in presets are not stored.
  bool _gapEnabled = false;
  GapSettings _gap = const GapSettings();
  List<GapPreset> _customPresets = const [];

  /// Plays the pattern for the strip while the metronome is stopped, so a
  /// preview needs no engine. Dropped whenever the pattern changes.
  GapPatternGenerator? _gapPreview;

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

  /// What the notification says while the metronome plays in the
  /// background.
  static const AndroidNotificationConfig _backgroundNotification =
      AndroidNotificationConfig(
        title: 'Accel',
        body: 'Metronome running',
        channelName: 'Metronome',
      );

  /// How long the settings wait after the last change before they are
  /// written, so dragging a slider writes once rather than fifty times.
  static const Duration _saveDelay = Duration(milliseconds: 400);

  /// Bars the strip shows: the one playing and the six after it.
  static const int gapStripBars = 7;

  /// How far ahead the card counts when it measures a gap.
  static const int _gapScanBars = 32;

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

  /// Waits out [_saveDelay] before the settings are written.
  Timer? _saveTimer;

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

  // --------------------------------------------------------- gap trainer

  bool get gapEnabled => _gapEnabled;

  /// Everything the trainer plays by, in one piece — what a preset stores.
  GapSettings get gapSettings => _gap;

  GapMode get gapMode => _gap.mode;
  int get gapClickBars => _gap.clickBars;
  int get gapSilentBars => _gap.silentBars;
  double get gapSilentChance => _gap.silentChance;
  int get gapMaxSilentRun => _gap.maxSilentRun;
  int get gapStartSilentBars => _gap.startSilentBars;
  int get gapMaxSilentBars => _gap.maxSilentBars;
  int get gapCyclesPerStep => _gap.cyclesPerStep;
  bool get hideBeatWhenSilent => _gap.hideBeatWhenSilent;
  bool get showRemainingSilentBars => _gap.showRemainingSilentBars;

  /// The presets on offer: the ones Accel ships with, then the user's own.
  List<GapPreset> get gapPresets => [...builtInGapPresets, ..._customPresets];

  /// Only the user's own, in the order they were saved.
  List<GapPreset> get customGapPresets => List.unmodifiable(_customPresets);

  /// The preset the current settings match, or `null` when they match none.
  GapPreset? get selectedGapPreset =>
      gapPresets.where((preset) => preset.settings == _gap).firstOrNull;

  /// The pattern the trainer's settings describe, or `null` while it is
  /// off. This is what the engine is given.
  GapPattern? get gapPattern => _gapEnabled ? _gap.toPattern() : null;

  /// What the trainer is doing right now, or `null` when it is off or
  /// nothing has been heard yet.
  GapPhase? get gapPhase {
    final beat = _lastBeat;
    if (!_gapEnabled || !_playing || beat == null) return null;
    if (beat.muted) return GapPhase.silent;
    return beat.landing ? GapPhase.landing : GapPhase.click;
  }

  /// The bar playing and the six after it, for the strip. Empty while the
  /// trainer is off.
  List<GapStripCell> get gapStrip {
    if (!_gapEnabled) return const [];
    // A random pattern would give its gaps away; only the bar being heard
    // is shown.
    final hideAhead = _gap.mode == GapMode.random;
    return [
      for (var offset = 0; offset < gapStripBars; offset++)
        GapStripCell(
          silent: hideAhead && offset > 0
              ? null
              : _playing && offset == 0
              ? _lastBeat?.muted
              : _barAhead(offset)?.silent,
          current: _playing && offset == 0,
        ),
    ];
  }

  /// Silent bars left, counting the one playing. `null` unless the option
  /// is on and a countable gap is running — a random pattern has none.
  int? get silentBarsLeft {
    if (!_gap.showRemainingSilentBars || _gap.mode == GapMode.random) {
      return null;
    }
    if (!(_lastBeat?.muted ?? false)) return null;
    var left = 1;
    while (left < _gapScanBars && (_barAhead(left)?.silent ?? false)) {
      left++;
    }
    return left;
  }

  /// How many silent bars the ladder's current step has: the gap being
  /// played, or the one coming up. `null` in the other modes.
  int? get gapLadderBars {
    if (!_gapEnabled || _gap.mode != GapMode.ladder) return null;
    for (var offset = 0; offset < _gapScanBars; offset++) {
      if (!(_barAhead(offset)?.silent ?? false)) continue;
      // Measure the whole gap, not just what is left of it.
      var first = offset;
      while (_barAhead(first - 1)?.silent ?? false) {
        first--;
      }
      var bars = 1;
      while (_barAhead(first + bars)?.silent ?? false) {
        bars++;
      }
      return bars;
    }
    return null;
  }

  /// Whether the beat indicator is held back: a silenced bar with "hide
  /// the beat in gaps" on. The dial's ring never fires on a silenced beat,
  /// with or without the option.
  bool get _indicatorHidden =>
      _gap.hideBeatWhenSilent && (_lastPulse?.muted ?? false);

  /// The beat the dial marks, or `null` when nothing should light up.
  int? get indicatorBeat =>
      _playing && !_indicatorHidden ? _lastBeat?.beatIndex : null;

  /// Whether that beat carries an accent.
  bool get indicatorAccent => !_indicatorHidden && (_lastBeat?.accent ?? false);

  /// Bar [offset] bars after the one playing, or after the pattern's start
  /// while stopped. `null` when that bar is not known.
  GapBar? _barAhead(int offset) {
    final pattern = gapPattern;
    if (pattern == null) return null;
    if (_playing) {
      final beat = _lastBeat;
      if (beat == null) return null;
      return _metronome.gapBarAt(beat.barIndex + offset);
    }
    if (offset < 0) return null;
    return (_gapPreview ??= GapPatternGenerator(pattern)).barAt(offset);
  }

  /// `true` while the ramp is stepping back down towards the start tempo,
  /// or while a plain ramp counts downwards.
  TempoDirection get direction => _direction;
  RampProgress? get progress => _progress;
  BeatEvent? get lastBeat => _lastBeat;

  /// The accent-grid cell currently sounding, or `null` when stopped or
  /// while a gap hides the beat.
  int? get currentSlot {
    final pulse = _lastPulse;
    if (!_playing || pulse == null || _indicatorHidden) return null;
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
    // The settings the last run left behind, before any of them is pushed
    // to the engine. A store that cannot be read leaves the defaults.
    try {
      _applySettings(await _store.loadSettings());
      _customPresets = await _store.loadPresets();
    } catch (error) {
      debugPrint('Accel could not read its settings: $error');
    }
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
      await _metronome.setGapPattern(gapPattern);
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
    // Anything still waiting out the delay is written now, not dropped.
    if (_saveTimer?.isActive ?? false) unawaited(_saveSettings());
    _saveTimer?.cancel();
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
    await _enableBackground();
    _playing = true;
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_ready || !_playing) return;
    await _metronome.stop();
    await _disableBackground();
    _playing = false;
    _clearLive();
    notifyListeners();
  }

  /// Lets the metronome play on with the app in the background: a
  /// foreground service on Android, the audio session on iOS. Failing to
  /// get it must not keep the metronome from playing, so it is only
  /// logged — the click simply stops when Android reclaims the process.
  Future<void> _enableBackground() async {
    try {
      await _metronome.enableBackgroundPlayback(
        androidNotification: _backgroundNotification,
      );
    } on PlatformException catch (error) {
      debugPrint('Accel could not keep playing in the background: $error');
    }
  }

  /// Releases it again, so no notification outlives the click.
  Future<void> _disableBackground() async {
    try {
      await _metronome.disableBackgroundPlayback();
    } on PlatformException catch (error) {
      debugPrint('Accel could not release the background service: $error');
    }
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
    _settingsChanged();
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
    _settingsChanged();
  }

  /// Toggles one cell of the accent grid. [slot] is
  /// `beat * pulsesPerBeat + pulse`, so subdivision pulses can be accented
  /// as well as main beats.
  Future<void> setAccent(int slot, bool accented) async {
    if (slot < 0 || slot >= _pulseAccents.length) return;
    if (_pulseAccents[slot] == accented) return;
    _pulseAccents = List<bool>.of(_pulseAccents)..[slot] = accented;
    if (_ready) await _metronome.setAccentPattern(_pulseAccents);
    _settingsChanged();
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
    _settingsChanged();
  }

  Future<void> setVoice(MetronomeVoice voice) async {
    if (voice == _voice) return;
    _voice = voice;
    if (_ready) await _metronome.setVoice(voice);
    _settingsChanged();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped == _volume) return;
    _volume = clamped;
    if (_ready) await _metronome.setVolume(clamped);
    _settingsChanged();
  }

  /// Dynamic mode and the gap trainer both work the bar line, and running
  /// them together is out of scope for now, so each turns the other off.
  /// The cards disable the switch while the other one is playing, so this
  /// only ever happens between runs.
  Future<void> setDynamicMode(bool value) async {
    if (value == _dynamic) return;
    _dynamic = value;
    if (value && _gapEnabled) {
      _gapEnabled = false;
      await _pushGapPattern();
    }
    _settingsChanged();
  }

  void setStepMode(StepMode mode) {
    if (mode == _stepMode) return;
    _stepMode = mode;
    _settingsChanged();
  }

  void setBarsPerStep(int bars) {
    _barsPerStep = bars.clamp(minBarsPerStep, maxBarsPerStep);
    _settingsChanged();
  }

  void setStepDuration(Duration duration) {
    _stepDuration = duration < minStepDuration
        ? minStepDuration
        : duration > maxStepDuration
        ? maxStepDuration
        : duration;
    _settingsChanged();
  }

  void setStepBpm(double step) {
    _stepBpm = step.clamp(minStepBpm, maxStepBpm);
    _keepTargetAboveStart();
    _settingsChanged();
  }

  void setUseTarget(bool value) {
    _useTarget = value;
    _settingsChanged();
  }

  void setTargetBpm(double bpm) {
    _targetBpm = bpm.clamp(minBpm, maxBpm);
    _settingsChanged();
  }

  void setReturnToStart(bool value) {
    _returnToStart = value;
    _settingsChanged();
  }

  // ---------------------------------------------------- gap trainer setters

  Future<void> setGapEnabled(bool value) async {
    if (value == _gapEnabled) return;
    _gapEnabled = value;
    if (value) _dynamic = false;
    await _pushGapPattern();
    _settingsChanged();
  }

  Future<void> setGapMode(GapMode mode) =>
      _updateGap((gap) => gap.copyWith(mode: mode));

  Future<void> setGapClickBars(int bars) => _updateGap(
    (gap) => gap.copyWith(
      clickBars: bars.clamp(GapSettings.minBars, GapSettings.maxBars),
    ),
  );

  Future<void> setGapSilentBars(int bars) => _updateGap(
    (gap) => gap.copyWith(
      silentBars: bars.clamp(GapSettings.minBars, GapSettings.maxBars),
    ),
  );

  /// The chance snaps to the 5 % steps the slider offers.
  Future<void> setGapSilentChance(double chance) => _updateGap((gap) {
    final stepped =
        (chance / GapSettings.chanceStep).roundToDouble() *
        GapSettings.chanceStep;
    return gap.copyWith(
      silentChance: stepped.clamp(GapSettings.minChance, GapSettings.maxChance),
    );
  });

  Future<void> setGapMaxSilentRun(int bars) => _updateGap(
    (gap) => gap.copyWith(
      maxSilentRun: bars.clamp(GapSettings.minRun, GapSettings.maxRun),
    ),
  );

  Future<void> setGapStartSilentBars(int bars) => _updateGap((gap) {
    final start = bars.clamp(GapSettings.minBars, GapSettings.maxBars);
    // The ladder cannot top out below where it starts.
    return gap.copyWith(
      startSilentBars: start,
      maxSilentBars: gap.maxSilentBars < start ? start : gap.maxSilentBars,
    );
  });

  Future<void> setGapMaxSilentBars(int bars) => _updateGap(
    (gap) => gap.copyWith(
      maxSilentBars: bars.clamp(gap.startSilentBars, GapSettings.maxLadderBars),
    ),
  );

  Future<void> setGapCyclesPerStep(int cycles) => _updateGap(
    (gap) => gap.copyWith(
      cyclesPerStep: cycles.clamp(GapSettings.minCycles, GapSettings.maxCycles),
    ),
  );

  Future<void> setHideBeatWhenSilent(bool value) =>
      _updateGap((gap) => gap.copyWith(hideBeatWhenSilent: value));

  Future<void> setShowRemainingSilentBars(bool value) =>
      _updateGap((gap) => gap.copyWith(showRemainingSilentBars: value));

  // --------------------------------------------------------- gap presets

  /// Plays [preset]: its settings take over, and the trainer comes on.
  Future<void> applyGapPreset(GapPreset preset) async {
    _gapEnabled = true;
    _dynamic = false;
    _gap = preset.settings.clamped();
    await _pushGapPattern();
    _settingsChanged();
  }

  /// Saves the settings in play under [name]. A name already taken is
  /// overwritten, so saving twice leaves one preset, not two.
  Future<void> saveGapPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final preset = GapPreset(name: trimmed, settings: _gap);
    final taken = _customPresets.indexWhere((p) => p.name == trimmed);
    final next = [..._customPresets];
    if (taken < 0) {
      next.add(preset);
    } else {
      next[taken] = preset;
    }
    await _saveCustomPresets(next);
  }

  Future<void> renameGapPreset(GapPreset preset, String name) async {
    final trimmed = name.trim();
    final index = _customPresets.indexOf(preset);
    if (trimmed.isEmpty || index < 0) return;
    final next = [..._customPresets];
    next[index] = GapPreset(name: trimmed, settings: preset.settings);
    await _saveCustomPresets(next);
  }

  Future<void> deleteGapPreset(GapPreset preset) async {
    if (!_customPresets.contains(preset)) return;
    await _saveCustomPresets([..._customPresets]..remove(preset));
  }

  Future<void> _saveCustomPresets(List<GapPreset> presets) async {
    _customPresets = presets;
    notifyListeners();
    try {
      await _store.savePresets(presets);
    } catch (error) {
      debugPrint('Accel could not write its presets: $error');
    }
  }

  /// Applies [change] to the trainer's settings, hands the result to the
  /// engine and remembers it.
  Future<void> _updateGap(GapSettings Function(GapSettings gap) change) async {
    final next = change(_gap);
    if (next == _gap) return;
    _gap = next;
    await _pushGapPattern();
    _settingsChanged();
  }

  /// Gives the engine the pattern the settings describe — it silences the
  /// bars itself — and drops the preview the strip draws while stopped.
  Future<void> _pushGapPattern() async {
    _gapPreview = null;
    if (_ready) await _metronome.setGapPattern(gapPattern);
  }

  /// A ramp has to climb somewhere: when the start tempo catches up with
  /// the target, the target moves one step above it.
  void _keepTargetAboveStart() {
    if (_targetBpm <= _startBpm) {
      _targetBpm = (_startBpm + _stepBpm).clamp(minBpm, maxBpm);
    }
  }

  // --------------------------------------------------------- persistence

  /// Tells the widgets, and starts the clock on writing the settings. Live
  /// feedback (beats, ramp steps) notifies without it: nothing to store.
  void _settingsChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () => unawaited(_saveSettings()));
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      await _store.saveSettings(_toJson());
    } catch (error) {
      debugPrint('Accel could not write its settings: $error');
    }
  }

  Map<String, Object?> _toJson() => {
    'tempo': _startBpm,
    'numerator': _signature.numerator,
    'denominator': _signature.denominator,
    'beatsPerBar': _signature.beatsPerBar,
    'subdivision': _subdivision.name,
    'accents': _pulseAccents,
    'voice': _voice.name,
    'volume': _volume,
    'dynamic': _dynamic,
    'stepMode': _stepMode.name,
    'barsPerStep': _barsPerStep,
    'stepMs': _stepDuration.inMilliseconds,
    'stepBpm': _stepBpm,
    'useTarget': _useTarget,
    'targetBpm': _targetBpm,
    'returnToStart': _returnToStart,
    'gapEnabled': _gapEnabled,
    'gap': _gap.toJson(),
  };

  /// Reads back what [_toJson] wrote. Anything missing or unreadable keeps
  /// its default, so a half-written or older store still starts the app.
  void _applySettings(Map<String, Object?> json) {
    if (json.isEmpty) return;
    _startBpm = GapSettings.readDouble(
      json['tempo'],
      _startBpm,
    ).clamp(minBpm, maxBpm);
    try {
      _signature = TimeSignature.grouped(
        GapSettings.readInt(json['numerator'], _signature.numerator),
        GapSettings.readInt(json['denominator'], _signature.denominator),
        GapSettings.readInt(json['beatsPerBar'], _signature.beatsPerBar),
      );
    } on ArgumentError {
      // An impossible meter leaves the default in place.
    }
    _subdivision = Subdivision.values.firstWhere(
      (value) => value.name == json['subdivision'],
      orElse: () => _subdivision,
    );
    _voice = MetronomeVoice.values.firstWhere(
      (value) => value.name == json['voice'],
      orElse: () => _voice,
    );
    _volume = GapSettings.readDouble(json['volume'], _volume).clamp(0.0, 1.0);
    // The accents have to fit the meter they are read back into.
    final accents = json['accents'];
    final slots = _signature.beatsPerBar * _subdivision.pulsesPerBeat;
    _pulseAccents = accents is List && accents.length == slots
        ? [for (final accent in accents) accent == true]
        : List<bool>.generate(slots, (slot) => slot == 0);
    _dynamic = GapSettings.readBool(json['dynamic'], _dynamic);
    _stepMode = StepMode.values.firstWhere(
      (value) => value.name == json['stepMode'],
      orElse: () => _stepMode,
    );
    _barsPerStep = GapSettings.readInt(
      json['barsPerStep'],
      _barsPerStep,
    ).clamp(minBarsPerStep, maxBarsPerStep);
    final step = Duration(
      milliseconds: GapSettings.readInt(
        json['stepMs'],
        _stepDuration.inMilliseconds,
      ),
    );
    _stepDuration = step < minStepDuration
        ? minStepDuration
        : step > maxStepDuration
        ? maxStepDuration
        : step;
    _stepBpm = GapSettings.readDouble(
      json['stepBpm'],
      _stepBpm,
    ).clamp(minStepBpm, maxStepBpm);
    _useTarget = GapSettings.readBool(json['useTarget'], _useTarget);
    _targetBpm = GapSettings.readDouble(
      json['targetBpm'],
      _targetBpm,
    ).clamp(minBpm, maxBpm);
    _returnToStart = GapSettings.readBool(
      json['returnToStart'],
      _returnToStart,
    );
    _gapEnabled = GapSettings.readBool(json['gapEnabled'], _gapEnabled);
    if (json['gap'] case final Map<Object?, Object?> gap) {
      _gap = GapSettings.fromJson(gap.cast<String, Object?>());
    }
    // The two trainers take turns, whatever an older store may hold.
    if (_gapEnabled) _dynamic = false;
    _keepTargetAboveStart();
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
    // subdivision pulse. A silenced beat never fires it: a gap is meant to
    // feel like silence, not like a click with the sound turned down.
    if (beat.isMainBeat) {
      _lastBeat = beat;
      if (!beat.muted) _beatTick++;
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
      unawaited(_disableBackground());
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
