//
//  VisionOS100PercentTests.swift
//  Echoelmusic
//
//  Comprehensive Test Suite for visionOS 100% Completion
//  Tests all new features: animations, gestures, colors, haptics, LOD, streaming
//
//  Created: 2026-01-25
//

import XCTest
import simd
@testable import Echoelmusic

// MARK: - VisionOS Animation Controller Tests

final class VisionOSAnimationControllerTests: XCTestCase {

    var animationController: VisionOSAnimationController!

    override func setUp() async throws {
        await MainActor.run {
            animationController = VisionOSAnimationController()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            animationController.stop()
            animationController = nil
        }
    }

    // MARK: - Heart Sync Tests

    @MainActor
    func testHeartPulseValue_AtDefaultBPM_ReturnsValidRange() {
        // Heart pulse should be 0-1
        let pulse = animationController.heartPulseValue
        XCTAssertGreaterThanOrEqual(pulse, 0.0)
        XCTAssertLessThanOrEqual(pulse, 1.0)
    }

    @MainActor
    func testHeartPulseScale_WithDefaultIntensity_ReturnsPositiveScale() {
        let scale = animationController.heartPulseScale
        XCTAssertGreaterThan(scale, 0.0)
        XCTAssertLessThan(scale, 2.0) // Should be around 1.0 +/- intensity
    }

    @MainActor
    func testHeartPulseWaveforms_AllTypesCompute() {
        let waveforms: [VisionOSAnimationController.HeartSyncParameters.PulseWaveform] = [
            .sine, .cardiac, .smooth, .sharp
        ]

        for waveform in waveforms {
            animationController.heartSync.pulseWaveform = waveform
            let pulse = animationController.heartPulseValue
            XCTAssertGreaterThanOrEqual(pulse, 0.0, "Waveform \(waveform) failed")
            XCTAssertLessThanOrEqual(pulse, 1.0, "Waveform \(waveform) failed")
        }
    }

    @MainActor
    func testHeartSync_DisabledReturnsZero() {
        animationController.heartSync.enabled = false
        XCTAssertEqual(animationController.heartPulseValue, 0.0)
    }

    // MARK: - Floating Animation Tests

    @MainActor
    func testFloatingOffset_ReturnsValidVector() {
        let offset = animationController.floatingOffset
        XCTAssertFalse(offset.x.isNaN)
        XCTAssertFalse(offset.y.isNaN)
        XCTAssertFalse(offset.z.isNaN)
    }

    @MainActor
    func testFloatingOffset_DisabledReturnsZero() {
        animationController.floating.enabled = false
        let offset = animationController.floatingOffset
        XCTAssertEqual(offset, .zero)
    }

    @MainActor
    func testFloatingRotation_ReturnsValidAngle() {
        let rotation = animationController.floatingRotation
        XCTAssertFalse(rotation.isNaN)
        XCTAssertFalse(rotation.isInfinite)
    }

    // MARK: - Breathing Animation Tests

    @MainActor
    func testBreathingValue_ReturnsValidRange() {
        let value = animationController.breathingValue
        XCTAssertGreaterThanOrEqual(value, 0.0)
        XCTAssertLessThanOrEqual(value, 1.0)
    }

    @MainActor
    func testBreathingScale_ReturnsPositiveScale() {
        let scale = animationController.breathingScale
        XCTAssertGreaterThan(scale, 0.0)
        XCTAssertLessThan(scale, 2.0)
    }

    @MainActor
    func testBreathing_DisabledReturnsHalf() {
        animationController.breathing.enabled = false
        XCTAssertEqual(animationController.breathingValue, 0.5)
    }

    // MARK: - Coherence Color Tests

    @MainActor
    func testCoherenceColor_LowCoherence_ReturnsLowColor() {
        animationController.coherenceLevel = 0.2
        let color = animationController.coherenceColor
        // Should be closer to low color (red)
        XCTAssertGreaterThan(color.x, 0.5, "Red component should be high for low coherence")
    }

    @MainActor
    func testCoherenceColor_HighCoherence_ReturnsHighColor() {
        animationController.coherenceLevel = 0.9
        let color = animationController.coherenceColor
        // Should be closer to high color (cyan)
        XCTAssertGreaterThan(color.y, 0.5, "Green component should be high for high coherence")
    }

    @MainActor
    func testCoherenceColor_DisabledReturnsWhite() {
        animationController.coherence.enabled = false
        let color = animationController.coherenceColor
        XCTAssertEqual(color, SIMD3<Float>(1, 1, 1))
    }

