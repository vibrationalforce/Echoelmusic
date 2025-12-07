import XCTest
@testable import Echoelmusic

// MARK: - Autopilot System Tests

final class AutopilotSystemTests: XCTestCase {

    // MARK: - AutopilotMode Tests

    func testAutopilotModesHaveValidTargetStates() {
        for mode in AutopilotMode.allCases {
            // Jeder Modus sollte einen gültigen Zielzustand haben
            XCTAssertNotNil(mode.targetState)
            XCTAssertFalse(mode.displayName.isEmpty, "Mode \(mode) has empty display name")
        }
    }

    func testAutopilotModeBrainwaveRanges() {
        // Wissenschaftlich korrekte Brainwave-Bereiche prüfen

        // Delta: 0.5-4 Hz (Schlaf)
        XCTAssertEqual(AutopilotMode.sleep.targetBrainwaveRange.lowerBound, 0.5)
        XCTAssertEqual(AutopilotMode.sleep.targetBrainwaveRange.upperBound, 4.0)

        // Theta: 4-8 Hz (Meditation)
        XCTAssertEqual(AutopilotMode.meditation.targetBrainwaveRange.lowerBound, 4.0)
        XCTAssertEqual(AutopilotMode.meditation.targetBrainwaveRange.upperBound, 8.0)

        // Beta: 15-25 Hz (Focus)
        XCTAssertTrue(AutopilotMode.focus.targetBrainwaveRange.contains(15.0))
        XCTAssertTrue(AutopilotMode.focus.targetBrainwaveRange.contains(20.0))
    }

    func testEvidenceLevelsAssigned() {
        // Kritische Modi sollten peer-reviewed sein
        XCTAssertEqual(AutopilotMode.meditation.evidenceLevel, .peerReviewed)
        XCTAssertEqual(AutopilotMode.focus.evidenceLevel, .peerReviewed)
        XCTAssertEqual(AutopilotMode.sleep.evidenceLevel, .peerReviewed)

        // Experimentelle Modi sollten anekdotisch sein
        XCTAssertEqual(AutopilotMode.creativity.evidenceLevel, .anecdotal)
    }

    // MARK: - UserPhysiologicalState Tests

    func testStateDistanceCalculation() {
        // Gleiche Zustände = Distanz 0
        XCTAssertEqual(UserPhysiologicalState.relaxed.distance(to: .relaxed), 0.0)

        // Gegensätzliche Zustände = hohe Distanz
        let stressToRelax = UserPhysiologicalState.stressed.distance(to: .relaxed)
        XCTAssertGreaterThan(stressToRelax, 0.5)

        // Ähnliche Zustände = niedrige Distanz
        let relaxToDeep = UserPhysiologicalState.relaxed.distance(to: .deepRelaxation)
        XCTAssertLessThan(relaxToDeep, 0.3)
    }

    func testArousalLevels() {
        // Müde sollte niedriges Arousal haben
        XCTAssertLessThan(UserPhysiologicalState.drowsy.arousalLevel, 0.3)

        // Energetisiert sollte hohes Arousal haben
        XCTAssertGreaterThan(UserPhysiologicalState.energized.arousalLevel, 0.7)

        // Neutral sollte mittleres Arousal haben
        XCTAssertEqual(UserPhysiologicalState.neutral.arousalLevel, 0.5)
    }

    func testValenceLevels() {
        // Stress sollte negative Valenz haben
        XCTAssertLessThan(UserPhysiologicalState.stressed.valenceLevel, 0.3)

        // Tiefe Entspannung sollte positive Valenz haben
        XCTAssertGreaterThan(UserPhysiologicalState.deepRelaxation.valenceLevel, 0.7)
    }

    // MARK: - Safety Thresholds Tests

    func testSafetyThresholdsPhysiologicallyValid() {
        let thresholds = SafetyThresholds()

        // Herzfrequenz-Grenzen müssen physiologisch sinnvoll sein
        XCTAssertGreaterThanOrEqual(thresholds.maxHeartRate, 120, "Max HR too low for exercise")
        XCTAssertLessThanOrEqual(thresholds.maxHeartRate, 220, "Max HR unrealistically high")

        XCTAssertGreaterThanOrEqual(thresholds.minHeartRate, 30, "Min HR too low")
        XCTAssertLessThanOrEqual(thresholds.minHeartRate, 60, "Min HR too high for athletes")

        // Frequenzgrenzen für Audio-Sicherheit
        XCTAssertGreaterThanOrEqual(thresholds.minFrequency, 0.1, "Sub-Hz dangerous")
        XCTAssertLessThanOrEqual(thresholds.maxFrequency, 22000, "Above hearing range")

        // Sitzungsdauer sinnvoll
        XCTAssertGreaterThanOrEqual(thresholds.maxSessionDuration, 1800, "Session too short")
        XCTAssertLessThanOrEqual(thresholds.maxSessionDuration, 14400, "4+ hour sessions unsafe")
    }

