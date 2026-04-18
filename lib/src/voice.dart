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
  click;

  /// Value sent across the method channel. Must match the native enum.
  String get wireName => name;
}
