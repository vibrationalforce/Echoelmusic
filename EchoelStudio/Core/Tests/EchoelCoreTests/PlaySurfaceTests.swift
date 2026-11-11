import XCTest
@testable import EchoelCore

/// Which surface the screen offers for an instrument, and how its pads are laid out.
final class PlaySurfaceTests: XCTestCase {
    func testAKitGetsItsPadsAndAMelodicInstrumentKeys() {
        XCTAssertEqual(PlaySurface.surface(for: InstrumentSettings(device: .drums)), .drumPads)
        XCTAssertEqual(PlaySurface.surface(for: InstrumentSettings(device: .synth)), .keys)
        XCTAssertEqual(PlaySurface.surface(for: InstrumentSettings(device: .plugin)), .keys)
        XCTAssertEqual(PlaySurface.surface(for: InstrumentSettings(device: .sampler)), .keys,
                       "one sample across the keys is melodic")
    }

    func testASlicedSampleGetsAPadForEverySlice() {
        var sampler = InstrumentSettings(device: .sampler)
        sampler.slices = [SampleSlice(start: 0), SampleSlice(start: 12_000), SampleSlice(start: 30_000)]
        XCTAssertEqual(PlaySurface.surface(for: sampler), .slicePads(count: 3))
        sampler.slices = (0..<40).map { (index: Int) -> SampleSlice in SampleSlice(start: index * 100) }
        XCTAssertEqual(PlaySurface.surface(for: sampler), .slicePads(count: SampleSlice.maximumCount),
                       "never more pads than a sample can be cut into")
        sampler.slices = nil
        XCTAssertEqual(PlaySurface.surface(for: sampler), .keys)
    }

    /// Slices left in the settings of a track that plays another device mean nothing.
    func testSlicesOnAnotherDeviceChangeNothing() {
        var synth = InstrumentSettings(device: .synth)
        synth.slices = [SampleSlice(start: 0)]
        XCTAssertEqual(PlaySurface.surface(for: synth), .keys)
        var kit = InstrumentSettings(device: .drums)
        kit.slices = [SampleSlice(start: 0)]
        XCTAssertEqual(PlaySurface.surface(for: kit), .drumPads)
    }

    func testPadsRiseFromTheBottomLeft() {
        let sixteen: [[Int]] = [[12, 13, 14, 15], [8, 9, 10, 11], [4, 5, 6, 7], [0, 1, 2, 3]]
        XCTAssertEqual(PlaySurface.padRows(count: 16, columns: 4), sixteen)
        let wide: [[Int]] = [[8, 9, 10, 11, 12, 13, 14, 15], [0, 1, 2, 3, 4, 5, 6, 7]]
        XCTAssertEqual(PlaySurface.padRows(count: 16, columns: 8), wide)
        let six: [[Int]] = [[4, 5], [0, 1, 2, 3]]
        XCTAssertEqual(PlaySurface.padRows(count: 6, columns: 4), six, "only the top row is short")
        let three: [[Int]] = [[0, 1, 2]]
        XCTAssertEqual(PlaySurface.padRows(count: 3, columns: 8), three)
    }

    func testNoPadsAreNoRowsAndNoColumnsCountAsOne() {
        XCTAssertTrue(PlaySurface.padRows(count: 0, columns: 4).isEmpty)
        XCTAssertTrue(PlaySurface.padRows(count: -2, columns: 4).isEmpty)
        let stacked: [[Int]] = [[2], [1], [0]]
        XCTAssertEqual(PlaySurface.padRows(count: 3, columns: 0), stacked)
        XCTAssertEqual(PlaySurface.padRows(count: 3, columns: -5), stacked)
    }

    func testEveryPadIsShownExactlyOnce() {
        for count in 1...SampleSlice.maximumCount {
            for columns in 1...8 {
                let rows = PlaySurface.padRows(count: count, columns: columns)
                var shown: [Int] = []
                for row in rows.reversed() { shown.append(contentsOf: row) }
                XCTAssertEqual(shown, Array(0..<count), "\(count) pads in rows of \(columns)")
                let longest = rows.map(\.count).max() ?? 0
                XCTAssertLessThanOrEqual(longest, columns)
                for row in rows.dropFirst() { XCTAssertEqual(row.count, columns, "a row under the top one is full") }
            }
        }
    }
}
