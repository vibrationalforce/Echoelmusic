import XCTest
@testable import Blab

/// Unit tests for Breathing Phase Detector
/// Validates RSA-based breathing cycle detection and phase calculation
final class BreathingPhaseDetectorTests: XCTestCase {

    var detector: BreathingPhaseDetector!

    override func setUp() {
        super.setUp()
        detector = BreathingPhaseDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(detector.currentPhase, 0.0, accuracy: 0.01)
        XCTAssertEqual(detector.breathingRate, 15.0, accuracy: 0.1)
        XCTAssertEqual(detector.rsaAmplitude, 0.0, accuracy: 0.01)
        XCTAssertEqual(detector.confidence, 0.0, accuracy: 0.01)
    }

    func testReset() {
        // Add some data
        for _ in 0..<50 {
            detector.addRRInterval(Double.random(in: 700...900))
        }

        detector.reset()

        XCTAssertEqual(detector.currentPhase, 0.0, accuracy: 0.01)
        XCTAssertEqual(detector.breathingRate, 15.0, accuracy: 0.1)
        XCTAssertEqual(detector.rsaAmplitude, 0.0, accuracy: 0.01)
        XCTAssertEqual(detector.confidence, 0.0, accuracy: 0.01)
    }

    // MARK: - RR Interval Input Tests

    func testAddRRInterval_ValidRange() {
        detector.addRRInterval(800.0)  // Valid
        // No crash = success
    }

    func testAddRRInterval_OutOfRange() {
        detector.addRRInterval(100.0)   // Too low (should be rejected)
        detector.addRRInterval(3000.0)  // Too high (should be rejected)
        // Should handle gracefully without crashing
    }

    // MARK: - Synthetic RSA Signal Tests

    /// Test with synthetic breathing signal at 15 breaths/min (0.25 Hz)
    func testSyntheticBreathing_15BPM() {
        // Generate 120 RR intervals with 15 breaths/min RSA pattern
        // 15 breaths/min = 0.25 Hz = 4-second cycles
        // At 60 BPM: 1 RR interval per second = 4 intervals per breath cycle

        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time) // 0.25 Hz = 15 breaths/min
            let baseRR = 800.0  // 75 BPM
            let rsaModulation = breathingPhase * 80.0 // ±80ms RSA amplitude
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        // After processing, breathing rate should be detected
        XCTAssertGreaterThan(detector.breathingRate, 10.0, "Should detect breathing rate")
        XCTAssertLessThan(detector.breathingRate, 20.0, "Breathing rate should be in physiological range")

