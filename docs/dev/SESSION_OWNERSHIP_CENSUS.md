# WA2 — Session Ownership Census + Founder Decision

**Status: WA2 COMPLETE — Founder decision APPROVED WITH BINDING AMENDMENTS (2026-09-24, §O).
Nothing here is implemented.** The census (§A–§L) is read-only evidence of CURRENT REALITY. §M is
the proposal as amended; §O is the binding decision and the APPROVED TARGET OWNERSHIP. Where §M
and §O differ, §O wins.

⚠️ **Terminology.** *Canonical Session* in this document means the future full workstation
creative/session truth (`DMMWProject`). The historical `SessionView`/`SessionEngine`/
`SessionRecorder` are a parked breathing/performance experiment. They are **not the same
concept**; no production type is renamed.

Census analysis dated 2026-09-24.
- Branch head at census time: `c2fad0a0a`. `main` = `7b2690357`.
- No production code, test, store, persistence format, UI or workflow was changed.

**Authority:**
1. `docs/dev/FOUNDER_PRODUCT_LAW.md`
2. `docs/dev/ECHOELMUSIC_MASTER_PLAN.md` (invariants 1–5 and 9 bind this document)
3. current code and tests
4. `docs/dev/HISTORY_ARCHIVE.md`
5. older docs, as evidence only

**Predecessor:** `docs/dev/WORKSTATION_UI_OWNERSHIP_CENSUS.md` (WA1).

**How it was measured.**
- Four read-only inspection passes: save/open/export/collaboration · time/transport/Start ·
  timeline/arrangement/clips/tracks · automation/context/routing.
- Every load-bearing "zero callers" was re-measured with a comment-stripped fixed-string grep,
  `git grep -nF '<call>' -- Sources | grep -v ': *//'`.
- ⚠️ The first attempt at that sweep used `-nE` with an unescaped `(`. git errored, and the
  pipeline still printed `0` for every row. **A zero from a failing grep is not a measurement.**
  The fixed-string re-run is the one quoted here.
- Line numbers are dates, not facts. Re-derive them before acting.

⚠️ **Output path.** This file is the WA2 output. The master plan's old `scratchpads/` path for
it was corrected in the decision-lock commit.

---

## A. Executive conclusion

1. **There is no single song today.** Four stores could each claim the name, and they do not
   share one record:
   - **`TimelineDocument`** (lanes, regions, song automation) is the only song model that has
     live writers and live playback. It is reached from the Workstation.
   - **`PianoRollModel` + the `Project` take** (notes, raw take, BPM, key, patch) is the song the
     instrument actually SOUNDS, SAVES, OPENS, EXPORTS and SHARES.
   - **`Arrangement`** is persisted and has zero writers and zero playback.
   - **`DMMWProject`** — the one type that would bind the other three — is importer-only, has
     no caller and is never written.
2. **Save/Open preserves the instrument take, not the workstation.** `open(_:)` restores:
   - key, scale, A4, tone system, genre, mode, tempo, loop bars;
   - patch, FX character, mood, notes, raw take and drum steps.
   It does **not** touch timeline, clips, arrangement, automation, mixer, TrackFX, routing or
   collaboration state. Opening a project leaves the Workstation's arrangement as it was.
3. **Time has one clock and three unrelated notions of "loop".**
   - `PatternEngine` is the only musical clock; `Transport` is its relay. Invariant 3 holds.
   - Tempo DATA has no home in the song document.
   - Loop length lives in the composer (`studio.loopBars`), the timeline player (derived) and
     the fixed 16-step grid.
   - Nothing stops the generator and the timeline player from both using the clock at once.
4. **There is no canonical Track.** `TimelineLane` is the de facto track record, and nearly all
   of its mixer setters have no caller. The mixers that do sound are fixed role buses.
5. **Automation has three persisted homes.** Two of them compete at song level: the automation
   file and `TimelineDocument.automation`. **None of the three has a production writer.**
   At runtime the order is timeline > clip > global.
6. **Musical context is split between a "selected" truth and a "named" mirror.** The selected
   truth is `@AppStorage` (`studio.rootIndex`/`scale`/`genre`/`toneSystemID`). The named mirror
   is `SessionContext` (`echoel.keyRoot`/`keyScale`); A4 has its single home there. Time
   signature is hard-coded 4/4.
7. **Start is a mixed historical responsibility.** It sets `running`, fetches weather, generates
   a take, starts the clock, starts the evolve loop and only then starts the bio source. It is a
   performance bootstrap that also starts the transport.
8. **Export exports the current take as heard.** WAV is a real-time capture of the master tap
   while the pattern replays. MIDI is the composer's arrangement bars. Nothing renders the
   timeline offline.
9. **Live Colabo shares a flat `Project` plus bio readings.** It shares no transport, no
   parameters, no clips, no media and no Session. Loading a shared project replaces the take.
10. **Scenes: NONE.** There is no musical Scene type, and clip launching exists only as unreached
    player code.

**Recommendation (§M) — APPROVED WITH BINDING AMENDMENTS; the binding form is §O:**
- The canonical Session is the **already-built `DMMWProject` envelope**, stored as the payload
  of the **existing** `ProjectStore` root. There is no new root and no new store.
- Its content spine is **`TimelineDocument`**.
- The existing stores remain the runtime owners of its children, and `PatternEngine` remains
  the clock.
- The Echoel instrument becomes **a device whose output lands on a Session track**, not a
  second song (the Track itself is defined by WA3, §O).
- Arrangement becomes a future projection (port its sequencing algorithm).
- The automation file and `Project` v1 become import-only legacy.
- App/system settings stay outside the Session; creative routing, domain creative state,
  device modulation and collaboration metadata belong to it (amended, §O).

**Founder: APPROVE or REJECT.**

---

## B. Current ownership graph

```
                         ┌──────────────── EchoelmusicApp (@State, composition root) ────────────────┐
                         │                                                                           │
 PERSISTED (App Group)   │  projects.json.json ── ProjectStore ── [Project v1]  ◄── save/open ── EchoelStudioView
                         │  Timeline/timeline ─── TimelineStore ── TimelineDocument ◄── WorkstationView (+ composer mirror)
                         │  Clips/clips ───────── ClipStore ─────── [Clip?] ×8 ◄──── imports, composer mirror
                         │  Arrangement/song ──── ArrangementStore ─ Arrangement      (0 writers)
                         │  Automation/automation AutomationPlayer ─ AutomationState  (0 lane writers)
 PERSISTED (UserDefaults)│  echoel.keyRoot/keyScale/a4Hz ── SessionContext  (named mirror; A4 home)
                         │  studio.rootIndex/scale/genre/toneSystemID/loopBars/lockBPM/lockedBPM/mood/fxCharacter/presetIndex
                         │                                   (@AppStorage, spread over views — "selected" truth)
                         │  mixer.* ── MixerStore · trackfx.* ── TrackFXStore · modulationMatrix.v1 · signalGraph.routes.v1 · net.*
 NOT PERSISTED           │  PatternEngine (clock) ─► Transport (relay) ─► metronome · MIDI clock · players · automation
                         │  PianoRollModel (the SOUNDING take) · currentPatch/delaySync/running (view @State)
                         │  LightingStore · SpatialSceneStore (derived) · FXBioModulator routes · MultipeerSession
 NEVER WRITTEN           │  DMMWProject (type + pure importer, no caller) · TempoMap/MeterMap (only via that importer)
                         └───────────────────────────────────────────────────────────────────────────┘
 Players on the one clock: PianoRollModel ◄ generate()   ·   TimelineRegionPlayer ◄ Workstation Play
                           AudioLanePlayer ◄ timeline     ·   ArrangementPlayer (no caller)   ·   AutomationPlayer (per step)
```

