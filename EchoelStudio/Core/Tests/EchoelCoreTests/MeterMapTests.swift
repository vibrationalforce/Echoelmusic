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

    // MARK: - Where bars are counted

    /// Snapping, a tap, the song's length, a short video export and the assistant's "bar 4" all
    /// count the bars of the meter, not the first bar's length.
    func testEveryBarCountReadsTheMeter() throws {
        var project = Project()
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)).apply(to: &project)
        let meter = project.meterMap
        XCTAssertEqual(Arranging.nearestBar(2 * bar44 + bar78 / 2 + 1, meter: meter), 2 * bar44 + bar78)
        XCTAssertEqual(Arranging.barStart(2 * bar44 + bar78 + 5, meter: meter), 2 * bar44 + bar78)

        // "Bar 4" is the second bar of 7/8.
        let commands = try AgentTools.commands(for: .writeNotes(track: "Keys", notes: "C4 1 1", bar: 4, bars: 2, replace: false),
                                               in: project)
        for command in commands { try command.apply(to: &project) }
        let placement = try XCTUnwrap(project.track(keys)?.placements.first)
        XCTAssertEqual(placement.start, 2 * bar44 + bar78)
        XCTAssertEqual(project.track(keys)?.clips.first?.length, 2 * bar78)
        XCTAssertEqual(Arranging.songBars(of: project), 5)
        XCTAssertTrue(AgentTools.describe(project).contains("Time signature changes: bar 3 7/8."))
        XCTAssertTrue(AgentTools.describe(project).contains("bars 4–5"), AgentTools.describe(project))

        let automate = try AgentTools.commands(for: .automate(track: "Keys", parameter: "volume", fromBar: 3, toBar: 5,
                                                              from: -6, to: 0, curve: 0), in: project)
        guard case let .setAutomation(_, points)? = automate.first else { return XCTFail("\(automate)") }
        XCTAssertEqual(points.map(\.tick), [2 * bar44, 2 * bar44 + 2 * bar78])

        XCTAssertEqual(Arranging.ticks(movingBars: 1, from: bar44, meter: meter), bar44, "bar 2 to bar 3: a 4/4 bar")
        XCTAssertEqual(Arranging.ticks(movingBars: 1, from: 2 * bar44, meter: meter), bar78, "bar 3 to bar 4: a 7/8 bar")
        XCTAssertEqual(Arranging.ticks(movingBars: -1, from: 2 * bar44 + bar78, meter: meter), -bar78)
        XCTAssertEqual(Arranging.ticks(movingBars: .max, from: 0, meter: meter), 0, "no overflow")
        XCTAssertEqual(Arranging.songLoop(songEnd: 2 * bar44 + 1, meter: meter), 0..<(2 * bar44 + bar78))
        XCTAssertEqual(Arranging.songLoop(songEnd: 0, meter: meter), 0..<bar44)
        // The constant case is the loop the engine has always played.
        XCTAssertEqual(Arranging.songLoop(songEnd: 5 * bar44 + 3, meter: MeterMap(signature: .common)), 0..<(6 * bar44))

        let range = try XCTUnwrap(VideoExportPlan.shortRange(in: project, startBar: 3, seconds: 0.1))
        XCTAssertEqual(range, (2 * bar44)...(2 * bar44 + bar78), "at least one bar of 7/8")
    }

    /// A MIDI file carries every signature as a 0x58 at its bar line; read back into an empty
    /// song, the meter is the same — and a clip ends on a bar line of it.
    func testTheMeterRoundTripsThroughAMIDIFile() throws {
        var song = Project(name: "Odd")
        let keys = TrackID(), clip = ClipID()
        try Command.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)).apply(to: &song)
        try Command.setTimeSignatureChange(at: 2 * bar44 + bar78, TimeSignature(3, 4)).apply(to: &song)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &song)
        try Command.createClip(track: keys, id: clip, name: "C", length: 2 * bar44 + bar78 + 100).apply(to: &song)
        try Command.addNotes(clip, [Note(pitch: 60, start: 2 * bar44 + bar78 + 50, length: 40)]).apply(to: &song)
        try Command.placeClip(track: keys, id: PlacementID(), clip: clip, start: 0).apply(to: &song)

        let content = try MIDIFileImport.read(MIDIFile.data(for: song))
        XCTAssertEqual(content.timeSignature, .common)
        XCTAssertEqual(content.timeSignatureChanges, song.timeSignatureChanges)
        var empty = Project()
        try Command.setTimeSignatureChange(at: bar44, TimeSignature(5, 4)).apply(to: &empty)
        for command in try MIDIFileImport.commands(for: content, fileName: "Odd", in: empty) {
            try command.apply(to: &empty)
        }
        XCTAssertEqual(empty.meterMap, song.meterMap, "the file's meter replaces the song's")
        let imported = try XCTUnwrap(empty.tracks.last?.clips.first)
        XCTAssertEqual(imported.length, 2 * bar44 + bar78 + 3 * quarter, "the clip ends on the next 3/4 bar line")
    }

    /// A clip counts the song's bars from where it is first placed; a session-only clip, the
    /// first bar's. VoiceOver says its notes and steps in those bars.
    func testAClipCountsTheBarsWhereItIsPlaced() throws {
        var project = Project()
        let keys = TrackID(), clip = ClipID(), loose = ClipID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.setTimeSignatureChange(at: 2 * bar44, TimeSignature(7, 8)).apply(to: &project)
        try Command.createClip(track: keys, id: clip, name: "C", length: 2 * bar44).apply(to: &project)
        try Command.createClip(track: keys, id: loose, name: "L", length: bar44).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: clip, start: 3 * bar44).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: clip, start: bar44).apply(to: &project)

        let meter = project.clipMeter(clip)
        XCTAssertEqual(meter.segments.map(\.startTick), [0, bar44], "from bar 2: one bar of 4/4, then 7/8")
        XCTAssertEqual(meter.signature(at: bar44), TimeSignature(7, 8))
        XCTAssertTrue(project.clipMeter(loose).isConstant)
        XCTAssertEqual(project.meterMap.starting(at: 0), project.meterMap)

        XCTAssertEqual(NoteEditing.spokenPosition(bar44 + bar78 + 480, meter: meter, grid: 240), "bar 3, beat 2", "an eighth-note beat of 7/8")
        XCTAssertEqual(NoteEditing.spokenPosition(1_440, meter: meter, grid: 240), "bar 1, beat 2, plus 2 sixteenths")
        XCTAssertEqual(NoteEditing.spokenPosition(1_440, meter: MeterMap(signature: .common), grid: 240),
                       NoteEditing.spokenPosition(1_440, signature: .common, grid: 240))
        XCTAssertEqual(NoteEditing.spokenStep(18, step: 240, meter: meter, clipLength: 2 * bar44), "step 19, bar 2, beat 2")
        XCTAssertEqual(NoteEditing.spokenStep(5, step: 240, meter: MeterMap(signature: .common), clipLength: 2 * bar44),
                       NoteEditing.spokenStep(5, step: 240, signature: .common, clipLength: 2 * bar44))
    }

    /// The Field's bar phase runs once per bar of the meter playing: a 7/8 bar is half way through
    /// at its fourth eighth note and a quarter, and wraps on its own bar line.
    func testTheFieldsBarPhaseFollowsTheMeter() {
        let map = meter
        func frame(_ tick: Tick) -> FieldFrame {
            FieldFrame.at(tick: Double(tick), meter: map, context: MusicalContext(), level: 0,
                          pulse: nil, hrv: nil, coherence: nil, isPlaying: true)
        }
        XCTAssertEqual(frame(2 * bar44 + bar78 / 2).barPhase, 0.5, accuracy: 1e-12)
        XCTAssertEqual(frame(2 * bar44 + bar78).barPhase, 0, accuracy: 1e-12, "a 7/8 bar line")
        XCTAssertEqual(frame(2 * bar44 + 240).beatPhase, 0.5, accuracy: 1e-12, "an eighth-note beat")
        for tick in stride(from: Tick(0), to: 2 * bar44, by: 97) {
            let old = FieldFrame.at(tick: Double(tick), signature: .common, context: MusicalContext(), level: 0,
                                    pulse: nil, hrv: nil, coherence: nil, isPlaying: true)
            XCTAssertEqual(frame(tick), old, "before the change, the frame of one signature")
        }
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
