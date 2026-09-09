# Accel app — UI kit

Mobile-first (390×844) main metronome screen, composed from `components/core/`.

- `index.html` — interactive: Start/Stop runs a real scheduler (Web Audio click), Dynamic mode ramps tempo every N bars, optional target and ramp-down, subdivisions, time signatures, settings sheet.
- `MetronomeScreen.jsx` — the screen; `useMetronome.js` — timing/ramp logic.

Layout: header (wordmark + settings) → BeatRing dial with giant BPM → dynamic-mode glass card → subdivision / signature pickers → fixed transport bar.
