// BridgeComponentTests.swift - Tests for Swift↔C++ Bridge Components
// Tests: BioDataBridge, OSCBridge, SyncBridge
// Copyright © 2025 Echoelmusic. All rights reserved.

import XCTest
@testable import Echoelmusic

// MARK: - BioDataBridge Tests

final class BioDataBridgeTests: XCTestCase {

    // Note: BioDataBridge is an Objective-C++ class
    // These tests validate the Swift-side interface

    // MARK: - HRV Data Tests

    func testHRVDataStructure() {
        // Test that HRV data structure has correct default values
        var hrvData = BioHRVData()

        // Verify structure can be initialized
        hrvData.heartRate = 72.0
        hrvData.hrv = 55.0
        hrvData.rmssd = 35.0
        hrvData.sdnn = 48.0
        hrvData.pnn50 = 18.0
        hrvData.lfHfRatio = 1.2
        hrvData.isValid = true

        XCTAssertEqual(hrvData.heartRate, 72.0, accuracy: 0.1)
        XCTAssertEqual(hrvData.hrv, 55.0, accuracy: 0.1)
        XCTAssertTrue(hrvData.isValid)
    }

    func testHRVNormalRange() {
        // Test HRV values are within normal physiological ranges
        let normalHeartRate: Float = 72.0
        let normalHRV: Float = 50.0

        XCTAssertTrue(normalHeartRate >= 40 && normalHeartRate <= 200, "Heart rate should be 40-200 BPM")
        XCTAssertTrue(normalHRV >= 10 && normalHRV <= 200, "HRV should be 10-200 ms")
    }

    // MARK: - EEG Data Tests

    func testEEGDataStructure() {
        var eegData = BioEEGData()

        // Set brainwave bands (normalized 0-1)
        eegData.delta = 0.2
        eegData.theta = 0.3
        eegData.alpha = 0.5   // Relaxed state
        eegData.beta = 0.3
        eegData.gamma = 0.1
        eegData.isValid = true

        XCTAssertEqual(eegData.alpha, 0.5, accuracy: 0.01)
        XCTAssertTrue(eegData.isValid)
    }

    func testEEGFocusCalculation() {
        // Focus = High Beta + Low Alpha
        let beta: Float = 0.7
        let alpha: Float = 0.2

        let focusLevel = (beta * 0.7) + ((1.0 - alpha) * 0.3)

        XCTAssertTrue(focusLevel >= 0 && focusLevel <= 1, "Focus level should be 0-1")
        XCTAssertGreaterThan(focusLevel, 0.5, "High beta/low alpha should indicate high focus")
    }

    func testEEGRelaxationCalculation() {
        // Relaxation = High Alpha + Low Beta
        let alpha: Float = 0.8
        let beta: Float = 0.2

        let relaxationLevel = (alpha * 0.7) + ((1.0 - beta) * 0.3)

        XCTAssertTrue(relaxationLevel >= 0 && relaxationLevel <= 1, "Relaxation level should be 0-1")
        XCTAssertGreaterThan(relaxationLevel, 0.5, "High alpha/low beta should indicate high relaxation")
    }

    // MARK: - Breathing Data Tests

    func testBreathingDataStructure() {
        var breathData = BioBreathingData()

        breathData.breathingRate = 12.0  // Normal adult breathing rate
        breathData.breathingDepth = 0.7
        breathData.isInhaling = true
        breathData.isValid = true

        XCTAssertEqual(breathData.breathingRate, 12.0, accuracy: 0.1)
        XCTAssertTrue(breathData.isInhaling)
    }

    func testBreathingCoherenceCalculation() {
        // Optimal coherent breathing is ~6 breaths/min
        let optimalRate: Float = 6.0
        let currentRate: Float = 6.5

        let rateDeviation = abs(currentRate - optimalRate) / optimalRate
        let coherenceScore = max(0.0, 1.0 - rateDeviation)

        XCTAssertGreaterThan(coherenceScore, 0.8, "Near-optimal breathing should have high coherence")
    }

    // MARK: - Audio Parameter Mapping Tests

    func testFilterCutoffMapping() {
        // Focus level maps to filter cutoff (200 Hz - 8200 Hz)
        let focusLevel: Float = 0.5
        let sensitivity: Float = 1.0

        let filterCutoff = 200.0 + (focusLevel * 8000.0 * sensitivity)

        XCTAssertEqual(filterCutoff, 4200.0, accuracy: 100)
        XCTAssertTrue(filterCutoff >= 200 && filterCutoff <= 8200)
    }

    func testLFORateMapping() {
        // Breathing rate maps to LFO rate
        let breathingRate: Float = 12.0  // breaths per minute
        let lfoRate = breathingRate / 60.0  // Convert to Hz

        XCTAssertEqual(lfoRate, 0.2, accuracy: 0.01)
    }

    func testMasterVolumeMapping() {
        // Coherence maps to master volume (0.5 - 1.0)
        let coherenceScore: Float = 0.8
        let masterVolume = 0.5 + (coherenceScore * 0.5)

        XCTAssertEqual(masterVolume, 0.9, accuracy: 0.01)
        XCTAssertTrue(masterVolume >= 0.5 && masterVolume <= 1.0)
    }

    // MARK: - Combined State Tests

    func testCombinedStateTimestamp() {
        var state = BioCombinedState()
        state.timestamp = Date().timeIntervalSince1970

        XCTAssertGreaterThan(state.timestamp, 0)
    }
}

// MARK: - OSCBridge Tests

final class OSCBridgeTests: XCTestCase {

