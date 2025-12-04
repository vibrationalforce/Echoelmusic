import XCTest
@testable import Echoelmusic

/// Tests for Spatial Audio Engine
final class SpatialAudioTests: XCTestCase {

    var spatialEngine: SpatialAudioEngine!

    @MainActor
    override func setUp() async throws {
        spatialEngine = SpatialAudioEngine()
    }

    @MainActor
    override func tearDown() {
        spatialEngine.stop()
        spatialEngine = nil
    }

    // MARK: - Initialization Tests

    @MainActor
    func testSpatialEngineInitialization() {
        XCTAssertNotNil(spatialEngine, "Spatial engine should initialize")
        XCTAssertFalse(spatialEngine.isActive, "Engine should not be active initially")
        XCTAssertEqual(spatialEngine.currentMode, .stereo, "Default mode should be stereo")
    }

    // MARK: - Source Management Tests

    @MainActor
    func testAddSpatialSource() {
        let position = SIMD3<Float>(1.0, 0.0, 2.0)
        let sourceID = spatialEngine.addSource(position: position, amplitude: 0.8, frequency: 440)

        XCTAssertNotNil(sourceID, "Should return valid UUID")
        XCTAssertEqual(spatialEngine.spatialSources.count, 1, "Should have one source")
        XCTAssertEqual(spatialEngine.spatialSources.first?.position, position, "Position should match")
    }

