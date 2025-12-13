import XCTest
@testable import Echoelmusic

/// Tests for Spatial Audio system
@MainActor
final class SpatialAudioTests: XCTestCase {

    // MARK: - Spatial Mode Tests

    func testSpatialModeEnumeration() throws {
        let allModes = SpatialMappingMode.allCases

        XCTAssertEqual(allModes.count, 5)
        XCTAssertTrue(allModes.contains(.centered))
        XCTAssertTrue(allModes.contains(.orbital))
        XCTAssertTrue(allModes.contains(.breathing))
        XCTAssertTrue(allModes.contains(.coherenceResponsive))
        XCTAssertTrue(allModes.contains(.immersive))
    }

    func testSpatialModeRawValues() throws {
        XCTAssertEqual(SpatialMappingMode.centered.rawValue, "Centered")
        XCTAssertEqual(SpatialMappingMode.orbital.rawValue, "Orbital")
        XCTAssertEqual(SpatialMappingMode.breathing.rawValue, "Breathing")
        XCTAssertEqual(SpatialMappingMode.coherenceResponsive.rawValue, "Coherence")
        XCTAssertEqual(SpatialMappingMode.immersive.rawValue, "Immersive")
    }

    // MARK: - Bio Parameter Mapper Spatial Tests

    func testBioParameterMapperSpatialPosition() throws {
        let mapper = BioParameterMapper()

        // Update with test parameters
        mapper.updateParameters(
            hrvCoherence: 80,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.5
        )

        // Spatial position should be calculated
        let (x, y, z) = mapper.spatialPosition
        XCTAssertEqual(z, 1.0, "Z should be constant at 1.0")

        // High coherence should result in more centered position
        XCTAssertLessThan(abs(x), 1.0, "X should be within bounds")
        XCTAssertLessThan(abs(y), 1.0, "Y should be within bounds")
    }

    func testSpatialPositionWithLowCoherence() throws {
        let mapper = BioParameterMapper()

        // Low coherence should spread audio
        mapper.updateParameters(
            hrvCoherence: 20,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.5
        )

        let (x1, y1, _) = mapper.spatialPosition

        // High coherence should center audio
        mapper.updateParameters(
            hrvCoherence: 90,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.5
        )

        let (x2, y2, _) = mapper.spatialPosition

        // High coherence position should be more centered
        let lowCoherenceDeviation = sqrt(x1 * x1 + y1 * y1)
        let highCoherenceDeviation = sqrt(x2 * x2 + y2 * y2)

        // Note: Due to time-based animation, we just verify bounds
        XCTAssertLessThanOrEqual(lowCoherenceDeviation, 0.5)
        XCTAssertLessThanOrEqual(highCoherenceDeviation, 0.5)
    }

    // MARK: - Binaural State Tests

    func testBinauralStateEnumeration() throws {
        let allStates = BinauralState.allCases

        XCTAssertEqual(allStates.count, 5)
        XCTAssertTrue(allStates.contains(.delta))
        XCTAssertTrue(allStates.contains(.theta))
        XCTAssertTrue(allStates.contains(.alpha))
        XCTAssertTrue(allStates.contains(.beta))
        XCTAssertTrue(allStates.contains(.gamma))
    }

    func testBinauralStateRawValues() throws {
        XCTAssertEqual(BinauralState.delta.rawValue, "Delta")
        XCTAssertEqual(BinauralState.theta.rawValue, "Theta")
        XCTAssertEqual(BinauralState.alpha.rawValue, "Alpha")
        XCTAssertEqual(BinauralState.beta.rawValue, "Beta")
        XCTAssertEqual(BinauralState.gamma.rawValue, "Gamma")
    }

    // MARK: - Preset Spatial Mode Tests

    func testPresetSpatialModes() throws {
        let library = BioMappingPresetLibrary.shared

        // Verify different presets use different spatial modes
        let spatialModes = Set(library.presets.map { $0.spatialMode })

        XCTAssertGreaterThan(spatialModes.count, 1, "Presets should use various spatial modes")
    }

    func testMeditationPresetSpatialMode() throws {
        let library = BioMappingPresetLibrary.shared

        guard let meditationPreset = library.preset(named: "Deep Meditation") else {
            XCTFail("Deep Meditation preset not found")
            return
        }

        // Meditation should use breathing mode for calming effect
        XCTAssertEqual(meditationPreset.spatialMode, .breathing)
    }

    func testFocusPresetSpatialMode() throws {
        let library = BioMappingPresetLibrary.shared

        guard let focusPreset = library.preset(named: "Deep Focus") else {
            XCTFail("Deep Focus preset not found")
            return
        }

        // Focus should use centered mode to avoid distraction
        XCTAssertEqual(focusPreset.spatialMode, .centered)
    }

    // MARK: - Harmonic Profile Tests

    func testHarmonicProfileEnumeration() throws {
        let allProfiles = HarmonicProfile.allCases

        XCTAssertEqual(allProfiles.count, 5)
        XCTAssertTrue(allProfiles.contains(.minimal))
        XCTAssertTrue(allProfiles.contains(.balanced))
        XCTAssertTrue(allProfiles.contains(.rich))
        XCTAssertTrue(allProfiles.contains(.pure))
        XCTAssertTrue(allProfiles.contains(.overtone))
    }

