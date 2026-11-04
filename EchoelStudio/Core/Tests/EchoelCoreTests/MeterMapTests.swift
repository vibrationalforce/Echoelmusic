import Foundation
import XCTest
@testable import EchoelCore

/// Time signature changes: bars of another length from a bar line on.
final class MeterMapTests: XCTestCase {
    private let quarter = MusicalTime.ticksPerQuarter
    private let bar44 = MusicalTime.ticksPerBar(.common)
    private let bar78 = MusicalTime.ticksPerBar(TimeSignature(7, 8))

    /// Two bars of 4/4, three of 7/8, then 3/4.
    private var meter: MeterMap {
        MeterMap(signature: .common, changes: [
            TimeSignatureChange(tick: 2 * MusicalTime.ticksPerBar(.common) + 3 * MusicalTime.ticksPerBar(TimeSignature(7, 8)),
                                signature: TimeSignature(3, 4)),
            TimeSignatureChange(tick: 2 * MusicalTime.ticksPerBar(.common), signature: TimeSignature(7, 8)),
        ])
    }

    func testAConstantMeterAnswersAsTheOldArithmetic() {
        let map = MeterMap(signature: TimeSignature(6, 8))
        XCTAssertTrue(map.isConstant)
        let bar = MusicalTime.ticksPerBar(TimeSignature(6, 8)), beat = MusicalTime.ticksPerBeat(TimeSignature(6, 8))
        for tick in stride(from: Tick(0), through: 40 * bar, by: 173) {
            XCTAssertEqual(map.barStart(at: tick), tick / bar * bar)
            XCTAssertEqual(map.bar(at: tick), tick / bar)
            XCTAssertEqual(map.beatStart(at: tick), tick / beat * beat)
            XCTAssertEqual(map.nearestBarLine(tick), Arranging.nearestBar(tick, signature: TimeSignature(6, 8)))
        }
        XCTAssertEqual(map.tick(ofBar: 9), 9 * bar)
    }

    func testBarsCountOnAcrossEachChange() {
        let map = meter
        XCTAssertEqual(map.segments.map(\.startBar), [0, 2, 5])
        XCTAssertEqual(map.signature(at: 2 * bar44 - 1), .common)
        XCTAssertEqual(map.signature(at: 2 * bar44), TimeSignature(7, 8))
        XCTAssertEqual(map.ticksPerBar(at: 2 * bar44 + 1), bar78)
        XCTAssertEqual(map.ticksPerBeat(at: 2 * bar44 + 1), quarter / 2)
        let three = 2 * bar44 + 3 * bar78
        XCTAssertEqual(map.signature(at: three), TimeSignature(3, 4))
        XCTAssertEqual(map.tick(ofBar: 3), 2 * bar44 + bar78, "bar 4 is the second bar of 7/8")
        XCTAssertEqual(map.tick(ofBar: 6), three + 3 * quarter)
        for index in Int64(0)...12 {
            let tick = map.tick(ofBar: index)
            XCTAssertTrue(map.isBarLine(tick))
            XCTAssertEqual(map.bar(at: tick), index)
            XCTAssertEqual(map.bar(at: tick + 1), index)
            XCTAssertEqual(map.barStart(at: tick + 1), tick)
            XCTAssertEqual(map.nextBarLine(atOrAfter: tick + 1), map.tick(ofBar: index + 1))
            XCTAssertEqual(map.beatStart(at: tick), tick, "a bar line is a beat in both signatures")
        }
        XCTAssertFalse(map.isBarLine(2 * bar44 + quarter * 4), "4/4's bar length is no bar line in 7/8")
        XCTAssertEqual(map.nearestBarLine(2 * bar44 + bar78 / 2 - 1), 2 * bar44)
        XCTAssertEqual(map.nearestBarLine(2 * bar44 + bar78 / 2), 2 * bar44 + bar78)
    }

    func testAChangeOffABarLineCountsFromTheNextOneAndExtremeBarsSaturate() {
        let map = MeterMap(signature: .common, changes: [TimeSignatureChange(tick: bar44 + 1, signature: TimeSignature(3, 4))])
        XCTAssertEqual(map.segments.map(\.startTick), [0, 2 * bar44])
        XCTAssertEqual(map.tick(ofBar: .max), .max)
        XCTAssertEqual(MeterMap(signature: .common, changes: [TimeSignatureChange(tick: 0, signature: TimeSignature(5, 4))])
            .signature(at: 0), TimeSignature(5, 4))
    }

