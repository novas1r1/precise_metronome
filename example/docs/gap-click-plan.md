# Gap Click Trainer – Implementierungsplan

Status: Entwurf zur Umsetzung · Stand: 10.09.2026
Zielgruppe: Coding-KI (Claude Code / Cursor) und Verry als Reviewerin
Zugehörige Datei: `gap_click_mockup.html` (funktionales Mockup, auch in Anhang A eingebettet)

---

## 0. Anweisungen an die Coding-KI (zuerst lesen)

1. **Nicht sofort implementieren.** Starte mit Phase 0 (Codebase-Analyse) und liefere einen kurzen Bericht. Implementierung erst nach Freigabe.
2. **Bestehende Konventionen haben Vorrang.** Architektur, State Management, Naming, Ordnerstruktur, Test-Setup und Styling der App gehen vor. Alle Code-Skizzen in diesem Dokument sind Vorschläge, keine Vorgaben.
3. **Offene Entscheidungen (Abschnitt 10) nicht selbst treffen.** Nachfragen, bevor du dazu Code schreibst.
4. **Keine neuen Dependencies, kein Analytics/Tracking** ohne Rückfrage.
5. **Das Mockup ist eine funktionale Referenz**, kein Visual Design. Das UI folgt dem bestehenden Design der App. Die Audio-Logik im Mockup (WebAudio, Zufall zur Schedule-Zeit) ist ausdrücklich **nicht** als Vorlage für die App gedacht – siehe Abschnitt 5.
6. Arbeite phasenweise (Abschnitt 11) und halte nach jeder Phase an: Zusammenfassung, Tests grün, offene Punkte.

### Phase-0-Bericht soll beantworten

- Welche Audio-Engine nutzt die App (z. B. `precise_metronome`: AVAudioEngine auf iOS, Oboe auf Android)? Wie werden Beats geplant (Lookahead, Sample-Position, Callback)?
- Lässt sich pro Beat (inkl. Subdivisions) sample-genau muten bzw. ein Gain setzen? Falls nein: minimaler Eingriff, um das zu ermöglichen.
- Gibt es einen Takt-/Beat-Zähler im nativen Code, und liefert die Engine Beat-Events an Dart (mit Bar- und Beat-Index)?
- Welche Features existieren bereits: Taktarten, Subdivisions, Akzente, Count-in, Presets/Songs/Setlists, Tempo-Ramps, Haptik, Screen-Flash?
- Läuft Dart zuverlässig im Hintergrund bzw. bei gesperrtem Bildschirm (iOS Background Audio, Android Foreground Service), sodass Dart-seitig Daten an die Engine nachgeliefert werden können? (Entscheidet zwischen Option A und B in Abschnitt 5.2.)
- Wie ist In-App-Kauf/Entitlement umgesetzt (z. B. RevenueCat)?
- Wie werden Einstellungen lokal persistiert?

---

## 1. Kontext und Ziel

**Gap Click:** Der Metronom-Klick setzt nach einem Muster taktweise aus, die Clock läuft weiter. Nach der Pause kommt der Klick zurück – der Spieler hört, ob er das Tempo gehalten hat. Trainiert wird das innere Timing statt Abhängigkeit vom Klick.

**Warum:** Dieses Training gibt es aktuell nicht plattformübergreifend als Einmalkauf (Time Guru nur iPhone, Takt/Tack nur Android, Soundbrenner im Abo). Es ist als Kern der Pro-Version der Metronom-App vorgesehen.

**Wichtigstes Qualitätskriterium:** Die Clock bleibt sample-genau. Der erste Klick nach einer Pause muss exakt auf dem Raster sitzen – sonst ist das Feature wertlos.

---

## 2. Scope

### In v1

- Modi: **Fest**, **Zufall**, **Leiter**, **Beat-Maske** (Beat-Maske als letzte Feature-Phase, verschiebbar – siehe Entscheidung 7)
- Landing-Akzent (eigener Sound für den ersten Klick nach einer Pause)
- Anzeigeregeln für Pausen (Beat-Anzeige ausblenden, Haptik/Flash aus)
- Takt-Streifen mit Vorschau
- Eingebaute Presets + eigene Presets
- Persistenz der letzten Einstellung
- Pro-Gating nach Entscheidung 1

### Nicht in v1

- **Landing-Check** (Messung der Abweichung per Mikrofon oder Tap) – bewusst ausgeklammert, Entscheidung 2
- Statistiken/Historie
- Kombination mit Tempo-Ramps im selben Lauf (v1.1)
- Zufall auf Beat-Ebene (nur Takt-Ebene in v1, Entscheidung 6)
- Apple Watch / Wear OS

