import XCTest
@testable import Echoelmusic

/// Tests for breathing rate calculation from HRV data
@MainActor
class BreathingRateCalculationTests: XCTestCase {

    var healthKitManager: HealthKitManager!

    override func setUp() async throws {
        healthKitManager = HealthKitManager()
    }

    override func tearDown() {
        healthKitManager = nil
    }

    // MARK: - Breathing Rate Calculation Tests

    func testBreathingRateCalculation_withSufficientData() {
        // Given: Simulated RR intervals with respiratory pattern
        // Simulate 6 breaths/min (0.1 Hz) pattern
        var rrIntervals: [Double] = []
        let baseInterval = 800.0 // 800ms = 75 BPM
        let amplitude = 50.0      // ±50ms variation

        for i in 0..<60 {
            let phase = Double(i) * 0.1 * 2.0 * .pi  // 0.1 Hz = 6 breaths/min
            let variation = amplitude * sin(phase)
            rrIntervals.append(baseInterval + variation)
        }

        // When: Calculate breathing rate
        let breathingRate = healthKitManager.calculateBreathingRate(rrIntervals: rrIntervals)

        // Then: Should detect ~6 breaths/min
        XCTAssertGreaterThan(breathingRate, 4.0, "Breathing rate should be above minimum")
        XCTAssertLessThan(breathingRate, 10.0, "Breathing rate should be below 10 for slow breathing pattern")
        XCTAssertEqual(breathingRate, 6.0, accuracy: 2.0, "Should detect approximately 6 breaths/min")
    }

    func testBreathingRateCalculation_withInsufficientData() {
        // Given: Too few RR intervals
        let rrIntervals = [800.0, 810.0, 790.0]

        // When: Calculate breathing rate
        let breathingRate = healthKitManager.calculateBreathingRate(rrIntervals: rrIntervals)

        // Then: Should return default value
        XCTAssertEqual(breathingRate, 6.0, "Should return default 6 breaths/min for insufficient data")
    }

    func testBreathingRateCalculation_fastBreathing() {
        // Given: Simulated fast breathing pattern (18 breaths/min = 0.3 Hz)
        var rrIntervals: [Double] = []
        let baseInterval = 800.0
        let amplitude = 40.0

        for i in 0..<60 {
            let phase = Double(i) * 0.3 * 2.0 * .pi  // 0.3 Hz = 18 breaths/min
            let variation = amplitude * sin(phase)
            rrIntervals.append(baseInterval + variation)
        }

        // When: Calculate breathing rate
        let breathingRate = healthKitManager.calculateBreathingRate(rrIntervals: rrIntervals)

        // Then: Should detect fast breathing
        XCTAssertGreaterThan(breathingRate, 10.0, "Should detect fast breathing pattern")
        XCTAssertLessThan(breathingRate, 25.0, "Should be within reasonable range")
    }

    func testBreathingRateCalculation_clamping() {
        // Given: RR intervals that might produce extreme values
        var rrIntervals: [Double] = []
        let baseInterval = 800.0

        // Create pattern that might produce very high frequency
        for i in 0..<60 {
            let phase = Double(i) * 1.0 * 2.0 * .pi  // 1 Hz = 60 breaths/min (unrealistic)
            let variation = 30.0 * sin(phase)
            rrIntervals.append(baseInterval + variation)
        }

        // When: Calculate breathing rate
        let breathingRate = healthKitManager.calculateBreathingRate(rrIntervals: rrIntervals)

        // Then: Should clamp to reasonable range
        XCTAssertGreaterThanOrEqual(breathingRate, 4.0, "Should not go below minimum")
        XCTAssertLessThanOrEqual(breathingRate, 30.0, "Should not exceed maximum")
    }

    // MARK: - Coherence Calculation Tests

    func testCoherenceCalculation_highCoherence() {
        // Given: Regular, rhythmic RR intervals (high coherence)
        var rrIntervals: [Double] = []
        let baseInterval = 900.0

        for i in 0..<60 {
            let phase = Double(i) * 0.1 * 2.0 * .pi  // 0.1 Hz sine wave
            let variation = 40.0 * sin(phase)
            rrIntervals.append(baseInterval + variation)
        }

        // When: Calculate coherence
        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Then: Should show high coherence
        XCTAssertGreaterThan(coherence, 40.0, "Regular pattern should produce higher coherence")
    }

    func testCoherenceCalculation_lowCoherence() {
        // Given: Chaotic RR intervals (low coherence)
        var rrIntervals: [Double] = []
        let baseInterval = 900.0

        for i in 0..<60 {
            // Mix multiple frequencies for chaotic pattern
            let phase1 = Double(i) * 0.05 * 2.0 * .pi
            let phase2 = Double(i) * 0.23 * 2.0 * .pi
            let phase3 = Double(i) * 0.37 * 2.0 * .pi
            let variation = 15.0 * sin(phase1) + 12.0 * sin(phase2) + 8.0 * sin(phase3)
            rrIntervals.append(baseInterval + variation)
        }

        // When: Calculate coherence
        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Then: Should show lower coherence
        XCTAssertLessThan(coherence, 60.0, "Chaotic pattern should produce lower coherence")
    }

    func testCoherenceCalculation_insufficientData() {
        // Given: Too few RR intervals
        let rrIntervals = [800.0, 810.0, 820.0]

        // When: Calculate coherence
        let coherence = healthKitManager.calculateCoherence(rrIntervals: rrIntervals)

        // Then: Should return 0
        XCTAssertEqual(coherence, 0.0, "Should return 0 for insufficient data")
    }

    // MARK: - Integration Tests

    func testHealthKitManager_initialization() {
        // When: Create HealthKitManager
        let manager = HealthKitManager()

        // Then: Should have default values
        XCTAssertEqual(manager.heartRate, 60.0)
        XCTAssertEqual(manager.hrvRMSSD, 0.0)
        XCTAssertEqual(manager.hrvCoherence, 0.0)
        XCTAssertEqual(manager.breathingRate, 6.0)
        XCTAssertFalse(manager.isAuthorized)
    }

    func testHealthKitManager_coherenceThresholds() {
        // Test coherence thresholds from AppConfiguration

        // Low coherence
        XCTAssertEqual(AppConfiguration.Biofeedback.lowCoherenceThreshold, 40.0)

        // High coherence
        XCTAssertEqual(AppConfiguration.Biofeedback.highCoherenceThreshold, 60.0)
    }

    func testHealthKitManager_breathingRateRanges() {
        // Test breathing rate ranges from AppConfiguration

        XCTAssertEqual(AppConfiguration.Biofeedback.minBreathingRate, 4.0)
        XCTAssertEqual(AppConfiguration.Biofeedback.maxBreathingRate, 30.0)
        XCTAssertEqual(AppConfiguration.Biofeedback.optimalBreathingRate, 6.0)
    }
}