    // MARK: - Animation Control Tests

    @MainActor
    func testStart_SetsIsAnimatingTrue() {
        animationController.start()
        XCTAssertTrue(animationController.isAnimating)
    }

    @MainActor
    func testStop_SetsIsAnimatingFalse() {
        animationController.start()
        animationController.stop()
        XCTAssertFalse(animationController.isAnimating)
    }

    @MainActor
    func testUpdateBioData_UpdatesProperties() {
        animationController.updateBioData(heartRate: 80.0, coherence: 0.8)
        XCTAssertEqual(animationController.heartRate, 80.0)
        XCTAssertEqual(animationController.coherenceLevel, 0.8)
    }
}

// MARK: - VisionOS Gesture Handler Tests

final class VisionOSGestureHandlerTests: XCTestCase {

    var gestureHandler: VisionOSGestureHandler!

    override func setUp() async throws {
        await MainActor.run {
            gestureHandler = VisionOSGestureHandler()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            gestureHandler = nil
        }
    }

    // MARK: - Visual Effect Tests

    @MainActor
    func testAllVisualEffects_HaveDescriptions() {
        for effect in VisionOSGestureHandler.VisualEffect.allCases {
            XCTAssertFalse(effect.description.isEmpty, "Effect \(effect) has no description")
        }
    }

    @MainActor
    func testTriggerVisualEffect_SetsActiveEffect() {
        gestureHandler.triggerVisualEffect(.pulse)
        XCTAssertEqual(gestureHandler.effectState.activeEffect, .pulse)
    }

    @MainActor
    func testTriggerVisualEffect_SetsProgress() {
        gestureHandler.triggerVisualEffect(.expand)
        XCTAssertEqual(gestureHandler.effectState.effectProgress, 0.0)
    }

    @MainActor
    func testTriggerVisualEffect_SetsCenter() {
        let position = SIMD3<Float>(1.0, 2.0, 3.0)
        gestureHandler.triggerVisualEffect(.spiral, at: position)
        XCTAssertEqual(gestureHandler.effectState.effectCenter, position)
    }

    // MARK: - Effect State Tests

    @MainActor
    func testEffectState_IsActive_WhenEffectInProgress() {
        gestureHandler.triggerVisualEffect(.pulse)
        XCTAssertTrue(gestureHandler.effectState.isActive)
    }

    @MainActor
    func testEffectState_IsNotActive_Initially() {
        XCTAssertFalse(gestureHandler.effectState.isActive)
    }

    // MARK: - Gesture Type Tests

    @MainActor
    func testAllGestureTypes_HaveRawValues() {
        for gesture in VisionOSGestureHandler.GestureType.allCases {
            XCTAssertFalse(gesture.rawValue.isEmpty)
        }
    }
}

// MARK: - VisionOS Color Palettes Tests

final class VisionOSColorPalettesTests: XCTestCase {

    // MARK: - Color Blind Mode Tests

