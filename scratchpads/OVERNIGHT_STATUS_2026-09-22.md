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

## Findings That Changed The Plan

1. **Der Ueberlauf-Befund oben** hat die #1440-Notiz praezisiert: ich hatte dort
   „sekundaere MIDI-Spuren brauchen `multiRollCapacity > 0` (`FeatureFlags.multiRoll`)"
   registriert. Gemessen ist `multiRoll` **DEFAULT-ON**, die Luecke ist also NICHT das
   Flag, sondern die **Rack-Kapazitaet 4**. Ein Befund, der das Flag beschuldigt, haette
   die naechste Sitzung zum falschen Schalter geschickt.
2. **`play()` fragt `canPlay` selbst nochmal.** Damit ist die ganze Familie
   „das UI-Praedikat koennte veralten" keine Korrektheitsfrage mehr, sondern nur noch
   eine Frage der Knopf-Beschriftung. Das war mir vor diesem Audit nicht praesent.

## Current Capability Matrix

(Phase-5-Vermessung, §4 — wird gefuellt)

## Open Device Checks

- Workstation-Tuer am Geraet (#1436, Task 115)
- Workstation Play/Stop am Geraet (#1437, Task 118)
- Zwei-Telefon-Probe PeerIdentity (#1435, Task 113)

## Founder Decisions Required

(wird gefuellt)

## Failed / Abandoned Attempts

(wird gefuellt)

## Remaining Risks

(wird gefuellt)

## Recommended Next Slice

(wird gefuellt)

## Exact Morning Starting Point

(wird gefuellt)
