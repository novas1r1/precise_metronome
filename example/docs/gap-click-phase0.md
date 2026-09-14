# Gap Click Trainer – Phase 0 Report

Status: Phase 0 complete, decisions recorded · 11.09.2026
Companion to `gap-click-plan.md` (sections 0 and 10) and `gap_click_mockup.html`.

---

## 1. Verdict

The feature can be built cleanly on the current engine. Both native
schedulers already keep bar, beat and pulse counters on the audio thread,
pick a click buffer per pulse from a per-pulse pattern, and report beat
events with bar and beat indices. Per-beat muting is a small addition at
the exact spot where the buffer is chosen, so the clock and the first click
after a gap stay sample-accurate by construction. No engine restructure is
needed.

The plan assumes several app features that do not exist yet (see section 4)
and one architectural adjustment to Option A is recommended (section 3).

---

## 2. Codebase findings

### Engine and scheduling

| | iOS | Android |
|---|---|---|
| Stack | AVAudioEngine + AVAudioPlayerNode | Oboe data callback |
| Scheduling | 25 ms `DispatchSourceTimer`, buffers scheduled up to 100 ms ahead by sample time | Pulses rendered frame-accurately inside the callback |
| Parameter hand-off | Serial queue | Atomics, lock-free |
| Counters | `barIndex`, `beatIndexInBar`, `pulseIndexInBeat` | `bar_index_`, `beat_index_in_bar_`, `pulse_index_in_beat_` |
| Buffer pick | `MetronomeEngine.swift` `schedulerTick()` | `metronome_engine.cpp` `onAudioReady()` |

Both engines start every session at bar 0. There is no count-in, so bar 0
is simply the first bar after `start()`.

### Per-beat mute

Not available today. The insertion point is the buffer pick in both
engines. A muted beat skips `scheduleBuffer` (iOS) or the mix loop
(Android) while the counters advance as usual. Checking the flag on the
beat index mutes the beat's subdivision pulses automatically. No per-beat
gain is required.

### Beat events

`Metronome.beats` delivers `BeatEvent(barIndex, beatIndex, pulseIndex,
accent)` on both platforms. Events are held back until the click is
audible: iOS dispatches to the main queue after look-ahead plus output
latency, Android drains a lock-free ring buffer from the main thread every
10 ms. Two fields must be added: `muted` and `landing`. On Android the ring
struct and the JNI flattening (four ints per event) must be widened.

### Existing features

| Feature | Status |
|---|---|
| Time signatures | 1–32 beats per bar, compound grouping for 6/8, 9/8, 12/8 |
| Subdivisions | 1, 2, 3, 4 pulses per beat |
| Accents | Binary, one flag per pulse of the bar |
| Tempo ramps | Native, bar-line stepping, bar- or time-based steps, return to start, hold at goal |
| Nudge | Native phase shift |
| Voices | Five procedural voices, buffers accent / normal / sub per voice |
| Beat events | Yes, see above |
| Count-in | Not present |
| Haptics, screen flash | Not present |
| Presets, songs, setlists | Not present |
| Persistence | Not present, settings live in memory in `AccelMetronome` |
| In-app purchase, entitlements | Not present |

### Background playback

The package supports it opt-in: `enableBackgroundPlayback()` starts a
foreground service on Android; on iOS the `.playback` session plus
`UIBackgroundModes: audio` in the host `Info.plist` is enough. Accel does
not call it yet, and the example's generated `ios/` and `android/` folders
are gitignored, so the host-project settings must be documented in
`example/README.md` and applied locally.

With background enabled, Dart keeps running on both platforms: the Android
main `Handler` keeps polling under the foreground service, and the iOS main
queue runs while the audio session is active. Option A's premise (Dart can
keep feeding the engine) holds.

### Interruptions

iOS stops on an audio-session interruption and does not resume, so a
restart begins at bar 0. Android reopens the stream after a device error
and keeps counting without resetting the bar index.

### Conventions

- `AccelMetronome` (ChangeNotifier) is the only place that talks to
  `Metronome`; screen sections are plain widgets; controls come from
  `widgets/` and `design/accel_tokens.dart`.
- Package tests mock the method channel (`test/metronome_test.dart`).
  The example has one widget test.
- There is no native test harness. The offline render tests in plan section
  8.2 would need new infrastructure or a recording-based check.

### Mockup

`gap_click_mockup.html` is byte-identical to the plan's appendix and is a
faithful functional reference for 4/4 without subdivisions. No behavior in
it contradicts plan section 4.

---

## 3. Architecture: Option A, adjusted

> Revised 11.09.2026 in Phase 2. Replacing plans "from the next bar" races
> with the audio thread, so the hand-off now uses segments (see below).

**Generator in Dart, inside the package.** `GapPattern` and
`GapPatternGenerator` live in `precise_metronome`, not in Accel, because
Drumbitious will use the same feature. The package owns the loop that
feeds the native engine.

**Declarative public API.** `Metronome.setGapPattern(GapPattern?)`, with
`null` turning the feature off, plus `BeatEvent.muted`, `BeatEvent.landing`
and `Metronome.gapBarAt(bar)` for previews. The channel methods
(`setGapPlan`, `clearGapPlan`) stay private to the package.

