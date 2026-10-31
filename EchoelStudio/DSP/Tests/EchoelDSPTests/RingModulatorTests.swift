import XCTest
@testable import EchoelDSP

final class RingModulatorTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ effect: RingModulator, left: [Float], right: [Float]) -> ([Float], [Float]) {
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
        let ring = RingModulator(sampleRate: rate, settings: .init(mix: 0))
        let input = sine(220, amplitude: 0.8, count: 4_800)
        let (l, r) = run(ring, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// 1 kHz through a 300 Hz carrier: 700 Hz and 1.3 kHz, half the level each, and no 1 kHz.
    func testATonBecomesTheSumAndDifference() {
        let ring = RingModulator(sampleRate: rate, settings: .init(frequency: 300, mix: 1))
        let input = sine(1_000, amplitude: 0.8, count: 48_000)
        let (l, _) = run(ring, left: input, right: input)
        XCTAssertEqual(level(of: 700, in: l), 0.4, accuracy: 0.01)
        XCTAssertEqual(level(of: 1_300, in: l), 0.4, accuracy: 0.01)
        XCTAssertLessThan(level(of: 1_000, in: l), 0.01)
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let ring = RingModulator(sampleRate: rate, settings: .init(frequency: 0, mix: .nan))
        XCTAssertEqual(ring.settings, .init(frequency: 1, mix: 0.5))
        var input = [Float](repeating: 0.5, count: 100)
        input[10] = -.infinity
        let (l, r) = run(ring, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
