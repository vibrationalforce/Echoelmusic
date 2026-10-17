import XCTest
@testable import EchoelCore

final class TempoMapTests: XCTestCase {
    private let quarter = MusicalTime.ticksPerQuarter
    private let bar = MusicalTime.ticksPerBar(.common)

    func testAConstantMapMatchesTheOldArithmetic() {
        let map = TempoMap(bpm: 120)
        XCTAssertEqual(map.seconds(at: quarter), 0.5, accuracy: 1e-12)
        XCTAssertEqual(map.tick(atSeconds: 0.5), quarter)
        XCTAssertEqual(map.bpm(at: 123_456), 120)
    }

    func testAChangeTakesEffectAtItsTickAndTimeStaysContinuous() {
        // One bar at 120 (2 s), then 60 BPM: the next quarter takes a full second.
        let map = TempoMap(bpm: 120, changes: [TempoChange(tick: bar, bpm: 60)])
        XCTAssertEqual(map.bpm(at: bar - 1), 120)
        XCTAssertEqual(map.bpm(at: bar), 60)
        XCTAssertEqual(map.seconds(at: bar), 2, accuracy: 1e-12)
        XCTAssertEqual(map.seconds(at: bar + quarter), 3, accuracy: 1e-12)
        XCTAssertEqual(map.tick(atSeconds: 3), bar + quarter)
        XCTAssertEqual(map.tick(atSeconds: 1.999_999), bar - 1)
    }

    func testTicksAndSecondsRoundTripAcrossSeveralChanges() {
        let map = TempoMap(bpm: 90, changes: [
            TempoChange(tick: 3 * bar, bpm: 174),
            TempoChange(tick: bar, bpm: 140),     // out of order on purpose
            TempoChange(tick: 7 * bar, bpm: 73.5),
        ])
        XCTAssertEqual(map.segments.map(\.startTick), [0, bar, 3 * bar, 7 * bar])
        var previous = -1.0
        for tick in stride(from: Tick(0), through: 10 * bar, by: 97) {
            let seconds = map.seconds(at: tick)
            XCTAssertGreaterThan(seconds, previous)
            previous = seconds
            // A hair past the tick, so rounding down cannot land one tick early.
            let back = map.tick(atSeconds: seconds + 1e-9)
            XCTAssertEqual(back, tick, "\(tick)")
        }
    }

    func testAChangeAtTickZeroOrADuplicateTickCollapsesToOne() {
        let map = TempoMap(bpm: 100, changes: [TempoChange(tick: bar, bpm: 110), TempoChange(tick: bar, bpm: 120)])
        XCTAssertEqual(map.segments.count, 2)
        XCTAssertEqual(TempoMap(bpm: 100, changes: [TempoChange(tick: 0, bpm: 50)]).segments.count, 1)
    }

    func testNonFiniteSecondsReadAsTheStart() {
        let map = TempoMap(bpm: 120)
        XCTAssertEqual(map.tick(atSeconds: .nan), 0)
        XCTAssertEqual(map.tick(atSeconds: .infinity), 0)
    }

    func testCommandsSetReplaceAndRemoveChanges() throws {
        var project = Project()
        try Command.setTempoChange(at: 2 * bar, bpm: 140).apply(to: &project)
        try Command.setTempoChange(at: bar, bpm: 130).apply(to: &project)
        try Command.setTempoChange(at: 2 * bar, bpm: 150).apply(to: &project)
        XCTAssertEqual(project.tempoChanges, [TempoChange(tick: bar, bpm: 130), TempoChange(tick: 2 * bar, bpm: 150)])
        XCTAssertEqual(project.tempoMap.bpm(at: 2 * bar), 150)

        try Command.removeTempoChange(at: bar).apply(to: &project)
        XCTAssertEqual(project.tempoChanges, [TempoChange(tick: 2 * bar, bpm: 150)])
        XCTAssertThrowsError(try Command.removeTempoChange(at: bar).apply(to: &project))
    }

    func testInvalidChangesAreRefusedAndLeaveTheProjectAlone() {
        var project = Project()
        let bad: [Command] = [
            .setTempoChange(at: 0, bpm: 120),
            .setTempoChange(at: -1, bpm: 120),
            .setTempoChange(at: MusicalTime.maximumTick + 1, bpm: 120),
            .setTempoChange(at: bar, bpm: .nan),
            .setTempoChange(at: bar, bpm: 10),
        ]
        for command in bad {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
        }
        XCTAssertTrue(project.tempoChanges.isEmpty)
    }

    func testThePlanAndTheSampleClockFollowTheMap() throws {
        var project = Project(tempo: 120)
        try Command.setTempoChange(at: bar, bpm: 60).apply(to: &project)
        let plan = PlaybackPlan(compiling: project)
        let time = TimeConversion(tempoMap: plan.tempoMap, sampleRate: 48_000)
        XCTAssertEqual(time.sample(at: bar), 96_000)
        XCTAssertEqual(time.sample(at: bar + quarter), 144_000)
        XCTAssertEqual(time.tick(atSample: 144_000), bar + quarter)
        XCTAssertEqual(time.samplesPerTick(at: bar), 50, accuracy: 1e-12)
    }

    func testChangesSurviveTheCodecAndOldFilesWithoutThemStillOpen() throws {
        var project = Project(name: "Map")
        try Command.setTempoChange(at: bar, bpm: 97).apply(to: &project)
        let data = try ProjectCodec.encode(project)
        XCTAssertEqual(try ProjectCodec.decode(data), project)

        // A format-1 file written before tempo changes existed has no such key.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try ProjectCodec.encode(Project(name: "Old"))) as? [String: Any])
        json.removeValue(forKey: "tempoChanges")
        let old = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.name, "Old")
        XCTAssertTrue(old.tempoChanges.isEmpty)
    }

    func testTheCatalogNamesTheNewCommands() {
        let names = CommandCatalog.all.map(\.name)
        XCTAssertTrue(names.contains("tempo.change.set"))
        XCTAssertTrue(names.contains("tempo.change.remove"))
        XCTAssertEqual(Set(names).count, names.count)
    }
}
