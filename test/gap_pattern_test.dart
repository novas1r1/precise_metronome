import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

/// [count] bars of [bars] from bar [from] on: `C` for a bar that clicks,
/// `.` for a silent one.
String _play(GapPatternGenerator bars, int count, {int from = 0}) => [
  for (var i = from; i < from + count; i++) bars.barAt(i).silent ? '.' : 'C',
].join();

/// Long-run share of silent bars for a random pattern with silent
/// probability [p] and a cap of [cap] silent bars in a row.
///
/// The length of the silent run after each bar is a Markov chain on
/// 0..cap. Below the cap the next bar is silent with probability p (the
/// run grows by one) or clicks (the run drops to 0); at the cap it always
/// clicks. Balancing the flow into each run length gives
/// π(r) = p^r · π(0), so the silent share is Σ p^r for r = 1..cap over
/// Σ p^r for r = 0..cap, which is p(1 − p^cap) / (1 − p^(cap + 1)).
double _expectedSilentShare(double p, int cap) =>
    p * (1 - math.pow(p, cap)) / (1 - math.pow(p, cap + 1));

void main() {
  group('GapPattern', () {
    test('rejects counts below one', () {
      expect(
        () => GapPattern.fixed(clickBars: 0, silentBars: 2),
        throwsArgumentError,
      );
      expect(
        () => GapPattern.fixed(clickBars: 2, silentBars: 0),
        throwsArgumentError,
      );
      expect(
        () => GapPattern.ladder(
          clickBars: 0,
          startSilentBars: 1,
          maxSilentBars: 4,
          cyclesPerStep: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 0,
          maxSilentBars: 4,
          cyclesPerStep: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 1,
          maxSilentBars: 4,
          cyclesPerStep: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            GapPattern.random(silentProbability: 0.3, maxConsecutiveSilent: 0),
        throwsArgumentError,
      );
    });

    test('a ladder cannot top out below where it starts', () {
      expect(
        () => GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 3,
          maxSilentBars: 2,
          cyclesPerStep: 1,
        ),
        throwsArgumentError,
      );
      expect(
        GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 3,
          maxSilentBars: 3,
          cyclesPerStep: 1,
        ),
        isA<LadderGapPattern>(),
      );
    });

    test('a random probability must be 0..1', () {
      for (final p in [-0.01, 1.01, double.nan]) {
        expect(
          () =>
              GapPattern.random(silentProbability: p, maxConsecutiveSilent: 2),
          throwsArgumentError,
          reason: 'p = $p',
        );
      }
      for (final p in [0.0, 1.0]) {
        expect(
          GapPattern.random(silentProbability: p, maxConsecutiveSilent: 2),
          isA<RandomGapPattern>(),
        );
      }
    });

    test('compares by value', () {
      final a = GapPattern.fixed(clickBars: 2, silentBars: 2);
      final b = GapPattern.fixed(clickBars: 2, silentBars: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(GapPattern.fixed(clickBars: 2, silentBars: 3)));
      expect(
        GapPattern.fixed(clickBars: 2, silentBars: 1),
        isNot(
          GapPattern.ladder(
            clickBars: 2,
            startSilentBars: 1,
            maxSilentBars: 1,
            cyclesPerStep: 1,
          ),
        ),
      );
      expect(
        GapPattern.random(silentProbability: 0.3, maxConsecutiveSilent: 2),
        GapPattern.random(silentProbability: 0.3, maxConsecutiveSilent: 2),
      );
    });
  });

  group('GapPatternGenerator, fixed', () {
    test('alternates click and silent phases', () {
      final bars = GapPatternGenerator(
        GapPattern.fixed(clickBars: 2, silentBars: 2),
      );
      expect(_play(bars, 8), 'CC..CC..');
    });

    test('plays a long click phase and a single silent bar', () {
      final bars = GapPatternGenerator(
        GapPattern.fixed(clickBars: 4, silentBars: 1),
      );
      expect(_play(bars, 10), 'CCCC.CCCC.');
    });

    test('answers the same for a bar asked out of order', () {
      final pattern = GapPattern.fixed(clickBars: 3, silentBars: 2);
      final inOrder = _play(GapPatternGenerator(pattern), 12);
      final bars = GapPatternGenerator(pattern);
      expect(bars.barAt(11).silent, isFalse);
      expect(bars.barAt(4).silent, isTrue);
      expect(_play(bars, 12), inOrder);
    });
  });

  group('GapPatternGenerator, ladder', () {
    test('grows the gap every few cycles and holds it at the maximum', () {
      final bars = GapPatternGenerator(
        GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 1,
          maxSilentBars: 3,
          cyclesPerStep: 2,
        ),
      );
      expect(
        _play(bars, 29),
        'CC.'
        'CC.'
        'CC..'
        'CC..'
        'CC...'
        'CC...'
        'CC...',
      );
    });

    test('grows every cycle when cyclesPerStep is 1', () {
      final bars = GapPatternGenerator(
        GapPattern.ladder(
          clickBars: 1,
          startSilentBars: 1,
          maxSilentBars: 3,
          cyclesPerStep: 1,
        ),
      );
      expect(
        _play(bars, 13),
        'C.'
        'C..'
        'C...'
        'C...',
      );
    });

    test('plays like a fixed pattern when it starts at its maximum', () {
      final ladder = GapPatternGenerator(
        GapPattern.ladder(
          clickBars: 2,
          startSilentBars: 2,
          maxSilentBars: 2,
          cyclesPerStep: 3,
        ),
      );
      final fixed = GapPatternGenerator(
        GapPattern.fixed(clickBars: 2, silentBars: 2),
      );
      expect(_play(ladder, 24), _play(fixed, 24));
    });
  });

  group('GapPatternGenerator, random', () {
    test('with certain silence, bar 0 clicks and the cap decides the rest', () {
      final bars = GapPatternGenerator(
        GapPattern.random(silentProbability: 1, maxConsecutiveSilent: 2),
      );
      expect(_play(bars, 9), 'C..C..C..');
    });

    test('with zero probability never goes silent', () {
      final bars = GapPatternGenerator(
        GapPattern.random(silentProbability: 0, maxConsecutiveSilent: 4),
        random: math.Random(1),
      );
      expect(_play(bars, 1000), 'C' * 1000);
    });

    test('never runs longer than the cap', () {
      final bars = GapPatternGenerator(
        GapPattern.random(silentProbability: 0.8, maxConsecutiveSilent: 2),
        random: math.Random(1),
      );
      final played = _play(bars, 10000);
      expect(played, contains('..'));
      expect(played, isNot(contains('...')));
    });

    test('plays the same bars for the same seed', () {
      final pattern = GapPattern.random(
        silentProbability: 0.4,
        maxConsecutiveSilent: 3,
      );
      final first = GapPatternGenerator(pattern, random: math.Random(42));
      final second = GapPatternGenerator(pattern, random: math.Random(42));
      expect(_play(first, 500), _play(second, 500));
    });

    test('silences the share the probability and the cap predict', () {
      // The tolerance is five standard deviations of the share over
      // 10,000 independent bars. The cap makes neighbouring bars depend on
      // each other, but only by forcing a click after a full run, which
      // spreads the silent bars out more evenly and makes the true spread
      // smaller, not larger. A band this wide fails by chance less than
      // once in a million seeds.
      //
      // For p = 0.3 and a cap of 4 the cap lowers the share only from
      // 0.300 to 0.298, which 10,000 bars cannot resolve, so the test
      // compares against the exact expectation rather than asserting
      // "below p". The lower caps show the effect clearly.
      const count = 10000;
      for (final (p, cap) in [(0.3, 4), (0.3, 1), (0.8, 2)]) {
        final bars = GapPatternGenerator(
          GapPattern.random(silentProbability: p, maxConsecutiveSilent: cap),
          random: math.Random(7),
        );
        final share = '.'.allMatches(_play(bars, count)).length / count;
        final expected = _expectedSilentShare(p, cap);
        final sd = math.sqrt(expected * (1 - expected) / count);
        expect(share, closeTo(expected, 5 * sd), reason: 'p $p, cap $cap');
        expect(share, greaterThan(0.2), reason: 'p $p, cap $cap');
      }
      expect(_expectedSilentShare(0.3, 1), lessThan(0.24));
      expect(_expectedSilentShare(0.8, 2), lessThan(0.6));
    });
  });

  group('GapPatternGenerator, landing', () {
    test('marks the first click after every gap', () {
      final bars = GapPatternGenerator(
        GapPattern.fixed(clickBars: 2, silentBars: 2),
      );
      expect(
        [
          for (var i = 0; i < 10; i++)
            if (bars.barAt(i).landing) i,
        ],
        [4, 8],
      );
    });

    test('is exactly a click that follows a silent bar', () {
      final bars = GapPatternGenerator(
        GapPattern.random(silentProbability: 0.5, maxConsecutiveSilent: 3),
        random: math.Random(3),
      );
      final played = _play(bars, 10000);
      for (var i = 0; i < played.length; i++) {
        final expected = i > 0 && played[i] == 'C' && played[i - 1] == '.';
        expect(bars.barAt(i).landing, expected, reason: 'bar $i');
      }
    });

    test('never falls on bar 0', () {
      final patterns = [
        GapPattern.fixed(clickBars: 1, silentBars: 1),
        GapPattern.ladder(
          clickBars: 1,
          startSilentBars: 1,
          maxSilentBars: 2,
          cyclesPerStep: 1,
        ),
        GapPattern.random(silentProbability: 1, maxConsecutiveSilent: 1),
      ];
      for (final pattern in patterns) {
        final bar = GapPatternGenerator(pattern).barAt(0);
        expect(bar, const GapBar(index: 0, silent: false, landing: false));
      }
    });
  });
}
