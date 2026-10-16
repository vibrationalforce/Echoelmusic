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
| 3 | Multi-select + clipboard (A9) | ✅ `8b5d152` | guard `TheGatheredPartsAreCopiedAndPastedTests` (pure paste + store undo + gather rules + scan), Python transcription of the scan green, 6 checkers 0; gates: pending |
| 4a | Track colour (A4b) | ✅ `fa1f6b8` | guard `TheTrackColourIsThePersonsChoiceTests`; 6 checkers 0; gates: pending |
| 4b | Track reorder (A4c) | ✅ `1ded828` | guard `TheTracksMoveWithoutTakingTheEchoelTests`; 6 checkers 0; gates: pending |
| 5 | Count-in (A10) | ✅ (this commit) | guard `TheRecordCountsInWithTheOneClickTests` (pure length through the click's clamp + scan of the button paths); two guards re-anchored (`TheFirstTakeRunsTheClockTests` → `beginTake()`, header word + hint needles); Python transcription green; checkers 0 |
| 6a | Record scenes — pure take (P4a) | ✅ (this commit) | guard `TheLaunchesBecomePartsOnTheArrangementTests` (log → tiled copies, switch/stop/gone, store paste = one undo, recording wins over parts under it); checkers 0 |
| 6b | Record scenes — player + door (P4b) | ✅ (this commit) | guard `TheSessionRecordsIntoTheArrangementTests` (every `launch.removeAll()` ends the take first; wrap before fold; sink → `pasteRegions`; leaf door); Python transcription green; checkers 0 |
| 7a | Automation on the canvas — display (this commit) | ✅ | guard `TheCanvasShowsEachTracksAutomationTests` (own curves only; samples = `value(atTick:)` at the canvas scale; leaf, no gesture, canvas pins intact); checkers 0 |
| 7b | Automation on the canvas — edit points there | **NEXT** | — |
| 7 | Automation on the canvas | open | — |

Done before the fixed order: A1 `2c56287` · P1 `8788833` · P2 `1fd0e02` · P3 `2f694fe` (release v10.79.512 = `26be2e6`).

### Measured before item 4 (read-only audit, 2026-10-16)
Lane ORDER is routing, not display: `rollLaneID` = first non-bio MIDI lane (and two inline
copies of that rule: the `rollSlot*` getters in `Timeline.swift`, `EchoelStudioView`'s
`applyLaneOverrides`); voice-rack slots = rank among the non-roll MIDI lanes, capped by
`laneVoiceCapacity` ("top lanes win"); SongMIDIExport channels by MIDI-lane index; video
`programShot` = first video lane with a picture; `AudioImport` lands on the first audio lane.
`structurallyEqual` already treats ORDER as structural, and the player flushes/re-primes on a
rank shift. Council: colour first (display only); reorder second, with the roll lane pinned.

### Item 5 as built (deviation from the plan, measured)
Record always plays the piece from bar 1 and records from bar 1 (`RecordTake.caption`), so a
transport pre-roll "n bars before the record point" would start before tick 0. Built instead: a
click-only count-in BEFORE the one start — `CountInPicker` (menu, Off · 1 bar · 2 bars, key
`record.countInBars`) beside Record; `RecordTakeButton` restarts the one click's bar
(`MetronomeVoice.restartBar()`, or arms it and switches it off again at the take), waits
`bars × 4` beats through `MetronomeVoice.samplesPerBeat`, then `beginTake()` (arm → start). A tap
during the count-in cancels it; music started another way meanwhile records nothing. The wait is a
main-actor sleep; the first transport beat re-anchors the click (≤ ¼ beat absorbed). NEEDS-FOUNDER-VERIFY (A10).

### Item 6 as built
`LaunchTake` (pure) + `TimelineRegionPlayer.recordsLaunches` / `launchTakeSink` + `SessionRecordToggle`
("Record to arrangement", Session grid header) + the app's sink → `TimelineStore.pasteRegions` (one
Undo step per take). The take ends wherever launches die (Stop, external stop, locate, cycle jump,
restart) and at the song's wrap (each wrap = its own Undo step; a part still launched across the wrap
is recorded up to it). NEEDS-FOUNDER-VERIFY (P4b).

### Exact next step (item 7b, edit automation on the canvas)
Measured constraints (read-only audit 2026-10-16): the canvas file may hold exactly ONE
`DragGesture(` and ONE `@GestureState` (`TheArrangeCanvasMovesAPartByDraggingTests`), no `.menu`
Picker (freeze law, ArrangeCanvasView header), and `SongAutomationEditor(` may be mounted only in
the inspector (`TheSongAutomationIsDrawnThroughOneWriterTests`, `TheDetailShowsOnePageAtATimeTests`).
So 7b = an "Edit automation" mode (a cold toggle in the gather bar row): while on, the parts on the
SELECTED track step back and the trace becomes a leaf in its own file that reuses
`SongAutomationEdit.resolveTap` / `resolveMove` / `adding` / `moving` with the canvas's `songTicks`,
for the parameter the Track page opens on (`openingBase`), and commits through
`timeline.setSongAutomation` — one Undo step per gesture. The writer-count pin (4 in the editor file)
does not move; the new leaf is a second file the pin must then name (update it in the same commit).

Device asks for the next release note: A1, P1, P2, P3, A5, A2, A9, A4b, A4c, A10 (all in v10.79.514 = `d6105b9`); next build: P4b, 7a.
