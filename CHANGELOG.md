# Changelog

## 0.1.0 — Initial release

- iOS implementation: AVAudioEngine + AVAudioPlayerNode with 25 ms
  look-ahead scheduling at sample-accurate resolution.
- Android implementation: Oboe data callback (low-latency performance
  mode, exclusive sharing where available, shared fallback) with
  lock-free parameter updates.
- Procedural click synthesis for `tone` and `click` voices (identical
  DSP on both platforms).
- Public API: tempo (20–400 BPM), time signatures with smart
  compound-meter defaults, arbitrary accent patterns, voice selection,
  volume, tap tempo.
- Opt-in background playback (iOS audio-session, Android foreground
  service).
