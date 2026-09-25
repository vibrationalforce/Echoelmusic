// TheArrangeCanvasMovesAPartByDraggingTests.swift
// Echoel — WA4 path D: press, hold and slide a part on the Arrange canvas to move it.
//
// WHAT THIS PINS. The part bar moved a part one bar per tap; the canvas could only select.
// A part now follows the finger in whole bars and lands where its preview sits. The risks are
// the ones the cut arrange view paid for: a preview that disagrees with the commit (the part
// "jumps" on release), a finger-rate state that churns more than the dragged block, a delta
// that sticks when the scroll view cancels the drag (#56 C2), a commit per frame instead of
// one per release, and a drag that steals the Workstation's vertical scroll.
//
// 1. END-TO-END (pure): `ArrangeCanvas.dropTick` moves by WHOLE BARS relative to the start —
//    under half a bar is no move, just over is one bar, an off-grid part keeps its offset,
//    nothing lands before the song's top, degenerate geometry is no move — and
//    `offsetPoints` previews exactly that landing on the scale the blocks are placed on.
// 2. SOURCE: the finger-rate state is ONE `@GestureState` in the `ArrangePartBlock` leaf and
//    nowhere else in the file; the leaf's preview and its release both ask `dropTick`; the
//    release is the ONLY call of `onDrop`; the leaf owns no store, no selection and no clock.
// 3. SOURCE: the canvas commits a drop through `TrackParts.move` — the part bar's own store
//    call, one undo step — once, after selecting the part, and not at all when the part lands
//    where it started.
// 4. SOURCE: hold first, then slide (`LongPressGesture … .sequenced(before: DragGesture`), so a
//    swipe that starts on a part still scrolls the Workstation.
//
// Grading (§0, no Swift toolchain in a web session): claim 1 transcribed into Python
// (`TimelineDragMath.tickDelta`'s rounding, then whole-bar rounding) with the numbers below;
// claims 2–4 driven against this tree. On the parent (b4c2179bf) `ArrangeCanvas.dropTick` does
// not exist, so the bundle does not build there — ONE absence (#486): all four are FORWARD
// guards. The counterweights that the canvas stays cold live in
// `TheSongIsSeenOnOneScaleTests` claim 3, moved in the same commit.
// NOT covered: that a hold-and-slide feels right on glass, that a vertical swipe on a part
// still scrolls, and that the part is heard where it lands while playing — device probes.
// NEEDS-FOUNDER-VERIFY: Workstation, a track with a part — press and hold the part, slide it
// right about one bar and let go: it lands one bar later, outlined; Undo puts it back. A quick
// swipe up or down that starts on a part scrolls the page and moves nothing.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArrangeCanvasMovesAPartByDraggingTests: XCTestCase {

    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerBeat

    // An 8-bar song on a 320 pt lane: 40 pt per bar, 10 pt per beat — exact in binary.
    private static let song = 8 * TimelineTime.ticksPerBar
    private static let width: CGFloat = 320

    // MARK: 1 — whole bars, relative, clamped, and previewed where it lands

    func testADragMovesByWholeBarsAndThePreviewIsTheLanding() {
        let start = 2 * Self.bar
        func drop(_ points: CGFloat, from tick: Int? = nil) -> Int {
            ArrangeCanvas.dropTick(startTick: tick ?? start, dragPoints: points,
                                   laneWidth: Self.width, songTicks: Self.song)
        }
        XCTAssertEqual(drop(0), start, "no drag, no move")
        XCTAssertEqual(drop(19), start, "under half a bar (20 pt) is a wobble, not a move")
        XCTAssertEqual(drop(-19), start)
        XCTAssertEqual(drop(21), start + Self.bar, "just over half a bar is one bar")
        XCTAssertEqual(drop(-21), start - Self.bar)
        XCTAssertEqual(drop(121), start + 3 * Self.bar)
        XCTAssertEqual(drop(-1_000), 0, "nothing lands before the song's top")

        let offGrid = Self.bar + Self.beat
        XCTAssertEqual(drop(40, from: offGrid), offGrid + Self.bar,
                       "an off-grid part keeps its offset — the part bar's one-bar step, not a snap to the grid")

        for (w, songTicks) in [(CGFloat(0), Self.song), (CGFloat.nan, Self.song), (Self.width, 0)] {
            XCTAssertEqual(ArrangeCanvas.dropTick(startTick: start, dragPoints: 100,
                                                  laneWidth: w, songTicks: songTicks), start,
                           "degenerate geometry (width \(w), song \(songTicks)) is no move")
        }
        XCTAssertEqual(drop(.nan), start, "a non-finite drag is no move")

        let landing = drop(121)
        XCTAssertEqual(ArrangeCanvas.offsetPoints(from: start, to: landing,
                                                  laneWidth: Self.width, songTicks: Self.song), 120,
                       "the preview is drawn exactly where the release will land — three bars, 120 pt")
        XCTAssertEqual(ArrangeCanvas.offsetPoints(from: start, to: start + Self.bar,
                                                  laneWidth: 0, songTicks: Self.song), 0)
    }

    // MARK: 2 — one gesture-local state, preview and release from one rule

    func testTheFingerRateStateLivesInThePartBlockAlone() throws {
        let file = try source(Self.canvasPath)
        guard let blockStart = file.range(of: "struct ArrangePartBlock: View {") else {
            return XCTFail("ANCHOR MISSING: `struct ArrangePartBlock: View {` (#454)")
        }
        let block = String(file[blockStart.upperBound...])
        XCTAssertEqual(file.components(separatedBy: "@GestureState").count - 1, 1,
                       "exactly one finger-rate state in the canvas file")
        XCTAssertTrue(block.contains("@GestureState private var dragPoints: CGFloat = 0"),
                      "the drag delta is `@GestureState` — it resets itself when the scroll view cancels the drag (#56 C2)")
        XCTAssertFalse(block.contains("@State"),
                       "a plain `@State` delta sticks on a cancelled drag and leaves the part drawn away from where it sits")
        XCTAssertEqual(block.components(separatedBy: "ArrangeCanvas.dropTick(").count - 1, 2,
                       "the preview and the release both ask `dropTick` — one rule, or the part jumps on release")
        XCTAssertTrue(block.contains("ArrangeCanvas.offsetPoints(from: startTick, to: landing,"),
                      "the preview draws the landing, not the raw finger")
        XCTAssertEqual(block.components(separatedBy: "onDrop(").count - 1, 1,
                       "the store is reached once per release, never per frame")
        guard let ended = block.range(of: ".onEnded") else {
            return XCTFail("ANCHOR MISSING: the gesture's `.onEnded` (#454)")
        }
        XCTAssertTrue(block[ended.upperBound...].contains("onDrop("), "`onDrop` is called from the release")
        for banned in ["TimelineStore", "timeline", "selection", "currentTick", "player",
                       "TimelineView(", "Timer"] {
            XCTAssertFalse(block.contains(banned), """
                `ArrangePartBlock` contains `\(banned)`. The leaf draws a part and reports a \
                release; the store, the selection and every clock stay out of it.
                """)
        }
    }

    // MARK: 3 — one commit, through the part bar's store call

    func testTheDropCommitsOnceThroughThePartBarsMove() throws {
        let file = try source(Self.canvasPath)
        guard let head = file.range(of: "private func drop(_ regionID: UUID, onLane laneID: UUID, from startTick: Int, to tick: Int) {"),
              let blockStart = file.range(of: "struct ArrangePartBlock: View {"),
              head.upperBound < blockStart.lowerBound else {
            return XCTFail("ANCHOR MISSING: the canvas's `drop` before `ArrangePartBlock` (#454)")
        }
        let drop = String(file[head.upperBound..<blockStart.lowerBound])
        guard let select = drop.range(of: "selection.selectRegion(regionID, in: document)"),
              let noMove = drop.range(of: "guard tick != startTick,"),
              let move = drop.range(of: "TrackParts.move(part, toStartTick: tick, timeline: timeline)") else {
            return XCTFail("the drop no longer selects, refuses a no-move, and moves through `TrackParts.move`")
        }
        XCTAssertTrue(select.upperBound <= noMove.lowerBound && noMove.upperBound <= move.lowerBound,
                      "select first, refuse a no-move, then ONE store edit")
        XCTAssertEqual(file.components(separatedBy: "TrackParts.move(").count - 1, 1,
                       "one commit site on the canvas")
        for banned in ["moveRegion(", "resizeRegion(", "trimRegionStart(", "splitRegion(", "undo("] {
            XCTAssertFalse(file.contains(banned), """
                the canvas calls `\(banned)` directly. Its one edit is `TrackParts.move` — the \
                part bar's own path, one undo step; every other edit belongs to the part bar.
                """)
        }
    }

    // MARK: 4 — hold, then slide

    func testTheDragWaitsForAHoldSoTheWorkstationStillScrolls() throws {
        let file = try source(Self.canvasPath)
        XCTAssertTrue(file.contains("LongPressGesture(minimumDuration: 0.3)"))
        XCTAssertTrue(file.contains(".sequenced(before: DragGesture(minimumDistance: 0))"),
                      "the drag starts only after the hold — a bare drag on a part steals the page scroll")
        XCTAssertEqual(file.components(separatedBy: "DragGesture(").count - 1, 1,
                       "one drag gesture on the canvas")
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
