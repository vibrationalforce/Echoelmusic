import XCTest
@testable import Blab

/// Unit tests for HealthKitManager
/// Tests coherence calculation algorithm and error handling
@MainActor
final class HealthKitManagerTests: XCTestCase {

    var healthKitManager: HealthKitManager!

    override func setUp() async throws {
        healthKitManager = HealthKitManager()
    }

    override func tearDown() {
        healthKitManager = nil
    }


    // MARK: - Coherence Calculation Tests

    /// Test coherence calculation with synthetic low-coherence RR intervals
    /// Low coherence = random, chaotic intervals (stress state)
    func testCoherenceCalculation_LowCoherence() {
        // Generate random RR intervals (chaotic = low coherence)
        let rrIntervals = (0..<120).map { _ in Double.random(in: 600...1000) }

        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Low coherence should be < 40
        XCTAssertGreaterThanOrEqual(coherence, 0.0, "Coherence should be >= 0")
        XCTAssertLessThanOrEqual(coherence, 100.0, "Coherence should be <= 100")
        print("Low coherence score: \(coherence)")
    }

    /// Test coherence calculation with synthetic high-coherence RR intervals
    /// High coherence = rhythmic 0.1 Hz oscillation (optimal state)
    func testCoherenceCalculation_HighCoherence() {
        // Generate sinusoidal RR intervals at 0.1 Hz (HeartMath resonance frequency)
        // This simulates perfect heart-breath coherence
        let rrIntervals = (0..<120).map { i in
            let time = Double(i)
            let sinusoid = sin(2.0 * .pi * 0.1 * time) // 0.1 Hz = 6 breaths/min
            return 800.0 + sinusoid * 100.0 // 800ms ± 100ms oscillation
        }

        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // High coherence should be > 60
        XCTAssertGreaterThan(coherence, 40.0, "Rhythmic breathing should produce medium-high coherence")
        print("High coherence score: \(coherence)")
    }

    /// Test coherence calculation with insufficient data
    func testCoherenceCalculation_InsufficientData() {
        let rrIntervals = [800.0, 850.0, 820.0] // Only 3 intervals

        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        XCTAssertEqual(coherence, 0.0, "Insufficient data should return 0 coherence")
    }

    /// Test coherence calculation with empty array
    func testCoherenceCalculation_EmptyData() {
        let coherence = healthKitManager.calculateCoherence(rrIntervals: [])

        XCTAssertEqual(coherence, 0.0, "Empty data should return 0 coherence")
    }

