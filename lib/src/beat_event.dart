/// One pulse of the metronome, delivered through `Metronome.beats` as close
/// as possible to the moment it is heard.
///
/// Positions are 0-based. [pulseIndex] is 0 for a main beat and > 0 for
/// subdivision pulses within that beat (only sent when
/// `Metronome.setBeatEventOptions(includeSubdivisions: true)` is set).
class BeatEvent {
  /// Bars elapsed since the metronome was started (0 = first bar).
  final int barIndex;

  /// Beat within the bar, `0 .. beatsPerBar - 1`.
  final int beatIndex;

  /// Pulse within the beat, `0 .. pulsesPerBeat - 1`. 0 is the main beat.
  final int pulseIndex;

  /// Whether this pulse used the accent click. Always `false` for
  /// subdivision pulses.
  final bool accent;

  /// `true` when a gap pattern silenced this pulse: nothing was heard, but
  /// the pulse kept its place in time. [accent] still tells which click it
  /// would have used. See `Metronome.setGapPattern`.
  final bool muted;

  /// `true` for every pulse of the first audible bar after one or more
  /// silent bars. The bar's downbeat is the moment that tells the player
  /// whether they held the tempo through the gap.
  final bool landing;

  const BeatEvent({
    required this.barIndex,
    required this.beatIndex,
    required this.pulseIndex,
    required this.accent,
    this.muted = false,
    this.landing = false,
  });

  /// `true` for the first pulse of a beat (the one that follows the
  /// accent pattern).
  bool get isMainBeat => pulseIndex == 0;

  /// `true` for the first beat of a bar.
  bool get isDownbeat => beatIndex == 0 && pulseIndex == 0;

  @override
  String toString() =>
      'BeatEvent(bar $barIndex, beat $beatIndex, pulse $pulseIndex'
      '${accent ? ', accent' : ''}${muted ? ', muted' : ''}'
      '${landing ? ', landing' : ''})';
}
