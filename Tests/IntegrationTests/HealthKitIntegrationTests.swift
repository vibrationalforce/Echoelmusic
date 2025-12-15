//
// HealthKitIntegrationTests.swift
// Echoelmusic
//
// HealthKit → Bio-Reactive DSP integration tests
// Validates: Heart Rate → DSP Modulation → Audio Output
//

import XCTest
import HealthKit
@testable import Echoelmusic

class HealthKitIntegrationTests: IntegrationTestBase {

    // MARK: - HealthKit to Audio Pipeline Tests

    func testHealthKitToBioReactiveFlow() throws {
        // Test complete flow: HealthKit heart rate → BioReactive DSP → Audio

        // 1. Start audio engine with bio-reactive processing
        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        // 2. Inject mock heart rate data
        let testHeartRate: Double = 75.0
        injectMockHeartRate(testHeartRate)

        // Wait for heart rate to propagate
        let hrUpdated = waitForCondition(timeout: 5.0) {
            self.healthKitManager.currentHeartRate == testHeartRate
        }

        XCTAssertTrue(hrUpdated, "Heart rate did not update")

        // 3. Process audio and verify bio-reactive modulation
        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        var processedBuffer: AVAudioPCMBuffer?

        waitForCompletion(description: "Bio-reactive processing") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    processedBuffer = buffer
                }
                completion()
            }
        }

        // 4. Verify output reflects heart rate influence
        guard let output = processedBuffer else {
            XCTFail("No processed buffer")
            return
        }

        XCTAssertTrue(verifyBufferValid(output), "Output buffer invalid")
        assertNoAudioArtifacts(output)

        // Verify audio characteristics changed based on heart rate
        let rms = calculateRMS(buffer: output)
        assertAudioLevel(rms, inRange: 0.01...2.0)
    }

    func testHeartRateVariabilityModulation() throws {
        // Test HRV (Heart Rate Variability) affects DSP parameters

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        // Test with low HRV (stressed state)
        healthKitManager.injectTestHRV(value: 20.0) // Low HRV

        var outputLowHRV: AVAudioPCMBuffer?
        waitForCompletion(description: "Low HRV") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputLowHRV = buffer
                }
                completion()
            }
        }

        // Test with high HRV (relaxed state)
        healthKitManager.injectTestHRV(value: 80.0) // High HRV

        var outputHighHRV: AVAudioPCMBuffer?
        waitForCompletion(description: "High HRV") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputHighHRV = buffer
                }
                completion()
            }
        }

        // Verify HRV affects processing differently
        guard let lowHRV = outputLowHRV, let highHRV = outputHighHRV else {
            XCTFail("Missing output buffers")
            return
        }

        let rmsLow = calculateRMS(buffer: lowHRV)
        let rmsHigh = calculateRMS(buffer: highHRV)

        XCTAssertNotEqual(
            rmsLow,
            rmsHigh,
            accuracy: 0.05,
            "HRV changes did not affect processing"
        )
    }

    func testDynamicHeartRateUpdates() throws {
        // Test real-time heart rate changes affect audio processing

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.2)

        var outputs: [AVAudioPCMBuffer] = []
        let heartRates: [Double] = [60, 80, 100, 120, 100, 80, 60]

        for bpm in heartRates {
            // Update heart rate
            injectMockHeartRate(bpm)

            // Allow time for update
            Thread.sleep(forTimeInterval: 0.1)

            // Process audio
            var output: AVAudioPCMBuffer?
            waitForCompletion(description: "Process @\(bpm)BPM") { completion in
                self.audioEngine.processBuffer(testBuffer) { result in
                    if case .success(let buffer) = result {
                        output = buffer
                    }
                    completion()
                }
            }

            if let buffer = output {
                outputs.append(buffer)
            }
        }

        // Verify we got all outputs
        XCTAssertEqual(outputs.count, heartRates.count, "Missing outputs")

        // Verify outputs differ (heart rate changes affected processing)
        let rmsValues = outputs.map { calculateRMS(buffer: $0) }

        for i in 0..<(rmsValues.count - 1) {
            // At least some consecutive pairs should differ
            if abs(rmsValues[i] - rmsValues[i + 1]) > 0.01 {
                return // Found difference, test passes
            }
        }

        XCTFail("Heart rate changes did not affect audio processing")
    }

    func testHealthKitPermissionHandling() throws {
        // Test graceful handling when HealthKit permissions denied

        // Simulate no permissions
        healthKitManager.setTestPermissions(granted: false)

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        // Should still process audio (fallback to default behavior)
        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        var processed = false

        waitForCompletion(description: "Process without permissions") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                processed = result.isSuccess
                completion()
            }
        }

        XCTAssertTrue(processed, "Failed to process without HealthKit")

        // Verify no crash or hang
        XCTAssertTrue(audioEngine.isRunning, "Audio engine stopped")
    }

    func testHealthKitDataCaching() throws {
        // Test HealthKit data is cached to reduce queries

        healthKitManager.clearTestCache()

        // First query - should fetch from HealthKit
        injectMockHeartRate(75.0)

        let firstFetch = Date()
        _ = healthKitManager.currentHeartRate

        let firstQueryTime = Date().timeIntervalSince(firstFetch)

        // Second query immediately after - should use cache
        let secondFetch = Date()
        _ = healthKitManager.currentHeartRate

        let secondQueryTime = Date().timeIntervalSince(secondFetch)

        // Cached query should be significantly faster
        XCTAssertLessThan(
            secondQueryTime,
            firstQueryTime * 0.1,
            "HealthKit data not cached"
        )
    }

    func testBioMetricsCoherence() throws {
        // Test heart rate and HRV maintain coherence over time

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        // Simulate coherent bio-metrics (low HR + high HRV = relaxed)
        injectMockHeartRate(65.0)
        healthKitManager.injectTestHRV(value: 75.0)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        var outputRelaxed: AVAudioPCMBuffer?
        waitForCompletion(description: "Relaxed state") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputRelaxed = buffer
                }
                completion()
            }
        }

        // Simulate incoherent bio-metrics (high HR + low HRV = stressed)
        injectMockHeartRate(110.0)
        healthKitManager.injectTestHRV(value: 25.0)

        var outputStressed: AVAudioPCMBuffer?
        waitForCompletion(description: "Stressed state") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputStressed = buffer
                }
                completion()
            }
        }

        // Verify coherent vs incoherent states produce different audio
        guard let relaxed = outputRelaxed, let stressed = outputStressed else {
            XCTFail("Missing output buffers")
            return
        }

        let rmsRelaxed = calculateRMS(buffer: relaxed)
        let rmsStressed = calculateRMS(buffer: stressed)

        XCTAssertNotEqual(
            rmsRelaxed,
            rmsStressed,
            accuracy: 0.05,
            "Coherence state did not affect audio"
        )
    }

    func testBreathingRateIntegration() throws {
        // Test breathing rate (if available) modulates audio

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 1.0)

        // Test with slow breathing (relaxed)
        healthKitManager.injectTestBreathingRate(rate: 8.0) // 8 breaths/min

        var outputSlowBreath: AVAudioPCMBuffer?
        waitForCompletion(description: "Slow breathing") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputSlowBreath = buffer
                }
                completion()
            }
        }

        // Test with fast breathing (active)
        healthKitManager.injectTestBreathingRate(rate: 20.0) // 20 breaths/min

        var outputFastBreath: AVAudioPCMBuffer?
        waitForCompletion(description: "Fast breathing") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputFastBreath = buffer
                }
                completion()
            }
        }

        // Verify breathing rate affects processing
        guard let slow = outputSlowBreath, let fast = outputFastBreath else {
            XCTFail("Missing output buffers")
            return
        }

        let rmsSlow = calculateRMS(buffer: slow)
        let rmsFast = calculateRMS(buffer: fast)

        // Different breathing rates should produce different audio
        XCTAssertNotEqual(
            rmsSlow,
            rmsFast,
            accuracy: 0.05,
            "Breathing rate did not affect processing"
        )
    }

    func testHealthKitErrorRecovery() throws {
        // Test recovery from HealthKit query errors

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        // Simulate HealthKit error
        healthKitManager.simulateError(.dataUnavailable)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        // Should still process audio despite error
        var processed = false

        waitForCompletion(description: "Process with error") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                processed = result.isSuccess
                completion()
            }
        }

        XCTAssertTrue(processed, "Failed to recover from HealthKit error")

        // Recover from error
        healthKitManager.clearError()
        injectMockHeartRate(75.0)

        // Should resume normal operation
        processed = false

        waitForCompletion(description: "Process after recovery") { completion in
            self.audioEngine.processBuffer(testBuffer) { result in
                processed = result.isSuccess
                completion()
            }
        }

        XCTAssertTrue(processed, "Failed to resume after error recovery")
    }
}

// MARK: - Test Configuration

extension HealthKitIntegrationTests {
    override func setUp() {
        super.setUp()
        // Enable test mode for HealthKitManager
        healthKitManager.testMode = true
    }

    override func tearDown() {
        // Disable test mode
        healthKitManager.testMode = false
        super.tearDown()
    }
}
