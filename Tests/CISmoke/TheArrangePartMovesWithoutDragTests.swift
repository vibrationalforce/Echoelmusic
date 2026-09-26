// TheArrangePartMovesWithoutDragTests.swift
// Echoel — modes census 2026-09-26, UX F2: a part on the Arrange canvas moves without a drag.
//
// WHAT THIS PINS. Moving a part on the canvas was hold-and-slide only (WA4 path D). A drag
// cannot be performed with VoiceOver or Switch Control, so a whole user group could select a
// part there and never move it. Each block now carries two named actions — "Move one bar
// earlier" / "Move one bar later" — and they must be the drag's TWIN, not a second opinion:
//
// 1. PURE: the step the actions take is the part bar's own — `TrackParts.earlierStart` is nil
//    at the song's top (so "earlier" is not offered there), never lands before 0, and
//    `laterStart` is one bar.
// 2. SOURCE: the block offers "earlier" only where `startTick > 0`, and both actions report
//    through `onStep` — the leaf still owns no store, no selection and no clock.
// 3. SOURCE: the canvas lands a step through `drop` — the one `TrackParts.move` commit (select,
//    refuse a no-move, one undo step) — using the part bar's step, never tick maths of its own.
//
// Grading (§0, no Swift toolchain in a web session): claims transcribed into Python against
// this tree. On the parent (4884c7a47) the block has no `onStep`, so claims 2–3 are red there
// and claim 1 is green (it pins existing behaviour the actions rely on) — FORWARD guards.
// Counterweights that the canvas stays cold and commits once live in
// `TheArrangeCanvasMovesAPartByDraggingTests`, unchanged.
// NOT covered: that VoiceOver reads the actions well on glass — a device probe.
// NEEDS-FOUNDER-VERIFY: VoiceOver on, Workstation, a track with a part — focus the part, swipe
// up/down to "Move one bar later", double-tap: it moves one bar and stays selected; Undo puts
// it back. On a part at bar 1 the "earlier" action is not offered.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArrangePartMovesWithoutDragTests: XCTestCase {

    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the step is the part bar's own

    func testTheStepIsThePartBarsOneBarStep() {
        func part(at tick: Int) -> TrackParts.Part {
            TrackParts.Part(id: UUID(), startTick: tick, lengthTicks: Self.bar)
        }
        XCTAssertNil(TrackParts.earlierStart(part(at: 0)),
                     "a part at the song's top has no bar earlier — the action is not offered there")
        XCTAssertEqual(TrackParts.earlierStart(part(at: 3 * Self.bar)), 2 * Self.bar)
        XCTAssertEqual(TrackParts.earlierStart(part(at: Self.bar / 2)), 0,
                       "an off-grid part near the top lands on the top, never before it")
        XCTAssertEqual(TrackParts.laterStart(part(at: 3 * Self.bar)), 4 * Self.bar)
    }

    // MARK: 2 — the leaf offers the actions and reports them

    func testTheBlockOffersBothMovesAsNamedActions() throws {
        let file = try source(Self.canvasPath)
        guard let blockStart = file.range(of: "struct ArrangePartBlock: View {") else {
            return XCTFail("ANCHOR MISSING: `struct ArrangePartBlock: View {` (#454)")
        }
        let block = String(file[blockStart.upperBound...])
        XCTAssertTrue(block.contains("let onStep: (Bool) -> Void"), "the leaf reports a step, it does not take one")
        guard let actions = block.range(of: ".accessibilityActions {"),
              let gate = block.range(of: "if startTick > 0 {"),
              let earlier = block.range(of: "Button(\"Move one bar earlier\") { onStep(false) }"),
              let later = block.range(of: "Button(\"Move one bar later\") { onStep(true) }") else {
            return XCTFail("the part block no longer offers both named moves through `onStep`")
        }
        XCTAssertTrue(actions.upperBound <= gate.lowerBound && gate.upperBound <= earlier.lowerBound,
                      "\"earlier\" is offered only where a bar earlier exists")
        XCTAssertLessThan(earlier.lowerBound, later.lowerBound)
        for banned in ["TrackParts.", "timeline", "selection", "ticksPerBar"] {
            XCTAssertFalse(block.contains(banned), """
                `ArrangePartBlock` contains `\(banned)`. The leaf names the move; the canvas \
                decides where it lands and commits it.
                """)
        }
    }

    // MARK: 3 — the canvas lands a step through the drag's one commit

    func testTheCanvasLandsAStepThroughTheDropCommit() throws {
        let file = try source(Self.canvasPath)
        XCTAssertTrue(file.contains("onStep: { later in step(block.id, onLane: row.id, later: later) })"),
                      "each block's step reaches the canvas's `step`")
        guard let head = file.range(of: "private func step(_ regionID: UUID, onLane laneID: UUID, later: Bool) {"),
              let blockStart = file.range(of: "struct ArrangePartBlock: View {"),
              head.upperBound < blockStart.lowerBound else {
            return XCTFail("ANCHOR MISSING: the canvas's `step` before `ArrangePartBlock` (#454)")
        }
        let step = String(file[head.upperBound..<blockStart.lowerBound])
        XCTAssertTrue(step.contains("TrackParts.laterStart(part)") && step.contains("TrackParts.earlierStart(part)"),
                      "the step is the part bar's own (#416)")
        XCTAssertTrue(step.contains("drop(regionID, onLane: laneID, from: part.startTick, to: target)"),
                      "a step lands through `drop` — select, refuse a no-move, ONE `TrackParts.move`")
        for banned in ["TrackParts.move(", "ticksPerBar", "stepTicks", "moveRegion("] {
            XCTAssertFalse(step.contains(banned), """
                the canvas's `step` contains `\(banned)`. It asks the part bar for the target and \
                lands through `drop`; a second commit site or its own tick maths is a second \
                opinion about where a part goes.
                """)
        }
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
