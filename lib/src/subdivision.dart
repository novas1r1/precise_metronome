/// How many audible pulses the engine plays per main beat.
///
/// [Subdivision.none] plays one click per beat — the "classic" metronome
/// feel. Higher values insert additional, softer clicks between beats:
///
///  * [Subdivision.duple]     — 2 pulses per beat (e.g. eighth notes in a
///    quarter-based meter, or sixteenth notes over an eighth-based beat).
///  * [Subdivision.triplet]   — 3 pulses per beat (eighth-note triplets).
///  * [Subdivision.quadruple] — 4 pulses per beat (sixteenth notes in a
///    quarter-based meter).
///
/// [Subdivision] is meter-agnostic. It describes how each audible beat
/// is split, not the musical note value. To translate from note values,
/// divide the subdivision's note value by the meter's beat note value —
/// e.g. a 4/4 meter with an eighth-note subdivision has
/// `pulsesPerBeat = 8 / 4 = 2` → [Subdivision.duple].
///
/// The tempo (BPM) always refers to the rate of main beats, regardless
/// of subdivision. Subdivision pulses fire at `tempo × pulsesPerBeat`
/// per minute.
enum Subdivision {
  /// No subdivision — one click per beat.
  none(1),

  /// Two pulses per beat.
  duple(2),

  /// Three pulses per beat (triplet feel).
  triplet(3),

  /// Four pulses per beat.
  quadruple(4);

  /// How many audible pulses fire during one main beat, including the
  /// main beat itself.
  final int pulsesPerBeat;

  const Subdivision(this.pulsesPerBeat);
}