---

## 3. Begriffe

| Begriff | Bedeutung |
|---|---|
| Takt (bar) | Ein Takt der aktuellen Taktart, Index ab 0 ab Start (Count-in zählt nicht) |
| Beat | Zählzeit innerhalb eines Takts, Index ab 0 |
| Stummer Takt | Takt, in dem kein Beat hörbar ist (inkl. Subdivisions) |
| Zyklus | Klick-Takte + Stumm-Takte (Modi Fest, Leiter) |
| Landing-Beat | Erster hörbarer Beat nach mindestens einem stummen Takt |
| BarPlan | Geplantes Muster eines Takts: welche Beats hörbar sind, ob Landing |

---

## 4. Funktionale Spezifikation

### 4.1 Modi und Parameter

**Fest** – wiederholt: `clickBars` Takte Klick, dann `silentBars` Takte stumm.

| Parameter | Typ | Bereich | Default |
|---|---|---|---|
| clickBars | int | 1–8 | 2 |
| silentBars | int | 1–8 | 2 |

**Zufall** – jeder Takt ist mit Wahrscheinlichkeit `silentProbability` stumm.

| Parameter | Typ | Bereich | Default |
|---|---|---|---|
| silentProbability | double | 0.10–0.80 (Schritt 0.05) | 0.30 |
| maxConsecutiveSilent | int | 1–4 | 2 |

Regeln: Takt 0 ist immer hörbar. Nach `maxConsecutiveSilent` stummen Takten in Folge ist der nächste Takt zwingend hörbar.

**Leiter** – wie Fest, aber die Stumm-Takte steigen automatisch.

| Parameter | Typ | Bereich | Default |
|---|---|---|---|
| clickBars | int | 1–8 | 2 |
| startSilentBars | int | 1–8 | 1 |
| maxSilentBars | int | 1–16 | 8 |
| cyclesPerStep | int | 1–8 | 2 |

Regeln: Nach je `cyclesPerStep` vollständigen Zyklen erhöht sich die Zahl der Stumm-Takte um 1, bis `maxSilentBars` erreicht ist; danach bleibt sie konstant.

**Beat-Maske** – jeder Takt ist gleich, nur bestimmte Beats sind hörbar.

| Parameter | Typ | Bereich | Default |
|---|---|---|---|
| beatAudible | List\<bool\> | Länge = Beats pro Takt | 4/4: „2 und 4“ = `[false, true, false, true]` |

Presets für 4/4: „2 und 4“, „1“, „1 und 3“. Bei Taktartwechsel wird die Maske auf „alle hörbar“ zurückgesetzt, sofern kein passendes Preset existiert (Nutzer sieht den Zustand in der UI). Kein Landing-Beat in diesem Modus.

### 4.2 Verhaltensregeln

- **Clock läuft durch.** „Stumm“ bedeutet ausschließlich: kein Audio, keine Haptik, kein Flash. Timing und Zähler laufen unverändert weiter.
- **Subdivisions:** In stummen Takten sind Subdivisions ebenfalls stumm. In der Beat-Maske sind Subdivisions gemuteter Beats stumm (Entscheidung 8).
- **Landing-Akzent:** Der Landing-Beat nutzt einen eigenen, klar unterscheidbaren Sound (Entscheidung 5). Einstellbar, Default an.
- **Count-in:** Falls vorhanden, ist der Count-in immer hörbar und nicht Teil des Musters. Takt 0 ist der erste Takt nach dem Count-in.
- **Start:** Muster beginnt bei Takt 0; Leiter startet bei `startSilentBars`.
- **Stop → Start:** Muster beginnt neu.
- **Tempoänderung während der Wiedergabe:** Wirkt wie bisher sofort; das Muster bleibt unverändert (es ist taktbasiert).
- **Änderung von Modus, Parametern oder Taktart während der Wiedergabe:** Wirkt ab dem nächsten Takt, der noch nicht begonnen hat. Fest und Leiter starten ab dort mit einer Klick-Phase. Zufall übernimmt die Zählung aufeinanderfolgender stummer Takte aus der Historie.
- **Hintergrund/Sperrbildschirm:** Muster läuft weiter.
- **Audio-Unterbrechung** (Anruf, Alarm, Route-Change): Nach Wiederaufnahme startet das Muster neu bei Takt 0.
- **Gap aus:** Alle Beats hörbar, bisheriges Verhalten der App unverändert.

### 4.3 Anzeige

