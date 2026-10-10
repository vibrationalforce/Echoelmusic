# FEATURE STATUS — was läuft, was versteckt ist, was gestrichen ist

> **Produktumfang ≠ diese Seite.** Was Echoelmusic werden soll, entscheidet
> [`FOUNDER_PRODUCT_LAW.md`](FOUNDER_PRODUCT_LAW.md) (DMMW, seit 2026-09-24). Diese Seite sagt nur, was HEUTE
> läuft. Fach 3 ist Historie: eine Streichung dort nahm eine Implementierung zurück, nicht die Fähigkeit.

Stand: 2026-10-04 · gemessen am Code und an den TestFlight-Läufen, nicht aus dem Gedächtnis. Die App spricht seit
v10.79.488 nur amerikanisches Englisch; die Wege unten nennen deshalb die englischen Wörter.

**Wozu diese Datei.** `FEATURE_MATRIX.md` ist über Monate gewachsen und trägt viele datierte
Schichten — sie bleibt die nachvollziehbare HERKUNFT (wann, warum, welche Nummer). Diese Seite sagt nur,
was HEUTE in der App steckt, und hat eine Regel: **nichts darf gebaut sein, ohne hier zu stehen.** Wer
eine Ansicht löscht, versteckt oder wieder erreichbar macht, zieht diese Seite im selben Commit mit.

Wächter: `Tests/CISmoke/EveryHiddenSurfaceIsInTheStatusRegisterTests.swift`. Er wird rot, sobald eine
SwiftUI-Ansicht existiert, die nirgends gebaut wird und hier fehlt. Er fängt nur diese eine Form (siehe
„Grenzen“ unten).

---

## 0. WELCHER STAND — drei Ebenen, nie vermischt

| Ebene | Stand | Beleg |
|---|---|---|
| **Ausgeliefert (TestFlight)** | **v10.79.490 · Build 2615** · Commit `4919d7001` · 2026-10-04 08:23 UTC | TestFlight-Lauf #2615 (`testflight.yml`, `BUILD_NUMBER` = `github.run_number`), Lauf 37188777769, Conclusion `success`; ob der Build in App Store Connect sichtbar ist, bestätigt der Founder |
| **In `main`, noch in keinem Build** | `73deb73ba` — F1–F6b (eine Gestaltungssprache) und A3a (Raum reist mit dem Stück), siehe 1b | Auto-Merge hat `main` dorthin bewegt ⇒ Xcode Compile Check + Build for Testing grün |
| **Am Gerät bestätigt** | nur die Zeilen mit **ja** und Datum | Founder-Beobachtung; offene Bitten: `python3 scripts/founder-verify.py` |

Messen statt abschreiben: `head -1 .deploy/release` (Version) · `git log -1 --format=%h -- .deploy/release`
(Commit) · `gh api repos/vibrationalforce/Echoelmusic/actions/workflows/testflight.yml/runs?per_page=1`
(`run_number` = Buildnummer) · `git ls-remote origin refs/heads/main`.

Spalten in Fach 1: **Fähigkeit** = was der Code kann · **Nutzerweg** = wie man in der App dorthin kommt ·
**Build** = der erste ausgelieferte Build, der diesen Weg trägt · **Gerät** = **ja** (Datum) oder **offen**.
„Offen“ heißt: baut, ist erreichbar, aber niemand hat es am Gerät gesehen. Für alles aus 2613–2615 gilt das ausnahmslos.

---

## 1. LÄUFT UND IST ERREICHBAR (ausgeliefert)

### 1a. Die gemeinsame Oberfläche

| Fähigkeit | Nutzerweg | Build | Gerät |
|---|---|---|---|
| Fünf Bereiche als eine Oberfläche | Umschalter unten **Arrange · Mixer · Instrument · Browse · Project**; quer eine Leiste links | 2614 | offen |
| Projekt-Menü | E-Logo oben links → **Open · Save │ Live Colabo · Learn │ Guide** | 2614 | offen |
| EIN Transport | Kopf: **Play / Stop / Record**; im Instrument hält „Pause“ auf der Platte, „Play“ setzt fort | 2614 | offen |
| Song-Einstellungen | **Project** → Tonart, Stimmung, Tempo-Modus | 2614 | offen |
| Undo/Redo der Stück-Bearbeitung | Kopf (`SongHistoryRow`) · mit Tastatur ⌘Z / ⇧⌘Z | 2613 | offen |
| Startet auf dem Stück, Visual als Karte | frische Installation → Arrange | 2609 | offen |

