import 'dart:async';

import 'package:flutter/services.dart';

import 'background_config.dart';
import 'beat_event.dart';
import 'subdivision.dart';
import 'tempo_ramp.dart';
import 'time_signature.dart';
import 'voice.dart';

/// Sample-accurate metronome controller.
///
/// All timing happens on the native side — this class only sends state
/// commands (start, stop, tempo, meter, accent pattern). Dart GC pauses
/// cannot affect click timing.
///
/// A [Metronome] instance wraps a single native audio engine. Call
/// [init] once before any other method. Call [dispose] to release
/// native resources when you are done.
///
/// Example:
/// ```dart
/// final metronome = Metronome();
/// await metronome.init();
/// await metronome.setTempo(120);
/// await metronome.setTimeSignature(TimeSignature(7, 8));
/// await metronome.start();
/// // ... later
/// await metronome.stop();
/// await metronome.dispose();
/// ```
class Metronome {
  static const MethodChannel _channel = MethodChannel('precise_metronome');
  static const EventChannel _rampChannel =
      EventChannel('precise_metronome/ramp');

  bool _initialized = false;
  bool _disposed = false;
  bool _isPlaying = false;

  TempoRamp? _activeRamp;
  StreamSubscription<dynamic>? _rampSubscription;
  final StreamController<RampProgress> _rampController =
      StreamController<RampProgress>.broadcast();

  static const EventChannel _beatChannel =
      EventChannel('precise_metronome/beats');
  StreamSubscription<dynamic>? _beatSubscription;
  late final StreamController<BeatEvent> _beatController =
      StreamController<BeatEvent>.broadcast(
    onListen: _enableBeatEvents,
    onCancel: _disableBeatEvents,
  );
  bool _includeSubdivisions = false;

  double _bpm = 120.0;
  TimeSignature _timeSignature = TimeSignature(4, 4);
  /// One flag per pulse of the bar: `beat * pulsesPerBeat + pulse`.
  List<bool> _pulseAccents = const [true, false, false, false];
  bool _accentEnabled = true;
  int _accentBeat = 0;
  Subdivision _subdivision = Subdivision.none;
  MetronomeVoice _voice = MetronomeVoice.tone;
  double _volume = 0.8;

  /// Whether the metronome is currently producing clicks.
  bool get isPlaying => _isPlaying;

  /// Current tempo in BPM (rate of the audible beat).
  ///
  /// While a [TempoRamp] is running this follows the ramp: it is updated
  /// each time a [RampProgress] event arrives.
  double get tempo => _bpm;

  /// The ramp started by [startRamp], or `null` when playing normally or
  /// stopped.
  TempoRamp? get activeRamp => _activeRamp;

  /// Progress of the running [TempoRamp].
  ///
  /// Emits once at every tempo step (including the first, right after
  /// [startRamp]) and once more with `finished == true` when the goal
  /// tempo has been played out and the metronome stopped itself. Nothing
  /// is emitted while playing without a ramp.
  Stream<RampProgress> get rampProgress => _rampController.stream;

  /// Every audible pulse, delivered as close as the platform allows to the
  /// moment it is heard (typically 2–10 ms behind the audio on iOS, 10–25 ms
  /// on Android — well below what the eye can notice).
  ///
  /// Native emission is switched on while this stream has listeners and
  /// off again when the last one cancels, so an idle app pays nothing.
  /// By default only main beats are sent; see [setBeatEventOptions] to
  /// include subdivision pulses.
  ///
  /// The events are meant for UI feedback (beat indicators, bar counters),
  /// not for driving audio — clicks are scheduled natively and never wait
  /// for Dart.
  Stream<BeatEvent> get beats => _beatController.stream;

  /// Whether [beats] also delivers subdivision pulses (`pulseIndex > 0`).
  bool get includeSubdivisionsInBeats => _includeSubdivisions;

