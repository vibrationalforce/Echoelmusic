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
