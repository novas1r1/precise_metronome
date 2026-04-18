import 'dart:collection';

/// Derives a BPM estimate from a series of user taps.
///
/// This is pure Dart — it does not touch the native engine. Feed it
/// timestamps (or call [tap] at the moment the user taps) and read
/// [bpm]. The estimator uses a moving window of recent intervals and
/// discards outliers so a single accidental tap does not ruin the
/// estimate.
///
/// Example:
/// ```dart
/// final tap = TapTempo();
/// // on each tap:
/// final bpm = tap.tap();
/// if (bpm != null) metronome.setTempo(bpm);
/// ```
class TapTempo {
  /// Maximum interval between consecutive taps before the series resets.
  final Duration maxInterval;

  /// How many recent intervals to average over.
  final int windowSize;

  /// Minimum number of taps before [bpm] returns a value.
  final int minTaps;

  final Queue<DateTime> _taps = Queue<DateTime>();

  TapTempo({
    this.maxInterval = const Duration(seconds: 2),
    this.windowSize = 6,
    this.minTaps = 2,
  }) : assert(windowSize >= 2),
       assert(minTaps >= 2);

  /// Registers a tap at [now] (defaults to `DateTime.now()`) and returns
  /// the current BPM estimate, or `null` if not enough taps have been
  /// collected yet.
  ///
  /// BPM is clamped to 20..400 to match the engine's valid range.
  double? tap([DateTime? now]) {
    now ??= DateTime.now();

    if (_taps.isNotEmpty &&
        now.difference(_taps.last) > maxInterval) {
      _taps.clear();
    }

    _taps.addLast(now);
    while (_taps.length > windowSize + 1) {
      _taps.removeFirst();
    }

    return bpm;
  }

  /// Current BPM estimate, or `null` if fewer than [minTaps] taps.
  double? get bpm {
    if (_taps.length < minTaps) return null;

    final taps = _taps.toList(growable: false);
    final intervals = <double>[];
    for (var i = 1; i < taps.length; i++) {
      intervals.add(
        taps[i].difference(taps[i - 1]).inMicroseconds / 1e6,
      );
    }
    if (intervals.isEmpty) return null;

    // Median-based average: sort, drop extremes if we have enough data.
    intervals.sort();
    late final List<double> filtered;
    if (intervals.length >= 4) {
      filtered = intervals.sublist(1, intervals.length - 1);
    } else {
      filtered = intervals;
    }
    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    if (mean <= 0) return null;

    final raw = 60.0 / mean;
    return raw.clamp(20.0, 400.0);
  }

  /// Clears the tap history.
  void reset() => _taps.clear();

  /// Number of taps currently in the rolling window.
  int get tapCount => _taps.length;
}
