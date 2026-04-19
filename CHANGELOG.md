# Changelog

## 0.2.0 — Subdivisions

- Added `Subdivision` (none / duple / triplet / quadruple) and
  `Metronome.setSubdivision`. Each main beat is split into
  `pulsesPerBeat` pulses; the first pulse of each beat uses the
  accent/normal click, remaining pulses use a softer "sub" click.
- Scheduler is now pulse-based on both iOS and Android. Main-beat timing
  and accent semantics are unchanged when subdivision is `none`.
- Tempo continues to refer to the main-beat rate, independent of
  subdivision.

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
