# PLAN — Automation editing (Phase 3, step 6, founder order 2026-09-25)

Status: A1 + A2 SHIPPED (gates green, reviewed; main = d53c1b351) · A3 built · device open — 2026-09-26

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
- ⛔ CORRECTED (A2 review L1): the Modulation Matrix does NOT reach a track slot — matrix and
  global lanes bind `polyVoice` (harmony) only; per-track keys dispatch through `bindPerTrack` to
  `laneVoiceRack`. The real co-writer on the slot is the region-load patch apply (`slotPatchSink`).
- `ClipAutomationEdit.laneIndex` is not alias-aware (fine for registry keys).

## Next (not started)
- A2 candidates: parameter picker (all `automatableBases`), curve shape per segment, the
  switch/strip honesty fix above. Echoel-track automation = founder call.

## A1 review (6bcbc731f, independent, no HIGH) — repaired in the next commit
- MED-1 REPAIRED: a held, trembling finger nudged the point and wrote an Undo step —
  `resolveMove` now returns nil under `TimelineAutomationRowMath.tapSlopPoints` (6 pt).
- MED-3 REPAIRED: removing a track left its per-track lanes as orphans, and an `.automation`
  Undo could then change only an orphan — `removeLaneIfEmpty` drops them; `apply(.automation)`
  filters them and SKIPS a step that would change nothing else (the `.clipNotes` shape).
- MED-4 REPAIRED: VoiceOver could reach only the mid-song point — "Pick next / previous point"
  actions, an honest hint, "1 point" grammar.
- LOW-6/7 REPAIRED: Remove drops only the emptied lane; a move onto an occupied sixteenth
  replaces it. LOW-8: guard pins `doc.automation = fresh.automation`; claim-3 comment honest.
  LOW-9: three stale "no producer yet" notes. LOW-11: the pick shows by colour, not size.
- MED-2 OPEN (design, recorded): the 28-pt pick radius (44-pt touch target) makes a NEW point
  within ~28 pt of an existing one land as a pick on long songs (32 bars ≈ 3 bars on a phone).
  Workaround today: add further away, then hold-and-slide. A2 candidate: zoom, or a time-only
  hit radius.
- LOW-5 OPEN: a point past a shortened song end is not drawn, so the last segment is drawn
  flat while playback ramps toward it (comment in `draw` now says so).
- LOW-10 OPEN: after Stop, or after removing every point while playing, the rack slot keeps
  the last automated brightness until the next patch apply — not told to the user.

