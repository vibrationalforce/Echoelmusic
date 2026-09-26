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

- **Scale lock — DEFERRED by founder 2026-09-26** ("Do NOT add the scale-lock feature now"). The
  scale-aware behaviour that exists (key/scale shading, Fit, ±1 step) is enough for now; scale lock
  is later workflow polish, not a v1 blocker. Do not build it without a new founder ask.
- **LOW-3 (M7 review)**: `play()` loads the roll with `step: 0`; if the instrument's own loop is
  already running mid-bar when the song starts, the roll's bar plan is told "bar line" and repeats
  one bar. Pre-existing. M10's "Play from here" reaches this case exactly as the Workstation's Play
  already does (the button is Stop only while the SONG plays; the instrument's loop is not the
  song). Reachability on a device unconfirmed.
- **LOW-4 (M7 review)**: a rack part starting exactly on the chase tick is loaded twice (benign).
- Off-grid part starts play from the bar they start in (floor) — by design, documented at the button.

## Evidence for M7–M10 (test-result forensics, 2026-09-26 ~13:00Z)

| level | M7 repair `608b803bc` | M10 `4ada958a5` | repair `ab1586c95` |
|---|---|---|---|
| Xcode Compile Check | cancelled (superseded) | success (2942) | **success (2943)** |
| CI/CD Build for Testing | success (6406) | success (6407) | **success (6408)**; main = `ab1586c95` |
| Run Tests | failure, #396 shape | failure, #396 shape | in progress at last read |
| independent review | M7 reviewed | M8–M10 reviewed (no HIGH/MED) | review running |

Run Tests reading (`gh-test-verdict.py`): 6406 = 168 observed passing, 0 failures, 0 skipped,
`TEST EXECUTE FAILED`, no launch-failure line, 1028 s silence in the fetched log; 6407 = 167 / 0 / 0,
973 s silence. **None of the four MIDI guards occurs in either window**
(`TheNoteEditorSaysWhenATrackHasNoVoiceTests`, `ABoxAddsToTheSelectionTests`,
`APartPlaysFromItsBarTests`, `AStructureEditKeepsTheBarTests`: 0 hits each). Per #445/#807 their
ABSENCE proves nothing: they are **compiled, execution UNRECORDED** — not green, not red.

**Why the founder's evidence A and B are not reachable from this container (measured, not assumed):**
- A (xcresult): the artifact `test-results-ios-iPhone 17` exists (run 6407, 7.6 MB, id
  10906911804). The MCP gives only a signed Azure blob URL; `curl` through the agent proxy gets
  `CONNECT tunnel failed, response 403` on `productionresultssa18.blob.core.windows.net` — a
  network-policy denial (HARNESS_LEDGER #814/#1092b, re-confirmed today).
- B (targeted run): no workflow accepts a test filter. `ci.yml` `workflow_dispatch` has no inputs
  and its only `-only-testing:` lines are the hard-coded Performance job; `full-tests.yml` builds
  `Tests/EchoelmusicTests`, not `Tests/CISmoke`. Adding a filter input is a `.github/workflows/**`
  edit = founder-gated.

**Routes that would close it (each needs the founder):**
1. Network: add `productionresultssa18.blob.core.windows.net` (or the Azure blob wildcard GitHub
   uses for Actions artifacts) to this environment's allowed domains; the zip then downloads here.
   Whether the bundle is readable without `xcresulttool` is UNMEASURED (no bundle has ever been
   opened here).
2. Founder Mac: `gh run download 36240499051 -n "test-results-ios-iPhone 17"` then
   `xcrun xcresulttool get test-results tests --path TestResults.xcresult | grep -E
   "NoVoice|BoxAdds|PartPlays|StructureEdit"`.
3. Workflow (founder edit): a `workflow_dispatch` input `only_testing` passed as
   `-only-testing:EchoelmusicTests/<Suite>` to `ci.yml`'s Run Tests, or an xcresult summary step
   after it (#208 / #807).

#396 (reported separately): `Run Tests` = failure with `Build for Testing` = success at step level on
6404–6407 (6401–6403: run conclusion failure, steps not re-read), `TEST EXECUTE FAILED`, 0 visible assertion failures — the chronic
simulator-clone shape, predating M8–M10. That is "these slices did not cause it", not "their
guards passed".

**Status: MIDI EDITOR AUTONOMOUS GATES NOT CLOSED** — compile gates green, reviews done (repair
review running), test execution of the four guards unrecorded. Device acceptance (M5–M10) is the
founder's either way.