    func testAllColorBlindModes_HaveDescriptions() {
        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "Mode \(mode) has no description")
        }
    }

    func testAllColorBlindModes_HaveIds() {
        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            XCTAssertFalse(mode.id.isEmpty)
        }
    }

    // MARK: - Coherence Colors Tests

    func testCoherenceColors_AllModes_ReturnValidColors() {
        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            let colors = VisionOSColorPalettes.coherenceColors(for: mode)

            XCTAssertValidSIMD3(colors.low, "Low color for \(mode)")
            XCTAssertValidSIMD3(colors.medium, "Medium color for \(mode)")
            XCTAssertValidSIMD3(colors.high, "High color for \(mode)")
        }
    }

    func testCoherenceColors_ColorInterpolation_Works() {
        let colors = VisionOSColorPalettes.coherenceColors(for: .normal)

        let lowColor = colors.color(for: 0.0)
        let midColor = colors.color(for: 0.5)
        let highColor = colors.color(for: 1.0)

        XCTAssertValidSIMD3(lowColor, "Interpolated low")
        XCTAssertValidSIMD3(midColor, "Interpolated mid")
        XCTAssertValidSIMD3(highColor, "Interpolated high")
    }

    // MARK: - Quantum Colors Tests

    func testQuantumColors_AllModes_ReturnValidColors() {
        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            let colors = VisionOSColorPalettes.quantumColors(for: mode)

            XCTAssertValidSIMD3(colors.photon, "Photon color for \(mode)")
            XCTAssertValidSIMD3(colors.coherence, "Coherence color for \(mode)")
            XCTAssertValidSIMD3(colors.entanglement, "Entanglement color for \(mode)")
            XCTAssertValidSIMD3(colors.collapse, "Collapse color for \(mode)")
            XCTAssertValidSIMD3(colors.superposition, "Superposition color for \(mode)")
        }
    }

    // MARK: - UI Colors Tests

    func testUIColors_AllModes_ReturnValidColors() {
        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            let colors = VisionOSColorPalettes.uiColors(for: mode)

            XCTAssertValidSIMD3(colors.primary, "Primary color for \(mode)")
            XCTAssertValidSIMD3(colors.secondary, "Secondary color for \(mode)")
            XCTAssertValidSIMD3(colors.accent, "Accent color for \(mode)")
            XCTAssertValidSIMD3(colors.warning, "Warning color for \(mode)")
            XCTAssertValidSIMD3(colors.success, "Success color for \(mode)")
            XCTAssertValidSIMD3(colors.error, "Error color for \(mode)")
        }
    }

    // MARK: - Color Conversion Tests

    func testSIMD3ToUIColor_ReturnsValidColor() {
        let simd = SIMD3<Float>(0.5, 0.7, 0.9)
        let uiColor = VisionOSColorPalettes.simd3ToUIColor(simd)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(Float(r), 0.5, accuracy: 0.01)
        XCTAssertEqual(Float(g), 0.7, accuracy: 0.01)
        XCTAssertEqual(Float(b), 0.9, accuracy: 0.01)
        XCTAssertEqual(Float(a), 1.0, accuracy: 0.01)
    }

    // MARK: - Helper

    func XCTAssertValidSIMD3(_ value: SIMD3<Float>, _ message: String) {
        XCTAssertGreaterThanOrEqual(value.x, 0.0, "\(message) x component")
        XCTAssertLessThanOrEqual(value.x, 1.0, "\(message) x component")
        XCTAssertGreaterThanOrEqual(value.y, 0.0, "\(message) y component")
        XCTAssertLessThanOrEqual(value.y, 1.0, "\(message) y component")
        XCTAssertGreaterThanOrEqual(value.z, 0.0, "\(message) z component")
        XCTAssertLessThanOrEqual(value.z, 1.0, "\(message) z component")
    }
}

// MARK: - VisionOS Haptic Engine Tests

final class VisionOSHapticEngineTests: XCTestCase {

    var hapticEngine: VisionOSHapticEngine!

    override func setUp() async throws {
        await MainActor.run {
            hapticEngine = VisionOSHapticEngine()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            hapticEngine.stopAllLoops()
            hapticEngine = nil
        }
    }

    // MARK: - Pattern Tests

    @MainActor
    func testAllHapticPatterns_HaveValidIntensity() {
        for pattern in VisionOSHapticEngine.HapticPattern.allCases {
            XCTAssertGreaterThanOrEqual(pattern.intensity, 0.0)
            XCTAssertLessThanOrEqual(pattern.intensity, 1.0)
        }
    }

    @MainActor
    func testAllHapticPatterns_HaveValidSharpness() {
        for pattern in VisionOSHapticEngine.HapticPattern.allCases {
            XCTAssertGreaterThanOrEqual(pattern.sharpness, 0.0)
            XCTAssertLessThanOrEqual(pattern.sharpness, 1.0)
        }
    }

    // MARK: - Enable/Disable Tests

    @MainActor
    func testHapticEngine_IsEnabledByDefault() {
        XCTAssertTrue(hapticEngine.isEnabled)
    }

    @MainActor
    func testHapticEngine_DisableStopsPlayback() {
        hapticEngine.isEnabled = false
        // Should not crash when playing disabled
        hapticEngine.playPattern(.heartbeat)
    }

    // MARK: - Global Intensity Tests

    @MainActor
    func testGlobalIntensity_DefaultIsOne() {
        XCTAssertEqual(hapticEngine.globalIntensity, 1.0)
    }

    @MainActor
    func testGlobalIntensity_CanBeModified() {
        hapticEngine.globalIntensity = 0.5
        XCTAssertEqual(hapticEngine.globalIntensity, 0.5)
    }

    // MARK: - Coherence Feedback Tests

    @MainActor
    func testPlayCoherenceFeedback_HighCoherence() {
        // Should not crash
        hapticEngine.playCoherenceFeedback(level: 0.9)
    }

