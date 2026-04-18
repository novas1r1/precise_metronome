# precise_metronome — Handoff for Claude Code

This doc is a handoff from a planning + scaffolding session with Claude
on claude.ai. The full initial package was designed and written there;
you are picking up from v0.1.0 scaffolding.

## What this package is

A Flutter plugin providing a sample-accurate metronome. Timing runs
entirely on native audio engines so Dart GC pauses cannot affect click
accuracy. May eventually be published to pub.dev — keep the API clean.

- **iOS**: AVAudioEngine + AVAudioPlayerNode, 25 ms `DispatchSourceTimer`
  lookahead scheduler, sample-accurate `AVAudioTime(sampleTime:atRate:)`.
- **Android**: Oboe data callback, lock-free atomic parameter updates,
  frame-accurate beat scheduling directly inside the callback.

## Design decisions already locked in (do not revisit unless asked)

1. **Production-grade accuracy is non-negotiable.** No Dart-side timers,
   no `just_audio`-type approach. Native scheduling only.
2. **Headless engine + reference example.** The package exposes a Dart
   API; Drumbitious will build its own UI on top. No built-in widgets.
3. **Procedural click synthesis, no bundled audio assets.** Two voices:
   `tone` (1000/1500 Hz pitched burst) and `click` (bandpassed noise +
   transient). Identical DSP on iOS and Android.
4. **Binary accents only** (accent / no accent). Four-level accents were
   deferred to keep the API narrow.
5. **Smart compound-meter defaults.** 6/8 → 2 beats/bar, 9/8 → 3, 12/8
   → 4. Override via `TimeSignature.grouped(...)`.
6. **Tempo range 20–400 BPM**, max 32 beats/bar.
7. **iOS 15+, Android minSdk 28.** Android side assumes AAudio fast-path
   is available on every target device.
8. **Internal PPQN modeling** (engine uses frame-position math that
   subdivisions can slot into later) but v1 exposes beats only.
9. **Audio session**: iOS `.playback` + `.mixWithOthers` so users can
   play along with backing tracks.
10. **Background playback is opt-in.** iOS relies on
    `UIBackgroundModes: audio`; Android starts a foreground service
    (`mediaPlayback` type) with a visible notification.
11. **Namespace**: `com.repeatlab.precise_metronome`. If publishing to
    pub.dev, a neutral namespace is fine — Verry can decide later.

## File map

```
lib/
  precise_metronome.dart              public exports
  src/
    metronome.dart                    main API class
    time_signature.dart               TimeSignature + compound defaults
    voice.dart                        MetronomeVoice enum
    tap_tempo.dart                    pure Dart tap-tempo estimator
    background_config.dart            AndroidNotificationConfig

ios/
  precise_metronome.podspec
  Classes/
    PreciseMetronomePlugin.swift      Flutter plugin entry + dispatch
    MetronomeEngine.swift             AVAudioEngine + scheduler
    ClickSynth.swift                  tone + click DSP

android/
  build.gradle                        AGP 8.2, Kotlin 1.9.22, NDK, Oboe 1.9.0
  src/main/
    AndroidManifest.xml               foreground service + perms
    kotlin/com/repeatlab/precise_metronome/
      PreciseMetronomePlugin.kt       Flutter plugin entry + dispatch
      NativeBridge.kt                 JNI wrapper (external fun)
      MetronomeService.kt             foreground service
    cpp/
      CMakeLists.txt
      metronome_engine.{cpp,h}        Oboe callback + scheduling
      click_synth.{cpp,h}             tone + click DSP (mirrors iOS)
      jni_bridge.cpp                  JNI entry points

example/
  pubspec.yaml
  lib/main.dart                       minimal reference UI
  README.md                           post-`flutter create` setup steps

test/
  time_signature_test.dart
  tap_tempo_test.dart
  metronome_test.dart                 method channel mocked

README.md, CHANGELOG.md, LICENSE (MIT), analysis_options.yaml, .gitignore
```

## Public API (current)

