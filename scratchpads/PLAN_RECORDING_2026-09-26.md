# PLAN — Phase 3 / Recording & Input (2026-09-26)

## Census (read-only subagent, measured)
- **MIDI recording is BUILT and WIRED, and has no door.** `MIDIBusPublisher.onRecordNoteOn/Off` (main
  actor, before `publish`, so NO second `controllerEvents` consumer) → `RecordController`
  (step/stop subscribers, `commit` = `clips.setClip` + `timeline.addRegion`, ONE region undo
  step per take) → `TakeRecorder` → `MIDINoteRecorder` → `Clip(kind: .midi)`. `RecordController.arm()`
  and `TimelineStore.toggleArm` have 0 production callers; the lane row already renders an "ARM"
  tag. No Info.plist key is needed (CoreMIDI; Bluetooth MIDI covered).
  ⚠️ The WA4 note "No Arm (no record path, #1302)" is stale for MIDI: #1302 removed AUDIO input.
- **Audio input** (mic/line-in): FOUNDER-GATED — `NSMicrophoneUsageDescription` must return in the
  same commit as any `RecordRouteOwner` case (Info.plist is founder-gated), plus a design note +
  Council (HISTORY_ARCHIVE class REBUILD) and the public-claims reversal. Not autonomous.
- **Own-output bounce** (`RetroCapture` → `AudioImport.perform`): founder-ungated; a third
  audio-clip door that needs its own guard; must be named "bounce", never input. Candidate R3.

## Measured before building R1 — the clock mismatch
`RecordController` places notes at `transport.position.absoluteStep * 120`, which counts LINEARLY
from Play. The Workstation's song WRAPS at its end (`TimelineRegionPlayer` resets its cursor at
`loopTicks`; nothing seeks the transport). So after the first wrap a take would land PAST the song
end, not where it was heard. Also `absoluteStep` starts at the play bar, so a take started from a
scene bar would sit at bar 1.

## R1 — Record a MIDI take in the Workstation (Council, silent: proceed)
· Architect: the one recorder stays `RecordController`; the door is a leaf (`RecordTakeButton`,
  `TrackArmToggle`) in its own file, because `WorkstationView` must not name `RecordController`.
  Record starts the song through the Workstation's ONE `startTimeline(fromTick: 0, …)`, so the take
  and the song share bar 1.
· Skeptic: the take ENDS at the song end (`RecordController.followSongEnd` ← the player's
  `songEndTick`), so a wrap can never misplace notes. Record only while stopped. A song that cannot
  play (empty) cannot be recorded into yet — said, not hidden (R2 = the clock over an empty song).
  A full 8-slot clip grid dropped a take silently — now counted and shown.
· User-Advocate: Arm on the selected rack MIDI track (not Echoel, not bio, not audio); the lane row's
  existing "ARM" tag shows it. Notes land on the sixteenth grid (stated). While recording you hear
  the keyboard's live voice, the take plays back on the track's own sound (stated; R2 candidate:
  monitor through the armed track).
· Shipper: RecordController + player (1 property) + app wiring (1 line) + new leaf file + 2 mount
  lines + guard.
Open after R1: R2 empty-song clock; sub-step timing (`RecordAnchor.tick(afterSeconds:)`); monitor
through the armed track's voice; R3 bounce; the "arm() has zero callers" prose in ~16 files.