    @MainActor
    func testPlayCoherenceFeedback_LowCoherence() {
        // Should not crash
        hapticEngine.playCoherenceFeedback(level: 0.1)
    }
}

// MARK: - VisionOS Particle LOD Tests

final class VisionOSParticleLODTests: XCTestCase {

    var particleLOD: VisionOSParticleLOD!

    override func setUp() throws {
        particleLOD = VisionOSParticleLOD()
    }

    override func tearDown() throws {
        particleLOD = nil
    }

    // MARK: - LOD Level Tests

    func testLODLevels_ParticleRatios_AreValid() {
        for level in VisionOSParticleLOD.LODLevel.allCases {
            XCTAssertGreaterThan(level.particleRatio, 0.0)
            XCTAssertLessThanOrEqual(level.particleRatio, 1.0)
        }
    }

    func testLODLevels_MaxParticles_ArePositive() {
        for level in VisionOSParticleLOD.LODLevel.allCases {
            XCTAssertGreaterThan(level.maxParticles, 0)
        }
    }

    func testLODLevels_Ordering_IsCorrect() {
        XCTAssertTrue(VisionOSParticleLOD.LODLevel.full < .high)
        XCTAssertTrue(VisionOSParticleLOD.LODLevel.high < .medium)
        XCTAssertTrue(VisionOSParticleLOD.LODLevel.medium < .low)
        XCTAssertTrue(VisionOSParticleLOD.LODLevel.low < .minimal)
    }

    // MARK: - Distance-Based LOD Tests

    func testCalculateLOD_CloseDistance_ReturnsFull() {
        let lod = particleLOD.calculateLOD(distanceFromCamera: 1.0)
        XCTAssertEqual(lod, .full)
    }

    func testCalculateLOD_FarDistance_ReturnsMinimal() {
        let lod = particleLOD.calculateLOD(distanceFromCamera: 100.0)
        XCTAssertEqual(lod, .minimal)
    }

    func testCalculateLOD_MediumDistance_ReturnsMedium() {
        let lod = particleLOD.calculateLOD(distanceFromCamera: 7.0)
        XCTAssertEqual(lod, .medium)
    }

    // MARK: - Frustum Culling Tests

    func testIsInFrustum_InFront_ReturnsTrue() {
        let result = particleLOD.isInFrustum(
            position: SIMD3<Float>(0, 0, -5),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            cameraForward: SIMD3<Float>(0, 0, -1)
        )
        XCTAssertTrue(result)
    }

    func testIsInFrustum_Behind_ReturnsFalse() {
        let result = particleLOD.isInFrustum(
            position: SIMD3<Float>(0, 0, 5),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            cameraForward: SIMD3<Float>(0, 0, -1)
        )
        XCTAssertFalse(result)
    }

    func testIsInFrustum_ToSide_ReturnsFalse() {
        let result = particleLOD.isInFrustum(
            position: SIMD3<Float>(10, 0, -1),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            cameraForward: SIMD3<Float>(0, 0, -1)
        )
        XCTAssertFalse(result)
    }

    func testIsInFrustum_CullingDisabled_ReturnsTrue() {
        particleLOD.configuration.cullingEnabled = false
        let result = particleLOD.isInFrustum(
            position: SIMD3<Float>(0, 0, 5), // Behind camera
            cameraPosition: SIMD3<Float>(0, 0, 0),
            cameraForward: SIMD3<Float>(0, 0, -1)
        )
        XCTAssertTrue(result)
    }

    // MARK: - Adaptive LOD Tests

    func testUpdateAdaptiveLOD_LowFrameRate_ReducesLOD() {
        particleLOD.configuration.adaptiveMode = true

        // Simulate consistently low frame rate
        for _ in 0..<35 {
            particleLOD.updateAdaptiveLOD(currentFrameRate: 30.0)
        }

        XCTAssertNotEqual(particleLOD.currentLOD, .full)
    }

    func testUpdateAdaptiveLOD_AdaptiveDisabled_NoChange() {
        particleLOD.configuration.adaptiveMode = false

        for _ in 0..<35 {
            particleLOD.updateAdaptiveLOD(currentFrameRate: 30.0)
        }

        XCTAssertEqual(particleLOD.currentLOD, .full)
    }

    // MARK: - Statistics Tests

    func testStatistics_ReturnsNonEmptyString() {
        XCTAssertFalse(particleLOD.statistics.isEmpty)
    }
}

// MARK: - VisionOS Gaze Audio Bridge Tests

final class VisionOSGazeAudioBridgeTests: XCTestCase {

