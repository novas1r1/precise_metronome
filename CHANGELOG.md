# Changelog

## 0.4.0 — Tempo ramps and beat events

- Added `Metronome.beats`, a `Stream<BeatEvent>` (bar, beat, pulse index,
  accent) delivered close to the moment each click is heard, for beat
  indicators and bar counters. Native emission is switched on only while
  the stream has listeners. `setBeatEventOptions(includeSubdivisions:)`
  also delivers subdivision pulses. New `precise_metronome/beats` event
  channel; on Android the audio thread writes into a lock-free ring buffer
  drained from the main thread, on iOS events are dispatched with the
  scheduling look-ahead compensated.
- Added `TempoRamp` and `Metronome.startRamp(ramp)`: the metronome starts
  at `startBpm`, holds each tempo for `barsPerStep` bars, then moves
  `stepBpm` towards `goalBpm` (the last step is clamped so the goal is hit
  exactly; descending ramps are supported). After the goal tempo has been
  played for its bars the metronome stops itself.
- Tempo steps are applied by the native engines exactly on the bar line,
  sample-accurately — no Dart timers involved.
- Added `Metronome.rampProgress`, a `Stream<RampProgress>` that reports
  each step (index, total, BPM) and the final `finished` event, plus
  `Metronome.activeRamp`. Delivered over a new `precise_metronome/ramp`
  event channel.
- `goalBpm` is optional: without it the ramp is open-ended and keeps
  stepping up until 400 BPM, holding there until `stop()`.
- Example app gained a "Tempo ramp" section.

## 0.3.3 — Android: lower minSdk to 26

- Android `minSdk` dropped from 28 to **26** (Android 8.0). Nothing in the
  plugin actually required API 28: Oboe switches to the AAudio fast path at
  26, and the two version-sensitive call sites (`NotificationChannel`,
  `startForeground` with a service type) are already guarded for O and Q
  respectively. The `mediaPlayback` `foregroundServiceType` attribute needs
  only `compileSdk` 29+, not `minSdk`.
- Host apps can now ship down to Android 8.0 instead of 9.

## 0.3.1 — Android: shared Oboe stream

- The Android engine now always opens its Oboe stream in **shared** mode.
  It previously requested an exclusive (MMAP) stream first, which on some
  devices/HALs claims the output device and can silently starve or stall
  other audio streams — including the host app's own music playback.
  Clicks are scheduled ahead inside the stream, so the mixer path's extra
  fixed latency does not affect timing accuracy.

## 0.3.0 — Phase control

- `Metronome.start` gained an `initialDelay` parameter: the first click
  fires that much later than it otherwise would, applied with sample
  accuracy on the native side. Useful for aligning the click grid with
  external audio.
- Added `Metronome.nudge(Duration delta)`: shifts the phase of all
  future clicks while playing (positive = later, negative = earlier).
  If the shifted position would collide with an already-scheduled click
  or land in the past, the engine rolls forward by whole pulse periods
  (phase-equivalent) — clicks never double-fire.
- Documented the phase-preservation guarantee of `setTempo`: the next
  scheduled click keeps its time; only the subsequent interval changes.
  Tempo sweeps (e.g. from a slider) never cause jumps or dropped clicks.

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