  /// Configures which pulses [beats] delivers. With
  /// [includeSubdivisions] `false` (the default) only main beats are sent.
  Future<void> setBeatEventOptions({required bool includeSubdivisions}) async {
    _assertReady();
    _includeSubdivisions = includeSubdivisions;
    if (_beatController.hasListener) {
      await _pushBeatEventOptions();
    }
  }

  /// Current time signature.
  TimeSignature get timeSignature => _timeSignature;

  /// Current accent pattern, one flag per main beat. Length always equals
  /// `timeSignature.beatsPerBar`. A beat counts as accented when its own
  /// pulse is; see [pulseAccents] for accents on subdivision pulses.
  List<bool> get accentPattern => List<bool>.unmodifiable(
    List<bool>.generate(
      _timeSignature.beatsPerBar,
      (beat) => _pulseAccents[beat * _subdivision.pulsesPerBeat],
    ),
  );

  /// Current accent pattern, one flag per audible pulse of the bar, indexed
  /// `beat * subdivision.pulsesPerBeat + pulse`. Length always equals
  /// `timeSignature.beatsPerBar * subdivision.pulsesPerBeat`.
  List<bool> get pulseAccents => List.unmodifiable(_pulseAccents);

  /// Whether any pulse in the bar is accented.
  ///
  /// `false` means every beat uses the normal click, so the metronome
  /// sounds completely even. See [setAccentEnabled].
  bool get accentEnabled => _accentEnabled;

  /// The beat the single accent sits on (0-based), as set by
  /// [setAccentBeat] and restored by `setAccentEnabled(true)`.
  ///
  /// When a richer pattern has been set via [setAccentPattern] this keeps
  /// its last single-accent value; it only tracks patterns whose one accent
  /// sits on a main beat.
  int get accentBeat => _accentBeat;

  /// Current subdivision. Each main beat is split into
  /// `subdivision.pulsesPerBeat` pulses; the first pulse of each beat
  /// uses the accent/normal click, remaining pulses use a softer
  /// "sub" click.
  Subdivision get subdivision => _subdivision;

  /// Current click voice.
  MetronomeVoice get voice => _voice;

  /// Current output gain (0.0..1.0, linear).
  double get volume => _volume;

  /// Initializes the native audio engine.
  ///
  /// Must be called before any other method. Safe to call once; subsequent
  /// calls are no-ops. Throws if the native engine fails to start.
  Future<void> init() async {
    _assertNotDisposed();
    if (_initialized) return;
    await _channel.invokeMethod<void>('init');
    _initialized = true;
    // Push initial state so native matches Dart defaults even before the
    // user sets anything.
    await _pushState();
    // A listener may have subscribed to `beats` before init().
    if (_beatController.hasListener) await _enableBeatEvents();
  }

  /// Starts the metronome from bar position zero.
  ///
  /// If [initialDelay] is non-zero, the first click fires that much later
  /// than it otherwise would — useful for aligning the click grid with
  /// external audio whose first beat does not coincide with "now".
  /// [initialDelay] must not be negative; it is applied with sample
  /// accuracy on the native side.
  Future<void> start({Duration initialDelay = Duration.zero}) async {
    _assertReady();
    if (_isPlaying) return;
    if (initialDelay.isNegative) {
      throw ArgumentError.value(
        initialDelay,
        'initialDelay',
        'must not be negative',
      );
    }
    await _channel.invokeMethod<void>('start', {
      'initialDelayMs': initialDelay.inMilliseconds,
    });
    _isPlaying = true;
  }

