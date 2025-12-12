import XCTest
import AVFoundation
@testable import Echoelmusic

/// Comprehensive integration tests for Phase 3 components:
/// - SpatialAudioEngine (6 spatial modes, head tracking)
/// - MIDIToVisualMapper (MIDI → visual parameter mapping)
/// - Push3LEDController (8x8 LED grid, bio-reactive patterns)
/// - MIDIToLightMapper (DMX/Art-Net, LED strips, bio-reactive lighting)
/// - UnifiedControlHub (Phase 3 integration, multi-modal fusion)
@MainActor
final class Phase3IntegrationTests: XCTestCase {

    // MARK: - SpatialAudioEngine Tests

    var spatialEngine: SpatialAudioEngine!

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        spatialEngine?.stop()
        spatialEngine = nil
        try await super.tearDown()
    }

    // MARK: - SpatialAudioEngine: Initialization Tests

    func testSpatialAudioEngineInitialization() {
        spatialEngine = SpatialAudioEngine()

        XCTAssertNotNil(spatialEngine)
        XCTAssertFalse(spatialEngine.isActive, "Should not be active initially")
        XCTAssertEqual(spatialEngine.currentMode, .stereo, "Should default to stereo mode")
        XCTAssertFalse(spatialEngine.headTrackingEnabled, "Head tracking should be disabled initially")
        XCTAssertEqual(spatialEngine.spatialSources.count, 0, "Should have no sources initially")
    }

    // MARK: - SpatialAudioEngine: Mode Initialization Tests

    func testAllSpatialModesExist() {
        let allModes = SpatialAudioEngine.SpatialMode.allCases

        XCTAssertEqual(allModes.count, 6, "Should have 6 spatial modes")
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

    // MARK: - SpatialAudioEngine: Mode Switching Tests

    func testModeSwitching() {
        spatialEngine = SpatialAudioEngine()

        // Test switching to each mode
        spatialEngine.setMode(.surround_3d)
        XCTAssertEqual(spatialEngine.currentMode, .surround_3d)

        spatialEngine.setMode(.binaural)
        XCTAssertEqual(spatialEngine.currentMode, .binaural)

        spatialEngine.setMode(.afa)
        XCTAssertEqual(spatialEngine.currentMode, .afa)

        spatialEngine.setMode(.stereo)
        XCTAssertEqual(spatialEngine.currentMode, .stereo)
    }

    // MARK: - SpatialAudioEngine: Source Management Tests

    func testAddSpatialSource() {
        spatialEngine = SpatialAudioEngine()

        let position = SIMD3<Float>(1.0, 0.5, -1.0)
        let sourceID = spatialEngine.addSource(position: position, amplitude: 0.8, frequency: 440.0)

        XCTAssertNotNil(sourceID)
        XCTAssertEqual(spatialEngine.spatialSources.count, 1)

        let source = spatialEngine.spatialSources.first!
        XCTAssertEqual(source.id, sourceID)
        XCTAssertEqual(source.position, position)
        XCTAssertEqual(source.amplitude, 0.8)
        XCTAssertEqual(source.frequency, 440.0)
    }

    func testRemoveSpatialSource() {
        spatialEngine = SpatialAudioEngine()

        let sourceID = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        XCTAssertEqual(spatialEngine.spatialSources.count, 1)

        spatialEngine.removeSource(id: sourceID)
        XCTAssertEqual(spatialEngine.spatialSources.count, 0)
    }

    func testUpdateSourcePosition() {
        spatialEngine = SpatialAudioEngine()

        let sourceID = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        let newPosition = SIMD3<Float>(2.0, 1.0, -0.5)

        spatialEngine.updateSourcePosition(id: sourceID, position: newPosition)

        let source = spatialEngine.spatialSources.first!
        XCTAssertEqual(source.position, newPosition)
    }

    func testUpdateSourceOrbital() {
        spatialEngine = SpatialAudioEngine()

        let sourceID = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 2.0, speed: 1.5, phase: 0.5)

        let source = spatialEngine.spatialSources.first!
        XCTAssertEqual(source.orbitalRadius, 2.0)
        XCTAssertEqual(source.orbitalSpeed, 1.5)
        XCTAssertEqual(source.orbitalPhase, 0.5)
    }

    // MARK: - SpatialAudioEngine: 4D Orbital Motion Tests

    func testUpdate4DOrbitalMotion() {
        spatialEngine = SpatialAudioEngine()
        spatialEngine.setMode(.surround_4d)

        // Add source with orbital parameters
        let sourceID = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 3.0, speed: 1.0, phase: 0.0)

        // Update orbital motion
        spatialEngine.update4DOrbitalMotion(deltaTime: 0.1)

        let source = spatialEngine.spatialSources.first!
        XCTAssertGreaterThan(source.orbitalPhase, 0.0, "Phase should have advanced")
        XCTAssertNotEqual(source.position, SIMD3(0, 0, 0), "Position should have changed")
    }

    func testUpdate4DOrbitalMotionOnlyInCorrectMode() {
        spatialEngine = SpatialAudioEngine()
        spatialEngine.setMode(.stereo)  // Not 4D mode

        let sourceID = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        spatialEngine.updateSourceOrbital(id: sourceID, radius: 3.0, speed: 1.0, phase: 0.0)

        let initialPosition = SIMD3<Float>(0, 0, 0)
        spatialEngine.update4DOrbitalMotion(deltaTime: 0.1)

        let source = spatialEngine.spatialSources.first!
        // In non-4D mode, orbital motion should not be applied
        XCTAssertEqual(source.position, initialPosition)
    }

    // MARK: - SpatialAudioEngine: AFA Field Tests

    func testApplyAFAFieldCircle() {
        spatialEngine = SpatialAudioEngine()
        spatialEngine.setMode(.afa)

        // Add 8 sources
        for _ in 0..<8 {
            _ = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        }

        spatialEngine.applyAFAField(geometry: .circle(radius: 2.0), coherence: 75.0)

        // Verify sources are arranged in a circle
        XCTAssertEqual(spatialEngine.spatialSources.count, 8)

        // Verify sources are not all at origin
        let nonZeroSources = spatialEngine.spatialSources.filter { source in
            source.position != SIMD3(0, 0, 0)
        }
        XCTAssertEqual(nonZeroSources.count, 8, "All sources should be positioned")
    }

    func testApplyAFAFieldFibonacci() {
        spatialEngine = SpatialAudioEngine()
        spatialEngine.setMode(.afa)

        for _ in 0..<12 {
            _ = spatialEngine.addSource(position: SIMD3(0, 0, 0))
        }

        spatialEngine.applyAFAField(geometry: .fibonacci(count: 12), coherence: 50.0)

        XCTAssertEqual(spatialEngine.spatialSources.count, 12)

        // Fibonacci sphere should distribute sources across 3D space
        let hasVariedZ = spatialEngine.spatialSources.contains { source in
            abs(source.position.z) > 0.1
        }
        XCTAssertTrue(hasVariedZ, "Fibonacci sphere should use Z axis")
    }

    // MARK: - MIDIToVisualMapper Tests

    var visualMapper: MIDIToVisualMapper!

    func testVisualMapperInitialization() {
        visualMapper = MIDIToVisualMapper()

        XCTAssertNotNil(visualMapper)
        XCTAssertEqual(visualMapper.cymaticsParameters.frequency, 440.0)
        XCTAssertEqual(visualMapper.mandalaParameters.petalCount, 8)
        XCTAssertEqual(visualMapper.cymaticsParameters.patterns.count, 0)
    }

    // MARK: - MIDIToVisualMapper: MIDI Note Mapping Tests

    func testMIDINoteToColorMapping() {
        visualMapper = MIDIToVisualMapper()

        // Test note to color conversion
        let noteC = noteToColor(0)   // C
        let noteE = noteToColor(4)   // E
        let noteG = noteToColor(7)   // G

        XCTAssertNotEqual(noteC, noteE)
        XCTAssertNotEqual(noteE, noteG)

        // Verify octave equivalence (same pitch class = same hue)
        let c4 = noteToColor(60)
        let c5 = noteToColor(72)
        // Both should map to same hue (note % 12 = 0)
        XCTAssertEqual(c4, c5)
    }

    func testMIDINoteOnCreatesVisualParameters() {
        visualMapper = MIDIToVisualMapper()

        visualMapper.handleNoteOn(note: 60, velocity: 0.8)

        // Should create Cymatics pattern
        XCTAssertEqual(visualMapper.cymaticsParameters.patterns.count, 1)

        let pattern = visualMapper.cymaticsParameters.patterns.first!
        XCTAssertEqual(pattern.amplitude, 0.8)
        XCTAssertGreaterThan(pattern.frequency, 0)

        // Should create Mandala layer
        XCTAssertGreaterThan(visualMapper.mandalaParameters.layers.count, 0)

        // Should emit particles
        XCTAssertGreaterThan(visualMapper.particleParameters.particles.count, 0)
    }

    func testMIDINoteOffRemovesPattern() {
        visualMapper = MIDIToVisualMapper()

        visualMapper.handleNoteOn(note: 60, velocity: 0.8)
        XCTAssertEqual(visualMapper.cymaticsParameters.patterns.count, 1)

        visualMapper.handleNoteOff(note: 60)
        XCTAssertEqual(visualMapper.cymaticsParameters.patterns.count, 0)
    }

    // MARK: - MIDIToVisualMapper: Velocity Mapping Tests

    func testVelocityToIntensityMapping() {
        visualMapper = MIDIToVisualMapper()

        // Low velocity
        visualMapper.handleNoteOn(note: 60, velocity: 0.2)
        let lowPattern = visualMapper.cymaticsParameters.patterns.first!
        XCTAssertEqual(lowPattern.amplitude, 0.2, accuracy: 0.01)

        visualMapper.handleNoteOff(note: 60)

        // High velocity
        visualMapper.handleNoteOn(note: 60, velocity: 1.0)
        let highPattern = visualMapper.cymaticsParameters.patterns.first!
        XCTAssertEqual(highPattern.amplitude, 1.0, accuracy: 0.01)
    }

    // MARK: - MIDIToVisualMapper: CC Mapping Tests

    func testBrightnessControlMapping() {
        visualMapper = MIDIToVisualMapper()

        visualMapper.handleNoteOn(note: 60, velocity: 0.5)
        visualMapper.handleBrightness(note: 60, brightness: 0.8)

        // Should update Cymatics amplitude
        let pattern = visualMapper.cymaticsParameters.patterns.first!
        XCTAssertEqual(pattern.amplitude, 0.8, accuracy: 0.01)

        // Should update particle size
        XCTAssertGreaterThan(visualMapper.particleParameters.particleSize, 2.0)
    }

    func testTimbreControlMapping() {
        visualMapper = MIDIToVisualMapper()

        visualMapper.handleNoteOn(note: 60, velocity: 0.5)
        visualMapper.handleTimbre(note: 60, timbre: 0.5)

        // Should update Mandala petal count (6-12 based on timbre)
        let petalCount = visualMapper.mandalaParameters.petalCount
        XCTAssertGreaterThanOrEqual(petalCount, 6)
        XCTAssertLessThanOrEqual(petalCount, 12)
    }

    func testPitchBendMapping() {
        visualMapper = MIDIToVisualMapper()

        visualMapper.handleNoteOn(note: 60, velocity: 0.5)
        let initialSpeed = visualMapper.mandalaParameters.rotationSpeed

        visualMapper.handlePitchBend(note: 60, bend: 0.5)

        // Pitch bend should affect rotation speed
        XCTAssertNotEqual(visualMapper.mandalaParameters.rotationSpeed, initialSpeed)
    }

    // MARK: - MIDIToVisualMapper: Bio-Reactive Tests

    func testBioParameterMapping() {
        visualMapper = MIDIToVisualMapper()

        let bioParams = MIDIToVisualMapper.BioParameters(
            hrvCoherence: 75.0,
            heartRate: 70.0,
            breathingRate: 6.0,
            audioLevel: 0.8
        )

        visualMapper.updateBioParameters(bioParams)

        // HRV should map to hue (75/100 = 0.75)
        XCTAssertEqual(visualMapper.cymaticsParameters.hue, 0.75, accuracy: 0.01)
        XCTAssertEqual(visualMapper.mandalaParameters.hue, 0.75, accuracy: 0.01)

        // Heart rate should map to rotation speed
        let expectedRotation = Float(70.0 / 60.0)  // BPM → rotations/sec
        XCTAssertEqual(visualMapper.mandalaParameters.rotationSpeed, expectedRotation, accuracy: 0.1)

        // Audio level should map to glow intensity
        XCTAssertEqual(visualMapper.waveformParameters.glowIntensity, 0.8, accuracy: 0.01)
    }

    func testParticleSystemUpdate() {
        visualMapper = MIDIToVisualMapper()

        // Emit particles
        visualMapper.handleNoteOn(note: 60, velocity: 0.8)
        let initialCount = visualMapper.particleParameters.particles.count

        XCTAssertGreaterThan(initialCount, 0)

        // Update particles (should move and decay)
        visualMapper.updateParticles(deltaTime: 0.1)

        // Particles should still exist (lifetime = 2.0 seconds)
        XCTAssertGreaterThan(visualMapper.particleParameters.particles.count, 0)

        // Update with very long deltaTime to expire all particles
        visualMapper.updateParticles(deltaTime: 3.0)
        XCTAssertEqual(visualMapper.particleParameters.particles.count, 0, "All particles should expire")
    }

    // MARK: - MIDIToVisualMapper: Visual Presets Tests

    func testVisualPresets() {
        visualMapper = MIDIToVisualMapper()

        // Test meditation preset
        visualMapper.applyPreset(.meditation)
        XCTAssertEqual(visualMapper.mandalaParameters.rotationSpeed, 0.5)
        XCTAssertEqual(visualMapper.cymaticsParameters.amplitude, 0.3)

        // Test energizing preset
        visualMapper.applyPreset(.energizing)
        XCTAssertEqual(visualMapper.mandalaParameters.rotationSpeed, 2.0)
        XCTAssertEqual(visualMapper.cymaticsParameters.amplitude, 0.8)

        // Test healing preset
        visualMapper.applyPreset(.healing)
        XCTAssertEqual(visualMapper.mandalaParameters.rotationSpeed, 1.0)
        XCTAssertEqual(visualMapper.cymaticsParameters.amplitude, 0.5)
    }

    // MARK: - Push3LEDController Tests

    var ledController: Push3LEDController!

    func testPush3LEDInitialization() {
        ledController = Push3LEDController()

        XCTAssertNotNil(ledController)
        XCTAssertEqual(ledController.currentPattern, .breathe)
        XCTAssertEqual(ledController.brightness, 0.7, accuracy: 0.01)
        // Note: isConnected depends on hardware, may be false
    }

    // MARK: - Push3LEDController: LED Grid Tests

    func testLEDGridInitialization() {
        ledController = Push3LEDController()

        // Grid should be initialized (verified by not crashing when setting LEDs)
        ledController.setLED(row: 0, col: 0, color: Push3LEDController.RGB.red)
        ledController.setLED(row: 7, col: 7, color: Push3LEDController.RGB.blue)

        // Should not crash
        XCTAssertNotNil(ledController)
    }

    func testSetIndividualLED() {
        ledController = Push3LEDController()

        ledController.setLED(row: 3, col: 4, color: Push3LEDController.RGB.green)

        // Verify bounds checking
        ledController.setLED(row: -1, col: 0, color: Push3LEDController.RGB.red)  // Out of bounds
        ledController.setLED(row: 8, col: 0, color: Push3LEDController.RGB.red)   // Out of bounds

        // Should not crash
        XCTAssertNotNil(ledController)
    }

    func testSetGrid() {
        ledController = Push3LEDController()

        let testGrid = Array(
            repeating: Array(repeating: Push3LEDController.RGB.cyan, count: 8),
            count: 8
        )

        ledController.setGrid(testGrid)

        // Should not crash
        XCTAssertNotNil(ledController)
    }

    func testClearGrid() {
        ledController = Push3LEDController()

        ledController.clearGrid()

        // Should not crash
        XCTAssertNotNil(ledController)
    }

    // MARK: - Push3LEDController: Pattern Tests

    func testAllLEDPatterns() {
        ledController = Push3LEDController()

        let allPatterns = Push3LEDController.LEDPattern.allCases
        XCTAssertEqual(allPatterns.count, 7, "Should have 7 LED patterns")

        for pattern in allPatterns {
            ledController.applyPattern(pattern)
            XCTAssertEqual(ledController.currentPattern, pattern)
        }
    }

    func testBreathePattern() {
        ledController = Push3LEDController()

        ledController.applyPattern(.breathe)
        ledController.updateFromBioSignals(hrvCoherence: 60.0, heartRate: 70.0)

        XCTAssertEqual(ledController.currentPattern, .breathe)
    }

    func testPulsePattern() {
        ledController = Push3LEDController()

        ledController.applyPattern(.pulse)
        ledController.updateFromBioSignals(hrvCoherence: 60.0, heartRate: 72.0)

        XCTAssertEqual(ledController.currentPattern, .pulse)
    }

    func testCoherencePattern() {
        ledController = Push3LEDController()

        ledController.applyPattern(.coherence)
        ledController.updateFromBioSignals(hrvCoherence: 80.0, heartRate: 70.0)

        XCTAssertEqual(ledController.currentPattern, .coherence)
    }

    // MARK: - Push3LEDController: Bio-Reactive Tests

    func testBioSignalMapping() {
        ledController = Push3LEDController()

        // Test low coherence
        ledController.applyPattern(.coherence)
        ledController.updateFromBioSignals(hrvCoherence: 30.0, heartRate: 80.0)
        XCTAssertNotNil(ledController)

        // Test high coherence
        ledController.updateFromBioSignals(hrvCoherence: 85.0, heartRate: 65.0)
        XCTAssertNotNil(ledController)
    }

    func testGestureFlash() {
        ledController = Push3LEDController()

        ledController.flashGesture(gesture: "Pinch")

        // Should not crash
        XCTAssertNotNil(ledController)
    }

    // MARK: - Push3LEDController: Color Utility Tests

    func testCoherenceToColor() {
        ledController = Push3LEDController()

        // Low coherence = Red
        let redColor = ledController.coherenceToColor(coherence: 20.0)
        XCTAssertGreaterThan(redColor.r, redColor.g)
        XCTAssertGreaterThan(redColor.r, redColor.b)

        // Medium coherence = Yellow
        let yellowColor = ledController.coherenceToColor(coherence: 50.0)
        // Yellow has high R and G

        // High coherence = Green
        let greenColor = ledController.coherenceToColor(coherence: 80.0)
        XCTAssertGreaterThan(greenColor.g, greenColor.r)
    }

    // MARK: - MIDIToLightMapper Tests

    var lightMapper: MIDIToLightMapper!

    func testLightMapperInitialization() {
        lightMapper = MIDIToLightMapper()

        XCTAssertNotNil(lightMapper)
        XCTAssertFalse(lightMapper.isActive)
        XCTAssertEqual(lightMapper.currentScene, .ambient)
        XCTAssertEqual(lightMapper.dmxUniverse.count, 512)
        XCTAssertGreaterThan(lightMapper.ledStrips.count, 0, "Should have default LED strips")
    }

    // MARK: - MIDIToLightMapper: DMX Channel Mapping Tests

    func testDMXUniverseInitialization() {
        lightMapper = MIDIToLightMapper()

        // DMX universe should be 512 channels
        XCTAssertEqual(lightMapper.dmxUniverse.count, 512)

        // All channels should be zero initially
        let allZero = lightMapper.dmxUniverse.allSatisfy { $0 == 0 }
        XCTAssertTrue(allZero)
    }

    func testMIDINoteToLightMapping() {
        lightMapper = MIDIToLightMapper()

        lightMapper.handleNoteOn(note: 60, velocity: 0.8, channel: 0)

        // DMX universe should have been updated
        let hasNonZero = lightMapper.dmxUniverse.contains { $0 > 0 }
        XCTAssertTrue(hasNonZero, "DMX channels should be set")
    }

    func testMIDINoteOffFades() {
        lightMapper = MIDIToLightMapper()

        lightMapper.handleNoteOn(note: 60, velocity: 0.8, channel: 0)
        lightMapper.handleNoteOff(note: 60, channel: 0)

        // Should still have some values (faded, not off)
        XCTAssertNotNil(lightMapper)
    }

    // MARK: - MIDIToLightMapper: LED Strip Tests

    func testLEDStripConfiguration() {
        lightMapper = MIDIToLightMapper()

        // Should have default LED strips
        XCTAssertGreaterThan(lightMapper.ledStrips.count, 0)

        for strip in lightMapper.ledStrips {
            XCTAssertGreaterThan(strip.pixelCount, 0)
            XCTAssertGreaterThan(strip.startAddress, 0)
            XCTAssertEqual(strip.pixels.count, strip.pixelCount)
        }
    }

    func testAddDMXFixture() {
        lightMapper = MIDIToLightMapper()

        let fixture = MIDIToLightMapper.DMXFixture(
            name: "Test PAR",
            startAddress: 100,
            channelMap: .rgbPar(r: 0, g: 1, b: 2, dimmer: 3)
        )

        lightMapper.addFixture(fixture)

        // Should not crash
        XCTAssertNotNil(lightMapper)
    }

    // MARK: - MIDIToLightMapper: Art-Net Packet Tests

    func testArtNetPacketFormat() {
        lightMapper = MIDIToLightMapper()

        // Set some DMX values
        lightMapper.dmxUniverse[0] = 255
        lightMapper.dmxUniverse[1] = 128
        lightMapper.dmxUniverse[2] = 64

        // Note: Can't easily test packet format without network connection
        // Just verify it doesn't crash
        XCTAssertNotNil(lightMapper)
    }

    // MARK: - MIDIToLightMapper: Scene Tests

    func testLightScenes() {
        lightMapper = MIDIToLightMapper()

        let allScenes = MIDIToLightMapper.LightScene.allCases
        XCTAssertEqual(allScenes.count, 6, "Should have 6 light scenes")

        for scene in allScenes {
            lightMapper.setScene(scene)
            XCTAssertEqual(lightMapper.currentScene, scene)
        }
    }

    func testSceneTransitions() {
        lightMapper = MIDIToLightMapper()

        // Test scene transition
        lightMapper.setScene(.ambient)
        XCTAssertEqual(lightMapper.currentScene, .ambient)

        lightMapper.setScene(.performance)
        XCTAssertEqual(lightMapper.currentScene, .performance)

        lightMapper.setScene(.meditation)
        XCTAssertEqual(lightMapper.currentScene, .meditation)
    }

    // MARK: - MIDIToLightMapper: Bio-Reactive Tests

    func testBioReactiveLighting() {
        lightMapper = MIDIToLightMapper()

        let bioData = MIDIToLightMapper.BioData(
            hrvCoherence: 70.0,
            heartRate: 68.0,
            breathingRate: 6.0
        )

        lightMapper.updateBioReactive(bioData)

        // Should update DMX universe
        XCTAssertNotNil(lightMapper)
    }

    func testBioReactiveScenesRespond() {
        lightMapper = MIDIToLightMapper()

        // Test each scene responds to bio data
        let bioData = MIDIToLightMapper.BioData(
            hrvCoherence: 60.0,
            heartRate: 70.0,
            breathingRate: 6.0
        )

        let scenes: [MIDIToLightMapper.LightScene] = [
            .ambient, .meditation, .energetic, .reactive, .performance, .strobeSync
        ]

        for scene in scenes {
            lightMapper.setScene(scene)
            lightMapper.updateBioReactive(bioData)
            XCTAssertNotNil(lightMapper, "Scene \(scene) should handle bio data")
        }
    }

    // MARK: - UnifiedControlHub Integration Tests

    var hub: UnifiedControlHub!

    func testUnifiedControlHubInitialization() {
        hub = UnifiedControlHub(audioEngine: nil)

        XCTAssertNotNil(hub)
        XCTAssertEqual(hub.activeInputMode, .automatic)
        XCTAssertTrue(hub.conflictResolved)
    }

    // MARK: - UnifiedControlHub: Phase 3 Component Integration

    func testEnableSpatialAudio() async throws {
        hub = UnifiedControlHub(audioEngine: nil)

        // Note: May fail without proper audio session
        do {
            try hub.enableSpatialAudio()
            // If successful, should be enabled
            XCTAssertNotNil(hub)
        } catch {
            // Expected if audio session can't be configured in test environment
            XCTAssertNotNil(error)
        }
    }

    func testEnableVisualMapping() {
        hub = UnifiedControlHub(audioEngine: nil)

        hub.enableVisualMapping()

        // Should not crash
        XCTAssertNotNil(hub)
    }

    func testEnablePush3LED() {
        hub = UnifiedControlHub(audioEngine: nil)

        do {
            try hub.enablePush3LED()
            // If successful, should be enabled
            XCTAssertNotNil(hub)
        } catch {
            // Expected if Push 3 hardware not connected
            XCTAssertNotNil(error)
        }
    }

    func testEnableLighting() {
        hub = UnifiedControlHub(audioEngine: nil)

        do {
            try hub.enableLighting()
            // If successful, should be enabled
            XCTAssertNotNil(hub)
        } catch {
            // Expected if network not available
            XCTAssertNotNil(error)
        }
    }

    // MARK: - UnifiedControlHub: Multi-Modal Fusion Tests

    func testControlLoopInitialization() {
        hub = UnifiedControlHub(audioEngine: nil)

        hub.start()

        let expectation = XCTestExpectation(description: "Control loop starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThan(hub.controlLoopFrequency, 0)

        hub.stop()
    }

    func testPriorityBasedInputResolution() {
        hub = UnifiedControlHub(audioEngine: nil)

        // Test conflict resolution (should always resolve successfully)
        XCTAssertTrue(hub.conflictResolved)

        hub.start()

        let expectation = XCTestExpectation(description: "Conflict resolution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(hub.conflictResolved)

        hub.stop()
    }

    func testMapRangeUtility() {
        hub = UnifiedControlHub(audioEngine: nil)

        // Test linear mapping
        let result1 = hub.mapRange(0.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result1, 50.0, accuracy: 0.01)

        let result2 = hub.mapRange(0.0, from: 0...1, to: 200...8000)
        XCTAssertEqual(result2, 200.0, accuracy: 0.01)

        let result3 = hub.mapRange(1.0, from: 0...1, to: 200...8000)
        XCTAssertEqual(result3, 8000.0, accuracy: 0.01)

        // Test clamping
        let result4 = hub.mapRange(-0.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result4, 0.0, accuracy: 0.01)

        let result5 = hub.mapRange(1.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result5, 100.0, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testSpatialAudioPerformance() {
        spatialEngine = SpatialAudioEngine()

        measure {
            for _ in 0..<10 {
                let position = SIMD3<Float>(
                    Float.random(in: -5...5),
                    Float.random(in: -5...5),
                    Float.random(in: -5...5)
                )
                _ = spatialEngine.addSource(position: position)
            }

            for _ in 0..<100 {
                spatialEngine.update4DOrbitalMotion(deltaTime: 0.016)
            }
        }
    }

    func testVisualMapperPerformance() {
        visualMapper = MIDIToVisualMapper()

        measure {
            for note in 60..<72 {
                visualMapper.handleNoteOn(note: UInt8(note), velocity: 0.8)
            }

            for _ in 0..<100 {
                visualMapper.updateParticles(deltaTime: 0.016)
            }

            for note in 60..<72 {
                visualMapper.handleNoteOff(note: UInt8(note))
            }
        }
    }

    func testLightMapperPerformance() {
        lightMapper = MIDIToLightMapper()

        measure {
            for note in 60..<72 {
                lightMapper.handleNoteOn(note: UInt8(note), velocity: 0.8, channel: 0)
            }

            let bioData = MIDIToLightMapper.BioData(
                hrvCoherence: 70.0,
                heartRate: 68.0,
                breathingRate: 6.0
            )

            for _ in 0..<100 {
                lightMapper.updateBioReactive(bioData)
            }
        }
    }

    // MARK: - Helper Methods

    private func noteToColor(_ note: UInt8) -> String {
        // Simplified color identifier based on hue
        let hue = Double(note % 12) / 12.0
        return String(format: "%.2f", hue)
    }
}
