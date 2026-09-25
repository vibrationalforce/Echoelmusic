# ECHOELMUSIC MASTER PLAN — the canonical roadmap and control document

**Status: CANONICAL for SEQUENCE and STATUS.** Created 2026-09-24 at `main` = `7b2690357`.

This is the one roadmap. It is the bridge between four things:

| Question | Answered by |
|---|---|
| What is Echoelmusic? (scope, law) | [`FOUNDER_PRODUCT_LAW.md`](FOUNDER_PRODUCT_LAW.md) — outranks this file |
| What existed, did it work, may it come back? | [`HISTORY_ARCHIVE.md`](HISTORY_ARCHIVE.md) |
| What ships and is reachable today? | [`FEATURE_STATUS.md`](FEATURE_STATUS.md) |
| **In what order do we build, and what state is each item in?** | **this file** |

⚠️ **Scope is not a claim.** This file names the destination and the order of work. It does
not say that anything ships. Public copy (App Store, website, content) claims only what
`FEATURE_STATUS.md` and `ContentPipeline/CLAIMS.md` allow. App Store wording stays with the
Founder.

⚠️ **One roadmap only.** Older sequencing documents are history as far as ORDER is concerned:
`ROADMAP.md` (2026-06-19; since the WA2 decision lock bannered as subordinate to the law and to this file),
`ARCHITECTURE_NORTH_STAR.md`, `DMMW_ARCHITECTURE.md` and the `scratchpads/PLAN_*` files. They
remain useful as evidence. Where they disagree with this file about order or status, this file
wins. Where this file disagrees with `FOUNDER_PRODUCT_LAW.md`, the law wins.

---

## 1. Product North Star

**Echoelmusic is a full professional Distributed Multidimensional Multimedia Workstation
(DMMW).**

Its destination is to create, record, edit, mix, grade, compose, perform, spatialize, stream and
publish all of the following natively, inside **one canonical Session**:

- audio
- music
- MIDI and MPE
- video
- visuals
- lighting
- spatial / XR
- bio and motion
- collaboration
- broadcast

> **OWN THE COMPLETE CREATIVE WORKFLOW. INTEGRATE THE COMPLETE PROFESSIONAL ECOSYSTEM.**

Owning the workflow does NOT mean rebuilding specialist infrastructure: codecs, Dante, NDI,
CDNs and plugin SDKs are integrated, not rebuilt (law §1).

**The historical "pure instrument" product restriction is not restored** (2026-07-25 →
2026-09-24; law §2). Historical deletions revoked IMPLEMENTATIONS. Their engineering warnings
stay binding. Their scope verdicts do not.

The bio-reactive instrument remains Echoel's differentiator and the first shipping surface. It
is not the product boundary.

---

## 2. Canonical product model

This is the target model. **Nothing in this section is implemented as described.** It is the
vocabulary WA1–WA4 are measured against.

```
WORKSTATION
  → Session            one canonical document; the only owner of song state
  → Tracks             audio · MIDI · instrument · visual · light · spatial · bio · video
  → Arrangement        linear time (the timeline projection of the Session)
  → Session / Scenes   non-linear launch (the clip/scene projection of the SAME Session)
  → Mixer              buses, sends, master
  → Automation         one automation home per parameter
  → Domains            audio · MIDI · video · visual · light · spatial · bio · collab · broadcast

DEVICE LAYER           (things that live ON a track)
  → Instruments        e.g. the Echoel instrument, synths, samplers, drums
  → Effects            e.g. the EchoelFXChain stages
  → Generators         visual, light and pattern generators
  → Analyzers          meters, key/tempo detection, spectrum
  → Utilities          routing, gain, MIDI tools

ENGINE LAYER           (things devices are built on)
  → DSP                Foundation + Accelerate, realtime-safe
  → MIDI/MPE           event model, I/O, MIDI 2.0
  → Parameters         registry, binding, eligibility
  → Modulation         ModulationEngine / matrix
  → Bio / Motion       measured signal → quality → feature → consent → ControlSource
  → AI                 offline or assistive only; never in a realtime callback
```

**The current Echoel experience is a CANDIDATE first-class native Echoel instrument/device
inside the larger workstation.** That experience is `EchoelStudioView` plus its engine: the
bio-generative composer, the voices, the FX character and the visual field. It is not meant
to stay the permanent whole-app shell. **Status: IDEA.** WA3 decides how the move happens.
Nothing moves before WA1–WA3.

---

## 3. Architecture invariants

These hold for every slice. Breaking one needs an explicit Founder decision recorded in
`decisions.csv`.

1. **One canonical Session.** There is never a second document that owns song state. Since the
   WA2 decision (2026-09-24) that Session is **`DMMWProject`** in the existing `ProjectStore`
   (`SESSION_OWNERSHIP_CENSUS.md` §O). ⚠️ *Canonical Session* ≠ the historical `SessionView`/
   `SessionEngine` breathing experiment; no production type is renamed.
2. **No second transport truth.** One clock, one play state, one tempo.
3. **`PatternEngine` stays the musical clock authority** unless the Founder changes it. Every
   production `Transport.setTempo` call is made inside `PatternEngine`; every other tempo
   writer goes through `PatternEngine.setTempo(_:source:)`. Measure it with
   `git grep -n "\.setTempo(" -- Sources`. The tempo invariants T1–T3 in `CLAUDE.md` apply,
   and `TempoInvariantTests` is their law.
4. **`TimelineStore`/`TimelineDocument` and `Arrangement`/`ArrangementStore` are NOT
   consolidated.** Decided in WA2: `TimelineDocument` is the canonical linear spine,
   `Arrangement` a future song-form/sections/scene projection, and `ArrangementStore` with its
   format is preserved. Any migration toward that target is its own Founder-approved slice.
5. **No new persistence root** without a Founder decision. Twelve roots exist today; see
   `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md`.