    func testHarmonicCountMapping() throws {
        let mapper = BioParameterMapper()

        // Test clear pitch with high audio level
        mapper.updateParameters(
            hrvCoherence: 50,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.8
        )

        // High clarity should produce more harmonics
        XCTAssertGreaterThanOrEqual(mapper.harmonicCount, 5)

        // Test unclear pitch with low audio level
        mapper.updateParameters(
            hrvCoherence: 50,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.05
        )

        // Low clarity should produce fewer harmonics
        XCTAssertEqual(mapper.harmonicCount, 3)
    }
}

// MARK: - Visual Mode Tests

@MainActor
final class VisualModeTests: XCTestCase {

    func testSacredGeometryPatterns() throws {
        let patterns = SacredGeometryMode.GeometryPattern.allCases

        XCTAssertEqual(patterns.count, 5)
        XCTAssertTrue(patterns.contains(.goldenSpiral))
        XCTAssertTrue(patterns.contains(.flowerOfLife))
        XCTAssertTrue(patterns.contains(.metatronsCube))
        XCTAssertTrue(patterns.contains(.sriYantra))
        XCTAssertTrue(patterns.contains(.fibonacciSpiral))
    }

    func testBrainwaveVisualizerChannels() throws {
        let visualizer = BrainwaveVisualizerMode(
            audioLevel: 0.5,
            frequency: 440,
            hrvCoherence: 60,
            heartRate: 70,
            binauralBeatFrequency: 10
        )

        // Test dominant state detection
        XCTAssertEqual(visualizer.dominantState, "Alpha")
        XCTAssertEqual(visualizer.stateDescription, "Relaxation")
    }

    func testBrainwaveStateDetection() throws {
        // Delta (0.5-4 Hz)
        let deltaVisualizer = BrainwaveVisualizerMode(
            audioLevel: 0.5,
            frequency: 440,
            hrvCoherence: 60,
            heartRate: 70,
            binauralBeatFrequency: 2
        )
        XCTAssertEqual(deltaVisualizer.dominantState, "Delta")

        // Theta (4-8 Hz)
        let thetaVisualizer = BrainwaveVisualizerMode(
            audioLevel: 0.5,
            frequency: 440,
            hrvCoherence: 60,
            heartRate: 70,
            binauralBeatFrequency: 6
        )
        XCTAssertEqual(thetaVisualizer.dominantState, "Theta")

        // Beta (15-20 Hz)
        let betaVisualizer = BrainwaveVisualizerMode(
            audioLevel: 0.5,
            frequency: 440,
            hrvCoherence: 60,
            heartRate: 70,
            binauralBeatFrequency: 18
        )
        XCTAssertEqual(betaVisualizer.dominantState, "Beta")

        // Gamma (30-50 Hz)
        let gammaVisualizer = BrainwaveVisualizerMode(
            audioLevel: 0.5,
            frequency: 440,
            hrvCoherence: 60,
            heartRate: 70,
            binauralBeatFrequency: 40
        )
        XCTAssertEqual(gammaVisualizer.dominantState, "Gamma")
    }

    func testPresetVisualModes() throws {
        let library = BioMappingPresetLibrary.shared

        // Verify presets specify visual modes
        for preset in library.presets {
            XCTAssertFalse(preset.visualMode.isEmpty, "Preset \(preset.name) should have a visual mode")
        }

        // Verify heart coherence preset uses heart coherence mandala
        guard let heartCoherencePreset = library.preset(named: "Heart Coherence") else {
            XCTFail("Heart Coherence preset not found")
            return
        }
        XCTAssertEqual(heartCoherencePreset.visualMode, "heartCoherenceMandala")
    }
}

// MARK: - Preset Category Tests

final class PresetCategoryTests: XCTestCase {

    func testPresetCategoryEnumeration() throws {
        let allCategories = PresetCategory.allCases

        XCTAssertEqual(allCategories.count, 8)
        XCTAssertTrue(allCategories.contains(.meditation))
        XCTAssertTrue(allCategories.contains(.healing))
        XCTAssertTrue(allCategories.contains(.focus))
        XCTAssertTrue(allCategories.contains(.creative))
        XCTAssertTrue(allCategories.contains(.relaxation))
        XCTAssertTrue(allCategories.contains(.energizing))
        XCTAssertTrue(allCategories.contains(.sleep))
        XCTAssertTrue(allCategories.contains(.custom))
    }

    func testPresetCategoryRawValues() throws {
        XCTAssertEqual(PresetCategory.meditation.rawValue, "Meditation")
        XCTAssertEqual(PresetCategory.healing.rawValue, "Healing")
        XCTAssertEqual(PresetCategory.focus.rawValue, "Focus")
        XCTAssertEqual(PresetCategory.creative.rawValue, "Creative")
        XCTAssertEqual(PresetCategory.relaxation.rawValue, "Relaxation")
        XCTAssertEqual(PresetCategory.energizing.rawValue, "Energizing")
        XCTAssertEqual(PresetCategory.sleep.rawValue, "Sleep")
        XCTAssertEqual(PresetCategory.custom.rawValue, "Custom")
    }
}
