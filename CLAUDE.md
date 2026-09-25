# CLAUDE.md — Echoel v10 (Bio · Audio · Video · Light · Space)

## IDENTITY

Repository: https://github.com/vibrationalforce/Echoelmusic
Developer: Echoel (Michael Terbuyken) @ Studio Hamburg
App Apple ID: 6757957358 · SKU: Simsalabimbam · Team ID: via `APPLE_TEAM_ID` secret
Bundle prefix: `com.echoelmusic` · App Group: `group.com.echoelmusic`
Bundles: `.app` (main, universal) · `.app.watchkitapp` · `.app.widgets` · `.app.clip` (deferred) · `.app.notification-service` (deferred)

**Canonical identity map:** `docs/dev/APP_STORE_CONNECT.md` · **Cross-platform plan:** `scratchpads/PLAN_MULTIPLATFORM_LINKING.md`

**Echoel — Physical Computing · Biofeedback · Multimedial & Multidimensional.**
An immersive, iPhone-first instrument and production platform where the body — heart, breath — drives sound, image, light and immersive space in real time.

⛔ **Drei Wörter sind am 2026-07-31 gestrichen worden, weil sie keinen Produzenten haben** — aus dieser Zeile, aus „Built for" darunter und aus den beiden BRAND-Zeilen: **„motion"** (`ModulationMatrix.hasProducer` gibt für `.motion` hart `false` zurück; ALLE SECHS `BioSampleFrame`-Konstruktionsstellen in `Sources/` schreiben `motionEnergy: 0`, der letzte CoreMotion-Provider ging im 2026-06-19-Cleanup — `import CoreMotion` kommt nirgends mehr vor) · **„brain rhythm"** (`.eegBurst` hat in `Sources/` VIER Vorkommen — Enum-Case, ein Doc-Kommentar, eine OSC-Adresszuordnung, ein Consumer-`switch` — und **NULL Produzenten**; nichts konstruiert je ein solches Ereignis) · **„broadcast"** (`Package.swift` hat ein leeres `dependencies`-Array, HaishinKit nicht verlinkt; RTMP kann als Codepfad nicht existieren).

⛔ **Und die ERSTE Fassung dieser Streichung ließ die Zeile stehen, die eine Session zuallererst liest: die H1.** Sie behauptete „Bio · Audio · Video · Light · **Broadcast**" als Produktsäule, während der Absatz direkt darunter erklärte, warum Broadcast nicht existiert — die einzige überlebende Falschstelle saß in der Überschrift, und der Absatz nannte sich dabei selbst „die erste Zeile, die eine Session liest". Die H1 sagt jetzt **Space** (ADM-OSC ist real und verdrahtet). Lehre für die nächste Wahrheits-Runde: **die Überschrift ist Teil der Behauptung**; ein `git grep` nach dem gestrichenen Wort über die GANZE Datei gehört zum Streichen dazu, nicht nur das Bearbeiten der Absätze, an die man gerade denkt.

Built for: **Installation · Event · Content · Cinema · Theater · Performance.** (⛔ „Live Broadcast" gestrichen, gleicher Grund.)

Capabilities (all routed through one typed bus): **bio-reactive synthesis** · **generative composition** (key/scale/genre, in-key melody + harmony from the body) · **OSC / MIDI I/O** · **generative visuals + lighting** (Art-Net · sACN · ADM-OSC).

⛔ **Was hier stand und gestrichen wurde, weil es nichts davon (mehr) gibt** — je Eintrag Datum, Grund und was BLEIBT:
· **„Beat Maker (16-step × 8-track sequencer + sampler)"** — Drums, Pad-Stimmen, Sample-Import und die Sample-Bibliothek sind mit #166/#167 gelöscht; der Step-Grid überlebt nur als Takt-Clock.
· **„Multi-track Recorder (mic over beats)"** — **GELÖSCHT mit #1302** (Founder 2026-09-12, kein Mikrofon mehr): `MultiTrackRecorder` ist als DATEI weg; `git grep -n MultiTrackRecorder -- Sources` liefert nur noch Kommentare. `FeatureFlags.audioLaneRecording` existiert weiter und hat seit #1302 KEINEN Zweig (`EveryFlagSaysWhatItGatesTests`). ⛔ Bis #1326 stand hier eine KORREKTUR, die den Typ für lebend erklärte und dabei zwei Zeilennummern zitierte, die längst auf fremden Code zeigten — in der Zeile, die eine Sitzung ZUERST liest. **Lehre: eine KORREKTUR veraltet genauso wie das, was sie korrigierte** — und eine Zeilennummer einer lebenden Datei ist ein Datum, kein Sachverhalt (§E).
· **„Video Capture & Trim"** — **GANZ GESTRICHEN, #1304** (Founder 2026-09-12, wörtlich „Kein Video Capture"). Der SCHNITT war schon mit #121 Slice 3 weg; jetzt ist auch die AUFNAHME weg — Recorder, Muxer, Bibliothek, REC-Taste, Menüfall, Kopf-Kachel, acht Wächter und jede nutzersichtbare Zeile. ⚠️ **`Video/CameraCapture`, `CameraAnalyzer`, `RPPGConditioning` und `PulsePeriodEstimator` BLEIBEN** — das ist der rPPG-PULSPFAD, die Flaggschiff-Bio-Quelle; sie teilen nur das Verzeichnis. **Wer hier nach Verzeichnis aufräumt, löscht den Puls.**
· **„RTMP Live Stream"** — nie verlinkt (`BroadcastPublisher` ist ein Compile-Guard-Gerüst).
· **„Harmonizer", „Granularsynthese", „Autotune"** — GESTRICHEN 2026-09-12 (#1305, Founder wörtlich „Kein audioninout kein Autotune, Harmonizer, granularsynthese"). Autotune war schon mit #1302 weg (`VoicePitchCorrector` ging mit dem Audio-Eingang). ⚠️ **Die DATEI `Sequencer/MicrotonalTuning.swift` BLEIBT, und der TYP darin heißt `TuningSystem`** — die #1376-Falle, deshalb hier beide Namen: wer nach einem Typ `MicrotonalTuning` greppt, findet nichts und könnte das lebende Tonsystem für tot halten. Es ist das Tonsystem JEDER gestimmten Stimme, und das ist gemessen, nicht behauptet: `setTuningCents(` hat SIEBEN Aufrufstellen und erreicht `synth` · `touchSynth` · `leadSynth` · `bassSynth` · `subBass` · `bioVoice` · `laneVoiceRack` (das an voices/subs/bios weiterfächert). Es war nur zusätzlich das Autotune-Ziel.
· **„MPE"** bleibt aus dem I/O-Satz gestrichen, aber mit einer ANDEREN Begründung als früher: **MPE OUT ist real und schaltbar, MPE IN nicht** (#548/#713 — Details eine Ebene tiefer bei „Live pipeline"). Ein „MPE"-Satz im I/O-Set behauptete also die Hälfte, die fehlt.
⛔ **Die Streich-Provenienz — die vollständigen Datei-Listen je Entfernung, die Founder-Zitate in ganzer Länge und die zwei Zeilennummern des #1326-Fehlers — liegt in `memory/LEDGER_COUNTS.md` §AI.** Diese Zeile ist die Identitäts-Zeile der Datei: sie muss der Wahrheit folgen, sonst plant die nächste Session aus ihr heraus Features, deren Fundament abgerissen ist.

---

## CURRENT STATE

