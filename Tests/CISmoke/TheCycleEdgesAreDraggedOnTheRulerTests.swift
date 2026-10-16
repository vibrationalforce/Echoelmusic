// TheCycleEdgesAreDraggedOnTheRulerTests.swift
// A2 (founder 2026-10-16, gap list item 2 "Cycle-Bereich ziehen"): while a cycle plays, its band
// on the ruler carries a grip at each edge. Dragging a grip moves that edge to the nearest bar
// line; lifting writes the new range once — one `.cycle` Undo step. Before, the range was fixed
// by the Cycle button's proposal and could only be turned off and on again.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on the pure `CycleDrag` (snapping, the one-bar minimum, the piece's
//     bounds, the whole-piece refusal).
//   · Claim 3 is a SOURCE-TEXT SCAN: the grips are their own view mounted by the ruler row (whose
//     law forbids a drag in the row itself), they preview locally and write once on lift, and they
//     are gated on the row's lock.
//   · NOT CLAIMED (DEVICE PROBE): that the grip's drag wins over the ruler's hold-and-slide scrub
//     and that a plain tap on a grip still locates. NEEDS-FOUNDER-VERIFY (A2) — the probe is at
//     `ArrangeCycleHandles.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`CycleDrag` and
// `ArrangeCycleHandles` are new), so no assertion has a verdict on the parent. Hand-transcribed:
// claims 1–2 are the CAPABILITY plus COUNTERWEIGHTS (an edge never crosses the other, a range never
// leaves the piece, the whole piece is refused because it already loops); claim 3 is a FORWARD
// guard. Mutants: floor instead of round (1) · no one-bar minimum (2) · end past the piece (2) ·
// a write per drag frame (3) · the drag moved into the row (3) · no lock (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheCycleEdgesAreDraggedOnTheRulerTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — a finger names the nearest bar line

    func testAFingerNamesTheNearestBarLine() {
        let bar = Self.bar
        let song = 8 * bar
        XCTAssertEqual(CycleDrag.barLine(atX: 0, laneWidth: 800, songTicks: song), 0)
        XCTAssertEqual(CycleDrag.barLine(atX: 240, laneWidth: 800, songTicks: song), 2 * bar,
                       "2.4 bars rounds to the line at bar 3's start — the nearest, not the floor")
        XCTAssertEqual(CycleDrag.barLine(atX: 270, laneWidth: 800, songTicks: song), 3 * bar,
                       "2.7 bars rounds up")
        XCTAssertEqual(CycleDrag.barLine(atX: 5_000, laneWidth: 800, songTicks: song), 8 * bar,
                       "past the right edge is the canvas's last line")
        XCTAssertEqual(CycleDrag.barLine(atX: -30, laneWidth: 800, songTicks: song), 0)
        XCTAssertNil(CycleDrag.barLine(atX: .nan, laneWidth: 800, songTicks: song))
        XCTAssertNil(CycleDrag.barLine(atX: 10, laneWidth: 0, songTicks: song))
        XCTAssertNil(CycleDrag.barLine(atX: 10, laneWidth: 800, songTicks: bar / 2))
    }

    // MARK: 2 — an edge moves, never across the other, never out of the piece

    func testAnEdgeMovesWithinThePieceAndKeepsOneBar() {
        let bar = Self.bar
        let loop = 16 * bar
        let window = (4 * bar)..<(8 * bar)
        XCTAssertEqual(CycleDrag.dragged(window, edge: .end, toTick: 10 * bar, loopTicks: loop),
                       TimelineCycle(startTick: 4 * bar, endTick: 10 * bar), "the right edge moves right")
        XCTAssertEqual(CycleDrag.dragged(window, edge: .start, toTick: 2 * bar, loopTicks: loop),
                       TimelineCycle(startTick: 2 * bar, endTick: 8 * bar), "the left edge moves left")
        XCTAssertEqual(CycleDrag.dragged(window, edge: .start, toTick: 12 * bar, loopTicks: loop),
                       TimelineCycle(startTick: 7 * bar, endTick: 8 * bar),
                       "the left edge stops one bar before the right — a cycle is at least a bar")
        XCTAssertEqual(CycleDrag.dragged(window, edge: .end, toTick: 0, loopTicks: loop),
                       TimelineCycle(startTick: 4 * bar, endTick: 5 * bar))
        XCTAssertEqual(CycleDrag.dragged(window, edge: .end, toTick: 40 * bar, loopTicks: 12 * bar),
                       TimelineCycle(startTick: 4 * bar, endTick: 12 * bar), "the right edge stops at the piece's end")
        XCTAssertNil(CycleDrag.dragged(0..<(8 * bar), edge: .end, toTick: 16 * bar, loopTicks: loop),
                     "a range covering the whole piece is no cycle — the piece already loops")
        XCTAssertNil(CycleDrag.dragged(window, edge: .end, toTick: 6 * bar, loopTicks: bar),
                     "a one-bar piece has nothing to cycle")
    }

    // MARK: 3 — its own view, previewed locally, written once on lift, locked with the row

    func testTheGripsAreTheirOwnViewAndWriteOnceOnLift() throws {
        let ruler = try source("Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift")
        XCTAssertEqual(ruler.components(separatedBy: "ArrangeCycleHandles(document: document, songTicks: songTicks, laneWidth: width,").count - 1, 1,
                       "the ruler row mounts the grips once")
        XCTAssertTrue(ruler.contains("height: height, locked: locked)"), "with the row's own lock")
        let handles = try source("Sources/Echoelmusic/Studio/ArrangeCycleHandles.swift")
        XCTAssertTrue(handles.contains("@State private var preview: TimelineCycle?"), "the range under the finger is local")
        guard let ended = handles.range(of: ".onEnded { _ in"),
              let changed = handles.range(of: ".onChanged { value in") else {
            return XCTFail("ANCHOR MISSING: the grip's drag phases (#408)")
        }
        XCTAssertLessThan(changed.lowerBound, ended.lowerBound)
        XCTAssertEqual(handles.components(separatedBy: "timeline.setCycle(").count - 1, 1, "one write")
        XCTAssertFalse(handles[changed.lowerBound..<ended.lowerBound].contains("setCycle"),
                       "never a write per drag frame — one Undo step per drag")
        XCTAssertTrue(handles[ended.upperBound...].contains("if let next = preview { timeline.setCycle(next) }"))
        XCTAssertTrue(handles.contains("if !locked, let committed = document.cycle?.window(loopTicks: loopTicks),"),
                      "no grips while a take records or a bounce runs")
        XCTAssertFalse(handles.contains("currentTick"), "cold: the playhead is a leaf of its own")
        XCTAssertFalse(handles.contains("EchoelTheme.accent"), "never green — green is the body's signal")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
