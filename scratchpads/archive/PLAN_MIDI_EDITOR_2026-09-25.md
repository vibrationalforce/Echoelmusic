# PLAN — Phase 3 / Creation Workflow, target 1: the selected-MIDI-part note editor

Founder 2026-09-25 ("FOUNDER PHASE DECISION — CLOSE WA4, THEN CREATION WORKFLOW").
Implementation starts only after WA4's autonomous gates close (task #217).
Recovery census: read-only subagent, 2026-09-25 (clone NOT shallow, 8364 commits — all history readable).

## 1. Recovery classification

| Source | What it is | Class | Why |
|---|---|---|---|
| `PianoRollModel` (`Studio/PianoRollView.swift:105-1375`) | live playback buffer + `MusicalFrame` publisher; ONE-bar grid (16 steps, pitch 36…84); PRIVATE undo `[[Note]]` depth 50 | **DO NOT RESTORE as editor model** — leave untouched (load-bearing) | one bar only, a second undo history, overwritten at every region onset by `TimelineRegionPlayer.loadClip` (:805-814); every editing member has 0 production callers |
| `RollHitTest` (`Studio/RollHitTest.swift`) | pure touch classifier: `.empty(pitch,step)` / `.body(id)` / `.rightEdge(id)`, `notesInRect`, `clampedGroupDelta`, `resizedLengthSteps`, `velocity(forY:)` | **PORT ALGORITHM** | Foundation-only, tested; `stepCount` is a parameter so N bars = N×16 |
| `RollFitMath` | `fittedStepW`, `fittedRowH`, `medianPitch`, `centeredOffsetY` | **PORT ALGORITHM** | pure; `fittedStepW` assumes one bar fits — multi-bar needs a scroll/fit decision |
| `RollNoteOps` | reverse, legato, double/half time, echo, invert, `snapPitch`, `snapToScale`, `velocityRamp` | **PORT ALGORITHM later** | hard-wired `barTicks = 1920`; needs a bar-length parameter; not slice 1 |
| `RollSelection` (`PianoRollView.swift:1381-1403`) | `none / single / group(Set)` | **PORT ALGORITHM** (move with the editor) | test-only today |
| `MelodyBarEdit` (`Sequencer/MelodyBarEdit.swift`) | `slice` / `splice` with total sort order | **PORT ALGORITHM** (sort order) | test-only |
| deleted `PianoRollView` (`f28a95d5c^`, struct :1305) | one `DragGesture(minimumDistance:0)`, classified ONCE at touch-down via `RollHitTest`; tap = create/select; marquee from empty; velocity paint lane; Scale-Lock; zoom | **PORT INTERACTION IDEA** · **DO NOT RESTORE the struct** | it mutated per drag SAMPLE, kept its own undo, read hot transport state, needed a sheet, one bar only, bio stamp modes |
| deleted `ArrangeTimelineView` clip mode (`eb58e7af5^` :305-431) | throwaway model from `MelodyBarEdit.slice`, ONE commit on Done via `updateMelody` | **PORT INTERACTION IDEA** (edit a copy, commit once) | exactly the performance law |
| `ClipStore.updateMelody(id:notes:)` (`Core/ClipStore.swift:71`) | whole-value write, persists immediately; 0 production callers | **REUSE behind an undo-aware wrapper** | the canonical writer; must never be called directly by UI |
| `MusicalKey.contains / quantize` (`Sequencer/MusicalKey.swift:593/599`) | scale membership + snap (tie → lower) | **PORT ALGORITHM later** (Scale-Lock) | read the key inside a handler, never in a body |

## 2. Canonical ownership (one answer)

- **Note content:** `ClipStore` → `Clip.melody.notes` (`Note`: `id, pitch, startTick, lengthTicks, velocity, role, operators?, mpe?`; 480 PPQ), addressed by `TimelineRegion.clipID`. `PianoRollModel.notes` is a playback buffer, not an owner.
- **Undo:** `TimelineStore`'s ONE history (`SongHistoryRow` → `timeline.undo()/redo()`). Today it holds regions only; it is EXTENDED to carry clip-note steps. No second history.
- **Playback:** `TimelineRegionPlayer` re-reads `clips.clip(id:)?.melody?.notes` at each region onset → an edit is heard from the next onset / loop wrap, not mid-region (state it in the UI hint; mid-region refresh is a later slice).

## 3. Risks the slices must close

1. A UI path calling `clipStore.updateMelody` directly bypasses Undo → guard: exactly one production caller, `TimelineStore.setClipNotes`.
2. `composerOwned` clips are rewritten by evolve every ~25–45 s → read-only in the editor, one sentence says why (later: "make an editable copy").
3. `duplicateRegion` shares `clipID` → an edit changes every copy. Slice 1: say so visibly ("Edits change all N copies") — linked-pattern semantics, honest; independent copies = later decision (ClipStore has 8 fixed slots, so copy-on-write can fail and needs its own answer).
4. Hot reads (`player.currentTick`, `pattern.*`, `SessionContext`) in a body on the root-evaluated `dropdownContent` path → the editor is a leaf, no playhead in slice 1.
5. Per-drag-sample persistence (whole 8-slot grid) → gesture-local `@GestureState` preview, ONE commit at release.
6. Trimmed regions → show the window `[effectiveOffsetTicks, +lengthTicks)` and map taps to clip ticks through `RegionNoteWindow`.
7. `WorkstationSummary.swift:177` "does not edit them" + `TheWorkstationPlaysTheTimelineTests.swift:810` must change in the slice that adds editing.
8. `TimelineStore` header (:50) still calls `undo/redo` callerless (doc drift) — fix in slice 1.
9. No new `.sheet` on the root: inline leaf under `SelectedPartBar`.