    // MARK: - Format

    func testASongWithoutChangesIsStoredExactlyAsBefore() throws {
        let data = try ProjectCodec.encode(Project(name: "Plain"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(root["timeSignatureChanges"])
    }

    func testChangesSurviveTheCodecAndAnOffBarChangeRefusesTheSong() throws {
        var project = Project(name: "Meter")
        try Command.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)).apply(to: &project)
        let data = try ProjectCodec.encode(project)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stored = try XCTUnwrap(root["timeSignatureChanges"] as? [[String: Any]])
        XCTAssertEqual(Set(stored[0].keys), ["tick", "numerator", "denominator"])
        XCTAssertEqual(try ProjectCodec.decode(data), project)

        var json = root
        json["timeSignatureChanges"] = [["tick": 2 * bar44 + 1, "numerator": 7, "denominator": 8]]
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)), "off a bar line")
        json["timeSignatureChanges"] = [["tick": 2 * bar44, "numerator": 7, "denominator": 3]]
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)), "a denominator no song has")
        json["timeSignatureChanges"] = []
        XCTAssertTrue(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)).timeSignatureChanges.isEmpty)
    }

    // MARK: - Commands

    func testCommandsSetReplaceRemoveAndUndo() async throws {
        let bar44 = self.bar44, bar78 = self.bar78
        try await MainActor.run {
            let store = ProjectStore(project: Project())
            try store.perform(.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)))
            try store.perform(.setTimeSignatureChange(at: 2 * bar44 + 3 * bar78, TimeSignature(3, 4)))
            XCTAssertEqual(store.project.meterMap.segments.count, 3)
            XCTAssertEqual(store.undoTitle, "Set Time Signature Change")
            store.undo()
            XCTAssertEqual(store.project.timeSignatureChanges.map(\.tick), [2 * bar44])
            try store.perform(.setTimeSignatureChange(at: 2 * bar44, TimeSignature(5, 4)))
            XCTAssertEqual(store.project.timeSignatureChanges, [TimeSignatureChange(tick: 2 * bar44, signature: TimeSignature(5, 4))])
            try store.perform(.removeTimeSignatureChange(at: 2 * bar44))
            XCTAssertTrue(store.project.timeSignatureChanges.isEmpty)
            store.undo()
            XCTAssertEqual(store.project.timeSignatureChanges.count, 1)
        }
    }

    /// A change off a bar line, or one that would push a later change off its bar line, is
    /// refused and leaves the song alone — also through the first bar's signature.
    func testAChangeThatLeavesABarLineIsRefused() throws {
        var project = Project()
        try Command.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)).apply(to: &project)
        try Command.setTimeSignatureChange(at: 2 * bar44 + bar78, TimeSignature(3, 4)).apply(to: &project)
        let before = project
        let refused: [Command] = [
            .setTimeSignatureChange(at: 0, TimeSignature(3, 4)),
            .setTimeSignatureChange(at: bar44 + quarter, TimeSignature(3, 4)),
            .setTimeSignatureChange(at: 2 * bar44, TimeSignature(3, 3)),
            .setTimeSignatureChange(at: MusicalTime.maximumTick + bar44, TimeSignature(3, 4)),
            // 5/4 for bars 3+ would put the 3/4 change half way into a bar.
            .setTimeSignatureChange(at: 2 * bar44, TimeSignature(5, 4)),
            // Without the 7/8, the 3/4 change would be off a 4/4 bar line.
            .removeTimeSignatureChange(at: 2 * bar44),
            .removeTimeSignatureChange(at: 3 * bar44),
            // 3/4 from bar 1 puts 2 · 3840 on no 3/4 bar line.
            .setTimeSignature(TimeSignature(5, 4)),
        ]
        for command in refused {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
            XCTAssertEqual(project, before, "\(command)")
        }
        try Command.setTimeSignature(TimeSignature(2, 4)).apply(to: &project)
        XCTAssertEqual(project.meterMap.segments.map(\.startBar), [0, 4, 5], "2/4 keeps every later bar line")
        XCTAssertTrue(CommandCatalog.all.map(\.name).contains("meter.change.set"))
    }
}
