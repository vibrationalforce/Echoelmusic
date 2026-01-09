// GazeTrackerIntegrationTests.swift
// Echoelmusic - Phase λ∞ Ralph Wiggum Loop Tests
//
// Tests for GazeTracker integration with UnifiedControlHub
// and audio-visual control mapping
//
// Created 2026-01-07

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for GazeTracker integration
@available(iOS 15.0, macOS 12.0, *)
final class GazeTrackerIntegrationTests: XCTestCase {

    // MARK: - GazeData Tests

    func testGazeDataInitialization() {
        let gazeData = GazeData()

        XCTAssertEqual(gazeData.gazePoint.x, 0.5)
        XCTAssertEqual(gazeData.gazePoint.y, 0.5)
        XCTAssertEqual(gazeData.leftEyeOpenness, 1.0)
        XCTAssertEqual(gazeData.rightEyeOpenness, 1.0)
        XCTAssertFalse(gazeData.isBlinking)
        XCTAssertFalse(gazeData.isFixating)
    }

    func testGazeDataAverageOpenness() {
        var gazeData = GazeData()
        gazeData.leftEyeOpenness = 0.8
        gazeData.rightEyeOpenness = 0.6

        XCTAssertEqual(gazeData.averageOpenness, 0.7, accuracy: 0.01)
    }

    func testGazeDataAveragePupilDilation() {
        var gazeData = GazeData()
        gazeData.leftPupilDilation = 0.4
        gazeData.rightPupilDilation = 0.6

        XCTAssertEqual(gazeData.averagePupilDilation, 0.5, accuracy: 0.01)
    }

    func testGazeDataAttentionLevel() {
        var gazeData = GazeData()
        gazeData.isFixating = true
        gazeData.leftPupilDilation = 0.5
        gazeData.rightPupilDilation = 0.5

        // Attention = fixation(1.0) * 0.6 + dilation(0.5) * 0.4 = 0.8
        XCTAssertEqual(gazeData.attentionLevel, 0.8, accuracy: 0.01)
    }

    func testGazeDataAttentionLevelNotFixating() {
        var gazeData = GazeData()
        gazeData.isFixating = false
        gazeData.leftPupilDilation = 0.5
        gazeData.rightPupilDilation = 0.5

        // Attention = fixation(0.5) * 0.6 + dilation(0.5) * 0.4 = 0.5
        XCTAssertEqual(gazeData.attentionLevel, 0.5, accuracy: 0.01)
    }

    // MARK: - GazeZone Tests

    func testGazeZoneFromPointCenter() {
        let point = SIMD2<Float>(0.5, 0.5)
        let zone = GazeZone.from(point: point)

        XCTAssertEqual(zone, .center)
    }

    func testGazeZoneFromPointTopLeft() {
        let point = SIMD2<Float>(0.1, 0.1)
        let zone = GazeZone.from(point: point)

        XCTAssertEqual(zone, .topLeft)
    }

    func testGazeZoneFromPointBottomRight() {
        let point = SIMD2<Float>(0.9, 0.9)
        let zone = GazeZone.from(point: point)

        XCTAssertEqual(zone, .bottomRight)
    }

    func testAllGazeZonesHaveDisplayNames() {
        for zone in GazeZone.allCases {
            XCTAssertFalse(zone.displayName.isEmpty)
            XCTAssertFalse(zone.displayName.contains("_"))
        }
    }

    func testGazeZoneIdentifiable() {
        for zone in GazeZone.allCases {
            XCTAssertEqual(zone.id, zone.rawValue)
        }
    }

    // MARK: - GazeGesture Tests

    func testAllGazeGesturesHaveDisplayNames() {
        for gesture in GazeGesture.allCases {
            XCTAssertFalse(gesture.displayName.isEmpty)
            XCTAssertFalse(gesture.displayName.contains("_"))
        }
    }

    func testGazeGestureCount() {
        // Should have 11 gesture types
        XCTAssertEqual(GazeGesture.allCases.count, 11)
    }

    // MARK: - GazeControlParameters Tests

    func testGazeControlParametersAudioPan() {
        let params = GazeControlParameters(
            gazeX: 0.0,
            gazeY: 0.5,
            attention: 0.5,
            focus: 0.5,
            stability: 0.5,
            arousal: 0.5,
            zone: .centerLeft,
            isFixating: false,
            isBlinking: false
        )

        // Pan = (0.0 - 0.5) * 2.0 = -1.0 (full left)
        XCTAssertEqual(params.audioPan, -1.0, accuracy: 0.01)
    }

