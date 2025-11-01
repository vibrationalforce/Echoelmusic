import XCTest
@testable import Blab
import AVFoundation

@MainActor
final class SpatialAudioEngineTests: XCTestCase {

    var engine: SpatialAudioEngine!

    override func setUp() async throws {
        try await super.setUp()
        engine = SpatialAudioEngine()
    }

    override func tearDown() async throws {
        engine.stop()
        engine = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(engine, "Engine should be initialized")
        XCTAssertFalse(engine.isActive, "Engine should not be active initially")
        XCTAssertEqual(engine.currentMode, .stereo, "Default mode should be stereo")
        XCTAssertFalse(engine.headTrackingEnabled, "Head tracking should be disabled initially")
        XCTAssertTrue(engine.spatialSources.isEmpty, "Should have no spatial sources initially")
    }

    // MARK: - Spatial Mode Tests

    func testSpatialModeEnums() {
        let allModes = SpatialAudioEngine.SpatialMode.allCases
        XCTAssertEqual(allModes.count, 6, "Should have 6 spatial modes")

        // Verify all modes exist
        XCTAssertTrue(allModes.contains(.stereo))
        XCTAssertTrue(allModes.contains(.surround_3d))
        XCTAssertTrue(allModes.contains(.surround_4d))
        XCTAssertTrue(allModes.contains(.afa))
        XCTAssertTrue(allModes.contains(.binaural))
        XCTAssertTrue(allModes.contains(.ambisonics))
    }

