import 'dart:async';

import 'package:flutter/services.dart';

import 'background_config.dart';
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

  bool _initialized = false;
  bool _disposed = false;
  bool _isPlaying = false;

  double _bpm = 120.0;
  TimeSignature _timeSignature = TimeSignature(4, 4);
  List<bool> _accentPattern = const [true, false, false, false];
  MetronomeVoice _voice = MetronomeVoice.tone;
  double _volume = 0.8;

  /// Whether the metronome is currently producing clicks.
  bool get isPlaying => _isPlaying;

  /// Current tempo in BPM (rate of the audible beat).
  double get tempo => _bpm;

  /// Current time signature.
  TimeSignature get timeSignature => _timeSignature;

  /// Current accent pattern. Length always equals `timeSignature.beatsPerBar`.
  List<bool> get accentPattern => List.unmodifiable(_accentPattern);

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
  }

  /// Starts the metronome from bar position zero.
  Future<void> start() async {
    _assertReady();
    if (_isPlaying) return;
    await _channel.invokeMethod<void>('start');
    _isPlaying = true;
  }

  /// Stops the metronome. The next [start] will begin at bar position zero.
  Future<void> stop() async {
    _assertReady();
    if (!_isPlaying) return;
    await _channel.invokeMethod<void>('stop');
    _isPlaying = false;
  }

  /// Sets the tempo in beats per minute.
  ///
  /// [bpm] must be in the range 20.0..400.0. If the metronome is currently
  /// playing, the change takes effect at sample-accurate resolution at the
  /// next scheduling window (within ~25 ms).
  Future<void> setTempo(double bpm) async {
    _assertReady();
    if (bpm < 20.0 || bpm > 400.0) {
      throw ArgumentError.value(bpm, 'bpm', 'must be 20..400');
    }
    _bpm = bpm;
    await _channel.invokeMethod<void>('setTempo', {'bpm': bpm});
  }

  /// Sets the time signature and resets the accent pattern to a sensible
  /// default (accent on beat 1 only, all other beats unaccented).
  ///
  /// To keep or customize the accent pattern, call [setAccentPattern]
  /// after this.
  Future<void> setTimeSignature(TimeSignature signature) async {
    _assertReady();
    _timeSignature = signature;
    _accentPattern = List<bool>.generate(
      signature.beatsPerBar,
      (i) => i == 0,
    );
    await _channel.invokeMethod<void>('setTimeSignature', {
      'numerator': signature.numerator,
      'denominator': signature.denominator,
      'beatsPerBar': signature.beatsPerBar,
      'accentPattern': _accentPattern,
    });
  }

  /// Sets a custom accent pattern.
  ///
  /// Length must equal `timeSignature.beatsPerBar`. `true` = accent,
  /// `false` = normal.
  Future<void> setAccentPattern(List<bool> pattern) async {
    _assertReady();
    if (pattern.length != _timeSignature.beatsPerBar) {
      throw ArgumentError(
        'Accent pattern length (${pattern.length}) must equal '
        'timeSignature.beatsPerBar (${_timeSignature.beatsPerBar}).',
      );
    }
    _accentPattern = List<bool>.from(pattern);
    await _channel.invokeMethod<void>('setAccentPattern', {
      'accentPattern': _accentPattern,
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
  }

  // ---- internals ----

  Future<void> _pushState() async {
    await _channel.invokeMethod<void>('setTempo', {'bpm': _bpm});
    await _channel.invokeMethod<void>('setTimeSignature', {
      'numerator': _timeSignature.numerator,
      'denominator': _timeSignature.denominator,
      'beatsPerBar': _timeSignature.beatsPerBar,
      'accentPattern': _accentPattern,
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