  /// Starts a progressive tempo ramp from bar position zero.
  ///
  /// The tempo is set to `ramp.startBpm`, held for one `ramp.stepLength`
  /// (a number of bars, or a duration that ends at the next bar line), then
  /// moved `ramp.stepBpm` towards `ramp.goalBpm` — exactly on the bar
  /// line, sample-accurately, on the native side. When the goal tempo has
  /// been played for its step the metronome stops itself and [isPlaying]
  /// becomes `false`. Listen to [rampProgress] to follow the steps.
  ///
  /// With `ramp.holdAtGoal` the metronome keeps clicking at the ramp's final
  /// tempo instead of stopping; [activeRamp] stays set and the last
  /// [RampProgress] is the final step (`isLastStep`). End it with [stop].
  ///
  /// With `ramp.returnToStart` the ramp turns around once the goal has been
  /// played out and steps back down to `ramp.startBpm`. The turnaround is
  /// handled by the same native ramp — the metronome does not stop and
  /// restart — so it lands on the bar line as accurately as every other
  /// step. [RampProgress.stepIndex] keeps counting through both legs.
  ///
  /// An open-ended ramp (`ramp.goalBpm == null`) keeps stepping up until
  /// [TempoRamp.maxBpm], holds there, and only ends with [stop].
  ///
  /// [initialDelay] behaves as in [start]. Calling [setTempo] while a
  /// ramp runs only lasts until the next step; call [stop] to abort the
  /// ramp early.
  Future<void> startRamp(
    TempoRamp ramp, {
    Duration initialDelay = Duration.zero,
  }) async {
    _assertReady();
    if (_isPlaying) return;
    if (initialDelay.isNegative) {
      throw ArgumentError.value(
        initialDelay,
        'initialDelay',
        'must not be negative',
      );
    }
    _activeRamp = ramp;
    _bpm = ramp.startBpm;
    _rampSubscription ??= _rampChannel.receiveBroadcastStream().listen(
      _onRampEvent,
      // Ramp events are informational; surface the error on the stream
      // but keep the metronome usable.
      onError: _rampController.addError,
    );
    await _channel.invokeMethod<void>('startRamp', {
      'initialDelayMs': initialDelay.inMilliseconds,
      ...ramp.toMap(),
    });
    _isPlaying = true;
    _rampController.add(RampProgress(
      stepIndex: 0,
      totalSteps: ramp.isOpenEnded ? null : ramp.totalSteps,
      bpm: ramp.startBpm,
      finished: false,
    ));
  }

  /// Shifts the phase of all future clicks by [delta] while playing.
  ///
  /// Positive values move clicks later, negative values earlier. The bar
  /// position (beat/pulse counters) is unaffected — only the click grid
  /// moves. If the shifted position would collide with an already-scheduled
  /// click or land in the past, the native side rolls forward by whole
  /// pulse periods (phase-equivalent), so clicks never double-fire.
  ///
  /// No-op when the metronome is stopped.
  Future<void> nudge(Duration delta) async {
    _assertReady();
    if (!_isPlaying) return;
    await _channel.invokeMethod<void>('nudge', {
      'deltaMs': delta.inMilliseconds,
    });
  }

  /// Stops the metronome. The next [start] will begin at bar position zero.
  Future<void> stop() async {
    _assertReady();
    if (!_isPlaying) return;
    await _channel.invokeMethod<void>('stop');
    _isPlaying = false;
    _activeRamp = null;
  }

  /// Sets the tempo in beats per minute.
  ///
  /// [bpm] must be in the range 20.0..400.0. If the metronome is currently
  /// playing, the change takes effect at sample-accurate resolution at the
  /// next scheduling window (within ~25 ms).
  ///
  /// Tempo changes are phase-preserving: the already-scheduled next click
  /// keeps its time, and only the interval between subsequent clicks
  /// changes. Sweeping the tempo (e.g. from a slider) therefore never
  /// causes clicks to jump, double-fire, or drop.
  Future<void> setTempo(double bpm) async {
    _assertReady();
    if (bpm < 20.0 || bpm > 400.0) {
      throw ArgumentError.value(bpm, 'bpm', 'must be 20..400');
    }
    _bpm = bpm;
    await _channel.invokeMethod<void>('setTempo', {'bpm': bpm});
  }