**The composer mirror.** `generate()` writes the take into a composer-owned clip on the first
MIDI lane (`syncPrimaryRollClip` → `ensureComposerRegion` / `updateComposerMelody`).
- It only does this if such a lane exists.
- `TimelineStore.bootstrapIfNeeded` has no caller, so a fresh install has no lanes until the
  user taps "Add MIDI/Audio Track".
- The sound of Generate still comes from `PianoRollModel.loadArrangement`, **not** from the
  timeline.

---

## C. Owner-by-owner census

Fields 1–18 as requested, split into two tables keyed by ID.

**Role vocabulary:**
- CANONICAL
- CHILD OF SESSION
- PROJECTION
- RUNTIME DERIVED
- LEGACY
- PARK
- NEEDS FOUNDER DECISION

The role column is **this document's recommendation**. No code carries it.

### C1 — identity, persistence, truth, role

| ID | (1) Type | (2) File | (3) Persistence | (4) Constructs · (5) lifetime | (8) Current SoT? | (9) Duplicated by | (17) Historical reason | (18) Recommended role |
|---|---|---|---|---|---|---|---|---|
| O1 | `Project` / `ProjectStore` | `Core/Project.swift`, `Core/ProjectStore.swift` | App Group `Echoel/projects.json.json` (double extension: `AppGroupStore.fileURL` appends `.json`); schema 1 | App (`EchoelmusicApp`) · app lifetime | **Yes** for saved takes | the live `@AppStorage` keys, `SessionContext`, `PianoRollModel` (it is a snapshot of them) | instrument-phase save format (key/tempo/patch/notes) | **ProjectStore = CANONICAL root (container)**; `Project` v1 payload = **LEGACY** (import source) |
| O2 | `DMMWProject` + `DMMWProjectImport` | `Core/DMMWProject.swift`, `Core/DMMWProjectImport.swift` | none (never written) | nobody (pure; 0 production callers) | No | would unify O1, O3, O6, O7, O13 | #1416/#1419 envelope, "importer first, writer second" | **CANONICAL** (Session shape) — see §M |
| O3 | `TimelineDocument` / `TimelineStore` | `Sequencer/Timeline.swift`, `Core/TimelineStore.swift` | App Group `Timeline/timeline`, 250 ms debounced + flush on background; schema 1 | App · app lifetime | **Yes** for the arrangement | `Arrangement` (O6); composer take in O12 | DAW timeline, kept through the #121 cuts | **CANONICAL content spine (CHILD OF SESSION: `content.timeline`)** |
| O4 | `TimelineLane` | `Sequencer/Timeline.swift` | inside O3 | O3 | de facto track | `MixerStore` roles, `LaneVoiceRack` slots, `TrackFXStore` buses | lane = track since the DAW phase | **CHILD OF SESSION** (the future Track record, §G) |
| O5 | `TimelineRegion` | `Sequencer/Timeline.swift` | inside O3 | O3 | Yes (placement) | — | — | **CHILD OF SESSION** |
| O6 | `Arrangement` / `ArrangementStore` / `ArrangementPlayer` | `Sequencer/Arrangement.swift`, `Core/ArrangementStore.swift`, `Sequencer/ArrangementPlayer.swift` | App Group `Arrangement/song`, immediate save | App · injected, read by nobody's UI | **No** (0 writers, `play` has 0 callers) | O3 | song-form sections before the timeline | **PROJECTION (future Scenes/sections) + PORT ALGORITHM** (`ArrangementCursor`); store = **LEGACY, do not delete** |
| O7 | `ClipStore` / `Clip` | `Core/ClipStore.swift`, `Sequencer/Clip.swift` | App Group `Clips/clips`, 8 fixed slots, immediate save; `Clip` schema 1; slot array unversioned | App · app lifetime | **Yes** (region content) | — (see §C-ClipStore note on overloading) | clip launcher era | **CHILD OF SESSION** (clip pool); capacity is a later decision |
| O8 | `MediaLibrary` | `Core/MediaLibrary.swift` | files in App Group `Media/Audio` (Video/Image folders exist) | static enum, never instantiated | Yes (file bytes) | the file's identity is only a path inside `Clip.mediaRef` | Audio Import V1 | **CHILD OF SESSION** (asset store; referenced, not embedded) |
| O9 | `PatternEngine` | `Sequencer/PatternEngine.swift` | none (tempo mirrored to `studio.lockedBPM` only when locked) | `BeatPlayer` ← App · app lifetime | **Yes** (clock, live tempo, play state) | `Transport` mirror (by design) | the only clock since v10 | **RUNTIME DERIVED executor — clock authority stays** (invariant 3) |
| O10 | `Transport` | `Core/Transport.swift` | none | App · wired to O9 | No (relay) | mirror of O9 | — | **RUNTIME DERIVED** |
| O11 | `TimelineRegionPlayer`, `AudioLanePlayer` | `Sequencer/TimelineRegionPlayer.swift`, `Sequencer/AudioLanePlayer.swift` | none | App | No | — | #1437–#1440 | **RUNTIME DERIVED** (plays O3) |
| O12 | `PianoRollModel` (the sounding take) | `Studio/PianoRollView.swift` | none of its own; saved through O1 (`notes`, `rawTake`) | App · `start(...)` at launch | **Yes, for what the instrument plays** | O3 composer mirror clip | piano-roll era; editor view deleted #475 | **CHILD OF THE ECHOEL DEVICE** (device runtime), take content → **LEGACY** in O1, future = region content in O3 |
| O13 | `AutomationPlayer` / `AutomationState` | `Core/AutomationPlayer.swift` | App Group `Automation/automation` | App · wired to O9 | No (0 lane writers) | `TimelineDocument.automation` (O14) | per-bar global lanes, pre-timeline | executor = **RUNTIME DERIVED**; its lane file = **LEGACY** (import via "timeline wins"); `enabled` = NEEDS FOUNDER DECISION (Session vs app setting) |
| O14 | `TimelineDocument.automation` | `Sequencer/Timeline.swift` | inside O3 | O3 | Plays last (authoritative at runtime) | O13 lanes | song-absolute automation | **CHILD OF SESSION** (canonical song automation) |
| O15 | `Clip.automation` | `Sequencer/Clip.swift` | inside O7 | O7 | clip-relative, separate domain | — | cycle-4 clip automation | **CHILD OF SESSION** (via clip) |
| O16 | `ModulationEngine` / `ModulationMatrix` | `Core/ModulationEngine.swift`, `Core/ModulationMatrix.swift` | UserDefaults `modulationMatrix.v1` | App | Yes (live routes) | — | #1250 surface | **NEEDS FOUNDER DECISION** (Session vs device vs app); stays app-level until decided |
| O17 | `FXBioModulator` routes | `Tools/FXBioModulator.swift` | none (in memory) | App | Yes (session-only) | — | FX bio routes | **RUNTIME** (device-level later) |
| O18 | `SessionContext` | `Core/SessionContext.swift` | UserDefaults `echoel.keyRoot`/`keyScale`/`a4Hz`/`artistName` | App | **A4 + artist: yes**; key/scale: mirror | `@AppStorage studio.rootIndex/scale` (O19) | naming context ("Echoel_<date>_<Key>_<bpm>") | **CANONICAL runtime owner of MusicalContext** (recommended — §I), today a partial mirror |
| O19 | `@AppStorage` musical keys | `StudioDefaultKeys.swift`, read in ≥3 views | UserDefaults (`studio.rootIndex`, `scale`, `genre`, `toneSystemID`, `loopBars`, `lockBPM`, `lockedBPM`, `mood`, `fxCharacter`, `presetIndex`) | views | **Yes (selected truth)** for key/scale/genre/tone/mode | O18 (key/scale), O1 (snapshot) | instrument-phase settings | **PROJECTION** of Session musical context / device state (after migration) |
| O20 | `Timebase` / `TempoMap` / `MeterMap` | `Core/Timebase.swift`, `Core/TempoMap.swift` | none (only inside O2) | only `DMMWProjectImport` | No | `Project.bpm`, `studio.lockedBPM`, live O9 tempo | #1416 EchoelCore time | **CHILD OF SESSION** (`timebase`), the tempo home |
| O21 | `MetronomeVoice` | `Audio/MetronomeVoice.swift` | none | App | its own `beatsPerBar` (1–16) | disagrees with fixed 4/4 elsewhere | practice click | **RUNTIME DERIVED** (reads Session meter later) |
| O22 | `currentPatch` / `PatchStore` | `Studio/EchoelStudioView.swift`, `Core/PatchStore.swift` | patch: view `@State`, rebuilt from `studio.presetIndex`/genre; library: App Group `Patches/userPatches` | view / App | patch: Yes (UI-owned) | O1 `patch` (snapshot), `TimelineLane.patch` (unused field) | — | patch = **CHILD OF THE ECHOEL DEVICE**; library = app-level (outside Session) |
| O23 | `MixerStore`, `TrackFXStore` | `Core/MixerStore.swift`, `Core/TrackFXStore.swift` | UserDefaults `mixer.*`, `trackfx.*` | App | Yes (fixed role buses) | `TimelineLane.level/pan/mute/solo` (unused setters) | instrument voice mix | **CHILD OF THE ECHOEL DEVICE** (internal voice mix, WA1 S28) |
| O24 | `SignalRouter` + network targets | `Core/SignalRouter.swift`, `Sync/*Sender.swift`, `Sync/OSCReceiver.swift` | UserDefaults `signalGraph.routes.v1`, `net.*` | App; `applyRouting` starts senders | Yes (app-global) | — | I/O hub | **Outside the Session** (app/studio settings; adapters, invariant 9) |
| O25 | `LightingStore`, `SpatialSceneStore` | `Core/LightingStore.swift`, `Core/SpatialSceneStore.swift` | none; spatial scene is rebuilt from O4 | App | Lighting: runtime; Spatial: derived | — | P2 lighting seam; ADM-OSC | Spatial = **PROJECTION of Session tracks**; lighting creative state = **NEEDS FOUNDER DECISION** (not persisted today) |
| O26 | `MultipeerSession` / `ColabPayload` / `PeerIdentity` | `Sync/MultipeerSession.swift`, `Sync/ColabPayload.swift`, `Sync/PeerIdentity.swift` | none (peer identity reads `echoel.installationID`) | App | No | — | J2 Live Colabo | **ADAPTER** (shares Session snapshots later; not an owner) |
| O27 | `SessionEngine` / `SessionRecorder` | `Bio/SessionEngine.swift`, `Core/SessionRecorder.swift` | recorder: UserDefaults `bioSessions.v1` | App (engine attached, never started) | No (breathing/bio log, not a musical session) | — | 07-06A Session-as-home experiment | **PARK** — ⚠️ the NAME "Session" collides; do not reuse it for the musical Session type |
| O28 | Export chain: `LoopExporter`, `RetroCapture`, `SingleExport`, `exportMIDI` | `Audio/LoopExporter.swift`, `Audio/RetroCapture.swift`, `Audio/SingleExport.swift`, ESV | output files only | App / view | — | — | loop-export era | **RUNTIME** (a Session render is a future capability, §J) |
| O29 | `RecordController` / `TakeRecorder` / `BioAutomationRecorder` | `Core/RecordController.swift`, `Sequencer/TakeRecorder.swift` | would write O7 + O3 | App (wired, `arm()` never called) | No | — | recorder chain (#204) | **PARK** |

### C2 — readers, writers, save/open, usage

**Columns:**
- (6) Readers
- (7) Writers
- (10) Survives save/open
- (11) UI-owned
- (12) Realtime-sensitive
- (13) Export
- (14) Collaboration
- (15) Arrangement UI (Workstation)
- (16) Instrument UI

| ID | (6) | (7) | (10) | (11) | (12) | (13) | (14) | (15) | (16) |
|---|---|---|---|---|---|---|---|---|---|
| O1 | Open list, `open(_:)` | `saveProject`, `autosaveTake` (scene leaves `.active`; before `open`), `delete`, JSON import, Colabo "Save" (keeps sender id) | is the save/open | no | no | no | **yes** (the shared payload) | no | yes |
| O2 | — | — | no | no | no | no | no | no | no |
| O3 | WorkstationView, `TimelineRegionPlayer`, `SpatialSceneStore` (dead door), ESV composer mirror | WorkstationView (import, add track, warp, pitch), ESV `ensureComposerRegion`/heal, `RecordController` (dead) | **no** (own file; `open` never touches it) | no | player snapshot | **no** (no offline render) | no | **yes** | mirror only |
| O4 | players, rack gains, per-track keyPaths | `addLane` (import helpers), `setLaneTranspose`; ~20 other setters have 0 callers | no | no | slot gain/pan | no | no | yes | no |
| O5 | players | imports, composer mirror, warp | no | no | yes (scheduling) | no | no | yes | no |
| O6 | `ArrangementPlayer` (never started) | **none** | no | no | no | no | no | no | no |
| O7 | players, WorkstationView | imports, composer melody, tempo detection/correction, `RecordController` (dead) | no | no | audio prime chain | no | no | yes | mirror only |
| O8 | `AudioLanePlayer` via `resolveRef`, `BeatPlayer` | `AudioImport` (copies into `Media/Audio`) | no | no | file reads off-thread | no | no | yes | no |
| O9 | everything time-aware | ESV (tap, open, generate glide/play/stop), BodyTempoField, PlaybackToggleButton, TimelineRegionPlayer, LoopExporter, AutomationPlayer (`.automation`), OSC-in (`.remoteControl`), modulation route (dormant), output-loss stop | tempo **yes** (via `Project.bpm` → `setTempo(.user)`) | no | **yes** | yes (re-play for WAV) | no | yes (play) | yes |
| O10 | subscribers (MIDI clock, metronome, preflight, haptics, players, RecordController) + readers | PatternEngine only | no | no | yes | — | no | yes | yes |
| O11 | — | Workstation Play/Stop | no | no | yes | no | no | yes | no |
| O12 | export, visual/light (`MusicalFrame`) | `generate()`, `open()`, timeline player (roll region), rebalance | **yes** (as `notes`/`rawTake`) | no | yes (note engine) | **yes** (MIDI + WAV source) | yes (inside `Project`) | via roll lane | **yes** |
| O13 | per-step apply | `enabled` only (AutomationStatusStrip) | no | no | yes | no | no | no | strip |
| O14 | applied last | **none** (editing API 0 callers) | no | no | yes | no | no | no | no |
| O15 | applied second | **none** (`ClipStore.setClipAutomation(id:lanes:)` 0 callers; `TakeRecorder` dead) | no | no | yes | no | no | no | no |
| O16 | 100 ms apply loop | PatchbayView only | no | no | yes | no | no | no | via Routing |
| O17 | FX chain | EchoelFXView | no | no | yes | no | no | no | yes |
| O18 | session naming, header strip (A4) | `adopt(key:)` on compose/open, `resetMusicalIdentity`, A4 field, A4 reset, open | key via O19; **A4 yes** | no | A4 → 7 voices | naming only | no | no | yes |
| O19 | ESV, WorkspaceView, FloatingVisualWindow, ExternalDisplayScene | header strip, ESV, OSC-in, open, SoundReset | **yes** (all captured in `Project`) | **yes** (views declare them) | via retune/recompose | loopBars, loudness | via `Project` | no | yes |
| O20 | — | only the importer | no | no | — | no | no | no | no |
| O21 | click | tempo from Transport; UI slider | no | UI | audio thread | no | no | no | yes |
| O22 | synth voices | sound panel, presets, open | **yes** (by value) | **yes** (`@State`) | yes | indirectly | via `Project` | no | yes |
| O23 | voices, rack | mix panel | **no** | no | yes | indirectly | no | no | yes |
| O24 | `applyRouting` | PatchbayView, OSC cue (blackout) | no | no | network | no | no | no | via Routing |
| O25 | ADM/DMX senders | parameter binding (lighting); parked stage view (spatial) | no | no | network | no | no | no | no |
| O26 | LiveColaboView | share/sendBio/receive | shares `Project` | no | no | no | **is** collaboration | no | yes |
| O27 | parked views | parked views | — | — | engine attached silent | no | no | no | no |
| O28 | — | Record/Keep-last/MIDI tiles, visual-window WAV | — | — | real-time capture | **is** export | no | no | yes |
| O29 | — | — | — | — | — | — | — | — | — |

---

## D. Duplication matrix

**Verdicts used:**
- ONE OWNER
- DUPLICATED (independent writers of the same truth)
- DERIVED COPY
- RUNTIME CACHE
- UNRESOLVED (no owner can be named)

| Concept | Every current owner / writer | Verdict |
|---|---|---|
| **TEMPO** | live: `PatternEngine.tempo` (8 writers, all through `setTempo`/`glideTempo(source:)`); persisted: `studio.lockedBPM` (5 writers), `Project.bpm`; data model: `TempoMap` (unused); mirror: `Transport.tempo`, `pianoRoll.musicalTempoBPM` | **DUPLICATED** persisted homes (`lockedBPM` vs `Project.bpm`), **ONE OWNER** live clock, **UNRESOLVED** song-level home (none in `TimelineDocument`) |
| **KEY** | `studio.rootIndex` (header, ESV, OSC, open); `SessionContext.keyRoot` (adopt, reset, open); `Project.keyRoot`; `PianoRollModel.musical*` | **DUPLICATED** (selected vs named), plus DERIVED COPY in the roll |
| **SCALE** | `studio.scale` (header, genre change, OSC, open); `SessionContext.keyScale`; `Project.scaleRaw` | **DUPLICATED** |
| **A4** | `SessionContext.a4Hz` (header field, reset, open); `Project.a4Hz`; `pianoRoll.musicalA4Hz` | **ONE OWNER** + snapshot + DERIVED COPY |
| **LOOP** | `studio.loopBars` (composer bar count; picker, open); `Project.loopBars`; timeline `loopTicks` (derived from document end); PatternEngine 16-step bar (fixed) | **UNRESOLVED** — three different concepts share the word; no Session cycle region exists |
| **AUTOMATION** | `AutomationState.lanes` (file); `TimelineDocument.automation`; `Clip.automation`; live: ModulationMatrix, FX routes | song level **DUPLICATED** (file vs timeline); clip = separate domain; player arrays = RUNTIME CACHE; modulation = separate live domain |
| **PROJECT** | `Project` in `ProjectStore`; `DMMWProject` (type only); the five working files | **DUPLICATED** (a saved take and a working arrangement that never meet) |
| **TIMELINE** | `TimelineDocument` | **ONE OWNER** |
| **CLIP** | `ClipStore` slots | **ONE OWNER** (but overloaded as asset + content, §L) |
| **ARRANGEMENT** | `Arrangement` (dead); `TimelineDocument` (live); `PianoRollModel.arrangementBars` (the composer's bar cycle) | **DUPLICATED by name**, three different meanings |
| **PLAYHEAD** | `Transport.position`; timeline cursor; roll `playedBars`; audio lanes on sample time; metronome sample counter | ONE clock, several **DERIVED** cursors; metronome downbeat re-aligned only on the generate path |
| **TRANSPORT RUNNING** | `transport.isPlaying`; view `@State running`; `bus.instrumentRunning` | **DUPLICATED** meaning (clock ticking vs take exists), bridged by `TransportTransition.decide` |
| **DEVICE STATE** | `currentPatch` (view `@State`), `studio.presetIndex`, `fxCharacter`, `mood`, `MixerStore`, `TrackFXStore`; snapshot in `Project`; unused lane fields (`patch`, `genreOverride`, `mood`) | **DUPLICATED** (view truth + UserDefaults + snapshot + unused lane slots) |
| **ROUTING** | `SignalRouter` routes, `net.*`, ModulationMatrix | **ONE OWNER** each (app-global) |

---

## E. Persistence map

```
DISK                                   DECODED               RUNTIME OWNER            UI PROJECTION
Echoel/projects.json.json         →    [Project v1]      →   ProjectStore         →   Open list · open(_:) scatters into ↓
Timeline/timeline                 →    TimelineDocument  →   TimelineStore        →   WorkstationView
Clips/clips                       →    [Clip?]×8         →   ClipStore            →   WorkstationView (parts)
Arrangement/song                  →    Arrangement       →   ArrangementStore     →   (none)
Automation/automation             →    AutomationState   →   AutomationPlayer     →   AutomationStatusStrip (enabled)
Media/Audio/*                     →    file URL          →   MediaLibrary.resolve →   (via regions)
UD echoel.keyRoot/keyScale/a4Hz   →    values            →   SessionContext       →   header A4 field, session names
UD studio.* (@AppStorage)         →    values            →   (the views)          →   header strip, panels
UD mixer.*, trackfx.*             →    values            →   MixerStore/TrackFX   →   Mix panel
UD modulationMatrix.v1            →    ModulationMatrix  →   ModulationEngine     →   Patchbay
UD signalGraph.routes.v1, net.*   →    routes/targets    →   SignalRouter/senders →   Patchbay
(none)                                                   →   PatternEngine/Transport, PianoRollModel, currentPatch, running
```

**Persisted but not restored by Open:**
- timeline, clips, arrangement, automation file, mixer, TrackFX, routing, modulation;
- `lockedBPM` is restored only indirectly (open writes it from `Project.bpm`).

**Restored but not canonical:**
- `SessionContext.keyRoot`/`keyScale` (open writes it, but the selected key is `studio.rootIndex`);
- `pianoRoll.musical*` (derived);
- `Project.drumSteps`/`drumAccents` (restored into a pattern that has no drum voice).

**Runtime truth never persisted:**
- `delaySync`;
- `running`;
- `FXBioModulator` routes;
- `LightingStore` (creative look state);
- metronome settings;
- the live timeline playhead;
- `currentPatch` edits that were not saved as a preset or project.

**UI truth that should not be the persistent owner:**
- the ~13 musical/device `@AppStorage` keys declared inside views (WA1 §F1);
- `currentPatch` as view `@State`;
- `MoodPresetStore` owned as view `@State` (WA1 §F2).

**Oddities, reported and not fixed:**
- The project library file is `projects.json.json`.
- Live Colabo "Save" keeps the sender's project UUID, so it can overwrite a same-id project.
- `ClipStore` resets every slot to nil when the saved array length ≠ 8.

---

## F. Time / transport ownership

- **Clock:** `PatternEngine` is the only clock.
  - It is a main-queue `DispatchSourceTimer` that reschedules itself.
  - It owns tempo, play state, current step, swing and glide.
  - `Transport` mirrors it for its subscribers.
  - Every `Transport.setTempo` call is inside `PatternEngine`. Invariant 3 is **intact**.
- **Tempo writers** (all through `PatternEngine.setTempo/glideTempo(source:)`, whose `source:`
  has no default):
  - user: tap, locked field, project open, lock toggle;
  - flow servo: the `generate` glide;
  - automation: `AutomationPlayer`;
  - remote control: OSC, only when locked;
  - modulation route: dormant.
- **Tempo data home:** none in the song.
  - `Project.bpm` is a scalar.
  - `studio.lockedBPM` is a UserDefaults value.
  - `TempoMap` exists but is only constructed by the uncalled importer.
- **Loop:** there is no Session loop or cycle region.
  - The composer's `studio.loopBars` is how many bars `generate` writes.
  - The timeline player wraps at the document end rounded to bars.
  - The pattern grid is one fixed bar.
- **Metronome:** follows tempo through Transport. Its `beatsPerBar` slider can disagree with the
  fixed 4/4. The downbeat is re-synced only on the generate path. None of its settings are
  persisted.
- **Time signature:** 4/4 is hard-coded in `Transport`, `TimelineTime`, `AutomationPlayer` and
  `AudioClipFactory`. `MeterMap` exists only in the importer.
- **Generator vs timeline:** there is **no mutual exclusion**. Both start the clock only if it is
  idle, and both load `PianoRollModel`.
  - Workstation Stop during a live take ends the whole bio session
    (`TransportTransition.decide` → `.endSession`).
  - A resumed take's evolve loop can overwrite the timeline's roll content.
  - This is the concrete cost of two songs sharing one clock and one note engine.
- **Second clocks:**
  - The metronome's audio-thread sample counter is a follower, not an authority.
  - `SessionEngine`'s 100 ms loop and sample clock never start (parked).
  - Nothing else drives musical time.

**Start (`toggleBiofeedback` → `startBiofeedback`), in order:**
1. breadcrumb;
2. `timelineStore.healRollSlotNamingCause()`;
3. `running = true`;
4. `bus.setInstrumentRunning(true)`;
5. new fallback seed;
6. weather fetch (non-blocking);
7. a Task that runs:
   1. `synth.bioModulationEnabled = true`;
   2. `generate(reason: "start")`. This composes, applies pitch and sound, resolves tempo,
      loads `PianoRollModel`, mirrors into the timeline, glides the tempo, sets swing and ends
      with `pattern.play(.generate)` + `metronome.resync()`;
   3. `startEvolving()`, which re-generates every 25–45 s;
   4. `await startBioSource()` (camera, Polar or demo);
   5. HealthKit notification;
   6. `snapToLockWhenReady()`.

The voices themselves were started at app launch.
- **Verdict:** a **performance bootstrap** that bundles device activation (generator + bio
  modulation) with Session transport start. The bio source starts **after** the sound.
- **Play (▶):** the transport-only control. It appears only while `running`, never starts a
  session and never generates.

---

## G. Track reality

**Echoelmusic has NO canonical Track type.**
- `git grep -n "struct Track\b\|class Track\b" -- Sources` finds none. The hits named "Track*"
  are `TrackFX`/`TrackFXStore`, `TrackInstrument` and a private enum in `BioComposer`.

| Thing | What it actually is |
|---|---|
| `TimelineLane` | the de facto track record: id, name, kind, isBio, level, pan, mute, solo, arm, `builtinInstrument`, `patch`, `genreOverride`, `mood`, `variationSeed`, transpose, detune, octave, sample path. **Only `addLane` and `setLaneTranspose` have production callers**; ~20 setters are unreached |
| `TimelineRegion` | placement of a clip on a lane (start, length, offsets, gain, warp) |
| `Clip` | content (MIDI melody, audio media ref, clip automation) |
| `LaneVoiceRack` (4 slots) + `LaneVoiceKind` | a runtime voice pool indexed by lane rank. A voice container, not a track |
| `TrackInstrument` | persisted lane-instrument enum |
| `MixerStore` | fixed ROLE levels (bass, pad, lead, drums), baked into velocities. Not lanes |
| `TrackFXStore` | fixed BUS inserts (bass, melodic, drums). Every rack slot gets `melodic` |
| `SignalRouter` ports | global endpoints (`bus.bio`, `midi.out`, `audio.master`, `adm.out`, …), none per lane |
| `PerTrackParameterKeyPath` | the only lane-keyed parameter address (`track.<laneID>.<base>`), bound through the rack |
| `SpatialSceneStore` | one object per non-bio lane, rebuilt only by a parked view |

**Minimum Track contract** (INPUT to WA3, not the decision — §O: WA3 defines the minimum
Track/device contract, and `TimelineLane` is its precursor, not the final Track; derived from what
`TimelineLane` already half-holds):
1. **Identity:** stable UUID (the lane id) + name.
2. **Domain:** audio · MIDI/instrument · bio · (later: video, light, spatial object).
3. **Timeline relationship:** owns an ordered set of regions; overlap precedence stays
   `TimelineScheduling.activeRegion` (one definition).
4. **Device chain:** ONE instrument/generator slot (the Echoel device can occupy it), then insert
   devices. Device state lives here, not in view `@State` or global UserDefaults.
5. **Routing:** an output target (master bus now; sends later), expressed as the
   `track.<id>.*` parameter namespace that already exists.
6. **Mixer:** level, pan, mute, solo, arm, owned by the track. The fixed role buses become the
   Echoel device's internal mix.
7. **Automation:** song-absolute lanes addressed by `track.<id>.*`, stored in the Session's
   single automation home.
8. **Media/clips:** references to the clip pool and the asset store, never embedded bytes.
9. **Spatial relationship:** a spatial object derived from the track (as `SpatialSceneStore`
   already does), not stored twice.

---

## H. Automation ownership

| Home | Persisted | Writers | Applied | Nature |
|---|---|---|---|---|
| `AutomationState.lanes` (`Automation/automation`) | yes | **none** (`.adoptLane(`, `.removeLane(`, point edits → 0) | first, per BAR (loops each bar), only if `enabled` | song-level, **competes** with the timeline |
| `TimelineDocument.automation` (`Timeline/timeline`) | yes | **none** (`.addAutomationPoint(` etc. → 0) | last, song-absolute, **wins** | song-level, **canonical candidate** |
| `Clip.automation` (`Clips/clips`) | yes | **none** (`ClipStore.setClipAutomation(id:lanes:)` → 0; `TakeRecorder` path dead) | second, clip-relative | separate domain (clip content) |
| `AutomationPlayer.clipLanes/timelineLanes` | no | players push them | — | **runtime cache** of the two above |
| `ModulationMatrix` (`modulationMatrix.v1`) | yes | Patchbay | own 100 ms loop, last writer wins against automation | live modulation (not song content) |
| `FXBioModulator.routes` | no | FX editor | FX chain | live modulation |
| Recorders (`BioAutomationRecorder`, `AutomationGestureRecorder`) | — | — | — | dormant (nothing arms them) |

**Verdict:**
- Two **competing song-level truths**: the automation file and timeline automation.
- One **separate domain**: clip automation.
- Two **runtime caches**: the player's clip and timeline arrays.
- Two **live-modulation domains**: the matrix and the FX routes. These are not automation.
- **No automation home has a production writer today**, so consolidation cannot lose user-made
  automation EXCEPT what an older build persisted. That is exactly why the "timeline wins"
  import rule carries uncovered player lanes over instead of dropping them.
- The per-bar global lane cannot be expressed song-absolutely without a loop length, which makes
  it a legacy shape.

---

## I. Musical-context ownership

| Value | Homes | Class |
|---|---|---|
| Key root / scale | `studio.rootIndex`/`scale` (selected; saved into `Project`); `SessionContext.keyRoot/keyScale` (naming mirror; `adopt` + `resetMusicalIdentity`) | global Session truth, **DUPLICATED** |
| A4 | `SessionContext.a4Hz` | global Session truth, **ONE OWNER** |
| Tone system | `@AppStorage toneSystemID` | global Session truth (UI-owned) |
| Genre | `studio.genre` | **device-local** (composer input) |
| Mode (Flow/Loop) | `studio.lockBPM` + `lockedBPM` | tempo policy: Loop = Session tempo; Flow = a device SOURCE driving the clock |
| Tempo | see §F | Session truth without a home |
| Time signature | hard-coded 4/4; metronome slider | **UNRESOLVED** |
| Loop length | `studio.loopBars` | **device-local** (composer bars), not a Session loop |
| Mood | `studio.mood` (+ presets) | **device-local** |
| `MusicalFrame` / `pianoRoll.musical*` | derived broadcast | **derived** |
| Detected key/tempo (`AudioKeyAnalysis`) | reported only; writes clip tempo, never key/scale/A4 | **derived, advisory** |

---

## J. Export ownership

| Path | Source | Normalised | Session? |
|---|---|---|---|
| Record tile → `exportWav` → `LoopExporter.exportWav` | stops the pattern, starts `RetroCapture` on the master mixer tap, re-plays `pattern` (`.loopExport`) in real time for `loopBars` + tail, then `SingleExport` | yes (`studio.loudnessTarget`, integrated LUFS) | **current generator take as heard** (the label says "offline render"; it is real-time) |
| Keep last → `exportRecentLoop` | retro ring (≤ 29.5 s) of the master tap | yes | **whatever sounded** |
| MIDI tile → `exportMIDI` | `pianoRoll.arrangementForExport()` (composer bars; no drums) | n/a | **composer take** |
| Visual window WAV | master tap, arbitrary length | yes | **whatever sounded** |
| Project share (`.echoel.json`) | `Project` v1 | n/a | **take snapshot** |

**Verdict:**
- Export is **current-take / live-output export**.
- Timeline audio lanes appear in a WAV only if they happened to be sounding during capture.
- No path renders the canonical arrangement, and none renders offline.
- A Session render is a missing capability, not a bug in an existing path.

---

## K. Collaboration ownership

- **Transport:** MultipeerConnectivity, `serviceType "echoel-colab"`, encryption required.
- **Payload** (`ColabPayload`): `kind` ("session" | "bio"; "tempo" and "chat" are only reserved
  in a comment), `senderName`, `project: Project?`, `bio: BioPeek?`.
- **"session" means a `Project` v1 snapshot.** It is sent reliably on demand. On receive the
  user may **Load** (calls `open()`, which replaces the take after an autosave), **Save** (keeps
  the sender's id) or **Dismiss**.
- **Bio:** readings are sent every 0.4 s, unreliably.
- **Not shared:**
  - no transport or clock sync (Ableton Link is a separate, unbuilt step);
  - no parameter events, clips, timeline or media;
  - no device state beyond the patch inside `Project`;
  - no Session.
- `onReceiveSession` is declared and never assigned.
- **Verdict:** snapshot exchange + bio telemetry. **Not a distributed session**, and it must not
  be described as one.

---

## L. Timeline vs Arrangement assessment

| Question | `TimelineDocument` / `TimelineStore` | `Arrangement` / `ArrangementStore` |
|---|---|---|
| Real writers | **yes**: imports, add track, warp, pitch, composer mirror | **none** |
| Playback semantics | **yes**: `TimelineRegionPlayer` + `AudioLanePlayer`, overlap precedence, audio warp, per-lane voices, song automation | `ArrangementPlayer` exists; `play` has **0 callers** |
| Editing APIs | many (move, trim, split, merge, combine, undo/redo, automation points); **0 callers** | section add/move/length/rename/clip; **0 callers** |
| Persisted | yes (`Timeline/timeline`, schema 1) | yes (`Arrangement/song`, schema 1) |
| Reachable | yes (Workstation chip) | no |
| Worth porting | — (it is the base) | **`ArrangementCursor.completeBar`** (pure section-chain sequencer with loop/finish/seek) and `ArrangementPlayer`'s bar-wrap section swap: the only song-form/scene sequencing core in the repo |

- **Timeline:** CANONICAL.
- **Arrangement:** a **future PROJECTION**, for sections and scenes over the Session. Its
  algorithm is PORT ALGORITHM; its store and file are LEGACY and are **not deleted**.
- Invariant 4 (no consolidation without a Founder decision) stays in force until the Founder
  answers §O.

**ClipStore:**
- **Identity is the Clip UUID.** The slot index fixes only storage position and colour, and
  regions reference `clipID` only.
- **Capacity is 8 fixed slots.** When full: imports fail with `.clipGridFull`, the composer
  mirror is skipped, and nothing is evicted. A saved array of the wrong length resets all slots.
- **Relation to TimelineRegion:** many regions may share one clip (`duplicated()` keeps
  `clipID`). Per-use state lives on the region (offset, gain, warp).
- **Relation to imported audio:** each import copies the file into `Media/Audio` under a unique
  name and creates one `Clip` whose `mediaRef` is the managed path. Importing the same file twice
  gives two copies and two clips.
- **Overloading: yes.** `Clip` is simultaneously the source-media record (path, native duration,
  native BPM) and creative content (melody, clip automation, composer ownership). A future
  `MediaAsset` (source identity, deduplication, file metadata) remains **justified**. It is
  **not** introduced here.

---

## M. Canonical Session proposal (ONE model)

Derived from what the repository already built, not from a template:
- the envelope from #1416/#1419;
- the timeline from the DAW phase;
- the lane fields that already carry device state;
- `SessionContext` as the one existing A4 home.

```
Session  ≙  DMMWProject envelope  (the type already in Core/DMMWProject.swift)
│           stored as the payload of the EXISTING ProjectStore root — no new root, no new store
├── meta            id · name · artist · savedAt
├── timebase        TempoMap · MeterMap · ppq          ← the ONE tempo/meter home; PatternEngine EXECUTES it
├── musical         key · scale · A4 · tone system     ← runtime owner: SessionContext (widened), views project it
├── content
│   ├── timeline    TimelineDocument                   ← CANONICAL linear spine: lanes (Track PRECURSOR — WA3 defines Track), regions, song automation
│   ├── clipSlots   ClipStore pool                     ← content referenced by regions; media by reference (MediaLibrary)
│   └── songForm    Arrangement                        ← preserved; future song-form/sections/scenes = PROJECTION over the timeline
├── devices         device instances + state per track  ← today's envelope `sound` {patch, fxCharacter} + genre, mood,
│                                                        loopBars, mixer roles, TrackFX, AND the device's own modulation matrix
├── routing         logical source/destination assignments (creative routing only)
├── domains         visual · video · lighting creative state · SpatialScene (looks, automation, assignments, positions)
├── assets          references to media (ClipStore/MediaLibrary today; no MediaAsset yet)
├── collaboration   identity · permissions · provenance · collaboration metadata
├── automation      = content.timeline.automation (song) + Clip.automation (clip)   ← playerAutomation imported, never written
└── legacy          Project v1 notes / rawTake / drumSteps / loopBars             ← importer-only, read once

OUTSIDE the Session (app / system settings and adapters):
  PatchStore · FXPresetStore · MoodPresetStore (libraries) · global modulation DEFAULTS · system/endpoint I/O
  config (net.*, discovered hardware, addresses, credentials, Dante/AES67/NMOS, external services) ·
  MultipeerSession (replication ADAPTER, never a second Session owner) · SessionEngine/SessionRecorder (parked bio log)
RUNTIME (derived, never persisted as truth):
  PatternEngine + Transport (the ONE clock) · TimelineRegionPlayer/AudioLanePlayer/AutomationPlayer (executors;
  AutomationPlayer arrays are caches/projections) · PianoRollModel (the Echoel device's note engine) · MusicalFrame
  · live Flow/Bio tempo (a ControlSource; reaches the TempoMap only through an explicit Capture/Record/Commit)
```

**The five modes are projections of this one object:**
- **Arrange** is the timeline.
- **Session** will be scenes derived from `songForm`/clip slots.
- **Perform** is the Echoel device's live surfaces writing into its track.
- **Immerse** is the spatial and visual projections of the tracks.
- **Broadcast** is an adapter.

None of them owns a document.

**Owner by owner:**

| Proposed owner | WHY | MIGRATION COST | RISKS | WHAT SURVIVES | WHAT BECOMES A PROJECTION | MUST NOT BE DELETED YET |
|---|---|---|---|---|---|---|
| **Session = `DMMWProject` in `ProjectStore`** | the only type that already binds all five song roots; importer written and tested; reuses an existing root (invariant 5) | a writer (save → envelope), a reader (open → envelope → stores), a v1→envelope import on first open; medium | double-extension file name; the Colabo same-id save; a half-migrated library | every saved `Project` (imported, not converted in place) | `Project` v1 (becomes import source) | `Project` decoder, `projects.json.json`, `DMMWProjectImport` |
| **Content spine = `TimelineDocument`** | only song model with writers, playback, persistence and a door | open/save must now include it; the composer mirror becomes the primary write path | the generator and timeline share one note engine and one clock (§F), which must be resolved first | the timeline file and all its APIs | `Arrangement` (sections/scenes later) | `ArrangementStore`, `Arrangement/song`, `ArrangementPlayer`, `bootstrapIfNeeded` |
| **Tempo/meter/loop = `timebase` (TempoMap · MeterMap · Session loop)**; clock = `PatternEngine` | one tempo home; invariant 3 unchanged | `setTempo(source:)` callers keep working; the TempoMap changes only by Session edits or an explicit Capture/Record/Commit | DECIDED (§O): live Flow/Bio tempo is a ControlSource and never mutates the TempoMap automatically | `PatternEngine`, `Transport`, T1–T3 | `studio.lockedBPM`, `Project.bpm` | `studio.lockBPM/lockedBPM` keys (OSC and UI read them) |
| **Musical context = `SessionContext`** | already persists A4 and key; already the naming owner | move "selected" key/scale/tone off `@AppStorage` into it; views read it | the ~13 view-declared keys and the OSC dispatch write the old keys | `SessionContext` keys | `studio.rootIndex/scale/toneSystemID` | those keys (SoundReset, OSC, 3+ views) |
| **Automation = Session-owned persistent automation (timeline song automation converges into it) + clip-relative automation (separate scope)** | the timeline already wins at runtime; clip automation is a real separate domain | nothing migrates now; later, uncovered player lanes import once ("timeline wins") | per-bar player lanes have no song-absolute equivalent without a loop length | both homes | `AutomationPlayer.lanes` (legacy import source) | the `Automation/automation` file |
| **Tracks: defined by WA3; `TimelineLane` is the strongest precursor and migration source** (DECIDED §O — not grown in place into the final Track) | already the only per-track record and already keyed for parameters | WA3 names the minimum Track/device contract; lane data migrates into it | fixed role buses and the 4-slot rack assume ≤4 voices | lanes, `PerTrackParameterKeyPath` | `MixerStore` roles → the Echoel device's internal mix | `MixerStore`, `TrackFXStore` |
| **Echoel = a device on a track** | WA1 §D: the device half never writes song stores; the lane already has `patch`/`genreOverride`/`mood`/`variationSeed` | the device's take becomes region content on its track; `loopBars`, genre, mood, patch, FX character move under the device | Start/▶ semantics (decided §O: START = device activation, ▶ = Session transport); `PianoRollModel` is shared with timeline playback | `PianoRollModel` as the device note engine | the `Project` take (notes/rawTake) | `PianoRollModel`, `Project.notes/rawTake` |

**Rejected alternatives (named, not recommended):**
1. **A new `SessionStore` over all stores.** It adds a 13th persistence root, violating
   invariant 5 and this slice's rule, and duplicates the envelope that already exists.
2. **`Project` v1 widened with timeline, clip and automation fields.** It grows the flattened
   copy instead of the envelope and keeps two schemas for one song.
3. **`Arrangement` as the canonical song.** It has zero writers, zero playback and no door; it
   would invert the only live model.
4. **The instrument take (`PianoRollModel` + `Project`) as the canonical Session with the
   timeline as a view.** It cannot hold audio lanes, imports, warp or per-lane voices, all of
   which are live today.

---

## N. Migration boundaries

These are for a later phase. **None of this happens in WA2**, and the WA2 approval does not
authorize any of it: each step is its own Founder-approved slice, and WA3 comes first.

1. **Before any writer:**
   - Resolve generator-vs-timeline clock and note-engine sharing (§F).
   - Pin `TimelineDocument` + `ClipStore` + automation round-trip through the envelope with
     guards (#1419 already pins the importer).
2. **Writer second:**
   - Save writes the envelope into `ProjectStore`.
   - v1 entries are read through `DMMWProjectImport`, never rewritten in place.
3. **Open restores the Session:**
   - timeline, clips and automation first;
   - then musical context;
   - then device state.
   - The five working files remain the working copy of the open Session.
4. **Single-home moves, one at a time:**
   - tempo into `timebase`;
   - key/scale/tone into `SessionContext`;
   - player automation lanes → import only.
5. **Echoel as a track device:** its state moves under a lane. `loopBars` becomes a device
   parameter; the Session loop is a separate, new concept.
6. **Only after all of the above is proven on real devices:** consider retiring `Arrangement`
   into a sections/scenes projection.

**Hard boundaries in every step:**
- no deletion of a persisted file or decoder while any build that wrote it may still be
  installed (#527 lesson);
- no second clock;
- no new persistence root without a Founder decision;
- the audio-thread and hot-state laws.

---

## O. Founder decision — APPROVED WITH BINDING AMENDMENTS (2026-09-24)

**The Founder approved the §M package with binding amendments. They overwrite the defaults this
document proposed for its five holds** (those defaults — "Flow tempo: live source only, Loop
mode writes the map", "modulation matrix: app setting until WA3", "lighting creative state: not
now, stays runtime", "tracks = `TimelineLane` grown to the §G contract" — are withdrawn, not
kept as alternatives). Nothing below is implemented; it is the target every later slice is
measured against. Decision row: `decisions.csv` 2026-09-24.

### O1. CURRENT REALITY vs APPROVED TARGET OWNERSHIP

| Area | CURRENT REALITY (measured §A–§L) | APPROVED TARGET OWNERSHIP |
|---|---|---|
| Session root | no single song: timeline has the writers, `Project` v1 + `PianoRollModel` is what is saved/opened/exported/shared; `DMMWProject` has 0 callers | **`DMMWProject` is the ONE canonical Session root**, stored in the existing `ProjectStore`. No new SessionStore, no new persistence root. **Not schema-frozen** — later migration design is expected. `Project` v1 stays a legacy take/import source |
| Session contents | spread over 12 roots | metadata · Timebase · MusicalContext · Tracks · `TimelineDocument` · clip/media relationships · automation · device instances/state · logical routing · visual/video/lighting creative state · SpatialScene · assets/references · collaboration metadata/provenance · legacy migration payload. **Fields are not implemented in this slice** |
| Clock | `PatternEngine` is the only clock, `Transport` relays | unchanged: **`PatternEngine` stays the ONE clock/runtime executor** |
| Tempo · meter · loop | tempo in `studio.lockedBPM`/`Project.bpm`; 4/4 hard-coded; three unrelated loop meanings | **Session `Timebase` owns TempoMap, MeterMap and the Session loop** |
| Flow / Bio tempo | the body servo sets the live tempo directly | **a ControlSource. It never mutates the TempoMap automatically**; only an explicit Capture/Record/Commit turns it into Session automation or TempoMap data. Not implemented |
| Start vs ▶ | one Start arms bio + generator + transport | **START/ACTIVATE = device/performance activation; PLAY ▶ = the canonical Session transport.** Current behaviour unchanged |
| Track | no Track type; `TimelineLane` is the de-facto track | **`TimelineLane` is NOT the final Track** — it is the strongest precursor and migration source. **WA3 defines the minimum Track/device contract.** No Track type is created before that |
| Linear content | `TimelineDocument` (writers, playback, door) | **`TimelineDocument` is the canonical linear content/timeline spine** |
| Arrangement | 0 writers, `ArrangementPlayer.play` 0 callers | **a future song-form / sections / scene PROJECTION.** `ArrangementStore` and its format are preserved — not consolidated, not deleted |
| Automation | three homes (automation file, `TimelineDocument.automation`, `Clip.automation`), no production writers; runtime order timeline > clip > global | **the canonical Session owns persistent automation**; timeline song automation converges toward it; **clip-relative automation is a valid separate scope**; `AutomationPlayer` runtime arrays are caches/projections. Nothing migrates now |
| Modulation | `ModulationMatrix` persisted as a global app preference | **the concrete matrix of a native Echoel Device is creative device/Session state and will persist with that device instance.** Global defaults may stay app preferences. UserDefaults are not migrated now |
| Musical context | key/scale duplicated (`studio.*` selected, `SessionContext` naming mirror); A4 owned by `SessionContext` | **Session-level: key, scale, A4/tuning, tone system, time signature/MeterMap.** Device-local context may derive from it; genre, mood and generative-phrase settings may stay device-local. Storage not migrated now |
| Lighting · visual · spatial · video | lighting look is runtime; spatial scene in its own store; video absent | **their CREATIVE state belongs to the Session** (look, automation, track/light assignments, spatial positions, visual composition, video edit/composition). **Outside the Session:** discovered hardware, network addresses, credentials, Dante/AES67/NMOS infrastructure, external service config |
| Routing | `SignalRouter` + `net.*` app settings | **creative routing (logical source/destination assignments) is Session truth**; system/endpoint configuration is not |
| Collaboration | Live Colabo sends a `Project` v1 snapshot + bio every 0.4 s; no sync | **the runtime is an adapter/replication layer.** The Session owns shared creative state plus identity, permissions, provenance and collaboration metadata. The transport is never a second Session owner |
| ClipStore | 8 slots | **the 8 slots stay for compatibility; they are NOT a future capacity limit.** No `MediaAsset` yet |
| Export | "take as heard": real-time master-tap WAV + composer-bar MIDI | **future MAIN EXPORT renders/bounces the canonical Session.** Today's take export stays valid and later becomes an explicit take/device/performance capture or bounce path. Export code unchanged |

### O2. What this decision does NOT authorize

- no production Swift, test, persistence-format, UserDefaults or workflow change;
- no Track type, no Session fields, no migration, no consolidation of `ArrangementStore`;
- no workstation UI (WA4 is blocked on WA3);
- no renaming of `SessionView`/`SessionEngine` or any other production type.

### O3. Next

**WA3 — Native Device Architecture** designs the Echoel device and the minimum Track/device
contract against this target: parameters, state, presets, the device-instance modulation matrix,
device-local context derived from the Session, bio as a ControlSource, outputs, and the same core
behind the native and AUv3 adapters. Invariant 4 of the master plan now carries this decision.

---

**Stale sources found and not edited:**
- `WorkspaceView.swift` and `EchoelmusicApp.swift` comments still say the timeline player has
  no production caller; that has been false since #1437.
- `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md` §2.1 says "the player reads the first
  (automation file)"; it also plays timeline automation, last.
- `PatternEngine.PlayCause.loopExport` is described as an "offline render" and is real-time.
- ~~The master plan names `scratchpads/` paths for the WA1 and WA2 outputs.~~ Fixed in the WA2
  decision-lock commit.

*Maintenance:* evidence dated 2026-09-24. Re-measure with the commands named above; do not
update numbers in place without re-running them.
