//
//  TheHeadphoneSpaceKeepsTheADMSidesTests.swift
//  Restructure S3a — the conversion from a track's ADM position into the listener space of the
//  future binaural output (`Core/HeadphoneSpace.swift`).
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (all claims) — `HeadphoneSpace`, `SpatialPosition` and `RoomModel`
//    are shipped, Foundation-only value types.
//  · DEVICE PROBE, OPEN AND NOT YET POSSIBLE — that a track is HEARD on the left. Nothing
//    renders this mapping until S3b; this guard pins only the arithmetic it will hand over.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `HeadphoneSpace`, created by this commit — so no assertion has a verdict on the parent.
//  All four claims are FORWARD guards, transcribed in Python against the formulas before push.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheHeadphoneSpaceKeepsTheADMSidesTests: XCTestCase {

    private let room = RoomModel()

    // MARK: 1 — front, left, right, up land where ADM says they are

    func testTheFourDirectionsLandOnTheirSides() {
        let r = HeadphoneSpace.radiusMeters(for: room)
        let front = HeadphoneSpace.point(for: SpatialPosition(azimuth: 0, elevation: 0, distance: 1), in: room)
        XCTAssertEqual(front.x, 0, accuracy: 1e-4)
        XCTAssertEqual(front.y, 0, accuracy: 1e-4)
        XCTAssertEqual(front.z, -r, accuracy: 1e-4, "front is −z: the listener of an environment node faces −z")

        let left = HeadphoneSpace.point(for: SpatialPosition(azimuth: 90, elevation: 0, distance: 1), in: room)
        XCTAssertEqual(left.x, -r, accuracy: 1e-4, """
            ADM azimuth +90 is LEFT (the convention `ADMOSCSender` sends). It landed at x = \(left.x); \
            a positive x would put the track on the right ear while the rig hears it on the left.
            """)
        XCTAssertEqual(left.z, 0, accuracy: 1e-4)

        let right = HeadphoneSpace.point(for: SpatialPosition(azimuth: -90, elevation: 0, distance: 1), in: room)
        XCTAssertEqual(right.x, r, accuracy: 1e-4, "ADM azimuth −90 is RIGHT")

        let up = HeadphoneSpace.point(for: SpatialPosition(azimuth: 0, elevation: 90, distance: 1), in: room)
        XCTAssertEqual(up.y, r, accuracy: 1e-4, "elevation +90 is up, and up is +y in the listener space")
    }

    // MARK: 2 — the same direction as the ADM cartesian every renderer already receives

    func testTheDirectionAgreesWithTheADMCartesian() {
        for (az, el) in [(30, 10), (-135, -20), (170, 45), (-60, 0)] as [(Float, Float)] {
            let position = SpatialPosition(azimuth: az, elevation: el, distance: 0.8)
            let p = HeadphoneSpace.point(for: position, in: room)
            let c = position.cartesian
            let meters = 0.8 * HeadphoneSpace.radiusMeters(for: room)
            XCTAssertEqual(p.x, c.x / 0.8 * meters, accuracy: 1e-3, "x (right) must follow ADM x at az \(az)")
            XCTAssertEqual(p.y, c.z / 0.8 * meters, accuracy: 1e-3, "listener y (up) is ADM z at az \(az)")
            XCTAssertEqual(p.z, -c.y / 0.8 * meters, accuracy: 1e-3, "listener −z (front) is ADM y at az \(az)")
        }
    }

    // MARK: 3 — distance scales to the room and never reaches the head

    func testDistanceScalesToTheRoomAndKeepsItsSideAtZero() {
        let r = HeadphoneSpace.radiusMeters(for: room)
        let half = HeadphoneSpace.point(for: SpatialPosition(azimuth: 0, elevation: 0, distance: 0.5), in: room)
        XCTAssertEqual(half.z, -0.5 * r, accuracy: 1e-4)

        let atHead = HeadphoneSpace.point(for: SpatialPosition(azimuth: 90, elevation: 0, distance: 0), in: room)
        XCTAssertEqual(atHead.x, -HeadphoneSpace.nearestMeters, accuracy: 1e-4, """
            A source at distance 0 must keep its side (left here) at the nearest distance — at the \
            centre of the head an HRTF has no direction to render.
            """)

        XCTAssertLessThanOrEqual(r, min(room.width, room.depth) / 2 + 1e-4,
                                 "distance 1 must not place a source outside the nearer wall")
    }

    // MARK: 4 — non-finite input never reaches a node position

    func testNonFiniteInputStaysFinite() {
        let p = HeadphoneSpace.point(for: SpatialPosition(azimuth: .nan, elevation: .infinity, distance: .nan), in: room)
        XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z.isFinite,
                      "a NaN position must not reach a player node; `SpatialPosition` sanitises, this pins it")
    }
}
