import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelHost
import EchoelKernels
import XCTest

/// Gains on the two sides, in pure Swift: an effect that pushes a region past full scale.
private final class Boost: HostedProcessor, @unchecked Sendable {
    let sampleRate: Double
    let isBypassed = false
    let insert: InsertID? = nil
    let parameterRanges: [UInt64: ClosedRange<Float>] = [:]
    private let left: Float
    private let right: Float

    init(left: Float, right: Float, sampleRate: Double) {
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
    }

    func schedule(address: UInt64, value: Float, offset: Int, ramp: Int) {}

    func process(frames: Int, left l: UnsafeMutablePointer<Float>, right r: UnsafeMutablePointer<Float>) {
        for i in 0..<frames {
            l[i] *= left
            r[i] *= right
        }
    }
}

/// A bake's file holds what the bake made (W17b): written in 32-bit float, a peak above full scale
/// opens again as it was instead of clipped at 1.0, and a bake an earlier build wrote in 24-bit
/// still reads as it was. Read the way the app's import reads a file (`AudioFileImport.decode`).
final class BakeFileTests: XCTestCase {
    private let rate = 48_000.0
    private let frames = 24_000

    /// One audio track holding one region of a 0.5 sine a bar in.
    private func song() throws -> (Project, TrackID, RegionID, [MediaID: SampleBuffer]) {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Voice", path: "Media/voice.wav", frameCount: frames, sampleRate: rate)
        try Command.addTrack(id: track, name: "Voice", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id,
                               start: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        let sine = (0..<frames).map { (index: Int) -> Float in Float(0.5 * sin(2 * Double.pi * 220 * Double(index) / 48_000)) }
        let buffer = try XCTUnwrap(SampleBuffer(samples: sine, sampleRate: rate))
        return (project, track, region, [media.id: buffer])
    }

    /// What the app's import does with a file in the song's Media folder.
    private func opened(_ url: URL) throws -> SampleBuffer {
        let reader = try SampleFile.Reader(url, maximumSeconds: 600)
        return try XCTUnwrap(try SampleBuffer(capacity: reader.frameCount, channels: reader.keptChannels,
                                              sampleRate: reader.sampleRate, fill: { try reader.read(sidesInto: $0) }))
    }

    private func peak(_ values: [Float]) -> Float {
        values.map { (value: Float) -> Float in abs(value) }.max() ?? 0
    }

    private func interleaved(_ left: [Float], _ right: [Float]) -> [Float] {
        zip(left, right).flatMap { (pair: (Float, Float)) -> [Float] in [pair.0, pair.1] }
    }

    func testABakePastFullScaleOpensAgainWithTheSamePeaks() throws {
        let (project, track, region, samples) = try song()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bake-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        // ×6 on both sides: peaks of 3.0, +9.5 dBFS, and the bake stays mono.
        let mono = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                   samples: samples, effects: [Boost(left: 6, right: 6, sampleRate: rate)]))
        XCTAssertEqual(mono.channelCount, 1)
        XCTAssertGreaterThan(peak(mono.left), 2, "the bake peaks above +6 dBFS")
        try RegionBake.write(mono, to: url, sampleRate: rate)
        let format = try AVAudioFile(forReading: url).fileFormat
        XCTAssertEqual(format.commonFormat, .pcmFormatFloat32, "written as 32-bit float")
        XCTAssertEqual(format.channelCount, 1)
        let reopened = try opened(url)
        XCTAssertEqual(reopened.channelCount, 1)
        XCTAssertEqual(reopened.copyFrames(), mono.left, "every frame as the bake made it")
        XCTAssertEqual(peak(reopened.copyFrames()), peak(mono.left), "the same peaks, not 1.0")

        // ×6 on the left, ×−5 on the right: a wide bake keeps both sides past full scale.
        let wide = try XCTUnwrap(RegionBake.render(project, track: track, region: region, sampleRate: rate,
                                                   samples: samples, effects: [Boost(left: 6, right: -5, sampleRate: rate)]))
        let right = try XCTUnwrap(wide.right)
        XCTAssertGreaterThan(peak(right), 2)
        try RegionBake.write(wide, to: url, sampleRate: rate)
        let both = try opened(url)
        XCTAssertEqual(both.channelCount, 2)
        XCTAssertEqual(both.copyFrames(), interleaved(wide.left, right), "both sides as the bake made them")
    }

    /// A bake an earlier build wrote — 24-bit, stereo of two equal sides — reads as it was: the
    /// 24-bit values, held as one channel, nothing rescaled.
    func testABakeAnEarlierBuildWroteInTwentyFourBitReadsAsItWas() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("old-bake-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        var sound = (0..<frames).map { (index: Int) -> Float in Float(0.9 * sin(2 * Double.pi * 330 * Double(index) / 48_000)) }
        sound[100] = 1
        sound[200] = -1
        sound[300] = 1.5   // clipped when it was written, as every bake before W17b was
        let writer = try WAVWriter(url: url, sampleRate: rate)
        try sound.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return XCTFail("no storage") }
            try writer.append(left: base, right: base, count: pointer.count)
        }
        try writer.finish()
        let format = try AVAudioFile(forReading: url).fileFormat
        XCTAssertEqual(format.channelCount, 2)
        XCTAssertNotEqual(format.commonFormat, .pcmFormatFloat32, "an integer file")

        let reopened = try opened(url)
        XCTAssertEqual(reopened.channelCount, 1, "two equal sides are held as one")
        XCTAssertEqual(reopened.frameCount, frames)
        let values = reopened.copyFrames()
        for index in [0, 57, 100, 200, 300, 4_321, frames - 1] {
            // The 24-bit code it was written as (full scale 8,388,607), read back over 2²³.
            let code = (Swift.min(Swift.max(sound[index], -1), 1) * 8_388_607).rounded()
            XCTAssertEqual(values[index], code / 8_388_608, accuracy: 2e-7, "frame \(index)")
        }
        XCTAssertLessThanOrEqual(peak(values), 1, "a 24-bit file never held more than full scale")
    }
}
