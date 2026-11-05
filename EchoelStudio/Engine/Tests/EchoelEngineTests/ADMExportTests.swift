import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelEngine

/// Export ADM BWF: a BW64 file whose channels are the bed and one object per track, whose `chna`
/// and `axml` describe them, whose object positions are the pans, and whose bytes are the same
/// every time the same song is exported.
final class ADMExportTests: XCTestCase {
    private struct Song {
        var project: Project
        var keys: TrackID
        var lead: TrackID
        var loop: TrackID
        var room: TrackID
        var samples: [MediaID: SampleBuffer]
    }

    /// Two synth tracks, Keys panned left and Lead swept by pan automation; an audio track; a
    /// return fed by Keys.
    private func song() throws -> Song {
        var project = Project(tempo: 120)
        let keys = TrackID(), lead = TrackID(), loop = TrackID(), room = TrackID()
        let bar = MusicalTime.ticksPerBar(project.timeSignature)
        for (track, name, pitch) in [(keys, "Keys", 60), (lead, "Lead", 67)] {
            let clip = ClipID()
            try Command.addTrack(id: track, name: name, kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: name, length: bar).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: pitch, start: 0, length: 960)]).apply(to: &project)
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        try Command.setPan(.track(keys), pan: -0.5).apply(to: &project)
        try Command.setAutomation(.pan(lead), points: [AutomationPoint(tick: 0, value: 1),
                                                       AutomationPoint(tick: bar, value: -1)]).apply(to: &project)
        let file = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 24_000, sampleRate: 48_000)
        try Command.addTrack(id: loop, name: "Loop", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(file).apply(to: &project)
        try Command.placeAudio(track: loop, id: RegionID(), media: file.id, start: 0).apply(to: &project)
        try Command.setPan(.track(loop), pan: 0.25).apply(to: &project)
        try Command.addTrack(id: room, name: "Room", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.setSend(track: keys, to: room, db: -6).apply(to: &project)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.25, count: 24_000), sampleRate: 48_000))
        return Song(project: project, keys: keys, lead: lead, loop: loop, room: room, samples: [file.id: buffer])
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ADMExportTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func export(_ s: Song, in folder: URL, named name: String = "song.wav") throws -> (ADMBWF.Layout, Data) {
        let url = folder.appendingPathComponent(name)
        let layout = try XCTUnwrap(ADMExport.export(s.project, title: "Song", samples: s.samples,
                                                    scratch: folder.appendingPathComponent("scratch"), to: url))
        return (layout, try Data(contentsOf: url))
    }

    func testEveryTrackOnTheMasterIsAnObjectAndTheReturnIsTheBed() throws {
        let s = try song()
        let plan = try XCTUnwrap(ADMExport.plan(for: s.project, samples: s.samples))
        XCTAssertEqual(plan.parts.map(\.track), [s.keys, s.lead, s.loop, s.room])
        XCTAssertEqual(plan.parts.map(\.role), [.object(0), .object(1), .object(2), .bed])
        XCTAssertEqual(plan.objectSong.track(s.keys)?.mixer.pan, 0, "an object's place is in the metadata")
        XCTAssertNil(plan.objectSong.automation(for: .pan(s.lead)))
        XCTAssertEqual(plan.song, s.project)
    }

    func testTheFileHasTheBedAndOneChannelPerObject() throws {
        let s = try song()
        let (layout, data) = try export(s, in: try folder())
        XCTAssertEqual(layout.channelCount, 5)
        let file = try XCTUnwrap(RIFFChunks(data))
        XCTAssertEqual(file.form, "RIFF")
        XCTAssertEqual(file.ids, ["JUNK", "fmt ", "chna", "axml", "data"])
        let format = try XCTUnwrap(file.chunk("fmt "))
        XCTAssertEqual(format.le16(0), 1, "integer PCM")
        XCTAssertEqual(format.le16(2), 5, "channels")
        XCTAssertEqual(format.le32(4), 48_000, "the song's rate")
        XCTAssertEqual(format.le16(14), 24, "bits")
        let chna = try XCTUnwrap(file.chunk("chna"))
        XCTAssertEqual(chna.le16(0), 5)
        XCTAssertEqual(chna.le16(2), 5)
        XCTAssertEqual(chna, ADMBWF.chna(layout))
        XCTAssertEqual(try XCTUnwrap(file.chunk("axml")), ADMBWF.axml(layout))
        let samples = try XCTUnwrap(file.chunk("data"))
        XCTAssertEqual(samples.count % (5 * 3), 0)
        XCTAssertEqual(samples.count / 15, Int(Double(layout.duration) / 100_000 * 48_000 + 0.5))
    }

    func testTheObjectPositionIsThePan() throws {
        let s = try song()
        let (layout, _) = try export(s, in: try folder())
        XCTAssertEqual(layout.objects.map(\.name), ["Keys", "Lead", "Loop"])
        XCTAssertEqual(layout.objects[0].blocks.count, 1)
        XCTAssertEqual(layout.objects[0].blocks[0].azimuth, ADMObject.track(index: 1, pan: -0.5, level: 1).azimuth)
        XCTAssertEqual(layout.objects[0].blocks[0].azimuth, 45)
        XCTAssertEqual(layout.objects[2].blocks.map(\.azimuth), [-22.5])
    }

    func testAutomatedPanWritesBlocks() throws {
        let s = try song()
        let (layout, _) = try export(s, in: try folder())
        let blocks = layout.objects[1].blocks
        XCTAssertGreaterThan(blocks.count, 2)
        XCTAssertEqual(blocks.first?.azimuth, -90, "pan +1 is hard right")
        XCTAssertEqual(blocks.last?.azimuth, 90)
        XCTAssertEqual(blocks.reduce(0) { $0 + $1.duration }, layout.duration)
        XCTAssertTrue(ADMBWF.xml(layout).contains("AB_00031002_00000003"), "the moving object's third block")
    }

    func testTheObjectChannelIsTheTrackAtItsOwnLevel() throws {
        // A mono audio track: its object carries the file's samples at full level, whatever the pan.
        let s = try song()
        let (layout, data) = try export(s, in: try folder())
        let samples = try XCTUnwrap(try XCTUnwrap(RIFFChunks(data)).chunk("data"))
        let channel = layout.channel(ofObject: 2) - 1
        let frame = 10_000
        let value = samples.le24((frame * 5 + channel) * 3)
        XCTAssertEqual(Double(value) / 8_388_607, 0.25, accuracy: 0.002)
    }

    /// The song clock moves an export (`lfo.1`), but an object's place is metadata only: a route on
    /// its pan does not reach the object's samples, which stay at the track's own level.
    func testARouteOnAnObjectsPanLeavesItsSamplesAlone() throws {
        var s = try song()
        try Command.setModRoute(ModulationRoute(source: .lfo1, target: .pan(s.loop), depth: 1, polarity: .bipolar))
            .apply(to: &s.project)
        let plan = try XCTUnwrap(ADMExport.plan(for: s.project, samples: s.samples))
        XCTAssertFalse(plan.objectSong.modRoutes.contains { $0.target == .pan(s.loop) })
        let (layout, data) = try export(s, in: try folder())
        let samples = try XCTUnwrap(try XCTUnwrap(RIFFChunks(data)).chunk("data"))
        let channel = layout.channel(ofObject: 2) - 1
        let value = samples.le24((10_000 * 5 + channel) * 3)
        XCTAssertEqual(Double(value) / 8_388_607, 0.25, accuracy: 0.002, "a fifth of a bar in, the LFO would pan it right")
    }

    func testTheSameSongGivesTheSameBytes() throws {
        let s = try song()
        let place = try folder()
        let (_, first) = try export(s, in: place, named: "a.wav")
        let (_, second) = try export(s, in: place, named: "b.wav")
        XCTAssertEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: place.appendingPathComponent("scratch/part-0.f32").path),
                       "the scratch files are gone")
    }

    func testAFilePastTheRIFFLimitIsRF64() throws {
        let url = try folder().appendingPathComponent("big.wav")
        let writer = try BW64Writer(url: url, sampleRate: 48_000, channels: 3, chna: Data([1, 2, 3]), axml: Data("<a/>".utf8),
                                    riffLimit: 100)
        let block = [Float](repeating: 0.5, count: 3 * 64)
        try block.withUnsafeBufferPointer { try writer.append(interleaved: $0, frames: 64) }
        try writer.finish()
        let data = try Data(contentsOf: url)
        let file = try XCTUnwrap(RIFFChunks(data))
        XCTAssertEqual(file.form, "RF64")
        XCTAssertEqual(file.ids.first, "ds64")
        let ds64 = try XCTUnwrap(file.chunk("ds64"))
        XCTAssertEqual(ds64.le64(0), UInt64(data.count - 8), "RIFF size")
        XCTAssertEqual(ds64.le64(8), 64 * 3 * 3, "data size")
        XCTAssertEqual(ds64.le64(16), 64, "frames")
        XCTAssertEqual(file.chunk("chna"), Data([1, 2, 3]))
        XCTAssertEqual(file.chunk("data")?.count, 64 * 3 * 3)
    }

    func testAnEmptySongExportsNothing() throws {
        let place = try folder()
        XCTAssertNil(try ADMExport.export(Project(tempo: 120), title: "Empty", scratch: place, to: place.appendingPathComponent("x.wav")))
    }
}