  /// Sets the time signature and resets any custom accent pattern to a
  /// single accent.
  ///
  /// [accentEnabled] and [accentBeat] survive the change: with accents
  /// disabled the new bar stays even, and the accent keeps its beat as
  /// long as that beat exists in the new bar (otherwise it falls back to
  /// beat 1).
  ///
  /// To customize the accent pattern, call [setAccentPattern] after this.
  Future<void> setTimeSignature(TimeSignature signature) async {
    _assertReady();
    _timeSignature = signature;
    if (_accentBeat >= signature.beatsPerBar) _accentBeat = 0;
    _pulseAccents = _singleAccentPulses();
    await _channel.invokeMethod<void>('setTimeSignature', {
      'numerator': signature.numerator,
      'denominator': signature.denominator,
      'beatsPerBar': signature.beatsPerBar,
      'accentPattern': _pulseAccents,
    });
  }

  /// Sets a custom accent pattern. `true` = accent, `false` = normal.
  ///
  /// The length selects what a flag refers to:
  ///
  /// * `timeSignature.beatsPerBar` — one flag per main beat. Subdivision
  ///   pulses keep the softer sub click.
  /// * `timeSignature.beatsPerBar * subdivision.pulsesPerBeat` — one flag
  ///   per audible pulse, indexed `beat * pulsesPerBeat + pulse`, so
  ///   subdivision pulses can carry the accent click too.
  ///
  /// With [Subdivision.none] the two are the same length and mean the same
  /// thing. Changing the subdivision keeps the main-beat accents and clears
  /// any accents that were set on subdivision pulses.
  Future<void> setAccentPattern(List<bool> pattern) async {
    _assertReady();
    final beats = _timeSignature.beatsPerBar;
    final pulses = _subdivision.pulsesPerBeat;
    if (pattern.length == beats) {
      _pulseAccents = _expandToPulses(pattern, pulses);
    } else if (pattern.length == beats * pulses) {
      _pulseAccents = List<bool>.from(pattern);
    } else {
      throw ArgumentError(
        'Accent pattern length (${pattern.length}) must equal '
        'timeSignature.beatsPerBar ($beats) or '
        'timeSignature.beatsPerBar * subdivision.pulsesPerBeat '
        '(${beats * pulses}).',
      );
    }
    _syncSingleAccent();
    await _channel.invokeMethod<void>('setAccentPattern', {
      'accentPattern': _pulseAccents,
    });
  }

  /// Enables or disables the accent.
  ///
  /// With [enabled] `false` every beat uses the normal click, so the bar
  /// sounds completely even. With `true` the accent returns to the beat it
  /// was on before (see [accentBeat]; beat 1 by default). Accents that a
  /// richer [setAccentPattern] had placed elsewhere are not restored.
  ///
  /// Takes effect at the next pulse, like [setAccentPattern].
  Future<void> setAccentEnabled(bool enabled) async {
    _assertReady();
    _accentEnabled = enabled;
    _pulseAccents = _singleAccentPulses();
    await _channel.invokeMethod<void>('setAccentPattern', {
      'accentPattern': _pulseAccents,
    });
  }

  /// Puts the single accent on [beatIndex] (0-based) and removes it from
  /// every other pulse.
  ///
  /// [beatIndex] must be less than `timeSignature.beatsPerBar` — in 4/4
  /// the valid positions are 0..3, in 3/4 they are 0..2. Calling this also
  /// re-enables the accent if it was disabled.
  ///
  /// For more than one accent per bar, or an accent on a subdivision
  /// pulse, use [setAccentPattern].
  Future<void> setAccentBeat(int beatIndex) async {
    _assertReady();
    if (beatIndex < 0 || beatIndex >= _timeSignature.beatsPerBar) {
      throw ArgumentError.value(
        beatIndex,
        'beatIndex',
        'must be 0..${_timeSignature.beatsPerBar - 1} '
            '(timeSignature.beatsPerBar is ${_timeSignature.beatsPerBar})',
      );
    }
    _accentBeat = beatIndex;
    _accentEnabled = true;
    _pulseAccents = _singleAccentPulses();
    await _channel.invokeMethod<void>('setAccentPattern', {
      'accentPattern': _pulseAccents,
    });
  }

