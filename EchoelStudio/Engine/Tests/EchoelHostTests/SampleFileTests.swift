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
    }
}
