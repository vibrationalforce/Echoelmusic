import XCTest
@testable import EchoelDSP

final class LimiterTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ limiter: Limiter, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                limiter.process(left: a, right: b, frames: lp.count)
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

    /// How far `output` is from the best scaled copy of `input`, relative to its own level.
    private func shapeError(output: [Float], input: [Float]) -> Double {
        var cross = 0.0, inputEnergy = 0.0, outputEnergy = 0.0
        for index in 0..<Swift.min(output.count, input.count) {
            let x = Double(input[index]), y = Double(output[index])
            cross += x * y
            inputEnergy += x * x
            outputEnergy += y * y
        }
        guard inputEnergy > 0, outputEnergy > 0 else { return 1 }
        let scale = cross / inputEnergy
        var residual = 0.0
        for index in 0..<Swift.min(output.count, input.count) {
            let difference = Double(output[index]) - scale * Double(input[index])
            residual += difference * difference
        }
        return Foundation.sqrt(residual / outputEnergy)
    }

    func testQuietSoundPassesUntouched() {
        let limiter = Limiter(sampleRate: rate)
        let input = sine(440, amplitude: 0.5, count: 4_800)
        let (l, r) = run(limiter, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
        XCTAssertEqual(limiter.reduction, 0, accuracy: 1e-6)
    }

    /// 12 dB over the ceiling, on a bass and a mid tone: never above it, and scaled, not
    /// clipped flat. The settled output stays a scaled copy of the input: its shape error is
    /// under 5 % (a hard clipper at the same ceiling measures about 33 %).
    func testNothingPassesTheCeilingAndTheWaveIsScaledNotClipped() {
        for hertz in [40.0, 200.0] {
            let limiter = Limiter(sampleRate: rate, settings: .init(ceiling: -6))
            let ceiling = Float(Foundation.pow(10, -6.0 / 20))
            let input = sine(hertz, amplitude: 2, count: 48_000)
            let (l, r) = run(limiter, left: input, right: input)
            let peak = l.map { Swift.abs($0) }.max() ?? 0
            XCTAssertLessThanOrEqual(peak, ceiling * 1.001, "\(hertz) Hz")
            XCTAssertGreaterThan(peak, ceiling * 0.9, "\(hertz) Hz: it limits, it does not duck")
            XCTAssertLessThan(shapeError(output: Array(l.suffix(24_000)), input: Array(input.suffix(24_000))), 0.05,
                              "\(hertz) Hz: no flat tops")
            XCTAssertEqual(l, r)
            XCTAssertLessThan(limiter.reduction, -5)
        }
    }

    func testGainPushesTheSoundIntoTheCeilingAndTheReductionRecovers() {
        let limiter = Limiter(sampleRate: rate, settings: .init(gain: 12, ceiling: -1, release: 0.05))
        let loud = sine(220, amplitude: 0.5, count: 9_600)
        _ = run(limiter, left: loud, right: loud)
        XCTAssertLessThan(limiter.reduction, -4)
        let silence = [Float](repeating: 0, count: 48_000)
        _ = run(limiter, left: silence, right: silence)
        XCTAssertGreaterThan(limiter.reduction, -0.1, "a second of silence lets the gain come back")
    }

    func testABadSampleIsSilenceAndLeavesTheStateIntactAndSettingsAreClamped() {
        let limiter = Limiter(sampleRate: rate, settings: .init(gain: 100, ceiling: 5, release: .nan))
        XCTAssertEqual(limiter.settings, .init(gain: 24, ceiling: 0, release: 0.06))
        var input = sine(220, amplitude: 0.05, count: 4_800)
        input[100] = .nan
        input[200] = .infinity
        let (l, r) = run(limiter, left: input, right: input)
        XCTAssertEqual(l[100], 0)
        XCTAssertEqual(r[200], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
        XCTAssertLessThanOrEqual(l.map { Swift.abs($0) }.max() ?? 0, 1.001)
    }
}