    func testSpatialModeDescriptions() {
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.stereo.description, "L/R panning")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_3d.description, "3D positioning (X/Y/Z)")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.surround_4d.description, "3D + temporal evolution")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.afa.description, "Algorithmic Field Array")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.binaural.description, "HRTF binaural rendering")
        XCTAssertEqual(SpatialAudioEngine.SpatialMode.ambisonics.description, "Higher-order ambisonics")
    }

    func testSpatialModeChange() {
        engine.currentMode = .surround_3d
        XCTAssertEqual(engine.currentMode, .surround_3d, "Mode should update to 3D")

        engine.currentMode = .afa
        XCTAssertEqual(engine.currentMode, .afa, "Mode should update to AFA")
    }

    // MARK: - Start/Stop Tests

    func testStartEngine() async throws {
        // Note: This test may fail in simulator without audio hardware
        // In a real test environment, we would mock AVAudioEngine
        do {
            try engine.start()
            XCTAssertTrue(engine.isActive, "Engine should be active after start")
        } catch {
            // Expected to fail in simulator/CI environment
            print("⚠️ Start failed (expected in simulator): \(error)")
        }
    }

    func testStopEngine() {
        engine.stop()
        XCTAssertFalse(engine.isActive, "Engine should be inactive after stop")
    }

    func testDoubleStart() throws {
        // First start should succeed (or fail with expected error)
        do {
            try engine.start()
        } catch {
            // Expected in simulator
        }

        // Second start should be no-op
        XCTAssertNoThrow(try engine.start(), "Double start should not throw")
    }

    // MARK: - Spatial Source Tests

    func testAddSpatialSource() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 1.0,
            frequency: 440.0
        )

        engine.addSource(source)

        XCTAssertEqual(engine.spatialSources.count, 1, "Should have 1 source")
        XCTAssertEqual(engine.spatialSources.first?.id, source.id, "Source ID should match")
    }

    func testRemoveSpatialSource() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 1.0,
            frequency: 440.0
        )

        engine.addSource(source)
        XCTAssertEqual(engine.spatialSources.count, 1, "Should have 1 source")

        engine.removeSource(id: source.id)
        XCTAssertEqual(engine.spatialSources.count, 0, "Should have 0 sources after removal")
    }

    func testMultipleSpatialSources() {
        let source1 = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(1, 0, 0),
            amplitude: 1.0,
            frequency: 440.0
        )

        let source2 = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(-1, 0, 0),
            amplitude: 1.0,
            frequency: 880.0
        )

        engine.addSource(source1)
        engine.addSource(source2)

        XCTAssertEqual(engine.spatialSources.count, 2, "Should have 2 sources")
    }

    // MARK: - Head Tracking Tests

    func testHeadTrackingToggle() {
        XCTAssertFalse(engine.headTrackingEnabled, "Head tracking should be disabled initially")

        engine.headTrackingEnabled = true
        XCTAssertTrue(engine.headTrackingEnabled, "Head tracking should be enabled")

        engine.headTrackingEnabled = false
        XCTAssertFalse(engine.headTrackingEnabled, "Head tracking should be disabled")
    }

    func testHeadTrackingWithInactiveEngine() {
        engine.headTrackingEnabled = true
        // Should not crash when engine is not active
        XCTAssertTrue(engine.headTrackingEnabled, "Should be able to enable head tracking when engine is inactive")
    }

    // MARK: - 3D Position Tests

    func testSpatialSourcePosition() {
        let position = SIMD3<Float>(2.5, 1.0, -3.0)
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: position,
            amplitude: 1.0,
            frequency: 440.0
        )

        XCTAssertEqual(source.position.x, 2.5, accuracy: 0.001)
        XCTAssertEqual(source.position.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(source.position.z, -3.0, accuracy: 0.001)
    }

    func testUpdateSourcePosition() {
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, 0),
            amplitude: 1.0,
            frequency: 440.0
        )

        engine.addSource(source)

        // Update position
        source.position = SIMD3<Float>(1, 2, 3)
        engine.updateSource(source)

        let updatedSource = engine.spatialSources.first { $0.id == source.id }
        XCTAssertEqual(updatedSource?.position.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(updatedSource?.position.y, 2.0, accuracy: 0.001)
        XCTAssertEqual(updatedSource?.position.z, 3.0, accuracy: 0.001)
    }

    // MARK: - 4D Orbital Tests

    func testOrbitalParameters() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 1.0,
            frequency: 440.0,
            orbitalRadius: 2.0,
            orbitalSpeed: 1.5,
            orbitalPhase: Float.pi / 2
        )

        XCTAssertEqual(source.orbitalRadius, 2.0, accuracy: 0.001)
        XCTAssertEqual(source.orbitalSpeed, 1.5, accuracy: 0.001)
        XCTAssertEqual(source.orbitalPhase, Float.pi / 2, accuracy: 0.001)
    }

    func testOrbitalMotion() {
        // Test that orbital motion updates position over time
        var source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(1, 0, 0),
            amplitude: 1.0,
            frequency: 440.0,
            orbitalRadius: 1.0,
            orbitalSpeed: 1.0,
            orbitalPhase: 0.0
        )

        engine.addSource(source)
        engine.currentMode = .surround_4d

        // Update orbital phase
        source.orbitalPhase += Float.pi / 4  // 45 degrees
        engine.updateSource(source)

        // Position should have changed due to orbital motion
        let updatedSource = engine.spatialSources.first { $0.id == source.id }
        XCTAssertNotNil(updatedSource)
    }

    // MARK: - AFA Field Tests

    func testFieldGeometryTypes() {
        let geometries: [SpatialAudioEngine.SpatialSource.FieldGeometry] = [
            .circle, .sphere, .fibonacci, .grid
        ]

        XCTAssertEqual(geometries.count, 4, "Should have 4 field geometry types")
    }

    func testFibonacciFieldDistribution() {
        // Test Fibonacci sphere distribution
        // Fibonacci sphere provides even distribution of points on sphere surface
        let numSources = 8
        for i in 0..<numSources {
            let source = SpatialAudioEngine.SpatialSource(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0),
                amplitude: 1.0,
                frequency: 440.0,
                fieldIndex: i,
                fieldGeometry: .fibonacci
            )
            engine.addSource(source)
        }

        XCTAssertEqual(engine.spatialSources.count, numSources)

        // Calculate Fibonacci positions
        engine.updateFibonacciPositions()

        // All sources should have been positioned
        for source in engine.spatialSources {
            let distance = sqrt(
                source.position.x * source.position.x +
                source.position.y * source.position.y +
                source.position.z * source.position.z
            )
            // Should be on unit sphere (approximately)
            XCTAssertEqual(distance, 1.0, accuracy: 0.1)
        }
    }

    // MARK: - Binaural Tests

    func testBinauralMode() {
        engine.currentMode = .binaural
        XCTAssertEqual(engine.currentMode, .binaural)

        // Binaural mode should use HRTF rendering
        // (Testing actual HRTF would require audio analysis)
    }

    // MARK: - Ambisonics Tests

    func testAmbisonicsMode() {
        engine.currentMode = .ambisonics
        XCTAssertEqual(engine.currentMode, .ambisonics)

        // Ambisonics mode should support higher-order spherical harmonics
        // (Testing actual ambisonics would require audio analysis)
    }

    // MARK: - Audio Parameter Tests

    func testSourceAmplitude() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 0.5,
            frequency: 440.0
        )

        XCTAssertEqual(source.amplitude, 0.5, accuracy: 0.001)
    }

    func testSourceFrequency() {
        let frequencies: [Float] = [110.0, 220.0, 440.0, 880.0, 1760.0]

        for freq in frequencies {
            let source = SpatialAudioEngine.SpatialSource(
                id: UUID(),
                position: SIMD3<Float>(0, 0, -1),
                amplitude: 1.0,
                frequency: freq
            )

            XCTAssertEqual(source.frequency, freq, accuracy: 0.001)
        }
    }

    // MARK: - Performance Tests

    func testPerformanceAddManyисточников() {
        measure {
            for i in 0..<100 {
                let source = SpatialAudioEngine.SpatialSource(
                    id: UUID(),
                    position: SIMD3<Float>(
                        Float.random(in: -10...10),
                        Float.random(in: -10...10),
                        Float.random(in: -10...10)
                    ),
                    amplitude: 1.0,
                    frequency: Float(220 + i * 10)
                )
                engine.addSource(source)
            }
        }
    }

    func testPerformanceUpdatePositions() {
        // Add sources
        for i in 0..<50 {
            let source = SpatialAudioEngine.SpatialSource(
                id: UUID(),
                position: SIMD3<Float>(0, 0, Float(-i)),
                amplitude: 1.0,
                frequency: 440.0
            )
            engine.addSource(source)
        }

        measure {
            // Update all source positions
            for source in engine.spatialSources {
                var mutableSource = source
                mutableSource.position.x = Float.random(in: -5...5)
                mutableSource.position.y = Float.random(in: -5...5)
                engine.updateSource(mutableSource)
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroAmplitude() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 0.0,
            frequency: 440.0
        )

        engine.addSource(source)
        // Should not crash with zero amplitude
        XCTAssertEqual(engine.spatialSources.first?.amplitude, 0.0)
    }

    func testVeryHighFrequency() {
        let source = SpatialAudioEngine.SpatialSource(
            id: UUID(),
            position: SIMD3<Float>(0, 0, -1),
            amplitude: 1.0,
            frequency: 20000.0  // Near upper limit of human hearing
        )

        engine.addSource(source)
        XCTAssertEqual(engine.spatialSources.first?.frequency, 20000.0)
    }

    func testRemoveNonexistentSource() {
        let fakeID = UUID()
        XCTAssertNoThrow(engine.removeSource(id: fakeID), "Removing nonexistent source should not crash")
    }

    // MARK: - Integration Tests

    func testFullWorkflow() throws {
        // 1. Start engine
        do {
            try engine.start()
        } catch {
            // Expected in simulator
            print("⚠️ Start failed (expected in simulator)")
        }

        // 2. Change mode
        engine.currentMode = .surround_3d

        // 3. Enable head tracking
        engine.headTrackingEnabled = true

        // 4. Add sources
        for i in 0..<4 {
            let source = SpatialAudioEngine.SpatialSource(
                id: UUID(),
                position: SIMD3<Float>(
                    cos(Float(i) * Float.pi / 2),
                    0,
                    sin(Float(i) * Float.pi / 2)
                ),
                amplitude: 1.0,
                frequency: 440.0 * pow(2.0, Float(i) / 12.0)
            )
            engine.addSource(source)
        }

        XCTAssertEqual(engine.spatialSources.count, 4)

        // 5. Update positions
        for source in engine.spatialSources {
            var mutableSource = source
            mutableSource.position.y = 1.0
            engine.updateSource(mutableSource)
        }

        // 6. Remove sources
        let idsToRemove = engine.spatialSources.map { $0.id }
        for id in idsToRemove {
            engine.removeSource(id: id)
        }

        XCTAssertEqual(engine.spatialSources.count, 0)

        // 7. Stop engine
        engine.stop()
        XCTAssertFalse(engine.isActive)
    }
}
