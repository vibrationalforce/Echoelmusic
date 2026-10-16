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
| **Ausgeliefert (TestFlight)** | **v10.79.499 · Build 2624** · Commit `f2602f9d6` · 2026-10-13 11:39 UTC | TestFlight-Lauf #2624 (`testflight.yml`, `BUILD_NUMBER` = `github.run_number`), Lauf 38390494015, Schritt „Verify build landed in App Store Connect“ `success`; ob der Build in App Store Connect verarbeitet wurde, sieht nur der Founder |
| **Auf dem Branch, noch in keinem Build** | kein App-Code — alles bis `1e7c64aec` steckt in Build 2624; danach nur Doku | `git log --oneline f2602f9d6..HEAD -- Sources` |
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
| Fünf Bereiche als eine Oberfläche | Umschalter unten **Arrange · Mixer · Instrument · Browse · Piece** (fünftes Wort „Piece“ seit H18, 2026-10-07; davor „Project“); quer eine Leiste links | 2614 (2617: Piece) | offen |
| Siri / Kurzbefehle: „Start Echoelmusic“ · „Stop Echoelmusic“ · „Keep Last Loop“ (ohne Bericht, über `EchoelIntentInbox`) | Kurzbefehle-App oder Siri | ≤ 2616 | offen |
| Siri / Kurzbefehle mit Bericht und eigenem Undo: „Change Track Level“ · „Copy Selected Part“ · „Undo Echoel's Last Change“ | Kurzbefehle-App oder Siri; Bericht + „Undo Echoel's last change“ im `AgentReportBanner` | 2621 | offen |
| Siri: „Edit a Copy of the Part“ (Teil behalten) · Siri spricht das Ergebnis | Kurzbefehle-App oder Siri | 2622 | offen |
| Projekt-Menü | E-Logo oben links → **Open · Save │ Live Colabo · Learn │ Guide** | 2614 | offen |
| „Describe this piece“ — die Antwort steht in der Bericht-Zeile | E-Logo → „Describe this piece“ | 2622 | offen |
| Lernkarte „From pulse to piece“ | E-Logo → **Learn** → „Start Here“ | 2622 | offen |
| Live Colabo zeigt die Netz-Rundlaufzeit („Link: … — network round trip, not heard latency“) | E-Logo → **Live Colabo** → verbundener Peer | 2618 | offen |
| EIN Transport | Kopf: **Play / Stop / Record**; im Instrument hält „Pause“ auf der Platte, „Play“ setzt fort | 2614 | offen |
| Song-Einstellungen | **Piece** → Tonart, Stimmung, Tempo-Modus | 2614 | offen |
| Undo/Redo der Stück-Bearbeitung | Kopf (`SongHistoryRow`) · mit Tastatur ⌘Z / ⇧⌘Z | 2613 | offen |
| Startet auf dem Stück, Visual als Karte | frische Installation → Arrange | 2609 | offen |

### 1b. Auf dem Branch, aber in KEINEM ausgelieferten Build (kommt mit dem nächsten Bump)

Stand 2026-10-16, Zweig `claude/echoelmusic-review-optimize-u5jjpd` ab `81ebe64`/`39f954d`; Gates zum
Zeitpunkt des Eintrags offen, kein TestFlight-Build. Gerät für alle: offen. Präfix je ID, weil zwei
Pläne dieselben Buchstaben nutzen (`scratchpads/GSIDMMW_AUDIT_2026-10-16.md` §ID-Namensraum).

