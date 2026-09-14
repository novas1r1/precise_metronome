# Accel — precise_metronome example

A full metronome screen built on `precise_metronome`, styled with the Accel
design system in `docs/design_system/`.

Run it on a device or emulator:

```sh
flutter run
```

## What it shows

| Screen element | Package API |
| --- | --- |
| The dial's expanding ring, beat dots, bar counter, live accent cell | `Metronome.beats` (`BeatEvent`) |
| Dynamic mode, the badge readout, the step progress line | `TempoRamp` + `Metronome.startRamp` / `rampProgress` |
| "Ramp back down" | `TempoRamp.returnToStart` — one uninterrupted native ramp, so the turnaround lands on the bar line like every other step |
| "Hold each tempo for" — bars or time, with quick picks and a typed `m:ss` field; the countdown on the dial | `RampStepLength.bars` / `RampStepLength.time` — timed steps end on the next bar line, counted natively in audio frames |
| The plan under the card (`60 → 65 → … → 120 → … → 60 · 25 steps · 100 bars · ~4:42`) | `TempoRamp.steps` / `totalSteps` / `totalBars` / `totalDuration` |
| Time signature picker, accent grid | `setTimeSignature` / `setAccentPattern` |
| Subdivision picker (♩ ♪♪ ♪³ ♬♬) | `setSubdivision` |
| Settings sheet: volume, and all five click voices with a line of description each | `setVolume`, `setVoice` |
| Gap trainer: fixed, random and ladder patterns, the bar strip, and the badge that reads `click` / `silent` / `landing` | `GapPattern` + `setGapPattern`, `BeatEvent.muted` / `landing`, `gapBarAt` for the bars coming up |
| Gap presets, five built in and your own on top | `GapSettings` / `GapPreset` in `lib/gap_settings.dart`, stored with `shared_preferences` |
| Playing on with the screen off | `enableBackgroundPlayback` while the metronome runs, released when it stops |

Turning dynamic mode off starts a plain metronome (`start()`) at the tempo in
the stepper, which is relabelled "Tempo" there.

Dynamic mode and the gap trainer take turns: switching one on switches the
other off, and while one of them is playing the other's switch waits. A gap
hides the beat indicator and never fires the dial's ring, so a silent bar
feels like silence rather than a click with the sound turned down.

## Structure

- `lib/design/accel_tokens.dart` — the design system's colors, type, spacing,
  radii and motion curves, transcribed from `docs/design_system/tokens/`.
- `lib/widgets/` — the Accel control primitives, one per component in
  `docs/design_system/components/core/`.
- `lib/accel_metronome.dart` — the only place that talks to `Metronome`;
  republishes the native streams as something the widgets can paint.
- `lib/gap_settings.dart` — what the gap trainer plays by, what a preset
  stores, and the five presets Accel ships with.
- `lib/settings_store.dart` — the last settings and your own presets, as
  two JSON blobs in `shared_preferences`.
- `lib/metronome_screen.dart` — owns the model and lays the screen out.
- `lib/screen/` — the screen's sections (header, dial, meter controls,
  tempo, dynamic-mode and gap-trainer cards, transport bar, settings
  sheet), one widget per file.
- `lib/formatting.dart` — the tempo and clock formatting the screen and
  the model share.

## Remembering, and playing on

Every setting on screen is written a moment after it changes, and read back
on the next launch: tempo, meter, accents, subdivision, sound, volume, both
trainers and their options. Anything a store cannot supply keeps its
default, so an older or half-written store still starts the app.

While the metronome plays, Accel holds background playback, and releases it
as soon as it stops. On Android that is the package's foreground service
with its notification; the process then survives the screen going off. Two
host-project details are not in this repository, because `example/android`
and `example/ios` are generated:

- **iOS** needs `UIBackgroundModes` with `audio` in `Runner/Info.plist`.
- **Android 13 and newer** hides the notification until the app asks for
  the `POST_NOTIFICATIONS` permission, which Accel does not do yet. The
  service, and the click, run either way.

## Where it departs from the design system

- **Accents are per beat, not per subdivision slot.** The UI kit draws one
  toggle per subdivision slot, but `setAccentPattern` takes one flag per main
  beat — sub-pulses always use the softer sub click. Subdivisions are drawn
  inside each beat as passive ticks instead.
- **Compound meters group into fewer beats.** `TimeSignature(6, 8)` is two
  beats per bar and `12/8` is four, so the ring and the accent grid follow the
  felt pulse rather than the numerator.
- **Icons** are Material's rounded set standing in for Lucide, which the
  design system itself flags as a placeholder.
- **The tempo stepper stays live when dynamic mode is off**, since it is the
  app's only tempo control; the ramp-specific rows dim instead of the whole
  card.

## Fonts

Archivo (variable) and IBM Plex Mono are bundled under `assets/fonts/` with
their OFL licenses. Archivo ships as a single variable font, so weights are
selected with `FontVariation` in `AccelType` rather than with `fontWeight`.
