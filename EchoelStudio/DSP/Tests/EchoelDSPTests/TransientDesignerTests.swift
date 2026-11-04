import XCTest
@testable import EchoelDSP

final class TransientDesignerTests: XCTestCase {
    private let rate = 48_000.0

    /// A plucked note: silence, then a 220 Hz tone that starts at once and dies in about 150 ms.
    private func pluck(amplitude: Double = 0.5, count: Int = 24_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            let start = 2_400
            guard index >= start else { return 0 }
            let t = Double(index - start) / 48_000
            return Float(amplitude * Foundation.exp(-t / 0.15) * Foundation.sin(2 * Double.pi * 220 * t))
        }
    }

    private func run(_ designer: TransientDesigner, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                designer.process(left: a, right: b, frames: lp.count)
            }
        }
        return l
    }

    private func peak(_ signal: [Float], _ range: Range<Int>) -> Float {
        signal[range].reduce(0) { Swift.max($0, Swift.abs($1)) }
    }

    private func energy(_ signal: [Float], _ range: Range<Int>) -> Float {
        signal[range].reduce(0) { $0 + $1 * $1 }
    }

    func testAtZeroItLeavesTheSound() {
        let input = pluck()
        XCTAssertEqual(run(TransientDesigner(sampleRate: rate), input), input)
    }

    func testAttackHardensOrSoftensTheStart() {
        let input = pluck()
        let onset = 2_400..<(2_400 + 240) // the first 5 ms
        let plain = peak(input, onset)
        let harder = peak(run(TransientDesigner(sampleRate: rate, settings: .init(attack: 12)), input), onset)
        let softer = peak(run(TransientDesigner(sampleRate: rate, settings: .init(attack: -12)), input), onset)
        XCTAssertGreaterThan(harder, plain * 1.4, "harder \(harder), plain \(plain)")
        XCTAssertLessThan(softer, plain * 0.7, "softer \(softer), plain \(plain)")
    }

    func testSustainLengthensOrShortensTheTail() {
        let input = pluck()
        let tail = (2_400 + 9_600)..<24_000 // 200 ms after the start onward
        let plain = energy(input, tail)
        let longer = energy(run(TransientDesigner(sampleRate: rate, settings: .init(sustain: 12)), input), tail)
        let shorter = energy(run(TransientDesigner(sampleRate: rate, settings: .init(sustain: -12)), input), tail)
        XCTAssertGreaterThan(longer, plain * 2, "longer \(longer), plain \(plain)")
        XCTAssertLessThan(shorter, plain * 0.5, "shorter \(shorter), plain \(plain)")
    }

    func testTheShapeDoesNotDependOnTheLevel() {
        let onset = 2_400..<(2_400 + 240)
        let settings = TransientDesigner.Settings(attack: 12)
        let loud = pluck(amplitude: 0.5), quiet = pluck(amplitude: 0.05)
        let loudGain = peak(run(TransientDesigner(sampleRate: rate, settings: settings), loud), onset) / peak(loud, onset)
        let quietGain = peak(run(TransientDesigner(sampleRate: rate, settings: settings), quiet), onset) / peak(quiet, onset)
        XCTAssertEqual(loudGain, quietGain, accuracy: 0.05)
    }

    func testOutputGainAndABadSampleIsSilence() {
        let designer = TransientDesigner(sampleRate: rate, settings: .init(attack: 99, sustain: .nan, output: -99))
        XCTAssertEqual(designer.settings, .init(attack: 24, sustain: 0, output: -24))
        let quieter = run(TransientDesigner(sampleRate: rate, settings: .init(output: -6)), pluck())
        XCTAssertEqual(peak(quieter, 0..<24_000), peak(pluck(), 0..<24_000) * 0.501, accuracy: 0.01)
        var bad = pluck()
        bad[3_000] = .nan
        let out = run(designer, bad)
        XCTAssertEqual(out[3_000], 0)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
    }
}
