// TheWorkstationHasOneSelectionTests.swift
// Echoel — WA4 critical path 3: ONE low-frequency owner of what is selected in the Workstation.
//
// WHAT THIS PINS. Until WA4 the selected track was `@State selectedTrack` in `WorkstationView`.
// The Arrange canvas, the parts list and a device inspector all need the same answer to "which
// track, which part", and each keeping its own is how two surfaces come to disagree. The owner
// is `Studio/WorkstationSelection.swift`, built once by the app and injected.
//
// 1. END-TO-END over the shipped type: a part selects its track with it; an unknown part
//    selects nothing; toggling the selected track closes it and drops the part; switching
//    tracks drops a part that sat on the old one.
// 2. END-TO-END over the pure resolvers: an id the document no longer holds (after an Open, an
//    Undo, a removed track) resolves to nil — never pruned in a `body`, answered on read; a part
//    that an Undo moved to another track is not silently re-homed.
// 3. SOURCE: exactly ONE construction, in the app (beside the timeline player); the Workstation
//    reads it from the environment; nothing persists it (no `Codable`, no defaults key).
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 HAND-TRACED against the type as
// written; claim 3 driven in Python against this tree. On the parent (2eb3cb84d) the type does
// not exist, so the bundle does not build there — ONE absence (#486); every claim is a FORWARD
// guard. NOT covered: that tapping a row feels right on a device.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheWorkstationHasOneSelectionTests: XCTestCase {

    private static let laneA = TimelineLane(name: "MIDI 1", kind: .midi)
    private static let laneB = TimelineLane(name: "Audio 1", kind: .audio)
    private static let clipID = UUID()
    private static let partOnA = TimelineRegion(laneID: laneA.id, clipID: clipID,
                                                startTick: 0, lengthTicks: TimelineTime.ticksPerBar)
    private static let document = TimelineDocument(lanes: [laneA, laneB], regions: [partOnA])

    // MARK: 1 — the owner

    func testAPartSelectsItsTrackAndTheTrackToggles() {
        let selection = WorkstationSelection()
        XCTAssertNil(selection.trackID)
        XCTAssertNil(selection.regionID)

        selection.selectRegion(Self.partOnA.id, in: Self.document)
        XCTAssertEqual(selection.regionID, Self.partOnA.id)
        XCTAssertEqual(selection.trackID, Self.laneA.id, "a selected part implies its track")

        selection.selectRegion(UUID(), in: Self.document)
        XCTAssertEqual(selection.regionID, Self.partOnA.id, "an unknown part selects nothing")

        selection.toggleTrack(Self.laneB.id)
        XCTAssertEqual(selection.trackID, Self.laneB.id)
        XCTAssertNil(selection.regionID, "a part on the old track does not stay selected")

        selection.toggleTrack(Self.laneB.id)
        XCTAssertNil(selection.trackID, "tapping the open track closes it")
        XCTAssertNil(selection.regionID)
    }

    // MARK: 2 — stale ids resolve to nil

    func testAStaleSelectionResolvesToNothing() {
        let empty = TimelineDocument(lanes: [], regions: [])
        XCTAssertEqual(WorkstationSelection.resolvedTrack(Self.laneA.id, in: Self.document), Self.laneA.id)
        XCTAssertNil(WorkstationSelection.resolvedTrack(Self.laneA.id, in: empty),
                     "after an Open replaces the song, the old track id opens nothing")
        XCTAssertNil(WorkstationSelection.resolvedTrack(nil, in: Self.document))

        XCTAssertEqual(WorkstationSelection.resolvedRegion(Self.partOnA.id, track: Self.laneA.id,
                                                           in: Self.document), Self.partOnA.id)
        XCTAssertNil(WorkstationSelection.resolvedRegion(Self.partOnA.id, track: Self.laneA.id, in: empty))

        var moved = Self.partOnA
        moved.laneID = Self.laneB.id
        let undone = TimelineDocument(lanes: [Self.laneA, Self.laneB], regions: [moved])
        XCTAssertNil(WorkstationSelection.resolvedRegion(Self.partOnA.id, track: Self.laneA.id, in: undone),
                     "a part now on another track is not shown as selected under the old one")
    }

    // MARK: 3 — one owner, not persisted

    func testThereIsOneOwnerAndItIsNeverSaved() throws {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var constructions: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains("WorkstationSelection()") { constructions.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(constructions, ["EchoelmusicApp.swift"],
                       "one owner, built by the app — a surface that builds its own has a second truth")

        let app = try code("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains(".environment(workstationSelection)"), "built and never injected is no owner")

        let owner = try code("Sources/Echoelmusic/Studio/WorkstationSelection.swift")
        XCTAssertFalse(owner.contains("Codable"), "which row is open is not part of the piece")
        XCTAssertFalse(owner.contains("UserDefaults"), "and it is not remembered across launches")
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }
}
