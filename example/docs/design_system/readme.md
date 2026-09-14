# Accel Design System

Accel is a dynamic metronome app. Its signature feature is **Dynamic Mode**: set a start BPM, a bar count and a step (e.g. 60 BPM, every 4 bars, +5) and the tempo climbs automatically — optionally to a target BPM, optionally back down in the same steps. It also offers subdivisions (quarters, eighths, triplets, sixteenths) and time signatures (3/4, 4/4, 6/8, 12/8 …).

**Sources:** none provided — this system was designed from the product brief only. No logo was supplied; the brand renders as the word "Accel" in Archivo. Fonts are Google Fonts (Archivo, IBM Plex Mono).

## Products
- **Accel app** (mobile-first, 390px) — the main metronome screen. See `ui_kits/accel-app/`.

## Content fundamentals
- Voice: calm coach, second person ("you"). Direct, short, lowercase-friendly UI labels.
- Casing: sentence case everywhere ("Start tempo", "Every 4 bars"). ALL-CAPS only for tiny tracked labels (`--tracking-label`) like "BPM", "BARS".
- Numbers are the hero. Always tabular (`font-feature-settings: var(--font-features-tabular)`), always in Archivo for large tempo digits, IBM Plex Mono for small readouts and status ("bar 3 of 4", "+5 → 120").
- No emoji. No exclamation marks. Musical terms are used correctly (bars, beats, subdivision, time signature) but never jargon for its own sake.
- Examples: "Start", "Stop", "Dynamic mode", "Increase by 5 BPM every 4 bars", "Ramp back down", "Target 140 BPM", "Tap to set tempo".

## Visual foundations
- **Palette:** deep navy ground (`--navy-950` #070B18) with hot coral accent (`--coral-500` #FF5E45). Mint = positive/downbeat-reached, sun yellow = accented beat, sky blue = descending ramp. Text is cool off-white, never pure white for body.
- **Type:** Archivo (variable, wide weight range) for everything from labels to the giant BPM number; tight tracking (-0.04em) on display sizes. IBM Plex Mono for readouts and units.
- **Surfaces:** soft glass — translucent white at 5–9% over navy, 1px 10% white border, `backdrop-filter: blur(18px)`. Cards use `--radius-lg` 22px, controls 14px, pills 999px. Shadows are deep and soft (`--shadow-glass`), never hard.
- **Backgrounds:** flat navy with one large radial coral glow behind the tempo dial, intensifying on each beat. No imagery, no patterns.
- **Motion:** the beat is the animation system. On every beat a ring expands from the dial and fades (`accel-beat`, 1.9× scale, ~400ms, `--ease-out`). Tempo changes count in with a spring (`--ease-spring`). Panels fade up 8px (`accel-fade-up`). Nothing bounces except the tempo digits.
- **Hover:** background brightens one glass step (5% → 9%). **Press:** scale 0.97 + `--accent-press`. **Focus:** 3px coral ring at 45%.
- **Borders:** 1px translucent white; strong variant 18%. No dividers inside cards — use spacing.
- **Layout:** single column, mobile-first (390px), max content width 480px centered on desktop. Transport (Start/Stop) is fixed at the bottom.
- **Transparency/blur:** only for glass surfaces and the bottom transport bar over content.
- **Corners:** 8 / 14 / 22 / 32 / pill.

## Iconography
- No icon set shipped with the brief. Components use **Lucide** via CDN (`https://unpkg.com/lucide@latest`), stroke 1.75, sized 20px in controls and 24px in the transport. Play/Pause/Plus/Minus/ChevronDown/Settings/X are the used glyphs. Music glyphs (note values) are drawn as text using Unicode ♩ ♪ where a subdivision needs a symbol. No emoji.
- Substitution flag: Lucide is a stand-in until a brand icon set exists.

## Components (`components/core/`)
Button, IconButton, Input, NumberField, Select, Switch, Segmented, Slider, Card, Badge, Dialog, Toast, Tooltip, BeatRing, AccentGrid.
Intentional additions: **NumberField** (stepper — the core input of dynamic mode), **Segmented** (subdivision / signature pickers), **BeatRing** (the beat visualiser), **AccentGrid** (per-slot accent toggles; accented slots are coral with glow).

## Index
- `styles.css` — global entry (imports `tokens/*.css`).
- `tokens/` — colors, typography, spacing/radius/motion, base keyframes.
- `guidelines/` — specimen cards for the Design System tab.
- `components/core/` — React primitives + `core.card.html`.
- `ui_kits/accel-app/` — main metronome screen (`index.html`, `MetronomeScreen.jsx`).
- `thumbnail.html`, `SKILL.md`.