    func testGazeControlParametersAudioPanRight() {
        let params = GazeControlParameters(
            gazeX: 1.0,
            gazeY: 0.5,
            attention: 0.5,
            focus: 0.5,
            stability: 0.5,
            arousal: 0.5,
            zone: .centerRight,
            isFixating: false,
            isBlinking: false
        )

        // Pan = (1.0 - 0.5) * 2.0 = 1.0 (full right)
        XCTAssertEqual(params.audioPan, 1.0, accuracy: 0.01)
    }

    func testGazeControlParametersFilterCutoff() {
        let params = GazeControlParameters(
            gazeX: 0.5,
            gazeY: 0.5,
            attention: 0.8,
            focus: 0.6,
            stability: 0.5,
            arousal: 0.5,
            zone: .center,
            isFixating: true,
            isBlinking: false
        )

        // FilterCutoff = attention * stability = 0.8 * 0.5 = 0.4
        XCTAssertEqual(params.filterCutoff, 0.4, accuracy: 0.01)
    }

    func testGazeControlParametersReverbAmount() {
        let params = GazeControlParameters(
            gazeX: 0.5,
            gazeY: 0.5,
            attention: 0.5,
            focus: 0.7,
            stability: 0.5,
            arousal: 0.5,
            zone: .center,
            isFixating: true,
            isBlinking: false
        )

        // ReverbAmount = 1.0 - focus = 1.0 - 0.7 = 0.3
        XCTAssertEqual(params.reverbAmount, 0.3, accuracy: 0.01)
    }

    func testGazeControlParametersVisualIntensity() {
        let params = GazeControlParameters(
            gazeX: 0.5,
            gazeY: 0.5,
            attention: 0.8,
            focus: 0.5,
            stability: 0.5,
            arousal: 0.6,
            zone: .center,
            isFixating: true,
            isBlinking: false
        )

        // VisualIntensity = (attention + arousal) / 2.0 = (0.8 + 0.6) / 2.0 = 0.7
        XCTAssertEqual(params.visualIntensity, 0.7, accuracy: 0.01)
    }

    // MARK: - GazeTracker Tests

    func testGazeTrackerInitialization() {
        let tracker = GazeTracker()

        XCTAssertFalse(tracker.isTracking)
        XCTAssertEqual(tracker.currentZone, .center)
        XCTAssertTrue(tracker.recentGestures.isEmpty)
        XCTAssertFalse(tracker.isCalibrated)
    }

    func testGazeTrackerDefaultMetrics() {
        let tracker = GazeTracker()

        XCTAssertEqual(tracker.attentionLevel, 0.5)
        XCTAssertEqual(tracker.focusIntensity, 0.5)
        XCTAssertEqual(tracker.gazeStability, 0.5)
        XCTAssertEqual(tracker.arousalLevel, 0.5)
    }

    func testGazeTrackerStartStop() {
        let tracker = GazeTracker()

        tracker.startTracking()
        XCTAssertTrue(tracker.isTracking)

        tracker.stopTracking()
        XCTAssertFalse(tracker.isTracking)
    }

    func testGazeTrackerCalibration() {
        let tracker = GazeTracker()

        XCTAssertFalse(tracker.isCalibrated)
        XCTAssertEqual(tracker.calibrationProgress, 0.0)

        tracker.startCalibration()

        // Calibration is simulated, so it should start
        // In real implementation, this would require user interaction
    }

    func testGazeTrackerGetControlParameters() {
        let tracker = GazeTracker()
        let params = tracker.getControlParameters()

        XCTAssertEqual(params.gazeX, 0.5, accuracy: 0.01)
        XCTAssertEqual(params.gazeY, 0.5, accuracy: 0.01)
        XCTAssertEqual(params.zone, .center)
    }

    // MARK: - Zone Mapping Tests

    func testAllNineZonesCovered() {
        // Test all 9 zones are reachable
        let testPoints: [(SIMD2<Float>, GazeZone)] = [
            (SIMD2(0.1, 0.1), .topLeft),
            (SIMD2(0.5, 0.1), .topCenter),
            (SIMD2(0.9, 0.1), .topRight),
            (SIMD2(0.1, 0.5), .centerLeft),
            (SIMD2(0.5, 0.5), .center),
            (SIMD2(0.9, 0.5), .centerRight),
            (SIMD2(0.1, 0.9), .bottomLeft),
            (SIMD2(0.5, 0.9), .bottomCenter),
            (SIMD2(0.9, 0.9), .bottomRight),
        ]

        for (point, expectedZone) in testPoints {
            let zone = GazeZone.from(point: point)
            XCTAssertEqual(zone, expectedZone, "Point \(point) should map to \(expectedZone)")
        }
    }