### 1b. In `main`, aber in KEINEM ausgelieferten Build (kommt mit dem nächsten Bump)

| Fähigkeit | Was sich ändert | Commit | Gerät |
|---|---|---|---|
| F1 ein Werkzeug-Knopf | `EchoelToolButtonStyle` ersetzt drei Kopien | `ef49372bf` | offen |
| F2a/F2b Abstände und Bewegung | eine Abstands-Skala `spaceXS…spaceXL`, zwei Bewegungs-Tempi | `704e0acfa` · `29ec3b6bc` | offen |
| F3 „spielt“ | grünes Wort im starken Rahmen, nie eine grüne Fläche | `8613d84d6` · `a74b17f1a` | offen |
| F4a/F4b Schalter und Auswahl | ein eingeschalteter Schalter ist die invertierte Monochrom-Kachel; jede gewählte Kachel zeichnet ihre Kante | `a0a53ba98` · `39d77bf3b` | offen |
| F5a/F5b Haptik | das Wertfeld tickt an Standard und Rand, OK bestätigt; das eine Play/Stop ist spürbar | `a585fa507` · `75645cff9` | offen |
| F6a/F6b Mixer-Streifen und Live-Rot | ein Mix-Streifen hat keine eigene Fläche; Broadcast „live“ trägt das Aufnahme-Rot | `360e6be0d` · `d4e7d1b9d` | offen |
| A3a Raum reist mit dem Stück | Sichern schreibt die Raumszene (Spur-Positionen + Raum) in das Stück; Öffnen stellt sie NACH den Spuren wieder her; ältere Stücke bekommen die Standard-Positionen | `73deb73ba` | offen |

### 1c. Arrange — das Stück

| Fähigkeit | Nutzerweg | Build | Gerät |
|---|---|---|---|
| Audio importieren und abspielen; Tonart, Stimmton, Tempo werden erkannt | leeres Stück: „Import Audio“ · sonst **Add** → „Import Audio“ | ≤ 2612 | **ja (Import + Play, 2026-09-23)** |
| Spuren anlegen, MIDI-Datei importieren, neues MIDI-Teil | leeres Stück: fünf Knöpfe · sonst **Add**-Menü | 2613 (Menü) | offen |
| Warp, Tempo je Datei (×2 · ÷2 · von Hand), Tonhöhe je Audiospur (±24) | Spur antippen → Detail **Track** / **Part** | ≤ 2612 | offen |
| Teile verschieben/kopieren/trimmen, Einrast-Tick pro Takt | Teil halten und ziehen · `SelectedPartBar` | 2613 (Tick) | offen |
| Zeit-Zoom | zwei Finger spreizen auf Arrange · „Zoom in“ / „Zoom out“ unter den Spuren | 2614 | offen |
| Detail folgt der Auswahl | Spur antippen → **Track · Part · Notes · Automation · Device** | 2614 | offen |
| Noten-Editor (`PartNoteEditor`) mit Zoom | Detail **Notes** · „Zoom in/out“ oder spreizen | 2614 | offen |
| Noten-Editor mit VoiceOver | VoiceOver auf dem Gitter → Aktionen „Add a note“, „Move earlier/later“, „Make longer/shorter“ | 2615 | offen |
| Automations-Kurven je Parameter | Detail **Automation** | ≤ 2612 | offen |
| MIDI-Aufnahme in eine scharfgeschaltete Spur | Kopf **Record** | ≤ 2612 | offen |
| Export MIDI · Export WAV (ganzes Stück, Echtzeit, ab Takt 1) | Arrange-Reiter „Export“ · „WAV“ → „Share WAV“ | 2613 (WAV) | offen |
| Foto und Video als Bild-Saat fürs Visual (kein Videoschnitt) | `PhotoSeedCard` · `VideoSeedCard` | ≤ 2612 | offen |

### 1d. Mixer · Browse · Instrument

| Fähigkeit | Nutzerweg | Build | Gerät |
|---|---|---|---|
| Spur-Streifen + Master-Kasten (Lautstärke, Pegel, LUFS/True-Peak, Clear) | **Mixer** | 2614 | offen |
| Klänge für die gewählte MIDI-Spur, Medienbibliothek | **Browse** → „Sounds“ · darunter die Bibliothek | 2614 | offen |
| Synth-Klang formen: Presets, Ton/Filter/Hüllkurve, Speichern-als, Favoriten | **Instrument** → Chip **Sound** | ≤ 2612 | offen |
| Effekt-Charakter, volle Effektkette | Chip **FX** → „All FX“ (`EchoelFXView`) | ≤ 2612 | offen |
| Pegel je Stimme · Master · Mood (Genre, Charakter, Wetter, Takt-Variation) · Tempo (Tap, Metronom, Haptik, Explore) · Field | Chips **Mix · Master · Mood · Tempo · Field** | ≤ 2612 | offen |
| Loop-Länge, Klang zurücksetzen, Textgröße, Diagnose | Chip **Save/Export** | ≤ 2612 | offen |
| Szenen starten | Instrument, zweite Sicht **Perform** | ≤ 2612 | offen |

