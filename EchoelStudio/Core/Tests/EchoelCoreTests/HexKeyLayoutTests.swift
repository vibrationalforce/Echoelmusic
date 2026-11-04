import EchoelCore
import XCTest

final class HexKeyLayoutTests: XCTestCase {
    func testTheBottomLeftCellPlaysTheLowestNote() {
        let board = HexKeyLayout(columns: 6, rows: 4, lowest: 48)
        let first = board.cells.first
        XCTAssertEqual(first?.column, 0)
        XCTAssertEqual(first?.row, 0)
        XCTAssertEqual(first?.pitch, 48)
        XCTAssertEqual(board.cells.count, 24)
    }

    func testTheThreeDirectionsAreThirdsAndAFifth() {
        XCTAssertEqual(HexKeyLayout.rightStep, 4, "a major third to the right")
        XCTAssertEqual(HexKeyLayout.upLeftStep, 3, "a minor third up and to the left")
        XCTAssertEqual(HexKeyLayout.upRightStep, 7, "a fifth up and to the right")
        // Row 0 → row 1 at the same column is up-right; row 1 → row 2 is up-left.
        XCTAssertEqual(HexKeyLayout.pitch(column: 0, row: 1, lowest: 60), 67)
        XCTAssertEqual(HexKeyLayout.pitch(column: 0, row: 2, lowest: 60), 70)
        XCTAssertEqual(HexKeyLayout.pitch(column: 2, row: 0, lowest: 60), 68)
    }

    /// Isomorphism, measured on the drawn geometry: every pair of touching cells (centres one
    /// cell width apart) differs by the interval of their direction, the same on every row.
    func testEveryNeighbourDiffersByTheIntervalOfItsDirection() {
        let board = HexKeyLayout(columns: 7, rows: 6, lowest: 36)
        let cells = board.cells
        var directions: [String: Int] = [:]
        var pairs = 0
        for a in cells {
            for b in cells where a != b {
                let dx = b.x - a.x
                let dy = b.y - a.y
                guard Swift.abs((dx * dx + dy * dy).squareRoot() - 1) < 1e-9 else { continue }
                pairs += 1
                let key = "\(Int((dx * 2).rounded())),\(Int((dy / HexKeyLayout.rowSpacing).rounded()))"
                let step = b.pitch - a.pitch
                if let known = directions[key] {
                    XCTAssertEqual(step, known, "direction \(key) from (\(a.column), \(a.row))")
                } else {
                    directions[key] = step
                }
            }
        }
        XCTAssertEqual(directions.count, 6, "six directions, each one interval")
        XCTAssertEqual(directions["2,0"], 4)
        XCTAssertEqual(directions["-1,1"], 3)
        XCTAssertEqual(directions["1,1"], 7)
        XCTAssertEqual(directions["-2,0"], -4)
        XCTAssertGreaterThan(pairs, 100)
    }

    func testAMajorTriadIsOneShapeEverywhere() {
        // Root, up-right minus up-left (the third to the right) and the fifth up-right.
        for lowest in [40, 47, 53] {
            for column in 0..<4 {
                let root = HexKeyLayout.pitch(column: column, row: 0, lowest: lowest)
                let third = HexKeyLayout.pitch(column: column + 1, row: 0, lowest: lowest)
                let fifth = HexKeyLayout.pitch(column: column, row: 1, lowest: lowest)
                XCTAssertEqual([third - root, fifth - root], [4, 7])
            }
        }
    }

    func testNoCellPlaysOutsideMIDI() {
        let board = HexKeyLayout(columns: 10, rows: 10, lowest: 96)
        XCTAssertFalse(board.cells.isEmpty)
        XCTAssertTrue(board.cells.allSatisfy { (0...127).contains($0.pitch) })
        XCTAssertTrue(board.cells.allSatisfy { (0...11).contains($0.pitchClass) })
    }

    func testTheBoardFitsItsSpace() {
        let fit = HexKeyLayout.fitting(width: 390, height: 180, minimumCell: 48)
        XCTAssertEqual(fit.columns, 7)
        let board = HexKeyLayout(columns: fit.columns, rows: fit.rows, lowest: 48)
        let cell = 390 / board.width
        XCTAssertGreaterThanOrEqual(cell, 48)
        XCTAssertLessThanOrEqual(board.height * cell, 180 + 1e-9)
        XCTAssertGreaterThanOrEqual(fit.rows, 3)
        let broken = HexKeyLayout.fitting(width: .nan, height: 100, minimumCell: 48)
        XCTAssertEqual([broken.columns, broken.rows], [1, 1])
        let tiny = HexKeyLayout.fitting(width: 10, height: 10, minimumCell: 48)
        XCTAssertEqual([tiny.columns, tiny.rows], [1, 1])
    }
}
