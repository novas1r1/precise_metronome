import 'package:flutter_test/flutter_test.dart';

import 'package:precise_metronome/precise_metronome.dart';

void main() {
  group('TapTempo', () {
    test('returns null before minimum taps reached', () {
      final t = TapTempo();
      expect(t.tap(DateTime(2026, 1, 1, 0, 0, 0)), isNull);
    });

    test('computes BPM from evenly-spaced taps', () {
      final t = TapTempo();
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      // 500 ms between taps = 120 BPM.
      t.tap(start);
      final bpm = t.tap(start.add(const Duration(milliseconds: 500)));
      expect(bpm, isNotNull);
      expect(bpm, closeTo(120.0, 0.5));
    });

    test('handles tight tempo (200 BPM = 300 ms intervals)', () {
      final t = TapTempo();
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      t.tap(start);
      t.tap(start.add(const Duration(milliseconds: 300)));
      t.tap(start.add(const Duration(milliseconds: 600)));
      final bpm = t.tap(start.add(const Duration(milliseconds: 900)));
      expect(bpm, closeTo(200.0, 1.0));
    });

    test('resets when gap exceeds maxInterval', () {
      final t = TapTempo(maxInterval: const Duration(seconds: 1));
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      t.tap(start);
      t.tap(start.add(const Duration(milliseconds: 500))); // ~120 BPM
      // Long gap — should reset.
      t.tap(start.add(const Duration(seconds: 10)));
      // Only one tap in the new window → no BPM yet.
      expect(t.tapCount, 1);
    });

    test('discards extreme intervals when window large enough', () {
      final t = TapTempo();
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      // 500 ms, 500 ms, 500 ms, 1200 ms (outlier), 500 ms, 500 ms.
      t.tap(start);
      t.tap(start.add(const Duration(milliseconds: 500)));
      t.tap(start.add(const Duration(milliseconds: 1000)));
      t.tap(start.add(const Duration(milliseconds: 1500)));
      t.tap(start.add(const Duration(milliseconds: 2700))); // outlier
      t.tap(start.add(const Duration(milliseconds: 3200)));
      final bpm = t.tap(start.add(const Duration(milliseconds: 3700)));
      // Median-trimmed mean should stay near 120.
      expect(bpm, closeTo(120.0, 10.0));
    });

    test('clamps to 20..400 range', () {
      final t = TapTempo();
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      // Very fast taps — would compute >400 BPM raw.
      t.tap(start);
      t.tap(start.add(const Duration(milliseconds: 100)));
      final bpm = t.tap(start.add(const Duration(milliseconds: 200)));
      expect(bpm, lessThanOrEqualTo(400.0));
    });

    test('reset clears state', () {
      final t = TapTempo();
      t.tap(DateTime(2026, 1, 1));
      t.tap(DateTime(2026, 1, 1).add(const Duration(milliseconds: 500)));
      t.reset();
      expect(t.tapCount, 0);
      expect(t.bpm, isNull);
    });
  });
}