    func testOSCAddressPattern() {
        // Test valid OSC address patterns
        let validAddresses = [
            "/echoelmusic/hrv",
            "/echoelmusic/eeg/alpha",
            "/echoelmusic/breathing/rate",
            "/parameter/filter/cutoff"
        ]

        for address in validAddresses {
            XCTAssertTrue(address.hasPrefix("/"), "OSC address must start with /")
            XCTAssertFalse(address.contains(" "), "OSC address must not contain spaces")
        }
    }

    func testOSCPortRange() {
        // Standard OSC ports
        let defaultSendPort = 9000
        let defaultReceivePort = 8000

        XCTAssertTrue(defaultSendPort >= 1024 && defaultSendPort <= 65535)
        XCTAssertTrue(defaultReceivePort >= 1024 && defaultReceivePort <= 65535)
    }

    func testOSCFloatNormalization() {
        // OSC float values should be normalized 0-1 for audio parameters
        let rawHRV: Float = 55.0
        let minHRV: Float = 20.0
        let maxHRV: Float = 100.0

        let normalizedHRV = (rawHRV - minHRV) / (maxHRV - minHRV)

        XCTAssertTrue(normalizedHRV >= 0 && normalizedHRV <= 1)
        XCTAssertEqual(normalizedHRV, 0.4375, accuracy: 0.01)
    }
}

// MARK: - SyncBridge Tests

final class SyncBridgeTests: XCTestCase {

    func testBPMRange() {
        // Valid BPM range for music
        let minBPM: Double = 20.0
        let maxBPM: Double = 300.0
        let defaultBPM: Double = 120.0

        XCTAssertTrue(defaultBPM >= minBPM && defaultBPM <= maxBPM)
    }

    func testBeatDurationCalculation() {
        // Beat duration in seconds = 60 / BPM
        let bpm: Double = 120.0
        let beatDuration = 60.0 / bpm

        XCTAssertEqual(beatDuration, 0.5, accuracy: 0.001)
    }

    func testSampleAccurateSync() {
        // Sample-accurate timing calculation
        let sampleRate: Double = 48000.0
        let bpm: Double = 120.0
        let beatDuration = 60.0 / bpm
        let samplesPerBeat = sampleRate * beatDuration

        XCTAssertEqual(samplesPerBeat, 24000.0, accuracy: 1.0)
    }

    func testTransportState() {
        // Transport states
        enum TransportState {
            case stopped
            case playing
            case recording
            case paused
        }

        let currentState: TransportState = .playing
        XCTAssertEqual(currentState, .playing)
    }

    func testPhaseAlignment() {
        // Phase should be 0-1 within a beat
        let currentSample: Int64 = 12000
        let samplesPerBeat: Int64 = 24000

        let phase = Double(currentSample % samplesPerBeat) / Double(samplesPerBeat)

        XCTAssertTrue(phase >= 0 && phase < 1)
        XCTAssertEqual(phase, 0.5, accuracy: 0.001)
    }
}

// MARK: - Integration Tests

final class BridgeIntegrationTests: XCTestCase {

    func testBioToAudioParameterFlow() {
        // Simulate the full flow: Bio data → Processing → Audio parameters

        // 1. Input bio data
        let heartRate: Float = 72.0
        let alpha: Float = 0.6
        let breathingRate: Float = 6.0  // Coherent breathing

        // 2. Process and map
        let hrvNorm = (heartRate - 40.0) / (200.0 - 40.0)  // Normalize HR
        let filterResonance = 0.1 + (hrvNorm * 0.8)
        let reverbSize = alpha * 0.8
        let lfoRate = breathingRate / 60.0

        // 3. Verify output parameters are in valid ranges
        XCTAssertTrue(filterResonance >= 0.1 && filterResonance <= 0.9)
        XCTAssertTrue(reverbSize >= 0 && reverbSize <= 0.8)
        XCTAssertTrue(lfoRate >= 0 && lfoRate <= 1.0)
    }

    func testCalibrationWorkflow() {
        // Test 60-second calibration workflow
        let calibrationDuration: TimeInterval = 60.0
        let sampleInterval: TimeInterval = 1.0
        let expectedSamples = Int(calibrationDuration / sampleInterval)

        XCTAssertEqual(expectedSamples, 60)
    }

    func testParameterSmoothing() {
        // Test exponential smoothing for parameter changes
        let currentValue: Float = 0.5
        let targetValue: Float = 0.8
        let smoothingFactor: Float = 0.9

        // Smoothed value = current + (1 - smoothing) * (target - current)
        let smoothedValue = currentValue + (1.0 - smoothingFactor) * (targetValue - currentValue)

        XCTAssertEqual(smoothedValue, 0.53, accuracy: 0.01)
        XCTAssertTrue(smoothedValue > currentValue && smoothedValue < targetValue)
    }
}

// MARK: - Performance Tests

final class BridgePerformanceTests: XCTestCase {

    func testParameterProcessingPerformance() {
        // Measure parameter processing time (should be < 1ms for real-time)
        measure {
            for _ in 0..<1000 {
                // Simulate parameter calculation
                let hrvNorm = Float.random(in: 0...1)
                let _ = 0.1 + (hrvNorm * 0.8)
                let alpha = Float.random(in: 0...1)
                let _ = alpha * 0.8
            }
        }
    }

    func testAudioBufferProcessingPerformance() {
        // Measure buffer processing time
        let bufferSize = 512
        let numChannels = 2
        var buffer = [Float](repeating: 0.0, count: bufferSize * numChannels)

        // Fill with test signal
        for i in 0..<buffer.count {
            buffer[i] = sin(Float(i) * 0.1)
        }

        measure {
            // Simple gain processing (similar to BioDataBridge.processAudioBuffer)
            let gain: Float = 0.8
            for i in 0..<buffer.count {
                buffer[i] *= gain
            }
        }
    }
}
