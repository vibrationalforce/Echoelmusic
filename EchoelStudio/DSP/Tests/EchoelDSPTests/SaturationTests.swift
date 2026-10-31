import XCTest
@testable import EchoelDSP

final class SaturationTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ saturation: Saturation, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                saturation.process(left: a, right: b, frames: lp.count)
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

    /// The level of one frequency in `signal`, as the amplitude of a sine at it.
    private func level(of hertz: Double, in signal: [Float]) -> Double {
        var real = 0.0, imaginary = 0.0
        for (index, sample) in signal.enumerated() {
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            real += Double(sample) * Foundation.cos(phase)
            imaginary += Double(sample) * Foundation.sin(phase)
        }
        return 2 * Foundation.sqrt(real * real + imaginary * imaginary) / Double(signal.count)
    }

    func testFullyDryPassesTheSoundThrough() {
        let saturation = Saturation(sampleRate: rate, settings: .init(drive: 1, mix: 0))
        let input = sine(220, amplitude: 0.8, count: 4_800)
        let (l, r) = run(saturation, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// Driven, a pure 200 Hz tone gains odd harmonics from the curve and even ones from its bias,
    /// and more drive means more of them; the offset the bias would leave is blocked.
    func testDriveAddsOddAndEvenHarmonicsAndNoOffset() {
        let input = sine(200, amplitude: 0.7, count: 48_000)
        func harmonics(_ drive: Double) -> (second: Double, third: Double, offset: Double) {
            let saturation = Saturation(sampleRate: rate, settings: .init(drive: drive, tone: 1, mix: 1))
            let (l, _) = run(saturation, left: input, right: input)
            let settled = Array(l.suffix(24_000))
            let mean = settled.reduce(0.0) { $0 + Double($1) } / Double(settled.count)
            return (level(of: 400, in: settled), level(of: 600, in: settled), mean)
        }
        let gentle = harmonics(0.1)
        let hard = harmonics(1)
        XCTAssertGreaterThan(hard.third, 0.05, "odd harmonics")
        XCTAssertGreaterThan(hard.second, 0.005, "even harmonics from the bias")
        XCTAssertGreaterThan(hard.third, gentle.third * 2)
        XCTAssertLessThan(Swift.abs(hard.offset), 0.001, "the DC blocker takes the bias out")
    }

    /// A dark tone keeps the fundamental and takes the top off.
    func testTheToneFilterRoundsOffTheTop() {
        let input = sine(8_000, amplitude: 0.3, count: 9_600)
        let bright = Saturation(sampleRate: rate, settings: .init(drive: 0, tone: 1, mix: 1))
        let dark = Saturation(sampleRate: rate, settings: .init(drive: 0, tone: 0, mix: 1))
        let (b, _) = run(bright, left: input, right: input)
        let (d, _) = run(dark, left: input, right: input)
        XCTAssertGreaterThan(level(of: 8_000, in: Array(b.suffix(4_800))), level(of: 8_000, in: Array(d.suffix(4_800))) * 4)
    }

    func testABadSampleEmptiesTheFiltersAndSettingsAreClamped() {
        let saturation = Saturation(sampleRate: rate, settings: .init(drive: 9, tone: -1, mix: .nan))
        XCTAssertEqual(saturation.settings, .init(drive: 1, tone: 0, mix: 0.6))
        var input = [Float](repeating: 0.5, count: 2_000)
        input[10] = .nan
        input[20] = -.infinity
        let (l, r) = run(saturation, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "no NaN rings on")
    }
}
