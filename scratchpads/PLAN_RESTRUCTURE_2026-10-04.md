# PLAN — Restrukturierung: Architektur · Informationsarchitektur · Gefühl (2026-10-04)

**Auftrag (Founder 2026-10-04, wörtlich):** „Das gesamte produkt restrukturieren. Die gesamte
architekur der DMMW und das feeling soll überarbeitet werden. Vermeide slop.“

**Wie gearbeitet wurde.** Zuerst gemessen: vier Prüfungen nur mit Lesezugriff (Architektur,
Domänenmodell, Navigation, Gestaltung), jede mit `datei:zeile`. Die tragenden Zahlen sind von
Hand nachgemessen; der Befehl steht jeweils daneben. Danach kommt das Zielbild. Gebaut wird erst
nach dem Migrationsplan, in umkehrbaren Scheiben, eine Scheibe je Zyklus, jede durch die beiden
Gates geprüft.

**Was „ohne Slop“ hier heißt.** Kein Neuschreiben im Großen. Keine neue Abstraktion, die nicht
sofort zwei Dubletten ersetzt. Keine Behauptung ohne Messung. Kein Regler, Knopf oder Typ ohne
Aufrufer. Jede Scheibe nimmt mehr weg, als sie hinzufügt, oder ersetzt mindestens zwei Wege
durch einen.

Rangfolge: `docs/dev/FOUNDER_PRODUCT_LAW.md` legt den Umfang fest, `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`
die Reihenfolge der WA-Arbeit. Dieser Plan ordnet sich darunter ein: er ist der **Querschnitt**
durch alle WA-Phasen. Neue Fähigkeiten baut er nicht.

---

## 1. Befund — gemessen

### 1A Architektur: ein Gottobjekt und viele Besitzer pro Tatsache

| Befund | Messung | Befehl |
|---|---|---|
| `EchoelStudioView` ist das Gottobjekt | 13 359 Zeilen · 77 `@State`-Deklarationen · 116 `@AppStorage` · 47 `@Environment` | `wc -l`; `grep -cE '^\s*@State\b'` |
| Die View besitzt die App-Abläufe | `startBiofeedback` :9919 · `stopEverything` :10099 · `generate` :10799 · `saveProject` :11816 | `grep -nE 'func (saveProject\|stopEverything\|generate\|startBiofeedback)\b'` |
| Die Komposition steckt im App-Struct | `EchoelmusicApp.swift` 1 709 Zeilen · 57 `.environment(`-Injektionen · rund 60 langlebige Objekte | `wc -l`; `grep -c '\.environment('` |
| Der Zustand „läuft“ hat drei Besitzer | `@State running` · `bus.instrumentRunning` · `transport.isPlaying` | Architektur-Audit |
| Das Tempo hat drei Spiegel und zwei Speicherorte | Transport · MetronomeVoice · `preflightTempo`; `studio.lockedBPM` und `Project.bpm` | Architektur-Audit |
| Undo hat vier Besitzer | TimelineStore-Stapel · PianoRollModel · MediaLookUndo · `patchBeforeSoundChange` | Architektur-Audit |
| Views steuern die Uhr direkt | 8 Aufrufe von `pattern.play/stop/setTempo` in `Studio/` | `git grep -nE '(pattern\|beatPlayer\.pattern)\??\.(play\|stop\|setTempo)\(' -- Studio` |
| Einstellungen sind zersplittert | 313 `@AppStorage` app-weit, dazu rund 46 direkte `UserDefaults` | `git grep -c '@AppStorage'` |
| Toter Code | rund 7 250 Zeilen in 36 Dateien (EchoelAI/ allein 1 232) ohne Aufrufer | Architektur-Audit |

### 1B Domänenmodell: Speichern und Öffnen sind nicht symmetrisch

- `DMMWProject` (`Core/DMMWProject.swift`) wird **geschrieben** (`SessionSaveOpen.capturing` →
  `DMMWProjectImport.envelope`). `restoreSong` **liest** davon nur Timeline und Clip-Raster.
  Timebase, `musical`, `sound` und `songForm` werden gespeichert, aber nie wieder gelesen. Die
  TempoMap wird als Konstante plus 4/4 gebaut und nie gelesen; `Transport.beatsPerBar = 4` ist
  fest verdrahtet.
- **Gar nicht in der Session** stehen Licht (`LightingStore`, nur im Speicher), Raum
  (`SpatialSceneStore`, nur im Speicher), Routing (`SignalRouter`, UserDefaults), Modulation
  (`ModulationMatrix`, UserDefaults) und Kollaboration.
