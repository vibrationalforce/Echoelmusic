# PLAN — Unified Production App: Deep Audit + Vision-Aligned Pivot

**Date:** 2026-10-29
**Session branch (harness-designated):** `claude/multimedia-production-suite-pN0Eo`
**User-requested branch name (needs resolution):** `claude/unified-production-app-Qdm6b` already exists on origin as a **STALE sprint from April 2026** (2537 commits, CLAUDE.md v10 "DAW + Video + Stream" edition, 18K vs. current 149K; 50 commits behind main). Not touched by this plan. If the founder wants that name, options: (a) rename this working branch, (b) force-restart `Qdm6b` from current main — destroys 2537 commits of April history, needs founder gate.
**Author:** Claude Opus 4.7 (`claude-opus-4-7`), neutral/independent audit
**Status:** HANDOVER — plan committed, no code touched

> **Audit basis.** Explore-subagents were rate-limited at planning time; this audit is grounded in the always-loaded ground truth: `CLAUDE.md` (v10, 2026-10-29 state), `.claude/rules/{context,engineering,swift-audio}.md`, `memory/` slices from the SessionStart hook. These files are already the repo's canonical state table — provenance is stored there, not re-derived. Where the plan proposes a slice, it names files and the law it must respect; it does not quote line numbers (CLAUDE.md law: a line number of a living file is a date, not a fact).

---

## 1. CONTEXT

Why this plan exists:

The founder (@michaelterbuyken) requests repositioning Echoelmusic from a **biofeedback-centric instrument** toward a **unified multidimensional multimedia production suite** that:

- targets **M5/M6-ready** Apple silicon with **A15 backward compatibility** (iPhone 13 floor)
- carries a **multi-touch, high-accessibility, lightweight (Leichtbau) creative UI**
- spans **Music + Visuals + AI-driven Video + AI-driven Audio**
- scales across **XR/AR/Glasses, future handhelds, desktop** — Apple ecosystem first
- **removes biofeedback as the identity**, but preserves all the knowledge (code, DSP triad, publishers)
- keeps **minimal HealthKit** usage: *"Leg mal eine Produktionspause ein, beweg dich"*
- keeps **minimal WeatherKit** usage: *light UI mood adaptation to weather*
- adds **Live Streaming, 180°/360° spatial video, spatial audio**

This is **not a rewrite**. The spine (`EngineBus`, OSC/ADM-OSC egress, protected Rausch triad, `EchoelValueField`) stays. The **FRAMING** shifts: bio becomes one modulation dimension among many; the home surface, the first-run teach-in, and the store copy stop centering it.

The DMMW product law (canonical since 2026-09-24) already permits this scope — *"audio, MIDI/MPE, instruments, FX, recording, arrangement, mixing, mastering, automation, video, visual, light, spatial/XR, streaming, collaboration, AI"*. This plan executes that law without resurrecting struck implementations.

---

## 2. DEEP AUDIT — Current State (2026-10-29, from CLAUDE.md ground truth)

### 2.1 Live and shipping (iPhone only, `TARGETED_DEVICE_FAMILY=1`)

