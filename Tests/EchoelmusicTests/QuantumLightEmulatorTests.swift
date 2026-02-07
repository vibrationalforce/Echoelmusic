//
//  QuantumLightEmulatorTests.swift
//  EchoelmusicTests
//
//  Comprehensive test suite for Quantum Light Emulator
//  Target: 100% coverage of quantum-inspired functionality
//
//  Created: 2026-01-05
//

import XCTest
@testable import Echoelmusic

@MainActor
final class QuantumLightEmulatorTests: XCTestCase {

    // MARK: - Quantum Audio State Tests

    func testQuantumAudioStateInitialization() {
        let amplitudes: [SIMD2<Float>] = [
            SIMD2<Float>(0.707, 0),
            SIMD2<Float>(0.707, 0)
        ]
        let phases: [Float] = [0, Float.pi / 4]

        let state = QuantumAudioState(
            amplitudes: amplitudes,
            phases: phases,
            coherence: 1.0,
            entanglementFactor: 0.5
        )

        XCTAssertEqual(state.amplitudes.count, 2)
        XCTAssertEqual(state.phases.count, 2)
        XCTAssertEqual(state.coherence, 1.0)
        XCTAssertEqual(state.entanglementFactor, 0.5)
    }

    func testQuantumStateProbabilities() {
        let amplitudes: [SIMD2<Float>] = [
            SIMD2<Float>(1.0, 0),   // |0⟩ with amplitude 1
            SIMD2<Float>(0, 0)      // |1⟩ with amplitude 0
        ]
        let phases: [Float] = [0, 0]

        let state = QuantumAudioState(amplitudes: amplitudes, phases: phases)
        let probs = state.probabilities

        XCTAssertEqual(probs[0], 1.0, accuracy: 0.001) // 100% probability for |0⟩
        XCTAssertEqual(probs[1], 0.0, accuracy: 0.001) // 0% probability for |1⟩
    }

    func testQuantumStateSuperposition() {
        let state1 = QuantumAudioState(
            amplitudes: [SIMD2<Float>(1, 0), SIMD2<Float>(0, 0)],
            phases: [0, 0],
            coherence: 1.0
        )
        let state2 = QuantumAudioState(
            amplitudes: [SIMD2<Float>(0, 0), SIMD2<Float>(1, 0)],
            phases: [0, 0],
            coherence: 1.0
        )

        let superposed = QuantumAudioState.superposition(state1, state2, ratio: 0.5)

        // Equal superposition should have ~0.5 probability for each state
        let probs = superposed.probabilities
        XCTAssertEqual(probs[0], 0.5, accuracy: 0.1)
        XCTAssertEqual(probs[1], 0.5, accuracy: 0.1)
    }

    func testQuantumStateCollapse() {
        let amplitudes: [SIMD2<Float>] = [
            SIMD2<Float>(0.707, 0),
            SIMD2<Float>(0.707, 0)
        ]
        let state = QuantumAudioState(amplitudes: amplitudes, phases: [0, 0])

        // Collapse should return valid index
        let collapsed = state.collapse()
        XCTAssertTrue(collapsed >= 0 && collapsed < amplitudes.count)
    }

    func testQuantumStateCoherenceClamping() {
        let state = QuantumAudioState(
            amplitudes: [SIMD2<Float>(1, 0)],
            phases: [0],
            coherence: 1.5,  // Should clamp to 1.0
            entanglementFactor: -0.5  // Should clamp to 0.0
        )

        XCTAssertEqual(state.coherence, 1.0)
        XCTAssertEqual(state.entanglementFactor, 0.0)
    }

    // MARK: - Photon Tests

