import XCTest
@testable import EchoelDSP

final class MultibandCompressorTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, amplitude: Double = 0.5, count: Int = 48_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000) * amplitude)
        }
    }

    private func run(_ compressor: MultibandCompressor, _ input: [Float], block: Int = 256) -> [Float] {
        var l = input, r = input
        var start = 0
        while start < input.count {
            let n = Swift.min(block, input.count - start)
            l.withUnsafeMutableBufferPointer { lp in
                r.withUnsafeMutableBufferPointer { rp in
                    guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                    compressor.process(left: a + start, right: b + start, frames: n)
                }
            }
            start += n
        }
        return l
    }

    private func level(_ signal: [Float]) -> Float {
        let tail = Array(signal.suffix(signal.count / 2))
        return (tail.reduce(0) { $0 + $1 * $1 } / Float(tail.count)).squareRoot()
    }

    private func decibels(_ ratio: Float) -> Float { 20 * log10f(ratio) }

    /// With no band compressing, the crossovers add back up to the input's level at every
    /// frequency — on a crossover, between them and far from them.
    func testUncompressedTheBandsSumBackToTheInputsLevel() {
        let open = MultibandCompressor.Settings(lowRatio: 1, midRatio: 1, highRatio: 1)
        for hertz in [40.0, 200, 700, 2_500, 9_000] {
            let input = sine(hertz)
            let out = run(MultibandCompressor(sampleRate: rate, settings: open), input)
            XCTAssertEqual(decibels(level(out) / level(input)), 0, accuracy: 0.05, "\(hertz) Hz")
        }
    }

    func testOneBandCompressesWithoutTouchingTheOthers() {
        let lowOnly = MultibandCompressor.Settings(lowThreshold: -40, midThreshold: 0, highThreshold: 0,
                                                   lowRatio: 10, midRatio: 1, highRatio: 1)
        let bass = sine(70), air = sine(6_000)
        let compressor = MultibandCompressor(sampleRate: rate, settings: lowOnly)
        let bassOut = run(compressor, bass)
        XCTAssertLessThan(decibels(level(bassOut) / level(bass)), -20, "the low band is held down")
        XCTAssertLessThan(compressor.reduction, -20, "the meter reads the deepest band")
        let airOut = run(MultibandCompressor(sampleRate: rate, settings: lowOnly), air)
        XCTAssertEqual(decibels(level(airOut) / level(air)), 0, accuracy: 0.1, "the high band is left alone")
    }

    func testMakeupRaisesTheSumAndABlockOfAnySizePlaysTheSame() {
        let open = MultibandCompressor.Settings(lowRatio: 1, midRatio: 1, highRatio: 1, makeup: 6)
        let input = sine(1_000, amplitude: 0.2)
        let small = run(MultibandCompressor(sampleRate: rate, settings: open), input, block: 37)
        let large = run(MultibandCompressor(sampleRate: rate, settings: open), input, block: 1_024)
        XCTAssertEqual(decibels(level(large) / level(input)), 6, accuracy: 0.05)
        for index in stride(from: 0, to: input.count, by: 97) {
            XCTAssertEqual(small[index], large[index], accuracy: 1e-5)
        }
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let compressor = MultibandCompressor(sampleRate: rate, settings: .init(lowCrossover: 5, highCrossover: .nan, makeup: 99))
        XCTAssertEqual(compressor.settings.lowCrossover, 50)
        XCTAssertEqual(compressor.settings.highCrossover, 2_500)
        XCTAssertEqual(compressor.settings.makeup, 24)
        compressor.settings = .init()
        var input = sine(300, count: 4_800)
        input[1_000] = .nan
        let out = run(compressor, input)
        XCTAssertEqual(out[1_000], 0)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
    }
}