6. **Realtime callbacks** (render blocks, taps, AUv3 `internalRenderBlock`) contain no locks,
   no allocations, no actor hops, no UI observation and no AI.
7. **AI never runs in a realtime callback.**
8. **Parameter eligibility is four separate facts:** registered ≠ bound ≠ `automationEligible`
   ≠ `modulationEligible`. Never infer one from another; see `EchoelParameterRegistry`,
   `ParameterApplyRouter` and P2 Proof #1.1.
9. **External specialist systems are adapters or capability endpoints**, never competing
   Session owners. This covers other DAWs, lighting desks, spatial renderers, broadcast tools,
   CMS/DAM systems and AI providers.
10. **Plugin-format logic never lives inside instrument DSP.** DSP compiles in isolation
    (`DSP/` imports Foundation and Accelerate only; the AUv3 target builds it alone).
11. **AUv3/plugin render behaviour is independent of standalone export mastering policy.** The
    E1–E3 export normalisation belongs to `SingleExport`. It never runs inside a plugin render.
12. **The UI engineering laws are unchanged:**
    - the black-screen modifier-chain law;
    - the hot-state leaf law;
    - `EchoelValueField` for numeric parameters;
    - the Uncodixfy constraints;
    - the 3 Hz flash ceiling.
13. **Bio law:** measured signal → quality/confidence → derived feature → consent/privacy →
    ControlSource. No healing, organ, consciousness or medical claims (law §4).

---

## 4. Status vocabulary

Every item in this file carries statuses from exactly this list. **The words are never
collapsed.** "Compiles" is not "tested", and "tested" is not "device verified".

| Status | Means | Evidence required |
|---|---|---|
| **IDEA** | wanted, no agreed design | a sentence in this file |
| **PLANNED** | design or slice definition exists | a plan or census file |
| **IN PROGRESS** | code is being written on the branch | commits exist |
| **IMPLEMENTED** | the code for the capability exists | file path(s) |
| **COMPILES** | `Xcode Compile Check` (Sources) and CI/CD `Build for Testing` (test bundle) are green | run IDs or `main` advanced by auto-merge |
| **TESTED** | a guard's execution is observed passing (its name in a run log), or it is proven by a local run | log line; *"kompiliert nachweislich, Ausführung unbelegt"* when the name is absent (#445/#807) |
| **DEVICE VERIFIED** | observed on physical hardware, with a date | founder report, `VERIFIED-YYYY-MM-DD` marker |
| **INDEPENDENTLY REVIEWED** | a reviewer who did not build it passed it | review verdict |
| **CLOSED** | Founder/orchestrator closed the slice; reopening needs a measured regression | closure note |

⚠️ **CLOSED is a process state, not an evidence state.** A slice can be CLOSED with an open
device obligation. When that happens, the obligation is listed in §9 and does not reopen the
slice.

---

## 5. Current verified state

### 5.1 Export-quality foundation — E1 · E2 · E3

