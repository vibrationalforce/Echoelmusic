@testable import EchoelKernels
import XCTest

/// The soft clip at the end of an Echoel unit in another host (audit 2026-11-04).
final class OutputSafetyTests: XCTestCase {
    func testBelowMinusThreeDecibelsNothingChanges() {
        for x: Float in [0, 0.1, -0.5, 0.7, -0.707] { XCTAssertEqual(OutputSafety.shape(x), x) }
    }

    func testAboveTheKneeTheOutputBendsUnderFullScaleWithoutACorner() {
        var previous: Float = 0
        for step in 0...4_000 {
            let x = Float(step) / 1_000   // 0 … 4
            let y = OutputSafety.shape(x)
            XCTAssertLessThanOrEqual(y, 1, "never above full scale, at \(x)")
            XCTAssertGreaterThanOrEqual(y, previous, "monotonic, at \(x)")
            XCTAssertEqual(OutputSafety.shape(-x), -y, "symmetric")
            previous = y
        }
        // The slope just above the knee is the line's: no corner.
        let k = OutputSafety.knee
        XCTAssertEqual((OutputSafety.shape(k + 1e-3) - OutputSafety.shape(k)) / 1e-3, 1, accuracy: 0.01)
    }

    func testABadSampleIsSilence() {
        XCTAssertEqual(OutputSafety.shape(.nan), 0)
        XCTAssertEqual(OutputSafety.shape(-.infinity), 0)
    }

    /// The flanger that peaked at 4.0 from a 0.5 sine leaves the unit under full scale.
    func testTheLoudestFlangerLeavesTheUnitUnderFullScale() {
        let kernel = EffectKernel(effect: .flanger, sampleRate: 48_000)
        for parameter in EffectKernel.parameters(for: .flanger) where parameter.identifier == "feedback" {
            kernel.setParameter(parameter.address, -0.95)
        }
        var left = [Float](repeating: 0, count: 512), right = left
        var peak: Float = 0
        for block in 0..<375 {
            for i in 0..<512 {
                let phase: Double = 2 * Double.pi * 220 * Double(block * 512 + i) / 48_000
                left[i] = Float(sin(phase)) * 0.5
                right[i] = left[i] * 0.7
            }
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let a = l.baseAddress, let b = r.baseAddress else { return }
                    kernel.process(left: a, right: b, frames: 512)
                    OutputSafety.apply(left: a, right: b, frames: 512)
                }
            }
            peak = Swift.max(peak, left.map(abs).max() ?? 0, right.map(abs).max() ?? 0)
        }
        XCTAssertLessThan(peak, 1)
    }
}
