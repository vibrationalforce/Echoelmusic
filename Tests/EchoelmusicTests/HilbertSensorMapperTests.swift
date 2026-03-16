#if canImport(Metal)
//
//  HilbertSensorMapperTests.swift
//  Echoelmusic
//
//  Tests for HilbertSensorMapper: map(index:order:), mapToGrid(values:gridSize:),
//  locality preservation, and bijection properties.
//

import XCTest
@testable import Echoelmusic

// MARK: - HilbertSensorMapper map() Tests

final class HilbertSensorMapperMapTests: XCTestCase {

    // MARK: - Order 0

    func testMap_orderZero_returnsZeroZero() {
        let result = HilbertSensorMapper.map(index: 0, order: 0)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 0)
    }

    func testMap_orderZero_anyIndex_returnsZeroZero() {
        let result = HilbertSensorMapper.map(index: 5, order: 0)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 0)
    }

    // MARK: - Order 2 (4 cells)

    func testMap_order2_index0() {
        let result = HilbertSensorMapper.map(index: 0, order: 2)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 0)
    }

    func testMap_order2_index1() {
        let result = HilbertSensorMapper.map(index: 1, order: 2)
        XCTAssertEqual(result.x, 1)
        XCTAssertEqual(result.y, 0)
    }

    func testMap_order2_index2() {
        let result = HilbertSensorMapper.map(index: 2, order: 2)
        XCTAssertEqual(result.x, 1)
        XCTAssertEqual(result.y, 1)
    }

    func testMap_order2_index3() {
        let result = HilbertSensorMapper.map(index: 3, order: 2)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 1)
    }

    // MARK: - Order 4 (16 cells) — Unique Coordinates

    func testMap_order4_allIndicesMapToUniqueCoordinates() {
        var seen = Set<String>()
        for i in 0..<16 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 4)
            let key = "\(x),\(y)"
            XCTAssertFalse(seen.contains(key), "Duplicate coordinate (\(x),\(y)) at index \(i)")
            seen.insert(key)
        }
        XCTAssertEqual(seen.count, 16)
    }

    func testMap_order4_allCoordinatesWithinBounds() {
        for i in 0..<16 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 4)
            XCTAssertGreaterThanOrEqual(x, 0, "x out of bounds at index \(i)")
            XCTAssertLessThan(x, 4, "x out of bounds at index \(i)")
            XCTAssertGreaterThanOrEqual(y, 0, "y out of bounds at index \(i)")
            XCTAssertLessThan(y, 4, "y out of bounds at index \(i)")
        }
    }

    func testMap_order4_index0_isOrigin() {
        let result = HilbertSensorMapper.map(index: 0, order: 4)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 0)
    }

    func testMap_order4_index15_isValid() {
        let result = HilbertSensorMapper.map(index: 15, order: 4)
        XCTAssertGreaterThanOrEqual(result.x, 0)
        XCTAssertLessThan(result.x, 4)
        XCTAssertGreaterThanOrEqual(result.y, 0)
        XCTAssertLessThan(result.y, 4)
    }

    // MARK: - Clamping / Boundary Behavior

    func testMap_negativeIndex_clampedToZero() {
        let resultNeg = HilbertSensorMapper.map(index: -5, order: 2)
        let resultZero = HilbertSensorMapper.map(index: 0, order: 2)
        XCTAssertEqual(resultNeg.x, resultZero.x)
        XCTAssertEqual(resultNeg.y, resultZero.y)
    }

    func testMap_negativeIndex_large_clampedToZero() {
        let resultNeg = HilbertSensorMapper.map(index: -100, order: 4)
        let resultZero = HilbertSensorMapper.map(index: 0, order: 4)
        XCTAssertEqual(resultNeg.x, resultZero.x)
        XCTAssertEqual(resultNeg.y, resultZero.y)
    }

    func testMap_indexEqualToN_clampedToNMinus1() {
        // order=2, n=4, so index 4 should clamp to index 3
        let resultOver = HilbertSensorMapper.map(index: 4, order: 2)
        let resultLast = HilbertSensorMapper.map(index: 3, order: 2)
        XCTAssertEqual(resultOver.x, resultLast.x)
        XCTAssertEqual(resultOver.y, resultLast.y)
    }

    func testMap_indexGreaterThanN_clampedToNMinus1() {
        let resultOver = HilbertSensorMapper.map(index: 100, order: 2)
        let resultLast = HilbertSensorMapper.map(index: 3, order: 2)
        XCTAssertEqual(resultOver.x, resultLast.x)
        XCTAssertEqual(resultOver.y, resultLast.y)
    }

    func testMap_indexGreaterThanN_order4_clampedToLast() {
        let resultOver = HilbertSensorMapper.map(index: 50, order: 4)
        let resultLast = HilbertSensorMapper.map(index: 15, order: 4)
        XCTAssertEqual(resultOver.x, resultLast.x)
        XCTAssertEqual(resultOver.y, resultLast.y)
    }

    // MARK: - Coordinates Within Bounds

    func testMap_order2_allCoordinatesWithinBounds() {
        for i in 0..<4 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 2)
            XCTAssertGreaterThanOrEqual(x, 0)
            XCTAssertLessThan(x, 2)
            XCTAssertGreaterThanOrEqual(y, 0)
            XCTAssertLessThan(y, 2)
        }
    }

    func testMap_order1_index0() {
        // order=1, n=1, only one cell
        let result = HilbertSensorMapper.map(index: 0, order: 1)
        XCTAssertEqual(result.x, 0)
        XCTAssertEqual(result.y, 0)
    }

    // MARK: - Larger Orders

    func testMap_order8_allCoordinatesWithinBounds() {
        for i in 0..<64 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 8)
            XCTAssertGreaterThanOrEqual(x, 0, "x out of bounds at index \(i)")
            XCTAssertLessThan(x, 8, "x out of bounds at index \(i)")
            XCTAssertGreaterThanOrEqual(y, 0, "y out of bounds at index \(i)")
            XCTAssertLessThan(y, 8, "y out of bounds at index \(i)")
        }
    }

    func testMap_order8_allIndicesMapToUniqueCoordinates() {
        var seen = Set<String>()
        for i in 0..<64 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 8)
            let key = "\(x),\(y)"
            XCTAssertFalse(seen.contains(key), "Duplicate coordinate at index \(i)")
            seen.insert(key)
        }
        XCTAssertEqual(seen.count, 64)
    }
}

