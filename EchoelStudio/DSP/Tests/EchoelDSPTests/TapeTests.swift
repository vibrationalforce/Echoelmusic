import XCTest
@testable import EchoelDSP

final class TapeTests: XCTestCase {
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

    /// Clean and bright without warble, the tape is the sound 6 ms later.
    func testWithoutWowTheSoundArrivesAfterTheBaseDelay() {
        let tape = Tape(sampleRate: rate, settings: .init(wow: 0, saturation: 0, tone: 1))
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        let (l, _) = run(tape, left: impulse, right: impulse)
        let peak = l.indices.max { l[$0] < l[$1] } ?? -1
        XCTAssertEqual(peak, Int(Tape.baseSeconds * rate), "the impulse arrives after the base delay")
    }

    /// With wow the delay sways, so the delay between input and output changes over time.
    func testWowMakesThePitchWarble() {
        let tape = Tape(sampleRate: rate, settings: .init(wow: 1, saturation: 0, tone: 1))
        let input = sine(1_000, amplitude: 0.5, count: 96_000)
        let (l, _) = run(tape, left: input, right: input)
        let still = Tape(sampleRate: rate, settings: .init(wow: 0, saturation: 0, tone: 1))
        let (s, _) = run(still, left: input, right: input)
        let difference = zip(l, s).map { Swift.abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 0.3, "the warbled copy drifts against the steady one")
        XCTAssertTrue(l.allSatisfy(\.isFinite))
    }

    /// A worn tape (tone 0) keeps a low tone and loses a high one.
    func testAWornToneLosesTheTop() {
        let tape = Tape(sampleRate: rate, settings: .init(wow: 0, saturation: 0, tone: 0))
        let low = sine(200, amplitude: 0.5, count: 9_600)
        let high = sine(8_000, amplitude: 0.5, count: 9_600)
        let (l, _) = run(tape, left: low, right: low)
        tape.reset()
        let (h, _) = run(tape, left: high, right: high)
        XCTAssertGreaterThan(level(of: 200, in: Array(l.suffix(4_800))), 0.45)
        XCTAssertLessThan(level(of: 8_000, in: Array(h.suffix(4_800))), 0.1)
    }

    func testABadSampleEmptiesTheLineAndSettingsAreClamped() {
        let tape = Tape(sampleRate: rate, settings: .init(wow: 3, saturation: .nan, tone: -2))
        XCTAssertEqual(tape.settings, .init(wow: 1, saturation: 0.25, tone: 0))
        var input = [Float](repeating: 0.5, count: 2_000)
        input[10] = .nan
        let (l, r) = run(tape, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "no NaN rings on")
    }
}