    @MainActor
    func testRemoveSpatialSource() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))

        XCTAssertEqual(spatialEngine.spatialSources.count, 1)

        spatialEngine.removeSource(id: sourceID)

        XCTAssertEqual(spatialEngine.spatialSources.count, 0, "Source should be removed")
    }

    @MainActor
    func testUpdateSourcePosition() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))
        let newPosition = SIMD3<Float>(5.0, 3.0, -2.0)

        spatialEngine.updateSourcePosition(id: sourceID, position: newPosition)

        XCTAssertEqual(spatialEngine.spatialSources.first?.position, newPosition, "Position should be updated")
    }

    @MainActor
    func testUpdateSourceOrbital() {
        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))

        spatialEngine.updateSourceOrbital(id: sourceID, radius: 2.0, speed: 1.5, phase: 0.5)

        let source = spatialEngine.spatialSources.first
        XCTAssertEqual(source?.orbitalRadius, 2.0)
        XCTAssertEqual(source?.orbitalSpeed, 1.5)
        XCTAssertEqual(source?.orbitalPhase, 0.5)
    }

    // MARK: - Mode Switching Tests

    @MainActor
    func testModeSwitching() {
        let modes: [SpatialAudioEngine.SpatialMode] = [.stereo, .surround_3d, .surround_4d, .binaural, .afa, .ambisonics]

        for mode in modes {
            spatialEngine.setMode(mode)
            XCTAssertEqual(spatialEngine.currentMode, mode, "Mode should be \(mode)")
        }
    }

    // MARK: - 4D Orbital Motion Tests

    @MainActor
    func testOrbitalMotionUpdatesPosition() {
        spatialEngine.setMode(.surround_4d)

        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 2.0, speed: 1.0, phase: 0)

        let initialPosition = spatialEngine.spatialSources.first?.position

        // Simulate time step
        spatialEngine.update4DOrbitalMotion(deltaTime: 0.1)

        let newPosition = spatialEngine.spatialSources.first?.position

        XCTAssertNotEqual(newPosition, initialPosition, "Position should change with orbital motion")
    }

    @MainActor
    func testOrbitalPhaseWrapping() {
        spatialEngine.setMode(.surround_4d)

        let sourceID = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 1))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 1.0, speed: Float.pi, phase: Float.pi * 1.9)

        spatialEngine.update4DOrbitalMotion(deltaTime: 1.0)

        let phase = spatialEngine.spatialSources.first?.orbitalPhase ?? 0
        XCTAssertLessThan(phase, 2 * Float.pi, "Phase should wrap at 2π")
    }

    // MARK: - AFA Field Tests

    @MainActor
    func testAFAFieldCircleGeometry() {
        spatialEngine.setMode(.afa)

        // Add multiple sources
        for _ in 0..<8 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))
        }

        spatialEngine.applyAFAField(geometry: .circle(radius: 3.0), coherence: 80)

        // Check that sources are distributed in a circle
        for source in spatialEngine.spatialSources {
            let radius = sqrt(source.position.x * source.position.x + source.position.y * source.position.y)
            XCTAssertEqual(radius, 3.0, accuracy: 0.1, "Sources should be at radius 3.0")
        }
    }

    @MainActor
    func testAFAFieldGridGeometry() {
        spatialEngine.setMode(.afa)

        for _ in 0..<9 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))
        }

        spatialEngine.applyAFAField(geometry: .grid(rows: 3, cols: 3), coherence: 70)

        XCTAssertEqual(spatialEngine.spatialSources.count, 9, "Should have 9 sources")
    }

    @MainActor
    func testAFAFieldFibonacciGeometry() {
        spatialEngine.setMode(.afa)

        for _ in 0..<13 {
            _ = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))
        }

        spatialEngine.applyAFAField(geometry: .fibonacci(count: 13), coherence: 90)

        // Fibonacci distribution should be uniform on sphere surface
        let positions = spatialEngine.spatialSources.map { $0.position }

        // Check that positions are normalized (on unit sphere)
        for pos in positions {
            let magnitude = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            XCTAssertEqual(magnitude, 1.0, accuracy: 0.01, "Fibonacci points should be on unit sphere")
        }
    }

    // MARK: - Head Tracking Tests

    @MainActor
    func testHeadTrackingToggle() {
        XCTAssertFalse(spatialEngine.headTrackingEnabled, "Head tracking should be off by default")

        spatialEngine.headTrackingEnabled = true
        XCTAssertTrue(spatialEngine.headTrackingEnabled)

        spatialEngine.headTrackingEnabled = false
        XCTAssertFalse(spatialEngine.headTrackingEnabled)
    }

    // MARK: - Debug Info Tests

    @MainActor
    func testDebugInfoContainsExpectedFields() {
        let debugInfo = spatialEngine.debugInfo

        XCTAssertTrue(debugInfo.contains("Mode:"), "Should contain mode info")
        XCTAssertTrue(debugInfo.contains("Active:"), "Should contain active state")
        XCTAssertTrue(debugInfo.contains("Sources:"), "Should contain source count")
        XCTAssertTrue(debugInfo.contains("Head Tracking:"), "Should contain head tracking state")
    }

    // MARK: - Spatial Source Struct Tests

    func testSpatialSourceInitialization() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(1, 2, 3),
            velocity: SIMD3<Float>(0.1, 0.2, 0.3),
            amplitude: 0.8,
            frequency: 440
        )

        XCTAssertEqual(source.position, SIMD3<Float>(1, 2, 3))
        XCTAssertEqual(source.amplitude, 0.8)
        XCTAssertEqual(source.frequency, 440)
        XCTAssertEqual(source.orbitalRadius, 0)
        XCTAssertEqual(source.fieldGeometry, .circle)
    }

    // MARK: - Performance Tests

    @MainActor
    func testMultipleSourcesPerformance() {
        spatialEngine.setMode(.surround_4d)

        // Add 100 sources
        for i in 0..<100 {
            let angle = Float(i) * 2.0 * Float.pi / 100.0
            let sourceID = spatialEngine.addSource(
                position: SIMD3<Float>(cos(angle), sin(angle), 0)
            )
            spatialEngine.updateSourceOrbital(id: sourceID, radius: 2.0, speed: Float.random(in: 0.5...2.0), phase: 0)
        }

        measure {
            for _ in 0..<1000 {
                spatialEngine.update4DOrbitalMotion(deltaTime: 0.016)  // ~60fps
            }
        }
    }

    @MainActor
    func testPositionUpdatePerformance() {
        // Add 50 sources
        var sourceIDs: [UUID] = []
        for _ in 0..<50 {
            let id = spatialEngine.addSource(position: SIMD3<Float>(0, 0, 0))
            sourceIDs.append(id)
        }

        measure {
            for _ in 0..<1000 {
                for id in sourceIDs {
                    let newPos = SIMD3<Float>(
                        Float.random(in: -5...5),
                        Float.random(in: -5...5),
                        Float.random(in: -5...5)
                    )
                    spatialEngine.updateSourcePosition(id: id, position: newPos)
                }
            }
        }
    }
}

// MARK: - SIMD3 Extension Tests

final class SIMD3Tests: XCTestCase {

    func testSIMD3Distance() {
        let a = SIMD3<Float>(0, 0, 0)
        let b = SIMD3<Float>(3, 4, 0)

        let distance = sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y) + (b.z - a.z) * (b.z - a.z))

        XCTAssertEqual(distance, 5.0, accuracy: 0.001, "Distance should be 5 (3-4-5 triangle)")
    }

    func testSIMD3Normalization() {
        let v = SIMD3<Float>(3, 4, 0)
        let magnitude = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        let normalized = v / magnitude

        let normalizedMagnitude = sqrt(normalized.x * normalized.x + normalized.y * normalized.y + normalized.z * normalized.z)

        XCTAssertEqual(normalizedMagnitude, 1.0, accuracy: 0.001, "Normalized vector should have magnitude 1")
    }
}
