// EchoelmusicCompleteTests.swift
// Comprehensive test suite

import XCTest
@testable import EchoelmusicComplete

// MARK: - Biometric Data Tests

final class BiometricDataTests: XCTestCase {

    func testDefaultValues() {
        let data = BiometricData()

        XCTAssertEqual(data.heartRate, 70)
        XCTAssertEqual(data.hrvMs, 50)
        XCTAssertEqual(data.coherence, 50)
        XCTAssertEqual(data.breathingRate, 12)
        XCTAssertEqual(data.breathPhase, 0.5)
    }

    func testNormalizedCoherence() {
        let data = BiometricData(coherence: 75)
        XCTAssertEqual(data.normalizedCoherence, 0.75, accuracy: 0.01)
    }

    func testCoherenceLevelLow() {
        let data = BiometricData(coherence: 30)
        XCTAssertEqual(data.coherenceLevel, .low)
    }

    func testCoherenceLevelMedium() {
        let data = BiometricData(coherence: 55)
        XCTAssertEqual(data.coherenceLevel, .medium)
    }

    func testCoherenceLevelHigh() {
        let data = BiometricData(coherence: 85)
        XCTAssertEqual(data.coherenceLevel, .high)
    }
}

// MARK: - Coherence Calculator Tests

final class CoherenceCalculatorTests: XCTestCase {

    func testCalculateWithLowHRV() {
        let calculator = CoherenceCalculator()
        let coherence = calculator.calculate(hrvMs: 25, rrIntervals: [])

        XCTAssertLessThan(coherence, 30)
    }

    func testCalculateWithHighHRV() {
        let calculator = CoherenceCalculator()
        let coherence = calculator.calculate(hrvMs: 90, rrIntervals: [])

        XCTAssertGreaterThan(coherence, 70)
    }

    func testCoherenceBounds() {
        let calculator = CoherenceCalculator()

        let veryLow = calculator.calculate(hrvMs: 0, rrIntervals: [])
        XCTAssertGreaterThanOrEqual(veryLow, 0)
        XCTAssertLessThanOrEqual(veryLow, 100)

        let veryHigh = calculator.calculate(hrvMs: 200, rrIntervals: [])
        XCTAssertGreaterThanOrEqual(veryHigh, 0)
        XCTAssertLessThanOrEqual(veryHigh, 100)
    }
}

// MARK: - Audio Mode Tests

final class AudioModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(AudioMode.allCases.count, 4)
    }

    func testIcons() {
        for mode in AudioMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    func testDescriptions() {
        for mode in AudioMode.allCases {
            XCTAssertFalse(mode.description.isEmpty)
        }
    }
}

// MARK: - Visualization Type Tests

final class VisualizationTypeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(VisualizationType.allCases.count, 5)
    }

    func testIcons() {
        for type in VisualizationType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }
}

// MARK: - Binaural State Tests

final class BinauralStateTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(BinauralState.allCases.count, 5)
    }

    func testDeltaFrequency() {
        XCTAssertEqual(BinauralState.delta.frequency, 2.0, accuracy: 0.1)
    }

    func testThetaFrequency() {
        XCTAssertEqual(BinauralState.theta.frequency, 6.0, accuracy: 0.1)
    }

    func testAlphaFrequency() {
        XCTAssertEqual(BinauralState.alpha.frequency, 10.0, accuracy: 0.1)
    }

    func testBetaFrequency() {
        XCTAssertEqual(BinauralState.beta.frequency, 20.0, accuracy: 0.1)
    }

    func testGammaFrequency() {
        XCTAssertEqual(BinauralState.gamma.frequency, 40.0, accuracy: 0.1)
    }
}

// MARK: - Preset Tests

final class PresetTests: XCTestCase {

    func testPresetCreation() {
        let preset = Preset(
            name: "Test",
            visualization: .mandala,
            audioMode: .binaural
        )

        XCTAssertEqual(preset.name, "Test")
        XCTAssertEqual(preset.visualization, .mandala)
        XCTAssertEqual(preset.audioMode, .binaural)
    }

