import XCTest
@testable import EchoelCore

final class AutomationTests: XCTestCase {
    private func project() throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        return (project, track)
    }

    func testALaneDrawsStraightLinesAndHoldsItsEnds() {
        let lane = AutomationLane(target: .masterVolume, points: [AutomationPoint(tick: 960, value: -12),
                                                                  AutomationPoint(tick: 1_920, value: 0)])
        XCTAssertEqual(lane.value(at: 0), -12)
        XCTAssertEqual(lane.value(at: 1_440), -6)
        XCTAssertEqual(lane.value(at: 9_999), 0)
        XCTAssertNil(AutomationLane(target: .masterVolume, points: []).value(at: 0))
    }

    func testABentSegmentStillMeetsItsPointsAndBendsBetweenThem() {
        let rising = AutomationLane(target: .masterVolume, points: [AutomationPoint(tick: 0, value: 0, curve: 0.8),
                                                                    AutomationPoint(tick: 1_000, value: 1)])
        XCTAssertEqual(rising.value(at: 0), 0)
        XCTAssertEqual(rising.value(at: 1_000), 1)
        XCTAssertLessThan(rising.value(at: 500) ?? 1, 0.2, "exponential: slow at first")
        let falling = AutomationLane(target: .masterVolume, points: [AutomationPoint(tick: 0, value: 0, curve: -0.8),
                                                                     AutomationPoint(tick: 1_000, value: 1)])
        XCTAssertGreaterThan(falling.value(at: 500) ?? 0, 0.8, "logarithmic: early")
        let old = Data(#"{"tick":0,"value":0.5}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(AutomationPoint.self, from: old).curve, 0, "an older file is straight")
    }

    func testSetAutomationValidatesAndAnEmptyListRemovesTheLane() throws {
        let made = try project()
        var song = made.0
        let track = made.1
        let volume = ParameterAddress.volume(track)
        try Command.setAutomation(volume, points: [AutomationPoint(tick: 0, value: -6)]).apply(to: &song)
        XCTAssertEqual(song.automation(for: volume)?.points.count, 1)

        let before = song
        XCTAssertThrowsError(try Command.setAutomation(volume, points: [AutomationPoint(tick: 0, value: 40)]).apply(to: &song))
        XCTAssertThrowsError(try Command.setAutomation(volume, points: [AutomationPoint(tick: 10, value: 0),
                                                                        AutomationPoint(tick: 10, value: 0)]).apply(to: &song))
        XCTAssertThrowsError(try Command.setAutomation(.tempo, points: [AutomationPoint(tick: 0, value: 120)]).apply(to: &song),
                             "the tempo has its own track")
        XCTAssertEqual(song, before, "a refused edit leaves the song as it was")

        try Command.setAutomation(volume, points: []).apply(to: &song)
        XCTAssertTrue(song.automation.isEmpty)
    }

    func testRemovingATrackRemovesItsLanesAndAFileKeepsThem() throws {
        let made = try project()
        var song = made.0
        let track = made.1
        try Command.setAutomation(.pan(track), points: [AutomationPoint(tick: 0, value: 0.5)]).apply(to: &song)
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(song))
        XCTAssertEqual(decoded.automation, song.automation)
        try Command.removeTrack(track).apply(to: &song)
        XCTAssertTrue(song.automation.isEmpty)
    }
}
