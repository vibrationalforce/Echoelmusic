import XCTest
@testable import EchoelDSP

final class StereoDelayTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ delay: StereoDelay, left: [Float], right: [Float]) -> ([Float], [Float]) {
        var l = left, r = right
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                guard let a = lp.baseAddress, let b = rp.baseAddress else { return }
                delay.process(left: a, right: b, frames: lp.count)
            }
        }
        return (l, r)
    }

    private func impulse(_ count: Int) -> [Float] {
        var x = [Float](repeating: 0, count: count)
        x[0] = 1
        return x
    }

    func testAnImpulseComesBackAfterTheTimeAndEachRepeatIsQuieter() {
        let delay = StereoDelay(sampleRate: rate, settings: .init(time: 0.01, feedback: 0.5, mix: 1, damping: 20_000))
        let (left, right) = run(delay, left: impulse(2_000), right: [Float](repeating: 0, count: 2_000))
        XCTAssertEqual(left[0], 0, "fully wet: no dry impulse")
        XCTAssertEqual(left[480], 1, accuracy: 0.05, "back after 10 ms")
        XCTAssertLessThan(left[479], 0.05)
        XCTAssertGreaterThan(left[960], 0.3)
        XCTAssertLessThan(left[960], left[480], "the second repeat is quieter")
        XCTAssertTrue(right.allSatisfy { $0 == 0 }, "a straight delay keeps its sides")
    }

    func testPingPongSendsTheRepeatsFromSideToSide() {
        let delay = StereoDelay(sampleRate: rate, settings: .init(time: 0.01, feedback: 0.8, mix: 1, damping: 20_000,
                                                                   pingPong: true))
        let (left, right) = run(delay, left: impulse(2_000), right: [Float](repeating: 0, count: 2_000))
        XCTAssertGreaterThan(left[480], 0.3)
        XCTAssertLessThan(abs(right[480]), 0.01)
        XCTAssertGreaterThan(right[960], 0.2, "the next repeat is on the other side")
        XCTAssertLessThan(abs(left[960]), 0.01)
    }

    func testDryPassesUntouchedAndTheTailDiesAwayAtFullFeedback() {
        let dry = StereoDelay(sampleRate: rate, settings: .init(mix: 0))
        let noise = (0..<4_800).map { Float(sin(Double($0) * 0.37)) }
        XCTAssertEqual(run(dry, left: noise, right: noise).0, noise)

        let loud = StereoDelay(sampleRate: rate, settings: .init(time: 0.05, feedback: 5, mix: 1))
        XCTAssertEqual(loud.settings.feedback, 0.95, "feedback is held short of 1")
        _ = run(loud, left: noise, right: noise)
        let silence = [Float](repeating: 0, count: 48_000 * 4)
        let (tail, _) = run(loud, left: silence, right: silence)
        XCTAssertTrue(tail.allSatisfy { $0.isFinite && abs($0) < 4 }, "bounded")
        XCTAssertLessThan(tail.suffix(4_800).map { abs($0) }.max() ?? 1, 0.05, "and dying away")
    }

    func testABadSampleResetsTheLineAndATimeChangeGlides() {
        let delay = StereoDelay(sampleRate: rate, settings: .init(time: 0.01, feedback: 0.9, mix: 1))
        var input = [Float](repeating: 0.5, count: 1_000)
        input[100] = .nan
        let (out, _) = run(delay, left: input, right: input)
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        delay.settings.time = .infinity
        XCTAssertEqual(delay.settings.time, 0.375, "non-finite takes the default")

        let loaded = StereoDelay(sampleRate: rate)
        loaded.settings = .init(time: 0.01, feedback: 0, mix: 1)
        var click = [Float](repeating: 0, count: 1_000)
        click[0] = 1
        XCTAssertEqual(run(loaded, left: click, right: click).0[480], 1, accuracy: 0.05,
                       "settings given before the first sample apply at once, without a sweep")

        let gliding = StereoDelay(sampleRate: rate, settings: .init(time: 0.1, feedback: 0, mix: 1))
        // One continuous tone, so any jump in the output is the read head's own.
        let tone = (0..<19_200).map { Float(sin(Double($0) * 0.05)) }
        let first = Array(tone[..<9_600]), second = Array(tone[9_600...])
        _ = run(gliding, left: first, right: first)
        gliding.settings.time = 0.2
        let (moved, _) = run(gliding, left: second, right: second)
        let jumps = zip(moved.dropFirst(), moved).map { abs($0 - $1) }.max() ?? 1
        XCTAssertLessThan(jumps, 0.1, "the read head bends instead of jumping")
    }
}
