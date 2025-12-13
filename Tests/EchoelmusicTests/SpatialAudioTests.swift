import XCTest
@testable import Echoelmusic

/// Tests for Spatial Audio and Scientific Frequency Systems
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
        XCTAssertEqual(SpatialMappingMode.coherenceResponsive.rawValue, "Coherence Responsive")
        XCTAssertEqual(SpatialMappingMode.immersive.rawValue, "Immersive")
    }

    // MARK: - Bio Parameter Mapper Spatial Tests

    func testBioParameterMapperSpatialPosition() throws {
        let mapper = BioParameterMapper()

        mapper.updateParameters(
            hrvCoherence: 80,
            heartRate: 70,
            voicePitch: 440,
            audioLevel: 0.5
        )

        let (x, y, z) = mapper.spatialPosition
        XCTAssertEqual(z, 1.0, "Z should be constant at 1.0")
        XCTAssertLessThan(abs(x), 1.0, "X should be within bounds")
        XCTAssertLessThan(abs(y), 1.0, "Y should be within bounds")
    }

    // MARK: - Brainwave Band Tests (EEG-based, scientifically validated)

    func testBrainwaveBandEnumeration() throws {
        let allBands = BrainwaveBand.allCases

        XCTAssertEqual(allBands.count, 5)
        XCTAssertTrue(allBands.contains(.delta))
        XCTAssertTrue(allBands.contains(.theta))
        XCTAssertTrue(allBands.contains(.alpha))
        XCTAssertTrue(allBands.contains(.beta))
        XCTAssertTrue(allBands.contains(.gamma))
    }

    func testBrainwaveBandFrequencyRanges() throws {
        // Verify frequency ranges match clinical EEG standards
        XCTAssertEqual(BrainwaveBand.delta.frequencyRange.lowerBound, 0.5)
        XCTAssertEqual(BrainwaveBand.delta.frequencyRange.upperBound, 4.0)

        XCTAssertEqual(BrainwaveBand.theta.frequencyRange.lowerBound, 4.0)
        XCTAssertEqual(BrainwaveBand.theta.frequencyRange.upperBound, 8.0)

        XCTAssertEqual(BrainwaveBand.alpha.frequencyRange.lowerBound, 8.0)
        XCTAssertEqual(BrainwaveBand.alpha.frequencyRange.upperBound, 13.0)

        XCTAssertEqual(BrainwaveBand.beta.frequencyRange.lowerBound, 13.0)
        XCTAssertEqual(BrainwaveBand.beta.frequencyRange.upperBound, 30.0)

        XCTAssertEqual(BrainwaveBand.gamma.frequencyRange.lowerBound, 30.0)
        XCTAssertEqual(BrainwaveBand.gamma.frequencyRange.upperBound, 100.0)
    }

    func testBrainwaveBandCenterFrequencies() throws {
        XCTAssertEqual(BrainwaveBand.delta.centerFrequency, 2.25, accuracy: 0.01)
        XCTAssertEqual(BrainwaveBand.theta.centerFrequency, 6.0, accuracy: 0.01)
        XCTAssertEqual(BrainwaveBand.alpha.centerFrequency, 10.5, accuracy: 0.01)
        XCTAssertEqual(BrainwaveBand.beta.centerFrequency, 21.5, accuracy: 0.01)
        XCTAssertEqual(BrainwaveBand.gamma.centerFrequency, 65.0, accuracy: 0.01)
    }

    // MARK: - Tuning Standard Tests

    func testTuningStandardFrequencies() throws {
        XCTAssertEqual(TuningStandard.concert440.a4Frequency, 440.0)
        XCTAssertEqual(TuningStandard.baroque415.a4Frequency, 415.0)
        XCTAssertEqual(TuningStandard.scientific432.a4Frequency, 432.0)
        XCTAssertEqual(TuningStandard.orchestral442.a4Frequency, 442.0)
    }

    func testTuningStandardMidiConversion() throws {
        // A4 = MIDI note 69
        let a4Concert = TuningStandard.concert440.frequency(forMidiNote: 69)
        XCTAssertEqual(a4Concert, 440.0, accuracy: 0.001)

        // A3 = MIDI note 57 = 220 Hz at A440
        let a3Concert = TuningStandard.concert440.frequency(forMidiNote: 57)
        XCTAssertEqual(a3Concert, 220.0, accuracy: 0.001)

        // C4 = MIDI note 60 ≈ 261.63 Hz at A440
        let c4Concert = TuningStandard.concert440.frequency(forMidiNote: 60)
        XCTAssertEqual(c4Concert, 261.63, accuracy: 0.1)
    }

    // MARK: - Preset Category Tests (Refactored without pseudoscience)

    func testPresetCategoryEnumeration() throws {
        let allCategories = PresetCategory.allCases

        XCTAssertEqual(allCategories.count, 7)
        XCTAssertTrue(allCategories.contains(.relaxation))
        XCTAssertTrue(allCategories.contains(.focus))
        XCTAssertTrue(allCategories.contains(.creative))
        XCTAssertTrue(allCategories.contains(.sleep))
        XCTAssertTrue(allCategories.contains(.energizing))
        XCTAssertTrue(allCategories.contains(.experimental))
        XCTAssertTrue(allCategories.contains(.custom))

        // Verify pseudoscience categories are removed
        let categoryNames = allCategories.map { $0.rawValue }
        XCTAssertFalse(categoryNames.contains("Healing"))
        XCTAssertFalse(categoryNames.contains("Meditation"))
    }

    // MARK: - Harmonic Profile Tests

    func testHarmonicProfileEnumeration() throws {
        let allProfiles = HarmonicProfile.allCases

        XCTAssertEqual(allProfiles.count, 5)
        XCTAssertTrue(allProfiles.contains(.pure))
        XCTAssertTrue(allProfiles.contains(.minimal))
        XCTAssertTrue(allProfiles.contains(.balanced))
        XCTAssertTrue(allProfiles.contains(.rich))
        XCTAssertTrue(allProfiles.contains(.oddOnly))
    }

    // MARK: - Preset Library Tests

    func testPresetLibraryInitialization() throws {
        let library = BioMappingPresetLibrary.shared

        XCTAssertFalse(library.presets.isEmpty)
        XCTAssertGreaterThanOrEqual(library.presets.count, 10)
    }

    func testPresetsHaveScientificDescriptions() throws {
        let library = BioMappingPresetLibrary.shared

        for preset in library.presets {
            // Descriptions should not contain pseudoscientific terms
            let description = preset.description.lowercased()

            XCTAssertFalse(description.contains("chakra"), "Preset '\(preset.name)' contains pseudoscience")
            XCTAssertFalse(description.contains("dna repair"), "Preset '\(preset.name)' contains pseudoscience")
            XCTAssertFalse(description.contains("love frequency"), "Preset '\(preset.name)' contains pseudoscience")
            XCTAssertFalse(description.contains("healing frequency"), "Preset '\(preset.name)' contains pseudoscience")
        }
    }

    func testPresetsByCategory() throws {
        let library = BioMappingPresetLibrary.shared

        let relaxationPresets = library.presets(for: .relaxation)
        XCTAssertFalse(relaxationPresets.isEmpty)

        let focusPresets = library.presets(for: .focus)
        XCTAssertFalse(focusPresets.isEmpty)

        let experimentalPresets = library.presets(for: .experimental)
        XCTAssertFalse(experimentalPresets.isEmpty)
    }

    func testPresetParameterRanges() throws {
        let library = BioMappingPresetLibrary.shared

        for preset in library.presets {
            // Validate all presets have scientifically reasonable parameter ranges
            XCTAssertGreaterThanOrEqual(preset.hrvToReverbRange.lowerBound, 0)
            XCTAssertLessThanOrEqual(preset.hrvToReverbRange.upperBound, 1)

            XCTAssertGreaterThan(preset.heartRateToFilterRange.lowerBound, 0)
            XCTAssertLessThanOrEqual(preset.heartRateToFilterRange.upperBound, 20000)

            // Base frequency should be standard pitch (not arbitrary "healing" frequencies)
            XCTAssertGreaterThanOrEqual(preset.baseFrequency, 20)
            XCTAssertLessThanOrEqual(preset.baseFrequency, 20000)
        }
    }

    func testPresetBrainwaveTargets() throws {
        let library = BioMappingPresetLibrary.shared

        // Verify presets target appropriate brainwave bands
        let sleepPresets = library.presets(for: .sleep)
        for preset in sleepPresets {
            XCTAssertEqual(preset.brainwaveTarget, .delta, "Sleep presets should target delta")
        }

        let focusPresets = library.presets(for: .focus)
        for preset in focusPresets {
            XCTAssertEqual(preset.brainwaveTarget, .beta, "Focus presets should target beta")
        }
    }
}

