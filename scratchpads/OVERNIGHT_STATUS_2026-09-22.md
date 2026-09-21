# Echoelmusic Overnight Status — 2026-09-22

## Executive Summary

Nachtlauf nach dem Vertrag „OVERNIGHT AUTONOMOUS EXECUTION" (Founder 2026-09-21).
Eintritt mit bereits gebautem und gepushtem Phase-4d-Slice (#1440); der Lauf beginnt
also bei §20.2 (Gate-Lesung), nicht bei §20.1.

STATUS: LAUFEND — diese Zeile wird beim Beenden ersetzt.

## Starting HEAD

    1b351d0b3501c23dc18c9283e9f6eb8115dd0372   (claude/echoelmusic-review-optimize-u5jjpd)
    origin/main bei Eintritt: fa21213a96165e316a6b694f6b8b6f2f2c572f7e

## Ending HEAD

    (wird beim Beenden gesetzt)

## Completed Slices

### Slice 1 — PHASE 4d: canPlay fragt den echten Overlap-Gewinner (#1440)

- **Defekt / Ziel:** `canPlay` genehmigte eine ausfuehrbare Region, die von einer
  ueberlappenden Region vollstaendig BESCHATTET ist — der echte Scheduler
  (`TimelineScheduling.activeRegion`) waehlt an jedem Gitter-Tick die spaeter
  beginnende (bei gleichem Start die spaeter platzierte) Region. Der Vorbehalt
  pruefte jede Region EINZELN; der Spieler fragt keine Region einzeln.
- **Commit SHA:** `1b351d0b3501c23dc18c9283e9f6eb8115dd0372`
- **Dateien (6, +527/−38):**
  - `Sources/Echoelmusic/Sequencer/TimelineScheduling.swift` (neu: `candidateSampleTicks`)
  - `Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift` (`firstExecutableRegion` laeuft ueber den Scheduler)
  - `Tests/CISmoke/TheWorkstationPlaysTheTimelineTests.swift` (36 → 41 `func test`)
  - `CLAUDE.md` · `docs/dev/FEATURE_MATRIX.md` · `scratchpads/SESSION_LOG.md`
- **Guards:** Ansprueche 20–23 + Scan O. 20 = Beschattung (3× FALSE), 21 = der
  Scheduler-Gewinner spielt (3× TRUE), 22 = Spuren sind unabhaengig (2× TRUE),
  23 = Kandidaten-Menge SOUND und VOLLSTAENDIG gegen einen Voll-Gitter-Scan.
- **Verifikation (kein Swift lokal, §0-Transkription):** 21/21 Verhaltenszeilen
  korrekt auf der Reparatur, 5 falsch auf dem Elternteil; 200 000-Dokument-Orakel
  gegen Voll-Gitter-Sweep = 0 Abweichungen; Mutation 10/10 getoetet;
  Scans 50/50 gruen am Arbeitsbaum, 4 rot am Elternteil `84ee5670e`.
- **Compile Check run + conclusion:** run `35659456101`, job `106530962043`,
  Schritt 7 `Compile (iOS device SDK, no signing)` = **success** (21:50:39Z → 21:55:21Z).
- **Build for Testing run/job/step + conclusion:** run `35659456058`, job `106531162318`,
  Schritt 9 `Build for Testing` = **success** (21:52:08Z → 21:58:09Z). Das blockierende
  Buendel KOMPILIERT also mit den 41 `func test`. Schritt 11 `Run Tests` unterliegt
  unveraendert #396/#445/#807 und ist KEIN Verdikt.
- **Zehn Standard-Checker:** alle exit 0 (swift-escapes · dead-needles · count-pins --all ·
  moved-needles · foreign-needles · diag-ladder --source · founder-verify --selftest ·
  genre-prebatch --selftest · doctor --selftest · needle-reachability).
- **Device status:** OFFEN — Workstation Play/Stop am Geraet (#1437, Task 118).

### Slice 2 — PHASE 4 ABSCHLUSS-AUDIT (read-only, §3)

Versucht wurde, die ganze Kette zu FALSIFIZIEREN:
Workstation Play → `canPlay` → Scheduler-Auswahl → Clip/Source-Aufloesung →
MIDI/Audio-Executor → `PatternEngine` → `Transport` → Stop.

**Ergebnis: KEIN erreichbares Gegenbeispiel am aktuellen Baum.** Kein Code geaendert
(§3: nicht fuer hypothetische Perfektion editieren).

Was geprueft wurde, und womit:

| Angriff | Messung | Verdikt |
|---|---|---|
| ZWEITER `play(`-Aufrufer | `git grep -n "\.play(document:" -- Sources \| grep -v ': *//'` → **1** (`WorkstationView.swift:299`) | sauber |
| ZWEITE Uhr | `cause: .timelineRegion` → **1** Stelle, und sie JOINT (`if !pattern.isPlaying`) | sauber |
| VERALTETES UI-Praedikat | Der Knopf rechnet mit `player.preflightTempo`; `play()` fragt `canPlay` SELBST nochmal mit `pattern.tempo` (Zeile 554). Die Engine ist also autoritativ, der Knopf beratend. `preflightTempo` hat **genau EINEN** Schreiber (`EchoelmusicApp.swift:892`) | sauber |
| ARGUMENT-Mismatch UI vs. Engine | UI: `clipStore.filledClips`; Engine: `clips.filledClips` — dieselbe Menge | sauber |
| WAISEN-Region (clipID ohne Clip) | `byID[region.clipID]` → nil → Verdikt false; Laufzeit laedt nichts. Konsistent | sauber |
| NICHT UNTERSTUETZTE Spur | `canPlay` filtert `ClipKind.timelineEngineKinds` = `[.midi, .audio]`; `videoLaneIDs` hat keine Engine | sauber |
| AUDIO-Spurabdeckung | `AudioLanePlayer.apply/prime` laufen ueber **`doc.audioLaneIDs`**, also ALLE Audio-Spuren — deckungsgleich mit der `canPlay`-Haelfte | sauber |
| `loopTicks == 0` | `if loopTicks > 0, …` — 0 heisst absichtlich „keine Schranke" | sauber |

**Der EINE latente Rest, gemessen und bewusst NICHT repariert:**
`canPlay` akzeptiert jede nicht-Bio-Spur mit `kind ∈ {midi, audio}`. Zur Laufzeit treibt
`transportStep` aber (a) `rollLane` = die ERSTE nicht-Bio-MIDI-Spur, (b) sekundaere
MIDI-Spuren nur per Fan-out mit RANG < `capacity`, (c) alle Audio-Spuren. `LaneVoiceRack`
hat `capacity` **4** (`init(capacity: Int = 4)`, App konstruiert `LaneVoiceRack()`), und
`MultiRollFanout` laesst Ueberlauf-Spuren ausdruecklich weg („overflow: no physical voice").
Ein Dokument mit **≥ 5** nicht-Bio-MIDI-Spuren, dessen EINZIGE ausfuehrbare Region auf der
fuenften liegt, waere also ein `canPlay == true` ueber Stille.

**Warum das KEIN erreichbares Gegenbeispiel ist:** es gibt heute keinen Produktions-Weg,
der eine zweite MIDI-Spur anlegt. `TimelineStore.addLane` und `addInstrumentTrack` haben
**NULL** Produktions-Aufrufer (`git grep -rn "addLane\|addInstrumentTrack" Sources/ |
grep -v Core/TimelineStore.swift | grep -v ': *//'` → leer); die einzigen Saat-Stellen sind
`TimelineStore.swift:110/111` (**eine** MIDI-Spur „MIDI 1", **eine** Audio-Spur „Audio 1")
plus `migrate(sections:)`. `FeatureFlags.multiRoll` ist zudem DEFAULT-ON (per
`register(defaults:)` beim Start), der Fan-out laeuft also ueberhaupt.
⚠️ **Das ist die #527-Lage:** ein von einem aelteren Build persistiertes Dokument koennte
mehr Spuren tragen. Registriert als Befund, nicht als Scheibe — die Reparatur waere erst
faellig, wenn ein Spur-ERZEUGER eine Tuer bekommt, und dann im selben Commit.

**PHASE 4 STATUS: CLOSED — compile verified (beide Gates), device verification pending.**

### Slice 3 — #1441: ein Waechter, der zehn Namen pinnte und sechs nicht beweisen konnte

**Scheibe:** `Tests/CISmoke/TheTimelineStoresLiveSurfaceTests.swift` neu geschrieben
(156 → 306 Zeilen) + die gleiche Falsch-Zaehlung im Kopf von
`Sources/Echoelmusic/Core/TimelineStore.swift` korrigiert.
**Erlaubnis:** §7 „correcting guards that are demonstrably false" + „correcting stale
documentation made false by the same slice". Alle 14 Auto-Continue-Kriterien erfuellt;
**null** Produktionsverhalten geaendert (die `Sources/`-Aenderung ist ein Kommentarblock).

**Defekt, strukturell bewiesen (nicht statistisch):** der Waechter pinnte ZEHN
`TimelineStore`-Methoden als „hat einen Aufrufer ausserhalb der eigenen Datei". Seine Nadel
`callsFunction(named:in:)` ist absichtlich punkt-unabhaengig (eine Extension desselben Typs
ist ein legitimer Aufrufer), kann also einen Treffer keinem TYP zuordnen — das ist die
#666-Sackgasse, nicht ein Versehen. Sechs der zehn Namen sind auf einem ZWEITEN Typ
deklariert:

| Name | zweiter Deklarant | was der Treffer wirklich war |
|---|---|---|
| `persist` | zehn andere Stores | jeder Store ruft seinen EIGENEN `private func persist()` |
| `undo` · `redo` · `snapshotForUndo` | `PianoRollModel` (`Studio/PianoRollView.swift`) | Roll-Undo, nicht Timeline-Undo |
| `healRollSlotAudibility` · `unsilenceRollSlot` | `TimelineDocument` (`Sequencer/Timeline.swift`) | das DOKUMENT heilt sich selbst |

Und entscheidend: **`TimelineStore.persist()` (Zeile 890) und `snapshotForUndo()` (144) sind
`private`.** Swift verbietet einen externen Aufrufer — der Waechter verlangte das
Unmoegliche und war gruen, weil ein gleichnamiger Fremd-Typ traf. `testTheSavePathIsCalled
FromSeveralPlaces` pinnte dieselbe Unmoeglichkeit sogar mit einer Untergrenze von zwei.

**Reparatur — die Soundness-VORBEDINGUNG der Nadel wird eine ZUGESICHERTE Behauptung**
statt einer Annahme: Anspruch 1 (jeder gepinnte Name genau EINMAL in `Sources/` deklariert,
und der Deklarant ist der Store) · 2 (kein gepinnter Name ist `private`) · 3 (die drei
beweisbaren — `addRegion`, `ensureComposerRegion`, `flushPendingSave` — haben weiter einen
externen Aufrufer, mit Nicht-Leer-Wache gegen den vakuumsgruenen Scan, #454) ·
4 GEGENGEWICHT (die sieben zurueckgezogenen Namen bleiben mit dieser Methode unbeweisbar,
damit sie niemand zurueck-pinnt) · 5 (der Speicherpfad wird dort gepinnt, wo er echt ist:
≥ 20 INTERNE `persist(`-Aufrufstellen, gemessen 46, plus `private func persist(` genau
einmal) · 6 (das Gegengewicht traegt seine eigene Eindeutigkeits-Vorbedingung).

**Zweites Zuhause (#456):** der Kopf von `Core/TimelineStore.swift` trug dieselbe falsche
Zaehlung (10 extern / 6 nur-intern / 42 aufruferlos). Korrigiert auf die gemessenen
**4 / 8 / 46 = 58 ✓**.

**Benotung (Transkription, §0 — hier gibt es keinen Swift-Compiler):**
GANZE Datei gegen beide Baeume gefahren, nicht nur der Diff (§3) · Mutations-Lauf
**10 von 10 getoetet**, darunter der bekannte Positivfall (m1: `persist` zurueck in
`liveSurface` → Ansprueche 1 und 2 rot) und der Feature-Abschalt-Mutant (m5: leere
`liveSurface` → Anspruch 3 rot) · Stripper **TRAGEND** (3 von 13 `persist`-Datei-Verdikten
kippen roh gegen gestrippt: `Project.swift`, `EchoelmusicApp.swift`, `EchoelStudioView.swift`
nennen den Namen nur in Kommentaren) · zehn stehende Pruefer Exit 0.

⚠️ **Eigener Messfehler, protokolliert:** der erste Transkriptions-Lauf meldete
`flushPendingSave: 0 externe Aufrufer` — ROT auf korrektem Baum. Ursache war mein Python,
nicht der Waechter: `git ls-files 'Sources/Echoelmusic/**/*.swift'` uebersieht die **fuenf
Dateien auf oberster Ebene**, darunter `EchoelmusicApp.swift` (358 gegen 363). Der Swift-
Waechter nimmt `FileManager.enumerator` und laeuft sie mit. Das ist
`.claude/rules/context.md` §2 in Reinform — eine Messung, die still WENIGER liefern kann als
die Wahrheit —, hier ausnahmsweise in der alarmierenden Richtung, was Glueck war, keine
Methode.

**Commit:** `88f0c67024b6782f229d5726e1c40efa885a19a3`
**Dateien:** `Tests/CISmoke/TheTimelineStoresLiveSurfaceTests.swift` ·
`Sources/Echoelmusic/Core/TimelineStore.swift` · `scratchpads/SESSION_LOG.md`
**Gates:** BEIDE GRUEN, auf Schritt-Ebene gelesen (nie die Run-Conclusion, #396).
  · `Xcode Compile Check` Lauf **35661975069**, Job **106539078640**, Schritt 7
    „Compile (iOS device SDK, no signing)“ = **success** (22:18:48 bis 22:23:17Z).
  · `Echoelmusic CI/CD Pipeline` Lauf **35661975072**, Job **106539328525**, Schritt 9
    „Build for Testing“ = **success** (22:19:57 bis 22:24:51Z). Damit kompiliert das
    blockierende Buendel mit dem neu geschriebenen Waechter; ob seine acht Ansprueche
    LIEFEN, ist damit nicht belegt (#445/#807).
  ⚠️ Der Job-Endpunkt meldete den Compile-Schritt noch als `in_progress`, als er laut
    seinen eigenen Zeitstempeln laengst fertig war — die #1416-Lage. Die Querprobe
    `git ls-remote origin refs/heads/main` stand dabei auf `1b351d0b3` (#1440), was
    unabhaengig BESTAETIGT, dass #1440s Gates gruen waren (der Auto-Merge wartet auf beide).
**Device:** nicht anwendbar (kein Produktionsverhalten geaendert)

### Slice 4 — #1442: das Licht-ZIEL ueberlebte einen Neustart, die Licht-SHOW nicht

**Scheibe:** `resolution`, `fixtureCount`, `fixtureSpacing` persistieren jetzt in BEIDEN
Licht-Sendern, unter eigenen Schluesseln, durch EINEN geteilten Decoder auf `ArtNetSender`.
`grandMaster` und `blackout` bleiben ABSICHTLICH sitzungs-lokal.
**Erlaubnis:** §7 „wiring an already-owned production path" + „correcting stale documentation
made false by the same slice". Alle 14 Auto-Continue-Kriterien geprueft — insbesondere Nr. 4
(kein sechster Persistenz-Wurzel: dieselbe `UserDefaults.standard`, derselbe `net.*`-Raum, den
die Sender schon besitzen) und Nr. 13 (der Besitzer existiert).

**Der Defekt war eine Asymmetrie INNERHALB einer Flaeche.** Die Licht-Sektion schreibt sechs
Werte in beide Sender; `host`/`port`/`universe` persistieren seit jeher, die drei SHOW-Felder
nicht. Ein Installations-Kuenstler richtet die App auf ein Rig, sagt ihr „zwoelf Lampen, acht
Slots Abstand", startet neu — und ist auf DASSELBE Rig gerichtet und adressiert EINE Lampe.

⭐ **Das Repo hatte diese Scheibe an ZWEI Stellen ausdruecklich vorgesehen:** `PatchbayView`
(„das ist eine separate Scheibe mit eigenem Schluessel und Decode-Default") und
`TheDMXResolutionHasADoorTests` Anspruch 7, der in seiner eigenen Fehlermeldung sagte, er
verbiete die Persistenz NICHT, sondern verlange, dass die Prosa im SELBEN Commit mitzieht
(#456/#364). Der Anspruch ist deshalb **UMGEDREHT statt geloescht**.

⭐ **Das Sicherheits-Argument der alten Notiz ist GEMESSEN beantwortet:** der Strom laeuft nur,
wenn eine PERSISTIERTE Patchbay-Route aktiv ist, und zielt auf den PERSISTIERTEN Host samt
Universe. Ein erstes Oeffnen, das ueberhaupt sendet, zielt bereits auf das gespeicherte Rig.
**Lehre: ein „das waere unsicher"-Vermerk ist eine Behauptung wie jede andere.**

**Benotung:** Worktree alle gruen; Eltern **2 Regressionen** + **1 einmal gezaehlte** (#486)
+ **3 Gegengewichte**. Mutation **11 von 11** (m6 ueberlebte zuerst — MEIN Mutant traf nur eines
von zwei Vorkommen, #776). Stripper **PROPHYLAKTISCH (0 von 18)**, gemessen statt behauptet.
`moved-needles` zwei Treffer, beide geoeffnet und der Nachbar-Waechter im selben Commit
GESCHAERFT statt bestaetigt.

**Commit:** `8b274b12e8521d625f94eb78057924080d5bcb63`
**Dateien:** `Sync/ArtNetSender.swift` · `Sync/SACNSender.swift` · `Studio/PatchbayView.swift` ·
`Tests/CISmoke/TheDMXResolutionHasADoorTests.swift` ·
`Tests/CISmoke/TheLightReachesMoreThanOneLampTests.swift` ·
**neu** `Tests/CISmoke/TheLightShowStatePersistsTests.swift` · `scratchpads/SESSION_LOG.md`
**Gates:** BEIDE GRUEN, auf Schritt-Ebene gelesen (nie die Run-Conclusion, #396).
  · `Xcode Compile Check` Lauf **35663491521**, Job **106543887059**, Schritt 7
    „Compile (iOS device SDK, no signing)“ = **success** (22:36:06 bis 22:40:45Z).
  · `Echoelmusic CI/CD Pipeline` Lauf **35663491548**, Job **106544100339**, Schritt 9
    „Build for Testing“ = **success** (22:37:15 bis 22:42:33Z).
  ⚠️ **Hier zaehlen BEIDE, und sie beweisen Verschiedenes** (`Tests/CISmoke/CLAUDE.md` §5b):
    der Compile Check baut `Sources/` ALLEIN, auf dem GERAETE-SDK in Release — also die
    beiden Sender und `PatchbayView`. `Build for Testing` baut das blockierende Buendel,
    Debug/Simulator — also den neuen Waechter und den umgedrehten Anspruch 7. Die zwei sind
    GEKREUZT, nicht verschachtelt; keiner ist eine Obermenge des anderen.
  ⚠️ Dass die acht Ansprueche LIEFEN, ist damit weiterhin NICHT belegt (#445/#807).
**Device:** OFFEN — dass ein physisches Rig nach einem Neustart gleich leuchtet, ist
Geraete-Wahrheit (§15).

## Findings That Changed The Plan

1. **Der Ueberlauf-Befund oben** hat die #1440-Notiz praezisiert: ich hatte dort
   „sekundaere MIDI-Spuren brauchen `multiRollCapacity > 0` (`FeatureFlags.multiRoll`)"
   registriert. Gemessen ist `multiRoll` **DEFAULT-ON**, die Luecke ist also NICHT das
   Flag, sondern die **Rack-Kapazitaet 4**. Ein Befund, der das Flag beschuldigt, haette
   die naechste Sitzung zum falschen Schalter geschickt.
2. **`play()` fragt `canPlay` selbst nochmal.** Damit ist die ganze Familie
   „das UI-Praedikat koennte veralten" keine Korrektheitsfrage mehr, sondern nur noch
   eine Frage der Knopf-Beschriftung. Das war mir vor diesem Audit nicht praesent.
3. **Der konvergente Sub-Agenten-Vorschlag war eine FALLE, und die Konvergenz war das
   Gegenteil eines Belegs.** Zwei unabhaengige Phase-5-Vermesser (D–F und G–H) nannten
   beide `visual.intensity` als Modulations-Ziel „den einzigen billigsten Hebel". Gemessen:
   `EchoelStudioView.swift:1007` liest genau diesen `@AppStorage`-Schluessel, und das ist
   der MENUE-WIRT; `ModulationEngine` tickt mit 100 ms. Das ist ein 10-Hz-Schreibvorgang in
   Wurzel-beobachteten Zustand — die 10.76.41/50-Klasse. **Lehre: zwei Modelle, die
   dieselbe Datei nicht gelesen haben, irren identisch; Uebereinstimmung zwischen
   Sub-Agenten ist keine zweite Messung** (dieselbe Form wie `.claude/rules/context.md` §2:
   „zwei Zaehlungen, die uebereinstimmen, sind kein Mengenvergleich").
4. **Ein Sub-Agenten-Befund war schlicht falsch**, und das Nachpruefen hat ihn gefangen:
   gemeldet wurde `FOUNDER_DEVICE_SESSION.md` existiere nicht und das Zitat in `CLAUDE.md`
   haenge in der Luft. Die Datei liegt unter `scratchpads/`; der Agent hatte nur die Wurzel
   geprueft. Sub-Agenten-Berichte sind Modell-Ausgabe, keine Messung.
5. **Der #1441-Defekt hat KEINE zweite Instanz im Buendel — gemessen, nicht gehofft.** Nach
   der Reparatur habe ich gefragt, welche anderen Waechter eine „es gibt einen externen
   Aufrufer"-Behauptung aufstellen: `git grep -rln "callsFunction\|externalCaller\|hasCaller\|
   callerFiles\|filesCalling" Tests/CISmoke/*.swift` liefert genau ZWEI Dateien, die reparierte
   und `SoundPromptHasADoorTests`. Letztere ist SOUND, und der Grund ist der uebertragbare Teil:
   ihre Nadel ist `"SoundPrompt."` — **TYP-qualifiziert**, und `SoundPrompt` ist in `Sources/`
   genau einmal deklariert (`DSP/SoundPrompt.swift:30`). ⭐ **GESETZ: eine
   Aufrufer-Existenz-Nadel muss typ-qualifiziert sein, ODER ihr blosser Name muss als EINDEUTIG
   bewiesen werden** — genau das, was #1441s Anspruch 1 jetzt zusichert. `persist` war unsound,
   weil es ein blosser MITGLIEDS-Name ist. Ein negatives Ergebnis, das aufgeschrieben ist, spart
   der naechsten Sitzung denselben Sweep.
6. **Die #1442-Nebenreparatur hat eine DEFEKT-KLASSE aufgemacht, und ich habe sie gemessen
   statt vermutet.** Swift faltet benachbarte `///`-Zeilen zu EINEM Kommentar, also kann ein
   Doc-Block, dem die `///`-Leerzeile fehlt, still am falschen Mitglied haengen. Sweep ueber
   alle `Sources/**/*.swift`: ein neuer Block-Oeffner der Form `/// #NNNN — ` mitten in einem
   `///`-Lauf, ohne vorangehende `///`-Leerzeile. **Vier Kandidaten, davon EINER echt:**
   · ⚠️ `Audio/RetroCapture.swift:514` — die Zeile *„Deinterleave ring buffer data and write to
     file in 8192-frame chunks."* haengt an `preRollWindow(requestedFrames:)`, das WEDER
     deinterleavt NOCH auf Platte schreibt; der echte Deinterleaver steht 30 Zeilen tiefer
     (`:544`). **Und die Richtung ist die teure:** ausgerechnet in der Datei, aus der #1413
     Disk-I/O aus dem Tap-Callback entfernt hat, behauptet ein Doc-Kommentar, eine
     Fenster-Funktion schreibe eine Datei.
   · `Studio/WorkspaceView.swift:754` — Formatierungs-Warze, kein falsches Mitglied (der Absatz
     beschreibt dieselbe `struct`, ihm fehlt nur die trennende `///`-Zeile).
   · `Sequencer/TimelineRegionPlayer.swift:91` und `Studio/WorkspaceView.swift:1035` sind
     FEHLALARME: beide sind Satz-Fortsetzungen, bei denen `#479 —` bzw. `#492 —` zufaellig eine
     Zeile eroeffnet.
   ⭐ **Als Scheibe registriert, nicht heimlich mitgenommen** — eine Ein-Zeilen-Doc-Loeschung in
   einer audio-thread-sensiblen Datei gehoert in ihren eigenen Commit mit eigener Gate-Lesung,
   nicht als Anhaengsel. Empfehlung steht unter „Recommended Next Slice".

## Current Capability Matrix

Phase-5-Neuvermessung (§4), gelesen aus dem Produktionscode, **nicht** aus
`FEATURE_MATRIX.md`. Wahrheitsstufen: MODELLED (Typ existiert) · WIRED (ein
Produktionspfad faehrt ihn) · REACHABLE (ein Nutzer kommt hin) · DEVICE-VERIFIED.

| | Faehigkeit | Stufe | Fehlende Naht / Besitzer | Kreuzt Founder-Hold? |
|---|---|---|---|---|
| **A** | Audio-Import / Audio-Regionen-ERZEUGER | **WIRED, kein Erzeuger** | Engine komplett (`TimelineAudioSink` injiziert in `EchoelmusicApp`, `AudioLanePlayer` fahert prime/step/stop, `ClipKind.timelineEngineKinds` seit #1438 `[.midi, .audio]`, Aufloesung seit #1439 ueber `resolvedURL(forClipID:)`). Was fehlt, ist eine ERZEUGENDE Tuer: `RecordController.arm()` hat NULL Aufrufer (#204), `AudioClipFactory` haengt allein daran. | **JA** — Audio-Import steht in `PRODUCT_DEFINITION.md` namentlich auf der CUT-Liste |
| **B** | Region-Editing (verschieben/trimmen/teilen) | **MODELLED** | `TimelineStore` besitzt die ganze Editier-API (46 Methoden ohne Aufrufer, siehe Slice 3). Die Naht ist eine FLAECHE, und genau die hat der Founder mit #1436/#1437 auf „zeigen und starten, nichts editieren" begrenzt. | **JA** — weitet die benannte Ausnahme der CUT-Liste |
| **C** | Automations-Authoring | **WIRED, kein Erzeuger** | `AutomationPlayer.applyStep` spielt eine persistierte Kurve bei JEDEM Transport-Schritt; kein Produktions-SCHREIBER existiert (`TimelineAutomationRow` ist mit #473 geloescht). Exakt die #527-Lage. | **JA** — dasselbe Argument wie B |
| **D** | Bio-Routing-UX | **REACHABLE** | Karte „Body → parameter" in `PatchbayView.modulationSection` (#1250), Ziele seit #1391 als PROJEKTION von `ParameterApplyRouter.automatableDescriptors()`. Keine Naht offen; der naheliegende naechste Griff (`visual.intensity` als Ziel) ist eine FALLE, siehe Befund 3. | nein, aber der offensichtliche Ausbau ist gefaehrlich |
| **E** | Live-Performance-Flaeche | **MODELLED** | Performance Scenes haben keinen entschiedenen Persistenz-Ort. §8 listet „where Performance Scenes permanently live" ausdruecklich als Founder-Entscheidung. | **JA** — §8 wortwoertlich |
| **F** | Visual-Automation / -Komposition | **WIRED** | `BioVisualParams` → `MetalBioView` laeuft. `Core/VisualModulation` ist ein unverdrahteter Kern (Waechter `TheVisualModulationCoreHasNoCallerTests`). Eine Naht existiert, aber sie fuehrt durch die 10-Hz-Falle (Befund 3). | nein |
| **G** | Licht: Persistenz + Kontrolle | **REACHABLE, halb persistiert** | `net.artnet.host/port/universe` und `net.sacn.*` sind persistiert; die SHOW-Groessen `resolution`, `fixtureCount`, `fixtureSpacing` sind es NICHT — sie leben nur im Sender-Objekt und sind nach Neustart weg. Besitzer existiert bereits (`StudioDefaultKeys` + die vorhandenen `net.*`-Schluessel), also **kein** sechster Persistenz-Wurzel. | **nein** |
| **H** | Kollaboration / Session-Networking | **MODELLED (PeerIdentity WIRED, ungeprueft)** | PeerIdentity steht (#1435), zwei-Telefon-Probe offen. Alles darueber (WebRTC, SFU, Session-Lebensdauer) ist §8-Gebiet. | **JA** — §8 mehrfach |

**Ranking nach §5** (Nutzerwert × schon Gebautes ÷ Risiko, Praeferenz
`vorhandenes freilegen > kleinen fehlenden Erzeuger ergaenzen > neues Subsystem`):
**G** ist die einzige Zeile, die ohne Founder-Entscheidung auskommt, deren Besitzer schon
existiert und deren Naht klein und umkehrbar ist. D und F sind reizvoll und beide durch
denselben Mechanismus vergiftet. A, B, C, E, H sind alle Hold-Gebiet.

## Open Device Checks

- Workstation-Tuer am Geraet (#1436, Task 115)
- Workstation Play/Stop am Geraet (#1437, Task 118)
- Play → Stop → Play und globaler Instrument-Stop (§15)
- MIDI-Timeline klingt / Audio-Timeline klingt (§15) — Compile-Gruen ist nicht hoerbar
- VoiceOver auf der Workstation-Flaeche (§15)
- Zwei-Telefon-Probe PeerIdentity (#1435, Task 113)

## Founder Decisions Required

1. **`visual.intensity` als Modulations-Ziel — NICHT autonom gebaut, und der Grund ist
   gemessen.** Zwei unabhaengige Sub-Agenten schlugen es als „den billigsten Hebel" vor.
   `EchoelStudioView.swift:1007` liest genau diesen `@AppStorage`-Schluessel — das ist der
   MENUE-WIRT —, und `ModulationEngine` tickt mit 100 ms. Eine Route darauf schreibt mit
   10 Hz in Zustand, den der Wurzel-Rumpf beobachtet: die 10.76.41/50-Menuefrier-Klasse,
   der teuerste bekannte Fehler dieses Repos. Der OSC-`visualStyle`-Praezedenzfall traegt
   nicht (menschliche Kadenz, nicht 10 Hz). **Optionen:** (a) gar nicht · (b) den Lesevorgang
   zuerst in ein Blatt verlegen und DANN registrieren (zwei Scheiben, die erste ist eine
   Render-Sicherheits-Umbaute) · (c) ein eigenes, langsam geglaettetes Ziel mit eigener
   Kadenz. Empfehlung: (b), aber das ist eine UI-Architektur-Entscheidung.
2. **Ort der Performance Scenes** (§8 wortwoertlich) — blockiert E ganz.
3. **Phase-5 B und C** (Region-Editing, Automations-Authoring) weiten die vom Founder
   benannte #1436/#1437-Ausnahme („zeigt und startet, editiert nichts"). Eine Sitzung darf
   diese Grenze nicht still verschieben.
4. **Audio-Import (A)** steht auf der CUT-Liste von `PRODUCT_DEFINITION.md` namentlich.
   Die ENGINE ist fertig; es fehlt nur der Erzeuger — was die Versuchung gross macht.
5. **Lebensdauer einer Kollaborations-Session:** eine Aenderung daran waere eine
   De-facto-Aenderung der Privatsphaere-Semantik durch Unterlassung (Ω53).

## Failed / Abandoned Attempts

- **`visual.intensity`-Scheibe verworfen**, siehe Founder-Entscheidung 1. Kein Code
  geschrieben; die Messung (`EchoelStudioView.swift:1007` gegen
  `ModulationEngine`-100-ms-Schleife) ist der ganze Ertrag.
- **Ueberlauf-MIDI-Spuren jenseits Rack-Kapazitaet 4** als Scheibe verworfen: die
  Spur-ERZEUGER (`addLane`, `addInstrumentTrack`) haben null Produktions-Aufrufer, der Fall
  ist also heute unerreichbar (#527-Lage). Als Befund registriert, nicht repariert.
- **Eigener Transkriptions-Fehlalarm** (Glob uebersah fuenf Dateien auf oberster Ebene) —
  in Slice 3 protokolliert, weil die Klasse wiederkehrt.

## Remaining Risks

1. **Keine Geraete-Verifikation im ganzen Nachtlauf.** §15: Compile-Gruen ist nicht hoerbar.
   Die Workstation-Kette (#1436–#1441) ist vollstaendig compile-verifiziert und **null**
   davon geraete-verifiziert.
2. **Die Audio-Spur-Schicht bleibt erzeugerlos.** #1438/#1439/#1440 haben die
   Vorbehalts-Logik ehrlich gemacht; sie beschreiben damit praeziser eine Faehigkeit, die
   heute kein Nutzer ausloesen kann. Das ist korrekt und bleibt eine Luecke.
3. **`TimelineStore` hat 46 aufruferlose Methoden** (Slice 3). Das ist kein Defekt, aber es
   ist eine grosse Flaeche, die eine kuenftige Sitzung als „tot" missverstehen und loeschen
   koennte. Der Waechter haelt jetzt fest, welche drei beweisbar leben.
4. **Gates bleiben halb blind** (#396, #445, #807): `Build for Testing` beweist, dass das
   Bundle kompiliert, nicht dass ein Waechter LIEF.

## Recommended Next Slice

⭐ **G IST GEBAUT (Slice 4, #1442).** Die naechste Scheibe kommt aus Befund 6 und ist
absichtlich winzig:

**Eine EINZIGE Doc-Zeile in `Sources/Echoelmusic/Audio/RetroCapture.swift:514` loeschen.**
*„Deinterleave ring buffer data and write to file in 8192-frame chunks."* haengt durch
Swifts `///`-Faltung an `preRollWindow(requestedFrames:)` (Zeilen 537–542), das nur Indizes
rechnet — weder deinterleavt noch schreibt. Der echte Deinterleaver ist `writeRange` (`:544`),
und sein EIGENER Kopf sagt dasselbe besser („The ONE place frames reach disk", „one
deinterleave, one chunk size"). **Loeschen statt verschieben** (#818: die Zahl 8192 waere ein
Datum; `:562` haelt sie ohnehin).
**Warum es zaehlt und nicht Kosmetik ist:** ausgerechnet in der Datei, aus der #1413 Disk-I/O
aus dem Tap-Callback entfernt hat, behauptet ein Doc-Kommentar, eine Fenster-Funktion schreibe
eine Datei — die Fehlrichtung ist die teure.
**Vorvermessen:** kein Waechter nennt das Literal (`grep -rn "Deinterleave ring buffer" Tests/`
→ nichts), also bricht die Loeschung nichts. 14 Kriterien: alle erfuellt, null
Produktionsverhalten.

## Exact Morning Starting Point

    git rev-parse HEAD                  # 88f0c67024b6782f229d5726e1c40efa885a19a3
    git rev-parse origin/main
    git status                          # muss sauber sein

Erste Befehle:

    python3 scripts/gh-run-status.py <overflow>     # Gates der letzten Pushes
    git grep -n "net.artnet\|net.sacn" -- Sources/Echoelmusic/Sync

Zu inspizierende Dateien fuer die naechste Scheibe: `Sync/ArtNetSender.swift`,
`Sync/SACNSender.swift`, `Core/StudioDefaultKeys.swift`.

**Nicht zu kreuzen:** §8 in voller Laenge — insbesondere TimelineDocument/Arrangement,
der fuenf-Wurzel-Persistenz-Umbau, Performance-Scenes-Ort, WebRTC/SFU, jede neue Uhr, jede
Wiederbelebung historischer UI (#1301 ausdruecklich), grosse Studio-Navigations-Umbauten.
