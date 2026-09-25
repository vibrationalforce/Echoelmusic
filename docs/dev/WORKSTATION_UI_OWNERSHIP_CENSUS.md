# WA1 — Workstation / UI Ownership Census

⭐ **WA1 COMPLETE (2026-09-24).** "W1"/"W2"/"W3" below mean WA1/WA2/WA3 of the master plan. Every
"NEEDS W2 DECISION" row is now answered by the WA2 decision (APPROVED WITH BINDING AMENDMENTS,
`docs/dev/SESSION_OWNERSHIP_CENSUS.md` §O); the rows are kept as the evidence they were.

**Status: EVIDENCE, not a roadmap.** Read-only census, 2026-09-24. Branch head at census time
`dd14a8b69`, `main` = `7b2690357`. No code, test, CI, view or model was changed.

**Authority order used:** `docs/dev/FOUNDER_PRODUCT_LAW.md` → `docs/dev/ECHOELMUSIC_MASTER_PLAN.md`
→ current code and tests → `docs/dev/HISTORY_ARCHIVE.md` → older ROADMAP / `CLAUDE.md` wording
(history only).

⚠️ **Output path.** This file is the WA1 output; the master plan's old `scratchpads/` path for it
was corrected in the WA2 decision-lock commit.

⚠️ **Known stale sources, reported and NOT edited:**
- `ROADMAP.md` still calls itself the sequencing source of truth. The master plan is.
- In `CLAUDE.md`, the "Positioning" and "Root view" paragraphs still frame the app as "the
  bio-generative INSTRUMENT is the app HOME". Product law 2026-09-24 supersedes that framing. The
  engineering warnings in those paragraphs still hold.
- Two stale doc comments found during the census:
  - `EchoelStudioView.swift` calls `workstationPanel` "the read-only Workstation plate". It is
    not read-only (§C, S38). `WorkstationView`'s own header already says "READ-ONLY HAS NARROWED TWICE".
  - The `WorkspaceView.swift` header lists a "video" chrome door. It has no poster and no
    receiver case.

**How it was measured.** Four read-only inspection passes: shell, Studio panels, secondary
surfaces, and history plus models. I then re-measured every load-bearing number myself. Commands
are named next to the numbers. Line numbers are dates, not facts (`CLAUDE.md` §E), so re-derive
them before acting.

---

## A. Executive summary

1. **There is one real shell, and it is the instrument.**
   - The chain is `EchoelmusicApp` → `WorkspaceView` → `SurfaceHost` → `EchoelStudioView`.
   - `EchoelStudioView` is a 12.7 k-line struct. Its 10-case `StudioMenu` chip strip is the
     dominant extension seam: every new surface since #1436 (Workstation) has entered through it.
   - Top-level navigation is owned by `EchoelStudioView.activeMenu`, which is `@State`. The
     `WorkspaceView` header opens studio surfaces only through string notifications
     (`.echoelChromeDoor` "bio" / "routing").
2. **Workstation and device are fused in one view.**
   - The same `EchoelStudioView` struct holds the Echoel device and the workstation:
     - device: synthesis, composer, FX character, bio arm, touch voice;
     - workstation: transport, project save/open, export, master, routing door, arrangement.
   - The same methods (`generate`, `open`, `stopEverything`, `resetSoundToDefaults`) write both.
     Any W3 split has to cut through those methods, not only through the views.
3. **The hypothesis holds only in part.** The current Echoel experience can become a native
   device, but not as a whole. The chip plate the user sees as "the instrument" holds all three
   groups of §D at once:
   - **device:** Sound, FX, Mood, Mix, the Field voice, the body-voice arm, variations;
   - **workstation:** Start/transport, Tempo, Master, Save & Export, Workstation, Open/Save,
     Routing;
   - **domain:** Field look (visual), the bio source, light (inside Routing).
   No percentage is given: surfaces differ too much in size for a share by count to mean
   anything. The class counts in item 4 are the measurement. The current "Mix" panel looks like a workstation mixer. It is the device's internal voice mix,
   and that is the sharpest mis-reading risk found (S28).
4. **Surfaces inventoried: 65** (§C). Primary class: WORKSTATION 29 · DEVICE 10 ·
   DOMAIN TOOL 13 · PERFORMANCE 3 · LEGACY / PARK 10. Disposition: KEEP 27 · MOVE INTO
   WORKSTATION 4 · MOVE INTO DEVICE 7 · MOVE INTO DOMAIN TOOL 3 · PERFORMANCE ONLY 1 · PARK 10 ·
   **NEEDS W2 DECISION 13**. (Counts parsed from table C1, not hand-tallied.)
5. **The modal budget is spent, not free.**
   - `EchoelStudioView` has 12 presentation modifiers file-wide, 11 of them on the black-screen
     chain (ceiling 14).
   - Five of the 11 carry workstation functions that should become persistent space: Routing,
     Open/project, the FX editor, collaboration, and Save project.
   - One slot (`showMeditation`) has no setter and is free headroom.
6. **State ownership is the largest risk class.**
   - There are **99 distinct `@AppStorage` bindings** in `Sources/Echoelmusic`. **54 of them are
     declared in more than one view.** A persistent key is truth, and it is spread across views.
   - `EchoelStudioView` owns a persistence store as view `@State` (`MoodPresetStore`), and so does
     `EchoelFXView` (`FXPresetStore`).
   - Session truth such as `currentPatch` and `delaySync` lives in view `@State`.
   - All 58 engines and stores are `@State` of the `@main` App struct.
7. **Realtime safety is currently held, by leaves and by a discipline that has no owner.**
   - No hot read was found in the `WorkspaceView` / `EchoelStudioView` bodies.
   - Several views write straight into engines: `generate`, the tap-tempo `setTempo`, mixer
     inserts, the touch surface's notes, and master-chain presets. A workstation split must give
     these writes a non-view owner.
8. **W2 is blocked on facts already known.** The details are in §I:
   - four song-like roots: Project, TimelineDocument, Arrangement, ClipStore;
   - three automation homes;
   - three key/scale homes;
   - an `ArrangementStore` with **zero writers**.
   §J lists 12 questions.

**READY FOR W2** — every inventoried surface has one primary class, a file, a measured door and a
disposition. Nothing in this census chooses Session ownership.

---

## B. Current shell map

```
EchoelmusicApp (@main, EchoelmusicApp.swift)                 ← 58 engines/stores as @State
 ├─ WindowGroup
 │   ├─ SafeModeView            (LaunchGuard.isSafeMode)      alternate root 1
 │   ├─ OnboardingView          (!hasCompletedOnboarding)     alternate root 2 (page TabView)
 │   └─ WorkspaceView           (+ ~50 .environment lines)    the root
 │       ├─ topBar: logo · TransportPositionView · wordmark(openURL)
 │       │          · EchoelLuxMonitorMini ──post "routing"──┐
 │       │          · ImmersiveMonitorMini (toggles floating visual)
 │       ├─ CompositionHeaderStrip (genre/key/scale/tuning/A4/lock) ──post .echoelCompositionEdited
 │       ├─ SurfaceHost → EchoelStudioView  ◄── receives .echoelChromeDoor / .echoelSelectBioSource
 │       │    ├─ startControlRow (Start · BodyTempoField · PlaybackToggle · PulseMonitorMiniLive
 │       │    │                   · quickActionRow · quickDoorRow · AudioDegradedRow)
 │       │    ├─ menuBar: studioChips = sound·effects·mix·master·mood·composition·field·workstation·export
 │       │    │           (+ .bio appended when the pulse pill opened it)
 │       │    ├─ menuPanelHost → dropdownContent (AnyView per StudioMenu case)
 │       │    └─ modal chain: 7 sheets · 1 fullScreenCover · 3 alerts   (+ 1 nested .fileImporter)
 │       ├─ FloatingVisualWindow (always mounted; small/medium/large/fullscreen)
 │       │    ├─ MetalBioView | VisualAnalysisLayer | SpectralDonutView | "on external screen"
 │       │    ├─ TouchInstrumentView overlay (plays touch synth + MIDI out)
 │       │    └─ handle: Studio chip · look scrub · MiniTransportView · meters · WAV record · size
 │       └─ GuideOverlay
 └─ Info.plist scene role → ExternalDisplaySceneDelegate → ExternalStageView (MetalBioView, non-interactive)
Separate products: EchoelmusicAUv3 (own SwiftUI slider view) · EchoelmusicWidgets (embedded)
                   · EchoelmusicWatch (compiled, NOT embedded — `project.yml` line commented out)
```

**The actual App root.** `EchoelmusicApp.body` has one `WindowGroup` with a three-way switch:
safe mode, onboarding, or `WorkspaceView`.
- A second scene exists only through the Info.plist role
  `UIWindowSceneSessionRoleExternalDisplayNonInteractive`.