| Was | Wo | Commit |
|---|---|---|
| „Describe this piece“ gehört bis zum Ende zum richtigen Stück; „Stop“; 45-s-Deadline (GSIDMMW-B) | Bericht-Zeile | `35d95ee` · `8a17474` |
| „Ask Echoel“: eine Bitte in eigenen Worten → Echoel schlägt vor (Spur + Betrag), „Apply“ / „Discard“, Undo; geänderte Auswahl wird abgewiesen; Rückfrage statt Raten (GSIDMMW-C1/C2a/C2b). Drei Befehle: beschreiben, Spur lauter/leiser, Teil kopieren | Siri/Kurzbefehle „Ask Echoelmusic“ → Bericht-Zeile; braucht Apple Intelligence | `183650e` · `8e0299e` · `39f954d` |
| „Ask Echoel“ auch IN der App: eine Eingabezeile im Bericht, gleicher Weg wie Siri (GSIDMMW-C2c) | ≡-Menü → „Ask Echoel“ | `b53f423` |
| Echoel kann eine Spur nach links/rechts setzen (−1 … 1) und stumm/laut schalten — beides mit Rücklesen und eigenem Undo; ein Wert, den du danach selbst setzt, bleibt (GSIDMMW-D1/D2). Jetzt fünf Befehle | Vorschlag → „Apply“ | `c87ee46` · `ee43f47` |
| „Share as MIDI“ für das gewählte MIDI-Teil (Ultraplan-C2) | Part-Leiste | `fc5d1da` |
| Gekürztes MIDI-Teil sagt, wie viele Noten es verbirgt (Ultraplan-A1) | unter dem Length-Feld | `cd93c14` |
| Neue MIDI-Spur jenseits der Rack-Stimmen sagt beim Anlegen, dass sie stumm ist (Ultraplan-D1) | „Add MIDI Track“ | `81ebe64` |

⛔ Davor stand hier „Leer.“ und eine Rücknahme-Kette; sie gilt für Build 2623/2624 und bleibt wahr:
GMMW R2, VV-4e, der Wellenform-Fix, F1–F6b und A3a sind ausgeliefert.

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
| Export MIDI · Export WAV (ganzes Stück, Echtzeit, ab Takt 1) | Bühne **Piece** → Kacheln „Export“ (MIDI) · „WAV“ → „Share WAV“ (⛔ „Arrange-Reiter“ stand hier; die Kacheln sitzen auf der Piece-Platte) | 2613 (WAV) | offen |
| Foto und Video als Bild-Saat fürs Visual (kein Videoschnitt) | `PhotoSeedCard` · `VideoSeedCard` | ≤ 2612 | offen |
| Sampler je Spur: ein Sample laden, die Teile der Spur spielen es | Spur antippen → Detail **Device** → Instrument „EchoelSampler“ → „Sample“ | 2617 (Tür) · 2621 (eigener Sampler je Spur) | offen |
| Audio-Teil bearbeiten: Wellenform im Teil, „Part level“, „Normalize“, „Fade in“/„Fade out“, „Part pitch“, „Stretch“ (Clean · Tape · Beats, nur gewarpte Teile) | Audio-Teil antippen → Leiste unter dem Canvas | 2621 | offen |
| Audio-Teil-Editor: Kanten ziehen, „Slip“, Pegel-Streifen mit Fade-Ecken | Spur antippen → Detail **Part** | 2621 | offen |
| Teil teilen „At playhead“ · „Join next“ · „Focus“ / „Show all“ | Teil antippen → Leiste | 2621 · 2618 (Join next) · 2621 | offen |
| Lineal: „Play from“ setzen (gestoppt) / springen (läuft), Scrub hört gestoppt mit | Lineal über den Spuren antippen oder ziehen | 2621 | offen |
| Song-Zyklus | Transport-Leiste → „Cycle“ neben Click | 2621 | offen |
| „Compose here“ auf einer Rack-MIDI-Spur, mit „Style“ und „New variation“ | Spur antippen → Detail **Device** | 2621 | offen |
| „Edit a copy“ macht einen Composer-Teil editierbar | Composer-Teil antippen → Leiste | 2621 | offen |
| Record ins LEERE Stück — der erste Take wird der erste Teil | Spur „Arm for recording“ → **Record** | 2623 | offen |
| Notenraster in Tonhöhenfarbe (dieselbe Regel wie Pads und Bild; Lautstärke = Tiefe der Farbe) | Detail **Notes** | {B} | offen |
| Kopfhörer-Raum für Audiospuren (Apple HRTF, nicht die 7 Raum-Kerne) | **Mixer** → „Headphone space“ (Default aus) | 2617 | offen |
| Den Ton eines Videos als Audiospur nehmen | **Browse** → „Visuals“ → „Video to Visuals“ → „Use Its Sound“ | 2617 | offen |
| Echoel Grain als Spur-Insert auf Audiospuren (Position · Länge · Dichte · Streuung · Tonhöhe · Breite; eine Änderung klingt ab dem nächsten Teil-Start) | Spur antippen → Detail **Device** → Zeilen „Grain“ (`TrackGrainRows`) | 2622 | offen (G10) |

