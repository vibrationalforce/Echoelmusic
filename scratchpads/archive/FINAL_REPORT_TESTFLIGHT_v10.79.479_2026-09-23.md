# FINAL REPORT — DMMW completion program → TestFlight v10.79.479 (build 2599)

Date: 2026-09-23 · Branch `claude/echoelmusic-review-optimize-u5jjpd`
Preceding report (the #F3–#F5 loop and censuses 1–5): `scratchpads/FINAL_REPORT_DMMW_LOOP_2026-09-23.md`.
It is not repeated here. This file covers the program that ran from there to the deploy.

## 0. Evidence legend (§34) — the level each claim here has reached

| Level | Meaning here |
|---|---|
| COMPILES | `Xcode Compile Check` green: `Sources/` only, Release, device |
| BUILD FOR TESTING | CI/CD step `Build for Testing` green: `Tests/CISmoke` compiles too (Debug, simulator) |
| TEST EXECUTED | the test name appears as `passed` in the job log. The log is only `tail -200`, so an absent name proves nothing |
| DEVICE VERIFIED | nothing in this report has reached this level |

## 1. Verdict

**DEPLOYED.** v10.79.479, build **2599**, is in App Store Connect with `processingState = VALID`.
No slice in it is device-verified. The W1–W9 checklist in `.deploy/release` is how that happens.

## 2. SHAs, version, counts

| | |
|---|---|
| Start SHA (this program) | `e5f51f02b` |
| Release candidate | `b1cd290ca` (= `main`, confirmed by `git ls-remote`) |
| Deploy commit | `a9537cb87` (the only touch of `.deploy/release`) |
| Final branch SHA | this report's commit (docs-only; no gate runs, no deploy) |
| `main` | `b1cd290ca` |
| Version / build | **10.79.479 / 2599** |
| Previous deploy | 10.79.478 at `cd15e0652` |
| Commits since previous deploy | 48, including the deploy commit (`git log --oneline cd15e0652..a9537cb87 \| wc -l`) |
| Commits this program | 4 before this report: 3 feature slices, 1 deploy |

## 3. TestFlight evidence (§39)

Run **2599**, id `35875710648`, triggered by pushing `.deploy/release` in `a9537cb87`.
- Preflight: success. Compile Check job: success (device compile 14:39:32→14:44:42; ecosystem targets success).
- iOS job `107231004569`:
  - Archive: success (14:39:43→14:45:03).
  - Export & Upload to TestFlight: success. Log: `Uploaded Echoelmusic` at 14:46:38.
  - Verify build landed in App Store Connect: success. Log:
    `##[notice]build_number=2599 id=07076289-8db6-4b8f-810d-0a2736b13c4c state=VALID uploaded=2026-09-23T07:51:24-07:00`
    after 7 polling attempts.
- Not claimed:
  - Tester distribution or the Beta App Review state. The workflow does not report either.
  - That a device has installed the build.

## 4. What shipped in this program

| Slice | Commit | What changed | Gates |
|---|---|---|---|
| **#B1** | `6f88bb3d7` | `Core/TempoDetector` (pure estimator), `DetectedTempo {bpm, confidence, octaveAlternativeBPM, loopBars, mediaDurationSeconds; isKnown}`, confidence floor 0.3. `Sequencer/AudioTempoAnalysis` is the AVFoundation adapter. It says "Tempo unclear." rather than guess | COMPILES + BUILD FOR TESTING (main advanced) |
| **#B2** | `36468bb9a` | Import adopts a KNOWN detection as `Clip.nativeBPM`, and only while the value is 0 (`adoptableNativeBPM`, `ClipStore.adoptDetectedNativeBPM`). The analysis runs off the main thread (`Task.detached(.utility)`). The song tempo is never written | COMPILES + BUILD FOR TESTING |
| **#C1** | `b1cd290ca` | `Sequencer/AudioWarp`: the first production writer of `TimelineRegion.warpEnabled`. `TimelineStore.setRegionWarp` is one undo step. A per-lane "Warp" switch in `WorkstationView` appears only where a part has a known native tempo and is disabled while playing. The span is resized from the rate that `StretchPlan.resolve` returns (clamp-aware) | COMPILES (run 35872946996) + BUILD FOR TESTING (main advanced) |
| deploy | `a9537cb87` | version line, build note, W1–W9, printed founder-verify list (13 of 172) | TestFlight run 2599 success |

Guards added or extended:
- `TheDetectedTempoIsHonestTests`: B1 + claims 15–16.
- `TheWarpSwitchIsHonestTests`: 9 claims.
- `TheTimelineStoresLiveSurfaceTests`: + `setRegionWarp`.
- `TheWorkstationImportsAudioTests`: message.

All four: **BUILD FOR TESTING; TEST EXECUTED unproven.** `Run Tests` is #396 on every push, and none of the new suites showed up in the tail-200 window.

## 5. Domain status (as of `a9537cb87`)

| Domain | Status |
|---|---|
| Audio import | **LIVE** (Audio Import V1 + #F1 Add Audio Track). Not device-verified |
| Tempo (song clock) | Unchanged. T1–T3 hold; the five tempo sources are enumerated. No new clock |
| Tempo detection | **NEW, heuristic** (#B1). Calibrated on synthetic material only. Real material = W3/W8 |
| Stretch / warp | **User-reachable at lane level** (#C1). No stretch-mode picker: `.clean` only. Trimmed parts keep their authored length |
| Pitch shift | Engine present (`StretchPlan`), no user control. Not started |
| Key | Detected and **reported as text, never adopted** (#E1/#F3). `SessionContext` stays the only owner |
| Tuning / concert pitch | Detected with its own confidence (#F4). Text only |
| Musical context | One truth (`SessionContext`). Census 1: no second truth |
| MIDI | In: monophonic performer voice. Out: live. MIDI file export live |
| MPE | **OUT real, IN has no zones** (`TheMPEInputHasNoZonesTests`) |
| MIDI 2.0 | Second switchable source (#1253), default off. Register corrected (#F5). Not device-verified |
| Audio input | **Deleted (#1302).** The founder approved bringing it back, but not blindly. Not started; discovery only |
| Sampler | Audition/lane `SamplerVoice` only. The drum kit is dead (#167) |
| Granular | **Struck (#1305).** Nothing to build without a new founder ask |
| Video capture | **Removed (#1304).** The founder approved video/AWB/AI video as ROADMAP: `scratchpads/ROADMAP_VIDEO_AWB_AI_2026-09-23.md`. Not started |
| Visual | Live (`MetalBioView`, floating window) |
| Lighting | Art-Net + sACN live. Ownership seam + delivery fixes #1444–#1447. Rig-only verification |
| Spatial | ADM-OSC control half live. Render half = seven unwired cores (registered) |
| Bio | HealthKit, camera rPPG, BLE HR (0x180D). The Watch reaches the phone through HealthKit |
| Collaboration | `PeerIdentity` (#1435) built. Two-phone probe pending (#113) |
| AI / agent | `FeatureFlags.echoelAI` has zero readers. `ParameterToolCore` is live but has no caller. Unchanged |
| Broadcast | Not linked (HaishinKit absent). Unchanged |

## 6. Ownership map for the new paths — one owner each

- `Clip.nativeBPM`: written ONLY by `ClipStore.adoptDetectedNativeBPM`, from a KNOWN detection, and only while the value is 0.
- `TimelineRegion.warpEnabled` / warped `lengthTicks`: written ONLY by `TimelineStore.setRegionWarp`, fed by `AudioWarp.changes`.
- Warp rate: asked of `StretchPlan.resolve`, never re-derived (#416).
- Session tempo, key and a4: untouched by all three slices.
- **New persistence roots: NONE.** Both fields already existed in persisted documents.
- **Second clocks: NONE.** Analysis runs once per import, off-main. Warp changes a rate the existing player already asks for.
- New types:
  - `TempoDetector`
  - `DetectedTempo`
  - `AudioTempoAnalysis`
  - `AudioWarp` (+ `LaneState`, `Change`)

## 7. Realtime and privacy

- Realtime: nothing new on the audio thread. The warp chain is preloaded at prime time by the existing `AudioLanePlayer`. The switch is disabled while playing, because hanging the chain mid-song would stop the engine.
- Privacy: analysis stays on the device and runs on the app's own managed copy. No new permission prompt. Info.plist, entitlements, `project.yml` and workflows are unchanged since `cd15e0652`.

## 8. Blockers and founder holds (open)

| # | Hold |
|---|---|
| — | **Second founder hold: content unknown. Never inferred, never used as permission.** |
| #27 | Brand line wording |
| #91 | HRV line in the App Store text (fastlane) |
| #95 | EchoelCore target in `project.yml` |
| #94 | FrameTime / drop-frame timecode (blocked) |
| #87 | Re-dooring / new media domains |
| #58 | Two genres blocked |
| #34, #40 | Ear tests / musicality |
| — | Workflow repairs, founder-gated: `CLAUDE.md` absent from `ci.yml` paths; `tail -200` test window; DerivedData cache key |

Device debt:
- #113, #115, #118, #152.
- `WorkstationView` NEEDS-FOUNDER-VERIFY (7)–(27).
- W1–W9 (this build) and D1–D9 (10.79.478).
- `python3 scripts/founder-verify.py` prints the full list.

## 9. Risks

1. **Tempo octave errors on real material.** Only synthetic material is measured. A 2× error would size a warped part at half or double its bars. W3 asks for exactly this.
2. **Confidence floor 0.3 is a heuristic.** Too low shows Warp on a pulseless file (W8). Too high hides it on real loops.
3. Execution of the four new or extended suites is unproven (#396 / tail window). Compile-proven only.
4. A mixed-state lane (older builds) warps every part on one tap. That is intended, but unverified on device.

## 10. Release notes (tester-facing, short)

> Workstation: add an audio track, import a file. Echoel tells you its key, concert pitch and tempo, or says when it can't tell. When the tempo is clear, a "Warp" switch lets the loop follow the song tempo at the same pitch.

## 11. Next 10 slices (dependency order)

1. **Device read of W1–W9** (founder). Everything below depends on its tempo findings.
2. Octave-choice UI: offer `octaveAlternativeBPM` as a one-tap correction on the import note. It writes through the same `ClipStore` owner.
3. Manual native-BPM entry for "Tempo unclear" parts (`EchoelValueField`, same owner). This unlocks Warp without detection.
4. Stretch-mode picker per part (`.clean` → the other `timelineCapabilities` modes). One control, no new store.
5. Pitch-shift (transpose) per part via `StretchPlan`. This is the first pitch power.
6. Offer the detected key as a one-tap "use this key" that writes through `SessionContext`. It needs a founder go, because it crosses the report-only law.
7. Warp on the trimmed-window case: define the authored-length rule.
8. Audio-input discovery memo (G): what #1302 removed, the `RecordRouteOwner` + plist coupling, and the crash family. **Discovery only.**
9. MPE-IN zones plan execution (second consumer first, `PLAN_MPE_ZONES`).
10. Video/AWB roadmap step 1: capability census only, no capture code.

## 12. Architectural verdict

The DMMW law held across the program:
- One session, one clock, one timeline, one clip store.
- The one new write path per field has exactly one owner.
- The warp rate is asked of the existing facade.
- Detected facts stay labelled as detected: tempo is adopted onto the CLIP only when confident, and key and a4 are never adopted.

The build is compile- and upload-verified, and sensorially unverified. What remains is a device session, not more building.

STOP.
