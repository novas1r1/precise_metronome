/// Describes a musical time signature and how its beats are audibly grouped.
///
/// `numerator` / `denominator` follow standard musical notation (e.g. 7/8).
/// `beatsPerBar` controls how many audible clicks the metronome produces per
/// bar — for most simple meters this equals [numerator], but compound meters
/// default to a grouped feel:
///
/// * 6/8  → 2 audible beats per bar (dotted-quarter pulse)
/// * 9/8  → 3 audible beats per bar
/// * 12/8 → 4 audible beats per bar
///
/// Override with [TimeSignature.grouped] if you want e.g. 6/8 clicked as
/// eighth notes (6 beats per bar).
///
/// The metronome always interprets BPM as the rate of the audible beat, so
/// 120 BPM in 4/4 clicks quarters 120× per minute, and 120 BPM in 6/8
/// compound clicks dotted-quarters 120× per minute.
class TimeSignature {
  /// Top number of the time signature (e.g. 7 in 7/8).
  final int numerator;

  /// Bottom number of the time signature (e.g. 8 in 7/8).
  /// Must be a power of two from 1 to 32.
  final int denominator;

  /// How many audible clicks occur per bar. For a custom grouping (e.g.
  /// 7/8 felt as 2+2+3 = 3 beats), use [TimeSignature.grouped].
  final int beatsPerBar;

  /// Creates a time signature with a sensible default grouping.
  ///
  /// Compound meters (6/8, 9/8, 12/8) default to dotted-quarter pulses.
  /// Everything else clicks once per numerator beat.
  TimeSignature(this.numerator, this.denominator)
      : beatsPerBar = _defaultBeatsPerBar(numerator, denominator) {
    _validate(numerator, denominator, beatsPerBar);
  }

  /// Creates a time signature with an explicit audible-beat count per bar.
  ///
  /// Use this for non-standard groupings such as 7/8 felt as 3 beats
  /// (2+2+3), or to force 6/8 to click every eighth (6 beats per bar).
  TimeSignature.grouped(this.numerator, this.denominator, this.beatsPerBar) {
    _validate(numerator, denominator, beatsPerBar);
  }

  /// 4/4 — the most common time signature.
  static final TimeSignature fourFour = TimeSignature(4, 4);

  /// 3/4 — waltz.
  static final TimeSignature threeFour = TimeSignature(3, 4);

  /// 6/8 compound (2 audible dotted-quarter beats).
  static final TimeSignature sixEightCompound = TimeSignature(6, 8);

  static int _defaultBeatsPerBar(int num, int den) {
    if (den == 8 && (num == 6 || num == 9 || num == 12)) {
      return num ~/ 3;
    }
    return num;
  }

  static void _validate(int num, int den, int bpb) {
    if (num < 1 || num > 32) {
      throw ArgumentError.value(num, 'numerator', 'must be 1..32');
    }
    const validDenominators = {1, 2, 4, 8, 16, 32};
    if (!validDenominators.contains(den)) {
      throw ArgumentError.value(den, 'denominator', 'must be 1, 2, 4, 8, 16, or 32');
    }
    if (bpb < 1 || bpb > 32) {
      throw ArgumentError.value(bpb, 'beatsPerBar', 'must be 1..32');
    }
  }

  @override
  String toString() =>
      beatsPerBar == numerator || beatsPerBar == _defaultBeatsPerBar(numerator, denominator)
          ? 'TimeSignature($numerator/$denominator)'
          : 'TimeSignature($numerator/$denominator, beatsPerBar: $beatsPerBar)';

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.numerator == numerator &&
      other.denominator == denominator &&
      other.beatsPerBar == beatsPerBar;

  @override
  int get hashCode => Object.hash(numerator, denominator, beatsPerBar);
}
