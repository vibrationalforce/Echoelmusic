# DMMW Reconciliation & Migration Design — 2026-09-21

**Status: AUDIT + PROPOSAL. Nothing committed. No production code changed.**
Founder decision of 2026-09-21 reverses the 2026-07-25 "Pure Instrument" definition.

> METHOD NOTE, and it is the single most important sentence in this document:
> every claim below is measured against the working tree at `7648150a7` by TYPE
> DECLARATION and by CONSTRUCTION SITE, with comments stripped. `CLAUDE.md` and the
> `scratchpads/` are treated as **evidence of intent, never as evidence of state** —
> this repo has a long, documented history of prose outliving the code it describes
> (most recently #1410, yesterday). Where a measurement contradicts a document, the
> measurement wins and the contradiction is recorded rather than edited away.

---

## 0. THE HEADLINE, BEFORE THE DETAIL

**The repository is far closer to DMMW than its own documentation says — because what
was removed in the 2026-07 "pure instrument" epic was overwhelmingly the USER
INTERFACE, not the MODEL.**

Measured at app start (`EchoelmusicApp.swift:124-154`), the running object graph already
constructs and owns:

| Constructed at launch | Line | DMMW role |
|---|---|---|
| `ClipStore` | 124 | clip/cell library |
| `MixerStore` | 126 | mixer state |
| `TrackFXStore` | 129 | per-track FX |
| `ArrangementStore` | 131 | section arrangement |
| `TimelineStore` | 134 | **the arrangement document** |
| `ArrangementPlayer` | 136 | section playback |
| `TimelineRegionPlayer` | 139 | **region playback** |
| `RecordController` | 140 | record arm/capture |
| `AutomationPlayer` | 145 | automation playback |
| `SignalRouter` | 148 | **the signal graph runtime** |
| `SpatialSceneStore` | 143 | immersive object scene |
| `BroadcastPublisher` | 154 | broadcast scaffold |
| `MultipeerSession` | 99 | collaboration transport |

None of these is a stub. `TimelineLane` (`Sequencer/Timeline.swift:19`) already carries
per-lane patch, genre override, mood, variation seed, transpose, detune, level, pan,
mute, solo, record-arm, built-in instrument and a bio-lane flag. `TimelineRegion:246`
already carries dual-domain trim (`contentOffsetSeconds` AND `contentOffsetTicks`),
per-placement gain, warp enable and `stretchMode`. `ClipKind:52` already enumerates
`.midi, .audio, .video, .visual`.

**Therefore the migration is NOT "build a workstation". It is three much smaller things:**
1. **Resolve duplicate ownership** before adding anything (this is the real risk).
2. **Extend the TIME MODEL** — today it is musical-only (bars/steps/PPQ); DMMW needs a
   seconds/samples/frames authority for video, timecode and network sync.
3. **Re-door** what already runs headless, one surface at a time, behind capability flags.

**The one thing that is genuinely absent and must be built from nothing: audio INPUT.**
Everything else exists in some measurable form.

---

## 7. TRANSPORT / TIME MODEL  *(placed early because it is the binding constraint)*

### Measured today

`Core/Transport.swift` — a **musical-only** model:
- `TransportPosition` = `bar` + `step`; derived `beat`, `ppqTick`, `absoluteStep` (`:33-51`)
- fixed grid: 4/4, 16 steps/bar (`:58`, "mirrors PatternEngine")
- `clockSource: TransportClockSource` (`:114`)
- subscriber fan-out: step / stop / play / tempo (`:194, :353, :360, :381`)

`Sequencer/PatternEngine.swift` is the **master clock**; `Transport` is its **publish
relay**. Measured: every `transport?.setTempo` call in `Sources/` is inside
`PatternEngine.swift` (six sites, `:323 :370 :399 :403 :556` plus `:247` for swing),
and `PatternEngine:631` calls `transport?.tick(step:)`. `Transport` has no independent
production driver.

**This is already a healthy single-authority design and must be preserved.** One clock
authority, one broadcast surface. Do not add a second clock.

### The gap

There is **no seconds/samples/frames authority anywhere in the model layer.** Measured:
`CMTime` appears only in `Audio/SingleExport.swift` (export-time), `sampleTime`/`hostTime`
only inside `Audio/AudioEngine.swift` and `Audio/RenderGapDetector.swift` (render
diagnostics). `git grep -nE 'timecode|SMPTE|frameRate'` over `Sources/**/*.swift`
returns **nothing**.

`TimelineRegion` papers over this with two parallel trims — ticks for MIDI, seconds for
media — and its own comment explains why (a seconds-stored MIDI trim shifts when tempo
changes between edit and play). That workaround is correct for two domains and does not
scale to five.

### Proposed: `Timebase` — one conversion authority, four coordinate spaces

```
MusicalTime   bar/beat/tick   (PPQ, authoritative for MIDI + generative)
SampleTime    Int64 frames    (authoritative for audio render + recording)
WallTime      Double seconds  (authoritative for media playback + network)
FrameTime     frame + rate    (authoritative for video/timecode; drop-frame aware)
```

Rules, each with a reason rather than an aesthetic:
1. **`TempoMap` is the only thing that converts MusicalTime ↔ WallTime.** Today the
   conversion is implicit in a constant tempo. A DMMW project must survive tempo changes
   mid-timeline, which is exactly the failure `TimelineRegion`'s dual trim already
   anticipates.
2. **`SampleTime` is authoritative wherever audio is rendered or recorded.** A recording
   punch point stored in seconds cannot round-trip: 48 000 and 44 100 disagree.
3. **`FrameTime` never derives from `WallTime` by multiplication.** 29.97 drop-frame is
   not a scale factor. This is the classic defect and it must be a named type.
4. **Every stored position declares its space.** The current model stores bare `Int`
   ticks and bare `Double` seconds in sibling fields; a typed wrapper makes the
   conversion site explicit and greppable.
5. **`Timebase` is a pure value type with zero Apple imports** — this is what makes the
   Windows/Linux claim honest rather than aspirational.

**This is the recommended FIRST IMPLEMENTATION SLICE (see §10).**

---

## 4. PROPOSED TARGET ARCHITECTURE

### 4.1 The two planes (this law already exists and is already enforced — keep it)

The repo has paid for this separation four times (10.76.41 / .48 / .50, #919/#928) and
`Tests/CISmoke/TheMenuHostReadsNoHotStateTests.swift` enforces it across four ancestors.
It is an ASSET, not an obstacle, and DMMW makes it more important, not less.

```
CONTROL PLANE                      │  REALTIME PLANE
@MainActor, @Observable            │  no locks · no malloc · no ObjC · no GCD · no actor hop
edits, undo, persistence, UI       │  audio render · Metal frame · DMX tick
                                   │
        ── compiles ──────────────►│  immutable RenderSnapshot (value type, pre-allocated)
        ◄──── lock-free SPSC ──────│  meters, events, positions
```

**The mechanism already exists**: `Core/EngineBus.swift` (`@MainActor @Observable`
control plane + lock-free `SPSCQueue`, three topics). DMMW adds topics; it does not
add a second bus. **One bus. Adding a medium = adding a subscriber** — that sentence
survives from the retired product definition and is the one part of it that should NOT
be superseded.

**New realtime law for the intelligence layer, stated because it is the new risk:**
no model inference, no tokenizer, no `Task`, no allocation inside any render callback.
The AI layer emits *edits to the control plane* and nothing else. It is a user with an
API, not a DSP stage.

### 4.2 Layering

```
┌─ UI (per platform, NOT shared) ────────── SwiftUI today; Compose/Win later
├─ Application services ────────────────── stores, undo, command bus, AI tool router
├─ DOMAIN CORE (platform-neutral, Foundation-only) ──────────────────────────┐
│   Timebase · TempoMap · DMMWProject · Timeline · Track · Clip · Region      │
│   Parameter · Automation · SignalGraph · Scene · Capability · SessionNode   │  ← the asset
├─ Engine boundaries (protocols) ─────────────────────────────────────────────┘
│   AudioEngineHost · VideoEngineHost · VisualEngineHost · LightSink
│   SpatialSink · BioSource · PluginHost · BroadcastSink · PublishingProvider
└─ PLATFORM ADAPTERS ───────── AVFoundation · CoreMIDI · Metal · HealthKit · AUv3 · Network
```

**The rule that makes "Apple-first, not Apple-locked" testable rather than rhetorical:**
the domain core imports **Foundation only**. This repo already enforces the analogous
rule one layer down — `.claude/rules/swift-audio.md` pins `DSP/` to
`{Foundation, Accelerate}` and `TheDSPLayerStaysFoundationOnlyTests` makes it executable.
**Extend that exact pattern to the new core.** A guard, not a memo.

### 4.3 The `Track` question — answered with reasons, not elegance

The founder asked explicitly not to choose on elegance. Three candidates:

| Design | Serialization | Realtime | Undo | Migration | Portability | UI |
|---|---|---|---|---|---|---|
| One heterogeneous struct with optional fields | trivial, stable | fine (flat) | trivial (value) | trivial | trivial | fields must be filtered per kind |
| Protocol `Track` + typed conformers | needs type-erased envelope + registry | existential = pointer chase | needs per-type diff | **new kind breaks old decoders** | protocol witness tables are Swift-only | clean |
| **Common struct + typed `payload` enum** | one envelope, one `kind` discriminant | flat, `switch`-able | value semantics | **additive: unknown kind decodes to `.unknown(raw)`** | plain data | `switch` per kind |

**RECOMMENDATION: the third — a common `Track` struct carrying identity, mixer state,
timing and a `payload: TrackPayload` enum.**

The deciding argument is not elegance, it is **forward-compatible decoding on a device
you do not control**. A DMMW project will be opened by an older build (a collaborator's
phone, a watch, a stage Mac that was not updated). A protocol-based design must know
every concrete type at decode time; an envelope with a discriminant can preserve an
unknown payload verbatim and re-emit it. This repo has already been bitten by exactly
this class: `LaneVoiceKind.drums` and `TrackInstrument.drums` are kept as dead enum
cases *specifically because an unknown rawValue throws and discards the whole lane on
decode*. That is the same lesson, one level up.

Second argument: the current `TimelineLane` is **already** shape (1) — one struct with
`kind: ClipKind` plus optional per-kind fields. Moving to (3) is a refactor with a
mechanical path and a preserved decoder. Moving to (2) is a rewrite with a migration.

**Counterweight, recorded honestly:** shape (3) puts kind-specific fields behind a
`switch`, so every consumer grows one. That cost is real and it is the price of the
decode guarantee. Shape (1) is acceptable for ≤4 kinds and becomes a swamp at nine.

### 4.4 Plugin architecture

- `PluginHost` protocol in the core: `discover() -> [PluginDescriptor]`,
  `instantiate(descriptor) -> PluginInstance`, parameters as `Parameter` values.
- Adapters: `AUv3PluginHost` (iOS/macOS) — **this is a re-ADD, see §2**, and note the
  founder cut AUv3 *hosting* in #121 Slice 2 while the AUv3 *target* (being a plugin)
  came back in #1385. Those are opposite directions and must not be conflated again.
- `VST3PluginHost` / `CLAPPluginHost` are desktop-only adapters. **CLAP is MIT; VST3 is
  GPLv3-or-proprietary-licence** — that is a founder/legal decision, not an engineering
  one, and it is registered as such in §11.

### 4.5 Publishing / broadcast

```
DeliveryGraph (core, platform-neutral)
  └─ DeliveryTarget { format, aspect, codecHint, subtitleTrack, reframePlan }
        └─ BroadcastSink   (live)     : RTMP · SRT · HLS · NDI   ← protocol
        └─ PublishingProvider (VOD)   : file · social API        ← protocol
```

**No platform name may appear in the document model.** A destination is data
(`DeliveryTarget`), a provider is a plug-in adapter. This is the single most important
structural requirement in the founder's brief and it is cheap if done first and
expensive if retrofitted.

---

## 5. MODULE / PACKAGE MAP

Today `Package.swift` has `dependencies: []` and the app is one module plus four small
targets. Proposal — **SwiftPM targets inside the same repo, not separate repos**, so a
cross-module violation is a compile error rather than a review comment:

```
Sources/
  EchoelCore/          ← Foundation ONLY. Timebase, TempoMap, DMMWProject, Track,
                          Clip, Region, Parameter, Automation, SignalGraph, Scene,
                          Capability, SessionNode, DeliveryGraph, ToolAction.
                          THE portability boundary. Guarded like DSP/ is today.
  EchoelDSP/           ← Foundation + Accelerate. (exists, keep as-is)
  EchoelEngineAudio/   ← AVFoundation adapter. Implements AudioEngineHost.
  EchoelEngineVideo/   ← AVFoundation/VideoToolbox adapter.
  EchoelEngineVisual/  ← Metal adapter.
  EchoelIO/            ← Network: OSC · ADM-OSC · Art-Net · sACN · (SRT/RTMP later)
  EchoelBio/           ← HealthKit · CoreBluetooth · camera rPPG adapters
  EchoelSession/       ← Echoel Session Protocol: discovery, clock, events, assets
  EchoelIntelligence/  ← tool/action router; NO model vendor in the type names
  Echoelmusic/         ← the iOS app (SwiftUI). UI stays per-platform.
  EchoelmusicAUv3/     ← the plug-in (exists; already isolated to DSP/ + 3 Core files)
  EchoelmusicWatch/ EchoelmusicWidgets/
```

**Do not port UI cross-platform** (explicit founder instruction, and correct). The
portable surface is `EchoelCore` + the engine protocols.

⚠️ **Cost to state plainly:** this repo is 356 Swift files in essentially one module.
Splitting into 11 targets is not free — it surfaces every accidental dependency at once
and will produce a large, noisy first build failure. **Therefore §9 extracts ONE module
first (`EchoelCore`) and leaves the rest alone.**

---

## 6. DMMW DOCUMENT MODEL

### 6.1 Ownership rules (these matter more than the field list)

1. **ONE document owns musical time.** Today FOUR types persist overlapping state:
   `Project` (one take), `TimelineDocument` (the arrangement), `Arrangement` (sections),
   `ClipStore`'s `[Clip?]` (the cells). That is the two-owner disease the founder named.
2. `DMMWProject` is the **root aggregate**. Everything else becomes a *member* or a
   *library*, never a sibling document.
3. **Assets are referenced, never embedded.** `MediaPool` holds `MediaAsset` (id, ref,
   native rate, native duration, checksum, proxy refs). `Clip` points at an asset id.
   This already half-exists: `Core/MediaLibrary.swift` + `Clip.mediaRef`.
4. **Every stored position carries its Timebase space** (§7).
5. **Schema version at the DOCUMENT level, not only per element.** `Clip`'s own comment
   already flags this defect: "The clips in the file are versioned; the file is not."
6. **Unknown enum rawValues and unknown payloads must decode, not throw.** Non-negotiable
   for collaboration across build versions (see §4.3).

### 6.2 Sketch

```
DMMWProject
  schemaVersion: Int
  id, name, createdAt, modifiedAt
  metadata: ProjectMetadata            // artist, tuning (a4Hz), notes, license
  timebase: TimebaseConfig             // ppq, sampleRate, frameRate, dropFrame
  tempoMap: TempoMap                   // [(tick, bpm, curve)]  — NEW, replaces scalar bpm
  meterMap: MeterMap                   // [(bar, numerator, denominator)] — NEW
  tracks: [Track]
  scenes: [Scene]                      // session/clip-launch view
  mediaPool: MediaPool
  signalGraph: SignalGraph             // EXISTS TODAY, reuse verbatim
  automation: AutomationBank
  deliveryGraph: DeliveryGraph         // NEW
  spatialScene: SpatialScene           // EXISTS TODAY
  unknown: [String: AnyCodableBlob]    // forward-compat escape hatch
```

`Track` = identity + mixer + routing + `payload: TrackPayload`
(`.audio .midi .video .video360 .visual .lighting .spatial .control .bio .unknown(raw)`).

### 6.3 Migration from today

`Project` (the take) does **not** die — it becomes a *preset/take* inside `DMMWProject`,
which preserves every saved user take. `TimelineDocument` becomes the `tracks` +
`scenes` members. **Write the importer before the new writer**, so v1 files keep opening.

---

## 8. REALTIME NETWORK MODEL

The founder is explicitly right that latency cannot be abolished. Four classes, each with
a different guarantee — **and the mistake to avoid is one transport trying to serve two**:

| Class | Budget | Carries | Mechanism |
|---|---|---|---|
| **L0 local hard-realtime** | < 10 ms | audio render, DSP | in-process only. NEVER crosses a network. |
| **L1 interactive realtime** | ~5–50 ms LAN | OSC · ADM-OSC · Art-Net · sACN · MIDI | UDP, fire-and-forget, latch state. **EXISTS TODAY.** |
| **L2 musical sync (global)** | 100 ms – 2 s | transport, scene launch, edits, bio | **timestamped events on a shared musical clock, quantised to bar/scene.** Late = applied at next boundary, never dropped silently. |
| **L3 asset conform** | seconds – minutes | recorded audio/video masters | each node records LOCALLY at full quality; proxies stream; masters reconcile afterwards by timestamp. |

**The load-bearing design decision: L2 must be an EVENT LOG, not state replication.**
Each event carries `(nodeID, logicalTime, payload, causality)`. This is what makes
undo, late-join, conflict resolution and offline editing one mechanism instead of four.
State replication over a 200 ms link produces exactly the two-owner problem the founder
asked to avoid, only distributed.

**Bio over L2, never L1 across the internet.** ~1 Hz bio (the measured application rate)
is a *trend*, not a trigger — the repo already knows this: Apple Watch's 4–5 s latency is
pinned as "display, trend, slow modulation, NEVER beat-sync".

`SessionNode` = `{ id, deviceClass, capabilities: Set<Capability>, latencyProfile, clockOffset }`.
Capabilities are declared, not inferred from device model — that is the same
capability-based rule the founder asked for on the bio side, applied to nodes.

---

## 1b. DUPLICATE OWNERSHIP — the finding that outranks every feature question

The founder asked specifically not to repeat the two-owner problem. Measured, the repo
**already has it**, in four places, today, before any DMMW work:

| Concern | Owners found | Evidence | Verdict |
|---|---|---|---|
| **Clock / tempo** | `PatternEngine` (authority) + `Transport` (relay) | every `transport?.setTempo` is inside `PatternEngine.swift`; `Transport.setTempo` has no other production caller | ✅ **NOT a defect.** One authority, one fan-out. Preserve exactly. |
| **Document / musical state** | `Project` · `TimelineDocument` · `Arrangement` · `ClipStore[Clip?]` | four independent `Codable` roots, four App-Group files, overlapping content | 🔴 **REAL two-owner (four-owner) problem. Fix BEFORE adding.** |
| **Playback execution** | `ArrangementPlayer` · `TimelineRegionPlayer` · `AudioLanePlayer` · `AutomationPlayer` · `BeatPlayer` | all constructed in `EchoelmusicApp` (`:136 :139 :145 :362`, `:1126`) | 🟠 **Coordinate, don't merge.** They are stage-specific; what is missing is one *scheduler* above them. |
| **Routing** | `SignalGraph`/`SignalRouter` (typed, persisted, general) vs. `ModulationMatrix`/`ModulationEngine` (bio→parameter) vs. `ParameterApplyRouter` | three route concepts, three persistence keys | 🟠 **Unify at the MODEL level** (`SignalGraph` is the superset), keep the engines. |

**Consequence for sequencing: the document unification (§9 slice M2) must land before any
new media domain**, otherwise a fifth owner is added to four.

---

## 9. MIGRATION PLAN — small reversible slices

Each slice: ≤3 production files where possible, one guard, green gates, independently
shippable, and **none of them makes a user-visible claim until §M7**.

| # | Slice | Why this order | Risk |
|---|---|---|---|
| **M1** | **`EchoelCore` module + `Timebase`/`TempoMap`/`MeterMap` as pure value types, Foundation-only, plus the import guard.** No call sites changed. | Everything else converts through it. Pure, exhaustively testable with no toolchain (transcribable in Python), immediately useful to audio, MIDI, video, light and session. | **Lowest.** Additive. Nothing reads it yet. |
| M2 | `DMMWProject` envelope + importer for the four existing documents. **Importer first, writer second.** Old files keep opening; new file not yet written. | Kills the four-owner problem before it becomes five. | Medium — needs decode fidelity tests per old format. |
| M3 | `Track` + `TrackPayload` envelope; `TimelineLane` becomes its `.midi`/`.audio` payload. Decoder keeps reading old lanes. | Unlocks every new media kind additively. | Medium. |
| M4 | **Audio input** — the one genuinely absent capability. New `AudioInputHost` protocol + adapter, behind a capability flag, silent by default. Re-derive the route/interruption handling from the `#1302` deletion but **do not restore the deleted files** (the `isInputConnToConverter` crash family is unsolved and is inherited with any input node — CLAUDE.md is explicit and correct about this). | Gates the whole "professional audio" pillar. | **HIGHEST of the early slices.** Device-only verification. |
| M5 | Re-door ONE dormant surface (recommend: the timeline, because the model, the store and two players already run). Consolidate the `.sheet` chain into one `.sheet(item:)` enum FIRST — the modifier ceiling is 13/14 and a new surface cannot just append. | Proves the "re-door, don't rebuild" thesis cheaply. | Medium — the black-screen law is real and already at budget. |
| M6 | `SessionNode` + `Capability` + the L2 timestamped event log, **loopback only**, no network. | Makes collaboration a model problem before it is a network problem. | Low (pure). |
| M7 | Update `PRODUCT_DEFINITION.md`, `CLAIMS.md`, the website and the App Store text — **only for what M1–M6 actually shipped.** | The repo's own hardest-won law: never claim ahead of code. | Low if honest. |

**Explicitly NOT in the early plan** (and each is a founder decision, not an omission):
VST3/CLAP hosting · RTMP/SRT link · Android/Windows/Linux targets · XR scenes ·
laser · on-device SLM. All are reachable from this architecture; none is the next step.

---

## 10. FIRST IMPLEMENTATION SLICE — recommendation

### `EchoelCore` + `Timebase` (M1)

**What it is:** a new SwiftPM target importing Foundation only, containing
`Timebase`, `TempoMap`, `MeterMap`, and the four position types
(`MusicalTime`, `SampleTime`, `WallTime`, `FrameTime`) with total, NaN-safe,
exhaustively-tested conversions — plus one guard asserting the target imports nothing
but Foundation (the `TheDSPLayerStaysFoundationOnlyTests` pattern, which already works).

**Why this one and not something visible:**
1. **It is the binding constraint.** Video, timecode, recording punch, network sync and
   conform all need it. Every other slice either waits for it or hard-codes a workaround
   that has to be undone — `TimelineRegion`'s dual trim is that workaround, already paid for once.
2. **It cannot become another dead subsystem.** It is not a surface; it is arithmetic
   that existing code will convert *through*. Dead code here is impossible because M2
   and M3 immediately consume it.
3. **It is provable in a web session with no Swift toolchain.** Pure value arithmetic
   transcribes to Python exactly, so the §0 grading discipline gives a real RED→GREEN
   instead of a transcription of a transcription.
4. **It establishes the portability boundary on day one** — the claim "Apple-first, not
   Apple-locked" becomes an executable guard rather than a paragraph.
5. **It touches no running code**, so it cannot destabilise the shipping instrument
   while ship-gates 1 and 5 are still open.

**Deliberately NOT chosen, with reasons:**
- *Audio input first* — highest-value to the founder, but it is device-gated, inherits
  an unsolved crash family, and would sit on a time model that is about to change.
- *Re-door the timeline first* — tempting because the machine already runs, but it spends
  the modal-ceiling budget before the document model is unified, and a surface over four
  competing documents makes the two-owner problem visible to users instead of fixing it.
- *A new DMMW document first* — right idea, wrong order: without `Timebase` it would
  store bare `Int`s again and need a migration in its own second slice.

---

## 11. RISKS / OPEN DECISIONS — separated as requested

### 11.1 TECHNICAL FACTS (measured, not opinion)
- The DAW **model** layer largely exists and runs headless; the UI is what was deleted.
- There is no seconds/samples/frames authority anywhere in the model layer.
- Four persisted document roots overlap.
- Audio input is genuinely, completely absent.
- The presentation-modifier chain is at **13 file-wide / 12 on the body**, ceiling 14.
  A new surface must consolidate first or it re-creates the 10.76.34 black-screen SIGSEGV.
- `Package.swift` has `dependencies: []`. No RTMP, no SRT, no HLS code exists.
- `SignalKind` already models `.video`/`.visual` and marks both `isLive = false`.
  `SignalTransport` already enumerates `rtmp`, `srt`, `ndi`, `auv3`, `midi2`,
  `abletonLink` as `.roadmap`. **The honest-roadmap scaffolding is already in the type
  system** — this is a genuine asset and should be extended, not replaced.

### 11.2 ARCHITECTURAL RECOMMENDATIONS (mine, arguable)
- `Track` = common struct + payload enum (§4.3).
- L2 collaboration as a timestamped event log, not state replication (§8).
- Extract `EchoelCore` before anything else (§10).
- Keep `PatternEngine` as the single clock authority; do not introduce a second.

### 11.3 FOUNDER DECISIONS STILL REQUIRED
1. **Does the shipping instrument keep shipping during the migration?** If yes, every
   slice must stay behind a capability flag and ship-gates 1/5 stay the release bar.
2. **VST3 licence** (GPLv3 or proprietary agreement) vs **CLAP only** (MIT). Legal, not technical.
3. **Ableton Link** — free but a C++ dependency; `CODE STYLE` permits it only
   Council-approved. DMMW's musical-sync story is much better with it.
4. **Subscription/pricing** — the v1.0-free / v1.1-subscription plan was written for an
   instrument. A workstation with collaboration and broadcast has recurring server cost.
5. **Does "global collaboration" imply a server we operate?** L2/L3 need relay + asset
   storage. That is an operating cost and a privacy decision (bio data must not transit).
6. **Which platform is second** — iPad (cheapest, needs a working bio source) vs macOS
   (unlocks plugins and the pro workflow) vs visionOS (the output-stage story).
7. **Whether the App Store listing stays "instrument"** during the whole migration.

### 11.4 DEVICE VERIFICATION REQUIRED
- Ship-gate 1 (Klang) and 5 (Stabilität) — still open, still founder-only.
- A11 — the measured ~20-percentage-point AUv3 DSP cost for one instance.
- A12 — should the plug-in drone at load.
- Audio input (M4) — route changes, interruptions, the 44.1/48 kHz mismatch, feedback.
- ~155 open `NEEDS-FOUNDER-VERIFY` markers (`python3 scripts/founder-verify.py`).

---

## 12. CANONICAL DECISION UPDATE — draft ADR wording

> DRAFT ONLY. Not written to `PRODUCT_DEFINITION.md`, `CLAUDE.md` or `decisions.csv`.
> Nothing is superseded until the founder says so.

### ADR-2026-09-21 — Echoelmusic becomes a DMMW

**Status:** ACCEPTED (founder, 2026-09-21). **Supersedes:** the 2026-07-25 product
definition ("pure bio-reactive instrument"), the retirement of "DMMW", and the
Editor ≠ Workstation boundary in its exclusionary form.

**Decision.** Echoelmusic is a **Digital / Distributed Multidimensional Multimedia
Workstation**: one project, one time model, one signal graph, many media domains, many
devices, many operating systems, many outputs. Audio, voice, MIDI/MPE, sampling, video,
360/spatial, visuals, lighting, XR, biofeedback and intelligent control are first-class
media domains sharing one document and one transport. Apple-first, **not** Apple-locked.

**What survives from the superseded definition, and why it is not a compromise:**
1. **"One bus. Adding a medium = adding a subscriber, never a new surface."** This was
   the best sentence in the retired definition and it is *more* true for a workstation.
2. **"The body plays it."** Bio is not a feature of the DMMW; it is Echoel's reason to
   exist and its differentiator. A DMMW without it is a worse Ableton.
3. **"Craft tools are instrument controls."** The note editor, patch editor and sampler
   return as craft tools that happen to sit on a timeline — not as a DAW cosplay.
4. **Every honesty law.** Claim only what ships; a doorless surface is written down;
   a number in an always-loaded file is a date. These are what make a scope this large
   survivable, and they get *harder* to keep, so they get stricter, not looser.

**What is explicitly reversed:**
- "There is no second product and no acronym" → DMMW is the product; the instrument is
  its flagship mode.
- The CUT list (timeline · arrangement · clips · multi-track · mixer · audio-file
  regions · video · AUv3 host · RTMP · subscriptions) → these move from **CUT** to
  **SEQUENCED**. None is forbidden; none is next.
- `docs/dev/DMMW_ARCHITECTURE.md` stops being "history only". It is re-opened as an
  input and must be re-verified line by line against HEAD before any of it is reused —
  it predates the deletions and will over-claim.

**What does NOT change, and this is the load-bearing clause:**
> **A capability is not claimed until it ships, is reachable, and is device-verified.**
> The DMMW decision changes the ROADMAP. It does not retroactively make anything true.
> `ContentPipeline/CLAIMS.md`, the App Store text and the website continue to describe
> only what a user can do today. Guards asserting that an absent capability is not sold
> are **not obstacles to the pivot** — they are the reason the pivot can be announced
> internally without becoming a 2.3 rejection externally.

**Consequence for the ship gate.** "Instrument-Complete v1" is **not** cancelled and is
**not** widened. It remains the bar for the CURRENT release, and its two open checks
(Klang, Stabilität) remain founder-and-device. DMMW work proceeds behind capability
flags on the same branch. **The first DMMW release is v2, not v1.**

### Guard-policy note for whoever executes the pivot

The blocking bundle contains guards written to prevent exactly what is now wanted.
**They must not be deleted en masse.** Three classes, three treatments:
- **Honesty guards that MEASURE their premise** — leave alone. They lift themselves the
  moment the capability is real. (#1410 proved this works, yesterday, in both directions.)
- **Honesty guards that HARD-CODE an absence** — edit in the same commit that makes the
  capability real, never before, never after.
- **Invariant guards** (audio thread, NaN, tempo T1–T3, render safety, naming) — these
  are the reason a scope this size is survivable. **Strengthen them.**

Deleting a guard to make room for a feature is how this repo got its worst bugs.

---

## 1. CURRENT-STATE AUDIT — file-level evidence

### 1.A NETWORK / COLLABORATION / BROADCAST / PLATFORM  *(measured 2026-09-21)*

**LIVE and reachable**
- **Collaboration.** `MultipeerSession` (`Sync/MultipeerSession.swift:52`) → constructed
  `EchoelmusicApp.swift:99`, injected `:601`. `LiveColaboView` is **doored** — a real tile
  in `EchoelStudioView.swift:2395` → `.sheet` at `:1684`. Wire carries exactly TWO message
  kinds (`ColabPayload.kind`): `"session"` (a whole `Project`, reliable, on tap) and
  `"bio"` (5-field `BioPeek`, unreliable, every 0.4 s).
- **OSC/ADM/Art-Net/sACN** — 5 files import `Network`, all in `Sync/`, each with exactly one
  construction site in `EchoelmusicApp`. `OSCReceiver` is the **only listening socket** in
  the app (UDP 8001, opt-in OFF, prefix + sender allowlist), doored in `PatchbayView`.
- **Bio** — `CameraRPPGBioPublisher`, `HealthKitBioPublisher`, `PolarH10BioPublisher`
  (standard SIG `180D`/`2A37`, not vendor-locked despite the name), `BioSimulator`.

**DORMANT (built, gated — keep)**
- `AnnouncementCenter`/CloudKit: gated by ONE literal,
  `AnnouncementCenter.swift:48 cloudKitConfigured = false`; three short-circuits; zero CK calls execute.
- `BroadcastPublisher`: 100 lines; behind `#if canImport(HaishinKit)` there is **a string
  assignment and nothing else**; `isLive` is never set true anywhere. `BroadcastView`: zero
  construction sites. `Package.swift dependencies: []` verified literally.
- `EchoelmusicWatch`: target compiles, **not embedded** (`project.yml:224` commented out).

**DEAD**
- `Core/CloudSync` — every reference outside its own file is in the NON-blocking test suite.
  Its own comment says the stores *"will conform in Phase 1"*; none ever did.
- `BioSource.oura` (2) and `.watch` (4) — **zero producers.** Measured: the only
  `source:` construction sites are `.fallback`, `.cameraPPG` ×2, `.healthKit`, `.ble` ×2.
  `.watch` still carries a live 90 s `freshnessWindow` branch that no frame can reach.
- `ColabPayload` kinds `"tempo"` and `"chat"` — reserved in a comment, never constructed.

**ABSENT** — all RTMP/SRT/HLS code · HaishinKit · every external dependency ·
`WatchConnectivity`/`WCSession` (zero code; the 3 grep hits are comments) · Ableton Link ·
NDI · App Clip target · Notification Service target · **any HTTP/`URLSession` at all**.

### 1.B TWO DEFECTS THAT ARE ACTIONABLE NOW, INDEPENDENT OF DMMW

> These are not migration items. They are true today, on the shipping build, and both are
> the repo's own "claim only what ships" law being broken in a place no guard was watching.

1. 🔴 **User-facing over-claim in the collaboration door.**
   `Studio/EchoelStudioView.swift:2403`
   `.accessibilityHint("Opens the nearby-session sheet to play together on one tempo")`
   **There is no tempo or clock transport of any kind.** `"tempo"` is a reserved-and-never-sent
   payload kind; Ableton Link is an unlinked enum case; the wire carries no clock; and
   `ColabPayload.swift:191` says so itself ("Two phones are not clock-synchronised").
   The file that implements it is honest; the VoiceOver hint is not. **A blind user is told
   the app does something it cannot do.** This is the #1410 shape again — an over-claim in
   the one surface nobody re-reads — and it deserves its own slice + guard.

2. 🟠 **`NSBonjourServices` declares 9 services; 4 are justified by code.**
   `Resources/iOS/Info.plist:102-112`. Justified: `_echoel-colab._tcp`/`._udp`
   (`MultipeerSession.serviceType`), `_midi._udp`/`_apple-midi._udp` (`MIDIInput.swift:139`).
   **Unjustified: `_http._tcp` and `_rtsp._tcp`** — there is no HTTP client and no
   RTSP/streaming code anywhere. Also unused: `_artnet._udp`, `_osc._udp`, `_echoelmusic._tcp`
   (the senders open direct `NWConnection`s to typed addresses and browse nothing).
   **Declaring `_rtsp._tcp` on an app with zero streaming code invites an App Review
   question.** `Info.plist` is **founder-gated — reported, not edited.**

### 1.C FOUR MORE STALE-PROSE FINDINGS (same class as #1410, all measured)

| Where | Claims | Measured |
|---|---|---|
| `CLAUDE.md` TECH STACK | "`git grep -l AVAssetWriter -- Sources` → 0" | **3 files match.** One is a LIVE `AVAssetWriter` in `Audio/SingleExport.swift:245` (audio export). The video half of the claim is true; the quoted recipe refutes itself. |
| `CLAUDE.md` IDENTITY, bundle line | lists `.app.clip` and `.app.notification-service` as deferred bundles | **Neither exists** as target, source or entitlement in `project.yml`. "Deferred" reads as backlog; they are absent. |
| `Package.swift`, `// No exclude:` block | "`Sources/` holds only Echoelmusic, EchoelmusicWatch and EchoelmusicWidgets" | **Four** directories since #1385 added `Sources/EchoelmusicAUv3`. |
| `EchoelmusicWatch/EchoelWatchApp.swift:17` | quotes a grep "returns NOTHING" | now returns **3 hits** — its own comment block. Fact true, proof self-refuting. Measure with `git grep -n "import WatchConnectivity\|WCSession(" -- Sources`. |
| `Core/CloudSync.swift:75` | stores "**will** conform in Phase 1" | never happened; forward-looking comment has become a false status line. |
| `.env.example:42` | `iCloud.com.echoelmusic` | entitlements + code say `iCloud.com.echoelmusic.app`. Harmless today, a trap the day the CloudKit gate flips. |

### 1.D PLATFORM CONFIGURATION — measured

Six XcodeGen targets; **three embedded** (`Echoelmusic` host, `EchoelmusicAUv3`,
`EchoelmusicWidgets`), Watch **not** embedded. `Package.swift` declares only **two**
targets and knows nothing of Watch/Widgets/AUv3 — by design, with one stale comment.
`TARGETED_DEVICE_FAMILY` is `"1"` on five targets and `"4"` on the Watch.

**AUv3 isolation, measured from `project.yml:258-277`:** the extension compiles
`Sources/EchoelmusicAUv3` + the **whole** `Sources/Echoelmusic/DSP` directory + **exactly
three** `Core/` files (`BioFeedbackManager`, `NumericExtensions`, `FloatingPointClamp`).
⭐ **This is the proof that the portability boundary in §4.2 is achievable: it already
exists, in a shipping target, and is enforced by the build.** `EchoelCore` is the same
move one layer up.

### 1.E BIO SOURCES — the founder asked for capability-based; measured, it is not

`git grep "protocol .*Bio" -- Sources` → **zero**. There is **no bio-source protocol**.
Each publisher is an independent `@Observable` class with its own `start(publishing: bus)`,
so adding a source means hand-editing `startBioSource`/`stopBioSource`/`selectBioSource`.

`BioSource` (`Core/EngineBus.swift:488`) is a **device enum** — `fallback, healthKit, oura,
ble, watch, cameraPPG` — and capability is **derived from the case** by four computed
properties (`providesTrustedHRV` → `.ble` only; `providesBreathWaveform` → `.cameraPPG ||
.fallback`; `isSynthetic`; `freshnessWindow`).

**Verdict: the right INSTINCT is already in the code and the wrong SHAPE.** Deriving
capability from a device case is exactly the architecture the founder's point 10 rules out —
it cannot express "an EEG headset that also reports respiration" without a new case plus
four `switch` edits, and `.oura`/`.watch` prove the failure mode: two cases with live
capability branches and zero producers.

**Recommended (in `EchoelCore`, M6-adjacent):**
```
BioSignalClass  { heartRate, hrv, ecg, eeg, emg, respiration, spo2, temperature,
                  motion, orientation, gaze, handTracking, bodyTracking }
BioSourceDescriptor { id, displayName, provides: Set<BioSignalClass>,
                      trustLevel: [BioSignalClass: Trust], freshnessWindow, isSynthetic }
protocol BioSourceAdapter { var descriptor: BioSourceDescriptor { get }
                            func start(publishing: EngineBus); func stop() }
```
The existing four publishers conform without behaviour change; the enum stays as a
**stable persisted/OSC discriminant** (it is deliberately not `Codable` today — keep that),
and the capability questions move to the descriptor. `.oura`/`.watch` then become
descriptors nobody registers rather than dead cases with live branches.

⚠️ **Do not delete `BioSource` while doing this.** It is the `/echoelmusic/bio/synthetic`
provenance discriminant on the wire and the thing `OneSpellingOfWhoseBodyItIsTests` pins.

### 1.F VIDEO / VISUAL / LIGHT / SPATIAL  *(measured 2026-09-21)*

**`Sources/Echoelmusic/Video/` is 100 % the rPPG PULSE path. There is no video capture.**
Four files; imports are `Foundation, AVFoundation, Accelerate, CoreImage, UIKit` — no
VideoToolbox, no Vision, no ARKit. `AVCaptureSession` exists at `CameraCapture.swift:13`
but: preset `.low`, 32BGRA, **15 fps**, **back camera hard-coded** (`position: .front`
occurs **0 times**), and the only frame sink pushes into `RGBSampleQueue`. **Pixels reach
nothing else** — no texture, no encoder, no display layer.

⭐ **Useful for DMMW §4 (professional camera): the photometric control layer partly EXISTS.**
`lockExposure()` already does `setExposureModeCustom(duration:iso:)` with a clamped ISO
(`:344-347`), locks white balance (`:369`) and drives the torch with a thermal ceiling
(`:273`). **Focus and zoom are untouched** (`focusMode`, `videoZoomFactor` → 0 hits).
So "manual exposure/ISO/WB" is a *generalisation* of working code, not a build-from-zero;
"focus/scopes/codecs/multicam" is genuinely new.

**Video recording/editing remnants: CONFIRMED ABSENT.** `VideoRecorder`, `VisualRecorder`,
`VideoMuxer`, `ClipTrimmer`, `CameraSession` — zero declarations, zero sites. The only
`AVAssetWriter` in the repo is **audio-only** (`Audio/SingleExport.swift:245`).

**⭐ EXTERNAL DISPLAY / PROJECTION IS REAL AND LIVE — the biggest unclaimed DMMW asset.**
`ExternalDisplaySceneDelegate` (`Studio/ExternalDisplayScene.swift:73`) is a
`UIWindowSceneDelegate` instantiated **by UIKit from `Info.plist:38-44`**, not from Swift.
On connect it mounts `UIHostingController(rootView: ExternalStageView())` with
`isUserInteractionEnabled = false`; `ExternalStageView:255` mounts `MetalBioView` with the
same look keys, and `ExternalStageBridge` (singleton, wired `EchoelmusicApp.swift:688`)
enforces a one-renderer law so the phone yields its renderer to the stage.
**A second screen / beamer output already works today.** `UIScreen` = 0 hits.
⚠️ Renaming the delegate type silently kills the feature — the only reference is a plist string.

**Lighting: LIVE ON THE WIRE.** `ArtNetSender` and `SACNSender` each have one construction
site, are started from `hasEnabledRoute(toSink:)` and open real `NWConnection`s. The
**3 Hz flash law is enforced in the tick interval** (`FlashGuard.senderTickMilliseconds`),
not in a view. `LightFixture`/`LightFixtureGroup`: zero references — dead cores.
⚠️ `EchoelLux` is **not a type** — a module label in comments plus a header tile.

**Spatial: control half live, render half dead — but narrower than documented.**
`ADMOSCSender` sends `/adm/obj/{n}/{azim,elev,dist,gain}` at 20 Hz, doored via `PatchbayView`.
⚠️ **BUT the SCENE-streaming half is unreachable**: `streamsScene` has exactly one writer,
a `Toggle` inside the doorless `ImmersiveStageView`, so `send(scene:)` can never fire.
**Only the bio→object path reaches the wire.** And `sceneDialect` has **no writer at all**,
so the `.admOSCCartesian` and `.iemMultiEncoder` dialects are dead code paths.
Render half — `VBAPPanner`, `AmbisonicsEncode`, `BinauralPanner`, `EchoelSpaceReverb`,
`SpatialAutomationMapping`, `BioSpaceMap`, `BioPhaser` — **all zero references.**

**360 / spatial video: NOTHING EXISTS.** `equirectangular`, `spherical`, `reframe`,
`fieldOfView`, `spatialVideo` → 0 hits. `RealityKit`/`SceneKit`/`Vision` → 0 imports.
`visionOS` → 2 hits, both **prose banners**, not platform guards (CLAUDE.md calls them
guards; the count is right and the description is wrong).
⚠️ `Bio/EchoelBioEngine.swift:95` and `:539` carry `case arkit = "ARKit Face"` — a
**user-visible rawValue naming a framework the project never imports** and a capability
deleted in #1301. No guard covers it.

**Visuals: the picture is thinner than it looks.**
- `MetalBioView` compiles its MSL **inline at runtime** from a string literal (`:1786`),
  ships zero `.metal` files, pins 60 fps statically (`:533`).
- Uniforms are **99 contiguous floats hand-mirrored by BYTE LAYOUT** between Swift
  (`:45`) and MSL (`:1791`) with **no compiler check**. `hr` is uploaded every frame and
  read by no shader code — kept only because removing it would shift 98 following fields.
  🔴 **For DMMW this is a structural liability**: every new visual parameter is a
  two-sided manual edit with a silent failure mode. It needs a generated or reflected
  layout before the visual domain grows.
- 🔴 **5 of 6 `BioVisualParams` fields are DEAD.** Measured: the only live read is
  `MetalBioView.swift:1398 vp.pulseHz`. `pattern`, `hue`, `complexity`, `spread`,
  `intensity` are computed every frame and consumed by nothing — and `complexity` is the
  app's **only HRV→picture path.** **The app has no live HRV→visual mapping today.**
  This must not be claimed in any DMMW copy.
- `AdaptiveQuality`: `visualDetailScale` and `reduceMotion` live; `bioHz` live with exactly
  one consumer (the OSC rate ceiling); **`oscHz` and `allowSpectralDonuts` have zero
  consumers**; `targetFPS` is a tier *reference*, never applied. CLAUDE.md is accurate here.

### 1.G 🔴 THREE STALE PERMISSION PROMISES IN `Info.plist` — founder-gated, REPORTED

`Resources/iOS/Info.plist` promises the user three capabilities the app does not have.
These are privacy strings; they drive App Review and the privacy nutrition label.

| Key | Line | Promises | Measured |
|---|---|---|---|
| `NSMicrophoneUsageDescription` | 84 | microphone use | **no microphone since #1302** |
| `NSPhotoLibraryAddUsageDescription` | 92 | *"Finished visual recordings are saved to your photo library"* | **zero `Photos`/`PHPhotoLibrary` references in `Sources/`**, and video recording was deleted in #1304 |
| `NSCameraUsageDescription` | 90 | *"facial movement from the front camera"* | face source deleted #1301; `position: .front` occurs **0 times** — the app only ever opens the BACK camera |

⚠️ The camera one is the subtle case and the existing guard says so itself
(`EveryPermissionPromptHasACapabilityTests:97-104`): its needles `AVCaptureSession`/
`AVCaptureDevice` **are** satisfied by the rPPG path, so a half-dead string passes. A
string can over-claim within a live permission. **That is the §AH under-claim lesson in
its mirror form and it is not currently guarded.**

`.github/workflows/**`, `project.yml` and `Info.plist` are founder-gated: **reported, not edited.**

> ✔ The three permission strings above were re-verified first-hand at `7648150a7`, not
> taken from the audit: `Info.plist:85/91/93` read as quoted; `import Photos` /
> `PHPhotoLibrary` / `UIImageWriteToSavedPhotosAlbum` → **zero** matches in `Sources/`;
> `position: .front` → **zero** matches. The camera string additionally promises
> "facial movement from the front camera as a control signal".

---

## 3. KEEP / EXTRACT / REWRITE / DELETE MATRIX

Legend — **KEEP** = leave where it is · **EXTRACT** = move into `EchoelCore`, Foundation-only ·
**REWRITE** = the shape is wrong for DMMW · **SUPERSEDE** = replaced by a new owner, old one
kept until its importer exists · **DELETE** = remove · **BUILD** = does not exist.

| Subsystem | Today | Action | Reasoning |
|---|---|---|---|
| `EngineBus` + `SPSCQueue` | live, 3 topics | **KEEP + EXTRACT the value types** | The control/realtime split is the single most valuable thing in the repo. `BioSampleFrame`/`ControllerEvent`/`BioEvent` are Foundation-only already. |
| `PatternEngine` (clock authority) | live | **KEEP** | One authority. Do not add a second clock. |
| `Transport` (fan-out) | live | **KEEP + EXTEND** | Gains `Timebase`/`TempoMap`; keeps its subscriber model. |
| Time conversion | **does not exist** | **BUILD (M1)** | The binding constraint for video/timecode/network. §7. |
| `TimelineDocument`/`TimelineLane`/`TimelineRegion` | live, persisted, headless | **KEEP + EXTRACT + REWRITE the lane into `Track`+payload** | 80 % of a DMMW track model already exists (per-lane patch, genre, mood, transpose, detune, mixer, arm). §4.3. |
| `Clip` / `ClipKind` / `ClipStore` | live | **KEEP + EXTRACT** | `.midi/.audio/.video/.visual` already modelled; `timelineEngineKinds` is a deliberate one-line extension point. |
| `Project` (one take) | live, persisted, user data | **SUPERSEDE, never delete** | Becomes a take/preset inside `DMMWProject`. Deleting it destroys saved user work. |
| `Arrangement` + `ArrangementStore` | live | **SUPERSEDE** | Folds into `scenes`. Importer first. |
| `SignalGraph` / `SignalRouter` | live, persisted, typed | **KEEP + EXTRACT — this is the "one signal graph"** | Already has kind/transport/direction/converter/route and an honest `.live`/`.roadmap` status split. Extend, do not replace. |
| `ModulationMatrix` / `ModulationEngine` | live, doored (#1250/#1391) | **KEEP, unify at model level** | Third route concept; make it a projection of `SignalGraph`, keep the engine. |
| `MediaLibrary` + `Clip.mediaRef` | live | **KEEP → grows into `MediaPool`** | Asset-by-reference is already the shape. Add id, checksum, proxies. |
| `AudioEngine` + `AutoMixChain` + `SingleExport` + `RetroCapture` | live | **KEEP**, hide behind `AudioEngineHost` | Working, device-proven. The protocol is the portability seam. |
| **Audio INPUT** | **absent** | **BUILD (M4)** | The only pillar with nothing to reuse. Inherits an unsolved crash family — §9/M4. |
| `Video/` (rPPG) | live | **KEEP, RENAME the directory** | It is the flagship bio sensor, not video. The name is a live deletion hazard. |
| Camera photometrics | partial (exposure/ISO/WB/torch) | **EXTRACT + EXTEND** | Generalise the existing lock path; focus/zoom/scopes/codecs are new. |
| Video capture/edit | absent | **BUILD** | Nothing to revive. Do **not** restore deleted files. |
| `MetalBioView` | live | **KEEP + REWRITE the uniform bridge** | 99 hand-mirrored floats with no compiler check does not scale to a visual domain. |
| `BioVisualParams` | live struct, **5/6 fields dead** | **KEEP + WIRE** | Cheapest real win in the visual domain: `complexity` is the only HRV→picture path and it is unconsumed. |
| `ExternalDisplayScene*` | **live** | **KEEP — and claim it** | Second-screen/beamer output already works and is not in any product copy. |
| Art-Net / sACN | live on the wire | **KEEP + EXTRACT the packet builders** | 3 Hz flash law enforced at the tick. Portable as-is. |
| `LightFixture(Group)` | dead cores | **KEEP dormant** | The fixture model DMMW needs; zero cost. |
| `ADMOSCSender` + `SpatialSceneStore` | control half live; scene half doorless | **KEEP + RE-DOOR `ImmersiveStageView`** | Re-dooring one parent revives three unreachable features at once. |
| Spatial RENDER half (7 cores) | dead | **KEEP dormant, do not claim** | Real DSP, no callers. Revive only with a founder ask. |
| `MultipeerSession` | live, doored | **KEEP as the L1 transport; REWRITE the payload** | Two ad-hoc JSON kinds, no clock, no participants, no versioning → becomes the L2 event log. §8. |
| `BroadcastPublisher` / `BroadcastView` | scaffold, `isLive` never true | **REWRITE as `BroadcastSink` protocol** | Keep the UI as a reference; the type must not name a vendor. §4.5. |
| `Core/CloudSync` | test-only, zero prod callers | **KEEP dormant** | Its LWW design is reusable for L3 conform. Do not claim; do not delete. |
| `AnnouncementCenter` | built, one `false` literal | **KEEP gated** | Flip only after the CloudKit schema is deployed to Production. |
| `BioSource` enum | live discriminant | **KEEP + ADD descriptors** | §1.E. Enum stays as the wire/persistence discriminant; capability moves to a descriptor. |
| `.oura` / `.watch` cases | zero producers, live branches | **KEEP the cases, DELETE nothing** | Unknown rawValue on decode is a known data-loss shape here. Mark the branches. |
| `EchoelStore`/`ProGate`/`ProUnlockView` | compiles, unreachable | **KEEP for repurposing** | Pricing is an open founder decision (§11.3). |
| `SessionView`/`SessionEngine`/`EntrainmentEngine` | compiles, nothing presents it | **KEEP** | Holds tested flash-safety/pacing laws. Reusable for XR. |
| Protected Rausch triad | live | **KEEP, READ-ONLY** | Unchanged by this pivot. |
| `EchoelCellular` | sounds in the AUv3 only | **KEEP + OPTIMISE (A11)** | ~20 pp DSP for one instance; scalar `sin()` in `renderAdditive`. |
| `EchoelModalBank` | zero instantiations | **KEEP dormant** | A modal/physical voice is squarely in DMMW scope. |
| `_http._tcp` / `_rtsp._tcp` Bonjour | declared, unused | **DELETE** (founder-gated) | An App Review liability for zero benefit. |
| `arkit = "ARKit Face"` rawValue | user-visible dead label | **DELETE or rename** | Names an unimported framework and a deleted capability. |

---

## 2. CONTRADICTION MAP

### 2.A ALWAYS-LOADED LAW (`CLAUDE.md`, `.claude/rules/*`) vs. the DMMW decision

| Law, as written today | Conflict | Treatment |
|---|---|---|
| *"Echoel is a bio-reactive instrument… There is no second product and no acronym."* | **Direct.** DMMW is a second framing and an acronym. | **SUPERSEDE** via the ADR in §12. |
| *"THE BOUNDARY… Editor ≠ Workstation"* + the CUT list (timeline · arrangement · clips · multi-track · mixer · audio-file regions · video edit · AUv3 host · RTMP · subscriptions) | **Direct, and it is the load-bearing decision rule** a session applies to every keep/cut. | **SUPERSEDE.** Replace "CUT" with "SEQUENCED" — nothing forbidden, nothing next. |
| *"`DMMW_ARCHITECTURE.md` is superseded — history only, do not plan from it."* | **Direct.** | **REOPEN as input, with a warning**: it predates the deletions and will over-claim. Re-verify line by line. |
| *"Adding a medium = adding a subscriber, never a new surface."* | **None — this SURVIVES and should be promoted.** | **KEEP.** It is the rule that makes nine media domains affordable. |
| SHIP GATE "Instrument-Complete v1", five checks | **Apparent, not real.** It is the bar for the CURRENT release. | **KEEP unchanged.** DMMW is v2. Widening v1 would put an unreachable gate on a shipping build. |
| Presentation ceiling: **13 file-wide / 12 on the body, budget 14** | **Hard structural block.** DMMW needs many surfaces; the chain is one below its cap and the overflow mode is a SIGSEGV black screen. | **BLOCKING PREREQUISITE.** Consolidate to one `.sheet(item:)` enum before any new surface (§9/M5). |
| `DO NOT: Create new targets or top-level dirs` | **Direct** — the module map (§5) is exactly that. | **Founder approval required.** Listed in §11.3. |
| `DO NOT: Add dependencies without asking` + *"no PAID frameworks (no JUCE), no CMake"* | **Partial.** CLAP is MIT; Ableton Link is already carved out as Council-gated; VST3's licence is the real question. | **Founder + Council.** §11.3 items 2–3. |
| Positioning: *"The first bio-reactive performance instrument"* | Narrower than DMMW, **but it is the differentiator** — see §12. | **KEEP as the flagship claim**, widen the product. |
| `TARGETED_DEVICE_FAMILY = "1"` on five targets + `DeviceFamilyIsPhoneOnlyTests` (hard equality, blocking bundle) | **Direct** with the iPad/macOS platform family. | **Edit only in the commit that actually enables a platform**, never in advance. |
| **TEMPO INVARIANT T1–T3** | **Not a conflict — a REQUIREMENT that grows.** T1 says tempo sources are *enumerable and logged*; DMMW adds a sixth (a remote peer's transport). | **KEEP and EXTEND.** Add `.remotePeer` to the enumeration in the same slice that lands network transport — never let an un-enumerated source reach the clock. |
| Audio-thread bans, NaN clamps, render-safety, `EchoelValueField`, 3 Hz flash ceiling | **No conflict.** | **STRENGTHEN.** These are what make a scope this size survivable. |
| *"Absent (not wired — do not claim as shipping)"* register | **No conflict** — it is a statement about today, not about the roadmap. | **KEEP and maintain.** It is the mechanism that keeps the pivot honest externally. |

### 2.B THE ONE LAW THAT MUST NOT BE TOUCHED

> **Claim only what ships.**

Every guard that enforces it (`ContentPipeline/CLAIMS.md`, the website honesty tests, the
store-text test, `EveryPermissionPromptHasACapabilityTests`) reads, from the outside, like
an obstacle to a pivot. It is the opposite: it is the only reason a scope this large can be
*decided* internally today without becoming a 2.3 rejection or a broken promise externally.
**A DMMW decision changes the roadmap. It does not retroactively make anything true.**

The three stale permission strings in §1.G and the collaboration over-claim in §1.B are
proof that this law is *already* leaking in the places nobody re-reads — before any DMMW
work has started. Widening the scope without tightening that discipline is the single
fastest way to turn this repo's documentation back into fiction.

---

## 4.6 INTELLIGENCE LAYER — ⭐ the founder's point 12 is already built in outline

This was the biggest surprise of the audit. Measured in `Sources/Echoelmusic/EchoelAI/`
(three files) plus `Core/`:

| Piece | File | What it already is |
|---|---|---|
| `protocol BrainBackend: Sendable` | `EchoelAI/BrainBackend.swift:22` | **provider-independent** by construction: `isAvailable` (async) + `respond(to:)`. Nothing above it names a vendor. |
| `FoundationModelsBrain` | `EchoelAI/FoundationModelsBrain.swift:24` | **one adapter** behind that protocol. Tier 2 (MLX) is named as a future conformer. |
| `ParameterToolCore.set/list` | `EchoelAI/ParameterToolCore.swift:30` | **the deterministic tool**: validates the keyPath against the registry, denormalises into the descriptor's real range, applies on the **control plane**, returns a typed `ParameterSetResult`. An unknown keyPath **throws a correctable error instead of a silent no-op.** |
| `EchoelParameterRegistry` | `Core/EchoelParameterRegistry.swift:72` | the catalog — "what can be automated". Constructed live at `EchoelmusicApp.swift:367`. |
| `ParameterApplyRouter` | `Core/ParameterApplyRouter.swift` | **LIVE.** `bind`/`applyNormalized`/`applyReal`/`automatableDescriptors()` = registry ∩ bound setter. Already the source of truth for the modulation matrix's destination list (#1391). |

And the realtime law the founder asked for is **already written into the file header**
(`BrainBackend.swift:5-7`), in almost the founder's own words:

> *"Tier 3 does not exist: realtime biosignal modulation NEVER goes through a language
> model — the planner configures control-plane mappings, EngineBus + DSP do the work."*

**What is missing is exactly two things, and neither is architecture:**
1. **A caller.** `FeatureFlags.echoelAI` has **zero readers** (`git grep -n
   "FeatureFlags.echoelAI" -- Sources` → one COMMENT hit). Nothing is behind the flag;
   the pieces are off for lack of a caller, not for lack of a gate. **Never rely on that
   flag as a guard** — it gates nothing.
2. **The action VOCABULARY.** Today the only tool is `setParameter`. The founder's example
   ("make the vocal warmer and wider but safe for stage use" →
   `SetCompressor` · `SetSaturation` · `SetHarmony` · `SetReverb` · `CreateAutomation`)
   needs composite, undoable, inspectable `ToolAction` values — not more backends.

**Recommendation:** model `ToolAction` as a **Codable value type in `EchoelCore`**, executed
by a command bus that is also the undo journal and (§8) the L2 network event. One
representation serves AI actions, user edits, undo/redo and collaboration. **Three of the
founder's requirements collapse into one mechanism if it is done once, and into three
divergent mechanisms if it is done three times.** That is the strongest argument in this
document for doing the core extraction (M1/M2) before any feature.

⚠️ **Do not add a second AI abstraction.** `Core/EchoelLanguageModel.swift` already owns the
error surface (`EchoelAIError`), and `BrainBackend.swift:13-17` records that this was
*already* discovered the hard way once ("red-gate lesson 2026-07-12: this module already
had the enum; one error type app-wide"). A DMMW intelligence layer that introduces its own
`AIError` repeats a mistake this repo has already paid for.

---

## 10b. FIRST SLICE — concrete sketch (`EchoelCore/Timebase.swift`)

Not code to commit; a shape to agree on.

```swift
// EchoelCore — Foundation only. No AVFoundation, no CoreMedia, no Metal.

public struct MusicalTime: Hashable, Comparable, Codable, Sendable {
    public var ticks: Int64                       // PPQ-based, signed
}
public struct SampleTime: Hashable, Comparable, Codable, Sendable {
    public var frames: Int64
    public var sampleRate: Double                 // CARRIED, never assumed
}
public struct WallTime: Hashable, Comparable, Codable, Sendable {
    public var seconds: Double                    // finite by construction
}
public struct FrameTime: Hashable, Comparable, Codable, Sendable {
    public var frames: Int64
    public var rate: VideoFrameRate               // .fps24 .fps25 .fps30 .fps2997df .fps50 .fps5994df .fps60
}

public struct TempoMap: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var atTick: Int64
        public var bpm: Double                    // > 0, finite
        public var curve: Curve                   // .step | .linear
    }
    public var entries: [Entry]                   // sorted, non-empty, first.atTick == 0
    public func seconds(at: MusicalTime, ppq: Int) -> WallTime
    public func ticks(at: WallTime, ppq: Int) -> MusicalTime
}

public struct Timebase: Codable, Sendable, Equatable {
    public var ppq: Int                           // e.g. 960
    public var sampleRate: Double                 // project render rate
    public var frameRate: VideoFrameRate
    public var tempoMap: TempoMap
    public var meterMap: MeterMap
    // total conversions, every pair, NaN/inf-safe, no trapping arithmetic
}
```

### The five properties the guard must pin (all transcribable in Python — no toolchain needed)

1. **Round-trip within one tick / one frame** across a randomised tempo map, including
   tempo changes mid-range and a non-zero start.
2. **Monotonicity**: `a < b` in any space implies `convert(a) <= convert(b)` in every other.
3. **Drop-frame correctness**: 29.97 df and 59.94 df timecode must land on the SMPTE
   reference values at 1 min, 10 min and 1 h — the classic defect, pinned by table,
   never by a scale factor.
4. **Total on hostile input**: NaN, ±inf, negative, zero sample rate, empty/unsorted
   tempo map, `bpm = 0` → a defined clamped result, never a trap and never a NaN out.
   (This repo has shipped a permanent-silence bug from `min(max(v, lo), hi)` passing NaN
   through — `.claude/rules` records it. Use the NaN-safe `clamped(to:)` shape.)
5. **`SampleTime` carries its rate.** A conversion between two `SampleTime`s of different
   rates must resample explicitly, never compare `frames` directly.

### Why it is safe to land while v1 is still shipping
It has **no call sites**. Nothing reads it until M2. `Xcode Compile Check` proves it
compiles; `Build for Testing` proves the guard compiles; the §0 transcription proves the
arithmetic. Ship-gates 1 and 5 are untouched because no running code changes.

### Definition of done for M1
- `EchoelCore` target exists, imports Foundation only, enforced by a guard in the
  BLOCKING bundle modelled on `TheDSPLayerStaysFoundationOnlyTests`.
- `Timebase`/`TempoMap`/`MeterMap` + the four position types, total and NaN-safe.
- One guard file, the five properties above, graded RED→GREEN by transcription.
- **Zero production call sites.** If M1 needs to change a caller, M1 is wrong.

### 1.H ⭐ THE CAPABILITY-GATE MECHANISM EXISTS, AND ITS VOCABULARY IS ALREADY DMMW-SHAPED

`Core/FeatureFlags.swift` declares **fifteen** flags, and they survived the pure-instrument
epic untouched:

```
spatialEngine · bioSpace · echoelRender · motionEngine · showControl · avObjects
performerTracking · liveCollab · headTracking · echoelAI · storeKit · multiRoll
voiceKindRouting · audioLaneRecording · instrumentHome
```

That list is a **DMMW vocabulary** — show control, AV objects, performer tracking, head
tracking, live collab, spatial engine — written during the earlier DMMW period and never
removed. The mechanism the migration needs in order to land slices without changing
shipping behaviour is therefore already in place, and `EveryFlagSaysWhatItGatesTests`
already forces each flag to name what it gates.

⚠️ **Two cautions, both measured:**
- `audioLaneRecording` has had **no branch since #1302** — it gates nothing.
- `echoelAI` has **zero readers**. **Never rely on it as a safety gate** (§4.6).

So: reuse the mechanism; **re-verify each flag's branch before trusting it**, because two
of fifteen are already hollow. A hollow flag is worse than no flag — it reads as a safety
net that is not there.

---

### 2.C EXECUTABLE GUARDS — the blocking bundle, classified

`git ls-files 'Tests/CISmoke/*.swift' | wc -l` → **552**.

| Class | Count | What it does at the pivot |
|---|---|---|
| **A — HONESTY** (reads `docs/`, `fastlane/`, `ContentPipeline/`, `CLAUDE.md`, board) | **64** | Red when COPY changes to sell DMMW, or when a capability returns and copy does not move in the same commit |
| **B — ABSENCE** (asserts a type/door/producer is absent from `Sources/`) | **43** | Red directly on rebuild |
| **C — INVARIANT** (audio thread, NaN, tempo, render safety, schema, a11y, genre) | **445** | **Survive. Assets. Strengthen them.** |

⭐ **The structural fact that changes how all of this reads:** most of these guards are
**deliberately not prohibitions.** The repo's own #364/#926 convention is *"this guard does
not forbid the return, it names the prose that travels with it."* A red usually means
*"rebuild is fine — move the named prose in the SAME commit."* That is why the pivot is
survivable at all.

### 2.D 🔴 THE REAL BLOCKER ORDERING — and the first one is not what anyone would guess

| # | Guard | Reds when | Headroom |
|---|---|---|---|
| **1** | **`TheLawFileStaysUnderItsCeilingTests`** | **on the FIRST pivot commit, before any code changes** | `ceilingBytes = 150_000`; `CLAUDE.md` = **149,157 B** → **843 B** ✔ verified |
| **2** | **`ResetSoundClearsWhatTheLaunchLineReportsTests`** | on the first new door | `XCTAssertEqual(modals.count, 13)` — **EXACT equality, ZERO headroom**; the body-chain assertion is `<= 14` with chain = 12 → 2 ✔ verified |
| 3 | `TheStoreTextClaimsOnlyWhatShipsTests` | on the first copy change | ~30-word banned list covering **every** DMMW term (`auv3`, `rtmp`, `multitrack`, `beat maker`, `step sequencer`, `piano roll`, `note editor`, `video capture`, …) |
| 4 | `EveryFlagSaysWhatItGatesTests` | on wiring any dormant flag | **exact-SET equality** over 11 unread flags — incl. `audioLaneRecording`, `liveCollab`, `spatialEngine`, `showControl` ✔ verified |
| 5 | `EveryPermissionPromptHasACapabilityTests` | the instant `.inputNode` / `requestRecordPermission` / `AVAudioRecorder` / `PHPhotoLibrary` returns | self-lifting: "move the row back into `table` in this same commit" |
| 6 | `ContentPipelineClaimsTests` | on linking ANY dependency | asserts `Package.swift` has no dependencies AND `project.yml` has no `packages:` ⇒ **HaishinKit/CLAP/VST3/Link cannot be linked without editing it** |
| 7 | `TheAudioLanesHaveNoProducerTests` | on multitrack rebuild | pins exactly 1 empty audio lane, both MIDI creators hard-coding `.midi`, `ensureUserMidiRegion` with zero callers |
| 8 | `TheAlwaysLoadedMemoryNamesLivingTypesTests` + `TheLawFileCitesGuardsThatExistTests` | **on writing the PLAN** | no backticked type name in an always-loaded file may name a type absent from `Sources/` (unless ⛔-marked); and no guard may be deleted while `CLAUDE.md` still cites it |
| 9 | `WebsitePagesAreFindableAndHonestTests` | on site copy | ~8 honesty claims; the video half **self-inverts** (counts `VideoRecorder(` and then DEMANDS the site mention recording) |
| 10 | `ASwiftUIBodyStaysUnderTheBuilderOverloadsTests` · `TheMenuHostReadsNoHotStateTests` · `NoDoorlessStudioViewsTests` | on every new panel | ≤10 rows per ViewBuilder block; no hot `@Observable` in a menu host or four ancestors; a `some View` that is not mounted is red |

### 2.E ⚠️ THE DISTINCTION THAT DECIDES THE WHOLE MIGRATION

**Five of these are NOT reversible by editing a test.** They encode physics, not policy:

- the SwiftUI **metadata-decoder stack limit** (why the modal ceiling exists — overflow is a
  SIGSEGV black screen at first render, and an `AnyView` split did **not** save it)
- the **ten-overload ViewBuilder cliff**
- the **10 Hz `@Observable` menu-freeze** law
- the **audio-thread bans**
- `DSP/` **Foundation+Accelerate only** — now a **build error**, not a style rule, because
  the AUv3 target compiles `DSP/` in isolation

Everything else in classes A and B is a *bookkeeping* cost: edit the literal in the same
commit that makes the capability real. **Never before.**

### 2.F 🔴 CONSEQUENCE: M0 COMES BEFORE M1

The audit found a blocker I had not planned for. **The very first pivot commit — the one
that merely rewrites the product definition — reds on `CLAUDE.md`'s 843 B of headroom.**
The guard's own repair instruction is the answer: *"move PROVENANCE to
`memory/LEDGER_COUNTS.md`, keep LAW here."*

**New M0, inserted ahead of everything:** offload ~15–30 KB of ⛔ provenance blocks from
`CLAUDE.md` to the ledger, changing **no law and no code**. Pure bookkeeping, fully
reversible, and it buys the room the ADR needs. Without it, the pivot cannot even be
*written down* in the file every session reads first.

⚠️ And a second-order trap the same audit surfaced: `TheAlwaysLoadedMemoryNamesLivingTypesTests`
means **you cannot name `DMMWProject`, `Timebase` or `Track` in backticks in `CLAUDE.md`
before those types exist.** The ADR must therefore describe the direction in prose and
name types only as they land — or mark them ⛔ in the same bullet. This is the repo
enforcing its own "claim only what ships" rule against its own planning documents, and it
is working as designed.

### 2.G PIVOT-FRIENDLY SURPRISES (do not rebuild — it is already there)

- Collaboration **exists and is doored** (`showLiveColabo` → `LiveColaboView`).
- The AUv3 **plugin** target is back and device-verified in AUM (#1385/#1386).
- **Timeline and clip persistence schemas are versioned AND round-trip tested**
  (`TimelineSchemaVersionSmokeTests`, `ClipSchemaVersionSmokeTests`) — the hardest part of
  a document migration already has coverage.
- `TimelineStore` still declares "a whole editing API" (pinned by a guard).
- `AudioLanePlayer` is still constructed and wired to the transport.
- `SamplerVoice` still exists and is constructed — **doorless, not deleted**.
- `RecordRouteOwner` machinery survives on purpose (#299).

### 2.H THE TWO PRODUCT DOCUMENTS

**`docs/dev/PRODUCT_DEFINITION.md`** (canonical, pinned by `TheEntryPointTellsTheTruthTests`)
says, verbatim: *"There is no second product, no workstation, and no acronym"* ·
*"The term is retired permanently"* · *"This is the line that decides every future keep/cut
question"* · and a CUT column naming arrangement, multi-track, audio-file regions, video
trim, AUv3 hosting, RTMP, subscriptions, drums/sequencer/sampler.
⚠️ It already carries **two internal inconsistencies** independent of the pivot: its KEEP
column still promises *"visual recording (mp4)"* (false since #1304), and it lists the AUv3
plugin **target** as CUT (it returned with #1385).

**`docs/dev/DMMW_ARCHITECTURE.md`** — **only its superseded BANNER conflicts.** The body
below it is architecturally intact and still matches the code's spine ("One typed signal
bus; many media subscribe"; typed clips Audio·MIDI·Video·Visual). One line is stale in the
*friendly* direction: it lists `MusicalFrame` as "to build", and `MusicalFrame` exists and
publishes today. **Re-open it as an input — and re-verify every line against HEAD, because
it predates all the deletions.**

### 1.I AUDIO / DSP / PLUGIN  *(measured 2026-09-21, comment-stripped)*

**Audio input: the deletion is real and COMPLETE in code.** Six `inputNode|installTap|
playAndRecord` hits in all of `Sources/`, **zero of them an input** — two OUTPUT meter taps,
one OUTPUT ring-buffer tap, three `.playAndRecord` lines inside a **provably closed chain**:
`RecordRouteOwner` is declared **case-less** (`AudioConfiguration.swift:434`), so no value
can exist; `claimRecordRoute`/`releaseRecordRoute` have **0 call sites**; the only caller of
`upgradeToPlayAndRecord()` is `claimRecordRoute`. ⇒ `.playback` always wins.

**Granular / harmonizer: clean removal.** Zero code hits in `Sources/` **and** `Tests/`.

**⭐ The AUv3 isolation is VERIFIED, not assumed** — and this is the strongest evidence for
the `EchoelCore` proposal in §4.2/§5:
- `DSP/` = **38 files**; their complete import set is exactly `{Foundation ×38, Accelerate ×7}`.
- Search for `EngineBus|BioSampleFrame|MusicalFrame|PatternEngine|Transport` **inside
  `DSP/` → 0 code hits.** The layer is genuinely control-plane-free.
- **AUv3 HOST code: NONE.** `AVAudioUnitComponentManager|AUAudioUnit.instantiate|
  AVAudioUnitComponent` → **0 hits**. Nothing enumerates or instantiates third-party AUs.

**One `AVAudioEngine`, one owner.** One construction site
(`AudioEngine.swift:411`), one `AudioEngine()` (`EchoelmusicApp.swift:358`), every
`attach`/`connect` inside that file; voices enter only via `attachSourceNode`.
`AutoMixChain` and `RetroCapture` *receive* the engine — contributors, not owners.
**No two-owner problem in the audio graph.** Preserve this exactly.

**🔴 The sampler is dead END TO END — a new finding, the #527 shape.**
`SamplerVoice` IS constructed (2 sites) and IS attached to the live graph behind two flags
that are registered **true**. But **nothing can put a sample into it**: the chain
`setSample → MultiRollFanout.samplePath → TimelineLane.samplePath` has exactly one writer,
`TimelineStore.setLaneSample(_:path:)` — **0 callers in `Sources/`, 0 in `Tests/`.**
`BeatPlayer.audition(url:)` likewise has **0 callers**. So a sampler voice occupies a live
source node and renders silence.
⚠️ **Do not "clean it up"** (persisted-document argument), **and do not describe it as a
feature.** ⚠️ `EchoelmusicApp.swift:1343` claims *"Arming a track's Record button …
captures its input"* — **there is no Record button**; `arm()` has 0 callers.

**🔴 Audio slicing / transient detection / chopping: ABSENT.** One hit repo-wide for the
whole family, and it is `RollNoteOps.reverse(_ notes:)` — **MIDI notes, not audio.**
`SamplerVoice.configurePlayback(startFrac:endFrac:reverse:rate:)` exists, but has no
producer. Pillar 3 (break engine) is a genuine build, not a revival.

**FX: `EchoelFXChain` is LIVE and doored**, and all twelve of its stages are built in its
`init` — two filters, tape, bitcrush, chorus, flanger, phaser, tremolo, delay, algorithmic
reverb, widener, compressor, limiter, plus inline saturation.
⛔ **Dead FX**: `EchoelFDNReverb` (**0 sites** — and **not in CLAUDE.md's unwired register**),
`EchoelSpaceReverb`, and the convolution stage inside `EchoelDDSP` (`useConvolutionReverb`
has **zero assignments**, confirming #546 — it is still *constructed* and never heard).
**EQ:** there is no Echoel EQ type; the only EQ is Apple's `AVAudioUnitEQ(numberOfBands: 4)`
in `AutoMixChain`. Per-voice tone is `ChannelInsertFX` (5 sites, live).

**⛔ FIVE DEAD CORES ARE MISSING FROM CLAUDE.md's UNWIRED REGISTER** — `EchoelFDNReverb`,
`EchoelBiquadCascade`, `EchoelComplexDFT`, `EchoelDecimator`, `EchoelSpectralAnalyzer`
(four of them inside `EchoelVDSPKit.swift`, whose live half is `EchoelRealFFT` +
`EchoelConvolution`). That register is the list a session reads to decide what it may open
or delete — a gap in it is the failure mode CLAUDE.md itself calls *"teurer als eine falsche
Zahl, weil sie gar nicht erst als Frage auftaucht."*

### 1.J 🔴 BLOCKING DISK I/O ON A LIVE, DOORED CAPTURE PATH ✔ verified first-hand

> ⛔ **CORRECTED 2026-09-21, AFTER EXTERNAL VERIFICATION — this section was headed "ONE REAL
> AUDIO-THREAD VIOLATION" and that over-stated it.** Apple does **not** document
> `AVAudioNodeTapBlock` as a hard realtime callback and does **not** forbid
> `AVAudioFile.write(from:)` inside it; the documentation says only that the block may be
> invoked on a thread other than the one that installed it, and for the newer sendable
> `installAudioTap(...)` that it may be called from any isolation domain. There is therefore
> no API-contract violation to cite. The finding survives on a weaker and TRUE basis: a
> potentially blocking filesystem call sits on a deadline-sensitive capture path, which is an
> avoidable underrun risk against Echoel's own pro-audio bar. Apple's own DTS guidance for
> this block — copy the samples out, dispatch the processing elsewhere — is exactly the
> repair. ⭐ **THE LESSON: a fix does not need the strongest available justification, it needs
> the TRUE one.** A finding sold as "Apple forbids this" dies the moment someone reads the
> documentation, and it takes the correct repair down with it. **FIXED in #1413**; guard
> `Tests/CISmoke/TheCaptureTapDoesNotTouchTheDiskTests.swift`.

`Sources/Echoelmusic/Audio/RetroCapture.swift:211`, inside the `installTap` callback
installed at `:183` on `engine.mainMixerNode`:

```swift
try file.write(from: buffer)        // :211 — synchronous AVAudioFile disk write
…
log.log(.error, … "\(error.localizedDescription)")   // :217 — allocation + logging
```

It **is** reachable: `FloatingVisualWindow.swift:1263` calls `startRecording(preRoll: 0)`.

**Honest assessment, because inflating this would be its own defect:**
- The **error path is already mitigated** — `failPtr` latches before the log, so the
  expensive branch fires at most once per take. The comment at `:203-208` derives that fix
  and is accurate.
- A tap callback is a high-priority audio-queue callback, **not the render block proper**,
  and `AVAudioFile.write(from:)` on a tap is a widely used Apple pattern that Apple's own
  documentation does not prohibit.
- **But the write itself is unconditional while recording and is not mitigated.** ⛔ The
  first draft of this bullet added "and `CLAUDE.md`'s audio-thread list bans file I/O" as
  though that settled it. It does not: that list governs DSP kernels and render blocks, and
  stretching it over a tap block is how a true finding acquires a false reason.

**This is the only blocking-I/O site found on any audio-priority path in the repo.** The rest
of the render bodies are clean: 654 lines across seven render blocks scanned brace-balanced
and comment-stripped for allocation/lock/actor-hop/logging → **zero hits**. The AUv3's one
hit is `Optional.map` on a raw pointer (no allocation, no ARC).

⚠️ **Relevance to DMMW:** pillar 1 asks for recording, punch/loop and resampling. That work
lands on exactly this path. **Fixed in #1413 before building on it** — the repair is the
lock-free hand-off the DTS guidance describes: the tap fills the ring (which it already did
first), and a serial writer queue follows the ring's cursor into the file. That is also what
multi-track recording needs anyway. ⚠️ It introduces ONE new failure mode the old shape could
not have — a writer that falls more than the 30 s ring behind loses frames — so the gap is
counted (`droppedFrames`) and shown in the REC bar, never swallowed.

### 1.K 🔴 THE WORST COMMENT-VS-CODE CONTRADICTION IN THE REPO

`Sources/Echoelmusic/Audio/AudioEngine.swift:50-67` — written in the **present tense**,
describing a mechanism that no longer exists:
- *"the LIVE input-monitoring mechanism … `setInputMonitoring(_:)` / `engageInputMonitoring()`
  drive `isInputMonitoring`"* — all three identifiers: **0 occurrences in code anywhere.**
- *"`stop(reason:)` has always called `microphoneManager.stopRecording()` UNCONDITIONALLY …
  **and still does**"* — `microphoneManager` appears in that file **only inside this comment.**

This is the class CLAUDE.md itself calls the most expensive (#475): *a note that declares a
live mechanism dead — or here, a dead mechanism live.* It sits in the file a session opens
first when it starts building audio input, and it would send that session hunting for a flag
nothing writes and a safety net that does not exist. **Fixing it should be part of M4's
first commit, before any input code.**

Further comment-vs-code contradictions (all measured): `EchoelmusicApp.swift:1343` (a Record
button that does not exist) · `project.yml:245` (lists `PolySynthVoice` as an AUv3 reference
— it appears only in a comment there) · `Package.swift:78` (`Sources/` inventory omits
`EchoelmusicAUv3`) · `.claude/rules/swift-audio.md` ("today 40 files" in `DSP/` — measured **38**).
