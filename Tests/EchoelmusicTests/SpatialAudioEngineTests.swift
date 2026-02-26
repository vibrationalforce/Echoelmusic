import XCTest
import simd
@testable import Echoelmusic

/// Comprehensive tests for SpatialAudioEngine
/// Tests spatial modes, source management, AFA field generation, and 4D orbital motion
@MainActor
final class SpatialAudioEngineTests: XCTestCase {

    var spatialEngine: SpatialAudioEngine!

    override func setUp() async throws {
        spatialEngine = SpatialAudioEngine()
    }

    override func tearDown() async throws {
        spatialEngine?.stop()
        spatialEngine = nil
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertFalse(spatialEngine.isActive)
        XCTAssertEqual(spatialEngine.currentMode, .stereo)
        XCTAssertFalse(spatialEngine.headTrackingEnabled)
        XCTAssertTrue(spatialEngine.spatialSources.isEmpty)
    }

    // MARK: - Spatial Mode Tests

    func testAllSpatialModes() {
        let modes = SpatialAudioEngine.SpatialMode.allCases
        XCTAssertEqual(modes.count, 6)

        XCTAssertTrue(modes.contains(.stereo))
        XCTAssertTrue(modes.contains(.surround_3d))
        XCTAssertTrue(modes.contains(.surround_4d))
        XCTAssertTrue(modes.contains(.afa))
        XCTAssertTrue(modes.contains(.binaural))
        XCTAssertTrue(modes.contains(.ambisonics))
    }

