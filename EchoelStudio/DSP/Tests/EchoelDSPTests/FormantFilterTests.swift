import XCTest
@testable import EchoelDSP

final class FormantFilterTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, amplitude: Double = 0.3, count: Int = 24_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000) * amplitude)
        }
    }

    private func run(_ filter: FormantFilter, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                filter.process(left: a, right: b, frames: lp.count)
            }
        }
        return l
    }

    /// The RMS of the second half, after the bands have rung in.
    private func level(_ signal: [Float]) -> Float {
        let tail = Array(signal.suffix(signal.count / 2))
        return (tail.reduce(0) { $0 + $1 * $1 } / Float(tail.count)).squareRoot()
    }

    func testEachVowelPassesItsOwnFirstFormantAndNotAnothersFirst() {
        // "a" sits at 730 Hz, "i" at 270 Hz: each vowel passes its own and holds back the other's.
        let a = FormantFilter.Settings(vowel: 0, resonance: 0.5, mix: 1)
        let i = FormantFilter.Settings(vowel: 2, resonance: 0.5, mix: 1)
        let aOwn = level(run(FormantFilter(sampleRate: rate, settings: a), sine(730)))
        let aOther = level(run(FormantFilter(sampleRate: rate, settings: a), sine(270)))
        let iOwn = level(run(FormantFilter(sampleRate: rate, settings: i), sine(270)))
        let iOther = level(run(FormantFilter(sampleRate: rate, settings: i), sine(730)))
        XCTAssertGreaterThan(aOwn, aOther * 4, "a: \(aOwn) at 730 Hz, \(aOther) at 270 Hz")
        XCTAssertGreaterThan(iOwn, iOther * 4, "i: \(iOwn) at 270 Hz, \(iOther) at 730 Hz")
    }

    func testTheVowelMorphsBetweenItsNeighbours() {
        let half = FormantFilter.formants(at: 0.5)
        XCTAssertEqual(half.0, (730 + 530) / 2, accuracy: 1e-9)
        XCTAssertEqual(half.1, (1_090 + 1_840) / 2, accuracy: 1e-9)
        XCTAssertEqual(FormantFilter.formants(at: 4).0, 300, accuracy: 1e-9, "u")
        XCTAssertEqual(FormantFilter.formants(at: 9).0, 300, accuracy: 1e-9, "past u is u")
    }

    func testAMoreResonantBandIsNarrower() {
        // Half an octave off the first formant of "a": a sharper band lets less of it through.
        let broad = level(run(FormantFilter(sampleRate: rate, settings: .init(vowel: 0, resonance: 0)), sine(1_030)))
        let sharp = level(run(FormantFilter(sampleRate: rate, settings: .init(vowel: 0, resonance: 1)), sine(1_030)))
        XCTAssertLessThan(sharp, broad * 0.7, "sharp \(sharp), broad \(broad)")
    }

    func testMixZeroPassesTheSoundAndABadSampleIsSilence() {
        let input = sine(440, count: 2_400)
        XCTAssertEqual(run(FormantFilter(sampleRate: rate, settings: .init(mix: 0)), input), input)
        let filter = FormantFilter(sampleRate: rate, settings: .init(vowel: .nan, resonance: 7, mix: -1))
        XCTAssertEqual(filter.settings, .init(vowel: 0, resonance: 1, mix: 0))
        filter.settings = .init()
        var bad = sine(440, count: 2_400)
        bad[100] = .infinity
        let out = run(filter, bad)
        XCTAssertEqual(out[100], 0)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
    }
}