- **⭐ PRODUCT LAW (canonical since 2026-09-24 — read `docs/dev/FOUNDER_PRODUCT_LAW.md` before ANY scope decision; build ORDER = `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`, WA3 next).** Echoelmusic is a full professional **DMMW** (distributed multidimensional multimedia workstation) — audio, MIDI/MPE, instruments, FX, recording, arrangement, mixing, mastering, automation, video, visual, light, spatial/XR, streaming, collaboration, AI. *Own the complete creative workflow, integrate the complete professional ecosystem* — never rebuild specialist infrastructure (codecs, Dante, NDI, CDNs, plugin SDKs).
  **CURRENT PRODUCT LAW SUPERSEDES HISTORICAL PRODUCT CUTS — a historical deletion revokes an IMPLEMENTATION, not the capability.** Every ⛔ „gestrichen / CUT / reines Instrument" in this file and in `decisions.csv` is PHASE HISTORY: its ENGINEERING warning stays law (#1302 input graph, #299 refcount, black-screen chain, hot-state), its SCOPE verdict does not. Recovery ports the proven core into today's owners — never copy a subsystem back; what existed, whether it worked and its recovery class: `docs/dev/HISTORY_ARCHIVE.md`. ⚠️ **Scope is not a claim:** store, website and content still claim only what ships (`docs/dev/FEATURE_STATUS.md`, `ContentPipeline/CLAIMS.md`).
  ⛔ **The pure-instrument phase (2026-07-25 → 09-24) is HISTORY.** Its one sentence („a bio-reactive instrument"), „DMMW is RETIRED" and the keep/cut boundary **Editor ≠ Workstation** stood here as law; moved verbatim to `memory/LEDGER_COUNTS.md` §AL, and `docs/dev/PRODUCT_DEFINITION.md` carries the same banner. TECHNICAL facts that survive it: `PianoRollView` (the editor) is deleted, `PianoRollModel` (note engine + `MusicalFrame` publisher) is load-bearing; the Workstation plays `TimelineStore` — read `Tests/CISmoke/TheWorkstationPlaysTheTimelineTests.swift` before touching it.
  **SHIP GATE "Instrument-Complete v1"** (seit 2026-09-24 ein RELEASE-Meilenstein, nicht die Produktgrenze — `FOUNDER_PRODUCT_LAW.md` §6) — replaces the dead *"bis die gesamte DMMW auf Profi-Level ist"* (unreachable once the workstation half was dismantled). Five binary checks, all true → v1 is instrument-complete and the App-Store step is the founder's (⛔ "lift the TestFlight freeze" stood here — that freeze was lifted 2026-07-17/07-31 and builds ship every green round; audit 2026-09-02): **1. Klang** (curated genres professional, identity survives, no convergence bug) · **2. Kontrolle** (patch editor reachable — `soundPanel` behind the Sound chip; **the piano-roll half of this check is RETIRED by founder decision 2026-07-26, "Pianoroll soll raus"** — the note editor is gone on purpose, so do not read this gate as blocked by its absence) · **3. Modi** (Flow + Loop) · **4. Ausgabe** (visual live + contemplative on device; light/space demonstrable, not required) · **5. Stabilität** (clean launch, no black screen, no menu freeze).
  ⭐ **WER JEDEN CHECK ENTSCHEIDET — nachgetragen 2026-08-22 (#750), weil „fünf binäre Checks" nicht sagt, welche eine Sitzung selbst schließen kann und welche dem Founder gehören. Ohne das liest sich der Rückstand größer als er ist, und die Freeze-Frage wird nie gestellt.** Gemessen, nicht geschätzt: **1. Klang = FOUNDER-OHR.** Die strukturelle Hälfte ist gepinnt (`GenreFamilyDistinctnessTests`: kein Paar der angebotenen Genres teilt einen hörbaren Fingerabdruck) — dass eines davon GUT klingt, beweist nichts im Repo · **2. Kontrolle = ERFÜLLT, code-belegbar** (`soundPanel` hinter dem Sound-Chip, Preset-Leiste durch `SoundPanelPresetBarTests`) · **3. Modi = ERFÜLLT, code-belegbar** — und der Check meint etwas Engeres, als sein Name nahelegt: **„Loop" ist der MODUS, nicht die Bar-Anzahl.** `ComposerMode.init(locked:)` sagt es selbst — Loop = `studioLocked` (fester BPM für Produktion/DAW-Übergabe), Flow = `flowFree` (Tempo folgt dem Körper). Beide sind EINE Wahrheit, das BPM-Schloss, dessen Knopf in `BodyTempoField` sitzt. ⛔ Erste Fassung: `BioComposer.mode(locked:)` (Name existiert nicht) plus der Loop-Längen-Picker als Beleg — der misst Takte, nicht den Modus. Nachlese im SESSION_LOG · **4. Ausgabe = CODE-HÄLFTE ERFÜLLT seit #748** (schwebendes Fenster + Donut-Renderer, beide mit Tür; ⛔ Vollbild-Feld und VJ-Overlay sind mit #1069 gelöscht), die Hälfte „kontemplativ AUF DEM GERÄT" ist ein Blick, kein Test · **5. Stabilität = NUR GERÄT.** ⚠️ Also: zwei Checks zu, einer halb, und **die zwei offenen sind BEIDE sensorisch** — keine Sitzung kann sie durch Bauen schließen. Wer hier „noch viel zu tun" liest, liest falsch; was fehlt, ist eine Geräte-Session. **Deren Einkaufszettel druckt `python3 scripts/founder-verify.py`** (#752): es sammelt jeden `NEEDS-FOUNDER-VERIFY`-Vermerk aus `Sources/`, `Tests/` und dieser Datei zu einer Liste nach Bereichen — vorher Fließtext und als Warteschlange unsichtbar. **Der Rückstand steht hier NIRGENDS als Literal — die Zeile daneben IST die Messung** (#818: eine Zahl in der immer-geladenen Datei ist ein Datum, kein Sachverhalt). ⚠️ Ein Handzählen ersetzt sie nicht: `git grep -l` zählt jede Datei, die den Marker TRÄGT, das Werkzeug nur die mit einer echten BITTE — **zwei Nenner für eine Sache**, und genau der Grund, warum hier der BEFEHL steht. Erledigt wird mit `VERIFIED-JJJJ-MM-TT` auf DERSELBEN Zeile wie der Marker markiert (ein ECHTES Datum, nicht das Wort); markierte Bitten wandern in einen ANSWERED-Abschnitt und werden nie gelöscht — das Datum IST die Antwort auf „wann zuletzt bestätigt". Prosa ÜBER den Marker steht getrennt unter „NOT ASKS", weil der Marker auch ein gewöhnliches Substantiv ist und das Werkzeug sonst seine eigene Beschreibung als Auftrag liest. Diese Zeile bekommt bewusst KEINEN Wächter: ein negativer Scan auf CLAUDE.md träfe diese Rücknahme selbst (#491). ⛔ **Die VIER Rücknahmen dieser Zeile — und die drei Zahlen, die #1177 im Ledger SELBST abgelaufen fand — liegen in `memory/LEDGER_COUNTS.md` §H.**
- **Branch:** run `git branch --show-current` — the literal used to be pinned here and was wrong for weeks. Prior cycles auto-merged to `main`.
- **Mode:** RALPH WIGGUM LAMBDA — one feature/fix per cycle, build → test → ship → loop
- **Positioning:** "The first bio-reactive performance instrument" — and, per the 2026-06-06 deep-research roadmap, the **bio-reactive object source for accessible immersive multidimensional media art** (open standards: ADM-OSC, MIDI 2.0-ready input · MPE out, OSC, BLE HRS; no SDK lock-in — ⛔ „MIDI 2.0" stand hier nackt und war INPUT-ONLY: der Ausgang war MIDI-1.0-Protokoll (#1229 / `output-sync-6`); seit #1253 gibt es eine zweite, schaltbare MIDI-2.0-Quelle (Routing-Fläche, Default aus, Gerät unbestätigt)). See `scratchpads/STRATEGY_STATE_OF_THE_ART_2026-06-06.md`.
- **Architecture (audited 2026-06-09 — `scratchpads/ARCHITECTURE_AUDIT_2026-06-09.md`):** `EngineBus` = `@MainActor @Observable` control plane (snapshots) + lock-free `SPSCQueue`. **Continuous bio → `latestBio` snapshot · `controllerEvents` → EIN Queue-Verbraucher (MIDI) · `bioEvents` → EIN Verbraucher, `OSCSender.drainAndSendEvents` (OSC egress only, no synth sink).** ⛔ Die dritte Queue `bioFrames` hatte keinen Verbraucher und ist am 2026-09-24 GELÖSCHT (Wächter `TheBioSignalIsASnapshotNotAQueueTests`); ein Vollraten-Pfad bringt Queue UND Verbraucher zusammen. Modules couple only via the bus.
  ⛔ **DER POLL IST 10 Hz, DIE ANWENDUNGSRATE ~1 Hz — und die Verwechslung hat fünf Mal eine Zeitkonstante um das 10- bis 60-Fache danebengelegt** (#315, #332, #336, dann #459 zweimal in einer Richtung, die der Absatz nicht abdeckte). Jeder Verbraucher dedupliziert auf `frame.timestamp`, und jeder verdrahtete Publisher sendet mit ~1 Hz (`CameraRPPGBioPublisher.activeTickSeconds`, Polar 1 s, Simulator 1 s, HealthKit 500-ms-Poll hinter einem 4–5-s-Sensor). Der Rückfall auf `heldTickSeconds` (0,5 s) greift nur, solange iOS die Kamera hält und seit sechs Sekunden nichts ankommt — ein Zustand, in dem der Publish-Pfad eine Zeile früher schon an `inboundRateEMA` schließt. **Die ~1-Hz-Decke gilt also für jeden Tick, der überhaupt veröffentlichen kann. Für jede Zeitkonstante gilt die 1 Hz, nicht die 10.** ⭐ **REGEL: eine Rate gehört zu genau EINER Operation; wer „~1 Hz" aus einem Nachbar-Kommentar übernimmt, übernimmt zuerst, WELCHE Operation dort gemeint war.** Wächter im blockierenden Bundle: `Tests/CISmoke/BioApplyRateIsTheDedupedRateTests.swift` — er verankert die BENANNTE Konstante, nicht eine Schreibweise wie `milliseconds(100)`, denn genau diese Verankerung war beim Umbau rot geworden. Provenienz der fünf Auflagen: `memory/LEDGER_COUNTS.md` §Y und §AI.
- **Live pipeline:** HealthKit + **camera rPPG (live, locks on device)** + Demo → bio snapshot. (**Universal BLE HR (0x180D) = GEBAUT + VERDRAHTET.** ⚠️ **Die Tür ist NICHT die Patchbay:** der Gurt hat genau EINEN Lifecycle-Besitzer, das Source-Dropdown der Pulse-Pille (`startBioSource`). `blehrs.in` ist ein reiner Datenfluss-Port; `hasEnabledRoute(fromSource:)` hat **keinen Produktions-Aufrufer** — daraus keinen Start-Hook zurück-ableiten. Ein zweiter Besitzer killte einen über die Pille gestarteten Gurt bei JEDEM unbeteiligten Patchbay-Edit mitten in der Performance; BLE-3 hat die Kopplung 2026-07-15 entfernt. Gerät-Verify wartet auf Gurt-Eintreffen [NEEDS-FOUNDER-VERIFY].) Pipeline weiter: bio snapshot → BioReactiveSynthVoice (EchoelDDSP; **silent until user-armed** — der Schalter ist „Body voice" im `bioPanel`, seit #277; davor war „user-armed" eine Handlung OHNE Bedienelement und jeder Atem-Onset lief in `guard isArmed`) + OSCSender (`/echoelmusic/bio/*`) + **ADMOSCSender** (`/adm/obj/{n}/*` immersive object out). CoreMIDI-Noteneingang → controllerEvents → EINE monophone Performer-Stimme (Noten · Pitch-Bend · Vorrang vor der Atem-Hüllkurve).
  ⛔ **MPE IN ist NICHT real, MPE OUT schon** (#548/#713): `MIDIBusPublisher` parst MPE-Verkehr, unterscheidet aber keine Zonen, und der Verbraucher `BioReactiveSynthVoice.apply(controller:)` liest `event.channel` nirgends. ⭐ **Alle DREI Dimensionen KLINGEN seit #942** (Bend seit jeher, Press #939 `expressionGain`, Slide #942 `renderCutoffScale`) — **und das ist trotzdem kein MPE IN**: ohne Zonen (RPN 6,6) gibt es keinen Member-Kanal zu unterscheiden. Wer weiterbaut (Zonen), fängt NICHT am Parser an: `controllerEvents` ist SPSC mit EINEM Verbraucher, und der ist monophon — Zonen ohne zweiten Verbraucher sind wirkungslos (`scratchpads/PLAN_MPE_ZONES_2026-09-01.md`). ⭐ **GESETZ, und es gilt über MIDI hinaus: eine Fähigkeits-Behauptung hat so viele Flächen, wie jemand aufzählt** — „alle geprüft" heißt nur „alle, die mir eingefallen sind"; das Erkennungszeichen ist, dass alle bisher geprüften dieselbe GATTUNG haben (#766/#768). Wächter: `Tests/CISmoke/TheMPEInputHasNoZonesTests.swift` — er pinnt den VERBRAUCHER, nicht diese Prosa (#491). Die gefundenen Flächen und die vier Rücknahmen dieser Zeile: `memory/LEDGER_COUNTS.md` §N. BioEventGraph → breath/motion onsets.
  ⭐ **MODULATIONS-MATRIX — die Maschine läuft, und seit #1250 hat sie ihre Fläche.** `ModulationEngine` wird beim App-Start konstruiert, `start(subscribing: bus)` läuft, die 100-ms-Schleife tickt, `ModDestinationKey.tempo` ist registriert. ⭐ **seit #1250 (Founder 2026-09-11) hat die Matrix ihre Fläche:** Karte „Body → parameter" in der Routing-Fläche (`PatchbayView.modulationSection`) legt Routen an und persistiert sie — ⭐ **seit #1391 Tempo PLUS jeder automatisierbare Synth-Parameter**, als PROJEKTION von `PolySynthVoice.automatableBases` statt als Abschrift (#416). Registriert wird zur Laufzeit aus `ParameterApplyRouter.automatableDescriptors()` = Registry ∩ gebundener Setter, also kann kein Ziel angeboten werden, das nichts bewegt. ⚠️ Das Tempo behält seinen EIGENEN Handler (BPM-Lock · Oktav-Faltung · Glide, T1/T2) und `register` ERSETZT — ein tempo-förmiger Schlüssel in `automatableBases` überschriebe ihn still. Messen, nicht zitieren: `grep -n "static let all" Sources/Echoelmusic/Core/ModulationEngine.swift`. Wächter: `Tests/CISmoke/TheMatrixReachesEveryAutomatableParameterTests.swift`. ⚠️ Ein von einem älteren Build persistiertes Dokument zieht weiterhin am Tempo (`load()` gewinnt über die leere Default-Matrix) — genau die #527-Lage der Audio-Spuren, und deshalb nicht abklemmen. ⛔ **Diese Zeile behauptete vier Monate „ModulationEngine wired (bio→tempo)", während die Route fehlte** — dieselbe Über-Behauptung, die #496 auf dem FX-Panel zurücknehmen musste, eine Ebene höher. Provenienz: `memory/LEDGER_COUNTS.md` §AI.
  **EchoelBeat ist TOT.** `BeatPlayer.attach(to:)` hängt nur noch `previewVoice` ein — kein Pad-Voice, kein `pattern.onStep`; es kann heute KEIN Drum-Klang entstehen. Der Abriss (#167) ist fertig: `DrumSynthVoice`, `LaneDrumKitVoice`, `DrumNoteMap`, `PhysicalVoiceRef.drums` und `LaneVoiceRack.kits`/`setDrumsInsert` sind als Dateien bzw. Member gelöscht. **Die Enum-Cases `LaneVoiceKind.drums` / `TrackInstrument.drums` BLEIBEN** — die Gründe stehen an den Cases selbst. ⛔ Die erste Fassung begründete das mit „persistierte rawValues" und war in BEIDEN Hälften falsch, in vier Quelldateien zugleich. **Lehre: ein „NICHT löschen"-Kommentar mit falscher Begründung ist schlimmer als keiner — die nächste Session kann ihn nicht widerlegen.** Herleitung: `memory/LEDGER_COUNTS.md` §AD.
- ⛔ **AUDIO-EINGANG: GELÖSCHT (#1302, Founder 2026-09-12, wörtlich „Face und Audio Input komplett entfernen"). Hier stand die Vokal-Ketten-Zeile; es gibt kein Mikrofon mehr.** Als DATEIEN weg: `MicrophoneManager`, `AudioInputManager`, `MonitorInsertAU`, `MonitorTapWindow`, `MultiTrackRecorder`, `FeedbackGuard` (mit `HowlDetector`), `AudioInputPickerView`, `PlugInInvitation`, `RoutePlugInWatcher`, `VoiceAnalyzer`, `VoiceCaptureController`, `VoiceCaptureEngine`, `VocoderCore`, `BrainwaveModulation`, `VoicePitchCorrector` — plus 38 Wächter und die Store-/Website-Zeilen. **DREI SACHEN BLEIBEN ABSICHTLICH, und wer sie für Reste hält, löscht Funktionierendes:** (1) die PATCH-Hälfte der Stimmfarbe (`SynthPatch.voiceProfileTaps`/`-Label`/`-Blend`, `PolySynthVoice.applyVoiceProfile`, `VoiceTimbreProfiler`) — ein von einem älteren Build gespeicherter Patch trägt sie und wendet sie an (#95/#527); der NAME sagt „Voice", die SACHE ist der Synth (#1293) · (2) `RecordRouteOwner` als LEERES Enum samt Refcount — #299: ein Zähler, den zwei Besitzer unbalancieren konnten, hielt das Telefon in `.playAndRecord` · (3) `RetroCapture`/`SingleExport`, die den EIGENEN Ausgang mitschneiden, nie ein Mikrofon. **Nach AUSSEN ist alles zurückgenommen**: `ContentPipeline/CLAIMS.md` §11 ist als ganzer Abschnitt ausgesetzt, `fastlane/metadata` und `docs/` tragen keine Stimm-Zeile mehr, `docs/_headers` schließt `microphone=()`. ⭐ **ERLEDIGT mit #1415** (Founder-Freigabe „E. correct verified stale permissions"): `NSMicrophoneUsageDescription` ist aus `Resources/iOS/Info.plist` ENTFERNT. Der Beleg ist strukturell, nicht nur ein `grep`: die EINZIGE Stelle, die die Sitzung auf `.playAndRecord` heben kann, ist `AudioConfiguration.claimRecordRoute(_ owner: RecordRouteOwner)`, und `RecordRouteOwner` ist ein LEERES Enum — der Parametertyp hat keinen Bewohner, die Funktion ist unaufrufbar, `recordingRouteNeeded` ist `private(set)` und kann nie wahr werden. ⚠️ **Wer einen Fall zu `RecordRouteOwner` hinzufügt, MUSS den plist-Schlüssel im selben Commit zurückholen** — iOS beendet die App beim Aktivieren einer Aufnahme-Kategorie ohne ihn. Genau das hält `EveryPermissionPromptHasACapabilityTests` (`retiredPrompts`) fest.
- **LEBENSZYKLUS-LEITER im Absturz-Log (#859–#862b) — lesen, BEVOR man ein `echoel_diag.log` auswertet.** Jeder Eingriff in den Audio-Graphen schreibt eine Sprosse (beide `start`-Zweige, `stop`, `restartOrDegrade`, alle attach/detach, Interruption, Route-Verlust; ⛔ die `on N/5`/`off N/5`-Monitoring-Leiter ist mit dem Audio-Eingang gelöscht (#1302); seit #878 auch die drei Sitzungs-Kategoriewechsel in `AudioConfiguration` als `session: configure|raise|lower` — das sind ABSICHTLICH nicht alle 15 Session-Aufrufe der Datei). **GESETZ: eine Sprosse steht VOR ihrem Aufruf** — ein Zeuge HINTER dem Schritt sieht nichts; stirbt der Schritt, schweigt das Log, und Schweigen liest sich dann wie „Weg nicht genommen" statt „Weg mitten im Schritt gestorben". **Folge: Stille zwischen zwei Sprossen ist ein BEFUND.** `EchoelCrashLog.breadcrumb` (unbuffered `write(2)` in die exportierte Datei) wird VOR `os_log` geschrieben — `os_log` ist dort unsichtbar und nimmt ein Schloss. Wächter: `TheEngineLifecycleSpeaksInTheDiagLogTests` (Anzahl der Ansprüche: `grep -c "    func test"` — nicht hier zitieren, sie wuchs schon einmal am selben Tag). ⚠️ Der `isInputConnToConverter`-Auslöser hat nie einen Namen bekommen — er ist mit #1302 **gegenstandslos, nicht gelöst**: die Absturzfamilie saß am Eingangsknoten, den es nicht mehr gibt. Wer einen Eingang zurückbaut, erbt sie ungelöst. Die Leiter repariert keinen Absturz, sie macht das nächste Log aussagefähig.
- **Protected DSP triad (READ-ONLY, now implemented):** BioSignalDeconvolver (detrend·notch·validity), HilbertSensorMapper (1D→2D Hilbert curve), BioEventGraph (heartbeat/breath/motion detectors). Pure value types, SKILL.md contracts under `.claude/skills/`.
- **SDK:** iOS 18 deployment floor (Package.swift + project.yml + Resources/iOS/Info.plist synced). Xcode 26.2 in `testflight.yml`. App Group `group.com.echoelmusic`.
- **Root view (RE-FOCUS 2026-07-06B — founder: "die Leute brauchen gar keine Atemübung. Es geht um Performance und Entspannungssteigerung dadurch, dass sich die Musik mit dem Biofeedback generativ verändert"): the bio-generative INSTRUMENT is the app HOME.** (⛔ as a PERMANENT rule this is phase history since 2026-09-24 — it describes today's shipped root; the Session front is WA4 in `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`.) This supersedes the same-day 2026-07-06A "Session is home" flip (the founder tested it and rejected the breathing-exercise framing within hours). `WorkspaceView` body = brand header (`topBar`) + `CompositionHeaderStrip` + `EchoelStudioView()` + `FloatingVisualWindow`. (⛔ Hier stand „persistent `TransportBar`“ — mit #456 am 2026-08-07 aufgelöst: die Leiste hielt seit #411 nur noch zwei Kinder, und der Founder hat beide per Screenshot-Pfeil in die Transport-Zeile des Instruments geschickt. Die Chrome ist zwei Leisten, nicht drei.) **The Session experiment (`SessionView`/`SessionEngine`/`SessionGuide`/`SessionClock`/`EntrainmentEngine`) stays in code, compiling, but NOTHING presents it** — ⚠️ it is NOT the **canonical Session** (the future `DMMWProject` workstation root, WA2 decision in `docs/dev/SESSION_OWNERSHIP_CENSUS.md`); never door it as that, and do not delete those files without a founder ask (they hold the tested flash-safety/latency/pacing laws, reusable for future bio-visual work). The product bar now: the generative MUSIC must sound organic/professional and the VISUAL must be part of the experience ("wow", contemplative) — new surfaces follow the master plan's WA order, never ad hoc.
- **Studio shell internals:** brand header (`topBar`) + `CompositionHeaderStrip` + `EchoelStudioView` (the instrument) + the floating immersive visual (`FloatingVisualWindow`, toggled from the header monitor). **Die Chrome ist ZWEI Leisten, nicht drei** — die `TransportBar` ist mit #456 gelöscht, ihre Kinder sind ins Instrument gewandert (Play/Stop als `PlaybackToggleButton` #289, das Tempo-Feld in `EchoelStudioView.startControlRow` #411, „•••" und `TransportPositionView` #456). Der EINE Tempo-Regler ist weiterhin genau einer, er sitzt nur im Instrument. ⭐ **Lehre aus der alten Fassung: eine zitierte Phrase überlebt eine Einfügung, eine Zeilennummer nicht** — sie nannte vier Bedienelemente einer Leiste, die es nicht mehr gibt, und dazu eine Zeilennummer, die längst auf fremden Code zeigte.
  **The former 6-surface bottom bar (Arrange · Clips · Compose · Mix · Bio · Browse) is REMOVED from navigation** — **von den sechs ist nur noch EINE als Datei da: `BioSourceView`** (unerreichbar, aber restaurierbar). `ClipView` und `ArrangeTimelineView` sind mit #121 Slice 4 gelöscht, `BrowserView` und `ChannelRackView` mit #167. **Wiederherstellen hieße hier NEU BAUEN, nicht wieder anhängen** — die alte Fassung dieser Zeile behauptete das Gegenteil und war zu drei Vierteln falsch. Do not "restore" them without a founder ask. ⛔ **Es gibt keine „aufgeschobene" Video-Seite mehr** (#1303 nahm den Plan, #1304 die Fähigkeit): eine als vertagt geführte Fläche liest sich als Rückstand und lädt eine Sitzung ein, sie zu bauen. Sie ist zurückgenommen, nicht vertagt. The old `StudioRoot` Tools/Works/Sync/Well TabView is long gone. Provenienz: `memory/LEDGER_COUNTS.md` §AI.
- **Presentation (stability, as-shipped — corrected 10.76.38):** the device-confirmed-launching `EchoelStudioView` uses **MANY `AnyView`-wrapped `.sheet`/`.fullScreenCover` modifiers** chained on the body. Heute **12 dateiweit, 11 auf der Kette** (#1069 nahm das Vollbild, #1302 das Eingangs-Sheet, #W1 den toten MIDI-Importer), beide seit #479 in `ResetSoundClearsWhatTheLaunchLineReportsTests` festgenagelt — die DECKE bleibt bewusst 14, ein Budget, keine Zählung (#364). ⛔ Die AUFSCHLÜSSELUNG nach Modifier-Art stand hier und ist **gelöscht statt nachgeführt (#818): ihre SUMME überlebte, während beide geänderten Summanden falsch wurden** — kein Wächter auf die Summe kann das sehen. Messen: `python3 scripts/doctor.py --section D`. Provenienz und die Lehre: `memory/LEDGER_COUNTS.md` §D. Diese Zahl liest eine Sitzung, BEVOR sie einen Modal anhängt — an Kopfraum zu glauben, den es nicht gibt, ist der Weg zurück zum Black-Screen-SIGSEGV. Each has its own `isPresented:`/`item:` binding and an `AnyView(...)`-erased content closure. This is the baseline that launches — the earlier "ONE `.sheet(item:)` + ONE `.fullScreenCover(item:)` via computed bindings" note was **aspirational, never the shipping code**, and is removed to stop a future session "fixing" the launching code into a regression. **THE REAL RULE (learned the hard way, 10.76.34/build 2068 black screen): do NOT keep GROWING this modifier chain.** Adding sheets pushed the body's aggregate generic type past the SwiftUI metadata-decoder stack limit → SIGSEGV at first render, before any view appears (presents as a black screen, or "Safe Mode oder Black Screen" alternating once the self-healing net catches every other launch). The chain was "just under" the limit at 10.76.9/21; three sheets added 10.76.25/27/29 tipped it over (an `AnyView`-split of the chain did NOT save it — 10.76.35 still crashed; only reverting to the 10.76.21 body did). To add a NEW modal: **reuse/replace an existing slot, or consolidate the whole chain into a single `.sheet(item:)` enum FIRST** — never just append another `.sheet`. (Separately: never drive two modals true at once — that installs an invisible tap-blocking layer, the "can't click anything" hang.) **Also (10.76.41, "Tonart-Menü friert ein / kann plötzlich nicht mehr auswählen"): never read a HIGH-FREQUENCY `@Observable` (the ~10 Hz `CameraRPPGBioPublisher` finger/confidence/waveform, any bio snapshot, a playhead) directly in `EchoelStudioView.body` or in a computed `var` that `body` evaluates — `AnyView(...)` is NOT an observation boundary, so those reads register the WHOLE root body as a 10 Hz observer and every rebuild tears down any open `.menu` Picker popover (the freeze; worse while playing). Confine such reads to their own small leaf `View` struct (e.g. `BioStripView`, `PulseMeasurementView`) so only that view churns; the Picker-hosting body stays still.** **AND (10.76.48, "Sobald Biofeedback läuft kann ich nicht mehr auswählen"): the camera-freeze had a SECOND, non-SwiftUI cause — a high-frequency producer on a background queue must NOT hop to `@MainActor` per item. `CameraRPPGBioPublisher.onFrame` did a `Task { @MainActor }` PER captured frame (~30/s before the analyzer's frame-skip); that flood of tiny main-actor task submissions starved the SwiftUI executor → the open `.menu` Picker stopped responding while bio ran. Fix pattern: the background closure pushes into a lock-protected `RGBSampleQueue` (`@unchecked Sendable`, `NSLock`, capped) with ZERO actor hop; the EXISTING 10 Hz `publishTask` drains+feeds the `@MainActor` analyzer in one batch (carry a `timestamp` so rate maths is unchanged). Rule: never `Task { @MainActor }` per frame from a 30 fps source — batch into an existing low-rate main-actor poll via a Sendable queue.** **AND (10.76.50, the ACTUAL recurring menu-freeze cause — found after 41/43/47/48 each fixed a real-but-insufficient cause): the churn was in `WorkspaceView` (the ROOT, ABOVE every surface), NOT in `EchoelStudioView`. `WorkspaceView.topBar` read `cameraRPPG.waveform`/`detectedBPM`/`isLocked` directly to feed the header `PulseMonitorMini` — `waveform` updates ~10 Hz during biofeedback, so `WorkspaceView.body` rebuilt 10×/s and tore down any open `.menu` Picker in the surface BELOW it. Every prior audit scoped to `EchoelStudioView` and correctly found it clean — the 10 Hz read was one level up. FIX: confine the live reads to a leaf (`PulseMonitorMiniLive` reads the publisher in its OWN body); `WorkspaceView` only reads `isRunning` (start/stop). **RULE: when a freeze/churn persists after the obvious view is proven clean, AUDIT THE PARENT/ROOT (`WorkspaceView`, any always-on header/HUD that reads live bio) — a 10 Hz read in ANY ancestor of the menu host rebuilds the whole subtree. Header/monitor tiles that show live bio MUST read it in their own leaf, never via values passed down from a parent body.** ⭐ **DIE KAMERA IST NICHT DER EINZIGE HEISSE ERZEUGER — es sind FÜNF (#1268: die Face-Quelle), und zwei churnen, wenn AUDIO läuft, nicht wenn die Kamera läuft** (#919/#928). `AudioEngine.startMeterPollTimer` schreibt mit **60 Hz** neun `@Observable`-Anzeigen (`masterLevel`, `masterLevelR`, die R128-Werte) · `AutomationPlayer.applyStep` schreibt `masterVolume` bei **jedem Transport-Schritt** — und das ist BEREITS EINMAL PASSIERT (inline im `masterPanel`, riss die Tonart-Picker ab; `MasterVolumeField` ist die Reparatur) · `metronome.bpm` wird von `Transport.onTempoChange(id: "metronome")` bei jeder Tempoänderung geschoben, während eines Glides bis ~20 Hz. **Die Metronom-Fläche ist die gefährlichste der vier**, weil der Wirt `metronome.`-Eigenschaften bereits an ZWEI Stellen liest, die `body` auswertet (`mixerPanel`s Click-Leiste und `metronomeRow`) — zu Recht KALT, weil ein Finger sie dreht; Empfänger und Gewohnheit sitzen also schon im Rumpf, und die heiße Schreibweise unterscheidet sich um ein Wort. Gleiches Gesetz, gleiche Reparatur: der Read gehört ins Blatt. Wächter: `Tests/CISmoke/TheMenuHostReadsNoHotStateTests.swift` — VIER Mengen, die Bio-Menge über vier Vorfahren. Die Zähl-Kette dieser VIER (zwei Rücknahmen, beide Zahlen) liegt in `memory/LEDGER_COUNTS.md` §O. Details in `.claude/skills/swiftui-render-safety/SKILL.md`.
- **✅ TESTFLIGHT PIPELINE: GREEN (verified 2026-05-30).** Prior "deploy blocker" note is resolved — `testflight.yml` runs #1404–#1407 on `main` all succeeded across every platform (iOS upload + Summary), preflight confirms App Store Connect secrets are present and valid. Dispatch + poll from the sandbox via `bash scripts/check-testflight.sh dispatch` (token in gitignored `.claude/settings.local.json`). Push the feature branch's newer work (bio synth / OSC / Polar) to TestFlight with a full `build_only=false` run once a branch verification run is green.
- **Latest batch (2026-07-12)** — the 07-12 changelog paragraph (A3 · A4 · L1 · P1 · B2 · B3 · B4 · B5 · W1 · EchoelAI N0–N4 · Body Science) is MOVED verbatim to `memory/LEDGER_COUNTS.md` §P (audit 2026-09-02; it was 3.7 KB of dated history in the always-loaded file). Two facts from it stay LAW here: (1) `FeatureFlags.echoelAI` has ZERO readers (`git grep -n "FeatureFlags.echoelAI" -- Sources` → one COMMENT hit) — nothing is behind it; `EchoelParameterRegistry` and `ParameterToolCore` are LIVE in `Core/`, off only for lack of a caller. Never rely on that flag as a guard. (2) **Healing/organ/tissue/wound theme = pre-Echoel (BLAB/Syng) legacy, never code here, stays a hard REJECT red line.**
- **Quality-Knöpfe — die Zeile, die eine Sitzung liest, BEVOR sie einen anfasst:** `AdaptiveQuality` + `ResourceGovernor` leiten aus Thermik/Batterie/gemessener FPS eine Stufe ab, und die treibt `MetalBioView`s DETAIL/Reduce-Motion — **nie die Bildrate** (`MetalBioView` pinnt `preferredFramesPerSecond = 60` statisch, `AdaptiveQuality.swift` sagt es selbst). Der EINE verdrahtete Verbraucher ist `bioHz` → `OSCSender` (`PollingRateCeiling`), und das ist eine **DECKE, kein Ziel**. `targetFPS` / `oscHz` / `allowSpectralDonuts` haben bewusst KEINEN Verbraucher. ⛔ Diese Zeile behauptete bis 2026-07-28 beide Hälften falsch herum — die gefährliche Sorte veraltet. Zwei datierte Changelog-Absätze (2026-06-18 Ship, 2026-06-23 Arbeit, 1.865 B) sind mit #1311 nach `memory/LEDGER_COUNTS.md` §X verschoben; dort stehen sie wörtlich.
- **Absent (not wired — do not claim as shipping):** RTMP/streaming (`BroadcastPublisher` is a compile-safe scaffold behind `#if canImport(HaishinKit)`; HaishinKit not integrated), Video (⛔ die CAPTURE ist mit #1304 ganz zurückgenommen, der SCHNITT ging mit #121 Slice 3 — siehe den ⛔-Absatz ganz oben), multitrack audio (gebaut, flag-gated AUS, türlos — #204; „absent" stimmt für den Nutzer, „nicht gebaut" nicht für den Entwickler). **EchoelStore** (`Core/EchoelStore.swift`) = kompiliert, aber UNERREICHBAR: `ProUnlockView` wird nie präsentiert, es ist heute nichts kaufbar. Das eine kompilierte Produkt ist die NICHT-VERBRAUCHBARE `com.echoelmusic.app.pro` (`ProGate.swift`) — **ÜBRIGGEBLIEBEN, nicht der Plan**: die Founder-Entscheidung vom 2026-07-10 (wörtlich in `WorkspaceView.swift` über `body`) hebt das Einmal-Pro auf — v1.0 kostenlos, v1.1 „Echoel Live" Jahres-Abo, v1.2 Per-Event-Gebühr. `ProUnlockView`/`EchoelStore`/`ProGate` bleiben zur UMWIDMUNG im Code: nicht löschen, vor v1.1 nicht präsentieren. **Push/CloudKit:** `aps-environment=production` + iCloud/CloudKit-Entitlements SIND deklariert und `AnnouncementCenter` EXISTIERT — hart AUS über `AnnouncementCenter.cloudKitConfigured = false` (null CloudKit-/Push-Aufrufe; Launch-Crash-Fix v10.79.148), sein Lern-Schalter ist versteckt, solange das Gate false ist. Vor dem Umlegen in v1.1: CloudKit-Schema „Announcement" ZUERST nach Production deployen. **Art-Net + sACN (unicast) sind live.** **BioModulation** = reiner getesteter Kern, **nicht verdrahtet**. ⛔ `VocoderCore`, `VocoderMapping`, `VoiceAnalyzer`/`VoiceFrame`, `FeedbackGuard` und `HowlDetector` standen hier und sind mit #1302 als DATEIEN gelöscht.
  **TÜRLOS** seit dem Tools-Grid-Removal (2026-07-02) und weiter türlos: MeditationView (Founder: bewusst so, Teil des Produktionsflusses) · BroadcastView (korrekt so, solange RTMP nicht verlinkt ist — eine Tür zu einem toten Backend wäre ein Halbfertig-Feature). **Aus derselben toten Kette bleibt nur `importMIDI()` übrig, ohne Importer** — der ging mit #W1: ein `.fileImporter` über der Workstation überschattet deren Import-Tür. **BETÜRT:** PatchbayView (Routing/Master-Panel) · **WorkstationView** (#1436/#1437, Chip „Workstation“; die EINZIGE Produktions-Aufrufstelle von `TimelineRegionPlayer.play(`). **ALS DATEI GELÖSCHT STATT BETÜRT:** `PatchEditorView` (#132 Slice 6 — der lebende Timbre-Editor ist und war `soundPanel` hinter dem Sound-Chip), `SampleBrowserView` (#167), `FileWaveformView`/`WaveformView`/`WaveformCache` (#132 Slice 5; der reine Kern `WaveformReducer` BLEIBT, jetzt test-only und mit Nachruf im eigenen Dateikopf), `AutomationView` (Datei existiert nicht). `SpectralDonutView` ist erreichbar — messen, nicht zitieren: `git grep -n SpectralDonutView\( -- Sources`. **BioVisualParams** (immersive flash-safe pulse) ist **verdrahtet**.
  ⭐ **DREI GESETZE, die dieser Absatz teuer bezahlt hat:** (1) **unerreichbar ≠ wirkungslos** — „wirkungslos" lädt eine Sitzung ein, ein totes Bedienelement zu löschen; sie fände keins und stünde vor einem FUNKTIONIERENDEN hinter einer fehlenden Tür (#227/#1069) · (2) **Slot + Setzer beweist keine Erreichbarkeit** — „per direktem Code-Read verifiziert" heißt nur etwas, wenn die Kette bis zum RENDERNDEN Elternteil verfolgt wurde · (3) **vor dem Löschen eines UI-Blocks prüfen, welche Modelle er als EINZIGER schreibt** — ein Toggle mit persistiertem Flag hinterlässt eine unwiderrufliche Zustands-Leiche, keine Lücke. Die drei Opt-ins des toten Tools-Katalogs sind zurückgeholt: „Save to Apple Health" als `HealthWriteOptInRow` im Bio-Panel (ein persistiertes Gesundheits-Einverständnis MUSS einen erreichbaren Aus-Schalter haben), `midiOut.mpeEnabled` und `expressionEnabled` mit #713 als zwei Schalter im `midiOutSection` (EIN Besitzer: `MIDIOutput.applyOutputPreferences()`; der zweite ist deaktiviert, solange der erste aus ist, weil der Sendepfad `if mpeEnabled, expressionEnabled` liest). Wächter: `Tests/CISmoke/MIDIOutQualitySwitchesTests.swift`. **Nicht geräteverifiziert.**
  ⭐ **Mehrere Präsentations-Slots hängen an Flags, die niemand setzen kann** = freier Kopfraum, statt einen 15. anzuhängen. **Die Liste wird gedruckt, nicht abgeschrieben: `python3 scripts/doctor.py --section C`** (Datei und Zeile je Flagge). ⚠️ **Diese Zeile bekommt bewusst KEINEN Wächter** — ein Negativ-Scan auf CLAUDE.md wäre die #364/#486/#491-Falle: die Datei zitiert zurückgenommene Behauptungen absichtlich und träfe ihre eigene Rücknahme. ⛔ **Die PROVENIENZ dieses Registers — die Tür-Geschichte #1024→#1247 (§T), die „Donuts"-Nachlese (§G), die Grabstein-Erzählungen zu SampleBrowser/FileWaveform und die #713-Baugeschichte — liegt in `memory/LEDGER_COUNTS.md` §AI.** Register: `docs/dev/FEATURE_STATUS.md` (heute, drei Fächer) · `docs/dev/FEATURE_MATRIX.md` (Provenienz).
  ⛔ **DREI TÜRLOSE FLÄCHEN FEHLTEN IN DIESEM REGISTER (nachgetragen 2026-08-07, jede per Zählung der Instanziierungsstellen).** Das Register ist die Liste, aus der eine Sitzung ableitet, was sie noch aufmachen oder löschen darf — eine Lücke darin ist teurer als eine falsche Zahl, weil sie gar nicht erst als Frage auftaucht.
  · **Die VIER Analyse-Ansichten sind seit S4c (2026-09-23) BETÜRT — im Visual-Fenster, nicht im Field-Panel** (Founder: „Wenn dann ins Visual Window übertragen"): `VisualAnalysisLayer` ersetzt bei Large/Vollbild das Bild durch EIN Messgerät; das Field-Panel bleibt messgerätefrei. Wächter: `TheMetersLiveInTheVisualWindowTests`. **GESETZ: wer eine Register-Zeile über einen NACHBARN mit-behauptet, misst den Nachbarn mit** — dieser Eintrag nannte zwei der vier gemessen und die anderen zwei aus dem Gedächtnis „sehr wohl montiert", und der Quelltext war die ganze Zeit ehrlich. Herleitung: `memory/LEDGER_COUNTS.md` §K (#867).
· **`TimelineAutomationRow` = GELÖSCHT (#473, 2026-08-07).** Der Eintrag stand hier als türlos-aber-nicht-löschbar, weil `TimelineAutomationRowMath` in DERSELBEN Datei lebte und `Core/TimelineStore.swift` es ruft — ein „lösch die türlose Datei"-Aufräumen hätte den Store gebrochen. **#472 hat den Kern herausgehoben, #473 hat die Ansicht gelöscht**: `struct TimelineAutomationRow: View` plus `TimelineAutomationTargetOption` und `TimelineAutomationHeadCell`, alle drei mit null externen Verweisen. Die Datei ist weg; `Sequencer/TimelineAutomationRowMath.swift` bleibt und ist unverändert.
    ⛔ Die 415/198/344-Zahlengeschichte dieser Zeile (dieselbe Zahl ans falsche OBJEKT geheftet — nicht veraltet, sondern von Anfang an falsch zugeordnet) liegt in `memory/LEDGER_COUNTS.md` §I (#856); das GESETZ daraus steht schon in der #475-Zeile darunter: nenne die Größe des Eingriffs, für die Ansicht die Ansicht.
    ⭐ **Die SECHS Prosa-Zitate in fünf Dateien sind UMGESIEDELT, nicht verworfen** — der eigentliche Blocker, den keine Register-Zeile vorhergesagt hatte. Zwei GESETZE daraus, weil sie beim Bauen gebraucht werden: **ein Zeiger ist nur so haltbar wie das, worauf er zeigt** (dieselbe Datei verlor erst eine Zeilenspanne, dann den zitierten Block) · **„türlos, aber nicht löschbar" ist eine eigene Kategorie** (`AutomationPlayer.extraAutomatableDescriptors` stand von #473 bis #559 ohne Aufrufer und war die ganze Zeit richtig behalten — seit #559 liest es `Studio/AutomationStatusStrip.swift`). Welche fünf Dateien, welche zwei Ausfall-Mechanismen und warum zwei der Argumente durch die Löschung STÄRKER wurden: `memory/LEDGER_COUNTS.md` §R (#1142).
    ⚠️ Der Wächter ist im SELBEN Commit mitgezogen (#456): `TheAutomationRowLawHasItsOwnFileTests` LAS die gelöschte Datei über ein `try` hinter einem verzeichnis-weiten Skip — die Löschung wäre sonst ein hartes Rot auf korrektem Baum geworden. Ersetzt durch etwas STRENGERES: die Datei muss ABWESEND sein, und ein Lauf über `Sources/` verlangt **genau EINE** Deklaration von `enum TimelineAutomationRowMath` (die alte Form fragte nur, ob EINE benannte Datei sie nicht wiederholt — eine Zweitkopie irgendwo anders wäre durchgegangen). Der Test ist dabei umbenannt, weil sein alter Name ein Verfahren beschrieb, das der Code nicht mehr nimmt (#374). ⚠️ **Der hier ZITIERTE Name ist der heutige** — die Datei und die Klasse heißen so; wer aus diesem Satz einen neuen Namen sucht, sucht nichts. Der ALTE Name ist in diesem Shallow-Klon nicht mehr nachlesbar (die Datei existiert schon am Graft `545b19e`, `git log --diff-filter=R` über `Tests/CISmoke/` ist leer), also steht er bewusst nirgends — eine erfundene Rekonstruktion wäre schlimmer als die Lücke.
    ⚠️ **Was sich NICHT geändert hat: Timeline-Automation ist weiter unerreichbar.** `AutomationPlayer` hat keinen Produktions-Schreiber; eine von einem älteren Build persistierte Kurve SPIELT (über `applyStep` auf jedem Transport-Schritt), aber keine Fläche kann heute eine zeichnen. #473 hat eine Ansicht entfernt, die nichts montiert hat — keine Fähigkeit.
  · **`BreathGuideView` — SIEBTER Eintrag (#947), und der erste, den ein WERKZEUG fand statt eine Sitzung.** Genau EINE Konstruktionsstelle, in der selbst türlosen `BioSourceView` — also unerreichbar EINEN SPRUNG TIEFER, die Klasse, die `doctor --section C` bis #947 nicht sah. **Nicht löschen:** Atem-Führung mit Resonanz-Default, ≤0,2-Hz-Blitz-Gesetz, Kontraindikations-Bestätigung. Wer sie aufmacht, betürt den ELTERNTEIL. Herleitung und Wächter: `Tests/CISmoke/TheBreathGuideHasNoDoorTests.swift`.
  · ⛔ **`FaceExpressionBioPublisher` WAR DER ACHTE EINTRAG (#1002), wurde mit #1257 betürt und ist am 2026-09-12 KOMPLETT ENTFERNT (#1301, Founder wörtlich: „OK Face und Audio Input komplett entfernen. Keine Tests davon sollen im Repo bleiben").** Weg sind: der Publisher, `BodyPoseAnalyzer`, `FaceExpressionMapping`, `FaceTrackingRate`, `BodyPoseMath`, `FaceChannelsRow`, `CameraFrameSlot`, `BioSource.faceCam`, die 17 `BioSampleFrame`-Gesichts-/Kopf-/Körperfelder, die 17 `ModSource`-Kanäle samt `faceChannels`/`bodyChannels`/`gestureChannels`, `FXModPreset` mit den drei Startsätzen, der OSC-Adressraum `/echoelmusic/gesture/*`, die sieben `visualCamera*`-Schlüssel, `faceTrackingHz`, die 13 Kamera-Uniforms und der Kamera-Pass im Shader, `FeatureFlags.cameraExpression`, `BioSourceOption.face`, `cameraLayerRow` — plus **zwölf Wächter-Dateien**. ⭐ **Die zwei Gesetze, die NICHT mit weggehen, weil sie teuer gelernt wurden und nichts mit Gesichtern zu tun haben:** (1) **ein Schalter in einer VISUAL-Fläche darf das Instrument nicht starten** — #1298 leitete sein AUS durch `selectBioSource(_:)`, dessen dritter Zweig `else { startBiofeedback() }` ist, und #1300 musste ihn asymmetrisch machen; (2) **ein Kanal, dessen neutrale Messung eine echte 0 ist, kann nicht über seinen eigenen WERT gegatet werden — er braucht die PROVENIENZ des Frames** (steht jetzt im Doc von `ModSource.isMeasured`). ⭐ **`NSCameraUsageDescription` nennt seit #1415 nur noch die RÜCKSEITIGE Linse** — die Front-Kamera-Hälfte beschrieb den mit #1301 entfernten Gesichts-Pfad; gemessen: `AVCaptureDevice.Position.front` kommt in `Sources/` nicht vor.
  · **`PulseMeasurementView` — VIERTE türlose Fläche, nachgetragen 2026-08-12 (#525), und die einzige dieser Liste, die von sich selbst BEHAUPTET hat, auf dem Schirm zu sein.** Gemessen: `git grep -n "PulseMeasurementView(" -- Sources | grep -v ': *//'` = **EINE** Stelle (`Studio/BioSourceView.swift`), `git grep -n "BioSourceView(" -- Sources | grep -v ': *//'` = **NULL**. Die Kette endet einen Sprung höher. Ihr Dateikopf sagte trotzdem in der ersten Zeile „shown above the controls while a take is playing" — seit dem Tools-Grid-Removal (2026-07-02) falsch. ⛔ **Hier stand die „TEUERSTE Auslassung dieses Registers", und ihre MESSUNG war richtig, ihre SCHLUSSFOLGERUNG falsch (#703).** Wahr bleibt: `CameraRPPGBioPublisher.coachingHint` (= `acquisitionCue.fullHint`) hat GENAU EINEN Leser, und der ist diese türlose Ansicht. Daraus wurde hier „die rPPG-Abhilfe erreichte einen sehenden Nutzer nirgends" — und **das ist seit #523/#569 unwahr**: `BioStripView` rendert DIESELBE Zeichenkette über `acquisitionCue.fullHint` als Banner, sichtbar im `bioPanel`, gegated durch `cueWarrantsFullHintOnScreen` — **die Tür ist die PULS-PILLE** (`PulseMonitorMiniLive`-Tap → Chrome-Tür „bio"), KEIN Chip: `.bio` fehlt in `EchoelStudioView.studioChips` (#704). **Tot ist die PROPERTY, nicht die FÄHIGKEIT** — und der Quelltext hat das die ganze Zeit richtig gesagt (`PulseCue`: „UNTIL THIS PROPERTY HAD A CONSUMER"; `BioStripView`: „before this line"). Wächter der POSITIVEN Hälfte: `TheStallRemedyReachesTheScreenTests.testTheStripRendersTheStallRemedy` — ein neuer wäre #416. Ein Dateikopf, der „ist auf dem Schirm" sagt, bleibt trotzdem der Grund, warum das lange niemandem auffiel. ⛔ **NICHT LÖSCHEN, und zwar aus dem #472-Grund:** in diesem Dateikopf steht die kanonische Fassung des 10.76.41/50-Freeze-Gesetzes für diese Form, und die Präsentations-Zeile weiter oben zitiert die Ansicht NAMENTLICH als Musterbeispiel (dort neben `BioStripView` — die ist über die Puls-Pille erreichbar, diese nicht; das Beispiel gilt der FORM, nicht der Erreichbarkeit). Eine türlose ANSICHT und ein tragender Nachbar in EINER Datei. Wächter: `Tests/CISmoke/ThePulseReadoutHasNoDoorTests.swift` — er verbietet das Wieder-Aufmachen NICHT (#364), er nennt in seiner Fehlermeldung die **sechs** Prosa-Stellen, die dann im selben Commit mitzuziehen sind.
  · **Die AUDIO-SPUR-Schicht — FÜNFTER Eintrag (#527, 2026-08-12), und der EINZIGE dieser Liste, der GESCHLOSSEN ist.** `AudioLanePlayer` wird beim App-Start konstruiert (`EchoelmusicApp`) und vom Transport bei JEDEM prime/apply/stop gefahren — das war immer wahr. Sein Dateikopf sagte zusätzlich „audio lanes now sound in time with the arrangement“, und das war **eine Fähigkeitsbehauptung ohne Produzenten**: vier Monate lang konnte nichts Erreichbares eine audio-tragende Region anlegen — `AudioClipFactory` hatte genau EINEN Aufrufer (`TakeRecorder`), erreichbar nur über `RecordController.arm()` mit NULL Aufrufern (#204). ⭐ **AUDIO IMPORT V1 (Founder 2026-09-22) IST DER ERZEUGER**: `Sequencer/AudioImport.swift` ist der ZWEITE Aufrufer von `AudioClipFactory` und der erste mit Tür — die Zeile „Import Audio“ in `WorkstationView` kopiert eine gewählte Datei über `MediaLibrary` nach `Media/Audio`, misst die KOPIE, und legt `Clip(kind: .audio)` in `ClipStore` plus eine `TimelineRegion` auf die erste nicht-Bio-Audio-Spur. ⚠️ Die Behauptung bleibt BEDINGT: eine Spur klingt, wenn der Nutzer importiert hat; ⭐ **SEIT #F1 (Founder 2026-09-23) HAT DIE FRISCHE INSTALLATION EINEN AUSWEG**: „Add Audio Track“ in `WorkstationView` ruft `AudioImport.addAudioTrack`, `addLane`s ERSTEN Produktions-Aufrufer — über den Handover-Saum, nie aus dem `body`. ⛔ Vorher sät das Default-Dokument GAR KEINE Spur und der Import war auf einer frischen Installation unerreichbar; die SAAT (`TimelineStore.migrate`) bleibt es (§AK). Die RECORDER-Kette bleibt türlos — sie bräuchte einen Audio-EINGANG, den es nicht gibt (#1302). ⛔ Die alte Fünf-Stellen-Zählung der `TimelineRegion(`-Konstruktionsstellen stand hier und ist **gelöscht statt nachgeführt** (#818): die Zensur lebt als Wächter, nicht als Prosa.
    ⛔ **UND DAS IST KEIN LÖSCH-ARGUMENT, sondern das Gegenteil — der Punkt, an dem sich dieser Eintrag von den vier darüber unterscheidet.** `TimelineDocument` wird PERSISTIERT und beim Start dekodiert; ein Projekt, das ein Build mit erreichbarem Recorder-Pfad geschrieben hat, kann weiterhin eine Audio-Region tragen, und dieser Koordinator ist das Einzige, was sie abspielen würde. Die Schicht als „tot" abzuklemmen macht aus „offensichtlich abwesend" ein „still stumm". Die leere Audio-Spur im Default-Dokument bleibt ebenfalls absichtlich — der Founder hat die Mehrspur-Form („mehrere") ausdrücklich verlangt.
    ⭐ **DIE AUDIO-WAHRHEIT IST MIT #1438 EINMAL SAUBER ENTSCHIEDEN, weil der Repo-Stand sich selbst widersprach:** `ClipKind.timelineEngineKinds` sagte `[.midi]` („engines not shipped"), während `TimelineAudioSink` ausgeliefert ist, `EchoelmusicApp` ihn in `AudioLanePlayer` injiziert (`makeSink:` + `resolveURL:` → `MediaLibrary.resolveRef`) und `TimelineRegionPlayer` ihn bei jedem prime/step/stop fährt. **Die Maschine gewinnt gegen das Etikett:** die Menge ist jetzt `[.midi, .audio]`. ⚠️ **Das ist eine Korrektur, keine neue Fähigkeit** — was fehlt, ist der ERZEUGER, nicht die Engine, und beides sind verschiedene Tatsachen; genau ihre Vermengung hielt die Menge vier Monate veraltet. Eine UNTER-Behauptung kostet hier dasselbe wie eine Über-Behauptung, nur in die andere Richtung: ein Dokument, das die Engine spielen würde, wird von einem Prädikat abgelehnt, das diese Menge liest — „still stumm" statt „offensichtlich abwesend", die #527-Lage selbst.
    ⭐ **UND #1439 HAT DIE PRÜFFRAGE GESCHÄRFT, WEIL EIN MEDIEN-VERWEIS KEINE DATEI IST.** Der Play-Vorbehalt fragte, ob `clip.mediaRef` eine nicht-leere ZEICHENKETTE ist — wahr für jede Aufnahme, die seit dem Speichern gelöscht, verschoben oder von einer anderen Installation geschrieben wurde; `AudioLanePlayer` überspringt so eine Spur an allen drei `guard let url = self.resolveURL(`-Stellen, und der Transport lief über nichts. Gefragt wird jetzt `AudioLanePlayer.resolvedURL(forClipID:)` — DIESELBE injizierte Closure, die auch der Streaming-Pfad nimmt. ⭐ **GESETZ für jede künftige Medien-Domäne: die Existenz eines Verweises ist keine Auskunft über die Sache, auf die er zeigt — fragen darf nur der Auflöser, den der spielende Pfad selbst benutzt.** Die Grenze ist bewusst die AUFLÖSUNG, nicht die Abspielbarkeit: eine URL heißt „der Scheduler hat eine Quelle", nicht „die Datei dekodiert" (das bleibt Laufzeit).
    ⭐ **UND #1440 HAT DIESELBE FRAGE EINE EBENE HÖHER GESTELLT: EIN PLATZIERTER TEIL IST KEIN GESPIELTER TEIL.** Der Vorbehalt prüfte jede Region EINZELN — Gitter-Treffer plus Inhalt — und der Spieler fragt keine Region: `laneEvent` lädt, was `TimelineScheduling.activeRegion` an einem Gitter-Tick ZURÜCKGIBT, und das ist die SPÄTER beginnende überlappende Region (bei gleichem Start die später platzierte). Ein Teil, das man auf ein veraltetes drauflegt, nimmt ihm also jeden Tick, den es besitzt — und der Vorbehalt sagte Ja, während der Transport über Stille lief. `firstExecutableRegion` läuft jetzt über `TimelineScheduling.candidateSampleTicks(in:laneID:)` (die begrenzte Menge der Ticks, an denen der Gewinner wechseln kann — O(Regionen), kein Per-Tick-Durchlauf, keine zweite Uhr) und fragt `activeRegion`, wer gewinnt. ⭐ **GESETZ, und es gilt für jede künftige Fläche, die eine Zeitachse auswertet: Vorrang bei Überlappung ist EINMAL definiert, in `activeRegion` — wer ihn nachbaut, baut eine zweite Wahrheit über das, was der Nutzer hört.** Wächter: die Ansprüche 20–23 und Scan O in `Tests/CISmoke/TheWorkstationPlaysTheTimelineTests.swift`.
    ⭐ **Und der ranked board-Eintrag, der diese Schicht als „WIRED“ führt, ist seit Audio Import V1 GANZ richtig:** verdrahtet UND mit Erzeuger. Bis dahin war er halb falsch (verdrahtet ja, klingend nein), und wer daraus eine Löschung ableitete, leitete sie aus der falschen Hälfte ab. Wächter: `Tests/CISmoke/TheAudioLaneProducerIsTheImportDoorTests.swift` (die Zensur — wer darf erzeugen; ⛔ hieß bis 2026-09-22 TheAudioLanesHaveNoProducerTests.swift — ohne Backticks zitiert, weil zurückgenommene Namen hier bewusst keine bekommen (der Zitat-Wächter verlangt, dass jeder gebacktickte Name auflöst); der Name war ab dem Tag eine Falschaussage, #374) und `Tests/CISmoke/TheWorkstationImportsAudioTests.swift` (was ein Import erzeugt). Beide verbieten einen DRITTEN Erzeuger NICHT (#364) — sie verlangen, dass er diese Zeile mitzieht.
  · **Die MODULATIONS-MATRIX — SECHSTER Eintrag, nachgetragen 2026-08-12 (#541), und der zweite nach der Audio-Spur, der keine ANSICHT ist, sondern eine laufende Maschine ohne Erzeuger.** ⭐ **ERLEDIGT mit #1250:** `PatchbayView.modulationSection` konstruiert `ModRoute(` — der Eintrag bleibt als Herleitung, Wächter `TheMatrixHasADoorTests`. `ModulationEngine` wird beim Start konstruiert, `start(subscribing:)` läuft, die 100-ms-Schleife tickt, und `ModDestinationKey.tempo` ist als Ziel registriert. Gemessen fehlt die ROUTE: die Default-Matrix ist LEER (die Datei sagt es zweimal selbst), und `git grep -n "\bModRoute(" -- Sources` liefert **genau EINEN** Treffer — den `LossyDecoded`-Decoder in `ModulationMatrix.swift` (ohne die Wortgrenze kommt `FXModRoute(` dazu, ein fremder Typ). Null Produktions-Konstruktionsstellen. `Studio/BioModulation.swift` ist KEINE Fläche (es hält `ClockSource` und `BoundParameter`, reine Werttypen, null externe Verbraucher) — wer aus dem Dateinamen eine Matrix-UI erwartet, sucht falsch.
    ⛔ **Und das ist wieder KEIN Lösch-Argument, aus dem #527-Grund:** die Matrix wird PERSISTIERT und beim Start dekodiert (`load()` gewinnt über die leere Default), also kann ein Dokument aus einem Build mit erreichbarer Fläche weiterhin das Tempo ziehen. Abklemmen macht aus „offensichtlich abwesend" ein „still stumm". Ebenfalls tragend und nicht anzufassen: der `outputTap`, der JEDE angewandte Modulation als `/echoelmusic/mod/<key>` über OSC schickt — die Adresse steht im OSC-Abschnitt dieser Datei als real.
    ⚠️ Der Unterschied zu den vier Ansichts-Einträgen darüber: dort ist die Fläche weg und die Fähigkeit klar abwesend. Hier LÄUFT alles bis auf den letzten Zentimeter, und genau deshalb hat die CURRENT-STATE-Zeile vier Monate „wired (bio→tempo)" behauptet. Wächter: `Tests/CISmoke/TheTempoDestinationHasNoRouteTests.swift`.
- **P1 "Sound complete" — ALREADY BUILT (audited 2026-07-01; corrects the old "Clips/Arrangement UI not wired" note):** the melodic/DAW core is done and wired — **polyphonic synth** (`PolySynthVoice`) + **bass** (`SubBassVoice`) + ~~hybrid sample/synth drums~~ (`BeatPlayer` + `DrumSynthVoice` — **entfernt 2026-07-26, #166/#167; klingt nicht mehr**); **full patch editor + presets** (`SynthPatch`/`PatchStore` + `soundPanel`, favorites/community/save-as, live-apply, tested. ⛔ Hier stand `PatchEditorView` als der Editor „DOORLESS since 2026-07-25" — die Datei ist mit #132 Slice 6 gelöscht; der Editor war die ganze Zeit `soundPanel` hinter dem Sound-Chip); **breakbeat loop-cut** (`LoopBarLength` in der Studio-UI — ⛔ `LoopCutter` stand
  gleichrangig daneben und ist TOT, #1379: der `tile()`-Neuschneider hat null Aufrufer, die
  Fähigkeit liefert heute die Per-Takt-Generierung. Die DATEI bleibt, weil `LoopBarLength` in
  ihr wohnt und in sieben Dateien gelesen wird); **MIDI export** — **AUSGELIEFERT** (korrigiert 2026-07-28): `exportMIDI()` wird wieder aufgerufen, aus dem Export-Schacht heraus (#188 hat die Tür in den VORHANDENEN Slot zurückgeholt, kein neuer Sheet). `MIDIFileExporter` intakt und getestet. Der App-Store-Text behauptet den MIDI-Export — nicht entfernen, ohne `fastlane/metadata` mitzuziehen; Clips + Arrangement UI **DELETED** by the pure-instrument epic (#121 Slice 4 — `ClipView` 807dc0d, `ArrangeTimelineView` eb58e7a; `ClipStore`/`ArrangementStore`/`AutomationLane` model retires in Slice 5).
  **CRAFT-TOOL DOORS — the #131a craft-editor slot is GONE again (2026-07-26).** It was shipped 2026-07-25 (`f2cbf34`/`bda8f41`) to door the piano roll, and it held exactly ONE case; when the founder said *"Pianoroll soll raus"* the honest move was to take the slot with it rather than leave an undoored enum (the lying-`toolItems` trap). **Der Modifier-Zähler steht EINMAL, im Presentation-Absatz oben** — dort benannt, hier nicht nachgesprochen (⛔ #707 zitierte ihn hier wörtlich, und das Zitat traf nur sich selbst: `grep` fand die zitierte Schreibweise genau einmal, nämlich in diesem Zeiger; #708); seine Provenienz — die zwei Anker-Fehler und die Historie 12→16→15→14 — liegt in `memory/LEDGER_COUNTS.md` §D. Alerts und der File-Importer sitzen auf DERSELBEN Kette und kosten dieselben Metadaten. **The NEXT editor re-introduces the slot as `enum` + `@State` + ONE `.sheet(item:)` + an out-of-body content builder — NEVER a bare appended modifier**, and a case is added ONLY together with its door. Setterlose Slots sind die erste Stelle für Platz — **welche, druckt `python3 scripts/doctor.py --section C`; hier steht bewusst keine Liste**, die Menge bewegt sich in beide Richtungen (#747 nahm einen weg, #1024 legte einen dazu) und jede Abschrift altert. `sampleBrowserTrack` was the fourth and is DELETED (2026-07-27): once `SampleBrowserView` itself went, the slot pointed at a type that no longer compiles — a slot is only reusable while its content still builds.
  · **`PianoRollView` = GELÖSCHT (#475, 2026-08-07).** Der `struct` und die zwei privaten Gesten-Typen `RollDragAnchor`/`RollDrag` sind weg; belastbar ist die GRÖSSE des Eingriffs (`git show --stat`: 54 Einfügungen / 1020 Löschungen, netto **−966**), weil die sich nie wieder ändert. **Die Datei `Studio/PianoRollView.swift` BLEIBT**, weil sie `PianoRollModel` enthält — die Notenmaschine UND den `MusicalFrame`-Publisher, also die Wirbelsäule der Ausgabestufe (Visual · Licht · Raum). `RollSelection` ist geblieben, war test-only und hält seit Phase 3 / M1 die Auswahl von `PartNoteEditor` (`Tests/EchoelmusicTests/NoteTests.swift`), die `WaveformReducer`-Form. ⛔ **Diese Scheibe produzierte NEUN Falschbehauptungen — die höchste Zahl in dieser Kette; drei davon Zahlen. Die vollständige Nachlese liegt in `memory/LEDGER_COUNTS.md` §E** und gehört dorthin, nicht in die immer-geladene Datei. Was als GESETZ bleibt: **eine Zeilenzahl einer LEBENDEN Datei ist keine Tatsache, sondern ein Datum** — nenne die Größe des Eingriffs; und **ein Vermerk, der einen lebenden Mechanismus für tot erklärt, ist die teuerste Sorte**, weil er die nächste Sitzung einlädt, eine geltende Invariante als Ballast zu behandeln. **Consequence to state plainly: there is NO note editor in the app any more** — the generated take can be heard, mixed and exported, not corrected.
    ⭐ **UND DIE LÖSCHUNG HAT DREI NACHBARN VERWAIST, was keine Register-Zeile vorhergesagt hatte** (gemessen NACH dem Schneiden, die #472-Lehre): `Studio/RollHitTest.swift` und `Studio/RollFitMath.swift` hatten danach **null** Produktions-Aufrufer (⭐ seit Phase 3 / M1 ruft `Studio/PartNoteEditor` beide wieder — `classify` und `medianPitch`, via `Sequencer/ClipNoteEdit`), `Studio/RollNoteOps.swift` überlebt mit genau einem (`stableSeed`, gerufen von `PianoRollModel`). Keiner ist mitgelöscht — `RollHitTest` trägt das #470-Gesetz, das die Löschung überleben SOLLTE, und im blockierenden Bundle pinnt es `TheUnitToPeriodLawSurvivesTheViewTests`. Dessen dritte Behauptung („die Lane ruft das Gesetz noch") ist im selben Commit zurückgezogen, weil die Lane weg ist — der Wächter hatte diese Anweisung in der eigenen Fehlermeldung stehen. **Sieben `PianoRollModel`-Mitglieder sind ebenfalls aufruferlos** und im Dateikopf namentlich aufgeschrieben statt still gelöscht.
  · **`PatchEditorView.swift` IST GELÖSCHT (#132 Slice 6, 2026-07-31).** Der lebende Timbre-Editor ist `soundPanel` (an `dropdownContent` `.sound`, erreichbar über den Sound-Chip) und war es die ganze Zeit — meine frühere Behauptung, das Instrument könne „keinen Klang formen oder speichern", war FALSCH. Die fünf persistierten Parameter, deren einzige Zeile in der türlosen Datei stand, sind portiert (#281/#286); die Preset-Leiste hält alle sechs Aktionen. Wächter: `Tests/CISmoke/UnisonRowDefaultsTests.swift` und `Tests/CISmoke/SoundPanelPresetBarTests.swift` — und DAS ist der Grund, warum die Löschung nichts gekostet hat. **Lehre: ein „gehört dem Founder"-Vermerk mit prüfbarer Begründung gehört geprüft, bevor er eine Aufräumarbeit blockiert** — die `outputLevel`-Hälfte hing einen Monat an einer faktisch falschen. ⛔ Die Provenienz (die Portier-Geschichte je Parameter, die „fehlte nie"-Rücknahme des Shallow-Klons, die `loudnessNormalized()`-Widerlegung, die nicht portierte Preview-Tastatur) liegt in `memory/LEDGER_COUNTS.md` §Z.
  · **`ImmersiveStageView` (spatial stage) stays doorless — deliberately.** Ship-gate item 4 makes light/space "demonstrable, not required for v1" (#131c). Its only child, `ADMStreamStatusLine` (`NetworkActivityDot.swift`), is doorless one hop down — `git grep -n "ADMStreamStatusLine(" -- Sources | grep -v ': *//'` → 1, the stage; guard `TheStageStatusLineHasNoDoorTests`; re-door the parent, not the child (#1235).
  · **Correction to a claim I made about the roll:** presenting it is NOT what publishes `MusicalFrame`. That publish is in `PianoRollModel`'s tick handler (`PianoRollView.swift`) on the shared sequencer tick, installed once at app start (`pianoRoll.start(...)` in `EchoelmusicApp`) — so the visual/light output stage is lit whether or not the roll is open. The door is load-bearing for EDITING, not for the spine.
  · **NEEDS-FOUNDER-VERIFY:** launch (the +1 modifier vs the black-screen law). ⛔ Die zweite Hälfte — „and the roll's Stop, which cascades the ONE-Stop law … and ends the whole bio session" — ist **HINFÄLLIG**: dieser Knopf saß in der `PianoRollView`-`struct`, die #475 gelöscht hat. Ein Verify-Posten, der auf ein entferntes Bedienelement zeigt, kostet den Founder eine Geräteprobe, die nichts entscheiden kann. Der ÜBERLEBENDE Produzent des Playback-only-Stopps ist das Transport-■ in `WorkspaceView` (`pianoRoll.requestPlaybackOnlyStop()`, #179), und den pinnt `OneStartControlTests.testThePlaybackOnlyStopHasAReachableProducer` im blockierenden Bundle.
  Music theory is fully in-house. ⛔ **„The real remaining frontier is P3 Video" stand hier und ist mit #1304 gegenstandslos:** der Founder hat Video am 2026-09-12 ganz zurückgenommen („Kein Video Capture"), Recorder, Bibliothek und mp4-Export sind als Dateien gelöscht, der Schnitt war schon mit #121 Slice 3 weg. Es gibt keine Video-Grenze mehr zu erreichen — nur noch **P4 Broadcast**, und das ist unverlinkt. See `scratchpads/PLAN_REDOOR_CRAFT_TOOLS_2026-07-25.md`.
- **Files:** Swift-Dateien unter `Sources/` — **MESSEN, nicht zitieren**: `git ls-files 'Sources/**/*.swift' | wc -l`. ⛔ Hier stand ein Literal samt seiner ganzen Zähl-Kette (983 B in der immer geladenen Datei); beides ist mit #818 **gelöscht statt nachgeführt**, weil die Zahl beim Schreiben schon ein Datum war und es wieder geworden ist: #813 legte EINE Datei an (`Core/CoherenceTrend.swift`) und niemand wurde rot. Die ZÄHL-KETTE — jeder frühere Stand, die Taxonomie ±0/+1/+2/−1 und jede ⛔-Rücknahme — steht in `memory/LEDGER_COUNTS.md` §B; **wer eine Zahl nachführt, führt sie DORT nach.** Ein Wächter pinnt POSITIV, dass hier der Befehl steht; ein Negativ-Scan auf die Abwesenheit der Zahl träfe diese Rücknahme selbst (#491)), **ZERO Metal files** — corrected 2026-07-25; the old "~212 Swift + 1 Metal (`Video/Shaders/ChromaKey.metal`)" was stale twice over: the count was long out of date and `ChromaKey.metal` was DELETED by Slice 3 (video-cut removal) together with its directory. `MetalBioView` compiles its shader inline at runtime, so the app ships no `.metal` source at all. | **Swift 100%** | top-level dirs under `Sources/Echoelmusic/`: `Audio Bio Core DSP EchoelAI Resources Sequencer Stream Studio Sync Tools Video Views`, plus the two loose top-level files `EchoelmusicApp.swift` and `MicrophoneManager.swift`. NOTE: the "four pillars" (EchoelTools/Works/Sync/Well) referenced by older vision docs were **never built as modules** — `EngineBus` is the one real coupling spine; `Views/` now holds only `MetalBioView` + `OnboardingView` (its long deprecated list is gone).

---

## BRAND

**Echoel — Physical Computing · Biofeedback · Multimedial & Multidimensional.**

An immersive multimedia instrument and production platform for **Installation · Event · Content · Cinema · Theater · Performance.** The body is the controller: heart and breath drive sound, image, light and immersive space in real time.

⛔ **Der Absatz, der hier stand, war die dichteste Falschstelle der ganzen Datei** — und er stand unter der Überschrift BRAND, also genau dort, wo eine Session Formulierungen für Store-Text, Website und Presse HOLT. Er lautete: *„Concrete capabilities span beat-making, multi-track recording, video capture/edit, RTMP live streaming, bio-reactive synthesis, generative visuals, and OSC/MIDI/MPE integration"*. Davon existieren heute: bio-reaktive Synthese, generative Visuals, OSC/MIDI. **Beat-making ist mit #166/#167 gelöscht · Video-EDIT mit #121 Slice 3 · RTMP war nie verlinkt · MPE hat keinen Schreiber · Multi-Track-Recording ist gebaut, aber flag-gated aus und türlos.** Fünf falsche Behauptungen in einem Satz, aus dem Marketing-Text entsteht — #184 hat genau solche zwölf aus dem App-Store-Text entfernt, wo eine falsche Behauptung eine 2.3-Ablehnung ist. **Die wahre Fassung ist die Zeile, die mit „Capabilities (all routed through one typed bus)" beginnt**; von dort zitieren, nicht von hier. Die Identität ist **das Instrument**, nicht ein Konkurrent, den es ersetzt.

**Biofeedback is core, not wellness.** Echoel treats physiology as a first-class, science-based modulation source (HRV resonance, peer-reviewed bio-signal processing). It is NOT a wellness, soundscape, or therapy product.

NEVER use "BLAB", "Vibrational Force", legacy bio-wellness/soundscape branding, or esoteric terminology ("healing frequencies", chakras, Solfeggio) in user-facing copy.

---

## ARCHITECTURE (original v10 target — SUPERSEDED; see CURRENT STATE for as-built)

> ⚠️ **This tree is the ORIGINAL v10 plan, NOT what shipped.** The as-built app is a
> single `EchoelStudioView` (see "CURRENT STATE" above and "Studio sections" below) —
> there is **no `StudioRoot` TabView**, and Record/Video/Share were never built
> (RTMP / video capture / multitrack = roadmap). Kept here only as the audio-foundation
> reuse map.

```
EchoelmusicApp (@main)
└── StudioRoot                     ← TabView with 4 tabs (NEW)
    ├── BeatTab                    ← drum pads + 16-step sequencer (NEW)
    │   └── PatternEngine          ← 8-track × 16-step + tempo clock (NEW)
    │       └── SamplerVoice       ← one-shot WAV player (NEW)
    ├── RecordTab                  ← mic + master mixer + REC (NEW)
    │   ├── MultiTrackRecorder     ← mic over beats, sample-accurate sync (NEW)
    │   ├── RetroCapture           ← 30s pre-roll ring buffer (KEEP)
    │   └── AutoMixChain           ← EQ → Comp → Limiter → LUFS (KEEP)
    ├── VideoTab                   ← camera capture + trim (NEW)
    │   ├── CameraSession          ← AVCaptureSession 1080p30 (NEW)
    │   ├── VideoRecorder          ← AVAssetWriter H.264+AAC (NEW)
    │   └── ClipTrimmer            ← in/out points (NEW)
    └── ShareTab                   ← RTMP stream + export (NEW)
        ├── RTMPPublisher          ← HaishinKit wrapper (NEW)
        └── SingleExport           ← LUFS mastering → WAV/AAC/MP4 (KEEP)

Audio Foundation (KEEP):
  AudioEngine (AVAudioEngine master bus) · SPSCQueue ·   (⛔ MicrophoneManager: gelöscht #1302)
  EchoelDDSP (reused as synth voice) · EchoelCellular (⛔ „test-only, nicht als klingende
    Stufe zitieren" GESTRICHEN 2026-09-21: #1385 hat es auf einen Render-Thread befördert.
    `git grep -n "EchoelCellular(" -- Sources | grep -v ': *//'` → EINE Produktionsstelle, die `texture`-Stimme
    des AUv3. Im APP-Ziel klingt es weiter nicht — der Unterschied gehört in jede Kopie.
    ⭐ GESETZ: ein wiederbelebter AUFRUFER schärft jeden latenten Defekt im Aufgerufenen,
    dessen Datei sich nicht geändert hat. Herleitung: `memory/LEDGER_COUNTS.md` §AH.)
```

Deprecated from main flow: SoundscapeEngine, ClipEngine, MomentCaptureView, BioSourceManager,
  Oura/EEG bridges, WeatherProvider, CircadianClock — alle 2026-06-19 GELÖSCHT, existieren
  nicht mehr. (HealthKit + rPPG sind LIVE, nicht deprecated.)

  **REGISTER DER UNVERDRAHTETEN KERNE — Namen und die EINE Falle je Eintrag. Messung,
  Cluster-Begründung und Zähl-Ketten: `memory/LEDGER_COUNTS.md` §AB (Inventur) und §Q (die
  `Sync/`-Zählung). Kein Eintrag ist zu löschen; der Defekt war nie ihre Existenz, sondern
  unerreichbar UND nicht aufgeschrieben.**
  · **`Studio/BioModulation`** — ⚠️ der Pfad ist KEINE Kosmetik: `Core/BioModulationMap` ist
    eine ANDERE, LEBENDE Datei, deren `isMeasured` die „gemessen"-Anzeige in beiden
    Synth-Stimmen und im Bio-Panel gated. `git grep -c BioModulation` zählt die Nachbarin MIT;
    wer hier „aufräumt", löscht plausibel das lebende Gate. Wächter
    `TheTwoBioModulationsAreDifferentFilesTests`.
  · **`Core/CloudSync`** · **`Core/BioSpaceMap`** (die sendende bio→Objekt-Abbildung steht in
    `Sync/ADMOSCSender` selbst) · **`Core/VisualModulation`** (nicht mit dem verdrahteten
    `BioVisualParams` verwechseln; Wächter `TheVisualModulationCoreHasNoCallerTests`).
  · **`Core/AudioFeatureChannel` + `Core/AudioFeatureExtractor`** (#1325) — ⚠️ der Kanal wird
    trotzdem PRO BILD gelesen; `MetalBioView` bekommt jedes Mal `.silent`. Die Lese-Stelle IST
    der Montagepunkt eines künftigen Eingangs; wer sie „aufräumt", verlegt die teure Hälfte in
    den churn-empfindlichen Rumpf.
  · ⭐ **`Core/TuningDetector` (+`DetectedTuning`) IST SEIT #E1 KEIN WAISE MEHR** — Erzeuger ist
    `Sequencer/AudioKeyAnalysis` (Fenster aus der verwalteten Kopie → `DSP/PitchTracker` →
    `analyze`), GENAU EINER, gepinnt von `TheToneSystemIsNamedByItsTypeTests`. ⚠️ **Die
    Schätzung SCHREIBT NICHTS**: `SessionContext` bleibt der EINE Besitzer von
    `echoel.keyRoot`/`echoel.keyScale`/`echoel.a4Hz` — erkannt wird berichtet, entschieden
    wird vom Nutzer. **Wer detektierte Tonart baut, baut sonst einen zweiten**; `confidence`
    und das nil bei dünner Evidenz sind schon da.
    ⭐ **GESETZ, und es gilt dem REGISTER selbst: zwei Waisen können die zwei HÄLFTEN EINER
    Fähigkeit sein.** Das Register sieht das nicht, weil es je Eintrag fragt „wer ruft DAS
    hier?" — YIN lag in `DSP/`, die Tonart-Schätzung in `Core/`, beide monatelang aufruferlos,
    dazwischen fehlte nur das Lesen von PCM-Fenstern. **Bei einem Waisen-Eintrag also auch
    fragen, ob ein ANDERER Eintrag sein fehlendes Stück ist.** Herleitung (#C1 → #E1 an einem
    Tag, die Mikrofon-Falle im Dateikopf): `memory/LEDGER_COUNTS.md` §AJ.
  · **`Core/BioTempoDirector`** (#1163) — die fertige „Follow pulse"-Spur. **Gefährlichste
    Sorte: ein ZWILLING des lebenden Servos** (inline in `EchoelStudioView`); wer den
    Tempo-Glide repariert, editiert plausibel die Datei, die nichts ausliefert.
  · **Die RAUM-RENDER-Hälfte, sieben Kerne:** `Sync/VBAPPanner`, `Sync/AmbisonicsEncode`,
    `Sync/LightFixtureGroup` (+`LightFixture`), `Sync/BioPhaser` (+`BioPhaserSource`),
    `DSP/BinauralPanner` (+`BinauralCues`), `DSP/EchoelSpaceReverb`,
    `Sequencer/SpatialAutomationMapping`. Real ist die STEUER-Hälfte (`SpatialSceneStore` →
    ADM-OSC auf der Leitung). Wächter `TheSpatialRenderHalfIsNotClaimedLiveTests`.
  · **Der TOTE EXEKUTOR und seine sechs Nachbarn (#1381):** `Sequencer/AudioClipPlayer` plus
    `Sequencer/LyricsModel` (SIEBEN Typen), `Sequencer/TakeDistance`, `DSP/PatchLibrary`
    (+`LibraryPatch`), `Audio/LatencyCompensation`
    — je NULL Verweise aus fremdem `Sources/`-CODE, nach TYP gemessen. ⛔ **`DSP/PitchTracker`
    stand in dieser Aufzählung und ist mit #E1 GESTRICHEN**: `Sequencer/AudioKeyAnalysis` ruft
    es, die Behauptung „null Verweise" ist für diesen einen Eintrag falsch geworden. ⛔ **Ebenso
    `DSP/EchoelMIDIDecode` (gestrichen 2026-09-24):** der AUv3-Render-Block ruft es seit #1385 —
    der wiederbelebte Aufrufer, nach der Register-Messung. Der Rest
    der Zeile bleibt unberührt — eine Sammel-Zeile wird EINTRAGSWEISE zurückgenommen, nie im
    Ganzen, sonst verliert man sechs wahre Befunde für einen veralteten. ⚠️ **Die #1376-Falle
    sitzt hier siebenfach: `LyricsModel.swift` deklariert keinen Typ dieses Namens** — ein per
    DATEINAME belegter Eintrag wäre eine Nadel, die nie treffen kann. ⭐ Der tote Exekutor war
    in ACHT fremden Dateien als der LEBENDE ausgeschildert („Used by AudioClipPlayer", „the
    forthcoming AudioClipPlayer", „an AudioClipPlayer-backed sink"); die fünf Falschstellen
    sind korrigiert — der Sink ist `TimelineAudioSink`, injiziert in `EchoelmusicApp` —, die
    drei verbliebenen Zeiger tragen `(dead)`. ⚠️ `Sequencer/AudioClipRegion` ist NICHT tot,
    aber viel knapper als es aussieht: ZWEI lebende Leser (`Clip.swift`, seit S1 `AudioTempoCorrection`),
    beide lesen EIN Mitglied — `nativeBPMRange`, die geteilte Klammer (#416). Trim-/Loop-/Warp-Mathe
    hat nur tote Verbraucher; `Sequencer/WarpedClipPlan` ist dabei als ACHTER Waise gemessen
    worden. ⛔ Meine erste Fassung dieser Zeile schrieb „sechs Verbraucher" aus `git grep -l`,
    das KOMMENTARE mitzählt — vier davon nennen den Typ nur in Prosa, und
    `AudioRegionPlayback` nimmt einen `TimelineRegion`. **Der #867-Defekt in dem Register, das
    ihn als Gesetz führt**; kommentar-gestrippt messen, sonst zählt man Zitate.
  ⭐ **DREI GESETZE, die dieses Register teuer gelernt hat:** (1) **wer einen Scope in eine
  Register-Zeile schreibt, schreibt hin, was der Scope AUSGESCHLOSSEN hat** — der 2026-09-02-Lauf
  zählte ehrlich „VIER `Sync/`-Kerne" und wurde als Gesamtzahl gelesen, während drei identisch
  tote Zwillinge ein Verzeichnis weiter lagen (#1379) · (2) **wer eine Behauptung mit ZWEI
  Trägern zurücknimmt, misst die Träger EINZELN** — #1230 führte `DSP/EchoelWSOLA` hier, belegt
  mit einer Nadel auf einen DATEINAMEN (der Typ heißt `WSOLAStretcher` und hat drei
  Aufrufstellen); der Eintrag ist mit #1376 gestrichen, es ist die #527-Lage (verdrahtet, Daten
  ohne Erzeuger), §AA, Wächter `TheStretcherIsNamedByItsTypeTests` · (3) **ein Vermerk, der ein
  `grep` ZITIERT, altert schneller als einer, der eine Tatsache behauptet.**

  NOW WIRED — nicht als unverdrahtet führen: **BioVisualParams** (gelesen von `MetalBioView`) ·
  **LearnLibrary** (LearnView) · **EchoelFXView** (Tür `showAllFX`). ⛔ **`FeedbackGuard` stand
  in dieser Gegenliste und ist mit #1302 als DATEI GELÖSCHT (#1379)** — übrig sind vier
  Kommentare. Der Eintrag versprach dazu eine Tür („Master-Panel ‚Audio input'"), die mit dem
  Audio-Eingang ebenfalls weg ist. ⭐ **GESETZ: eine Löschung muss die Liste der LEBENDEN
  mitziehen, nicht nur die der toten** — #1302 führte den ⛔-Block über die Vokal-Kerne sauber
  nach und ließ den Namen eine Zeile höher, in der Gegenliste, stehen. VocoderCore,
  VoiceAnalyzer/VoiceFrame, VocoderMapping und BrainwaveModulation sind mit #1302 ebenfalls
  gelöscht; ihr Block ist entfernt statt nachgeführt, weil eine Verdrahtungs-Analyse über nicht
  mehr existierende Dateien zum Wiederaufbau einlädt. **Die LEHRE bleibt: ein „unverifiziert,
  behaupte nichts"-Vermerk bleibt für immer stehen, wenn niemand die zwei `grep`s macht, die
  ihn auflösen.**

Protected (do not modify without explicit user approval):
  BioEventGraph, HilbertSensorMapper, BioSignalDeconvolver.

### EchoelStudioView (actual, as shipped — corrected 2026-07-04)

**The single Compose instrument, NOT a section shell.** Since the 2026-07-02 founder
pivot ("Alles weg außer visuals"), the section Picker and the Tools grid are REMOVED
from the UI — `EchoelStudioView` is the one-button bio-generative flow: a menu bar of
chips, each opening one dropdown panel, plus generate + play and FX character.

**Re-verified against code 2026-07-25 — all three concrete claims that stood here were
wrong, so check before trusting this paragraph again:**
- `BioStripView` is NOT always-on. It lives in `bioPanel` (`EchoelStudioView`),
  reached by a TAP auf die Puls-Pille (⛔ diese Zeile SAID „reached by the \"Bio\" chip" und war die ACHTE und stärkste Fundstelle des #705-Idioms — sie überlebte, weil die Nadel `Bio chip` die ZITIERTE Form `the "Bio" chip` nicht trifft, also genau die häufigste Schreibweise; #706 hat die Nadel normalisiert) — that is deliberate (B3, 2026-07-12): the always-on strip was
  removed so its 10 Hz camera read stays in a leaf and cannot tear down an open Picker.
- `PianoRollView` is DELETED (#475, 2026-08-07) — the chip, the `craftEditor` slot and its
  content builder went 2026-07-26 on the founder's "Pianoroll soll raus"; the 987-line struct
  itself followed. This paragraph flipped twice while the view existed, so the flip-checking
  advice stood here for good reason — it no longer applies, there is nothing left to re-door
  without writing it. `PianoRollModel` in the same file is untouched and load-bearing.
- The patch editor's live equivalent is `soundPanel` (presets, tone/filter/envelope, save-as)
  behind the Sound chip. `PatchEditorView.swift` was the near-duplicate file and is DELETED
  (#132 Slice 6, 2026-07-31) — it never was the live door.

There are no audio-clip doors — that surface went with the DAW removal. AUv3 hosting is
gone (#121 Slice 2) — ⭐ **aber Echoel IST seit #1385 wieder ein AUv3-Instrument (Target
`EchoelmusicAUv3`, `aumu`/`echl`, reines Swift, in die App eingebettet); es HOSTET nur nichts.**
Wer die zwei verwechselt, baut einen Plugin-Wirt vor dem Geräte-Vertrag (WA3; Hosting ist künftiger DMMW-Umfang), oder löscht
ein Target, das er zurückbestellt hat. ⭐ **Es LÄDT — in AUM, gerätegemessen 2026-09-20 (#1386): die
`-3000`-Frage ist für EINEN Host beantwortet.** ⚠️ „Läuft in Logic/GarageBand" bleibt NICHT
freigegeben: ein Gerätelauf beweist EINEN Host. Messung und Nebenbefunde:
`FOUNDER_DEVICE_SESSION.md` §2b. The old Section/Tools table stood here until 2026-07-04; do not
resurrect it as fact.

---

## TECH STACK — Zero Dependencies Today

| Layer | Framework |
|---|---|
| Apple (iPhone) | SwiftUI + AVFoundation + Accelerate + Metal + CoreMIDI + **Network** (OSC · ADM-OSC · Art-Net · sACN) + die Sensor-/Kollab-Quellen HealthKit · CoreBluetooth · CoreLocation · WeatherKit · MultipeerConnectivity, je hinter `canImport` |
| RTMP/RTMPS | HaishinKit = **PLANNED** dep for P4 Broadcast — NOT linked (`Package.swift` `dependencies: []`; `BroadcastPublisher` is a `#if canImport(HaishinKit)` scaffold) |
| Build | XcodeGen (`project.yml`) + Fastlane (TestFlight upload) + GitHub Actions |
| DSP | Swift (audio-thread-safe, lock-free SPSC queues) |

⛔ **`VideoToolbox` und `SwiftData` standen hier und werden NIRGENDS importiert** (`git grep -l VideoToolbox -- Sources` → 0, `git grep -ln 'import SwiftData' -- Sources` → 0; Stand 2026-07-31). Das ist die Tabelle, die eine Session liest, BEVOR sie eine Persistenz- oder Encode-API wählt — ein Phantom hier führt direkt zu Code gegen ein Framework, das das Projekt nicht benutzt. Persistenz läuft über `Codable` + JSON in `*Store`-Typen. ⛔ Hier stand „Video-Encode über `AVAssetWriter` in `VideoRecorder`" — `VideoRecorder` ist mit #1304 weg und die App kodiert kein Video. ⛔ **Die Rücknahme BELEGTE das mit „`git grep -l AVAssetWriter -- Sources` → 0", und diese Zahl ist FALSCH** (#1425): `Audio/SingleExport.swift` konstruiert genau einen, mit `mediaType: .audio` — der Master-Export. **Ausgerechnet die Tabelle, die eine Sitzung VOR der Wahl einer Encode-API liest, behauptete damit die Abwesenheit der API, die hier BENUTZT wird** — dieselbe Phantom-Gefahr wie zwei Sätze höher, nur andersherum. Gepinnt ist die SACHE, nie diese Zahl: `TheShareReadyClipIsNotSoldAnywhereTests` Anspruch 4 verlangt null `AVAssetWriterInput(mediaType: .video` in `Sources/` UND den Audio-Input in `SingleExport`. Von dort lesen (§W).

⛔ **Und die erste Reparatur dieser Zeile machte denselben Fehler eine Stufe kleiner.** Sie ergänzte fünf Sensor-/Kollab-Frameworks und ließ **`Network` weg** — dabei trägt genau das die Sync-Fähigkeit, die die Identitätszeile nennt (`Sync/OSCSender`, `ADMOSCSender`, `ArtNetSender`, `SACNSender`, **4 Dateien**, mehr als HealthKit mit 3). Eine Tabelle, die vor der Wahl einer Netzwerk-API gelesen wird und das Netzwerk-Framework verschweigt, ist derselbe Defekt wie ein Phantom, nur andersherum. Ebenfalls nachgetragen: `SwiftUI` (47 Dateien, das mit Abstand meistimportierte). Bewusst NICHT gelistet: `UIKit` (13) — es steht schon als Plattform-Guard-Regel weiter unten; und die Ein-Datei-Fälle CloudKit · Photos · ARKit · AVKit · CoreHaptics · UserNotifications, damit die Zeile eine Orientierung bleibt und kein Inventar wird. **Auswahlregel, damit die nächste Ergänzung nicht wieder willkürlich ist: alles, was eine in der Identitätszeile genannte Fähigkeit trägt, plus alles ab ~3 importierenden Dateien.**

Zählweise: `git grep -ln "import <X>" -- Sources` — **und das zählt Kommentare mit**. Die erste Fassung schrieb „CoreBluetooth 2 Dateien"; einer der beiden Treffer ist Prosa in `MultipeerSession.swift`, echt importiert wird es in **einer**. **Jeder neue Eintrag in dieser Zeile braucht den Befehl daneben — und einen Blick auf die Treffer, nicht nur auf ihre Anzahl.**

**⭐ PLATTFORM-ZIEL (Founder 2026-07-31, wörtlich): „Das gesamte Apple Ökosystem soll langfristig unterstützt werden auch VR/XR und Waerables."** Das ist die Richtung, nicht eine Option — iPhone-first ist **Reihenfolge, kein Umfang**. Konsequenz für jede UI-Entscheidung ab hier: **jeder feste `frame(width:/height:)` und jedes Panel, das nicht reflowt, ist Ökosystem-Schuld**, kein Schönheitsfehler. Der Adaptivitäts-Durchgang (#292) ist damit Fundament, nicht Politur.

**Heute ausgeliefert: iPhone (`"1"`). Die Watch (`"4"`) ist ein KOMPILIERTES, NICHT EINGEBETTETES Target — `project.yml` hält `# - target: EchoelmusicWatch` auskommentiert, kein Build liefert eine Watch-App aus (⛔ hier stand „+ Watch als Anzeige"; Audit 2026-09-10 `ship-path-3`).** Die Reifeleiter — was jede Plattform BRAUCHT, bevor sie angeschaltet werden kann, damit die nächste Session nicht rät:

| Plattform | Stand | Was fehlt, bevor es angeht |
|---|---|---|
| **iPhone** | live | — (Instrument · Sensor · Ausgabe) |
| **Watch** | Target existiert und ist **NICHT eingebettet** (`project.yml` hält `- target: EchoelmusicWatch` unter den App-Abhängigkeiten auskommentiert), `EchoelWatchApp.swift` liest den App-Group-Container **dieses Geräts** | **ein TRANSPORT — aber NUR in EINER Richtung, und die erste Fassung dieser Zelle faltete beide in eine Frage (#549 → #1315).** **Uhr → Telefon (die Bio-Quelle) braucht KEINEN:** HealthKit IST der Transport, er ist verdrahtet, und ein `.healthKit`-Rahmen erreicht heute `PolySynthVoice` ohne Quellenfilter — und im Flow über `bodyTempoTrustworthy` im ERSTEN Rahmen auch das Tempo. Die Uhr KLINGT schon. Was dort fehlt, ist die KADENZ (`git grep -rn "HKWorkoutSession" -- Sources | grep -v ': *//'` → 0; im Ruhezustand schreibt die Uhr minutenweit, `HealthKitBioPublisher.swift:43`), nicht der Kanal. **Telefon → Uhr (Anzeige) braucht einen:** ein App-Group-Container ist PRO GERÄT — Uhr und Telefon teilen kein `UserDefaults(suiteName:)`, genau deshalb ist derselbe Code fürs Widget (dasselbe Telefon) richtig und trägt zwischen Handgelenk und Telefon in KEINE Richtung ein Byte. Gemessen: `git grep -n "WatchConnectivity\|WCSession" -- Sources | grep -v ': *//'` → nichts. Wer das übersieht, **merkt es nicht**: `refreshFromSharedStore()` liefert bei leerem Container nil und die Uhr rendert den plausiblen Leerzustand („Start a session on iPhone.") — verdrahtet-und-tot sieht aus wie unverdrahtet. `WCSession` ist ein NEUES Framework ⇒ Council/Founder. ⚠️ `project.yml:296` trägt die alte Ein-Richtungs-Route — **berichten, nicht editieren**. Plan, Council und die Scheiben A–E: `scratchpads/PLAN_WATCH_2026-09-13.md`. ⭐ **Scheibe A ist GEBAUT (#1319):** „Apple Health“ ist der vierte Chooser-Eintrag — sein Arm startet NICHTS (der Publisher ist app-eigen), er stoppt die anderen drei. B–E offen. Wächter: `Tests/CISmoke/TheWatchHasNoTransportTests.swift`. **Harte Grenze bleibt:** ~4–5 s LATENZ (nicht Kadenz — zwei verschiedene Größen) → Anzeige, Trend, langsame Modulation, **niemals Beat-Sync** |
| **iPad** | **fünf Einstellungen + ein Wächter, in EINEM Commit** (`TARGETED_DEVICE_FAMILY` an App · Widget · **AUv3 (#1385)** · beiden Test-Bundles, dazu `Tests/CISmoke/DeviceFamilyIsPhoneOnlyTests.swift` — harte Gleichheit im BLOCKIERENDEN Bundle — **plus zwei Prosa-Blöcke**, die beim Ändern falsch werden: der `#`-Block über der Einstellung und die ⛔-Notiz unter dieser Tabelle) | eine dort funktionierende Bio-Quelle — kein iPad hat eine rückseitige LED, und `CameraCapture` koppelt die rPPG-Beleuchtung an `device.hasTorch`; der BLE-Gurt ist gebaut+verdrahtet, die Watch käme als zweite Quelle infrage — **plus** #292 (heute reflowen **5 von 9** Panels; Befehl siehe die Zeile „Kein ‚nie'" unter dieser Tabelle. ⚠️ **Diese Zahl steht an ZWEI Stellen** (hier und in der Zeile „Kein ‚nie'") — wer sie nachführt, führt BEIDE nach; Provenienz in §F) |
| **Vision / XR** | kein Target; `visionOS` kommt in `Sources/` nur in Plattform-Guards vor — **gemessen 2026-09-12 nach #1302 noch ZWEI Dateien** (`SPSCQueue`, `MemoryPressureHandler`); `MicrophoneManager` und `AudioInputManager` standen hier und sind mit dem Audio-Eingang gelöscht | der natürliche Sitz ist die **Ausgabe-Stufe, die schon existiert**: `ImmersiveStageView` (türlos, absichtlich — Ship-Gate 4 sagt „demonstrierbar, nicht erforderlich"), ADM-OSC-Raum, das Visual. Bio-Quelle bliebe Telefon oder Gurt |
| **Mac** | kein Target, kein Catalyst-Flag | offen |

⛔ **DIE ENTSCHEIDUNG (v1.0 = iPhone) STEHT — ihre BEGRÜNDUNG ist Sequenzierung und der fehlende Sensor auf iPad, NICHT ein Verzicht aufs Ökosystem.** ⭐ **GESETZ, das eine künftige iPad-Rückkehr braucht, weil sie aus dieser Zeile ihren Aufwand schätzt: Wiederanschalten ist NICHT „eine Zeile"** — wie viele Einstellungen es sind, steht EINMAL, in der iPad-Zeile der Tabelle oben; hier wiederholt zu werden war #416, und die Kopie war am 2026-09-20 prompt die veraltete (#1385 machte aus vier fünf, und nur die Tabelle wurde gezogen). Der eingängigere Satz war der falsche; hier war nicht eine Zahl veraltet, sondern eine Behauptung wurde nie geprüft, weil sie gut klang und niemandem wehtat. **Ein Slogan, der Arbeit KLEINER macht als sie ist, ist gefährlicher als eine falsche Zahl.** ⛔ Die vollständige Provenienz — beide Fassungen des 07-31, der Slogan in vier Dateien — liegt in `memory/LEDGER_COUNTS.md` §S.

**Der entscheidende Grund ist der SENSOR, nicht das Layout, und er gehört hierher, weil aus dieser Zeile heraus über Plattformen geplant wird:** `CameraCapture` koppelt die rPPG-Beleuchtung an `device.hasTorch`, und kein iPad hat eine rückseitige LED. Auf iPad läuft der Finger-auf-Linse-Puls also ohne Licht — genau die Bedingung, die der 2026-06-18-Fix als Ursache fürs Nicht-Locken identifiziert hat. Ein iPad-Build stellt die eigene Prämisse („Dein Körper spielt es") auf ein Gerät, auf dem die Hauptquelle degradiert ist.

**Kein „nie".** Die großen Flächen sind die Zukunft als **AUSGABE** — externer Bildschirm/Beamer (#206), ADM-OSC-Raum —, nicht als zweite App-Oberfläche. Kommt iPad als Instrumenten-Fläche zurück, braucht es eine dort funktionierende Bio-Quelle (der BLE-Gurt ist gebaut und verdrahtet) plus den Adaptivitäts-Durchgang #292. **Der Durchgang passiert ohnehin:** iPhone allein spannt 375–440 pt, erlaubt Querformat und läuft mit ungedeckeltem Dynamic Type — heute reflowen **5 von 9** Panels (`mixerPanel` · `soundPanel` · `moodPanel` · `visualPanel` · `masterPanel`); die anderen vier — `menuPanelHost`, `bioPanel`, `tempoToolsPanel`, `effectsPanel` — stapeln weiter starr. ⚠️ **Das liest sich nach vier offenen Einheiten und ist es nicht:** `menuPanelHost` ist der WIRT und erreicht transitiv alles, `bioPanel` trägt NULL Zahlenfelder, `effectsPanel` zwei Picker. ⛔ **Der Rückstand ist NULL Scheiben plus ein Grund** (#1375): die einzige Fläche mit Inhalt zum Umbrechen wäre `tempoToolsPanel` mit zwei Feldern in `metronomeRow` — und die zwei sind **nicht benachbart** (zwischen ihnen sitzt „Accent downbeat", den #930b absichtlich direkt unter die Zahl gesetzt hat, die er hörbar macht). Ein Gitter braucht benachbarte Mitglieder; es zu erreichen hieße, eine dreimal korrigierte Entscheidung still umzudrehen, oder einen `Toggle` mit einem Feld zu paaren — die Ragged-Height-Regression, die `MoodPanelReflowsTests` Anspruch 3 verbietet. Wächter: `MasterPanelReflowsTests` · `MoodPanelReflowsTests` · `SoundPanelReflowsTests` · `VisualFineTuneReflowsTests` · `TheClickAccentPairStaysAdjacentTests`.

⭐ **DREI MESS-GESETZE, die diese Zahl teuer bezahlt hat — sie werden beim NACHFÜHREN gebraucht, deshalb stehen sie hier und nicht im Ledger:**
1. **Ein Gitter kann in einem `private var` liegen, das KEIN Panel ist** (`weatherRow` war genau das). Wer die Zahl nachführt, folgt dem AUFRUFER, nicht der Dateireihenfolge — eine aus der Dateireihenfolge abgeleitete Zuordnung hat hier zwei Codeänderungen überstanden, ohne dass ein Test rot wurde. Ebenso: ein Gitter muss nicht im Rumpf seines Panels stehen (`visualPanel`s zwei sitzen in `visualAdjustFields(spacing:)`, das der Rumpf nur AUFRUFT).
2. **Der NENNER und die GITTER-TRÄGER sind zwei verschiedene Fragen** und liefern zwei verschiedene Zahlen (9 bzw. 11). Wer sie verwechselt, hält eine für falsch. Der Nenner-Befehl misst zudem die NAMENSFORM statt der Sache: er zählt `menuPanelHost` mit (den WIRT) und übersieht `utilityRow` (ein Dropdown-Panel, das nicht reflowt).
3. **`spacing` ist bei `AdaptiveCardGrid` ein ARGUMENT, kein Literal** — in EINER Spalte ERSETZT das Gitter den Abstand seines Wirts, ein fest verdrahteter Wert setzte also eine Fläche im Hochformat still um.

```
grep -n "AdaptiveCardGrid {\|AdaptiveCardGrid(spacing" Sources/Echoelmusic/Studio/EchoelStudioView.swift
grep -n "private var \w*Panel\w*: some View\|private var weatherRow: some View" Sources/Echoelmusic/Studio/EchoelStudioView.swift
grep -n "^ *weatherRow$" Sources/Echoelmusic/Studio/EchoelStudioView.swift   # WER baut die Zeile ein
```
(die `private struct AdaptiveCardGrid`-Zeile selbst ist kein Treffer.) ⛔ **Die PROVENIENZ — die vier Fassungen der Zahl, die dreimal geerbte Falsch-Begründung mit `sessionPanel`, die #505→#747-Tür-Kette und der alte Nenner elf — liegt in `memory/LEDGER_COUNTS.md` §F.** Ein Verschieben ist erst eines, wenn BEIDE Seiten gemessen sind (#746/#912, §F.4).

---

## REPO STRUCTURE (v10)

```
Sources/Echoelmusic/
  Audio/               ← AudioEngine, AudioConfiguration, MIDIInput,
                          RetroCapture, AutoMixChain, SingleExport (KEEP)
                       ← (MicrophoneManager/AudioInputManager/MonitorInsertAU/
                          MonitorTapWindow/MultiTrackRecorder GELÖSCHT #1302 — kein Mikrofon)
  Sequencer/           ← PatternEngine (the TRANSPORT — tempo/play/stop/step clock),
                          BeatPlayer (its holder + audition; the kit inside it no longer
                          SOUNDS — attach(to:) hangs only previewVoice. ⛔ #167 ist am
                          2026-07-31 FERTIG: `DrumSynthVoice.swift`, `LaneDrumKitVoice.swift`
                          und `DrumNoteMap.swift` sind gelöscht, `PhysicalVoiceRef.drums`
                          und `LaneVoiceRack.kits`/`setDrumsInsert` ebenfalls. Was BLEIBT und
                          bleiben MUSS: die Enum-Cases `LaneVoiceKind.drums` und
                          `TrackInstrument.drums` — persistierte rawValues; ein unbekannter
                          wirft und verwirft die ganze Spur beim Decode),
                          SamplerVoice (audition + lane sampler)
  Video/               ← **NUR NOCH DER rPPG-PULSPFAD**: CameraCapture, CameraAnalyzer,
                          RPPGConditioning, PulsePeriodEstimator. ⚠️ Der Verzeichnisname lügt
                          seit #1304 — hier wird kein Video aufgenommen, hier wird der PULS
                          gemessen. `VideoRecorder`/`VisualRecorder`/`VideoMuxer`/
                          `VideoMuxAlignment` sind gelöscht (Founder 2026-09-12), `CameraSession`/
                          `ClipTrimmer` gab es nie. **Wer hier nach Verzeichnis löscht, löscht die
                          Flaggschiff-Bio-Quelle.**
  Stream/              ← BroadcastPublisher ONLY — a `#if canImport(HaishinKit)` compile-guard
                          scaffold. HaishinKit is NOT a dependency; there is no RTMPPublisher
  Studio/              ← EchoelStudioView (root), EchoelFXView,
                          EchoelTheme (as-built; the old StudioRoot/Beat/Record/Video/
                          ShareTab plan was never built. SampleBrowserView + BrowserView
                          gelöscht 2026-07-27 #167; ClipView mit #121 Slice 4)
  Core/                ← EchoelStore, SPSCQueue, ProfessionalLogger, MemoryPressureHandler,
                          NumericExtensions, ClipStore, ModulationEngine (KEEP). No `SessionStore`
                          — the real files are SessionContext/SessionNaming/SessionRecorder
                       ← (SoundscapeEngine/ClipEngine/WeatherProvider/CircadianClock/PlatformAvailability REMOVED 2026-06-19)
  Bio/                 ← BioEventGraph, HilbertSensorMapper, BioSignalDeconvolver (PROTECTED)
                       ← EchoelBioEngine + HealthKitBioPublisher + CameraRPPGBioPublisher (LIVE)
                       ← (BioSourceManager/OuraRingClient/EEGSensorBridge/MotionActivityProvider REMOVED)
  DSP/                 ← EchoelDDSP, EchoelVDSPKit (KEEP, reused as synth voices).
                          ⚠️ `EchoelCellular` KLINGT seit #1385 — aber NUR im AUv3, nie im
                          App-Ziel. Die Messung steht EINMAL, in der Audio-Foundation-Liste oben.
                       ← EchoelModalBank — ⛔ TEST-ONLY seit #167 (2026-07-31): sein einziger
                          Instanziierer war `DrumSynthVoice`. ~800 Zeilen DSP ohne
                          Produktionspfad. Nicht gelöscht (Founder sagte „erstmal"), aber auch
                          nicht als lebende Stimme zitieren.
                          ⛔ **Ein REZEPT hier lief ab** („`git grep -l EchoelModalBank` liefert
                          NUR die eigene Datei" — es wurden drei, beide Zusatztreffer Kommentare).
                          Der Befehl, der die SACHE misst, ist der auf die BENUTZUNG:
                          `git grep -n "EchoelModalBank(" -- Sources` → 0. **Lehre: ein Vermerk,
                          der ein `grep` ZITIERT, altert schneller als einer, der eine Tatsache
                          behauptet — jeder Kommentar über die Sache verfälscht den eigenen
                          Beleg.** ⭐ **Und die Gegen-Lehre, seit #1427 an sechs
                          Zitaten dieser Datei angewandt: wo ein Zitat bleiben MUSS, wird es
                          kommentarfest gemacht statt nachgeführt** — `| grep -v ': *//'`, die
                          Form, die `BioSourceView.swift` und `PulseMeasurementView.swift` schon
                          vorschreiben. Sie stellt jede der sechs Zahlen exakt wieder her. Herleitung: `memory/LEDGER_COUNTS.md` §W.
  Sync/                ← OSCSender, ADMOSCSender, Art-Net/sACN (EchoelLux), CloudSync
  Tools/               ← PolySynthVoice, SubBassVoice, BioReactiveSynthVoice,
                          FXBioModulator — ⛔ #1330: „breath/vocal tools" stand hier und
                          der Vokal-Pfad ging mit #1302; `ls` liefert genau diese vier
  Views/               ← MetalBioView + OnboardingView ONLY (the old deprecated-view list is deleted)
Tests/EchoelmusicTests/ ← die NICHT-blockierende Suite. **MESSEN, nicht zitieren:**
                          `git ls-files 'Tests/EchoelmusicTests/*.swift' | wc -l`.
                          Das BLOCKIERENDE Bundle ist eine ANDERE Suite — es baut aus
                          `Tests/CISmoke` (`git ls-files 'Tests/CISmoke/*.swift' | wc -l`); wie dort
                          ein Wächter geschrieben, benotet und gemeldet wird, steht in
                          `Tests/CISmoke/CLAUDE.md`. Die Beschriftung in `full-tests.yml` nennt eine
                          dritte Zahl und bleibt vorerst falsch — founder-gated (#208).
                          ⭐ **Ein Name ist genauso ein `git ls-files` wert wie eine Zahl** — die
                          Disziplin dieses Absatzes zielt auf veraltete ZAHLEN, während ein
                          erfundener Dateiname daneben ungeprüft durchläuft (#474).
                          ⛔ **Die ZÄHL-KETTE — jeder frühere Stand, jede ⛔-Rücknahme — liegt in
                          `memory/LEDGER_COUNTS.md` §C (#702; §A = `Tests/CISmoke`, §B = `Sources`).
                          KEINE Zeile ist gelöscht. Wer eine Zahl nachführt, führt sie DORT nach.**
                          Siehe KEY TESTS.
docs/                  ← Website (GitHub Pages)
.github/workflows/     ← CI/CD (testflight.yml is primary)
```

Existing top-level directories under `Sources/Echoelmusic/`: `Audio/ Bio/ Core/ DSP/ EchoelAI/ Resources/ Sequencer/ Stream/ Studio/ Sync/ Tools/ Video/ Views/`. No NEW top-level directories without approval.

---

## BIO-SIGNAL DSP — DO NOT SIMPLIFY

| Algorithm | Basis | Function |
|---|---|---|
| BioEventGraph | DELLY (Rausch 2012) | Graph-based event detection, k-means clustering |
| HilbertSensorMapper | Hilbert curves | 1D→2D locality-preserving sensor mapping |
| BioSignalDeconvolver | Tracy (Rausch 2017) | Separates cardiac/respiratory/artifact via adaptive biquad IIR |

### DDSP Bio-Mappings

**LIVE (4 — a producer derives each from the frame):** Coherence → **filter cutoff · brightness · harmonicity · noise level** | HRV → **brightness** | Heart rate → **vibrato depth AND rate · brightness** | Breath phase → **amplitude (the breath swell)**

⚠️ **LIVE heißt „hat einen Erzeuger", nicht „ist ab der ersten Sekunde messbar": Kohärenz kommt auf JEDER Quelle als Letzte, nach ~16 akzeptierten Schlägen** (`HRVCoherence.minIntervals` = 16). ⛔ Bis #1220 (2026-09-10) war sie auf der KAMERA bei Ruhepuls strukturell abwesend: `detectPeaks` baut `rrIntervals` aus einem festen 10-s-Fenster ganz neu (≥17 Peaks in 10 s ≈ 102 bpm), und genau dieses Array bekam `HRVCoherence.compute` — die vier Kohärenz-Kanäle und der Flow-Servo liefen auf der Flaggschiff-Quelle auf dem Neutral 0,5 (Audit 2026-09-10 `bio-pipeline-3`). Seit #1220 rechnet `CameraRPPGBioPublisher` auf einer pro-Take rollenden `coherenceRRHistory` (64, am selben Beat-Cursor wie die Atmung, in `stop()` geleert). Wächter: `Tests/CISmoke/TheCameraCoherenceAccumulatesTests.swift`. **Gerät-Verify offen** (Marker an der Kapazität).

⛔ **„HRV → brightness · **reverb mix**" ist am 2026-08-12 GESTRICHEN (#546).** Der Erzeuger schreibt sauber, der VERBRAUCHER ist zur Laufzeit aus (`useConvolutionReverb` = `false` ohne jede Zuweisung in `Sources/`), also kann die Stufe keinen Klang erzeugen. ⭐ **GESETZ, und es ist die Umkehrung von #496: eine Abbildung ist live, wenn der Schreibvorgang einen UNGATED Lesevorgang erreicht** — dort fehlte der ERZEUGER, hier ist der LESER abgeschaltet; dem Wert einen Sprung weit zu folgen sieht nach Sorgfalt aus und hört einen Sprung zu früh auf. Der billige Test ist ein `grep` auf die LESER des Ziels, nicht nur auf seine Schreiber. ⚠️ **Nicht mit dem Reverb der FX-Fläche verwechseln:** `EchoelReverb` in `EchoelFXChain` ist algorithmisch, von Genre-Presets eingeschaltet, und eine Bio-ROUTE darauf ist über die Modulationsmatrix erreichbar — der Hinweis „coherence → reverb" in `EchoelFXView` ist WAHR und darf aus diesem Absatz heraus nicht „korrigiert" werden. Tot ist allein die Convolution-Stufe in `EchoelDDSP`. ⭐ **Im AUv3 seit WA3.3 hörbar:** Adresse 6 ist der Anker, `EchoelReverb` der Verbraucher (`EchoelBodyVibeDevice.renderSpace`); das App-Ziel bleibt unverändert. Wächter: `Tests/CISmoke/DisabledReverbIsNotClaimedLiveTests` (#335). Herleitung samt den zwei Zeilennummern: `memory/LEDGER_COUNTS.md` §AE.

⛔ **Diese Tabelle war einen Zyklus lang EINS-ZU-EINS, während die Engine es nicht ist** (#498): ein Ziel je Kanal, während Kohärenz allein VIER bewegt. **Lehre, verschieden von der Stale-Zahl-Lehre: eine Aufzählung wird gegen den CODE geprüft, nicht gegen ihre eigene Symmetrie** — #496 korrigierte die ÜBER-Behauptung derselben Zeile und ließ die UNTER-Behauptung stehen, weil nur eine sich als Zahl zählen ließ. Herleitung: `memory/LEDGER_COUNTS.md` §J (#867), wo sie mit dem zweiten Beleg #864 steht.

⚠️ **EINE BEDINGTE ABBILDUNG STEHT ABSICHTLICH NICHT IN DER ZEILE, weil ihre Nennung MEHR irreführen würde:** auf dem `.harmonicSeries`-Map-Profil übernimmt HRV die Harmonizität ganz (`0.40 + hrv * 0.50`) und überschreibt den Kohärenz-Term darüber. Sie zu nennen suggerierte, ein Spieler könne sehen, welches Profil aktiv ist — kann er nicht, es ist eine Patch-Eigenschaft. Was oben steht, gilt unter JEDEM Profil. Der Typ, der diese vier Kanäle für die Oberfläche beschreibt, ist `Studio/AlwaysOnBioChannel.swift`, und sein Dateikopf trägt dieselbe Messung samt Ausnahme.

⛔ **DREI STANDEN HIER ALS GLEICHRANGIG UND HATTEN KEINEN PRODUZENTEN** (#496, gemessen 2026-08-08): **Breath depth → Noise · LF/HF → Spectral tilt · Coherence trend → Shape morphing.** ⭐ **EINER DAVON HAT SEIT #813 EINEN — der Trend.** `Core/CoherenceTrend` leitet aus der Kohärenz-HISTORIE eine vorzeichenbehaftete Änderungsrate ab (−1 fallend … +1 steigend); beide `…BioParams(`-Stellen schreiben `coherenceTrend: trend` statt der Literal-0. ⚠️ **Gespeist wird er aus dem ROHEN `frame.coherence`, nie aus `coherenceForSound`**: eine Neutral-Ersetzung ist für einen PEGEL richtig und für eine ABLEITUNG falsch, weil die Ersetzung selbst als Bewegung gelesen würde. **EINE HISTORIE PRO QUELLE** (#920c), plus Schutzstellen für ungemessen, nicht-endlich, langes Loch und dt ≤ 0 — hier steht bewusst keine Zahl (#818). ⚠️ **Die anderen ZWEI bleiben tot**: `git grep -n "PolyBioParams(\|BioParams(" -- Sources` findet weiterhin genau zwei Konstruktionsstellen, und beide schreiben `breathDepth: 0.5` und `lfHf: 0.5`. Konsequenz je Zeile, am Verbraucher nachgelesen: `breathFactor` ist auf jedem Frame exakt 1,0 (die Zeile reduziert sich auf ein Zurückschreiben des Patch-Werts, der eigentliche #279-Fix); `lfHfRatio` wird im Rumpf gar nicht gelesen (der Sanitizer sagt das selbst). ⚠️ **Die Skala des Trends ist eine SCHÄTZUNG** (`fullScaleRisePerSecond = 0.05/s`, benannt statt eingestreut) und das Einzige hier, was kein Test entscheiden kann — NEEDS-FOUNDER-VERIFY: Sitzung fahren, Kohärenz steigen und fallen lassen, sagen ob die Klangfarbenverschiebung hörbar-aber-nicht-störend ist. ⛔ **Die volle Kette #496 → #755 → #813 — die drei Kopie-Wächter, die Swift lasen und die Website nicht, und die eingetroffene Vorhersage — liegt in `memory/LEDGER_COUNTS.md` §AF** (Messung der über-behaupteten Fassung: §L).

⭐ **GESETZ aus dieser Kette: ein ⛔-Vermerk am VERBRAUCHER erreicht die Zeile nicht, die eine Sitzung ZUERST liest.** Zwei der drei standen am Verbraucher längst richtig, `coherenceTrend` als einziges nicht — und genau deshalb hat diese Tabelle es überlebt. Sie ist die Stelle, aus der Store-Text, Website und Panel-Kopie ihre Bio-Behauptungen holen. **Die verbliebenen ZWEI nicht als „live" zitieren, in keiner nutzersichtbaren Kopie** — ihr Code bleibt bewusst stehen. Wächter: `Tests/CISmoke/TheAlwaysOnBioPathIsNamedTests.swift` nagelt die Pins an BEIDEN Konstruktionsstellen fest und verbietet der Panel-Kopie, die drei zu nennen; die WEBSITE deckt `WebsitePagesAreFindableAndHonestTests.testTheProducerlessBioChannelsAreNotSoldAsMappings` ab — ⚠️ verboten ist die MAPPING-Behauptung, nicht das Wort (die FAQ nennt LF/HF-ANALYSE, und die ist echt). Herleitung: `memory/LEDGER_COUNTS.md` §AF.

---

## PERFORMANCE — Hard Limits

| Metric | Target | FAIL |
|---|---|---|
| Audio Latency | <10ms | >15ms |
| CPU | <30% | >50% |
| Memory | <200MB | >300MB |
| Visual FPS | 60 fps, GEPINNT (`MetalBioView` `preferredFramesPerSecond = 60`, nie zur Laufzeit geändert) | Frame-Drops/Ruckler; Thermik über die Detail-Stufe, nie über die Rate |
| Bio-Anwendung | ~1 Hz (dedupliziert auf `frame.timestamp`; der 10-Hz-Poll ist die Decke) | ein schnellerer Poll — das ist der #315/#332-Fehler |

⛔ „Visual FPS 120fps / Bio Loop 120Hz" standen hier und bewerteten das ausgelieferte Design als FAIL — 120 Hz bräuchte zusätzlich `CADisableMinimumFrameDurationOnPhone` (founder-gated, 0 Treffer), und die ~1 Hz ist das Bus-Gesetz von oben (Audit 2026-09-10 `studio-ui-2`).

**Audio thread: NO locks, NO malloc, NO ObjC messaging, NO file I/O, NO GCD.**

---

## TEMPO INVARIANT — T1·T2·T3 (ratified 2026-08-13, founder handover)

⭐ **FLOW FOLGT DEM PULS, LOOP STELLT MAN SELBST EIN — zwei Modi, nichts dazwischen** (Founder
2026-09-11: „entweder direkt an die Herzrate gekoppelt oder man stellt sie selbst ein").
`BioComposer.tempo(for:)` gibt unter `.flowFree` `min(max(hr, 40), 160)`, sonst den
Resonanz-Default. ⛔ **Der Kohärenz-Blend `hr·(1−Kohärenz) + 72·Kohärenz` ist mit #1271
GESTRICHEN**, und das war das „Hakeln": Kohärenz ist eine driftende Messung, also driftete das
ZIEL — und das Ziel erreicht die Uhr nicht direkt, sondern über die Oktav-Faltung ins
Genre-Fenster, die eine kleine Eingangs- in eine große Ausgangsänderung verstärkt, sobald sie
eine Grenze kreuzt. **Das Verbot „dein Herzschlag IST der Beat" bleibt erfüllt** — vier Stufen
sitzen weiter dazwischen: `bodyTempoTrustworthy`, die Faltung, die ±`tempoConvergeStep`-Kappe
je Evolve und `glideTempo`s ~2 s. Kohärenz formt weiter Dichte, Harmonie und Klangfarbe.

- **T1 — Tempo-Quellen sind aufzählbar und werden geloggt.** Das Tempo darf nur von (a) einer
  Nutzer-Geste (Lock, Feld-Edit, Tap, geladenes Projekt), (b) dem Flow-Servo, (c) einer
  Automations-Lane gesetzt werden. Die Transport-Play-Zeile trägt `tempoSource=`.
  ⚠️ **Die Aufzählung ist VIER, nicht drei** — der Beschluss sah einen Pfad nicht: die
  Modulations-Matrix-Destination `ModDestinationKey.tempo` in `EchoelmusicApp` ist eine
  vom Nutzer konfigurierte ROUTE, die einen Bio-Wert trägt; weder Servo (anderer Mechanismus,
  andere Klammer) noch gespeicherte Kurve. Sie heißt `.modulationRoute` und ist heute schlafend
  (leere Default-Matrix, null `ModRoute(`-Konstruktionsstellen, #541). Sie in eine der drei zu
  falten hieße, ein falsches Wort in genau die Log-Zeile zu schreiben, für die T1 existiert.
  ⭐ FÜNF seit #1255: `.remoteControl` — der OSC-Steuereingang, NUR unter `.studioLocked`.
- **T2 — Rohe Herzfrequenz erreicht die Uhr nie direkt.** Kein Pfad darf eine BPM-Schätzung
  (rPPG, BLE, HealthKit) ohne die vier Stufen oben oder ohne ausdrückliche
  Nutzer-Geste an den Takt geben. `.studioLocked` ist beweisbar unabhängig von `heartRateBPM`.
  ⚠️ **Die Zahlen stehen im CODE, nicht hier.** Der Beschluss nennt „Klammer 40–160" und das
  ist weiterhin exakt richtig (`min(max(hr, 40), 160)`, #1271) — sie hier
  ein drittes Mal auszuschreiben wäre die #416-Falle in dem Dokument, das Tempo-Mehrdeutigkeit
  gerade beendet. Wer die Klammer prüft, liest `BioComposer.tempo(for:)`.
- **T3 — CI-erzwungen, nicht dokument-erzwungen.** `Tests/CISmoke/TempoInvariantTests.swift`
  IST das Invariant. Prosa, die einem grünen Test widerspricht, ist veraltete Prosa.

⭐ **Der Engpass ist `PatternEngine`, und das ist der Grund, warum `Transport.setTempo` KEIN
`source:` bekommen hat.** Gemessen 2026-08-13: jedes `transport?.setTempo(…)` in `Sources/`
steht in `PatternEngine.swift` (sechs Stellen, davon drei auf dem TICK-Pfad eines laufenden
Glides). `Transport.setTempo` hat keinen eigenen Produktions-Aufrufer. Die Quelle an den zwei
`PatternEngine`-Methoden zu benennen benennt sie also für die ganze App, während das Relais ein
Relais bleibt — ein `source:` dort müsste auf dem Audio-Rate-Pfad etwas wiederholen, das er
nicht wissen kann, und ein Breadcrumb dort loggte mit 20 Hz. `source:` hat an beiden Methoden
**keinen Default** (#431/#440/#443: ein defaultetes Argument, das keine Aufrufstelle schreibt,
taucht in keinem Diff auf). Claim 4 des Wächters nagelt den Engpass fest, Claim 5 den fehlenden
Default.

---

## PLATFORM CONSTRAINTS

- Apple Watch HR: ~4-5 sec latency — NO beat-sync!
- RMSSD: Self-calculate (Apple only gives SDNN)
- Bluetooth Audio: 150-250ms latency
- Flash animations: Max 3 Hz (epilepsy W3C WCAG)

---

## SAFETY WARNINGS (must be in app)

- Brainwave Entrainment: NOT while operating vehicles
- NOT under influence of alcohol/drugs
- Therapeutic use: coordinate medications with provider
- Max 3 Hz visual flash rate
- Data for self-observation, NOT medical diagnosis

---

## RALPH WIGGUM LAMBDA PROTOCOL

```
1. git status && git log --oneline -10
2. swift build 2>&1 | tail -20
3. Identify ONE broken/unclear thing
4. Fix it (minimal change, max 3 files)
5. swift test --filter [relevant]
6. Commit: fix: [description]
7. Deploy to TestFlight
8. Evaluate on device
9. GOTO 1
```

ONE issue per cycle. No batching. Build fails = ONLY priority.

⚠️ **Web sessions have NO Swift toolchain** (`command -v swift` → nothing): steps 2 and 5 are `git push` + reading the two gates (`Tests/CISmoke/CLAUDE.md` §5); a guard you cannot run is graded by transcription (§0 there). The `swift` lines above are for the founder's Mac.
No features during fix cycles. Convergence only.

---

## "CLEAR SOFTWARE" CHECKLIST

1. Every screen does something (no placeholders)
2. Navigation works (tabs respond, back goes back)
3. Bio-feedback visible (HR, HRV, coherence front and center)
4. Audio works (tap synth = hear sound)
5. Buttons respond, states change, loading indicators work
6. No crashes (force unwraps banned, optionals handled)
7. Permission denials handled gracefully
8. Background/foreground transitions stable

---

## SESSION START

```bash
git status
git log --oneline -20
swift build 2>&1 | tail -30
cat .ai/*.md 2>/dev/null
swift test 2>&1 | tail -20
```

Priority: Build errors → Test failures → Crash code → Task → Cleanup

⚠️ No local `swift` in a web session: skip the two `swift` lines and read the last runs instead (`mcp__github__actions_list` → `python3 scripts/gh-run-status.py <overflow-file>`).

---

## CODE STYLE

- **SwiftUI + MVVM** | `@Observable` (iOS 17+) | async/await + `@MainActor`
- **Swift 6** strict concurrency | SwiftLint enforced
- `os_log` ONLY (never `print`) | Guard-let over if-let
- Conventional commits | One change per commit
- Swift-first; **no PAID frameworks (no JUCE), no CMake**. The original "no C++"
  rule was really "no JUCE licence fees" — C++ is permitted ONLY for a **free,
  well-contained, Council-approved** library kept out of the Swift audio core
  (e.g. Ableton Link / LinkKit, which is free). Default stays Swift; deps stay
  minimal (ZERO external deps shipped today; HaishinKit = the planned RTMP dep, not linked).
- `///` for public API docs

---

## CRITICAL BUILD ERROR PATTERNS

### Swift Compiler Errors

| Pattern | Fix |
|---------|-----|
| UIKit refs on non-iOS | `#if canImport(UIKit)` |
| @MainActor in Sendable closure | `Task { @MainActor in }` |
| deinit calls @MainActor method | Nonisolated cleanup directly |
| `public let foo: InternalType` | Hard error — match access levels |
| `Color.magenta` | Doesn't exist. Use `Color(red:1,green:0,blue:1)` |
| WeatherKit | `@available(iOS 16.0, *)` AND `#if canImport(WeatherKit)` |
| vDSP overlapping accesses | Copy inputs to temp vars before `vDSP_DFT_Execute` |
| `self` before `super.init()` | Move setup AFTER `super.init()` |
| `inout` + escaping closure | Copy to local var first |
| `@MainActor` property read from a `nonisolated` audio-render block ("main actor-isolated property X can not be referenced from a nonisolated context") | Keep the public `@MainActor` prop for the UI, add an `@ObservationIgnored nonisolated(unsafe)` mirror written in its `didSet`; the render reads the mirror (see SubBassVoice.audioSubGain / PolySynthVoice params) |
| `@Observable` class: a manual stored prop named `_foo` ("invalid redeclaration of '_foo'" / "ambiguous use of '_foo'") | The macro generates `_foo` as `foo`'s backing — never name your own field `_<name>`; use a non-underscore name (e.g. `audioFoo`) |
| `static let` on a `@MainActor` class read from `Task.detached` — "main actor-isolated static property X cannot be accessed from outside of the actor" | Xcode's toolchain isolates it even when immutable (SwiftPM CI may accept the same code — toolchains disagree on SE-0434 inference). Mark it `nonisolated static let` explicitly |
| `static let` holding key paths or closures — "static property X is not concurrency-safe because non-'Sendable' type … may have shared mutable state" | A `KeyPath` is NOT `Sendable` in Swift 6 even when Root and Value are, so a STORED global of them is a hard error (#1402, `MoodProfile.variationSpread`). Make it a COMPUTED `static var` — no storage, nothing to share. Do not paper over it with `nonisolated(unsafe)` |
| `Self.` in a STORED property initializer — "covariant 'Self' type cannot be referenced from a stored property initializer" | Illegal even on a `final class` (#1444, `LightingStore.lookIntensity = Self.defaultLookIntensity`). Write the TYPE NAME. ⚠️ `Self.` in a METHOD body or a computed property is fine, so the legal and the illegal spelling sit a few lines apart in the same file and only one of them is a build error — a §0 transcription cannot see this, only a gate can |

### Logger Usage (Global `log` is EchoelLogger instance)

```swift
// CORRECT:
log.log(.info, category: .audio, "message")

// WRONG - tries to call logger as function:
log(.info, ...)

// WRONG - instance method, not static:
ProfessionalLogger.log()

// Math log() is shadowed — use:
Foundation.log(value)
```

### API Gotchas

> **DELETED 2026-07-25 — every type this section named is GONE.** It listed
> `SpatialAudioEngine`, `UnifiedHealthKitEngine` and `NormalizedCoherence` with
> their "correct API". A grep of `Sources/` and `Tests/` returns **zero** matches
> for all three (`NormalizedCoherence` survives only as the name of a test METHOD,
> `CoreSystemTests.swift:61` — not a type). A session reading this would write code
> against APIs that do not exist and only find out at the CI gate.
> The same applied to the old **Type Conflict Resolution** section: `ProSessionEngine`,
> `ProStreamEngine`, `ProCueSystem`, `ProColorGrading`, `ChannelStrip`,
> `ArticulationType`, `SubsystemID` — all zero files. And to
> `CXProviderConfiguration` (CallKit is not used here).
> Do not restore any of it from an older revision; it documents a codebase that no
> longer exists.

Language-level notes that ARE still true and worth keeping:

- `Swift.max`/`Swift.min` must be qualified when a struct in scope has a static
  `.max` property.
- **Argument order in `max`/`min` decides NaN behaviour.** `max(x, y)` is
  `y >= x ? y : x`, so `max(0, NaN)` returns `0` (NaN-safe) while `max(NaN, 0)`
  returns `NaN`. `min(max(v, lo), hi)` therefore passes NaN straight through — use
  the NaN-safe `clamped(to:)` (`Core/FloatingPointClamp.swift`) for anything that
  reaches the audio thread. This has caused shipped permanent-silence bugs.
- `@escaping` required for `TaskGroup.addTask` closures.
- Result builder: `buildBlock(_ components: [T]...)` when using `buildExpression`.

---

## KEY TESTS (Anzahl: der `git ls-files`-Befehl in REPO STRUCTURE — hier steht bewusst keine Zahl)

Run `swift test` (or rely on the CI gates) before ANY commit. Highest-value areas:
DSP (`EchoelDDSPTests` · `DSPTests` · `VDSPTests`) · protected triad
(`BioEventGraphTests` · `BioSignalDeconvolverTests`) · sequencer/tempo
(`PatternEngineTransportRelayTests` · `TempoStabilityTests` · `SequencerTests`) ·
MIDI export (`MIDIFileImporterTests`) · rPPG trust (`CameraRPPGTrustTests`) ·
FX (`EchoelFXChainTests` · `GenreFXTests`). (The old "15 files, 1,060+ methods"
list named 11 files that never existed — do not reintroduce it.)

---

## CI/CD

### Active Workflows (.github/workflows/)

| Workflow | Purpose |
|----------|---------|
| `testflight.yml` | **PRIMARY** — TestFlight builds (ID: 225043686) |
| `ci.yml` | Main CI (SwiftPM build, test, lint) |
| `xcode-compile-check.yml` | XcodeGen + `xcodebuild` compile gate (catches Xcode/AUv3-only errors) |
| `quick-test.yml` | Fast test suite |
| `pr-check.yml` | PR validation |
| `auto-merge-claude.yml` | **Entscheidet, was `main` erreicht** — siehe den Absatz direkt unter dieser Tabelle |

⭐ **DER MERGE NACH `main` WARTET SEIT #1405 AUF ZWEI GATES** (Founder 2026-09-21: „auto-merge-claude.yml du hast das alles unter Kontrolle und machste das klar"). Vier Monate lang tat er es nicht, und diese Tabelle nannte den entscheidenden Workflow gar nicht erst (#683) — genau die Register-Lücke, die diese Datei an anderer Stelle „teurer als eine falsche Zahl" nennt, weil sie nie als Frage auftaucht.

**Was das Gate liest, und warum es ein POLL ist statt eines `needs:` — die Unterscheidung entscheidet jede künftige Änderung daran.** `Xcode Compile Check` wird über seine **Conclusion** gelesen (er baut `Sources/` allein, und seine Conclusion ist ehrlich). Die CI/CD-Pipeline wird über **einen SCHRITT** gelesen, `Build for Testing` — ihre eigene Conclusion ist wegen #396 auf JEDEM Push `failure`, trägt also null Information, und ein `needs:` darauf blockierte jeden Merge für immer. Eine Schritt-Conclusion ist aus `needs:` nicht erreichbar; sie muss abgefragt werden. **Abwesenheit ist Ablehnung, nie Zustimmung:** `never-ran` und `timeout` merged nicht.

⚠️ **Die EINE Ausnahme, und sie ist eng:** berührt der Merge weder `Sources/` noch `Tests/` noch `Package.swift` noch `project.yml`, läuft KEIN Gate — beide Gate-Workflows haben genau diese Pfadfilter plus ihre eigene Datei. Dann gibt es nichts zu prüfen und der Merge geht durch. Ohne diese Ausnahme wartete ausgerechnet ein Commit, der CI repariert, auf ein Gate, das nie startet.

⚠️ **Das VERHÄLTNIS des alten Befunds bleibt lesenswert, weil es sagt, was ein Rückbau kostet:** der TestFlight-Dispatch im selben Workflow steht auf `if: false`, ein ungetesteter Merge erreichte also `main`, aber nie einen Nutzer. ⛔ Dieser Dämpfer war trotzdem zu großzügig (#1337): ein nicht bauendes Test-Bündel auf `main` heißt, dass für jeden, der in dem Fenster zieht, KEIN Wächter des Repos läuft — die Schwere hing nie allein an `if: false`.

Wächter: `Tests/CISmoke/TheAutoMergeWaitsForTheGatesTests.swift`. ⛔ Die Provenienz — die vier Monate ohne Gate, die zwei gemessenen Fenster (`f61be63` zehn Minuten, `edc37a4a5` neun) und die zurückgenommene Fassung dieses Absatzes — liegt in `memory/LEDGER_COUNTS.md` §AG.

⛔ **UND DER ZWILLING DAZU (#697/#698/#699): ein Commit, der NUR `CLAUDE.md`, `memory/**` oder `scratchpads/**` anfasst, löst KEINEN eigenen Merge aus.** Die Filter stehen NICHT hier — sie sind schon in `ContentPipeline/README.md` unter #252 aufgezählt, zusammen mit `README.md`, `fastlane/**` und `.deploy/release`, die dasselbe Loch haben; eine dritte Abschrift wäre #416. ⭐ **Was #697 dort NICHT gelesen hat und was diesen Absatz kostet:** es schrieb „erreicht `main` NIE durch Automatik" — und `ContentPipeline/CLAIMS.md` sagte im selben Baum das Gegenteil („ein Commit, der beide anfasst, zieht diese Datei mit nach `main`"). Der Merge nimmt `${{ github.sha }}`, also die GANZE Vorgeschichte: ein Gesetzes-Commit fährt als **PASSAGIER** mit (gemessen: `c86a351` auf #695, `4ef259b` auf #697, `main` liest seither 369). **Die Über-Behauptung war aus dem Repo widerlegbar, eine Stunde bevor ich den Workflow las** — und die Momentaufnahme von `main`, die ich als Beleg zitierte, sieht bei „nie" und „noch nicht" identisch aus. ⚠️ Der Befund überlebt schwächer und echt: die Drift hält **bis zum nächsten Code-Commit** (unbegrenzt lang) und wird **dauerhaft**, wenn ein Zweig darauf ENDET — der Normalfall am Ende eines 24-h-Mandats; Signal gibt es keins. ⚠️ Und sie ist nicht folgenlos für `docs/`: `auto-merge-docs.yml` diffed `origin/main..<sha>`, ein einzelner Nicht-docs-Commit in der Delta setzt `docs_only=false`, der Cherry-Pick wird übersprungen und der Job endet trotzdem grün (`HARNESS_LEDGER`). Ein wartender Gesetzes-Commit **blockiert also den Docs-Merge**. Wächter: `Tests/CISmoke/TheLawFileNeverReachesMainByItselfTests.swift` (#364: verbietet nichts, wird rot, wenn ein Filter sich öffnet).

**⚠️ WELCHES GATE WAS BEWEIST — die Unterscheidung, die jede Session sonst neu falsch rät.** Kurzfassung, die immer gilt: **`Xcode Compile Check` kompiliert `Sources/` ALLEIN** (Scheme `Echoelmusic` unter `build.targets`; ein grünes Häkchen sagt über eine TESTDATEI nichts) · **`Echoelmusic CI/CD Pipeline` meldet wegen #396 auf JEDEM Push `failure`**, also sagt die Conclusion nichts — man liest die JOB-SCHRITTE. ⛔ **Die ausführliche Fassung stand hier und ist mit #763 nach `Tests/CISmoke/CLAUDE.md` §5/§5b gezogen — 10.019 B, und sie war die DRITTE Kopie einer Entscheidung, deren eine Heimat `.claude/rules/context.md` §3 schon benannt hatte („is not repeated here (#416)").** Schlimmer als redundant: sie war die ÄLTESTE der drei (vor #667/#679/#738/#739), und die immer-geladene gewinnt per Default — eine Sitzung folgte hier einem Rezept, das §5 längst korrigiert hatte. **Wer ein rotes Gate liest, öffnet §5.** Dort steht auch, was NUR dort steht: der Beleg für die Compile-Check-Reichweite, die #210-Nebenwirkung, der #478-Cache-Schlüssel, die Clone-2-Rücknahme.

- **`Echoel Full Test Suite (non-blocking)` beweist gar nichts** — es meldete am 2026-07-31 `success` auf `bc35248`, während beide echten Gates an 12 Compile-Fehlern scheiterten. Ursache und Reparatur: #208 (founder-gated, `.github/workflows/**` ist berichten-nicht-editieren).

> **No JUCE / no CMake / no C++.** Swift 100%, ZERO external dependencies today (`Package.swift` `dependencies: []`; HaishinKit = planned, compile-guarded only).
> The old CMake/JUCE/iPlug2 desktop scaffolding (`CMakeLists.txt`, `setup*.sh`,
> `build.yml`, `desktop_build.yml`, desktop build scripts) was removed 2026-06-19.
> Legacy/contradictory workflows also removed 2026-06-19: `android-build.yml`,
> `phase8000-ci.yml`, `swift.yml`, `release-all-platforms.yml` (Android is disabled;
> these were redundant with `ci.yml`/`testflight.yml`).

Android build is disabled. TestFlight needs 60min timeout (30min+ compile).

### GitHub API Access

Token stored in `.claude/settings.local.json` (gitignored, NEVER committed).

**Read token:**
```bash
GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('.claude/settings.local.json'))['github']['token'])" 2>/dev/null)
```

**Available commands:**
- `/testflight-deploy` — Full pre-flight + deploy to TestFlight
- `/github` — GitHub API operations (PRs, issues, workflow status)

**If token missing:** Ask user to create `.claude/settings.local.json`:
```json
{
  "github": {
    "token_name": "claude-code",
    "token": "ghp_...",
    "owner": "vibrationalforce",
    "repo": "Echoelmusic"
  }
}
```

---

## OSC (EchoelSync)

Actual address set (source of truth: `Sync/OSCSender.swift` — corrected 2026-07-04;
the old list named eeg/{band}, audio/rms, audio/pitch which are NEVER sent):

```
/echoelmusic/bio/heart/bpm       float
/echoelmusic/bio/heart/hrv       float [0-1] (normalized)
/echoelmusic/bio/heart/rmssd     float ms   OPT-IN, default OFF (#1292); sentinel gate
/echoelmusic/bio/heart/sdnn      float ms   unchanged (>0 AND a pulse). Door: Routing →
/echoelmusic/bio/heart/pnn50     float      "Send clinical HRV detail". The split and
                                 why: `BioEgressPolicy.FieldClass` (.derived/.clinical/.raw;
                                 `.raw` cannot be permitted, the frame is scalar-only).
/echoelmusic/bio/breath/rate     float
/echoelmusic/bio/breath/phase    float [0-1]
/echoelmusic/bio/coherence       float [0-1]
/echoelmusic/bio/synthetic       float 0|1  — 1 = Demo-Generator, 0 = echter Körper (#639).
                                 PREPENDED und auf den BATCH gegated: begleitet jeden Frame,
                                 der mindestens einen gemessenen Wert sendet, und fehlt in
                                 einem stummen Frame ganz — #245 bleibt unangetastet. 0 ist
                                 hier eine TATSACHE, kein fehlender Messwert. EIGENE Adresse,
                                 KEIN zusätzliches Argument: ein zweiter Float auf
                                 `/heart/bpm` bräche jeden Integrator auf dem alten Vertrag.
                                 Über UDP nicht reihenfolge-garantiert → als ZUSTAND latchen.
                                 ⛔ ADM-OSC und Art-Net tragen weiterhin KEINE Herkunft —
                                 **sACN seit #789 SCHON**, und die Gründe der drei sind
                                 VERSCHIEDEN (sACN hatte das Feld, Art-Net braucht ein
                                 ungeprüftes Discovery-Paket, ADM-OSC ist fremder Adressraum).
                                 ⭐ **DIE LEHRE IST ÜBER REGISTER, nicht über DMX:** der Eintrag
                                 nannte, was Art-Net und sACN GEMEINSAM haben („tragen DMX"),
                                 und verbarg damit den Unterschied, der die Frage entscheidet —
                                 sACN ist DMX ÜBER E1.31, und der TRÄGER hat einen Kopf, den die
                                 NUTZLAST nicht hat. Begründung je Standard und die
                                 `NWListener`-Zählung: `memory/LEDGER_COUNTS.md` §U.
                                 ⭐ **Die Event-Adressen unten tragen sie SEIT #785 auch** —
                                 anderer Codepfad (`drainAndSendEvents` → `eventMessages`) und
                                 bewusst andere Kadenz: die Flagge steht unmittelbar VOR dem
                                 Ereignis, das sie beschreibt, und wird nur bei WECHSEL erneut
                                 gesendet (über Drains gelatcht). Grund: Ereignisse kommen in
                                 Bündeln (Per-RR-Schläge, Atem-Onsets paarweise) — pro Ereignis
                                 zu wiederholen vervielfacht den Verkehr auf genau dem Pfad, der
                                 latenzgeformt ist, ohne Information. Wer mitten in der Session
                                 dazukommt, lernt den Zustand aus dem ~1-Hz-Batch. Die Arität
                                 der Event-Adressen bleibt `[confidence, aux]`.
/echoelmusic/bio/motion          float      — NOT SENT in this build (#215): nothing
                                              measures motion, so a constant 0 would be
                                              indistinguishable from a still performer.
                                              Gated on `ModSource.motion.hasProducer`
/echoelmusic/mod/<key>           float      (modulation-matrix outs, e.g. seq.tempo)
/echoelmusic/bio/event/breath/inhale | breath/exhale   (ADRESSEN MIT PRODUZENT, jede Quelle
                                   mit Atem-Wellenform; `BioEventGraph` aus `breathPhase`)
/echoelmusic/bio/event/heartbeat — PRODUZENT NUR DER BLE-GURT (`PolarH10BioPublisher`, per RR).
                                   ⛔ „coherence" stand mit in der MIT-PRODUZENT-Zeile und ist
                                   mit #1377 gestrichen; der heartbeat stand dort OHNE diese
                                   Bedingung. Der `BioEventGraph`-Pfad kann ihn nie feuern:
                                   `BioEventPublisher` ruft `graph.process(cleanedHeart: 0, …)`
                                   — die Rohwelle liegt nicht auf dem Bus. Auf der FLAGGSCHIFF-
                                   Quelle (Kamera-rPPG) kommt diese Adresse also nie
/echoelmusic/bio/event/coherence — Adresse existiert, wird nie gesendet. `.coherenceShift` hat
                                   in `Sources/` DREI Vorkommen (Enum-Fall, die Zuordnung in
                                   OSCSender, ein Verbraucher-`switch`) und NULL Konstruktionen —
                                   identisch zu `.eegBurst` darunter. Messen, nicht zitieren:
                                   `git grep -n "coherenceShift" -- Sources`
/echoelmusic/bio/event/motion    — Adresse existiert, wird nie gesendet (dieselbe #215-Begründung
                                   wie vier Zeilen höher; nichts misst Bewegung)
/echoelmusic/bio/event/eeg       — Adresse existiert, wird nie gesendet. `.eegBurst` hat NULL
                                   Produzenten in `Sources/`; die Zuordnung in OSCSender ist
                                   Vorbereitung, kein Ausgang. Kein Integrator darf darauf warten.
/echoelmusic/ctrl/{bpm,key,scale,genre,visualStyle,blackout}  ← EINGANG (#1255, `OSCReceiver`,
                                   UDP 8001, Opt-in AUS, Sender-Allowlist; bpm nur bei Lock).
/echoelmusic/music/{tempo,key/root,beat/phase,level/master,note/count}  ← AUSGANG (#1383,
                                   Posten 5). Aus `MusicalFrame`, gleicher 100-ms-Tick.
                                   **`tempo` hat EINEN ZWEITEN Filter**: zurückgehalten,
                                   wenn die lebende Bio-Quelle egress-gesperrt ist — unter
                                   `.flowFree` folgt es dem Puls und `MusicalFrame` hat
                                   KEIN Herkunftsfeld. ⚠️ Die Fail-closed-Eigenschaft
                                   gehört EINEM Filter, nicht dem Sender — ein neuer Pfad
                                   erbt sie NICHT. Warum vier Felder fehlen und warum es
                                   eine Menge statt eines Präfixes ist: am Erbauer
                                   (`OSCSender.musicMessages`, `BioEgressPolicy`).
```

Plus ADM-OSC immersive object out via `ADMOSCSender`: `/adm/obj/{n}/*`.
UDP. Target: <5ms LAN.

---

## PLATFORM NOTES

- **Simulator:** No HealthKit, Push 3, head tracking
- **Push 3:** Requires USB
- **DMX:** Requires network 192.168.1.100
- **Linux:** `apt install libasound2-dev`

---

## DEVELOPMENT WORKFLOW

### Persistent Memory (memory/)

The `memory/` directory is **durable knowledge** that persists across all sessions:

| File | Purpose |
|------|---------|
| `decisions.md` | Architectural and strategic decisions with rationale and review dates |
| `people.md` | Key contributors, collaborators, contacts |
| `preferences.md` | User preferences for workflow, communication, tooling |
| `user.md` | User profile, project vision, working style |
| `LEDGER_COUNTS.md` | **Zähl-Ketten (Provenienz).** ~580 KB. **NICHT beim Sitzungsstart lesen** — nur öffnen, wenn eine Zahl nachzuführen ist (#538) |

**SESSION START (mandatory):**
1. Restore context from `memory/` — **but not by reading the directory whole.** The
   SessionStart hook already `cat`s the small files (`people` · `user` · `vision` ·
   `project_knowledge` · `preferences`) and prints SLICES of the two big ones
   (`decisions.md` tail-400, `inspiration_intake.md` head-60 + tail-120), each with the
   command that reads the rest. ⛔ **„Read ALL files in `memory/`" stand hier und war
   die Anweisung, die sich selbst widerlegt:** der Hook schneidet seit #533 zwei Dateien,
   weil sie zusammen 191 875 B kosteten — eine Prosa-Zeile, die „lies alles" sagt, hebt
   genau die Messung auf, für die der Schnitt existiert. Seit #538 liegt zusätzlich
   `LEDGER_COUNTS.md` dort, das allein ~580 KB wiegt; wer die Zeile wörtlich befolgt,
   verbrennt mehr Budget als das gesamte Gesetz dieser Datei ausmacht.
2. Read `scratchpads/SESSION_LOG.md` for recent session history
3. Read `memory/decisions.md` for any decisions due for review

**SESSION END (mandatory):**
1. Update `memory/` files with any new discoveries, decisions, or preferences learned during the session
2. Log new decisions to `memory/decisions.md` AND `decisions.csv` (see Decision Logging below)
3. Update `scratchpads/SESSION_LOG.md` with session summary

### Decision Logging (decisions.csv)

Machine-readable decision log at repo root. Format:
```
date,decision,reasoning,expected_outcome,review_date,status
```

- Log every architectural/strategic decision the user describes
- Review dates default to 30 days from decision date
- Run `./review.sh` to surface decisions due for review; `./review.sh --flag` schreibt `REVIEW_DUE` in die Datei zurück
- ⛔ **NICHTS FLAGGT AUTOMATISCH — hier stand ein täglicher Cron als Tatsache.** #510 hat genau diese Behauptung am 2026-08-08 in `.claude/routines/05-decision-review.md` zurückgenommen („unwired as automation") und **diese** Datei stehen lassen, die jede Sitzung ZUERST liest — die #456-Form: Prosa zieht in JEDEM Zuhause mit, nicht nur dort, wo man gerade schreibt, und 16 Tage lang gewann das immer-geladene Zuhause. Gemessen an der STATUS-SPALTE, weil ein Wort-Zähler hier von der Prosa über sich selbst widerlegt wird (⛔ `git log -S REVIEW_DUE` stand hier als „leer" und liefert seit #805/#815 zwei Treffer — beide Prosa, null geflaggte Zeilen; §W): `python3 -c "import csv;print(sum(1 for r in csv.reader(open('decisions.csv')) if len(r)==6 and r[5].strip()=='REVIEW_DUE'))"` → **0**. Und **kein einziger Workflow trägt überhaupt einen `schedule:`-Trigger**; `check-decisions.sh` ist eine crontab-Zeile, die ein Mensch installiert. Die Folge ist nicht kosmetisch: der Rückstand — Zahl mit `./review.sh | grep -c '^REVIEW DUE'` messen, nicht hier ablesen (#803) — sieht betreut aus und ist es nicht. Wächter: `TheDecisionLogIsMachineReadableTests`, Anspruch 7.

### Long-Term Memory (scratchpads/)

The `scratchpads/` directory is session-specific logs and plans:

| File | Purpose |
|------|---------|
| `SESSION_LOG.md` | **Read first — CAPPED**: newest entries are at the END; the hook prints `sed -n '1,80p'`; read `grep -n '^## ' scratchpads/SESSION_LOG.md \| tail -20` + `tail -200`, never the whole ~1.8 MB |
| `HARNESS_LEDGER.md` | **The idea-maze** — proven DEAD-ENDS (don't retry), reliable PLAYBOOKS, shipped leaderboard |
| `ARCHITECTURE_AUDIT_*.md` | Data flow diagrams, env object chains, init sequence |
| `PLAN_*.md` | Feature/fix plans before implementation |

**Start every session** by reading `memory/` first (the hook's slices), then the END of
`scratchpads/SESSION_LOG.md`, then the DEAD-ENDS table of `scratchpads/HARNESS_LEDGER.md`
(~300 KB — index it with `grep -n '^## ' scratchpads/HARNESS_LEDGER.md`, do not read it whole).

**Harness discipline (long-running-agent effectiveness).** Before trying any
non-trivial approach, scan `HARNESS_LEDGER.md` DEAD-ENDS — a past (context-compacted)
cycle may already have proven it wrong; take the "do this instead". After a cycle,
append ONE row for any real dead-end hit or reliable playbook found, so the loop
climbs instead of circling. Check CI gate status compactly with
`python3 scripts/gh-run-status.py <saved-tool-result.json>` (parses the overflowing
`mcp__github__actions_*` dump into `sha status conclusion run_id title`).

### 4-Phase Workflow

**Phase 1 — Plan:**
- Read `scratchpads/SESSION_LOG.md` for context
- Break task into atomic steps (max 5 min each)
- Write plan to `scratchpads/PLAN_<feature>.md`
- Include exact file paths, expected changes, test strategy

**Phase 2 — Implement (TDD):**
- Write failing test FIRST when adding new functionality
- Run `swift test` (founder Mac) or transcribe the guard in Python against both trees (web) — confirm RED
- Implement minimal code to pass
- Run `swift test` (Mac) / re-drive the transcription (web) — confirm GREEN
- Refactor while GREEN

**Phase 3 — Verify:**
- `swift build` must pass (`-warnings-as-errors`) — web session: push and read `Xcode Compile Check`
- `swift test` must pass — web session: CI/CD `Build for Testing` + `python3 scripts/gh-test-verdict.py`
- No force unwraps, no divide-by-zero, no missing environmentObjects
- Guard all divisions, guard all array access, guard all optionals

**Phase 4 — Ship:**
- Commit with conventional prefix: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`
- Update `scratchpads/SESSION_LOG.md` with session summary
- Push to feature branch

### Parallel Agent Strategy

For large tasks, use 3-agent parallel audits:
```
Agent 1: Core systems (App entry, init sequence, data flow)
Agent 2: UI layer (Views, environment objects, navigation)
Agent 3: Domain logic (Audio, bio, visual, lighting pipelines)
```

### Code Review Checklist

- [ ] No `@EnvironmentObject` without matching `.environmentObject()` injection
- [ ] No division without guard (`.count`, heartRate, etc.)
- [ ] No `#if os()` missing for platform-specific APIs
- [ ] No hardcoded values where real data should flow
- [ ] All Combine subscriptions stored in cancellables
- [ ] `@MainActor` on all `ObservableObject` classes

---

## UI DESIGN CONSTRAINTS (Uncodixfy)

When generating SwiftUI views, follow clean design principles. Avoid AI-default patterns.

**Reference aesthetic:** Linear, Raycast, Stripe, GitHub — functional, minimal, precise.

**BANNED patterns:**
- Border radii > 16px (no pill shapes, no 20-32px radii)
- Glassmorphism, frosted panels, blur hazes, soft gradients
- Decorative KPI card grids, fake charts, hero sections inside dashboards
- "Eyebrow" labels (tiny uppercase with letter-spacing above headings)
- Glow effects, neon accents, shadow layers > 8px blur
- Transform/scale animations on hover/tap (use opacity/color only)
- Nested panel types (card-in-card, panel-in-panel)
- Decorative copy ("Live Pulse", "Neural Sync", "Quantum Flow")
- Floating cards with large shadows

**REQUIRED patterns:**
- Solid fills or borders on buttons, 8-12px radius max
- Subtle borders (1px, muted color), max 8px shadow blur
- Sidebars: 240-260px fixed, solid background, 1px border
- Forms: labels above inputs, no floating labels, simple focus ring
- Tables: left-aligned text, subtle row hover, clean grid
- Color: use existing palette, dark muted backgrounds, avoid neon
- Transitions: 100-200ms, opacity/color only
- Bio-signal displays: legible numbers first, visualization second
- Flash rate: max 3 Hz (W3C WCAG epilepsy compliance)
- **Parameter rows — ONE control everywhere:** every adjustable numeric parameter (FX, synth
  patch, mix, bio, future modules) uses `EchoelValueField` (label + value + unit, adjusted by a
  vertical-fader drag / tap-to-type). **No raw SwiftUI `Slider`/`Stepper` for parameters.** Tap-to-type
  opens `EchoelNumberPad` — our OWN keypad (the iOS decimal pad can't carry a sign key), with − / +
  at the bottom-left where **− makes the value negative, + positive** (logical for Transpose); − is
  disabled where the range can't go below zero (10.76.44). One keypad app-wide — don't reintroduce the
  system `.decimalPad`/keyboard-toolbar sign buttons. This
  keeps reading + interaction identical app-wide and is science-first (number, not a knob). Dimensionless
  values show as raw decimals (e.g. `0.50`), not `%`. New parameter UI MUST use it; if it can't, raise it
  in The Council before diverging. **Scope:** die ganze App — **AUSSER der AUv3-Plugin-Oberfläche im Fremd-Host** (Ausnahme
  wieder in Kraft seit #1385, weil das Target zurück ist; sie gilt für NICHTS sonst). Grund in
  einem Satz: die Extension kompiliert absichtlich nur `DSP/` plus drei Foundation-only
  `Core/`-Dateien, und `EchoelValueField` zöge `EchoelTheme`/`EchoelPanel`/`EchoelNumberPad`
  nach — also genau die Isolation, die den AUv3 abhängigkeitsfrei macht. Messung, Zählung und
  der Port-Posten stehen auf `scratchpads/BAUSTELLEN_BOARD.md`; ⛔ die alte Fassung hier sagte
  „void — that target was removed 2026-07-24", eine Ausnahme mit abgelaufener Begründung.)
  **⚠️ READ THE WORD "NUMERIC" — the law is not "every parameter is a number field".** A parameter whose
  values have NAMES is a `Picker`, and always was: the filter mode and the delay mode rows are
  `.pickerStyle(.segmented)`, the bio-mod carrier/target/curve rows and the Sound panel's two timbre rows
  are `.pickerStyle(.menu)`. **Do not "restore" any of those to an `EchoelValueField` in the name of this
  rule.** The rule exists so numbers read and behave identically app-wide; turning a named choice back
  into a raw count would be obeying its letter against its purpose. ⛔ The sharpest EXAMPLE of that lived
  here and went with #1305: the two **harmonizer intervals** (`HarmonyInterval`, `EchoelFXView.intervalRow`),
  made named on 2026-07-29 because the founder asked for *"keine semitone Schritte sondern sinnvolle
  harmonische"*. The example is gone, the law is not — and it is stated ONCE more, in the tombstone where
  `intervalRow` stood, for whoever writes the next named row. The Council step above still applies to a
  genuinely NUMERIC parameter that wants to diverge.

**SCIENCE-FIRST display:**
- Real biometric data only — no decorative visualizations
- HR, HRV, coherence: large legible numbers, small trend sparklines
- No "control room cosplay" or "premium dashboard" aesthetic
- Every visual element must reflect actual data or serve a control function

---

## DO NOT

- Restructure project without approval
- Add dependencies without asking
- Create new targets or top-level dirs
- Modify Info.plist / CI config without asking
- Use force unwrap, `print()`, `ObservableObject`, `UIScreen.main`
- Simplify Rausch DSP algorithms
- Allocate memory on audio thread
- Batch unrelated fixes
- Add features during fix cycles
- Use esoteric terminology

---

## THE COUNCIL (always-on, optimized)

Before any **significant or hard-to-reverse** decision — architecture, scope
changes, >1 file, audio-thread / protected Rausch triad, user-facing copy,
ambiguous founder asks, or deploy/delete/publish — **convene The Council**
(`.claude/skills/the-council/SKILL.md`). Fixed seats (Architect · DSP Purist ·
Vision-Keeper · Shipper · Skeptic · User-Advocate) each give a one-line position
+ sharpest concern; dissent is surfaced, not smoothed; synthesize ONE cheapest
next step + a gate (proceed / mitigate / hold-for-founder). **Skip trivial
reversible actions** — convening on trivia is the failure mode. Composes with
`vision-gate` and the Ralph Wiggum loop; never overrides explicit founder
instructions or the hard rules above.

**Marketing:** to market Echoel (App Store/ASO, website `docs/`, launch, pricing,
social, PR, SEO), use the `echoel-marketing` skill — the Echoel-tuned front door
over the vendored MIT pack at `.claude/skills/marketing/` (Corey Haines, 45
skills). It enforces brand guardrails (no wellness/esoteric/overclaim, claim only
what ships) and is **PIPELINE only — never shipped in-app, never touches `Sources/`**.

**Short-form video content** (TikTok/Reels/Shorts, founder 2026-07-30) lives in
`ContentPipeline/` — same PIPELINE-only rule. **Read `ContentPipeline/CLAIMS.md`
BEFORE writing any script, caption or hashtag set**; it is the one list of what is
true today and what is struck, with the reason. It exists because #158/#192 spent two
whole cycles removing ONE false claim (AUv3) from the website and #184 removed twelve
from the App Store text, where a false claim is a 2.3 rejection. A model asked for
"bio-music app content" will reliably invent an AUv3 plugin and a meditation audience
— Echoel is neither. Note two structural facts recorded in `ContentPipeline/README.md`:
XcodeGen needs no exclusion (targets list explicit source paths, so a new top-level
directory is never scanned), and `ContentPipeline/**` is in NO auto-merge path filter,
so commits touching only it never reach `main` by automation (#252).

## ACTIVATION

```
ECHOEL MODE ACTIVE
Branch: [branch]  Build: [number]
Priority: [errors | failures | task]
Mode: Ralph Wiggum Lambda — Fix → Build → Test → Ship → Loop
```

No intro. Audit → Fix → Build → Loop.