- **Takt-Streifen:** aktueller Takt hervorgehoben, dazu ca. 6–7 Takte Vorschau.
  - Fest/Leiter: Vorschau zeigt „Klick“/„stumm“.
  - **Zufall: zukünftige Takte als „?“** – eine sichtbare Vorschau würde die Übung entwerten.
  - Beat-Maske: Streifen zeigt das Maskenmuster.
  - Zustand nicht nur über Farbe kodieren (Text und/oder gestrichelter Rahmen).
- **Beat-Anzeige in stummen Takten ausblenden:** Option, Default an.
- **Haptik und Screen-Flash in stummen Takten:** immer aus (nicht konfigurierbar).
- **Verbleibende Stumm-Takte anzeigen:** Option, Default aus; im Modus Zufall nicht verfügbar.
- **Status-Text:** „Klick läuft“ / „Stumm – Zeit halten“ / „Landing – warst du drauf?“
- **Leiter:** aktuelle Stufe (Anzahl Stumm-Takte) sichtbar.
- Alle UI-Updates kommen aus Engine-Beat-Events, nicht aus eigenen Dart-Timern.
- Accessibility: Semantics-Labels für alle Steuerelemente; Status-Text als Live-Region.

### 4.4 Presets

Eingebaut:

| Name | Konfiguration |
|---|---|
| Einstieg | Fest 4 / 1 |
| Klassiker | Fest 2 / 2 |
| Fortgeschritten | Fest 1 / 3 |
| Zufall leicht | Zufall 20 %, max. 1 am Stück |
| Leiter Standard | Leiter 2 Klick, Start 1, max. 8, Stufe alle 2 Zyklen |

Eigene Presets: aktuelle Gap-Konfiguration inkl. Anzeigeoptionen unter einem Namen lokal speichern, umbenennen, löschen. Falls die App bereits ein Song-/Preset-System hat: siehe Entscheidung 4.

---

## 5. Architektur

### 5.1 Grundprinzip

**Das Muten passiert im nativen Audio-Scheduler.** Dart schaltet niemals per Timer die Lautstärke. Der native Scheduler rendert jeden Beat wie bisher an seiner Sample-Position und entscheidet anhand des BarPlans nur, ob ein Sample ausgegeben wird.

### 5.2 Aufteilung

**Option A (empfohlen): Generator in Dart, Queue in nativer Engine**

- `GapPatternGenerator` (pure Dart, ohne Flutter-Abhängigkeit, voll unit-testbar) erzeugt BarPlans.
- Dart übergibt der Engine BarPlans im Voraus: Ziel 8 Takte Lookahead, Nachfüllen, sobald weniger als 4 Takte gepuffert sind (getriggert durch Beat-Events).
- Bei Konfigurationsänderung ersetzt Dart alle gepufferten Pläne ab dem nächsten noch nicht begonnenen Takt.
- **Fail-audible:** Findet die Engine für einen Takt keinen Plan, spielt sie alle Beats hörbar und loggt eine Warnung. Ein fehlender Plan darf nie zu Stille führen.

**Option B (nur falls Phase 0 zeigt, dass Dart im Hintergrund nicht zuverlässig nachliefert):** Generator zusätzlich nativ (Swift + C++) mit identischem, geseedetem PRNG. Deutlich mehr Aufwand und Duplikation – vorher Rücksprache.

### 5.3 Datenmodell (Skizze)

```dart
sealed class GapConfig {
  const GapConfig();
}

class FixedGapConfig extends GapConfig {
  final int clickBars;   // 1–8
  final int silentBars;  // 1–8
  const FixedGapConfig({this.clickBars = 2, this.silentBars = 2});
}

class RandomGapConfig extends GapConfig {
  final double silentProbability;  // 0.10–0.80
  final int maxConsecutiveSilent;  // 1–4
  const RandomGapConfig({this.silentProbability = 0.30, this.maxConsecutiveSilent = 2});
}

class LadderGapConfig extends GapConfig {
  final int clickBars;        // 1–8
  final int startSilentBars;  // 1–8
  final int maxSilentBars;    // 1–16
  final int cyclesPerStep;    // 1–8
  const LadderGapConfig({
    this.clickBars = 2,
    this.startSilentBars = 1,
    this.maxSilentBars = 8,
    this.cyclesPerStep = 2,
  });
}

class BeatMaskGapConfig extends GapConfig {
  final List<bool> beatAudible;  // Länge = beatsPerBar
  const BeatMaskGapConfig(this.beatAudible);
}

class GapSettings {
  final GapConfig? config;               // null = Gap aus
  final bool hideBeatIndicatorWhenSilent; // Default true
  final bool landingAccent;               // Default true
  final bool showRemainingSilentBars;     // Default false
}

class BarPlan {
  final int barIndex;
  final List<bool> beatAudible;  // Länge = beatsPerBar
  final bool isLanding;          // Beat 0 dieses Takts ist Landing-Beat
  bool get isSilent => !beatAudible.contains(true);
}
```

