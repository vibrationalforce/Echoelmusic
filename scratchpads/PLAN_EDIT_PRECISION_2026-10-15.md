# Plan — MIDI, clips and editing that a finger can use (2026-10-15)

Founder on device: „Midi und Clips sowie editing View sind bisher komplett unbrauchbar und zu
ungenau." Rule from the same day: no new DAW surface until these are fixed and device-confirmed.

## Two causes, measured

**Timing (what you hear).** Playback plays only notes whose start is exactly the current 16th
(`Studio/PianoRollView.swift` ~:1126 `startStep == step`), and the step comes from a main-queue
timer (`Sequencer/PatternEngine.swift` ~:599). Anything finer is pulled to the grid; the step
jitters with UI load.

**Touch (what you do).**
| | measured | Apple minimum / goal |
|---|---|---|
| note row | 14 pt (`PartNoteEditor`) | 44 pt touch |
| note resize zone | 8 pt, ≤ half the note (`NoteGridGesture.edgeSlop`) | ~22–44 pt |
| step width | 11 / 22 / 44 pt, 3 levels, pinch applies on release | continuous |
| edits | every move/resize/box needs a 0.3 s hold, no "armed" signal | haptic + highlight |
| arrange snap | whole bars until zoom 4, beats until 16 (`SelectedPartBar.snapUnit`); zoom 1…8 of the WHOLE song → a 32-bar song stays at bar snap on a phone | snap by visible width |
| fine control | integer "Starts at bar" only, no length field, ±beat only in VoiceOver | Start / Length fields + nudge |
| MIDI part start | always whole bars | beat / 16th |
| copy | linked by default (edits change both); no loop | independent copy; Loop × N |

## Slices (each with a guard, each needs a finger on a device)

- **EP-1 Note rows 14 → 24 pt** — done in this commit (`TheNoteRowsAreTouchableTests`, a floor).
- **EP-2 Resize zone** 8 → 18 pt and allowed to reach outside the note's right end; clamp so it
  never covers the next note.
- **EP-3 Armed feedback** — a haptic tick and a highlight when the 0.3 s hold arms; a selected note
  or part drags directly (`minimumDistance` ~10, no hold).
- **EP-4 Numbers on the part bar** — Start (bar.beat.16th) and Length (bars.beats) fields with
  `EchoelValueField`, plus visible ±beat / ±16th nudge.
- **EP-5 Arrange snap by visible width**, zoom beyond 8 where the texture limit allows (AE-11).
- **EP-6 Copy is independent by default**, „Linked copy" stays as an option; Loop × N for MIDI.
- **T-1 Sample-accurate sequencer (the big one)** — notes scheduled inside the render with a sample
  offset from one host-time clock, not fired from the main-queue step; removes the 16th
  quantisation and the jitter at once, and serves the drums (SP-3) and MIDI out. Council +
  audio-thread review + Astra brief B before any code.

Order: EP-1 → EP-3 → EP-2 → EP-4 → EP-6 → EP-5, with T-1 designed in parallel.
