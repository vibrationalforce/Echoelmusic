# ECHOELMUSIC — DMMW GRAND AUDIT 2026-09-22

READ-ONLY audit. HEAD `cd15e0652`, branch `claude/echoelmusic-review-optimize-u5jjpd`.
Eight parallel measurement lanes, every claim comment-stripped (`| grep -v ': *//'`) and
measured by TYPE name. Symbols, not line numbers. MODELLED / WIRED / REACHABLE /
DEVICE-VERIFIED classified independently — never inferred from one another.
**No DEVICE-VERIFIED claim is made anywhere in this document.** No production code was
touched; this file is the only artifact.

---

## EXECUTIVE VERDICT

Echoelmusic is **not a partial DMMW**. It is a complete, unusually disciplined
**bio-reactive instrument** with professional egress to five open standards, sitting on top
of an **almost entirely doorless model layer** for five further domains. The distance to a
credible DMMW is therefore not feature count. It is **four structural seams, each of which
already has a canonical owner in this tree, and each of which has zero production callers.**

Three measurements carry the verdict:

1. **The body reaches eight domains through eight independently hand-written maps.** The one
   generic route table (`ModDestinationKey.all`) offers **12 destinations, every one audio or
   tempo**. A user cannot point a body channel at a light, a speaker position, a visual
   parameter or a MIDI destination. The USP is wired and not expressible.
2. **Seven canonical seam-owners exist and are unused**: `Core/Timebase`, `Core/TempoMap`,
   `Sequencer/RecordAnchor`, `Core/BioSpaceMap`, `Core/VisualModulation`,
   `Core/EchoelRenderLayout`, `Sequencer/SpatialAutomationMapping`. Each is the correct home
   for a seam the product needs. None is called.
3. **Opening a saved project restores none of the other persistence roots.**
   `EchoelStudioView.open(_ p: Project)` — measured over its whole body, comments stripped —
   contains zero references to `timelineStore`, `clipStore`, `arrangementStore`,
   `automationPlayer`, `mixer`, `trackFX`, `spatialScene` or the modulation matrix.

The privacy posture is the strongest thing in the repo and is **structural, not
conventional**. No violation was found on an adversarial sweep of twenty egress paths.

---

## WHAT ECHOELMUSIC IS TODAY

A **bio-reactive generative instrument** that:

- derives sound from live physiology (camera rPPG · BLE HRS 0x180D · HealthKit · labelled demo)
  through a protected DSP triad and a genre-aware generative composer;
- emits, simultaneously and from one running session, to **OSC · ADM-OSC · Art-Net · sACN ·
  MIDI 1.0 · MIDI 2.0/UMP · MPE · MIDI clock · network MIDI**, every one of them gated by a
  two-axis egress policy;
- renders **one** Metal visual (phone, floating window, external display) driven by the same body;
- exports a **loudness-mastered** WAV/AAC master, an unbounded lossless live WAV, a keep-last-N-bars
  retro capture, a standard MIDI file and a `.echoel.json` project — all through one share door;
- ships as an **AUv3 instrument** (`aumu`/`echl`, 8 parameters, 3 factory presets, MIDI in),
  device-confirmed in AUM;
- carries **zero external dependencies**, **zero `URLSession`**, **zero analytics SDK**.

It is a **strong one-way source and a near-zero sink**. It can drive other people's rigs. It
cannot join them: no Ableton Link, no MTC/LTC, no MIDI clock in, no Song Position Pointer
(deliberately — so it can only be clock master, only from bar 1), no audio import, no
plugin hosting, no patch interchange.

---

## WHAT THE DMMW MUST BECOME

Derived from source, not from ambition. The domains are already present as models; what is
missing is the connective tissue that makes them **one** workstation rather than ten
subsystems that happen to share a process.

1. **One canonical session that restores atomically.** Today: two song models, at least
   twenty-one structured persistence roots, and a "project" that is a partial UI snapshot.
2. **One route table from the body to every domain.** Today: one generic table (audio only)
   plus eight hard-wired maps.
3. **One timebase the audio thread can read.** Today: no render block knows what time it is.
4. **A frame source for the picture.** Today: `framebufferOnly = true`, never read back —
   the app cannot produce one pixel of a file.

Note what is *not* on this list: new media domains. Adding one today means writing a ninth
hard-wired map, which makes (2) worse.

---

## CURRENT CANONICAL ARCHITECTURE

| Concept | Owning type | Level |
|---|---|---|
| Musical position authority | `Sequencer/PatternEngine` | WIRED + REACHABLE |
| Transport control plane / fan-out | `Core/Transport` | WIRED + REACHABLE |
| Control plane (bio/controller/events) | `Core/EngineBus` (3 SPSC + main-actor snapshots) | WIRED |
| Bio frame contract | `BioSampleFrame` — **scalars only** | WIRED |
| Cross-domain music frame | `Core/MusicalFrame` (+ shared mapper `Sync/MusicMediaMap`) | WIRED + REACHABLE |
| Parameter identity + application | `Core/EchoelParameterRegistry` + `Core/ParameterApplyRouter` | WIRED |
| Body→parameter routing | `Core/ModulationEngine` + `ModRoute` | REACHABLE (Routing chip) |
| Timeline document | `Sequencer/Timeline` + `Core/TimelineStore` | WIRED; REACHABLE read-only |
| Signal/port routing | `Core/SignalRouter` + `SignalGraph` | REACHABLE (Patchbay) |
| Egress policy | `Core/BioEgressPolicy` | WIRED, 13 production gate sites |
| Flash safety | `Core/FlashGuard` | WIRED (DMX legs only) |
| Spatial scene document | `Core/SpatialScene` + `SpatialSceneStore` | WIRED, **no reachable writer** |
| Persistence primitive | `Core/AppGroupStore` (8 instances, 11 files) | WIRED + REACHABLE |

**The bus, measured.** `bioFrames` (cap 32): **5 enqueue sites, ZERO dequeues** — reserved and
undrained; every consumer reads the `latestBio`/`freshBio()`/`usableBio()` snapshot.
`controllerEvents` (128): 1 producer, 1 consumer (monophonic). `bioEvents` (64): 2 producers,
one consumer (`OSCSender`, egress only). **None of the three crosses to the audio thread** —
they serialize on the main actor. The real control→render boundary is a *second* layer of
**eight per-voice SPSC queues** drained inside render blocks.

---

## PROFESSIONAL BASELINE MATRIX

`M`=MODELLED `W`=WIRED `R`=REACHABLE `D`=DEVICE. Canonical owner = the type that must own the
seam if it is built (this repo forbids second truths).

