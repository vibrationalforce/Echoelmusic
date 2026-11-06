import XCTest
@testable import EchoelCore

/// The Weave's rows: rule 90 on an odd ring, any generation computed directly — checked here
/// against stepping there one generation at a time, not against the jump itself.
final class BarWeaveTests: XCTestCase {
    func testAnyGenerationIsTheSameAsSteppingThere() {
        let masks: [UInt16] = [BarWeave.keyMask(MusicalContext(root: 0, scale: .major)), 0x0FFF, 0b1, 0b1000_1001_0001, 0]
        for mask in masks {
            let seed = BarWeave.seed(keyMask: mask)
            var stepped = seed
            for generation in 0...2_000 {
                guard BarWeave.row(Int64(generation), seed: seed) == stepped else {
                    XCTFail("mask \(mask): generation \(generation) differs from stepping there")
                    break
                }
                stepped = BarWeave.step(stepped)
            }
        }
        XCTAssertEqual(BarWeave.row(-1, seed: 1), 0, "before the first bar there is no row")
    }

    func testRule90LightsACellWhenExactlyOneNeighbourWas() {
        let middle: UInt64 = 1 << 30
        XCTAssertEqual(BarWeave.step(middle), (1 << 29) | (1 << 31))
        XCTAssertEqual(BarWeave.step(BarWeave.step(middle)), (1 << 28) | (1 << 32), "lit by both neighbours: dark")
        XCTAssertEqual(BarWeave.step(1), (1 << 1) | (1 << 60), "the ring wraps: cell 0 sits next to cell 60")
        XCTAssertEqual(BarWeave.step(1 << 60), 1 | (1 << 59))
    }

    /// Every key mask, generations up to a million: no weave that has started dies out.
    func testAStartedWeaveNeverDiesOut() {
        var dead: [String] = []
        for mask in 0..<4_096 {
            let seed = BarWeave.seed(keyMask: UInt16(mask))
            for generation in stride(from: Int64(0), through: 1_000_000, by: 9_973)
            where BarWeave.row(generation, seed: seed) == 0 {
                dead.append("mask \(mask) at \(generation)")
            }
        }
        XCTAssertEqual(dead, [])
    }

    func testTheKeyIsTheFirstRow() {
        let major = BarWeave.seed(keyMask: BarWeave.keyMask(MusicalContext(root: 0, scale: .major)))
        let lit = (0..<BarWeave.width).filter { BarWeave.isLit(major, cell: $0) }
        XCTAssertEqual(lit, [24, 26, 28, 29, 31, 33, 35], "C major: C D E F G A B, C leftmost")
        let dorian = BarWeave.keyMask(MusicalContext(root: 2, scale: .dorian))
        XCTAssertEqual(dorian, BarWeave.keyMask(MusicalContext(root: 0, scale: .major)), "D Dorian holds C major's notes")
        XCTAssertNotEqual(BarWeave.keyMask(MusicalContext(root: 0, scale: .minor)), dorian)
        XCTAssertEqual(BarWeave.keyMask(MusicalContext()), 0x0FFF, "chromatic: all twelve")
        XCTAssertEqual(BarWeave.seed(keyMask: 0), 1 << 30, "no pitch class: one cell in the middle")
        XCTAssertFalse(BarWeave.isLit(major, cell: -1))
        XCTAssertFalse(BarWeave.isLit(major, cell: BarWeave.width))
    }

    /// The shader's words: the scroll's bits, then each row newest first as low and high half.
    func testTheWordsHoldTheScrollAndTheRowsNewestFirst() {
        let seed = BarWeave.seed(keyMask: BarWeave.keyMask(MusicalContext(root: 0, scale: .major)))
        let words = BarWeave.words(position: 5.25, seed: seed, light: 0.5)
        XCTAssertEqual(words.count, 4 + 2 * BarWeave.history)
        XCTAssertEqual(Float(bitPattern: words[0]), 0.25)
        XCTAssertEqual(Float(bitPattern: words[1]), 0.5)
        XCTAssertEqual(Float(bitPattern: BarWeave.words(position: 1, seed: seed, light: .nan)[1]), 0)
        for index in 0..<BarWeave.history {
            let row = BarWeave.row(5 - Int64(index), seed: seed)
            XCTAssertEqual(words[4 + 2 * index], UInt32(truncatingIfNeeded: row))
            XCTAssertEqual(words[5 + 2 * index], UInt32(truncatingIfNeeded: row >> 32))
        }
        XCTAssertEqual(BarWeave.words(position: .nan, seed: seed, light: 1), BarWeave.words(position: 0, seed: seed, light: 1))
        XCTAssertEqual(BarWeave.words(position: -3, seed: seed, light: 1), BarWeave.words(position: 0, seed: seed, light: 1))
    }

    /// The light: a lit cell's centre shines, an unlit one is dark, the row coming in is as bright
    /// as it has come, and nothing shows above the history.
    func testTheLightShowsLitCellsAndTheRowComingIn() {
        let seed = BarWeave.seed(keyMask: BarWeave.keyMask(MusicalContext(root: 0, scale: .major)))
        let width = Double(BarWeave.width)
        func at(cell: Int, rowsUp: Double, position: Double) -> Double {
            BarWeave.light(u: (Double(cell) + 0.5) / width, v: rowsUp / width, aspect: 1, position: position,
                           seed: seed, level: 1, strength: 1)
        }
        // At 1 the key's row stands whole at the bottom: rows up 0 … 1.
        XCTAssertEqual(at(cell: 24, rowsUp: 0.5, position: 1), 1, accuracy: 1e-9)
        XCTAssertEqual(at(cell: 25, rowsUp: 0.5, position: 1), 0, "D♭ is not in C major")
        // Half a bar on, the next row is half in and half lit; the key's row has moved up half a row.
        XCTAssertEqual(at(cell: 24, rowsUp: 1.0, position: 1.5), 1, accuracy: 1e-9)
        let comingIn = BarWeave.row(1, seed: seed)
        let cell = (0..<BarWeave.width).first { BarWeave.isLit(comingIn, cell: $0) } ?? 0
        XCTAssertEqual(at(cell: cell, rowsUp: 0.25, position: 1.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(at(cell: 24, rowsUp: Double(BarWeave.history) + 1, position: 100), 0)
        XCTAssertEqual(BarWeave.light(u: .nan, v: .infinity, aspect: .nan, position: .nan, seed: seed, level: .nan,
                                      strength: 1), 0)
        XCTAssertEqual(BarWeave.light(u: 24.5 / width, v: 0.5 / width, aspect: 1, position: 1, seed: seed, level: 1,
                                      strength: 0), 0, "dark while the weave fades through")
    }
}
