import XCTest
@testable import EchoelCore

/// A `VibeMatrix` is nine cells per genre, each lookup returns a `VibeParameters` the generator
/// can run on without further input (wave W11.1b).
final class VibeMatrixTests: XCTestCase {

    func testEachGenreOffersNineCells() {
        for genre in VibeParameters.Genre.allCases {
            XCTAssertEqual(VibeMatrix(genre: genre).allCells.count, 9, "\(genre)")
        }
    }

    func testCellLookupLandsOnTheRequestedBands() {
        let matrix = VibeMatrix(genre: .hipHop)
        let cell = matrix.cell(energy: .high, density: .dense)
        XCTAssertEqual(cell.energy, .high)
        XCTAssertEqual(cell.density, .dense)
    }

    func testParametersInheritGenreHouseValues() {
        let p = VibeMatrix(genre: .edm).parameters(at: .mid, density: .medium)
        XCTAssertEqual(p.genre, .edm)
        XCTAssertEqual(p.targetBPM, 128)
        XCTAssertEqual(p.targetScale, .minor)
        XCTAssertGreaterThan(p.brightness, 0.6)
    }

    func testHigherBandsIncreaseEnergyAndDensity() {
        let matrix = VibeMatrix(genre: .chill)
        let calm = matrix.parameters(at: .low, density: .sparse)
        let busy = matrix.parameters(at: .high, density: .dense)
        XCTAssertLessThan(calm.energy, busy.energy)
        XCTAssertLessThan(calm.density, busy.density)
    }

    func testScoreDefaultsToDorian() {
        let p = VibeMatrix(genre: .score).parameters(at: .mid, density: .medium)
        XCTAssertEqual(p.targetScale, .dorian)
    }
}
