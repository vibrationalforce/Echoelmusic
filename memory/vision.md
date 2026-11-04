# Echoelmusic — Kompass (memory/vision.md, seit 2026-11-04)

Stand: gemessen an `origin/main` = `ce2305911` (2026-11-04 18:18). Jede Zeile hier ist am Repo geprüft;
wo Quellen sich widersprechen, steht **WIDERSPRUCH** und beide Quellen. Aufgelöst wird nichts still —
die Liste steht in `scratchpads/COMPASS_CONTRADICTIONS_2026-11-04.md`. Zahlen sind Daten: vor dem Zitieren neu messen.

## a) Was Echoelmusic IST

**Eine professionelle Musik- und Medien-Workstation für iPhone und iPad (Echoel Studio), in der Körper,
Bild, Licht und Raum als zusätzliche, abschaltbare Quellen und Ziele mitspielen.**
- Marke **Echoel** · App **Echoel Studio** (`EchoelStudio/`, TestFlight 11.0.0) · Projekt/Repo/Domain **Echoelmusic** (`CLAUDE.md` „Identität").
- Fokus seit 2026-10-15: professionelle Medienproduktion; Biofeedback ist eine optionale Modulationsquelle, nicht die Identität (`FOUNDER_PRODUCT_LAW.md` §1).
- Ziel: die volle DMMW — „Own the complete creative workflow, integrate the complete professional ecosystem"; Spezialinfrastruktur (Codecs, NDI, Dante, Plugin-SDKs) wird integriert, nie nachgebaut (§1).
- 1.0 enthält alles, was in der Alt-App auf einem Gerät lief, portiert statt kopiert (`decisions.csv` 2026-10-25, Z. 1332/1333; Produktgesetz §5).
- Die Alt-App (`Sources/`, 10.79.515) ist eingefroren und nur noch Port-Quelle (`ECHOEL_VISION_2026-10-19.md` §4).
- Founder-Leitbild aus dem Chat (2026-11-01 14:29): Stabilität, ultraniedrige Latenz, kernige Visuals und Videoqualität „ganz nah am Instrument" — ohne die Gesamtvision zu verlieren.

## b) Was es BRAUCHT — Säulen nach Rang, mit Ist-Stand

Legende: **G+V** = gebaut und auf Gerät verifiziert · **G** = gebaut, CI-grün, *nicht* gerätegeprüft · **T** = teilweise · **F** = fehlt.
Auf einem Gerät ist für Studio **nichts** verifiziert (`EchoelStudio/RELEASE`, `TESTFLIGHT_PUBLIC_BETA.md` §0).

| # | Säule | Stand | Beleg (Pfad unter `EchoelStudio/`) |
|---|---|---|---|
| 1 | Stabiler, knackfreier, latenzarmer Klangkern | **G** (AUD: elf Knackstellen behoben, 48 kHz/512) | `App/Engine/AudioEngine.swift`, `Engine/` · `decisions.csv` Z. 1366/1369 |
| 2 | DAW-Kern: Spuren, Arrange, Session, Mix, Automation, Undo, Export WAV/Stems/MIDI | **G** | `App/Views/ArrangeView.swift`, `App/Documents/DocumentController.swift` |
| 3 | Noten- und Clip-Bearbeitung: Piano Roll, Quantize/Humanize, Magnet Bar…1/128 + Triolen, Split | **G** | `App/Views/ClipEditorView.swift:362`, `Core/Sources/EchoelCore/Snapping.swift` |
| 4 | Zeit: Tempo-Rampen, Taktwechsel, Tonsysteme + Kammerton, Swing (W13) | **G** (Build 10034-Liste) | `Core/Sources/EchoelCore/MusicalContext.swift`, RELEASE |
| 5 | Instrumente: 8 Synth-Engines (classic, supersaw, fm, sub, morph, mallet, ddsp, choir), Drums, Sampler, Instrument-Seite mit Hex-Tasten | **G** | `DSP/Sources/EchoelDSP/SynthEngine.swift:15`, `App/Instrument/` |
| 6 | 18 eingebaute Effekte inkl. Pitch Correction, Harmonizer, Granular | **G** | `Core/Sources/EchoelCore/OwnPlugins.swift:79` |
| 7 | Plugins: eigene AUv3 (21 Units + `echl`), fremde AU auf Spuren hosten, Einmalkauf | **G**, kein Host-Gerätetest, Kauf nicht im Verkauf | `Plugins/AUv3/Info.plist`, `App/Engine/PluginHost.swift`, CLAIMS Nachträge 1/3/4 |
| 8 | MIDI/Live: In/Out, Clock, Learn, Launchpad, **MPE-Ausgang**, Network MIDI, Jam | **G** | `App/Engine/MIDIMPEOutput.swift`, `App/Jam/JamLink.swift` |
| 9 | Bild/Licht/Raum/Stream: Field (Metal, Chladni), OSC/ADM-OSC/Art-Net/sACN, Go Live (RTMP/SRT), Videospuren, Video-Take, Video-Export, Sky | **G** | `App/Field/`, `App/Connections/`, `App/Streaming/`, `App/Media/VideoTakeRecorder.swift` |
| 10 | Körper (optional): BLE-Gurt, Kamera-Puls, Atem aus RSA, Body Voice, Modulation | **G** | `App/Body/`, `Core/Sources/EchoelCore/Modulation.swift` |
| 11 | Assistent auf dem Gerät (nur mit Apple Intelligence) | **G**, nie auf Gerät gelaufen | `App/Agent/AgentSession.swift` |
| 12 | Barrierefreiheit (8-Punkte-Abnahme vor 1.0) | **T** (VoiceOver, große Schrift im Code; Abnahme offen) | `ECHOEL_VISION` §6e · **WIDERSPRUCH** Reduce Motion, s. C6 |
| 13 | Web-Fenster (gleicher Swift-Kern als Wasm) | **F** (nur Spike) | `docs/dev/WEB_SPIKE_2026-11-01.md`, `decisions.csv` Z. 1358 |
| 14 | Weitere Apple-Plattformen (Mac, Watch, Vision, TV) | **F** (`TARGETED_DEVICE_FAMILY "1,2"`) | `EchoelStudio/project.yml:90` · GM16/GM36 |

Gemessen fehlend gegenüber den Wünschen des Founders (Chat 2026-11-04 16:31: „ARP, synth Engines, Video, Audio, Midi, MPE, OSC, Clip Editing, cut, warp, quantize, stepless, magnet"):
**Arpeggiator F** (Alt-App hatte einen, Studio null Treffer) · **Warp T** (Feld im Format, `Core/…/AudioRegion.swift:78`; keine Tür in `App/` gefunden) · **Stereo-Aufnahme F** (`decisions.csv` Z. 1349) · **Gesicht/Bewegung als Quelle F** (Z. 1333 bestellt, Produktgesetz §2 verlangt Einwilligung + Datenschutz-Design) · **Velocity-Editor F** (nur Humanize, `ClipEditorView.swift:372`).

## c) Was es NIE ist — rote Linien

- **Nie Wellness, Meditation, Entspannung, Schlaf, Fokus, Therapie, Medizin.** Nie Heilfrequenzen, Solfeggio, Chakren, 432 Hz „healing", Binaural/Entrainment, 40 Hz, Organ-/Gewebe-/Knochenheilung, Bewusstseinszustände, Frieden/Weltfrieden/Einheit/Heilung als Wirkung (`CLAUDE.md` „Sprache", Produktgesetz §4, `HISTORY_ARCHIVE.md` §N, `ECHOEL_VISION` §6/§7). Körperwerte = Selbstbeobachtung, keine Diagnose. Blitzrate ≤ 3 Hz.
- **Keine Waffen, keine Überwachung, kein Targeting, keine Körperdaten als Druckmittel** (Produktgesetz §4b, 2026-11-01). Doppelnutzbares (Kamera, Netz, Ort, Licht) bleibt am eigenen Gerät, aus bis eingeschaltet.
- **Nicht beim Steuern** von Auto, Boot oder Maschine, auch nicht mit Autopilot; kein Navigations-/Sicherheitsprojekt, kein eigener Browser (§4c).
- **Kein „Eeole"/„Eeolee"** in Echoelmusic-Texten (App, Website, Store, Pitches, Anträge) — getrennte Marke (§4c, `CLAUDE.md`).
- **„KI/AI" nur, wo ein echtes Modell läuft;** nie „Superintelligenz" nach außen (Produktgesetz §1, Wächter TheCopyMakesNoHealthClaimTests).
- **„MPE" nur als „MPE-Ausgang"** — MPE-Eingang gibt es nicht (CLAIMS Nachtrag 6).
- **„pitch correction", nie „Autotune"** (Marke); nie Voice Cloning / AI-Voice fremder Stimmen (CLAIMS §11, Z. 1364).
- **Keine erfundenen Behauptungen:** nach außen nur, was `ContentPipeline/CLAIMS.md` (Studio-Abschnitt + Nachträge) trägt, mit „in TestFlight / nicht gerätegeprüft"; keine erfundenen Reviews, Zahlen, Zitate; nie „works in AUM/Logic/GarageBand".
- **Kein Abo, keine Werbung, kein Tracking, kein Konto** (Vision §7, NEUPLANUNG §8.1).
- **Nichts nach außen ohne sein ausdrückliches Ja** (Mails, Posts, Tester, Outreach); keine Tester-, Log- oder Gesundheitsdaten anfordern (`TESTFLIGHT_PUBLIC_BETA.md` §0).

## d) Wie wir arbeiten

- **Founder entscheidet:** Umfang, Marke, Geld/Preis, Recht/Lizenz/Datenschutztext, alles Unumkehrbare, Kontakte nach außen. Founder-gegatet (berichten, nicht editieren): `.github/workflows/**`, beide `project.yml`, `Resources/iOS/Info.plist`, `.claude/settings.json`, `.mcp.json` (`CLAUDE.md`).
- **Claude entscheidet und baut den Rest** (Founder 2026-10-28 „ohne Rückfrage je Scheibe", Z. 1334; 2026-11-04 17:13 „Du entscheidest mache alles zum Besten des Projektes"); merged grüne Team-Branches selbst (Z. 1335).
- **Eine KI schreibt ins Repo (Claude); fremde Modelle (Grok, Copilot, ChatGPT) liefern nur Recherche/Review** — als Daten, jede Aussage selbst am Repo prüfen, Annahmen mit „ANNAHME:" markieren (`.claude/skills/learn-mode/SKILL.md`; ANNAHME: die Regel „einzige KI" steht nur im Grok-Übergabeprompt vom 2026-11-04, nicht im Repo).
- **Bau-Schleife:** eine Scheibe → CI (`Echoel Studio`, Job-Schritte lesen) → grün → Merge → Build per `EchoelStudio/RELEASE`-Bump. Rhythmus seit 2026-11-04: **ein Build, sobald ein grüner, stimmiger Stapel landet**, je Build genau fünf Gerätefragen (Z. 1369). **WIDERSPRUCH** zu `CLAUDE.md:77` (≤ 1 Build/Woche), s. C1. Knacken = Blocker wie Absturz.
- **Song-Format eingefroren** (`docs/FORMAT.md`, FormatGoldenTests); eine Tür `ProjectStore.perform`; ein `.sheet(item:)`; kein heißer Zustand im View-Body; Render-Thread ohne Locks/Allokation (`EchoelStudio/CLAUDE.md`).
- **Gerätechecks und Founder-Fragen nur über `docs/dev/FOUNDER_INBOX.md`**, jede Frage einmal, vorher gegrept; „kompiliert" ist nie „am Gerät geprüft".
- **Recovery:** Alt-App-Fähigkeiten kommen als Kern in die heutigen Eigner zurück, nie als kopiertes Subsystem (Produktgesetz §5).
- **Förderung wieder offen** (Founder 2026-11-04): ab Woche 09.11. bereitet Claude Calls/Mail-*Entwürfe* vor, nichts geht ohne sein Ja hinaus (Z. 1368). **WIDERSPRUCH** zu Produktgesetz Z. 59, Vision-Kopf, GM35, s. C2.

