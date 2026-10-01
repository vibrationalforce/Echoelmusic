# Modes census + ranked queue (2026-09-26, HEAD 4884c7a47)

Read-only workflow (4 analysts + synthesis). Performance · Stream · 360/Planetarium/XR · usability/accessibility. Nothing compiled or device-run. This is the ONE queue for these domains (orchestrator addendum §9); status per item is tracked in scratchpads/EXECUTION_CHECKPOINT.md.

## Synthesis (ranked queue)

# Ranked work queue for the orchestrator (HEAD `4884c7a47`)

## Checked against the code: confirmed and refuted

**Confirmed:**
- **D1, the Workstation Stop ends the bio session.**
  - `WorkstationView.swift:773` and `:811` call `player.stop()`.
  - `TimelineRegionPlayer.stop()` calls `pattern?.stop()` (around `:731`).
  - `TransportTransition.decide` returns `.endSession` when nothing requested a pause.
  - The button's VoiceOver label says "Stop timeline", so the control does more than it says.
- **P2 keep-awake has no timeline term.** The expression at `EchoelStudioView.swift:6557`ff and the `.onChange` at `:1667` have no timeline term, and `timelinePlayer` is already in the environment (`:177`).
- **Note grid hint.** The hint is at `PartNoteEditor.swift:180`, and no test pins it (`git grep 'Touch only' -- Tests` finds 0).
- **Arrange canvas.** `ArrangeCanvasView` has only the select action (`:233`). `TrackParts.earlierStart`/`laterStart` exist in `SelectedPartBar.swift:275-283`.
- **Broadcast.** `.rtmp`/`.srt` are `.roadmap` (`SignalRouting.swift:114`), and `BroadcastView(` has 0 construction sites.
- **Clips/Scenes LOW-1 is still OPEN** (last bullet of `PLAN_CLIPS_SCENES_2026-09-26.md`).
- **Media phase.** MA4.1–MA4.6 and MA4.4c/d are all BUILT (`PLAN_MEDIA_ASSET_2026-09-26.md`). The plan defines no next MA step.
- **visionOS in `Sources/`.** It appears only in two header comments (`SPSCQueue.swift:7`, `MemoryPressureHandler.swift:8`). These are not guards, so CLAUDE.md's word "Plattform-Guards" is wrong.

**Refuted:**
- **Performance P1 said "Back to song" calls `player.stop()`.** False. `SessionLaunchView` contains no `player.stop()`; "Back to song" (`stopAllLaunched`) returns tracks on the next bar and does not stop the transport. P1 therefore covers only two call sites.
- **The Stream report's "12 modal modifiers" is misleading.** The performance report says the same. Raw `grep -c` counts comments; the measured budget is 11 on the chain plus 1 = 12, against a ceiling of 14.

## READY (ranked)

**1. `stopTimeline()`: the Workstation Stop pauses and no longer ends the bio session (D1).** Run the Council first, because it narrows the reach of the ONE-Stop law.
- **Why READY:** it repairs a usability defect on the existing front. The label says "Stop timeline", and #179/#234 (`PlaybackToggleButton`) is the same mechanism.
- **GOAL:** both `player.stop()` sites go through one private `stopTimeline()`, which calls `pianoRoll.requestPlaybackOnlyStop()` first.
- **ALLOWED FILES:** `Studio/WorkstationView.swift` plus guard `Tests/CISmoke/TheTimelineStopKeepsThePulseTests.swift`.
- **MUST PRESERVE:**
  - `TransportTransition.decide` is unchanged.
  - The labelled start/stop in `transportLine1` still ends the session.
  - The request is consumed exactly once (`consumePlaybackOnlyStopRequest`).
  - No new state is read in `body`.
- **ACCEPTANCE:** a scan finds 0 bare `player.stop()` in `WorkstationView` outside `stopTimeline()`, and `decide(false, true, true) == .pausePlayback`. Device check (the camera lock survives) is still owed.
- **Open question:** Play during a take hits `.resume`. Nothing has measured whether the instrument and the song then layer; the next session should measure that.

**2. VoiceOver can step through notes in the grid (UX A).**
- **Why READY:** it is an accessibility repair; nothing gains a new edit capability.
- **GOAL:** named actions "Select next note", "Select previous note", backed by a pure stepping function.
- **ALLOWED FILES:** `Sequencer/ClipNoteEdit.swift`, `Studio/PartNoteEditor.swift`, plus guard `ThePartNoteGridSpeaksTests`.
- **MUST PRESERVE:**
  - The touch gestures.
  - `picked` is the one selection owner.
  - No read of `currentTick`.
  - Pattern copied from `SongAutomationEditor.swift:507-511`.
- **ACCEPTANCE:**
  - The hint no longer says "Touch only".
  - The pure function orders notes by start, then pitch.
  - It wraps around and does not trap on an empty list.
  - The guard finds both actions.