| Area | Status | Key files |
|---|---|---|
| Workstation (default home) | `WorkstationView` (ArrangeStage) is the Piece plate since S1a; `EchoelStudioView` mounted beneath | `Studio/WorkspaceView.swift`, `Workstation/WorkstationView.swift` |
| Instrument | Single-chip one-button bio-generative flow + patch editor + preset bar | `Studio/EchoelStudioView.swift`, `Studio/soundPanel`-section |
| Audio engine | `EngineBus` = `@MainActor @Observable` snapshots + lock-free `SPSCQueue`; master meter 60 Hz | `Core/EngineBus.swift`, `Audio/AudioEngine.swift` |
| Bio sources | HealthKit + camera rPPG (back lens only, since #1415) + Demo + BLE HRS 0x180D + Universal BLE HR | `Bio/HealthKitBioPublisher.swift`, `Video/CameraCapture.swift`, `Bio/CameraRPPGBioPublisher.swift`, `Bio/BLEHRSBioPublisher.swift` |
| Protected DSP triad (READ-ONLY) | `BioEventGraph` (wired), `HilbertSensorMapper` (unwired), `BioSignalDeconvolver` (unwired) | `Bio/BioEventGraph.swift`, `Bio/HilbertSensorMapper.swift`, `Bio/BioSignalDeconvolver.swift` |
| Synth voices | `PolySynthVoice`, `SubBassVoice`, `BioReactiveSynthVoice`, `FXBioModulator` | `Tools/` |
| Modulation matrix | `ModulationEngine` + `PatchbayView.modulationSection` (Tempo + every automatable synth param since #1391) | `Core/ModulationEngine.swift`, `Studio/PatchbayView.swift` |
| Timeline / Workstation | `TimelineStore`, `AudioLanePlayer`, `TimelineAudioSink`, Audio Import V1 (#1438), Add Audio Track (#F1) | `Core/TimelineStore.swift`, `Sequencer/AudioImport.swift`, `Sequencer/AudioLanePlayer.swift` |
| Egress — open standards | OSC (`/echoelmusic/*`), ADM-OSC (`/adm/obj/{n}/*`), Art-Net + sACN (unicast) | `Sync/OSCSender.swift`, `Sync/ADMOSCSender.swift`, `Sync/ArtNet*`, `Sync/sACN*` |
| MIDI | MPE **OUT** real + switchable (#548/#713); MPE **IN** parsed, zones not distinguished | `MIDI/MIDIOutput.swift`, `MIDI/MIDIBusPublisher.swift` |
| Visual output stage | `MetalBioView` (60 fps pinned) + `FloatingVisualWindow` + `MusicalFrame` publisher (installed in `EchoelmusicApp`) | `Views/MetalBioView.swift`, `Studio/FloatingVisualWindow.swift`, `Studio/PianoRollView.swift` (holds `PianoRollModel` — load-bearing) |
| AUv3 plugin | `EchoelmusicAUv3` (`aumu`/`echl`), Swift-only, DSP + Foundation-only Core, device-verified in AUM 2026-09-20 | `Sources/EchoelmusicAUv3/` |
| Weather | `Core/WeatherProvider` lives, 3 callers | `Core/WeatherProvider.swift` |
| Watch target | Compiled, **NOT embedded** (`project.yml` keeps `# - target: EchoelmusicWatch` commented) | `Sources/EchoelmusicWatch/EchoelWatchApp.swift` |
| Mastering | `AutoMixChain` (EQ→Comp→Limiter→LUFS), `SingleExport` (AVAssetWriter audio, master export), `RetroCapture` (30 s pre-roll) | `Audio/` |

### 2.2 Deleted recently — do NOT silently resurrect

| Deletion | Date | What went | What stays and why |
|---|---|---|---|
| #1302 Audio input | 2026-09-12 | `MicrophoneManager`, `MultiTrackRecorder`, `VocoderCore`, `VoiceAnalyzer`, `VoicePitchCorrector`, autotune/harmonizer/granular, feedback guards, 38 guards, `NSMicrophoneUsageDescription` | `RecordRouteOwner` empty enum + refcount (crash gate); `RetroCapture`/`SingleExport` (own-output capture) |
| #1304 Video capture | 2026-09-12 | `VideoRecorder`/`VisualRecorder`/`VideoMuxer`, mp4 export, REC button, 8 guards | **`Video/CameraCapture`, `CameraAnalyzer`, `RPPGConditioning`, `PulsePeriodEstimator` — the rPPG pulse path** (directory name misleads: that folder measures PULSE, not video) |
| #166/#167 Beat maker | 2026-07-26 | `DrumSynthVoice`, `LaneDrumKitVoice`, `DrumNoteMap`, sample browser | Persisted enum cases `LaneVoiceKind.drums`, `TrackInstrument.drums` (decode safety) |
| #475 PianoRollView | 2026-08-07 | 987-line editor struct | **`PianoRollModel` (same file) — load-bearing `MusicalFrame` publisher** |
| #121 Slice 3/4 | 2026 | `ClipView`, `ArrangeTimelineView`, video edit | `ClipStore`, `ArrangementStore`, `AutomationLane` (constructed at launch) |

### 2.3 Absent — must not be claimed as shipping (brand hard-rule)

- **RTMP streaming:** `BroadcastPublisher` is `#if canImport(HaishinKit)` scaffold; `Package.swift dependencies: []`; `Stream/` has 7 files as B2 scaffolding, nothing linked.
- **Video capture / recording / mp4 export:** gone.
- **Multitrack audio recording:** `FeatureFlags.audioLaneRecording` has NO branch since #1302.
- **180°/360°/equirectangular/fisheye/MV-HEVC:** no code.
- **Spatial AUDIO render:** `Sync/VBAPPanner`, `Sync/AmbisonicsEncode`, `Sync/LightFixtureGroup`, `Sync/BioPhaser`, `DSP/BinauralPanner`, `DSP/EchoelSpaceReverb`, `Sequencer/SpatialAutomationMapping` — all unwired. (The STEUER-half via ADM-OSC IS live.)
- **visionOS target:** none. "visionOS" appears only in two header comments (`SPSCQueue`, `MemoryPressureHandler`).
- **Mac target:** none, no Catalyst flag.
- **iPad:** `TARGETED_DEVICE_FAMILY=1` across App + Widget + AUv3 + 2 test bundles; `DeviceFamilyIsPhoneOnlyTests` pins it.
- **EchoelAI:** `Core/EchoelParameterRegistry` + `EchoelAI/ParameterToolCore` compile; `FeatureFlags.echoelAI` has **ZERO readers** — nothing is gated behind it.
- **CloudKit/Push:** declared + `AnnouncementCenter` exists but **hard-OFF** via `AnnouncementCenter.cloudKitConfigured = false` (launch-crash fix v10.79.148).
- **EchoelStore:** compiled but UNREACHABLE (`ProUnlockView` never presented); product plan is "app free, plugins one-time purchase, no subscription" (decisions.csv 2026-10-17).

### 2.4 Governance that applies to EVERY slice (hard-rules, inviolable)

1. **Audio thread sanctity:** no locks, no malloc, no ObjC, no GCD, no file I/O, no `print`, no `os_log` on render path. `nonisolated(unsafe)` mirrors for `@MainActor` reads.
2. **Protected Rausch triad is READ-ONLY:** no simplification of `BioEventGraph`, `HilbertSensorMapper`, `BioSignalDeconvolver`.
3. **Sheet-chain ceiling 14 modifiers on `EchoelStudioView`.** New modals **reuse a slot or consolidate** — never append a new `.sheet`.
4. **No `@Observable` 10 Hz read in `.menu`/Picker-host ancestors.** The `WorkspaceView` lesson 10.76.50 — reads live bio in a leaf, never a parent body.
5. **`EchoelValueField` for every NUMERIC parameter** everywhere except AUv3 (`EchoelTheme` not linked there). Named-choice parameters remain `Picker`.
6. **Branch discipline:** this feature lives on the session branch; the `Qdm6b` name question is unresolved (see header).
7. **Founder-gated edits (report, don't touch):** `.github/workflows/**`, `project.yml`, `Resources/iOS/Info.plist`. `.deploy/release` is NOT gated.
8. **Zero paid frameworks.** Only free, well-contained, Council-approved deps. The one planned external SPM dep is HaishinKit (RTMP).
9. **The Council** convenes before any significant / hard-to-reverse decision (new dep, new target, framing shift, >1 file).
10. **Grand Council** convenes for a pivot framing (this plan — before Phase A ships).

---

## 3. RECOMMENDED APPROACH — Phased slices (each a Ralph Wiggum cycle)

### Phase A — Repositioning in COPY, not in CODE *(cheapest, highest signal)*

- Update `docs/dev/FEATURE_STATUS.md` and `docs/dev/FEATURE_MATRIX.md` to the DMMW framing (not: "bio-reactive instrument"; yes: "unified multidimensional multimedia production suite").
- Audit `fastlane/metadata/`, `ContentPipeline/CLAIMS.md`, store description for bio-centric language and shift to DMMW capabilities already shipping.
- `BRAND` block in `CLAUDE.md` and the identity sentence remain unchanged **except via Grand Council** — those are hard-rules.
- Website `docs/` sweep: ensure no false claim (CLAIMS.md discipline; §2.3 Rejected list stays rejected: healing, chakras, Solfeggio).
- No Swift code changes. No `project.yml` touch.
- **Guard flip:** `WebsitePagesAreFindableAndHonestTests` must stay green.

### Phase B — Minimal Health + Weather UX *(the "ohne Biofeedback aber mit Wissen" layer)*

**B1. Break reminder.** Reuse `HealthKitBioPublisher` auth. New small type `StudioBreakCoach` reads `HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)` as a **daily aggregate** (not RR/HR). Delivers a non-intrusive banner inside the Workspace top-bar area ("Leg mal eine Produktionspause ein. Beweg dich.") after N minutes of continuous production without exercise. Opt-in, default OFF. Reuse `HealthWriteOptInRow` pattern.

- Files to touch: `Core/StudioBreakCoach.swift` (new), `Studio/ProjectHeader.swift` (add leaf view for banner).
- Guard: `BreakCoachBannerReadsInALeafTests` — the banner's live reads sit in a leaf, never in `WorkspaceView.body`.

**B2. Weather UI mood.** `Core/WeatherProvider` (lives, 3 callers). New small `WeatherMoodProvider` → emits an accent-tint hint (hue shift, max ΔE < 10) → consumed by `EchoelTheme`. Fallback: no-op when offline / permission denied. **UI stays fully usable without weather.** No new framework; `WeatherKit` already available on iOS 16+.

- Files to touch: `Core/WeatherMoodProvider.swift` (new), `Studio/EchoelTheme.swift` (add computed `moodAccent` that defaults to the current accent).
- Guard: `WeatherMoodDegradesToDefaultTests` — a nil weather returns the default accent exactly.

**No safety / medical / wellness language** in either. Both are productivity nudges.

### Phase C — Platform surface broadening *(founder-gated for `project.yml`)*

**C1. iPad enable (Council + founder gate).** Five settings + bio-source + reflow:
- `TARGETED_DEVICE_FAMILY` on App, Widget, AUv3, two test bundles → `1,2`.
- Update `DeviceFamilyIsPhoneOnlyTests` under founder approval.
- Bio source: no torch on iPad ⇒ BLE HRS or Watch is the primary; camera rPPG degrades gracefully.
- Panel reflow pass #292: the five already-adaptive panels (`mixerPanel`, `soundPanel`, `moodPanel`, `visualPanel`, `masterPanel`) are a start; the other four stack intentionally — do not force them to a grid.

**C2. visionOS target (Grand Council + founder).** New target `EchoelmusicVisionOS`:
- Mount `ImmersiveStageView` as the natural visionOS surface (it is doorless today, deliberately — Ship-Gate 4 says "demonstrable, not required").
- `#if os(visionOS)` guards for `RealityKit` + `ARKit` immersive content. No new SDK dep.
- A15 compatibility concern: visionOS is Apple Silicon only (M-series) — this target is M5/M6-era, so A15 constraint applies to iOS/iPadOS, not visionOS. **State this to the founder explicitly** before the slice ships.

**C3. Mac target (Catalyst or AppKit) — DEFER.** Not in this plan's first wave. Watch extension re-embed also deferred (B/C/D/E Watch slices live in `scratchpads/PLAN_WATCH_2026-09-13.md`).

**A15 floor:** iOS 18 supports A12+, so A15 is already the backward floor by virtue of iOS 18 running on it. No deployment-target bump needed. If the founder wants a tighter floor via `IPHONEOS_DEPLOYMENT_TARGET`, that's `project.yml` and founder-gated.

### Phase D — Live Streaming (RTMP, the real P4 Broadcast)

**D1. Link HaishinKit (Council + founder — first external SPM dep).** `BroadcastPublisher` stays the facade.
- Files to touch: `Package.swift` (dep), `Stream/BroadcastPublisher.swift` (drop the `#if canImport` scaffold, enable the real path).
- Encapsulation: HaishinKit sits behind `BroadcastEngine` protocol; the rest of the app never imports HaishinKit directly.

**D2. Door `BroadcastView`.** Reuse an existing sheet slot (NEVER append) — the chip is `broadcast` in `EchoelStudioView.studioChips`.
- Audio tap: master out via `AudioEngine` main mixer tap (zero-copy, no audio-thread allocation).
- Video source: `FloatingVisualWindow` content capture + Metal frames (ReplayKit `RPScreenRecorder` for one-click; `AVCaptureSession` would require re-adding the deleted mic/camera path, which is forbidden).

**D3. Latency + bitrate presets.** Three: `low-540p/30`, `balanced-720p/30`, `high-1080p/60`. Target end-to-end: <2 s to a nearby RTMP server.

**Guard:** `TheBroadcastPathDoesNotResurrectTheMicTests` — no `AVCaptureSession` mic in the stream encode path; audio comes from the engine tap only.

### Phase E — 180°/360° spatial video (viewer-first)

**E1. Playback.** Use `AVFoundation` + `AVPlayerItemVideoOutput`:
- VR180 EXIF detection → half-sphere projection on iOS; full sphere on visionOS via RealityKit texture-mapped sphere.
- MV-HEVC (spatial video) playback via `AVPlayerViewController` on iOS 17+/A17+ for display; metadata-only pass-through on A15 (file reference in `TimelineStore`, playback on supported devices only).
- Fisheye: deferred (specialized dewarping shaders — Phase E.2 if founder requests).

**E2. Recording & editing — DEFER.** No `VideoRecorder` comeback. Users import pre-captured 180°/360° files via system share-sheet → `MediaLibrary` → `TimelineRegion`. This respects #1304 (no video capture) while still enabling the production surface.

### Phase F — Spatial audio render (wire the dormant halves)

- Door the render path: `VBAPPanner` + `AmbisonicsEncode` + `BinauralPanner` behind `SpatialSceneStore` already-live egress.
- Head tracking: visionOS gets `ARKit`-based head tracking; iOS keeps a static listener position.
- `TheSpatialRenderHalfIsNotClaimedLiveTests` must be flipped **in the same commit** that wires the render — never ahead.
- AUv3 unaffected (`DSP/` imports Foundation + Accelerate only).
- Guard: audio-thread sanctity in the binaural render block — `nonisolated(unsafe)` mirrors for every `@MainActor` parameter.

### Phase G — AI-driven audio & video *(advisor, never actor)*

**G1. Audio advisor.** Wire `EchoelAI/ParameterToolCore` to an on-device `MLX` (Apple's `mlx-swift`) model that proposes **modulation routes**. The user applies manually via the matrix UI — nothing writes to the bus without user action.
- Council + founder for `mlx-swift` dependency.
- Guard: `TheAIAdvisorNeverWritesWithoutConsentTests` — proof via static analysis that only `PatchbayView` calls `ModRoute(` under a user gesture.

**G2. Video assistant.** `Vision` framework scene classifier → style suggestions for `MetalBioView` and `FloatingVisualWindow`. No generative video, no deepfake surface. Rejected by brand hard-rule.

**G3. Core ML Models.** Zero binary blobs in-repo. `.mlpackage` files, if any, live under `Resources/MLModels/` with a `README.md` naming the training data and the license.

### Phase H — Multi-touch, Accessibility, Lightweight UI

**H1. Multi-touch audit.**
- `MagnifyGesture` + `RotateGesture` on Spectral Donut (`SpectralDonutView`).
- `SimultaneousGesture` for two-finger timeline scrub on `WorkstationView`.
- `DragGesture` consolidation: every parameter uses `EchoelValueField`'s vertical-fader drag; no raw `Slider`.

**H2. Accessibility pass.**
- `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue` on every chip, chooser, matrix cell.
- Dynamic Type uncapped (already law; verify in reflow guards).
- Reduce Motion: `MetalBioView` and `FloatingVisualWindow` honor `UIAccessibility.isReduceMotionEnabled`.
- Max 3 Hz flash rate (already law in `BreathGuideView`'s ≤0.2 Hz).
- VoiceOver walkthrough recorded as a Guide for the first-run teach-in.

**H3. Lightweight (Leichtbau) UI.**
- Honor `Uncodixfy` rules (CLAUDE.md UI DESIGN CONSTRAINTS): no glassmorphism, no neon, radii ≤ 16 px, shadows ≤ 8 px blur, 100–200 ms transitions opacity/color only.
- Panel ergonomics: continue the #292 reflow pass only where NEW benches have adjacent peers to pair (CLAUDE.md: `tempoToolsPanel` was NOT a reflow candidate because its two fields are deliberately non-adjacent).

---

## 4. CRITICAL FILES — Reuse map

| Role | File |
|---|---|
| Workspace root | `Sources/Echoelmusic/Studio/WorkspaceView.swift` |
| Default home surface | `Sources/Echoelmusic/Workstation/WorkstationView.swift` |
| Instrument | `Sources/Echoelmusic/Studio/EchoelStudioView.swift` |
| Theme / accent | `Sources/Echoelmusic/Studio/EchoelTheme.swift` |
| Parameter idiom (reuse — don't fork) | `Sources/Echoelmusic/Views/EchoelValueField.swift`, `Sources/Echoelmusic/Views/EchoelNumberPad.swift` |
| Engine spine | `Sources/Echoelmusic/Core/EngineBus.swift`, `Sources/Echoelmusic/Core/SPSCQueue.swift` |
| OSC egress | `Sources/Echoelmusic/Sync/OSCSender.swift` |
| ADM-OSC egress | `Sources/Echoelmusic/Sync/ADMOSCSender.swift` |
| Spatial dormant halves | `Sources/Echoelmusic/Sync/VBAPPanner.swift`, `Sync/AmbisonicsEncode.swift`, `DSP/BinauralPanner.swift`, `DSP/EchoelSpaceReverb.swift` |
| Streaming scaffold | `Sources/Echoelmusic/Stream/BroadcastPublisher.swift`, `Stream/BroadcastEngine.swift` |
| Weather | `Sources/Echoelmusic/Core/WeatherProvider.swift` |
| HealthKit | `Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift` |
| rPPG pulse path (misleading dir — DO NOT prune) | `Sources/Echoelmusic/Video/CameraCapture.swift`, `Video/CameraAnalyzer.swift`, `Video/RPPGConditioning.swift`, `Video/PulsePeriodEstimator.swift` |
| Protected triad | `Sources/Echoelmusic/Bio/BioEventGraph.swift`, `Bio/HilbertSensorMapper.swift`, `Bio/BioSignalDeconvolver.swift` |
| Timeline / Workstation engine | `Sources/Echoelmusic/Core/TimelineStore.swift`, `Sequencer/AudioLanePlayer.swift`, `Sequencer/TimelineAudioSink.swift`, `Sequencer/AudioImport.swift` |
| AI tool core | `Sources/EchoelAI/ParameterToolCore.swift`, `Core/EchoelParameterRegistry.swift` |
| Immersive stage (visionOS natural seat) | `Sources/Echoelmusic/Studio/ImmersiveStageView.swift`, `Sync/ADMStreamStatusLine.swift` (child, doorless intentionally) |
| Visual output | `Sources/Echoelmusic/Views/MetalBioView.swift`, `Studio/FloatingVisualWindow.swift` |
| `MusicalFrame` spine | `Sources/Echoelmusic/Studio/PianoRollView.swift` (holds `PianoRollModel`) |
| Founder-gated (report only) | `project.yml`, `.github/workflows/**`, `Resources/iOS/Info.plist` |

---

## 5. VISION ALIGNMENT

### STAYS BRIGHT (vision-alignment, grand-council, factory skills apply)
- **Open standards**: ADM-OSC, OSC, MPE Out, BLE HRS 0x180D, Art-Net, sACN. No SDK lock-in. (Roman/Adamson relationship stays alive.)
- **Science-only language**: no healing, no wellness, no chakras, no Solfeggio. Permanent brand red line.
- **Accessibility-first**: 3 Hz max flash, Dynamic Type, VoiceOver, Reduce Motion.
- **Zero paid frameworks**: default stays Swift; new deps require Council.
- **Protected Rausch triad**: knowledge preserved, read-only.
- **Env/peace/inclusion/sustainability**: UI stays low-energy (Leichtbau), no feature justifies waste. 60 fps pinned, thermal via DETAIL stage, not FPS.
- **DMMW law**: own the creative workflow, integrate the specialist ecosystem (never rebuild codecs/Dante/NDI/CDNs/plugin SDKs).

### DIMS (framing only — code preserved)
- **Biofeedback as the identity** ⇒ becomes one modulation dimension among many.
- `Bio/` and the DDSP coupling remain; store copy, website, first-run teach-in no longer center it.
- The identity sentence (`Physical Computing · Biofeedback · Multimedial & Multidimensional`) is a hard rule and only changes via **Grand Council**.

### GROWS
- Streaming (RTMP via HaishinKit — the planned-but-unlinked P4).
- Spatial video (VR180/360/MV-HEVC playback; recording imported, not captured).
- Spatial audio render (wire the four dormant halves).
- visionOS target (immersive output surface already exists doorless).
- AI advisor (parameter proposals, never auto-writes).
- Minimal Health UX (break reminder, opt-in, default OFF).
- Minimal Weather UX (accent tint, offline-safe fallback).

---

## 6. VERIFICATION

End-to-end verification steps, slice by slice (CLAUDE.md Phase-3 Verify discipline).

| Slice | How to verify |
|---|---|
| A — Copy | `grep -rE 'healing\|chakra\|solfeggio\|chakras' docs/ fastlane/ ContentPipeline/` returns 0. `WebsitePagesAreFindableAndHonestTests` green. |
| B1 — Break coach | Simulate 60 min of app usage with 0 exercise minutes mocked → banner appears. `BreakCoachBannerReadsInALeafTests` green. |
| B2 — Weather mood | Toggle airplane mode → theme accent reverts to default without crash. `WeatherMoodDegradesToDefaultTests` green. |
| C1 — iPad | `Xcode Compile Check` green on new target slice; `DeviceFamilyIsPhoneOnlyTests` updated under founder gate. Device run on iPad Pro M-series. |
| C2 — visionOS | `xcrun simctl list` shows the new simulator target; immersive stage mounts in simulator; AV egress unchanged. |
| D — RTMP | Local MediaMTX / nginx-rtmp instance receives stream; end-to-end < 2 s latency. `TheBroadcastPathDoesNotResurrectTheMicTests` green. |
| E — Spatial video | VR180 asset plays correctly on iPhone and visionOS simulator; MV-HEVC detection on iPhone 15 Pro+. |
| F — Spatial audio | Binaural output measurable (headphones, static test tone); ADM-OSC continues sending on the same ticks. `TheSpatialRenderHalfIsNotClaimedLiveTests` flipped in same commit. |
| G — AI advisor | Advisor proposes a `ModRoute`; nothing is applied without a tap in `PatchbayView`. `TheAIAdvisorNeverWritesWithoutConsentTests` green. |
| H — Multi-touch + Accessibility | VoiceOver walkthrough of Workstation + EchoelStudio reaches every chip; `MasterPanelReflowsTests` + siblings green at 375 pt and iPad 1024 pt. |

**All phases**: `swift build -warnings-as-errors` (founder Mac) OR `Xcode Compile Check` (web session). `Build for Testing` + `python3 scripts/gh-test-verdict.py <log>` for CI reading.

---

## 7. GOVERNANCE AND PATH TO MERGE

- **Grand Council** gate before Phase A (framing shift is hard-to-reverse).
- **The Council** gate before every new dep (HaishinKit D1, mlx-swift G1), new target (visionOS C2), new feature phase (E, F, G, H).
- **decisions.csv** entries for each: DMMW framing shift, HaishinKit addition, visionOS target add, iPad enable, Weather-theme coupling, AI advisor pattern.
- **This file** mirrors the plan at `/root/.claude/plans/claude-unified-production-app-qdm6b-wie-floofy-alpaca.md`; each Ralph Wiggum cycle updates this scratchpad.
- **Branch** receives all commits — current session branch is `claude/multimedia-production-suite-pN0Eo` (see header for the `Qdm6b` note).
- **auto-merge gate**: `Xcode Compile Check` (conclusion) + `CI/CD Pipeline` → `Build for Testing` step status + `Echoel Studio` (conclusion) if `EchoelStudio/**` touched. A scratchpad-only commit does NOT trigger auto-merge (CLAUDE.md law).
- **Founder-gated edits** (`.github/workflows/**`, `project.yml`, `Resources/iOS/Info.plist`): this plan surfaces each needed edit as a founder-inbox entry, does not autoedit.
- **PR template** (if a PR is explicitly requested later): mirror `.github/pull_request_template.md` if present.

---

## 8. WHAT THIS PLAN IS NOT

- **Not a rewrite.** `EngineBus`, OSC/ADM-OSC egress, protected Rausch triad, `EchoelValueField`, Workstation spine, AUv3 extension — all unchanged.
- **Not a bio removal.** All code and knowledge remain. Only FRAMING shifts.
- **Not a dep fest.** Only HaishinKit (long-planned) and, optionally after Council, mlx-swift.
- **Not a workflow / Info.plist / project.yml edit.** Those are founder-gated.
- **Not an iPad / Mac / Watch embed in Phase 1.** Those are separate slices with their own Council passes.
- **Not a mic/camera resurrection.** `#1302` and `#1304` deletions are respected everywhere.
- **Not a biofeedback marketing claim.** CLAIMS.md discipline carries.

---

## 9. CLEAN HANDOFF

This file is the artifact. The founder reviews it when convenient; on approval, Phase A copy edits ship first as a Ralph Wiggum slice, followed by Phase B. Each slice is one commit on the session branch, pushed with conventional-commit prefix. The founder is notified only for Council gates and `project.yml`/workflow questions.

**Open founder decisions needed before Phase A:**
1. **Branch name:** stay on `claude/multimedia-production-suite-pN0Eo` (harness default, current state), rename to `claude/unified-production-app-Qdm6b` (your explicit mention — note: that name already exists as a stale April 2026 sprint on origin), or create a fresh name.
2. **Grand Council** sign-off for the DMMW framing shift away from bio-as-identity.
3. **Dependency gates**: when ready — HaishinKit (D1), mlx-swift (G1), visionOS target (C2).

**Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>**
**Claude-Session: https://claude.ai/code/session_015AT2qAYZridWTAU1QfKjb2**
