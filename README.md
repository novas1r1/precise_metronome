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
- Arbitrary accent patterns
- Subdivisions (duple / triplet / quadruple) with softer sub-clicks between main beats
- Two procedural click voices (no bundled audio assets)
- Tempo range 20–400 BPM
- Tap tempo
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

// When done:
await metronome.dispose();
```

### Tap tempo

```dart
final tap = TapTempo();

// Call this on each tap:
final bpm = tap.tap();
if (bpm != null) await metronome.setTempo(bpm);
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

Minimum SDK: **28** (Android 9).

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
   mode (AAudio fast-path on all API 28+ devices).
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

- `beatStream` for UI sync.
- Tempo ramps, practice modes (progressive, random-mute).
- User-supplied WAV samples.
- Web, macOS, Windows, Linux.
- Auto-resume after phone-call interruptions.

## License

MIT. See `LICENSE`.