- Measured with `git grep -n "WindowGroup\|var body: some Scene" -- Sources/Echoelmusic/EchoelmusicApp.swift`.

**Who owns top-level navigation.** `EchoelStudioView.activeMenu`, a `@State StudioMenu?` that
nothing persists. `displayedMenu = activeMenu ?? .sound`.
  ⚠️ Amended by WA4-P2 (2026-09-25): the fallback is now `reopensWorkstation ? .workstation :
  .sound` — one persisted Bool (`studio.reopensWorkstation`), written only when the player
  chooses a plate. `activeMenu` itself is still unpersisted `@State`.
- `WorkspaceView` owns no navigation state. It owns two persistent visual-window keys and posts
  string notifications into the studio.
- **One receiver** handles those strings: the `.onReceive(.echoelChromeDoor)` on `menuBar`.

**Competing shell concepts: 7 live, 1 dead.**
1. `WorkspaceView` chrome.
2. The `EchoelStudioView` chip / front-plate system.
3. The Workstation chip. It is an arrangement surface inside the instrument's plate.
4. `FloatingVisualWindow` at fullscreen, seeded as the "instrument home" when
   `FeatureFlags.instrumentHome` is set. It has its own exit chip, mini transport and meters, so
   it is effectively a second root laid over the first.
5. Sheets that are navigation roots: `PatchbayView` has its own `NavigationStack` and a push.
   `EchoelFXView`, `LiveColaboView` and `LearnView` also bring `NavigationStack`s.
6. The external-display scene (UIKit, non-interactive).
7. The launch branches `SafeModeView` and `OnboardingView`.
- **Dead:** `SurfaceSwitcher.swift`. It now only defines `SurfaceHost`; the switcher bar and the
  `WorkspaceSurface` enum are deleted, and the `workspace.surface` default is orphaned.

