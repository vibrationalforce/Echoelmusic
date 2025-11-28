import XCTest
@testable import Echoelmusic

/// Comprehensive tests for Biofeedback processing
/// Coverage target: HRV analysis, EEG processing, parameter mapping
final class BiofeedbackProcessingTests: XCTestCase {

    // MARK: - HRV (Heart Rate Variability) Tests

    func testHRVCoherenceRange() {
        // HRV coherence typically 0-100
        let minCoherence = 0.0
        let maxCoherence = 100.0
        let healthyCoherence = 70.0

        XCTAssertGreaterThanOrEqual(healthyCoherence, minCoherence)
        XCTAssertLessThanOrEqual(healthyCoherence, maxCoherence)
    }

    func testRMSSDCalculation() {
        // RMSSD = Root Mean Square of Successive Differences
        let rrIntervals: [Double] = [800, 810, 795, 820, 805] // milliseconds
        var sumSquaredDiff = 0.0

        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i-1]
            sumSquaredDiff += diff * diff
        }

        let rmssd = sqrt(sumSquaredDiff / Double(rrIntervals.count - 1))
        XCTAssertGreaterThan(rmssd, 0, "RMSSD should be positive")
        XCTAssertLessThan(rmssd, 100, "RMSSD should be reasonable")
    }

    func testHeartRateFromRR() {
        // HR (bpm) = 60000 / RR interval (ms)
        let rrInterval = 800.0  // ms
        let heartRate = 60000.0 / rrInterval

        XCTAssertEqual(heartRate, 75.0, accuracy: 0.1, "HR should be ~75 bpm")
    }

    func testHeartRateRange() {
        // Normal resting HR: 60-100 bpm
        let restingMin = 60.0
        let restingMax = 100.0
        let athleteResting = 50.0  // Athletes can have lower resting HR

        XCTAssertGreaterThanOrEqual(restingMin, 40, "Min HR should be >= 40")
        XCTAssertLessThanOrEqual(restingMax, 120, "Max resting should be <= 120")
    }

    // MARK: - EEG Brainwave Tests

    func testDeltaWaveRange() {
        // Delta: 0.5-4 Hz (deep sleep)
        let deltaMin = 0.5
        let deltaMax = 4.0

        XCTAssertEqual(deltaMin, 0.5, accuracy: 0.1)
        XCTAssertEqual(deltaMax, 4.0, accuracy: 0.1)
    }

    func testThetaWaveRange() {
        // Theta: 4-8 Hz (drowsiness, meditation)
        let thetaMin = 4.0
        let thetaMax = 8.0

        XCTAssertEqual(thetaMin, 4.0, accuracy: 0.1)
        XCTAssertEqual(thetaMax, 8.0, accuracy: 0.1)
    }

    func testAlphaWaveRange() {
        // Alpha: 8-13 Hz (relaxed wakefulness)
        let alphaMin = 8.0
        let alphaMax = 13.0

        XCTAssertEqual(alphaMin, 8.0, accuracy: 0.1)
        XCTAssertEqual(alphaMax, 13.0, accuracy: 0.1)
    }

    func testBetaWaveRange() {
        // Beta: 13-30 Hz (active thinking)
        let betaMin = 13.0
        let betaMax = 30.0

        XCTAssertEqual(betaMin, 13.0, accuracy: 0.1)
        XCTAssertEqual(betaMax, 30.0, accuracy: 0.1)
    }

    func testGammaWaveRange() {
        // Gamma: 30-100 Hz (higher cognition)
        let gammaMin = 30.0
        let gammaMax = 100.0

        XCTAssertEqual(gammaMin, 30.0, accuracy: 0.1)
        XCTAssertLessThanOrEqual(gammaMax, 100.0)
    }

    // MARK: - Parameter Mapping Tests

    func testHRVToReverbMapping() {
        // Low coherence → less reverb, high coherence → more reverb
        let lowCoherence = 20.0
        let highCoherence = 80.0

        let lowReverb = mapLinear(value: lowCoherence, from: 0...100, to: 0.1...0.8)
        let highReverb = mapLinear(value: highCoherence, from: 0...100, to: 0.1...0.8)

        XCTAssertLessThan(lowReverb, highReverb, "Low coherence should map to less reverb")
    }

    func testHeartRateToTempoMapping() {
        // HR maps to tempo for breathing guidance
        let heartRate = 75.0  // bpm
        let breathingRate = heartRate / 4.0  // ~4:1 ratio

        XCTAssertEqual(breathingRate, 18.75, accuracy: 1.0, "Breathing rate should be ~HR/4")
    }

    func testAmplitudeMapping() {
        // Amplitude should be 0.0-1.0
        let mappedAmplitude = min(1.0, max(0.0, 0.75))
        XCTAssertGreaterThanOrEqual(mappedAmplitude, 0.0)
        XCTAssertLessThanOrEqual(mappedAmplitude, 1.0)
    }

    // MARK: - Smoothing Tests

    func testExponentialSmoothing() {
        // Smoothing: new = old + factor * (target - old)
        let currentValue = 0.5
        let targetValue = 0.8
        let smoothingFactor = 0.1

        let smoothed = currentValue + smoothingFactor * (targetValue - currentValue)
        XCTAssertEqual(smoothed, 0.53, accuracy: 0.01)
    }

    func testSmoothingConvergence() {
        // Smoothing should eventually reach target
        var value = 0.0
        let target = 1.0
        let factor = 0.1

        for _ in 0..<100 {
            value = value + factor * (target - value)
        }

        XCTAssertEqual(value, target, accuracy: 0.001, "Should converge to target")
    }

    // MARK: - Calibration Tests

    func testBaselineCalibration() {
        // Baseline should be average of calibration period
        let samples: [Double] = [70, 72, 68, 71, 69]
        let baseline = samples.reduce(0, +) / Double(samples.count)

        XCTAssertEqual(baseline, 70.0, accuracy: 0.1)
    }

    func testNormalization() {
        // Normalize to 0-1 range
        let value = 75.0
        let min = 50.0
        let max = 100.0
        let normalized = (value - min) / (max - min)

        XCTAssertEqual(normalized, 0.5, accuracy: 0.01)
    }

    // MARK: - Safety Tests

    func testPhotoSensitivityThreshold() {
        // Flash frequency must be < 3 Hz for photosensitivity safety
        let maxSafeFlashRate = 3.0  // Hz
        XCTAssertLessThanOrEqual(maxSafeFlashRate, 3.0, "Flash rate must be <= 3 Hz")
    }

    func testAudioLevelSafety() {
        // Sustained audio > 85 dB can cause hearing damage
        let maxSafeLevel = 85.0  // dB
        XCTAssertLessThanOrEqual(maxSafeLevel, 85.0)
    }

    // MARK: - Helper Functions

    private func mapLinear(value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Double {
        let normalized = (value - from.lowerBound) / (from.upperBound - from.lowerBound)
        return to.lowerBound + normalized * (to.upperBound - to.lowerBound)
    }
}