**3. Arrange part blocks get VoiceOver move actions (UX B).**
- **GOAL:** actions "Move one bar earlier" and "Move one bar later" on the part block.
- **ALLOWED FILES:** `Studio/ArrangeCanvasView.swift` plus guard `TheArrangePartMovesWithoutDragTests`.
- **MUST PRESERVE:** the move goes through `TrackParts.move` with `earlierStart`/`laterStart` and no tick maths of its own (#416). It stays one undo step.
- **ACCEPTANCE:** the guard finds both actions and the call to `TrackParts.move`.

**4. Keep the screen awake while only the song plays (P2).**
- **GOAL:** add a `timelinePlayer.isPlaying` term to the keep-awake rule.
- **ALLOWED FILES:** `Studio/EchoelStudioView.swift` plus guard `TheSongKeepsTheScreenAwakeTests`.
- **MUST PRESERVE:**
  - Add the term to the existing `.onChange` at `:1667` rather than a new `.onChange` (the #1044 pattern).
  - `isPlaying` is cold state (it changes twice per take), and nothing hot is read.
- **ACCEPTANCE:** the guard finds the term in both `updateKeepAwake()` and the `.onChange` expression.

**5. A scene launched while the transport already runs loads its part one bar late (Clips/Scenes LOW-1).**
- **GOAL:** when `PatternEngine` is already running, the launched and Play-loaded part uses the next step instead of step 0, so a multi-bar part lands on the right bar.
- **ALLOWED FILES:** `Sequencer/TimelineRegionPlayer.swift` plus `Tests/CISmoke/TheSceneLaunchIsASwitchTests.swift`.
- **MUST PRESERVE:**
  - The MED-1 repair (an audio scene part starts once).
  - Nothing on the render thread.
  - `activeRegion` stays the only precedence rule.
- **ACCEPTANCE:** a pure `ArrangementLoadPlan` case with next step s≠0 lands on the correct bar, and `testAnAudioScenePartStartsOnce` stays green.

**6. Guard: Broadcast has no door while its engine cannot run (Stream S1).**
- **Why READY:** it does not deepen Broadcast. It pins that Broadcast is absent, guarding against an App Store 2.1 dead-endpoint rejection.
- **GOAL:** the guard goes red if `.rtmp`/`.srt` become `.live` or `BroadcastView(` gets a construction site while `engineAvailable == false`.
- **ALLOWED FILES:** only the guard `Tests/CISmoke/TheBroadcastHasNoDoorWithoutAnEngineTests.swift`.
- **MUST PRESERVE:** it forbids nothing (#364); its failure message names what has to change.
- **ACCEPTANCE:** green on today's tree. A transcription check that flipping to `.live` makes it red.

**7. Picked notes get a 1 pt outline, not only a colour change (UX C).**
- **ALLOWED FILES:** `Studio/PartNoteEditor.swift` plus a guard.
- **MUST PRESERVE:** radius and colour tokens, no glow.
- **ACCEPTANCE:** the draw loop strokes the picked notes.

**8. Workstation icons scale with the text (UX D).**
- **GOAL:** replace the `.system(size:)` icon calls in `WorkstationView.swift` with `EchoelTheme.font`/`.imageScale`.
- **ALLOWED FILES:** `Studio/WorkstationView.swift` plus a guard scoped to that file.
- **ACCEPTANCE:** 0 `.system(size:` left in that file.

**9. Correct stale comments (Stream S2 plus the visionOS wording).**
- **GOAL:** fix the stale comments at `BroadcastPublisher.swift:17`, `SignalRouter.swift:176` and `EchoelmusicApp.swift:174`, and change CLAUDE.md "Plattform-Guards" to "Kopfkommentare".
- **ALLOWED FILES:** those three `Sources/` files. CLAUDE.md is the law file and must stay under its 150,000 B ceiling; the CLAUDE.md fix is a one-word swap.
- **ACCEPTANCE:** the existing prose and citation guards stay green.

**10. `Core/DomeProjection.swift` as a pure core (Immersive A).** Only if nothing above is open.
- **Why it does not "deepen" the paused domain:**
  - Foundation-only maths with 0 production callers.
  - No change to the shader, `MetalBioView`, `ExternalDisplayScene`, audio or UI.
  - It adds no claim anywhere.
  - The cost is one more entry in the "Register der unverdrahteten Kerne", and it must be entered there in the same commit.
- **ALLOWED FILES:** `Core/DomeProjection.swift` plus `TheDomeProjectionRoundTripsTests`.
- **ACCEPTANCE:**
  - Round-trip error below 1e-6.
  - The dome centre maps to the zenith.
  - The edge at r = 1 maps to elevation 90° − FOV/2.
  - The equirect seam gives the same direction at u = 0 and u = 1.
  - NaN input gives a masked result.
  - A test pins the ADM azimuth sign.

## BLOCKED

| Item | State | Gate |
|---|---|---|
| Next MA step (MA5: Replace Source, physical delete, or reference census over autosaves) | BLOCKED_FOUNDER | No MA row after MA4.6 exists. Physical delete is explicitly blocked by the founder |
| MA4.x device acceptance, S1/S2 device check, `ExternalDisplayScene` on a capture card | BLOCKED_EXTERNAL | Founder device session |
| Perform plate (a surface with large targets) | BLOCKED_FOUNDER | Scope. It must follow the master plan's WA order; if approved it becomes a `StudioMenu` panel, never a `.sheet` |
| Shader dome warp (B), dome on the external stage (C), headphone spatial monitoring (D) | BLOCKED_FOUNDER | Visual/XR/Output pause. D also needs a device check and an edit to `TheSpatialRenderHalfIsNotClaimedLiveTests` |
| visionOS target | BLOCKED_FOUNDER | New target in `project.yml` |
| HaishinKit/RTMP/SRT, ReplayKit, obs-websocket | BLOCKED_FOUNDER | Dependency hold (§13) plus the Broadcast pause |
| Stream key in the Keychain | BLOCKED_DEPENDENCY | Only relevant once Broadcast is back in scope |
| MIDI-learn to launch scenes | BLOCKED_FOUNDER | MIDI domain decision |
| Orientation lock / Guided Access | BLOCKED_FOUNDER | `Info.plist` is founder-gated |
| Store or website wording ("stream", "360", "performance mode") | BLOCKED_FOUNDER | App Store wording hold; forbidden today by `TheStoreTextClaimsOnlyWhatShipsTests` |

## Founder decisions needed

1. **What comes after MA4?**
   - (a) Replace Source as its own operation.
   - (b) A reference census across autosaves and legacy formats as a precondition for physical delete.
   - (c) Close the media phase and move on to the next Phase 3 domain (recording, notes or automation).

   Unblocks: the next media slice. The queue above holds no MA work today.

2. **Should the Workstation's "Stop timeline" keep the pulse running?**
   - (a) Yes: pause only; the labelled start/stop ends the session (item 1 as written).
   - (b) No: it ends everything, and the label and VoiceOver text must say so.

   Unblocks: item 1 without a Council caveat.

3. **Performance mode as a surface?**
   - (a) Now, as a `StudioMenu` panel (Start/Pause, scene grid, BPM lock, pulse leaf).
   - (b) After the WA4 device journey.
   - (c) Not before v1.

   Unblocks: the Perform plate, and later MIDI-learn to scenes.

4. **Lift the Visual/XR/Output pause for immersive output?**
   - (a) Dome warp to the external stage (B + C).
   - (b) Headphone spatial monitoring (D).
   - (c) Keep everything paused, with only the pure core in item 10.
   - (d) Add HaishinKit for streaming.

   Unblocks: the matching rows in the BLOCKED table.

Everything here was checked by reading and grepping at `4884c7a47`. Nothing was compiled, run, or tried on a device.

## Source reports

### performance

**Performance mode: what exists on iPhone today, and what a real mode would need (read-only, HEAD `4884c7a47`)**

The biggest finding: if a body take is running, the Workstation's Stop also ends the whole bio session. That's a stop control that does more than it says, on the path a performer uses most.

## 1. What exists today

**Reachable now:**
- **Start.** One labelled start control, `startButton`. The row is built in `transportLine1`: `Studio/EchoelStudioView.swift:2030-2037`. `OneStartControlTests` pins it.
- **Pause without losing the pulse.** `PlaybackToggleButton` (`Studio/WorkspaceView.swift:774`) shows `pause.fill` and only appears while `bus.instrumentRunning` is true. It raises `requestPlaybackOnlyStop`, so the body session and camera lock survive.
- **The ONE-Stop law.** `Core/TransportTransition.swift:45-50` returns `.endSession` for any stop that nobody flagged as a pause. The observer that applies it is at `EchoelStudioView.swift:1602-1639`.
- **Workstation.** Chip list at `EchoelStudioView.swift:2874-2875`, panel at `:3309`. Its Play/Stop button (`Studio/WorkstationView.swift:773`) is the only production caller of `player.play` (`:1132`). The button is `minHeight 44` with VoiceOver label and hint (`:797-798`).
- **Perform scenes (S1/S2).** `SessionLaunchView` (`WorkstationView.swift:342`):
  - "Launch scene" makes one `launchScene` call, and "Back to song" returns every track.
  - A scene can start a stopped song (`playFrom`).
  - Touch targets are 44 pt (`SessionLaunchView.swift:325,374,401,438`), with a 32-scene cap (`:291`).
  - It reads only cold state: `launchGeneration` and `isPlaying`.
- **Touch instrument.** `TouchInstrumentView`, inside `FloatingVisualWindow.swift:882`. The UI census classes it as PERFORMANCE ONLY (`WORKSTATION_UI_OWNERSHIP_CENSUS.md:237`).
- **Stage output (beamer).** `ExternalDisplayScene` is a second, non-interactive scene. The scene manifest is in `Resources/iOS/Info.plist:25-37`. Not device-verified (`HISTORY_ARCHIVE.md` G4).
- **Keep screen awake.** One rule at `EchoelStudioView.swift:6557-6560`: running · meditation · pacer · projecting · (fullscreen && camera).

**Exists but has no door:** `ImmersiveStageView`, `SessionView`, `BioSourceView`. **Scaffold only:** streaming (`BroadcastPublisher`, HaishinKit not linked). **Absent:** a dedicated Perform surface, a setlist, cues, keystone (G4 is marked PORT, not built), and MIDI-learn to launch scenes.

**Modal budget:** `grep -c` finds 14 `.sheet(` and 5 `.fullScreenCover(`, but those counts include comments. The real chain (`grep -n "^ *\.\(sheet\|fullScreenCover\|alert\|fileImporter\)("`) is 11 modifiers on the chain (`:1681-1813`) plus the `.fileImporter` at `:9621`, so 12 in the file. The ceiling is 14, leaving 2 slots.

## 2. What a real mode would need

**Defects found by reading (not device-run):**
- **D1 — the timeline Stop ends the bio session.**
  - `WorkstationView.swift:773` and `RecordTakeButton(stopSong:)` at `:811` call `player.stop()`.
  - `player.stop()` calls `pattern?.stop()` (`Sequencer/TimelineRegionPlayer.swift:731-734`).
  - `Transport.isPlaying` flips, and with no pause flagged and `running == true`, `decide` returns `.endSession` and `stopEverything("transport-stopped")` runs.
  - Result: camera and torch go off, with about 20 s to re-lock. This is the same trap as build 2475 (`WorkspaceView.swift:803-812`).
  - `git grep` finds no mention of it in `WorkstationView`, `SessionLaunchView`, `TimelineRegionPlayer` or the Clips/Scenes plan.
  - Unverified corollary: Play on the timeline during a take hits `.resume`, which calls `resumeAfterPause()`. Whether the instrument and the song then layer needs to be measured.
- **D2 — no keep-awake while only the song plays.** The keep-awake rule has no timeline term, so the screen can auto-lock mid-set when there is no bio take and no projector.

**Code-only slices I can do autonomously (≤3 files each):**
- **P1 (fixes D1).** Workstation Stop, record-stop and Back to song raise `pianoRoll.requestPlaybackOnlyStop()` before `player.stop()`, through one private `stopTimeline()`. Files: `WorkstationView.swift`, a new guard, and `PianoRollPauseRequestTests` if needed.
  - **Acceptance:** a scan shows every `player.stop()` in `WorkstationView` goes through `stopTimeline()`, and `decide(isPlaying:false, running:true, pauseRequested:true) == .pausePlayback`.
  - **Council check first:** this narrows the ONE-Stop law (#161) to "the labelled Stop ends the session". That is arguably a founder call.
- **P2 (fixes D2).** Add `timelinePlayer.isPlaying` (it changes twice per take) to the `.onChange` expression at `:1667` and to `updateKeepAwake()`. Files: `EchoelStudioView.swift`, a guard.
  - **Acceptance:** the guard finds the term in both places.
  - **Measure first:** whether `TimelineRegionPlayer` is actually in `EchoelStudioView`'s environment.
- **P3.** Fix the open LOW-1 from the S2 review: a scene or Play started while `PatternEngine` is already running loads a multi-bar part one bar behind (`PLAN_CLIPS_SCENES_2026-09-26.md`, last bullet). Files: `TimelineRegionPlayer.swift`, `TheSceneLaunchIsASwitchTests`.
  - **Acceptance:** a pure `ArrangementLoadPlan` case with next step s ≠ 0 lands on the correct bar.
- **P4 (accessibility).** Give scene rows an accessibility action for "Launch scene N", plus a custom rotor entry. Files: `SessionLaunchView.swift`, a guard. No new state.

**Founder-gated:**
- **A Perform plate as a new surface** (big targets: Start/Pause, scene grid, BPM lock, pulse leaf). Gate: product/scope. CLAUDE.md says new surfaces follow the master plan's WA order, never ad hoc, and the chip strip already holds 9 chips. If approved, it must be a `StudioMenu` panel like `workstationPanel`, never a new `.sheet`.
- **Orientation lock or Guided Access hints** — gate: `Info.plist`.
- **Stream mode** — gates: new dependency (HaishinKit) plus the Broadcast freeze.
- **Stage cues and keystone (G4 port), 360°/planetarium output, XR** — gate: the Output/Visual/XR freeze.
- **MIDI-learn to scene launch** — gate: the MIDI domain decision (the MIDI editor's autonomous gates stay open).
- **Device proof for S1/S2 and the external scene** — the founder's device session.

## 3. Highest-value next slice

**P1.** It's a correctness defect on the performance path: stopping the song kills the flagship pulse source for about 20 s, and nothing on screen says so. It's one file plus a guard, uses the existing pause mechanism (#179/#234) rather than new machinery, and a performance mode can't be trusted without it. Run the Council first, because it scopes the ONE-Stop law.

## 4. Risks

- **Black screen.** 2 slots left before the ceiling of 14. Any Perform surface must be a panel or plate. Don't trust raw `grep -c` for this count, because it includes comments.
- **Hot state.** A Perform plate must not read `currentTick`, `Transport.position`, bio values, meters or `metronome.bpm` in the host body. Reuse the `PulseMonitorMiniLive` and `PlaybackToggleButton` leaves.
- **Audio thread.** Nothing above touches a render path. P3 changes load planning on the main actor only.
- **Overclaim.** "Performance mode", "stream", "360" and "planetarium" must not appear in store or website copy. The only real stage path is `ExternalDisplayScene` (not device-verified) and ADM-OSC control; the spatial render half is unwired (`TheSpatialRenderHalfIsNotClaimedLiveTests`).

Everything here was established by reading code. Nothing was compiled, run, or tried on a device.

### stream

**Stream Mode domain audit (read-only)**

Nothing in this build streams. There is already a zero-dependency path to a stream-ready feed: the external-display scene sends the clean visual to a capture card, and the phone's normal audio route carries the sound. Getting from there to a real RTMP/SRT stream needs a founder decision in every variant.

## 1. What exists today

| Item | Evidence | Class |
|---|---|---|
| `BroadcastPublisher` | `Stream/BroadcastPublisher.swift:24-26,65-71,89-95`. Even with HaishinKit present, `start()` only sets a message ("connecting path lands next cycle"). `isLive` is never set true. | SCAFFOLD |
| HaishinKit | `Package.swift:66` and `:73` have empty `dependencies` | ABSENT |
| `BroadcastView` | `Studio/BroadcastView.swift:10`. `git grep -n "BroadcastView(" -- Sources \| grep -v ': *//'` returns 0 construction sites. `FEATURE_STATUS.md:63` lists it. | EXISTS-DOORLESS |
| Router sinks `rtmp.out` / `srt.out` | `Core/SignalRouter.swift:177-178` defines them. `.rtmp` and `.srt` are `.roadmap` (`Core/SignalRouting.swift:115`), and `defaultInventory()` removes roadmap ports (`SignalRouter.swift:130-131`). So the `wantsBroadcast` branch at `EchoelmusicApp.swift:588-590` can never be true. | dormant code path |
| Clean program feed: `ExternalDisplaySceneDelegate` / `ExternalStageView` | `Studio/ExternalDisplayScene.swift:73-115,228-285`, role declared at `Resources/iOS/Info.plist:38-44`. Full-bleed `MetalBioView`, no controls, `isUserInteractionEnabled = false` (`:97`), honours Reduce Motion (`:196`). Works over USB-C/HDMI and AirPlay. Store text already claims it (`fastlane/metadata/en-US/description.txt:40`, `CLAIMS.md:87`). Launch was device-verified (build 2473, `:16`). I found no device check of the picture on a capture card. | EXISTS-AND-REACHABLE (opens automatically when a screen connects) |
| Program audio | Category `.playback` with `[.allowBluetoothA2DP, .mixWithOthers]` (`Audio/AudioConfiguration.swift:242,780`). That category routes to HDMI and AirPlay by system default. `AVRoutePickerView` is not used anywhere. | EXISTS (system route) |
| Capture / encode APIs | `AVCaptureSession` exists only for rPPG (`Video/CameraCapture.swift:13`). `AVAssetWriter` exists only for audio export (`Audio/SingleExport.swift:362`). ReplayKit: 0 hits. | none usable for streaming |
| OSC out for overlays and show control | `/echoelmusic/music/*` (`Sync/OSCSender.swift:311-321`, tempo filtered by `BioEgressPolicy.swift:166-170`), plus bio, ADM-OSC, Art-Net and sACN | EXISTS-AND-REACHABLE |
| OSC control in | `/echoelmusic/ctrl/*` (`Sync/OSCReceiver.swift:113-126`), switch in `PatchbayView.swift:453-460`, off by default, allowlist | EXISTS-AND-REACHABLE |

## 2. What a real "Stream Mode" needs

**Works today with no code:** HDMI adapter → capture card → OBS/vMix gives a clean visual plus program audio. OSC `/music/*` and `/bio/*` can drive overlays in vMix, TouchDesigner, Resolume or QLab. iOS Control Center screen broadcast to another app's extension also works, but it shows the full UI.

**Code-only slices that don't expand the product:**
- **S1 – guard that pins the joint invariant.** One new file under `Tests/CISmoke/`. It asserts both of these:
  - `defaultInventory()` contains no `.rtmp`/`.srt` port while `BroadcastPublisher().engineAvailable == false`;
  - `BroadcastView(` has 0 construction sites unless `engineAvailable` is true.
  - Acceptance: red if someone flips `.rtmp` to `.live` or opens a door to the dead engine. That is the App Store 2.1 dead-endpoint case `SignalRouter.swift:126` warns about.
- **S2 – correct stale comments (2 files).** `BroadcastPublisher.swift:17` ("capture path is wired in the follow-up cycle"), `SignalRouter.swift:176` ("CUT 2026-07-25", which predates the 2026-09-24 law), and `EchoelmusicApp.swift:174` ("stream-out pillar"). Acceptance: the existing prose guards stay green.
- **S3 – `docs/dev` note "Stream Mode today = program feed + OSC"** (internal, docs only), with the grep evidence above. It must not touch store or website text.

**Founder-gated, with the exact gate:**
- **Link HaishinKit** (RTMP; SRT additionally pulls the C library libsrt). Gates: new dependency (`MASTER_PLAN §13`, "adding any dependency"), `Package.swift` plus `project.yml`, and a product decision on the camera conflict with rPPG (`BROADCAST_HAISHINKIT_FINISH.md` §2, "mutually exclusive modes").
- **Store the stream key in the Keychain instead of UserDefaults.** Today it sits in UserDefaults in plaintext (`BroadcastPublisher.swift:43`). This must be fixed before any door opens, and only makes sense once broadcast is back in scope.
- **In-app ReplayKit (`RPBroadcastActivityViewController`)** handing off to a third-party broadcast extension. This needs no new target and no package, but it is a new system framework (Council/founder), a new modal, and deepens Broadcast. It also captures the UI, not a clean feed.
- **ReplayKit Broadcast Upload Extension.** This is a new target (`project.yml`, entitlements, App Group), and it would still need an RTMP client, i.e. HaishinKit. It hits two gates.
- **Remote control for OBS via obs-websocket** (JSON over `URLSessionWebSocketTask`, no dependency). It is a new protocol integration, which counts as Distributed/Output deepening and needs a product decision.
- **Stream frames from the Metal renderer** (`CVPixelBuffer` into an encoder). This deepens Visual and Output. It must tap the one existing renderer: two live `MetalBioView`s are forbidden (`ExternalDisplayScene.swift:124-126`).
- **Any store or website wording** ("stream", "broadcast"). This is gated by the "App Store wording" hold, and `TheStoreTextClaimsOnlyWhatShipsTests.swift:354` forbids those words.

## 3. Best next slice

**S1, the joint-invariant guard.** It is the only autonomous slice that removes real risk. The one-line status flip at `SignalRouting.swift:115` would bring "Broadcast (RTMP)" back into the Routing screen, with a toggle that silently does nothing: the status message only renders in the doorless `BroadcastView`. That is a 2.1 rejection. S1 costs one test file, touches no product scope, and forces whoever reopens Broadcast to decide consciously. The most valuable thing overall is founder work, not code: a device check of HDMI → capture card → OBS (picture plus audio). That is the stream-ready path that already ships.

## 4. Risks

- **Black-screen budget:** reopening `BroadcastView` or adding a ReplayKit picker adds a modal. Today there are 12 modal modifiers in the file, 11 on the chain, ceiling 14. It must reuse a slot without a setter (`python3 scripts/doctor.py --section C`), never append one.
- **Hot-state:** reading `ExternalStageBridge.isConnected` in `body` is legal because it changes only on connect (`EchoelStudioView.swift:6568-6571`). Any future bitrate, dropped-frame or live-status field must be read in a leaf view, never in `WorkspaceView`/`EchoelStudioView`.
- **Audio thread:** feeding an encoder must never happen inside the render block. It needs a tap plus a lock-free ring, following the RetroCapture pattern, with no allocation and no GCD in the render path.
- **GPU:** one `MetalBioView` app-wide. Frame capture must come from the existing renderer.
- **Overclaim:**
  - `BroadcastView.swift:42` promises "will work once it ships".
  - "Stream-ready" must not reach the store; only "external display" is claimed there.
  - `/music/tempo` follows the pulse under Flow. Its egress filter is the only protection (`CLAUDE.md` OSC section: "a new path does not inherit it"), so any new stream-metadata path has to reapply it.

### immersive

**360 / Planetarium / XR: inventory and slice plan (read-only, measured 2026-09-26)**

**(1) What exists today**

| Item | Class | Evidence |
|---|---|---|
| Generative visual `MetalBioView` | EXISTS, REACHABLE | `Views/MetalBioView.swift:533` sets `preferredFramesPerSecond = 60`. The shader is compiled inline. The vertex stage draws one full-screen triangle and sets `uv = clip position` (`:2531-2537`). The fragment shader is a **flat 2D field** of `pf ∈ [-1,1]²` plus the radial distance `d` (`:2542-2548`). It has no 3D scene and no camera. |
| `FloatingVisualWindow` | EXISTS, REACHABLE | `WorkspaceView.swift:288`. It mounts `MetalBioView` at `FloatingVisualWindow.swift:845` and `VisualAnalysisLayer` at `:804`. |
| External display stage (#206) | EXISTS, REACHABLE when a screen is attached | Scene role `UIWindowSceneSessionRoleExternalDisplayNonInteractive` (`Resources/iOS/Info.plist:38`). `ExternalDisplaySceneDelegate` creates the window (`ExternalDisplayScene.swift:92`) and mounts a second `MetalBioView` (`:255`). It is wired through `ExternalStageBridge` (`EchoelmusicApp.swift:726`). Not device-verified (HISTORY_ARCHIVE G4). |
| Drawable cost cap | EXISTS | `MetalBioView.swift:1050-1070`: the drawable shrinks with the governor tier; the frame rate never changes. |
| ADM-OSC object out | EXISTS, REACHABLE | Sender created at `EchoelmusicApp.swift:115`; `attachScene` and start/stop at `:549-550`, gated on a patchbay route to `adm.out`. |
| `SpatialSceneStore` | EXISTS, REACHABLE (control half) | `EchoelmusicApp.swift:159` |
| `ImmersiveStageView` | EXISTS, NO DOOR | `git grep -n "ImmersiveStageView(" -- Sources` returns 0 hits. Guarded by `TheStageStatusLineHasNoDoorTests`. |
| `VBAPPanner`, `AmbisonicsEncode` (ACN/SN3D, up to 3rd order, `:43-56`), `BinauralPanner` (ILD + Woodworth ITD + distance air-cut, `:48-105`), `EchoelSpaceReverb` | UNWIRED CORES (pure math, 0 production callers) | Unit tests in `Tests/EchoelmusicTests/{Ambisonics,Binaural,VBAP,EchoelSpaceReverb}Tests.swift`. `TheSpatialRenderHalfIsNotClaimedLiveTests.swift:71` **goes red on purpose** when any of them gets a production caller. |
| Dome, fisheye or equirectangular projection | ABSENT | `git grep -in "domemaster\|fulldome\|equirect\|fisheye\|cubemap" -- Sources Tests` returns 0 hits. |
| visionOS | ABSENT | `project.yml` has only `platform: iOS` and `platform: watchOS`. `Package.swift:57` lists `.iOS("18.0")` only. `git grep -c "os(visionOS)" -- Sources` returns 0. The two "visionOS" hits are header comments (`SPSCQueue.swift:7`, `MemoryPressureHandler.swift:8`), not guards. CLAUDE.md calls them "Plattform-Guards" and should be corrected. RealityKit / ImmersiveSpace / CompositorServices: 0 hits. |
| Multichannel audio output | ABSENT | The master bus is stereo. No ambisonic decoder exists and nothing renders to more than two channels. |

**(2) What a real "Dome / 360 / XR mode" needs**

All of this is Visual/XR/Output deepening, so it is **paused by the founder**. The one exception is slice A, which is pure preparation.

Code-only slices you could do on your own (each touches 3 files or fewer):

- **A — `Core/DomeProjection.swift`**: a pure Foundation-only math core. Changes no UI and no rendering, so it is preparation only and does not need the pause lifted.
  - Covers: domemaster pixel → direction (azimuthal equidistant, field of view 180–220°, tilt), the inverse, equirectangular uv → direction and back, and an "outside the circle" mask.
  - Acceptance test (CISmoke `TheDomeProjectionRoundTripsTests`):
    - round trip error below 1e-6 on a grid;
    - dome centre maps to the zenith;
    - edge at r = 1 maps to elevation 90° − FOV/2;
    - equirectangular seam at u = 0 and u = 1 gives the same direction;
    - NaN input gives a masked result, never NaN.
  - Uses the ADM azimuth convention (+90 = left), with a test that pins the sign.
  - Files: 1 source + 1 test.
- **B — Shader port** (needs the pause lifted). Add a `projection` uniform. A fragment prelude warps `in.uv → direction → field coordinate` before `styleField`.
  - The existing radial rings already centre on the zenith, so a dome warp is natural. But **a warped flat pattern is not a true 360 environment**; copy must say "dome-warped field", not "360 world".
  - A guard must pin that the shader-string constants match A, because the Swift core and the shader are two copies (#416).
  - The flash law is untouched (the warp does not depend on phase), but `FlashGuardTests` must stay green.
  - Files: `MetalBioView.swift` + guard.
- **C — Dome output on the external stage** (paused). `ExternalStageView` sets `projection = .dome` and renders a square letterbox.
  - A 4K domemaster is about 16 MP of fragment work per frame at 60 fps, twice the ~8 MP noted at `:1054`. It must go through the governor's `renderScale`.
  - Files: `ExternalDisplayScene.swift` + guard.
- **D — Headphone spatial monitoring** (paused; HISTORY_ARCHIVE H2 names it as the "next safe slice"). Wire `BinauralPanner` cues into the master graph for the `SpatialSceneStore` objects.
  - This is an audio-thread change and needs device verification. `TheSpatialRenderHalfIsNotClaimedLiveTests` claim 1 must be edited in the same commit.

Founder-gated items:

- **visionOS target**: needs `project.yml` (new target) plus a Council decision on the platform. The `DSP/` isolation rule already makes the cores portable.
- **Ambisonic or VBAP speaker output**: needs a multichannel `AVAudioSession` / hardware-output product decision. Integrate Dante/MADI hardware; do not rebuild it. External decoders (IEM) are already reachable today through ADM-OSC.
- **Any door onto `ImmersiveStageView` / a "mode" chip**: needs a product decision plus the modal budget below.
- **Stream mode**: HaishinKit is not linked; adding it is a dependency decision.
- **NDI/Syphon for dome servers**: specialist infrastructure; the rule is integrate, never rebuild.

**(3) Highest-value next slice: A, `DomeProjection`**

It is the only slice that needs neither the pause lifted nor a founder gate. It changes no rendering, touches no audio thread and adds no modal. It turns "Planetarium" from ABSENT into a tested contract that B, C and a future visionOS target can all reuse. The pattern already exists: `ImmersiveStageMath` is a 59-line pure core with its own test file.

**(4) Risks**

- **Black screen**: any mode switch must reuse an existing slot or the planned single `.sheet(item:)` enum, never append a modifier. `python3 scripts/doctor.py --section D` must be run before any door.
- **Hot-state freeze**: a projection toggle is cold state (`@AppStorage` is fine). Never read bio values or the playhead in `EchoelStudioView` or `WorkspaceView` body.
- **Thermal**: dome and 4K raise pixel cost. Use `renderScale`, never change the pinned 60 fps.
- **Audio thread**: slice D needs a pre-allocated ITD delay line and a one-pole air filter. No allocation per block.
- **Overclaim**: "360", "Planetarium", "XR" and "spatial audio" must not appear in store, website or `ContentPipeline/CLAIMS.md` until B, C or D ship and are device-verified. Only ADM-OSC control out is real today.
- **"Binaural" wording**: the word sits next to a purged red line (brainwave entrainment, HISTORY_ARCHIVE:655). Use "headphone spatial" in user-facing copy.
- **Delete-by-directory**: `DSP/BinauralPanner` and `DSP/EchoelSpaceReverb` are compiled into the AUv3 in isolation, so moving them breaks that build.

### ux

(1) As-built inventory (Workstation front, all REACHABLE through the "Workstation" chip)

- **`WorkstationView`** (1315 lines, 36 accessibility modifiers). It is done well:
  - The track row is one element with a composed sentence (`WorkstationView.swift:579-580`).
  - M/S are toggles with `accessibilityInputLabels([name, letter])`, a value and a hint (`:544-550`).
  - Row selection has a tap gesture and a matching accessibility action (`:501-502`).
  - Buttons carry a 44 pt minimum (`:536, :620, :787…1196`).
  - The only frame below 44 pt (`:575`) is on a text tag that is not tappable.
- **`TrackInspectorView`**: level and pan are `EchoelValueField` (`:352, :365`). Named choices are Pickers with hints (`:446-500`). The name field has a label (`:348`).
- **`SessionLaunchView`**: state is always spoken and written as a word, never shown by colour alone (`:311-314, :366-368, :385`). Cells are 44 pt (`:325, :370`).
- **`MediaBrowserView`**: labels, hints and a header trait are in place (`:192-194, :259, :350-393`).
- **`SelectedPartBar`**: every action is a labelled 44 pt button (`:372, :379`). Earlier and Later give an alternative to dragging (`:274-285`).
- **`SongAutomationEditor`**: the canvas has VoiceOver actions "Pick next point" and "Pick previous point" (`:507-511`). This is the pattern the note grid lacks.
- Design and tokens:
  - Radii are 4, 8 and 12 (`EchoelTheme.swift:172-174`), so no Uncodixfy violation.
  - No blur, shadow, glow or `withAnimation` in any of the 9 files (grep over the 9 files: 0 hits).
  - No raw `Slider` or `Stepper` in the 8 files.
  - `EchoelTheme.font` scales with Dynamic Type (`relativeTo: .body`, `:300`).
  - Contrast is already guarded by `ThemeContrastTests`, and chip tap targets and Dynamic Type by `ChipLabelGrowsWithTheTextTests` and `ChromeDynamicTypeTests`, so I excluded them.

Findings, ranked by user impact:

**F1 (HIGH, VoiceOver blocker). The note grid is one opaque element.**
- `PartNoteEditor.swift:177-181` is `.accessibilityElement()` plus a hint that says "Touch only in this version".
- Cells are 22×14 pt (`:140-141`), well under 44.
- A VoiceOver user cannot select a single note. The selection tools therefore fall back to "every note in this part" (`ClipNoteEdit.swift:178-181`, `PartNoteEditor.swift:344`). Transpose, Fit, Quantize, Delete and velocity work only on the whole part.
- No guard pins the hint: `git grep 'Touch only' -- Tests` returns 0.

**F2 (MED). Moving a part on the canvas is drag-only.**
- `ArrangeCanvasView.swift:228, 237-248`: the block has a select action and nothing else.
- An alternative exists, but only after selecting and then finding `SelectedPartBar`.
- Blocks can be 2 pt wide (`:224`) and lanes are 28 pt tall (`:91`). That is a known trade-off, recorded as review LOW-3 at `:104-106`.

**F3 (LOW). Selected notes differ from unselected ones by colour only.**
- `PartNoteEditor.swift` draws selected notes in `text` grey and the rest in `accent` green (in the `PartNoteCanvas` draw loop). Out-of-key rows are shaded by colour (`:517-518`).
- The count in the label covers VoiceOver, not a colour-blind sighted user. A 1 pt outline on picked notes would fix it.

**F4 (LOW). 17 icon glyphs use a fixed `.system(size:)`.**
- Examples: `WorkstationView.swift:777`, `SessionLaunchView.swift:362`.
- Next to scaling labels they stay small at accessibility sizes. The repo already accepts this for icons (`CoachingTextScalesTests.swift:56`), so it is low priority.

**F5 (LOW).** The playhead is a moving 1 pt line at 15 Hz (`ArrangeCanvasView.swift:172`) and ignores Reduce Motion. It does not flash (it moves; nothing blinks), so it is not a safety issue.

(2) What a real "mode" needs, for this domain

Code-only slices you can do without asking (each ≤ 3 files):
- **A (F1).** Add actions to the note canvas: `accessibilityAction(named: "Select next note")`, "Select previous note" and "Add note after selection".
  - Put a pure stepping function in `ClipNoteEdit.swift`, wire it in `PartNoteEditor.swift`, and add a new CISmoke guard.
  - Acceptance: the canvas carries both named actions; the hint no longer says "Touch only"; the pure function orders notes by start then pitch and wraps without trapping on an empty list.
- **B (F2).** Add `accessibilityAction(named: "Move one bar earlier")` and "…later" to `ArrangePartBlock`, calling the same `TrackParts.earlierStart` / `laterStart` → `TrackParts.move` as `SelectedPartBar.swift:275-283`.
  - Files: `ArrangeCanvasView.swift` plus a guard.
  - Acceptance: the guard finds both actions, and they call `TrackParts.move` rather than their own tick maths (#416).
- **C (F3).** Outline picked notes in the canvas draw loop. Files: `PartNoteEditor.swift` plus a guard.
- **D (F4).** Replace the Workstation icon `.system(size:)` calls with `EchoelTheme.font(…)` or `.imageScale`. About 7 sites, all in `WorkstationView.swift`, plus a scoped guard.

Items that need a founder decision:
- **"Performance / Stream mode" as a separate root or screen.** This is a product decision: it is WA4 or later in the master plan, and Broadcast is unlinked (HaishinKit is not a dependency).
- **"VR/XR / 360 / Planetarium".** Needs a new target (visionOS) or output-surface work. Both new targets and XR/Output work are held for a founder decision.
- **Any new modal for a mode** hits the black-screen budget: 11 of the 14-modifier ceiling are already on the chain.
- **An iPad layout** needs the device-family setting in `project.yml`, which is founder-gated.

(3) The single highest-value next slice

**Slice A.** It is the only finding here that locks a whole user group out of an entire feature, not just makes it harder. The fix is a copy of a pattern that already ships (`SongAutomationEditor.swift:510-511`, also `MoodPads.swift:99-102`). It adds no modal, no state that changes at playback rate, and does not touch the audio thread.

Caveat: you told me the MIDI editor stays "autonomous gates not closed". Slice A is an accessibility repair inside that editor, not new editor features, but it touches `PartNoteEditor`. If that counts as deepening, do Slice B first instead.

(4) Risks

- **Black-screen modifier budget.** None of the slices adds a `.sheet` or `.fullScreenCover`. Accessibility actions are not presentation modifiers.
- **Frozen menus from fast-changing state.** Slice A must keep its reads cold: the named actions change `picked` state only. They must not read `player.currentTick`, which is read only inside `ArrangePlayheadView`.
- **Audio thread.** Not touched.
- **Overclaiming.** Do not state "VoiceOver-complete note editor" anywhere, including `ContentPipeline/CLAIMS.md` and `fastlane`. After Slice A the grid can select and step through notes but still cannot resize or place notes freely.
- **Verification.** All of this compiles and can be checked by reading only. Whether VoiceOver actually reads it well needs a device test, and that is still outstanding.
---

# Design — mockup vs. shipped Workstation (2026-09-27)

Source: the founder's two ChatGPT mockups (phone + tablet, 2026-09-26), run through the vision
gate (`inspiration.csv`, ADOPT-PRODUCT-TEILWEISE). A read-only census compared them with HEAD
`e1036b874`. Verdict: the shipped Workstation already covers roughly 70 % of the phone
mockup's FUNCTION; the gap is LEGIBILITY (no bar ruler, unlabelled blocks, sparse note-grid
labels, a tall button stack), not capability. Every slice reuses an existing owner, adds no
modal, and adds no hot read in a parent body.

| # | Slice | Files | State |
|---|---|---|---|
| 1 | Bar ruler over the Arrange canvas (`ArrangeCanvas.rulerMarks`, cold `ArrangeBarRuler`) | ArrangeCanvasView | BUILT `d16d764b1` — VERIFY (gates + review) |
| 2 | Selected part: end bar (`barSpan`, joiner "–") + note count on the "Notes" toggle | SelectedPartBar, PartNoteEditor | BUILT + reviewed — VERIFY (gates) |
| 3 | Note-grid row names through the reader's `NoteNaming` + one line describing a single picked note | PartNoteEditor | BUILT + reviewed (MED part-relative bars fixed `da3feb02d`) — VERIFY |
| 4 | Creation buttons in a `ViewThatFits` (row first, stack fallback; order unchanged) | WorkstationView | BUILT + reviewed — VERIFY |
| 5 | Muted/soloed visible on the canvas (opacity + shape cue + VoiceOver), no second M/S control | ArrangeCanvasView | BUILT + reviewed (LOWs `b8e3c1e0f`) — VERIFY |
| 6 | Quantize grid choice 1/16 · 1/8 · 1/4 (named SEGMENTED Picker; required `gridSteps`, #431) | ClipNoteEdit, PartNoteEditor | BUILT `f0d2b55fe` — VERIFY |
| 7 | Part start as an `EchoelValueField`, commit-only, one `TrackParts.move` | SelectedPartBar | BUILT `6c69dacad` + review repair `8c40b0fd0` (range follows the song) — VERIFY |
| 8 | Track level also read in dB (static caption, never a meter) | TrackInspectorView | BUILT `8a0202491` — VERIFY |
| 9 | Note-grid playhead as its own self-driving leaf | PartNotePlayheadView (new) + mount | BUILT `e091712e5` — REVIEW, VERIFY |
| 10 | Metronome on the Workstation — first a timing repair, then the switch | MetronomeVoice + EchoelmusicApp (anchor) · WorkstationClickToggle (new) + WorkstationSummary + mount | BUILT `54b2e28cf` (the transport's step subscriber anchors the click on every beat; the instrument's old `resync()` struck one 16th EARLY — the same defect #300 fixed for MIDI Start) + `9d64dd8a8` (the switch). ⛔ The parked diagnosis here ("the Workstation starts mid-bar, needs a render-path phase offset") was WRONG: `TimelineRegionPlayer.play` floors the start to the bar. reviewed twice, MED/MED-LOW/MED fixed `887bbafd1` + `ce04926b5` — VERIFY; timing on glass NEEDS-FOUNDER-VERIFY |
| 11 | A part on the Arrange canvas shows its notes (cold sketch) | ArrangeCanvasView + TrackPartsView | BUILT `c51b1645a` + review-9 repair `0c0735a6e`/`3bab7f277` — VERIFY |
| 12 | The note grid shows how loud each note is (opaque surface/accent mix, floor 0.55) | ClipNoteEdit + PartNoteEditor | BUILT `aad532d33` + reviews 10/11 repaired `c2ad1ed33`/`e845ba35e`/`13cdb3572` — VERIFY (watch `Color.mix(with:by:)` in Compile Check) |
| 13 | The transport shows the mix level (L/R, pre-chain) beside the song position while the song plays — the mockup's "level"; its "time" deliberately NOT built (a tick clock under a body-following tempo would be a guess) | WorkstationMixMeter (new leaf) + WorkstationView mount + MasterLoudnessGrid (one shared `MixLevelBar`, one warn threshold) | BUILT — REVIEW, VERIFY |
| — | Loop toggle | — | BLOCKED_FOUNDER |

REJECTED from the mockups (vision gate): glow/neon accents and pill radii (Uncodixfy), decorative
KPI tiles, a second M/S control on the canvas, a live per-lane meter (no per-lane meter source
exists — it would be a hot read with no producer) [superseded 2026-10-01: B5 `TrackLevelMeter` reads the poly-slot voice in its own leaf], and every Visual/XR/Broadcast/Output panel
(paused without a founder decision).