// MARK: - Cymatics Engine Tests

@MainActor
final class CymaticsEngineTests: XCTestCase {

    func testCymaticsEngineInitialization() throws {
        let engine = CymaticsEngine()

        XCTAssertEqual(engine.currentFrequency, 440.0)
        XCTAssertEqual(engine.amplitude, 0.5)
        XCTAssertEqual(engine.plateGeometry, .circular)
    }

    func testPatternGeneration() throws {
        let engine = CymaticsEngine()

        engine.generatePattern()

        XCTAssertFalse(engine.patternData.isEmpty)
        XCTAssertEqual(engine.patternData.count, 128)  // Grid size
    }

    func testPlateGeometries() throws {
        let geometries = CymaticsEngine.PlateGeometry.allCases

        XCTAssertEqual(geometries.count, 3)
        XCTAssertTrue(geometries.contains(.circular))
        XCTAssertTrue(geometries.contains(.square))
        XCTAssertTrue(geometries.contains(.rectangular))
    }

    func testNodalLineDetection() throws {
        let engine = CymaticsEngine()
        engine.currentFrequency = 500
        engine.generatePattern()

        let nodal = engine.nodalLinePositions()

        // Should detect some nodal lines for a standing wave pattern
        // Exact count depends on frequency/mode
        XCTAssertGreaterThan(nodal.count, 0, "Should detect nodal lines")
    }
}