### 5.4 Generator (Skizze)

```dart
class GapPatternGenerator {
  GapPatternGenerator({
    required GapConfig config,
    required int beatsPerBar,
    Random? random,  // injizierbar für deterministische Tests
  });

  /// Liefert den Plan für [barIndex]. Erzeugt sequentiell und cached die
  /// Historie, da Zufall und Leiter vom Verlauf abhängen.
  BarPlan planFor(int barIndex);

  /// Neue Konfiguration ab [fromBar]. Historie < fromBar bleibt erhalten.
  void reconfigure(GapConfig config, {required int fromBar, int? beatsPerBar});
}
```

Regeln für `isLanding`: `true`, wenn Takt `i - 1` stumm ist und Takt `i` hörbar ist (nur bar-basierte Modi). In der Beat-Maske immer `false`.

Die Entscheidung, ob der Landing-Sound tatsächlich gespielt wird, fällt in Dart (`isLanding && settings.landingAccent`) und wird der Engine als eigenes Flag mitgegeben (z. B. `useLandingSound`), damit die Engine keine Settings kennen muss.

### 5.5 Engine-Schnittstelle (Vorschlag, an bestehende API anpassen)

```dart
abstract interface class GapCapableEngine {
  /// Hängt Pläne an den Puffer an.
  Future<void> enqueueBarPlans(List<EngineBarPlan> plans);

  /// Ersetzt alle gepufferten Pläne mit barIndex >= [fromBar].
  Future<void> replaceBarPlansFrom(int fromBar, List<EngineBarPlan> plans);

  /// Leert den Puffer; alle Beats wieder hörbar.
  Future<void> clearBarPlans();

  /// Beat-Events aus der Engine für UI, Haptik, Flash und Nachfüllen.
  Stream<BeatEvent> get beatEvents;
}

class EngineBarPlan {
  final int barIndex;
  final List<bool> beatAudible;
  final bool useLandingSound;
}

class BeatEvent {
  final int barIndex;
  final int beatIndex;
  final bool muted;
  final bool isLanding;
  // plus vorhandene Timing-Infos der Engine (z. B. hostTime)
}
```

Native Seite (iOS und Android identisch im Verhalten):

1. Beim Rendern von Takt `b`, Beat `k`: Plan für `b` im Puffer suchen.
2. Kein Plan → hörbar (fail-audible) + Warn-Log.
3. `beatAudible[k] == false` → kein Sample für diesen Beat und seine Subdivisions.
4. `useLandingSound && k == 0` → Landing-Sample statt Akzent-Sample.
5. Beat-Event mit `muted` und `isLanding` an Dart senden.
6. Pläne für vergangene Takte aus dem Puffer entfernen.
7. Bar-Zähler: startet bei 0 nach dem Count-in; Dart und Engine müssen denselben Index verwenden.

Haptik und Flash: Wo immer sie ausgelöst werden (Dart oder nativ), müssen sie `muted` respektieren.

---

## 6. UI

Referenz: `gap_click_mockup.html` (im Browser öffnen, mit Ton spielbar) bzw. Anhang A.

Elemente:

- Modus-Auswahl: Fest / Zufall / Leiter / Maske
- Parameter je Modus (Stepper bzw. Slider, Bereiche laut 4.1)
- Takt-Streifen und Beat-Anzeige nach Regeln aus 4.3
- Status-Text
- Schalter: Beat-Anzeige in Pausen ausblenden, Landing-Akzent, Verbleibende Stumm-Takte anzeigen
- Preset-Auswahl und „Als Preset speichern“
- Pro-Hinweis an gesperrten Modi (nach Entscheidung 1)

Platzierung in der App: Entscheidung 3. Schlage auf Basis des bestehenden UI eine Variante vor.

---

## 7. Monetarisierung (Vorschlag – Entscheidung 1)

- **Free:** Modus Fest mit Preset „Klassiker 2/2“, Anzeigeoptionen und Landing-Akzent.
- **Pro (Einmalkauf):** alle Modi, frei einstellbare Parameter, eigene Presets.

Umsetzung über die bestehende Entitlement-Abstraktion. Gating in UI **und** bei der Übernahme von Konfigurationen (z. B. beim Laden eines Presets nach Ablauf einer Test- oder Promo-Freischaltung). Keine Hardcodierung der Aufteilung an mehreren Stellen – eine zentrale Stelle, die festlegt, welche Configs Pro erfordern.

---

## 8. Tests

