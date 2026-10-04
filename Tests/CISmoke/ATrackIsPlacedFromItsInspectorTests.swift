//
//  ATrackIsPlacedFromItsInspectorTests.swift
//  Restructure S3d (founder 2026-10-04: „Abnahme ist eine reproduzierbar hörbare Raumposition samt
//  Wiederherstellung im Stück" · „Accessibility gehört in jede berührte Kernaktion: große Schrift,
//  klare Namen, sichtbare Zustände und Alternativen zu Ziehgesten.")
//
//  S3c made a track audible at its place on headphones; until this slice the only hand that could
//  MOVE that place was the doorless Stage's drag. The open track's Track page now carries two
//  numbers — Direction and Distance — written through the scene store's one writer.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `SpatialSceneStore`, `SpatialPosition` and `TimelineLane`
//    are shipped. Claim 1: the "Default" the rows offer is exactly where a rebuild places a new
//    track. Claim 2: a typed number can never leave the room (the position type clamps).
//  · SOURCE-TEXT SCAN (claims 3–4) — `TrackSpaceRows` and `TrackInspectorView` are `View`s.
//  · DEVICE PROBE, OPEN — that a track moved here is HEARD there on headphones, and is there again
//    after reopening the piece: G6 in `docs/dev/FOUNDER_INBOX.md`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `SpatialSceneStore.defaultPosition(forLane:in:)`, created by this commit — so no assertion has
//  a verdict on the parent (ONE absence, #486). Claims 1–2 are FORWARD guards transcribed by
//  reading `rebuild` → `ImmersiveObjectDefaults.defaultPosition`; claims 3–4's needles were grepped
//  against the worktree and are absent on the parent.
//  COUNTERWEIGHTS (#343): claim 1's rebuild half (a moved object keeps its place across a rebuild,
//  so "Default" is the ONLY way back) and claim 2 (the clamp the rows rely on).
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATrackIsPlacedFromItsInspectorTests: XCTestCase {

    private static let rows = "Sources/Echoelmusic/Studio/TrackSpaceRows.swift"
    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    // MARK: 1 — "Default" is where a rebuild puts the track, and a move survives a rebuild

    func testTheDefaultIsWhereARebuildPlacesTheTrack() {
        let lanes = [TimelineLane(name: "Body", kind: .midi, isBio: true),
                     TimelineLane(name: "Keys", kind: .midi),
                     TimelineLane(name: "Loop", kind: .audio)]
        let store = SpatialSceneStore()
        store.rebuild(from: lanes)
        for lane in lanes.dropFirst() {
            XCTAssertEqual(SpatialSceneStore.defaultPosition(forLane: lane.id, in: lanes),
                           store.object(forLane: lane.id)?.position, """
                The inspector's Default for "\(lane.name)" is not where a rebuild places it. Two \
                derivations of one placement is the #416 defect — the Default must ask the same inputs.
                """)
        }
        XCTAssertNil(SpatialSceneStore.defaultPosition(forLane: lanes[0].id, in: lanes),
                     "a bio track is no object in the space and has no place to return to")
        XCTAssertNil(SpatialSceneStore.defaultPosition(forLane: UUID(), in: lanes),
                     "a lane the piece does not have has no default")

        // COUNTERWEIGHT: a moved track KEEPS its place across a rebuild — which is why the rows
        // need a Default at all: nothing else puts it back.
        let loop = lanes[2].id
        store.setPosition(laneID: loop, SpatialPosition(azimuth: 60, elevation: 0, distance: 0.4))
        store.rebuild(from: lanes)
        XCTAssertEqual(store.object(forLane: loop)?.position.azimuth ?? .nan, 60, accuracy: 1e-4)
        XCTAssertEqual(store.object(forLane: loop)?.position.distance ?? .nan, 0.4, accuracy: 1e-4)
    }

    // MARK: 2 — a typed number cannot leave the room (COUNTERWEIGHT on the shipped type)

    func testATypedPlaceStaysInsideTheRoom() {
        let far = SpatialPosition(azimuth: 400, elevation: 0, distance: 3)
        XCTAssertEqual(far.azimuth, 180)
        XCTAssertEqual(far.distance, 1)
        let broken = SpatialPosition(azimuth: .nan, elevation: 0, distance: .infinity)
        XCTAssertEqual(broken.azimuth, 0, "a non-finite direction is the front, never NaN on the bus")
        XCTAssertEqual(broken.distance, 0)
    }

    // MARK: 3 — two named numbers, written through the scene's one writer, in their own leaf

    func testTheRowsAreTwoNamedNumbersThroughTheOneWriter() throws {
        let code = SourceText.codeOnly(try text(Self.rows))
        for needle in ["@Environment(SpatialSceneStore.self) private var spatial",
                       "label: \"Direction\"", "range: -180...180", "unit: \"°\"",
                       "label: \"Distance\"", "range: 0...1",
                       "standard: standard.map { Double($0.azimuth) }",
                       "standard: standard.map { Double($0.distance) }",
                       "SpatialSceneStore.defaultPosition(forLane: laneID, in: timeline.document.lanes)",
                       "spatial.setPosition(laneID: laneID, SpatialPosition("] {
            XCTAssertTrue(code.contains(needle), """
                `TrackSpaceRows` lost `\(needle)`. The place is two named numbers with a Default, \
                written through `SpatialSceneStore.setPosition` — the writer the Stage and ADM-OSC use.
                """)
        }
        XCTAssertEqual(code.components(separatedBy: "EchoelValueField(").count - 1, 2,
                       "the space is two numbers on this page — Direction and Distance")
        for banned in ["Slider(", "DragGesture(", ".gesture("] {
            XCTAssertFalse(code.contains(banned), """
                `TrackSpaceRows` uses `\(banned)`. The place must stay reachable without a drag: \
                the value field's tap-to-type and VoiceOver adjust are the alternative.
                """)
        }
    }

    // MARK: 4 — the inspector mounts the leaf and does not read the scene itself

    func testTheInspectorMountsTheLeafAndReadsNoScene() throws {
        let code = SourceText.codeOnly(try text(Self.inspector))
        XCTAssertTrue(code.contains("if !lane.isBio {\n                        TrackSpaceRows(laneID: laneID, isAudio: lane.kind == .audio)"),
                      "the Track page lost the space rows (or shows them on a bio track, which has no place)")
        XCTAssertFalse(code.contains("SpatialSceneStore"), """
            `TrackInspectorView` reads the scene itself. The scene moves at an external controller's \
            rate (`apply(_:)`), and the inspector hosts menu pickers — the read belongs in the leaf \
            (10.76.41/50 law).
            """)
    }

    // MARK: - helpers

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