    var gazeAudioBridge: VisionOSGazeAudioBridge!

    override func setUp() async throws {
        await MainActor.run {
            gazeAudioBridge = VisionOSGazeAudioBridge()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            gazeAudioBridge.disconnect()
            gazeAudioBridge = nil
        }
    }

    // MARK: - Initial State Tests

    @MainActor
    func testInitialState_IsNotActive() {
        XCTAssertFalse(gazeAudioBridge.isActive)
    }

    @MainActor
    func testInitialState_AudioPanIsZero() {
        XCTAssertEqual(gazeAudioBridge.audioPan, 0.0)
    }

    @MainActor
    func testInitialState_FilterCutoffIsMiddle() {
        XCTAssertEqual(gazeAudioBridge.filterCutoff, 0.5)
    }

    // MARK: - Mapping Preset Tests

    @MainActor
    func testApplyPreset_UpdatesMapping() {
        gazeAudioBridge.applyPreset(.meditation)
        XCTAssertFalse(gazeAudioBridge.currentMapping.gazeXToPan)
    }

    @MainActor
    func testDefaultMapping_HasExpectedValues() {
        let mapping = VisionOSGazeAudioBridge.GazeAudioMapping.default
        XCTAssertTrue(mapping.gazeXToPan)
        XCTAssertTrue(mapping.gazeYToFilter)
        XCTAssertTrue(mapping.attentionToReverb)
    }

    @MainActor
    func testPerformanceMapping_HasHigherSensitivity() {
        let mapping = VisionOSGazeAudioBridge.GazeAudioMapping.performance
        XCTAssertGreaterThan(mapping.panSensitivity, 1.0)
    }

    // MARK: - Zone Frequency Mapping Tests

    func testZoneFrequencyMapping_TopZones_HighFrequency() {
        let topFreq = VisionOSGazeAudioBridge.ZoneFrequencyMapping.frequency(for: .topCenter)
        let bottomFreq = VisionOSGazeAudioBridge.ZoneFrequencyMapping.frequency(for: .bottomCenter)
        XCTAssertGreaterThan(topFreq, bottomFreq)
    }

    func testZoneFrequencyMapping_AllZones_HaveFrequencies() {
        for zone in GazeZone.allCases {
            let freq = VisionOSGazeAudioBridge.ZoneFrequencyMapping.frequency(for: zone)
            XCTAssertGreaterThan(freq, 0)
        }
    }
}

// MARK: - VisionOS HealthKit Bridge Tests

final class VisionOSHealthKitBridgeTests: XCTestCase {

    var healthKitBridge: VisionOSHealthKitBridge!

    override func setUp() async throws {
        await MainActor.run {
            healthKitBridge = VisionOSHealthKitBridge()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            healthKitBridge.stopStreaming()
            healthKitBridge = nil
        }
    }

    // MARK: - Initial State Tests

    @MainActor
    func testInitialState_IsNotStreaming() {
        XCTAssertFalse(healthKitBridge.isStreaming)
    }

    @MainActor
    func testInitialState_HasDefaultHeartRate() {
        XCTAssertEqual(healthKitBridge.heartRate, 60.0)
    }

    @MainActor
    func testInitialState_HasDefaultHRV() {
        XCTAssertEqual(healthKitBridge.hrvRMSSD, 50.0)
    }

    @MainActor
    func testInitialState_HasDefaultCoherence() {
        XCTAssertEqual(healthKitBridge.coherenceLevel, 0.5)
    }

    // MARK: - Streaming Control Tests

    @MainActor
    func testStartStreaming_SetsIsStreaming() {
        healthKitBridge.startStreaming()
        XCTAssertTrue(healthKitBridge.isStreaming)
    }

    @MainActor
    func testStopStreaming_ClearsIsStreaming() {
        healthKitBridge.startStreaming()
        healthKitBridge.stopStreaming()
        XCTAssertFalse(healthKitBridge.isStreaming)
    }

    // MARK: - Data Injection Tests

    @MainActor
    func testInjectBioData_UpdatesHeartRate() {
        healthKitBridge.injectBioData(heartRate: 80.0)
        XCTAssertEqual(healthKitBridge.heartRate, 80.0)
    }

    @MainActor
    func testInjectBioData_UpdatesHRV() {
        healthKitBridge.injectBioData(hrv: 70.0)
        XCTAssertEqual(healthKitBridge.hrvRMSSD, 70.0)
    }