### 8.1 Unit-Tests Generator (Pflicht)

- **Fest 2/2:** Takte 0–7 → hörbar, hörbar, stumm, stumm, hörbar, hörbar, stumm, stumm.
- **Leiter** (clickBars 2, start 1, max 3, cyclesPerStep 2):
  `H H S | H H S | H H S S | H H S S | H H S S S | H H S S S | …` (bleibt bei 3).
- **Zufall** mit geseedetem `Random`:
  - Takt 0 hörbar.
  - Nie mehr als `maxConsecutiveSilent` stumme Takte in Folge (10.000 Takte).
  - Mit `maxConsecutiveSilent` = 4 und p = 0.30 liegt der Stumm-Anteil über 10.000 Takte plausibel unter p, aber deutlich über 0 (Toleranz im Test begründen, nicht raten).
  - Gleicher Seed → gleiche Sequenz.
- **Landing:** korrekt nach jedem stummen Block; nie bei Beat-Maske; nie bei Takt 0.
- **reconfigure:** Pläne < fromBar unverändert; ab fromBar neues Muster; Fest/Leiter beginnen ab fromBar mit Klick-Phase; Zufall übernimmt laufende Stumm-Serie.
- **beatsPerBar-Wechsel:** Länge von `beatAudible` passt; Maske fällt auf „alle hörbar“ zurück, wenn kein Preset passt.

### 8.2 Engine / Integration

- Falls die Engine einen Offline-Render- oder Test-Hook hat: N Takte rendern, Klicks pro Takt zählen, Landing-Sample an der korrekten Sample-Position prüfen.
- Fail-audible: leerer Puffer → alle Beats hörbar.
- `replaceBarPlansFrom`: bereits begonnener Takt bleibt unverändert.

### 8.3 Manuelle Testcheckliste (iOS und Android, inkl. schwaches Android-Gerät)

- [ ] Geräteausgabe bei 120 BPM, Fest 2/2, 5 Minuten in eine DAW aufnehmen: Landing-Klicks liegen genauso auf dem Raster wie normale Klicks.
- [ ] 5 Minuten bei gesperrtem Bildschirm: Muster läuft korrekt weiter.
- [ ] Bluetooth-Kopfhörer: Muster korrekt (Latenz ist bekannt, darf aber nicht driften).
- [ ] Parameteränderung während der Wiedergabe wirkt ab dem nächsten Takt.
- [ ] Tempoänderung während eines stummen Takts: Landing sitzt im neuen Tempo korrekt.
- [ ] Unterbrechung (Anruf/Alarm) und Wiederaufnahme: Muster startet neu, keine Stille-Hänger.
- [ ] Zufall: Vorschau zeigt „?“; Beat-Anzeige in Pausen ausgeblendet; keine Haptik/kein Flash in Pausen.
- [ ] Gap aus: Verhalten identisch zur App vor dem Feature.

---

## 9. Akzeptanzkriterien

- [ ] Alle vier Modi funktionieren gemäß 4.1 und 4.2 auf iOS und Android.
- [ ] Muting erfolgt im nativen Scheduler; Landing-Klick ist sample-genau.
- [ ] Fail-audible ist implementiert und getestet.
- [ ] Anzeigeregeln aus 4.3 sind umgesetzt (inkl. „?“ im Zufallsmodus).
- [ ] Eingebaute und eigene Presets funktionieren; letzte Einstellung wird persistiert.
- [ ] Pro-Gating gemäß getroffener Entscheidung 1.
- [ ] Unit-Tests aus 8.1 grün; manuelle Checkliste 8.3 abgehakt.
- [ ] Keine Regression bei ausgeschaltetem Gap.

---

## 10. Offene Entscheidungen (von Verry zu treffen – nicht selbst festlegen)

1. **Free/Pro-Aufteilung** – Vorschlag in Abschnitt 7.
2. **Landing-Check (Messung per Mikrofon/Tap)** – gehört er in die Metronom-App oder als Coaching-Feature in Drumbitious? Nicht Teil dieses Plans.
3. **Platzierung im UI** – Bereich im Hauptscreen, Bottom Sheet oder eigener Screen.
4. **Presets** – eigenständige Gap-Presets oder Gap-Konfiguration als Teil bestehender Song-/Setlist-Presets.
5. **Landing-Sound** – eigenes Sample oder höhere Tonhöhe/Lautstärke des Akzent-Samples.
6. **Zufall** – nur pro Takt (Vorschlag v1) oder zusätzlich pro Beat.
7. **Beat-Maske** – in v1 oder in ein späteres Update verschieben.
8. **Subdivisions bei gemuteten Beats in der Beat-Maske** – mit stumm (Vorschlag) oder hörbar lassen.

