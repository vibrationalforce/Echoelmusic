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
        XCTAssertEqual(lane.value(atPosition: 960.5) ?? 0, -12 + 12 * 0.5 / 960, accuracy: 1e-9, "between ticks too")
        XCTAssertEqual(lane.value(atPosition: .nan), -12, "a position that is not finite reads the start")
        let time = TimeConversion(bpm: 120, sampleRate: 48_000)
        XCTAssertEqual(time.position(atSample: 12), 0.48, accuracy: 1e-9, "25 samples per tick at 120 BPM")
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

    func testAPluginParameterIsAutomatedAsAPositionAndGoesWithItsUnit() throws {
        let made = try project()
        var song = made.0
        let track = made.1
        let synth = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                    manufacturer: PluginComponent.code("Acme"), name: "Mini", manufacturerName: "Acme")
        let delay = PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("Dely"),
                                    manufacturer: PluginComponent.code("Acme"), name: "Delay", manufacturerName: "Acme")
        let insert = InsertID()
        let cutoff = ParameterAddress.plugin(track, PluginParameter(.instrument, address: 7))
        let feedback = ParameterAddress.plugin(track, PluginParameter(.insert(insert), address: 3))
        let points = [AutomationPoint(tick: 0, value: 0), AutomationPoint(tick: 960, value: 1)]
        XCTAssertThrowsError(try Command.setAutomation(cutoff, points: points).apply(to: &song), "no plugin yet")

        try Command.setInstrumentPlugin(track, synth).apply(to: &song)
        try Command.addInsert(track: track, id: insert, plugin: delay, index: nil).apply(to: &song)
        try Command.setAutomation(cutoff, points: points).apply(to: &song)
        try Command.setAutomation(feedback, points: points).apply(to: &song)
        XCTAssertThrowsError(try Command.setAutomation(cutoff, points: [AutomationPoint(tick: 0, value: 2)]).apply(to: &song),
                             "a position is 0…1")
        XCTAssertEqual(ParameterKey(rawValue: cutoff.key.rawValue).pluginParameter, PluginParameter(.instrument, address: 7))
        XCTAssertEqual(feedback.key.pluginParameter, PluginParameter(.insert(insert), address: 3))
        XCTAssertNil(ParameterKey(rawValue: "plugin.insert/nonsense/3").pluginParameter)

        let decoded = try ProjectCodec.decode(ProjectCodec.encode(song))
        XCTAssertEqual(decoded.automation, song.automation)

        try Command.removeInsert(track: track, insert).apply(to: &song)
        XCTAssertNil(song.automation(for: feedback), "the insert took its lanes")
        XCTAssertNotNil(song.automation(for: cutoff))
        try Command.setInstrumentPlugin(track, synth).apply(to: &song)
        XCTAssertNotNil(song.automation(for: cutoff), "the same plugin keeps them")
        try Command.setInstrumentPlugin(track, nil).apply(to: &song)
        XCTAssertNil(song.automation(for: cutoff), "another plugin's addresses mean nothing")
    }
}
