// APartIsDraggedOntoAnotherTrackTests.swift
// Ultraplan-A4 / WA4-DRAG-XTRACK (2026-10-16): the Arrange canvas moved a part in TIME only; the
// store's `moveRegion(id:toStartTick:laneOffset:)` could change its track and had no caller. A
// hold-and-slide now carries a part DOWN or UP onto another track of its kind — previewed on the
// row it will land on, written once on release (time and track together, one Undo step), the
// selection following the part. VoiceOver gets the same move as two actions.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END over pure `ArrangeCanvas.rowsCrossed` / `dropLane`.
//   · Claim 3 is END-TO-END over a REAL `TimelineStore`: `TrackParts.move(_:toStartTick:toLane:
//     timeline:)` lands the part on the named track counted in DOCUMENT order, one Undo takes it
//     back, and the store's own guard still refuses a track of another kind.
//   · Claim 4 is a SOURCE-TEXT SCAN — `ArrangePartBlock` is a View: the preview and the release
//     share ONE row answer (`landingRows`), the row pitch is the lanes' own height plus spacing,
//     and the two VoiceOver actions are offered only where a track takes the part.
//   · DEVICE PROBE, open: the hold-and-slide reads on glass, the part draws over the row below
//     it, and it is heard on its new track.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — it names
// `ArrangeCanvas.dropLane` and the `toLane:` mover, which this commit creates — ONE absence
// (#486), every claim a FORWARD guard. Claim 3's kind refusal is a COUNTERWEIGHT on the store.
// Mutants and the claim each turns red: the offset counted in canvas rows instead of the
// document's lane order (3, a hidden bio lane between two MIDI tracks shifts the landing) · a
// composer take dragged off the Echoel's track (2) · a preview that ignores `acceptsRows` and
// draws the part on a track that refuses it (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class APartIsDraggedOntoAnotherTrackTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    // One fixture VALUE per lane — never a factory (#1419).
    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let loop = TimelineLane(name: "Loop", kind: .audio)
    private static let bass = TimelineLane(name: "Bass", kind: .midi)
    private static let notes = Clip(name: "A4 notes", kind: .midi)
    private static let take = Clip(name: "A4 take", kind: .midi, composerOwned: true)
    private static let wave = Clip(name: "A4 wave", kind: .audio)
    private static let keysPart = TimelineRegion(laneID: keys.id, clipID: notes.id, startTick: 0, lengthTicks: bar)
    private static let loopPart = TimelineRegion(laneID: loop.id, clipID: wave.id, startTick: 0, lengthTicks: bar)
    private static let fixture = TimelineDocument(lanes: [keys, body, loop, bass], regions: [keysPart, loopPart])
    /// The canvas's own row order, top to bottom.
    private static let order = [keys.id, body.id, loop.id, bass.id]

    // MARK: 1 — the rows a vertical drag crosses

    func testTheRowsCrossedRoundToTheNearestRow() {
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: 0, rowPitch: 72), 0)
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: 35, rowPitch: 72), 0, "under half a row stays")
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: 37, rowPitch: 72), 1, "past half a row is the next")
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: -150, rowPitch: 72), -2)
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: .nan, rowPitch: 72), 0)
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: 100, rowPitch: 0), 0)
        XCTAssertEqual(ArrangeCanvas.rowsCrossed(dragPoints: .greatestFiniteMagnitude, rowPitch: 1), 1_000,
                       "bounded, never a trap")
    }

    // MARK: 2 — which track takes the part

    func testOnlyATrackOfTheSameKindTakesThePart() {
        func lane(_ part: TimelineRegion, _ rows: Int, clip: Clip?) -> UUID? {
            ArrangeCanvas.dropLane(for: part.id, rows: rows, order: Self.order, in: Self.fixture, clip: clip)
        }
        XCTAssertEqual(lane(Self.keysPart, 3, clip: Self.notes), Self.bass.id, "three rows down: the other MIDI track")
        XCTAssertNil(lane(Self.keysPart, 1, clip: Self.notes), "a bio track takes no part")
        XCTAssertNil(lane(Self.keysPart, 2, clip: Self.notes), "a MIDI part never lands on an audio track")
        XCTAssertNil(lane(Self.keysPart, -1, clip: Self.notes), "no row above the top")
        XCTAssertNil(lane(Self.keysPart, 0, clip: Self.notes), "no rows crossed, no track change")
        XCTAssertNil(lane(Self.loopPart, 1, clip: Self.wave), "an audio part never lands on a MIDI track")
        XCTAssertNil(lane(Self.keysPart, 3, clip: Self.take),
                     "a composer take stays on the track that plays it")
        XCTAssertNil(lane(Self.keysPart, .max, clip: Self.notes), "an overflowing count is no row")
    }

    // MARK: 3 — one store command, counted in the document's order, one Undo

    func testTheMoveLandsOnTheNamedTrackInOneUndoStep() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(Self.fixture)
        let part = try XCTUnwrap(TrackParts.parts(onLane: Self.keys.id, in: timeline.document).first)
        TrackParts.move(part, toStartTick: 2 * Self.bar, toLane: Self.bass.id, timeline: timeline)
        let moved = try XCTUnwrap(timeline.document.regions.first(where: { $0.id == Self.keysPart.id }))
        XCTAssertEqual(moved.laneID, Self.bass.id, "the part sits on the track the canvas named")
        XCTAssertEqual(moved.startTick, 2 * Self.bar, "and at the time it was dropped at, in the same command")
        timeline.undo()
        let back = try XCTUnwrap(timeline.document.regions.first(where: { $0.id == Self.keysPart.id }))
        XCTAssertEqual(back.laneID, Self.keys.id, "ONE Undo takes track and time back together")
        XCTAssertEqual(back.startTick, 0)

        // Counterweight: the store's own guard — an audio track refuses a MIDI part, the time still moves.
        let again = try XCTUnwrap(TrackParts.parts(onLane: Self.keys.id, in: timeline.document).first)
        TrackParts.move(again, toStartTick: Self.bar, toLane: Self.loop.id, timeline: timeline)
        let refused = try XCTUnwrap(timeline.document.regions.first(where: { $0.id == Self.keysPart.id }))
        XCTAssertEqual(refused.laneID, Self.keys.id, "the store refuses a track of another kind")
        XCTAssertEqual(refused.startTick, Self.bar)
    }

    // MARK: 4 — one row answer for preview and release; VoiceOver gets the same move

    func testThePreviewAndTheReleaseShareOneRowAnswer() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let file = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"), encoding: .utf8))
        guard let blockStart = file.range(of: "struct ArrangePartBlock: View {") else {
            return XCTFail("`ArrangePartBlock` moved — re-anchor")
        }
        let block = String(file[blockStart.upperBound...])
        XCTAssertTrue(block.contains("let crossed = landingRows(drag.height)"), "the preview asks the one row answer")
        XCTAssertTrue(block.contains("landingRows(finger.translation.height))"), "and so does the release")
        XCTAssertTrue(block.contains("return crossed != 0 && acceptsRows(crossed) ? crossed : 0"),
                      "a row no track takes is no row — the preview never sits on a refusing track")
        XCTAssertTrue(block.contains(".offset(x: laneWidth * block.start + shift, y: CGFloat(crossed) * rowPitch)"))
        for (word, rows) in [("Move to the track above", "-1"), ("Move to the track below", "1")] {
            XCTAssertTrue(block.contains("if acceptsRows(\(rows)) {\n                    Button(\"\(word)\") { onMoveTrack(\(rows)) }"),
                          "`\(word)` is offered only where a track takes the part (WCAG 2.5.7)")
        }
        XCTAssertTrue(file.contains("rowPitch: Self.rowHeight + Self.rowSpacing,"),
                      "a row crossed is a row drawn: the lanes' height plus their spacing")
        XCTAssertEqual(file.components(separatedBy: "VStack(spacing: Self.rowSpacing) {").count - 1, 2,
                       "both columns stack with the one spacing the drag reads")
        XCTAssertTrue(file.contains("TrackParts.move(part, toStartTick: tick, toLane: target, timeline: timeline)\n        selection.selectRegion(regionID, in: timeline.document)"),
                      "the selection follows the part to its new track, read from the store after the write")
    }
}
