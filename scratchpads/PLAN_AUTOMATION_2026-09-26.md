# PLAN — Automation editing (Phase 3, step 6, founder order 2026-09-25)

Status: A1 SHIPPED (6bcbc731f) · review running · gates pending · device open — 2026-09-26

## Census summary (read-only subagent, measured)
- `TimelineDocument.automation: [AutomationLane]` is persisted and PLAYED: `AutomationPlayer`
  applies the timeline layer on every transport step (per 16th), independent of the
  "Play automation" switch (that switch gates the older clip layer only).
- Keys: a global base (`ddsp.osc.brightness` …) reaches only the harmony voice; a per-track key
  `track.<laneID>.<base>` (`PerTrackParameterKeyPath`) resolves through
  `PerTrackAutomationResolver` → `MultiRollFanout.slot` to a rack voice — ONLY on a secondary
  MIDI lane inside the rack's capacity, NEVER on the roll/Echoel lane.
- Eligible bases: `PolySynthVoice.automatableBases` ∩ `DDSPParameterCatalog.descriptors`
  (`automationEligible`).
- No writer with a door: `TimelineAutomationRow` went with #473; the store's per-point mutators
  (`addAutomationPoint` …) have no caller and write NO undo step.
- Pure cores ready: `ClipAutomationEdit` (upsert/move/remove), `AutomationCanvasMath` (snap to
  the 120-tick sixteenth, value↔y), `TimelineAutomationRowMath` (x↔tick, hit-test 28 pt,
  displayPoints).
- Undo: `TimelineStore` history is typed (`.regions`, `.clipNotes`), depth 50.

## Council — A1 "draw one curve"
· User-Advocate: the reachable workflow is "select a track → Automation → draw, move, set,
  remove a point → hear it → Undo". One parameter is enough to prove the chain.
· Architect: ONE writer (`setSongAutomation`, whole-list, one `HistoryStep.automation`), no
  new model, no persistence change; reuse the three pure cores; the view reads the document
  only in its own leaf.
· Skeptic: every drawn point is a persist → a structural refresh → the chase flushes voices and
  restarts audio while the song plays. Needs an automation-only short path in the player.
  Also: offer the row only where the key SOUNDS, or the user draws silence.
· DSP Purist: nothing on the audio thread changes; `AutomationPlayer` already applies on the
  main-actor step.
· Aesthetic Maximalist: brightness is the most audible single timbre move — right first pick.
→ Gate: proceed. Echoel-track meaning (per-track key silent there, global key harmony-only) =
  founder call, not built.

## A1 — as built (6bcbc731f)
1. `TimelineStore.setSongAutomation(_:)` + `HistoryStep.automation([AutomationLane])`.
2. `TimelineRegionPlayer.differsOnlyInAutomation` + short path in `refreshStructure` before
   `flushPumps` (lanes to `PianoRollModel.setTimelineAutomation`).
3. `Studio/SongAutomationEditor.swift`: pure `SongAutomationEdit` + leaf views; mounted in
   `WorkstationView` below `PartNoteEditor`; `@GestureState` preview, one commit on release;
   `EchoelValueField` draft; 44 pt targets; VoiceOver labels.
4. `SongHistoryRow` copy names automation; two pinning guards moved in the same commit.
5. Guard `TheSongAutomationIsDrawnThroughOneWriterTests` (forward; store end-to-end, pure
   gestures, resolver premise, short-path scan).

## Risks recorded (not fixed in A1)
- The timeline curve plays regardless of the "Play automation" switch; the
  `AutomationStatusStrip` hint can read as if it gated it.
- After Stop the parameter holds its last automated value.
- Per-16th sampling can zipper on steep ramps.
- The Modulation Matrix may also write `ddsp.osc.brightness` (two writers on one parameter).
- `ClipAutomationEdit.laneIndex` is not alias-aware (fine for registry keys).

## Next (not started)
- A2 candidates: parameter picker (all `automatableBases`), curve shape per segment, the
  switch/strip honesty fix above. Echoel-track automation = founder call.
