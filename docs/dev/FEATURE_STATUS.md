# FEATURE STATUS — was läuft, was versteckt ist, was gestrichen ist

Stand: 2026-09-23 · v10.79.480 / Build 2600 · gemessen am Code, nicht aus dem Gedächtnis.

**Wozu diese Datei.** `FEATURE_MATRIX.md` ist über Monate gewachsen und trägt viele datierte
Schichten. Deshalb ist aus ihr kaum noch zu lesen, was HEUTE in der App steckt. Diese Seite hat genau
drei Fächer und eine Regel: **nichts darf gebaut sein, ohne hier zu stehen.** Wer eine Ansicht
löscht, versteckt oder wieder erreichbar macht, zieht diese Seite im selben Commit mit.

Wächter: `Tests/CISmoke/EveryHiddenSurfaceIsInTheStatusRegisterTests.swift`. Er wird rot, sobald eine
SwiftUI-Ansicht existiert, die nirgends gebaut wird und hier fehlt. Er fängt nur diese eine Form (siehe
„Grenzen“ unten).

Legende „Gerät“: **ja** = am Gerät bestätigt (Datum) · **offen** = baut und ist erreichbar, aber
noch nicht am Gerät bestätigt.

---

## 1. LÄUFT UND IST ERREICHBAR

