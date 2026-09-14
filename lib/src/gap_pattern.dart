import 'dart:math' as math;

/// Which bars of a running metronome go silent while the clock keeps
/// counting: the pattern behind a gap click trainer.
///
/// Nothing sounds in a silent bar, subdivision pulses included, but tempo
/// and bar position carry on unchanged. When the click comes back it lands
/// exactly on the grid, so the player hears whether they held the tempo
/// through the gap.
///
/// * [GapPattern.fixed]: a few bars of click, then a few silent bars,
///   repeating.
/// * [GapPattern.ladder]: like [GapPattern.fixed], but the gap grows by one
///   bar every few cycles, up to a limit.
/// * [GapPattern.random]: each bar is silent by chance, with a cap on how
///   many silent bars may follow each other.
///
/// Bars are counted from 0, the first bar after the metronome starts, and
/// every pattern opens with an audible bar. [GapPatternGenerator] works out
/// which bars a pattern silences.
sealed class GapPattern {
  const GapPattern._();

  /// [clickBars] audible bars, then [silentBars] silent bars, repeating.
  /// Both must be >= 1.
  factory GapPattern.fixed({required int clickBars, required int silentBars}) =
      FixedGapPattern;

  /// [clickBars] audible bars followed by a gap of [startSilentBars] silent
  /// bars, repeating. After every [cyclesPerStep] cycles the gap grows by
  /// one bar until it is [maxSilentBars] long, and stays there. A cycle is
  /// one click phase plus the gap that follows it.
  ///
  /// All counts must be >= 1, and [maxSilentBars] must not be less than
  /// [startSilentBars].
  factory GapPattern.ladder({
    required int clickBars,
    required int startSilentBars,
    required int maxSilentBars,
    required int cyclesPerStep,
  }) = LadderGapPattern;

  /// Each bar is silent with [silentProbability] (0..1), except that after
  /// [maxConsecutiveSilent] silent bars in a row the next bar always
  /// clicks. [maxConsecutiveSilent] must be >= 1.
  ///
  /// Bar 0 always clicks. Because of the cap, the share of silent bars
  /// comes out below [silentProbability]: barely for a high cap and a low
  /// probability, noticeably for a low cap or a high probability.
  factory GapPattern.random({
    required double silentProbability,
    required int maxConsecutiveSilent,
  }) = RandomGapPattern;

  static void _checkPositive(int value, String name) {
    if (value < 1) {
      throw ArgumentError.value(value, name, 'must be >= 1');
    }
  }
}

/// A [GapPattern] that alternates a fixed click phase with a fixed gap.
final class FixedGapPattern extends GapPattern {
  /// Audible bars at the start of every cycle. Always >= 1.
  final int clickBars;

  /// Silent bars at the end of every cycle. Always >= 1.
  final int silentBars;

  FixedGapPattern({required this.clickBars, required this.silentBars})
    : super._() {
    GapPattern._checkPositive(clickBars, 'clickBars');
    GapPattern._checkPositive(silentBars, 'silentBars');
  }

  @override
  bool operator ==(Object other) =>
      other is FixedGapPattern &&
      other.clickBars == clickBars &&
      other.silentBars == silentBars;

  @override
  int get hashCode => Object.hash(FixedGapPattern, clickBars, silentBars);

  @override
  String toString() =>
      'GapPattern.fixed(clickBars: $clickBars, silentBars: $silentBars)';
}

/// A [GapPattern] whose gap grows by one bar every [cyclesPerStep] cycles,
/// from [startSilentBars] up to [maxSilentBars].
final class LadderGapPattern extends GapPattern {
  /// Audible bars at the start of every cycle. Always >= 1.
  final int clickBars;

  /// Length of the gap in the first cycles. Always >= 1.
  final int startSilentBars;

  /// The longest gap the ladder climbs to; it stays there once reached.
  /// Never less than [startSilentBars].
  final int maxSilentBars;

  /// How many cycles each gap length is played before the gap grows.
  /// Always >= 1.
  final int cyclesPerStep;