/// The chunks of a RIFF, RF64 or BW64 file; a `data` chunk sized 0xFFFFFFFF takes its size from `ds64`.
struct RIFFChunks {
    let form: String
    private(set) var ids: [String] = []
    private var bodies: [String: Data] = [:]

    init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { return nil }
        form = String(decoding: bytes[0..<4], as: UTF8.self)
        var offset = 12
        var dataSize64: UInt64?
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<(offset + 4)], as: UTF8.self)
            var size = Int(Data(bytes[(offset + 4)..<(offset + 8)]).le32(0))
            if id == "data", size == Int(UInt32.max), let big = dataSize64 { size = Int(big) }
            let start = offset + 8
            guard start + size <= bytes.count else { return nil }
            let body = Data(bytes[start..<(start + size)])
            if id == "ds64" { dataSize64 = body.le64(8) }
            ids.append(id)
            bodies[id] = body
            offset = start + size + size % 2
        }
    }

    func chunk(_ id: String) -> Data? { bodies[id] }
}

extension Data {
    fileprivate func le16(_ at: Int) -> UInt16 {
        let b = [UInt8](self)
        return UInt16(b[at]) | UInt16(b[at + 1]) << 8
    }

    fileprivate func le32(_ at: Int) -> UInt32 {
        let b = [UInt8](self)
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(b[at + $1]) << UInt32(8 * $1) }
    }

    fileprivate func le64(_ at: Int) -> UInt64 {
        let b = [UInt8](self)
        return (0..<8).reduce(UInt64(0)) { $0 | UInt64(b[at + $1]) << UInt64(8 * $1) }
    }

    fileprivate func le24(_ at: Int) -> Int32 {
        let b = [UInt8](self)
        let raw = Int32(b[at]) | Int32(b[at + 1]) << 8 | Int32(b[at + 2]) << 16
        return raw & 0x80_0000 != 0 ? raw - 0x100_0000 : raw
    }
}
