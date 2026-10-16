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

## Gap map against Ableton (Arrangement) — MEASURED 2026-10-16 (read-only audit)

⛔ The first version of this table named loop brace, duplicate and snap as missing. Measured,
they exist: the "Cycle" toggle (`WorkstationCycleToggle`), "Copy" + the "Repeat" field and
`moveRegion(laneOffset:)` in `SelectedPartBar`, automatic snap via `PartTrim.snapUnit`, and pinch
zoom (`ArrangeTimeZoom`). **Lesson: measure the gap map BEFORE writing it.**

| Ableton | Echoel | Slice |
|---|---|---|
| every track has a lane, click → clip, room past the end | built | **A1 ✅ `2c56287`** |
| Session ⇄ Arrangement | built | **P1 ✅ `8788833`** |
| cycle brace | toggle only (selection or 4 bars from the cue), not draggable | A2: drag/resize the band |
| markers / locators | MISSING (no model) | A5 |
| grid choice | automatic from zoom; no picker | A6 (low priority) |
| track reorder / colour / duplicate | MISSING (⚠️ order decides `rollLaneID`) | A7 — council first |
| part name / colour | MISSING (no field on `TimelineRegion`) | A8 |
| multi-select | store APIs take `Set<UUID>`, no door | A9 |
| clipboard copy/paste | MISSING | A9b |
| count-in | MISSING | A10 (transport, device-heavy) |
| automation on the canvas | inspector page only | A11 |

## Performance (Session)

- **P1 — the toggle**: in the Arrange view, a segmented toggle `Arrangement · Session` at the
  top. Session takes the canvas's place and shows the scene grid full-width. Persisted
  per device, no new modal, no new switcher entry (the founder approved exactly five, E18).
- **P2 ✅ `1fd0e02`** — the grid: tracks as columns × scenes as rows.
- **P3 ✅ `2f694fe`** — "Launch on" Beat · Bar · 2 Bars · 4 Bars (`SessionLaunchPoint`).
- **P4 — capture**: launches are recorded into the arrangement.
- **P5 — free slots**: clips that do not stand in the arrangement. ⚠️ This touches WA2 ("no
  second Session owner"), so the founder decides (inbox).
- **P6 — performance with the instrument**: the body-voice and the scenes on ONE surface.

## Order — FIXED since the founder's goal (2026-10-16, seven items, one slice per turn)

| # | Item | State | Evidence |
|---|---|---|---|
| 1 | Markers (A5) | ✅ `48a28d6` | guard `TheMarkersNameBarsOfThePieceTests` (pure + store undo + scan); gates: not yet read |
| 2 | Cycle region drag (A2) | ✅ `28b1059` | guard `TheCycleEdgesAreDraggedOnTheRulerTests` (pure `CycleDrag` + scan), Python transcription green, 6 checkers 0; gates: pending |
| 3 | Multi-select + clipboard (A9) | **NEXT** | — |
| 4 | Track reorder + colour | open — council first (order decides `rollLaneID`) | — |
| 5 | Count-in | open | — |
| 6 | Record scenes into arrangement (P4) | open | — |
| 7 | Automation on the canvas | open | — |

Done before the fixed order: A1 `2c56287` · P1 `8788833` · P2 `1fd0e02` · P3 `2f694fe` (release v10.79.512 = `26be2e6`).

### Exact next step (item 3)
The multi-select APIs in `TimelineStore` exist without a door (measured gap). Slice: a
"Select" mode in the canvas — a tap toggles a part into the selection (no new modal), and
Copy / Paste act on the selection at the Play-start bar through the store, ONE undo step per
paste. Clipboard = an in-memory value on the store (never the system pasteboard, never
persisted). Guard: pure paste plan end to end + one writer + no `currentTick` in the door.

Device asks for the next release note: A1, P1, P2, P3, A5, A2.
