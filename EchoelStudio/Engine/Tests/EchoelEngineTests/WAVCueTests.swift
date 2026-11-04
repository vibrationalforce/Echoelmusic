import EchoelCore
import Foundation
import XCTest
@testable import EchoelEngine

/// The song's markers in a WAV or stem file (PRO-W1): a `cue ` chunk and `LIST`/`adtl` labels
/// after the samples, which Pro Tools, Logic, Reaper and Resolve show as markers.
final class WAVCueTests: XCTestCase {
    private func u32(_ data: Data, _ at: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[data.startIndex + at + $1]) << (8 * UInt32($1)) }
    }

    private func range(of tag: String, in data: Data) -> Int? {
        let needle = Array(tag.utf8)
        let bytes = [UInt8](data)
        guard bytes.count >= needle.count else { return nil }
        return (0...(bytes.count - needle.count)).first { start in
            needle.indices.allSatisfy { bytes[start + $0] == needle[$0] }
        }
    }

    func testTheMarkersBecomeCuePointsAtTheirFrames() throws {
        var project = Project(tempo: 120)
        try Command.addMarker(at: 0, name: "Intro").apply(to: &project)
        try Command.addMarker(at: MusicalTime.ticksPerQuarter, name: "Beat 2").apply(to: &project)
        let cues = WAVFile.cues(for: project, sampleRate: 48_000)
        XCTAssertEqual(cues, [WAVCue(frame: 0, name: "Intro"), WAVCue(frame: 24_000, name: "Beat 2")],
                       "a quarter at 120 BPM is half a second")

        let samples = [Float](repeating: 0, count: 48_000)
        let data = WAVFile.data(left: samples, right: samples, sampleRate: 48_000, cues: cues)
        XCTAssertEqual(Int(u32(data, 4)), data.count - 8, "RIFF counts the trailing chunks")
        let cue = try XCTUnwrap(range(of: "cue ", in: data))
        XCTAssertEqual(cue, 44 + 48_000 * 6, "after the samples")
        XCTAssertEqual(u32(data, cue + 4), 4 + 24 * 2)
        XCTAssertEqual(u32(data, cue + 8), 2)
        XCTAssertEqual(u32(data, cue + 12 + 24 + 20), 24_000, "the second cue's sample offset")
        let list = try XCTUnwrap(range(of: "LIST", in: data))
        XCTAssertEqual(list, cue + 8 + 4 + 24 * 2)
        XCTAssertNotNil(range(of: "Beat 2\u{0}", in: data))
        XCTAssertEqual(data.count, list + 8 + Int(u32(data, list + 4)))
    }

    func testNoMarkersWriteTheFileAsBeforeAndACuePastTheEndIsLeftOut() {
        let plain = WAVFile.data(left: [0, 0.5], right: [0, 0.5], sampleRate: 48_000)
        XCTAssertEqual(WAVFile.data(left: [0, 0.5], right: [0, 0.5], sampleRate: 48_000, cues: []), plain)
        XCTAssertEqual(WAVFile.data(left: [0, 0.5], right: [0, 0.5], sampleRate: 48_000,
                                    cues: [WAVCue(frame: 3, name: "Gone")]), plain)
        XCTAssertTrue(WAVFile.cues(for: Project(), sampleRate: 48_000).isEmpty)
        XCTAssertTrue(WAVFile.cues(for: Project(), sampleRate: .nan).isEmpty)
    }

    func testTheWriterPadsAnOddBlockBeforeTheCues() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cues-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WAVWriter(url: url, sampleRate: 48_000, channels: 1)
        let side: [Float] = [0.1, 0.2, 0.3]
        try side.withUnsafeBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else { return XCTFail("no storage") }
            try writer.append(left: pointer, right: pointer, count: 3)
        }
        try writer.finish(cues: [WAVCue(frame: 1, name: "A")])
        let data = try Data(contentsOf: url)
        XCTAssertEqual(u32(data, 40), 9, "the data chunk keeps its own size")
        XCTAssertEqual(data[44 + 9], 0, "a pad byte after an odd block")
        XCTAssertEqual(range(of: "cue ", in: data), 44 + 10, "the cue chunk starts on an even byte")
        XCTAssertEqual(Int(u32(data, 4)), data.count - 8)
    }
}
