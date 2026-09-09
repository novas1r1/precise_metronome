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
| The plan under the card (`60 → 65 → … → 120 → … → 60`) | `TempoRamp.steps` / `totalSteps` |
| Time signature picker, accent grid | `setTimeSignature` / `setAccentPattern` |
| Subdivision picker (♩ ♪♪ ♪³ ♬♬) | `setSubdivision` |
| Settings sheet: volume, and all five click voices with a line of description each | `setVolume`, `setVoice` |

Turning dynamic mode off starts a plain metronome (`start()`) at the tempo in
the stepper, which is relabelled "Tempo" there.

## Structure

- `lib/design/accel_tokens.dart` — the design system's colors, type, spacing,
  radii and motion curves, transcribed from `docs/design_system/tokens/`.
- `lib/widgets/` — the Accel control primitives, one per component in
  `docs/design_system/components/core/`.
- `lib/accel_metronome.dart` — the only place that talks to `Metronome`;
  republishes the native streams as something the widgets can paint.
- `lib/metronome_screen.dart` — the screen itself.

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
