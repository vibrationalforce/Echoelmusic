# Composition UX — execution contract, 2026-09-29

Status: IMPLEMENTED, native validation and independent review pending, for CUX-1 only. The sequence and scope live in
[`ECHOELMUSIC_MASTER_PLAN.md`](../docs/dev/ECHOELMUSIC_MASTER_PLAN.md); this file is the
implementation contract for its first code slice, not another roadmap.

## CUX-1 — New MIDI Part follows the selected playable track

- **TASK / GOAL:** repair UX-04 from the 2026-09-29 UX audit. Adding a second MIDI track
  and creating a part must put the part on that track, not silently on the primary track.
- **CURRENT HEAD:** `fe390f7e3e279a87393cda66e9f88d9b304296dc`, freshly cloned and matched
  to remote `main` on 2026-09-29. Branch: `feature/echoelmusic-composition-handoff-2026-09-29`.
- **CANONICAL OWNERS:** `TimelineStore` / `TimelineDocument`; `ClipStore`;
  `WorkstationSelection`; `MultiRollFanout.slot` for secondary-voice capacity.
- **ALLOWED FILE AREA:** `Sequencer/MIDIImport.swift`, `Studio/WorkstationView.swift`,
  `Tests/CISmoke/ANewMIDIPartOpensTheNoteEditorTests.swift`; plan, evidence and handover docs.
- **MUST PRESERVE:** user-owned clips, empty orphan reuse, clip-before-region transaction,
  one Undo, non-bio MIDI eligibility, primary-lane MIDI-file import, current transport and DSP.
- **DO NOT CHANGE:** root presentation chain, audio graph, persistence schema, dependencies,
  targets, protected CI/plist/release files, sound presets or App Store claims.
- **ACCEPTANCE:** Add MIDI Track selects the new track. New MIDI Part uses that selection,
  appends on its next barline, selects the new region and names its target. Nil/stale/audio/bio
  selection and a secondary lane beyond the actual rack capacity refuse before any write.
  The first track is unchanged. Undo removes the region; another New/Undo reuses the empty slot.
- **REQUIRED TESTS:** extend the existing empty-part behavioural tests; preserve legacy import
  tests; source checks for the view-to-owner handover; actual Xcode Compile Check, Build for
  Testing and named test results on the resulting SHA. Python transcription is supplementary.
- **REQUIRED REVIEWERS:** Claude Code, independently reading the implementation; no independent
  approval is claimed by Codex. Physical iPhone: two MIDI tracks, selected target, audible
  edited notes, Undo, Save/Open, portrait/landscape, VoiceOver and large text.
- **LIMITS:** insertion remains after the selected lane's last part. Explicit insertion bar,
  automatic opening of Notes, instrument selection, four-workspace navigation and hosting are
  later master-plan slices. This slice alone does not meet the complete composition milestone.

Council decision: proceed with mitigation. Architect: reuse owners and the player's capacity
rule. DSP: no audio-thread edit. User advocate: make the target visible and never redirect a
failed selection. Skeptic: prevent silent parts beyond rack capacity; preserve import behaviour.
Shipper: one bounded fix with a real regression case. Expressive scope remains in the master
plan rather than being marked implemented by this fix.

Baseline evidence: Xcode Compile Check run `36478741765` succeeded; CI run `36478741726`
Build for Testing succeeded but Run Tests failed. TestFlight run `36526763299` succeeded,
including Upload and Verify build landed in App Store Connect. These are different facts.
No local Swift/Xcode toolchain; no device proof in this session.

Local verification: `git diff --check` passed. A Python transcription of the target,
capacity, slot reuse and barline decisions passed 18 scenarios, including the parent
reproducing the wrong-track destination. Source wiring/transaction assertions passed.
The existing dead-needle, count-pin and foreign-needle checks passed within their stated
coverage; the moved-needle advisory was inspected (the existing caller is still present).
The runtime-needle heuristic reports three pre-existing findings in untouched code; these
are not new Swift failures and are not silently treated as passing native tests.