// MARK: - HilbertSensorMapper mapToGrid() Tests

final class HilbertSensorMapperGridTests: XCTestCase {

    // MARK: - Empty Values

    func testMapToGrid_emptyValues_returnsAllZeroGrid() {
        let grid = HilbertSensorMapper.mapToGrid(values: [], gridSize: 2)
        XCTAssertEqual(grid.count, 2)
        XCTAssertEqual(grid[0].count, 2)
        for row in grid {
            for cell in row {
                XCTAssertEqual(cell, 0.0)
            }
        }
    }

    func testMapToGrid_emptyValues_gridSize4_returnsAllZero() {
        let grid = HilbertSensorMapper.mapToGrid(values: [], gridSize: 4)
        XCTAssertEqual(grid.count, 4)
        for row in grid {
            XCTAssertEqual(row.count, 4)
            for cell in row {
                XCTAssertEqual(cell, 0.0)
            }
        }
    }

    // MARK: - Exact Fit

    func testMapToGrid_gridSize2_fourValues_allPlaced() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 2)

        // Verify all four values appear in the grid
        var flatGrid: [Float] = []
        for row in grid {
            flatGrid.append(contentsOf: row)
        }
        let sortedGrid = flatGrid.sorted()
        XCTAssertEqual(sortedGrid, [1.0, 2.0, 3.0, 4.0])
    }

    func testMapToGrid_gridSize2_verifyHilbertPlacement() {
        // index 0 -> (0,0), index 1 -> (1,0), index 2 -> (1,1), index 3 -> (0,1)
        let values: [Float] = [10.0, 20.0, 30.0, 40.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 2)

        // grid[y][x]
        XCTAssertEqual(grid[0][0], 10.0, accuracy: 0.001) // index 0 -> (0,0)
        XCTAssertEqual(grid[0][1], 20.0, accuracy: 0.001) // index 1 -> (1,0)
        XCTAssertEqual(grid[1][1], 30.0, accuracy: 0.001) // index 2 -> (1,1)
        XCTAssertEqual(grid[1][0], 40.0, accuracy: 0.001) // index 3 -> (0,1)
    }

    // MARK: - More Values Than Cells

    func testMapToGrid_moreValuesThanCells_extraIgnored() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 2)

        // Only 4 cells in 2x2 grid, so values 5-8 should be ignored
        var flatGrid: [Float] = []
        for row in grid {
            flatGrid.append(contentsOf: row)
        }
        let sortedGrid = flatGrid.sorted()
        XCTAssertEqual(sortedGrid, [1.0, 2.0, 3.0, 4.0])
    }

    func testMapToGrid_moreValuesThanCells_gridSizeCorrect() {
        let values: [Float] = Array(repeating: 1.0, count: 100)
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 2)
        XCTAssertEqual(grid.count, 2)
        XCTAssertEqual(grid[0].count, 2)
    }

    // MARK: - Fewer Values Than Cells

    func testMapToGrid_fewerValuesThanCells_remainingZero() {
        let values: [Float] = [5.0, 10.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 4)

        // 2 values in a 4x4 (16 cell) grid; 14 cells should be 0
        var nonZeroCount = 0
        var zeroCount = 0
        for row in grid {
            for cell in row {
                if cell != 0.0 {
                    nonZeroCount += 1
                } else {
                    zeroCount += 1
                }
            }
        }
        XCTAssertEqual(nonZeroCount, 2)
        XCTAssertEqual(zeroCount, 14)
    }

    func testMapToGrid_singleValue_onlyOneCell_nonZero() {
        let values: [Float] = [42.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 4)

        // index 0 -> (0,0), so grid[0][0] should be 42.0
        XCTAssertEqual(grid[0][0], 42.0, accuracy: 0.001)

        // All other cells should be 0
        var nonZeroCount = 0
        for row in grid {
            for cell in row {
                if cell != 0.0 { nonZeroCount += 1 }
            }
        }
        XCTAssertEqual(nonZeroCount, 1)
    }

    // MARK: - Grid Dimensions

    func testMapToGrid_gridSize1_singleCell() {
        let values: [Float] = [99.0]
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 1)
        XCTAssertEqual(grid.count, 1)
        XCTAssertEqual(grid[0].count, 1)
        XCTAssertEqual(grid[0][0], 99.0, accuracy: 0.001)
    }

    func testMapToGrid_gridSize4_dimensions() {
        let values: [Float] = Array(1...16).map { Float($0) }
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 4)
        XCTAssertEqual(grid.count, 4)
        for row in grid {
            XCTAssertEqual(row.count, 4)
        }
    }

    func testMapToGrid_gridSize4_allValuesPlaced() {
        let values: [Float] = Array(1...16).map { Float($0) }
        let grid = HilbertSensorMapper.mapToGrid(values: values, gridSize: 4)
        var flatGrid: [Float] = []
        for row in grid {
            flatGrid.append(contentsOf: row)
        }
        let sortedGrid = flatGrid.sorted()
        let expected = Array(1...16).map { Float($0) }
        XCTAssertEqual(sortedGrid, expected)
    }
}

