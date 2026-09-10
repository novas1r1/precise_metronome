# Changelog

## 0.8.0 — Timed ramp steps

- A `TempoRamp` step can now be a stretch of time instead of a bar count.
  `barsPerStep` is replaced by `stepLength`, a `RampStepLength`:
  `RampStepLength.bars(4)` or `RampStepLength.time(Duration(seconds: 30))`.
  The tempo still only changes on a bar line: a timed step is held until
  its duration has elapsed and then ends at the next downbeat (30 s at
  100 BPM in 4/4 plays 13 bars). Works with `holdAtGoal`, `returnToStart`
  and open-ended ramps alike.
- Both native engines count the step time in audio frames from the
  downbeat that opened the step, so it is sample-accurate and unaffected
  by Dart, background playback or nudges. New `stepMs` argument on the
  `startRamp` method call (0 for bar-counted steps).
- Added `TempoRamp.barsAt`, `totalBars` and `totalDuration`, and
  `RampStepLength.barsAt` / `durationAt`, to predict how many bars and how
  long a ramp plays for a given time signature.
- Example app: "Hold each tempo for" switches between bars and time, with
  quick picks (15 s – 5 min) and a typed `m:ss` field (5 s – 30 min). The
  dial counts the step down, and the plan line now shows the total time.
- **Breaking:** `TempoRamp(barsPerStep: n)` becomes
  `TempoRamp(stepLength: RampStepLength.bars(n))`.

## 0.7.0 — Round-trip ramps and accents on subdivision pulses

- `setAccentPattern` now also accepts a pattern with one flag per audible
  pulse (`timeSignature.beatsPerBar * subdivision.pulsesPerBeat`, indexed
  `beat * pulsesPerBeat + pulse`), so a subdivision pulse can carry the
  accent click instead of always taking the softer sub click. Passing one
  flag per main beat keeps working exactly as before.
- Added `Metronome.pulseAccents` for the per-pulse view. `accentPattern`
  still reports one flag per main beat.
- `setSubdivision` rescales the pattern onto the new pulse grid: main-beat
  accents are kept, accents that sat on subdivision pulses are cleared.
- `BeatEvent.accent` is now `true` for an accented subdivision pulse.
- Both engines index the pattern per pulse; the native maximum grew from 32
  beats to 128 pulses per bar.
- `setAccentEnabled` and `setAccentBeat` (0.5.0) now write onto the pulse
  grid too. `accentBeat` tracks a lone accent only while it sits on a main
  beat: a single accent placed on a subdivision pulse leaves it untouched,
  so switching accents off and on again restores the beat, not the off-beat.

- Added `TempoRamp.returnToStart`: after the goal tempo has been played for
  its bars, the ramp steps back down to `startBpm` in the same increments
  and ends there (60 → 65 → 70 → 65 → 60 for a 60→70 ramp in steps of 5).
  The turnaround happens inside the running native ramp, on the bar line,
  with the same sample accuracy as every other step — the engine never
  stops and restarts, so there is no gap or late click at the top.
  `returnToStart` requires a `goalBpm`; combined with `holdAtGoal` the
  metronome holds `startBpm` at the end of the return leg.
- `TempoRamp.totalSteps`, `steps` and `bpmAt` cover both legs, and
  `RampProgress.stepIndex` counts straight through the turnaround, so a
  progress bar can show the whole arc. The goal step is counted once.

## 0.6.0 — Three new voices

- Added three procedurally synthesized voices (still no bundled assets):
  - `MetronomeVoice.wood` — warm, hollow wood (modal synthesis of a
    struck wooden bar: three inharmonic decaying partials plus a short
    stick-impact noise). 820 Hz fundamental, 1080 Hz on accents.
  - `MetronomeVoice.mechanical` — classic pendulum-metronome tick
    (broadband snap plus a low wooden-case resonance). Accents ring with
    a bell-like partial, like the bell of an old mechanical metronome,
    so they are unmistakable.
  - `MetronomeVoice.blip` — soft marimba-like blip with a gentle attack
    (C5, E5 on accents); the least fatiguing voice for quiet practice.
- Voices are rendered identically on iOS and Android (same DSP, same
  deterministic noise), as before.

## 0.5.0 — Accent settings

- Added `Metronome.setAccentEnabled(bool)`: with `false` every beat uses
  the normal click, so the bar sounds completely even; `true` restores
  the accent on the beat it was on before.
- Added `Metronome.setAccentBeat(int)`: puts the single accent on any
  beat of the bar (0-based, validated against `beatsPerBar` — 4 positions
  in 4/4, 3 in 3/4, …) and re-enables a disabled accent.
- Added the `accentEnabled` and `accentBeat` getters. Both stay in sync
  with `setAccentPattern` (all-`false` disables, a single-accent pattern
  moves `accentBeat`).
- `setTimeSignature` now preserves the accent-enabled state and keeps the
  accent on its beat when that beat still exists in the new bar (falling
  back to beat 1 otherwise). Previously it always reset to an accent on
  beat 1. Custom multi-accent patterns are still reset.
- Example app: new "Accent" switch in the Accents section.
- No native changes — both engines already play any accent pattern.

## 0.4.1 — Hold at goal

- Added `TempoRamp.holdAtGoal`: the metronome keeps clicking at `goalBpm`
  after the ramp is done instead of stopping itself. `activeRamp` stays set
  and no `finished` event is sent; end the ramp with `stop()`. Both native
  engines already supported this — it is the existing `stopAtGoal` flag
  exposed in the Dart API.
- Added `TempoRamp.stopsAtGoal` and `RampProgress.isLastStep`.

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