| Domain | Professional baseline | Echoel today | M | W | R | D | Missing seam | Canonical owner | Architectural risk | USP value | External alternative |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Music/DAW** | arrangement, clips, comping, PDC | generative instrument + read-only Workstation plate | ✅ | ✅ | ~ | ✖ | sample-correlated scheduling | `Core/Timebase` | main-queue 16th tick | low | Ableton/REAPER |
| **Audio** | sends/returns, sidechain, stems, multichannel | master bus + AutoMixChain + LUFS export, hard stereo | ✅ | ✅ | ✅ | ✖ | bus/stem selector | `Audio/SingleExport` | none | low | REAPER |
| **MIDI/MPE** | full in/out, MPE both ways, learn | MPE **out** real+doored; MPE **in** is not MPE (no zones, channel never read) | ✅ | ✅ | ✅ | ✖ | zones + a 2nd polyphonic consumer | `Sync/MIDIBusPublisher` | SPSC has one mono consumer | medium | any DAW |
| **Sampling** | library, slicing, warp | `SamplerVoice` live (preview + lane); import deleted #167 | ✅ | ✅ | ✖ | ✖ | any audio import | `Core/MediaLibrary` | 3 import fns, 0 callers | low | Ableton |
| **Video** | timeline, codecs, color | **residue only** — `Video/` is the rPPG pulse path | ✖ | ✖ | ✖ | ✖ | a frame source | (founder decision) | deleting by directory kills the pulse | none | Resolve |
| **Visual** | layer graph, compositor, effects | ONE `MetalBioView`, bio-driven, 3 surfaces | ✅ | ✅ | ✅ | ~ | HRV→picture; a route table | `Core/VisualModulation` | 99 hand-mirrored uniforms, no compiler check | **high** | Resolume |
| **Lighting** | fixtures, universes, cues | Art-Net + sACN unicast, 1 universe, N identical fixtures, chord→CIE colour | ✅ | ✅ | ✅ | ✖ | per-fixture patch | `Sync/LightFixtureGroup` | 0 callers | **high** (colour law) | grandMA/Chamsys |
| **Spatial/XR** | renderer, room, head tracking | ADM-OSC single object live; full scene doc with **no writer** | ✅ | ✅ | ✖ | ✖ | a door on `ImmersiveStageView` | `Core/SpatialScene` | room never transported ⇒ distance uninterpretable | **high** | IEM/FletcherMachine |
| **Broadcast** | scene comp, encoder, muxer, transport | none — 3 blocking layers | ✖ | ✖ | ✖ | ✖ | a routable audio/video tap | `Core/SignalRouter` | no `.audio` **source** port exists | none | OBS |
| **Live perf** | scene recall, setlist, cue, MIDI learn | chip strip + transport + FX character | ~ | ~ | ✅ | ~ | a performance-state type | new `Core/PerformanceScene` | state in 6+ roots | medium | Ableton/Resolume |
| **Collaboration** | shared doc, conflict resolution | LAN Multipeer, whole-`Project` handoff, human Load/Save/Dismiss | ~ | ✅ | ✅ | ✖ | shared timebase | `Core/Transport` (`.link`) | sheet dismiss tears down session | medium | — |
| **Bio/Motion** | — (no reference class) | 6 live channels, 3 real sources, 2-axis egress policy | ✅ | ✅ | ✅ | ~ | ONE route table | `Core/ParameterApplyRouter` | 8 private maps | **the moat** | none |
| **Automation** | curves, gestures, per-track | plays; **no production writer**, no reachable editor | ✅ | ✅ | ✖ | ✖ | any curve producer | `Core/AutomationPlayer` | 3 automation homes | **high** | any DAW |
| **Social output** | vertical render, camera roll | audio/MIDI/JSON only, via share sheet | ~ | ✅ | ✅ | ~ | `framebufferOnly` readback | `Views/MetalBioView` | collides with #1304 | **high** | Resolve/CapCut |
| **Interop** | SMF, stems, timecode, session formats | SMF out ✅ / in doorless; 9 protocols out; no clock in | ✅ | ✅ | ~ | ~ | SPP / Link | `Sequencer/PatternEngine` | clock-master-only, bar 1 only | medium | — |

---

## MUSIC / AUDIO / MIDI

Echoel has a generative instrument plus an unusually complete, **almost entirely doorless DAW
model layer**. All twelve region mutators, six automation mutators and every lane-management
method on `TimelineStore` have zero external callers; `WorkstationView` contains no
`DragGesture` and no `onTapGesture`. Both undo stacks (`TimelineStore`, `PianoRollModel`) have
zero callers — the only reachable undo is the one-step patch undo.

The single production path to a timeline region is the **Generate / Start ▶** button
(`generate(startTransport:)` → `syncPrimaryRollClip(createIfNeeded: true)` → `ensureComposerRegion`).
Background evolve passes `false` and only feeds an existing clip.

Absent entirely, measured: sends/returns, sidechain, stems, freeze, comping, punch/loop
recording, multichannel (hard stereo cap), plugin hosting, hardware routing (MIDI out
broadcasts to every destination), time signature beyond 4/4 (`Transport.stepsPerBar = 16`
hardcoded; `TempoMap.MeterMap` exists with zero callers), latency compensation
(`Audio/LatencyCompensation` 0 consumers), offline rendering (`enableManualRenderingMode` → 0
hits; bounce is real-time capture).

**MPE out is real and doored** (RPN 6, 15 member channels, per-note bend + CC74, two toggles
in `midiOutSection`). **MPE in is not MPE**: no zone parsing, `event.channel` never read, one
monophonic consumer. CC21–31 arrive on the bus as `.airCC` and the consumer does `break`.
CC64 (sustain) falls into `default: return`.

---

## VIDEO / MEDIA

**Removed to residue, not unwired.** `Sources/Echoelmusic/Video/` holds only the rPPG pulse
path (`CameraCapture`, `CameraAnalyzer`, `RPPGConditioning`, `PulsePeriodEstimator`). Zero
`AVPlayer`, zero `.metal` files, zero `kind: .video`/`.visual` construction sites, zero
VideoToolbox, zero video-typed `AVAssetWriterInput`. The only `AVAssetWriter` in `Sources/` is
audio-typed, in `Audio/SingleExport.swift`.

⚠️ **The directory name is a live trap: cleaning up `Video/` by name deletes the flagship bio
source.** A second trap: `FloatingVisualWindow.renamedForShare` still documents and falls back
to `mp4` — #1304 residue in the one function that names every shared file.

The media-reference layer is real but producerless: `Clip.mediaRef` is a bare `String` path;
`MediaLibrary.resolveRef` has two callers; **all three `import*` functions have zero callers**;
the only `mediaRef` writer is `RecordController`, whose `arm()` has zero callers.

---

## VISUAL

One `MetalBioView` app-wide, by logged decision (decisions.csv 2026-07-03), shader compiled
inline at runtime, `preferredFramesPerSecond = 60` pinned and never reassigned. Three
surfaces: in-app, `FloatingVisualWindow`, `ExternalDisplayScene` (registered in Info.plist as
an external-display scene role — the one real second-screen output).

**HRV has no path to the picture.** `BioVisualParams.hue/.complexity/.pattern` are computed
every frame and read by nothing; only `vp.pulseHz` is consumed.

`Core/VisualModulation.swift` is a **complete bio→visual modulation core** — `VisualModTarget`
(intensity/detail/motion/spread/hue/saturation/blend), `VisualModRoute`, `VisualParams`,
`apply(routes:base:bio:lfoTime:)`, reusing `FXModCarrier` + `ModSource` — with **zero external
consumers**. It is the largest finished piece sitting exactly on the moat axis.

`Core/AudioFeatureChannel` has a wired consumer and **no producer**: `MetalBioView` reads
`snapshot(now:)` every frame and gets `.silent` every time. That read site *is* the mounting
point for a future audio-reactive input.

