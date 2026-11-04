import XCTest
@testable import EchoelDSP

final class DynamicEQTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, amplitude: Double, count: Int = 24_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000) * amplitude)
        }
    }

    private func run(_ eq: DynamicEQ, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                eq.process(left: a, right: b, frames: lp.count)
            }
        }
        return l
    }

    private func gain(_ eq: DynamicEQ, _ input: [Float]) -> Float {
        let out = run(eq, input)
        func rms(_ x: [Float]) -> Float {
            let tail = Array(x.suffix(x.count / 2))
            return (tail.reduce(0) { $0 + $1 * $1 } / Float(tail.count)).squareRoot()
        }
        return 20 * log10f(rms(out) / rms(input))
    }

    /// A band cuts its frequency when it is loud and leaves it when it is quiet: what makes it
    /// dynamic rather than a fixed bell.
    func testABandCutsItsFrequencyOnlyWhenItIsLoud() {
        let settings = DynamicEQ.Settings(high: .init(frequency: 3_000, threshold: -24, range: -12))
        let loud = gain(DynamicEQ(sampleRate: rate, settings: settings), sine(3_000, amplitude: 0.5))
        let quiet = gain(DynamicEQ(sampleRate: rate, settings: settings), sine(3_000, amplitude: 0.02))
        XCTAssertEqual(loud, -12, accuracy: 0.5, "0.5 is 18 dB over −24: the full range")
        XCTAssertEqual(quiet, 0, accuracy: 0.05, "−34 dBFS is under the threshold: flat")
    }

    func testABandLeavesOtherFrequenciesAndCanLiftToo() {
        let settings = DynamicEQ.Settings(low: .init(frequency: 250, range: 0),
                                          high: .init(frequency: 3_000, q: 4, threshold: -24, range: -12))
        XCTAssertEqual(gain(DynamicEQ(sampleRate: rate, settings: settings), sine(250, amplitude: 0.5)), 0, accuracy: 0.3)
        let lift = DynamicEQ.Settings(low: .init(frequency: 250, threshold: -24, range: 6), high: .init(frequency: 3_000, range: 0))
        XCTAssertEqual(gain(DynamicEQ(sampleRate: rate, settings: lift), sine(250, amplitude: 0.5)), 6, accuracy: 0.5)
    }

    func testTheRangeGrowsWithTheLevelOverTheThreshold() {
        // 6 dB over the threshold: half the range.
        let settings = DynamicEQ.Settings(high: .init(frequency: 3_000, threshold: -12, range: -12))
        let half = gain(DynamicEQ(sampleRate: rate, settings: settings), sine(3_000, amplitude: 0.5))
        // The follower rises at the attack, so it sits a little under a steady peak: about half.
        XCTAssertEqual(half, -6, accuracy: 1)
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let eq = DynamicEQ(sampleRate: rate, settings: .init(low: .init(frequency: 1, q: .nan, threshold: 9, range: -99),
                                                            attack: 0, release: .infinity))
        XCTAssertEqual(eq.settings.low, .init(frequency: 20, q: 1, threshold: 0, range: -18))
        XCTAssertEqual(eq.settings.attack, 0.0001)
        XCTAssertEqual(eq.settings.release, 0.15)
        var input = sine(1_000, amplitude: 0.4, count: 4_800)
        input[500] = .nan
        let out = run(eq, input)
        XCTAssertEqual(out[500], 0)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
    }
}
