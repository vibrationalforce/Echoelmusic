// TheNoteGridZoomsItsTimeTests.swift
// Echoel — DAW shell S9b (founder 2026-10-02, „Alles auf professionellstem Level"; inbox E16
// „Zeit zoomen" made the pinch a TIME zoom on the arrangement — this is its twin on the Notes page).
//
// WHY: a sixteenth on the note grid was a fixed 22 pt. An eight-bar part is 128 steps, almost
// 2,900 pt of scrolling to see it whole, and 22 pt is half a fingertip when placing a note.
// S9b gives the grid three column widths (`NoteGridZoom`): an overview, the M1 width, and a step
// a finger can hit — through two buttons in the tool row, a two-finger pinch and an assistive
// zoom action, all keeping the step in view where it was.
//
// THE CLAIMS:
// 1. END-TO-END (pure, `NoteGridZoom`): the widths are usable and ordered, the grid opens on a
//    level with room both ways, the widest step is at least a tap target (the button says
//    "easier to tap"), stepping clamps at both ends for any delta, a pinch maps to a level step
//    with a dead zone and never moves on garbage, and the anchored offset keeps the anchored song
//    position in place, stays inside what can scroll, and never returns NaN.
// 2. SOURCE — ONE WIDTH: the grid computes ONE `stepWidth` from the level; the canvas grid, the
//    playhead line, the velocity lane and the tap hit-test all read it; the old static constant
//    is gone; the level is written at ONE place (the zoom step).
// 3. SOURCE — THREE DOORS, NO FINGER-RATE STATE: the two buttons sit in the existing tool row and
//    ask the one stepping rule for their enabled state; the pinch acts ONCE, on release, through
//    `levelDelta(forPinch:)` (no `.updating`, no `.onChanged`, no new `@GestureState`); the
//    assistive zoom action takes the same step; the step writes nothing and reads nothing hot.
//
// KIND (per this directory's §1): claim 1 is END-TO-END on a shipped, pure, nonisolated type;
// claims 2–3 are SOURCE-TEXT scans — `PartNoteGrid` is a private SwiftUI struct no bundle renders.
// They prove where the width is read and which doors step it, never that a pinch feels right.
//
// HONEST GRADING (§3), parent = the tree before S9b: this file names `NoteGridZoom`, which this
// commit creates, so it DOES NOT COMPILE there and no assertion has a verdict. Transcribed in
// Python against both trees instead: claim 1 is FORWARD (drives the new type); claims 2 and 3 are
// red on the parent by ONE ABSENCE (`zoomLevel` / the computed `stepWidth`), reported once (#486);
// the "old constant is gone" and hot-read needles are COUNTERWEIGHTS. Stripper
// `SourceText.codeOnly`: LOAD-BEARING (measured, 1 of the file's verdicts flips): raw, the
// editor's comments name `@GestureState` twice more, so the "no new gesture state" count reads 3
// on a correct tree. Every other verdict reads the same raw and stripped, on both trees.
//
// DEVICE PROBE, open (NEEDS-FOUNDER-VERIFY): a part with notes on the Notes page — "Zoom in"
// widens the columns and the step that was in the middle stays in the middle; at the widest a
// note is easy to tap; "Zoom out" shows the part at a glance; both grey out at their ends; a
// two-finger spread on the grid steps once when the fingers lift, around where they were; a
// note drag, a box-select and the velocity lane still land on the right step at every width.
// Two cases the review of S9b named and only glass can settle: "Zoom in" near the END of a long
// part — does the step stay put, or is the scroll cut to the old, narrower content? And two
// fingers that rest ~0.3 s before spreading can also start the canvas's hold-and-drag, so an
// edit may commit with the zoom (undoable; the S9a canvas has the same limit). A two-finger pan
// during the pinch shifts its anchor by the pan (the release reads the end offset).

import XCTest
@testable import Echoelmusic

final class TheNoteGridZoomsItsTimeTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — END-TO-END: the zoom arithmetic

    func testTheWidthsAreOrderedAndTheGridOpensWithRoomBothWays() {
        let widths = NoteGridZoom.stepWidths
        XCTAssertGreaterThanOrEqual(widths.count, 2, "a zoom needs at least two widths")
        for width in widths {
            XCTAssertTrue(width.isFinite && width > 0, "every column width is a real, positive width")
        }
        XCTAssertEqual(widths, widths.sorted(), "narrow to wide — `Zoom in` is the next index")
        XCTAssertEqual(Set(widths).count, widths.count, "no two levels draw the same width")
        let open = NoteGridZoom.defaultLevel
        XCTAssertGreaterThan(open, 0, "the grid opens with a narrower level to zoom out to")
        XCTAssertLessThan(open, widths.count - 1, "and a wider level to zoom in to — both buttons start enabled")
        guard let widest = widths.last else { return XCTFail("no widths") }
        XCTAssertGreaterThanOrEqual(widest, 44, """
            the widest step is narrower than the 44-pt tap target (`EchoelTheme.controlTapHeight`). \
            The Zoom in button says "wider steps, easier to tap" — at this width that is not true.
            """)
    }

    func testSteppingClampsAtBothEndsForAnyDelta() {
        let last = NoteGridZoom.stepWidths.count - 1
        for level in [-5, 0, NoteGridZoom.defaultLevel, last, last + 9, Int.min, Int.max] {
            for delta in [-1, 0, 1, 2, -2, Int.min, Int.max] {
                let next = NoteGridZoom.level(level, steppedBy: delta)
                XCTAssertTrue((0...last).contains(next), "level \(level) stepped by \(delta) left the list: \(next)")
            }
        }
        XCTAssertEqual(NoteGridZoom.level(0, steppedBy: -1), 0, "Zoom out stops at the narrowest")
        XCTAssertEqual(NoteGridZoom.level(last, steppedBy: 1), last, "Zoom in stops at the widest")
        XCTAssertEqual(NoteGridZoom.level(NoteGridZoom.defaultLevel, steppedBy: 1), NoteGridZoom.defaultLevel + 1)
        XCTAssertEqual(NoteGridZoom.level(NoteGridZoom.defaultLevel, steppedBy: -1), NoteGridZoom.defaultLevel - 1)
        XCTAssertEqual(NoteGridZoom.stepWidth(atLevel: -3), NoteGridZoom.stepWidths.first,
                       "a level below the list reads as the narrowest, never out of bounds")
        XCTAssertEqual(NoteGridZoom.stepWidth(atLevel: last + 3), NoteGridZoom.stepWidths.last,
                       "a level above the list reads as the widest, never out of bounds")
    }

    func testAPinchStepsOnceOutsideItsDeadZoneAndNeverOnGarbage() {
        for still in [1.0, 1.1, 0.9, 1.2, 0.85] {
            XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: still), 0,
                           "a pinch of \(still) is a wobble — it must not change the zoom")
        }
        XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: 2), 1, "a doubling spread is one level in")
        XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: 0.5), -1, "a halving pinch is one level out")
        XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: 1.4), 1, "past the dead zone, at least one level")
        XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: 0.7), -1)
        XCTAssertEqual(NoteGridZoom.levelDelta(forPinch: 4), 2, "two doublings, two levels")
        for garbage in [Double.nan, .infinity, -.infinity, 0, -1, .greatestFiniteMagnitude, .leastNonzeroMagnitude] {
            let delta = NoteGridZoom.levelDelta(forPinch: garbage)
            if !garbage.isFinite || garbage <= 0 {
                XCTAssertEqual(delta, 0, "a pinch reporting \(garbage) moves nothing")
            } else {
                XCTAssertTrue(abs(delta) <= 64, "an extreme but finite pinch stays bounded: \(delta)")
            }
        }
    }

    func testTheAnchoredOffsetKeepsTheStepInViewAndStaysScrollable() {
        let view = 300.0, steps = 128
        let widths = NoteGridZoom.stepWidths
        for old in widths {
            for new in widths {
                for offset in [0.0, 40, 500, 1_000] {
                    for anchor in [0.0, 150, 300] {
                        let result = NoteGridZoom.anchoredOffset(offset, anchor: anchor, from: old, to: new,
                                                                 steps: steps, viewWidth: view)
                        let newMax = Swift.max(0, Double(steps) * new - view)
                        XCTAssertTrue(result.isFinite && result >= 0 && result <= newMax + 1e-9,
                                      "offset \(result) outside 0…\(newMax) (old \(old) → new \(new))")
                        let oldMax = Swift.max(0, Double(steps) * old - view)
                        let start = Swift.min(offset, oldMax)
                        let target = (start + anchor) * new / old - anchor
                        if target >= 0, target <= newMax {
                            // Inside the scrollable range the anchored song position is exact:
                            // the step under the anchor before is the step under it after.
                            XCTAssertEqual((result + anchor) / new, (start + anchor) / old, accuracy: 1e-9,
                                           "the step under the anchor moved (old \(old) → new \(new), offset \(offset), anchor \(anchor))")
                        }
                    }
                }
            }
        }
        for old in widths {
            XCTAssertEqual(NoteGridZoom.anchoredOffset(120, anchor: 150, from: old, to: old, steps: steps, viewWidth: view),
                           Swift.min(120, Swift.max(0, Double(steps) * old - view)), accuracy: 1e-9,
                           "no zoom change, no scroll change")
        }
    }

    func testTheAnchoredOffsetFallsBackToTheLeftEdgeOnUnusableInput() {
        let cases: [(Double, Double, Double, Double, Int, Double)] = [
            (.nan, 150, 22, 44, 128, 300), (100, .nan, 22, 44, 128, 300),
            (100, 150, .nan, 44, 128, 300), (100, 150, 22, .infinity, 128, 300),
            (100, 150, 0, 44, 128, 300), (100, 150, 22, -1, 128, 300),
            (100, 150, 22, 44, 0, 300), (100, 150, 22, 44, -5, 300),
            (100, 150, 22, 44, 128, 0), (100, 150, 22, 44, 128, .nan),
            (.infinity, -.infinity, 22, 44, 128, 300),
        ]
        for (offset, anchor, old, new, steps, view) in cases {
            let result = NoteGridZoom.anchoredOffset(offset, anchor: anchor, from: old, to: new,
                                                     steps: steps, viewWidth: view)
            XCTAssertTrue(result.isFinite && result >= 0, """
                anchoredOffset(\(offset), anchor: \(anchor), \(old) → \(new), steps \(steps), view \(view)) \
                returned \(result) — a scroll position must be finite and never negative
                """)
        }
        XCTAssertEqual(NoteGridZoom.anchoredOffset(100, anchor: 150, from: 22, to: 44, steps: 4, viewWidth: 300), 0,
                       "a part narrower than the view at both widths does not scroll")
    }

    // MARK: 2 — SOURCE: one width, one writer of the level

    func testTheGridReadsOneWidthFromTheLevel() throws {
        let code = SourceText.codeOnly(try text(Self.editor))
        XCTAssertEqual(occurrences("private var stepWidth: CGFloat { CGFloat(NoteGridZoom.stepWidth(atLevel: zoomLevel)) }", in: code), 1,
                       "the grid computes ONE column width from the zoom level")
        XCTAssertFalse(code.contains("Self.stepWidth"), "a reader still takes the old fixed width — it would not follow the zoom")
        XCTAssertFalse(code.contains("static let stepWidth"), "the fixed 22-pt constant is back beside the zoomed width — two widths")
        for (needle, who) in [
            ("stepWidth: Double(stepWidth), rowHeight: Double(Self.rowHeight),", "the canvas grid (notes, drag, box)"),
            ("stepWidth: stepWidth)", "the playhead line"),
            ("stepWidth: stepWidth, editable: editable,", "the velocity lane"),
            ("stepW: Double(stepWidth), rowH: Double(Self.rowHeight),", "the tap hit-test"),
        ] {
            XCTAssertEqual(occurrences(needle, in: code), 1, "\(who) reads the one zoomed width")
        }
        let grid = try member("private struct PartNoteGrid: View {", in: code)
        XCTAssertTrue(grid.contains("@State private var zoomLevel = NoteGridZoom.defaultLevel"),
                      "the level is view state of the open grid, starting at the default")
        let writes = matches(#"\bzoomLevel\s*[-+*/]?=(?!=)"#, in: grid)
        XCTAssertEqual(writes, 2, """
            `zoomLevel` is assigned \(writes - 1) time(s) besides its declaration. The zoom step is the \
            one writer — every door goes through it, so every door keeps the step in view.
            """)
        let step = try member("private func zoom(by delta: Int, steps: Int, anchor: CGFloat) {", in: grid)
        XCTAssertTrue(step.contains("zoomLevel = next"), "the one write sits in the zoom step")
        XCTAssertTrue(step.contains("NoteGridZoom.anchoredOffset("), "the step keeps the song position in view")
        XCTAssertTrue(step.contains("position.scrollTo(x: CGFloat(offset))"), "and scrolls there")
    }

    // MARK: 3 — SOURCE: three doors, no finger-rate state, nothing written

    func testTheThreeDoorsStepTheZoomAndNothingRedrawsAtFingerRate() throws {
        let code = SourceText.codeOnly(try text(Self.editor))
        let grid = try member("private struct PartNoteGrid: View {", in: code)
        // The tail of `controls(range:picked:editable:region:steps:)`'s signature — unique in the file (#408).
        let controls = try member("region: TimelineRegion, steps: Int) -> some View {", in: grid)
        let flow = try member("NoteToolFlow(spacing: EchoelTheme.spaceS) {", in: controls)
        for (word, delta, symbol) in [("Zoom out", "-1", "minus.magnifyingglass"), ("Zoom in", "1", "plus.magnifyingglass")] {
            guard let button = flow.range(of: "button(\"\(word)\", \"\(symbol)\",") else {
                XCTFail("`\(word)` is not a button in the note tool row — the zoom needs a one-finger way (WCAG 2.5.1)")
                continue
            }
            let rest = String(flow[button.upperBound...])
            XCTAssertTrue(rest.contains("enabled: NoteGridZoom.level(zoomLevel, steppedBy: \(delta)) != zoomLevel"),
                          "`\(word)` greys out exactly where the one stepping rule would not move (#416)")
            XCTAssertTrue(rest.contains("zoom(by: \(delta), steps: steps, anchor: viewport.width / 2)"),
                          "`\(word)` steps around the middle of the view through the one zoom step")
        }
        guard let pinch = grid.range(of: "MagnifyGesture()") else {
            return XCTFail("the grid's pinch is gone")
        }
        let afterPinch = String(grid[pinch.upperBound...].prefix(400))
        XCTAssertTrue(afterPinch.hasPrefix(".onEnded { value in"), """
            the pinch acts at release only. A `.updating` or `.onChanged` here is finger-rate work on \
            the WHOLE grid (it reads the stores) — the leaf law says finger-rate state lives in a leaf
            """)
        // The whole gesture expression — up to the tool row that follows it — so a `.updating` or
        // `.onChanged` chained AFTER the release closure is caught too (review of S9b, LOW-5).
        let gestureExpression = afterPinch.components(separatedBy: "controls(range:").first ?? afterPinch
        for fingerRate in [".onChanged", ".updating"] {
            XCTAssertFalse(gestureExpression.contains(fingerRate),
                           "the pinch carries `\(fingerRate)` — finger-rate work on the whole grid")
        }
        XCTAssertTrue(afterPinch.contains("zoom(by: NoteGridZoom.levelDelta(forPinch: Double(value.magnification)),"),
                      "the pinch takes the pure dead-zoned step, through the one zoom step")
        XCTAssertTrue(afterPinch.contains("anchor: value.startAnchor.x * viewport.width)"),
                      "around where the fingers started")
        XCTAssertEqual(occurrences("MagnifyGesture()", in: code), 1, "one pinch on the grid")
        XCTAssertEqual(occurrences("@GestureState", in: code), 1,
                       "counterweight: the file's one `@GestureState` stays the canvas's drag — the zoom added none")
        XCTAssertTrue(grid.contains(".accessibilityZoomAction { action in")
                      && grid.contains("zoom(by: action.direction == .zoomIn ? 1 : -1, steps: steps,"),
                      "an assistive zoom takes the same step")
        let step = try member("private func zoom(by delta: Int, steps: Int, anchor: CGFloat) {", in: grid)
        for banned in ["setClipNotes", "UserDefaults", "@AppStorage", "timeline.", "clipStore.", "session.",
                       "player.", "transport.", "currentTick"] {
            XCTAssertFalse(step.contains(banned), """
                the zoom step touches `\(banned)`. A zoom is a VIEW of the part: it writes nothing, is \
                not on Undo, is not saved, and reads nothing hot.
                """)
        }
        XCTAssertTrue(grid.contains("private final class GridViewport {"),
                      "the scroll position lands in a reference SwiftUI does not observe — scrolling rebuilds nothing")
    }

    // MARK: helpers

    private func occurrences(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func matches(_ pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            XCTFail("bad pattern \(pattern)")
            return -1
        }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
