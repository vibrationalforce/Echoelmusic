import Foundation
import XCTest
@testable import EchoelCore

final class MIDIFileImportTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    // MARK: Building files

    private func vlq(_ value: UInt32) -> [UInt8] { MIDIFile.variableLength(value) }

    private func chunk(_ tag: String, _ body: [UInt8]) -> [UInt8] {
        let n = UInt32(body.count)
        let length: [UInt8] = [UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)]
        return Array(tag.utf8) + length + body
    }

    private func file(format: UInt16, division: UInt16, tracks: [[UInt8]]) -> Data {
        let count = UInt16(tracks.count)
        var bytes = chunk("MThd", [UInt8(format >> 8), UInt8(format & 0xFF), UInt8(count >> 8), UInt8(count & 0xFF),
                                   UInt8(division >> 8), UInt8(division & 0xFF)])
        for track in tracks { bytes += chunk("MTrk", track + [0x00, 0xFF, 0x2F, 0x00]) }
        return Data(bytes)
    }

    private func notes(_ track: MIDIFileImport.ImportedTrack) -> [String] {
        track.notes.map { "\($0.start)+\($0.length) p\($0.pitch) v\($0.velocity)" }
    }

    // MARK: Reading

    func testWhatTheExportWritesReadsBackNoteForNote() throws {
        var project = Project(tempo: 120)
        let keys = TrackID(), drums = TrackID(), keyClip = ClipID(), drumClip = ClipID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentDevice(drums, .drums).apply(to: &project)
        try Command.createClip(track: keys, id: keyClip, name: "C", length: bar).apply(to: &project)
        try Command.addNotes(keyClip, [Note(pitch: 60, velocity: 90, start: 480, length: 240),
                                       Note(pitch: 64, velocity: 70, start: 480, length: 960)]).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: keyClip, start: bar).apply(to: &project)
        try Command.createClip(track: drums, id: drumClip, name: "D", length: bar).apply(to: &project)
        try Command.addNotes(drumClip, [Note(pitch: 36, velocity: 100, start: 0, length: 120)]).apply(to: &project)
        try Command.placeClip(track: drums, id: PlacementID(), clip: drumClip, start: 0).apply(to: &project)
        try Command.setTimeSignature(TimeSignature(3, 4)).apply(to: &project)
        try Command.setTempoChange(at: 2 * bar, bpm: 90).apply(to: &project)

        let content = try MIDIFileImport.read(MIDIFile.data(for: project))
        XCTAssertEqual(content.tracks.map(\.name), ["Keys", "Drums"])
        XCTAssertEqual(content.tracks.map(\.isDrums), [false, true])
        XCTAssertEqual(notes(content.tracks[0]), ["\(bar + 480)+240 p60 v90", "\(bar + 480)+960 p64 v70"])
        XCTAssertEqual(notes(content.tracks[1]), ["0+120 p36 v100"])
        XCTAssertEqual(content.tempo ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(content.tempoChanges.map(\.tick), [2 * bar])
        XCTAssertEqual(content.tempoChanges.first?.bpm ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(content.timeSignature, TimeSignature(3, 4))
    }

    func testTicksAreScaledToTheDocumentResolution() throws {
        // 96 per quarter: a quarter note at the second beat lands on 960, one quarter long.
        let track: [UInt8] = vlq(96) + [0x90, 60, 100] + vlq(96) + [0x80, 60, 0]
        let content = try MIDIFileImport.read(file(format: 1, division: 96, tracks: [track]))
        XCTAssertEqual(notes(content.tracks[0]), ["960+960 p60 v100"])
        XCTAssertNil(content.tempo, "a file without a tempo leaves the song's")
    }

    func testRunningStatusAndANoteOnAtVelocityZeroEndANote() throws {
        // One status byte, then data only; the second "on" at velocity 0 is the off.
        let track: [UInt8] = [0x00, 0x91, 62, 80] + vlq(480) + [62, 0] + [0x00, 64, 70] + vlq(240) + [64, 0]
        let content = try MIDIFileImport.read(file(format: 1, division: 960, tracks: [track]))
        XCTAssertEqual(notes(content.tracks[0]), ["0+480 p62 v80", "480+240 p64 v70"])
    }

    func testFormatZeroIsSplitByChannelAndChannelTenIsTheDrumKit() throws {
        let track: [UInt8] = [0x00, 0xFF, 0x03, 0x04] + Array("Song".utf8)
            + [0x00, 0x90, 60, 100, 0x00, 0x99, 36, 110]
            + vlq(480) + [0x80, 60, 0, 0x00, 0x89, 36, 0]
        let content = try MIDIFileImport.read(file(format: 0, division: 960, tracks: [track]))
        XCTAssertEqual(content.tracks.count, 2)
        XCTAssertEqual(content.tracks.map(\.isDrums), [false, true])
        XCTAssertEqual(content.tracks.map(\.name), ["Song Ch 1", "Song Ch 10"])
    }

    func testControllersProgramsAndSystemExclusiveAreSteppedOver() throws {
        let track: [UInt8] = [0x00, 0xC0, 5, 0x00, 0xB0, 7, 100, 0x00, 0xF0, 0x03, 0x7E, 0x00, 0xF7,
                              0x00, 0xE0, 0x00, 0x40, 0x00, 0xD0, 50, 0x00, 0x90, 67, 90] + vlq(960) + [0x80, 67, 0]
        let content = try MIDIFileImport.read(file(format: 1, division: 960, tracks: [track]))
        XCTAssertEqual(notes(content.tracks[0]), ["0+960 p67 v90"])
    }

    func testANoteNeverEndedStopsWhereItsTrackDoes() throws {
        let track: [UInt8] = [0x00, 0x90, 60, 100] + vlq(1_920) + [0xFF, 0x01, 0x00]
        let content = try MIDIFileImport.read(file(format: 1, division: 960, tracks: [track]))
        XCTAssertEqual(notes(content.tracks[0]), ["0+1920 p60 v100"])
    }

    func testWhatIsNotAReadableFileIsRefusedWithItsReason() {
        func refusal(_ data: Data) -> MIDIFileImport.ReadError? {
            do {
                _ = try MIDIFileImport.read(data)
                return nil
            } catch let error as MIDIFileImport.ReadError {
                return error
            } catch {
                return nil
            }
        }
        let note: [UInt8] = [0x00, 0x90, 60, 100, 0x10, 0x80, 60, 0]
        XCTAssertEqual(refusal(Data("not midi at all".utf8)), .notAMIDIFile)
        XCTAssertEqual(refusal(file(format: 2, division: 960, tracks: [note])), .unsupportedFormat(2))
        XCTAssertEqual(refusal(file(format: 1, division: 0xE728, tracks: [note])), .timecodeDivision)
        XCTAssertEqual(refusal(file(format: 1, division: 960, tracks: [[0x00, 0xFF, 0x03, 0x00]])), .noNotes)
        XCTAssertEqual(refusal(file(format: 1, division: 960, tracks: [[0x00, 60, 100]])), .damaged,
                       "a data byte with no status before it")
        var cut = [UInt8](file(format: 1, division: 960, tracks: [note]))
        cut.removeLast(6)
        XCTAssertEqual(refusal(Data(cut)), .damaged, "a chunk that runs past the end of the file")
        XCTAssertEqual(refusal(Data(count: MIDIFileImport.maximumBytes + 1)), .tooLarge)
        for each in [MIDIFileImport.ReadError.notAMIDIFile, .tooLarge, .unsupportedFormat(2), .timecodeDivision,
                     .damaged, .tooManyNotes, .noNotes, .tooManyTracks(needed: 3, free: 1)] {
            XCTAssertFalse(each.explanation.isEmpty)
        }
    }

    // MARK: Commands

    private func twoTrackContent() throws -> MIDIFileImport.Content {
        let lead: [UInt8] = [0x00, 0xFF, 0x03, 0x04] + Array("Lead".utf8) + [0x00, 0x90, 72, 100] + vlq(4_000) + [0x80, 72, 0]
        let beat: [UInt8] = [0x00, 0x99, 36, 100] + vlq(240) + [0x89, 36, 0]
        let conductor: [UInt8] = [0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,   // 500 000 µs = 120 BPM
                                  0x00, 0xFF, 0x58, 0x04, 0x06, 0x03, 24, 8]   // 6/8
            + vlq(UInt32(4 * 960)) + [0xFF, 0x51, 0x03, 0x09, 0x27, 0xC0]       // 600 000 µs = 100 BPM
        return try MIDIFileImport.read(file(format: 1, division: 960, tracks: [conductor, lead, beat]))
    }

    func testAnEmptySongTakesTheFilesTracksTempoAndMeterInOneStep() async throws {
        let content = try twoTrackContent()
        try await MainActor.run {
            let store = ProjectStore(project: Project(tempo: 90))
            let commands = try MIDIFileImport.commands(for: content, fileName: "Groove", in: store.project)
            try store.perform(commands, title: "Import MIDI")
            let project = store.project
            XCTAssertEqual(project.tracks.map(\.name), ["Lead", "Groove 2"])
            XCTAssertEqual(project.tracks.map(\.instrument.device).last, .drums)
            XCTAssertEqual(project.timeSignature, TimeSignature(6, 8))
            XCTAssertEqual(project.tempo, 120, accuracy: 0.001)
            XCTAssertEqual(project.tempoChanges.map(\.tick), [4 * 960])
            let sixEight = MusicalTime.ticksPerBar(TimeSignature(6, 8))
            XCTAssertEqual(project.tracks[0].clips.first?.length, 2 * sixEight, "the clip ends on the bar after its last note")
            XCTAssertEqual(project.tracks[0].placements.map(\.start), [0])
            XCTAssertTrue(project.arrangementHasEvents)
            store.undo()
            XCTAssertTrue(store.project.tracks.isEmpty, "one undo takes the whole import back")
            XCTAssertEqual(store.project.tempo, 90, accuracy: 0.001)
        }
    }

    func testASongThatPlaysKeepsItsTempoAndMeter() throws {
        var project = Project(tempo: 100)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Bass", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "B", length: bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 40, start: 0, length: 240)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        let commands = try MIDIFileImport.commands(for: try twoTrackContent(), fileName: "Groove", in: project)
        for command in commands { try command.apply(to: &project) }
        XCTAssertEqual(project.tempo, 100, accuracy: 0.001)
        XCTAssertEqual(project.timeSignature, .common)
        XCTAssertTrue(project.tempoChanges.isEmpty)
        XCTAssertEqual(project.tracks.count, 3)
    }

    func testAFileWithMoreTracksThanTheSongHasRoomForIsRefused() throws {
        var project = Project()
        for i in 0..<(Track.limit(for: .instrument) - 1) {
            try Command.addTrack(id: TrackID(), name: "T\(i)", kind: .instrument, index: nil).apply(to: &project)
        }
        XCTAssertThrowsError(try MIDIFileImport.commands(for: try twoTrackContent(), fileName: "Groove", in: project)) {
            XCTAssertEqual($0 as? MIDIFileImport.ReadError, .tooManyTracks(needed: 2, free: 1))
        }
    }
}
