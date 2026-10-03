// TheSpatialControllerMovesTheTracksTests.swift
// Echoel — Spatial S1 (founder 2026-10-03: "Live Set · binaural broadcast · Spatial Audio ·
// immersive and multidimensional media — du entscheidest").
//
// WHAT IT GUARDS. Echoel SENT ADM-OSC objects and could not RECEIVE one: a spatial controller
// (Grapes, L-ISA, SPAT, a console's object panner) could read where the tracks sit and could not
// move them. The OSC control socket (#1255) now also accepts `/adm/obj/{n}/…` positions — same
// opt-in, same allowlist — and writes them into the ONE scene store, from which the outgoing
// ADM-OSC scene stream carries them on to the renderer.
//
// §1 LIMITS, per claim:
// · Claims 1–3 are END-TO-END BEHAVIOUR on shipped value types and the real store
//   (`ADMObjectInput.parse`, `.applied(to:)`, `SpatialSceneStore.apply`).
// · Claim 4 is a SOURCE-TEXT SCAN: the dispatch order in the receiver, the app wiring, and the
//   hot-state counterweight (no ancestor body reads the scene).
// · Claim 5 is a SOURCE-TEXT SCAN of the routing card's two sentences.
// · NOT COVERED, stated so nobody reads it as covered: a real datagram through the socket (the
//   loopback path is `testALoopbackCueReachesTheDispatch`, a known flake, and is not repeated
//   here); smoothing (there is none yet); any audible render (none — the scene is control plane).
//   What a controller on a real network does is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY: Grapes or
//   any ADM-OSC sender → phone port 8001, "Accept OSC control" on, "Every track as its own
//   object" on → the renderer follows the controller.
//
// §3 HONEST GRADING — TRANSCRIBED (Tests/CISmoke/CLAUDE.md §0) against the parent (ee163a910)
// and this tree: claims 1–3 do not compile on the parent (`ADMObjectInput` and
// `SpatialSceneStore.apply` do not exist) — FORWARD guards, one finding. Claim 4's dispatch and
// wiring halves are RED on the parent by anchor absence; its hot-state half is a COUNTERWEIGHT
// (green on both trees). Claim 5 is RED on the parent ("Nothing else is accepted" stood without
// the ADM sentence — the card would have denied the input this commit adds). The polar↔Cartesian
// algebra in claim 2 was driven in Python against `SpatialPosition.cartesian` before this file
// was written (#442). Stripper `SourceText.codeOnly`: TRAGEND for claim 4 (the receiver's header
// names `SpatialSceneStore` in prose).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSpatialControllerMovesTheTracksTests: XCTestCase {

    private func msg(_ address: String, _ floats: [Float]) -> OSCDecoder.Message {
        OSCDecoder.Message(address: address, arguments: floats.map { .float($0) })
    }

    // MARK: - Claim 1 — the ADM-OSC object namespace parses, bounded; everything else is refused

    func testTheObjectLeavesParseAndAreBounded() {
        XCTAssertEqual(ADMObjectInput.leaves, ["azim", "elev", "dist", "aed", "x", "y", "z", "xyz", "gain"])
        XCTAssertEqual(ADMObjectInput.parse(msg("/adm/obj/1/aed", [30, 10, 0.5])),
                       ADMObjectInput(object: 1, value: .polar(azimuth: 30, elevation: 10, distance: 0.5)))
        XCTAssertEqual(ADMObjectInput.parse(msg("/adm/obj/3/xyz", [0.2, -0.4, 0.1])),
                       ADMObjectInput(object: 3, value: .cartesian(x: 0.2, y: -0.4, z: 0.1)))
        XCTAssertEqual(ADMObjectInput.parse(msg("/adm/obj/2/azim", [-90])),
                       ADMObjectInput(object: 2, value: .azimuth(-90)))
        XCTAssertEqual(ADMObjectInput.parse(.init(address: "/adm/obj/2/gain", arguments: [.int(1)])),
                       ADMObjectInput(object: 2, value: .gain(1)), "an int argument is a number too")
        // Lenient receiver: a finite value past its range is clamped, not refused.
        XCTAssertEqual(ADMObjectInput.parse(msg("/adm/obj/1/azim", [270])),
                       ADMObjectInput(object: 1, value: .azimuth(180)))
        XCTAssertEqual(ADMObjectInput.parse(msg("/adm/obj/1/dist", [1e30])),
                       ADMObjectInput(object: 1, value: .distance(1)), "a hostile magnitude is bounded, never a trap (#1321)")
        // Refused.
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/azim", [.nan])), "NaN never reaches the scene")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/azim", [.infinity])))
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/0/azim", [0])), "ADM objects are 1-based")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/129/azim", [0])), "past the index ceiling")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/99999999999999999999/azim", [0])), "an overflowing index is refused, not trapped")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/aed", [30, 10])), "a packed form needs all three")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/azim", [1, 2])), "a single leaf takes one number")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/position/azimuth", [0])), "the pre-#1210 dialect is not the spec")
        XCTAssertNil(ADMObjectInput.parse(msg("/adm/obj/1/mute", [1])), "an unknown leaf moves nothing")
        XCTAssertNil(ADMObjectInput.parse(.init(address: "/adm/obj/1/azim", arguments: [.string("left")])))
        XCTAssertNil(ADMObjectInput.parse(msg("/echoelmusic/ctrl/key", [7])), "a control cue is not an object move")
        XCTAssertNil(OSCControlCommand.parse(msg("/adm/obj/1/aed", [30, 10, 0.5])), "an object move is not a control cue")
    }

    // MARK: - Claim 2 — a move changes exactly what it names; Cartesian goes through the same derivation

    func testAMoveChangesOnlyWhatItNames() {
        let start = SpatialObject(id: "a", position: SpatialPosition(azimuth: 45, elevation: 20, distance: 0.8), gain: 0.7)

        let azim = ADMObjectInput(object: 1, value: .azimuth(-30)).applied(to: start)
        XCTAssertEqual(azim.position.azimuth, -30)
        XCTAssertEqual(azim.position.elevation, 20)
        XCTAssertEqual(azim.position.distance, 0.8)
        XCTAssertEqual(azim.gain, 0.7, "a position leaf does not touch the gain")

        let gain = ADMObjectInput(object: 1, value: .gain(0.25)).applied(to: start)
        XCTAssertEqual(gain.gain, 0.25)
        XCTAssertEqual(gain.position, start.position, "the gain leaf does not move the object")

        // Cartesian: hard left at full distance is azimuth +90 (positive = left, `SpatialPosition`).
        let left = ADMObjectInput.position(x: -1, y: 0, z: 0)
        XCTAssertEqual(left.azimuth, 90, accuracy: 1e-3)
        XCTAssertEqual(left.elevation, 0, accuracy: 1e-3)
        XCTAssertEqual(left.distance, 1, accuracy: 1e-5)
        XCTAssertEqual(ADMObjectInput.position(x: 0, y: 0, z: 0), SpatialPosition(azimuth: 0, elevation: 0, distance: 0),
                       "the origin is a defined position, not NaN")
        // A cube corner lands on the unit sphere's surface.
        XCTAssertEqual(ADMObjectInput.position(x: 1, y: 1, z: 1).distance, 1)

        // Round trip through the sender's own derivation.
        let back = ADMObjectInput.position(x: start.position.cartesian.x,
                                           y: start.position.cartesian.y,
                                           z: start.position.cartesian.z)
        XCTAssertEqual(back.azimuth, 45, accuracy: 1e-3)
        XCTAssertEqual(back.elevation, 20, accuracy: 1e-3)
        XCTAssertEqual(back.distance, 0.8, accuracy: 1e-5)

        // A single Cartesian leaf keeps the other two Cartesian components.
        let before = start.position.cartesian
        let moved = ADMObjectInput(object: 1, value: .x(0.1)).applied(to: start).position.cartesian
        XCTAssertEqual(moved.x, 0.1, accuracy: 1e-4)
        XCTAssertEqual(moved.y, before.y, accuracy: 1e-4)
        XCTAssertEqual(moved.z, before.z, accuracy: 1e-4)
    }

    // MARK: - Claim 3 — the store: object n is track n, a missing track moves nothing, a rebuild keeps the move

    @MainActor
    func testTheStoreMovesTrackNAndKeepsItAcrossARebuild() {
        let store = SpatialSceneStore()
        let lanes = [TimelineLane(name: "Body", kind: .midi, isBio: true),
                     TimelineLane(name: "Keys", kind: .midi),
                     TimelineLane(name: "Lead", kind: .midi)]
        store.rebuild(from: lanes)
        XCTAssertEqual(store.scene.objects.count, 2, "the bio lane is never an object")

        store.apply(ADMObjectInput(object: 2, value: .polar(azimuth: -60, elevation: 15, distance: 0.4)))
        let lead = store.object(forLane: lanes[2].id)
        XCTAssertEqual(lead?.position, SpatialPosition(azimuth: -60, elevation: 15, distance: 0.4),
                       "object 2 is the SECOND track in the scene array — the table the stream numbers")

        let revision = store.scene.revision
        store.apply(ADMObjectInput(object: 3, value: .azimuth(10)))
        XCTAssertEqual(store.scene.revision, revision, "an object this piece does not have moves nothing")

        store.rebuild(from: lanes)
        XCTAssertEqual(store.object(forLane: lanes[2].id)?.position.azimuth, -60,
                       "a document change must not snap a controller's move back to the default")
    }

    // MARK: - Claim 4 — SOURCE: the object path comes first, the app wires it, no ancestor reads the scene

    func testTheReceiverDispatchesMovesAndTheAppWiresThem() throws {
        let receiver = try source("Sources/Echoelmusic/Sync/OSCReceiver.swift")
        guard let decode = receiver.range(of: "guard let message = OSCDecoder.decode(datagram) else {"),
              let move = receiver.range(of: "if let move = ADMObjectInput.parse(message) {"),
              let cue = receiver.range(of: "guard let command = OSCControlCommand.parse(message) else {"),
              let crumb = receiver.range(of: "EchoelCrashLog.breadcrumb(\"osc in: adm object moves arriving\")"),
              let dispatch = receiver.range(of: "onObjectMove?(move)") else {
            XCTFail("ANCHOR MISSING: the receiver's decode, object branch, cue branch, breadcrumb or dispatch moved — re-anchor (#408)")
            return
        }
        XCTAssertLessThan(decode.lowerBound, move.lowerBound)
        XCTAssertLessThan(move.lowerBound, cue.lowerBound, "the object namespace must be tried before the cue whitelist")
        XCTAssertLessThan(crumb.lowerBound, dispatch.lowerBound, "a ladder rung stands before its call")
        XCTAssertFalse(receiver.contains("SpatialSceneStore"), "the socket must not know the scene — it hands the move to a closure")
        XCTAssertTrue(receiver.contains("if move == lastMove, now - lastMoveAt < Self.repeatWindow { return }"),
                      "identical repeats of a move are not dropped — a controller at 60 Hz floods the main actor")

        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("oscIn.onObjectMove = { [weak spatialScene] move in spatialScene?.apply(move) }"),
                      "the receiver's object moves reach no scene")

        // Counterweight (the 10.76.50 law): a trajectory rewrites the scene at the sender's rate,
        // so no ancestor of a menu host may read it in a body.
        for path in ["Sources/Echoelmusic/EchoelmusicApp.swift",
                     "Sources/Echoelmusic/Studio/WorkspaceView.swift",
                     "Sources/Echoelmusic/Studio/EchoelStudioView.swift"] {
            let text = try source(path)
            XCTAssertFalse(text.contains("spatialScene.scene") || text.contains("spatial.scene"),
                           "\(path) reads the live scene — a controller would rebuild it at its send rate")
        }
    }

    // MARK: - Claim 5 — the routing card says what the socket now accepts

    func testTheRoutingCardNamesTheObjectInput() throws {
        let view = try String(contentsOf: try repoRoot().appendingPathComponent("Sources/Echoelmusic/Studio/PatchbayView.swift"),
                              encoding: .utf8)
        XCTAssertTrue(view.contains("and for ADM-OSC object positions /adm/obj/{n}/aed"),
                      "the ON sentence does not name the object input — the card would deny what the socket does")
        XCTAssertTrue(view.contains("and to let a spatial controller move each track over ADM-OSC (/adm/obj/{n}/…). Nothing else is accepted"),
                      "the OFF sentence still says nothing but the cues is accepted")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