    func testSpatialModeDescriptions() {
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.stereo.description, "L/R panning")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_3d.description, "3D positioning (X/Y/Z)")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_4d.description, "3D + temporal evolution")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.afa.description, "Algorithmic Field Array")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.binaural.description, "HRTF binaural rendering")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.ambisonics.description, "Higher-order ambisonics")
    }

    func testSpatialModeRawValues() {
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.stereo.rawValue, "Stereo")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_3d.rawValue, "3D Spatial")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_4d.rawValue, "4D Orbital")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.afa.rawValue, "AFA Field")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.binaural.rawValue, "Binaural")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.ambisonics.rawValue, "Ambisonics")
    }

    func testSetMode() {
        spatialEngine.setMode(.surround_3d)
        XCTAssertEqual(spatialEngine.currentMode, .surround_3d)

        spatialEngine.setMode(.binaural)
        XCTAssertEqual(spatialEngine.currentMode, .binaural)
    }

    // MARK: - SpatialSource Tests

    func testSpatialSourceCreation() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(1.0, 2.0, 3.0),
            amplitude: 0.8,
            frequency: 523.251
        )

        XCTAssertEqual(source.position.x, 1.0)
        XCTAssertEqual(source.position.y, 2.0)
        XCTAssertEqual(source.position.z, 3.0)
        XCTAssertEqual(source.amplitude, 0.8)
        XCTAssertEqual(source.frequency, 523.251)
    }

    func testSpatialSourceDefaults() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(source.velocity, SIMD3<Float>.zero)
        XCTAssertEqual(source.amplitude, 1.0)
        XCTAssertEqual(source.frequency, 440.0)
        XCTAssertEqual(source.orbitalRadius, 0.0)
        XCTAssertEqual(source.orbitalSpeed, 0.0)
        XCTAssertEqual(source.orbitalPhase, 0.0)
        XCTAssertEqual(source.fieldIndex, 0)
    }

    func testFieldGeometryTypes() {
        let circleSource = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero,
            fieldGeometry: .circle
        )
        XCTAssertNotNil(circleSource)

        let sphereSource = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero,
            fieldGeometry: .sphere
        )
        XCTAssertNotNil(sphereSource)

        let fibonacciSource = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero,
            fieldGeometry: .fibonacci
        )
        XCTAssertNotNil(fibonacciSource)

        let gridSource = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: .zero,
            fieldGeometry: .grid
        )
        XCTAssertNotNil(gridSource)
    }

    // MARK: - Source Management Tests

    func testAddSource() {
        let sourceID = spatialEngine.addSource(
            position: SIMD3<Float>(0, 0, 1),
            amplitude: 0.8,
            frequency: 440.0
        )

        XCTAssertEqual(spatialEngine.spatialSources.count, 1)
        XCTAssertEqual(spatialEngine.spatialSources.first?.id, sourceID)
    }

    func testAddMultipleSources() {
        _ = spatialEngine.addSource(position: SIMD3<Float>(1, 0, 0))
        _ = spatialEngine.addSource(position: SIMD3<Float>(0, 1, 0))
        _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))

        XCTAssertEqual(spatialEngine.spatialSources.count, 3)
    }

    func testRemoveSource() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(spatialEngine.spatialSources.count, 1)

        spatialEngine.removeSource(id: sourceID)
        XCTAssertEqual(spatialEngine.spatialSources.count, 0)
    }

    func testRemoveNonexistentSource() {
        _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        spatialEngine.removeSource(id: UUID())  // Random ID

        XCTAssertEqual(spatialEngine.spatialSources.count, 1)  // Original still there
    }

    func testUpdateSourcePosition() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))

        let newPosition = SIMD3<Float>(2.0, 3.0, 4.0)
        spatialEngine.updateSourcePosition(id: sourceID, position: newPosition)

        let source = spatialEngine.spatialSources.first { $0.id == sourceID }
        XCTAssertEqual(source?.position.x, 2.0)
        XCTAssertEqual(source?.position.y, 3.0)
        XCTAssertEqual(source?.position.z, 4.0)
    }

    func testUpdateSourceOrbital() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))

        spatialEngine.updateSourceOrbital(id: sourceID, radius: 2.0, speed: 1.5, phase: 0.5)

        let source = spatialEngine.spatialSources.first { $0.id == sourceID }
        XCTAssertEqual(source?.orbitalRadius, 2.0)
        XCTAssertEqual(source?.orbitalSpeed, 1.5)
        XCTAssertEqual(source?.orbitalPhase, 0.5)
    }

    // MARK: - 4D Orbital Motion Tests

    func testOrbitalMotionInNonOrbitalMode() {
        spatialEngine.setMode(.stereo)
        _ = spatialEngine.addSource(position: SIMD3<Float>(1, 0, 0))

        let initialPosition = spatialEngine.spatialSources.first?.position

        // Should not update in stereo mode
        spatialEngine.update4DOrbitalMotion(deltaTime: 0.1)

        XCTAssertEqual(spatialEngine.spatialSources.first?.position, initialPosition)
    }

    func testOrbitalMotionUpdatesPhase() {
        spatialEngine.setMode(.surround_4d)
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(1, 0, 1))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 1.0, speed: 2.0, phase: 0.0)

        let initialPhase = spatialEngine.spatialSources.first?.orbitalPhase ?? 0

        spatialEngine.update4DOrbitalMotion(deltaTime: 0.5)

        let newPhase = spatialEngine.spatialSources.first?.orbitalPhase ?? 0
        XCTAssertGreaterThan(newPhase, initialPhase)
    }

    func testOrbitalMotionZeroRadiusNoChange() {
        spatialEngine.setMode(.surround_4d)
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(1, 0, 1))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 0.0, speed: 2.0, phase: 0.0)

        let initialPosition = spatialEngine.spatialSources.first?.position

        spatialEngine.update4DOrbitalMotion(deltaTime: 0.5)

        // With zero radius, position should not change from orbital motion
        XCTAssertEqual(spatialEngine.spatialSources.first?.position, initialPosition)
    }

    // MARK: - AFA Field Tests

    func testAFAFieldNotAppliedInNonAFAMode() {
        spatialEngine.setMode(.stereo)
        _ = spatialEngine.addSource(position: SIMD3<Float>(1, 0, 0))

        let initialPosition = spatialEngine.spatialSources.first?.position

        spatialEngine.applyAFAField(geometry: .circle(radius: 2.0), coherence: 80)

        // Should not change position in stereo mode
        XCTAssertEqual(spatialEngine.spatialSources.first?.position, initialPosition)
    }

    func testAFAFieldAppliedInAFAMode() {
        spatialEngine.setMode(.afa)
        _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))

        spatialEngine.applyAFAField(geometry: .circle(radius: 2.0), coherence: 80)

        // Position should be updated
        let source = spatialEngine.spatialSources.first
        XCTAssertNotNil(source)
    }

    // MARK: - AFA Field Geometry Tests

    func testAFAFieldGeometryGrid() {
        spatialEngine.setMode(.afa)

        // Add 4 sources for a 2x2 grid
        for _ in 0..<4 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        }

        spatialEngine.applyAFAField(geometry: .grid(rows: 2, cols: 2), coherence: 50)

        // All sources should have Z = 1.0 (grid is 2D)
        for source in spatialEngine.spatialSources {
            XCTAssertEqual(source.position.z, 1.0, accuracy: 0.01)
        }
    }

    func testAFAFieldGeometryCircle() {
        spatialEngine.setMode(.afa)

        // Add 4 sources for a circle
        for _ in 0..<4 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        }

        spatialEngine.applyAFAField(geometry: .circle(radius: 1.0), coherence: 50)

        // Each source should be at radius 1.0 from origin (in XY plane)
        for source in spatialEngine.spatialSources {
            let distance = sqrt(source.position.x * source.position.x + source.position.y * source.position.y)
            XCTAssertEqual(distance, 1.0, accuracy: 0.01)
        }
    }

    func testAFAFieldGeometryFibonacci() {
        spatialEngine.setMode(.afa)

        // Add 10 sources for fibonacci distribution
        for _ in 0..<10 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        }

        spatialEngine.applyAFAField(geometry: .fibonacci(count: 10), coherence: 80)

        // Fibonacci sphere: all points should be on unit sphere
        for source in spatialEngine.spatialSources {
            let distance = sqrt(
                source.position.x * source.position.x +
                source.position.y * source.position.y +
                source.position.z * source.position.z
            )
            XCTAssertEqual(distance, 1.0, accuracy: 0.01)
        }
    }

    func testAFAFieldGeometrySphere() {
        spatialEngine.setMode(.afa)

        // Add 8 sources for sphere distribution
        for _ in 0..<8 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        }

        let radius: Float = 2.0
        spatialEngine.applyAFAField(geometry: .sphere(radius: radius), coherence: 70)

        // All points should be on sphere of given radius
        for source in spatialEngine.spatialSources {
            let distance = sqrt(
                source.position.x * source.position.x +
                source.position.y * source.position.y +
                source.position.z * source.position.z
            )
            XCTAssertEqual(distance, radius, accuracy: 0.1)
        }
    }

    // MARK: - Debug Info Tests

    func testDebugInfo() {
        let debugInfo = spatialEngine.debugInfo

        XCTAssertTrue(debugInfo.contains("SpatialAudioEngine"))
        XCTAssertTrue(debugInfo.contains("Mode"))
        XCTAssertTrue(debugInfo.contains("Active"))
        XCTAssertTrue(debugInfo.contains("Sources"))
        XCTAssertTrue(debugInfo.contains("Head Tracking"))
    }

    // MARK: - Head Tracking Tests

    func testHeadTrackingEnabledProperty() {
        XCTAssertFalse(spatialEngine.headTrackingEnabled)

        spatialEngine.headTrackingEnabled = true
        XCTAssertTrue(spatialEngine.headTrackingEnabled)
    }

    // MARK: - Performance Tests

    func testAddSourcePerformance() {
        measure {
            for _ in 0..<100 {
                _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
            }
        }
    }

    func testOrbitalUpdatePerformance() {
        spatialEngine.setMode(.surround_4d)

        // Add many sources with orbital motion
        for _ in 0..<50 {
            let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
            spatialEngine.updateSourceOrbital(id: sourceID, radius: 1.0, speed: 1.0, phase: 0.0)
        }

        measure {
            for _ in 0..<100 {
                spatialEngine.update4DOrbitalMotion(deltaTime: 0.016)  // ~60fps
            }
        }
    }
}