**Segment hand-off.** Dart cannot know which bar the engine has already
scheduled: events arrive late, and iOS schedules 100 ms ahead.

- Every run of a pattern is a segment with an increasing id; its bars count
  from 0.
- The engine starts a newly arrived segment on the first bar it schedules
  after the segment arrived, so a change always lands on a bar line that
  has not been scheduled yet.
- Consequence: a pattern changed while playing always starts over with an
  audible bar, in every mode. Random mode does not carry the silent run
  across a change, and the generator has no `reconfigure`.
- Every beat event carries the segment id and the bar within it. Downbeats
  drive topping up (at least 4 s and 8 bars ahead) and self-healing: when
  the engine ran out of bars or dropped a segment it had started, Dart
  starts a new one.
- `start()` and `startRamp()` send a fresh segment before starting, so the
  pattern begins on the session's first bar.

**Fail-audible.** A bar without a plan plays all beats. Dart logs it via
`dart:developer` and starts the pattern over; nothing is logged on the
Android audio thread.

**Native plan.** Android: `gap_plan.{h,cpp}`, a lock-free single-producer,
single-consumer command ring from the Flutter thread, an atomic for
"clear", and segments owned by the audio thread, 64 bars kept per segment.
iOS: `GapPlan.swift` mirrors it on the serial queue. Both decide each bar
once, before its first pulse, and schedule no click for any pulse of a
silent bar, subdivisions included.

**Android device errors (decision 5).** After a stream reopen the engine
drops the segment in effect. Dart notices on the next downbeat and starts
the pattern over at its bar 0; the session's bar counter keeps counting.

**Time signature changes** do not restart the pattern. The modes are
bar-based, so the meter does not change which bars are silent.

**Rejected alternative.** A fully native pattern engine (like the ramp)
would remove the Dart dependency but means implementing Fixed, Ladder and
Random three times (C++, Swift, Dart) with no native tests.

---

## 4. Plan assumptions that do not hold

- Count-in does not exist. Bar 0 is the first bar. Nothing to model.
- Haptics and flash do not exist. Only the ring, dial dots and accent-grid
  highlight need to respect `muted`.
- No preset system exists. Gap presets are standalone.
- Ramps and gap patterns are independent code paths natively; combining
  them costs nothing in the engine. Excluding it from v1 is a UI rule.

---

## 5. Decisions (recorded 11.09.2026)

| # | Question | Decision |
|---|---|---|
| 1 | Persistence dependency | Yes, `shared_preferences` |
| 2 | Entitlement / IAP dependency | Later, not now |
| 3 | Option A as adjusted (generator in package, package feeds queue, native latches at downbeat) | Yes. Package must carry the gap feature for Drumbitious |
| 4 | Public API shape | Declarative (`setGapPattern`-style); queue methods private |
| 5 | Android stream reopen after device error | Pattern restarts at bar 0 |
| 6 | Ramps + gap in the same run | Mutually exclusive for now |
| 7 | Free / Pro split (plan decision 1) | Decided later; no gating in this iteration |
| 8 | Landing check by microphone / tap (plan decision 2) | Out of scope |
| 9 | UI placement (plan decision 3) | "Gap trainer" card below the dynamic-mode card; status text in the header badge slot; turning gap on turns dynamic mode off |
| 10 | Presets (plan decision 4) | Standalone gap presets, 3–5 built-in; selection left to implementation |
| 11 | Landing sound (plan decision 5) | No special landing sound for now. `landing` still reported on `BeatEvent` for the UI status text |
| 12 | Random granularity (plan decision 6) | Bar-level only |
| 13 | Beat mask (plan decision 7) | Not now |
| 14 | Subdivisions under beat mask (plan decision 8) | Not applicable while 13 is out |
| 15 | Background playback in Accel | Yes, wire it up as part of this work |
| 16 | This report as a file | Yes (this document) |

---

## 6. Resulting scope for v1

In: modes Fixed, Random, Ladder · bar strip with preview ("?" for Random)
· hide beat indicator during silent bars (option, default on) · remaining
silent bars (option, default off, not in Random) · status text · built-in
and custom presets · persistence of the last settings · background
playback in Accel.

Out: landing sound, beat mask, Pro gating, landing check, ramp + gap in one
run, beat-level random, watch apps.

## 7. Phases

| Phase | Content | Stop point |
|---|---|---|
| 1 | Package: `GapPattern` model, `GapPatternGenerator`, unit tests (plan 8.1) | Tests green |
| 2 | Package: native queue + latch + fail-audible + `muted`/`landing` events on iOS and Android; Dart `setGapPattern` with refill loop; method-channel tests | Recording test on device |
| 3 | Accel: Gap trainer card, bar strip, display rules, status text | Review with screenshots |
| 4 | Accel: presets + persistence (`shared_preferences`) + background playback | Review |
| 5 | Manual checklist (plan 8.3), polish | Acceptance (plan section 9, minus gated items) |