### 1d. Mixer · Browse · Instrument

| Fähigkeit | Nutzerweg | Build | Gerät |
|---|---|---|---|
| Spur-Streifen + Master-Kasten (Lautstärke, Pegel, LUFS/True-Peak, Clear) | **Mixer** | 2614 | offen |
| Klänge für die gewählte MIDI-Spur, Medienbibliothek | **Browse** → ein Regal auf einmal: „Sounds“ · „Media“ (die Bibliothek) · „Visuals“ | 2614 (2621: Regale) | offen |
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

⛔ Echoel Grain und der Siri-Bedienagent standen hier bis 2026-10-13 und haben eine Tür — Grain seit GA-10d2 (Build 2622), Siri seit AI-1/AI-2 (Build 2621, nicht 2622 wie hier stand); sie stehen jetzt in 1c und 1a. ⛔ Ebenso standen hier „Tonhöhe je einzelnem TEIL“ und „Stretch-Modi außer clean“ als reglerlos: beide haben seit Build 2621 einen Regler („Part pitch“, „Stretch“) und stehen in 1c.

| Fähigkeit | Stand | Was fehlt |
|---|---|---|
| Fluid-Oberfläche (`FluidSurfaceMath`, F1) | reiner Kern mit begrenzter Energie, kein Aufrufer, kein Shader | F2–F3: Shader und Tür (`scratchpads/PLAN_FLUID_SURFACE_2026-10-13.md`) |
| Erkannte Tonart übernehmen | wird nur angezeigt, nie übernommen (Absicht) | Founder-Entscheidung + ein Knopf |
| „Follow pulse“-Tempo (`BioTempoDirector`) | fertig, aber ein Zwilling des lebenden Servos | Entscheidung, welcher gilt |
| Raum-Render (7 eigene Kerne: VBAP, Ambisonics, `BinauralPanner`, Raumhall …) | Steuer-Hälfte (ADM-OSC aus und ein) läuft. Im Kopfhörer: seit Restructure S3c sitzen AUDIO-Spuren an ihrer Szenen-Position — über Apples HRTF (`AVAudioEnvironmentNode`, `AudioEngine.attachSpaceBus`), NICHT über die 7 Kerne; Schalter „Headphone space“ im Mixer, Default aus, Gerät offen (G6). Die generierten Stimmen bleiben stereo. ⛔ Bis 2026-10-11 stand hier „im Kopfhörer ist nichts räumlich“ — seit S3c falsch (`docs/research/SPATIAL_MIX_RESEARCH.md` §7). Unter den 7 Kernen hängen zwei Dateien, die NUR sie benutzen (aufgeschrieben 2026-10-13): `EchoelRenderLayout` — die Lautsprecher-Geometrie, von ihren 15 Typen nennt nur `VBAPPanner` einen — und `AutomationGestureRecorder`, den nur `SpatialAutomationMapping` nennt; Wächter `TheSpatialRenderHalfIsNotClaimedLiveTests` Anspruch 5 | für die 7 Kerne: je ein Aufrufer (die zwei Dateien darunter kommen mit); für den Kopfhörer: G6 am Gerät |
| Stream-Key in der Keychain (Broadcast S1) | gebaut, Build 2615 | eine Fläche — und die hängt an S2 (gesperrt, siehe 2a) |
| `CloudSync`, `BioSpaceMap`, `VisualModulation`, `AudioFeatureExtractor` | reine Kerne, kein Aufrufer | je ein Aufrufer |
| Onset-Slicer (`SampleSlicer`, GMMW GA-6) | reiner Kern: schneidet ein Sample an seinen Treffern, mit der Onset-Regel der Tempo-Erkennung; kein Aufrufer | GA-7 (Founder-Gate): wo die Schnittpunkte liegen und was ein Schnitt spielt |
| Watch-App | Target existiert, wird nicht mit ausgeliefert | Transport Telefon→Uhr (`WCSession`, neues Framework) |
| Mehrspur-Aufnahme | Kette gebaut, flag-aus | ein Audio-EINGANG, den es nicht mehr gibt |
| `ParameterToolCore` (EchoelAI) | reiner Kern, kein Aufrufer — der Bedienagent selbst (`EchoelCommandExecutor`) hat seit AI-1/AI-2 seine Tür über Siri und steht in 1a; ein Sprachmodell als Planer (drei Befehle, nur Vorschlag) steht seit GSIDMMW-C2b in 1b | GSIDMMW-D: Pan und Mute mit Rücklesen + Undo GEBAUT (D1/D2); Synth-Parameter warten auf einen Besitzer mit Rücklesen (der Router schreibt nur die Live-Stimme); Körper-Adjektive für den Planer bleiben Founder-Gate GM10 |

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
| AUv3-HOST (fremde Plugins laden) | #121 Slice 2 | wie oben (das Echoel-PLUGIN ist zurück, #1385) — ⭐ 2026-10-14: **wieder GEBAUT** für Instrument-Plugins (`Audio/HostedInstrumentHost`, Tür `TrackPluginRow`), Gerät offen, nicht behauptet (CLAIMS §1b) |
| Mikrofon / Audio-Eingang, Vocoder, Autotune | 2026-09-12, #1302 | „Face und Audio Input komplett entfernen“ |
| Harmonizer, Granularsynthese | 2026-09-12, #1305 | wörtlich gestrichen — ⭐ die Granular-Hälfte ist zurück (Echoel Grain, GA-9/GA-10, Fach 1); der Harmonizer bleibt gestrichen |
| Gesichts-/Körper-Tracking | 2026-09-12, #1301 | wie Audio-Eingang |
| Video-Aufnahme und -Schnitt | 2026-09-12, #1304 (Schnitt schon #121) | „Kein Video Capture“ |
| Vollbild-Visual, VJ-Overlay | #1069 | durch das schwebende Fenster ersetzt |

