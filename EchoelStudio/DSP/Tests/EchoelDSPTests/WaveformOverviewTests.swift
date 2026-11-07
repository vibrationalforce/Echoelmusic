import XCTest
@testable import EchoelDSP

/// The picture inside an audio region: each column's lowest and highest sample and its RMS, exact
/// for signals whose answer is known, cut to the stretch a region plays, and never anything for
/// nothing to draw.
final class WaveformOverviewTests: XCTestCase {
    private func assertColumn(_ column: WaveformOverview.Column?, min: Float, max: Float, rms: Float,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard let column else { return XCTFail("no column", file: file, line: line) }
        XCTAssertEqual(column.min, min, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(column.max, max, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(column.rms, rms, accuracy: 1e-6, file: file, line: line)
    }

    /// One full-scale sample in four: the peak is the impulse, the RMS the root of a quarter.
    func testAnImpulseHasItsPeakAndTheRootOfItsShare() {
        let overview = WaveformOverview(samples: [1, 0, 0, 0, 0, 0, 0, 0], framesPerColumn: 4)
        XCTAssertEqual(overview.columns.count, 2)
        XCTAssertEqual(overview.frameCount, 8)
        assertColumn(overview.columns.first, min: 0, max: 1, rms: 0.5)
        assertColumn(overview.columns.last, min: 0, max: 0, rms: 0)
    }

    /// A full-scale square reaches both rails and has an RMS of one, column by column and folded.
    func testASquareReachesBothRailsAtAnRMSOfOne() {
        let square: [Float] = [1, 1, -1, -1, 1, 1, -1, -1]
        let overview = WaveformOverview(samples: square, framesPerColumn: 2)
        XCTAssertEqual(overview.columns.count, 4)
        assertColumn(overview.columns.first, min: 1, max: 1, rms: 1)
        assertColumn(overview.columns.dropFirst().first, min: -1, max: -1, rms: 1)
        let folded = overview.window(offset: 0, length: 8, columns: 2)
        XCTAssertEqual(folded.count, 2)
        assertColumn(folded.first, min: -1, max: 1, rms: 1)
        assertColumn(folded.last, min: -1, max: 1, rms: 1)
    }

    /// Silence is a flat line: zero everywhere, not an empty picture.
    func testSilenceIsZeroEverywhere() {
        let overview = WaveformOverview(samples: [Float](repeating: 0, count: 100), framesPerColumn: 10)
        XCTAssertFalse(overview.isEmpty)
        let window = overview.window(offset: 0, length: 100, columns: 5)
        XCTAssertEqual(window.count, 5)
        for column in window { assertColumn(column, min: 0, max: 0, rms: 0) }
    }

    /// A region's window picks the columns of the frames it plays, not the file's start.
    func testARegionWindowSelectsItsOwnColumns() {
        let samples: [Float] = [0.1, 0.1, 0.2, 0.2, 0.3, 0.3, 0.4, 0.4]
        let overview = WaveformOverview(samples: samples, framesPerColumn: 2)
        let window = overview.window(offset: 4, length: 4, columns: 2)
        XCTAssertEqual(window.count, 2)
        assertColumn(window.first, min: 0.3, max: 0.3, rms: 0.3)
        assertColumn(window.last, min: 0.4, max: 0.4, rms: 0.4)
        // Past the file's end it is cut at the end; wholly past it, nothing.
        XCTAssertEqual(overview.window(offset: 6, length: 100, columns: 1).count, 1)
        XCTAssertTrue(overview.window(offset: 8, length: 4, columns: 3).isEmpty)
    }

    /// Nothing to draw draws nothing: no columns asked for, no frames, an empty file.
    func testNothingToDrawIsEmpty() {
        let overview = WaveformOverview(samples: [0.5, -0.5], framesPerColumn: 1)
        XCTAssertTrue(overview.window(offset: 0, length: 2, columns: 0).isEmpty)
        XCTAssertTrue(overview.window(offset: 0, length: 0, columns: 4).isEmpty)
        let empty = WaveformOverview(samples: [], framesPerColumn: 64)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty, .empty)
        XCTAssertTrue(empty.window(offset: 0, length: 10, columns: 4).isEmpty)
    }

    /// A sample that is not a number counts as silence, so it never draws off the block.
    func testANonFiniteSampleCountsAsSilence() {
        let overview = WaveformOverview(samples: [.nan, .infinity, -.infinity, 0.5], framesPerColumn: 4)
        assertColumn(overview.columns.first, min: 0, max: 0.5, rms: 0.25)
    }

    /// A file read in chunks that end anywhere gives the picture of the file read at once.
    func testChunksThatEndAnywhereGiveTheSamePicture() {
        let samples: [Float] = (0..<37).map { (index: Int) -> Float in Float(index % 7) / 7 - 0.4 }
        let whole = WaveformOverview(samples: samples, framesPerColumn: 5)
        var builder = WaveformOverview.Builder(framesPerColumn: 5)
        samples.withUnsafeBufferPointer { all in
            var start = 0
            for size in [3, 11, 1, 22] {
                let stop = Swift.min(all.count, start + size)
                builder.append(UnsafeBufferPointer(rebasing: all[start..<stop]))
                start = stop
            }
        }
        XCTAssertEqual(builder.finished(), whole)
        XCTAssertEqual(whole.columns.count, 8)
    }
}