### 1e. Körper, Bild, Ausgänge

| Fähigkeit | Nutzerweg | Build | Gerät |
|---|---|---|---|
| Bio-Panel: Puls, HRV, Kohärenz, Quellenwahl, „Body voice“, Apple-Health-Schreiben | Puls-Pille im Kopf | ≤ 2612 | offen |
| Quellen: Kamera-Puls, Apple Health (auch Watch), BLE-Brustgurt, Demo | Bio-Panel → Quelle | ≤ 2612 | **Kamera: ja** |
| Gurt verbindet sich nach Bluetooth aus/an wieder | automatisch | 2615 | offen |
| Kamera-Startfehler wird genannt | Bio-Panel-Zeile „The rear camera didn't start …“ | 2615 | offen |
| Atem-Führung „Release“ (4 s ein, 8 s aus, Ausatem-Hinweis, kein Mikrofon) | Bio-Panel → Atem-Führung → „Release“ | 2615 | offen |
| Schwebendes Visual-Fenster; ab „Large“ vier Messgeräte statt Bild | Monitor-Kachel im Kopf | ≤ 2612 | offen |
| Routing: OSC, ADM-OSC, Art-Net, sACN, MIDI-Out, MPE-Out, MIDI 2.0, Modulations-Matrix | Licht-Kachel im Kopf → Routing | ≤ 2612 | offen |
| Raum-Controller bewegt die Spuren (ADM-OSC-Eingang, Port 8001) | Routing → „Accept OSC control“ (+ „Every track as its own object“) | 2615 | offen |
| MIDI-Keyboard spielt eine Performer-Stimme; hört Echoels eigene Ausgänge nicht mehr | im Hintergrund | 2615 (Filter) | offen |
| AUv3-Instrument in anderen Apps (kein Hosting) | Host-App, z. B. AUM | ≤ 2612 | **ja (AUM, 2026-09-20)** |

Die zwei offenen Punkte aus dem Ship-Gate (**Klang** und **Stabilität**) kann nur ein Gerät
entscheiden. Die Liste aller Geräteproben druckt `python3 scripts/founder-verify.py`; die
gebündelte Runde steht in `docs/dev/FOUNDER_INBOX.md` §2.

---

## 2. GEBAUT, ABER VERSTECKT — keine Tür in der App

Diese Teile existieren und kompilieren, ein Nutzer kommt aber nicht an sie heran. **Nichts davon ist
zum Löschen freigegeben.** Jede Zeile nennt, warum es versteckt ist und was eine Tür kosten würde.

### 2a. Ansichten, die nirgends gebaut werden (vom Wächter geprüft)

Messen: `python3 scripts/doctor.py --section C` (Abschnitt „never constructed“).

| Ansicht | Was sie kann | Warum versteckt | Tür kostet |
|---|---|---|---|
| `BioSourceView` | alte Bio-Seite; trägt Atem-Führung und Puls-Messanzeige | seit dem Tools-Grid-Abbau (2026-07-02) ohne Tür | ein Knopf im Bio-Panel |
| `ImmersiveStageView` | Raumkarte: jede Spur als Punkt im Raum, ADM-OSC-Status | Ship-Gate 4: Raum „demonstrierbar, nicht Pflicht“ | ein Chip oder Routing-Knopf |
| `SessionView` | geführte Session mit Atemtakt | Founder 2026-07-06: „keine Atemübung“ | nur mit neuer Founder-Entscheidung |
| `ProUnlockView` | Kauf-Seite (StoreKit) | Preismodell v1.1 (Jahres-Abo) steht aus | erst mit v1.1 |
| `BroadcastView` | RTMP-Livestream | HaishinKit ist nicht verlinkt; eine Tür führte ins Leere. ⛔ **Broadcast S2 ist gesperrt:** das Einbinden von HaishinKit 2.2.5 als Swift-Paket in `project.yml` (für Build und TestFlight-Lauf) wurde am 2026-10-04 von der automatischen Sicherheitsprüfung zweimal abgelehnt („Untrusted Code Integration“). Kein Umweg; freischalten kann nur der Founder (Berechtigungsregel, interaktive Zustimmung oder selbst einbinden) | erst mit neuer Abhängigkeit, und erst nach Freigabe |