- Das Genre hat zwei Heimaten (`musical.styleRaw` und der `echoel`-Blob im DeviceInsert).
- Die Geräte-Identität hat drei Formen (`com.echoelmusic.device.echoel` ·
  `echoel.instrument` · `echoel.bodyvibe`). `.assemble(` hat 0 Aufrufer.

**Folge für den Nutzer:** Ein gespeichertes Projekt öffnet sich mit anderem Licht, anderem Raum,
anderem Routing und anderer Modulation, als beim Speichern eingestellt waren. Für eine
Workstation ist das der schwerste Befund, weil man ihn nicht sieht: die Datei sieht vollständig
aus.

### 1C Informationsarchitektur: viele Türen für dieselbe Fähigkeit

| Fähigkeit | Türen heute | Problem |
|---|---|---|
| Play / Stop | 7 | drei Komponenten mit drei Darstellungen von „spielt“ |
| Aufnahme ● | 4 | zwei Bedeutungen auf einem Bildschirm (MIDI-Take im Kopf, WAV in der Startzeile) |
| Tempo | 5 | — |
| Mix | 4 | „Mixer“ ist ein Reiter, „Mix“ und „Master“ sind Chips |
| Klang | 4 | — |
| Visual | 4 | — |
| Audio-Export | 3 | Der Chip „Save/Export“ speichert nicht und exportiert nicht |

Dazu kommen:
- **Zwei Welten:** Auf dem leeren Stück ist Play gesperrt, auf der Instrument-Bühne startet
  dieselbe Taste das Biofeedback.
- **Chrome:** mindestens 105 pt oben (mit Spur 162 pt) und rund 102 pt unten. Auf einem
  iPhone bleibt der Arbeitsfläche damit gut die Hälfte.
- **Rund 40 Substantive** auf oberster Ebene. „Field“ und „Studio“ werden nirgends erklärt.

### 1D Gefühl: Tokens ohne Komponenten

- Farbe, Radien (4/8/12), Schriftrampe (11·12·13·15·18·22) und Steuerhöhen (32/44) sind als
  Tokens vorhanden. **Abstand, Bewegung und Deckkraft haben keine Tokens:** 246 `.padding` und
  448 `spacing:` mit Zahlen-Literal (`git grep -cE '\.padding\([^)]*[0-9]'`), 4 Kurven und
  5 Dauern ohne Namen.
- **Es gibt keinen einzigen `ButtonStyle`** in `Sources/`. Dieselbe Werkzeug-Taste ist drei Mal
  als private Funktion `button(` abgeschrieben: `SelectedPartBar` :364, `PartNoteEditor` :711,
  `SongHistoryRow` :80. Es gibt vier Varianten der Haupttaste und drei Chip-Stile.
- **„Ausgewählt“ hat drei Darstellungen**, „spielt“ ebenfalls. `ProjectHeader` :334 und
  `SelectedPartBar` :436 legen Grün flächig hinter ein Label, gegen die Theme-Regel.
- Karte in Karte: `panel("Mix")` → `mixStripCard`, außerdem „Tempo & variations“.
- Haptik nur stellenweise: `EchoelValueField` und `EchoelNumberPad` geben keine.
- Broadcast „live“ nimmt `danger` statt `recording`.

---

## 2. Zielbild

### 2A Architektur — vier Schichten, ein Besitzer pro Tatsache

```
Darstellung   Bühnen (Arrange · Mixer · Instrument · Browse · Project) + Detailbereich
              → lesen Zustand, senden ABSICHTEN. Kein pattern.play, kein Store-Schreiben im body.
                         │ Absichten (play, stop, record, setTempo, save, open, undo …)
Steuerung     SessionController (@MainActor @Observable) — EIN Besitzer für:
              run state · start/stop · generate · save/open · undo-Verlauf · Tempo-Absicht
                         │
Domäne        DMMWProject = DAS Dokument. Öffnen liest alles, was Speichern schreibt:
              timebase · musical · tracks/devices · timeline · media · automation ·
              lighting · spatial · routing · modulation
                         │
Engine        PatternEngine = die EINE Uhr · Transport = der EINE Tempo-Besitzer ·
              EngineBus (Bio/MIDI/Musical-Frames) · AudioEngine · Sync-Sender
```

Regeln, an denen jede Scheibe gemessen wird:
1. **Eine Tatsache, ein Besitzer.** Tempo gehört `Transport` (persistiert in `Project.bpm`).
   „Läuft“ gehört `SessionController`. Undo ist eine Historie mit `HistoryStep`-Arten.
2. **Absicht statt Durchgriff.** Views rufen `session.play()`, nicht `pattern.play()`. Der
   Controller entscheidet, ob Bio startet, ob die Timeline spielt und wer protokolliert.
