import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

final class EffectKernelTests: XCTestCase {
    private let rate = 48_000.0

    private func process(_ kernel: EffectKernel, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                kernel.process(left: x, right: y, frames: a.count)
            }
        }
        return l
    }

    func testEveryEffectStartsAtItsDefaultsAndHoldsValuesInRange() {
        for effect in StandardEffect.allCases {
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            XCTAssertFalse(kernel.parameters.isEmpty)
            XCTAssertEqual(kernel.parameters.map(\.address), Array(kernel.parameters.indices))
            XCTAssertEqual(Set(kernel.parameters.map(\.identifier)).count, kernel.parameters.count)
            for p in kernel.parameters {
                XCTAssertTrue(p.range.contains(p.defaultValue), "\(effect) \(p.title)")
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
                kernel.setParameter(p.address, p.range.upperBound + 1_000)
                XCTAssertEqual(kernel.parameter(p.address), p.range.upperBound)
                kernel.setParameter(p.address, .nan)
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
            }
            let noise = (0..<4_096).map { Float(sin(Double($0) * 0.21)) * 0.8 }
            XCTAssertTrue(process(kernel, noise).allSatisfy(\.isFinite), "\(effect)")
        }
    }

    func testAParameterReachesTheSoundAtTheNextBlockAndCarriesToANewRate() {
        let eq = EffectKernel(effect: .equalizer, sampleRate: rate)
        let tone = (0..<4_800).map { Float(sin(2 * Double.pi * 3_000 * Double($0) / 48_000)) }
        XCTAssertEqual(process(eq, tone), tone, "a flat EQ passes the signal")
        eq.setParameter(7, 12) // High Mid Gain at 3 kHz
        let boosted = process(eq, tone)
        XCTAssertGreaterThan(boosted.suffix(1_000).map { abs($0) }.max() ?? 0, 3)

        let moved = EffectKernel(effect: .equalizer, sampleRate: 44_100, values: eq.allValues)
        XCTAssertEqual(moved.parameter(7), 12)

        let compressor = EffectKernel(effect: .compressor, sampleRate: rate)
        compressor.setParameter(0, -30)
        _ = process(compressor, tone)
        XCTAssertLessThan(compressor.gainReduction, -10, "the meter reads the reduction")
    }
}
