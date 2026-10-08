//
//  TheSpatialSceneSurvivesARelaunchTests.swift
//  Restructure S3d, review repair (MED): a place given to a track — in its inspector, by an
//  ADM-OSC controller, or on the Stage — was lost on relaunch. The scene lived in memory and in
//  a SAVED piece only; the app's launch `rebuild(from:)` placed every object at its default, and
//  only Open-from-library (`SessionSaveOpen.restoreSpatialScene`) brought places back. The
//  inspector's header said the place "comes back when the piece reopens", which was half true.
//  `SpatialSceneStore.workingCopy()` now loads and writes the scene beside the working song.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `SpatialSceneStore`, `AppGroupStore` and the scene
//    value types are shipped. Claim 1 relaunches by constructing a SECOND store on the same
//    directory and rebuilding it from the same lanes, which is exactly what launch does.
//    The directory is this test's own (`SpatialSceneRelaunchTests`), cleaned at the start, so
//    nothing is read from or left in the app's working copy.
//  · SOURCE-TEXT SCAN (claims 3–4) — the app constructs the working copy and flushes it on the
//    background path; every mutator of the scene asks for a write; the write is debounced to
//    ONE pending task, never a task per move (10.76.48 — an ADM-OSC controller moves objects at
//    its full send rate).
//  · DEVICE PROBE, OPEN — that a place set on the phone is there after a force-quit: G6.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it calls
//  `workingCopy(on:)` and `workingCopyName`, created by this commit — so no assertion has a
//  verdict on the parent (ONE absence, #486). Claims 1–2 are FORWARD guards transcribed by
//  reading `workingCopy(on:)`, `rebuild`, `setPosition` and `flushPendingSave`; claims 3–4's
//  needles were grepped against the worktree. COUNTERWEIGHTS (#343): claim 1's other-lanes
//  rebuild (a working copy never leaks into another piece) and claim 2 (a plain `init()` reads
//  and writes no disk, so every other test of the store stays in memory).
//
//  CLAIM 5 (2026-10-08, the GMMW crash-class lens): a place READ BACK is clamped like a place
//  set in code. END-TO-END on the shipped value type: decode `{"azimuth":720,"elevation":-200,
//  "distance":3}` and expect the clamped (180, -90, 1); counterweight: an in-range place
//  round-trips unchanged and keeps its three keys. GRADING (transcribed by reading the
//  synthesized decoder against the new one): RED on the parent for its named reason — the
//  synthesized decoder assigned the stored lets directly, so the three values came back as
//  written; the counterweight is green on both. The lens's first reading ("a persisted NaN
//  reaches AVAudio3DPoint") is REFUTED and stated here so it is not re-derived: JSON has no NaN
//  and the default decoding strategy throws on one.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSpatialSceneSurvivesARelaunchTests: XCTestCase {

    private static let directory = "SpatialSceneRelaunchTests"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let store = "Sources/Echoelmusic/Core/SpatialSceneStore.swift"

    // MARK: 1 — a moved place is there after a relaunch, and only for the piece it belongs to

    func testAMovedPlaceIsThereAfterARelaunch() {
        let disk = AppGroupStore(subdirectory: Self.directory)
        XCTAssertTrue(disk.save(SpatialScene(), name: SpatialSceneStore.workingCopyName),
                      "premise: the test's own working copy starts empty")

        let lanes = [TimelineLane(name: "Loop", kind: .audio), TimelineLane(name: "Keys", kind: .midi)]
        let moved = SpatialPosition(azimuth: 90, elevation: 0, distance: 0.5)

        let before = SpatialSceneStore.workingCopy(on: disk)
        before.rebuild(from: lanes)
        XCTAssertNotEqual(before.object(forLane: lanes[0].id)?.position, moved,
                          "premise: the default place is not the moved one")
        before.setPosition(laneID: lanes[0].id, moved)
        XCTAssertTrue(before.flushPendingSave(), "the working copy reaches the disk")

        // Relaunch: a new store on the same directory, fitted to the same song.
        let after = SpatialSceneStore.workingCopy(on: disk)
        after.rebuild(from: lanes)
        XCTAssertEqual(after.object(forLane: lanes[0].id)?.position, moved, """
            A place given to a track was lost on relaunch. The scene's working copy must load at \
            launch, and the launch rebuild must keep a known lane's object as it is.
            """)

        // COUNTERWEIGHT: another piece (other lanes, other ids) gets defaults, not this place.
        let other = SpatialSceneStore.workingCopy(on: disk)
        let otherLanes = [TimelineLane(name: "Loop", kind: .audio)]
        other.rebuild(from: otherLanes)
        XCTAssertNotEqual(other.object(forLane: otherLanes[0].id)?.position, moved,
                          "a working copy must not carry one piece's places into another")
        XCTAssertNil(other.object(forLane: lanes[0].id), "an object whose lane is gone drops")
    }

    // MARK: 2 — COUNTERWEIGHT: a plain store reads and writes no disk

    func testAPlainStoreHasNoWorkingCopy() {
        let plain = SpatialSceneStore()
        XCTAssertTrue(plain.scene.objects.isEmpty, "`init()` loads nothing")
        XCTAssertTrue(plain.flushPendingSave(), "with no working copy there is nothing to write")
    }

    // MARK: 3 — the app owns the working copy and flushes it on the way to the background

    func testTheAppOwnsTheWorkingCopy() throws {
        let app = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(app.contains("@State private var spatialScene = SpatialSceneStore.workingCopy()"),
                      "the app's scene must be the working copy, or a relaunch loses every place")
        XCTAssertEqual(app.components(separatedBy: "SpatialSceneStore(").count - 1, 0,
                       "the app constructs no second, in-memory scene")
        XCTAssertTrue(app.contains("spatialScene.flushPendingSave()"),
                      "a move made in the last half second must be written before suspension")
    }

    // MARK: 4 — every mutator asks for a write, and the write is ONE pending task

    func testEveryMutatorWritesAndTheWriteIsDebounced() throws {
        let code = SourceText.codeOnly(try text(Self.store))
        for member in ["public func rebuild(from", "public func restore(", "public func setPosition(",
                       "public func apply(", "public func setExtent("] {
            let body = try XCTUnwrap(self.body(of: member, in: code), "`\(member)` not found")
            XCTAssertTrue(body.contains("persist()"), """
                `\(member)` changes the scene without asking for a write — that change would be \
                lost on relaunch.
                """)
        }
        let persist = try XCTUnwrap(body(of: "private func persist()", in: code))
        XCTAssertTrue(persist.contains("guard disk != nil, !writePending else { return }"), """
            The write is no longer debounced to one pending task. An ADM-OSC controller moves \
            objects at its full send rate; a main-actor task per move starves the UI (10.76.48).
            """)
    }

    // MARK: 5 — a place read back is clamped like a place set in code

    func testADecodedPlaceIsClampedLikeAConstructedOne() throws {
        let wild = Data(#"{"azimuth":720,"elevation":-200,"distance":3}"#.utf8)
        let decoded = try JSONDecoder().decode(SpatialPosition.self, from: wild)
        XCTAssertEqual(decoded, SpatialPosition(azimuth: 720, elevation: -200, distance: 3),
                       "decoding must go through the clamping init, like every other construction")
        XCTAssertEqual(decoded.azimuth, 180)
        XCTAssertEqual(decoded.elevation, -90)
        XCTAssertEqual(decoded.distance, 1)

        // COUNTERWEIGHT: an in-range place round-trips unchanged, under the same three keys.
        let place = SpatialPosition(azimuth: -45, elevation: 10, distance: 0.5)
        let encoded = try JSONEncoder().encode(place)
        XCTAssertEqual(try JSONDecoder().decode(SpatialPosition.self, from: encoded), place)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
        let keys: Set<String> = Set(object.keys)
        XCTAssertEqual(keys, ["azimuth", "elevation", "distance"],
                       "the encoded keys are the stored names — a saved scene from an older build must still decode")
    }

    // MARK: - helpers

    /// The text from `marker` to the end of its brace block.
    private func body(of marker: String, in code: String) -> String? {
        guard let start = code.range(of: marker),
              let open = code[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

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
