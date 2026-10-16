// TheTracksMoveWithoutTakingTheEchoelTests.swift
// A4c (founder 2026-10-16, gap list item 4 "Spuren umsortieren", the order half): the Track page
// of the inspector has Move up / Move down, one Undo step per tap. The order of the tracks is
// ROUTING, not only display — the first non-bio MIDI track plays the Echoel instrument
// (`rollLaneID` and two inline copies of its rule) — so a move is refused whenever it would hand
// that instrument to another track, and the bio track keeps its place.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped types: every allowed move keeps `rollLaneID`, refusals,
//     the reapply-order rule, and the real store's `moveLane` as ONE undo step.
//   · Claim 3 is a SOURCE-TEXT SCAN: the door is mounted on the Track page and the store is the one
//     writer of the order.
//   · NOT CLAIMED (DEVICE PROBE): that the player re-primes cleanly mid-play. NEEDS-FOUNDER-VERIFY
//     (A4c) — the probe is at `TrackOrderRow.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`LaneOrder`,
// `moveLane`, `TrackOrderRow` are new), so no assertion has a verdict on the parent. Hand-transcribed:
// claims 1–2 are the CAPABILITY plus COUNTERWEIGHTS (the Echoel track never changes hands; the bio
// track never moves; an order changed since keeps the later one on Undo); claim 3 is a FORWARD
// guard. Mutants: a MIDI track moved above the Echoel track (1) · the bio track moved (1) · a step
// of 2 (1) · two undo steps (2) · Undo over a later order (2) · a second writer (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTracksMoveWithoutTakingTheEchoelTests: XCTestCase {

    // MARK: 1 — every allowed move keeps the Echoel track; the refusals

    func testEveryAllowedMoveKeepsTheEchoelTrack() {
        let audio = TimelineLane(name: "Audio", kind: .audio)
        let echoel = TimelineLane(name: "Echoel", kind: .midi)
        let synth = TimelineLane(name: "Synth", kind: .midi, builtinInstrument: .polySynth)
        let video = TimelineLane(name: "Video", kind: .video)
        let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
        let lanes = [audio, echoel, synth, video, body]
        let roll = TimelineDocument(lanes: lanes, regions: []).rollLaneID
        XCTAssertEqual(roll, echoel.id, "fixture premise: the first MIDI track plays the Echoel")
        for lane in lanes {
            for delta in [-1, 1] {
                guard let next = LaneOrder.moved(lanes, id: lane.id, by: delta) else { continue }
                XCTAssertEqual(TimelineDocument(lanes: next, regions: []).rollLaneID, roll,
                               "moving \(lane.name) by \(delta) handed the Echoel to another track")
                XCTAssertEqual(next.last?.id, body.id, "the bio track keeps its place")
            }
        }
        XCTAssertEqual(LaneOrder.moved(lanes, id: video.id, by: -1)?.map(\.name),
                       ["Audio", "Echoel", "Video", "Synth", "Body"], "a track moves one place")
        XCTAssertEqual(LaneOrder.moved(lanes, id: echoel.id, by: -1)?.map(\.name),
                       ["Echoel", "Audio", "Synth", "Video", "Body"], "the Echoel track moves past a non-MIDI one")
        XCTAssertNil(LaneOrder.moved(lanes, id: synth.id, by: -1), "a MIDI track never moves above the Echoel")
        XCTAssertNil(LaneOrder.moved(lanes, id: echoel.id, by: 1), "the Echoel never moves below a MIDI track")
        XCTAssertNil(LaneOrder.moved(lanes, id: video.id, by: 1), "nothing moves past the bio track")
        XCTAssertNil(LaneOrder.moved(lanes, id: body.id, by: -1), "the bio track does not move")
        XCTAssertNil(LaneOrder.moved(lanes, id: audio.id, by: -1), "the top edge")
        XCTAssertNil(LaneOrder.moved(lanes, id: audio.id, by: 2), "one place at a time")
        XCTAssertNil(LaneOrder.moved(lanes, id: UUID(), by: 1))
        let extra = TimelineLane(name: "New", kind: .audio)
        XCTAssertEqual(LaneOrder.ordered([synth, extra, audio], as: [audio.id, UUID(), synth.id]).map(\.name),
                       ["Audio", "Synth", "New"], "a named order reapplies; an added track keeps its place after it")
    }

    // MARK: 2 — the store moves as ONE undo step, and Undo never overwrites a later order

    func testMoveLaneIsOneUndoStep() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        let echoel = TimelineLane(name: "Echoel", kind: .midi)
        let audio = TimelineLane(name: "Audio", kind: .audio)
        let video = TimelineLane(name: "Video", kind: .video)
        timeline.replaceDocument(TimelineDocument(lanes: [echoel, audio, video], regions: []))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        XCTAssertFalse(timeline.canMoveLane(id: echoel.id, by: -1))
        XCTAssertFalse(timeline.moveLane(id: echoel.id, by: -1), "a refused move")
        XCTAssertFalse(timeline.canUndo, "a refused move writes no undo step")
        XCTAssertTrue(timeline.moveLane(id: video.id, by: -1))
        XCTAssertEqual(timeline.document.lanes.map(\.name), ["Echoel", "Video", "Audio"])
        timeline.undo()
        XCTAssertEqual(timeline.document.lanes.map(\.name), ["Echoel", "Audio", "Video"], "ONE Undo puts it back")
        XCTAssertFalse(timeline.canUndo)
        timeline.redo()
        XCTAssertEqual(timeline.document.lanes.map(\.name), ["Echoel", "Video", "Audio"], "and Redo moves it again")
        timeline.addLane(kind: .audio, name: "Later")
        timeline.undo()
        XCTAssertEqual(timeline.document.lanes.map(\.name), ["Echoel", "Video", "Audio", "Later"],
                       "COUNTERWEIGHT: an order changed since (a track added) keeps the later one")
    }

    // MARK: 3 — the door and the one writer

    func testTheTrackPageMovesTheTrackThroughTheStore() throws {
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(inspector.components(separatedBy: "TrackOrderRow(laneID: laneID)").count - 1, 1, "one mount")
        let row = try source("Sources/Echoelmusic/Studio/TrackOrderRow.swift")
        XCTAssertTrue(row.contains("timeline.moveLane(id: laneID, by: delta)"))
        XCTAssertTrue(row.contains("timeline.canMoveLane(id: laneID, by: delta)"), "a refused move is a disabled button")
        XCTAssertFalse(row.contains("DragGesture"), "buttons in v1, never a drag on the track column")
        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        XCTAssertTrue(store.contains("guard let next = LaneOrder.moved(document.lanes, id: id, by: delta) else { return false }"))
        XCTAssertTrue(store.contains("document.lanes = LaneOrder.ordered(document.lanes, as: before)"),
                      "Undo reapplies the order, never an old lanes array (a later edit's content survives)")
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