        print("Detected rate: \(detector.breathingRate) breaths/min")
        print("RSA amplitude: \(detector.rsaAmplitude) ms")
        print("Confidence: \(detector.confidence * 100)%")
    }

    /// Test with slow breathing (6 breaths/min - 0.1 Hz)
    func testSyntheticBreathing_SlowBreathing() {
        // 6 breaths/min = 0.1 Hz (HeartMath coherence breathing)
        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.1 * time)
            let baseRR = 1000.0  // 60 BPM
            let rsaModulation = breathingPhase * 100.0 // Large RSA amplitude
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        XCTAssertGreaterThan(detector.breathingRate, 4.0)
        XCTAssertLessThan(detector.breathingRate, 10.0)
        XCTAssertGreaterThan(detector.rsaAmplitude, 50.0, "Slow breathing should have strong RSA")

        print("Slow breathing - Rate: \(detector.breathingRate) breaths/min")
    }

    /// Test with fast breathing (20 breaths/min - 0.33 Hz)
    func testSyntheticBreathing_FastBreathing() {
        // 20 breaths/min = 0.33 Hz
        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.33 * time)
            let baseRR = 700.0  // ~85 BPM
            let rsaModulation = breathingPhase * 60.0
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        XCTAssertGreaterThan(detector.breathingRate, 15.0)
        XCTAssertLessThan(detector.breathingRate, 25.0)

        print("Fast breathing - Rate: \(detector.breathingRate) breaths/min")
    }

    // MARK: - Phase Detection Tests

    func testBreathingPhase_Range() {
        // Generate synthetic breathing signal
        for i in 0..<100 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let rrInterval = 800.0 + breathingPhase * 80.0
            detector.addRRInterval(rrInterval)
        }

        // Phase should be in valid range
        XCTAssertGreaterThanOrEqual(detector.currentPhase, 0.0)
        XCTAssertLessThanOrEqual(detector.currentPhase, 1.0)

        print("Current phase: \(detector.currentPhase)")
    }

    func testInhaleExhaleDetection() {
        // Test phase interpretation
        // Note: This is a basic test - actual phase detection requires real-time data

        // Phase 0.0-0.5 should be inhaling
        // Phase 0.5-1.0 should be exhaling

        // We can't directly set the phase, but we can test the properties
        XCTAssertTrue(detector.currentPhase >= 0.0 && detector.currentPhase <= 1.0)
    }

    // MARK: - RSA Amplitude Tests

    func testRSAAmplitude_HighAmplitude() {
        // Strong RSA signal (large amplitude)
        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let baseRR = 800.0
            let rsaModulation = breathingPhase * 120.0 // Large amplitude
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        // Strong RSA should be detected
        XCTAssertGreaterThan(detector.rsaAmplitude, 50.0, "High RSA amplitude should be detected")
        XCTAssertGreaterThan(detector.confidence, 0.3, "High RSA should increase confidence")

        print("High RSA - Amplitude: \(detector.rsaAmplitude) ms, Confidence: \(detector.confidence * 100)%")
    }

    func testRSAAmplitude_LowAmplitude() {
        // Weak RSA signal (small amplitude)
        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let baseRR = 800.0
            let rsaModulation = breathingPhase * 15.0 // Small amplitude
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        // Low RSA may still be detected but with lower confidence
        XCTAssertLessThan(detector.rsaAmplitude, 80.0)

        print("Low RSA - Amplitude: \(detector.rsaAmplitude) ms, Confidence: \(detector.confidence * 100)%")
    }

    // MARK: - Confidence Tests

    func testConfidence_GoodSignal() {
        // Clean, strong breathing signal
        for i in 0..<150 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let baseRR = 800.0
            let rsaModulation = breathingPhase * 100.0
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        // Good signal should produce reasonable confidence
        XCTAssertGreaterThanOrEqual(detector.confidence, 0.0)
        XCTAssertLessThanOrEqual(detector.confidence, 1.0)

        print("Good signal - Confidence: \(detector.confidence * 100)%")
    }

    func testConfidence_NoisySignal() {
        // Noisy signal with random variations
        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let noise = Double.random(in: -50...50)
            let baseRR = 800.0
            let rsaModulation = breathingPhase * 80.0
            let rrInterval = baseRR + rsaModulation + noise

            detector.addRRInterval(rrInterval)
        }

        // Noisy signal may have lower confidence
        XCTAssertGreaterThanOrEqual(detector.confidence, 0.0)
        XCTAssertLessThanOrEqual(detector.confidence, 1.0)

        print("Noisy signal - Confidence: \(detector.confidence * 100)%")
    }

    // MARK: - Edge Case Tests

    func testConstantRRIntervals() {
        // No RSA (constant RR intervals)
        for _ in 0..<100 {
            detector.addRRInterval(800.0)
        }

        // Should handle gracefully
        XCTAssertEqual(detector.rsaAmplitude, 0.0, accuracy: 10.0)
        XCTAssertEqual(detector.confidence, 0.0, accuracy: 0.2)
    }

    func testRandomRRIntervals() {
        // Completely random (no breathing pattern)
        for _ in 0..<120 {
            detector.addRRInterval(Double.random(in: 600...1000))
        }

        // Should not detect strong breathing pattern
        XCTAssertLessThan(detector.confidence, 0.5, "Random data should have low confidence")
    }

    func testInsufficientData() {
        // Only a few RR intervals
        for _ in 0..<10 {
            detector.addRRInterval(800.0)
        }

        // Should handle gracefully without crashing
        XCTAssertEqual(detector.currentPhase, 0.0, accuracy: 0.01)
    }

    // MARK: - Multiple Breathing Rates Tests

    func testVaryingBreathingRates() {
        let breathingRates: [Double] = [6.0, 12.0, 15.0, 18.0, 24.0] // breaths/min

        for rate in breathingRates {
            detector.reset()

            let frequency = rate / 60.0 // Convert to Hz

            for i in 0..<120 {
                let time = Double(i)
                let breathingPhase = sin(2.0 * .pi * frequency * time)
                let baseRR = 800.0
                let rsaModulation = breathingPhase * 80.0
                let rrInterval = baseRR + rsaModulation

                detector.addRRInterval(rrInterval)
            }

            // Should detect breathing rate within reasonable range
            XCTAssertGreaterThan(detector.breathingRate, rate * 0.6, "Should detect \(rate) BPM (lower bound)")
            XCTAssertLessThan(detector.breathingRate, rate * 1.4, "Should detect \(rate) BPM (upper bound)")

            print("Target rate: \(rate) BPM, Detected: \(detector.breathingRate) BPM")
        }
    }

    // MARK: - Breathing State Description Tests

    func testBreathingStateDescription() {
        let description = detector.breathingStateDescription

        // Should return one of the valid states
        XCTAssertTrue(["Inhaling", "Exhaling", "Transition"].contains(description))
    }

    func testBreathingAnalysisSummary() {
        // Add synthetic data
        for i in 0..<100 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let rrInterval = 800.0 + breathingPhase * 80.0
            detector.addRRInterval(rrInterval)
        }

        let summary = detector.breathingAnalysisSummary

        XCTAssertTrue(summary.contains("Phase"), "Summary should contain phase information")
        XCTAssertTrue(summary.contains("Rate"), "Summary should contain rate information")
        XCTAssertTrue(summary.contains("RSA"), "Summary should contain RSA information")
        XCTAssertTrue(summary.contains("Confidence"), "Summary should contain confidence information")

        print("Breathing analysis summary:\n\(summary)")
    }

    // MARK: - Real-world Simulation Tests

    func testRelaxedBreathing_Simulation() {
        // Simulate relaxed breathing: 6-8 breaths/min with strong RSA
        let breathingRate = 7.0 / 60.0 // 7 breaths/min = 0.117 Hz

        for i in 0..<150 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * breathingRate * time)
            let baseRR = 1000.0  // 60 BPM (relaxed)
            let rsaModulation = breathingPhase * 120.0 // Strong RSA
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        XCTAssertGreaterThan(detector.breathingRate, 5.0)
        XCTAssertLessThan(detector.breathingRate, 10.0)
        XCTAssertGreaterThan(detector.rsaAmplitude, 80.0, "Relaxed breathing should have strong RSA")

        print("Relaxed breathing simulation:")
        print(detector.breathingAnalysisSummary)
    }

    func testStressedBreathing_Simulation() {
        // Simulate stressed breathing: 18-22 breaths/min with weak RSA
        let breathingRate = 20.0 / 60.0 // 20 breaths/min = 0.33 Hz

        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * breathingRate * time)
            let baseRR = 700.0  // 85 BPM (elevated)
            let rsaModulation = breathingPhase * 40.0 // Weak RSA
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)
        }

        XCTAssertGreaterThan(detector.breathingRate, 15.0)
        XCTAssertLessThan(detector.breathingRate, 25.0)

        print("Stressed breathing simulation:")
        print(detector.breathingAnalysisSummary)
    }

    // MARK: - Integration Tests

    func testMultipleCycles_Tracking() {
        // Test continuous tracking through multiple breath cycles
        for i in 0..<200 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * 0.25 * time)
            let baseRR = 800.0
            let rsaModulation = breathingPhase * 80.0
            let rrInterval = baseRR + rsaModulation

            detector.addRRInterval(rrInterval)

            // After sufficient data, phase should be tracked
            if i > 50 {
                XCTAssertGreaterThanOrEqual(detector.currentPhase, 0.0)
                XCTAssertLessThanOrEqual(detector.currentPhase, 1.0)
            }
        }

        print("After 200 intervals:")
        print(detector.breathingAnalysisSummary)
    }

    // MARK: - Performance Tests

    func testProcessingPerformance() {
        measure {
            for i in 0..<120 {
                let time = Double(i)
                let breathingPhase = sin(2.0 * .pi * 0.25 * time)
                let rrInterval = 800.0 + breathingPhase * 80.0
                detector.addRRInterval(rrInterval)
            }
        }
    }

    // MARK: - Boundary Condition Tests

    func testMinimumBreathingRate() {
        // 4 breaths/min (minimum detectable)
        let frequency = 4.0 / 60.0

        for i in 0..<150 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * frequency * time)
            let rrInterval = 1200.0 + breathingPhase * 150.0
            detector.addRRInterval(rrInterval)
        }

        // Should handle very slow breathing
        XCTAssertGreaterThanOrEqual(detector.breathingRate, 3.0)
        XCTAssertLessThan(detector.breathingRate, 8.0)
    }

    func testMaximumBreathingRate() {
        // 30 breaths/min (maximum detectable)
        let frequency = 30.0 / 60.0

        for i in 0..<120 {
            let time = Double(i)
            let breathingPhase = sin(2.0 * .pi * frequency * time)
            let rrInterval = 600.0 + breathingPhase * 50.0
            detector.addRRInterval(rrInterval)
        }

        // Should handle very fast breathing
        XCTAssertGreaterThan(detector.breathingRate, 20.0)
        XCTAssertLessThanOrEqual(detector.breathingRate, 35.0)
    }
}