3. **Die Rundreise ist die Wahrheit.** Ein Wächter speichert ein voll belegtes Dokument, öffnet
   es und vergleicht Feld für Feld. Was er nicht vergleicht, gilt als nicht persistiert.
4. **Die Komposition ist kein App-Struct.** `EchoelmusicApp` baut einen `AppGraph` aus Modulen
   (Audio · Bio · Sync · Session) und injiziert diesen Graphen. Die Verdrahtung wandert aus dem
   Struct in die Module, ohne dass sich ihre Reihenfolge ändert.

### 2B Informationsarchitektur — eine Welt, eine Tür pro Fähigkeit

Die DAW-Hülle (E18 „Ja, so bauen“) ist der Rahmen. Was dieser Plan ergänzt, ist die Regel
**eine Tür pro Fähigkeit**:

| Fähigkeit | Die EINE Tür | Was wegfällt |
|---|---|---|
| Play / Stop / ⏮ | Steuerleiste (S1) | Kopf-Play, Startzeilen-Play, Teil-Play als zweite Darstellung |
| Aufnahme ● | Steuerleiste = Take auf die gewählte Spur | „●“ in der Startzeile wird zu „Bounce“ unter Export |
| Tempo / Tonart | Anzeigeblatt der Steuerleiste („Song“) | Tempo-Feld in der Instrument-Startzeile wird zur Anzeige |
| Mischen | Bühne „Mixer“ | die Chips „Mix“ und „Master“ |
| Klang | Detailbereich der gewählten Spur → Gerät | der Sound-Chip als zweite Tür |
| Speichern / Öffnen / Export | ≡-Menü | der Chip „Save/Export“ |
| Körper (Bio) | Puls in der Steuerleiste | Bio-Start über Play auf der Instrument-Bühne |

**Eine Welt:** Das Instrument ist die Geräteseite der Echoel-Spur, keine zweite App. Play heißt
überall Transport. Der Körper wird über den Puls gestartet. Auf einem leeren Stück startet Play
das Instrument als Spur und ist damit nicht mehr gesperrt.

### 2C Gefühl — Sprache: ruhig, präzise, körperlich

Leitbild bleibt Uncodixfy (Linear · Raycast · Logic): Zahlen zuerst, monochrome Chrome, Grün
nur für Signal.

| Schicht | Ziel |
|---|---|
| Tokens | `EchoelTheme.Space` (4 · 8 · 12 · 16 · 24) · `Motion` (`quick` 0,12 s · `standard` 0,18 s, beide ease-out, nur Deckkraft und Farbe) · `Opacity` (`pressed` · `disabled`) |
| Komponenten | **vier Tastenstufen** als `ButtonStyle`: Primary (Fläche `.text`) · Secondary (Rahmen) · Tool (Fläche `fill`, 44 pt) · Chip (eine Form) |
| Zustände | **spielt** = grünes Symbol plus Rahmen `borderStrong`, nie eine grüne Fläche · **an / gewählt** = invertiert monochrom (Fläche `.text`, Label `onPrimary`), wie Mute/Solo und die Chips · **Objekt ausgewählt** (Spur, Teil) = Rahmen 2 pt statt 1 pt (`TheSelectedTrackIsNotColourAloneTests`) — ⛔ hier stand „ausgewählt = Rahmen `borderStrong` 1 pt plus `fill`“: nicht baubar, weil jedes Bedienelement schon in Ruhe `borderStrong` trägt (`ControlBoundaryIsInteractiveTests`), der Rahmen also AN nicht von AUS trennt (F4a) · **nimmt auf** = `recording` · **gedrückt** = Deckkraft `pressed` |
| Struktur | keine Karte in einer Karte; ein Panel hat eine Fläche |
| Haptik | Auswahl-Tick am Rastpunkt von `EchoelValueField`, Bestätigung bei OK auf dem Zahlenfeld, Start und Stopp des Transports. Nie auf der Render-Bahn |
| Bewegung | 0,12 bis 0,18 s, nur Deckkraft und Farbe, „Bewegung reduzieren“ wird respektiert |

---

## 3. Migration — Scheiben in Reihenfolge

Jede Scheibe: höchstens drei Dateien plus Wächter, wenn es geht, und **eine logische Änderung**.
Wird es mehr, steht der Grund im Commit-Text. Gates: Xcode Compile Check plus CI/CD
`Build for Testing`. Gerät: gesammelt nach `FOUNDER_INBOX.md` §2.

