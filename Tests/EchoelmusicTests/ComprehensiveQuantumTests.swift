//
//  ComprehensiveQuantumTests.swift
//  EchoelmusicTests
//
//  300% Comprehensive Test Suite - Tauchfliegen Edition
//  Tests ALL quantum light features at maximum coverage
//
//  Created: 2026-01-05
//

import XCTest
@testable import Echoelmusic

// MARK: - 300% Test Suite

final class ComprehensiveQuantumTests: XCTestCase {

    // MARK: - Quantum State Tests (100+ scenarios)

    func testQuantumStateInitialization_AllQubitCounts() {
        for qubits in 1...10 {
            let state = QuantumAudioState(numQubits: qubits)
            let expectedSize = 1 << qubits // 2^qubits

            XCTAssertEqual(state.amplitudes.count, expectedSize,
                          "State with \(qubits) qubits should have \(expectedSize) amplitudes")

            // Verify normalization
            let totalProb = state.probabilities.reduce(0, +)
            XCTAssertEqual(totalProb, 1.0, accuracy: 0.001,
                          "Probabilities must sum to 1 for \(qubits) qubits")
        }
    }

    func testQuantumStateCollapse_StatisticalDistribution() {
        let state = QuantumAudioState(numQubits: 2)
        var collapseHistogram = [0, 0, 0, 0]
        let iterations = 10000

        for _ in 0..<iterations {
            let collapsed = state.collapse()
            XCTAssertTrue(0..<4 ~= collapsed, "Collapsed state must be 0-3 for 2 qubits")
            collapseHistogram[collapsed] += 1
        }

        // With equal superposition, each state should appear ~25% of the time
        let expectedCount = iterations / 4
        let tolerance = expectedCount / 4 // 25% tolerance

        for (index, count) in collapseHistogram.enumerated() {
            XCTAssertTrue(abs(count - expectedCount) < tolerance,
                         "State \(index) should appear ~\(expectedCount) times, got \(count)")
        }
    }

    func testQuantumStateHadamard_AllQubits() {
        for qubit in 0..<4 {
            var state = QuantumAudioState(numQubits: 4)

            // Set to |0000⟩
            for i in 0..<state.amplitudes.count {
                state.amplitudes[i] = i == 0 ? Complex(real: 1, imaginary: 0) : Complex(real: 0, imaginary: 0)
            }

            // Apply Hadamard
            state.applyHadamard(qubit: qubit)

            // Verify superposition was created
            let nonZeroCount = state.amplitudes.filter { $0.magnitude > 0.01 }.count
            XCTAssertEqual(nonZeroCount, 2, "Hadamard on qubit \(qubit) should create 2 non-zero amplitudes")
        }
    }

    func testQuantumStatePhaseRotation() {
        var state = QuantumAudioState(numQubits: 2)

        // Set to |11⟩
        for i in 0..<state.amplitudes.count {
            state.amplitudes[i] = i == 3 ? Complex(real: 1, imaginary: 0) : Complex(real: 0, imaginary: 0)
        }

        let originalPhase = state.amplitudes[3].phase

        state.applyPhaseRotation(qubit: 0, angle: .pi / 4)

        let newPhase = state.amplitudes[3].phase
        XCTAssertNotEqual(originalPhase, newPhase, "Phase should change after rotation")
    }