⚠️ `BioUniforms` is **99 `Float` fields hand-mirrored against the MSL struct by byte layout
with no compiler check** (#1119). Only END appends are safe. Any multi-output visual design
must budget this.

---

## LIGHTING

Art-Net (ArtDMX 0x5000) and sACN/E1.31, **both unicast**, default host `192.168.1.100`, **one
universe each**, `DMXFixtureFan` fanning **N identical** 4-channel blocks (max 32, 512-slot
ceiling, clipped not spilled). 8/16-bit resolution, persisted. `FlashGuard` slew-limits dimmer
*and* colour; fanning happens **after** the slew so the 3 Hz guarantee is one history, not N.

Two mapping arms: **music priority** (`MusicMediaMap` → chord → `SpectralColor.physicalColor`,
CIE 1931/OKLab — the chord you play *is* the colour) and **bio fallback**
(`ArtNetSender.dmxChannels(for:)`: dimmer = 0.3 + 0.7·coherence, R = HR, G = HRV, B = breathPhase).
sACN calls Art-Net's function directly — **one map, two transports; a "delete Art-Net" cleanup
silently breaks sACN.**

Rate is change-driven with a ≥1.25 Hz keep-alive, ~30 Hz while a fade settles — *not* a
continuous professional DMX refresh. sACN carries provenance via the E1.31 Source Name
(`" (DEMO)"`); Art-Net and ADM-OSC carry none.

**No receive path at all**: one `NWListener` in the whole app and it is `OSCReceiver`. No
ArtPoll/ArtPollReply, no RDM, no DMX in. Echoel is discovery-invisible on a lighting network.

⚠️ **The route is a power switch, not a selector.** `hasEnabledRoute(toSink:)` ignores the
source and the converter; `SignalRoute.converterID` is persisted and read only for display.
A user who patches "Bio → Light" still gets music-driven colour whenever the composer sounds.

`Sync/LightFixtureGroup` + `LightFixture` — per-fixture start channels, arbitrary-length
colour (the RGBW hook), same `masteredDimmer` law — **zero construction sites**. Not in
CLAUDE.md's unwired register.

---

## SPATIAL / XR

The **model is excellent and canonical**: `SpatialScene` with `schemaVersion`, monotonic
`revision`, a real `Diff` (added/removed/changed/room/order) that reconciles object *order*
because array position is the ADM object index, `SpatialRole` capabilities, `ListenerPose`,
`RoomModel`, deterministic `ImmersiveObjectDefaults`. `SpatialSceneStore.scene` is
`private(set)`; `ADMOSCSender` holds it `weak` and only reads. **The ownership boundary is
correct by construction — a renderer can never become the source of truth.**

**And it has no writer.** Every mutator caller lives in `ImmersiveStageView`, which has **zero
construction sites**. Consequences: the scene is permanently empty; `streamsScene` can never
become true; **`sceneDialect` has zero writers**, so `.admOSCCartesian` and `.iemMultiEncoder`
are unreachable output formats; `setExtent` has no caller; `extent` and `roomSend` are never
transported; `SpatialSceneStore` has **no persistence** — every object position dies with the
process.

What *does* ship is the **single-object** bio/music ADM arm at 20 Hz, port 4001, route-gated.

Five gaps a renderer would have to invent, in cost order: **(1) `RoomModel` is never
transported — and since `distance` is normalized, the room is the only thing that says what
`distance = 1` means in metres, so the normalization is uninterpretable**; (2) `extent`;
(3) `ListenerPose`/yaw (no `CMHeadphoneMotionManager` anywhere — head tracking is not a
missing driver, the field has no producer *and* no wire); (4) no OSC bundle, no shared
timestamp; (5) `revision` never reaches the wire.

Render half absent: `VBAPPanner`, `AmbisonicsEncode`, `BinauralPanner`, `EchoelSpaceReverb`,
`BioPhaser`, `SpatialAutomationMapping` — **all zero external references**. Plus
`Core/EchoelRenderLayout`: a spec-complete, **IEM AllRADecoder-compatible** `LoudspeakerLayout`
JSON model (sub/shaker groups, crossovers, per-channel calibration, validation) with zero
consumers and a feature flag nobody reads. **The most valuable unwired interop asset in the
repo**, and not in CLAUDE.md's register.

visionOS/XR: zero `#if os(visionOS)`, zero RealityKit, zero ARKit, zero OpenXR in `Sources/`.

---

## BROADCAST

**Blocked by three independent layers, and the cheapest-looking fix is wrong.**

1. HaishinKit is not a dependency (`Package.swift` `dependencies: []`); the `#if canImport`
   branch contains no connect call at all.
2. `rtmp.out`/`srt.out` are **filtered out of the shipped port inventory** —
   `defaultInventory() = allPortsIncludingRoadmap().filter { $0.transport.status == .live }`,
   and `.rtmp`/`.srt` are `.roadmap`. `graph` is assigned **once**, from that filter;
   `allPortsIncludingRoadmap()` has exactly one caller (the filter). `restore` drops routes
   whose ports are absent. **So they are not rendered in the Patchbay and
   `hasEnabledRoute(toSink: "rtmp.out")` is structurally always false.** (One lane reported a
   "lying control" here; re-measured and refuted. CLAUDE.md's reasoning is correct.)
3. **The router has no `.audio`-kind SOURCE port.** Sources are `.controlBio ×2`,
   `.controlMusical`, `.note`; every `.audio` port is a sink. The in-code claim that ship day
   is *"flipping its transport's `status` to `.live`, nothing else"* is **false today** — the
   flip would expose two sinks nothing can legally connect to.

Six of seven OBS-class pieces are architecturally absent (scene composition, source mixing,
encoder, muxer, transport, bitrate adaptation, A/V sync). Present: the **audio mastering end**
only. No ReplayKit, no NDI, no Syphon/Spout.

---

## LIVE PERFORMANCE

Reachable surface: nine standing chips (`.bio` reaches `bioPanel` via the pulse pill),
transport line (generate · play/stop · tempo + BPM lock · pulse monitor), quick actions
(record/keep-last/MIDI export/save), quick doors (open · Live Colabo · Learn), FX character
picker, `AudioDegradedRow` (always on screen, with a Retry button).

**There is no type that stores and recalls a performance state set.** No setlist, no cue list,
no song order — measured for absence across `Snapshot|Cue|SetList|Recall` declarations (only
`BioSnapshot`, `PulseCue`, `HapticCue`, `WeatherSnapshot` — none of them performance cues).
Clip launching is MODELLED only: `ClipLaunchEngine`, `LaunchQuantize`, `LaneLaunchLatch` exist;
`launchRegion` and `stopLaunched` have **zero production callers**.

**MIDI learn: absent.** Footswitch/CC64: absent. Transport sync in: absent (`MIDIEventParse`
decodes no system-real-time).

OSC control in: UDP 8001, opt-in default OFF, six commands, `bpm` only under the BPM lock.
⚠️ **The sender allowlist is default-EMPTY, and empty means any sender on the LAN.** The
in-app copy says so honestly; the CLAUDE.md wording ("Sender-Allowlist") reads as closed.

Failure behaviour: engine death → visible with Retry (good). **Interruption and media-reset
failure → silent** (they write a breadcrumb, not `lastAudioError`, so the degraded row stays
hidden). Thermal/battery tiering → silent, and the FPS half of the governor is dark whenever
the Metal visual is unmounted (one feeder: `MetalBioView.recordFrame`). Memory pressure → silent.

**Blackout kills the rig and leaves the projector lit.** `/ctrl/blackout` writes
`artNet.blackout` and `sacn.blackout` and nothing else; `MetalBioView`, `FloatingVisualWindow`
and `ExternalDisplayScene` read no blackout flag. There is no panic and no global fade.

---

## GLOBAL COLLABORATION

**Nothing in this repo is global.** Everything networked is LAN/AWDL-scoped.
`URLSession`: **zero occurrences in `Sources/`.** WebRTC/WebSocket/signalling: zero.

`MultipeerSession` (`echoel-colab`) sends exactly two payload kinds: a whole `Project`
(reliable) and a `BioPeek` at 2.5 Hz (unreliable, gated on a default-off non-persisted toggle
*and* the egress policy). `ColabPayload`'s `"tempo"` and `"chat"` kinds are documented reserved
strings with **no producer**. Invitations are never auto-accepted.
⚠️ `LiveColaboView` carries `.onDisappear { colab.stop() }` — **the peer session exists only
while the sheet is open.** Touching any instrument control tears it down. That is the hard
ceiling on collaboration as a performance feature.

`PeerIdentity` is real (stable per-install UUID + display name, packed into MCPeerID's 63-byte
limit). It identifies an **install**, not a person. Multi-user session model, shared document,
CRDT/OT: **absent**. The only merge logic (`SyncConflict`, last-writer-wins) has zero callers.
Reconciliation is a human button: Load (whole-document replace) / Save / Dismiss.

Clock sync across machines: **absent in all four forms** — no Link (`dependencies: []`), no
MTC/LTC, no NTP offset, MIDI clock **out only**.

Per mode, against this architecture: **control-only = carriable today and partly shipping**
(the `/ctrl/*` in and the five senders out, ~1 Hz, jitter-tolerant, no new truth).
**Event-level = not carriable** — needs a shared timebase; `TransportClockSource.link` names
the hole and the whole enum has zero usages. **Media-level = not carriable.**
**Full-session = not carriable** and would need the performance-state type first.

---

## BIO / MOTION / GESTURE

**Live, with real producers:** heart rate, HRV (normalized + RMSSD/SDNN/pNN50), coherence,
coherence trend, breath rate, breath phase — from camera rPPG, BLE strap, HealthKit and a
labelled demo generator. Honest sentinels, per-source provenance, per-channel measurement gates.

**Dead, measured at every construction site:** motion (all five `BioSampleFrame(` sites write
`motionEnergy: 0`; `ModSource.motion.hasProducer == false` and every consumer gates on it),
EEG (`.eegBurst` zero producers), audio analysis (`AudioFeatureFrame(` zero constructions),
**breath depth** and LF/HF (both hard-coded `0.5` at both construction sites).

⚠️ **`breathDepth` is worse than dead — it is refuted as a name.** Two production call sites
feed it coherence: `EchoelStudioView` passes `0.3 + 0.5·liveCoherence`, `PianoRollModel` passes
`breathDepth: coherence` outright.

⛔ **THE SHARPEST DEFECT IN THE BIO PATH, and the repo already documents it.**
`EngineBus`'s own doc for the field says verbatim: *"THE CONTRACT IS A SAWTOOTH PHASE; THE
CAMERA DOES NOT HONOUR IT."* The camera writes `measuredBreath ? Float(resp.amplitude) : 0` —
a soft-clipped sine. Three consumers read it as cycle **phase**: ADM azimuth
(`clamp((breathPhase*2-1)*180, -180, 180)`), `BioPhaser`, and the breath-onset detector that
waits for a 1→0 wrap. **The spatial position and every camera-sourced breath event are computed
from the wrong physical quantity.**

⚠️ And the strap is worse than the camera: `PolarH10BioPublisher` writes `breathPhase: 0` on
every frame. **On the one bio source a performer can strap on, the breath channel does not
exist** — and breath is half the identity line.

**The frame carries no confidence.** Confidence lives on the publisher and is consumed as a
*publish gate*; it never travels with the value. Discrete `BioEvent`s do carry confidence.
Two halves of one bus with opposite provenance contracts.

**`.heartbeat` events fire only on the BLE strap** — the `BioEventGraph` path is fed
`cleanedHeart: 0`, so on the flagship camera source that address never fires.

**Apply rate diverges 60× across consumers of the same frame.** Eight consumers dedup on
`frame.timestamp` (~1 Hz). Two do not: **`FXBioModulator` re-reads and rewrites every FX
parameter at 33 ms (~30 Hz)** and **`MetalBioView` at 60 Hz**. The "~1 Hz apply" law is true
for the deduped and false for exactly the two that touch timbre and picture.

---

## CONTROL / MODULATION / AUTOMATION

**Seven distinct routing vocabularies.** They converge at exactly two points and diverge at five:

| # | vocabulary | destinations | status |
|---|---|---|---|
| 1 | `ModRoute`/`ModSource` → `ModDestinationKey` | **12, all audio+tempo** | LIVE, doored, default-empty, persisted |
| 2 | `FXModRoute`/`FXModCarrier` | 13 FX targets | LIVE, doored, **not persisted** |
| 3 | `AutomationTarget` + `ParameterDescriptor` | registry ∩ bound setter | WIRED, **no production writer** |
| 4 | `PerTrackParameterKeyPath` | per-track | WIRED, byte-identical no-op |
| 5 | `VisualModRoute` | visual | **DEAD** |
| 6 | `SpatialAutomationMapping` | spatial | **DEAD** |
| 7 | `SignalRouter` port graph | transport enablement | LIVE (different *kind* of routing) |

Plus an **eighth source spelling that belongs to none of them**: `BioModulationMap.Driver`
`{coherence, heartRate, hrv, breath}` — four cases, not convertible to `ModSource`'s six
(`breath` vs `breathRate`/`breathPhase`), and live in both synth voices. **Two independent
enumerations of the same physiology, with different case sets.**

Convergence point 1: `ParameterApplyRouter` + `ParameterDescriptor` — a body route and a drawn
automation lane already share one denormalization path. Convergence point 2:
`FXModCarrier.bio(ModSource)`.

**Divergence, measured:** `ModDestinationKey.all == [tempo] + PolySynthVoice.automatableBases`
= `["seq.tempo", "ddsp.warmth.drive", "ddsp.env.attack", "ddsp.env.decay", "ddsp.env.sustain",
"ddsp.env.release", "ddsp.amp.level", "ddsp.osc.harmonicity", "ddsp.osc.noiseLevel",
"ddsp.mod.vibratoDepth", "ddsp.mod.vibratoRate", "ddsp.osc.brightness"]`. **Not one visual,
light, DMX or spatial destination.**

**~150 controllable parameters across 14 identity schemes.** Seven identities for tempo, four
for filter cutoff (three with *incompatible ranges*), four for level, three for brightness.
Two systems already carry alias resolvers to reconcile themselves. One dedup filter
(`AutomationPlayer.extraAutomatableDescriptors`) is a **measured no-op** — its filter set
shares no member with what it filters.

**Automation has three homes** (`Automation/automation.json` — what the player reads;
`TimelineDocument.automation` — what a doorless editor would write; `Clip.automation` — a
different scope), with **no reconciliation**.

---

## SOCIAL CONTENT

Treated by the founder as first-class, and the audio half is genuinely done: **three reachable
export paths** (loop export, keep-last-N-bars retro capture, **unbounded lossless live WAV**
from the floating visual window's REC tile), all loudness-mastered, all correctly named
(`Echoel_<date>_<Key>_<bpm>_A440_<Genre>`), all through one share door.

The picture half is **zero pixels**: no `ImageRenderer`, no `UIGraphicsImageRenderer`, no
video `AVAssetWriterInput`, no VideoToolbox, no `import Photos`, and **no
`NSPhotoLibraryAddUsageDescription`** — the app cannot write to the camera roll without a
founder-gated Info.plist change. No 9:16 path. The container is not browsable
(`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `CFBundleDocumentTypes`: all absent).

**The whole lane reduces to one deleted seam:** `MetalBioView` sets `framebufferOnly = true`
once and nothing reads the drawable back. The file itself records the two non-obvious laws a
reader must restore (only read a texture on a frame whose drawable was already readable coming
in; only *write* the property when the state actually flips). Everything downstream —
encoder, muxer, portrait target, Photos write — is conventional.

⚠️ **"First-class social output" and the #1304 decision "Kein Video Capture" are the same
decision.** It is the founder's, not an engineering question.

---

## PLUGIN / INTEROP

**AUv3 (`EchoelmusicAUv3`)** — `aumu`/`echl`, embedded, compiles `Sources/EchoelmusicAUv3` +
the whole `DSP/` group + three Foundation-only `Core/` files. No control-plane type is even
visible to it. 8 parameters in 2 groups, 3 factory presets + user presets + `fullState`, empty
input busses (instrument), **MIDI in yes / MIDI out no**, no MPE. Render path reads a lock-free
`nonisolated(unsafe)` parameter mirror, never an `AUParameter`. `maximumFramesToRender` clamped
to 4096 to match the scratch buffers. Device-confirmed in **AUM only**; Logic/GarageBand UNMEASURED.

⚠️ **`EchoelmusicAUv3.entitlements` contains no App Group keys** (removed 2026-07-19, the
`-3000 invalidComponentID` fix). `BioFeedbackManager.isAvailable` is therefore false inside the
plugin: **the live app→plugin bio bridge does not work today.** The plugin sounds, but only
from host-set parameters.

Plugin hosting: **zero** (`AVAudioUnitComponentManager`, `AUAudioUnit.instantiate` → 0 hits).
Inter-app audio: the one real affordance is `AVAudioSession .playback` with `.mixWithOthers`.
`RecordRouteOwner` is confirmed an **uninhabited enum** — `claimRecordRoute` has no callable
argument, `recordingRouteNeeded` can never become true, and `NSMicrophoneUsageDescription` is
correctly absent. Ableton Link, AudioBus, IAA: zero code.

File interop: SMF **out** reachable; SMF **in** built, tested, and **doorless**
(`midiImportPresented` has two occurrences — the declaration and the binding; no producer sets
it true). WAV/AAC out. `.echoel.json` project both ways. **Patch/preset: container-only** — no
export, no `Transferable`, no UTI, no import. Audio import: none.

Protocol interop **out**, each with a production construction site and a reachable enable:
OSC · ADM-OSC · Art-Net · sACN · MIDI 1.0 · MIDI clock (24 ppqn) · MIDI 2.0/UMP (default off) ·
MPE · network MIDI. **In**: MIDI notes, OSC control, BLE HRS, HealthKit, camera.

Architecturally absent: MTC/LTC/SMPTE, **MIDI Song Position Pointer** (deliberately — without
SPP a mid-take clock enable would jump the receiver to bar 1, so **Echoel can only ever be
clock master, only from bar 1, and can never join a running session**), Ableton Link, stems,
AAF/OMF/OpenTimelineIO/ReWire.

---

## REALTIME RISKS

**The render path itself is clean.** All six `AVAudioSourceNode` render blocks,
`EchoelDDSP.render`/`renderStereo`, the AUv3 `internalRenderBlock`, both AudioEngine taps and
the RetroCapture tap were audited for locks, allocation, ObjC messaging, file I/O and GCD:
**no violations**.

**The risk is timing, not safety.**

1. **No render block knows what time it is.** All six are spelled `{ _, _, frameCount,
   audioBufferList in }` — the `AudioTimeStamp` is discarded at every one. Every production
   `scheduleBuffer` passes `at: nil`. `CACurrentMediaTime` occurs **zero** times.
2. **Note onset is quantized to the buffer.** `drainNoteCommands()` runs once before render,
   so every queued note lands at buffer-frame 0: **512 frames = 10.67 ms @48 kHz ≈ 8.5 % of a
   16th at 120 BPM**, before any jitter.
3. **The musical clock is a main-queue `DispatchSourceTimer` at 8 Hz** (16 steps/bar), with
   `leeway: 0`, competing with **≈370 main-actor wake-ups per second** (60 Hz meter poll,
   60 Hz Metal draw, 50 Hz LUFS ease, 48 Hz MIDI clock, 2×30 Hz DMX, 20 Hz ADM, 5×10 Hz polls)
   plus unbounded SwiftUI rebuilds. **No priority mechanism exists among them.**
4. **There is a second timebase, though not a second position authority.**
   `MIDIOutput.armClockTimer` is an independent `leeway: 0` main-queue timer advancing its own
   pulse phase at 24 ppqn (48 Hz @120 BPM, 120 Hz at max tempo); `emitPulse()` reads no step,
   tick or position and is **never re-synced**.
5. **The sound-critical fan-out order is not expressed in the priority mechanism that exists.**
   `Transport.addStepSubscriber(priority:)` has two production subscribers, neither of which
   makes sound. The order that matters (arrangement → timeline → automation → notes) is
   statement order inside one closure in a view file.
6. **SwiftUI render safety holds today** — four hot-producer sets pinned across four ancestors.
   A fifth candidate exists and is harmless only because nothing observes it:
   `EchoelBioEngine.startFallbackMode()` writes eight `@Observable` properties at 20 Hz with
   **zero view readers**. The moment any view binds to it, it is defect #5 with no guard.
7. **Presentation-modifier headroom: two.** 13 file-wide, 12 on the body chain, ceiling 14.

---

## PRIVACY RISKS

**NO VIOLATION FOUND. NO BLOCKER.** Twenty egress paths were followed to their payload builders.

The two hard laws hold **structurally, not by convention**:

- *No raw biosignal leaves the device.* Enforced twice over: `BioEgressPolicy.FieldClass.raw`
  returns `false` with **no configurable argument**, AND **`BioSampleFrame` — the single
  transport type every egress path reads — declares only `Float`/`TimeInterval`/`BioSource`.
  No array, no `Data`, no collection.** A waveform or an RR series cannot be expressed on the bus.
- *No health data in iCloud.* `AnnouncementCenter.cloudKitConfigured = false` guards both entry
  points, and even enabled the class only saves a `CKQuerySubscription` — it has no record-upload
  path. `CloudSyncEngine` has zero production constructions. **Zero `URLSession` in `Sources/`.**
  No third-party SDK, no analytics, no crash reporter.
- *App Store 5.1.3*: source gate applied at **13 production sites** covering all four network
  senders, Multipeer, MIDI/MPE out, the modulation tap and the App-Group write. The reverse
  direction is gated non-circularly (`HealthWritePolicy.isWritableSource` = `.ble`/`.cameraPPG`
  only). Clinical HRV detail is opt-in, default OFF, with a verified door in `PatchbayView`.

**Four things on the record, none of them blockers:**

- **F1** — the egress rule's fail-closed property belongs to **the filter, not the sender**.
  `/echoelmusic/music/tempo`'s hold, and `sendModulation`'s gate in `ModulationEngine.apply`,
  are both caller discipline. **A new egress path added to `OSCSender` inherits nothing.**
- **F2** — the **App Group enforcement model is inverted**: `BioFeedbackPublisher` writes
  unconditionally and carries an `egressAllowed` flag. The AUv3 reader checks it (correctly —
  it runs in a third-party host process). **The widget and the watch do not.** Same device,
  same user, so not a breach; but any future forwarding reader inherits the data, not the rule.
- **F3** — `echoel_diag.log` sits in `.documentDirectory` with **no `isExcludedFromBackupKey`
  anywhere in `Sources/`** and contains derived bio scalars (bpm, breath rate, amplitudes).
  It never leaves by code (export is a user tap through the share sheet) and the Files app
  does not expose it; it is included in the user's own encrypted device backup.
- **F4** — the OSC control input's allowlist is **default-empty = accept-any**.

**The one change that would break all of this: a non-scalar field on `BioSampleFrame`.** That
is the place to put a guard, not the senders.

---

## DUPLICATE-TRUTH RISKS

1. **Two song models.** `TimelineDocument` (lanes + regions + automation, 480-PPQ song-absolute)
   vs `Arrangement` (ordered bar-quantised sections). Both reference the same `ClipStore`, both
   persisted independently, **nothing synchronises them** (`bootstrapIfNeeded(sections:)` has
   zero callers). Asymmetry measured: `Arrangement` has **zero production writers** and no view
   declares `@Environment(ArrangementStore.self)`; `TimelineDocument` has one (the generate path).
   **FOUNDER HOLD — reported, not resolved.**
2. **Song content lives a third time, flattened, in `Project`** — its own copies of notes,
   patch, BPM, key, loop length, mood fields, with no clip/lane/region reference. And
   `open(_ p: Project)` restores nothing else.
3. **Automation in three homes**, same type, two files, no reconciliation.
4. **Four route models** with different durability: matrix routes persist, FX-mod routes do not.
5. **Key/scale in three homes** (`SessionContext`, two `@AppStorage` keys, `Project`), pushed
   one-way at generate/open.
6. **Two time conversions**: live `TimelineTime` (scalar BPM, hardcoded 4/4) vs designed
   `TempoMap`/`Timebase` (tempo-change-safe, zero callers). `TimelineRegion` carries **two
   parallel trims** (ticks for MIDI, seconds for media) precisely because no tempo-safe
   conversion is in use.
7. **Two enumerations of the same physiology** (`ModSource` 6 cases vs `BioModulationMap.Driver`
   4), and a third spelling of "is this measured?" written inline in three files.
8. **Persistence roots**: at least **21 structured roots + ~128 loose keys** by mechanism
   (11 AppGroup JSON files, 9 UserDefaults blob keys, ≥128 scalar keys, 1 media directory),
   plus a **dormant sixth-root class** (`CrashSafeStatePersistence`) that would start a timer
   the moment anything constructs it. The "no fifth root" law counts *song* roots and is
   already spent — the repo's own guard message says a **sixth** would have to be migrated.
   ⚠️ The project library is on disk as **`projects.json.json`** (`fileName` ends in `.json`
   and `AppGroupStore` appends `.json`). Lossless today; wrong for every migration and
   external tool, and three plan documents name a file that does not exist.
9. **Eight independent copies of the bio dedup rule**, each with its own `lastFrameTimestamp`.

---

## DOORLESS CAPABILITIES

Wired or modelled, with no reachable user path. **Doorless is not automatically a defect here
— several are deliberate. Doorless *and unwritten* is.**

| Capability | Door state | Note |
|---|---|---|
| `ImmersiveStageView` (+ the whole spatial scene stack) | deliberate, ship-gate 4 | re-dooring makes `SpatialScene` reachable at a stroke |
| `BroadcastView` | correct while RTMP is unlinked | |
| `MeditationView` | **setterless slot** — zero writers of `true` | consumes a presentation-chain slot; and it is one of only two `SessionRecorder.start` call sites, so **`BioSessionSummary` is never written today** |
| MIDI file import | doorless | built and tested; `MIDIFileImporterTests` is in KEY TESTS, so a reader assumes it ships |
| Timeline region/lane/automation editing | doorless | 12 + 6 mutators, zero external callers |
| Clip launching | modelled, zero callers | `ClipLaunchEngine`, `LaunchQuantize` |
| `RecordController` → `TakeRecorder` → `AudioClipFactory` | `arm()` has zero callers | the whole audio-lane producer chain |
| Both undo stacks | zero callers | |
| `BioSourceView`, `PulseMeasurementView`, `BreathGuideView` | doorless (nested) | `BreathGuideView` is doorless one hop *inside* a doorless parent |
| Four analysis views | deliberate (founder red X) | |
| `Core/VisualModulation`, `Core/BioSpaceMap`, `Core/EchoelRenderLayout`, `Sequencer/SpatialAutomationMapping`, `Core/CloudSync`, `Core/BioTempoDirector`, `Sequencer/RecordAnchor`, `Core/Timebase`/`TempoMap`, `Sync/LightFixtureGroup`, the 7 spatial render cores | zero callers | **`EchoelRenderLayout` and `LightFixtureGroup` are not in CLAUDE.md's register** |
| `sceneDialect` (`.admOSCCartesian`, `.iemMultiEncoder`) | **zero writers** | two unreachable output formats |

---

## HISTORICALLY REMOVED CAPABILITIES THAT MATTER

Architectural evidence, **not implementation instructions**.

1. **Video capture (#1304) + video edit (#121 Slice 3).** The removal is why the social-output
   lane has no frame source. It is also why `Video/` now lies about its contents. The founder's
   "first-class social output" and this removal are the same decision.
2. **Audio input / microphone (#1302).** Removed cleanly and structurally (`RecordRouteOwner`
   uninhabited, plist key gone). Its side effect: `AudioFeatureChannel` has a 60 Hz consumer
   and no producer — an audio-reactive visual has a mounting point and no signal.
3. **The piano roll editor (#475).** `PianoRollModel` survives and is load-bearing (it is the
   **only** `MusicalFrame` producer, i.e. the spine of the entire output stage). The
   *editor* is gone: a generated take can be heard, mixed and exported — not corrected.
4. **The arrangement/clip surfaces (#121 Slice 4).** This is why the timeline model has a
   complete mutation API with zero callers, and why the audio-lane chain has no producer.
5. **The face/expression source (#1301).** Its two surviving laws matter more than the code:
   a switch in a visual surface must not start the instrument; and a channel whose neutral
   measurement is a real 0 cannot be gated on its own value — it needs the frame's provenance.
6. **AUv3 hosting (#121 Slice 2)** — but Echoel *is* an AUv3 again since #1385.
   `SignalTransport.auv3` still means *host* and reads backwards.

---

## MUST OWN

The things that are the product, or that no external tool can supply:

1. **The bio signal chain** — acquisition, the protected Rausch triad, coherence, trust gating,
   provenance, and the egress policy. Nobody else has this, and the privacy posture is an asset.
2. **The bio→everything route table.** Not the mappings — the *ability to express* them.
3. **The generative musical engine** (key/scale/genre, in-key melody and harmony from the body).
4. **The flash-safety guarantee** (`FlashGuard`). A generative source that a venue can trust not
   to strobe is something no desk can provide for third-party input.
5. **The physical colour law** (`SpectralColor`: chord → wavelength → CIE). Unique and it is
   the "wow".
6. **The canonical session** — one document, atomic restore. Nobody can own this for us.
7. **The performance state / scene** — the thing that makes a live set repeatable.

## MUST INTEROPERATE

Own the *speaking*, never the *doing*:

| Partner class | Protocol | Direction | Timing | Boundary | Crosses | Must NOT cross |
|---|---|---|---|---|---|---|
| Lighting desks (grandMA/Chamsys/ETC) | Art-Net, sACN, **OSC** | out | ~30 Hz change-driven, ≥1.25 Hz keep-alive | we are a *source*, the desk patches and cues | dimmer, colour, named generative streams | raw bio, clinical HRV |
| Spatial renderers (IEM, FletcherMachine) | ADM-OSC, IEM MultiEncoder | out | 20 Hz | we own the scene document, they render | position, gain, **and the room model** | raw bio |
| DAWs | SMF, **AUv3**, MIDI/MPE/UMP, MIDI clock, **+SPP/Link** | both | sample-critical | they own arrangement | notes, tempo, expression | — |
| Video/VJ (Resolume, Resolve, OBS) | OSC, **+NDI/Syphon one day** | out | frame | they own compositing and encoding | control values, eventually a frame | raw bio |
| Health | HealthKit | both, gated | 4–5 s | Apple owns the store | HR, respiratory rate (opt-in write) | **never outward** |
| Peers | Multipeer today; a global transport is a founder/Council gate | both | ~2.5 Hz | LAN only today | project, `BioPeek` | raw bio, clinical |

## SHOULD NOT REBUILD

- Fixture libraries, personalities, patch, multi-universe, merging/HTP/LTP, cue stacks, RDM.
- Video editing, color grading, codecs, NLE timeline.
- Spatial *rendering* (VBAP/Ambisonics/binaural decode) — we have the cores and no reason to
  ship them; the renderers exist and speak our protocol.
- Broadcast encoding/muxing/bitrate adaptation.
- Plugin hosting.
- Arrangement/comping/PDC-class DAW surface — the boundary "Editor ≠ Workstation" is right.
- Any second clock, second timeline model, second persistence root, or second parameter registry.

---

## PROFESSIONAL BACKBONE

The minimum for credible participation, derived from source:

1. **A canonical session that restores atomically** — one envelope over the song roots, with a
   writer. (`Core/DMMWProject` is the modelled envelope; its importer has no caller and there
   is no exporter.)
2. **A timebase the audio thread can read** — `Core/Timebase` + `Sequencer/RecordAnchor` wired;
   render blocks capture their `AudioTimeStamp`; `NoteCommand` gains a buffer offset. **Not a
   second clock**: `PatternEngine` keeps advancing, `Timebase` only answers.
3. **Transport sync IN** — SPP at minimum, Link if the Council approves it. Owner:
   `Sequencer/PatternEngine` / `Core/Transport.TransportClockSource` (`.link` already exists).
4. **A performance-state type** — one value that composes the existing roots *by reference* and
   can be captured and re-applied. Unblocks scene recall, setlist, cue list and MIDI learn
   simultaneously.
5. **Meter beyond 4/4 and tempo-change-safe time conversion** — `TempoMap.MeterMap` exists.

## DIFFERENTIATING BACKBONE

The minimum for the bio-native USP to be real rather than wired:

1. **ONE route table from body to every domain.** `Core/ParameterApplyRouter` +
   `ParameterDescriptor` is already the convergence point — it already unifies the drawn
   automation lane and the body matrix. Light, space and visual must *register descriptors*
   instead of owning private static functions.
2. **Bio automation that can be recorded and edited.** `AutomationPlayer` plays; nothing writes.
3. **Provenance on the cross-domain frame.** `MusicalFrame` has no `source`, which is why
   `/music/tempo` needs a hand-written second filter. Every future cross-domain frame inherits
   that problem.
4. **The breath channel repaired** — the phase/amplitude contract, and a breath producer on the
   strap. Breath is half the identity line and is broken on both real sources in different ways.
5. **HRV to the picture** — the one mapping the founder's own USP example names and that does
   not exist.

---

## HARD-TO-COPY MOAT — §21 classification

| | Claim | Verdict | Evidence |
|---|---|---|---|
| **A** | One physiological signal can control every creative domain | **CURRENT MODEL CONFLICT** | Bio reaches 8 domains via 8 private maps; `ModDestinationKey.all` = 12 keys, all audio. Adding a domain today means a **ninth** hard-wired map — the model actively resists the claim. |
| **B** | Those mappings can be recorded as editable automation | **MAJOR BUILD** | `AutomationPlayer` plays a persisted curve; **no production writer**, no reachable editor, `BioAutomationRecorder` sits behind a dead `RecordController`. |
| **C** | One canonical session produces music, visuals, lighting, immersive and broadcast | **ARCHITECTURALLY CLOSE** for music + visual + light + space (all four egress simultaneously from one running session today); **MAJOR BUILD** for broadcast (three blocking layers, no audio source port). |
| **D** | Live performance and authored production use the same project | **CURRENT MODEL CONFLICT** | Two song models, `Project` restores nothing else, no performance-state type. |
| **E** | Remote collaborators contribute without becoming separate truths | **MAJOR BUILD** | Whole-`Project` handoff with a human Load/Save/Dismiss; no shared timebase; LAN only; session dies with the sheet. |
| **F** | Raw bio stays private while transformed signals are shareable | **TRUE TODAY** — and the strongest fact in the repo, because it is enforced by the *shape of the transport type*, not by convention. |
| **G** | One performance directly becomes social, broadcast and immersive output | **MAJOR BUILD** for social and broadcast (no frame source, no encoder); **partly TRUE** for immersive (single ADM object, live). |

**The moat, stated honestly: one is true, two are close, two are major builds, and two are in
conflict with the current model.** The two conflicts (A and D) are the two the product name
depends on — and both are addressed by the same two programs below.

---

## TOP ARCHITECTURAL BLOCKERS

1. `ModDestinationKey.all` hard-codes `[tempo] + PolySynthVoice.automatableBases` — **one line
   makes the route table audio-only.**
2. No render block captures its `AudioTimeStamp`; no `scheduleBuffer` passes a time. Note onset
   is quantized to 10.67 ms.
3. Two song models with no synchroniser (**founder hold**).
4. `Project` is a partial UI snapshot, not a session.
5. `MusicalFrame` has no provenance field.
6. No `.audio`-kind **source** port in `SignalRouter` — broadcast has nothing to connect.
7. `MetalBioView.framebufferOnly = true`, never read back.
8. No performance-state type; state in 21+ roots.
9. `RoomModel` never transported ⇒ normalized `distance` is uninterpretable to any renderer.
10. Seven routing vocabularies, eight bio-source spellings, 14 parameter identity schemes.

## TOP REACHABILITY BLOCKERS

1. `ImmersiveStageView` has zero construction sites → the entire spatial scene stack, both
   alternate output dialects, and `streamsScene` are unreachable.
2. Every timeline mutator has zero callers → `WorkstationView` can show and play, not edit.
3. `RecordController.arm()` has zero callers → the whole audio-lane producer chain is dead.
4. `midiImportPresented` has no producer → MIDI import is built, tested and unreachable.
5. `MeditationView` is a setterless slot → `SessionRecorder` never runs.
6. `sceneDialect` has zero writers.
7. `Core/VisualModulation` has zero consumers.
8. The AUv3's missing App Group entitlement → the app→plugin bio bridge is dead.

## DEVICE-ONLY TRUTH

Nothing in this document is device-verified. These can only be settled on hardware:

- Whether the five egress paths actually run **simultaneously** from one session on a real LAN
  (moat claim C) — needs a packet capture.
- Whether the generative genres are *musically* distinct (founder's ear; the structural half is
  pinned by `GenreFamilyDistinctnessTests`).
- Whether the visual is contemplative/"wow" on device.
- Clean launch, no black screen, no menu freeze.
- BLE strap arrival and lock; rPPG lock on a torchless or thermally throttled device.
- AUv3 in Logic/GarageBand (AUM is confirmed; one host proves one host).
- Watch as a source at real cadence; the two-phone `PeerIdentity` probe.
- Whether Art-Net/sACN keep-alive satisfies real nodes' loss timers in a venue.

## FOUNDER DECISIONS REQUIRED

Reported, **not resolved** — the nine holds plus three the audit surfaced:

1. `TimelineDocument` vs `Arrangement` — which is the song.
2. Persistence-root consolidation (21+ structured roots; the "no fifth" law is spent).
3. Performance Scene ownership.
4. Plugin ABI strategy.
5. WebRTC vendor/dependency.
6. SFU topology.
7. Project-format migration.
8. Global authentication architecture.
9. OpenXR architecture. (Measured: "OpenXR" appears **once in the whole repo**, in
   `docs/brainstorming.html`. Nothing is chosen.)
10. **NEW — video/social:** "first-class social output" vs #1304 "Kein Video Capture". Same
    decision. Also gates `NSPhotoLibraryAddUsageDescription`.
11. **NEW — the multicast entitlement** (`com.apple.developer.networking.multicast`): zero code,
    unknown Apple lead time, blocks true sACN multicast and Art-Net broadcast, i.e. the
    "plug into a venue network and be found" story on both protocols. Cheapest to start,
    longest to land.
12. **NEW — Ableton Link**: explicitly permitted by repo law (free, C++, Council-gated) and
    absent. `TransportClockSource.link` already names its seat. It is the single
    highest-leverage absent interop for a live instrument.

---

## THREE FOUNDATIONAL PROGRAMS

Exactly three, derived from the blockers, each unblocking several moat claims at once.
**None of them is a new feature surface.** Each has a canonical owner that already exists.

### P1 — THE CANONICAL SESSION
*One document that restores atomically.*
Resolve the two song models (founder), give `Core/DMMWProject` a writer, make `Project` point
into the roots instead of copying them, and add the performance-state value that composes the
existing stores **by reference**. Owner: `Core/DMMWProject` + `Core/ProjectStore`, plus one new
`Core/PerformanceScene` that must be the **last** root.
**Unblocks:** moat D and E, scene recall, setlist, cue list, MIDI learn, project migration —
and it is the precondition for every collaboration mode above control-only.
**Why first:** every other program writes state. Building them onto a session that cannot
restore itself multiplies the duplicate-truth problem instead of resolving it.

### P2 — THE ONE ROUTE TABLE
*From the body to every domain, through one vocabulary.*
Extend `Core/ParameterApplyRouter` beyond audio: light, space and visual **register
`ParameterDescriptor`s** instead of owning private static mappers. `ModDestinationKey.all`
becomes a projection of `automatableDescriptors()` across all registered domains instead of
`[tempo] + PolySynthVoice.automatableBases`.
**Three things this must not break, all measured:** (a) the `tempo` destination's bespoke
handler — `register` *replaces* by key, so a tempo-shaped key in a projected list silently
overwrites the BPM-lock veto, the octave fold and the glide, i.e. the T1/T2 invariant;
(b) the egress gate — a new route path inherits nothing, the fail-closed property belongs to
the filter; (c) `MusicalFrame` still has no provenance.
**Unblocks:** moat A and B. **This program *is* the USP.**

### P3 — THE CORRELATED TIMEBASE
*Let the audio thread know what time it is, without a second clock.*
Wire `Core/Timebase` (three spaces, six conversions, "⛔ NOT A CLOCK") and
`Sequencer/RecordAnchor`. Three concrete pieces: render blocks stop discarding their
`AudioTimeStamp`; `PatternEngine` writes a `nonisolated(unsafe)` correlation pair (host/sample
time ↔ `MusicalTime`) once per tick, read lock-free by the render; `NoteCommand` gains an
offset-in-buffer field so `drainNoteCommands` stops applying everything at frame 0.
**Unblocks:** sample-accurate scheduling, PDC, punch recording, tempo-change-safe media trims,
Link/SPP, and event-level collaboration. **Ω48 is preserved by construction** — `PatternEngine`
keeps advancing position; `Timebase` only answers questions.

**Deliberately NOT a program:** video/broadcast/social. That is a founder decision (#1304),
not an engineering plan, and it should not be smuggled in as one.

---

## RECOMMENDED NEXT MEASUREMENT

**One device session with a LAN packet capture, running all five egress paths simultaneously
from a single live take** — OSC, ADM-OSC, Art-Net, sACN and MIDI out, with the visual on an
external display, while a body drives it.

This is the single measurement the repository cannot make and on which the entire product claim
rests (moat C). Every other open question is either a founder decision, a build, or a thing
this audit already settled from source. Secondary, same session: confirm the `/ctrl/blackout`
asymmetry with a live projector, and confirm the breath channel's behaviour on the strap
(expected: absent — `breathPhase: 0` on every frame).

---

## §26 — THE ONE WORKFLOW

> *If Echoelmusic succeeds, what is the one workflow a creator can perform inside Echoelmusic
> that would otherwise require combining several of Ableton/REAPER + Resolve + Resolume + OBS +
> lighting/spatial tools?*

**A performer puts a finger on the lens — or straps on a belt — and plays their own physiology;
and from that ONE signal, inside ONE process, the music is generated in key and in genre, the
projected image moves, the DMX rig changes colour, and the immersive objects move in the room —
simultaneously, in real time, with the mapping decided once.**

To assemble that with the reference stack you need: a DAW plus a bio-sensor bridge and custom
Max/OSC glue for the generative music; Resolume for the picture; a lighting desk plus a
converter for the DMX; a spatial renderer for the ADM objects; and a person patching them
together. Five programs, several machines — and the body signal has to be **forked five ways by
hand, with five separately authored mappings that drift the moment anything changes.**

The evidence says the *simultaneity* is real today: one `BioSampleFrame`, five live senders, one
Metal visual, one running session, zero external dependencies, zero SDK lock-in, and an egress
policy that lets the derived signals travel while the raw physiology structurally cannot.

**And the evidence says the claim is false in its second half.** The mapping is decided once —
but it is decided *in Swift*, not by the performer. `ModDestinationKey.all` is twelve audio
keys. Light, space and visual each hold a private static function. The performer cannot say
"my coherence drives the beam angle" or "my breath drives object elevation"; those two sentences
are frozen in `ArtNetSender` and `ADMOSCSender`.

So the honest answer to §26 is: **the workflow exists and the instrument to express it does
not.** That gap is exactly one program wide (P2), it sits on top of one other (P1), and the
thing that would make it credible in a professional room is the third (P3). Everything else in
this audit is detail.

---

*READ-ONLY audit. No production code changed. Eight measurement lanes; two cross-lane conflicts
found and resolved by direct re-measurement (the RTMP "lying control", refuted; the
`framebufferOnly` seam, confirmed). Fourteen CLAUDE.md claims measured stale and listed at their
sections — none corrected here, because correcting them is a write.*
