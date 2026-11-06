import XCTest
@testable import EchoelDSP

final class DeEsserTests: XCTestCase {
    private let rate = 48_000.0
    private let count = 24_000

    /// White noise from a fixed seed, −1 … 1.
    private func noise(_ length: Int) -> [Float] {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var out = [Float](repeating: 0, count: length)
        for index in 0..<length {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(state >> 11) / Double(UInt64(1) << 53)
            out[index] = Float(unit * 2 - 1)
        }
        return out
    }

    /// An "s": white noise high-passed at 5 kHz (24 dB per octave) at about −12 dBFS RMS.
    private func sibilant() -> [Float] {
        var first = ZDFStage(), second = ZDFStage()
        let g = ZDFStage.g(5_000, sampleRate: rate)
        let k = ZDFStage.butterworth
        return noise(count).map { (sample: Float) -> Float in
            0.5 * second.process(first.process(sample, g: g, k: k).high, g: g, k: k).high
        }
    }

    /// A vowel: 300 Hz and its harmonics up to 1.8 kHz, peaking at 0.8.
    private func vowel() -> [Float] {
        let raw = (0..<count).map { (index: Int) -> Float in
            var sum = 0.0
            for harmonic in 1...6 {
                let phase = 2 * Double.pi * 300 * Double(harmonic) * Double(index) / 48_000
                sum += Foundation.sin(phase) / Double(harmonic)
            }
            return Float(sum)
        }
        let peak = raw.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        return raw.map { (sample: Float) -> Float in sample / peak * 0.8 }
    }

    private func run(_ deEsser: DeEsser, _ input: [Float], blocks: [Int] = []) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                guard !blocks.isEmpty else {
                    deEsser.process(left: a, right: b, frames: lp.count)
                    return
                }
                var done = 0, turn = 0
                while done < lp.count {
                    let piece = Swift.min(blocks[turn % blocks.count], lp.count - done)
                    deEsser.process(left: a + done, right: b + done, frames: piece)
                    done += piece
                    turn += 1
                }
            }
        }
        return l
    }

    private func rms(_ x: [Float]) -> Float {
        (x.reduce(Float(0)) { $0 + $1 * $1 } / Float(Swift.max(x.count, 1))).squareRoot()
    }

    /// The level change of the second half (the follower settled), in dB.
    private func change(_ deEsser: DeEsser, _ input: [Float]) -> Float {
        let out = run(deEsser, input)
        let half = input.count / 2
        return 20 * log10f(rms(Array(out[half...])) / rms(Array(input[half...])))
    }

    /// An "s" far over the threshold is turned down by nearly its Range and never by more: the
    /// shelf takes the full range above its frequency and less in the noise between 5 kHz and it
    /// (a float simulation of this design, 2026-11-06: −11.25 dB for Range 12 at 5 kHz, −8.73 dB
    /// for Range 10 at the default 6.5 kHz).
    func testAnSOverTheThresholdDropsByAboutItsRange() {
        let s = sibilant()
        let atFive = DeEsser(sampleRate: rate, settings: .init(frequency: 5_000, threshold: -40, range: 12))
        let five = change(atFive, s)
        XCTAssertLessThan(five, -10, "nearly the 12 dB of Range")
        XCTAssertGreaterThan(five, -12, "never more than Range")
        XCTAssertEqual(atFive.reduction, -12, "the meter reads the full Range")
        let atDefault = change(DeEsser(sampleRate: rate, settings: .init(threshold: -40, range: 10)), s)
        XCTAssertLessThan(atDefault, -8)
        XCTAssertGreaterThan(atDefault, -10)
    }

    /// A vowel passes: under the threshold it is the input itself, and even with the threshold so
    /// low that its faint top sets the de-esser off, the highs it turns down are not where a vowel is.
    func testAVowelBelowTwoKilohertzPasses() {
        let v = vowel()
        let quiet = DeEsser(sampleRate: rate, settings: .init(threshold: -40, range: 12))
        XCTAssertEqual(change(quiet, v), 0, accuracy: 0.1)
        XCTAssertEqual(quiet.reduction, 0, "a vowel does not reach the detector at −40 dB")
        let triggered = DeEsser(sampleRate: rate, settings: .init(threshold: -60, range: 12))
        XCTAssertEqual(change(triggered, v), 0, accuracy: 0.1)
    }

    /// With no reduction the output is the input sample for sample — the split is complementary,
    /// not an allpass.
    func testRangeZeroAndUnderTheThresholdAreTheInputItself() {
        let input = zip(sibilant(), vowel()).map { (pair: (Float, Float)) -> Float in pair.0 + 0.5 * pair.1 }
        XCTAssertEqual(run(DeEsser(sampleRate: rate, settings: .init(threshold: -60, range: 0)), input), input)
        let quiet = input.map { (sample: Float) -> Float in sample * 0.001 }
        XCTAssertEqual(run(DeEsser(sampleRate: rate, settings: .init(threshold: -20, range: 24)), quiet), quiet)
    }

    /// Listen plays the detector's band: the "s" nearly whole, the vowel hardly at all.
    func testListenPlaysOnlyTheDetectedBand() {
        let settings = DeEsser.Settings(threshold: -40, range: 12, listen: true)
        XCTAssertLessThan(change(DeEsser(sampleRate: rate, settings: settings), vowel()), -40)
        XCTAssertGreaterThan(change(DeEsser(sampleRate: rate, settings: settings), sibilant()), -3)
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let deEsser = DeEsser(sampleRate: rate, settings: .init(frequency: 100, threshold: .nan, range: 99))
        XCTAssertEqual(deEsser.settings, .init(frequency: 3_000, threshold: -30, range: 24))
        var input = sibilant()
        input[500] = .nan
        input[900] = .infinity
        let out = run(deEsser, input)
        XCTAssertEqual(out[500], 0)
        XCTAssertEqual(out[900], 0)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        XCTAssertTrue(deEsser.reduction.isFinite)
    }

    /// Every sample is worked out on its own, so how the host cuts the blocks changes nothing.
    func testTheBlockSizeDoesNotChangeTheSound() {
        let input = zip(sibilant(), vowel()).map { (pair: (Float, Float)) -> Float in pair.0 + 0.5 * pair.1 }
        let settings = DeEsser.Settings(frequency: 7_000, threshold: -36, range: 18)
        let whole = run(DeEsser(sampleRate: rate, settings: settings), input)
        let pieces = run(DeEsser(sampleRate: rate, settings: settings), input, blocks: [1, 7, 64, 333, 512])
        XCTAssertEqual(whole, pieces)
    }
}
