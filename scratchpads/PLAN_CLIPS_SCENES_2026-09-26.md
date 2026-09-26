# PLAN — Clips · Scenes · Session (Phase 3, founder order 2026-09-25)

Status: S1 SHIPPED + REVIEWED · 2026-09-26

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

## S1 as built + review
- f5b573b9e; review (no HIGH) repaired next commit: MED guard claim now scans the USE of Back to
  song; LOW 2 doc (a deleted region's lane counts as not-in-scene → returns to the song); LOW 3
  a11y value "Not the current scene"; LOW 5 Queued word in `dim`, not the signal accent; LOW 6
  Back to song only from two launched tracks (one track's own Stop row is the same action);
  LOW 7 guard covers the queued-stop / queued-switch compositions.
- OPEN LOW 4: two scene ticks with identical cells (an unplayable later-placed winner) can both
  read Playing — cosmetic, rare.

## S2 — a scene starts a stopped song (2026-09-26)
- Council: the "founder call" flagged by the census dissolves — the Workstation stays the ONE
  `player.play(` caller; it hands `SessionLaunchView` a `playFrom` action. Proceed.
- Shape: `WorkstationView.startTimeline(fromTick:)` (required argument; Play passes 0, the Session a
  scene's bar) · `SessionLaunchView(playFrom:)` · the scene button is enabled while stopped: on a
  stopped song it calls `playFrom(scene.startTick)` FIRST (play clears launches), then
  `launchScene` — requested on the floored bar, so it lands on that bar. A single PART stays
  disabled while stopped. WA4.2 guard's "scene disabled while stopped" claim changed on purpose.
- Evidence: forward claims in `TheSceneLaunchIsASwitchTests` §4 (engine end-to-end + scans);
  device open.

## S2 review (526804d0c, independent, no HIGH) — repaired
- MED-1 REPAIRED: a scene launched AFTER `play` returned let the audio prime start the lane's
  arrangement file and the launch restart it from the top one step later (same file twice).
  `play(…, launching:)` now fires the scene on the start bar inside the call; the roll skips its
  arrangement load for a launched lane, `AudioLanePlayer.prime(…, launchingInThisCall:)` warms
  but does not start a launch-owned lane, and the launch starts it once. MIDI was already clean.
- MED-2 REPAIRED: the stopped-state VoiceOver hint named "Bar N beat M"; the song starts on the
  floored bar — `SessionGrid.songStartLabel`.
- LOW-1 OPEN (recorded): a `canPlay` refusal makes the scene button silent, as it does Play.
- LOW-2 answered by the spy test (`testAnAudioScenePartStartsOnce`).