// MARK: - Locality Preservation Tests

final class HilbertSensorMapperLocalityTests: XCTestCase {

    /// For a proper Hilbert curve, adjacent indices should map to adjacent cells
    /// (Manhattan distance of exactly 1).
    func testLocality_order4_adjacentIndicesHaveManhattanDistanceOne() {
        for i in 0..<15 {
            let (x1, y1) = HilbertSensorMapper.map(index: i, order: 4)
            let (x2, y2) = HilbertSensorMapper.map(index: i + 1, order: 4)
            let manhattan = abs(x2 - x1) + abs(y2 - y1)
            XCTAssertEqual(manhattan, 1,
                "Adjacent indices \(i) and \(i+1) have Manhattan distance \(manhattan), expected 1. " +
                "(\(x1),\(y1)) -> (\(x2),\(y2))")
        }
    }

    func testLocality_order2_adjacentIndicesHaveManhattanDistanceOne() {
        for i in 0..<3 {
            let (x1, y1) = HilbertSensorMapper.map(index: i, order: 2)
            let (x2, y2) = HilbertSensorMapper.map(index: i + 1, order: 2)
            let manhattan = abs(x2 - x1) + abs(y2 - y1)
            XCTAssertEqual(manhattan, 1,
                "Adjacent indices \(i) and \(i+1) have Manhattan distance \(manhattan), expected 1")
        }
    }

