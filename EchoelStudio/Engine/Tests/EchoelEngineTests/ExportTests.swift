import EchoelCore
import XCTest
@testable import EchoelEngine

final class ExportTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func oneNoteSong(start: Tick = 0, length: Tick = 960) throws -> Project {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: start, length: length)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return project
    }

    func testTheRenderCoversTheSongPlusTheTail() throws {
        let result = OfflineRender.render(try oneNoteSong(start: 960, length: 960), sampleRate: 48_000, tailSeconds: 1)
        // The note ends at tick 1 920 = 1 s; plus a 1 s tail.
        XCTAssertEqual(result.frameCount, 96_000)
        let first = try XCTUnwrap(result.left.firstIndex { Swift.abs($0) > 1e-6 })
        XCTAssertTrue((24_000...24_002).contains(first), "\(first)")
        XCTAssertGreaterThan(result.peak, 0.01)
        XCTAssertLessThan(result.peak, 1)
        XCTAssertTrue(result.left[95_000...].allSatisfy { Swift.abs($0) < 1e-4 }, "the release has rung out")
    }

    func testAnEmptySongRendersNothing() {
        let result = OfflineRender.render(Project())
        XCTAssertEqual(result.frameCount, 0)
        XCTAssertEqual(result.peak, 0)
    }

    func testTheExportIsDeterministic() throws {
        let song = try oneNoteSong()
        XCTAssertEqual(OfflineRender.render(song).left, OfflineRender.render(song).left)
    }

    func testTheStreamedRenderIsTheWholeRender() throws {
        let song = try oneNoteSong(start: 960, length: 960)
        var left: [Float] = [], right: [Float] = [], blocks = 0
        let summary = OfflineRender.render(song, tailSeconds: 1, blockFrames: 1_000) { l, r, count in
            XCTAssertLessThanOrEqual(count, 1_000)
            left.append(contentsOf: UnsafeBufferPointer(start: l, count: count))
            right.append(contentsOf: UnsafeBufferPointer(start: r, count: count))
            blocks += 1
        }
        let whole = OfflineRender.render(song, tailSeconds: 1)
        XCTAssertEqual(blocks, 96)
        XCTAssertEqual(summary.frameCount, whole.frameCount)
        XCTAssertEqual(summary.peak, whole.peak)
        XCTAssertEqual(left, whole.left)
        XCTAssertEqual(right, whole.right)
    }

    func testAThrowingBlockStopsTheRender() throws {
        struct Stop: Error {}
        var blocks = 0
        XCTAssertThrowsError(try OfflineRender.render(try oneNoteSong(), blockFrames: 512) { _, _, _ in
            blocks += 1
            if blocks == 3 { throw Stop() }
        })
        XCTAssertEqual(blocks, 3)
    }

    func testTheWriterWritesWhatDataEncodes() throws {
        let left: [Float] = [0, 0.5, -1, 0.25, 2]
        let right: [Float] = [1, 0, 0, -0.25, .nan]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("writer-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WAVWriter(url: url, sampleRate: 44_100)
        try left.withUnsafeBufferPointer { l in
            try right.withUnsafeBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return XCTFail("no storage") }
                try writer.append(left: lp, right: rp, count: 2)
                try writer.append(left: lp + 2, right: rp + 2, count: 3)
            }
        }
        try writer.finish()
        XCTAssertEqual(writer.frameCount, 5)
        XCTAssertEqual(try Data(contentsOf: url), WAVFile.data(left: left, right: right, sampleRate: 44_100))
    }

    func testTheHeaderNeverCountsPastWhatRIFFCanHold() {
        let header = WAVFile.header(frames: .max, sampleRate: 48_000, bitDepth: .twentyFour)
        func u32(_ at: Int) -> UInt32 { header[at..<at + 4].enumerated().reduce(0) { $0 | UInt32($1.element) << (8 * $1.offset) } }
        XCTAssertEqual(Int(u32(40)), WAVFile.maximumFrames(.twentyFour) * 6)
        XCTAssertLessThanOrEqual(Int(u32(4)), Int(UInt32.max))
    }

    func testTheWAVHeaderDescribesTheData() {
        let data = WAVFile.data(left: [0, 0.5, -1], right: [1, 0, 0], sampleRate: 44_100)
        XCTAssertEqual(data.count, 44 + 3 * 2 * 3)
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data[36..<40], as: UTF8.self), "data")
        func u32(_ at: Int) -> UInt32 { data[at..<at + 4].enumerated().reduce(0) { $0 | UInt32($1.element) << (8 * $1.offset) } }
        func u16(_ at: Int) -> UInt16 { UInt16(data[at]) | UInt16(data[at + 1]) << 8 }
        XCTAssertEqual(u32(4), UInt32(data.count - 8))
        XCTAssertEqual(u16(20), 1)            // PCM
        XCTAssertEqual(u16(22), 2)            // stereo
        XCTAssertEqual(u32(24), 44_100)
        XCTAssertEqual(u32(28), 44_100 * 6)
        XCTAssertEqual(u16(32), 6)
        XCTAssertEqual(u16(34), 24)
        XCTAssertEqual(u32(40), 18)
    }

    func testSamplesEncodeAndClipAtFullScale() {
        XCTAssertEqual(WAVFile.integer(1, bits: 24), 8_388_607)
        XCTAssertEqual(WAVFile.integer(-1, bits: 24), -8_388_607)
        XCTAssertEqual(WAVFile.integer(2, bits: 24), 8_388_607)
        XCTAssertEqual(WAVFile.integer(-7, bits: 16), -32_767)
        XCTAssertEqual(WAVFile.integer(0, bits: 16), 0)
        XCTAssertEqual(WAVFile.integer(.nan, bits: 24), 0)
        // A negative 24-bit sample is written as its two's-complement low three bytes.
        let data = WAVFile.data(left: [-1], right: [0], sampleRate: 48_000)
        XCTAssertEqual(Array(data[44..<47]), [0x01, 0x00, 0x80])
    }
}