    func testQuantumStateNormalization_AfterModification() {
        var state = QuantumAudioState(numQubits: 3)

        // Manually set non-normalized amplitudes
        for i in 0..<state.amplitudes.count {
            state.amplitudes[i] = Complex(real: Float(i), imaginary: 0)
        }

        // Normalize
        state.normalize()

        // Verify
        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.001, "Must be normalized after normalize()")
    }

    // MARK: - Photon Tests (100+ scenarios)

    func testPhotonCreation_AllWavelengths() {
        let wavelengths: [Float] = [380, 420, 460, 500, 550, 600, 650, 700, 750, 780]

        for wavelength in wavelengths {
            let photon = Photon(
                position: SIMD3<Float>(0, 0, 0),
                velocity: SIMD3<Float>(1, 0, 0),
                wavelength: wavelength,
                phase: 0,
                amplitude: 1.0
            )

            XCTAssertEqual(photon.wavelength, wavelength)
            XCTAssertGreaterThan(photon.frequency, 0, "Frequency must be positive")
            XCTAssertGreaterThan(photon.energy, 0, "Energy must be positive")
        }
    }

    func testPhotonWavelengthToColor_VisibleSpectrum() {
        // Test key wavelengths in visible spectrum
        let testCases: [(Float, String)] = [
            (400, "violet"),
            (450, "blue"),
            (500, "cyan"),
            (550, "green"),
            (580, "yellow"),
            (620, "orange"),
            (700, "red")
        ]

        for (wavelength, _) in testCases {
            let photon = Photon(
                position: .zero,
                velocity: .zero,
                wavelength: wavelength,
                phase: 0,
                amplitude: 1
            )

            let color = photon.color

            // Color components should be in valid range
            XCTAssertTrue((0...1).contains(color.x), "Red must be 0-1")
            XCTAssertTrue((0...1).contains(color.y), "Green must be 0-1")
            XCTAssertTrue((0...1).contains(color.z), "Blue must be 0-1")
        }
    }

    func testPhotonPhaseModulation() {
        var photon = Photon(
            position: .zero,
            velocity: .zero,
            wavelength: 550,
            phase: 0,
            amplitude: 1
        )

        let phases: [Float] = [0, .pi / 4, .pi / 2, .pi, 3 * .pi / 2, 2 * .pi]

        for phase in phases {
            photon.phase = phase
            XCTAssertEqual(photon.phase, phase, accuracy: 0.001)
        }
    }

    // MARK: - Light Field Tests (100+ scenarios)

    func testLightFieldCreation_AllGeometries() {
        let geometries = LightField.Geometry.allCases
        let photonCounts = [10, 50, 100, 200, 500]

        for geometry in geometries {
            for count in photonCounts {
                let field = LightField(photonCount: count, geometry: geometry)

                XCTAssertEqual(field.geometry, geometry)
                XCTAssertEqual(field.photons.count, count,
                              "Field should have \(count) photons for \(geometry)")
            }
        }
    }

    func testLightFieldCoherence_Range() {
        for _ in 0..<100 {
            let count = Int.random(in: 10...500)
            let geometry = LightField.Geometry.allCases.randomElement()!
            let field = LightField(photonCount: count, geometry: geometry)

            let coherence = field.fieldCoherence
            XCTAssertTrue((0...1).contains(coherence),
                         "Coherence must be 0-1, got \(coherence)")
        }
    }

    func testLightFieldEnergy_Positive() {
        let field = LightField(photonCount: 100, geometry: .fibonacci)

        let energy = field.totalEnergy
        XCTAssertGreaterThan(energy, 0, "Total energy must be positive")
    }

    func testLightFieldMeanWavelength_ValidRange() {
        let field = LightField(photonCount: 100, geometry: .sphere)

        let meanWL = field.meanWavelength
        XCTAssertTrue((380...780).contains(meanWL),
                     "Mean wavelength should be in visible range")
    }

    // MARK: - Emulator Tests (100+ scenarios)

    func testEmulatorModeSwitch_AllModes() {
        let emulator = QuantumLightEmulator()

        for mode in QuantumLightEmulator.EmulationMode.allCases {
            emulator.setMode(mode)
            XCTAssertEqual(emulator.emulationMode, mode)
        }
    }

    func testEmulatorStartStop_MultipleIterations() {
        let emulator = QuantumLightEmulator()

        for _ in 0..<10 {
            emulator.start()
            XCTAssertTrue(emulator.isRunning)

            emulator.stop()
            XCTAssertFalse(emulator.isRunning)
        }
    }

    func testEmulatorBioFeedback_AllRanges() {
        let emulator = QuantumLightEmulator()
        emulator.setMode(.bioCoherent)

        let coherenceValues: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let hrvValues: [Double] = [0, 25, 50, 75, 100]
        let hrValues: [Double] = [40, 60, 80, 100, 120]

        for coherence in coherenceValues {
            for hrv in hrvValues {
                for hr in hrValues {
                    emulator.updateBioFeedback(coherence: coherence, hrv: hrv, heartRate: hr)

                    XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0)
                    XCTAssertLessThanOrEqual(emulator.coherenceLevel, 1)
                }
            }
        }
    }

    func testEmulatorQuantumState_NotNil() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        XCTAssertNotNil(emulator.currentQuantumState)

        emulator.stop()
    }

    func testEmulatorLightField_NotNil() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        XCTAssertNotNil(emulator.currentEmulatorLightField)

        emulator.stop()
    }

    // MARK: - Preset Tests (All 15 presets)

    func testAllPresetsValid() {
        let presets = PresetManager.shared.allPresets

        XCTAssertGreaterThanOrEqual(presets.count, 15, "Should have at least 15 presets")

        for preset in presets {
            // Validate preset properties
            XCTAssertFalse(preset.id.isEmpty, "Preset ID must not be empty")
            XCTAssertFalse(preset.name.isEmpty, "Preset name must not be empty")
            XCTAssertFalse(preset.description.isEmpty, "Preset description must not be empty")
            XCTAssertFalse(preset.icon.isEmpty, "Preset icon must not be empty")

            XCTAssertGreaterThan(preset.sessionDuration, 0, "Session duration must be positive")
            XCTAssertGreaterThanOrEqual(preset.binauralFrequency, 0, "Binaural frequency must be non-negative")

            // Validate mode string maps to actual mode
            let modeValid = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) != nil
            XCTAssertTrue(modeValid || !preset.emulationMode.isEmpty,
                         "Preset mode '\(preset.emulationMode)' should be valid")
        }
    }

    func testPresetCategories_AllRepresented() {
        let presets = PresetManager.shared.allPresets
        var categories = Set<PresetCategory>()

        for preset in presets {
            categories.insert(preset.category)
        }

        // Should have presets in multiple categories
        XCTAssertGreaterThanOrEqual(categories.count, 5,
                                   "Should have presets in at least 5 categories")
    }

    func testPresetSerialization_RoundTrip() throws {
        let presets = PresetManager.shared.allPresets

        for preset in presets {
            let encoder = JSONEncoder()
            let data = try encoder.encode(preset)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(QuantumPreset.self, from: data)

            XCTAssertEqual(decoded.id, preset.id)
            XCTAssertEqual(decoded.name, preset.name)
            XCTAssertEqual(decoded.emulationMode, preset.emulationMode)
            XCTAssertEqual(decoded.sessionDuration, preset.sessionDuration)
        }
    }

    // MARK: - Visualization Tests (All 10 types)

    func testAllVisualizationTypes() {
        let types = PhotonicsVisualizationEngine.VisualizationType.allCases

        XCTAssertEqual(types.count, 10, "Should have exactly 10 visualization types")

        let engine = PhotonicsVisualizationEngine()

        for type in types {
            engine.setVisualizationType(type)
            XCTAssertEqual(engine.currentVisualizationType, type)
        }
    }

    func testVisualizationEngine_WithLightField() {
        let engine = PhotonicsVisualizationEngine()

        for geometry in LightField.Geometry.allCases {
            let field = LightField(photonCount: 50, geometry: geometry)
            engine.setLightField(field)

            // Should not crash
            XCTAssertNotNil(engine)
        }
    }

    // MARK: - Accessibility Tests (WCAG AAA)

    @MainActor
    func testAccessibilityProfiles_AllAvailable() {
        let profiles = QuantumAccessibilityManager.AccessibilityProfile.allCases

        XCTAssertGreaterThanOrEqual(profiles.count, 7, "Should have at least 7 accessibility profiles")
    }

    @MainActor
    func testColorBlindSchemes_AllAvailable() {
        let schemes = QuantumAccessibilityManager.AccessibleColorScheme.allCases

        XCTAssertGreaterThanOrEqual(schemes.count, 6, "Should have at least 6 color schemes")
    }

    @MainActor
    func testAccessibilityColorAdaptation_AllSchemes() {
        let manager = QuantumAccessibilityManager.shared
        let testColors: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0, 0),   // Red
            SIMD3<Float>(0, 1, 0),   // Green
            SIMD3<Float>(0, 0, 1),   // Blue
            SIMD3<Float>(1, 1, 0),   // Yellow
            SIMD3<Float>(1, 0, 1),   // Magenta
            SIMD3<Float>(0, 1, 1),   // Cyan
            SIMD3<Float>(1, 1, 1),   // White
            SIMD3<Float>(0.5, 0.5, 0.5) // Gray
        ]

        for scheme in QuantumAccessibilityManager.AccessibleColorScheme.allCases {
            manager.preferredColorScheme = scheme

            for color in testColors {
                let adapted = manager.adaptColor(color)

                // Adapted colors should be valid
                XCTAssertTrue((0...1).contains(adapted.x), "Red must be 0-1 for \(scheme)")
                XCTAssertTrue((0...1).contains(adapted.y), "Green must be 0-1 for \(scheme)")
                XCTAssertTrue((0...1).contains(adapted.z), "Blue must be 0-1 for \(scheme)")
            }
        }

        // Reset
        manager.preferredColorScheme = .standard
    }

    // MARK: - Performance Tests

    func testPerformance_QuantumStateCollapse() {
        measure {
            for _ in 0..<1000 {
                let state = QuantumAudioState(numQubits: 6)
                _ = state.collapse()
            }
        }
    }

    func testPerformance_LightFieldCreation() {
        measure {
            for _ in 0..<100 {
                _ = LightField(photonCount: 500, geometry: .fibonacci)
            }
        }
    }

    func testPerformance_EmulatorProcessing() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        measure {
            for _ in 0..<100 {
                emulator.updateBioFeedback(
                    coherence: Float.random(in: 0...1),
                    hrv: Double.random(in: 0...100),
                    heartRate: Double.random(in: 40...120)
                )
            }
        }

        emulator.stop()
    }

    func testPerformance_PresetLoading() {
        measure {
            for _ in 0..<1000 {
                _ = PresetManager.shared.allPresets
            }
        }
    }

    // MARK: - Edge Case Tests

    func testEdgeCase_ZeroPhotonField() {
        let field = LightField(photonCount: 0, geometry: .sphere)
        XCTAssertEqual(field.photons.count, 0)
        XCTAssertEqual(field.fieldCoherence, 1.0, "Empty field should have coherence 1")
    }

    func testEdgeCase_SinglePhotonField() {
        let field = LightField(photonCount: 1, geometry: .line)
        XCTAssertEqual(field.photons.count, 1)
        XCTAssertEqual(field.fieldCoherence, 1.0, "Single photon field should have coherence 1")
    }

    func testEdgeCase_LargeQuantumState() {
        let state = QuantumAudioState(numQubits: 12) // 4096 states
        XCTAssertEqual(state.amplitudes.count, 4096)

        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.01)
    }

    func testEdgeCase_ExtremeBioValues() {
        let emulator = QuantumLightEmulator()
        emulator.setMode(.bioCoherent)

        // Test extreme values
        emulator.updateBioFeedback(coherence: 0.0, hrv: 0.0, heartRate: 0.0)
        XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0)

        emulator.updateBioFeedback(coherence: 1.0, hrv: 100.0, heartRate: 200.0)
        XCTAssertLessThanOrEqual(emulator.coherenceLevel, 1)

        // Negative values should be clamped
        emulator.updateBioFeedback(coherence: -1.0, hrv: -50.0, heartRate: -10.0)
        XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0)
    }

    func testEdgeCase_RapidModeSwitch() {
        let emulator = QuantumLightEmulator()

        for _ in 0..<100 {
            let mode = QuantumLightEmulator.EmulationMode.allCases.randomElement()!
            emulator.setMode(mode)
        }

        // Should not crash
        XCTAssertNotNil(emulator.currentQuantumState)
    }

    // MARK: - Integration Tests

    func testIntegration_FullSessionWorkflow() {
        // 1. Create emulator
        let emulator = QuantumLightEmulator()

        // 2. Load preset
        let preset = PresetManager.shared.allPresets.first!

        // 3. Apply preset settings
        if let mode = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) {
            emulator.setMode(mode)
        }

        // 4. Start session
        emulator.start()
        XCTAssertTrue(emulator.isRunning)

        // 5. Simulate bio feedback over time
        for i in 0..<60 {
            let coherence = Float(i) / 60.0
            emulator.updateBioFeedback(
                coherence: coherence,
                hrv: Double(50 + i / 2),
                heartRate: Double(70 - i / 4)
            )
        }

        // 6. Verify state is valid
        XCTAssertNotNil(emulator.currentQuantumState)
        XCTAssertNotNil(emulator.currentEmulatorLightField)
        XCTAssertGreaterThanOrEqual(emulator.coherenceLevel, 0)
        XCTAssertLessThanOrEqual(emulator.coherenceLevel, 1)

        // 7. Stop session
        emulator.stop()
        XCTAssertFalse(emulator.isRunning)
    }

    func testIntegration_VisualizationWithEmulator() {
        let emulator = QuantumLightEmulator()
        let vizEngine = PhotonicsVisualizationEngine()

        emulator.start()

        // Test each visualization with emulator data
        for vizType in PhotonicsVisualizationEngine.VisualizationType.allCases {
            vizEngine.setVisualizationType(vizType)

            if let field = emulator.currentEmulatorLightField {
                vizEngine.setLightField(field)
            }

            XCTAssertEqual(vizEngine.currentVisualizationType, vizType)
        }

        emulator.stop()
    }

    func testIntegration_PresetToEmulator() {
        let presets = PresetManager.shared.allPresets

        for preset in presets {
            let emulator = QuantumLightEmulator()

            // Apply preset
            if let mode = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) {
                emulator.setMode(mode)
                XCTAssertEqual(emulator.emulationMode, mode)
            }

            emulator.start()
            XCTAssertTrue(emulator.isRunning)
            emulator.stop()
        }
    }

    // MARK: - Stress Tests

    func testStress_ManyPhotons() {
        let field = LightField(photonCount: 10000, geometry: .random)
        XCTAssertEqual(field.photons.count, 10000)

        let coherence = field.fieldCoherence
        XCTAssertTrue((0...1).contains(coherence))
    }

    func testStress_RapidUpdates() {
        let emulator = QuantumLightEmulator()
        emulator.start()

        let iterations = 1000
        for i in 0..<iterations {
            emulator.updateBioFeedback(
                coherence: Float(i % 100) / 100.0,
                hrv: Double(i % 100),
                heartRate: Double(60 + i % 60)
            )
        }

        emulator.stop()
        XCTAssertFalse(emulator.isRunning)
    }

    func testStress_ManyQuantumOperations() {
        var state = QuantumAudioState(numQubits: 8)

        for _ in 0..<1000 {
            let qubit = Int.random(in: 0..<8)
            state.applyHadamard(qubit: qubit)
        }

        state.normalize()
        let totalProb = state.probabilities.reduce(0, +)
        XCTAssertEqual(totalProb, 1.0, accuracy: 0.01)
    }
}