  /// The pulse grid for the current single-accent state: one accent on
  /// [accentBeat]'s own pulse, or nothing at all when disabled.
  List<bool> _singleAccentPulses() {
    final pulses = _subdivision.pulsesPerBeat;
    return List<bool>.generate(
      _timeSignature.beatsPerBar * pulses,
      (i) => _accentEnabled && i == _accentBeat * pulses,
    );
  }

  /// Keeps [accentEnabled] and [accentBeat] in step with the pattern that
  /// was just set. A lone accent on a main beat moves [accentBeat]; a lone
  /// accent on a subdivision pulse, or several accents, leave it alone.
  void _syncSingleAccent() {
    _accentEnabled = _pulseAccents.contains(true);
    if (_pulseAccents.where((a) => a).length != 1) return;
    final slot = _pulseAccents.indexOf(true);
    final pulses = _subdivision.pulsesPerBeat;
    if (slot % pulses == 0) _accentBeat = slot ~/ pulses;
  }

  /// Spreads one flag per beat over [pulsesPerBeat] pulses: the beat's own
  /// pulse keeps the flag, the pulses in between are unaccented.
  static List<bool> _expandToPulses(List<bool> perBeat, int pulsesPerBeat) {
    return List<bool>.generate(
      perBeat.length * pulsesPerBeat,
      (i) => i % pulsesPerBeat == 0 && perBeat[i ~/ pulsesPerBeat],
    );
  }

  /// Sets the subdivision — how each main beat is split into audible
  /// pulses.
  ///
  /// Pulses carrying an accent (see [setAccentPattern]) use the accent
  /// click; other main beats use the normal click and the pulses in
  /// between use a softer "sub" click. The tempo continues to refer to the
  /// main-beat rate.
  ///
  /// The accent pattern is rescaled to the new pulse grid: main-beat
  /// accents are kept and any accents on subdivision pulses are cleared,
  /// since those slots no longer line up.
  ///
  /// See [Subdivision] for the available options. Changes take effect
  /// at the next pulse boundary (within one main-beat interval).
  Future<void> setSubdivision(Subdivision subdivision) async {
    _assertReady();
    if (subdivision != _subdivision) {
      final perBeat = accentPattern;
      _subdivision = subdivision;
      _pulseAccents = _expandToPulses(perBeat, subdivision.pulsesPerBeat);
    }
    await _channel.invokeMethod<void>('setSubdivision', {
      'pulsesPerBeat': subdivision.pulsesPerBeat,
    });
    await _channel.invokeMethod<void>('setAccentPattern', {
      'accentPattern': _pulseAccents,
    });
  }

  /// Switches between the built-in voices.
  Future<void> setVoice(MetronomeVoice voice) async {
    _assertReady();
    _voice = voice;
    await _channel.invokeMethod<void>('setVoice', {'voice': voice.wireName});
  }

