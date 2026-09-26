# MIDI editor — M5 audit + slices (2026-09-26)

Founder correction 2026-09-26: return to MIDI / Piano Roll as the critical path. First loop:
OPEN MIDI REGION → SEE NOTES → SELECT NOTE → CREATE → MOVE → RESIZE → DUPLICATE → DELETE →
UNDO / REDO → PLAY. Canonical notes stay in Clip ownership (`ClipStore`), one writer
(`TimelineStore.setClipNotes`), one undo step per gesture, no second MIDI document.

## Loop table (measured against code 2026-09-26, read-only audit + own reads)

| Step | State | Where |
|---|---|---|
| Open MIDI region | built (M1) — part bar → Notes | `Studio/PartNoteEditor.swift`, `SelectedPartBar` |
| See notes | built — windowed by the player's own rule | `RegionNoteWindow` |
| Select / create / move / resize / duplicate / delete | built (M1–M4) | `Sequencer/ClipNoteEdit`, `RollHitTest`, `RollNoteOps` |
| Undo / Redo | built — `.clipNotes` history step | `TimelineStore.setClipNotes` |
| Play (hear the edit) | **was defective, repaired M5/M5b** | `TimelineRegionPlayer.refreshNoteContent`, `LaneNotePump`, `PianoRollModel.trigger` |

## ⛔ Correction of my own earlier report

I told the founder a mid-play edit is heard only at the next region onset. **False** — M1's review
already added `refreshNoteContent` (per-step poll of `ClipStore.userMelodyGeneration`). The real
defects were in HOW it reloaded, below.

## Defects found and repaired

1. **MED-HIGH — multi-bar part one bar late after a mid-play edit** (roll AND rack tracks). The
   refresh ran before `cursor.advance` at `lastTick` with the roll's `step: 0`. Repaired in
   `65ed99950` (M5): runs after cursor/wrap/launch at `newTick` with the real step.
2. **MED — every edit cut ringing notes on every other MIDI track** (`primeSecondaryLanes` reset +
   re-bind). Repaired in `65ed99950`: `reloadSecondaryNotes` re-windows each pump in place.
3. **LOW-MED — a note moved while sounding hung its old pitch** (id-keyed `active` overwrite, pump
   AND roll). Repaired in `849e4a845` (M5b).

Guards: `AMidPlayNoteEditKeepsTheBarTests` (end-to-end, real player/store/pattern/roll),
`AMovedSoundingNoteIsReleasedTests` (pump end-to-end + roll scan).

## Still open after M5 — now closed (M6–M10)

- STRUCTURE chase at `lastTick`/`step: 0` → **M7** `c3f72e956` (`chaseStructure` at this step's
  tick and step; relocate gets `nextStep`). Reviewed; repair `(M7 review)` commit: relocate half is
  LATENT (no production caller), ordering anchor after the launch shift, four stale doc blocks.
  Guard `AStructureEditKeepsTheBarTests`. BfT green (main = `c3f72e956`).
- Rack-capacity note → **M8** `3723e000d` (`PartNoteEditor.noVoiceLine` over `TrackMix.role`).
- Marquee replaced the selection → **M9** `6220398fc` (`NoteGridGesture.boxing`, preview = commit).
- Deselect → M6 (`28ce8dc8a` kept Undo under the editor after the M6 review revert).
- Play far from the grid, always from the top → **M10** `4ada958a5` ("Play from here" in
  `SelectedPartBar`'s title row via the Workstation's one start + one `canPlay`, `songCanStart()`).

## Open

- **Scale lock** — the last usability slice in the founder's list (in-key note entry).
- **LOW-3 (M7 review)**: `play()` loads the roll with `step: 0`; if the instrument's own loop is
  already running mid-bar when the song starts, the roll's bar plan is told "bar line" and repeats
  one bar. Pre-existing; M10 does not add a way in (it is Stop while playing). Reachability on a
  device unconfirmed.
- **LOW-4 (M7 review)**: a rack part starting exactly on the chase tick is loaded twice (benign).
- Off-grid part starts play from the bar they start in (floor) — by design, documented at the button.

Evidence: COMPILES pending for M8–M10 (gates), TESTED by transcription only, NOT device verified.