    @MainActor
    func testInjectBioData_UpdatesCoherence() {
        healthKitBridge.injectBioData(coherence: 0.8)
        XCTAssertEqual(healthKitBridge.coherenceLevel, 0.8)
    }

    @MainActor
    func testInjectBioData_SetsLastUpdate() {
        healthKitBridge.injectBioData(heartRate: 75.0)
        XCTAssertNotNil(healthKitBridge.lastUpdate)
    }

    // MARK: - Configuration Tests

    @MainActor
    func testDefaultConfig_HasReasonableUpdateInterval() {
        XCTAssertGreaterThan(healthKitBridge.config.updateInterval, 0)
        XCTAssertLessThan(healthKitBridge.config.updateInterval, 10.0)
    }

    @MainActor
    func testDefaultConfig_HasReasonableSmoothingFactor() {
        XCTAssertGreaterThan(healthKitBridge.config.smoothingFactor, 0)
        XCTAssertLessThan(healthKitBridge.config.smoothingFactor, 1.0)
    }
}

// MARK: - GazeTracker Integration Tests

final class GazeTrackerIntegrationTests: XCTestCase {

    var gazeTracker: GazeTracker!

    override func setUp() async throws {
        await MainActor.run {
            gazeTracker = GazeTracker()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            gazeTracker.stopTracking()
            gazeTracker = nil
        }
    }

    // MARK: - GazeData Tests

    func testGazeData_DefaultValues_AreValid() {
        let data = GazeData()
        XCTAssertEqual(data.gazePoint, SIMD2<Float>(0.5, 0.5))
        XCTAssertEqual(data.confidence, 0.0)
        XCTAssertFalse(data.isBlinking)
    }

    func testGazeData_AverageOpenness_CalculatesCorrectly() {
        var data = GazeData()
        data.leftEyeOpenness = 0.8
        data.rightEyeOpenness = 0.6
        XCTAssertEqual(data.averageOpenness, 0.7, accuracy: 0.001)
    }

    func testGazeData_AveragePupilDilation_CalculatesCorrectly() {
        var data = GazeData()
        data.leftPupilDilation = 0.4
        data.rightPupilDilation = 0.6
        XCTAssertEqual(data.averagePupilDilation, 0.5, accuracy: 0.001)
    }

    func testGazeData_AttentionLevel_CalculatesCorrectly() {
        var data = GazeData()
        data.isFixating = true
        data.leftPupilDilation = 0.5
        data.rightPupilDilation = 0.5
        // attentionLevel = isFixating(1.0) * 0.6 + avgPupilDilation(0.5) * 0.4 = 0.8
        XCTAssertEqual(data.attentionLevel, 0.8, accuracy: 0.001)
    }

    // MARK: - GazeZone Tests

    func testGazeZone_FromPoint_Center() {
        let zone = GazeZone.from(point: SIMD2<Float>(0.5, 0.5))
        XCTAssertEqual(zone, .center)
    }

    func testGazeZone_FromPoint_TopLeft() {
        let zone = GazeZone.from(point: SIMD2<Float>(0.1, 0.1))
        XCTAssertEqual(zone, .topLeft)
    }

    func testGazeZone_FromPoint_BottomRight() {
        let zone = GazeZone.from(point: SIMD2<Float>(0.9, 0.9))
        XCTAssertEqual(zone, .bottomRight)
    }

    func testGazeZone_AllZones_HaveDisplayNames() {
        for zone in GazeZone.allCases {
            XCTAssertFalse(zone.displayName.isEmpty)
        }
    }

    // MARK: - GazeGesture Tests

    func testGazeGesture_AllGestures_HaveDisplayNames() {
        for gesture in GazeGesture.allCases {
            XCTAssertFalse(gesture.displayName.isEmpty)
        }
    }

    // MARK: - GazeControlParameters Tests

    func testGazeControlParameters_AudioPan_CalculatesCorrectly() {
        let params = GazeControlParameters(
            gazeX: 0.75,
            gazeY: 0.5,
            attention: 0.8,
            focus: 0.7,
            stability: 0.9,
            arousal: 0.6,
            zone: .centerRight,
            isFixating: true,
            isBlinking: false
        )
        // audioPan = (gazeX - 0.5) * 2.0 = (0.75 - 0.5) * 2.0 = 0.5
        XCTAssertEqual(params.audioPan, 0.5, accuracy: 0.001)
    }