  LadderGapPattern({
    required this.clickBars,
    required this.startSilentBars,
    required this.maxSilentBars,
    required this.cyclesPerStep,
  }) : super._() {
    GapPattern._checkPositive(clickBars, 'clickBars');
    GapPattern._checkPositive(startSilentBars, 'startSilentBars');
    GapPattern._checkPositive(cyclesPerStep, 'cyclesPerStep');
    if (maxSilentBars < startSilentBars) {
      throw ArgumentError.value(
        maxSilentBars,
        'maxSilentBars',
        'must be >= startSilentBars ($startSilentBars)',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LadderGapPattern &&
      other.clickBars == clickBars &&
      other.startSilentBars == startSilentBars &&
      other.maxSilentBars == maxSilentBars &&
      other.cyclesPerStep == cyclesPerStep;

  @override
  int get hashCode => Object.hash(
    LadderGapPattern,
    clickBars,
    startSilentBars,
    maxSilentBars,
    cyclesPerStep,
  );

  @override
  String toString() =>
      'GapPattern.ladder(clickBars: $clickBars, '
      'startSilentBars: $startSilentBars, maxSilentBars: $maxSilentBars, '
      'cyclesPerStep: $cyclesPerStep)';
}

/// A [GapPattern] that silences bars by chance, never more than
/// [maxConsecutiveSilent] in a row.
final class RandomGapPattern extends GapPattern {
  /// Chance that a bar is silent, 0..1, whenever the cap allows it.
  final double silentProbability;

  /// The most silent bars that may follow each other; the bar after them
  /// always clicks. Always >= 1.
  final int maxConsecutiveSilent;

  RandomGapPattern({
    required this.silentProbability,
    required this.maxConsecutiveSilent,
  }) : super._() {
    if (!(silentProbability >= 0 && silentProbability <= 1)) {
      throw ArgumentError.value(
        silentProbability,
        'silentProbability',
        'must be 0..1',
      );
    }
    GapPattern._checkPositive(maxConsecutiveSilent, 'maxConsecutiveSilent');
  }

  @override
  bool operator ==(Object other) =>
      other is RandomGapPattern &&
      other.silentProbability == silentProbability &&
      other.maxConsecutiveSilent == maxConsecutiveSilent;

  @override
  int get hashCode =>
      Object.hash(RandomGapPattern, silentProbability, maxConsecutiveSilent);

  @override
  String toString() =>
      'GapPattern.random(silentProbability: $silentProbability, '
      'maxConsecutiveSilent: $maxConsecutiveSilent)';
}

/// One bar as a [GapPattern] plays it.
class GapBar {
  /// Bars since the metronome started, 0 = first bar. The same numbering
  /// as `BeatEvent.barIndex`.
  final int index;

  /// `true` when nothing sounds in this bar.
  final bool silent;

  /// `true` for the first audible bar after one or more silent bars: the
  /// bar whose downbeat tells the player whether they kept time. Never
  /// `true` for bar 0 or for a silent bar.
  final bool landing;

  const GapBar({
    required this.index,
    required this.silent,
    required this.landing,
  });

  @override
  bool operator ==(Object other) =>
      other is GapBar &&
      other.index == index &&
      other.silent == silent &&
      other.landing == landing;

  @override
  int get hashCode => Object.hash(index, silent, landing);

  @override
  String toString() =>
      'GapBar($index${silent ? ', silent' : ''}${landing ? ', landing' : ''})';
}

/// Decides, bar by bar, which bars a [GapPattern] silences.
///
/// Bars are decided in order and every decision is kept, so asking for the
/// same bar twice always gives the same answer. That matters for
/// [GapPattern.random], where each bar is a fresh roll of the dice, and for
/// [GapPattern.ladder], whose gap depends on how many cycles came before.
/// Asking for a bar far ahead decides every bar up to it.
///
/// `Metronome.setGapPattern` plays a pattern through one of these, starting
/// a fresh one whenever the pattern starts over. Use one directly to
/// preview a pattern before it plays.
///
/// ```dart
/// final bars = GapPatternGenerator(
///   GapPattern.fixed(clickBars: 2, silentBars: 2),
/// );
/// bars.barAt(2).silent; // true
/// bars.barAt(4).landing; // true
/// ```
class GapPatternGenerator {
  /// Creates a generator that plays [pattern] from bar 0.
  ///
  /// [random] rolls the dice for [GapPattern.random]; pass a seeded
  /// [math.Random] for a reproducible sequence.
  GapPatternGenerator(this.pattern, {math.Random? random})
    : _sequence = _sequenceFor(pattern, random ?? math.Random());

  /// The pattern this generator plays.
  final GapPattern pattern;

  final _BarSequence _sequence;

  /// Whether each bar decided so far is silent, indexed by bar.
  final List<bool> _silent = [];

  /// How many silent bars end [_silent].
  int _silentRun = 0;

  /// Bar [index] (>= 0) as the pattern plays it.
  GapBar barAt(int index) {
    RangeError.checkNotNegative(index, 'index');
    _decideThrough(index);
    final silent = _silent[index];
    return GapBar(
      index: index,
      silent: silent,
      landing: !silent && index > 0 && _silent[index - 1],
    );
  }

  /// Decides every bar up to and including [index].
  void _decideThrough(int index) {
    while (_silent.length <= index) {
      final silent = _sequence.next(
        index: _silent.length,
        silentRun: _silentRun,
      );
      _silent.add(silent);
      _silentRun = silent ? _silentRun + 1 : 0;
    }
  }

  static _BarSequence _sequenceFor(GapPattern pattern, math.Random random) =>
      switch (pattern) {
        FixedGapPattern(:final clickBars, :final silentBars) => _CycleSequence(
          clickBars: clickBars,
          silentBars: silentBars,
          maxSilentBars: silentBars,
          cyclesPerStep: 1,
        ),
        LadderGapPattern(
          :final clickBars,
          :final startSilentBars,
          :final maxSilentBars,
          :final cyclesPerStep,
        ) =>
          _CycleSequence(
            clickBars: clickBars,
            silentBars: startSilentBars,
            maxSilentBars: maxSilentBars,
            cyclesPerStep: cyclesPerStep,
          ),
        final RandomGapPattern chance => _RandomSequence(chance, random),
      };
}

/// How one [GapPattern] decides its bars, with the state it carries from
/// bar to bar. A new sequence starts at the bar its pattern takes effect.
abstract class _BarSequence {
  /// Whether bar [index] is silent. [silentRun] is how many silent bars
  /// directly precede it.
  bool next({required int index, required int silentRun});
}

/// Click phases alternating with gaps. The gap grows by one bar after
/// every [cyclesPerStep] cycles until it is [maxSilentBars] long; a fixed
/// pattern is a cycle whose gap cannot grow.
final class _CycleSequence implements _BarSequence {
  _CycleSequence({
    required this.clickBars,
    required int silentBars,
    required this.maxSilentBars,
    required this.cyclesPerStep,
  }) : _silentBars = silentBars;

  final int clickBars;
  final int maxSilentBars;
  final int cyclesPerStep;

  /// Gap length of the current cycle.
  int _silentBars;

  /// Position in the current cycle, 0 = its first click bar.
  int _barInCycle = 0;

  /// Cycles completed at the current gap length.
  int _cyclesAtGap = 0;

  @override
  bool next({required int index, required int silentRun}) {
    final silent = _barInCycle >= clickBars;
    if (++_barInCycle == clickBars + _silentBars) {
      _barInCycle = 0;
      if (++_cyclesAtGap == cyclesPerStep) {
        _cyclesAtGap = 0;
        _silentBars = math.min(_silentBars + 1, maxSilentBars);
      }
    }
    return silent;
  }
}

/// Rolls the dice for every bar the cap allows to be silent.
final class _RandomSequence implements _BarSequence {
  _RandomSequence(this.pattern, this.random);

  final RandomGapPattern pattern;
  final math.Random random;

  @override
  bool next({required int index, required int silentRun}) {
    // Bar 0 opens every pattern with a click, and a full run forces one.
    if (index == 0 || silentRun >= pattern.maxConsecutiveSilent) return false;
    return random.nextDouble() < pattern.silentProbability;
  }
}
