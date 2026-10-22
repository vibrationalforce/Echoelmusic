import XCTest
@testable import EchoelKernels

/// The demo's silence fades instead of switching (ultra-audit A9). The expected values follow
/// from the gate's definition: silent from second 28 to 29.99 of every 30, with 10 ms ramps, so
/// one frame moves the gain by at most 1 / (0.01 × sample rate).
final class DemoGateTests: XCTestCase {
    private func frame(_ seconds: Double, _ rate: Double) -> Int64 { Int64((seconds * rate).rounded()) }

    func testTheGateIsOpenThenSilentThenOpenAgainWithHalfwayPointsOnBothRamps() {
        let rate = 48_000.0
        XCTAssertEqual(DemoGate.gain(atFrame: 0, sampleRate: rate), 1)
        XCTAssertEqual(DemoGate.gain(atFrame: frame(27, rate), sampleRate: rate), 1)
        XCTAssertEqual(DemoGate.gain(atFrame: frame(29, rate), sampleRate: rate), 0)
        XCTAssertEqual(DemoGate.gain(atFrame: frame(31, rate), sampleRate: rate), 1, "and again")
        XCTAssertEqual(DemoGate.gain(atFrame: frame(27.995, rate), sampleRate: rate), 0.5, accuracy: 1e-3)
        XCTAssertEqual(DemoGate.gain(atFrame: frame(29.995, rate), sampleRate: rate), 0.5, accuracy: 1e-3)
        XCTAssertTrue(DemoGate.isSilent(atFrame: frame(28.5, rate), sampleRate: rate))
        XCTAssertFalse(DemoGate.isSilent(atFrame: frame(27.995, rate), sampleRate: rate))
    }

    func testNoFrameMovesTheGainByMoreThanOneRampStep() {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            let limit = Float(1 / (0.01 * rate)) + 1e-5
            var previous = DemoGate.gain(atFrame: frame(27.9, rate), sampleRate: rate)
            var steepest: Float = 0
            for n in (frame(27.9, rate) + 1)...frame(30.1, rate) {
                let g = DemoGate.gain(atFrame: n, sampleRate: rate)
                steepest = Swift.max(steepest, abs(g - previous))
                previous = g
            }
            XCTAssertLessThanOrEqual(steepest, limit, "at \(rate) Hz")
            XCTAssertGreaterThan(steepest, 0, "the gate does close")
        }
    }

    func testApplyScalesEveryFrameByTheGateAndLeavesAnOpenBlockAlone() {
        let rate = 48_000.0
        let start = frame(27.98, rate), count = 2_048
        var left = [Float](repeating: 0.5, count: count), right = [Float](repeating: -0.5, count: count)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                DemoGate.apply(left: a, right: b, frames: count, fromFrame: start, sampleRate: rate)
            }
        }
        for i in 0..<count {
            let g = DemoGate.gain(atFrame: start + Int64(i), sampleRate: rate)
            XCTAssertEqual(left[i], 0.5 * g, accuracy: 1e-6)
            XCTAssertEqual(right[i], -0.5 * g, accuracy: 1e-6)
        }
        XCTAssertEqual(left.last, 0, "the block ends inside the silence")

        var early = [Float](repeating: 0.3, count: 512), earlyRight = early
        early.withUnsafeMutableBufferPointer { l in
            earlyRight.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                DemoGate.apply(left: a, right: b, frames: 512, fromFrame: frame(5, rate), sampleRate: rate)
            }
        }
        XCTAssertEqual(early, [Float](repeating: 0.3, count: 512))
        XCTAssertEqual(earlyRight, [Float](repeating: 0.3, count: 512))
    }
}
