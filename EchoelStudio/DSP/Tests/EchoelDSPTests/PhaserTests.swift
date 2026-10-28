import XCTest
@testable import EchoelDSP

final class PhaserTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ phaser: Phaser, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                phaser.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    private func tone(_ hertz: Double, count: Int) -> [Float] {
        (0..<count).map { (index: Int) -> Float in Float(sin(2 * Double.pi * hertz * Double(index) / 48_000)) }
    }

    private func energy(_ samples: ArraySlice<Float>) -> Float {
        samples.reduce(0) { $0 + $1 * $1 } / Float(Swift.max(1, samples.count))
    }

    func testFullyDryPassesTheSoundThrough() {
        let phaser = Phaser(sampleRate: rate, settings: .init(mix: 0))
        let input: [Float] = (0..<1_000).map { (index: Int) -> Float in Float(index % 7) * 0.1 }
        let (l, r) = run(phaser, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// An allpass chain without feedback keeps a tone's level; only the mix with the dry sound
    /// makes the notch.
    func testTheWetChainKeepsTheLevel() {
        let phaser = Phaser(sampleRate: rate, settings: .init(depth: 0, feedback: 0, mix: 1))
        let input = tone(440, count: 24_000)
        let (l, _) = run(phaser, left: input, right: input)
        XCTAssertEqual(energy(l[12_000...]), energy(input[12_000...]), accuracy: 0.01)
    }

    /// Half wet, half dry: a tone near the parked break frequency loses level in the notch.
    func testTheMixCutsANotch() {
        let phaser = Phaser(sampleRate: rate, settings: .init(depth: 0, feedback: 0, mix: 0.5))
        let input = tone(1_250, count: 24_000)
        let (l, _) = run(phaser, left: input, right: input)
        XCTAssertLessThan(energy(l[12_000...]), energy(input[12_000...]) * 0.5)
    }

    /// The sweep moves the sides against each other: the stereo width.
    func testTheSidesSweepAgainstEachOther() {
        let phaser = Phaser(sampleRate: rate, settings: .init(rate: 2, depth: 1, feedback: 0.5, mix: 0.5))
        let input = tone(800, count: 24_000)
        let (l, r) = run(phaser, left: input, right: input)
        let difference = zip(l, r).map { abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 0.1)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }

    func testABadSampleEmptiesTheStagesAndSettingsAreClamped() {
        let phaser = Phaser(sampleRate: rate, settings: .init(rate: 100, depth: 5, feedback: 2, mix: .nan))
        XCTAssertEqual(phaser.settings, .init(rate: 8, depth: 1, feedback: 0.95, mix: 0.5))
        var input = [Float](repeating: 0.5, count: 2_000)
        input[10] = .nan
        let (l, r) = run(phaser, left: input, right: input)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite), "no NaN rings on")
    }
}