### 2b. Versteckt, eine Ebene tiefer (der Wächter sieht sie NICHT)

| Teil | Wo es hängt | Tür kostet |
|---|---|---|
| `BreathGuideView` (die Vollbild-Atem-Führung, Blitz-Grenze ≤ 0,2 Hz) | nur in `BioSourceView` | die Tür zu `BioSourceView`. ⚠️ Ihr Nachbar `BreathCoachStrip` in derselben Datei IST erreichbar (Bio-Panel) und trägt „Start“ und „Release“ |
| `PulseMeasurementView` (Puls-Messanzeige) | nur in `BioSourceView` | dito; der Hinweistext erscheint schon heute im Bio-Panel |
| `ADMStreamStatusLine` | nur in `ImmersiveStageView` | die Tür zur Raumkarte |
| `MeditationView` | wird gebaut, aber `showMeditation` kann nie wahr werden | ein Knopf, der den Schalter setzt (Founder: bewusst so) |
| `importMIDI` (der alte Weg ins INSTRUMENT) | der Dateiwähler blockierte Audio-Import und wurde in #W1 gelöscht; die Funktion lebt ohne Knopf. ⭐ Seit S2 gibt es MIDI-Import als TEIL in der Workstation (`MIDIImport`, Abschnitt 1) — dieser Weg hier lädt stattdessen in den Take des Instruments und bleibt absichtlich knopflos | Entscheidung des Founders, ob er entfällt |

### 2c. Maschine läuft, aber kein Regler