| Slice | What it guarantees | Implementation | COMPILES | TESTED | DEVICE VERIFIED | INDEPENDENTLY REVIEWED | State |
|---|---|---|---|---|---|---|---|
| **E1 — Peak Safety** | a positive normalisation gain never pushes the finite source sample peak above −1 dBFS; one scalar, no limiter | `d71eb2936` | yes | compiled; execution not shown in the log window (#445) | no | PASS | **CLOSED** |
| **E2 — Integrated Loudness** | export gain comes from gated BS.1770 integrated loudness (the one meter); undefined loudness → 0 dB | `ad356e10b` | yes | compiled; execution not shown in the log window | no | PASS | **CLOSED** |
| **E3 — Sample-Rate-Correct Loudness** | K-weighting derived per rate (44.1–192 kHz); unsupported rates read no value; one analysis decode | `2e6b54d66` + `7b2690357` (final) | yes | compiled; execution not shown in the log window | no | PASS WITH DEVICE-VERIFY CONDITION | **CLOSED — device obligation in §9** |

E1–E3 are not reopened unless a measurement shows a regression.

**Honest claim ceiling for E1–E3:** sample-rate-correct BS.1770-style stereo integrated loudness,
with sample-peak-safe normalisation, for the supported rates. None of the following are claimed:
- full EBU R128 conformance;
- true peak;
- codec-safe AAC output;
- every rate.

### 5.2 Workstation-relevant state today

Detail and device status: `FEATURE_STATUS.md` §1. Owners: `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md`.

| Area | Status | Evidence / note |
|---|---|---|
| Bio-generative instrument (`EchoelStudioView`, composer, voices, FX, field) | IMPLEMENTED · COMPILES · shipping on TestFlight | Ship-gate checks 1 (sound) and 5 (stability) are founder/device checks |
| Workstation chip (`Studio/WorkstationView.swift`) | IMPLEMENTED · COMPILES; import + play **DEVICE VERIFIED 2026-09-23** | Audio and MIDI tracks, audio/MIDI file import, play via `TimelineRegionPlayer`, key/tempo detection, warp, pitch per track |
| Timeline document (`Core/TimelineStore.swift`, `Sequencer/Timeline.swift`) | IMPLEMENTED | Persisted; played by the Workstation |
| Arrangement (`Core/ArrangementStore.swift`, `Sequencer/Arrangement.swift`) | IMPLEMENTED (model) | Separate persistence root; DECIDED in WA2: a future song-form/sections/scene projection over the timeline, store and format preserved |
| Clips (`Core/ClipStore.swift`) | IMPLEMENTED (model) | Written by audio import |
| Project envelope (`Core/DMMWProject.swift`, `DMMWProjectImport.swift`) | IMPLEMENTED (M2) | Wraps the song roots; reader/importer exists |
| Timebase (`Core/TempoMap.swift`) | IMPLEMENTED (M1) | EchoelCore target is founder-gated (#95) |
| Canonical Session (`DMMWProject`) | **DECIDED (WA2)** · envelope + importer IMPLEMENTED (M2), 0 callers | Target ownership: `SESSION_OWNERSHIP_CENSUS.md` §O |
| Session / Scenes (clip launch) | **IDEA** | No scene type exists in `Sources/` |
| Automation | IMPLEMENTED (player); **no editor** | Two homes of `[AutomationLane]` (`automation` + `timeline`), see the roots plan §2.1 |
| Parameters (`Core/EchoelParameterRegistry.swift`, `ParameterApplyRouter.swift`) | IMPLEMENTED · COMPILES | Eligibility split per invariant 8 |
| Modulation matrix (`Core/ModulationEngine.swift`) | IMPLEMENTED · reachable (Routing → "Body → parameter") | Not device verified |
| Undo / redo | **IDEA** | None anywhere (HISTORY_ARCHIVE D6) |
| Note editing / piano roll | **IDEA** (view deleted #475; `PianoRollModel` kept) | Capability is scope (law §2) |
| Recording / audio input | **IDEA** (implementation revoked #1302) | Engineering warnings stand; see law §2 |
| Video | **IDEA** (implementation revoked #1304) | Integrate codecs; never rebuild them |
| Lighting (Art-Net, sACN unicast) | IMPLEMENTED · COMPILES | `look.intensity` goes through the canonical parameter path (P2 Proof #1) |
| Spatial: ADM-OSC control out | IMPLEMENTED | Render cores exist but have no caller (CLAUDE.md register) |
| XR / visionOS | **IDEA** | No target |
| Motion as a bio source | **IDEA** | No producer (`ModulationMatrix.hasProducer(.motion)` is false) |
| Collaboration (Live Colabo) | IMPLEMENTED | Two-phone probe open (#113) |
| Broadcast / streaming | **IDEA** | HaishinKit is not linked; `BroadcastPublisher` is a compile guard |
| AI (`EchoelAI`, registry/tool core) | IMPLEMENTED core, **no caller** | `FeatureFlags.echoelAI` has zero readers |
| AUv3 instrument (`Sources/EchoelmusicAUv3`) | IMPLEMENTED · **DEVICE VERIFIED in AUM 2026-09-20** | Other hosts are not verified |
| Plugin hosting (AUv3/VST3/CLAP) | **IDEA** | Hosting removed with #121 Slice 2 |

---

## 6. Phases

| Phase | Content | State |
|---|---|---|
| **PHASE 1 — Foundation & truth** | the shipping instrument; product law R1–R3; export quality E1–E3; Workstation chip with import/play | CLOSED as a phase (items carry their own statuses above) |
| **PHASE 2 — WORKSTATION ARCHITECTURE** | WA1 → WA2 → WA3 → WA4 (§7) | **CURRENT** — WA1 and WA2 COMPLETE; WA3 APPROVED (WA3.1 CLOSED, WA3.2 IMPLEMENTED, slice 2 IMPLEMENTED); WA4 IMPLEMENTED 2026-09-25 (items 1–9; Arm absent by design, no record path) — compile gates QUEUED for everything after `5bdcd2b`, device journey owed (§2c) |
| PHASE 3 — Domain recovery | recording/input, note editing, automation editing, undo, video, broadcast, hosting, etc., each through the recovery principle (law §5) into the WA2 owners | PLANNED — order decided by the Founder after WA2 |

**Phase 2 is architecture, not UI construction.** No workstation UI is built until WA1–WA3 are
done. WA4 is the first front.

---

## 7. Next four slices — in this exact order

### WA1 — Workstation / UI Ownership Census

- **Mode:** READ-ONLY. No code, no tests, no CI changes.
- **Task:** classify every major current UI surface into exactly one of:
  - **WORKSTATION** — Session-level surfaces (tracks, arrangement, mixer, transport, project);
  - **DEVICE** — belongs on a track as an instrument, effect, generator, analyzer or utility;
  - **DOMAIN TOOL** — a domain-specific editor or output (light, spatial, visual, bio source);
  - **PERFORMANCE** — live playing/controlling surfaces;
  - **LEGACY / PARK** — doorless or superseded, kept on purpose.
- **Inputs:**
  - `EchoelStudioView` and its chips/panels;
  - `WorkspaceView` chrome;
  - `WorkstationView`;
  - `PatchbayView`;
  - `EchoelFXView`;
  - `FloatingVisualWindow` / `VisualAnalysisLayer`;
  - `ImmersiveStageView`;
  - `BioSourceView`;
  - `SessionView`;
  - `BroadcastView`;
  - `ProUnlockView`;
  - the AUv3 UI;
  - the doorless list in `FEATURE_STATUS.md` §2 and `python3 scripts/doctor.py --section C`.
- **Record per surface:**
  - its door (or "no door");
  - the models it writes as the ONLY writer;
  - the hot state it reads;
  - its share of the modal budget.
- **Output:** [`WORKSTATION_UI_OWNERSHIP_CENSUS.md`](WORKSTATION_UI_OWNERSHIP_CENSUS.md)
  (evidence, not a roadmap). ⛔ The path planned here was `scratchpads/CENSUS_W1_UI_OWNERSHIP.md`.
- **Done when:** every surface has one class, each with a file path and a measured door.
- **Status:** **COMPLETE** (`c2fad0a0a`, 2026-09-24). Its 13 "NEEDS WA2 DECISION" rows are
  answered by the WA2 decision below.

### WA2 — Session Ownership Census + Founder Decision

- **Mode:** READ-ONLY FIRST. It ends in a Founder decision; there is no consolidation before it.
- **Trace:**
  - `TimelineDocument`/`TimelineStore`;
  - `Arrangement`/`ArrangementStore`;
  - `ClipStore`;
  - `PatternEngine` + `Transport`;
  - scenes / session launch (currently none);
  - tracks (`TimelineLane`, lane voice rack);
  - `AutomationPlayer` and the second automation home in the timeline;
  - `DMMWProject`.
- **Answer for each item:**
  - who writes it;
  - who reads it;
  - who plays it;
  - what is persisted where;
  - where two truths exist today.
- **Then:** propose ONE canonical ownership model — a Session that both Arrangement and Scenes
  project. Include a migration outline and the decision the Founder must make.
- **Prior art to start from:**
  - `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md` (12 roots, 3 overlaps);
  - `scratchpads/AUDIT_DMMW_RECONCILIATION_2026-09-21.md`;
  - `Tests/CISmoke/TheWorkstationPlaysTheTimelineTests.swift`.
- **Output:** [`SESSION_OWNERSHIP_CENSUS.md`](SESSION_OWNERSHIP_CENSUS.md) + a `decisions.csv`
  row. ⛔ The path planned here was `scratchpads/CENSUS_W2_SESSION_OWNERSHIP.md`.
- **Done when:** the Founder has chosen the ownership model.
- **Status:** **COMPLETE** — census `a52170ca5`; Founder decision **APPROVED WITH BINDING
  AMENDMENTS** 2026-09-24, recorded in §O of the census (CURRENT REALITY vs APPROVED TARGET).
  In short: `DMMWProject` is the one Session root (not schema-frozen); `PatternEngine` stays the
  one clock and the Session `Timebase` owns TempoMap/MeterMap/loop; live Flow/Bio tempo is a
  ControlSource that reaches the TempoMap only by explicit commit; START = device activation,
  ▶ = Session transport; `TimelineLane` is the Track precursor; `TimelineDocument` is the linear
  spine and `Arrangement` a future projection; the Session owns persistent automation, device
  modulation, creative routing, domain creative state and collaboration metadata; ClipStore's 8
  slots are compatibility only; future main export bounces the Session. **Nothing implemented.**

### WA3 — Native Device Architecture

- **Task:** define how the current Echoel environment becomes a first-class native
  instrument/device inside the workstation. That environment is:
  - the composer;
  - the voices;
  - FX character;
  - the bio routing;
  - the field.
- **Define:**
  - the device contract: parameters, state, presets;
  - the event input (MIDI/MPE, bio ControlSource);
  - the audio/visual/light outputs;
  - the per-track instancing question;
  - how the same device core feeds the native DMMW adapter and the AUv3 adapter.
- **Bound by WA2:**
  - define the **minimum Track/device contract** (`TimelineLane` is precursor and migration
    source, not the final Track; no Track type exists until WA3 designs it);
  - the device's concrete modulation matrix is device-instance state that persists with the
    device in the Session (global defaults may stay app preferences);
  - device-local context (genre, mood, generative phrase) derives from the Session musical
    context (key, scale, A4/tuning, tone system, MeterMap);
  - bio and Flow tempo enter as ControlSources; START activates the device, ▶ is the Session
    transport.
- **Hard rule:** no plugin-format-specific coupling in DSP (invariants 10–11).
- **Output:** a design document plus a `decisions.csv` row. Code only as separately approved slices.
- **Status:** **APPROVED** — design `docs/dev/NATIVE_DEVICE_ARCHITECTURE.md` (`59a243958`).
  Code arrives only as separately approved slices:
  - **WA3.1 — AUv3 bio state privacy: CLOSED.** `87d829f42`; COMPILES (both gates green, `main`
    advanced); independent review PASS WITH HOST VERIFICATION. Host obligation in §9.
  - **WA3.2 — canonical parameter identity + AUv3 adapter mapping + minimal
    `EchoelDeviceState`: IMPLEMENTED** (`DSP/ParameterDescriptor.swift`,
    `DSP/EchoelBodyVibeDevice.swift`; the AUv3 tree is built from the mapping; guard
    `TheParameterIdentityIsFormatNeutralTests`). **COMPILES** at `be17d968b` (Xcode Compile Check
    run 36047320605 success, AUv3 embedded; CI/CD `Build for Testing` success, run 36047320600;
    `main` advanced). Not TESTED: Run Tests ended `TEST EXECUTE FAILED` (#396) and the
    `tail -200` window does not show the new guard (#807). `EchoelDeviceState` has no production caller; instance addressing is a
    contract only; the preset coherence seed is HOLD-FOR-FOUNDER. **CLOSED** (independent review
    PASS WITH NAMED WA3.3 DEFECTS).
  - **WA3.3 — BodyVibe reverb runtime truth + binding hardening: IMPLEMENTED.** Address 6 is
    the anchor, bio modulates around it (`EchoelDDSP.bioModulatedReverbMix`), and `EchoelReverb`
    makes it audible (`EchoelBodyVibeDevice.renderSpace`). A creative host parameter without a
    runtime binding now fails setup. Guard `TheBodyVibeReverbIsHeardAndAnchoredTests`. **COMPILES** at `f72b09b74` (Xcode
    Compile Check run 36053234043 success, AUv3 embedded; CI/CD `Build for Testing` success, run
    36053233853; `main` advanced). Not TESTED: Run Tests `TEST EXECUTE FAILED` (#396), no
    failure in the tail window, new guard not visible there (#807). Host check WA3-5 in §9.
  - **WA3.3a — reverb follows the host rate; `tailTime` covers the room: IMPLEMENTED
    (2026-09-24).** `EchoelReverb.setSampleRate` in `allocateRenderResources`; `tailTime` =
    release + reverb T60 (`EchoelBodyVibeDevice.tailSeconds`). Guards
    `TheAUv3ReverbFollowsTheHostRateTests`, `TheAUv3TailCoversTheReverbTests`. Host check WA3-6.
  - **WA3 slice 2 (app instrument) — Echoel instance state, read-only assembly: IMPLEMENTED
    (2026-09-25).** `Core/EchoelInstanceState.swift` gathers the app instrument's creative state
    (patch, FX character, genre, mood, variation, articulation, rhythm/pad shape, auto mode,
    phrase length, role mix, device modulation routes) from today's owners into ONE value and
    writes nothing. Session state (key, scale, A4, tone system, BPM lock, tempo route), runtime
    and bio are excluded by a guard; known gaps (bus inserts, live FX-chain parameters,
    touch/field) are named in the file. Guard `TheEchoelInstanceStateIsAssembledReadOnlyTests`.
    This closes WA4 prerequisite 4 (`NATIVE_DEVICE_ARCHITECTURE.md` §P); no caller yet.

### WA4 — Arrange + Session Front

- **Only after WA1–WA3.**
- **Task:** the first workstation front. Arrange (linear) and Session (scenes) are both
  **projections of the same canonical Session** from WA2 — never two documents.
- **Must obey:**
  - the modal budget (consolidate before appending);
  - the hot-state leaf law;
  - `EchoelValueField`;
  - Uncodixfy;
  - iPhone-first layout with adaptive reflow.
- **Status:** **IN PROGRESS (2026-09-25)** — WA3 prerequisites re-evaluated against code (WA3
  APPROVED; prerequisite 4 closed by WA3 slice 2). The first three slices live inside the ONE
  Workstation plate; no new modal, no second document, every write through `TimelineStore`:
  - **WA4.1 — select a track → device → mix: IMPLEMENTED.** `Studio/TrackInspectorView.swift`
    (`b2913f96b`, review PASS WITH CONDITIONS → repaired `8b8e9af19` + `7ebb2e322`). Only
    controls the engine applies are shown (`TrackMix.controls`; no pan on the Echoel track,
    none on a voiceless rack lane). Guard `TheTrackInspectorShowsOnlyWiredControlsTests`.
  - **WA4.2 — Session projection (launch a part / a scene on the bar): IMPLEMENTED.**
    `Studio/SessionLaunchView.swift` (`d9a0b87fc`, voiceless-lane fix `7ebb2e322`) — the first
    production caller of `TimelineRegionPlayer.launchRegion`. Scenes are start bars; cells are
    `activeRegion`'s answer. Runtime-only launch state. Guard
    `TheSessionLaunchesWhatTheSongPlaysTests`. Review PASS WITH CONDITIONS → repaired
    `764e1f8e7` (WA4.2c): a cell only for a part the player would sound (`isExecutable`, the
    playing path's resolver), the phase caveat stated, `launchGeneration` bumped on prune/relocate.
  - **WA4.3 — arrange parts (move · copy · remove · undo/redo): IMPLEMENTED.**
    `Studio/TrackPartsView.swift` (`e0d7132a3`) — first production callers of
    `moveRegion` / `duplicateRegion` / `removeRegion` / `undo` / `redo`. Undo is region-only by
    the store's design and says so. Guard `TheTrackPartsAreArrangedThroughTheStoreTests`.
  - **WA4.4 — remove an empty track: IMPLEMENTED.** `TrackMix.removal` / `removeTrack` in
    `Studio/TrackInspectorView.swift` (`0faea6e66`) — first production caller of
    `TimelineStore.removeLaneIfEmpty`. Only an empty, non-Echoel, non-bio track; the reason is
    shown otherwise. Guard `OnlyAnEmptyTrackCanBeRemovedTests`.
  - **WA4.5 — the song at a glance: IMPLEMENTED.** `Studio/ArrangementStripView.swift`
    (`325710ca9`) — every track's parts on one shared scale, overlap drawn in `activeRegion`
    order, no playhead (hot-state law). Guard `TheSongIsSeenOnOneScaleTests`. Plate copy
    corrected in `a6cc4fef2`.
  - **WA4-S1…S3 — the Operational Session (critical path 1): IMPLEMENTED.**
    `a924cd4fb` (whole-song replace: `TimelineStore.replaceDocument`, `ClipStore.replaceSlots`),
    `3da618ede` (composer reuses its orphaned clip — the slot leak), `bc261fae3` (the Session
    rides in the `projects.json` row as opaque bytes: `Core/ProjectSession.swift`, newer/damaged
    envelopes refused AND preserved), `2eb3cb84d` (`Core/SessionSaveOpen.swift`: Save captures
    the song through the one importer; Open from the library replaces it, a legacy take opens on
    a fresh song, a refused Open changes nothing; shared/Colabo takes never replace the song).
    Guards `TheSessionReplacesTheSongWholeTests`, `TheComposerReusesItsOrphanedClipTests`,
    `TheSessionTravelsInTheProjectRowTests`, `TheSessionSaveOpensTheSameSongTests` (Acceptance
    Test A minus the audible half). Review PASS WITH CONDITIONS → repaired `7ceb7e2f5`: the ONE
    recovery slot keeps the richer half of old and new (`SessionSaveOpen.recoveryRow` — never an
    empty take over a composed one, never a blank song over the user's); an imported document's
    Session is stripped. Known gaps, stated at the code: song form captured not restored; player
    automation not captured by the Studio's Save; a Save whose song fails to encode reads as a
    pre-Session row (review M1, logged only).
  - **WA4 path 3 — one selection owner: IMPLEMENTED.** `Studio/WorkstationSelection.swift`
    (`f43bfe505`), built once in `EchoelmusicApp`, never persisted; stale ids resolve to nil on
    read. Guard `TheWorkstationHasOneSelectionTests`.
  - **WA4 path 4 — the Arrange canvas: IMPLEMENTED.** `Studio/ArrangeCanvasView.swift`
    (`c5c938ccd`) replaces the WA4.5 per-row strips: all tracks with parts on one scale, a part
    selected by tapping it, `ArrangePlayheadView` the only `currentTick` reader (15 Hz leaf,
    paused when stopped). Guard `TheSongIsSeenOnOneScaleTests`.
  - **WA4 path 5 — act on the selected part: IMPLEMENTED (move · split · copy · remove).**
    `Studio/SelectedPartBar.swift` (`ccc96c753`); Split snaps to the song grid and hands
    `splitRegion` the tempo MEDIA elapses at (`PartSplit.mediaBPM`), fixing a latent jump at the
    cut of a warped part. Guard `TheSelectedPartIsCutWhereItIsHeardTests`. (Held at the time:
    drag-move and trim — both since built, see path D and TRIM below.)
  - **WA4 path 7 — Undo/Redo for the song: IMPLEMENTED.** `Studio/SongHistoryRow.swift`
    (`048b4c69c`), one history control under the canvas, moved (not copied) out of
    `TrackPartsView`, so Remove on the part bar keeps a visible way back. Region-only, as the
    store's history is. Guard `TheTrackPartsAreArrangedThroughTheStoreTests` claim 4.
  - **WA4 path 6 — track headers: Mute/Solo IMPLEMENTED.** M/S switches in the track row
    (`33d5c0537`), gated on `TrackMix.controls(…).muteSolo`, writing through `TrackMix`; the
    inspector no longer draws them (one door per fact), hints worded once in
    `TrackMix.muteHint`/`soloHint`. **No Arm** (no record path, #1302). Level/Pan stay in the
    inspector (numeric → `EchoelValueField`, too wide for a phone row). Guard
    `TheTrackHeaderMutesAndSolosTests`.
  - **WA4 path 9 — Echoel as a Device on its track: DOOR IMPLEMENTED.** The Echoel track's
    device row carries ONE "Open" that posts the existing chrome door `"sound"` (`f8feea953`)
    — the Sound plate is the instrument's editor; no new modal, the inspector stays a leaf.
    Guard `TheEchoelTrackOpensItsDeviceTests`. Not yet: the instance state on the row (needs the
    view-private live patch).
  - **WA4 path 8 — one part editor: IMPLEMENTED.** The parts list under the inspector now only
    SELECTS (`6bf183726`); every edit of a part lives on the one `SelectedPartBar` (review
    MEDIUM-2: two editors for one part). Guard `TheTrackPartsAreArrangedThroughTheStoreTests`.
  - **Review of paths 3–5: PASS WITH CONDITIONS → repaired** (`75d27e615`, `534b0df29`):
    Split is refused where the cut would change which overlapping part plays
    (`PartSplit.keepsWhoPlays`, asked through `TimelineScheduling.activeRegion` — the one
    precedence rule); the part bar collapses to icons before it overflows; a live Session that
    failed to encode never replaces the recovery slot's good one; every arrival (Import, Live
    Colabo Save) goes through `ProjectStore.adoptArriving` — fresh id, no song. **Accepted and
    logged (MEDIUM-4):** the slot's Session stays while the live song holds no user parts — a
    flag set on Open and cleared on the first edit would close it.
  - **Acceptance Test A gap closed:** the Save tile was `hasComposed`-gated, so a song built
    only by importing could not be saved. `SaveSessionButton` (`c69af8995`) is enabled by
    `hasComposed || SessionSaveOpen.songHasUserParts` — the recovery slot's predicate — and reads
    the song in its own leaf body (freeze law). Guard `TheSongAloneCanBeSavedTests`.
  - **Acceptance Test A inside the Workstation:** `WorkstationProjectRow` (`dc55c2d6e`) puts
    Save and Open on the plate itself, gated on the same facts as the Studio's tiles, raising the
    Studio's OWN Save alert and Open sheet through the chrome door (`"save"`/`"open"` receiver
    cases) — no presentation modifier of its own. Guard `TheSongAloneCanBeSavedTests` claim 4.
  - **WA4 path 5 — TRIM: IMPLEMENTED, inward only** (`a246cf91b`). Trim start/Trim end on the
    part bar move one grid step inward (bar, else beat) through `TimelineStore.trimRegionStart`/
    `resizeRegion`; a trim that would hand bars of an overlapped part to another part — or take
    them from one — is refused via `PartTrim.onlyLetsGo`, asked through `activeRegion`. The
    refused Split now says why in visible text. Guard `TheSelectedPartIsCutWhereItIsHeardTests`.
  - **Review of paths 6–9: PASS WITH CONDITIONS → repaired** (`be933a627`): M/S carry
    `accessibilityInputLabels([name, letter])`; a part selected in the parts list says in visible
    text where its actions are. Open as a device check: the header row at accessibility type
    sizes (journey step 5).
  - **WA4 path 9 — the instance on its row** (`aefcd42dc`): the Echoel track's inspector shows
    its genre and FX character, read-only, from the instrument's own keys resolved through their
    types (`EchoelInstanceLine`, its own file because the inspector owns no persistence). The
    patch name is not shown — view-private. Guard `TheEchoelTrackNamesItsInstanceTests`.
  - **WA4 path 10 — device proof journey: WRITTEN, execution is the founder's.**
    `scratchpads/FOUNDER_DEVICE_SESSION.md` §2c orders the nine steps of one sitting (Acceptance
    Test A in the middle); each ask stays worded at its guard.
  - Evidence ceiling: transcription-graded guards; compile gates are read per commit in
    `scratchpads/SESSION_LOG.md`; **device verification owed** for every slice
    (NEEDS-FOUNDER-VERIFY markers in each guard header).
  - **WA4 journey proof — item 9: WRITTEN** (`b0d1739a4`, review repair `5c8de3c59`):
    `TheWorkstationJourneySurvivesSaveAndOpenTests` walks one song through the calls the surfaces
    make — Add Audio Track, the real `AudioImport.commit`, trim/move/split/duplicate/delete,
    undo/redo, `TrackMix`, Save, a fresh `ProjectStore`, restore, field-by-field equality and the
    Play preflight. A song-only saved row is no longer shared as an empty take
    (`Project.shareCarriesItsContent`).
  - **WA4 path 2 — the Workstation as a first-class workspace: IMPLEMENTED** (`b4c2179bf`,
    §13 WA4-P2 option (a) with the tuning banner). A relaunch returns to the Workstation the
    player left from; a first launch still shows Sound.
  - **WA4 path D — drag-move on the canvas: IMPLEMENTED** (`e3211f21d`). Press, hold, slide:
    whole bars relative to the start (the part bar's step), `@GestureState` preview in the
    `ArrangePartBlock` leaf, ONE commit through `TrackParts.move` on release. Old
    `ArrangeTimelineView` classified: body drag + snapped preview PORTED as idea,
    `TimelineDragMath.tickDelta` PORTED as algorithm; zoom, magnet, lane change and overlap
    trimming NOT RESTORED. Guard `TheArrangeCanvasMovesAPartByDraggingTests`.
  - **Open in WA4 (after path D):** a general undo step beyond regions (mixer edits are not
    undoable), drag across tracks and drag-trim of edges (and an outward trim — today's trim
    only shortens), the MEDIUM-4 flag (kept open on purpose: today's behaviour errs toward
    keeping a song, the flag would trade that for losing one); Arm stays absent (no record
    path, #1302); the device proof journey is written and owed to the founder.
---

## 8. Deferred — parked, not forgotten

| Item | Why parked | Trigger to revisit |
|---|---|---|
| More loudness work | E1–E3 closed; the export is correct for its claim ceiling | a measured regression, or the Founder asks |
| AutoMix conversion to integrated LUFS | AutoMixChain's live auto-gain is still RMS − 0.1 (a third loudness truth) | after Phase 2, as its own slice |
| True-peak limiting | no true-peak claim is made; E1 is sample-peak | a codec/distribution requirement |
| Jev installation | not in Phase 2 scope | Founder schedules it |
| XcodeBuildMCP | developer harness | local Apple-silicon machine available |
| Maestro | UI test harness | local Apple-silicon machine available |
| Periphery | needs a full local build (doctor §C would move to it) | local Apple-silicon machine available |
| actionlint | CI linting; `.github/workflows/**` is founder-gated | Founder opens CI work |
| CodeQL | CI security scanning; founder-gated | Founder opens CI work |
| Dependabot | zero dependencies today | the first linked dependency |
| Claude harness cleanup | `.claude/` hygiene | a quiet cycle, never mid-slice |
| M5 local-Xcode migration | web sessions have no Swift toolchain | local machine available (see below) |

**Developer Harness / M5 migration: TRIGGER WHEN LOCAL M5/APPLE-SILICON DEVELOPMENT MACHINE IS
AVAILABLE.** Until then, machine truth is CI, and guards are graded by transcription
(`Tests/CISmoke/CLAUDE.md` §0).

---

## 9. Device verification queue

These never block Phase 2 architecture work. Each is closed by a dated `VERIFIED-` marker or
Founder report. `python3 scripts/founder-verify.py` prints the full marker list.

**E3 — loudness meter on real routes**

| # | Check | Pass looks like |
|---|---|---|
| E3-1 | running 48 → 44.1 kHz route switch, e.g. speaker → Bluetooth, while playing | Master LUFS keeps reading plausibly; no stall, crash or frozen meter |
| E3-2 | running 44.1 → 48 kHz route switch | same |
| E3-3 | meter rebuild after an engine restart | the diag log shows the `start` ladder; the meter reads again |
| E3-4 | unsupported route behaviour, if hardware offers one | the meter reads the floor (no value), never a wrong value |
| E3-5 | 44.1 vs 48 kHz Master parity: same material on both routes | integrated readings agree within ~0.1 LU |
| E3-6 | higher-rate interface (88.2/96/176.4/192 kHz), when hardware exists | readings agree with 48 kHz within ~0.15 LU |

Known code fact behind E3-1/E3-2: `AudioEngine`'s configuration-change branch for a still-running
engine re-arms taps without rebuilding the meter. Apple documents that a rate change stops the
engine, which routes through `start()` → `installMeterTap()` → a new meter. The device run
settles which path really fires.

**WA3.1 / WA3.2 — the AUv3 in real hosts** (AUM measured loading once, 2026-09-20; nothing since)

| # | Check | Pass looks like |
|---|---|---|
| WA3-1 | old host project saved before WA3.1, reopened | the four creative values restore; nothing crashes |
| WA3-2 | new save → reopen in AUM, then GarageBand/Logic when available | the saved state holds no coherence/HRV/heart-rate/breath-phase value |
| WA3-3 | host parameter list after WA3.2 | the same eight parameters, names, ranges and order as before; existing automation lanes still drive the same parameter |
| WA3-4 | factory presets 0–2 | as before, except that their reverb (0.4 / 0.6 / 0.2) is now audible (WA3.3); the coherence seed is unchanged |
| WA3-5 | automate address 6 from 0 → 1 while audio sounds, with bio modulation active for several seconds | the space audibly follows the host value and stays anchored to it; it never snaps back to a fixed base |
| WA3-6 | reverb at 1, a 55 Hz note, then bounce/freeze past note-off at 44.1 kHz and at 96 kHz | the same room at both rates; the bounce keeps the whole tail (no cut about 2 s after note-off) |

**Other open device checks (existing):**
- ship-gate check 1 (sound: founder ear) and check 5 (stability);
- two-phone PeerIdentity (#113);
- spatial instruction wording (#152);
- the four genre A/Bs (#34);
- the Workstation tempo correction, pitch and MIDI import;
- AUv3 in hosts other than AUM.

---

## 10. Platform strategy

**Apple-first, not Apple-only.**

- **Apple, in release order:** iOS (iPhone ships today), then iPadOS, macOS and visionOS. Each
  platform's prerequisites are in the platform table in `CLAUDE.md`. The iPad needs a bio
  source that works there, plus the reflow work.
- **Later:** Windows, Linux, Android, OpenXR.
- **The shared, platform-neutral core should increasingly own:**
  - Session semantics;
  - DSP, where appropriate;
  - MIDI and events;
  - parameters and modulation;
  - automation;
  - collaboration protocols;
  - file and interchange logic.
- **Platform adapters own the native APIs:** AVFoundation, CoreMIDI, Metal, HealthKit,
  Network and their future equivalents.
- **No migration date is promised.** The first concrete step is the founder-gated EchoelCore
  target (#95).

---

## 11. Plugin strategy

Echoelmusic is the complete workstation. Echoel's native instruments and effects can **also**
ship as standalone plugins.

```
Echoel Module / DSP core   (Foundation + Accelerate, format-agnostic)
  → Native DMMW adapter    (a device on a workstation track)
  → AUv3                   (first — exists, AUM-verified 2026-09-20)
  → later VST3
  → later CLAP
```

**AUv3 first. VST3/CLAP are not current priority.** Plugin hosting (loading third-party
plugins into Echoelmusic) is a separate capability and currently IDEA.

---

## 12. Development and review strategy

| Role | Owns |
|---|---|
| **Founder** | product intent; every irreversible decision; App Store wording; founder-gated files |
| **ChatGPT** | roadmap, architecture, orchestration, closure sequencing |
| **Claude (Claude Code sessions)** | primary implementation agent |
| **Codex / Astra** | independent adversarial review |
| **Local Xcode / CI** | machine truth: compile, test execution |
| **Physical device** | hardware, route and sensory truth |

**The builder never self-certifies.** A slice built by the implementation agent reaches
INDEPENDENTLY REVIEWED only through a reviewer who did not build it. It reaches DEVICE VERIFIED
only on hardware.

---

## 13. Founder holds

These are decisions only the Founder can make. They block their own items, not Phase 2 in
general.

| # | Hold | Blocks |
|---|---|---|
| ~~WA2~~ | ~~canonical Session ownership model~~ — **ANSWERED 2026-09-24: APPROVED WITH BINDING AMENDMENTS** (`SESSION_OWNERSHIP_CENSUS.md` §O). Every migration toward the target is still its own Founder-approved slice | — |
| ~~—~~ | ~~confirm "Instrument-Complete v1" as a release gate, not the product boundary~~ — **ANSWERED 2026-09-24** in the WA2 decision lock (law §6) | — |
| — | App Store wording | any store text |
| #27 | brand line "Create from Within" vs "multidimensional" | brand copy |
| #91 | the HRV line in the App Store text (`fastlane/metadata`) | store text |
| #95 | the EchoelCore target in `project.yml` | the shared-core migration |
| #94 | FrameTime + drop-frame timecode (blocked) | video timebase |
| #58 | two blocked genres (gnawaGuembri, koraOstinato) | genre catalogue |
| #208 / #396 / #807 / #1176 | CI: full-tests label, the simulator-clone crash, the `tail -200` log window, and the `CLAUDE.md` path filter | test-execution evidence (TESTED status) |
| — | adding any dependency (HaishinKit, LinkKit, NDI SDK, …) | broadcast, Link, NDI |
| WA4-P2 | **the Workstation as a first-class workspace (critical path 2).** ⭐ **TAKEN 2026-09-25 under the WA4 EXECUTION GO: option (a) with the banner.** A relaunch returns to the Workstation when the player left from there (`studio.reopensWorkstation`, one Bool, ONE writer = the plate the player chose); a first launch and every launch after leaving from an instrument panel still show Sound; `nonStandardTuningBanner` is mounted on the Workstation plate too, so #325 holds for whichever plate a launch shows; the chip strip scrolls the restored chip into view. (b) was measured and dropped — the brand keeps ~72 pt on a 360 pt phone and the header layout is founder-drawn; (c) stays forbidden (D10). Guards: `TheWorkstationHasADoorTests` claim G, `DetunedInstrumentSaysSoTests`. Evidence: TESTED by transcription; COMPILES pending; DEVICE open (founder sheet §2c). | path 2 |

---

## 14. Maintaining this file

- A status changes only with its evidence (§4), written in the same commit.
- A new slice enters §7 only after the previous one closes, or when the Founder or orchestrator
  reorders.
- A closed slice moves from §7 to §5 with its commits and review verdict.
- Do not copy counts from code into this file; name the command (the `CLAUDE.md` #818 rule).
- Change log:
  - 2026-09-24 — created at `main` = `7b2690357`; Phase 2 opened with WA1–WA4.
  - 2026-09-25 — WA4 items 1–9 implemented through `3f383f666` (path 2 = §13 WA4-P2 option (a), path D drag-move, journey proof); Phase 3 order stays the Founder's.
  - 2026-09-24 — WA1 COMPLETE (`c2fad0a0a`); WA2 COMPLETE (`a52170ca5` + the decision lock:
    APPROVED WITH BINDING AMENDMENTS); WA3 NEXT; WA4 BLOCKED ON WA3. Bare W1–W4 renamed WA1–WA4;
    the two census output paths corrected from `scratchpads/` to `docs/dev/`.
  - 2026-09-24 — WA3 APPROVED (`59a243958`); WA3.1 CLOSED (`87d829f42`, PASS WITH HOST
    VERIFICATION); WA3.2 IMPLEMENTED (canonical identity + AUv3 mapping + `EchoelDeviceState`
    foundation); AUv3 host checks WA3-1…4 added to §9.
  - 2026-09-25 — WA3 slice 2 IMPLEMENTED (`862e41279`/`c071ddbba`); WA4 IN PROGRESS: WA4.1
    track inspector, WA4.2 Session launch grid, WA4.3 part arrange + undo IMPLEMENTED
    (commits in §7 WA4). Device verification owed.
  - 2026-09-25 — WA4.2c review repair, WA4.4 remove empty track, WA4.5 song-wide parts strip
    IMPLEMENTED (commits in §7 WA4). Device verification owed.
  - 2026-09-25 — Codex forensic override applied: Operational Session S1–S3, one selection
    owner, Arrange canvas + leaf playhead, selected-part bar with warped-split fix IMPLEMENTED
    (commits in §7 WA4). Device verification owed; Acceptance Test A's audible half open.
