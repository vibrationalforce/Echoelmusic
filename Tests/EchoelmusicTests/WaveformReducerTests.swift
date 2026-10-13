// WaveformReducerTests.swift — locks the Stage-2 waveform reduction (pure, Linux CI).

import XCTest
@testable import Echoelmusic

final class WaveformReducerTests: XCTestCase {

    func testReduce_knownSignal_minMaxRms() {
        // Two buckets of 4: [-1,1,0,0] and [0.5,-0.5,0.5,-0.5].
        let s: [Float] = [-1, 1, 0, 0, 0.5, -0.5, 0.5, -0.5]
        let b = WaveformReducer.reduce(s, bucketSize: 4)
        XCTAssertEqual(b.count, 2)
        XCTAssertEqual(b[0].min, -1); XCTAssertEqual(b[0].max, 1)
        XCTAssertEqual(b[0].rms, (0.5 as Float).squareRoot(), accuracy: 1e-6)
        XCTAssertEqual(b[1].min, -0.5); XCTAssertEqual(b[1].max, 0.5)
        XCTAssertEqual(b[1].rms, 0.5, accuracy: 1e-6)
    }

    func testReduce_partialLastBucket_andEmpty_andClamp() {
        let b = WaveformReducer.reduce([0.2, -0.4, 0.6], bucketSize: 2)
        XCTAssertEqual(b.count, 2)                       // 2 + 1 partial
        XCTAssertEqual(b[1].min, 0.6); XCTAssertEqual(b[1].max, 0.6)
        XCTAssertTrue(WaveformReducer.reduce([], bucketSize: 256).isEmpty)
        XCTAssertEqual(WaveformReducer.reduce([1, -1], bucketSize: 0).count, 2) // size clamps to 1
    }

    func testFoldStereo_keepsLargerMagnitudeSigned() {
        let out = WaveformReducer.foldStereo(left: [0.9, -0.1, -0.7],
                                             right: [-0.2, 0.8, 0.7])
        XCTAssertEqual(out, [0.9, 0.8, -0.7])            // sign preserved, extremes win
    }

    func testDownsample_preservesExtremes() {
        let fine = WaveformReducer.reduce([-1, 0, 0, 0, 0, 0, 0, 1], bucketSize: 2) // 4 buckets
        let coarse = WaveformReducer.downsample(fine, factor: 4)
        XCTAssertEqual(coarse.count, 1)
        XCTAssertEqual(coarse[0].min, -1)                 // extremes never vanish
        XCTAssertEqual(coarse[0].max, 1)
    }

    /// `join` is the one-bucket case of `downsample`. The canvas calls `join` on a
    /// slice so a pinch does not copy it; this locks the two to the same bucket.
    func testJoin_matchesDownsampleOfTheWholeSpan() {
        let fine = WaveformReducer.reduce([-1, 0.2, 0.5, -0.4, 0, 1, -0.2, 0.3], bucketSize: 2)
        XCTAssertNil(WaveformReducer.join([] as [WaveformBucket]))
        XCTAssertEqual(WaveformReducer.join(fine),
                       WaveformReducer.downsample(fine, factor: fine.count).first)
        let slice = fine[1..<3]
        XCTAssertEqual(WaveformReducer.join(slice),
                       WaveformReducer.downsample(Array(slice), factor: slice.count).first,
                       "a column's slice joins to the same bucket downsample used to return")
        // A partial last group (factor that does not divide) stays the old algebra.
        let coarse = WaveformReducer.downsample(fine, factor: 3)
        XCTAssertEqual(coarse.count, 2)
        XCTAssertEqual(coarse[0], WaveformReducer.join(fine[0..<3]))
        XCTAssertEqual(coarse[1], WaveformReducer.join(fine[3..<4]))
    }
}
