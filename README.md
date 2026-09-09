# precise_metronome

A sample-accurate, production-grade Flutter metronome.

Timing runs entirely on native audio engines — **AVAudioEngine** on iOS,
**Oboe** on Android — with a classic look-ahead scheduler. Dart never
participates in per-beat timing, so GC pauses, platform channel jitter,
and widget rebuilds cannot affect click accuracy.

## Status

**v0.1.0 — initial release.** iOS + Android. All timing-critical paths
use atomic state access on the audio thread; buffer synthesis happens
once at init. No per-beat allocations on the audio thread.

## Features

- Sample-accurate scheduling via a 25 ms look-ahead loop
- Time signatures with smart compound-meter defaults (6/8 → 2 beats, 9/8 → 3, 12/8 → 4)
- Arbitrary accent patterns, per main beat or per subdivision pulse
- Subdivisions (duple / triplet / quadruple) with softer sub-clicks between main beats — and accents that can land on a subdivision pulse
- Two procedural click voices (no bundled audio assets)
- Tempo range 20–400 BPM
- Tap tempo
- Beat events (`Metronome.beats`) for UI sync — beat indicators, bar counters — with optional subdivision pulses
- Tempo ramps ("speed trainer"): step from a start to a goal BPM every N bars, exactly on the bar line — optionally back down to the start in one uninterrupted ramp
- Optional background playback (iOS audio session + Android foreground service)
- Mixes with other audio by default — practice over backing tracks

## Install

```yaml
dependencies:
  precise_metronome: ^0.1.0
```

## Quick start

```dart
import 'package:precise_metronome/precise_metronome.dart';

final metronome = Metronome();

await metronome.init();
await metronome.setTempo(120);
await metronome.setTimeSignature(TimeSignature(7, 8));
await metronome.setAccentPattern([true, false, false, true, false, true, false]);
await metronome.setSubdivision(Subdivision.duple);   // eighth-note subdivisions
await metronome.setVoice(MetronomeVoice.tone);
await metronome.setVolume(0.8);

await metronome.start();
// ...
await metronome.stop();

// Align the click grid with external audio: delay the first click,
// then shift the phase live while playing. Both are sample-accurate.
await metronome.start(initialDelay: Duration(milliseconds: 120));
await metronome.nudge(Duration(milliseconds: -25)); // clicks 25 ms earlier

// setTempo while playing is phase-preserving: the next click keeps its
// time, only the interval after it changes — safe to drive from a slider.

// When done:
await metronome.dispose();
```

### Accents

`setAccentPattern` takes one flag per main beat, or one flag per audible
pulse when you want a subdivision to carry the accent:

```dart
await metronome.setTimeSignature(TimeSignature(4, 4));
await metronome.setSubdivision(Subdivision.duple);

// One flag per beat — the eighths in between stay on the sub click.
await metronome.setAccentPattern([true, false, true, false]);

// One flag per pulse (beat * pulsesPerBeat + pulse): beat 1, and the
// "and" of 3 — a backbeat push.
await metronome.setAccentPattern([
  true, false,   // 1  &
  false, false,  // 2  &
  false, true,   // 3  &
  false, false,  // 4  &
]);
```

`accentPattern` reports the per-beat view, `pulseAccents` the full grid.
Changing the subdivision keeps the main-beat accents and clears any that sat
on subdivision pulses, since those slots no longer line up.

### Tap tempo

```dart
final tap = TapTempo();

// Call this on each tap:
final bpm = tap.tap();
if (bpm != null) await metronome.setTempo(bpm);
```

### Beat events (UI sync)

`Metronome.beats` delivers a `BeatEvent` for every main beat (bar, beat,
pulse index, accent), timed to arrive as close as possible to the moment
the click is heard — typically 2–10 ms behind the audio on iOS and
10–25 ms on Android, below what the eye can notice. Native emission is
only active while the stream has listeners.

```dart
final sub = metronome.beats.listen((b) {
  setState(() => currentBeat = b.beatIndex);   // light up beat b.beatIndex
  if (b.isDownbeat) barCounter = b.barIndex + 1;
});

// Also receive subdivision pulses (pulseIndex > 0):
await metronome.setBeatEventOptions(includeSubdivisions: true);
```

The events are for feedback, not for driving audio — clicks are
scheduled natively and never wait for Dart. For animations that need to
land exactly *on* the beat (a pendulum, say), interpolate locally from
`tempo` and use the events to re-sync.

### Tempo ramp (speed trainer)

Play a passage progressively faster: start at one tempo, hold it for a
number of bars, step up (or down), repeat until the goal tempo has been
played — then the metronome stops itself. The tempo change happens on the
native side exactly on the bar line, so it is as sample-accurate as every
other click.

