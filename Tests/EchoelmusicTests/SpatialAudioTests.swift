// SpatialAudioTests.swift
// Echoelmusic - Spatial Audio Test Suite
// Wise Mode Implementation

import XCTest
import simd
@testable import Echoelmusic

final class SpatialAudioTests: XCTestCase {

    // MARK: - Properties

    var spatialEngine: SpatialAudioService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        spatialEngine = SpatialAudioService()
    }

    override func tearDown() {
        spatialEngine = nil
        super.tearDown()
    }

    // MARK: - Mode Tests

    func testDefaultModeIsStereo() {
        XCTAssertEqual(spatialEngine.currentMode, .stereo)
    }

    func testSetSpatialMode() {
        for mode in SpatialMode.allCases {
            spatialEngine.setMode(mode)
            XCTAssertEqual(spatialEngine.currentMode, mode, "Mode should be \(mode.rawValue)")
        }
    }

    // MARK: - Position Validation Tests

    func testPositionValidation() {
        // Test normal position
        let normalPosition = SIMD3<Float>(1.0, 2.0, 3.0)
        let validated = InputValidator.validatePosition(normalPosition)
        XCTAssertEqual(validated, normalPosition)
    }

    func testPositionClampingAtMaxDistance() {
        // Test position beyond max distance
        let farPosition = SIMD3<Float>(200.0, 0.0, 0.0)
        let validated = InputValidator.validatePosition(farPosition, maxDistance: 100.0)

        // Should be clamped to max distance (100)
        let length = simd_length(validated)
        XCTAssertLessThanOrEqual(length, 100.0, accuracy: 0.001)
    }

    func testListenerPositionUpdate() {
        let position = SIMD3<Float>(5.0, 0.0, -3.0)
        spatialEngine.updateListenerPosition(position)
        // Position should be validated and stored
        // Note: Add getter to verify in production implementation
    }

    // MARK: - Azimuth/Elevation Tests

    func testAzimuthValidation() {
        // Test normal range
        XCTAssertEqual(InputValidator.validateAzimuth(45.0), 45.0)
        XCTAssertEqual(InputValidator.validateAzimuth(-90.0), -90.0)
        XCTAssertEqual(InputValidator.validateAzimuth(180.0), 180.0)
        XCTAssertEqual(InputValidator.validateAzimuth(-180.0), -180.0)

        // Test wrapping
        XCTAssertEqual(InputValidator.validateAzimuth(270.0), -90.0, accuracy: 0.001)
        XCTAssertEqual(InputValidator.validateAzimuth(-270.0), 90.0, accuracy: 0.001)
        XCTAssertEqual(InputValidator.validateAzimuth(360.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(InputValidator.validateAzimuth(540.0), 180.0, accuracy: 0.001)
    }

    func testElevationValidation() {
        // Test clamping
        XCTAssertEqual(InputValidator.validateElevation(0.0), 0.0)
        XCTAssertEqual(InputValidator.validateElevation(45.0), 45.0)
        XCTAssertEqual(InputValidator.validateElevation(90.0), 90.0)
        XCTAssertEqual(InputValidator.validateElevation(-90.0), -90.0)

        // Test out of range
        XCTAssertEqual(InputValidator.validateElevation(100.0), 90.0)
        XCTAssertEqual(InputValidator.validateElevation(-100.0), -90.0)
    }

    // MARK: - Fibonacci Sphere Tests

    func testFibonacciSphereDistributionCount() {
        // Test various counts
        let counts = [8, 16, 32, 64, 128]

        for count in counts {
            let points = generateFibonacciSphere(count: count)
            XCTAssertEqual(points.count, count, "Should generate exactly \(count) points")
        }
    }

    func testFibonacciSpherePointsOnUnitSphere() {
        let points = generateFibonacciSphere(count: 100)

        for point in points {
            let length = simd_length(point)
            XCTAssertEqual(length, 1.0, accuracy: 0.0001, "Points should be on unit sphere")
        }
    }

    func testFibonacciSphereDistributionUniformity() {
        let points = generateFibonacciSphere(count: 64)

        // Calculate average distance between nearest neighbors
        var totalMinDistance: Float = 0
        for point in points {
            var minDistance: Float = Float.greatestFiniteMagnitude
            for other in points where point != other {
                let distance = simd_distance(point, other)
                minDistance = min(minDistance, distance)
            }
            totalMinDistance += minDistance
        }

        let avgMinDistance = totalMinDistance / Float(points.count)

        // For uniform distribution, average min distance should be roughly consistent
        // Expected: roughly 2 * sqrt(pi / n) for n points on unit sphere
        let expected = 2.0 * sqrt(Float.pi / Float(points.count))
        XCTAssertEqual(avgMinDistance, expected, accuracy: 0.1, "Distribution should be roughly uniform")
    }

    // MARK: - Helper Functions

    /// Generate Fibonacci sphere distribution
    private func generateFibonacciSphere(count: Int) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let goldenRatio = (1.0 + sqrt(5.0)) / 2.0
        let angleIncrement = Float.pi * 2.0 * Float(goldenRatio)

        for i in 0..<count {
            let t = Float(i) / Float(count - 1)
            let inclination = acos(1.0 - 2.0 * t)
            let azimuth = angleIncrement * Float(i)

            let x = sin(inclination) * cos(azimuth)
            let y = sin(inclination) * sin(azimuth)
            let z = cos(inclination)

            points.append(SIMD3<Float>(x, y, z))
        }

        return points
    }
}

// MARK: - Performance Tests

extension SpatialAudioTests {

    func testFibonacciSphereGenerationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = generateFibonacciSphere(count: 256)
            }
        }
    }

    func testPositionValidationPerformance() {
        let positions = (0..<10000).map { _ in
            SIMD3<Float>(
                Float.random(in: -200...200),
                Float.random(in: -200...200),
                Float.random(in: -200...200)
            )
        }

        measure {
            for position in positions {
                _ = InputValidator.validatePosition(position)
            }
        }
    }
}