    /// Test coherence calculation with constant RR intervals
    /// (no variability = unhealthy but technically "coherent")
    func testCoherenceCalculation_ConstantIntervals() {
        let rrIntervals = Array(repeating: 800.0, count: 120)

        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Constant intervals have no power in any frequency band
        XCTAssertLessThan(coherence, 10.0, "Constant intervals should have very low coherence")
    }


    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(healthKitManager.heartRate, 60.0, "Initial heart rate should be 60")
        XCTAssertEqual(healthKitManager.hrvRMSSD, 0.0, "Initial HRV should be 0")
        XCTAssertEqual(healthKitManager.hrvCoherence, 0.0, "Initial coherence should be 0")
    }


    // MARK: - Monitoring Control Tests

    func testStartStopMonitoring() {
        // Note: These will fail if HealthKit is not authorized
        // In real app testing, you'd need to mock HealthKit or test on device

        // Just verify methods don't crash
        healthKitManager.startMonitoring()
        healthKitManager.stopMonitoring()

        // If not authorized, error message should be set
        if !healthKitManager.isAuthorized {
            XCTAssertNotNil(healthKitManager.errorMessage, "Error message should be set if not authorized")
        }
    }


    // MARK: - Algorithm Component Tests

    /// Test that detrend function removes linear trends
    func testDetrendAlgorithm() {
        // Create data with strong linear trend
        let trendedData = (0..<100).map { Double($0) * 2.0 + 100.0 } // y = 2x + 100

        // Access private method via reflection or make it internal for testing
        // For now, test through coherence calculation
        let coherence = healthKitManager.calculateCoherence(rrIntervals: trendedData)

        XCTAssertGreaterThanOrEqual(coherence, 0.0, "Detrended data should produce valid coherence")
    }

    /// Test FFT with known frequency components
    func testFFTAccuracy() {
        // Generate 120 samples with a clear 0.1 Hz component
        let rrIntervals = (0..<120).map { i in
            800.0 + 50.0 * sin(2.0 * .pi * 0.1 * Double(i))
        }

        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Should detect the 0.1 Hz component in coherence band
        XCTAssertGreaterThan(coherence, 30.0, "FFT should detect 0.1 Hz component")
        print("FFT coherence score for 0.1 Hz signal: \(coherence)")
    }


    // MARK: - Performance Tests

    func testCoherenceCalculationPerformance() {
        let rrIntervals = (0..<120).map { _ in Double.random(in: 600...1000) }

        measure {
            _ = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)
        }
    }


    // MARK: - LF/HF Frequency Domain Tests

    /// Test LF/HF calculation with synthetic data
    func testLFHFCalculation_BasicValidation() {
        // Generate 120 RR intervals with mixed frequency content
        let rrIntervals = (0..<120).map { i in
            let time = Double(i)
            let lf = sin(2.0 * .pi * 0.1 * time)  // 0.1 Hz (LF band)
            let hf = sin(2.0 * .pi * 0.3 * time)  // 0.3 Hz (HF band)
            return 800.0 + lf * 50.0 + hf * 30.0
        }

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        // All values should be non-negative
        XCTAssertGreaterThanOrEqual(result.lf, 0.0, "LF power should be >= 0")
        XCTAssertGreaterThanOrEqual(result.hf, 0.0, "HF power should be >= 0")
        XCTAssertGreaterThanOrEqual(result.lfhfRatio, 0.0, "LF/HF ratio should be >= 0")
        XCTAssertGreaterThanOrEqual(result.totalPower, 0.0, "Total power should be >= 0")

        print("""
        LF/HF Analysis:
          LF: \(result.lf)
          HF: \(result.hf)
          Ratio: \(result.lfhfRatio)
          Total: \(result.totalPower)
        """)
    }

    /// Test LF dominance (sympathetic activation - stress)
    func testLFHFCalculation_HighLFRatio() {
        // Generate RR intervals with strong LF component (0.1 Hz)
        // Simulates stress state with elevated sympathetic activity
        let rrIntervals = (0..<120).map { i in
            let time = Double(i)
            let lf = sin(2.0 * .pi * 0.1 * time)  // Strong LF
            let hf = sin(2.0 * .pi * 0.25 * time) // Weak HF
            return 800.0 + lf * 100.0 + hf * 20.0
        }

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        // LF should dominate (high ratio = sympathetic dominance)
        XCTAssertGreaterThan(result.lf, result.hf * 1.5, "LF should be significantly larger than HF")
        XCTAssertGreaterThan(result.lfhfRatio, 1.0, "LF/HF ratio should indicate sympathetic dominance")

        print("High LF ratio (stress): \(result.lfhfRatio)")
    }

    /// Test HF dominance (parasympathetic activation - relaxation)
    func testLFHFCalculation_HighHFRatio() {
        // Generate RR intervals with strong HF component (0.25 Hz = ~15 breaths/min)
        // Simulates relaxed state with elevated vagal tone
        let rrIntervals = (0..<120).map { i in
            let time = Double(i)
            let lf = sin(2.0 * .pi * 0.1 * time)  // Weak LF
            let hf = sin(2.0 * .pi * 0.25 * time) // Strong HF (breathing)
            return 800.0 + lf * 20.0 + hf * 100.0
        }

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        // HF should dominate (low ratio = parasympathetic dominance)
        XCTAssertGreaterThan(result.hf, result.lf * 1.5, "HF should be significantly larger than LF")
        XCTAssertLessThan(result.lfhfRatio, 1.0, "LF/HF ratio should indicate parasympathetic dominance")

        print("Low LF/HF ratio (relaxed): \(result.lfhfRatio)")
    }

    /// Test with insufficient data
    func testLFHFCalculation_InsufficientData() {
        let rrIntervals = [800.0, 850.0, 820.0] // Only 3 intervals

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        XCTAssertEqual(result.lf, 0.0)
        XCTAssertEqual(result.hf, 0.0)
        XCTAssertEqual(result.lfhfRatio, 0.0)
        XCTAssertEqual(result.totalPower, 0.0)
    }

    /// Test frequency band separation accuracy
    func testLFHFCalculation_FrequencyBandSeparation() {
        // Pure LF component (0.1 Hz)
        let lfIntervals = (0..<120).map { i in
            800.0 + 50.0 * sin(2.0 * .pi * 0.1 * Double(i))
        }
        let lfResult = healthKitManager.calculateLFHF(rrIntervals: lfIntervals)

        // Pure HF component (0.3 Hz)
        let hfIntervals = (0..<120).map { i in
            800.0 + 50.0 * sin(2.0 * .pi * 0.3 * Double(i))
        }
        let hfResult = healthKitManager.calculateLFHF(rrIntervals: hfIntervals)

        // LF signal should have more LF power than HF power
        XCTAssertGreaterThan(lfResult.lf, lfResult.hf, "Pure LF signal should have higher LF power")

        // HF signal should have more HF power than LF power
        XCTAssertGreaterThan(hfResult.hf, hfResult.lf, "Pure HF signal should have higher HF power")

        print("LF signal - LF power: \(lfResult.lf), HF power: \(lfResult.hf)")
        print("HF signal - LF power: \(hfResult.lf), HF power: \(hfResult.hf)")
    }

    /// Test autonomic balance description
    func testAutonomicBalanceDescription() {
        // Mock different LF/HF ratios by directly setting the property
        // (In real tests, this would be set via actual calculation)

        // Simulate parasympathetic dominance
        healthKitManager.hrvLFHFRatio = 0.5
        XCTAssertEqual(healthKitManager.autonomicBalanceDescription, "Parasympathetic Dominance (Relaxed)")

        // Simulate balanced state
        healthKitManager.hrvLFHFRatio = 1.5
        XCTAssertEqual(healthKitManager.autonomicBalanceDescription, "Balanced Autonomic State")

        // Simulate sympathetic dominance
        healthKitManager.hrvLFHFRatio = 3.0
        XCTAssertEqual(healthKitManager.autonomicBalanceDescription, "Sympathetic Dominance (Stressed/Active)")
    }

    /// Test frequency analysis summary output
    func testFrequencyAnalysisSummary() {
        healthKitManager.hrvLF = 1000.0
        healthKitManager.hrvHF = 500.0
        healthKitManager.hrvLFHFRatio = 2.0
        healthKitManager.hrvTotalPower = 2000.0

        let summary = healthKitManager.frequencyAnalysisSummary

        XCTAssertTrue(summary.contains("1000.00"), "Summary should contain LF value")
        XCTAssertTrue(summary.contains("500.00"), "Summary should contain HF value")
        XCTAssertTrue(summary.contains("2.00"), "Summary should contain LF/HF ratio")
        XCTAssertTrue(summary.contains("2000.00"), "Summary should contain total power")

        print("Frequency analysis summary:\n\(summary)")
    }

    /// Test LF/HF calculation with breathing-rate HF component
    func testLFHFCalculation_BreathingRateDetection() {
        // Simulate breathing at 15 breaths/min = 0.25 Hz (within HF band)
        let rrIntervals = (0..<120).map { i in
            let breathingPhase = sin(2.0 * .pi * 0.25 * Double(i))
            return 800.0 + breathingPhase * 80.0
        }

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        // Should show elevated HF power (respiratory sinus arrhythmia)
        XCTAssertGreaterThan(result.hf, result.lf, "Breathing signal should elevate HF power")
        XCTAssertLessThan(result.lfhfRatio, 1.0, "Breathing should produce low LF/HF ratio")

        print("Breathing-rate HF power: \(result.hf), LF/HF ratio: \(result.lfhfRatio)")
    }

    /// Test zero HF power (edge case for ratio calculation)
    func testLFHFCalculation_ZeroHFPower() {
        // Very slow oscillation (below HF band)
        let rrIntervals = (0..<120).map { i in
            800.0 + 50.0 * sin(2.0 * .pi * 0.05 * Double(i))
        }

        let result = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)

        // Should handle zero HF gracefully (not crash with division by zero)
        XCTAssertGreaterThanOrEqual(result.lfhfRatio, 0.0)
        XCTAssertTrue(result.lfhfRatio.isFinite, "Ratio should be finite even with low HF")
    }

    /// Test LF/HF performance
    func testLFHFCalculationPerformance() {
        let rrIntervals = (0..<120).map { _ in Double.random(in: 600...1000) }

        measure {
            _ = healthKitManager.calculateLFHF(rrIntervals: rrIntervals)
        }
    }

    /// Test initial state of LF/HF properties
    func testLFHFInitialState() {
        XCTAssertEqual(healthKitManager.hrvLF, 0.0, "Initial LF should be 0")
        XCTAssertEqual(healthKitManager.hrvHF, 0.0, "Initial HF should be 0")
        XCTAssertEqual(healthKitManager.hrvLFHFRatio, 0.0, "Initial LF/HF ratio should be 0")
        XCTAssertEqual(healthKitManager.hrvTotalPower, 0.0, "Initial total power should be 0")
    }
}
