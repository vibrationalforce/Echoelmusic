import AVFoundation
import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

final class SamplerKernelTests: XCTestCase {
    private func render(_ kernel: SamplerKernel, frames: Int, gain: Float = 1) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: gain)
            }
        }
        return left
    }

    private func peak(_ samples: [Float]) -> Float { samples.map { abs($0) }.max() ?? 0 }

    /// One second of a constant level, so what a voice plays is easy to read.
    private func constant(_ value: Float, seconds: Double = 1) -> SampleBuffer? {
        SampleBuffer(samples: [Float](repeating: value, count: Int(48_000 * seconds)), sampleRate: 48_000)
    }

    func testWithoutASampleANoteIsSilentAndALoadedSamplePlays() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 60, 127)
        XCTAssertEqual(peak(render(kernel, frames: 960)), 0)
        XCTAssertTrue(kernel.load(try XCTUnwrap(constant(0.5))))
        kernel.receive(status: 0x90, 60, 127)
        XCTAssertGreaterThan(peak(render(kernel, frames: 960)), 0.3)
        kernel.load(nil)
        XCTAssertEqual(peak(render(kernel, frames: 960)), 0, "taking the sample away stops every voice")
    }

    func testTheRootKeyDecidesWhichNotePlaysTheSampleAtItsOwnSpeed() throws {
        // A sample one second long: at its own speed it lasts a second, an octave up half that.
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5)))
        kernel.setParameter(4, 1) // one-shot: plays to the end
        kernel.setParameter(0, 48)
        _ = render(kernel, frames: 16) // parameters apply at the top of a render, as in a host
        kernel.receive(status: 0x90, 60, 127) // an octave above the root
        _ = render(kernel, frames: 26_400)
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0, "an octave up the second lasts half")
        kernel.setParameter(0, 60)
        _ = render(kernel, frames: 16)
        kernel.receive(status: 0x90, 60, 127)
        _ = render(kernel, frames: 26_400)
        XCTAssertGreaterThan(peak(render(kernel, frames: 480)), 0.3, "at the root it plays on")
    }

    func testANoteOffFindsItsNoteAfterTheRootKeyMoved() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5, seconds: 4)))
        kernel.setParameter(2, 0.01) // short release
        _ = render(kernel, frames: 16)
        kernel.receive(status: 0x90, 64, 127)
        _ = render(kernel, frames: 480)
        kernel.setParameter(0, 55)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x80, 64, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0, "released, not stuck")
    }

    func testParametersAreClampedAndLoadsPastAStalledRenderAreRefused() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.setParameter(3, 7)
        XCTAssertEqual(kernel.parameter(3), 1)
        kernel.setParameter(3, .infinity)
        XCTAssertEqual(kernel.parameter(3), 1)
        let buffer = try XCTUnwrap(constant(0.1, seconds: 0.01))
        for _ in 0..<63 { XCTAssertTrue(kernel.load(buffer)) }
        XCTAssertFalse(kernel.load(buffer), "the render thread has not taken one of them")
        _ = render(kernel, frames: 16)
        XCTAssertTrue(kernel.load(buffer), "once it has, the ring is free again")
    }

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