**Is the chip/panel system the dominant extension seam? Yes.** Chip-hosted:
- Workstation (#1436);
- Master and Export (#290);
- Field (renamed from `synth`).
It costs zero presentation modifiers, which is why it won (see the `StudioMenu` comment on
`.workstation`).

**Surfaces that bypass the seam:**
- the header monitors: a notification door into the seam, plus one direct `@AppStorage` toggle
  for the visual window;
- `CompositionHeaderStrip`, which writes `@AppStorage` and posts a notification;
- `FloatingVisualWindow` and its handle-bar tools;
- every sheet on the modal chain;
- `PatchbayView` (reached from three places: the Master panel, the Bio panel and the header tile);
- the external display;
- the `quickDoorRow` tiles, which open sheets directly.

**Temporary or historical patterns still in the shell:**
- The chrome-door **string** protocol ("bio", "routing"; "video" survives only in a header comment).
- `echoelPanelForceOpen` makes every `EchoelPanel` disclosure permanently open. As a result the
  `isExpanded` flags `studio.showComposition` / `showMix` / `showExport` (persisted) and
  `showMood` / `showSound` / `showWorkstation` (`@State`) no longer do anything.
- The `presentSession` binding / `sessionEntryCard`. `SurfaceHost` never passes the binding, so
  the card cannot appear.
- `moodPadsSection` and `liveNarrationBanner` are declared and never referenced.
- The instrument-home fullscreen seed.

This census does **not** design a replacement shell.

---

## C. Surface ownership table

**Columns (the 16 required fields, split into two tables keyed by ID):**
- **C1:**
  - (1) name
  - (2) file
  - (3) door
  - (4) primary class
  - (5) secondary relationship
  - (12) reusable as Device UI
  - (13) workstation-global
  - (14) domain-specific
  - (15) historically transitional
  - (16) disposition
- **C2:**
  - (6) models read
  - (7) models written
  - (8) ONLY writer of
  - (9) fast/live values
  - (10) realtime-sensitive state touched
  - (11) modal created

**Abbreviations:**
- Class: WS = WORKSTATION · DEV = DEVICE · DOM = DOMAIN TOOL · PERF = PERFORMANCE ·
  PARK = LEGACY / PARK.
- Disposition: MI-WS / MI-DEV / MI-DOM = MOVE INTO WORKSTATION / DEVICE / DOMAIN TOOL ·
  W2 = NEEDS W2 DECISION.
- File prefix: `S/` = `Sources/Echoelmusic/Studio/`, ESV = `EchoelStudioView.swift`.

**Doors** were measured with `git grep -n "Name(" -- Sources | grep -v ': *//'`, following the
constructor to a rendering parent. Doorless surfaces agree with `python3 scripts/doctor.py
--section C`: 5 never constructed, 3 reachable only through a doorless parent, 1 setterless
modal flag.

Two sections of ESV are also doorless and are **not** listed by doctor, because they are
constructed-but-unreferenced sections rather than view types: `moodPadsSection` and
`sessionEntryCard`.

### C1 — identity, class, disposition

| ID | (1) Surface | (2) File | (3) Door | (4) Class | (5) Secondary | (12) Dev-UI | (13) WS-glob | (14) Domain | (15) Transitional | (16) Disposition |
|---|---|---|---|---|---|---|---|---|---|---|
| S01 | App root switch | `EchoelmusicApp.swift` | launch | WS | — | no | yes | — | no | KEEP |
| S02 | SafeModeView | `S/SafeModeView.swift` | launch (LaunchGuard) | WS | system | no | yes | — | no | KEEP |
| S03 | OnboardingView | `Views/OnboardingView.swift` | first launch | WS | — | no | yes | — | no | KEEP |
| S04 | WorkspaceView chrome (topBar) | `S/WorkspaceView.swift` | root | WS | shell | no | yes | — | yes (shell has changed 6×, archive D10) | KEEP |
| S05 | CompositionHeaderStrip | `S/WorkspaceView.swift` | header, always | WS | DEV (genre = composer input) | partly | yes (key/scale/A4) | music | no | **W2** |
| S06 | TransportPositionView | `S/WorkspaceView.swift` | header | WS | — | no | yes | — | no | KEEP |
| S07 | PlaybackToggleButton | `S/WorkspaceView.swift` (built in ESV `transportLine1`) | top line | WS | PERF | no | yes | — | no | **W2** |
| S08 | PulseMonitorMiniLive (pulse pill) | `S/HeaderMonitors.swift` | top line | DOM (bio) | door into S35 | no | no | bio | no | KEEP |
| S09 | ImmersiveMonitorMini | `S/HeaderMonitors.swift` | header | DOM (visual) | toggle for S12 | no | no | visual | no | KEEP |
| S10 | EchoelLuxMonitorMini | `S/HeaderMonitors.swift` | header | DOM (light) | door into S45 | no | no | light | no | KEEP |
| S11 | GuideOverlay | `S/GuideOverlay.swift` | root overlay | WS | help | no | yes | — | no | KEEP |
| S12 | FloatingVisualWindow | `S/FloatingVisualWindow.swift` | header monitor, Field panel, instrument-home seed | DOM (visual) | PERF host, second root | no | no | visual | yes (instrument-home seed) | KEEP |
| S13 | TouchInstrumentView | `S/TouchInstrumentView.swift` | S12 overlay, every size | PERF | DEV (plays touch voice) | yes | no | — | no | PERFORMANCE ONLY |
| S14 | Visual-window WAV record/export control | `S/FloatingVisualWindow.swift` (handle bar) | S12 handle | WS (export) | — | no | yes | — | no | MI-WS |
| S15 | MiniTransportView | `S/FloatingVisualWindow.swift` | S12 handle | WS | projection of transport | no | yes | — | no | KEEP |
| S16 | VisualAnalysisLayer + 4 meters | `S/VisualAnalysisMeter.swift`, `S/Analysis*View.swift` | S12 "Meters" | DOM (visual/analysis) | DEV analyzer | **yes** | partly (master out) | visual | no | KEEP |
| S17 | SpectralDonutView | `S/SpectralDonutView.swift` | S12, Field toggle | DOM (visual) | — | yes | no | visual | no | KEEP |
| S18 | InstrumentHintOverlay | `S/FloatingVisualWindow.swift` | S12 fullscreen | PERF | help | no | no | — | no | KEEP |
| S19 | ExternalStageView | `S/ExternalDisplayScene.swift` | Info.plist scene role | DOM (stage) | — | no | no | visual/stage | no | KEEP |
| S20 | EchoelStudioView host (chip strip + front plate) | ESV | root via SurfaceHost | WS (de facto shell) | DEV (fused) | no | yes | — | yes | **W2** |
| S21 | Start button (`toggleBiofeedback`) | ESV `startControlRow` | top line | PERF | DEV + WS (starts session, generator, bio source, transport) | no | yes | bio | no | **W2** |
| S22 | quickActionRow (Record · Keep last · MIDI · Save) | ESV | top line | WS | — | no | yes | — | no | MI-WS |
| S23 | quickDoorRow (Open · Live Colabo · Learn) | ESV | top line | WS | — | no | yes | — | no | MI-WS |
| S24 | BodyTempoField | `S/BodyTempoField.swift` | top line | WS (tempo) | DOM bio (Flow follows pulse) | no | yes | bio | no | **W2** |
| S25 | soundPanel | ESV | chip Sound (default) | DEV | WS (tuning banner) | **yes** | no | sound | no | MI-DEV |
| S26 | effectsPanel (FX character, delay sync) | ESV | chip FX | DEV | — | yes | no | sound | no | MI-DEV |
| S27 | EchoelFXView (full FX editor) | `S/EchoelFXView.swift` | sheet from effectsPanel | DEV | — | **yes** | no | sound | no | MI-DEV |
| S28 | mixerPanel (bass · pad · field · click levels, bus FX) | ESV | chip Mix | **DEV** (internal voice mix) | WS (click → metronome) | yes | **no** (not a track mixer) | sound | no | MI-DEV |
| S29 | masterPanel | ESV | chip Master | WS | — | no | yes | — | no | KEEP |
| S30 | MasterLoudnessGrid + MasterVolumeField | `S/MasterLoudnessGrid.swift` | masterPanel; BroadcastView (doorless) | WS | DEV analyzer | yes | yes | — | no | KEEP |
| S31 | moodPanel (+ rhythm, pad shape, variation, weather rows) | ESV | chip Mood | DEV (composer character) | — | **yes** | no | music | no | MI-DEV |
| S32 | tempoToolsPanel (tap · metronome · haptics · variations maze) | ESV | chip Tempo | WS | DEV (variations maze) | partly | yes | — | no | **W2** |
| S33 | visualPanel (look · presets · window) | ESV | chip Field | DOM (visual) | DEV (instrument-local visual response) | partly | no | visual | yes (was "synth") | MI-DOM |
| S34 | touchSoundSection (Field voice) | ESV (inside visualPanel) | chip Field | DEV | PERF (voice of S13) | yes | no | sound | no | MI-DEV |
| S35 | bioPanel (source · arm · auto · body-only) | ESV | pulse pill → chrome door "bio" | DOM (bio) | DEV (`BreathVoiceRow`, `AutoModeRow`) | partly | no | bio | no | MI-DOM |
| S36 | BioStripView (+ BioMetricInfoView, guide) | `S/BioStripView.swift`, `S/BioMetricInfo.swift` | bioPanel | DOM (bio) | — | no | no | bio | no | KEEP |
| S37 | HealthWriteOptInRow | ESV (bioPanel) | bioPanel | DOM (bio consent) | — | no | no | bio | no | KEEP |
| S38 | WorkstationView (`workstationPanel`) | `S/WorkstationView.swift` | chip Workstation | WS | — | no | yes | — | yes (young, #1436–#1440, F1) | **W2** |
| S39 | utilityRow (Save & Export · loop length · place · artist · reset · diagnostics) | ESV | chip Save/Export | WS | DEV (loop length, sound reset) | no | yes | — | no | **W2** |
| S40 | openSheet (+ JSON `.fileImporter`) | ESV | quickDoorRow "Open" | WS | — | no | yes | — | no | **W2** |
| S41 | "Save project" alert | ESV | quickActionRow "Save" | WS | — | no | yes | — | no | **W2** |
| S42 | "Save sound" / "Save mood" alerts | ESV | soundPanel / moodPanel | DEV | — | yes | no | — | no | MI-DEV |
| S43 | diagnosticsSheet | ESV | Export panel; auto after crash | WS | system | no | yes | — | no | KEEP |
| S44 | ShareSheet | ESV | export/record | WS | — | no | yes | — | no | KEEP |
| S45 | PatchbayView — routing graph + network out + OSC/MIDI I/O | `S/PatchbayView.swift` | sheet: Master "Routing", Bio "Open Routing", header Lux tile | WS | — | no | yes | — | no | MI-WS |
| S46 | PatchbayView `modulationSection` (Body → parameter) | `S/PatchbayView.swift` | inside S45 | DEV (bio modulation) | WS (tempo destination) | yes | partly | bio | no | **W2** |
| S47 | PatchbayView `lichtSection` (grand master · blackout · DMX size) | `S/PatchbayView.swift` | inside S45 | DOM (light) | — | no | no | light | no | MI-DOM |
| S48 | BluetoothMIDIPairingView | `S/PatchbayView.swift` | NavigationLink in S45 | WS | — | no | yes | — | no | KEEP |
| S49 | LiveColaboView | `S/LiveColaboView.swift` | sheet from quickDoorRow | WS (collaboration) | PERF | no | yes | — | no | **W2** |
| S50 | LearnView | `S/LearnView.swift` | sheet from quickDoorRow | WS (help/content) | — | no | yes | content | no | KEEP |
| S51 | AutomationStatusStrip | `S/AutomationStatusStrip.swift` | soundPanel | WS (automation) | — | no | yes | — | no | **W2** |
| S52 | AudioDegradedRow | `S/AudioDegradedRow.swift` | top line | WS (engine status) | — | no | yes | — | no | KEEP |
| S53 | LiveNarrationDisclosure + StudioCaptionView | `S/LiveNarrationDisclosure.swift`, `S/StudioCaptionView.swift` | Mood/Sound area | DEV (composer narration) | — | yes | no | music | no | KEEP |
| S54 | AUv3 plugin view | `Sources/EchoelmusicAUv3/AudioUnitViewController.swift` | host app | DEV | — | no (stock sliders, no Echoel primitives) | no | sound | yes (#1385) | KEEP |
| S55 | EchoelBioWidget | `Sources/EchoelmusicWidgets/EchoelBioWidget.swift` | home screen | DOM (bio display) | — | no | no | bio | no | KEEP |
| S57 | MeditationView | `S/MeditationView.swift` | **none** (`showMeditation` never set true) | PARK | DOM bio | no | no | bio | yes (I7) | PARK |
| S58 | BioSourceView | `S/BioSourceView.swift` | **none** | PARK | DOM bio | no | no | bio | yes (bottom bar) | PARK |
| S59 | BreathGuideView | `S/BreathGuideView.swift` | only via S58 | PARK | DOM bio | no | no | bio | yes (I7) | PARK |
| S60 | PulseMeasurementView | `S/PulseMeasurementView.swift` | only via S58 | PARK | DOM bio | no | no | bio | yes | PARK |
| S61 | SessionView | `S/SessionView.swift` | **none** | PARK | DOM bio / PERF | no | no | bio | yes (Session-as-home, 07-06A) | PARK |
| S62 | BroadcastView | `S/BroadcastView.swift` | **none** | PARK | DOM broadcast | no | no | broadcast | yes | PARK |
| S63 | ProUnlockView | `S/ProUnlockView.swift` | **none** | PARK | WS commerce | no | yes | — | yes (v1.1 repurpose) | PARK |
| S64 | ImmersiveStageView (+ ADMStreamStatusLine) | `S/ImmersiveStageView.swift`, `S/NetworkActivityDot.swift` | **none** | PARK | DOM space | no | no | space | no | PARK |
| S65 | moodPadsSection (MoodXYPad leaves) | ESV, `S/MoodPads.swift` | **none** (section unreferenced) | PARK | DEV / DOM visual | no | no | music | yes (founder-removed) | PARK |
| S66 | sessionEntryCard · liveNarrationBanner | ESV | **none** (`presentSession` never passed; banner unreferenced) | PARK | — | no | no | — | yes | PARK |

The Watch app (`Sources/EchoelmusicWatch`) is **not counted**: it is compiled and not embedded
(`project.yml` keeps `# - target: EchoelmusicWatch` commented out), and it reads its own device's
App Group store, which carries nothing from the phone. ID S56 is unused (the nested
`.fileImporter` it once tracked is part of S40).

**Counts — recomputed by parsing the C1 rows above, 65 surfaces:**

| Class | n | Rows |
|---|---|---|
| WORKSTATION | 29 | S01–S07, S11, S14, S15, S20, S22–S24, S29, S30, S32, S38–S41, S43–S45, S48–S52 |
| DEVICE | 10 | S25–S28, S31, S34, S42, S46, S53, S54 |
| DOMAIN TOOL | 13 | S08–S10, S12, S16, S17, S19, S33, S35–S37, S47, S55 |
| PERFORMANCE | 3 | S13, S18, S21 |
| LEGACY / PARK | 10 | S57–S66 |

| Disposition | n | Rows |
|---|---|---|
| KEEP | 27 | S01–S04, S06, S08–S12, S15–S19, S29, S30, S36, S37, S43, S44, S48, S50, S52–S55 |
| MOVE INTO WORKSTATION | 4 | S14, S22, S23, S45 |
| MOVE INTO DEVICE | 7 | S25–S28, S31, S34, S42 |
| MOVE INTO DOMAIN TOOL | 3 | S33, S35, S47 |
| PERFORMANCE ONLY | 1 | S13 |
| PARK | 10 | S57–S66 |
| **NEEDS W2 DECISION** | **13** | S05, S07, S20, S21, S24, S32, S38–S41, S46, S49, S51 |

Of the 10 LEGACY / PARK rows, three are **legacy** (superseded code with no recovery intent:
S61 Session-as-home, S65 mood pads, S66 unreferenced ESV sections) and seven are **parked**
capabilities (S57–S60, S62–S64). None is to be deleted — S58, S61, S62 and S64 are the ONLY
writers of something (§F14).

### C2 — data, hot state, realtime, modals

| ID | (6) Reads | (7) Writes | (8) ONLY writer of | (9) Fast/live | (10) Realtime-sensitive | (11) Modal |
|---|---|---|---|---|---|---|
| S01 | LaunchGuard, `hasCompletedOnboarding` | constructs 58 engines/stores; startup `.task` builds the audio graph; `applyRouting`; OSC-in dispatch writes genre/key/scale/visualStyle/lockedBPM, artNet/sACN blackout | engine lifetimes; sender start/stop via `applyRouting` | — | audio graph, all senders, transport wiring | — |
| S02 | crash-log export | `LaunchGuard.reset` | — | — | — | NavigationStack, ShareLink |
| S03 | — | `hasCompletedOnboarding` | `hasCompletedOnboarding`. The safety acknowledgement is `@State` only and NOT persisted | — | — | page TabView |
| S04 | `cameraRPPG.isRunning` (cold) | `visual.floating.visible`, floating size (instrument-home seed) | — | none in body | — | openURL only |
| S05 | SessionContext | `@AppStorage` genre · rootIndex · scale · toneSystemID · lockBPM · lockedBPM · noteNaming; `session.a4Hz`; posts `.echoelCompositionEdited` | `noteNaming` (UI) | `transport.tempo` in the leaf `SessionNamePreviewLeaf` (glide rate) | none directly; the studio retunes and recomposes on the notification | 5 `.menu` Pickers |
| S06 | `transport.position`, `isPlaying`, loopBars | — | — | **~10 Hz playhead** (leaf, correct) | — | — |
| S07 | `bus.instrumentRunning`, `transport.isPlaying` | `pattern.play(cause: .transportButton)` / `stop`, `pianoRoll.requestPlaybackOnlyStop()` | playback-only stop producer | — | **PatternEngine transport** | — |
| S08 | `bus.freshBio`, rPPG waveform/BPM/lock, Polar state | posts chrome door "bio", `.echoelSelectBioSource` | — | **10 Hz bio** (leaf) | — (the studio starts the sources) | contextMenu |
| S09 | `ExternalStageBridge.isConnected`; bio/musical frames in a 20 Hz TimelineView while running | — (its button toggles S12) | — | **20 Hz** TimelineView (leaf) | — | — |
| S10 | `SignalRouter.graph`, `bus.freshMusical` | posts "routing" | — | TimelineView ≤ flash rate (leaf) | — | — |
| S11 | `guideVisible` | `guideVisible` | — (co-written by the Export panel toggle) | — | — | overlay |
| S12 | ~45 `@AppStorage` keys (visual, weather mix, touch, field arp, key/scale/genre/loudness), WeatherProvider, SessionContext | floating size/visible, visualStyle/StyleB/Blend (look scrub), touchShowGrid, `ExternalStageBridge.setSky` | — | MetalBioView per frame (renderer, not body); transport only inside closures | **renderer lifetime**; must stay mounted for the Field arp's CADisplayLink | `.sheet(item:)` ShareSheet (WAV) |
| S13 | key/scale, touch settings, transport (inside a closure at touch time) | notes on the touch synth; MIDI out notes | touch-surface notes | touch rate | **synth noteOn/Off, MIDI out** | UIKit layer |
| S14 | engine, exporter state | `audioEngine.retroCapture` start/stop, `singleExport` WAV | the visual-window WAV path (second export path beside S22) | — | **RetroCapture tap, export render** | ShareSheet via S12 |
| S15 | `transport.position` (gated on visible) | — | — | playhead (leaf) | — | — |
| S16 | output samples (20–30 Hz), `truePeak`, `cameraRPPG.rrWindowMs`, SessionContext, `noteNaming` | `visual.analysisMeter`; `claimDetailedMetering(.scope)` | `visual.analysisMeter` | **20–30 Hz** TimelineViews (leaves) | turns on R128 detail DSP on the engine | — |
| S17 | output samples, master levels, `bus.usableBio` | — | — | Canvas/TimelineView (leaf) | — | — |
| S18 | hint flags | `onboard.instrumentHintShows`, `instrumentHintSeen` | `onboard.instrumentHintShows` | — | — | overlay |
| S19 | `ExternalStageBridge` (bus, governor, synth, sky), 13 visual keys + weather mix | — | — | renderer | renderer | — (non-interactive window) |
| S20 | everything in the environment | `activeMenu`; hosts every panel | navigation state (`activeMenu`, not persisted) | none in body (guard `TheMenuHostReadsNoHotStateTests`) | through its methods: see S21, S25–S39 | 11 on the chain + 1 nested (§E) |
| S21 | `running`, `hasComposed` | `running` → `bus.setInstrumentRunning`; `synth.bioModulationEnabled`; `generate`; `startEvolving`; `startBioSource` (camera/Polar/demo); weather fetch; `stopEverything` | **session run state** (`running` is view `@State`) | — | **generator, transport play/stop, bio publishers, voices panic** | — |
| S22 | exporter, pattern, loopBars | `exportWav`, `keepLastLoop`, `exportMIDI`, Save dialog | — | — | **offline/recent render via `audioEngine`** | alert, ShareSheet |
| S23 | projects | `showOpen`, `showLiveColabo`, `showLearn` | — | — | — | 3 sheets |
| S24 | rPPG displayBPM, `transport.tempo`, `bus.usableBio` (1 s) | `studio.lockBPM`/`lockedBPM`; `pattern.glideTempo(source: .user)` / `setTempo` | — (ESV and OSC-in also write both keys) | tempo glide ~20 Hz (leaf) | **PatternEngine tempo** | — |
| S25 | `currentPatch` (`@State`), PatchStore, style, tuning, `session.a4Hz`, sub-bass params | `currentPatch` → `applySoundLive` → `synth.apply` + touch sync; `studio.articulation`; `studio.presetIndex`; sub-bass params; PatchStore save/delete/favourite; `resetTuningToStandard` (tuningID, A4, `pianoRoll.musicalA4Hz`) | `studio.presetIndex`, `studio.articulation`; the only PatchStore UI writer | leaves `BodyShapesThisSoundLine`, S51 | **synth params on every knob change** | "Save sound" alert (S42) |
| S26 | `studio.fxCharacter`, `delaySync` (`@State`), tempo, FX chains, mixer level, `pianoRoll.notes` | `fxCharacter.apply` on synth + touch chains; `delaySync`; `chain.delay*` | `studio.fxCharacter` (besides `open`) | — | **FX chain params** | opens S27 |
| S27 | FXPresetStore, FXBioModulator, tempo (leaf), `bus.latestBio` (leaf) | every EchoelFXChain param (fanned to mirror chains); FX master gate; `modulator.routes` (in memory only); FXPresetStore save/rename/favourite | **FXPresetStore** (constructed in this view); `FXBioModulator.routes`; the only production `setFXEnabled` caller | 10 Hz bio, modulator contributions (leaves) | **FX chain on live voices** | own NavigationStack, 2 alerts, `.searchable` |
| S28 | MixerStore bass/pad, TrackFXStore, touch level, metronome | MixerStore (persisted), `subBass.mixLevel`, `laneVoiceRack.setBassMixLevel`, bus inserts on subBass/laneVoiceRack/bass/synth/lead, `touch.level`, metronome enabled/level; rebalance → `pianoRoll.rebakeArrangement` | MixerStore, TrackFXStore UI | — | **voice bus inserts and levels** | — |
| S29 | loudnessTarget, masterCharacter | `studio.loudnessTarget`; `studio.masterCharacter` → `autoMixChain.applyPersistedPreset`; `resetMastering`; `AudioConfiguration.setLatencyMode`; panic fan-out; `showRouting` | `studio.masterCharacter` (UI) | 60 Hz meters confined to S30 | **master chain, latency mode, panic across all voices + MIDI out** | opens S45 |
| S30 | `masterLevel` L/R, LUFS short/integrated, true peak, LRA | `claimDetailedMetering(.masterPanel)` / release; `resetMastering`; `audioEngine.masterVolume` | — | **60 Hz meters** (leaf) | R128 DSP on/off, master volume | — |
| S31 | `mood` (`@State`), MoodPresetStore (`@State`!), loopBars, weather | `mood` (persisted by root `.onChange` into `studio.mood`); rhythm/pad/variation keys; MoodPresetStore; weather, location | `studio.mood`, `studio.moodVariation`, `studio.bassRhythm`, `studio.padRhythm`, pad gate/accent/evolve; **MoodPresetStore** (owned as view `@State`) | — | **recompose** (`recomposeIfRunning` → `generate`) | "Save mood" alert (S42) |
| S32 | metronome, haptics, maze state | `lockedBPM`, `lockBPM`, `pattern.setTempo(source: .user)`; metronome settings; `haptics.isEnabled`; maze `@State`; `applyVariation` → `generate` | tap-tempo producer | — (`metronome.bpm` not read) | **PatternEngine tempo; full generate** | — |
| S33 | visual.* keys, patches, `synth.entrainment*` (cold), `mixer.lead` | visual look/preset keys, `visual.preset`, spectral donuts, window visible/size (direct `UserDefaults.set`), keep-awake | `visual.preset` | `MusicColourRowView` reads `bus.freshMusical` (leaf) | idle-timer | — |
| S34 | touch.* / fieldAutoPlay.* / fieldArp.* keys | the same keys; `touchSynth.apply`, `syncTouchSound` | — (keys shared with S12 and S19) | — | **touch synth patch** | — |
| S35 | `running`, `bio.sourceKind`, `bodyOnly` | `bio.sourceKind`; start/stop camera/Polar/demo; body-only; `bioVoice` arm; `studio.autoMode`; `healthWriter.enabled`; `showRouting` | **`bio.sourceKind`** (no other file references it) | leaves: BioStrip 10 Hz, BreathCoachStrip ~30 Hz | **bio publishers, body voice arm** | opens S45 |
| S36 | `bus.usableBio` 10 Hz, rPPG state, `transport.isPlaying` | — (opens Settings) | — | **10 Hz** (leaf) | — | 2 sheets (metric info, guide) |
| S37 | HealthWriter | `healthWriter.enabled` | the reachable Health-write consent switch | — | — | — |
| S38 | TimelineStore.document, TimelineRegionPlayer, ClipStore | `player.play(document:clips:pattern:pianoRoll:)` / `stop`; `AudioImport.addAudioTrack` / `perform`; `MIDIImport.addMIDITrack` / `perform`; `AudioWarp.setWarp`; `AudioTranspose.setPitch`; `AudioTempoCorrection.setNativeBPM`; `clipStore.adoptDetectedNativeBPM` | **the only `TimelineRegionPlayer.play(` caller; the only UI for adding lanes, import, warp, pitch, part tempo** | none in body (bounded `fileExists` probe) | **timeline transport via PatternEngine; AudioLanePlayer prime chain** | `.fileImporter` (audio/MIDI), on the leaf |
| S39 | loopBars, locationNamer, `session.artistName` | `studio.loopBars` → recompose; `session.artistName`; place; `guideVisible`; `resetSoundToDefaults` (SoundReset, `session.resetMusicalIdentity`, mixer, sub, performer signature, mood, patch, tuning, `pianoRoll.musical*`, delaySync, `BioFeedbackManager.clearSharedVitals`) | `session.artistName` (production writer) | — | **recompose; global reset of voices and session identity** | diagnostics sheet |
| S40 | ProjectStore, `session.artistName` | `projects.delete`; `projects.importProject` (JSON); `open(p)`: autosave, then writes style/key/scale/fx/loopBars/patch/preset/mood/tuning/lockedBPM, `session.adopt`, `pianoRoll.load`, `pattern.load` + `setTempo` | the only project-open path | — | **pattern load + tempo, voices retune** | sheet + nested `.fileImporter` (JSON), ShareLink |
| S41 | `currentProject()` | `projects.save` | project save (also `autosaveTake` on scene departure) | — | — | alert |
| S42 | name field | PatchStore / MoodPresetStore save-as | — | — | — | 2 alerts |
| S43 | crash log | `diagnostics = nil` | — | — | — | sheet |
| S44 | url | — | — | — | — | sheet |
| S45 | SignalRouter, OSC/ADM/Art-Net/sACN senders, OSCReceiver | `router.toggle` / suggestions / clear (→ `applyRouting` starts/stops senders, `midiOut.enabled`, thru); `midi.out.mpe` / `.expression` / `.ump2`; `midi.networkSession`; `net.osc.in.enabled`, allow list, port; sender host/port/universe; `net.osc.clinicalDetail` | **SignalRouter routes (= every sender's enable flag); MIDI-out prefs; network targets; OSC-in opt-in** | leaves `NetworkOutputHeader` (~30 Hz sent stamp), `OSCInputStatusLine` | **all network senders, MIDI out/thru, broadcast lifecycle** (indirect) | sheet with own NavigationStack + push |
| S46 | ModulationEngine.matrix | `matrix.routes` append/remove, `engine.save()` | **the only production `ModRoute(` constructor and matrix writer** | — | **modulation onto synth params and tempo** | — |
| S47 | Art-Net / sACN | grandMaster, blackout, DMX resolution, fixture count/spacing (to both senders) | grandMaster (blackout also written by the OSC cue in S01) | — | **DMX output** | — |
| S48 | CoreMIDI BLE | BLE MIDI pairing | — | — | MIDI input set | pushed controller |
| S49 | MultipeerSession, ProjectStore, `EngineBus.usableBio` (1 s leaf) | `start`/`stop`, `share(project:)`, invite/respond, `sendBio` loop; `onLoadShared` → `open()` **replaces the current session**; `projects.save` | the only UI user of MultipeerSession | 1 s bio (leaf) | via `open()` | sheet with own NavigationStack |
| S50 | LearnLibrary, AnnouncementCenter | `announcements.enabled` | `echoel.announcements.enabled` | — | — | NavigationStack + detail sheet |
| S51 | AutomationPlayer lanes (own, clip, timeline), `bus.usableBio` | `player.enabled` (persisted) | **`AutomationPlayer.enabled`** | leaf | **whether automation drives synth, master and tempo** | — |
| S52 | `audioEngine.degraded`, `lastAudioError` | `audioEngine.start()` (Retry) | — | — | **engine start** | — |
| S53 | `StudioCaption.text` (per generate) | `studio.liveNarration` | — | — | — | — |
| S54 | AUParameterTree | parameter values 0–7 | host-facing parameters | host automation | AU render (separate process) | — |
| S55 | App Group shared vitals | — | — | 5 min timeline | — | — |
| S57 | BreathPacer, SessionRecorder, `bus.freshBio` | pacer; `recorder.start` / `stop(name:)` (persists `bioSessions.v1`) | SessionRecorder (unreachable) | bio | pacer | hold-warning sheet |
| S58 | rPPG, bus, synth | camera start/stop; `synth.bioModulationEnabled`; `bioMappingHarmonic`, `entrainmentEnabled`, `entrainmentManualBand` | **the three PolySynthVoice features, which are therefore unreachable** | 10 Hz | bio publisher | fullScreenCover → S59 |
| S59 | BreathPacer | pacer start/stop | — | pacer | — | sheet |
| S60 | rPPG waveform/lock | — | — | 10 Hz | — | — |
| S61 | SessionEngine, rPPG | `session.start(subscribing:)` / `stop`; camera | the only `SessionEngine.start` caller. The engine is attached to the audio graph at every launch and cannot start | — | audio source node (silent) | — |
| S62 | BroadcastPublisher | url, streamKey, transport, start/stop | the only URL/stream-key UI (so `rtmp.out` routes are unconfigurable) | — | — | NavigationStack |
| S63 | EchoelStore | purchase / restore | — | — | — | NavigationStack, alert |
| S64 | TimelineStore lanes, SpatialSceneStore, ADMOSCSender | `spatial.rebuild`, `setPosition`, `admOSC.streamsScene` | **SpatialSceneStore positions; `streamsScene`** (so 0 reachable writers) | — | **ADM-OSC object stream** | — |
| S65 | mood | `mood.sound.*`, `mood.visual.*`, visual hue/motion/intensity | — | — | recompose | — |
| S66 | — | — | — | — | — | — |

**Shared primitives, not counted as surfaces:**
- `EchoelValueField` has about 54 uses in ESV. It presents `EchoelNumberPad` as a sheet from its
  own leaf, so that sheet is not on the ESV chain.
- `EchoelPanel` and `EchoelSheetPanelModifier` are also shared primitives.
- These are the device-UI toolkit W3 would reuse. The AUv3 view does not use any of them (S54).

---

## D. Current Echoel experience decomposition

This section tests the hypothesis "the current Echoel experience becomes a first-class native
Echoel device" against the code, surface by surface.

**ECHOEL NATIVE DEVICE** (the instrument that would sit on a track):
- **Synthesis:** soundPanel (S25), Field voice (S34), Save sound (S42), and the preset/patch
  library (PatchStore).
- **Composer:** moodPanel (S31) with its rhythm, pad-shape and variation rows; the variations
  maze from S32; genre (the composer-input half of S05); loop length (from S39); narration (S53).
- **Bio/motion modulation:** body-voice arm and Auto mode (from S35); `modulationSection` synth
  targets (S46); FXBioModulator routes (inside S27).
  - ⚠️ Motion has no producer (`ModulationMatrix.hasProducer(.motion) == false`), so it is
    listed as a slot, not a capability.
- **Device FX:** effectsPanel (S26), EchoelFXView (S27), FXPresetStore.
- **Sound character:** FX character, master-independent articulation, sub-bass shaping (S25/S26).
- **Instrument-local mix:** mixerPanel (S28). It mixes bass · pad · field voices and their bus
  inserts, all inside the Echoel device. **It is not a track mixer.**
- **Instrument-local visual response:** the part of S33 that is a per-take colour/brightness
  response to the device's own music (`MusicColourRowView`, `bus.freshMusical`).
- **Instrument-local parameters:** everything S46's `ParameterApplyRouter` registry can reach.
- **Play surface:** TouchInstrumentView (S13) plays the device's own touch voice. It is
  PERFORMANCE by class, and its sound is the device's.

**WORKSTATION:**
- **Project/session:** open (S40), save (S41), collaboration (S49), autosave, artist/place (S39).
- **Tracks and arrangement:** WorkstationView (S38).
- **Transport:** play/stop (S07), position (S06, S15), tempo field (S24), tap tempo and
  metronome (S32).
- **Global mixer/master:** masterPanel (S29), loudness (S30), latency, panic.
- **Media import:** Workstation import. The JSON project import sits in S40.
- **Export:** WAV, MIDI, keep-last (S22), the visual-window WAV path (S14), share (S44).
- **Global routing:** Patchbay graph, network and MIDI I/O (S45, S48).
- **Automation ownership:** AutomationStatusStrip (S51), and the timeline's automation lanes,
  which have no editor.
- **System:** App root, safe mode, onboarding, diagnostics, degraded-audio row, guide, Learn.

**DOMAIN TOOLS:**
- **Full visual composition:** FloatingVisualWindow (S12), the look/preset half of visualPanel
  (S33), analysis meters (S16), spectral donuts (S17), external display (S19).
- **Lighting:** Patchbay `lichtSection` (S47), header Lux tile (S10), `LightingStore`. It has no
  UI writer; the only writer is the `lighting.look.intensity` parameter binding.
- **Spatial scene:** ImmersiveStageView (S64, parked). `SpatialSceneStore` has **0 reachable UI
  writers**.
- **Bio source:** bioPanel source choice (S35), BioStrip (S36), Health consent (S37), pulse pill
  (S08).
- **Broadcast:** BroadcastView (S62, parked; publisher unlinked).
- **Content/assets:** Learn (S50) and help sheets. There is no asset browser; `MediaLibrary` is
  static and has no UI.
- **Video:** there is no surface.

**NEEDS W2 DECISION** (ownership depends on the Session):
- **S05 CompositionHeaderStrip.** Key, scale and A4 are session-global, while genre is a composer
  input. Today one strip writes both, into three key homes.
- **S07, S24, S32 (transport and tempo).** Is tempo a Session property (a `TempoMap` on the
  Session), or a property of the Echoel device in Flow mode, where it follows the body? Today one
  PatternEngine carries both meanings.
- **S20 EchoelStudioView host.** Is the chip plate the device's editor, the workstation's shell,
  or split?
- **S21 Start.** It starts the bio session, the generator and the transport at once. Is Start a
  device action or a Session action?
- **S38 WorkstationView.** Which song model does it project: the timeline only, or a Session that
  also owns scenes?
- **S39 / S40 / S41 (loop length, project open/save).** `Project` is a flattened copy that does
  not carry timeline, clips, arrangement or automation.
- **S46 modulationSection.** Its tempo destination is Session-level, its synth targets are
  device-level.
- **S49 LiveColaboView.** It shares and replaces a `Project`, so it inherits the S40 answer.
- **S51 AutomationStatusStrip.** Which automation home is canonical?

**Verdict on the hypothesis.** It holds for the device half, which is well bounded:
- every device surface already writes through the voices, the FX chains, PatchStore,
  MoodPresetStore and `@AppStorage` composer keys;
- none of them writes TimelineStore, ClipStore or ProjectStore directly.

It does **not** hold for the host view. `EchoelStudioView` is both the device's editor and the
workstation's shell, and its methods (`generate`, `open`, `stopEverything`,
`resetSoundToDefaults`) cross the boundary in single calls. W3 needs to split the methods before
it can split the views.

---

## E. Modal / navigation inventory

Measured with
`git grep -nE '^\s*\.(sheet|fullScreenCover|alert|confirmationDialog|popover|fileImporter|fileExporter)\(' -- Sources/Echoelmusic/Studio/EchoelStudioView.swift`.
It returns 12 file-wide: 11 on the root chain plus the `.fileImporter` nested in `openSheet`.
This agrees with `python3 scripts/doctor.py --section D` ("12"). The ceiling is 14.
⚠️ One inspection pass reported "22 modal modifiers" for this file. That was wrong, and the grep
above is the measurement.

### E1 — `EchoelStudioView` chain

| # | Modifier | Content | Flag setter | Functionality should become persistent workstation space? |
|---|---|---|---|---|
| 1 | `.sheet(isPresented: $showOpen)` | openSheet (+ nested JSON `.fileImporter`) | quickDoorRow "Open" | **Yes**: a project browser is workstation space |
| 2 | `.sheet(item: $share)` | ShareSheet | export paths | no (system share is transient) |
| 3 | `.sheet(item: $diagnostics)` | crash report | Export panel, post-crash | no |
| 4 | `.sheet(isPresented: $showAllFX)` | EchoelFXView | effectsPanel | **Yes**: a device editor wants a persistent device view, not a modal |
| 5 | `.sheet(isPresented: $showRouting)` | PatchbayView | 3 doors (Master, Bio, header tile) | **Yes**: routing/I-O is the most-doored modal; it is workstation space |
| 6 | `.sheet(isPresented: $showLearn)` | LearnView | quickDoorRow | no (help) |
| 7 | `.fullScreenCover(isPresented: $showMeditation)` | MeditationView | **none**, setterless | free headroom (doctor C) |
| 8 | `.sheet(isPresented: $showLiveColabo)` (Multipeer builds) | LiveColaboView | quickDoorRow | **Yes**: collaboration is session-level |
| 9 | `.alert("Save project")` | name field | quickActionRow | **Yes**: part of a project surface |
| 10 | `.alert("Save mood")` | name field | moodPanel | no (device preset save) |
| 11 | `.alert("Save sound")` | name field | soundPanel | no (device preset save) |
| (12) | `.fileImporter` inside openSheet | Echoel project JSON → ProjectStore | toolbar Import | belongs with #1 |

### E2 — modals outside the chain (they do not count against the ESV ceiling)

| Where | Modal |
|---|---|
| `WorkstationView` | `.fileImporter` (audio/MIDI). It sits on the leaf on purpose: an ancestor importer shadowed it (#W1) |
| `FloatingVisualWindow` | `.sheet(item:)` ShareSheet, guarded against presenting while hidden |
| `EchoelFXView` | own NavigationStack; alerts "Save preset" and "Rename preset"; `.searchable` |
| `PatchbayView` | own NavigationStack; NavigationLink → BLE MIDI pairing |
| `BioStripView` | 2 sheets (metric info, metrics guide) |
| `LearnView` | NavigationStack + detail sheet |
| `LiveColaboView` | NavigationStack |
| `EchoelValueField` | number-pad sheet (one per field instance, leaf) |
| `SafeModeView` | NavigationStack, ShareLink |
| `OnboardingView` | page TabView |
| Doorless | MeditationView sheet · BreathGuideView sheet · BioSourceView fullScreenCover · BroadcastView / ProUnlockView NavigationStack + alert |

- **Custom overlays:** `GuideOverlay` (root), `InstrumentHintOverlay` and `TouchInstrumentView`
  (inside the visual window), and the always-mounted `FloatingVisualWindow` itself, which is a
  custom floating layer rather than a modal. The remaining `.overlay` hits in `Studio/` are
  decorative strokes.
- **Navigation pushes:** exactly one, Patchbay → BLE MIDI pairing. `NavigationStack` appears in 9
  files, each inside a sheet or an alternate root. None is on the main path.
- **Not used anywhere:** `.popover`, `.confirmationDialog`, `.fileExporter`, `.inspector`.

**Findings:**
1. Four workstation functions live in modals on the budget-limited chain: routing (#5), project
   (#1, #9, #12), collaboration (#8) and the FX device editor (#4). Moving them into persistent
   space would **free** chain slots. This is an observation, not a plan.
2. The Workstation chip proved the zero-modifier route (a chip plate) for a workstation surface.
   PatchbayView is the most obvious next candidate by door count. This is not a decision.
3. The header "routing" door and two panel buttons reach the same sheet. That makes three doors
   for one modal, and the string protocol is the only thing tying them together.

---

## F. State-ownership risks

No repair is made here.

| # | Risk | Evidence | Why it matters for W2/W3 |
|---|---|---|---|
| F1 | **`@AppStorage` is persistent truth spread over views** | 99 distinct bindings, 54 declared in >1 place (`git grep -hoE '@AppStorage\([^,)]+' -- 'Sources/Echoelmusic/**/*.swift' \| sort \| uniq -c \| awk '$1>1' \| wc -l`). genre/loopBars/autoMode/loudnessTarget/noteNaming ×4; the visual keys ×3 (ESV, FloatingVisualWindow, ExternalDisplayScene) | A key read by the shell, the device editor and the domain tool at once has no owner to move. Every split has to take its readers along |
| F2 | **Persistence stores owned as view `@State`** | `MoodPresetStore` is `@State` in ESV; `FXPresetStore` is constructed in EchoelFXView | A device-preset library that lives and dies with a view cannot be shared by a second device instance or a track |
| F3 | **Session truth in view `@State`, not persisted** | ESV `currentPatch` (persisted only via `presetIndex` or a project save), `delaySync`, `running`, `bodyOnly`, `lastRawTake`, `evolution`, `performerSignature` (written to UserDefaults from the view), `moodPresetID` | Device state that is neither a store nor a document; W3's device contract has to name it |
| F4 | **Three homes for key/scale** | SessionContext (`echoel.keyRoot` / `keyScale`, written by `adopt`); `@AppStorage studio.rootIndex` / `studio.scale` (header strip, ESV, OSC-in); `Project` fields | Selected key vs composed key vs saved key. The FINAL_REPORT found "no second truth" for key/A4 by role; the three homes are still three |
| F5 | **Tempo has three writers and no document home** | PatternEngine tempo is written from ESV (tap, open, generate glide), BodyTempoField, OSC-in (remote control) and TimelineRegionPlayer preflight; `lockedBPM` `@AppStorage` is written by the header, the studio and the tempo field; `TimelineDocument` has no tempo field; `Project.bpm` is a scalar | The W2 Session needs a tempo owner (the `TempoMap` of #1416) |
| F6 | **Four song-like roots, one of them writerless** | `Project` (ProjectStore), `TimelineDocument`, `Arrangement` (**0 writers**: `git grep -n "\.addSection(\|\.setLength(\|\.bootstrapIfNeeded(" -- Sources \| grep -v ': *//'` → 0), `ClipStore`. `open(_:)` restores the Project and does not touch timeline, clips, arrangement or automation | Opening a project changes the instrument and leaves the arrangement as it was. A user can load "a song" and hear two |
| F7 | **Three automation homes** | `AutomationState.lanes` (file `automation`, no writer); `TimelineDocument.automation` (played via TimelineRegionPlayer → `pianoRoll.setTimelineAutomation`); `Clip.automation` (clip-relative) | S51 toggles a player that merges them; no surface edits any |
| F8 | **Direct audio-engine ownership from views** | S14 (RetroCapture start/stop, SingleExport), S22 (export render), S29 (master chain preset, latency mode, reset), S30 (R128 claim), S52 (`audioEngine.start()`), S16 (metering claim) | Workstation export lives in two places (S14, S22) |
| F9 | **View-owned transport** | S07 (play/stop), S24/S32 (setTempo, glide), S38 (region play), S21 (`generate` → `pattern.play(cause: .generate)`), S40 (`pattern.load` + `setTempo`) | Five views start or retime the one clock; `PatternEngine` is the single relay (invariant 3 holds), and its callers are views |
| F10 | **Lighting and network ownership** | Routes are the senders' enable flags, written only by Patchbay; `applyRouting` in the App starts and stops senders; blackout has two writers (Patchbay, the OSC cue); `LightingStore` has no UI writer and is not persisted | Workstation routing and the lighting domain tool share one sheet |
| F11 | **Direct persistence writes from views** | `openFullscreenVisual` (`UserDefaults.set`), `restorePreTakeVisual`, `performerSignature`, MoodPads `UserDefaults` | Bypasses `@AppStorage` observation, so co-readers update only on their next body |
| F12 | **Duplicated selected-track / session truth** | There is **no selected-track state anywhere** (no surface selects a track; WorkstationView lists lanes without selection). The session name is derived (`session.sessionName` + `saveName`); `running` is mirrored into `bus.setInstrumentRunning` | Selection is absent rather than duplicated. W3/W4 will introduce it, and it needs one owner from the start |
| F13 | **Engines as `@State` of the `@main` App** | 58 `@State` engines/stores in `EchoelmusicApp` | Correct for lifetime; it means the App struct is the de facto composition root. A W3 device instance model cannot instantiate a second Echoel device from there |
| F14 | **Unreachable sole writers** | S58 is the only writer of `bioMappingHarmonic` / `entrainmentEnabled` / `entrainmentManualBand`; S64 is the only writer of SpatialSceneStore positions; S61 is the only `SessionEngine.start`; S62 is the only broadcast URL/key UI; S57 is the only SessionRecorder writer | Parked, but deleting any of them would delete the only writer (CLAUDE.md law 3) |

---

## G. Realtime / UI risks

No optimisation is made here.

| # | Hot path | Where | State today |
|---|---|---|---|
| G1 | 10 Hz bio (rPPG) | S08, S35/S36, S58/S60, S09 (20 Hz TimelineView), S27 leaf | Confined to leaves; guard `TheMenuHostReadsNoHotStateTests`. `WorkspaceView` reads only `isRunning` |
| G2 | 60 Hz meters | S30, S16/S17 | Confined to leaves; `MasterVolumeField` exists because an inline read once tore down the key picker |
| G3 | Playhead ~10 Hz | S06, S15; S13 reads it inside a closure only | Leaves / closures |
| G4 | Tempo glide ~20 Hz | S24 leaf, S05 `SessionNamePreviewLeaf` | Leaves. ⚠️ S05's leaf follows `transport.tempo` during a glide. It is correct only while it stays a leaf |
| G5 | `AutomationPlayer.applyStep` → `masterVolume` per step | S30 | Read only in the leaf |
| G6 | View → synth params per knob | S25 (`applySoundLive` → `synth.apply`), S26/S27 (FX chain), S28 (bus inserts), S34 (touch patch) | Main-thread writes into voices that mirror into `nonisolated(unsafe)` render fields. W3 must keep the mirror pattern when device parameters move behind a device contract |
| G7 | View → generator / clock | S21, S31 (`recomposeIfRunning`), S32 (`applyVariation`, `setTempo`), S39 (loop bars), S40 (`pattern.load`) | Full `generate` from view actions; `loadAtBoundary` protects the boundary |
| G8 | View → note on/off | S13 (touch notes + MIDI out, plus the Field arp via CADisplayLink in S12) | This is why `FloatingVisualWindow` can never unmount (hidden = opacity). A performance surface's lifetime is tied to a domain tool's window |
| G9 | Renderer lifetime | S12/S19 (`MetalBioView`, 60 fps pinned) | Hidden window renders `Color.clear`; the external display takes the renderer |
| G10 | Always-evaluated panel router | `dropdownContent` is evaluated in the root body permanently (`echoelPanelForceOpen`) | Any hot read added to any panel lands in the root body: the 10.76.41/50 freeze. Every new panel inherits this risk |
| G11 | Audio-engine control from UI | S52 Retry → `audioEngine.start()`; S29 latency mode; S30/S16 metering claims | Refcounted claims (`claimDetailedMetering`); latency mode persists |
| G12 | Network egress from UI state | S45 routes → `applyRouting`; S47 DMX; S64 `streamsScene` (parked) | Egress starts from a persisted route, not from a view lifetime. Good for a workstation split |

---

## H. Historical reusable UX findings

Classes as asked: REUSE / PORT UX IDEA / REBUILD / DO NOT RESTORE. Sources are
`docs/dev/HISTORY_ARCHIVE.md` section IDs; no unbounded excavation.

| Archive | What it was | Class | What is worth keeping |
|---|---|---|---|
| D1 Arrangement (`ArrangeTimelineView` et al.) | Timeline views, deleted with #121 | **REUSE** WorkstationView + TimelineStore; **PORT UX IDEA** for editing | Lane headers with mute/solo/arm/level/pan; tick-snapped move/trim that stays tempo-safe. The model already has an editing API with zero callers: `moveRegion`, `trimRegionStart`, split/merge |
| D2 Session / clip launcher (`ClipView`, `ClipLauncherGrid`) | Slot grids; no quantised launch ever existed | **REBUILD** | Slot index = identity; launch at the next bar (`PatternEngine.loadAtBoundary` exists); per-clip automation |
| D3 Piano roll (3 generations) | Deleted #475 ("Pianoroll soll raus") | **REBUILD** surface, REUSE the `Roll*` math | Hit-testing, fit-to-content zoom, note ops, stamp chord/arp, unit-to-period grid (#470) |
| D4 Automation editors (`TimelineAutomationRow` et al.) | Drawn curves; deleted #473 | **REBUILD** | Target picker limited to the per-track key-path namespace; per-segment curvature; clip vs song automation kept apart. TimelineStore's automation editing API has zero callers |
| D6 Undo | Archive says "none exists". There is region undo/redo in TimelineStore (no UI caller) and a PianoRollModel undo | **REUSE** (model) | Region undo/redo already in the timeline model. ⚠️ The archive entry is imprecise |
| D7 Browser / SampleBrowserView | Never had a working door | **PORT UX IDEA** | Audition before import; a left-column browser over `MediaLibrary` folders |
| D7/C7 ChannelRackView | Per-drum mixer for silent channels | **DO NOT RESTORE** | Only the mute/solo gate semantics (tests exist) |
| C7 Mixer surfaces (4 generations) | ProMixEngine → MixerView → EchoelMixView → ChannelRack | **REBUILD** on `TimelineLane` | A channel strip per lane. `TimelineLane` already carries level/pan/mute/solo/arm. ⚠️ Not the current `mixerPanel`, which is device-internal (S28) |
| D10 App shells (13-workspace hub, StudioRoot tabs, 6-surface bar, Tools grid, SurfaceSwitcher, Session-as-home) | Each lived a day to ~6 weeks | **DO NOT RESTORE** any shell | One root with replaceable leaf panels; the sheet-chain and hot-read laws; "check sole writers before removing a surface" |
| — `PatchEditorView` | Near-duplicate of soundPanel, deleted #132 | **DO NOT RESTORE** | Superseded by `soundPanel` + preset bar |
| F1 Video editor | Never shipped working | **REBUILD** (AVFoundation) | Video as a clip kind on timeline lanes |
| F4 VisualForge / EchoelVis / VJ compositor | EchoelVis modes worked; quantum shaders are overclaim | **PORT UX IDEA** (mode picker, layer stack); **DO NOT RESTORE** quantum/photonics | Layered look composition for the visual domain tool |
| F5 MetalBioView + floating window + meters | Live | **REUSE** | Already current (S12, S16, S17) |
| G4 Stage / external display / keystone / cues | `EchoelStageEngine` had keystone + cues | **PORT UX IDEA** | 4-corner keystone and a cue list for S19 |
| H2 ADM-OSC + spatial render cores | Control half live; view intact but doorless | **REUSE** (`ImmersiveStageView`) | Per-lane object position rebuilt from timeline lanes; binaural monitor as next slice |
| I7 Breathing / Session / Meditation / BreathGuide | Removed as home, not as capability | **REUSE** (later) | The ≤0.2 Hz flash law; the contraindication confirmation; the session summary |

---

## I. W2 dependencies

Marked **NEEDS W2 DECISION** and **not decided here:** TimelineDocument, Arrangement, ClipStore,
PatternEngine, Transport, automation, and project/session.

| Model | Owner type · construction | Persists | UI writers today | Readers / players | Open two-truth issue |
|---|---|---|---|---|---|
| TimelineDocument | `TimelineStore` · `EchoelmusicApp` | App Group `Timeline/timeline` (debounced) | ESV (composer-region sync, healing), WorkstationView (import, warp, pitch, tracks) | TimelineRegionPlayer, AudioLanePlayer, ImmersiveStageView (parked) | Automation home #2; no tempo field; editing + undo API with no caller |
| Arrangement | `ArrangementStore` · `EchoelmusicApp` | App Group `Arrangement/song` | **none** | ArrangementPlayer only | A second song model with zero writers; the bridge `bootstrapIfNeeded` has zero callers |
| ClipStore | `ClipStore` · `EchoelmusicApp` | App Group `Clips/clips` | ESV (composer melody), WorkstationView (tempo, detection, import helpers) | TimelineRegionPlayer, ArrangementPlayer | Clip automation (home #3); `ClipStore.setClipAutomation(id:lanes:)` has no caller (the `setClipAutomation` hits elsewhere are `PianoRollModel`'s player feed) |
| PatternEngine | via `BeatPlayer` · `EchoelmusicApp` | none (live tempo entry is `studio.lockedBPM`) | ESV, WorkspaceView (PlaybackToggle), BodyTempoField | Transport relay; every player | Device clock (Flow) vs Session clock |
| Transport | `Transport` · `EchoelmusicApp` | none | none (relay only; `seek` has no production caller) | position leaves, touch surface | — |
| Automation | `AutomationPlayer` · `EchoelmusicApp` | App Group `Automation/automation` | AutomationStatusStrip (`enabled` only) | synth, master, tempo | three homes (§F7) |
| Project / session | `ProjectStore` · `EchoelmusicApp`; SessionContext | `projects.json` (App Group); SessionContext UserDefaults `echoel.*` | ESV (save/open/delete/import/autosave), LiveColaboView (save) | `open(_:)` | Flattened copy that ignores timeline/clips/arrangement/automation; the `DMMWProject` envelope (#1419) exists as importer-first |
| Scenes / clip launch | — | — | — | — | Does not exist |
| Tracks | `TimelineLane` inside TimelineDocument; `LaneVoiceRack` for voices | with the timeline | WorkstationView (add track) | players | No selected-track state (§F12) |

**What W1 hands to W2 that W2's prior art did not have:**
- the per-surface writer map for each of these models (§C2);
- the finding that the device half of the UI never writes them directly (§D);
- the observation that `open(_:)` and `generate()` are the two methods where the Session boundary
  would have to cut.

Correction to prior art, found during this census: `scratchpads/PLAN_DOCUMENT_ROOTS_2026-09-21.md`
§2.1 implies the player reads only the `automation` file. In fact `TimelineDocument.automation` is
also played, pushed through `TimelineRegionPlayer` → `pianoRoll.setTimelineAutomation` →
`AutomationPlayer.setTimelineLanes`.

---

## J. Proposed W2 questions

These are for the W2 census and the Founder decision. None is answered here.

1. **Song model.** Which of TimelineDocument / Arrangement / Project is the canonical song? Does
   `ArrangementStore` (zero writers) retire into it, or become the Scenes projection?
2. **Project envelope.** Does `open(_:)` become "open a Session", restoring timeline, clips and
   automation too, so that loading a project stops leaving the arrangement as it was (F6)?
3. **Tempo home.** Is tempo a Session `TempoMap`, with the Echoel device's Flow mode as a
   *source* into it? Or is it device-owned in Flow and Session-owned in Loop? T1–T3 stay law
   either way.
4. **Start.** When Echoel is a device on a track, what does today's Start button start: the
   device (bio source + generator), the Session transport, or both? Who owns `running`?
5. **Key/scale/A4.** One Session-level home, with the device reading it? What happens to the two
   `@AppStorage` keys and `Project` fields (F4)?
6. **Automation.** Which of the three homes is canonical, and is `AutomationStatusStrip`'s
   `enabled` a Session setting or a player setting (F7)?
7. **Scenes.** Does a Scene project the same Session as the Arrangement (master plan §7), and does
   `ClipStore` slot identity become scene identity?
8. **Tracks and selection.** Where does selected-track state live, and does the Echoel device
   occupy a track (`LaneVoiceRack`) or sit above the tracks?
9. **Composer loop length.** Is `studio.loopBars` a device parameter or a Session region length?
10. **Collaboration.** Does Live Colabo share a Session or a device preset, given that it replaces
    the current `Project` today?
11. **Modulation to tempo.** Does the `.tempo` destination of the modulation matrix belong to the
    Session (as the T1 source `.modulationRoute`) while synth destinations stay with the device?
12. **Export.** Is export (WAV, MIDI, keep-last, visual-window WAV) a Session render of the whole
    arrangement, or a device render of the current take, or both as two named actions (F8)?

---

*Maintenance:* this census is evidence dated 2026-09-24. Re-measure with the commands named
above; do not update numbers in place without re-running them.