| Fähigkeit | Stand | Was fehlt |
|---|---|---|
| Tonhöhe je einzelnem TEIL (statt je Spur) | je Spur läuft seit #165 | ein neues gespeichertes Feld je Teil |
| Stretch-Modi außer „clean“ | Engine kann es | eine Auswahl je Teil |
| Erkannte Tonart übernehmen | wird nur angezeigt, nie übernommen (Absicht) | Founder-Entscheidung + ein Knopf |
| „Follow pulse“-Tempo (`BioTempoDirector`) | fertig, aber ein Zwilling des lebenden Servos | Entscheidung, welcher gilt |
| Raum-Render (7 Kerne: VBAP, Ambisonics, Binaural, Raumhall …) | Steuer-Hälfte (ADM-OSC aus und ein) läuft; im Kopfhörer ist nichts räumlich | Audio-Anbindung — der kleinste hörbare Weg ist S3 (binauraler Kopfhörer-Ausgang), Plan in `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §7 |
| Stream-Key in der Keychain (Broadcast S1) | gebaut, Build 2615 | eine Fläche — und die hängt an S2 (gesperrt, siehe 2a) |
| `CloudSync`, `BioSpaceMap`, `VisualModulation`, `AudioFeatureExtractor` | reine Kerne, kein Aufrufer | je ein Aufrufer |
| Echoel Grain (`GrainCloud`, GMMW GA-9) | reiner DSP-Kern: Körner aus einem geladenen Puffer (Position · Länge · Dichte · Streuung · Tonhöhe · Breite), portiert aus der mit dem Mikrofon entfernten Granular-Stufe; Spur-Insert (GA-10a), Vorab-Berechnung `GrainBake` (GA-10b), gespielt auf Audiospuren (GA-10c), Schreiber mit eigenem Muster je Spur + Neuberechnung bei Änderungen (GA-10d1), Zeilen „Grain“ auf der Device-Seite einer Audiospur (GA-10d2) — auf dem Gerät UNBESTÄTIGT (G10); eine Änderung klingt ab dem nächsten Start eines Teils | nicht im Store-Text behaupten, bis G10 bestätigt ist |
| Onset-Slicer (`SampleSlicer`, GMMW GA-6) | reiner Kern: schneidet ein Sample an seinen Treffern, mit der Onset-Regel der Tempo-Erkennung; kein Aufrufer | GA-7 (Founder-Gate): wo die Schnittpunkte liegen und was ein Schnitt spielt |
| Watch-App | Target existiert, wird nicht mit ausgeliefert | Transport Telefon→Uhr (`WCSession`, neues Framework) |
| Mehrspur-Aufnahme | Kette gebaut, flag-aus | ein Audio-EINGANG, den es nicht mehr gibt |
| EchoelAI-Bedienagent (`EchoelAI/EchoelCommand`, `EchoelCommandExecutor`) | Befehlsschicht + Ausführer gebaut und getestet (Auswahl lesen · Spurpegel · Teil kopieren · eigenes Undo), kein Aufrufer | ein Sprachmodell als Planer + eine Fläche ohne neuen Modal |

⚠️ **Zehn Feature-Flags haben null Leser** (`spatialEngine`, `bioSpace`, `echoelRender`, `motionEngine`,
`showControl`, `avObjects`, `performerTracking`, `liveCollab`, `headTracking`, `echoelAI`). Hinter
ihnen steckt nichts. Sie sind Platzhalter, keine versteckten Funktionen.
Messen: `git grep -n "FeatureFlags.<name>" -- Sources | grep -v ': *//'`.

---

## 3. HISTORISCH ENTFERNT — Implementierung zurückgenommen, Fähigkeit NICHT automatisch verboten

⭐ Seit 2026-09-24 gilt [`FOUNDER_PRODUCT_LAW.md`](FOUNDER_PRODUCT_LAW.md): **aktuelles Produktgesetz schlägt
historische Streichungen.** Die Zeilen unten sagen, welche IMPLEMENTIERUNG warum ging — nicht, dass die
Fähigkeit tabu ist. Ob und wie eine zurückkommt (wiederverwenden, Algorithmus portieren, neu bauen, nie wieder),
steht je Fähigkeit in [`HISTORY_ARCHIVE.md`](HISTORY_ARCHIVE.md).

Nichts davon ist verloren: jeder Stand liegt in der Git-Historie unter der genannten Nummer.
Zurückholen heißt aber meist **neu bauen**, nicht wieder anhängen.

| Was | Wann / Nummer | Founder-Grund |
|---|---|---|
| Drums / Beat-Maker / Sampler-**Kit** | 2026-07-26, #166/#167 | Fokus aufs Instrument — ⭐ 2026-10-10: ein **Sampler je Spur** ist zurück (GMMW GA-4: `LaneVoiceRack.samplers` + `loadSampleIfNeeded`, Tür `TrackSampleRow` im Spur-Detail); gestrichen bleiben Drum-Kit und Beat-Maker |
| Noten-**Fläche** Piano Roll | 2026-07-26, #178/#475 | „Pianoroll soll raus“ — ⭐ 2026-10-10: Noten werden wieder bearbeitet, im `PartNoteEditor` (Spur-Detail → Seite „Notes“, `TrackInspectorView`); Composer-Parts erst nach „Edit a copy“ |
| DAW-Arrangement (Clips, Arrange-Timeline, Mixer-Spuren) | 2026-07-24…31, #121 | Phase „reines Instrument“ (historisch, 2026-07-24) |
| AUv3-HOST (fremde Plugins laden) | #121 Slice 2 | wie oben (das Echoel-PLUGIN ist zurück, #1385) |
| Mikrofon / Audio-Eingang, Vocoder, Autotune | 2026-09-12, #1302 | „Face und Audio Input komplett entfernen“ |
| Harmonizer, Granularsynthese | 2026-09-12, #1305 | wörtlich gestrichen |
| Gesichts-/Körper-Tracking | 2026-09-12, #1301 | wie Audio-Eingang |
| Video-Aufnahme und -Schnitt | 2026-09-12, #1304 (Schnitt schon #121) | „Kein Video Capture“ |
| Vollbild-Visual, VJ-Overlay | #1069 | durch das schwebende Fenster ersetzt |

---

## 4. NIE GEBAUT — Roadmap, keine Lücke

**Was einer Profi-DAW heute wirklich fehlt** (UX-Audit 2026-10-02, `UX_AUDIT_2026-10-02.md`; Song-WAV-Export und
Zeit-Zoom aus dieser Liste sind seit Build 2613/2614 ausgeliefert, Fach 1): Beats aus Samples (⛔ „eine Tür zum Sampler … `SamplerVoice` hat keinen Lader“ stand hier — seit GA-4 hat jede Spur
einen Sampler mit Lader und Tür `TrackSampleRow`; korrigiert 2026-10-10) · Sends/Returns · Audio-Eingang mit Aufnahme, Sampling, Analyse
(#1302, Inbox E10) · AUv3-**Hosting** (Inbox E11 — das ausgelieferte AUv3-INSTRUMENT ist kein Hosting-Nachweis) ·
Video als musikalisches Material (Inbox E12) · ein hörbarer Raum im Kopfhörer (S3). Die Pläne dazu stehen in
`scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §7; geplant heißt nicht ausgeliefert.

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
