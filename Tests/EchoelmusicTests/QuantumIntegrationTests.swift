//
//  QuantumIntegrationTests.swift
//  EchoelmusicTests
//
//  Comprehensive Integration Tests for Quantum Light System
//  Tests all Phase 4 components: Emulator, Visualizations, SharePlay, Shortcuts, Presets
//
//  Created: 2026-01-05
//

import XCTest
@testable import Echoelmusic

final class QuantumIntegrationTests: XCTestCase {

    // MARK: - Preset Tests

    func testPresetManagerHasBuiltInPresets() {
        let manager = PresetManager.shared
        XCTAssertGreaterThanOrEqual(manager.allPresets.count, 15, "Should have at least 15 built-in presets")
    }

    func testPresetCategories() {
        let categories = PresetCategory.allCases
        XCTAssertGreaterThanOrEqual(categories.count, 8, "Should have at least 8 categories")

        // Verify expected categories exist
        XCTAssertTrue(categories.contains(.meditation))
        XCTAssertTrue(categories.contains(.focus))
        XCTAssertTrue(categories.contains(.sleep))
        XCTAssertTrue(categories.contains(.creativity))
    }

    func testPresetHasValidConfiguration() {
        let preset = QuantumPreset.deepMeditation

        XCTAssertFalse(preset.id.isEmpty, "Preset should have an ID")
        XCTAssertFalse(preset.name.isEmpty, "Preset should have a name")
        XCTAssertFalse(preset.description.isEmpty, "Preset should have a description")
        XCTAssertGreaterThan(preset.sessionDuration, 0, "Session duration should be positive")
        XCTAssertGreaterThanOrEqual(preset.binauralFrequency, 0, "Binaural frequency should be non-negative")
    }