    func testPhotonInitialization() {
        let photon = Photon(
            wavelength: 550,  // Green light
            polarization: Float.pi / 4,
            intensity: 0.8,
            coherence: 1.0,
            position: SIMD3<Float>(0, 0, 0),
            direction: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(photon.wavelength, 550)
        XCTAssertEqual(photon.intensity, 0.8)
        XCTAssertEqual(photon.coherence, 1.0)
    }

    func testPhotonWavelengthToColor() {
        // Test visible spectrum conversion
        let redPhoton = Photon(wavelength: 700)
        let greenPhoton = Photon(wavelength: 550)
        let bluePhoton = Photon(wavelength: 450)

        // Red photon should have high R value
        XCTAssertGreaterThan(redPhoton.color.x, 0.5)

        // Green photon should have high G value
        XCTAssertGreaterThan(greenPhoton.color.y, 0.5)

        // Blue photon should have high B value
        XCTAssertGreaterThan(bluePhoton.color.z, 0.5)
    }

    func testPhotonIntensityClamping() {
        let photon = Photon(wavelength: 550, intensity: 1.5)
        XCTAssertEqual(photon.intensity, 1.0) // Clamped to max

        let photon2 = Photon(wavelength: 550, intensity: -0.5)
        XCTAssertEqual(photon2.intensity, 0.0) // Clamped to min
    }

    func testPhotonDirectionNormalization() {
        let photon = Photon(
            wavelength: 550,
            direction: SIMD3<Float>(3, 4, 0)  // Length = 5
        )

        let length = simd_length(photon.direction)
        XCTAssertEqual(length, 1.0, accuracy: 0.001) // Should be normalized
    }

    // MARK: - Light Field Tests

    func testLightFieldInitialization() {
        let photons = [
            Photon(wavelength: 550),
            Photon(wavelength: 600),
            Photon(wavelength: 650)
        ]

        let field = LightField(
            photons: photons,
            fieldCoherence: 0.9,
            geometry: .fibonacci
        )

        XCTAssertEqual(field.photons.count, 3)
        XCTAssertEqual(field.fieldCoherence, 0.9)
        XCTAssertEqual(field.geometry, .fibonacci)
    }

    func testLightFieldInterferencePattern() {
        let photons = [
            Photon(wavelength: 550, position: SIMD3<Float>(-0.5, 0, 0)),
            Photon(wavelength: 550, position: SIMD3<Float>(0.5, 0, 0))
        ]

        let field = LightField(photons: photons, fieldCoherence: 1.0)

        // Test interference at different points
        let center = field.interferencePattern(at: SIMD3<Float>(0, 0, 0))
        let offset = field.interferencePattern(at: SIMD3<Float>(0.1, 0, 0))

        // Interference should produce varying values
        XCTAssertNotEqual(center, offset, accuracy: 0.001)
    }

    func testLightFieldGeometryTypes() {
        let geometries: [LightField.FieldGeometry] = [
            .planar, .spherical, .gaussian, .vortex, .fibonacci, .toroidal, .merkaba
        ]

        for geometry in geometries {
            let field = LightField(photons: [], geometry: geometry)
            XCTAssertEqual(field.geometry, geometry)
        }
    }

    // MARK: - Quantum Light Emulator Tests

    func testEmulatorInitialization() {
        let config = QuantumLightEmulator.Configuration()
        let emulator = QuantumLightEmulator(configuration: config)

        XCTAssertFalse(emulator.isActive)
        XCTAssertEqual(emulator.emulationMode, .classical)
        XCTAssertEqual(emulator.coherenceLevel, 0.0)
    }

    func testEmulatorStartStop() {
        let emulator = QuantumLightEmulator()

        emulator.start()
        XCTAssertTrue(emulator.isActive)

        emulator.stop()
        XCTAssertFalse(emulator.isActive)
    }

    func testEmulatorModeChange() {
        let emulator = QuantumLightEmulator()

        emulator.setMode(.bioCoherent)
        XCTAssertEqual(emulator.emulationMode, .bioCoherent)

        emulator.setMode(.quantumInspired)
        XCTAssertEqual(emulator.emulationMode, .quantumInspired)

        emulator.setMode(.hybridPhotonic)
        XCTAssertEqual(emulator.emulationMode, .hybridPhotonic)
    }

    func testEmulatorBioInputs() async {
        let emulator = QuantumLightEmulator()
        emulator.setMode(.bioCoherent)
        emulator.start()

        // Update bio inputs
        emulator.updateBioInputs(hrvCoherence: 80.0, heartRate: 72.0, breathingRate: 6.0)

        // Wait for update cycle
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // In bio-coherent mode, coherence should be influenced by HRV
        XCTAssertGreaterThan(emulator.coherenceLevel, 0.0)

        emulator.stop()
    }

    func testEmulatorAudioProcessing() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let input: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        // Classical mode should pass through
        emulator.setMode(.classical)
        let classicalOutput = emulator.processAudio(input)
        XCTAssertEqual(classicalOutput, input)

        // Quantum-inspired should modify
        emulator.setMode(.quantumInspired)
        let quantumOutput = emulator.processAudio(input)
        XCTAssertEqual(quantumOutput.count, input.count)

        emulator.stop()
    }

    func testEmulatorEntanglement() {
        let emulator = QuantumLightEmulator()

        emulator.entangle(with: "device-123", strength: 0.8)
        XCTAssertEqual(emulator.entanglementNetwork["device-123"], 0.8)

        emulator.entangle(with: "device-456", strength: 0.5)
        XCTAssertEqual(emulator.entanglementNetwork.count, 2)

        emulator.disentangle(from: "device-123")
        XCTAssertNil(emulator.entanglementNetwork["device-123"])
    }

    func testEmulatorDecisionCollapse() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let options = ["A", "B", "C", "D"]
        let decision = emulator.collapseToDecision(options: options)

