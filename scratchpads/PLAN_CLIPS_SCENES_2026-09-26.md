# PLAN — Clips · Scenes · Session (Phase 3, founder order 2026-09-25)

Status: S1 IN PROGRESS · 2026-09-26

## Census summary (read-only subagent, HEAD 34658ea88 — measured, file:line in the report)
- `SessionLaunchView` (WA4.2) is a PROJECTION: tracks = launchable lanes, scene = every distinct
  start tick of a playable part, cell = `TimelineScheduling.activeRegion` at that tick. Nothing
  persisted; launches ride `TimelineRegionPlayer` → `ClipLaunchEngine` (runtime-only, per-lane
  idle→queued→playing→queuedStop, `LaunchQuantize`). Reached: Studio chip → Workstation.
- Clip = content in `ClipStore` (fixed 8 slots); region/part = placement; regions may share a clip.
- No scene type, no names, no follow actions, no slot grid. `LaneLaunchLatch` is dead.
  `ArrangementSection`/`ArrangementPlayer` (song form) has 0 writers.
- Gap: scene launch was a per-cell loop — other launched tracks kept looping (two scenes played
  as their union); no "back to song"; launching needs the song playing; 8-clip pool cap.
- Undo: `TimelineStore` history (`HistoryStep.regions`/`.clipNotes`, 50 deep); launch state is
  runtime-only (nothing to undo).

## Council — S1 "Perform scenes"
· User-Advocate: the reachable workflow is "play the song, launch a scene, launch another, back to
  song" — today the second scene does not replace the first.
· Architect: no new model, no persistence, no root read; compose `requestStop` + `requestLaunch`
  in the pure engine (testable end-to-end in the blocking bundle); the player keeps ONE launch rule.
· Skeptic: "stop" in this model means BACK TO THE SONG, not silence — a scene that leaves a track
  out does not mute it. Say so in the caption; a silent-track override is a later engine change.
· Shipper: 3 source files + 1 guard; the existing WA4.2 guard's ranges stay intact.
→ Gate: proceed.

## S1 — shape
1. `ClipLaunchEngine.requestScene(_:atTick:quantize:)` (stop every other active lane, launch the
   scene's) and `requestStopAll(atTick:quantize:)` — both composed from the existing laws.
2. `TimelineRegionPlayer.launchScene(_:quantize:)` / `stopAllLaunched(quantize:)`; the refusal rule
   moves into ONE private `launchableLaneID(ofRegion:)` asked by `launchRegion` and `launchScene`.
3. `SessionLaunchView`: scene button → one `launchScene` call; "Back to song" button while a track is
   launched; scene header reads "Playing"/"Queued" (`SessionGrid.sceneState`).
4. Guard `TheSceneLaunchIsASwitchTests` (engine + sceneState end-to-end; source scans).

## Next (not started; founder calls marked)
- S2 candidates: start the song AT a scene (changes "WorkstationView is the one `play(` caller" —
  founder call) · authored/named scenes as a projection over song form (needs a `HistoryStep` case
  for ONE undo step) · raise the 8-clip pool + decide clip-owned sound (EF3) — "the Clips question".