    // MARK: - BiometricDataPoint Tests

    func testBiometricDataPointCodable() throws {
        let data = BiometricDataPoint(
            timestamp: Date(),
            heartRate: 72.0,
            hrv: 45.0,
            respirationRate: 14.0,
            coherence: 0.65
        )

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BiometricDataPoint.self, from: encoded)

        XCTAssertEqual(decoded.heartRate, 72.0)
        XCTAssertEqual(decoded.hrv, 45.0)
        XCTAssertEqual(decoded.respirationRate, 14.0)
        XCTAssertEqual(decoded.coherence, 0.65)
    }

    // MARK: - Configuration Tests

    func testConfigurationPresets() {
        let defaultConfig = AutopilotConfiguration.default
        let conservativeConfig = AutopilotConfiguration.conservative
        let responsiveConfig = AutopilotConfiguration.responsive

        // Conservative sollte weniger aggressiv sein
        XCTAssertLessThan(conservativeConfig.decisionAggressiveness, defaultConfig.decisionAggressiveness)

        // Responsive sollte aggressiver sein
        XCTAssertGreaterThan(responsiveConfig.decisionAggressiveness, defaultConfig.decisionAggressiveness)

        // Alle sollten gültige Werte haben
        XCTAssertTrue((0...1).contains(defaultConfig.stateSensitivity))
        XCTAssertTrue((0...1).contains(defaultConfig.parameterSmoothing))
    }
}

// MARK: - State Analyzer Tests

final class StateAnalyzerTests: XCTestCase {

    func testRingBufferBasicOperations() {
        let buffer = RingBuffer<Double>(capacity: 5)

        // Append und get
        buffer.append(1.0)
        buffer.append(2.0)
        buffer.append(3.0)

        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.last, 3.0)

        // lastN
        let lastTwo = buffer.lastN(2)
        XCTAssertEqual(lastTwo, [2.0, 3.0])
    }

    func testRingBufferOverflow() {
        let buffer = RingBuffer<Double>(capacity: 3)

        buffer.append(1.0)
        buffer.append(2.0)
        buffer.append(3.0)
        buffer.append(4.0)  // Sollte 1.0 überschreiben

        XCTAssertEqual(buffer.count, 3)
        XCTAssertEqual(buffer.last, 4.0)

        let all = buffer.all
        XCTAssertTrue(all.contains(2.0))
        XCTAssertTrue(all.contains(3.0))
        XCTAssertTrue(all.contains(4.0))
    }

    func testRingBufferStatistics() {
        let buffer = RingBuffer<Double>(capacity: 10)

        // Bekannte Werte für einfache Berechnung
        buffer.append(10.0)
        buffer.append(20.0)
        buffer.append(30.0)

        XCTAssertEqual(buffer.average, 20.0)

        // SD von [10, 20, 30] = ~8.16
        if let sd = buffer.standardDeviation {
            XCTAssertGreaterThan(sd, 8.0)
            XCTAssertLessThan(sd, 11.0)
        }
    }

    func testTrendDirection() {
        XCTAssertEqual(Trend.increasing.symbol, "↑")
        XCTAssertEqual(Trend.stable.symbol, "→")
        XCTAssertEqual(Trend.decreasing.symbol, "↓")
    }

    func testBiometricBaselineValidity() {
        let recentBaseline = BiometricBaseline(
            meanHR: 70.0,
            sdHR: 5.0,
            meanHRV: 50.0,
            sdHRV: 15.0,
            timestamp: Date()
        )

        XCTAssertTrue(recentBaseline.isRecent)
        XCTAssertLessThan(recentBaseline.ageInHours, 1.0)

        let oldBaseline = BiometricBaseline(
            meanHR: 70.0,
            sdHR: 5.0,
            meanHRV: 50.0,
            sdHRV: 15.0,
            timestamp: Date().addingTimeInterval(-86400 * 2)  // 2 days ago
        )

        XCTAssertFalse(oldBaseline.isRecent)
    }
}

// MARK: - Decision Engine Tests

final class DecisionEngineTests: XCTestCase {

    func testFeedbackDataValidation() {
        let effective = FeedbackData(
            wasEffective: true,
            effectivenessScore: 0.8,
            convergenceRate: 0.6
        )

        XCTAssertTrue(effective.wasEffective)
        XCTAssertGreaterThan(effective.effectivenessScore, 0.5)

        let ineffective = FeedbackData(
            wasEffective: false,
            effectivenessScore: 0.2,
            convergenceRate: 0.1
        )

        XCTAssertFalse(ineffective.wasEffective)
        XCTAssertLessThan(ineffective.effectivenessScore, 0.5)
    }
}

// MARK: - Parameter Controller Tests

final class ParameterControllerTests: XCTestCase {

