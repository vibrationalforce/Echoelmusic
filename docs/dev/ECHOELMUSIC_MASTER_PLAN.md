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
`ROADMAP.md` (2026-06-19, subordinate to the superseded `PRODUCT_DEFINITION.md`),
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
vocabulary W1–W4 are measured against.

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
to stay the permanent whole-app shell. **Status: IDEA.** W3 decides how the move happens.
Nothing moves before W1–W3.

---

## 3. Architecture invariants

These hold for every slice. Breaking one needs an explicit Founder decision recorded in
`decisions.csv`.

1. **One canonical Session.** There is never a second document that owns song state.
2. **No second transport truth.** One clock, one play state, one tempo.
3. **`PatternEngine` stays the musical clock authority** unless the Founder changes it. Every
   production `Transport.setTempo` call is made inside `PatternEngine`; every other tempo
   writer goes through `PatternEngine.setTempo(_:source:)`. Measure it with
   `git grep -n "\.setTempo(" -- Sources`. The tempo invariants T1–T3 in `CLAUDE.md` apply,
   and `TempoInvariantTests` is their law.
4. **`TimelineStore`/`TimelineDocument` and `Arrangement`/`ArrangementStore` are NOT
   consolidated** without an explicit Founder decision (W2).
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
| Arrangement (`Core/ArrangementStore.swift`, `Sequencer/Arrangement.swift`) | IMPLEMENTED (model) | Separate persistence root; relationship to the timeline is the W2 question |
| Clips (`Core/ClipStore.swift`) | IMPLEMENTED (model) | Written by audio import |
| Project envelope (`Core/DMMWProject.swift`, `DMMWProjectImport.swift`) | IMPLEMENTED (M2) | Wraps the song roots; reader/importer exists |
| Timebase (`Core/TempoMap.swift`) | IMPLEMENTED (M1) | EchoelCore target is founder-gated (#95) |
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
| **PHASE 2 — WORKSTATION ARCHITECTURE** | W1 → W2 → W3 → W4 (§7) | **CURRENT** |
| PHASE 3 — Domain recovery | recording/input, note editing, automation editing, undo, video, broadcast, hosting, etc., each through the recovery principle (law §5) into the W2 owners | PLANNED — order decided by the Founder after W2 |

**Phase 2 is architecture, not UI construction.** No workstation UI is built until W1–W3 are
done. W4 is the first front.

---

## 7. Next four slices — in this exact order

### W1 — Workstation / UI Ownership Census

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
- **Output:** `scratchpads/CENSUS_W1_UI_OWNERSHIP.md` (evidence, not a roadmap).
- **Done when:** every surface has one class, each with a file path and a measured door.
- **Status:** PLANNED.

### W2 — Session Ownership Census + Founder Decision

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
- **Output:** `scratchpads/CENSUS_W2_SESSION_OWNERSHIP.md` + a `decisions.csv` row **after** the
  Founder answers.
- **Done when:** the Founder has chosen the ownership model. Invariant 4 governs until then.
- **Status:** PLANNED.

### W3 — Native Device Architecture

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
- **Hard rule:** no plugin-format-specific coupling in DSP (invariants 10–11).
- **Output:** a design document plus a `decisions.csv` row. Code only as separately approved slices.
- **Status:** PLANNED (after W2).

### W4 — Arrange + Session Front

- **Only after W1–W3.**
- **Task:** the first workstation front. Arrange (linear) and Session (scenes) are both
  **projections of the same canonical Session** from W2 — never two documents.
- **Must obey:**
  - the modal budget (consolidate before appending);
  - the hot-state leaf law;
  - `EchoelValueField`;
  - Uncodixfy;
  - iPhone-first layout with adaptive reflow.
- **Status:** IDEA (its shape depends on W2/W3).

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
| W2 | canonical Session ownership model | consolidation of the timeline, arrangement and automation homes; W3/W4 |
| — | confirm the reading of "Instrument-Complete v1" as a release gate, not the product boundary (law §6) | release planning |
| — | App Store wording | any store text |
| #27 | brand line "Create from Within" vs "multidimensional" | brand copy |
| #91 | the HRV line in the App Store text (`fastlane/metadata`) | store text |
| #95 | the EchoelCore target in `project.yml` | the shared-core migration |
| #94 | FrameTime + drop-frame timecode (blocked) | video timebase |
| #58 | two blocked genres (gnawaGuembri, koraOstinato) | genre catalogue |
| #208 / #396 / #807 / #1176 | CI: full-tests label, the simulator-clone crash, the `tail -200` log window, and the `CLAUDE.md` path filter | test-execution evidence (TESTED status) |
| — | adding any dependency (HaishinKit, LinkKit, NDI SDK, …) | broadcast, Link, NDI |

---

## 14. Maintaining this file

- A status changes only with its evidence (§4), written in the same commit.
- A new slice enters §7 only after the previous one closes, or when the Founder or orchestrator
  reorders.
- A closed slice moves from §7 to §5 with its commits and review verdict.
- Do not copy counts from code into this file; name the command (the `CLAUDE.md` #818 rule).
- Change log:
  - 2026-09-24 — created at `main` = `7b2690357`; Phase 2 opened with W1–W4.
