import XCTest
@testable import EchoelDSP

final class TremoloTests: XCTestCase {
    private let rate = 48_000.0

    private func run(_ effect: x, left: [Float], right: [Float]) -> ([Float], [Float]) {
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

    func testWithoutDepthTheSoundPassesThrough() {
        let tremolo = Tremolo(sampleRate: rate, settings: .init(depth: 0))
        let input = sine(220, amplitude: 0.8, count: 4_800)
        let (l, r) = run(tremolo, left: input, right: input)
        XCTAssertEqual(l, input)
        XCTAssertEqual(r, input)
    }

    /// Full depth on a steady level: the level swings between silence and full, once per cycle.
    func testFullDepthSwingsTheLevelAtTheRate() {
        let tremolo = Tremolo(sampleRate: rate, settings: .init(rate: 4, depth: 1))
        let input = [Float](repeating: 0.5, count: 48_000)
        let (l, _) = run(tremolo, left: input, right: input)
        XCTAssertEqual(l.max() ?? 0, 0.5, accuracy: 1e-3)
        XCTAssertEqual(l.min() ?? 1, 0, accuracy: 1e-3)
        // Four dips in a second: count the falls below a quarter.
        var dips = 0
        for index in 1..<l.count where l[index] < 0.125 && l[index - 1] >= 0.125 { dips += 1 }
        XCTAssertEqual(dips, 4)
    }

    /// With pan on, left and right move against each other; their sum stays nearly steady.
    func testPanMovesTheSidesAgainstEachOther() {
        let tremolo = Tremolo(sampleRate: rate, settings: .init(rate: 2, depth: 1, pan: true))
        let input = [Float](repeating: 0.5, count: 24_000)
        let (l, r) = run(tremolo, left: input, right: input)
        let sums = zip(l, r).map { $0 + $1 }
        XCTAssertEqual(sums.max() ?? 0, 0.5, accuracy: 1e-3)
        XCTAssertEqual(sums.min() ?? 0, 0.5, accuracy: 1e-3)
        XCTAssertGreaterThan(zip(l, r).map { Swift.abs($0 - $1) }.max() ?? 0, 0.4)
    }

    func testABadSampleIsSilenceAndSettingsAreClamped() {
        let tremolo = Tremolo(sampleRate: rate, settings: .init(rate: 100, depth: .nan))
        XCTAssertEqual(tremolo.settings, .init(rate: 20, depth: 0.5))
        var input = [Float](repeating: 0.5, count: 2_000)
        input[10] = .nan
        let (l, r) = run(tremolo, left: input, right: input)
        XCTAssertEqual(l[10], 0)
        XCTAssertTrue(l.allSatisfy(\.isFinite) && r.allSatisfy(\.isFinite))
    }
}
