import Foundation
import XCTest
@testable import EchoelCore

final class MIDIFileTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    /// A track of the file read back: absolute ticks and each event's bytes after its delta.
    private struct ReadTrack {
        var events: [(tick: Int, bytes: [UInt8])] = []
        var notes: [String] {
            events.compactMap { event in
                guard let status = event.bytes.first, status & 0xF0 == 0x90 || status & 0xF0 == 0x80 else { return nil }
                let channel = Int(status & 0x0F) + 1
                let on = status & 0xF0 == 0x90
                return "\(event.tick) \(on ? "on" : "off") ch\(channel) \(event.bytes[1])" + (on ? " v\(event.bytes[2])" : "")
            }
        }
        func meta(_ type: UInt8) -> [(tick: Int, payload: [UInt8])] {
            events.compactMap { $0.bytes.count >= 2 && $0.bytes[0] == 0xFF && $0.bytes[1] == type
                ? ($0.tick, Array($0.bytes.dropFirst(3))) : nil }
        }
    }

    private func read(_ data: Data) throws -> (format: Int, division: Int, tracks: [ReadTrack]) {
        let bytes = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(bytes[i]) << 8 | Int(bytes[i + 1]) }
        func u32(_ i: Int) -> Int { u16(i) << 16 | u16(i + 2) }
        XCTAssertEqual(String(decoding: bytes[0..<4], as: UTF8.self), "MThd")
        XCTAssertEqual(u32(4), 6)
        var tracks: [ReadTrack] = []
        var at = 14
        while at < bytes.count {
            XCTAssertEqual(String(decoding: bytes[at..<at + 4], as: UTF8.self), "MTrk")
            let end = at + 8 + u32(at + 4)
            var i = at + 8, tick = 0
            var track = ReadTrack()
            func vlq() -> Int {
                var value = 0
                while true {
                    let b = bytes[i]; i += 1
                    value = value << 7 | Int(b & 0x7F)
                    if b & 0x80 == 0 { return value }
                }
            }
            while i < end {
                tick += vlq()
                let start = i
                if bytes[i] == 0xFF {
                    i += 2
                    let length = vlq()
                    i += length
                } else {
                    i += 3
                }
                track.events.append((tick, Array(bytes[start..<i])))
            }
            XCTAssertEqual(i, end, "events fill the chunk exactly")
            tracks.append(track)
            at = end
        }
        XCTAssertEqual(tracks.count, u16(10))
        return (u16(8), u16(12), tracks)
    }

    private func song() throws -> Project {
        var project = Project(tempo: 120)
        project.name = "Night"
        let keys = TrackID(), drums = TrackID(), keyClip = ClipID(), drumClip = ClipID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "Vox", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        project.tracks[2].instrument.device = .drums
        try Command.createClip(track: keys, id: keyClip, name: "C", length: bar).apply(to: &project)
        try Command.addNotes(keyClip, [Note(pitch: 60, velocity: 90, start: 480, length: 240)]).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: keyClip, start: bar).apply(to: &project)
        try Command.createClip(track: drums, id: drumClip, name: "D", length: bar).apply(to: &project)
        try Command.addNotes(drumClip, [Note(pitch: 36, velocity: 100, start: 0, length: 120)]).apply(to: &project)
        try Command.placeClip(track: drums, id: PlacementID(), clip: drumClip, start: 0).apply(to: &project)
        project.tempoChanges = [TempoChange(tick: 2 * bar, bpm: 90)]
        return project
    }

    func testTheFileIsFormatOneAtTheDocumentResolution() throws {
        let file = try read(MIDIFile.data(for: try song()))
        XCTAssertEqual(file.format, 1)
        XCTAssertEqual(file.division, 960)
        XCTAssertEqual(file.tracks.count, 3, "conductor plus the two instrument tracks; the audio track has no notes")
    }

    func testTheConductorCarriesNameMeterAndEveryTempo() throws {
        let conductor = try read(MIDIFile.data(for: try song())).tracks[0]
        XCTAssertEqual(conductor.meta(0x03).first?.payload, Array("Night".utf8))
        XCTAssertEqual(conductor.meta(0x58).first?.payload, [4, 2, 24, 8])
        let tempos = conductor.meta(0x51).map { ($0.tick, Int($0.payload[0]) << 16 | Int($0.payload[1]) << 8 | Int($0.payload[2])) }
        XCTAssertEqual(tempos.map(\.0), [0, Int(2 * bar)])
        XCTAssertEqual(tempos.map(\.1), [500_000, 666_667])
    }

    func testNotesLandWhereTheArrangementPlaysThem() throws {
        let tracks = try read(MIDIFile.data(for: try song())).tracks
        XCTAssertEqual(tracks[1].meta(0x03).first?.payload, Array("Keys".utf8))
        XCTAssertEqual(tracks[1].notes, ["\(bar + 480) on ch1 60 v90", "\(bar + 720) off ch1 60"])
        XCTAssertEqual(tracks[2].notes, ["0 on ch10 36 v100", "120 off ch10 36"], "drums play on the General MIDI drum channel")
    }

    func testBendsAndControllersAreWrittenOnTheTracksChannel() throws {
        var project = try song()
        let clip = project.tracks[0].clips[0].id
        try Command.setControls(clip, [ControlChange(kind: .pitchBend, start: 480, value: 0x2001),
                                       ControlChange(kind: .controller(number: 1), start: 240, value: 77)]).apply(to: &project)
        let keys = try read(MIDIFile.data(for: project)).tracks[1]
        let controls = keys.events.filter { [0xB0, 0xE0].contains($0.bytes[0] & 0xF0) }
        XCTAssertEqual(controls.map(\.tick), [bar + 240, bar + 480, 2 * bar])
        XCTAssertEqual(controls.map(\.bytes), [[0xB0, 1, 77], [0xE0, 0x01, 0x40], [0xE0, 0x00, 0x40]],
                       "14-bit bend, low seven bits first; the wheel returns to centre where the clip ends")
    }

    func testEveryTrackEndsWithEndOfTrack() throws {
        for track in try read(MIDIFile.data(for: try song())).tracks {
            XCTAssertEqual(track.events.last?.bytes, [0xFF, 0x2F, 0x00])
        }
    }

    func testMelodicTracksTakeEveryChannelButTheDrumOne() throws {
        var project = Project()
        for i in 0..<16 {
            let track = TrackID(), clip = ClipID()
            try Command.addTrack(id: track, name: "T\(i)", kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: "C", length: bar).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 120)]).apply(to: &project)
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        let channels = try read(MIDIFile.data(for: project)).tracks.dropFirst().map { track -> Int in
            Int((track.events.first { $0.bytes.first.map { $0 & 0xF0 == 0x90 } ?? false }?.bytes[0] ?? 0) & 0x0F) + 1
        }
        XCTAssertEqual(channels, [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 1],
                       "channel 10 is the drums'; the sixteenth melodic track wraps to channel 1")
    }

    func testVariableLengthQuantitiesMatchTheStandard() {
        XCTAssertEqual(MIDIFile.variableLength(0), [0x00])
        XCTAssertEqual(MIDIFile.variableLength(0x7F), [0x7F])
        XCTAssertEqual(MIDIFile.variableLength(0x80), [0x81, 0x00])
        XCTAssertEqual(MIDIFile.variableLength(0x2000), [0xC0, 0x00])
        XCTAssertEqual(MIDIFile.variableLength(0x0FFF_FFFF), [0xFF, 0xFF, 0xFF, 0x7F])
        XCTAssertEqual(MIDIFile.variableLength(.max), [0xFF, 0xFF, 0xFF, 0x7F], "clamped to the 28 bits the format holds")
    }
}