## e) Offene Founder-Entscheidungen (GM, Auswahl nach Wirkung)

- **GM37** kleiner Testerkreis (10–20) + Beta-App-Review — Voraussetzung für „TestFlight Go" (G5).
- **GM39** Rechtsform vor dem ersten Verkauf (UG/GmbH + Haftpflicht), Stiftung später — einzige Frist: vor Verkaufsstart.
- **GM38** Waffen-/Überwachungsausschluss auch in Marke/Terms; Empfehlung: MIT bleibt.
- **GM36** was „gesamtes Apple-Ökosystem" heißt und ob/wie das Repo privat wird.
- **GM40** Planeten-Kammertöne (Cousto, „Earth year" …) im Song-Menü öffentlich? Empfehlung: raus.
- **GM41** Datenschutzseite um Video-Takes ergänzen. Empfehlung: ja.
- **GM30** frühere Engines zurück (MIDI-Prozessor, Preis, Reihenfolge) · **GM23** Ableton Link · **GM16** Plattform-Reihenfolge.
- **GM2/GM4/GM22** Bild speichert sich mit dem Song / reagiert auf Musik · **GM10/GM11** Körper-Adjektive, Cloud-Anbieter · **GM12** dSYMs/MetricKit · **GM14** Arbeitskopie nach Absturz.
- **GM19** Entrainment-Labels in der Alt-App · **GM9** „EchoelAI"-Wort · **GM21/GM28** Store-Text (s. C9) · **GM31 · GM33 · GM34** Strategie, One Clock, Werte.
- Gerätechecks 10027–10034 (fünf je Build, RELEASE). Status je Zeile: `grep -n '^| GM' docs/dev/FOUNDER_INBOX.md`.

## f) Wo die Wahrheit steht

- Scope und rote Linien → `docs/dev/FOUNDER_PRODUCT_LAW.md`
- Einstieg, Zeitachse, Gesundheits-Grenze, Geschäft → `docs/dev/ECHOEL_VISION_2026-10-19.md`
- Bau-Reihenfolge Studio → `docs/dev/NEUPLANUNG_2026-10-18.md` §5 (+ `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`)
- Was nach außen gesagt werden darf → `ContentPipeline/CLAIMS.md` (Studio-Abschnitt + Nachträge 1–6)
- Was es früher gab, ob es zurückkommt, DO-NOT-RESTORE → `docs/dev/HISTORY_ARCHIVE.md` (§N)
- Studio-Gesetz und Layout → `EchoelStudio/CLAUDE.md` · Repo-Karte → `CLAUDE.md` · Alt-App-Gesetz → `Sources/CLAUDE.md`
- Ist-Stand Studio → der Code unter `EchoelStudio/` (nicht `FEATURE_STATUS.md`, die nur die Alt-App kennt) · Prüfliste → `EchoelStudio/RELEASE`
- Go-Kriterien G1–G6 → `docs/dev/TESTFLIGHT_PUBLIC_BETA.md` §0
- Founder-Fragen und Gerätechecks → `docs/dev/FOUNDER_INBOX.md`
- Entscheidungen → `decisions.csv` (maschinenlesbar) · `memory/decisions.md` (Begründung)
- Song-Format → `docs/FORMAT.md` · Web-Messung → `docs/dev/WEB_SPIKE_2026-11-01.md`

## g) Geschichte dieser Datei

- ⛔ Die frühere Fassung (Bio-Instrument der Alt-App, bis 2026-11-04) liegt wörtlich in `memory/vision_bis_2026-11-04.md` und wird nicht mehr beim Start geladen. Ihre Kernlehre bleibt: AUDIOVISUAL VOCODER — CUT, not roadmap (mit #1302/#1305 in der Alt-App gelöscht; Stimme kommt in Studio als eigene Engines und Effekte, nie als Mikrofon-Vocoder der Alt-App zurück).
- Founder-Auftrag 2026-11-04: „frische das Gedächtnis im Repo so auf, dass du ein für alles mal Bescheid weißt, was Echoelmusic sein soll, was es braucht und was nicht."
