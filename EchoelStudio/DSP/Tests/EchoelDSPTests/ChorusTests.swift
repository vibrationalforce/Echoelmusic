import XCTest
@testable import EchoelDSP

final class ChorusTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ chorus: Chorus, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                chorus.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    func testFullyDryPassesTheSoundThrough() {
        let chorus = Chorus(sampleRate: rate, settings: .init(mix: 0))
        let input: [Float] = (0..<1_000).map { (index: Int) -> Float in Float(index % 7) * 0.1 }
        let (l, r) = run(chorus, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// Without sway the wet sound is the input 12 ms later.
    func testWithoutDepthTheWetSoundIsTheCentreDelay() {
        let chorus = Chorus(sampleRate: rate, settings: .init(depth: 0, mix: 1))
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        let (l, _) = run(chorus, left: impulse, right: impulse)
        let peak = l.indices.max { l[$0] < l[$1] } ?? -1
        XCTAssertEqual(peak, Int(Chorus.centreSeconds * rate), "the impulse arrives after the centre delay")
        XCTAssertEqual(l[peak], 1, accuracy: 1e-4)
    }

    /// With sway the two sides read the line at different places: the stereo width.
    func testTheSidesSwayAgainstEachOther() {
        let chorus = Chorus(sampleRate: rate, settings: .init(rate: 2, depth: 1, mix: 1))
        let tone: [Float] = (0..<24_000).map { (index: Int) -> Float in Float(sin(2 * Double.pi * 440 * Double(index) / 48_000)) }
        let (l, r) = run(chorus, left: tone, right: tone)
        let difference = zip(l, r).map { abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 0.1)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }

    func testABadSampleEmptiesTheLinesAndSettingsAreClamped() {
        let chorus = Chorus(sampleRate: rate, settings: .init(rate: 100, depth: 5, mix: .nan))
        XCTAssertEqual(chorus.settings, .init(rate: 8, depth: 1, mix: 0.5))
        var input = [Float](repeating: 0.5, count: 2_000)
        input[10] = .nan
        let (l, r) = run(chorus, left: input, right: input)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "no NaN rings on")
    }
}
