import XCTest
@testable import EchoelDSP

final class MidSideTests: XCTestCase {
    private let rate = 48_000.0

    private func sine(_ hertz: Double, amplitude: Double, count: Int = 24_000) -> [Float] {
        (0..<count).map { (index: Int) -> Float in
            Float(Foundation.sin(2 * Double.pi * hertz * Double(index) / 48_000) * amplitude)
        }
    }

    private func run(_ effect: MidSide, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                effect.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    /// Two different sounds left and right: a mid and a side to work on.
    private func pair() -> ([Float], [Float]) {
        let low = sine(60, amplitude: 0.3), high = sine(5_000, amplitude: 0.2), mid = sine(440, amplitude: 0.3)
        let left = (0..<low.count).map { (i: Int) -> Float in mid[i] + low[i] + high[i] }
        let right = (0..<low.count).map { (i: Int) -> Float in mid[i] - low[i] - high[i] }
        return (left, right)
    }

    private func level(_ signal: [Float]) -> Float {
        let tail = Array(signal.suffix(signal.count / 2))
        return (tail.reduce(0) { $0 + $1 * $1 } / Float(tail.count)).squareRoot()
    }

    func testTheMonoSumIsTheMidWhateverTheSideDoes() {
        let (a, b) = pair()
        let extreme = MidSide.Settings(width: 2, midGain: 0, sideGain: 12, tilt: 6, monoBelow: 300)
        let (l, r) = run(MidSide(sampleRate: rate, settings: extreme), left: a, right: b)
        for index in stride(from: 0, to: a.count, by: 7) {
            XCTAssertEqual(l[index] + r[index], a[index] + b[index], accuracy: 1e-5)
        }
        let (ml, mr) = run(MidSide(sampleRate: rate, settings: .init(midGain: -6)), left: a, right: b)
        XCTAssertEqual(ml[1_000] + mr[1_000], (a[1_000] + b[1_000]) * 0.501, accuracy: 1e-3)
    }

    func testWidthZeroFoldsToMonoAndSideGainScalesTheSide() {
        let (a, b) = pair()
        let (ml, mr) = run(MidSide(sampleRate: rate, settings: .init(width: 0)), left: a, right: b)
        XCTAssertEqual(ml, mr)
        let side = { (l: [Float], r: [Float]) -> [Float] in (0..<l.count).map { (i: Int) -> Float in l[i] - r[i] } }
        let (pl, pr) = run(MidSide(sampleRate: rate), left: a, right: b)
        let (ql, qr) = run(MidSide(sampleRate: rate, settings: .init(sideGain: -12)), left: a, right: b)
        XCTAssertEqual(level(side(ql, qr)) / level(side(pl, pr)), 0.251, accuracy: 0.01)
    }

    func testMonoBelowTakesTheLowSideOutAndKeepsTheHigh() {
        let lowSide = sine(60, amplitude: 0.3), highSide = sine(5_000, amplitude: 0.3)
        let negate = { (x: [Float]) -> [Float] in x.map { -$0 } }
        let mono = MidSide.Settings(monoBelow: 300)
        let (ll, lr) = run(MidSide(sampleRate: rate, settings: mono), left: lowSide, right: negate(lowSide))
        let (hl, hr) = run(MidSide(sampleRate: rate, settings: mono), left: highSide, right: negate(highSide))
        XCTAssertLessThan(level(ll), level(lowSide) * 0.1, "60 Hz is mono below 300 Hz")
        XCTAssertLessThan(Swift.abs(level(hl) - level(highSide)), level(highSide) * 0.02, "5 kHz keeps its side")
        XCTAssertEqual(level(lr), level(ll), accuracy: 1e-4)
        XCTAssertEqual(level(hr), level(hl), accuracy: 1e-4)
    }

    func testTheTiltBrightensOrDarkensTheSide() {
        let high = sine(8_000, amplitude: 0.3), low = sine(100, amplitude: 0.3)
        let negate = { (x: [Float]) -> [Float] in x.map { -$0 } }
        let bright = MidSide.Settings(tilt: 6)
        let (bh, _) = run(MidSide(sampleRate: rate, settings: bright), left: high, right: negate(high))
        let (bl, _) = run(MidSide(sampleRate: rate, settings: bright), left: low, right: negate(low))
        XCTAssertGreaterThan(level(bh) / level(high), 1.3, "8 kHz up by nearly 3 dB")
        XCTAssertLessThan(level(bl) / level(low), 0.77, "100 Hz down by nearly 3 dB")
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let effect = MidSide(sampleRate: rate, settings: .init(width: 9, midGain: .nan, sideGain: -99, tilt: 99, monoBelow: 0))
        XCTAssertEqual(effect.settings, .init(width: 2, midGain: 0, sideGain: -24, tilt: 6, monoBelow: 20))
        var (a, b) = pair()
        a[50] = .nan
        b[60] = -.infinity
        let (l, r) = run(effect, left: a, right: b)
        XCTAssertEqual(l[50], 0)
        XCTAssertEqual(r[60], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
