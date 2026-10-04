//
//  EachTrackIsHandedItsPlaceInTheHeadphoneSpaceTests.swift
//  Restructure S3b (founder 2026-10-04, wörtlich: „Bereite S3 als hörbaren binauralen
//  Kopfhörer-Ausgang vor. Abnahme ist eine reproduzierbar hörbare Raumposition samt
//  Wiederherstellung im Stück.")
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–4) — `AudioLanePlayer` with a test-local spy sink: the
//    coordinator hands each audio lane its `HeadphoneSpace.Point` at a region start, again
//    only when it changes, and never invents one. No AVFoundation, no store.
//  · SOURCE-TEXT SCAN (claim 5) — the app wiring reads the point from the piece's OWN scene
//    (`SpatialSceneStore.object(forLane:)` + `scene.room`). `EchoelmusicApp` runs at launch
//    and cannot be instantiated here.
//  · DEVICE PROBE, OPEN AND NOT YET POSSIBLE — that the track is HEARD at that place. The
//    device sink ignores the point until S3c places its nodes in an environment node; this
//    guard pins the hand-over only.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `AudioRegionSink.setSpacePosition` and `AudioLanePlayer.spacePosition`, created by this
//  commit — so no assertion has a verdict on the parent. Claims 1–4 are FORWARD guards,
//  transcribed by reading the event order off `AudioLanePlayer.prime` → `start` and
//  `apply` → `reconcileMix`. Claim 5 was driven against both trees: absent on the parent
//  (ONE absence, #486), present here.
//  COUNTERWEIGHTS (#343): claim 3 (no source injected ⇒ the sink is never called, so every
//  piece without the wiring plays exactly as before) and claim 4's nil lane.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class EachTrackIsHandedItsPlaceInTheHeadphoneSpaceTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let bar = TimelineTime.ticksPerBar

    @MainActor
    private final class Spy: AudioRegionSink {
        var points: [HeadphoneSpace.Point] = []
        var plays = 0
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { plays += 1 }
        func stop() {}
        func setSpacePosition(_ point: HeadphoneSpace.Point) { points.append(point) }
    }

    /// One audio lane with one region covering bars 0–4, a spy sink, and a player.
    private func rig() -> (TimelineDocument, UUID, Spy, AudioLanePlayer) {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let clipID = UUID()
        let region = TimelineRegion(laneID: lane.id, clipID: clipID, startTick: 0,
                                    lengthTicks: 4 * Self.bar)
        let doc = TimelineDocument(lanes: [lane], regions: [region])
        let spy = Spy()
        let url = URL(fileURLWithPath: "/tmp/space.wav")
        let player = AudioLanePlayer(makeSink: { spy },
                                     resolveURL: { $0 == clipID ? url : nil })
        return (doc, lane.id, spy, player)
    }

    private static let left = HeadphoneSpace.Point(x: -2, y: 0, z: 0)
    private static let right = HeadphoneSpace.Point(x: 2, y: 0, z: 0)

    // MARK: 1 — a region start hands the lane its point

    func testARegionStartHandsTheLaneItsPoint() {
        let (doc, laneID, spy, player) = rig()
        let left = Self.left
        player.spacePosition = { id in id == laneID ? left : nil }
        player.prime(in: doc, atTick: 0, bpm: 120)
        XCTAssertEqual(spy.plays, 1, "premise: the region started")
        XCTAssertEqual(spy.points, [left], """
            The lane started without being told where it sits. S3c renders the point the sink \
            was handed — a start that skips it plays the track from wherever the last piece left it.
            """)
    }

    // MARK: 2 — a still lane costs nothing; a move lands within one step

    func testAStillLaneIsNotToldAgainAndAMoveLandsOnTheNextStep() {
        let (doc, laneID, spy, player) = rig()
        let left = Self.left, right = Self.right
        var current = left
        player.spacePosition = { id in id == laneID ? current : nil }
        player.prime(in: doc, atTick: 0, bpm: 120)
        player.apply(in: doc, fromTick: 0, toTick: 10, bpm: 120)
        player.apply(in: doc, fromTick: 10, toTick: 20, bpm: 120)
        XCTAssertEqual(spy.points, [left], "a lane that did not move must not be told again every step")

        current = right
        player.apply(in: doc, fromTick: 20, toTick: 30, bpm: 120)
        XCTAssertEqual(spy.points, [left, right], """
            An ADM-OSC move did not reach the lane on the next transport step. The reconcile \
            inside an unchanged region is where a live move lands — the same place a pan edit does.
            """)
    }

    // MARK: 3 — COUNTERWEIGHT: no source, no call

    func testWithoutASourceTheSinkIsNeverCalled() {
        let (doc, _, spy, player) = rig()
        player.prime(in: doc, atTick: 0, bpm: 120)
        player.apply(in: doc, fromTick: 0, toTick: 10, bpm: 120)
        XCTAssertEqual(spy.plays, 1, "premise: the region started")
        XCTAssertTrue(spy.points.isEmpty, "with nothing injected the coordinator must stay silent about space")
    }

    // MARK: 4 — a lane the scene does not name is never handed a guessed point

    func testALaneTheSceneDoesNotNameKeepsItsLastPoint() {
        let (doc, laneID, spy, player) = rig()
        let left = Self.left
        var named = true
        player.spacePosition = { id in (named && id == laneID) ? left : nil }
        player.prime(in: doc, atTick: 0, bpm: 120)
        named = false
        player.apply(in: doc, fromTick: 0, toTick: 10, bpm: 120)
        XCTAssertEqual(spy.points, [left], """
            A lane the scene stopped naming was handed something. It must keep the last point it \
            was given — a guessed default would jump the track across the head.
            """)
    }

    // MARK: 5 — the app reads the point from the piece's own scene

    func testTheAppReadsThePointFromThePiecesScene() throws {
        let app = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(app.contains("timelinePlayer.audioLanes?.spacePosition = {"), """
            `EchoelmusicApp` no longer injects the lanes' space source. Without it every lane \
            keeps the default and the piece's saved positions never reach the headphones.
            """)
        XCTAssertTrue(app.contains("store.object(forLane: laneID)"),
                      "the point must come from the piece's scene object for that lane")
        XCTAssertTrue(app.contains("HeadphoneSpace.point(for: object.position, in: store.scene.room)"), """
            The conversion must be `HeadphoneSpace.point` over the scene's own room — the one \
            definition of the ADM sides (`TheHeadphoneSpaceKeepsTheADMSidesTests`). A second \
            conversion here could put a track on the other ear than the rig hears it.
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