| Wo in der App | Was | Gerät |
|---|---|---|
| Chip **Sound** | Synth-Klang formen: Presets, Ton/Filter/Hüllkurve, Speichern-als, Favoriten | offen |
| Chip **FX** | Effekt-Charakter; „Alle FX“ öffnet die volle Effektkette (`EchoelFXView`) | offen |
| Chip **Mix** | Pegel je Stimme (Bass · Melodie) | offen |
| Chip **Master** | Master-Lautstärke, Lautheit, Ausgang | offen |
| Chip **Mood** | Genre, Charakter, Wetter-Färbung, Takt-Variation (#1402) | offen |
| Chip **Tempo** | Tap-Tempo, Metronom, Haptik-Beat, „Explore“ (6 Varianten, bewertet) | offen |
| Chip **Field** | die spielbare Bildfläche; Visual-Feinregler | offen |
| Chip **Workstation** | Spur anlegen, Audio importieren, abspielen; Tonart, Stimmton und Tempo werden erkannt; Warp-Schalter; Tempo je Datei korrigieren (×2 · ÷2 · von Hand, S1); Tonhöhe je Audiospur (±24 Halbtöne, #165) | **ja (Import + Play, 2026-09-23)**; Tempo-Korrektur und Tonhöhe offen |
| Chip **Save/Export** | Projekt speichern/öffnen, MIDI-Export, Loop-Länge, Klang zurücksetzen, Guide, Diagnose | offen |
| Puls-Pille (Kopfzeile) | Bio-Panel: Puls, HRV, Kohärenz, Quellenwahl, „Body voice“, Apple-Health-Schreiben | offen |
| Bio-Quellen | Kamera-Puls (Finger auf Linse), Apple Health (auch Watch), BLE-Brustgurt (0x180D), Demo | Kamera: ja |
| Kopfzeile | schwebendes Visual-Fenster, Donut-Visual | offen |
| Kopfzeile „•••“ | Routing (OSC, ADM-OSC, Art-Net, sACN, MIDI-Out, MPE-Out, MIDI 2.0, Modulations-Matrix „Body → parameter“) · Live Colabo · Learn | offen |
| im Hintergrund | MIDI-Keyboard spielt eine Performer-Stimme · OSC-Ausgang · OSC-Steuereingang (Opt-in) | offen |
| AUv3-Plugin | Echoel als Instrument in anderen Apps | ja (AUM, 2026-09-20) |

Die zwei offenen Punkte aus dem Ship-Gate (**Klang** und **Stabilität**) kann nur ein Gerät
entscheiden. Die Liste aller Geräteproben druckt `python3 scripts/founder-verify.py`.

---

## 2. GEBAUT, ABER VERSTECKT — keine Tür in der App

Diese Teile existieren und kompilieren, ein Nutzer kommt aber nicht an sie heran. **Nichts davon ist
zum Löschen freigegeben.** Jede Zeile nennt, warum es versteckt ist und was eine Tür kosten würde.

### 2a. Ansichten, die nirgends gebaut werden (vom Wächter geprüft)

Messen: `python3 scripts/doctor.py --section C` (Abschnitt „never constructed“).

| Ansicht | Was sie kann | Warum versteckt | Tür kostet |
|---|---|---|---|
| `AnalysisScopeView` | Oszilloskop des Ausgangs | Founder-X am 2026-08-02 (Field zeigt keine Messgeräte) | eine Zeile + Beschriftung |
| `AnalysisSpectrumView` | Spektrum, Spitzenton mit Notenname | wie oben | eine Zeile |
| `AnalysisPoincareView` | Poincaré-Plot der Herzschläge (HRV) | wie oben | eine Zeile |
| `AnalysisWavefrontView` | Wellenfront-Ringe (Alter · Klangfarbe) | wie oben | eine Zeile |
| `BioSourceView` | alte Bio-Seite; trägt Atem-Führung und Puls-Messanzeige | seit dem Tools-Grid-Abbau (2026-07-02) ohne Tür | ein Knopf im Bio-Panel |
| `ImmersiveStageView` | Raumkarte: jede Spur als Punkt im Raum, ADM-OSC-Status | Ship-Gate 4: Raum „demonstrierbar, nicht Pflicht“ | ein Chip oder Routing-Knopf |
| `SessionView` | geführte Session mit Atemtakt | Founder 2026-07-06: „keine Atemübung“ | nur mit neuer Founder-Entscheidung |
| `ProUnlockView` | Kauf-Seite (StoreKit) | Preismodell v1.1 (Jahres-Abo) steht aus | erst mit v1.1 |
| `BroadcastView` | RTMP-Livestream | HaishinKit ist nicht verlinkt; eine Tür führte ins Leere | erst mit neuer Abhängigkeit |

### 2b. Versteckt, eine Ebene tiefer (der Wächter sieht sie NICHT)

| Teil | Wo es hängt | Tür kostet |
|---|---|---|
| `BreathGuideView` (Atem-Führung, Blitz-Grenze ≤ 0,2 Hz) | nur in `BioSourceView` | die Tür zu `BioSourceView` |
| `PulseMeasurementView` (Puls-Messanzeige) | nur in `BioSourceView` | dito; der Hinweistext erscheint schon heute im Bio-Panel |
| `ADMStreamStatusLine` | nur in `ImmersiveStageView` | die Tür zur Raumkarte |
| `MeditationView` | wird gebaut, aber `showMeditation` kann nie wahr werden | ein Knopf, der den Schalter setzt (Founder: bewusst so) |
| **MIDI-Datei-Import** (`importMIDI`) | der Dateiwähler blockierte Audio-Import und wurde in #W1 gelöscht; die Funktion lebt ohne Knopf | ein Knopf in der Workstation, **mit eigenem Wähler an der Stelle, nicht an der Wurzel** |

### 2c. Maschine läuft, aber kein Regler

| Fähigkeit | Stand | Was fehlt |
|---|---|---|
| Tonhöhe je einzelnem TEIL (statt je Spur) | je Spur läuft seit #165 | ein neues gespeichertes Feld je Teil |
| Stretch-Modi außer „clean“ | Engine kann es | eine Auswahl je Teil |
| Erkannte Tonart übernehmen | wird nur angezeigt, nie übernommen (Absicht) | Founder-Entscheidung + ein Knopf |
| Timeline-Automation | gespeicherte Kurven SPIELEN, aber keine Fläche kann eine zeichnen | Zeichenfläche (Workstation-Grenze!) |
| „Follow pulse“-Tempo (`BioTempoDirector`) | fertig, aber ein Zwilling des lebenden Servos | Entscheidung, welcher gilt |
| Raum-Render (7 Kerne: VBAP, Ambisonics, Binaural, Raumhall …) | Steuer-Hälfte (ADM-OSC) läuft | Audio-Anbindung |
| `CloudSync`, `BioSpaceMap`, `VisualModulation`, `AudioFeatureExtractor` | reine Kerne, kein Aufrufer | je ein Aufrufer |
| Watch-App | Target existiert, wird nicht mit ausgeliefert | Transport Telefon→Uhr (`WCSession`, neues Framework) |
| Mehrspur-Aufnahme | Kette gebaut, flag-aus | ein Audio-EINGANG, den es nicht mehr gibt |

⚠️ **Zehn Feature-Flags haben null Leser** (`spatialEngine`, `bioSpace`, `echoelRender`, `motionEngine`,
`showControl`, `avObjects`, `performerTracking`, `liveCollab`, `headTracking`, `echoelAI`). Hinter
ihnen steckt nichts. Sie sind Platzhalter, keine versteckten Funktionen.
Messen: `git grep -n "FeatureFlags.<name>" -- Sources | grep -v ': *//'`.

---

## 3. GESTRICHEN — per Founder-Entscheidung entfernt

Nichts davon ist verloren: jeder Stand liegt in der Git-Historie unter der genannten Nummer.
Zurückholen heißt aber meist **neu bauen**, nicht wieder anhängen.

| Was | Wann / Nummer | Founder-Grund |
|---|---|---|
| Drums / Beat-Maker / Sampler-Kit | 2026-07-26, #166/#167 | Fokus aufs Instrument |
| Noten-Editor (Piano Roll) | 2026-07-26, #178/#475 | „Pianoroll soll raus“ |
| DAW-Arrangement (Clips, Arrange-Timeline, Mixer-Spuren) | 2026-07-24…31, #121 | Instrument statt Workstation |
| AUv3-HOST (fremde Plugins laden) | #121 Slice 2 | wie oben (das Echoel-PLUGIN ist zurück, #1385) |
| Mikrofon / Audio-Eingang, Vocoder, Autotune | 2026-09-12, #1302 | „Face und Audio Input komplett entfernen“ |
| Harmonizer, Granularsynthese | 2026-09-12, #1305 | wörtlich gestrichen |
| Gesichts-/Körper-Tracking | 2026-09-12, #1301 | wie Audio-Eingang |
| Video-Aufnahme und -Schnitt | 2026-09-12, #1304 (Schnitt schon #121) | „Kein Video Capture“ |
| Vollbild-Visual, VJ-Overlay | #1069 | durch das schwebende Fenster ersetzt |

---

## 4. NIE GEBAUT — Roadmap, keine Lücke

RTMP-Livestream · Bewegungs-Sensor · EEG · MPE-**Eingang** mit Zonen (MPE-Ausgang läuft) · iPad ·
Mac · Vision Pro. Video/KI-Video steht als Roadmap in `scratchpads/ROADMAP_VIDEO_AWB_AI_2026-09-23.md`.

---

## Grenzen dieser Seite

- Der Wächter prüft nur **2a**: Ansichten, die im ganzen `Sources/` kein einziges Mal gebaut werden.
  Er sieht keine Ansicht, die nur von einer toten Ansicht gebaut wird (2b), keinen Schalter, der nie
  wahr wird, und keine Funktion ohne Knopf. Die stehen hier von Hand. `doctor.py --section C` zeigt
  die ersten beiden Sorten ebenfalls.
- „Läuft“ in Fach 1 heißt: kompiliert, und eine Tür führt hin. Klang, Gefühl und Stabilität sind
  damit nicht bewiesen.