    func testGazeControlParameters_FilterCutoff_CalculatesCorrectly() {
        let params = GazeControlParameters(
            gazeX: 0.5,
            gazeY: 0.5,
            attention: 0.8,
            focus: 0.7,
            stability: 0.5,
            arousal: 0.6,
            zone: .center,
            isFixating: true,
            isBlinking: false
        )
        // filterCutoff = attention * stability = 0.8 * 0.5 = 0.4
        XCTAssertEqual(params.filterCutoff, 0.4, accuracy: 0.001)
    }

    func testGazeControlParameters_ReverbAmount_CalculatesCorrectly() {
        let params = GazeControlParameters(
            gazeX: 0.5,
            gazeY: 0.5,
            attention: 0.8,
            focus: 0.6,
            stability: 0.5,
            arousal: 0.6,
            zone: .center,
            isFixating: true,
            isBlinking: false
        )
        // reverbAmount = 1.0 - focus = 1.0 - 0.6 = 0.4
        XCTAssertEqual(params.reverbAmount, 0.4, accuracy: 0.001)
    }

    // MARK: - Tracker State Tests

    @MainActor
    func testGazeTracker_InitialState_NotTracking() {
        XCTAssertFalse(gazeTracker.isTracking)
    }

    @MainActor
    func testGazeTracker_InitialState_NotCalibrated() {
        XCTAssertFalse(gazeTracker.isCalibrated)
    }

    @MainActor
    func testGazeTracker_StartTracking_SetsTracking() {
        gazeTracker.startTracking()
        XCTAssertTrue(gazeTracker.isTracking)
    }

    @MainActor
    func testGazeTracker_StopTracking_ClearsTracking() {
        gazeTracker.startTracking()
        gazeTracker.stopTracking()
        XCTAssertFalse(gazeTracker.isTracking)
    }

    @MainActor
    func testGazeTracker_GetControlParameters_ReturnsValidParams() {
        let params = gazeTracker.getControlParameters()
        XCTAssertGreaterThanOrEqual(params.gazeX, 0)
        XCTAssertLessThanOrEqual(params.gazeX, 1)
        XCTAssertGreaterThanOrEqual(params.gazeY, 0)
        XCTAssertLessThanOrEqual(params.gazeY, 1)
    }
}

// MARK: - Integration Tests

final class VisionOSIntegrationTests: XCTestCase {

    @MainActor
    func testFullIntegration_AnimationAndGesture() async {
        let animationController = VisionOSAnimationController()
        let gestureHandler = VisionOSGestureHandler()

        animationController.start()
        gestureHandler.triggerVisualEffect(.pulse)

        XCTAssertTrue(animationController.isAnimating)
        XCTAssertEqual(gestureHandler.effectState.activeEffect, .pulse)

        animationController.stop()
    }

    @MainActor
    func testFullIntegration_HapticsAndAnimation() async {
        let animationController = VisionOSAnimationController()
        let hapticEngine = VisionOSHapticEngine()

        animationController.start()
        animationController.updateBioData(heartRate: 75.0, coherence: 0.8)

        // Haptics should work with animation values
        hapticEngine.playHeartbeat(bpm: animationController.heartRate)
        hapticEngine.playCoherenceFeedback(level: animationController.coherenceLevel)

        animationController.stop()
    }

    @MainActor
    func testFullIntegration_ColorPaletteApplication() async {
        let animationController = VisionOSAnimationController()

        for mode in VisionOSColorPalettes.ColorBlindMode.allCases {
            let colors = VisionOSColorPalettes.coherenceColors(for: mode)

            // Apply color palette to animation controller
            animationController.coherence.lowColor = colors.low
            animationController.coherence.mediumColor = colors.medium
            animationController.coherence.highColor = colors.high

            // Should produce valid colors
            let resultColor = animationController.coherenceColor
            XCTAssertGreaterThanOrEqual(resultColor.x, 0)
            XCTAssertLessThanOrEqual(resultColor.x, 1)
        }
    }

    @MainActor
    func testFullIntegration_HealthKitToAnimation() async throws {
        let healthKitBridge = VisionOSHealthKitBridge()
        let animationController = VisionOSAnimationController()

        // Inject test bio data
        healthKitBridge.injectBioData(heartRate: 72.0, hrv: 65.0, coherence: 0.75)

        // Apply to animation controller
        animationController.updateBioData(
            heartRate: healthKitBridge.heartRate,
            coherence: healthKitBridge.coherenceLevel
        )

        XCTAssertEqual(animationController.heartRate, 72.0)
        XCTAssertEqual(animationController.coherenceLevel, 0.75)
    }
}

// MARK: - Performance Tests

