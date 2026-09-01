/// The built-in synthesized click voices.
///
/// Clicks are procedurally generated on the native side — no audio assets
/// are bundled. This keeps the package tiny and guarantees the same sound
/// on every device.
enum MetronomeVoice {
  /// A classic electronic-metronome tone: a short pitched burst (sine + a
  /// touch of triangle) with a fast exponential decay (~30 ms). 1000 Hz
  /// on normal beats, 1500 Hz on accents.
  tone,

  /// A sharper wood-block / rim-style click: a pitched transient plus a
  /// band-passed noise burst (~20 ms). Cuts through busy practice audio
  /// better than [tone].
  click,

  /// A warm, hollow wood sound (modal synthesis of a struck wooden bar:
  /// three inharmonic decaying partials plus a short stick-impact noise,
  /// ~90 ms). Rounder and darker than [click] — like a large wood block
  /// or claves. 820 Hz fundamental on normal beats, 1080 Hz on accents.
  wood,

  /// A classic pendulum-metronome tick: a broadband snap plus a low
  /// wooden-case resonance. Accented beats additionally ring with a
  /// bell-like partial — like the bell of an old mechanical metronome —
  /// so they are unmistakable.
  mechanical,

  /// A soft marimba-like blip with a gentle attack (C5 on normal beats,
  /// E5 on accents). The least fatiguing voice for long, quiet practice
  /// sessions.
  blip;

  /// Value sent across the method channel. Must match the native enum.
  String get wireName => name;
}