---

## 4. NIE GEBAUT — Roadmap, keine Lücke

**Was einer Profi-DAW heute wirklich fehlt** (UX-Audit 2026-10-02, `UX_AUDIT_2026-10-02.md`; Song-WAV-Export und
Zeit-Zoom aus dieser Liste sind seit Build 2613/2614 ausgeliefert, Fach 1): Beats aus Samples (⛔ „eine Tür zum Sampler … `SamplerVoice` hat keinen Lader“ stand hier — seit GA-4 hat jede Spur
einen Sampler mit Lader und Tür `TrackSampleRow`; korrigiert 2026-10-10) · Sends/Returns · Audio-Eingang mit Aufnahme, Sampling, Analyse
(#1302, Inbox E10) · AUv3-**Hosting** (Inbox E11 — ⭐ für Instrument-Plugins seit H2–H4 gebaut, Gerät offen; Effekt-Plugins nicht; das ausgelieferte AUv3-INSTRUMENT ist kein Hosting-Nachweis) ·
Video als musikalisches Material (Inbox E12; ⭐ der erste Schritt E12-1 „Use Its Sound“ ist seit Build 2617 ausgeliefert, Fach 1c) · ein hörbarer Raum im Kopfhörer (S3; ⭐ für Audiospuren seit Build 2617 über „Headphone space“, Fach 1c — die generierten Stimmen bleiben stereo). Die Pläne dazu stehen in
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
