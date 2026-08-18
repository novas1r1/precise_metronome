/// One audible pulse of the metronome, delivered through `Metronome.beats`
/// as close as possible to the moment it is heard.
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

  const BeatEvent({
    required this.barIndex,
    required this.beatIndex,
    required this.pulseIndex,
    required this.accent,
  });

  /// `true` for the first pulse of a beat (the one that follows the
  /// accent pattern).
  bool get isMainBeat => pulseIndex == 0;

  /// `true` for the first beat of a bar.
  bool get isDownbeat => beatIndex == 0 && pulseIndex == 0;

  @override
  String toString() =>
      'BeatEvent(bar $barIndex, beat $beatIndex, pulse $pulseIndex'
      '${accent ? ', accent' : ''})';
}