---

## 11. Umsetzungsphasen

| Phase | Inhalt | Ergebnis / Stopp-Punkt |
|---|---|---|
| 0 | Codebase-Analyse (Fragen aus Abschnitt 0) | Bericht, Wahl Option A/B, Freigabe |
| 1 | Datenmodell + `GapPatternGenerator` + Unit-Tests (8.1) | Tests grün |
| 2 | Engine-Integration iOS + Android: Puffer, replace, fail-audible, Landing-Sound, Beat-Events | Integrationstests / Aufnahme-Test |
| 3 | UI: Modus, Parameter, Streifen, Anzeigeregeln, Status | Review mit Screenshots |
| 4 | Presets + Persistenz | Review |
| 5 | Beat-Maske (falls Entscheidung 7 = v1) | Review |
| 6 | Pro-Gating (nach Entscheidung 1) | Review |
| 7 | Manuelle Tests (8.3), Feinschliff | Abnahme nach Abschnitt 9 |

---

## Anhang A: Funktionales Mockup (HTML)

Als Datei `gap_click_mockup.html` im Browser öffnen, um das Verhalten mit Ton zu testen. Hinweise:

- Visuelles Design ist nicht verbindlich.
- Die Audio-Logik (WebAudio mit 120 ms Lookahead, Zufall wird beim Schedulen gewürfelt) ist eine Browser-Vereinfachung. In der App gilt Abschnitt 5.
- Das Mockup nutzt fest 4/4 und keine Subdivisions.

