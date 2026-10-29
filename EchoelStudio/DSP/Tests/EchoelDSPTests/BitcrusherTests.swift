import XCTest
@testable import EchoelDSP

final class BitcrusherTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ effect: x, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                effect.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    private func sine(_ hertz: Double, amplitude: Double, count: Int) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(Foundation.sin(phase) * amplitude)
        }
    }

    func testFullyDryPassesTheSoundThrough() {
        let crusher = Bitcrusher(sampleRate: rate, settings: .init(bits: 1, downsample: 64, mix: 0))
        let input = sine(220, amplitude: 0.8, count: 4_800)
        let (l, r) = run(crusher, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// Three bits: every output sample is one of 2 × 7 + 1 steps, held for four samples.
    func testItRoundsToTheBitDepthAndHoldsForTheDownsample() {
        let crusher = Bitcrusher(sampleRate: rate, settings: .init(bits: 3, downsample: 4, mix: 1))
        let input = sine(440, amplitude: 0.9, count: 4_800)
        let (l, _) = run(crusher, left: input, right: input)
        for sample in l {
            let steps = sample * 7
            XCTAssertEqual(steps, steps.rounded(), accuracy: 1e-4)
        }
        for start in Swift.stride(from: 0, to: 4_800, by: 4) {
            XCTAssertEqual(l[start], l[start + 3])
        }
        XCTAssertEqual(l[0], (input[0] * 7).rounded() / 7)
        XCTAssertEqual(l[4], (input[4] * 7).rounded() / 7)
    }

    func testABadSampleIsNeverHeldAndSettingsAreClamped() {
        let crusher = Bitcrusher(sampleRate: rate, settings: .init(bits: 40, downsample: .nan, mix: -1))
        XCTAssertEqual(crusher.settings, .init(bits: 16, downsample: 4, mix: 0))
        crusher.settings = .init(bits: 8, downsample: 8, mix: 1)
        var input = [Float](repeating: 0.5, count: 2_000)
        input[16] = .nan
        let (l, r) = run(crusher, left: input, right: input)
        XCTAssertEqual(l[16], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "the NaN is not held")
    }
}
