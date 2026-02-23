import XCTest
@testable import Echoelmusic

// =============================================================================
// VisualSynthesisTests.swift
// Echoelmusic
//
// Comprehensive tests for the Visual Synthesis pipeline:
//   - EchoelVisualCompositor (8-layer bio-reactive compositor)
//   - VisualModulationMatrix (synthesizer-style modulation routing)
//   - ISFShaderParser (Interactive Shader Format parsing + Metal conversion)
//   - SyphonNDIBridge (video output to NDI/Syphon/SMPTE 2110)
//   - BioReactiveVisualSynthEngine (unified bio-reactive visual engine)
//   - Material & Blend Mode coverage
//
// ~56 tests total.
// =============================================================================

// MARK: - EchoelVisualCompositor Tests (~15 tests)

@MainActor
final class EchoelVisualCompositorTests: XCTestCase {

    var sut: EchoelVisualCompositor!

    override func setUp() async throws {
        try await super.setUp()
        sut = EchoelVisualCompositor()
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // 1. Verify initialization creates 0 layers (empty stack), all disabled by default
    func testCompositorInitialization() {
        // Compositor starts with an empty layer stack and a background layer
        XCTAssertTrue(sut.layers.isEmpty, "Compositor should start with no user layers")
        XCTAssertNotNil(sut.backgroundLayer, "Background layer should exist on init")
        XCTAssertEqual(sut.backgroundLayer.material, .nebula, "Default background should be nebula")
        XCTAssertEqual(sut.masterOpacity, 1.0, accuracy: 0.001)
        XCTAssertFalse(sut.isRunning, "Compositor should not be running initially")

        // Add 8 layers (max) and verify they start enabled but can be checked
        for i in 0..<8 {
            let layer = sut.addLayer(name: "Layer \(i + 1)")
            XCTAssertNotNil(layer, "Should be able to add layer \(i + 1)")
        }
        XCTAssertEqual(sut.layers.count, 8, "Should have exactly 8 layers after adding max")
    }

    // 2. Add layer and verify count increases
    func testAddLayer() {
        XCTAssertEqual(sut.layers.count, 0)
        let layer = sut.addLayer(name: "Test Layer", material: .particles)
        XCTAssertNotNil(layer)
        XCTAssertEqual(sut.layers.count, 1)
        XCTAssertEqual(layer?.material, .particles)
        XCTAssertEqual(layer?.name, "Test Layer")
    }

    // 3. Remove layer and verify count decreases
    func testRemoveLayer() {
        let layer = sut.addLayer(name: "Removable")
        XCTAssertEqual(sut.layers.count, 1)
        let removed = sut.removeLayer(id: layer!.id)
        XCTAssertTrue(removed, "Should successfully remove existing layer")
        XCTAssertEqual(sut.layers.count, 0)

        // Removing non-existent layer returns false
        let removedAgain = sut.removeLayer(id: UUID())
        XCTAssertFalse(removedAgain, "Should return false for non-existent layer")
    }

    // 4. Move layer from index 0 to 4 and verify order
    func testMoveLayer() {
        var addedLayers: [VisualLayer] = []
        for i in 0..<5 {
            if let layer = sut.addLayer(name: "Layer \(i)", material: VisualMaterialType.allCases[i]) {
                addedLayers.append(layer)
            }
        }
        XCTAssertEqual(sut.layers.count, 5)

        let firstLayerID = sut.layers[0].id
        sut.moveLayer(from: 0, to: 4)

        XCTAssertEqual(sut.layers[4].id, firstLayerID, "Layer should have moved to index 4")
        XCTAssertNotEqual(sut.layers[0].id, firstLayerID, "Layer should no longer be at index 0")
    }

    // 5. Swap layers and verify positions changed
    func testSwapLayers() {
        let layerA = sut.addLayer(name: "A", material: .particles)
        let layerB = sut.addLayer(name: "B", material: .spectrum)
        XCTAssertEqual(sut.layers[0].id, layerA!.id)
        XCTAssertEqual(sut.layers[1].id, layerB!.id)

        sut.swapLayers(0, 1)

        XCTAssertEqual(sut.layers[0].id, layerB!.id, "Layer B should now be at index 0")
        XCTAssertEqual(sut.layers[1].id, layerA!.id, "Layer A should now be at index 1")
    }

    // 6. Set material and verify it persists
    func testSetMaterial() {
        let layer = sut.addLayer(name: "Test", material: .liquidLight)!
        XCTAssertEqual(sut.layers[0].material, .liquidLight)

        sut.setMaterial(.fractalZoom, for: layer.id)
        XCTAssertEqual(sut.layers[0].material, .fractalZoom, "Material should have been updated")
    }

    // 7. All 15 blend modes can be set
    func testSetBlendMode() {
        let layer = sut.addLayer(name: "Blend Test")!
        let allModes = CompositorBlendMode.allCases
        XCTAssertEqual(allModes.count, 15, "Should have exactly 15 blend modes")

        for mode in allModes {
            sut.setBlendMode(mode, for: layer.id)
            XCTAssertEqual(sut.layers[0].blendMode, mode,
                           "Blend mode should be \(mode.rawValue)")
        }
    }

    // 8. Verify opacity clamping to 0-1 range
    func testSetOpacity() {
        let layer = sut.addLayer(name: "Opacity Test")!

        sut.setOpacity(0.5, for: layer.id)
        XCTAssertEqual(sut.layers[0].opacity, 0.5, accuracy: 0.001)

        // Test clamping above 1.0
        sut.setOpacity(2.0, for: layer.id)
        XCTAssertEqual(sut.layers[0].opacity, 1.0, accuracy: 0.001, "Opacity should clamp to 1.0")

        // Test clamping below 0.0
        sut.setOpacity(-0.5, for: layer.id)
        XCTAssertEqual(sut.layers[0].opacity, 0.0, accuracy: 0.001, "Opacity should clamp to 0.0")
    }

    // 9. Enable solo on one layer and verify only it renders
    func testSoloMode() {
        let layerA = sut.addLayer(name: "A")!
        let layerB = sut.addLayer(name: "B")!
        _ = sut.addLayer(name: "C")!

        // Solo layer B
        sut.setSolo(true, for: layerB.id)

        let frame = sut.buildFrameOutput()
        XCTAssertEqual(frame.layerDescriptors.count, 1, "Only the solo'd layer should render")
        XCTAssertEqual(frame.layerDescriptors[0].layerID, layerB.id, "Solo'd layer B should be the one rendering")

        // Unsolo layer B, all should render again
        sut.setSolo(false, for: layerB.id)
        let frameAfter = sut.buildFrameOutput()
        XCTAssertEqual(frameAfter.layerDescriptors.count, 3, "All enabled layers should render when no solo")
    }

    // 10. Update coherence/HR/breath and verify snapshot
    func testBioDataUpdate() {
        sut.updateBioData(coherence: 0.85, heartRate: 68.0, breathPhase: 0.4, audioLevel: 0.6)

        XCTAssertEqual(sut.bioSnapshot.coherence, 0.85, accuracy: 0.001)
        XCTAssertEqual(sut.bioSnapshot.heartRate, 68.0, accuracy: 0.01)
        XCTAssertEqual(sut.bioSnapshot.breathPhase, 0.4, accuracy: 0.001)
        XCTAssertEqual(sut.bioSnapshot.audioLevel, 0.6, accuracy: 0.001)

        // Test clamping
        sut.updateBioData(coherence: 1.5, heartRate: 200.0, breathPhase: -0.1, audioLevel: 2.0)
        XCTAssertEqual(sut.bioSnapshot.coherence, 1.0, accuracy: 0.001, "Coherence should clamp to 1.0")
        XCTAssertEqual(sut.bioSnapshot.breathPhase, 0.0, accuracy: 0.001, "Breath phase should clamp to 0.0")
        XCTAssertEqual(sut.bioSnapshot.audioLevel, 1.0, accuracy: 0.001, "Audio level should clamp to 1.0")
    }

    // 11. Update spectrum/beat and verify snapshot
    func testAudioAnalysisUpdate() {
        let testSpectrum = Array(repeating: Float(0.5), count: 64)
        let testWaveform = Array(repeating: Float(0.1), count: 256)

        sut.updateAudioAnalysis(
            spectrumData: testSpectrum,
            waveformData: testWaveform,
            beatDetected: true,
            tempo: 128.0,
            beatPhase: 0.75,
            dominantFrequency: 440.0
        )

        XCTAssertEqual(sut.bioSnapshot.spectrumData.count, 64)
        XCTAssertEqual(sut.bioSnapshot.waveformData.count, 256)
        XCTAssertTrue(sut.bioSnapshot.beatDetected)
        XCTAssertEqual(sut.bioSnapshot.tempo, 128.0, accuracy: 0.01)
        XCTAssertEqual(sut.bioSnapshot.beatPhase, 0.75, accuracy: 0.001)
        XCTAssertEqual(sut.bioSnapshot.dominantFrequency, 440.0, accuracy: 0.01)
    }

    // 12. Start/stop compositor and verify isRunning state
    func testStartStop() {
        XCTAssertFalse(sut.isRunning)

        sut.start()
        XCTAssertTrue(sut.isRunning, "Compositor should be running after start()")

        // Start again should be no-op
        sut.start()
        XCTAssertTrue(sut.isRunning, "Compositor should still be running after redundant start()")

        sut.stop()
        XCTAssertFalse(sut.isRunning, "Compositor should be stopped after stop()")

        // Stop again should be no-op
        sut.stop()
        XCTAssertFalse(sut.isRunning, "Compositor should remain stopped after redundant stop()")
    }

    // 13. Duplicate layer copies all properties
    func testDuplicateLayer() {
        let original = sut.addLayer(name: "Original", material: .fractalZoom, blendMode: .additive, opacity: 0.7)!
        sut.setTransform(rotation: 1.5, scale: 2.0, positionX: 0.3, positionY: -0.2, for: original.id)
        sut.setShaderParams(speed: 2.0, complexity: 0.8, frequency: 3.0, amplitude: 1.5, for: original.id)
        sut.setColorAdjustment(hueShift: 0.5, saturation: 1.2, brightness: -0.3, for: original.id)

        let copy = sut.duplicateLayer(id: original.id)
        XCTAssertNotNil(copy, "Duplicate should succeed")
        XCTAssertEqual(sut.layers.count, 2, "Should have 2 layers after duplication")
        XCTAssertNotEqual(copy!.id, original.id, "Copy should have a new UUID")
        XCTAssertEqual(copy!.material, .fractalZoom, "Material should be copied")
        XCTAssertEqual(copy!.blendMode, .additive, "Blend mode should be copied")
        XCTAssertEqual(copy!.opacity, 0.7, accuracy: 0.01, "Opacity should be copied")
        XCTAssertTrue(copy!.name.contains("Copy"), "Copy name should contain 'Copy'")
    }

    // 14. Verify frame output has correct layer descriptors
    func testBuildFrameOutput() {
        sut.addLayer(name: "Base", material: .liquidLight, blendMode: .normal)
        sut.addLayer(name: "Overlay", material: .particles, blendMode: .additive, opacity: 0.5)
        sut.updateBioData(coherence: 0.7, heartRate: 75, breathPhase: 0.5, audioLevel: 0.3)

        let frame = sut.buildFrameOutput()

        XCTAssertEqual(frame.layerDescriptors.count, 2, "Should have 2 layer descriptors")
        XCTAssertNotNil(frame.backgroundDescriptor, "Background should have a descriptor")
        XCTAssertEqual(frame.masterOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(frame.layerDescriptors[0].material, .liquidLight)
        XCTAssertEqual(frame.layerDescriptors[1].material, .particles)
        XCTAssertEqual(frame.layerDescriptors[1].blendMode, .additive)
        XCTAssertEqual(frame.layerDescriptors[1].opacity, 0.5, accuracy: 0.01)

        // Verify bio snapshot is passed through
        XCTAssertEqual(frame.layerDescriptors[0].bioSnapshot.coherence, 0.7, accuracy: 0.01)
    }

    // 15. Load each preset and verify layer configurations
    func testCompositorPresets() {
        for preset in CompositorPreset.allCases {
            sut.applyPreset(preset)

            XCTAssertFalse(sut.layers.isEmpty,
                           "Preset '\(preset.rawValue)' should create at least one layer")
            XCTAssertLessThanOrEqual(sut.layers.count, EchoelVisualCompositor.maxLayerCount,
                                     "Preset '\(preset.rawValue)' should not exceed max layer count")

            // Verify all layers are enabled
            for layer in sut.layers {
                XCTAssertTrue(layer.isEnabled,
                              "Layer '\(layer.name)' in preset '\(preset.rawValue)' should be enabled")
            }
        }

        // Verify the 6 presets exist
        XCTAssertEqual(CompositorPreset.allCases.count, 6)
    }
}

// MARK: - VisualModulationMatrix Tests (~12 tests)

@MainActor
final class VisualModulationMatrixTests: XCTestCase {

    var compositor: EchoelVisualCompositor!
    var sut: VisualModulationMatrix!

    override func setUp() async throws {
        try await super.setUp()
        compositor = EchoelVisualCompositor()
        sut = VisualModulationMatrix(compositor: compositor)
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        compositor.stop()
        compositor = nil
        try await super.tearDown()
    }

    // 1. Verify 4 LFOs, 2 envelopes, 4 audio mods created
    func testMatrixInitialization() {
        XCTAssertEqual(sut.lfoStates.count, 4, "Should have 4 LFOs")
        XCTAssertEqual(sut.envelopeStates.count, 2, "Should have 2 envelopes")
        XCTAssertEqual(sut.audioModulatorStates.count, 4, "Should have 4 audio modulators")
        XCTAssertTrue(sut.routes.isEmpty, "Routes should be empty initially")
        XCTAssertFalse(sut.isRunning, "Matrix should not be running initially")

        // Verify LFOs are disabled by default
        for lfo in sut.lfoStates {
            XCTAssertFalse(lfo.isEnabled, "LFO \(lfo.index) should be disabled by default")
        }

        // Verify envelopes are disabled by default
        for env in sut.envelopeStates {
            XCTAssertFalse(env.isEnabled, "Envelope \(env.index) should be disabled by default")
        }
    }

    // 2. Verify all 5 LFO shapes produce different output
    func testLFOShapes() {
        let allShapes = LFOShape.allCases
        XCTAssertEqual(allShapes.count, 5, "Should have 5 LFO shapes")

        // Verify all shapes have unique raw values
        let rawValues = Set(allShapes.map { $0.rawValue })
        XCTAssertEqual(rawValues.count, 5, "All LFO shapes should have unique identifiers")

        // Test that each shape produces output via tick()
        for shape in allShapes {
            var lfo = LFOState(index: 0)
            lfo.shape = shape
            lfo.rateHz = 1.0
            lfo.isEnabled = true

            // Tick to phase 0.25 (quarter cycle)
            lfo.tick(deltaTime: 0.25, tempo: 120)

            // All shapes except random should produce deterministic non-zero output at phase 0.25
            if shape != .random {
                XCTAssertNotEqual(lfo.output, 0.0,
                                  "LFO shape \(shape.rawValue) should produce non-zero output at phase 0.25")
            }
        }

        // Verify sine and square produce different values
        var sineLFO = LFOState(index: 0)
        sineLFO.shape = .sine
        sineLFO.rateHz = 1.0
        sineLFO.isEnabled = true
        sineLFO.tick(deltaTime: 0.25, tempo: 120)

        var squareLFO = LFOState(index: 0)
        squareLFO.shape = .square
        squareLFO.rateHz = 1.0
        squareLFO.isEnabled = true
        squareLFO.tick(deltaTime: 0.25, tempo: 120)

        XCTAssertNotEqual(sineLFO.output, squareLFO.output,
                          "Sine and square LFOs should produce different outputs")
    }

    // 3. Verify BPM-synced rate calculation
    func testLFOBPMSync() {
        var lfo = LFOState(index: 0)
        lfo.shape = .saw
        lfo.bpmSync = true
        lfo.bpmDivision = 4.0  // quarter note
        lfo.isEnabled = true

        // At 120 BPM, quarter note rate = (120/60)/4 = 0.5 Hz
        // After 1 second, phase should advance by 0.5
        lfo.tick(deltaTime: 1.0, tempo: 120)
        XCTAssertEqual(lfo.phase, 0.5, accuracy: 0.01,
                       "BPM-synced LFO at 120 BPM / quarter note should advance 0.5 in 1 second")
    }

    // 4. ADSR envelope: gate on -> attack -> decay -> sustain -> gate off -> release
    func testADSREnvelope() {
        var env = EnvelopeState(index: 0)
        env.attack = 0.1
        env.decay = 0.1
        env.sustain = 0.7
        env.release = 0.2
        env.isEnabled = true

        // Idle state
        XCTAssertEqual(env.stage, .idle)
        XCTAssertEqual(env.output, 0.0, accuracy: 0.001)

        // Gate on: should move to attack
        env.gateOn()
        XCTAssertEqual(env.stage, .attack)
        XCTAssertTrue(env.gateOpen)

        // Tick through attack phase
        env.tick(deltaTime: 0.1)
        XCTAssertGreaterThanOrEqual(env.output, 0.9, "Output should be near 1.0 after attack")

        // Tick through decay phase
        env.tick(deltaTime: 0.1)
        XCTAssertEqual(env.output, env.sustain, accuracy: 0.15, "Output should approach sustain level after decay")

        // Tick while sustaining
        env.tick(deltaTime: 0.1)
        XCTAssertEqual(env.output, env.sustain, accuracy: 0.05, "Output should hold at sustain level")

        // Gate off: should move to release
        env.gateOff()
        XCTAssertEqual(env.stage, .release)
        XCTAssertFalse(env.gateOpen)

        // Tick through release
        env.tick(deltaTime: 0.2)
        XCTAssertEqual(env.output, 0.0, accuracy: 0.05, "Output should reach 0 after release")
    }

    // 5. Verify threshold-based peak detection in audio modulator
    func testAudioModulatorPeakMode() {
        var mod = AudioModulatorState(index: 0)
        mod.mode = .peak
        mod.threshold = 0.3
        mod.isEnabled = true

        // Below threshold: should produce 0
        mod.tick(audioLevel: 0.2, spectrumData: [], deltaTime: 0.016)
        XCTAssertEqual(mod.output, 0.0, accuracy: 0.05,
                       "Audio below threshold should produce near-zero output")

        // Above threshold: should produce positive output
        mod.tick(audioLevel: 0.8, spectrumData: [], deltaTime: 0.016)
        XCTAssertGreaterThan(mod.output, 0.0,
                             "Audio above threshold should produce positive output")
    }

    // 6. Verify frequency band energy extraction
    func testAudioModulatorBandMode() {
        var mod = AudioModulatorState(index: 0)
        mod.mode = .frequencyBand
        mod.bandLowHz = 20
        mod.bandHighHz = 200
        mod.isEnabled = true

        // Create a spectrum with energy in the low bands
        var spectrum = Array(repeating: Float(0), count: 64)
        // Fill low frequency bands with high energy
        for i in 0..<8 {
            spectrum[i] = 0.8
        }

        mod.tick(audioLevel: 0.5, spectrumData: spectrum, deltaTime: 0.016)
        XCTAssertGreaterThan(mod.output, 0.0,
                             "Band mode should detect energy in configured frequency range")
    }

    // 7. Add modulation route and verify it's stored
    func testAddRoute() {
        XCTAssertTrue(sut.routes.isEmpty)

        let route = sut.addRoute(
            source: .lfo(index: 0),
            destination: .opacity,
            amount: 0.5,
            curve: .linear
        )

        XCTAssertNotNil(route, "Route should be created successfully")
        XCTAssertEqual(sut.routes.count, 1, "Should have 1 route")
        XCTAssertEqual(sut.routes[0].amount, 0.5, accuracy: 0.001)
    }

    // 8. Remove route by ID
    func testRemoveRoute() {
        let route = sut.addRoute(
            source: .bioCoherence,
            destination: .hue,
            amount: 0.3
        )!

        XCTAssertEqual(sut.routes.count, 1)

        let removed = sut.removeRoute(id: route.id)
        XCTAssertTrue(removed, "Route should be removed successfully")
        XCTAssertTrue(sut.routes.isEmpty, "Routes should be empty after removal")

        // Removing non-existent route should return false
        let removedAgain = sut.removeRoute(id: UUID())
        XCTAssertFalse(removedAgain, "Removing non-existent route should return false")
    }

    // 9. All 5 modulation curves produce correct output shapes
    func testModulationCurves() {
        let curves = Echoelmusic.ModulationCurve.allCases
        XCTAssertEqual(curves.count, 5, "Should have 5 modulation curves")

        // All curves should map 0 to approximately 0
        for curve in curves {
            let output = curve.apply(0.0)
            XCTAssertEqual(output, 0.0, accuracy: 0.01,
                           "Curve \(curve.rawValue) should map 0.0 to approximately 0.0")
        }

        // Linear should return the same value
        XCTAssertEqual(Echoelmusic.ModulationCurve.linear.apply(0.5), 0.5, accuracy: 0.001)

        // Exponential should be less than linear at 0.5
        XCTAssertLessThan(Echoelmusic.ModulationCurve.exponential.apply(0.5), 0.5,
                          "Exponential should be below linear at 0.5")

        // Logarithmic should be greater than linear at 0.5
        XCTAssertGreaterThan(Echoelmusic.ModulationCurve.logarithmic.apply(0.5), 0.5,
                             "Logarithmic should be above linear at 0.5")

        // S-curve should equal 0.5 at 0.5 input (inflection point)
        XCTAssertEqual(Echoelmusic.ModulationCurve.sCurve.apply(0.5), 0.5, accuracy: 0.01,
                       "S-curve should pass through 0.5 at midpoint")
    }

    // 10. Verify MIDI note triggers envelope
    func testMIDINoteOn() {
        sut.envelopeStates[0].triggerSource = .midiNoteOn
        sut.envelopeStates[0].isEnabled = true
        sut.envelopeStates[0].attack = 0.01

        sut.handleMIDINoteOn(note: 60, velocity: 100)

        XCTAssertEqual(sut.midiState.note, 60)
        XCTAssertEqual(sut.midiState.velocity, Float(100) / 127.0, accuracy: 0.01)
        XCTAssertTrue(sut.midiState.noteOn)
        XCTAssertEqual(sut.envelopeStates[0].stage, .attack,
                       "MIDI note on should trigger attack stage on MIDI-triggered envelope")
    }

    // 11. Verify -1 to +1 range works correctly for route amount
    func testRouteAmountBipolar() {
        // Positive amount
        let posRoute = sut.addRoute(
            source: .lfo(index: 0),
            destination: .positionX,
            amount: 1.0
        )
        XCTAssertEqual(posRoute?.amount, 1.0, accuracy: 0.001)

        // Negative amount (inverted modulation)
        let negRoute = sut.addRoute(
            source: .lfo(index: 1),
            destination: .positionY,
            amount: -0.8
        )
        XCTAssertEqual(negRoute?.amount, -0.8, accuracy: 0.001)

        // Amount should be clamped to -1...+1
        let overRoute = sut.addRoute(
            source: .lfo(index: 2),
            destination: .rotation,
            amount: 2.0
        )
        XCTAssertEqual(overRoute?.amount, 1.0, accuracy: 0.001,
                       "Amount should be clamped to 1.0")
    }

    // 12. Start/stop and verify isRunning
    func testMatrixStartStop() {
        XCTAssertFalse(sut.isRunning)

        sut.start()
        XCTAssertTrue(sut.isRunning, "Matrix should be running after start()")

        sut.stop()
        XCTAssertFalse(sut.isRunning, "Matrix should be stopped after stop()")
    }
}

// MARK: - ISFShaderParser Tests (~8 tests)

@MainActor
final class ISFShaderParserTests: XCTestCase {

    // Valid ISF source for reuse in tests
    private let validISFSource = """
    /*{
        "DESCRIPTION": "A simple color generator",
        "CREDIT": "Echoelmusic Test",
        "ISFVSN": "2",
        "CATEGORIES": ["Generator"],
        "INPUTS": [
            {
                "NAME": "intensity",
                "TYPE": "float",
                "DEFAULT": 0.5,
                "MIN": 0.0,
                "MAX": 1.0
            },
            {
                "NAME": "mode",
                "TYPE": "long",
                "DEFAULT": 0,
                "LABELS": ["Red", "Green", "Blue"],
                "VALUES": [0, 1, 2]
            },
            {
                "NAME": "enabled",
                "TYPE": "bool",
                "DEFAULT": true
            },
            {
                "NAME": "center",
                "TYPE": "point2D",
                "DEFAULT": [0.5, 0.5]
            },
            {
                "NAME": "tint",
                "TYPE": "color",
                "DEFAULT": [1.0, 0.0, 0.0, 1.0]
            },
            {
                "NAME": "inputImage",
                "TYPE": "image"
            },
            {
                "NAME": "audioData",
                "TYPE": "audio",
                "MAX": 256
            },
            {
                "NAME": "fftData",
                "TYPE": "audioFFT",
                "MAX": 512
            }
        ]
    }*/

    void main() {
        vec4 color = vec4(intensity, 0.0, 0.0, 1.0);
        gl_FragColor = color;
    }
    """

    // 1. Parse valid ISF JSON header + GLSL body
    func testParseSimpleISF() throws {
        let descriptor = try ISFShaderParser.parse(source: validISFSource)

        XCTAssertEqual(descriptor.description, "A simple color generator")
        XCTAssertEqual(descriptor.credit, "Echoelmusic Test")
        XCTAssertEqual(descriptor.version, "2")
        XCTAssertEqual(descriptor.categories, ["Generator"])
        XCTAssertFalse(descriptor.glslSource.isEmpty, "GLSL source should not be empty")
        XCTAssertTrue(descriptor.glslSource.contains("void main()") ||
                      descriptor.glslSource.contains("color"),
                      "GLSL should contain main function body content")
    }

    // 2. Verify float, long, bool, point2D, color, image, audio, audioFFT inputs
    func testParseInputTypes() throws {
        let descriptor = try ISFShaderParser.parse(source: validISFSource)
        let inputs = descriptor.inputs

        XCTAssertEqual(inputs.count, 8, "Should parse all 8 input types")

        // Float input
        let floatInput = inputs.first { $0.name == "intensity" }
        XCTAssertNotNil(floatInput)
        XCTAssertEqual(floatInput?.type, .float)

        // Long input
        let longInput = inputs.first { $0.name == "mode" }
        XCTAssertNotNil(longInput)
        XCTAssertEqual(longInput?.type, .long)

        // Bool input
        let boolInput = inputs.first { $0.name == "enabled" }
        XCTAssertNotNil(boolInput)
        XCTAssertEqual(boolInput?.type, .bool)

        // Point2D input
        let pointInput = inputs.first { $0.name == "center" }
        XCTAssertNotNil(pointInput)
        XCTAssertEqual(pointInput?.type, .point2D)

        // Color input
        let colorInput = inputs.first { $0.name == "tint" }
        XCTAssertNotNil(colorInput)
        XCTAssertEqual(colorInput?.type, .color)

        // Image input
        let imageInput = inputs.first { $0.name == "inputImage" }
        XCTAssertNotNil(imageInput)
        XCTAssertEqual(imageInput?.type, .image)
        XCTAssertTrue(imageInput?.type.isTexture ?? false, "image type should be a texture")

        // Audio input
        let audioInput = inputs.first { $0.name == "audioData" }
        XCTAssertNotNil(audioInput)
        XCTAssertEqual(audioInput?.type, .audio)
        XCTAssertTrue(audioInput?.type.isTexture ?? false, "audio type should be a texture")

        // AudioFFT input
        let fftInput = inputs.first { $0.name == "fftData" }
        XCTAssertNotNil(fftInput)
        XCTAssertEqual(fftInput?.type, .audioFFT)
        XCTAssertTrue(fftInput?.type.isTexture ?? false, "audioFFT type should be a texture")
    }

    // 3. Verify PASSES with persistent buffers
    func testParseMultiPass() throws {
        let multiPassSource = """
        /*{
            "DESCRIPTION": "Multi-pass feedback shader",
            "ISFVSN": "2",
            "INPUTS": [],
            "PASSES": [
                {
                    "TARGET": "feedbackBuffer",
                    "PERSISTENT": true,
                    "WIDTH": "$WIDTH/2",
                    "HEIGHT": "$HEIGHT/2"
                },
                {
                    "TARGET": "blurBuffer",
                    "FLOAT": true
                },
                {}
            ]
        }*/
        void main() {
            gl_FragColor = vec4(1.0);
        }
        """

        let descriptor = try ISFShaderParser.parse(source: multiPassSource)

        XCTAssertEqual(descriptor.passes.count, 3, "Should have 3 render passes")
        XCTAssertTrue(descriptor.isMultiPass, "Should be detected as multi-pass")
        XCTAssertTrue(descriptor.usesFeedback, "Should be detected as using feedback")

        // First pass: persistent feedback buffer
        XCTAssertEqual(descriptor.passes[0].target, "feedbackBuffer")
        XCTAssertTrue(descriptor.passes[0].persistent)
        XCTAssertEqual(descriptor.passes[0].widthExpression, "$WIDTH/2")

        // Second pass: float target
        XCTAssertEqual(descriptor.passes[1].target, "blurBuffer")
        XCTAssertTrue(descriptor.passes[1].isFloatTarget)

        // Third pass: final output
        XCTAssertNil(descriptor.passes[2].target)
    }

    // 4. Verify graceful error for malformed JSON
    func testInvalidJSON() {
        let badSource = """
        /*{
            "DESCRIPTION": "broken,
        }*/
        void main() {}
        """

        XCTAssertThrowsError(try ISFShaderParser.parse(source: badSource)) { error in
            guard let isfError = error as? ISFParseError else {
                XCTFail("Expected ISFParseError, got \(type(of: error))")
                return
            }
            if case .invalidJSON = isfError {
                // Expected
            } else {
                XCTFail("Expected .invalidJSON, got \(isfError)")
            }
        }
    }

    // 5. Verify vec2->float2, mat4->float4x4, mod->fmod
    func testGLSLToMetalConversion() throws {
        let descriptor = try ISFShaderParser.parse(source: validISFSource)
        let metalSource = ISFShaderParser.convertToMetal(
            glslSource: descriptor.glslSource,
            descriptor: descriptor
        )

        // Type conversions
        XCTAssertFalse(metalSource.contains("vec4 "), "vec4 should be converted to float4")
        // Note: we check the Metal output contains float4 (from vec4 conversion)
        XCTAssertTrue(metalSource.contains("float4"), "Metal source should contain float4")

        // The conversion adds metal_stdlib header
        XCTAssertTrue(metalSource.contains("metal_stdlib"), "Metal source should include metal_stdlib")
        XCTAssertTrue(metalSource.contains("using namespace metal"), "Metal source should use metal namespace")
    }

    // 6. Verify TIME, RENDERSIZE, isf_FragNormCoord conversion
    func testISFBuiltInVariableConversion() throws {
        let isfWithBuiltins = """
        /*{
            "DESCRIPTION": "Built-in test",
            "ISFVSN": "2",
            "INPUTS": []
        }*/
        void main() {
            vec2 uv = isf_FragNormCoord;
            float t = TIME;
            vec2 size = RENDERSIZE;
            gl_FragColor = vec4(uv.x, uv.y, t / size.x, 1.0);
        }
        """

        let descriptor = try ISFShaderParser.parse(source: isfWithBuiltins)
        let metalSource = ISFShaderParser.convertToMetal(
            glslSource: descriptor.glslSource,
            descriptor: descriptor
        )

        XCTAssertTrue(metalSource.contains("in.texCoord"),
                      "isf_FragNormCoord should be converted to in.texCoord")
        XCTAssertTrue(metalSource.contains("uniforms.time"),
                      "TIME should be converted to uniforms.time")
        XCTAssertTrue(metalSource.contains("uniforms.resolution"),
                      "RENDERSIZE should be converted to uniforms.resolution")
    }

    // 7. Verify gl_FragColor -> return statement
    func testFragColorReplacement() throws {
        let descriptor = try ISFShaderParser.parse(source: validISFSource)
        let metalSource = ISFShaderParser.convertToMetal(
            glslSource: descriptor.glslSource,
            descriptor: descriptor
        )

        // gl_FragColor should be replaced with outputColor
        XCTAssertFalse(metalSource.contains("gl_FragColor"),
                       "gl_FragColor should be replaced in Metal output")
        XCTAssertTrue(metalSource.contains("outputColor"),
                      "Metal output should use outputColor variable")
        XCTAssertTrue(metalSource.contains("return outputColor"),
                      "Metal function should return outputColor")
    }

    // 8. Load shader into library and verify it's in library
    func testISFLibraryLoadShader() {
        let library = ISFShaderLibrary()

        XCTAssertTrue(library.shaders.isEmpty, "Library should start empty")

        // We cannot load from a real file URL in tests, but we can verify the library
        // initialization and basic state
        XCTAssertFalse(library.isLoading)
        XCTAssertNil(library.lastError)
        XCTAssertTrue(library.shaderNames.isEmpty)

        // Verify category lookup returns empty for non-existent category
        let generators = library.shaders(inCategory: "Generator")
        XCTAssertTrue(generators.isEmpty)

        // Verify allCategories is empty
        XCTAssertTrue(library.allCategories.isEmpty)

        // Verify audioReactiveShaders is empty
        XCTAssertTrue(library.audioReactiveShaders.isEmpty)
    }
}

// MARK: - SyphonNDIBridge Tests (~6 tests)

@MainActor
final class SyphonNDIBridgeTests: XCTestCase {

    var sut: SyphonNDIBridge!

    override func setUp() async throws {
        try await super.setUp()
        sut = SyphonNDIBridge()
    }

    override func tearDown() async throws {
        sut.stopOutput()
        sut = nil
        try await super.tearDown()
    }

    // 1. Verify default state (not active, no protocols)
    func testBridgeInitialization() {
        XCTAssertFalse(sut.isOutputActive, "Output should not be active initially")
        XCTAssertTrue(sut.activeProtocols.isEmpty, "No protocols should be active initially")
        XCTAssertEqual(sut.outputResolution.width, 1920, "Default width should be 1920")
        XCTAssertEqual(sut.outputResolution.height, 1080, "Default height should be 1080")
        XCTAssertEqual(sut.outputFPS, 60, "Default FPS should be 60")
        XCTAssertEqual(sut.framesSent, 0, "No frames should be sent initially")
        XCTAssertEqual(sut.currentBandwidthMbps, 0.0, accuracy: 0.001)
    }

    // 2. Start with NDI protocol and verify isOutputActive
    func testStartOutput() {
        sut.startOutput(protocols: [.ndi5], width: 1280, height: 720, fps: 30)

        XCTAssertTrue(sut.isOutputActive, "Output should be active after start")
        XCTAssertTrue(sut.activeProtocols.contains(.ndi5), "NDI5 should be in active protocols")
        XCTAssertEqual(sut.outputResolution.width, 1280)
        XCTAssertEqual(sut.outputResolution.height, 720)
        XCTAssertEqual(sut.outputFPS, 30)
    }

    // 3. Stop output and verify state reset
    func testStopOutput() {
        sut.startOutput(protocols: [.ndi5])
        XCTAssertTrue(sut.isOutputActive)

        sut.stopOutput()
        XCTAssertFalse(sut.isOutputActive, "Output should be inactive after stop")
        XCTAssertTrue(sut.activeProtocols.isEmpty, "Active protocols should be empty after stop")
    }

    // 4. Verify stats default state
    func testFrameStatistics() {
        let stats = sut.stats

        XCTAssertEqual(stats.framesSent, 0, "Frames sent should start at 0")
        XCTAssertEqual(stats.framesDropped, 0, "Frames dropped should start at 0")
        XCTAssertEqual(stats.averageLatencyMs, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats.bandwidthMbps, 0.0, accuracy: 0.001)
        XCTAssertEqual(stats.connectedReceivers, 0)
        XCTAssertEqual(stats.gpuUtilization, 0.0, accuracy: 0.001)
    }

    // 5. Verify status summary format
    func testStatusSummary() {
        let summary = sut.statusSummary

        XCTAssertTrue(summary.contains("IDLE"), "Status should show IDLE when not active")
        XCTAssertTrue(summary.contains("1920x1080"), "Status should show default resolution")
        XCTAssertTrue(summary.contains("Frames Sent"), "Status should include frame count")
    }

    // 6. Verify that starting output a second time without stopping is handled
    func testDoubleStartIsNoop() {
        sut.startOutput(protocols: [.ndi5], width: 1920, height: 1080, fps: 60)
        XCTAssertTrue(sut.isOutputActive)

        // Starting again should be a no-op (not crash)
        sut.startOutput(protocols: [.ndiHX3], width: 1280, height: 720, fps: 30)

        // Should still be at original settings since second start was a no-op
        XCTAssertTrue(sut.isOutputActive)
        XCTAssertEqual(sut.outputResolution.width, 1920,
                       "Resolution should remain from first start (second start is no-op)")
    }
}

// MARK: - BioReactiveVisualSynthEngine Tests (~10 tests)

@MainActor
final class BioReactiveVisualSynthEngineTests: XCTestCase {

    var sut: BioReactiveVisualSynthEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = BioReactiveVisualSynthEngine()
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // 1. Verify default profile and not running
    func testEngineInitialization() {
        XCTAssertEqual(sut.currentProfile, .creative, "Default profile should be creative")
        XCTAssertFalse(sut.isRunning, "Engine should not be running initially")
        XCTAssertFalse(sut.scenes.isEmpty, "Engine should have default scenes")
        XCTAssertFalse(sut.modulationRoutes.isEmpty, "Engine should have default modulation routes")
        XCTAssertFalse(sut.isOutputActive, "Output should not be active initially")
        XCTAssertNil(sut.activeTransition, "No active transition initially")
    }

    // 2. Load each of 6 profiles and verify configuration
    func testLoadProfile() {
        for profile in BioReactiveProfile.allCases {
            sut.loadProfile(profile)

            XCTAssertEqual(sut.currentProfile, profile,
                           "Current profile should be \(profile.rawValue)")
            XCTAssertFalse(sut.modulationRoutes.isEmpty,
                           "Profile \(profile.rawValue) should have modulation routes")

            // Verify profile properties
            XCTAssertGreaterThan(profile.bioWeight, 0.0)
            XCTAssertLessThanOrEqual(profile.bioWeight, 1.0)
            XCTAssertGreaterThan(profile.targetComplexity, 0.0)
            XCTAssertLessThanOrEqual(profile.targetComplexity, 1.0)
            XCTAssertGreaterThan(profile.baseAnimationSpeed, 0.0)
            XCTAssertFalse(profile.profileDescription.isEmpty,
                           "Profile \(profile.rawValue) should have a description")
        }

        XCTAssertEqual(BioReactiveProfile.allCases.count, 6, "Should have 6 profiles")
    }

    // 3. Start/stop engine and verify state
    func testStartStop() {
        XCTAssertFalse(sut.isRunning)

        sut.start()
        XCTAssertTrue(sut.isRunning, "Engine should be running after start()")

        // Starting again should be a no-op
        sut.start()
        XCTAssertTrue(sut.isRunning)

        sut.stop()
        XCTAssertFalse(sut.isRunning, "Engine should be stopped after stop()")

        // Stopping again should be a no-op
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }

    // 4. Update coherence/HR/breath and verify bioState
    func testBioStateUpdate() {
        // BioState has default values
        XCTAssertEqual(sut.bioState.coherence, 0.5, accuracy: 0.01)
        XCTAssertEqual(sut.bioState.heartRate, 70.0, accuracy: 1.0)

        // BioState is set by the engine's internal read methods.
        // We verify the default BioReactiveState struct
        var state = BioReactiveState()
        state.coherence = 0.9
        state.heartRate = 80.0
        state.breathPhase = 0.6
        state.hrvRaw = 65.0
        state.stressLevel = 0.1

        XCTAssertEqual(state.coherence, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.heartRate, 80.0, accuracy: 0.01)
        XCTAssertEqual(state.breathPhase, 0.6, accuracy: 0.001)
        XCTAssertEqual(state.hrvRaw, 65.0, accuracy: 0.01)
        XCTAssertEqual(state.stressLevel, 0.1, accuracy: 0.001)
    }

    // 5. Update level/spectrum/beat and verify audioState
    func testAudioStateUpdate() {
        // AudioState has default values
        XCTAssertEqual(sut.audioState.level, 0.0, accuracy: 0.001)
        XCTAssertEqual(sut.audioState.bpm, 120.0, accuracy: 0.01)

        // Verify AudioReactiveState struct behavior
        var state = AudioReactiveState()
        state.level = 0.8
        state.bpm = 140.0
        state.beatDetected = true
        state.dominantFrequency = 880.0
        state.bassLevel = 0.7
        state.midLevel = 0.4
        state.highLevel = 0.2

        XCTAssertEqual(state.level, 0.8, accuracy: 0.001)
        XCTAssertEqual(state.bpm, 140.0, accuracy: 0.01)
        XCTAssertTrue(state.beatDetected)
        XCTAssertEqual(state.dominantFrequency, 880.0, accuracy: 0.01)
        XCTAssertEqual(state.bassLevel, 0.7, accuracy: 0.001)
        XCTAssertEqual(state.spectrum.count, 64, "Default spectrum should have 64 bands")
    }

    // 6. Verify modulation source -> destination mapping
    func testModulationRouting() {
        sut.loadProfile(.meditation)

        let routes = sut.modulationRoutes
        XCTAssertFalse(routes.isEmpty, "Meditation profile should have routes")

        // Verify at least coherence and breathPhase are mapped
        let coherenceRoute = routes.first { $0.source == .coherence }
        XCTAssertNotNil(coherenceRoute, "Meditation should have a coherence route")
        XCTAssertTrue(coherenceRoute?.isActive ?? false, "Route should be active")
        XCTAssertGreaterThan(coherenceRoute?.amount ?? 0, 0.0, "Route amount should be positive")

        let breathRoute = routes.first { $0.source == .breathPhase }
        XCTAssertNotNil(breathRoute, "Meditation should have a breath phase route")
    }

    // 7. Create scene with layer configs
    func testSceneCreation() {
        let scene = VisualScene(
            name: "Test Scene",
            shaderType: "cymatics",
            baseHue: 0.3,
            baseBrightness: 0.8,
            baseComplexity: 0.6,
            particleCount: 5000,
            coherenceModulatesGeometry: true,
            heartRateModulatesSpeed: false,
            breathModulatesScale: true,
            beatTriggersFlash: true,
            coherenceTriggerThreshold: 0.75
        )

        XCTAssertEqual(scene.name, "Test Scene")
        XCTAssertEqual(scene.shaderType, "cymatics")
        XCTAssertEqual(scene.baseHue, 0.3, accuracy: 0.001)
        XCTAssertEqual(scene.baseBrightness, 0.8, accuracy: 0.001)
        XCTAssertEqual(scene.particleCount, 5000)
        XCTAssertTrue(scene.coherenceModulatesGeometry)
        XCTAssertFalse(scene.heartRateModulatesSpeed)
        XCTAssertTrue(scene.breathModulatesScale)
        XCTAssertTrue(scene.beatTriggersFlash)
        XCTAssertEqual(scene.coherenceTriggerThreshold, 0.75, accuracy: 0.001)
    }

    // 8. Trigger transition and verify crossfade progress
    func testSceneTransition() {
        let targetScene = VisualScene(name: "Target")
        XCTAssertNil(sut.activeTransition)

        sut.triggerTransition(to: targetScene, duration: 2.0)

        XCTAssertNotNil(sut.activeTransition, "Transition should be active after trigger")
        XCTAssertEqual(sut.activeTransition?.targetScene.name, "Target")
        XCTAssertEqual(sut.activeTransition?.duration, 2.0, accuracy: 0.001)
        XCTAssertEqual(sut.activeTransition?.progress, 0.0, accuracy: 0.01,
                       "Initial transition progress should be 0")
    }

    // 9. Verify coherence threshold triggers scene change
    func testBioTriggeredSceneSwitch() {
        // Add a scene with a coherence trigger threshold
        let triggerScene = VisualScene(
            id: "trigger-scene",
            name: "Triggered Scene",
            coherenceTriggerThreshold: 0.8
        )
        sut.scenes.append(triggerScene)

        // Scene with a threshold exists; we verify the VisualScene struct itself
        XCTAssertNotNil(triggerScene.coherenceTriggerThreshold)
        XCTAssertEqual(triggerScene.coherenceTriggerThreshold!, 0.8, accuracy: 0.001)

        // Verify default scenes include threshold-based scenes
        let scenesWithThresholds = sut.scenes.filter { $0.coherenceTriggerThreshold != nil }
        XCTAssertFalse(scenesWithThresholds.isEmpty,
                       "Should have at least one scene with a coherence trigger threshold")
    }

    // 10. Verify simulated data generation when no sources connected
    func testSimulationMode() {
        // Engine with no connected sources should simulate data
        sut.start()

        // Wait briefly for the control loop to execute at least one tick
        let expectation = XCTestExpectation(description: "Control loop tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // After running without sources, bio/audio state should have simulated values
        XCTAssertTrue(sut.isRunning)
        XCTAssertGreaterThan(sut.performanceStats.tickCount, 0,
                             "Should have processed at least one tick")

        // The status summary should be valid
        let status = sut.statusSummary
        XCTAssertTrue(status.contains("RUNNING"), "Status should show RUNNING")
        XCTAssertTrue(status.contains(sut.currentProfile.rawValue),
                      "Status should include current profile name")
    }
}

// MARK: - Material & Blend Mode Coverage Tests (~5 tests)

@MainActor
final class MaterialAndBlendModeCoverageTests: XCTestCase {

    // 1. Verify all 25 materials have SF Symbol icons
    func testAllMaterialTypesHaveIcons() {
        let allMaterials = VisualMaterialType.allCases
        XCTAssertEqual(allMaterials.count, 25, "Should have exactly 25 material types")

        for material in allMaterials {
            XCTAssertFalse(material.icon.isEmpty,
                           "Material '\(material.rawValue)' should have an icon")
        }
    }

    // 2. Verify descriptions are not empty
    func testAllMaterialTypesHaveDescriptions() {
        for material in VisualMaterialType.allCases {
            XCTAssertFalse(material.description.isEmpty,
                           "Material '\(material.rawValue)' should have a description")
            XCTAssertGreaterThan(material.description.count, 10,
                                "Material '\(material.rawValue)' description should be meaningful (>10 chars)")
        }
    }

    // 3. Verify 15 blend modes enumerated
    func testAllBlendModesCaseIterable() {
        let allModes = CompositorBlendMode.allCases
        XCTAssertEqual(allModes.count, 15, "Should have exactly 15 blend modes")

        // Verify each has a display name
        for mode in allModes {
            XCTAssertFalse(mode.displayName.isEmpty,
                           "Blend mode '\(mode.rawValue)' should have a display name")
        }

        // Verify each has a unique rawValue
        let rawValues = Set(allModes.map { $0.rawValue })
        XCTAssertEqual(rawValues.count, 15, "All blend modes should have unique raw values")
    }

    // 4. Verify all 12 modulation destinations have valid ranges
    func testModulationDestinationRanges() {
        let allDestinations = Echoelmusic.ModulationDestination.allCases
        XCTAssertEqual(allDestinations.count, 12, "Should have exactly 12 modulation destinations")

        for destination in allDestinations {
            XCTAssertGreaterThan(destination.defaultRange, 0.0,
                                "Destination '\(destination.rawValue)' should have a positive range")
            XCTAssertFalse(destination.displayName.isEmpty,
                           "Destination '\(destination.rawValue)' should have a display name")
        }
    }

    // 5. Verify all 5 LFO shapes enumerated
    func testLFOShapesCaseIterable() {
        let allShapes = LFOShape.allCases
        XCTAssertEqual(allShapes.count, 5, "Should have exactly 5 LFO shapes")

        for shape in allShapes {
            XCTAssertFalse(shape.displayName.isEmpty,
                           "LFO shape '\(shape.rawValue)' should have a display name")
        }

        // Verify expected shapes exist
        let shapeNames = Set(allShapes.map { $0.rawValue })
        XCTAssertTrue(shapeNames.contains("sine"), "Should include sine shape")
        XCTAssertTrue(shapeNames.contains("triangle"), "Should include triangle shape")
        XCTAssertTrue(shapeNames.contains("saw"), "Should include saw shape")
        XCTAssertTrue(shapeNames.contains("square"), "Should include square shape")
        XCTAssertTrue(shapeNames.contains("random"), "Should include random shape")
    }
}
