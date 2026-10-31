import EchoelCore
import EchoelKernels
import XCTest
@testable import EchoelEngine

/// A built-in effect kernel on an insert chain, the way its Audio Unit plays it.
private final class KernelInsert: HostedProcessor, @unchecked Sendable {
    let kernel: EffectKernel
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    var sampleRate: Double { kernel.sampleRate }

    init(_ kernel: EffectKernel) { self.kernel = kernel }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        kernel.process(left: left, right: right, frames: frames)
    }
}

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

    func testALongReleaseRingsOutPastTheFixedTailAndThenStops() throws {
        var song = try oneNoteSong(start: 0, length: 960)
        let track = try XCTUnwrap(song.tracks.first?.id)
        try Command.setInstrumentParameter(track, key: SynthParameter.release.key.rawValue, value: 5).apply(to: &song)
        let rate = 48_000.0
        let result = OfflineRender.render(song, sampleRate: rate, tailSeconds: 2)
        // The note ends at 0.5 s; a 2 s fixed tail would stop at 2.5 s, mid-release.
        XCTAssertGreaterThan(result.frameCount, Int(3.5 * rate), "the release is not cut at the fixed tail")
        XCTAssertLessThan(result.frameCount, Int((2.5 + OfflineRender.maximumRingOutSeconds) * rate),
                          "and the render ends once it has died away, before the limit")
        let end = result.left[(result.frameCount - 1_000)...]
        XCTAssertTrue(end.allSatisfy { Swift.abs($0) < 1e-4 }, "the last samples are silence")

        let cut = OfflineRender.render(song, sampleRate: rate, tailSeconds: 2, ringOutSeconds: 0)
        XCTAssertEqual(cut.frameCount, Int(2.5 * rate), "no ring-out keeps the fixed length")
    }

    /// A delay whose repeats lie further apart than a short silence: the export waits through
    /// each gap for the next repeat instead of stopping in it, and the file still ends where the
    /// last repeat dies away, not on the quiet window after it (audit 2026-10-23).
    func testASlowDelaysRepeatsAreAllInTheExportAndItEndsWithThem() throws {
        var song = try oneNoteSong(start: 0, length: 120)
        let track = try XCTUnwrap(song.tracks.first?.id)
        try Command.setInstrumentParameter(track, key: SynthParameter.release.key.rawValue, value: 0.01).apply(to: &song)
        let rate = 48_000.0
        let delay = KernelInsert(EffectKernel(effect: .delay, sampleRate: rate))
        delay.kernel.setParameter(0, 1)     // time, seconds
        delay.kernel.setParameter(1, 0.6)   // feedback
        delay.kernel.setParameter(2, 0.5)   // mix
        let result = OfflineRender.render(song, sampleRate: rate, tailSeconds: 2, effects: [track: [delay]])
        func peak(_ seconds: ClosedRange<Double>) -> Float {
            let from = Int(seconds.lowerBound * rate)
            let to = Swift.min(Int(seconds.upperBound * rate), result.frameCount)
            guard from < to else { return 0 }
            return result.left[from..<to].reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        }
        XCTAssertGreaterThan(peak(3.0...3.1), 1e-3, "the third repeat, after a silent gap past the fixed tail")
        XCTAssertGreaterThan(peak(5.0...5.1), 1e-4, "and the fifth")
        let last = try XCTUnwrap(result.left.indices.last)
        let ending: Float = Swift.max(Swift.abs(result.left[last]), Swift.abs(result.right[last]))
        XCTAssertGreaterThanOrEqual(ending, OfflineRender.quietLevel, "the file ends with the sound, not seconds after it")
    }

    func testAnEmptySongRendersNothing() {
        let result = OfflineRender.render(Project())
        XCTAssertEqual(result.frameCount, 0)
        XCTAssertEqual(result.peak, 0)
    }

    /// The fixed length — the song and its tail, before any ring-out — is known without rendering,
    /// so an export can refuse a song no WAV file holds before the first block (review 2026-10-28,
    /// 2.3) instead of after hours of rendering.
    func testTheFixedLengthIsKnownBeforeTheFirstBlock() throws {
        let song = try oneNoteSong(start: 960, length: 960)
        XCTAssertEqual(OfflineRender.fixedFrameCount(song, sampleRate: 48_000, tailSeconds: 1), 96_000)
        XCTAssertEqual(Int(OfflineRender.fixedFrameCount(song, tailSeconds: 1)),
                       OfflineRender.render(song, tailSeconds: 1, ringOutSeconds: 0).frameCount)
        XCTAssertEqual(OfflineRender.fixedFrameCount(Project()), 0)
        XCTAssertEqual(OfflineRender.fixedFrameCount(song, sampleRate: .nan, tailSeconds: .infinity),
                       OfflineRender.fixedFrameCount(song, sampleRate: 48_000, tailSeconds: 0),
                       "a rate that is no number reads as 48 kHz, a tail that is none as no tail")
        XCTAssertEqual(OfflineRender.fixedFrameCount(song, tailSeconds: 1e9),
                       OfflineRender.fixedFrameCount(song, tailSeconds: OfflineRender.longestTailSeconds),
                       "a tail of a thousand years is the longest tail")

        // The longest song at the slowest tempo lies thirty-three hours in: more than one WAV file
        // can hold, and more than 2³² samples — a number, not an overflow.
        var long = Project(tempo: 20)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &long)
        try Command.createClip(track: track, id: clip, name: "C", length: bar).apply(to: &long)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: bar)]).apply(to: &long)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: MusicalTime.maximumTick - bar).apply(to: &long)
        let frames = OfflineRender.fixedFrameCount(long)
        XCTAssertGreaterThan(frames, Int64(WAVFile.maximumFrames(.twentyFour)))
        XCTAssertGreaterThan(frames, Int64(UInt32.max))
        XCTAssertLessThan(frames, Int64(40 * 3_600 * 48_000))
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
