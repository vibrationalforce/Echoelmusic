import XCTest
@testable import Echoelmusic

/// Comprehensive tests for SpatialAudioEngine and spatial audio functionality
final class SpatialAudioTests: XCTestCase {

    // MARK: - SpatialMode Tests

    func testSpatialModeRawValues() {
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.stereo.rawValue, "Stereo")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_3d.rawValue, "3D Spatial")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_4d.rawValue, "4D Orbital")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.afa.rawValue, "AFA Field")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.binaural.rawValue, "Binaural")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.ambisonics.rawValue, "Ambisonics")
    }

    func testSpatialModeAllCases() {
        let modes = SpatialAudioEngine.SpatialMode.allCases
        XCTAssertEqual(modes.count, 6)
    }

    func testSpatialModeDescriptions() {
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.stereo.description, "L/R panning")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_3d.description, "3D positioning (X/Y/Z)")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_4d.description, "3D + temporal evolution")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.afa.description, "Algorithmic Field Array")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.binaural.description, "HRTF binaural rendering")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.ambisonics.description, "Higher-order ambisonics")
    }

    // MARK: - SpatialSource Tests

    func testSpatialSourceCreation() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(1.0, 2.0, 3.0)
        )

        XCTAssertEqual(source.position.x, 1.0)
        XCTAssertEqual(source.position.y, 2.0)
        XCTAssertEqual(source.position.z, 3.0)
        XCTAssertEqual(source.amplitude, 1.0)  // Default
        XCTAssertEqual(source.frequency, 440.0)  // Default
    }

    func testSpatialSourceDefaultVelocity() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero
        )

        XCTAssertEqual(source.velocity, .zero)
    }

    func testSpatialSourceOrbitalParameters() {
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, 0)
        )

        source.orbitalRadius = 2.0
        source.orbitalSpeed = 0.5
        source.orbitalPhase = Float.pi / 4

        XCTAssertEqual(source.orbitalRadius, 2.0)
        XCTAssertEqual(source.orbitalSpeed, 0.5)
        XCTAssertEqual(source.orbitalPhase, Float.pi / 4, accuracy: 0.001)
    }

    func testSpatialSourceFieldGeometry() {
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero
        )

        XCTAssertEqual(source.fieldGeometry, .circle)  // Default

        source.fieldGeometry = .fibonacci
        XCTAssertEqual(source.fieldGeometry, .fibonacci)

        source.fieldGeometry = .sphere
        XCTAssertEqual(source.fieldGeometry, .sphere)

        source.fieldGeometry = .grid
        XCTAssertEqual(source.fieldGeometry, .grid)
    }

    func testSpatialSourceFieldIndex() {
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero
        )

        XCTAssertEqual(source.fieldIndex, 0)  // Default

        source.fieldIndex = 7
        XCTAssertEqual(source.fieldIndex, 7)
    }

    // MARK: - SpatialAudioEngine Tests

    @MainActor
    func testEngineInitialState() async {
        let engine = SpatialAudioEngine()

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.currentMode, .stereo)
        XCTAssertFalse(engine.headTrackingEnabled)
        XCTAssertTrue(engine.spatialSources.isEmpty)
    }

    @MainActor
    func testEngineModeChange() async {
        let engine = SpatialAudioEngine()

        engine.currentMode = .surround_3d
        XCTAssertEqual(engine.currentMode, .surround_3d)

        engine.currentMode = .binaural
        XCTAssertEqual(engine.currentMode, .binaural)

        engine.currentMode = .afa
        XCTAssertEqual(engine.currentMode, .afa)
    }

    // MARK: - Position Calculation Tests

    func testSIMD3Initialization() {
        let position = SIMD3<Float>(1.5, -2.0, 3.5)

        XCTAssertEqual(position.x, 1.5)
        XCTAssertEqual(position.y, -2.0)
        XCTAssertEqual(position.z, 3.5)
    }

    func testSIMD3Zero() {
        let zero = SIMD3<Float>.zero

        XCTAssertEqual(zero.x, 0)
        XCTAssertEqual(zero.y, 0)
        XCTAssertEqual(zero.z, 0)
    }

    func testSIMD3Addition() {
        let a = SIMD3<Float>(1, 2, 3)
        let b = SIMD3<Float>(4, 5, 6)
        let sum = a + b

        XCTAssertEqual(sum.x, 5)
        XCTAssertEqual(sum.y, 7)
        XCTAssertEqual(sum.z, 9)
    }

    func testSIMD3Subtraction() {
        let a = SIMD3<Float>(5, 7, 9)
        let b = SIMD3<Float>(1, 2, 3)
        let diff = a - b

        XCTAssertEqual(diff.x, 4)
        XCTAssertEqual(diff.y, 5)
        XCTAssertEqual(diff.z, 6)
    }

    func testSIMD3ScalarMultiplication() {
        let v = SIMD3<Float>(1, 2, 3)
        let scaled = v * 2.0

        XCTAssertEqual(scaled.x, 2)
        XCTAssertEqual(scaled.y, 4)
        XCTAssertEqual(scaled.z, 6)
    }

    // MARK: - Field Geometry Tests

    func testFieldGeometryCircle() {
        // Test circular field distribution
        let sourceCount = 8
        var positions: [SIMD3<Float>] = []

        for i in 0..<sourceCount {
            let angle = Float(i) * (2.0 * Float.pi / Float(sourceCount))
            let radius: Float = 2.0
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            positions.append(SIMD3<Float>(x, 0, z))
        }

        XCTAssertEqual(positions.count, 8)

        // First position should be at (2, 0, 0)
        XCTAssertEqual(positions[0].x, 2.0, accuracy: 0.001)
        XCTAssertEqual(positions[0].y, 0.0, accuracy: 0.001)
        XCTAssertEqual(positions[0].z, 0.0, accuracy: 0.001)
    }

    func testFieldGeometryFibonacci() {
        // Test Fibonacci sphere distribution (golden angle)
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))
        let points = 13  // Fibonacci number

        var positions: [SIMD3<Float>] = []

        for i in 0..<points {
            let y = 1.0 - (Float(i) / Float(points - 1)) * 2.0
            let radiusAtY = sqrt(1.0 - y * y)
            let theta = goldenAngle * Float(i)

            let x = cos(theta) * radiusAtY
            let z = sin(theta) * radiusAtY

            positions.append(SIMD3<Float>(x, y, z))
        }

        XCTAssertEqual(positions.count, 13)

        // All points should be on unit sphere (distance = 1)
        for pos in positions {
            let distance = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            XCTAssertEqual(distance, 1.0, accuracy: 0.01)
        }
    }

    // MARK: - Orbital Motion Tests

    func testOrbitalPositionCalculation() {
        let radius: Float = 2.0
        let phase: Float = 0.0
        let speed: Float = 1.0
        let time: Float = Float.pi / 2  // Quarter revolution

        let angle = phase + speed * time
        let x = cos(angle) * radius
        let z = sin(angle) * radius

        XCTAssertEqual(x, 0.0, accuracy: 0.001)  // cos(π/2) = 0
        XCTAssertEqual(z, 2.0, accuracy: 0.001)  // sin(π/2) = 1, * 2 = 2
    }

    func testOrbitalFullRevolution() {
        let radius: Float = 1.0
        let startX = cos(0) * radius
        let endX = cos(2.0 * Float.pi) * radius

        XCTAssertEqual(startX, endX, accuracy: 0.001)  // Should return to start
    }

    // MARK: - Distance Attenuation Tests

    func testDistanceAttenuation() {
        // Test inverse-square law attenuation
        func calculateAttenuation(distance: Float, referenceDistance: Float = 1.0) -> Float {
            guard distance > 0 else { return 1.0 }
            return (referenceDistance / distance) * (referenceDistance / distance)
        }

        // At reference distance, attenuation should be 1.0
        XCTAssertEqual(calculateAttenuation(distance: 1.0), 1.0, accuracy: 0.001)

        // At 2x distance, attenuation should be 0.25 (1/4)
        XCTAssertEqual(calculateAttenuation(distance: 2.0), 0.25, accuracy: 0.001)

        // At 0.5x distance, attenuation should be 4.0 (clamped in practice)
        XCTAssertEqual(calculateAttenuation(distance: 0.5), 4.0, accuracy: 0.001)
    }

    // MARK: - HRTF Direction Tests

    func testAzimuthCalculation() {
        // Test azimuth angle from listener to source
        func calculateAzimuth(sourceX: Float, sourceZ: Float) -> Float {
            return atan2(sourceX, sourceZ) * (180.0 / Float.pi)
        }

        // Source directly ahead (0°)
        XCTAssertEqual(calculateAzimuth(sourceX: 0, sourceZ: 1), 0.0, accuracy: 0.001)

        // Source to the right (90°)
        XCTAssertEqual(calculateAzimuth(sourceX: 1, sourceZ: 0), 90.0, accuracy: 0.001)

        // Source directly behind (180° or -180°)
        let behindAzimuth = calculateAzimuth(sourceX: 0, sourceZ: -1)
        XCTAssertTrue(abs(behindAzimuth) == 180.0 || behindAzimuth == 180.0)

        // Source to the left (-90°)
        XCTAssertEqual(calculateAzimuth(sourceX: -1, sourceZ: 0), -90.0, accuracy: 0.001)
    }

    func testElevationCalculation() {
        // Test elevation angle from listener to source
        func calculateElevation(sourceY: Float, distance: Float) -> Float {
            guard distance > 0 else { return 0 }
            return asin(sourceY / distance) * (180.0 / Float.pi)
        }

        // Source at listener height (0°)
        XCTAssertEqual(calculateElevation(sourceY: 0, distance: 1), 0.0, accuracy: 0.001)

        // Source directly above (90°)
        XCTAssertEqual(calculateElevation(sourceY: 1, distance: 1), 90.0, accuracy: 0.001)

        // Source at 45° elevation
        let distance = sqrt(2.0) as Float
        XCTAssertEqual(calculateElevation(sourceY: 1, distance: distance), 45.0, accuracy: 0.1)
    }

    // MARK: - Bio-Reactive Field Tests

    func testCoherenceToFieldGeometry() {
        // High coherence → Fibonacci (harmonious)
        // Low coherence → Grid (grounded)

        func geometryForCoherence(_ coherence: Float) -> SpatialAudioEngine.SpatialSource.FieldGeometry {
            if coherence > 0.6 {
                return .fibonacci
            } else if coherence > 0.3 {
                return .sphere
            } else {
                return .grid
            }
        }

        XCTAssertEqual(geometryForCoherence(0.8), .fibonacci)
        XCTAssertEqual(geometryForCoherence(0.5), .sphere)
        XCTAssertEqual(geometryForCoherence(0.2), .grid)
    }

    // MARK: - Multiple Source Tests

    func testMultipleSources() {
        var sources: [SpatialAudioEngine.SpatialSource] = []

        for i in 0..<4 {
            let source = SpatialAudioEngine.SpatialSource(
                id: UUID(),
                position: SIMD3<Float>(Float(i), 0, 0),
                amplitude: Float(i) * 0.25
            )
            sources.append(source)
        }

        XCTAssertEqual(sources.count, 4)
        XCTAssertEqual(sources[0].position.x, 0)
        XCTAssertEqual(sources[3].position.x, 3)
        XCTAssertEqual(sources[2].amplitude, 0.5)
    }

    func testSourceIdentifiability() {
        let id1 = UUID()
        let id2 = UUID()

        let source1 = SpatialAudioEngine.SpatialSource(id: id1, position: .zero)
        let source2 = SpatialAudioEngine.SpatialSource(id: id2, position: .zero)

        XCTAssertEqual(source1.id, id1)
        XCTAssertEqual(source2.id, id2)
        XCTAssertNotEqual(source1.id, source2.id)
    }

    // MARK: - Frequency Tests

    func testDefaultFrequency() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero
        )

        XCTAssertEqual(source.frequency, 440.0)  // A4 concert pitch
    }

    func testCustomFrequency() {
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero
        )

        source.frequency = 261.63  // Middle C

        XCTAssertEqual(source.frequency, 261.63, accuracy: 0.01)
    }
}
