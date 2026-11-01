import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelHost
import XCTest

/// A file read the way the app's import reads it (`AudioFileImport.decode`: the reader's sides
/// straight into a buffer of the file's own channels), placed as a region and exported offline,
/// comes out as it went in (W17): a stereo file's left stays left and its right stays right, a
/// mono file stays the same in both sides.
final class StereoRoundTripTests: XCTestCase {
    private let rate = 48_000.0
    private let frames = 48_000
    /// The centre pan's gain on each side.
    private let centre = Float(0.5).squareRoot()

    private func tone(_ hertz: Double, _ level: Double) -> [Float] {
        (0..<frames).map { (index: Int) -> Float in Float(level * sin(2 * Double.pi * hertz * Double(index) / 48_000)) }
    }

    /// A CAF file of `sides` (one or two), as a recorder or another app writes it.
    private func file(_ sides: [[Float]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("roundtrip-\(UUID()).caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(sides.count)))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for (c, side) in sides.enumerated() {
            for i in 0..<frames { channels[c][i] = side[i] }
        }
        let written = try AVAudioFile(forWriting: url, settings: format.settings)
        try written.write(from: buffer)
        return url
    }

    /// What the app's import does with the file.
    private func imported(_ url: URL) throws -> SampleBuffer {
        let reader = try SampleFile.Reader(url, maximumSeconds: 600)
        return try XCTUnwrap(try SampleBuffer(capacity: reader.frameCount, channels: reader.keptChannels,
                                              sampleRate: reader.sampleRate, fill: { try reader.read(sidesInto: $0) }))
    }

    /// The file as a region a bar into a song, exported.
    private func exported(_ buffer: SampleBuffer) throws -> (result: OfflineRender.Result, start: Int) {
        var project = Project(tempo: 120)
        let track = TrackID()
        let media = MediaFile(name: "Wide", path: "Media/wide.caf", frameCount: buffer.frameCount, sampleRate: buffer.sampleRate)
        try Command.addTrack(id: track, name: "Wide", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: RegionID(), media: media.id,
                               start: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        let result = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0,
                                          samples: [media.id: buffer])
        return (result, 2 * 48_000)
    }

    /// The largest difference between the export and the original × the centre gain, side by
    /// side, outside the region's edge fades.
    private func apart(_ result: OfflineRender.Result, start: Int, left: [Float], right: [Float]) -> Float {
        var largest: Float = 0
        for i in 64..<(frames - 64) {
            largest = Swift.max(largest, abs(result.left[start + i] - left[i] * centre),
                                abs(result.right[start + i] - right[i] * centre))
        }
        return largest
    }

    func testAStereoFileComesOutOfTheExportWithItsSidesApart() throws {
        let left = tone(440, 0.5), right = tone(660, 0.3)
        let url = try file([left, right])
        defer { try? FileManager.default.removeItem(at: url) }
        let buffer = try imported(url)
        XCTAssertEqual(buffer.channelCount, 2, "the import keeps both sides")
        XCTAssertEqual(buffer.frameCount, frames)
        let (result, start) = try exported(buffer)
        XCTAssertEqual(result.frameCount, start + frames)
        XCTAssertLessThan(apart(result, start: start, left: left, right: right), 1e-5,
                          "the export nulls against the original, side by side")

        // Hard left in the file: nothing of it reaches the right.
        let silent = [Float](repeating: 0, count: frames)
        let hardURL = try file([left, silent])
        defer { try? FileManager.default.removeItem(at: hardURL) }
        let (hard, at) = try exported(try imported(hardURL))
        XCTAssertTrue(hard.right.allSatisfy { $0 == 0 }, "the right stays silent")
        XCTAssertLessThan(apart(hard, start: at, left: left, right: silent), 1e-5)
    }

    func testAMonoFileStaysTheSameInBothSides() throws {
        let sound = tone(440, 0.5)
        let url = try file([sound])
        defer { try? FileManager.default.removeItem(at: url) }
        let buffer = try imported(url)
        XCTAssertEqual(buffer.channelCount, 1, "a mono file stays mono")
        XCTAssertEqual(buffer.heldBytes, frames * MemoryLayout<Float>.stride)
        let (result, start) = try exported(buffer)
        XCTAssertLessThan(apart(result, start: start, left: sound, right: sound), 1e-5)
    }

    /// A stereo file of a mono sound — what every Bake Effects before W17 wrote — is held as one
    /// channel and plays as it did.
    func testAStereoFileOfAMonoSoundIsHeldAsOneChannel() throws {
        let sound = tone(330, 0.4)
        let url = try file([sound, sound])
        defer { try? FileManager.default.removeItem(at: url) }
        let reader = try SampleFile.Reader(url, maximumSeconds: 600)
        XCTAssertEqual(reader.keptChannels, 2, "the header says two")
        let buffer = try imported(url)
        XCTAssertEqual(buffer.channelCount, 1, "the two sides are the same, so it is held as one")
        XCTAssertLessThanOrEqual(buffer.heldBytes, 2 * frames * MemoryLayout<Float>.stride)
        let (result, start) = try exported(buffer)
        XCTAssertLessThan(apart(result, start: start, left: sound, right: sound), 1e-5)
    }
}
