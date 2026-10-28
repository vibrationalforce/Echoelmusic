import XCTest
@testable import EchoelDSP

final class LadderFilterTests: XCTestCase {
    private let rate: Float = 48_000

    private func level(_ hertz: Float, cutoff: Float, resonance: Float = 0, amplitude: Float = 0.1) -> Float {
        var filter = LadderFilter(cutoff: cutoff, resonance: resonance, sampleRate: rate)
        var sum: Float = 0
        let frames = 24_000
        for n in 0..<frames {
            let y = filter.process(amplitude * sinf(2 * Float.pi * hertz * Float(n) / rate))
            if n >= frames / 2 { sum += y * y }
        }
        return (sum / Float(frames / 2)).squareRoot() / (amplitude / Float(2).squareRoot())
    }

    func testItPassesBelowAndCutsAboveTheCutoff() {
        XCTAssertGreaterThan(level(100, cutoff: 2_000), 0.8, "well below: passes")
        XCTAssertLessThan(level(16_000, cutoff: 1_000), 0.01, "four octaves above: 24 dB per octave")
    }

    func testResonanceLiftsTheCutoff() {
        XCTAssertGreaterThan(level(1_000, cutoff: 1_000, resonance: 0.9), level(1_000, cutoff: 1_000, resonance: 0) * 2)
    }

    func testABadSampleOrSettingNeverRings() {
        var filter = LadderFilter(cutoff: .nan, resonance: .infinity, sampleRate: rate)
        XCTAssertEqual(filter.cutoff, 2_000)
        XCTAssertEqual(filter.resonance, 0.3)
        _ = filter.process(.nan)
        for _ in 0..<100 { XCTAssertTrue(filter.process(0.1).isFinite) }
        filter.setResonance(0.95)
        var peak: Float = 0
        for n in 0..<48_000 { peak = Swift.max(peak, Swift.abs(filter.process(n == 0 ? 1 : 0))) }
        XCTAssertLessThan(peak, 4, "full resonance stays bounded")
    }

    /// The synth plays through the ladder when its patch says so, and it sounds different from
    /// the state-variable filter at the same cutoff.
    func testTheSynthPlaysThroughTheLadder() {
        func render(_ model: SynthPatch.FilterModel) -> [Float] {
            var patch = SynthPatch(cutoff: 600, resonance: 0.8, filterEnvelopeAmount: 0, level: 1)
            patch.filterModel = model
            var synth = PolySynth(patch: patch, sampleRate: rate)
            synth.noteOn(pitch: 45, velocity: 127)
            var buffer = [Float](repeating: 0, count: 4_800)
            buffer.withUnsafeMutableBufferPointer { synth.render(into: $0) }
            return buffer
        }
        let ladder = render(.ladder), clean = render(.stateVariable)
        XCTAssertTrue(ladder.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(ladder.map { Swift.abs($0) }.max() ?? 0, 0.01)
        XCTAssertNotEqual(ladder, clean)
    }
}
