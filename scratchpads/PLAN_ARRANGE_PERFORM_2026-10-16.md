# PLAN — Arrangement on Ableton level + an integrated Performance mode (2026-10-16)

Founder, 2026-10-16, verbatim: „Ich sehe die ganzen bahnbrechenden Veränderungen nicht. Wir
brauchen einen einfachen arrangemnt Modus der alles kann auf Ableton Level. Und integrierten
Performance Modus".

## Why the founder sees nothing (measured, not guessed)

- Most of this session's work was plumbing without a surface: stereo sampler (audible, but
  only with a stereo sample), stem renderer (no door — E35), the launch counter (G10).
- **Arrange exists**: `WorkstationView` → `ArrangeCanvasView` (move, trim, drag across tracks,
  split, notes, automation). It sits under the Piece stage → "Arrange".
- **Session/Performance exists, but buried**: `SessionLaunchView` is a "Scenes" list UNDER the
  arrange canvas (`WorkstationView`, `pieceView == .arrange && !focused`), and a second copy
  sits in the instrument's panel (`PerformSessionView`). Engine: `ClipLaunchEngine` inside
  `TimelineRegionPlayer` (launch on the bar, scene = switch, back to song).
- Fresh install: the default document seeds no tracks → empty state.
- **Lesson: a capability with no visible door does not count as delivered.**

## Gap map against Ableton (Arrangement)

| Ableton | Echoel today | Slice |
|---|---|---|
| every track has a lane | only tracks with parts had a lane | **A1 ✅ `2c56287`** |
| click into a lane → clip | "New MIDI Part" row only | **A1 ✅** (tap on an empty bar) |
| room past the song's end | canvas = song length | **A1 ✅** (+4 bars, min. 8) |
| Session ⇄ Arrangement (Tab) | Session buried under the canvas | **P1 ✅ `8788833`** |
| loop brace over the ruler | loop point exists, no brace | A2 |
| right-click menu on a clip | button row under the canvas | A3 |
| duplicate (⌘D) | — | A4 |
| markers / locators | — | A5 |
| choice of snap grid | bar only | A6 |
| track order, colour, duplicate | partly | A7 |
| record from the playhead + count-in | arm exists (R1) | A8 |
| multi-select, clipboard | single selection | A9 |

## Performance (Session)

- **P1 — the toggle**: in the Arrange view, a segmented toggle `Arrangement · Session` at the
  top. Session takes the canvas's place and shows the scene grid full-width. Persisted
  per device, no new modal, no new switcher entry (the founder approved exactly five, E18).
- **P2 — the grid**: tracks as columns × scenes as rows, Ableton's picture instead of the list.
- **P3 — the launch quantize choice** (bar / 2 bars / beat). The engine has `LaunchQuantize`.
- **P4 — capture**: launches are recorded into the arrangement.
- **P5 — free slots**: clips that do not stand in the arrangement. ⚠️ This touches WA2 ("no
  second Session owner"), so the founder decides (inbox).
- **P6 — performance with the instrument**: the body-voice and the scenes on ONE surface.

## Order

A1 → P1 → P2 → A3 → A4 → A2 → P3 → the rest. Every slice has a guard.
Device asks go into the next release note (A1, P1).