    func testParameterSnapshotPresets() {
        let neutral = ParameterSnapshot.neutral
        let meditation = ParameterSnapshot.meditation
        let focus = ParameterSnapshot.focus
        let sleep = ParameterSnapshot.sleep

        // Meditation sollte niedrigere Beat-Frequenz haben (Theta)
        XCTAssertLessThan(meditation.beatFrequency, neutral.beatFrequency)

        // Focus sollte höhere Beat-Frequenz haben (Beta)
        XCTAssertGreaterThan(focus.beatFrequency, neutral.beatFrequency)

        // Sleep sollte niedrigste Beat-Frequenz haben (Delta)
        XCTAssertLessThan(sleep.beatFrequency, meditation.beatFrequency)

        // Alle Amplituden sollten in sicherem Bereich sein
        XCTAssertTrue((0.1...0.8).contains(neutral.amplitude))
        XCTAssertTrue((0.1...0.8).contains(meditation.amplitude))
        XCTAssertTrue((0.1...0.8).contains(focus.amplitude))
        XCTAssertTrue((0.1...0.8).contains(sleep.amplitude))
    }

    func testParameterSnapshotCodable() throws {
        let snapshot = ParameterSnapshot.meditation

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ParameterSnapshot.self, from: data)

        XCTAssertEqual(decoded.beatFrequency, snapshot.beatFrequency)
        XCTAssertEqual(decoded.carrierFrequency, snapshot.carrierFrequency)
        XCTAssertEqual(decoded.amplitude, snapshot.amplitude)
    }
}

// MARK: - Safety Monitor Tests

final class SafetyMonitorTests: XCTestCase {

    func testWarningTypesExist() {
        // Alle wichtigen Warnungstypen sollten existieren
        XCTAssertNotNil(SafetyWarning.WarningType.heartRateHigh)
        XCTAssertNotNil(SafetyWarning.WarningType.heartRateLow)
        XCTAssertNotNil(SafetyWarning.WarningType.hrvRapidChange)
        XCTAssertNotNil(SafetyWarning.WarningType.sessionTooLong)
        XCTAssertNotNil(SafetyWarning.WarningType.frequencyTooHigh)
        XCTAssertNotNil(SafetyWarning.WarningType.photosensitiveRange)
        XCTAssertNotNil(SafetyWarning.WarningType.emergencyStop)
    }

    func testSeverityComparison() {
        // Critical > Warning > Info
        XCTAssertTrue(SafetyWarning.Severity.critical > SafetyWarning.Severity.warning)
        XCTAssertTrue(SafetyWarning.Severity.warning > SafetyWarning.Severity.info)
        XCTAssertTrue(SafetyWarning.Severity.critical > SafetyWarning.Severity.info)
    }

    func testSafetyWarningCodable() throws {
        let warning = SafetyWarning(
            type: .heartRateHigh,
            severity: .warning,
            message: "Test warning",
            value: 120.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(warning)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SafetyWarning.self, from: data)

        XCTAssertEqual(decoded.type, .heartRateHigh)
        XCTAssertEqual(decoded.severity, .warning)
        XCTAssertEqual(decoded.message, "Test warning")
        XCTAssertEqual(decoded.value, 120.0)
    }

    func testSessionStatisticsDefaults() {
        let stats = SessionStatistics()

        XCTAssertEqual(stats.duration, 0)
        XCTAssertNil(stats.avgHeartRate)
        XCTAssertEqual(stats.warningCount, 0)
        XCTAssertEqual(stats.criticalEventCount, 0)
    }
}

// MARK: - Learning Export Tests

final class LearningExportTests: XCTestCase {

    func testLearningExportCodable() throws {
        // Wir können LearningExport nicht direkt erstellen (init ist internal),
        // aber wir können die Struktur testen wenn sie Codable ist
        let jsonString = """
        {
            "transitionScores": {"stressed_to_relaxed": 0.75},
            "overallEffectiveness": 0.65,
            "samplesCollected": 100,
            "timestamp": "2025-12-07T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = jsonString.data(using: .utf8)!
        let export = try decoder.decode(LearningExport.self, from: data)

        XCTAssertEqual(export.overallEffectiveness, 0.65)
        XCTAssertEqual(export.samplesCollected, 100)
        XCTAssertEqual(export.transitionScores["stressed_to_relaxed"], 0.75)
    }
}

// MARK: - Array Extension Tests

final class ArrayStatisticsTests: XCTestCase {

    func testMeanCalculation() {
        let values: [Double] = [1, 2, 3, 4, 5]
        XCTAssertEqual(values.mean, 3.0)

        let empty: [Double] = []
        XCTAssertEqual(empty.mean, 0)
    }

    func testStandardDeviationCalculation() {
        let values: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
        // Expected SD ≈ 2.0
        XCTAssertGreaterThan(values.standardDeviation, 1.9)
        XCTAssertLessThan(values.standardDeviation, 2.1)

        let single: [Double] = [5.0]
        XCTAssertEqual(single.standardDeviation, 0)
    }
}