```html
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gap Trainer – funktionales Mockup</title>
<style>
:root{--bg:#f3f3f1;--card:#fff;--soft:#ecebe7;--text:#1c1c1a;--text2:#5f5e5a;--border:rgba(0,0,0,.13);--border2:rgba(0,0,0,.28);--accent:#185FA5;--accent-bg:#E6F1FB}
@media (prefers-color-scheme:dark){:root{--bg:#1b1b1a;--card:#262624;--soft:#31312f;--text:#f1efe8;--text2:#b4b2a9;--border:rgba(255,255,255,.14);--border2:rgba(255,255,255,.3);--accent:#85B7EB;--accent-bg:#0C447C}}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:var(--bg);color:var(--text);font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;padding:24px}
.phone{width:100%;max-width:380px;background:var(--card);border:1px solid var(--border);border-radius:20px;padding:18px}
button{font:inherit;color:var(--text);background:transparent;border:1px solid var(--border2);border-radius:8px;padding:6px 10px;cursor:pointer}
button:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.seg{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:14px 0 4px}.seg button{font-size:13px;padding:6px 4px}
.seg button.on,.mask button.on{background:var(--accent-bg);color:var(--accent);border-color:var(--accent)}
.row{display:flex;align-items:center;gap:10px;margin:10px 0;font-size:13px;color:var(--text2)}
.row .val{min-width:18px;text-align:center;color:var(--text)}
.st{width:30px;height:30px;padding:0}
.strip{display:flex;gap:5px;margin:14px 0 8px}
.cell{flex:1;height:36px;border-radius:6px;border:1px solid var(--border);display:flex;align-items:center;justify-content:center;font-size:11px;color:var(--text2)}
.cell.aud{background:var(--soft)}.cell.sil{border-style:dashed}.cell.cur{border:2px solid var(--accent);color:var(--accent)}
.dots{display:flex;justify-content:center;gap:14px;margin:12px 0 6px;min-height:16px}
.dot{width:16px;height:16px;border-radius:50%;background:var(--soft);border:1px solid var(--border2)}.dot.hit{background:var(--accent);border-color:var(--accent)}.dot.off{opacity:.35}
.mask{display:flex;gap:6px}.mask button{font-size:12px;padding:5px 8px}
#status{text-align:center;font-size:13px;color:var(--text2);margin:4px 0 10px;min-height:20px}
#play{width:100%;height:44px;margin-top:8px;font-weight:500}
input[type=range]{accent-color:var(--accent)}
</style>
</head>
<body>
<main class="phone" aria-label="Gap Trainer Mockup">
  <div style="display:flex;align-items:baseline;justify-content:space-between">
    <span style="font-size:13px;color:var(--text2)">Gap Trainer</span>
    <span><span id="bpmOut" style="font-size:30px;font-weight:500">92</span><span style="font-size:13px;color:var(--text2)"> BPM</span></span>
  </div>
  <input type="range" id="bpm" min="40" max="200" step="1" value="92" style="width:100%" aria-label="Tempo">

  <div class="seg" role="group" aria-label="Modus">
    <button data-m="fix" class="on">Fest</button><button data-m="rnd">Zufall</button><button data-m="lad">Leiter</button><button data-m="mask">Maske</button>
  </div>

  <section id="pBars">
    <div class="row"><span style="flex:1">Klick-Takte</span><button class="st" data-k="on" data-d="-1" aria-label="Klick-Takte verringern">−</button><span class="val" id="onOut">2</span><button class="st" data-k="on" data-d="1" aria-label="Klick-Takte erhöhen">+</button></div>
    <div class="row"><span style="flex:1" id="offLbl">Stumm-Takte</span><button class="st" data-k="off" data-d="-1" aria-label="Stumm-Takte verringern">−</button><span class="val" id="offOut">2</span><button class="st" data-k="off" data-d="1" aria-label="Stumm-Takte erhöhen">+</button></div>
  </section>
  <section id="pRnd" hidden>
    <div class="row"><span style="flex:1">Stumm-Wahrscheinlichkeit</span><input type="range" id="prob" min="10" max="80" step="5" value="30" style="width:110px" aria-label="Stumm-Wahrscheinlichkeit"><span class="val" id="probOut" style="min-width:36px">30%</span></div>
    <div class="row"><span style="flex:1">Max. Stumm-Takte am Stück</span><button class="st" data-k="max" data-d="-1" aria-label="verringern">−</button><span class="val" id="maxOut">2</span><button class="st" data-k="max" data-d="1" aria-label="erhöhen">+</button></div>
  </section>
  <section id="pMask" hidden>
    <div class="row"><span style="flex:1">Klick nur auf</span>
      <div class="mask" role="group" aria-label="Beat-Maske">
        <button data-mask="0101" class="on">2 und 4</button><button data-mask="1000">1</button><button data-mask="1010">1 und 3</button>
      </div>
    </div>
  </section>

  <div class="strip" id="strip" aria-hidden="true"></div>
  <div class="dots" id="dots" aria-hidden="true"></div>
  <p id="status" aria-live="polite">Bereit</p>

  <div class="row"><label for="hide" style="flex:1">Beat-Anzeige in Pausen ausblenden</label><input type="checkbox" id="hide" checked></div>
  <div class="row"><label for="land" style="flex:1">Landing-Akzent nach Pause</label><input type="checkbox" id="land" checked></div>
  <div class="row"><label for="remain" style="flex:1">Verbleibende Stumm-Takte anzeigen</label><input type="checkbox" id="remain"></div>

  <button id="play">Start</button>
</main>

<script>
const $ = id => document.getElementById(id);
const BEATS = 4;
let mode = 'fix', onB = 2, offB = 2, prob = 30, maxSil = 2, mask = [0,1,0,1], bpm = 92;
let ctx = null, playing = false, timer = null;
let plan = [], ladderOff = 1, ladderCycles = 0;
let nextTime = 0, beat = 0, bar = 0, queue = [], curBar = 0, curBeat = -1;

function extend() {
  if (mode === 'fix') {
    for (let i = 0; i < onB; i++) plan.push(true);
    for (let i = 0; i < offB; i++) plan.push(false);
  } else if (mode === 'lad') {
    for (let i = 0; i < onB; i++) plan.push(true);
    for (let i = 0; i < ladderOff; i++) plan.push(false);
    ladderCycles++;
    if (ladderCycles % 2 === 0 && ladderOff < 8) ladderOff++;
  } else if (mode === 'rnd') {
    if (plan.length === 0) { plan.push(true); return; }
    let run = 0;
    for (let i = plan.length - 1; i >= 0 && !plan[i]; i--) run++;
    plan.push(run >= maxSil ? true : Math.random() * 100 >= prob);
  } else {
    plan.push(true);
  }
}
function barAudible(i) { while (plan.length <= i) extend(); return plan[i]; }
function beatAudible(b, k) { return mode === 'mask' ? mask[k] === 1 : barAudible(b); }
function isLanding(b, k) { return mode !== 'mask' && k === 0 && b > 0 && barAudible(b) && !barAudible(b - 1); }

function resetPlan() {
  plan = plan.slice(0, curBar + 1);
  ladderOff = 1; ladderCycles = 0;
  render();
}

function click(t, freq, vol) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.frequency.value = freq;
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
  o.connect(g); g.connect(ctx.destination);
  o.start(t); o.stop(t + 0.06);
}

function schedule() {
  while (nextTime < ctx.currentTime + 0.12) {
    if (beatAudible(bar, beat)) {
      if (isLanding(bar, beat) && $('land').checked) click(nextTime, 1600, 0.9);
      else click(nextTime, beat === 0 ? 1100 : 800, beat === 0 ? 0.7 : 0.45);
    }
    queue.push({ t: nextTime, bar, beat });
    nextTime += 60 / bpm;
    beat++;
    if (beat >= BEATS) { beat = 0; bar++; }
  }
}

function tick() {
  if (!playing) return;
  while (queue.length && queue[0].t <= ctx.currentTime) {
    const q = queue.shift();
    curBar = q.bar; curBeat = q.beat;
    render();
  }
  requestAnimationFrame(tick);
}

function render() {
  const strip = $('strip');
  strip.innerHTML = '';
  const start = Math.max(0, curBar - 1);
  for (let i = start; i < start + 8; i++) {
    const d = document.createElement('div');
    const hiddenFuture = mode === 'rnd' && (playing ? i > curBar : i > 0);
    if (mode === 'mask') {
      d.className = 'cell aud';
      d.textContent = mask.map(m => m ? '●' : '·').join('');
    } else if (hiddenFuture) {
      d.className = 'cell';
      d.textContent = '?';
    } else {
      const a = barAudible(i);
      d.className = 'cell ' + (a ? 'aud' : 'sil');
      d.textContent = a ? 'klick' : 'stumm';
    }
    if (playing && i === curBar) d.classList.add('cur');
    strip.appendChild(d);
  }

  const silentBar = mode !== 'mask' && !barAudible(curBar);
  const hide = playing && silentBar && $('hide').checked;
  const dots = $('dots');
  dots.innerHTML = '';
  for (let k = 0; k < BEATS; k++) {
    const d = document.createElement('div');
    d.className = 'dot';
    if (mode === 'mask' && !mask[k]) d.classList.add('off');
    if (playing && !hide && k === curBeat) d.classList.add('hit');
    d.style.visibility = hide ? 'hidden' : 'visible';
    dots.appendChild(d);
  }

  let st = 'Bereit';
  if (playing) {
    if (silentBar) {
      st = 'Stumm – Zeit halten';
      if ($('remain').checked && mode !== 'rnd') {
        let n = 1;
        for (let i = curBar + 1; !barAudible(i) && n < 20; i++) n++;
        st += ' (' + n + ')';
      }
    } else if (isLanding(curBar, 0) && curBeat === 0) {
      st = 'Landing – warst du drauf?';
    } else {
      st = 'Klick läuft';
    }
  }
  $('status').textContent = st;
  $('offLbl').textContent = mode === 'lad' ? 'Stumm-Takte (Start ' + 1 + ', aktuell ' + ladderOff + ')' : 'Stumm-Takte';
}

document.querySelectorAll('.seg button').forEach(b => b.onclick = () => {
  mode = b.dataset.m;
  document.querySelectorAll('.seg button').forEach(x => x.classList.toggle('on', x === b));
  $('pBars').hidden = !(mode === 'fix' || mode === 'lad');
  $('pRnd').hidden = mode !== 'rnd';
  $('pMask').hidden = mode !== 'mask';
  resetPlan();
});
document.querySelectorAll('.st').forEach(b => b.onclick = () => {
  const d = +b.dataset.d, k = b.dataset.k;
  if (k === 'on') onB = Math.min(8, Math.max(1, onB + d));
  if (k === 'off') offB = Math.min(8, Math.max(1, offB + d));
  if (k === 'max') maxSil = Math.min(4, Math.max(1, maxSil + d));
  $('onOut').textContent = onB; $('offOut').textContent = offB; $('maxOut').textContent = maxSil;
  resetPlan();
});
document.querySelectorAll('.mask button').forEach(b => b.onclick = () => {
  mask = b.dataset.mask.split('').map(Number);
  document.querySelectorAll('.mask button').forEach(x => x.classList.toggle('on', x === b));
  render();
});
$('bpm').oninput = e => { bpm = +e.target.value; $('bpmOut').textContent = bpm; };
$('prob').oninput = e => { prob = +e.target.value; $('probOut').textContent = prob + '%'; resetPlan(); };
['hide', 'remain'].forEach(id => $(id).onchange = render);

$('play').onclick = () => {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  if (playing) {
    playing = false; clearInterval(timer); queue = []; curBeat = -1;
    $('play').textContent = 'Start'; render(); return;
  }
  ctx.resume();
  playing = true; plan = []; ladderOff = 1; ladderCycles = 0;
  beat = 0; bar = 0; curBar = 0; queue = [];
  nextTime = ctx.currentTime + 0.1;
  timer = setInterval(schedule, 25); schedule(); tick();
  $('play').textContent = 'Stop';
};
render();
</script>
</body>
</html>
```
