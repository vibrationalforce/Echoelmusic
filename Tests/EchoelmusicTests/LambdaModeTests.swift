// LambdaModeTests.swift
// Echoelmusic - Comprehensive λ Lambda Mode Tests
// Phase λ∞ TRANSCENDENCE MODE Test Suite
// Created 2026-01-05

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Lambda Mode Engine and Quantum Loop Light Science
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LambdaModeTests: XCTestCase {

    //==========================================================================
    // MARK: - Lambda Constants Tests
    //==========================================================================

    func testLambdaConstantsGoldenRatio() {
        // Golden ratio should be approximately 1.618
        XCTAssertEqual(LambdaConstants.phi, (1.0 + sqrt(5.0)) / 2.0, accuracy: 0.0001)
        XCTAssertEqual(LambdaConstants.phi, 1.618033988749895, accuracy: 0.0001)
    }

    func testLambdaConstantsSchumannResonance() {
        // Earth's fundamental frequency
        XCTAssertEqual(LambdaConstants.schumannResonance, 7.83, accuracy: 0.01)
    }

    func testLambdaConstantsCoherenceRange() {
        // Optimal coherence frequency range
        XCTAssertTrue(LambdaConstants.coherenceFrequencyRange.contains(0.1))
        XCTAssertTrue(LambdaConstants.coherenceFrequencyRange.contains(0.04))
        XCTAssertTrue(LambdaConstants.coherenceFrequencyRange.contains(0.26))
        XCTAssertFalse(LambdaConstants.coherenceFrequencyRange.contains(0.03))
        XCTAssertFalse(LambdaConstants.coherenceFrequencyRange.contains(0.27))
    }

    func testLambdaConstantsFlowThreshold() {
        XCTAssertEqual(LambdaConstants.flowThreshold, 0.75)
    }

    //==========================================================================
    // MARK: - Lambda State Tests
    //==========================================================================

    func testLambdaStateAllCases() {
        XCTAssertEqual(LambdaState.allCases.count, 8)
    }

    func testLambdaStateDisplayNames() {
        XCTAssertEqual(LambdaState.dormant.displayName, "Dormant")
        XCTAssertEqual(LambdaState.awakening.displayName, "Awakening")
        XCTAssertEqual(LambdaState.lambda.displayName, "λ∞ Lambda")
    }

    func testLambdaStateEmojis() {
        XCTAssertEqual(LambdaState.dormant.emoji, "🌑")
        XCTAssertEqual(LambdaState.lambda.emoji, "λ")
        XCTAssertEqual(LambdaState.coherent.emoji, "💎")
    }

    func testLambdaStateColorHues() {
        // Color hues should be in valid range 0-1
        for state in LambdaState.allCases {
            XCTAssertGreaterThanOrEqual(state.colorHue, 0.0)
            XCTAssertLessThanOrEqual(state.colorHue, 1.0)
        }
    }

    //==========================================================================
    // MARK: - Unified Bio Data Tests
    //==========================================================================

    func testUnifiedBioDataDefaults() {
        let bioData = UnifiedBioData()

        XCTAssertEqual(bioData.heartRate, 70.0)
        XCTAssertEqual(bioData.hrvMs, 50.0)
        XCTAssertEqual(bioData.hrvCoherence, 0.5)
        XCTAssertEqual(bioData.breathingRate, 12.0)
        XCTAssertEqual(bioData.breathPhase, 0.5)
        XCTAssertEqual(bioData.spo2, 98.0)
    }

    func testUnifiedBioDataOverallCoherence() {
        var bioData = UnifiedBioData()

        // High coherence scenario
        bioData.hrvCoherence = 0.9
        bioData.breathingRate = 6.0  // Optimal
        bioData.peripheralTemperature = 35.0  // Warm
        bioData.skinConductance = 0.2  // Relaxed

        let coherence = bioData.overallCoherence
        XCTAssertGreaterThan(coherence, 0.7)
    }

    func testUnifiedBioDataFlowStateDetection() {
        var bioData = UnifiedBioData()

        // Not in flow
        bioData.flowScore = 0.5
        XCTAssertFalse(bioData.isInFlowState)

        // In flow
        bioData.flowScore = 0.8
        XCTAssertTrue(bioData.isInFlowState)

        // At threshold
        bioData.flowScore = 0.75
        XCTAssertFalse(bioData.isInFlowState)

        bioData.flowScore = 0.76
        XCTAssertTrue(bioData.isInFlowState)
    }

    //==========================================================================
    // MARK: - Unified Audio State Tests
    //==========================================================================

    func testUnifiedAudioStateDefaults() {
        let audioState = UnifiedAudioState()

        XCTAssertEqual(audioState.level, 0.0)
        XCTAssertEqual(audioState.bpm, 120.0)
        XCTAssertEqual(audioState.keyDetected, "C")
        XCTAssertEqual(audioState.spectrumBands.count, 64)
    }

    //==========================================================================
    // MARK: - Health Disclaimer Tests
    //==========================================================================

    func testHealthDisclaimerContainsRequiredText() {
        let fullDisclaimer = LambdaHealthDisclaimer.fullDisclaimer

        // Must contain key disclaimers
        XCTAssertTrue(fullDisclaimer.contains("NOT a medical device"))
        XCTAssertTrue(fullDisclaimer.contains("NOT intended to diagnose"))
        XCTAssertTrue(fullDisclaimer.contains("NOT a substitute for professional"))
        XCTAssertTrue(fullDisclaimer.contains("CONSULT A QUALIFIED HEALTHCARE PROVIDER"))
    }

    func testHealthDisclaimerShortVersion() {
        let shortDisclaimer = LambdaHealthDisclaimer.shortDisclaimer

        XCTAssertTrue(shortDisclaimer.contains("wellness"))
        XCTAssertTrue(shortDisclaimer.contains("Not medical advice"))
        XCTAssertLessThan(shortDisclaimer.count, 200)  // Should be concise
    }

    func testBiometricDisclaimer() {
        let disclaimer = LambdaHealthDisclaimer.biometricDisclaimer

        XCTAssertTrue(disclaimer.contains("Biometric"))
        XCTAssertTrue(disclaimer.contains("not be accurate"))
    }

    func testBreathingDisclaimer() {
        let disclaimer = LambdaHealthDisclaimer.breathingDisclaimer

        XCTAssertTrue(disclaimer.contains("relaxation"))
        XCTAssertTrue(disclaimer.contains("Stop if"))
    }

    //==========================================================================
    // MARK: - Lambda Mode Engine Tests
    //==========================================================================

    @MainActor
    func testLambdaModeEngineInitialization() async {
        let engine = LambdaModeEngine()

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.state, .dormant)
        XCTAssertEqual(engine.lambdaScore, 0.0)
        XCTAssertTrue(engine.bioSyncEnabled)
        XCTAssertTrue(engine.audioSyncEnabled)
    }

    @MainActor
    func testLambdaModeEngineActivation() async {
        let engine = LambdaModeEngine()

        engine.activate()
        XCTAssertTrue(engine.isActive)

        // Should transition to awakening
        XCTAssertEqual(engine.state, .awakening)

        engine.deactivate()
        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.state, .dormant)
    }

    @MainActor
    func testLambdaModeEngineToggle() async {
        let engine = LambdaModeEngine()

        XCTAssertFalse(engine.isActive)

        engine.toggle()
        XCTAssertTrue(engine.isActive)

        engine.toggle()
        XCTAssertFalse(engine.isActive)
    }

    @MainActor
    func testLambdaModeEngineBioDataUpdate() async {
        let engine = LambdaModeEngine()

        var bioData = UnifiedBioData()
        bioData.heartRate = 75.0
        bioData.hrvMs = 60.0
        bioData.hrvCoherence = 0.8

        engine.updateBioData(bioData)

        XCTAssertEqual(engine.bioData.heartRate, 75.0)
        XCTAssertEqual(engine.bioData.hrvMs, 60.0)
        XCTAssertEqual(engine.bioData.hrvCoherence, 0.8)
        XCTAssertTrue(engine.bioEngineActive)
    }

    @MainActor
    func testLambdaModeEngineBioSimulation() async {
        let engine = LambdaModeEngine()

        engine.simulateBioData()

        // Should have non-default values
        XCTAssertNotEqual(engine.bioData.hrvCoherence, 0.5)
        XCTAssertTrue(engine.bioEngineActive)
    }

    @MainActor
    func testLambdaModeEnginePresets() async {
        let engine = LambdaModeEngine()

        engine.loadMeditationPreset()
        XCTAssertTrue(engine.bioSyncEnabled)
        XCTAssertFalse(engine.audioSyncEnabled)
        XCTAssertTrue(engine.quantumModeEnabled)

        engine.loadCreativePreset()
        XCTAssertTrue(engine.bioSyncEnabled)
        XCTAssertTrue(engine.audioSyncEnabled)
        XCTAssertTrue(engine.creativeEngineActive)

        engine.loadPerformancePreset()
        XCTAssertEqual(engine.visualState.particleCount, 500)

        engine.loadWellnessPreset()
        XCTAssertFalse(engine.quantumModeEnabled)
    }

    @MainActor
    func testLambdaModeEngineSessionStats() async {
        let engine = LambdaModeEngine()
        engine.activate()

        let stats = engine.sessionStats

        XCTAssertGreaterThanOrEqual(stats.duration, 0)
        XCTAssertGreaterThanOrEqual(stats.lambdaScore, 0)
        XCTAssertLessThanOrEqual(stats.lambdaScore, 1)

        engine.deactivate()
    }

    //==========================================================================
    // MARK: - Quantum Light Constants Tests
    //==========================================================================

    func testQuantumLightConstantsPhysics() {
        // Physical constants should be positive
        XCTAssertGreaterThan(QuantumLightConstants.planckLength, 0)
        XCTAssertGreaterThan(QuantumLightConstants.planckTime, 0)
        XCTAssertGreaterThan(QuantumLightConstants.speedOfLight, 0)
    }

    func testQuantumLightConstantsCreative() {
        XCTAssertEqual(QuantumLightConstants.photonDensityMax, 10000)
        XCTAssertEqual(QuantumLightConstants.phi, LambdaConstants.phi, accuracy: 0.0001)
    }

    func testQuantumLightConstantsSacredAngle() {
        // Golden angle should be ~137.5 degrees
        XCTAssertEqual(QuantumLightConstants.sacredAngle, 137.5077640500378, accuracy: 0.01)
    }

    func testQuantumLightConstantsSchumannHarmonics() {
        let harmonics = QuantumLightConstants.schumannHarmonics
        XCTAssertEqual(harmonics.count, 5)
        XCTAssertEqual(harmonics[0], 7.83, accuracy: 0.01)
    }

    //==========================================================================
    // MARK: - Quantum State Type Tests
    //==========================================================================

    func testQuantumStateTypeAllCases() {
        XCTAssertEqual(QuantumStateType.allCases.count, 9)
    }

    func testQuantumStateTypeSymbols() {
        XCTAssertEqual(QuantumStateType.groundState.symbol, "|0⟩")
        XCTAssertEqual(QuantumStateType.excitedState.symbol, "|1⟩")
        XCTAssertEqual(QuantumStateType.superposition.symbol, "|ψ⟩")
        XCTAssertEqual(QuantumStateType.entangled.symbol, "|Φ⁺⟩")
        XCTAssertEqual(QuantumStateType.catState.symbol, "|🐱⟩")
    }

    //==========================================================================
    // MARK: - Light Field Geometry Tests
    //==========================================================================

    func testLightFieldGeometryAllCases() {
        XCTAssertEqual(LightFieldGeometry.allCases.count, 9)
    }

    func testLightFieldGeometryDimensionality() {
        XCTAssertEqual(LightFieldGeometry.spherical.dimensionality, 3)
        XCTAssertEqual(LightFieldGeometry.toroidal.dimensionality, 3)
        XCTAssertEqual(LightFieldGeometry.hopfFibration.dimensionality, 4)
        XCTAssertEqual(LightFieldGeometry.calabi_yau.dimensionality, 6)
    }

    //==========================================================================
    // MARK: - Quantum Photon Tests
    //==========================================================================

    func testQuantumPhotonInitialization() {
        let photon = QuantumPhoton()

        XCTAssertEqual(photon.position, .zero)
        XCTAssertEqual(photon.wavelength, 550)
        XCTAssertEqual(photon.amplitude, 1.0)
        XCTAssertEqual(photon.coherence, 1.0)
        XCTAssertNil(photon.entangledWith)
    }

    func testQuantumPhotonColor() {
        // Green wavelength
        let greenPhoton = QuantumPhoton(wavelength: 550)
        let greenColor = greenPhoton.color
        XCTAssertGreaterThan(greenColor.y, greenColor.x)  // Green > Red
        XCTAssertGreaterThan(greenColor.y, greenColor.z)  // Green > Blue

        // Red wavelength
        let redPhoton = QuantumPhoton(wavelength: 650)
        let redColor = redPhoton.color
        XCTAssertGreaterThan(redColor.x, redColor.y)  // Red > Green

        // Blue wavelength
        let bluePhoton = QuantumPhoton(wavelength: 450)
        let blueColor = bluePhoton.color
        XCTAssertGreaterThan(blueColor.z, blueColor.y)  // Blue > Green
    }

    //==========================================================================
    // MARK: - Wave Function Tests
    //==========================================================================

    func testWaveFunctionInitialization() {
        let wf = WaveFunction(gridSize: 32)

        XCTAssertEqual(wf.gridSize, 32)
        XCTAssertEqual(wf.realPart.count, 32 * 32)
        XCTAssertEqual(wf.imaginaryPart.count, 32 * 32)
    }

    func testWaveFunctionProbabilityDensity() {
        var wf = WaveFunction(gridSize: 4)

        // Set a specific value
        wf.realPart[0] = 0.6
        wf.imaginaryPart[0] = 0.8

        let density = wf.probabilityDensity

        // |ψ|² = 0.6² + 0.8² = 0.36 + 0.64 = 1.0
        XCTAssertEqual(density[0], 1.0, accuracy: 0.001)
    }

    func testWaveFunctionNormalization() {
        var wf = WaveFunction(gridSize: 4)

        // Set non-normalized values
        for i in wf.realPart.indices {
            wf.realPart[i] = 1.0
            wf.imaginaryPart[i] = 0.0
        }

        wf.normalize()

        let total = wf.probabilityDensity.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.001)
    }

    //==========================================================================
    // MARK: - Light Field Tests
    //==========================================================================

    func testLightFieldInitialization() {
        let field = LightField(photonCount: 100)

        XCTAssertEqual(field.photons.count, 100)
        XCTAssertEqual(field.geometry, .fibonacci)
    }

    func testLightFieldGeometries() {
        for geometry in LightFieldGeometry.allCases {
            let field = LightField(geometry: geometry, photonCount: 50)
            XCTAssertEqual(field.photons.count, 50)
            XCTAssertEqual(field.geometry, geometry)
        }
    }

    //==========================================================================
    // MARK: - Quantum Loop Light Science Engine Tests
    //==========================================================================

    @MainActor
    func testQuantumLoopLightScienceEngineInitialization() async {
        let engine = QuantumLoopLightScienceEngine()

        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.currentState, .groundState)
        XCTAssertEqual(engine.geometry, .fibonacci)
        XCTAssertEqual(engine.photonCount, 500)
    }

    @MainActor
    func testQuantumLoopLightScienceEngineStartStop() async {
        let engine = QuantumLoopLightScienceEngine()

        engine.start()
        XCTAssertTrue(engine.isActive)

        engine.stop()
        XCTAssertFalse(engine.isActive)
    }

    @MainActor
    func testQuantumLoopLightScienceEngineBioUpdate() async {
        let engine = QuantumLoopLightScienceEngine()

        engine.updateBioData(coherence: 0.8, heartRate: 72, breathRate: 6)

        XCTAssertEqual(engine.bioCoherence, 0.8)
        XCTAssertEqual(engine.heartRateFrequency, 72.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(engine.breathFrequency, 6.0 / 60.0, accuracy: 0.001)
    }

    @MainActor
    func testQuantumLoopLightScienceEngineGeometryChange() async {
        let engine = QuantumLoopLightScienceEngine()

        engine.setGeometry(.toroidal)
        XCTAssertEqual(engine.geometry, .toroidal)
        XCTAssertEqual(engine.lightField.geometry, .toroidal)
    }

    @MainActor
    func testQuantumLoopLightScienceEnginePhotonCount() async {
        let engine = QuantumLoopLightScienceEngine()

        engine.setPhotonCount(200)
        XCTAssertEqual(engine.photonCount, 200)
        XCTAssertEqual(engine.lightField.photons.count, 200)

        // Should clamp to valid range
        engine.setPhotonCount(5)
        XCTAssertEqual(engine.photonCount, 10)  // Min is 10

        engine.setPhotonCount(50000)
        XCTAssertEqual(engine.photonCount, 10000)  // Max is 10000
    }

    @MainActor
    func testQuantumLoopLightScienceEngineMeasurement() async {
        let engine = QuantumLoopLightScienceEngine()
        engine.updateBioData(coherence: 0.9, heartRate: 70, breathRate: 6)

        let result = engine.measure()

        XCTAssertTrue(result.state == 0 || result.state == 1)
        XCTAssertEqual(result.coherence, 0.9)
    }

    @MainActor
    func testQuantumLoopLightScienceEnginePresets() async {
        let engine = QuantumLoopLightScienceEngine()

        engine.loadMeditationPreset()
        XCTAssertEqual(engine.geometry, .fibonacci)
        XCTAssertEqual(engine.photonCount, 200)

        engine.loadEnergeticPreset()
        XCTAssertEqual(engine.geometry, .toroidal)
        XCTAssertEqual(engine.photonCount, 800)

        engine.loadCosmicPreset()
        XCTAssertEqual(engine.geometry, .spherical)
        XCTAssertEqual(engine.photonCount, 1000)

        engine.loadSacredGeometryPreset()
        XCTAssertEqual(engine.geometry, .platonic)
    }

    //==========================================================================
    // MARK: - Integration Tests
    //==========================================================================

    @MainActor
    func testLambdaAndQuantumIntegration() async {
        let lambdaEngine = LambdaModeEngine()
        let quantumEngine = QuantumLoopLightScienceEngine()

        // Activate both
        lambdaEngine.activate()
        quantumEngine.start()

        // Simulate bio data
        lambdaEngine.simulateBioData()

        // Transfer bio data to quantum engine
        quantumEngine.updateBioData(
            coherence: lambdaEngine.bioData.hrvCoherence,
            heartRate: lambdaEngine.bioData.heartRate,
            breathRate: lambdaEngine.bioData.breathingRate
        )

        XCTAssertEqual(quantumEngine.bioCoherence, lambdaEngine.bioData.hrvCoherence)

        // Cleanup
        lambdaEngine.deactivate()
        quantumEngine.stop()
    }

    @MainActor
    func testFullSessionSimulation() async {
        let engine = LambdaModeEngine()

        // Start session
        engine.activate()
        XCTAssertEqual(engine.state, .awakening)

        // Simulate bio data multiple times
        for _ in 0..<10 {
            engine.simulateBioData()
        }

        // Check session stats accumulated
        let stats = engine.sessionStats
        XCTAssertGreaterThanOrEqual(stats.duration, 0)

        // End session
        engine.deactivate()
        XCTAssertFalse(engine.isActive)
    }

    //==========================================================================
    // MARK: - Edge Case Tests
    //==========================================================================

    func testBioDataBoundaryValues() {
        var bioData = UnifiedBioData()

        // Zero coherence
        bioData.hrvCoherence = 0.0
        XCTAssertFalse(bioData.isInFlowState)

        // Max coherence
        bioData.hrvCoherence = 1.0
        bioData.flowScore = 1.0
        XCTAssertTrue(bioData.isInFlowState)
    }

    func testWaveFunctionEmptyGrid() {
        let wf = WaveFunction(gridSize: 0)
        XCTAssertEqual(wf.realPart.count, 0)
        XCTAssertEqual(wf.probabilityDensity.count, 0)
    }

    func testPhotonWavelengthBoundaries() {
        // UV (below visible)
        let uvPhoton = QuantumPhoton(wavelength: 300)
        let uvColor = uvPhoton.color
        XCTAssertEqual(uvColor.x, 0)
        XCTAssertEqual(uvColor.y, 0)
        XCTAssertEqual(uvColor.z, 0)

        // IR (above visible)
        let irPhoton = QuantumPhoton(wavelength: 800)
        let irColor = irPhoton.color
        XCTAssertEqual(irColor.x, 0)
        XCTAssertEqual(irColor.y, 0)
        XCTAssertEqual(irColor.z, 0)
    }

    //==========================================================================
    // MARK: - Performance Tests
    //==========================================================================

    func testLightFieldGenerationPerformance() {
        measure {
            _ = LightField(photonCount: 1000)
        }
    }

    func testWaveFunctionNormalizationPerformance() {
        var wf = WaveFunction(gridSize: 128)
        for i in wf.realPart.indices {
            wf.realPart[i] = Float.random(in: 0...1)
            wf.imaginaryPart[i] = Float.random(in: 0...1)
        }

        measure {
            wf.normalize()
        }
    }
}
