// EchoelmusicMVP Tests
// Minimal test suite for MVP validation

import XCTest
@testable import EchoelmusicMVP

final class EchoelmusicMVPTests: XCTestCase {

    // MARK: - Bio Data Tests

    func testBioDataInitialization() {
        let bioData = SimpleBioData()

        XCTAssertEqual(bioData.heartRate, 72.0)
        XCTAssertEqual(bioData.hrv, 50.0)
        XCTAssertEqual(bioData.coherence, 0.5)
        XCTAssertEqual(bioData.breathingRate, 12.0)
    }

    func testBioDataCustomValues() {
        let bioData = SimpleBioData(
            heartRate: 80.0,
            hrv: 65.0,
            coherence: 0.75,
            breathingRate: 14.0
        )

        XCTAssertEqual(bioData.heartRate, 80.0)
        XCTAssertEqual(bioData.hrv, 65.0)
        XCTAssertEqual(bioData.coherence, 0.75)
        XCTAssertEqual(bioData.breathingRate, 14.0)
    }

    func testCoherenceCalculation() {
        // Low HRV = Low coherence
        let lowCoherence = SimpleBioData.calculateCoherence(hrv: 20)
        XCTAssertLessThan(lowCoherence, 0.3)

        // Medium HRV = Medium coherence
        let mediumCoherence = SimpleBioData.calculateCoherence(hrv: 50)
        XCTAssertGreaterThan(mediumCoherence, 0.3)
        XCTAssertLessThan(mediumCoherence, 0.7)

        // High HRV = High coherence
        let highCoherence = SimpleBioData.calculateCoherence(hrv: 80)
        XCTAssertGreaterThan(highCoherence, 0.7)
    }

    func testCoherenceBounds() {
        // Coherence should always be between 0 and 1
        let veryLow = SimpleBioData.calculateCoherence(hrv: 0)
        XCTAssertGreaterThanOrEqual(veryLow, 0)
        XCTAssertLessThanOrEqual(veryLow, 1)

        let veryHigh = SimpleBioData.calculateCoherence(hrv: 200)
        XCTAssertGreaterThanOrEqual(veryHigh, 0)
        XCTAssertLessThanOrEqual(veryHigh, 1)
    }

    // MARK: - Health Disclaimer Tests

    func testHealthDisclaimerExists() {
        XCTAssertFalse(HealthDisclaimer.shortText.isEmpty)
        XCTAssertFalse(HealthDisclaimer.fullText.isEmpty)
    }

    func testHealthDisclaimerContent() {
        // Must contain key legal phrases
        XCTAssertTrue(HealthDisclaimer.fullText.contains("NOT a medical device"))
        XCTAssertTrue(HealthDisclaimer.fullText.contains("NOT provide medical advice"))
        XCTAssertTrue(HealthDisclaimer.fullText.contains("consult"))
    }

    // MARK: - Audio Preset Tests

    func testAudioPresetCases() {
        XCTAssertEqual(AudioPreset.allCases.count, 4)
    }

    func testAudioPresetFrequencies() {
        XCTAssertEqual(AudioPreset.calm.baseFrequency, 329.628, accuracy: 0.01)   // E4
        XCTAssertEqual(AudioPreset.focus.baseFrequency, 440.0, accuracy: 0.01)    // A4
        XCTAssertEqual(AudioPreset.energize.baseFrequency, 659.255, accuracy: 0.01) // E5
        XCTAssertEqual(AudioPreset.meditate.baseFrequency, 220.0, accuracy: 0.01)  // A3
    }

    func testAudioPresetHarmonics() {
        // All harmonic blends should be between 0 and 1
        for preset in AudioPreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.harmonicBlend, 0)
            XCTAssertLessThanOrEqual(preset.harmonicBlend, 1)
        }
    }

    func testAudioPresetReverb() {
        // All reverb values should be between 0 and 100
        for preset in AudioPreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.reverbMix, 0)
            XCTAssertLessThanOrEqual(preset.reverbMix, 100)
        }
    }

    // MARK: - Performance Tests

    func testCoherenceCalculationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = SimpleBioData.calculateCoherence(hrv: Double.random(in: 0...100))
            }
        }
    }

    func testBioDataCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = SimpleBioData(
                    heartRate: Double.random(in: 50...150),
                    hrv: Double.random(in: 20...100),
                    coherence: Double.random(in: 0...1),
                    breathingRate: Double.random(in: 8...20)
                )
            }
        }
    }
}

// MARK: - HealthKit Manager Tests

@MainActor
final class HealthKitManagerTests: XCTestCase {

    func testManagerInitialization() async {
        let manager = SimpleHealthKitManager()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testStartStopMonitoring() async {
        let manager = SimpleHealthKitManager()

        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)

        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)
    }

    func testBioDataCallback() async {
        let manager = SimpleHealthKitManager()
        let expectation = XCTestExpectation(description: "Bio data received")

        manager.onBioDataUpdate = { bioData in
            XCTAssertGreaterThan(bioData.heartRate, 0)
            expectation.fulfill()
        }

        manager.startMonitoring()

        await fulfillment(of: [expectation], timeout: 3.0)

        manager.stopMonitoring()
    }
}

// MARK: - Audio Engine Tests

@MainActor
final class AudioEngineTests: XCTestCase {

    func testEngineInitialization() {
        let engine = BasicAudioEngine()
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.volume, 0.7)
    }

    func testVolumeRange() {
        let engine = BasicAudioEngine()

        engine.setVolume(0.5)
        XCTAssertEqual(engine.volume, 0.5)

        engine.setVolume(-1.0) // Should clamp to 0
        XCTAssertEqual(engine.volume, 0.0)

        engine.setVolume(2.0) // Should clamp to 1
        XCTAssertEqual(engine.volume, 1.0)
    }

    func testFrequencyRange() {
        let engine = BasicAudioEngine()

        engine.setFrequency(440.0)
        // Frequency changes are internal, just verify no crash

        engine.setFrequency(10.0) // Should clamp to 20
        engine.setFrequency(5000.0) // Should clamp to 2000
    }

    func testBioDataIntegration() {
        let engine = BasicAudioEngine()

        let bioData = SimpleBioData(
            heartRate: 80.0,
            hrv: 65.0,
            coherence: 0.8,
            breathingRate: 10.0
        )

        // Should not crash
        engine.updateFromBioData(bioData)

        XCTAssertEqual(engine.coherenceLevel, 0.8, accuracy: 0.01)
    }
}