## A2 — parameter choice (Council, silent: proceed)
· Architect: the choice is a PROJECTION of `PolySynthVoice.automatableBases` ∩ catalog
  `automationEligible` (`SongAutomationEdit.offered`), never a second list (#416); one lane per
  parameter per track (`track.<id>.<base>`), same one writer, same Undo.
· User-Advocate: named values → `Picker(.menu)`, not a number; the menu marks parameters that
  already carry a curve ("· curve"); the row opens on the first such parameter, else Brightness.
· Skeptic: the opening parameter is decided ONCE per track (`onAppear`), so removing a curve's
  last point does not make the row jump to another parameter; switching drops the pick.
· Shipper: 2 source files (editor + CLAUDE.md line) + the guard; no store/player change.
Open (unchanged from A1): MED-2 pick radius, LOW-5, LOW-10.

## A2 review (4239a4200, independent) — repaired in the next commit
- HIGH-1 REPAIRED: the value field showed the stored 0…1 number while playback denormalizes
  (attack typed 0.5 played ~5 s). `SongAutomationEdit.realValue/storedValue/decimals(for:)` —
  the field reads and writes the parameter's real value and unit; guard pins agreement with
  `PerTrackAutomationResolver`. The canvas height stays LINEAR over the real range (short
  times sit low) — stated in the editor header, not fixed.
- MED-1 CLOSED AS NO DEFECT (A4 built and reverted, see below) — was: after Stop a curve that ended low leaves its value —
  Amplitude at 0 = a silent rack track until the next Play re-applies the patch. Bounded; stated
  in the header; NEEDS-FOUNDER-VERIFY in the guard. Fix candidate A3: re-send `slotPatchSink`
  on stop for slots with per-track lanes.
- LOW-1 REPAIRED (this plan): the Mod-Matrix co-writer claim was wrong for the slot.
- LOW-2 REPAIRED: guard header claim order.
- LOW-3 RECORDED: the projection-equality claim is near-circular (`automationEligible` is
  derived from `automatableBases`); it proves each base has an inventory entry. A base without
  a setter is caught elsewhere (`TheMatrixReachesEveryAutomatableParameterTests`).
- LOW-4 RECORDED: the parameter name shows twice (menu + gutter) — cosmetic, kept for the
  gutter's alignment with the Arrange names.

## A3 — the Sound panel's readout tells the truth about song curves (Council, silent: proceed)
Measured before building: `AutomationStatusStrip` read the arrangement layer from
`player.timelineLanes` (installed only while the Workstation plays) and scaled a key through
`extraAutomatableDescriptors`, where a per-track key never matches. So an A1/A2 curve showed as
raw `track.<uuid>.ddsp…` marked "no effect" WHILE it played, and at rest the strip said
"No automation recorded" while the song held curves. The switch's off-copy said it was "for
the song-wide curves" — the arrangement curves play regardless of it.
· Architect: `SongAutomationEdit.statusScale` = the row's own gate (`sounds`) + the value
  field's scale (`realValue`), so the readout and the editor cannot disagree (#416).
· Skeptic: the strip now observes `timeline.document` — cold (edits only), in its own leaf;
  `laneVoiceCapacity` is `@ObservationIgnored`. The empty sentence stays byte-identical
  (pinned by `TheSoundPanelNamesItsActualDriverTests`) and is now true.
· Shipper: 2 source files + guard claim 8.

## A3 review (97be5adc3, independent) — no HIGH, no MED
- LOW-3 REPAIRED (prose only): `AutomationPlayer.enabled` doc ("never writes a parameter" was
  false — clip and arrangement lanes write outside the gate), `AutomationStatus` header and
  empty-sentence doc, strip header and the "no in-app setter" row doc (#561 is the setter).
- LOW-4 REPAIRED: the A3 grading claimed regressions "where the file compiles" — it does not
  compile at the parent; reworded to "regression shape by transcription, no verdict there".
- LOW-1 RECORDED: a legacy GLOBAL-key lane in the song document now lists as an active
  Arrangement row while the Workstation is stopped (the layer applies only while it plays), and
  can mark a global row "overridden" at rest. Unreachable today — the only writer writes
  per-track keys. Fix candidate: gate arrangement `isActive` on the region player's playing.
- LOW-2 RECORDED: a per-track curve that no longer sounds (track turned into Sub/Sampler, past
  capacity) shows its raw `track.<uuid>.…` key with "no effect" — true but unreadable. Fix needs
  `AutomationStatus.rows` to take the name separately from the binding.
- LOW-3b RECORDED: the ON copy "Global curves move these parameters" sits above clip/arrangement
  rows it does not govern; `TheSoundPanelNamesItsActualDriverTests`' "no automation writer
  today" comment premise is now stale (harmless). 

## A4 — Stop returns each automated track to its own patch (Council, silent: proceed) — e6892d37f
Repairs A2 review MED-1. Both stop paths of `TimelineRegionPlayer` call
`restoreAutomatedSlots()` after releasing the arrangement layer; it re-sends each automated
track's OWN patch through the same `slotPatchSink` the region load uses (one owner of a slot's
timbre). Slots from the pure `automatedSlots(in:rollLane:capacity:)` — `MultiRollFanout.slot`,
exactly the resolver's rule; each once, slot order, within capacity; Echoel/audio/global/emptied
curves restore nothing. Guard claim 9 (behaviour + scan), FORWARD against 43620c8d6.
Evidence: transcription; gates pending; not device-verified. Global-voice hold after Stop is
NOT touched (the global layer has no song writer).

## A4 review (e6892d37f, independent) — A4 REVERTED
- MED-2 (decisive): the premise was false. `noteOn(slot:` has ONE caller (the timeline note
  sink) and every load re-sends the lane's patch before notes, so the held value is inaudible;
  the A4 device probe passed on the parent too. Measured: `git grep -n "noteOn(slot:" -- Sources`.
- MED-1: the restore raised the release tails of a faded track after Stop (patch commands drain
  before note commands in `PolySynthVoice`). A real regression → reverted.
- LOW-1/LOW-2 moot with the revert.
- LESSON: before repairing a "state persists" finding, name the control that would HEAR it.
  A2 review MED-1 had none.
