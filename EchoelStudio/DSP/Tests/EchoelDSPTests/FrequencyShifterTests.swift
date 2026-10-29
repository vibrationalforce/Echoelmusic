import XCTest
@testable import EchoelDSP

final class FrequencyShifterTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ effect: FrequencyShifter, left: [Float], right: [Float]) -> ([Float], [Float]) {
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
        let shifter = FrequencyShifter(sampleRate: rate, settings: .init(mix: 0))
        let input = sine(220, amplitude: 0.8, count: 4_800)
        let (l, r) = run(shifter, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// 1 kHz shifted by +150 Hz is 1.15 kHz — the same Hz, not the same ratio — and the mirror
    /// at 850 Hz stays far down. A negative shift goes the other way.
    func testEveryFrequencyMovesByTheSameHertz() {
        let input = sine(1_000, amplitude: 0.8, count: 48_000)
        for (shift, wanted, mirror) in [(150.0, 1_150.0, 850.0), (-150.0, 850.0, 1_150.0)] {
            let shifter = FrequencyShifter(sampleRate: rate, settings: .init(shift: shift, mix: 1))
            let (l, r) = run(shifter, left: input, right: input)
            let settled = Array(l.suffix(24_000))
            let main = level(of: wanted, in: settled)
            XCTAssertEqual(main, 0.8, accuracy: 0.05, "\(shift) Hz")
            XCTAssertLessThan(level(of: mirror, in: settled), main / 50, "\(shift) Hz: the other sideband is 34 dB down or more")
            XCTAssertLessThan(level(of: 1_000, in: settled), main / 50)
            XCTAssertEqual(l, r)
        }
    }

    func testABadSampleEmptiesTheAllpassesAndSettingsAreClamped() {
        let shifter = FrequencyShifter(sampleRate: rate, settings: .init(shift: 5_000, mix: .nan))
        XCTAssertEqual(shifter.settings, .init(shift: 1_000, mix: 0.5))
        var input = sine(440, amplitude: 0.5, count: 2_000)
        input[10] = .nan
        let (l, r) = run(shifter, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "no NaN rings on")
    }
}