## 4. Slices (each = architecture + reachable workflow + behavioural proof)

- **M1 — open · see · select · create · delete · undo.** `Sequencer/ClipNoteEdit.swift` (pure: `adding`, `removing`, visible window, total sort order) · `TimelineStore`: history element `enum HistoryStep { regions, clipNotes(clipID, notes) }` + `setClipNotes(clipID:_:)` (guards `.midi`, `!composerOwned`, ONE snapshot) with the `ClipStore` reached through one attach · `Studio/PartNoteEditor.swift` inline leaf: `Canvas` of notes, tap → `RollHitTest.classify` → select (local `RollSelection`) or create; Delete button; ONE commit per action · "Notes" toggle in `SelectedPartBar` for MIDI parts · `SongHistoryRow` copy "parts and notes". Guards: pure edits, one-step undo/redo of notes through the Workstation's Undo, Open clears it, composer clip refused, one `updateMelody` caller, leaf reads nothing hot.
- **M1b — New MIDI Part (done 2026-09-25, `3cf0a5346`).** `MIDIImport.planEmptyPart`/`addEmptyPart`: an empty user-owned MIDI part (4 bars, on the barline after the roll lane's last part), reusing an orphaned EMPTY user clip so New→Undo cannot spend the 8-slot grid; Workstation row "New MIDI Part" selects it. Closes the M1 reachability gap (editor needed a MIDI file). Guard `ANewMIDIPartOpensTheNoteEditorTests`.
- **M2 — move · resize · marquee · multi-select** with `@GestureState` preview and ONE commit per gesture (`clampedGroupDelta`, `resizedLengthSteps`, `notesInRect`).
- **M3 — duplicate · velocity · quantize · transpose** (buttons over the selection; velocity lane later). → SHIPPED `05a8f4619` (gates/review pending).
- **M4 — scale-aware** (Scale-Lock on create/move/transpose via `MusicalKey.quantize`; `RollNoteOps` with a bar parameter). → SHIPPED `9dc19bf71` as key-shaded rows + Fit + ±1 scale step; scale LOCK on tap/drag deliberately deferred (preview == commit law).
- Later: humanize / chord tools / expression; mid-region refresh of edited notes; independent copies.

## 5. Evidence vocabulary per slice

COMPILES (Xcode Compile Check + Build for Testing) · TESTED (named guard observed passing in the window, else "compiles, execution unrecorded") · SIMULATOR · DEVICE (founder) · INDEPENDENTLY REVIEWED (ui-state + code reviewer).

## 6. M1 design detail (read 2026-09-25 20:30Z, no code yet)

- **History step, no global wiring.** `TimelineStore`'s `undoStack`/`redoStack` become `[HistoryStep]`,
  `enum HistoryStep { case regions([TimelineRegion]); case clipNotes(clipID: UUID, notes: [Note], store: ClipStore) }`.
  The step CARRIES the (app-lifetime) `ClipStore` it was written through, so `undo()`/`redo()` keep their
  parameterless signatures (`SongHistoryRow` unchanged) and nothing has to be attached at launch. Undo of a
  notes step pushes the store's CURRENT notes onto redo, then writes the snapshot through `updateMelody`; a
  clip that no longer exists drops the step. `replaceDocument` still clears both stacks.
- **`setClipNotes(clipID:_:clips:) -> Bool`** on `TimelineStore`: guards (clip exists, `.midi`, not
  `composerOwned`, notes differ) → ONE `snapshot` of the old notes → `clips.updateMelody`. The ONLY production
  caller of `updateMelody` (guard).
- **Editor leaf `PartNoteEditor(regionID:)`** mounted under `SelectedPartBar` when the part is MIDI and the
  "Notes" toggle is on (toggle state local to the bar). Reads `timeline.document` + `clipStore.clip(id:)`
  cold; NO transport, NO tempo in body. Window = `[contentOffsetTicks, +lengthTicks)`; a LEGACY region
  (tick offset 0, seconds offset > 0) is shown read-only with one sentence (its window needs a tempo — see
  `RegionNoteWindow.effectiveOffsetTicks`).
- Geometry: steps = `ceil(lengthTicks / 120)`, pitch rows from the clip's notes ± an octave via
  `RollFitMath.medianPitch` (default C3–C5 when empty); tap → `RollHitTest.classify` with region-relative
  notes; `.empty` → create one 1-step note at velocity 0.8 (`role: .harmony`) at clip tick = offset + step·120;
  `.body` / `.rightEdge` → select (local `@State RollSelection`); Delete button removes the selection.
- Read-only cases with one sentence each: composer-owned clip; clip missing; legacy offset. Shared clip
  (`clipID` used by N>1 regions): editable, hint "Edits change all N copies of this part".
- Copy/guards to move in the same commit: `WorkstationSummary.swift:177` "does not edit them",
  `TheWorkstationPlaysTheTimelineTests.swift:810`, `SongHistoryRow` label/hint, `TimelineStore` header :50.