**Phase F — Gefühl, Fundament (additiv, kein Verhalten ändert sich)**
- **F1 Werkzeug-Taste als `ButtonStyle`.** `EchoelToolButtonStyle` in `EchoelTheme`. Die drei
  privaten `button(`-Abschriften nehmen ihn. Ein Wächter verlangt genau eine Definition und
  keine private Abschrift mit `.fill(EchoelTheme.fill)`.
- **F2 Tokens für Abstand, Bewegung und Deckkraft.** Plus Migration der Literale in den Dateien
  von F1. Eine Ratsche hält fest, dass die Zahl der Literale nur sinken darf.
- **F3 Ein „spielt“.** `PlaybackToggleButton` wird die einzige Play-Taste. Die beiden grünen
  Flächen (`ProjectHeader` :334, `SelectedPartBar` :436) werden zu grünem Symbol plus Rahmen.
- **F4 Ein „ausgewählt“, ein Chip-Stil.** Gemessen 2026-10-04: „ausgewählt“ hat nicht drei, sondern zwei
  saubere Grammatiken (siehe §2C) plus zwei Ausreißer. **F4a** — Click und Warp zeigten AN als grüne Fläche;
  sie nehmen jetzt die Mute/Solo-Form (`TheSwitchedOnStateIsMonochromeTests`, Ratsche 8 → 6).
  **F4b** — gemessen: elf invertierte Kacheln in `Sources/`, neun davon mit dem unsichtbaren `border`
  (1,16:1) im AUS-Zustand. Alle neun nehmen `borderStrong` (`TheChosenTileDeclaresItsBoundaryTests`).
  Ein Zusammenlegen der Chip-Ansichten bleibt aus: ihre Abstände (11/12) und Höhen sind je durch
  Wächter begründet (`TapTargetFloorTests`, `ThePresetChipMeetsTheInPanelFloorTests`), und die Gemeinsamkeit,
  die zählte — Füllung, Label, Rand —, ist jetzt eine.
- **F5 Haptik** an `EchoelValueField` (Rastpunkt) und `EchoelNumberPad` (OK), über den
  vorhandenen Haptik-Helfer aus Slice 13b.
- **F6** Karte in Karte auflösen (Mix, Tempo & variations); Broadcast „live“ → `recording`.

**Phase I — Informationsarchitektur (Verhalten ändert sich, freigegeben über E18)**
- **I1 = DAW-Hülle S1:** EINE Steuerleiste ersetzt topBar, Kompositionsstreifen und
  ProjectHeader. Das spart rund 50 bis 90 pt Chrome.
- **I2 Eine Aufnahme-Bedeutung:** ● = Take; das WAV-Mitschneiden wandert als „Bounce“ unter
  Export.
- **I3 Eine Welt:** Play = Transport auf jeder Bühne; Bio startet über den Puls; das leere Stück
  ist spielbar.
- **I4 Die Doppel-Türen abbauen**, mit Ratsche: die Chips „Mix“, „Master“ und „Save/Export“;
  das Tempo-Feld wird zur Anzeige.
- **I5 = DAW-Hülle S10:** die Instrument-Modals in den einen Hüllen-Slot (`.sheet(item:)`-Enum).
  Das gibt Kopfraum im Black-Screen-Budget frei.

**Phase A — Architektur (hinter unverändertem Verhalten)**
- **A1 `SessionController` als Saum.** Ein neuer Typ, der `play/stop/isRunning` besitzt und
  intern zunächst die heutigen drei Quellen liest. Die 8 direkten `pattern.`-Aufrufe in
  `Studio/` laufen über ihn, mit Ratsche auf 0.
- **A2 Run-State, ein Besitzer:** `@State running` und `bus.instrumentRunning` werden
  Projektionen des Controllers.
- **A3 Die Rundreise schließen, Domäne für Domäne:** `musical`/`timebase` zuerst (Tempo, Takt,
  Tonart), dann Licht, Raum, Routing, Modulation. Der Rundreise-Wächter wächst je Domäne.
- **A4 Ein Tempo-Besitzer:** `Transport`, persistiert nur noch in `Project.bpm`; `lockedBPM`
  bleibt Migrationsquelle.
- **A5 Save/Open aus der View** in den Controller (`SessionSaveOpen` bleibt der Serialisierer).
- **A6 Eine Undo-Historie:** die vier Besitzer werden `HistoryStep`-Arten.
- **A7 `AppGraph`:** die Verdrahtung in `EchoelmusicApp` wird modulweise herausgezogen, die
  Reihenfolge bleibt erhalten, die Injektionen ohne Leser fallen weg.
- **A8 Toter Code:** erst nach Founder-Antwort E21.