```dart
final ramp = TempoRamp(
  startBpm: 80,
  goalBpm: 120,
  stepBpm: 5,        // 80, 85, 90, ... 120 (last step is clamped to the goal)
  barsPerStep: 4,    // hold each tempo for 4 bars
);

final sub = metronome.rampProgress.listen((p) {
  print('step ${p.stepIndex + 1}/${p.totalSteps} — ${p.bpm} BPM');
  if (p.finished) print('done, metronome stopped itself');
});

await metronome.startRamp(ramp);
// ... call metronome.stop() to abort early.
```

Pass `holdAtGoal: true` to keep clicking at the goal tempo instead of
stopping — handy when the musician has just reached target tempo and wants
to keep playing. `RampProgress.isLastStep` tells you the goal step is on;
no `finished` event follows, end it with `stop()`.

```dart
await metronome.startRamp(TempoRamp(
  startBpm: 80, goalBpm: 120, stepBpm: 5, barsPerStep: 4,
  holdAtGoal: true,
));
```

Pass `returnToStart: true` to walk back down again: once the goal has had
its bars, the tempo steps back to `startBpm` in the same increments and the
ramp ends there. The turnaround happens inside the running native ramp — the
metronome does not stop and restart — so it lands on the bar line with the
same sample accuracy as every other step.

```dart
await metronome.startRamp(TempoRamp(
  startBpm: 60, goalBpm: 70, stepBpm: 5, barsPerStep: 4,
  returnToStart: true,
));
// 60 → 65 → 70 → 65 → 60, four bars each, then stops.
```

`ramp.steps` gives you the full list of tempi up front, e.g. for a
progress bar — both legs included, with the goal counted once — and
`RampProgress.stepIndex` counts straight through the turnaround.
`goalBpm` below `startBpm` ramps downwards.

Leave out `goalBpm` for an open-ended ramp: the tempo keeps climbing by
`stepBpm` until it reaches 400 BPM, holds there, and only ends when you
call `stop()` — `RampProgress.totalSteps` is `null` in that case.

```dart
await metronome.startRamp(TempoRamp(startBpm: 90, stepBpm: 4, barsPerStep: 8));
```

### Background playback (optional)

```dart
await metronome.enableBackgroundPlayback(
  androidNotification: AndroidNotificationConfig(
    title: 'Practice session',
    body: 'Metronome is running',
  ),
);

// Later:
await metronome.disableBackgroundPlayback();
```

## Platform setup

### iOS

Minimum deployment target: **iOS 15**.

If you use background playback, add `audio` to `UIBackgroundModes` in
your app's `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

No further setup. The plugin configures the audio session with
`.playback` category and the `.mixWithOthers` option, so your app plays
nicely alongside Spotify, YouTube, etc.

### Android

Minimum SDK: **26** (Android 8.0). API 26 is the floor because the engine
relies on AAudio, which Oboe only uses from that level up.

The plugin's `AndroidManifest.xml` already declares the permissions it
needs — `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and
`POST_NOTIFICATIONS` — plus the foreground-service component. Those get
merged into your app's manifest automatically at build time.

On Android 13+ you must request the `POST_NOTIFICATIONS` runtime
permission before calling `enableBackgroundPlayback()` if you want the
foreground-service notification to be visible. The service itself will
still run without it, but users won't see the notification.

Add the **Kotlin JVM target** in your app's `android/app/build.gradle`
if you don't have it already:

```groovy
kotlinOptions {
    jvmTarget = '17'
}
```

## How accuracy works

1. **Native audio engines only.** iOS uses `AVAudioEngine` + an
   `AVAudioPlayerNode` scheduled via `AVAudioTime(sampleTime:atRate:)`.
   Android uses Oboe with a data callback at low-latency performance
   mode (AAudio fast-path on all API 26+ devices).
2. **Look-ahead scheduling.** A 25 ms tick loop (iOS) or direct frame
   computation in the Oboe callback (Android) schedules beats up to
   100 ms ahead, at exact sample positions. Scheduled buffers are
   rendered with frame-level precision by the OS audio HAL.
3. **Dart is out of the hot path.** Tempo, meter, and accent changes
   are atomic writes on the native side. No per-beat platform channel
   traffic, so Dart GC pauses cannot shift click timing.
4. **Procedural click synthesis** means consistent sound across devices
   and zero asset loading latency.

## Limitations / roadmap

Not yet included, easy to add later:

- Practice modes beyond tempo ramps (random-mute, silent bars).
- User-supplied WAV samples.
- Web, macOS, Windows, Linux.
- Auto-resume after phone-call interruptions.

## License

MIT. See `LICENSE`.
