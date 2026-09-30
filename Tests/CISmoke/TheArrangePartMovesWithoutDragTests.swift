// TheArrangePartMovesWithoutDragTests.swift
// Echoel — modes census 2026-09-26, UX F2: a part on the Arrange canvas moves without a drag.
//
// WHAT THIS PINS. Moving a part on the canvas was hold-and-slide only (WA4 path D). A drag
// cannot be performed with VoiceOver or Switch Control, so such a user could move a part only
// by selecting it and then finding the part bar below (`SelectedPartBar`'s labelled move
// buttons — that door stays and is NOT unreachable). Each block now carries two named actions
// — "Move one bar earlier" / "Move one bar later" — putting the move on the part itself, and
// they must be the drag's TWIN, not a second opinion:
//
// (The step itself — nil at the song's top, never before 0, one bar later — is pinned ONCE, by
// `TheTrackPartsAreArrangedThroughTheStoreTests.testAOneBarMoveNeverLeavesTheSong`; #416.)
// 1. SOURCE: the block offers "earlier" only inside `if startTick > 0 { … }` and "later"
//    OUTSIDE it, both reporting through `onStep` — the leaf owns no store, selection or clock.
// 2. SOURCE: the canvas lands a step through `drop` — the one `TrackParts.move` commit (select,
//    refuse a no-move, one undo step) — using the part bar's step, never tick maths of its own,
//    and then ANNOUNCES the landing (VoiceOver does not re-read a changed label).
//
// Grading (§0, no Swift toolchain in a web session): claims transcribed into Python against
// this tree. On the parent (4884c7a47) the block has no `onStep`, so both claims are red there
// — FORWARD guards (one absence, #486).
// Counterweights that the canvas stays cold and commits once live in
// `TheArrangeCanvasMovesAPartByDraggingTests`, unchanged.
// NOT covered: that VoiceOver reads the actions well on glass — a device probe.
// NEEDS-FOUNDER-VERIFY: VoiceOver on, Workstation, a track with a part — focus the part, swipe
// up/down to "Move one bar later", double-tap: it moves one bar, stays selected, and VoiceOver
// says "Part at Bar N"; Undo puts it back. On a part at bar 1 the "earlier" action is not offered.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArrangePartMovesWithoutDragTests: XCTestCase {

    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    // MARK: 1 — the leaf offers the actions and reports them

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
        XCTAssertTrue(block[earlier.upperBound..<later.lowerBound].contains("}"), """
            "Move one bar later" sits inside the `if startTick > 0` gate — a part at bar 1 would \
            then offer no move at all. Only "earlier" is gated.
            """)
        for banned in ["TrackParts.", "timeline", "selection", "ticksPerBar"] {
            XCTAssertFalse(block.contains(banned), """
                `ArrangePartBlock` contains `\(banned)`. The leaf names the move; the canvas \
                decides where it lands and commits it.
                """)
        }
    }

    // MARK: 2 — the canvas lands a step through the drag's one commit

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
        guard let landed = step.range(of: "drop(regionID, onLane: laneID, from: part.startTick, to: target)"),
              // E4-27: the announcement's head is a catalog key; the claim (announce AFTER the landing) is unchanged.
              let said = step.range(of: "AccessibilityNotification.Announcement(String(localized: \"Part at \") + SessionGrid.label(forTick: target)).post()") else {
            return XCTFail("the step no longer announces where the part landed — VoiceOver does not re-read a changed label")
        }
        XCTAssertLessThan(landed.lowerBound, said.lowerBound, "announce the landing after it happened")
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