        XCTAssertNotNil(decision)
        XCTAssertTrue(options.contains(decision!))

        emulator.stop()
    }

    func testEmulatorLightFieldGeneration() async {
        let emulator = QuantumLightEmulator()
        emulator.start()

        // Wait for field generation
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertNotNil(emulator.currentEmulatorLightField)
        XCTAssertNotNil(emulator.currentQuantumState)

        emulator.stop()
    }

    func testEmulatorVisualizationGeneration() async {
        let emulator = QuantumLightEmulator()
        emulator.start()

        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let visualization = emulator.generateLightFieldVisualization(width: 64, height: 64)

        XCTAssertEqual(visualization.count, 64)
        XCTAssertEqual(visualization[0].count, 64)

        emulator.stop()
    }

    func testEmulatorConfiguration() {
        var config = QuantumLightEmulator.Configuration()
        config.qubitCount = 16
        config.photonCount = 128
        config.coherenceThreshold = 0.8
        config.decoherenceRate = 0.02

        let emulator = QuantumLightEmulator(configuration: config)

        XCTAssertEqual(emulator.configuration.qubitCount, 16)
        XCTAssertEqual(emulator.configuration.photonCount, 128)
    }

    // MARK: - Quantum Creativity Engine Tests

    func testCreativityEngineScaleGeneration() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let creativity = QuantumCreativityEngine(emulator: emulator)

        let scale = creativity.generateScale(rootNote: 60, scaleSize: 7)

        XCTAssertEqual(scale.count, 7)
        XCTAssertEqual(scale[0], 60) // Root note preserved

        // Notes should be ascending
        for i in 1..<scale.count {
            XCTAssertGreaterThan(scale[i], scale[i-1])
        }

        emulator.stop()
    }

    func testCreativityEngineRhythmGeneration() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let creativity = QuantumCreativityEngine(emulator: emulator)

        let rhythm = creativity.generateRhythm(steps: 16, density: 0.5)

        XCTAssertEqual(rhythm.count, 16)

        emulator.stop()
    }

    func testCreativityEngineColorPalette() async {
        let emulator = QuantumLightEmulator()
        emulator.start()

        try? await Task.sleep(nanoseconds: 100_000_000)

        let creativity = QuantumCreativityEngine(emulator: emulator)
        let palette = creativity.generateColorPalette(count: 5)

        XCTAssertEqual(palette.count, 5)

        emulator.stop()
    }

    func testCreativityEngineOptionSelection() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let creativity = QuantumCreativityEngine(emulator: emulator)

        let options = [1, 2, 3, 4, 5]
        let selected = creativity.selectOption(options)

        XCTAssertNotNil(selected)
        XCTAssertTrue(options.contains(selected!))

        emulator.stop()
    }

    // MARK: - Quantum Circuit Tests (Future Interface)

    func testQuantumCircuitCreation() {
        let circuit = QuantumCircuit(
            gates: [
                .hadamard(qubit: 0),
                .cnot(control: 0, target: 1),
                .phase(qubit: 1, angle: Float.pi / 4)
            ],
            qubitCount: 2
        )

        XCTAssertEqual(circuit.qubitCount, 2)
        XCTAssertEqual(circuit.gates.count, 3)
    }

    func testQuantumResultStructure() {
        let result = QuantumResult(
            measurements: [0: 512, 1: 488],
            shotCount: 1000,
            executionTime: 0.001
        )

        XCTAssertEqual(result.shotCount, 1000)
        XCTAssertEqual(result.measurements[0], 512)
        XCTAssertEqual(result.measurements[1], 488)
    }

    // MARK: - Performance Tests

    func testEmulatorPerformance() {
        let emulator = QuantumLightEmulator()

        measure {
            emulator.start()
            for _ in 0..<100 {
                _ = emulator.processAudio([Float](repeating: 0.5, count: 512))
            }
            emulator.stop()
        }
    }

    func testVisualizationPerformance() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        measure {
            _ = emulator.generateLightFieldVisualization(width: 128, height: 128)
        }

        emulator.stop()
    }

    // MARK: - Edge Cases

    func testEmptyOptionsDecision() {
        let emulator = QuantumLightEmulator()
        let decision = emulator.collapseToDecision(options: [String]())
        XCTAssertNil(decision)
    }

    func testZeroCoherenceState() {
        let state = QuantumAudioState(
            amplitudes: [SIMD2<Float>(0, 0)],
            phases: [0],
            coherence: 0
        )

        XCTAssertEqual(state.coherence, 0)
        XCTAssertEqual(state.probabilities[0], 0)
    }

    func testEmulatorStopWhenNotRunning() {
        let emulator = QuantumLightEmulator()
        // Should not crash when stopping without starting
        emulator.stop()
        XCTAssertFalse(emulator.isActive)
    }
}
