import 'package:flutter_test/flutter_test.dart';

import 'package:precise_metronome/precise_metronome.dart';

void main() {
  group('TimeSignature — default grouping', () {
    test('simple meters click once per numerator beat', () {
      expect(TimeSignature(4, 4).beatsPerBar, 4);
      expect(TimeSignature(3, 4).beatsPerBar, 3);
      expect(TimeSignature(5, 4).beatsPerBar, 5);
      expect(TimeSignature(7, 8).beatsPerBar, 7);
    });

    test('compound meters (6/8, 9/8, 12/8) click dotted-quarters', () {
      expect(TimeSignature(6, 8).beatsPerBar, 2);
      expect(TimeSignature(9, 8).beatsPerBar, 3);
      expect(TimeSignature(12, 8).beatsPerBar, 4);
    });
  });

  group('TimeSignature.grouped — explicit grouping', () {
    test('overrides the default grouping', () {
      final sig = TimeSignature.grouped(6, 8, 6);
      expect(sig.beatsPerBar, 6);
      expect(sig.numerator, 6);
      expect(sig.denominator, 8);
    });

    test('allows 7/8 felt as 3 beats (2+2+3)', () {
      final sig = TimeSignature.grouped(7, 8, 3);
      expect(sig.beatsPerBar, 3);
    });
  });

  group('TimeSignature — validation', () {
    test('rejects invalid numerator', () {
      expect(() => TimeSignature(0, 4), throwsArgumentError);
      expect(() => TimeSignature(33, 4), throwsArgumentError);
    });

    test('rejects non-power-of-two denominators', () {
      expect(() => TimeSignature(4, 3), throwsArgumentError);
      expect(() => TimeSignature(4, 7), throwsArgumentError);
    });

    test('accepts standard denominators', () {
      for (final d in [1, 2, 4, 8, 16, 32]) {
        expect(() => TimeSignature(4, d), returnsNormally);
      }
    });
  });

  group('TimeSignature — equality', () {
    test('equal signatures compare equal', () {
      expect(TimeSignature(4, 4), equals(TimeSignature(4, 4)));
      expect(TimeSignature(6, 8), equals(TimeSignature(6, 8)));
    });

    test('different grouping makes signatures unequal', () {
      expect(TimeSignature(6, 8), isNot(equals(TimeSignature.grouped(6, 8, 6))));
    });
  });
}