    func testDefaultPresetsCount() {
        XCTAssertEqual(DefaultPresets.all.count, 8)
    }

    func testDefaultPresetsHaveUniqueNames() {
        let names = DefaultPresets.all.map { $0.name }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count)
    }

    func testPresetCodable() throws {
        let preset = Preset(
            name: "Test Preset",
            visualization: .particles,
            audioMode: .drone,
            binauralState: .theta,
            baseFrequency: 528.0,
            volume: 0.8
        )

        let encoded = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(Preset.self, from: encoded)

        XCTAssertEqual(preset.name, decoded.name)
        XCTAssertEqual(preset.visualization, decoded.visualization)
        XCTAssertEqual(preset.audioMode, decoded.audioMode)
        XCTAssertEqual(preset.binauralState, decoded.binauralState)
        XCTAssertEqual(preset.baseFrequency, decoded.baseFrequency)
        XCTAssertEqual(preset.volume, decoded.volume)
    }
}

// MARK: - Constants Tests

final class ConstantsTests: XCTestCase {

    func testSampleRate() {
        XCTAssertEqual(AppConstants.sampleRate, 44100)
    }

    func testBufferSize() {
        XCTAssertEqual(AppConstants.bufferSize, 256)
    }

    func testOSCPorts() {
        XCTAssertEqual(AppConstants.oscSendPort, 8000)
        XCTAssertEqual(AppConstants.oscReceivePort, 9000)
    }
}

// MARK: - Health Disclaimer Tests

final class HealthDisclaimerTests: XCTestCase {

    func testShortDisclaimerExists() {
        XCTAssertFalse(HealthDisclaimer.short.isEmpty)
    }

    func testFullDisclaimerExists() {
        XCTAssertFalse(HealthDisclaimer.full.isEmpty)
    }

    func testDisclaimerContainsNotMedical() {
        XCTAssertTrue(HealthDisclaimer.full.contains("NOT a medical device"))
    }
}

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {

    func testBiometricDataCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = BiometricData(
                    heartRate: Double.random(in: 50...150),
                    hrvMs: Double.random(in: 20...100),
                    coherence: Double.random(in: 0...100),
                    breathingRate: Double.random(in: 8...20),
                    breathPhase: Double.random(in: 0...1)
                )
            }
        }
    }

    func testCoherenceCalculationPerformance() {
        let calculator = CoherenceCalculator()
        let intervals = (0..<120).map { _ in Double.random(in: 700...1200) }

        measure {
            for _ in 0..<1000 {
                _ = calculator.calculate(hrvMs: Double.random(in: 20...100), rrIntervals: intervals)
            }
        }
    }

    func testPresetLookupPerformance() {
        let presets = DefaultPresets.all

        measure {
            for _ in 0..<10000 {
                _ = presets.first { $0.name == "Meditation" }
            }
        }
    }
}

// MARK: - Integration Tests

@MainActor
final class IntegrationTests: XCTestCase {

    func testBiofeedbackManagerInitialization() {
        let manager = BiofeedbackManager()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testBiofeedbackManagerStartStop() {
        let manager = BiofeedbackManager()

        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)

        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testAudioEngineInitialization() {
        let engine = AudioEngine()
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.volume, 0.7, accuracy: 0.01)
    }

    func testPresetManagerInitialization() {
        let manager = PresetManager()
        XCTAssertFalse(manager.presets.isEmpty)
    }

    func testPresetManagerResetToDefaults() {
        let manager = PresetManager()
        let originalCount = manager.presets.count

        // Add custom preset
        manager.addPreset(Preset(name: "Custom"))
        XCTAssertEqual(manager.presets.count, originalCount + 1)

        // Reset
        manager.resetToDefaults()
        XCTAssertEqual(manager.presets.count, DefaultPresets.all.count)
    }
}