```dart
final metronome = Metronome();
await metronome.init();
await metronome.setTempo(120);                             // 20..400
await metronome.setTimeSignature(TimeSignature(7, 8));
await metronome.setAccentPattern([true, false, false,
                                  true, false,
                                  true, false]);
await metronome.setVoice(MetronomeVoice.tone);             // tone | click
await metronome.setVolume(0.8);
await metronome.start();
await metronome.stop();
await metronome.dispose();

// Tap tempo (pure Dart, no native hop)
final bpm = TapTempo().tap();

// Background audio (opt-in)
await metronome.enableBackgroundPlayback(
  androidNotification: AndroidNotificationConfig(...),
);
```

## Known caveats from the scaffolding session

The package was designed and written without any compile pass
(no Flutter/Xcode/NDK in the authoring environment). First build will
likely hit small, local issues. The most likely ones:

- **AGP / Gradle version mismatch.** `android/build.gradle` pins AGP
  8.2.0 and NDK 26.1.10909125. If the consuming app's tooling is older,
  relax these.
- **Oboe Prefab.** Requires AGP 7.1+ and `buildFeatures { prefab true }`
  (already set on the plugin side). If the consumer has odd Gradle
  setup, prefab resolution can fail.
- **JNI name mangling.** The Kotlin package `precise_metronome` has an
  underscore, so JNI escapes it as `precise_1metronome`. All function
  names in `jni_bridge.cpp` already use this mangling. If you see
  `UnsatisfiedLinkError: No implementation found for ...` this is where
  to look.
- **Info.plist `UIBackgroundModes`.** Plugin cannot inject it — host
  app must add `audio` entry if using background mode.
- **Android 13+ POST_NOTIFICATIONS runtime permission** for the
  foreground-service notification to be visible — host-app
  responsibility to request.

## Roadmap (deferred but deliberately easy to add)

Ordered by likely priority:

1. **`beatStream` for UI sync.** Engine already knows when each click
   fires; just need a native → Dart callback after each scheduled beat.
   Expected UI latency 5–20 ms behind audio, imperceptible visually.
2. **Subdivisions** (8ths, 16ths, triplets, sextuplets). The engine's
   frame-position math already supports fractional beats; this is an
   API-layer addition, not an engine rewrite.
3. **Tempo ramps / practice modes.** Progressive (increase X BPM every
   N bars), random mute (silence N% of bars).
4. **Four-level accents** (silent / soft / normal / loud) if real
   musical use cases emerge.
5. **User-supplied WAV samples.** Requirements doc already drafted in
   chat: 48 kHz 16-bit mono WAV, < 150 ms, peak-normalized to ~-3 dBFS,
   three files per kit (accent / normal / soft).
6. **Auto-resume after phone-call interruption** (iOS).
7. **Web, macOS, Windows, Linux.** Out of scope for v0.1.

## How to proceed

Suggested first CLI tasks in order:

1. Run `flutter analyze` — expect some lint warnings, fix them.
2. Run `flutter test` — expect pure-Dart tests to pass.
3. Set up the example: `cd example && flutter create --org com.example
   --project-name precise_metronome_example .` then apply the three
   post-create tweaks in `example/README.md`.
4. `flutter run` on a real device. Verify: first click fires promptly,
   tempo changes are clean, 6/8 compound clicks dotted-quarters, 7/8
   clicks every eighth, voice switching is seamless.
5. Fix whatever breaks on first build. Known suspects listed above.

## Collaboration style preferences

Verry prefers:

- German or English, either fine; tech terms stay in English.
- Being asked clarifying questions when decisions have real tradeoffs.
  Do not silently assume.
- Minimal but production-grade code. No over-engineering, but no
  shortcuts that compromise correctness.
- When something cannot be verified (e.g. compile, runtime), say so
  explicitly. Do not claim it "should work" without flagging.
- Brief, direct prose. Skip apology language.

## Reference

Drumbitious is the drum-practice app this package was built for
(comic/illustration visual style, purple + orange brand). Repeatlab is
the parent entity (`repeatlab.de`). The package namespace `com.repeatlab`
reflects that.