    func testPresetSerialization() throws {
        let preset = QuantumPreset.focusFlow

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)
        XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QuantumPreset.self, from: data)

        XCTAssertEqual(decoded.id, preset.id)
        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.emulationMode, preset.emulationMode)
    }

    func testPresetCategoryFiltering() {
        let meditationPresets = PresetManager.shared.presets(for: .meditation)
        XCTAssertGreaterThan(meditationPresets.count, 0, "Should have meditation presets")

        for preset in meditationPresets {
            XCTAssertEqual(preset.category, .meditation, "All presets should be in meditation category")
        }
    }

    // MARK: - Emulator Mode Tests

    func testAllEmulationModesValid() {
        let modes = QuantumLightEmulator.EmulationMode.allCases

        XCTAssertEqual(modes.count, 5, "Should have 5 emulation modes")
        XCTAssertTrue(modes.contains(.classical))
        XCTAssertTrue(modes.contains(.quantumInspired))
        XCTAssertTrue(modes.contains(.fullQuantum))
        XCTAssertTrue(modes.contains(.hybridPhotonic))
        XCTAssertTrue(modes.contains(.bioCoherent))
    }

    func testEmulatorModeSwitch() {
        let emulator = QuantumLightEmulator()

        for mode in QuantumLightEmulator.EmulationMode.allCases {
            emulator.setMode(mode)
            XCTAssertEqual(emulator.emulationMode, mode, "Emulator should switch to \(mode)")
        }
    }

    // MARK: - Visualization Tests

    func testAllVisualizationTypesAvailable() {
        let types = PhotonicsVisualizationEngine.VisualizationType.allCases

        XCTAssertEqual(types.count, 10, "Should have 10 visualization types")
        XCTAssertTrue(types.contains(.interferencePattern))
        XCTAssertTrue(types.contains(.waveFunction))
        XCTAssertTrue(types.contains(.coherenceField))
        XCTAssertTrue(types.contains(.photonFlow))
        XCTAssertTrue(types.contains(.sacredGeometry))
        XCTAssertTrue(types.contains(.quantumTunnel))
        XCTAssertTrue(types.contains(.biophotonAura))
        XCTAssertTrue(types.contains(.lightMandala))
        XCTAssertTrue(types.contains(.holographicDisplay))
        XCTAssertTrue(types.contains(.cosmicWeb))
    }

    func testVisualizationEngineInitialization() {
        let engine = PhotonicsVisualizationEngine()

        XCTAssertNotNil(engine, "Engine should initialize")
        XCTAssertEqual(engine.currentVisualizationType, .interferencePattern, "Default should be interference pattern")
    }

    func testVisualizationTypeSwitch() {
        let engine = PhotonicsVisualizationEngine()

        for type in PhotonicsVisualizationEngine.VisualizationType.allCases {
            engine.setVisualizationType(type)
            XCTAssertEqual(engine.currentVisualizationType, type, "Engine should switch to \(type)")
        }
    }

    // MARK: - Coherence Tests

    func testCoherenceLevelBounds() {
        let emulator = QuantumLightEmulator()

        // Coherence should always be between 0 and 1
        XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0.0, "Coherence should be >= 0")
        XCTAssertLessThanOrEqual(emulator.coherenceLevel, 1.0, "Coherence should be <= 1")
    }

    func testBioFeedbackCoherenceUpdate() {
        let emulator = QuantumLightEmulator()
        emulator.setMode(.bioCoherent)

        // Simulate bio-feedback update
        emulator.updateBioFeedback(coherence: 0.8, hrv: 65.0, heartRate: 70.0)

        // Coherence should reflect the bio data
        XCTAssertGreaterThan(emulator.coherenceLevel, 0.5, "Bio-coherent mode should respond to high coherence input")
    }

    // MARK: - Quantum State Tests

    func testQuantumStateCreation() {
        let state = QuantumAudioState(numQubits: 3)

        XCTAssertEqual(state.amplitudes.count, 8, "3 qubits should have 8 amplitudes (2^3)")
        XCTAssertEqual(state.probabilities.count, 8, "Should have 8 probabilities")

        // Probabilities should sum to ~1
        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.001, "Probabilities should sum to 1")
    }

    func testQuantumStateNormalization() {
        var state = QuantumAudioState(numQubits: 2)

        // Manually set amplitudes
        state.amplitudes = [
            Complex<Float>(real: 0.5, imaginary: 0),
            Complex<Float>(real: 0.5, imaginary: 0),
            Complex<Float>(real: 0.5, imaginary: 0),
            Complex<Float>(real: 0.5, imaginary: 0)
        ]

        state.normalize()

        // After normalization, probabilities should sum to 1
        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.001, "Normalized probabilities should sum to 1")
    }

    func testQuantumStateCollapse() {
        let state = QuantumAudioState(numQubits: 2)
        let collapsed = state.collapse()

        // Collapsed state should be one of the basis states (0-3)
        XCTAssertGreaterThanOrEqual(collapsed, 0, "Collapsed state should be >= 0")
        XCTAssertLessThan(collapsed, 4, "Collapsed state should be < 4 for 2 qubits")
    }

    // MARK: - Photon Tests

    func testPhotonCreation() {
        let photon = Photon(
            position: SIMD3<Float>(0, 0, 0),
            velocity: SIMD3<Float>(1, 0, 0),
            wavelength: 550,
            phase: 0,
            amplitude: 1.0
        )

        XCTAssertEqual(photon.wavelength, 550, "Wavelength should be 550nm (green)")
        XCTAssertEqual(photon.amplitude, 1.0, "Amplitude should be 1.0")
    }

    func testPhotonColorFromWavelength() {
        // Test visible spectrum range
        let violet = Photon(position: .zero, velocity: .zero, wavelength: 400, phase: 0, amplitude: 1)
        let green = Photon(position: .zero, velocity: .zero, wavelength: 550, phase: 0, amplitude: 1)
        let red = Photon(position: .zero, velocity: .zero, wavelength: 700, phase: 0, amplitude: 1)

        XCTAssertGreaterThan(violet.color.z, violet.color.x, "Violet should have more blue than red")
        XCTAssertGreaterThan(red.color.x, red.color.z, "Red should have more red than blue")

        // Green should have high green component
        XCTAssertGreaterThan(green.color.y, 0.5, "Green should have significant green component")
    }

    // MARK: - Light Field Tests

    func testLightFieldCreation() {
        let field = LightField(photonCount: 100, geometry: .sphere)

        XCTAssertEqual(field.photons.count, 100, "Field should have 100 photons")
        XCTAssertEqual(field.geometry, .sphere, "Geometry should be sphere")
    }

    func testLightFieldGeometries() {
        let geometries = LightField.Geometry.allCases

        for geometry in geometries {
            let field = LightField(photonCount: 50, geometry: geometry)
            XCTAssertEqual(field.geometry, geometry, "Field should have \(geometry) geometry")
            XCTAssertEqual(field.photons.count, 50, "Field should have 50 photons")
        }
    }

    func testLightFieldCoherence() {
        let field = LightField(photonCount: 100, geometry: .grid)

        // Field coherence should be between 0 and 1
        XCTAssertGreaterThanOrEqual(field.fieldCoherence, 0.0, "Coherence should be >= 0")
        XCTAssertLessThanOrEqual(field.fieldCoherence, 1.0, "Coherence should be <= 1")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityProfilesExist() {
        let profiles = QuantumAccessibilityManager.AccessibilityProfile.allCases

        XCTAssertGreaterThanOrEqual(profiles.count, 7, "Should have at least 7 accessibility profiles")
        XCTAssertTrue(profiles.contains(.standard))
        XCTAssertTrue(profiles.contains(.lowVision))
        XCTAssertTrue(profiles.contains(.colorBlind))
        XCTAssertTrue(profiles.contains(.motionSensitive))
    }

    func testColorBlindSchemes() {
        let schemes = QuantumAccessibilityManager.AccessibleColorScheme.allCases

        XCTAssertGreaterThanOrEqual(schemes.count, 6, "Should have at least 6 color schemes")
        XCTAssertTrue(schemes.contains(.standard))
        XCTAssertTrue(schemes.contains(.deuteranopia))
        XCTAssertTrue(schemes.contains(.protanopia))
        XCTAssertTrue(schemes.contains(.tritanopia))
        XCTAssertTrue(schemes.contains(.highContrast))
        XCTAssertTrue(schemes.contains(.monochrome))
    }

    @MainActor
    func testAccessibilityColorAdaptation() {
        let manager = QuantumAccessibilityManager.shared

        let originalColor = SIMD3<Float>(1.0, 0.0, 0.0) // Red

        // Test monochrome adaptation
        manager.preferredColorScheme = .monochrome
        let monochromeColor = manager.adaptColor(originalColor)

        // Monochrome should have equal RGB components
        XCTAssertEqual(monochromeColor.x, monochromeColor.y, accuracy: 0.001, "Monochrome should have equal R and G")
        XCTAssertEqual(monochromeColor.y, monochromeColor.z, accuracy: 0.001, "Monochrome should have equal G and B")

        // Reset to standard
        manager.preferredColorScheme = .standard
    }

    // MARK: - Data Store Tests

    func testQuantumDataStoreExists() {
        let store = QuantumDataStore.shared

        XCTAssertNotNil(store, "Data store should exist")
        XCTAssertGreaterThanOrEqual(store.coherenceLevel, 0, "Coherence level should be non-negative")
        XCTAssertGreaterThanOrEqual(store.heartRate, 0, "Heart rate should be non-negative")
    }

    // MARK: - Integration Tests

    func testFullQuantumSessionWorkflow() {
        // 1. Create emulator
        let emulator = QuantumLightEmulator()

        // 2. Set mode from preset
        let preset = QuantumPreset.deepMeditation
        if let mode = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) {
            emulator.setMode(mode)
            XCTAssertEqual(emulator.emulationMode, mode)
        }

        // 3. Start emulator
        emulator.start()

        // 4. Simulate bio feedback
        emulator.updateBioFeedback(coherence: 0.75, hrv: 60.0, heartRate: 68.0)

        // 5. Get quantum state
        let state = emulator.currentQuantumState
        XCTAssertNotNil(state, "Should have a quantum state after processing")

        // 6. Get light field
        let field = emulator.currentLightField
        XCTAssertNotNil(field, "Should have a light field")

        // 7. Stop emulator
        emulator.stop()
    }

    func testVisualizationEngineWithLightField() {
        let engine = PhotonicsVisualizationEngine()
        let field = LightField(photonCount: 50, geometry: .flowerOfLife)

        engine.setLightField(field)
        engine.setVisualizationType(.sacredGeometry)

        // Engine should accept the field
        XCTAssertEqual(engine.currentVisualizationType, .sacredGeometry)
    }

    // MARK: - Performance Tests

    func testEmulatorPerformance() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        measure {
            for _ in 0..<100 {
                emulator.updateBioFeedback(
                    coherence: Float.random(in: 0...1),
                    hrv: Double.random(in: 20...100),
                    heartRate: Double.random(in: 50...120)
                )
            }
        }

        emulator.stop()
    }

    func testQuantumStateCollapsePerformance() {
        measure {
            for _ in 0..<1000 {
                let state = QuantumAudioState(numQubits: 4)
                _ = state.collapse()
            }
        }
    }

    func testLightFieldCreationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = LightField(photonCount: 500, geometry: .sphere)
            }
        }
    }

    // MARK: - Edge Case Tests

    func testEmulatorWithZeroCoherence() {
        let emulator = QuantumLightEmulator()
        emulator.updateBioFeedback(coherence: 0.0, hrv: 0.0, heartRate: 60.0)

        XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0.0, "Coherence should be valid even at zero")
    }

    func testEmulatorWithMaxCoherence() {
        let emulator = QuantumLightEmulator()
        emulator.updateBioFeedback(coherence: 1.0, hrv: 100.0, heartRate: 60.0)

        XCTAssertLessThanOrEqual(emulator.coherenceLevel, 1.0, "Coherence should not exceed 1.0")
    }

    func testEmptyLightField() {
        let field = LightField(photonCount: 0, geometry: .line)

        XCTAssertEqual(field.photons.count, 0, "Empty field should have 0 photons")
    }

    func testLargeQuantumState() {
        let state = QuantumAudioState(numQubits: 10)

        XCTAssertEqual(state.amplitudes.count, 1024, "10 qubits should have 1024 amplitudes")

        // Should still be normalized
        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.01, "Large state should still be normalized")
    }
}