// MARK: - Resonance Physics Tests

@MainActor
final class ResonancePhysicsTests: XCTestCase {

    func testQFactorAnalysis() throws {
        let engine = ResonancePhysicsEngine()

        let analysis = engine.analyzeQFactor(frequency: 1000, q: 10)

        XCTAssertEqual(analysis.qFactor, 10)
        XCTAssertEqual(analysis.bandwidth, 100, accuracy: 0.1)  // f/Q = 1000/10
        XCTAssertTrue(analysis.isUnderdamped)  // Q > 0.5 is underdamped
    }

    func testFrequencyResponse() throws {
        let engine = ResonancePhysicsEngine()
        engine.resonantFrequency = 1000
        engine.qFactor = 10

        // At resonance, magnitude should be maximum
        let atResonance = engine.magnitudeResponse(atFrequency: 1000)
        let belowResonance = engine.magnitudeResponse(atFrequency: 500)
        let aboveResonance = engine.magnitudeResponse(atFrequency: 2000)

        XCTAssertGreaterThan(atResonance, belowResonance)
        XCTAssertGreaterThan(atResonance, aboveResonance)
    }

    func testImpulseResponse() throws {
        let engine = ResonancePhysicsEngine()
        engine.resonantFrequency = 440
        engine.qFactor = 20

        let impulse = engine.impulseResponse(durationSeconds: 0.1)

        XCTAssertFalse(impulse.isEmpty)
        XCTAssertGreaterThan(impulse.count, 1000)
    }

    func testStringResonanceFormula() throws {
        // A4 string: 440 Hz
        // Guitar string length ≈ 0.65m, tension varies, linear density ≈ 0.0005 kg/m
        let frequency = ResonancePhysicsEngine.stringResonance(
            length: 0.65,
            tension: 73.0,  // Calculated to give 440 Hz
            linearDensity: 0.0005
        )

        XCTAssertEqual(frequency, 440, accuracy: 5)
    }

    func testTubeResonanceFormulas() throws {
        // Open tube (flute-like)
        // L = 0.39m should give ~440 Hz at room temperature
        let openTubeF = ResonancePhysicsEngine.openTubeResonance(
            length: 0.39,
            harmonic: 1,
            speedOfSound: 343
        )

        XCTAssertEqual(openTubeF, 440, accuracy: 5)

        // Closed tube has only odd harmonics
        let closedTubeF3 = ResonancePhysicsEngine.closedTubeResonance(
            length: 0.195,
            harmonic: 1,  // First harmonic
            speedOfSound: 343
        )

        XCTAssertGreaterThan(closedTubeF3, 400)
    }
}