    // MARK: - Edge Case Tests

    func testGazePointAtBoundaries() {
        // Test boundary conditions
        XCTAssertEqual(GazeZone.from(point: SIMD2(0.0, 0.0)), .topLeft)
        XCTAssertEqual(GazeZone.from(point: SIMD2(1.0, 1.0)), .bottomRight)
        XCTAssertEqual(GazeZone.from(point: SIMD2(0.33, 0.33)), .center)
        XCTAssertEqual(GazeZone.from(point: SIMD2(0.66, 0.66)), .bottomRight)
    }

    func testGazeDataEquatable() {
        let data1 = GazeData()
        let data2 = GazeData()

        XCTAssertEqual(data1.gazePoint.x, data2.gazePoint.x)
        XCTAssertEqual(data1.leftEyeOpenness, data2.leftEyeOpenness)
    }

    func testGazeDataSendable() {
        // Compile-time check that GazeData is Sendable
        let data = GazeData()
        Task {
            let _ = data
        }
    }

    // MARK: - Performance Tests

    func testGazeZoneFromPointPerformance() {
        measure {
            for _ in 0..<10000 {
                let x = Float.random(in: 0...1)
                let y = Float.random(in: 0...1)
                _ = GazeZone.from(point: SIMD2(x, y))
            }
        }
    }

    func testGazeControlParametersCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = GazeControlParameters(
                    gazeX: Float.random(in: 0...1),
                    gazeY: Float.random(in: 0...1),
                    attention: Float.random(in: 0...1),
                    focus: Float.random(in: 0...1),
                    stability: Float.random(in: 0...1),
                    arousal: Float.random(in: 0...1),
                    zone: GazeZone.allCases.randomElement()!,
                    isFixating: Bool.random(),
                    isBlinking: Bool.random()
                )
            }
        }
    }

    // MARK: - Audio Mapping Tests

    func testGazeToAudioPanFullRange() {
        // Test pan ranges from -1 to +1
        for x in stride(from: Float(0), through: 1.0, by: 0.1) {
            let params = GazeControlParameters(
                gazeX: x,
                gazeY: 0.5,
                attention: 0.5,
                focus: 0.5,
                stability: 0.5,
                arousal: 0.5,
                zone: .center,
                isFixating: false,
                isBlinking: false
            )

            XCTAssertGreaterThanOrEqual(params.audioPan, -1.0)
            XCTAssertLessThanOrEqual(params.audioPan, 1.0)
        }
    }

    func testFilterCutoffRange() {
        // Test filter cutoff stays in valid range
        for attention in stride(from: Float(0), through: 1.0, by: 0.1) {
            for stability in stride(from: Float(0), through: 1.0, by: 0.1) {
                let params = GazeControlParameters(
                    gazeX: 0.5,
                    gazeY: 0.5,
                    attention: attention,
                    focus: 0.5,
                    stability: stability,
                    arousal: 0.5,
                    zone: .center,
                    isFixating: false,
                    isBlinking: false
                )

                XCTAssertGreaterThanOrEqual(params.filterCutoff, 0.0)
                XCTAssertLessThanOrEqual(params.filterCutoff, 1.0)
            }
        }
    }
}

// MARK: - Mock Gaze Tracker Delegate

@available(iOS 15.0, macOS 12.0, *)
class MockGazeTrackerDelegate: GazeTrackerDelegate {
    var lastGazeData: GazeData?
    var lastGesture: GazeGesture?
    var enteredZones: [GazeZone] = []
    var exitedZones: [GazeZone] = []
    var lostTrackingCount = 0

    func gazeTracker(_ tracker: GazeTracker, didUpdateGaze data: GazeData) {
        lastGazeData = data
    }

    func gazeTracker(_ tracker: GazeTracker, didDetectGesture gesture: GazeGesture) {
        lastGesture = gesture
    }

    func gazeTracker(_ tracker: GazeTracker, didEnterZone zone: GazeZone) {
        enteredZones.append(zone)
    }

    func gazeTracker(_ tracker: GazeTracker, didExitZone zone: GazeZone) {
        exitedZones.append(zone)
    }

    func gazeTrackerDidLoseTracking(_ tracker: GazeTracker) {
        lostTrackingCount += 1
    }
}
