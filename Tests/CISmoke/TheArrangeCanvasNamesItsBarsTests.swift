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
// 3. SOURCE: the canvas mounts it once, above the lanes, behind an empty gutter of the lanes'
//    own name width — so its numbers start where the blocks do. That the canvas as a whole stays
//    cold is pinned ONCE, by `TheSongIsSeenOnOneScaleTests` (the ruler sits inside that slice).
//
// Grading (§0, no Swift toolchain): `rulerMarks` and `ArrangeBarRuler` do not exist on the parent
// (`82ee9350b`), so this file does not compile there — every claim is a FORWARD guard, one
// absence (#486). Claim 1 was transcribed into Python and driven on the cases below; claims 2 and
// 3 transcribed against this tree: green.
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
        guard let canvas = file.range(of: "struct ArrangeCanvasView: View {"),
              let gutter = file.range(of: "Color.clear.frame(width: Self.nameWidth, height: 1)",
                                      range: canvas.upperBound..<file.endIndex),
              let mount = file.range(of: "ArrangeBarRuler(songTicks: songTicks)", range: canvas.upperBound..<file.endIndex),
              let lanes = file.range(of: "ForEach(rows) { row in", range: canvas.upperBound..<file.endIndex) else {
            return XCTFail("the canvas no longer mounts `ArrangeBarRuler` behind an empty name gutter, before its lanes")
        }
        XCTAssertLessThan(gutter.lowerBound, mount.lowerBound,
                          "the empty gutter comes first, so the numbers start where the lanes do")
        XCTAssertLessThan(mount.lowerBound, lanes.lowerBound, "the ruler sits above the lanes")
    }

    // MARK: helpers

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
