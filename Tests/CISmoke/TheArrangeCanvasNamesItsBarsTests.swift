// TheArrangeCanvasNamesItsBarsTests.swift
// Echoel — modes census 2026-09-26, design slice 1: the Arrange canvas names its bars.
//
// WHAT THIS PINS. The canvas showed WHERE parts sit and nothing said at WHICH bar — the unit the
// part bar, the parts list and the song-position readout all speak in. A ruler of bar numbers
// now runs above the lanes, on the blocks' own scale.
//
// 1. END-TO-END BEHAVIOUR (`ArrangeCanvas.rulerMarks`, pure): bar 1 and then every power-of-two
//    step that keeps two numbers at least `minSpacing` apart; every number on a downbeat; the
//    song's end unnamed; degenerate geometry names nothing.
// 2. SOURCE: `ArrangeBarRuler` is cold (no position, store, selection, clock or tap), hidden from
//    VoiceOver, untappable, and its spacing scales with the text.
// 3. SOURCE: the canvas mounts it once, above the lanes, in the SAME zoomed column as the lanes
//    (DAW shell S9a) — so its numbers stay on their bars at every zoom — while the names stand
//    still in their own column, level with their lanes (one `rulerHeight`, one `rowHeight`).
//    That the canvas as a whole stays cold is pinned ONCE, by `TheSongIsSeenOnOneScaleTests`
//    (the ruler sits inside that slice); where the pinch lives, by `ThePinchZoomsTheArrangementsTimeTests`.
//
// Grading (§0, no Swift toolchain): `rulerMarks` and `ArrangeBarRuler` do not exist on the parent
// (`82ee9350b`), so this file does not compile there — every claim was a FORWARD guard, one
// absence (#486). Re-graded after the review repair `645b056c0` (parent `292a932af`): the 8½-bar
// fractions and the 41-bar list are REGRESSIONS there (red for their named reason: whole-bar
// division, a spilled last number); "bar 1 on a 10 pt lane" and the row-spacing, closing-brace
// and trailing-modifier pins are COUNTERWEIGHTS (green there). Claim 1 transcribed into Python
// and driven on the cases below; claims 2 and 3 transcribed against this tree with mutants.
// S9a RE-PIN (parent `88058461d`): claim 3's two-row shape (an empty `nameWidth` gutter beside
// the ruler, then name + lane per row) became two COLUMNS. The new sequence is red on the parent
// by ANCHOR ABSENCE (`ArrangeTimeZoom`, `rulerHeight` — one absence, #486); it is STRICTER than
// the one it replaces — it adds the column order, both stacks' spacing, the name's row height,
// that nothing but the lanes follows the ruler, one scaled ruler height read twice, the ruler's
// own frame and the lane's height. Transcribed against this tree with mutants (ruler padding,
// a second ruler height, a dropped name height, the ruler moved out of the zoom: each red).
// NOT covered: that the numbers line up with the blocks on glass and stay legible at the largest
// text sizes — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation with an 8-bar song → the numbers 1…8 sit above the lanes, each
// on the left edge of its bar, and a part moved "one bar later" lands under the next number; at
// the largest text size the numbers thin out instead of overlapping.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArrangeCanvasNamesItsBarsTests: XCTestCase {

    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — which bars are named, pure

    func testEveryBarIsNamedWhenThereIsRoom() {
        let marks = ArrangeCanvas.rulerMarks(songTicks: 8 * Self.bar, laneWidth: 320, minSpacing: 28)
        XCTAssertEqual(marks.map(\.bar), [1, 2, 3, 4, 5, 6, 7, 8],
                       "40 pt per bar leaves room for every number; the song's end is not a bar")
        XCTAssertEqual(marks.map(\.fraction), [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875])
    }

    func testALongSongThinsItsNumbersByPowersOfTwo() {
        let marks = ArrangeCanvas.rulerMarks(songTicks: 64 * Self.bar, laneWidth: 320, minSpacing: 28)
        XCTAssertEqual(marks.map(\.bar), [1, 9, 17, 25, 33, 41, 49, 57],
                       "5 pt per bar: 2, 4 bars are too close, 8 bars (40 pt) is the first step that fits")
        for (a, b) in zip(marks, marks.dropFirst()) {
            XCTAssertGreaterThanOrEqual((b.fraction - a.fraction) * 320, 28,
                                        "two numbers never sit closer than the spacing asked for")
        }
        for mark in marks {
            XCTAssertEqual(mark.fraction * Double(64 * Self.bar), Double((mark.bar - 1) * Self.bar),
                           accuracy: 1e-6, "bar \(mark.bar) is drawn on its own downbeat")
        }
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 3 * Self.bar, laneWidth: 30, minSpacing: 28).map(\.bar), [1],
                       "a song too short for a second number still names its first bar")
    }

    func testTheRulerSharesTheBlocksScaleAndStaysOnTheLane() {
        // Review of d16d764b1, LOW-1: 8½ bars — the blocks divide by the song's ticks, so must
        // the ruler, or every number drifts off its downbeat.
        let half = 8 * Self.bar + Self.bar / 2
        let marks = ArrangeCanvas.rulerMarks(songTicks: half, laneWidth: 340, minSpacing: 28)
        XCTAssertEqual(marks.map(\.bar), [1, 2, 3, 4, 5, 6, 7, 8])
        for mark in marks {
            XCTAssertEqual(mark.fraction, Double((mark.bar - 1) * Self.bar) / Double(half), accuracy: 1e-12,
                           "bar \(mark.bar) sits where a part starting on it is drawn")
        }
        // LOW-2: 41 bars on 250 pt steps by 8; bar 41 would sit 6 pt from the end — left out.
        let long = ArrangeCanvas.rulerMarks(songTicks: 41 * Self.bar, laneWidth: 250, minSpacing: 28)
        XCTAssertEqual(long.map(\.bar), [1, 9, 17, 25, 33])
        for mark in long.dropFirst() {
            XCTAssertLessThanOrEqual(mark.fraction * 250 + 28, 250, "no number spills past the lane")
        }
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: Self.bar, laneWidth: 10, minSpacing: 28).map(\.bar), [1],
                       "bar 1 is always named, even on a lane too narrow for it")
    }

    func testDegenerateGeometryNamesNothing() {
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 0, laneWidth: 320, minSpacing: 28), [])
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: Self.bar - 1, laneWidth: 320, minSpacing: 28), [],
                       "less than one bar is no bar")
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 8 * Self.bar, laneWidth: 0, minSpacing: 28), [])
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 8 * Self.bar, laneWidth: .nan, minSpacing: 28), [])
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 8 * Self.bar, laneWidth: 320, minSpacing: 0), [])
        XCTAssertEqual(ArrangeCanvas.rulerMarks(songTicks: 8 * Self.bar, laneWidth: 320, minSpacing: .infinity), [])
    }

    // MARK: 2 — the ruler is cold and silent

    func testTheRulerIsColdHiddenAndScaled() throws {
        let file = try source(Self.canvasPath)
        guard let start = file.range(of: "struct ArrangeBarRuler: View {"),
              let end = file.range(of: "struct ArrangePlayheadView: View {", range: start.upperBound..<file.endIndex) else {
            return XCTFail("ANCHOR MISSING: `ArrangeBarRuler` before `ArrangePlayheadView` (#454)")
        }
        let ruler = String(file[start.upperBound..<end.lowerBound])
        XCTAssertTrue(ruler.contains("ArrangeCanvas.rulerMarks(songTicks: songTicks, laneWidth: width,"),
                      "the numbers come from the one pure rule, on the lane's own width")
        XCTAssertTrue(ruler.contains("minSpacing: labelSpacing)"))
        XCTAssertTrue(ruler.contains("@ScaledMetric(relativeTo: .body) private var labelSpacing"),
                      "the spacing grows with the text, so large sizes thin the numbers instead of colliding them")
        XCTAssertTrue(ruler.contains(".accessibilityHidden(true)"),
                      "every part already speaks its bar; bare numbers between the rows are noise to VoiceOver")
        XCTAssertTrue(ruler.contains(".allowsHitTesting(false)"), "a tap on the ruler reaches nothing")
        for banned in ["currentTick", "player", "timeline", "selection", "TimelineView(", "Button(",
                       "onTapGesture", "@State"] {
            XCTAssertFalse(ruler.contains(banned),
                           "`ArrangeBarRuler` contains `\(banned)` — it reads the song length it is handed and nothing else")
        }
    }

    // MARK: 3 — mounted once, above the lanes, aligned with them

    func testTheCanvasMountsTheRulerAboveItsLanes() throws {
        let file = try source(Self.canvasPath)
        XCTAssertEqual(file.components(separatedBy: "ArrangeBarRuler(").count - 1, 1, "one ruler on the canvas")
        // Review of d16d764b1, LOW-3: every search is bounded by the canvas struct. Since S9a the
        // gutter is the spacing between the TWO COLUMNS (the still names, the zoomed time), and the
        // ruler sits in the time column above the lanes, so a number cannot shift off its bar by a
        // gutter mismatch any more — what keeps a name beside its lane is the shared heights below.
        guard let canvas = file.range(of: "struct ArrangeCanvasView: View {"),
              let canvasEnd = file.range(of: "struct ArrangeBarRuler: View {", range: canvas.upperBound..<file.endIndex) else {
            return XCTFail("ANCHOR MISSING: `ArrangeCanvasView` before `ArrangeBarRuler` (#454)")
        }
        let body = String(file[canvas.upperBound..<canvasEnd.lowerBound])
        // Token sequences with ONLY whitespace between them, so a re-indent is not a regression
        // and each token exists verbatim in the source.
        // DAW shell S9a: TWO COLUMNS in one sequence. The names stand still on the left — an
        // empty cell of the ruler's height, then each name at the lane's height — and the ruler
        // and the lanes share ONE zoomed column on the right, the ruler first. One sequence, so
        // the two columns sit side by side with the same spacing and nothing between them.
        guard sequence(["HStack(alignment: .top, spacing: Self.gutter) {",
                                      "VStack(spacing: 4) {",
                                      "Color.clear.frame(width: Self.nameWidth, height: rulerHeight)",
                                      "ForEach(rows) { row in", "nameGutter(row)",
                                      ".frame(height: Self.rowHeight)", "}", "}",
                                      "ArrangeTimeZoom {", "VStack(spacing: 4) {",
                                      "ArrangeBarRuler(songTicks: songTicks, height: rulerHeight)",
                                      "ForEach(rows) { row in", "laneRow(row, selected: selected)", "}", "}"],
                                     in: body) != nil else {
            return XCTFail("""
                the canvas is no longer a still name column (an empty `rulerHeight` cell, then \
                each `nameGutter` at `rowHeight`) beside ONE `ArrangeTimeZoom` column that holds \
                the ruler above the lanes, both stacked with spacing 4 — so a name can leave its \
                lane, or a number its bar, when the time zooms
                """)
        }
        // The ruler is followed by NOTHING but the lanes (the sequence allows only whitespace
        // between them) — the review of 645b056c0, LOW-8, as a consequence of the shape: a
        // `.padding(.leading, …)` on the ruler breaks the sequence and lands in the XCTFail above.
        // Both columns stack the SAME heights: one scaled `rulerHeight`, declared once and read
        // by both the empty cell and the ruler's frame; and every lane is `rowHeight` tall, as
        // every name is.
        XCTAssertEqual(body.components(separatedBy: "@ScaledMetric(relativeTo: .body) private var rulerHeight: CGFloat").count - 1, 1,
                       "one ruler height on the canvas, scaled with the text")
        XCTAssertEqual(body.components(separatedBy: "rulerHeight").count - 1, 3,
                       "declared once, read by the empty cell and by the ruler — no third reader, no second value")
        guard let rulerStart = file.range(of: "struct ArrangeBarRuler: View {"),
              let rulerEnd = file.range(of: "struct ArrangePlayheadView: View {",
                                        range: rulerStart.upperBound..<file.endIndex) else {
            return XCTFail("ANCHOR MISSING: `ArrangeBarRuler` before `ArrangePlayheadView` (#454)")
        }
        let ruler = String(file[rulerStart.upperBound..<rulerEnd.lowerBound])
        XCTAssertTrue(ruler.contains("    let height: CGFloat\n"), "the ruler takes its height from the canvas")
        XCTAssertTrue(ruler.contains(".frame(height: height)"), "and is exactly that tall")
        XCTAssertFalse(ruler.contains("@ScaledMetric(relativeTo: .body) private var height"),
                       "a second scaled height in the ruler could differ from the names' empty cell")
        guard let lane = body.range(of: "private func laneRow("),
              let laneEnd = body.range(of: "private func drop(", range: lane.upperBound..<body.endIndex) else {
            return XCTFail("ANCHOR MISSING: `laneRow` before `drop` (#454)")
        }
        XCTAssertEqual(body[lane.upperBound..<laneEnd.lowerBound].components(separatedBy: ".frame(height: Self.rowHeight)").count - 1, 1,
                       "every lane is `rowHeight` tall, the height of the name beside it")
        guard let gutter = body.range(of: "private func nameGutter(_ row: WorkstationSummary.LaneRow) -> some View {"),
              let gutterEnd = body.range(of: "private func laneRow(", range: gutter.upperBound..<body.endIndex) else {
            return XCTFail("ANCHOR MISSING: `nameGutter` before `laneRow` (#454)")
        }
        // Review of 94395338f, LOW-5: the width must close the gutter's OUTER stack. On the `Text`
        // alone, a symbol-led row would be 3 pt + the symbol wider than the names column's empty
        // ruler cell (`nameWidth`), and the time column would start at a different x per row.
        let gutterBody = String(body[gutter.upperBound..<gutterEnd.lowerBound])
        XCTAssertNotNil(sequence([".lineLimit(1)", "}", ".frame(width: Self.nameWidth, alignment: .leading)"],
                                 in: gutterBody),
                        "the gutter's whole stack — symbol and name — keeps the width of the names column's empty ruler cell")
        XCTAssertEqual(gutterBody.components(separatedBy: "Self.nameWidth").count - 1, 1,
                       "one width in the gutter, on its outer stack")
    }

    // MARK: helpers

    /// Where `tokens` occur in order with nothing but whitespace between them, or nil.
    private func sequence(_ tokens: [String], in text: String) -> Range<String.Index>? {
        var from = text.startIndex
        while let first = text.range(of: tokens[0], range: from..<text.endIndex) {
            var end = first.upperBound
            var matched = true
            for token in tokens.dropFirst() {
                guard let next = text.range(of: token, range: end..<text.endIndex),
                      text[end..<next.lowerBound].allSatisfy(\.isWhitespace) else { matched = false; break }
                end = next.upperBound
            }
            if matched { return first.lowerBound..<end }
            from = first.upperBound
        }
        return nil
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
