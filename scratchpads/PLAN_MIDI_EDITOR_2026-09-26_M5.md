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

## Still open (not in M5)

- The STRUCTURE chase (`refreshStructure`, `relocate`, `reapplyLaunched`) still loads the roll with
  `step: 0` at `lastTick` — a region move/trim while playing has the same one-bar phase risk.
  Separate slice; touches the relocate law.
- The editor has no rack-capacity note: a MIDI track beyond `multiRollCapacity` never sounds.
- Usability: Undo sits about a screen below the grid, Play further; marquee replaces the selection
  (no add); no deselect-all; no scale lock. Next editor slices, in that order.

Evidence: COMPILES pending (gates), TESTED by transcription only, NOT device verified.