  /// Sets the output gain in the range 0.0..1.0 (linear).
  Future<void> setVolume(double volume) async {
    _assertReady();
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError.value(volume, 'volume', 'must be 0..1');
    }
    _volume = volume;
    await _channel.invokeMethod<void>('setVolume', {'volume': volume});
  }

  /// Enables background playback.
  ///
  /// On iOS this activates the audio session's playback category and the
  /// app will continue producing clicks when backgrounded (requires
  /// `UIBackgroundModes` to include `audio` in your `Info.plist`).
  ///
  /// On Android this starts a foreground service with a visible
  /// notification. The user can stop the service from the notification.
  /// You must declare the `FOREGROUND_SERVICE` and
  /// `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (API 34+) permissions in your
  /// app's `AndroidManifest.xml` — see the README.
  ///
  /// Call [disableBackgroundPlayback] to release the foreground service.
  Future<void> enableBackgroundPlayback({
    AndroidNotificationConfig androidNotification =
        const AndroidNotificationConfig(),
  }) async {
    _assertReady();
    await _channel.invokeMethod<void>('enableBackgroundPlayback', {
      'android': androidNotification.toMap(),
    });
  }

  /// Disables background playback and releases the Android foreground
  /// service (no-op on iOS beyond deactivating the session).
  Future<void> disableBackgroundPlayback() async {
    _assertReady();
    await _channel.invokeMethod<void>('disableBackgroundPlayback');
  }

  /// Releases native resources. The instance is unusable after this.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_initialized) {
      try {
        await _channel.invokeMethod<void>('dispose');
      } catch (_) {
        // Swallow — we're tearing down anyway.
      }
    }
    _initialized = false;
    _isPlaying = false;
    _activeRamp = null;
    await _rampSubscription?.cancel();
    _rampSubscription = null;
    await _rampController.close();
    await _beatSubscription?.cancel();
    _beatSubscription = null;
    await _beatController.close();
  }

  // ---- internals ----

  Future<void> _enableBeatEvents() async {
    if (_disposed || !_initialized) return;
    _beatSubscription ??= _beatChannel.receiveBroadcastStream().listen(
      _onBeatEvent,
      onError: _beatController.addError,
    );
    await _pushBeatEventOptions();
  }

  Future<void> _disableBeatEvents() async {
    await _beatSubscription?.cancel();
    _beatSubscription = null;
    if (_disposed || !_initialized) return;
    await _channel.invokeMethod<void>('setBeatEvents', {
      'enabled': false,
      'includeSubdivisions': _includeSubdivisions,
    });
  }

  Future<void> _pushBeatEventOptions() {
    return _channel.invokeMethod<void>('setBeatEvents', {
      'enabled': true,
      'includeSubdivisions': _includeSubdivisions,
    });
  }

  void _onBeatEvent(dynamic event) {
    if (event is! Map) return;
    _beatController.add(BeatEvent(
      barIndex: (event['bar'] as num?)?.toInt() ?? 0,
      beatIndex: (event['beat'] as num?)?.toInt() ?? 0,
      pulseIndex: (event['pulse'] as num?)?.toInt() ?? 0,
      accent: event['accent'] == true,
    ));
  }

  void _onRampEvent(dynamic event) {
    final ramp = _activeRamp;
    if (ramp == null || event is! Map) return;
    final stepIndex = (event['stepIndex'] as num?)?.toInt() ?? 0;
    final finished = event['finished'] == true;
    final bpm = (event['bpm'] as num?)?.toDouble() ?? ramp.bpmAt(stepIndex);
    _bpm = bpm;
    if (finished) {
      _isPlaying = false;
      _activeRamp = null;
    }
    _rampController.add(RampProgress(
      stepIndex: stepIndex,
      totalSteps: ramp.isOpenEnded ? null : ramp.totalSteps,
      bpm: bpm,
      finished: finished,
    ));
  }

  Future<void> _pushState() async {
    await _channel.invokeMethod<void>('setTempo', {'bpm': _bpm});
    await _channel.invokeMethod<void>('setTimeSignature', {
      'numerator': _timeSignature.numerator,
      'denominator': _timeSignature.denominator,
      'beatsPerBar': _timeSignature.beatsPerBar,
      'accentPattern': _pulseAccents,
    });
    await _channel.invokeMethod<void>('setSubdivision', {
      'pulsesPerBeat': _subdivision.pulsesPerBeat,
    });
    await _channel.invokeMethod<void>('setVoice', {'voice': _voice.wireName});
    await _channel.invokeMethod<void>('setVolume', {'volume': _volume});
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('Metronome has been disposed.');
    }
  }

  void _assertReady() {
    _assertNotDisposed();
    if (!_initialized) {
      throw StateError('Metronome.init() must be called first.');
    }
  }
}