    func testLocality_order8_adjacentIndicesHaveManhattanDistanceOne() {
        for i in 0..<63 {
            let (x1, y1) = HilbertSensorMapper.map(index: i, order: 8)
            let (x2, y2) = HilbertSensorMapper.map(index: i + 1, order: 8)
            let manhattan = abs(x2 - x1) + abs(y2 - y1)
            XCTAssertEqual(manhattan, 1,
                "Adjacent indices \(i) and \(i+1) have Manhattan distance \(manhattan), expected 1. " +
                "(\(x1),\(y1)) -> (\(x2),\(y2))")
        }
    }

    /// Verify the maximum Euclidean distance between adjacent indices is bounded
    func testLocality_order4_adjacentIndicesMaxEuclideanDistance() {
        for i in 0..<15 {
            let (x1, y1) = HilbertSensorMapper.map(index: i, order: 4)
            let (x2, y2) = HilbertSensorMapper.map(index: i + 1, order: 4)
            let dx = Double(x2 - x1)
            let dy = Double(y2 - y1)
            let euclidean = sqrt(dx * dx + dy * dy)
            XCTAssertLessThanOrEqual(euclidean, 1.0,
                "Adjacent indices \(i) and \(i+1) have Euclidean distance \(euclidean)")
        }
    }
}

// MARK: - Bijection Tests

final class HilbertSensorMapperBijectionTests: XCTestCase {

    func testBijection_order2_allFourIndicesMapToUniqueCoordinates() {
        var coordinates = Set<String>()
        for i in 0..<4 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 2)
            coordinates.insert("\(x),\(y)")
        }
        XCTAssertEqual(coordinates.count, 4, "Expected 4 unique coordinates for order 2")
    }

    func testBijection_order4_all16IndicesMapToUniqueCoordinates() {
        var coordinates = Set<String>()
        for i in 0..<16 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 4)
            coordinates.insert("\(x),\(y)")
        }
        XCTAssertEqual(coordinates.count, 16, "Expected 16 unique coordinates for order 4")
    }

    func testBijection_order8_all64IndicesMapToUniqueCoordinates() {
        var coordinates = Set<String>()
        for i in 0..<64 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 8)
            coordinates.insert("\(x),\(y)")
        }
        XCTAssertEqual(coordinates.count, 64, "Expected 64 unique coordinates for order 8")
    }

    func testBijection_order4_coversEntireGrid() {
        // Every (x,y) pair in 0..<4 x 0..<4 should be hit exactly once
        var grid = [[Bool]](repeating: [Bool](repeating: false, count: 4), count: 4)
        for i in 0..<16 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 4)
            XCTAssertFalse(grid[y][x], "Cell (\(x),\(y)) hit more than once")
            grid[y][x] = true
        }
        // Verify all cells covered
        for y in 0..<4 {
            for x in 0..<4 {
                XCTAssertTrue(grid[y][x], "Cell (\(x),\(y)) was never hit")
            }
        }
    }

    func testBijection_order2_coversEntireGrid() {
        var grid = [[Bool]](repeating: [Bool](repeating: false, count: 2), count: 2)
        for i in 0..<4 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 2)
            XCTAssertFalse(grid[y][x], "Cell (\(x),\(y)) hit more than once")
            grid[y][x] = true
        }
        for y in 0..<2 {
            for x in 0..<2 {
                XCTAssertTrue(grid[y][x], "Cell (\(x),\(y)) was never hit")
            }
        }
    }

    /// Verify that the Hilbert curve is a proper space-filling curve:
    /// it visits every cell exactly once and forms a continuous path.
    func testBijection_order4_isContinuousPath() {
        // All adjacent steps have Manhattan distance 1 AND all cells are visited
        var visited = Set<String>()
        var (prevX, prevY) = HilbertSensorMapper.map(index: 0, order: 4)
        visited.insert("\(prevX),\(prevY)")

        for i in 1..<16 {
            let (x, y) = HilbertSensorMapper.map(index: i, order: 4)
            let manhattan = abs(x - prevX) + abs(y - prevY)
            XCTAssertEqual(manhattan, 1, "Not a continuous path at index \(i)")
            visited.insert("\(x),\(y)")
            prevX = x
            prevY = y
        }
        XCTAssertEqual(visited.count, 16, "Not all cells visited")
    }
}

#endif
