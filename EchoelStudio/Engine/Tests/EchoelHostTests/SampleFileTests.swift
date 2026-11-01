import AVFoundation
import XCTest
@testable import EchoelHost

/// Reading a sample file for the sampler (moved out of the kernel tests: the kernels need no AVFoundation).
final class SampleFileTests: XCTestCase {
    func testAFileIsReadAsMonoAtItsOwnRate() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 441))
        buffer.frameLength = 441
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for i in 0..<441 { channels[0][i] = 0.5; channels[1][i] = -0.1 }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let mono = try SampleFile.readMono(url, maximumSeconds: 1)
        XCTAssertEqual(mono.sampleRate, 44_100)
        XCTAssertEqual(mono.samples.count, 441)
        XCTAssertEqual(mono.samples[100], 0.2, accuracy: 1e-5)
        XCTAssertThrowsError(try SampleFile.readMono(url, maximumSeconds: 0.001)) {
            XCTAssertEqual($0 as? SampleFile.ReadError, .tooLong(maximumSeconds: 0.001))
        }
        // A limit in frames: 441 frames do not fit in 220, and the error names the seconds 220
        // frames last at this file's rate.
        XCTAssertThrowsError(try SampleFile.readMono(url, maximumSeconds: 1, maximumFrames: 220)) {
            XCTAssertEqual($0 as? SampleFile.ReadError, .tooLong(maximumSeconds: 220.0 / 44_100))
        }
        XCTAssertEqual(try SampleFile.readMono(url, maximumSeconds: 1, maximumFrames: 441).samples.count, 441)

        // The reader writes into memory the caller owns: the same frames, and never past it.
        let reader = try SampleFile.Reader(url, maximumSeconds: 1)
        XCTAssertEqual(reader.frameCount, 441)
        XCTAssertEqual(reader.sampleRate, 44_100)
        var frames = [Float](repeating: 9, count: 300)
        let read = try frames.withUnsafeMutableBufferPointer { try reader.read(into: $0) }
        XCTAssertEqual(read, 300, "it stops at the room it was given")
        XCTAssertEqual(frames[299], 0.2, accuracy: 1e-5)
        XCTAssertThrowsError(try SampleFile.Reader(url, maximumSeconds: 1, maximumFrames: 220)) {
            XCTAssertEqual($0 as? SampleFile.ReadError, .tooLong(maximumSeconds: 220.0 / 44_100))
        }
    }

    /// Writes `frames` frames of `format` to a new CAF file, channel `c` of frame `i` from `value`.
    private func file(_ format: AVAudioFormat, frames: Int, _ value: (Int, Int) -> Float) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).caf")
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for c in 0..<Int(format.channelCount) {
            for i in 0..<frames { channels[c][i] = value(c, i) }
        }
        let written = try AVAudioFile(forWriting: url, settings: format.settings)
        try written.write(from: buffer)
        return url
    }

    /// The app's import keeps a file's two sides (W17): a stereo file reads left and right, a mono
    /// one as it is, and the limit in values counts both sides.
    func testAStereoFileKeepsItsSidesAndAMonoOneStaysMono() throws {
        let stereoFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let stereo = try file(stereoFormat, frames: 480) { (channel: Int, index: Int) -> Float in
            channel == 0 ? Float(index) / 480 : -0.25
        }
        defer { try? FileManager.default.removeItem(at: stereo) }
        let reader = try SampleFile.Reader(stereo, maximumSeconds: 1)
        XCTAssertEqual(reader.channelCount, 2)
        XCTAssertEqual(reader.keptChannels, 2)
        var values = [Float](repeating: 9, count: 960)
        XCTAssertEqual(try values.withUnsafeMutableBufferPointer { try reader.read(sidesInto: $0) }, 480)
        XCTAssertEqual(values[200], 100.0 / 480, accuracy: 1e-6, "left")
        XCTAssertEqual(values[201], -0.25, accuracy: 1e-6, "right")
        XCTAssertEqual(values[959], -0.25, accuracy: 1e-6)
        let short = try SampleFile.Reader(stereo, maximumSeconds: 1)
        var room = [Float](repeating: 9, count: 301)
        XCTAssertEqual(try room.withUnsafeMutableBufferPointer { try short.read(sidesInto: $0) }, 150,
                       "only whole frames fit")
        XCTAssertEqual(room[300], 9, "the half frame is not written")
        XCTAssertThrowsError(try SampleFile.Reader(stereo, maximumSeconds: 1, maximumValues: 959)) {
            XCTAssertEqual($0 as? SampleFile.ReadError, .tooLong(maximumSeconds: 479.0 / 48_000), "two values a frame")
        }
        XCTAssertNoThrow(try SampleFile.Reader(stereo, maximumSeconds: 1, maximumValues: 960))

        let monoFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let mono = try file(monoFormat, frames: 480) { (_: Int, index: Int) -> Float in Float(index) / 480 }
        defer { try? FileManager.default.removeItem(at: mono) }
        let monoReader = try SampleFile.Reader(mono, maximumSeconds: 1)
        XCTAssertEqual(monoReader.keptChannels, 1)
        var monoValues = [Float](repeating: 9, count: 480)
        XCTAssertEqual(try monoValues.withUnsafeMutableBufferPointer { try monoReader.read(sidesInto: $0) }, 480)
        XCTAssertEqual(monoValues[100], 100.0 / 480, accuracy: 1e-6, "a mono file reads as it is")
        XCTAssertNoThrow(try SampleFile.Reader(mono, maximumSeconds: 1, maximumValues: 480), "one value a frame")
    }

    /// A file of more than two channels keeps its first pair as left and right and shares the rest
    /// equally between them: the two sides averaged are the mono mix the sampler reads.
    func testAFileOfFourChannelsFoldsToTwoSidesWhoseAverageIsTheMonoMix() throws {
        let layout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 4))
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channelLayout: layout)
        XCTAssertEqual(format.channelCount, 4)
        let levels: [Float] = [0.4, -0.2, 0.1, 0.3]
        let url = try file(format, frames: 441) { (channel: Int, _: Int) -> Float in levels[channel] }
        defer { try? FileManager.default.removeItem(at: url) }
        let reader = try SampleFile.Reader(url, maximumSeconds: 1)
        XCTAssertEqual(reader.channelCount, 4)
        XCTAssertEqual(reader.keptChannels, 2)
        var values = [Float](repeating: 0, count: 882)
        XCTAssertEqual(try values.withUnsafeMutableBufferPointer { try reader.read(sidesInto: $0) }, 441)
        // Left: (0.4 + (0.1 + 0.3) / 2) × 2/4 = 0.3; right: (−0.2 + 0.2) × 2/4 = 0.
        XCTAssertEqual(values[100], 0.3, accuracy: 1e-6)
        XCTAssertEqual(values[101], 0, accuracy: 1e-6)
        let mono = try SampleFile.readMono(url, maximumSeconds: 1)
        XCTAssertEqual((values[100] + values[101]) / 2, mono.samples[50], accuracy: 1e-6, "the average is the mono mix")
    }
}
