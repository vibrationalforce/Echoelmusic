import EchoelDSP
import XCTest
@testable import EchoelKernels

/// A host runs an instrument plugin at the rate of its own session: 44.1, 48 or 96 kHz. Each
/// built-in kernel sounds the same at all three — the same pitch, the same length in seconds,
/// and nothing that is not a number.
final class InstrumentKernelRateTests: XCTestCase {
    private let rates: [Double] = [44_100, 48_000, 96_000]

    /// Renders `seconds` of `kernel` in host-sized blocks after one note-on; returns the left channel.
    private func play(_ kernel: any InstrumentKernel, note: UInt8, seconds: Double, rate: Double) -> [Float] {
        kernel.receive(status: 0x90, note, 100)
        let frames = Int(seconds * rate)
        let block = 512
        var out: [Float] = []
        out.reserveCapacity(frames)
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var done = 0
        while done < frames {
            let count = Swift.min(block, frames - done)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    kernel.render(frames: count, left: lp, right: rp, gain: 1)
                }
            }
            out.append(contentsOf: left[0..<count])
            done += count
        }
        return out
    }

    /// Upward zero crossings per second between `from` and `to` seconds: the pitch of a steady tone.
    private func crossingsPerSecond(_ samples: [Float], rate: Double, from: Double, to: Double) -> Double {
        let start = Int(from * rate), stop = Swift.min(samples.count, Int(to * rate))
        guard stop > start + 1 else { return 0 }
        var count = 0
        for index in (start + 1)..<stop where samples[index - 1] < 0 && samples[index] >= 0 {
            count += 1
        }
        return Double(count) / (Double(stop - start) / rate)
    }

    /// Seconds until the last sample above a hundredth of the peak: how long a hit rings.
    private func ringSeconds(_ samples: [Float], rate: Double) -> Double {
        var peak: Float = 0
        for value in samples { peak = Swift.max(peak, Swift.abs(value)) }
        guard peak > 0 else { return 0 }
        let floor = peak / 100
        let last = samples.lastIndex { Swift.abs($0) > floor } ?? 0
        return Double(last) / rate
    }

    private func assertFinite(_ samples: [Float], _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(samples.firstIndex { !$0.isFinite }, message, file: file, line: line)
        XCTAssertGreaterThan(samples.map { Swift.abs($0) }.max() ?? 0, 0.001, "\(message) is not silent", file: file, line: line)
    }

    func testTheSynthPlaysOnePitchAtEveryRate() {
        var pitches: [Double] = []
        for rate in rates {
            let kernel = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
            let out = play(kernel, note: 69, seconds: 0.5, rate: rate)
            assertFinite(out, "synth at \(rate)")
            pitches.append(crossingsPerSecond(out, rate: rate, from: 0.1, to: 0.45))
        }
        let reference = pitches[1]
        XCTAssertGreaterThan(reference, 0)
        for (rate, pitch) in zip(rates, pitches) {
            XCTAssertEqual(pitch, reference, accuracy: reference * 0.02, "synth A4 at \(rate) Hz")
        }
    }

    func testADrumHitRingsForTheSameTimeAtEveryRate() {
        var rings: [Double] = []
        for rate in rates {
            let kernel = DrumKernel(sampleRate: rate, maximumFrames: 4_096)
            let out = play(kernel, note: 36, seconds: 1.5, rate: rate)
            assertFinite(out, "kick at \(rate)")
            rings.append(ringSeconds(out, rate: rate))
        }
        let reference = rings[1]
        XCTAssertGreaterThan(reference, 0.01)
        for (rate, ring) in zip(rates, rings) {
            XCTAssertEqual(ring, reference, accuracy: reference * 0.1, "kick ring at \(rate) Hz")
        }
    }

    func testTheSamplerPlaysItsSampleAtItsPitchAtEveryRate() throws {
        let fileRate = 48_000.0
        let tone: [Float] = (0..<Int(fileRate / 2)).map { (index: Int) -> Float in
            Float(0.5 * sin(2 * Double.pi * 440 * Double(index) / fileRate))
        }
        let buffer = try XCTUnwrap(SampleBuffer(samples: tone, sampleRate: fileRate))
        for rate in rates {
            let kernel = SamplerKernel(sampleRate: rate, maximumFrames: 4_096)
            kernel.assign(buffer)
            let out = play(kernel, note: 60, seconds: 0.4, rate: rate)
            assertFinite(out, "sampler at \(rate)")
            let pitch = crossingsPerSecond(out, rate: rate, from: 0.05, to: 0.35)
            XCTAssertEqual(pitch, 440, accuracy: 440 * 0.02, "the root key plays the file's 440 Hz at \(rate) Hz")
        }
    }
}