final class VisionOSPerformanceTests: XCTestCase {

    func testPerformance_LODCalculation() throws {
        let particleLOD = VisionOSParticleLOD()

        measure {
            for _ in 0..<10000 {
                let _ = particleLOD.calculateLOD(distanceFromCamera: Float.random(in: 0...50))
            }
        }
    }

    func testPerformance_FrustumCulling() throws {
        let particleLOD = VisionOSParticleLOD()

        measure {
            for _ in 0..<10000 {
                let _ = particleLOD.isInFrustum(
                    position: SIMD3<Float>.random(in: -10...10),
                    cameraPosition: .zero,
                    cameraForward: SIMD3<Float>(0, 0, -1)
                )
            }
        }
    }

    func testPerformance_ColorPaletteLookup() throws {
        measure {
            for _ in 0..<10000 {
                let mode = VisionOSColorPalettes.ColorBlindMode.allCases.randomElement()!
                let _ = VisionOSColorPalettes.coherenceColors(for: mode)
            }
        }
    }

    @MainActor
    func testPerformance_AnimationValueComputation() async throws {
        let animationController = VisionOSAnimationController()
        animationController.start()

        measure {
            for _ in 0..<10000 {
                let _ = animationController.heartPulseValue
                let _ = animationController.floatingOffset
                let _ = animationController.breathingValue
                let _ = animationController.coherenceColor
            }
        }

        animationController.stop()
    }
}

// MARK: - Edge Case Tests

final class VisionOSEdgeCaseTests: XCTestCase {

    @MainActor
    func testEdgeCase_ZeroCoherence() async {
        let animationController = VisionOSAnimationController()
        animationController.coherenceLevel = 0.0
        let color = animationController.coherenceColor
        XCTAssertFalse(color.x.isNaN)
    }

    @MainActor
    func testEdgeCase_MaxCoherence() async {
        let animationController = VisionOSAnimationController()
        animationController.coherenceLevel = 1.0
        let color = animationController.coherenceColor
        XCTAssertFalse(color.x.isNaN)
    }

    @MainActor
    func testEdgeCase_ZeroHeartRate() async {
        let animationController = VisionOSAnimationController()
        animationController.heartRate = 0.0
        let pulse = animationController.heartPulseValue
        XCTAssertFalse(pulse.isNaN)
    }

    @MainActor
    func testEdgeCase_VeryHighHeartRate() async {
        let animationController = VisionOSAnimationController()
        animationController.heartRate = 200.0
        let pulse = animationController.heartPulseValue
        XCTAssertFalse(pulse.isNaN)
    }

    func testEdgeCase_LODAtZeroDistance() {
        let particleLOD = VisionOSParticleLOD()
        let lod = particleLOD.calculateLOD(distanceFromCamera: 0.0)
        XCTAssertEqual(lod, .full)
    }

    func testEdgeCase_LODAtNegativeDistance() {
        let particleLOD = VisionOSParticleLOD()
        let lod = particleLOD.calculateLOD(distanceFromCamera: -5.0)
        XCTAssertEqual(lod, .full) // Should still return full for invalid input
    }

    func testEdgeCase_FrustumCullingAtCameraPosition() {
        let particleLOD = VisionOSParticleLOD()
        let result = particleLOD.isInFrustum(
            position: SIMD3<Float>(0, 0, 0),
            cameraPosition: SIMD3<Float>(0, 0, 0),
            cameraForward: SIMD3<Float>(0, 0, -1)
        )
        XCTAssertTrue(result) // Very close positions should be visible
    }

    @MainActor
    func testEdgeCase_GestureEffectAtOrigin() async {
        let gestureHandler = VisionOSGestureHandler()
        gestureHandler.triggerVisualEffect(.pulse, at: .zero)
        XCTAssertEqual(gestureHandler.effectState.effectCenter, .zero)
    }

    @MainActor
    func testEdgeCase_GestureEffectAtExtremePosition() async {
        let gestureHandler = VisionOSGestureHandler()
        let extremePosition = SIMD3<Float>(1000, 1000, 1000)
        gestureHandler.triggerVisualEffect(.spiral, at: extremePosition)
        XCTAssertEqual(gestureHandler.effectState.effectCenter, extremePosition)
    }
}

// MARK: - SIMD Extension for Tests

extension SIMD3 where Scalar == Float {
    static func random(in range: ClosedRange<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            Float.random(in: range),
            Float.random(in: range),
            Float.random(in: range)
        )
    }
}