**Reihenfolge und Begründung.** Phase F zuerst, weil jede I-Scheibe neue Tasten braucht und
diese sonst eine vierte Abschrift würden. Phase I vor A, weil I1 (S1) freigegeben ist und den
größten spürbaren Gewinn bringt. Phase A läuft verschränkt: A1 vor I3, denn „eine Welt“ braucht
den einen Run-State-Besitzer.

---

## 4. Was dieser Plan NICHT tut

- Kein Neuschreiben von `EchoelStudioView` in einem Zug. Die Datei schrumpft scheibenweise,
  indem Besitz zum Controller wandert.
- Keine neuen Abhängigkeiten oder Targets. HaishinKit bleibt gesperrt (Klassifikator-Ablehnung,
  Founder-Entscheidung).
- Kein Löschen türloser Dateien ohne Founder-Antwort (E21). `SessionView`/`SessionEngine`
  tragen getestete Sicherheitsgesetze.
- Keine Store- oder Website-Aussage ändert sich durch diesen Plan.
- Die Engineering-Gesetze bleiben: Black-Screen-Kette, Hot-State, `EchoelValueField`,
  3-Hz-Grenze, Audio-Thread, Rausch-Triade.

## 5. Founder-Fragen

- **E21** (neu in `FOUNDER_INBOX.md`): rund 7 250 Zeilen ohne Aufrufer löschen? Empfehlung: ja
  für die Kerne ohne Gesetzeswert (EchoelAI-Werkzeugschicht, nie konstruierte Klassen). Nein für
  `SessionView`/`SessionEngine`, `BioSourceView`/`BreathGuideView`, `PulseMeasurementView` und
  `ProUnlockView`/`EchoelStore`; die tragen Gesetze oder sind für v1.1 vorgesehen.

Alles Übrige ist durch „Du entscheidest“ (2026-10-03) und E18/E19 gedeckt und steht in
`decisions.csv`.

## 6. Fortschritt

| Scheibe | Stand |
|---|---|
| F1 | gebaut — `ef49372bf`; Compile Check grün, Auto-Merge → main = `ef49372bf` (⇒ Build for Testing grün); Gerät offen |
| F2a | gebaut — `704e0acfa` (Abstands-Skala `spaceXS…spaceXL`, F1-Dateien migriert, Ratsche 696) |
| F2b | gebaut — zwei Bewegungs-Tokens, sieben Übergänge; F2a+F2b mit Auto-Merge → main = `6f1d71279` (⇒ Compile Check + Build for Testing grün); Gerät offen |
| F3 | gepusht — `8613d84d6`: „spielt“ = grünes Label im `borderStrong`-Rahmen auf `fill`, nie eine Fläche (`TheRunningStateIsOneLookTests`); Gates laufen |
| F4a | lokal — `a0a53ba98`: ein eingeschalteter Schalter ist die invertierte Monochrom-Kachel, nie grün (`TheSwitchedOnStateIsMonochromeTests`; Ratsche 8 → 6) |
| F4b | lokal — `39d77bf3b`: jeder Schalter und jede gewählte Kachel zeichnet ihre Kante mit `borderStrong` (`TheChosenTileDeclaresItsBoundaryTests`) |
| F5a | lokal — `a585fa507`: das Wertfeld tickt an Standard und Rand (`.selection`), OK auf dem Ziffernblock bestätigt (`.success`) (`TheValueFieldTicksAtItsDetentsTests`) |
| F5b | lokal — `75645cff9`: das EINE Play/Stop ist spürbar (`.start` / `.stop`) (`TheTransportIsFeltWhenItStartsAndStopsTests`) |
| F6a | lokal — `360e6be0d`: ein Mix-Streifen hat keine eigene Fläche, die Karte ist das Panel (`TheMixStripHasNoSurfaceOfItsOwnTests`) |
| F6b | lokal — `d4e7d1b9d`: Broadcast „live“ trägt das Aufnahme-Rot, nicht das Fehler-Rot (`TheLiveStateIsTheRecordingRedTests`) |

F2 ist bewusst in zwei Commits geteilt (Abstand und Bewegung), damit jeder eine logische Änderung bleibt. Die Deckkraft-Tokens gab es schon (`dim`, `border`, `fill`, `pressedOpacity`); dafür war keine Scheibe nötig.

Haptik (F5) sitzt nur an UI-Blättern, nie auf einem Render-Pfad; ob sie sich gut anfühlt, ist ein Geräte-Blick. F6 nimmt die Fälle, die §3 nennt: Karte in Karte in „Mix“ und „Tempo & variations“ (ein Helfer, fünf Streifen) und Broadcast „live“. Eine app-weite Suche nach weiteren Karten in Karten ist NICHT gelaufen.