// MARK: - Psychoacoustic Analyzer Tests

@MainActor
final class PsychoacousticAnalyzerTests: XCTestCase {

    func testThresholdOfHearing() throws {
        let analyzer = PsychoacousticAnalyzer()

        // Threshold is lowest around 2-4 kHz
        let threshold1k = analyzer.thresholdOfHearing(atFrequency: 1000)
        let threshold3k = analyzer.thresholdOfHearing(atFrequency: 3000)
        let threshold100 = analyzer.thresholdOfHearing(atFrequency: 100)

        // 3kHz should have lower threshold than 100Hz
        XCTAssertLessThan(threshold3k, threshold100)
    }

    func testBarkScale() throws {
        let analyzer = PsychoacousticAnalyzer()

        // Test Bark conversion
        let bark100 = analyzer.frequencyToBark(100)
        let bark1000 = analyzer.frequencyToBark(1000)
        let bark10000 = analyzer.frequencyToBark(10000)

        // Bark scale should be monotonically increasing
        XCTAssertLessThan(bark100, bark1000)
        XCTAssertLessThan(bark1000, bark10000)

        // 24 Bark ≈ 15500 Hz
        XCTAssertLessThan(bark10000, 24)
    }

    func testCriticalBandwidth() throws {
        let analyzer = PsychoacousticAnalyzer()

        let cb100 = analyzer.criticalBandwidth(atFrequency: 100)
        let cb1000 = analyzer.criticalBandwidth(atFrequency: 1000)
        let cb10000 = analyzer.criticalBandwidth(atFrequency: 10000)

        // Critical bandwidth increases with frequency
        XCTAssertLessThan(cb100, cb1000)
        XCTAssertLessThan(cb1000, cb10000)
    }

    func testAWeighting() throws {
        let analyzer = PsychoacousticAnalyzer()

        // A-weighting is 0 dB at 1kHz by definition
        let a1k = analyzer.aWeighting(atFrequency: 1000)
        XCTAssertEqual(a1k, 0, accuracy: 0.5)

        // Heavily attenuated at low frequencies
        let a50 = analyzer.aWeighting(atFrequency: 50)
        XCTAssertLessThan(a50, -20)

        // Less attenuated at high frequencies
        let a4k = analyzer.aWeighting(atFrequency: 4000)
        XCTAssertGreaterThan(a4k, a50)
    }

    func testSonesToPhonsConversion() throws {
        let analyzer = PsychoacousticAnalyzer()

        // 1 sone = 40 phons by definition
        let phonFor1Sone = analyzer.sonesToPhons(1.0)
        XCTAssertEqual(phonFor1Sone, 40, accuracy: 0.1)

        // 2 sones = 50 phons (doubling loudness = +10 phons)
        let phonFor2Sones = analyzer.sonesToPhons(2.0)
        XCTAssertEqual(phonFor2Sones, 50, accuracy: 0.1)
    }

    func testRoughness() throws {
        let analyzer = PsychoacousticAnalyzer()

        // Maximum roughness at ~25% of critical bandwidth
        let cb = analyzer.criticalBandwidth(atFrequency: 440)
        let maxRoughnessInterval = 0.25 * cb

        let roughnessMax = analyzer.roughness(
            frequency1: 440,
            frequency2: 440 + maxRoughnessInterval
        )

        let roughnessOctave = analyzer.roughness(
            frequency1: 440,
            frequency2: 880
        )

        // Max roughness should be higher than octave (consonant)
        XCTAssertGreaterThan(roughnessMax, roughnessOctave)
    }

    func testFrequencyJND() throws {
        let analyzer = PsychoacousticAnalyzer()

        // Below 500 Hz: ~3 Hz
        let jnd100 = analyzer.frequencyJND(atFrequency: 100)
        XCTAssertEqual(jnd100, 3, accuracy: 0.5)

        // Above 500 Hz: ~0.6%
        let jnd1000 = analyzer.frequencyJND(atFrequency: 1000)
        XCTAssertEqual(jnd1000, 6, accuracy: 1)  // 0.6% of 1000
    }
}
