import Foundation
import XCTest
@testable import EchoelDSP

/// W-3: the Beats stretch and the Re-Pitch read, below the engine.
final class WarpModeStretchTests: XCTestCase {
    private func ramp(_ count: Int) -> [Float] {
        (0..<count).map { (index: Int) -> Float in Float(sin(Double(index) * 0.01)) }
    }

    func testAReadAtWholeFramesIsTheInputAndOutsideItIsSilence() {
        let input = ramp(1_000)
        let out = WSOLAStretcher.resample([input], outputCount: 1_200) { (frame: Int) -> Double in Double(frame) }
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(Array(out[0][0..<1_000]), input)
        XCTAssertTrue(out[0][1_000...].allSatisfy { $0 == 0 }, "past the last frame is silence")
        XCTAssertEqual(WSOLAStretcher.resample([], outputCount: 10) { (frame: Int) -> Double in Double(frame) }.count, 0)
        let nan = WSOLAStretcher.resample([input], outputCount: 10) { (_: Int) -> Double in .nan }
        XCTAssertEqual(nan[0], [Float](repeating: 0, count: 10))
    }

    func testBeatsWithoutUsableAnchorsIsTheOneStretch() {
        let input = ramp(20_000)
        let stretcher = WSOLAStretcher()
        let map = { (frame: Int) -> Double in Double(frame) * 0.75 }
        let plain = stretcher.stretch([input], outputCount: 26_000, position: map)
        // An anchor at the very start or end cannot be spliced, and none is no piece.
        XCTAssertEqual(stretcher.stretch([input], outputCount: 26_000, anchors: [], splice: 96, position: map), plain)
        XCTAssertEqual(stretcher.stretch([input], outputCount: 26_000, anchors: [10, 19_990], splice: 96, position: map), plain)
    }

    func testBeatsPlaysEachAttackOnceWhereTheMappingPutsIt() {
        var input = [Float](repeating: 0, count: 40_000)
        let hits = [0, 10_000, 20_000, 30_000]
        for hit in hits { input[hit] = 1 }
        let stretcher = WSOLAStretcher()
        // Stretched to half speed: each hit belongs at twice its frame.
        let out = stretcher.stretch([input], outputCount: 80_000, anchors: Array(hits.dropFirst()), splice: 96) { (frame: Int) -> Double in
            Double(frame) / 2
        }
        let peaks = out[0].indices.filter { abs(out[0][$0]) > 0.5 }
        XCTAssertEqual(peaks, hits.map { $0 * 2 })
    }

    func testACancelledStretchStopsPartWayAndMakesNothing() {
        let input = ramp(48_000)
        var hits = [Float](repeating: 0, count: 48_000)
        for hit in [12_000, 24_000, 36_000] { hits[hit] = 1 }
        let stretcher = WSOLAStretcher()
        let map = { (frame: Int) -> Double in Double(frame) * 0.75 }
        // Never cancelled, it is the stretch it always was.
        XCTAssertEqual(stretcher.stretch([input], outputCount: 64_000, isCancelled: { false }, position: map),
                       stretcher.stretch([input], outputCount: 64_000, position: map))
        XCTAssertEqual(stretcher.stretch([hits], outputCount: 64_000, anchors: [12_000, 24_000, 36_000], splice: 96,
                                         isCancelled: { false }, position: map),
                       stretcher.stretch([hits], outputCount: 64_000, anchors: [12_000, 24_000, 36_000], splice: 96, position: map))
        // It is asked while it works, once per hop, not only before it starts: a stop on the
        // fifth ask is nil, and an uncancelled run asks far more often than that.
        var asks = 0
        let whole = stretcher.stretch([input], outputCount: 64_000, isCancelled: { asks += 1; return false }, position: map)
        XCTAssertNotNil(whole)
        XCTAssertGreaterThan(asks, 100, "a 64,000-frame stretch has 124 hops")
        asks = 0
        let stopped = stretcher.stretch([input], outputCount: 64_000, isCancelled: { asks += 1; return asks >= 5 }, position: map)
        XCTAssertNil(stopped)
        XCTAssertEqual(asks, 5, "nothing is asked, or made, after the stop")
        asks = 0
        let stoppedBeats = stretcher.stretch([hits], outputCount: 64_000, anchors: [12_000, 24_000, 36_000], splice: 96,
                                             isCancelled: { asks += 1; return asks >= 5 }, position: map)
        XCTAssertNil(stoppedBeats)
        XCTAssertEqual(asks, 5)
    }
}
