// SuperIntelligenceTests.swift
// Echoelmusic - Comprehensive Test Suite
//
// Tests for SuperIntelligenceQuantumBioPhysicalEngine
// 100% Evidence-Based Optimal Health Integration
//
// Created: 2026-01-21
// Phase: 10000.3 SUPER INTELLIGENCE MODE

import XCTest
@testable import Echoelmusic

@MainActor
final class SuperIntelligenceTests: XCTestCase {

    // MARK: - Research Citation Tests

    func testResearchCitationsExist() {
        let citations = ResearchCitationDatabase.allCitations
        XCTAssertFalse(citations.isEmpty, "Should have research citations")
        XCTAssertGreaterThanOrEqual(citations.count, 10, "Should have at least 10 citations")
    }

    func testHRVBiofeedbackCitation() {
        let citation = ResearchCitationDatabase.hrvBiofeedbackMeta
        XCTAssertEqual(citation.authors, "Lehrer PM, Gevirtz R")
        XCTAssertEqual(citation.year, 2014)
        XCTAssertEqual(citation.evidenceLevel, .level1a)
        XCTAssertNotNil(citation.effectSize)
        XCTAssertEqual(citation.effectSize?.classification, .medium)
    }

    func testHeartMathCoherenceCitation() {
        let citation = ResearchCitationDatabase.heartMathCoherence
        XCTAssertEqual(citation.authors, "McCraty R, Atkinson M, Tomasino D, Bradley RT")
        XCTAssertEqual(citation.year, 2009)
        XCTAssertEqual(citation.evidenceLevel, .level2a)
        XCTAssertFalse(citation.keyFindings.isEmpty)
    }

    func testBlueZonesCitation() {
        let citation = ResearchCitationDatabase.blueZones
        XCTAssertEqual(citation.authors, "Buettner D, Skemp S")
        XCTAssertEqual(citation.year, 2016)
        XCTAssertEqual(citation.evidenceLevel, .level2b)
        XCTAssertNotNil(citation.pmid)
    }

    func testEvidenceLevelDescriptions() {
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level1a.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level1b.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level2a.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level2b.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level3.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level4.description.isEmpty)
        XCTAssertFalse(ResearchCitationDatabase.EvidenceLevel.level5.description.isEmpty)
    }

    func testEffectSizeClassification() {
        let large = ResearchCitationDatabase.EffectSize(cohensD: 0.9)
        XCTAssertEqual(large.classification, .large)

        let medium = ResearchCitationDatabase.EffectSize(cohensD: 0.6)
        XCTAssertEqual(medium.classification, .medium)

        let small = ResearchCitationDatabase.EffectSize(cohensD: 0.3)
        XCTAssertEqual(small.classification, .small)

        let minimal = ResearchCitationDatabase.EffectSize(cohensD: 0.1)
        XCTAssertEqual(minimal.classification, .minimal)
    }

    // MARK: - Health State Tests

    func testHealthStateInitialization() {
        let state = SuperIntelligenceHealthState()

        XCTAssertEqual(state.heartRate, 70)
        XCTAssertEqual(state.hrvSDNN, 50)
        XCTAssertEqual(state.hrvRMSSD, 35)
        XCTAssertEqual(state.hrvCoherence, 0.5)
        XCTAssertEqual(state.breathingRate, 12)
        XCTAssertEqual(state.spo2, 98)
    }

    func testRecoveryScoreCalculation() {
        var state = SuperIntelligenceHealthState()

        // High recovery state
        state.hrvSDNN = 100
        state.hrvCoherence = 0.9
        state.heartRate = 55
        let highRecovery = state.recoveryScore
        XCTAssertGreaterThan(highRecovery, 70, "High HRV and coherence should yield high recovery")

        // Low recovery state
        state.hrvSDNN = 20
        state.hrvCoherence = 0.2
        state.heartRate = 95
        let lowRecovery = state.recoveryScore
        XCTAssertLessThan(lowRecovery, 50, "Low HRV should yield low recovery")
    }

    func testStressIndexCalculation() {
        var state = SuperIntelligenceHealthState()

        // Low stress state
        state.hrvSDNN = 80
        state.lfHfRatio = 0.8
        state.heartRate = 60
        state.gsr = 2
        let lowStress = state.stressIndex
        XCTAssertLessThan(lowStress, 40, "Good metrics should yield low stress")

        // High stress state
        state.hrvSDNN = 20
        state.lfHfRatio = 3.0
        state.heartRate = 100
        state.gsr = 15
        let highStress = state.stressIndex
        XCTAssertGreaterThan(highStress, 50, "Poor metrics should yield high stress")
    }

    func testLongevityScoreCalculation() {
        var state = SuperIntelligenceHealthState()

        // Optimal longevity state
        state.hrvSDNN = 100
        state.hrvCoherence = 0.9
        state.breathingRate = 6  // Optimal coherence breathing
        let optimalLongevity = state.longevityScore
        XCTAssertGreaterThan(optimalLongevity, 60, "Optimal state should have high longevity score")
    }

    func testHealthspanScoreCalculation() {
        var state = SuperIntelligenceHealthState()

        // Good healthspan metrics
        state.hrvSDNN = 80
        state.hrvCoherence = 0.8
        state.breathingRate = 6
        let goodHealthspan = state.healthspanScore
        XCTAssertGreaterThan(goodHealthspan, 50, "Good metrics should yield decent healthspan")
    }

    func testBiologicalAgeEstimate() {
        var state = SuperIntelligenceHealthState()

        // Young HRV pattern
        state.hrvSDNN = 120
        let youngAge = state.biologicalAgeEstimate
        XCTAssertLessThan(youngAge, 40, "High HRV should suggest younger biological age")

        // Older HRV pattern
        state.hrvSDNN = 40
        let olderAge = state.biologicalAgeEstimate
        XCTAssertGreaterThan(olderAge, 50, "Low HRV should suggest older biological age")
    }

    func testAutonomicBalanceCalculation() {
        var state = SuperIntelligenceHealthState()

        // Parasympathetic dominant
        state.lfHfRatio = 0.5
        state.gsr = 2
        state.skinTemperature = 35
        let parasymDominant = state.autonomicBalance
        XCTAssertLessThan(parasymDominant, 0.3, "Should indicate parasympathetic dominance")

        // Sympathetic dominant
        state.lfHfRatio = 2.5
        state.gsr = 15
        state.skinTemperature = 30
        let sympDominant = state.autonomicBalance
        XCTAssertGreaterThan(sympDominant, 0, "Should indicate sympathetic dominance")
    }

    func testQuantumInspiredMetrics() {
        var state = SuperIntelligenceHealthState()

        state.hrvCoherence = 0.8
        state.hrvSDNN = 80
        state.heartRate = 70
        state.breathingRate = 6  // Optimal 4:1 ratio with HR=70

        let coherenceAmp = state.quantumCoherenceAmplitude
        XCTAssertGreaterThan(coherenceAmp, 0, "Should have positive coherence amplitude")

        let phaseAlign = state.phaseAlignment
        XCTAssertGreaterThan(phaseAlign, 0, "Should have positive phase alignment")
        XCTAssertLessThanOrEqual(phaseAlign, 1, "Should be clamped to 0-1")

        let superPos = state.superpositionPotential
        XCTAssertGreaterThan(superPos, 0, "Should have positive superposition potential")
    }

    // MARK: - High Precision Timer Tests

    func testTimerConfigurationPresets() {
        let echoelCore = HighPrecisionTimerSystem.TimerConfiguration.echoelUniversalCore
        XCTAssertEqual(echoelCore.frequency, 120)
        XCTAssertEqual(echoelCore.priority, .userInteractive)

        let unifiedHub = HighPrecisionTimerSystem.TimerConfiguration.unifiedControlHub
        XCTAssertEqual(unifiedHub.frequency, 60)

        let healthKit = HighPrecisionTimerSystem.TimerConfiguration.healthKit
        XCTAssertEqual(healthKit.frequency, 1)
        XCTAssertEqual(healthKit.priority, .background)
    }

    func testTimerIntervalCalculation() {
        let config = HighPrecisionTimerSystem.TimerConfiguration(frequency: 60)
        let expectedInterval = 1.0 / 60.0
        XCTAssertEqual(config.interval, expectedInterval, accuracy: 0.0001)
    }

    // MARK: - Breathing Protocol Tests

    func testResonanceBreathingProtocol() {
        let protocol = OptimalHealthProtocols.resonanceBreathing
        XCTAssertEqual(protocol.inhaleSeconds, 5.0)
        XCTAssertEqual(protocol.exhaleSeconds, 5.0)
        XCTAssertEqual(protocol.cyclesPerMinute, 6.0, accuracy: 0.1)
        XCTAssertEqual(protocol.evidenceLevel, .level1a)
        XCTAssertFalse(protocol.contraindications.isEmpty)
    }

    func test478BreathingProtocol() {
        let protocol = OptimalHealthProtocols.relaxation478
        XCTAssertEqual(protocol.inhaleSeconds, 4.0)
        XCTAssertEqual(protocol.holdInhaleSeconds, 7.0)
        XCTAssertEqual(protocol.exhaleSeconds, 8.0)
        XCTAssertEqual(protocol.totalCycleSeconds, 19.0)
        XCTAssertEqual(protocol.evidenceLevel, .level2b)
    }

    func testBoxBreathingProtocol() {
        let protocol = OptimalHealthProtocols.boxBreathing
        XCTAssertEqual(protocol.inhaleSeconds, 4.0)
        XCTAssertEqual(protocol.holdInhaleSeconds, 4.0)
        XCTAssertEqual(protocol.exhaleSeconds, 4.0)
        XCTAssertEqual(protocol.holdExhaleSeconds, 4.0)
        XCTAssertEqual(protocol.totalCycleSeconds, 16.0)
    }

    func testCoherenceBreathingProtocol() {
        let protocol = OptimalHealthProtocols.coherenceBreathing
        XCTAssertEqual(protocol.cyclesPerMinute, 6.0, accuracy: 0.1)
        XCTAssertEqual(protocol.evidenceLevel, .level2a)
    }

    func testAllBreathingProtocolsExist() {
        let protocols = OptimalHealthProtocols.allBreathingProtocols
        XCTAssertGreaterThanOrEqual(protocols.count, 4)
    }

    // MARK: - Circadian Protocol Tests

    func testCircadianPhasesExist() {
        let phases = OptimalHealthProtocols.CircadianPhase.allCases
        XCTAssertEqual(phases.count, 8)
    }

    func testCircadianProtocolsExist() {
        let protocols = OptimalHealthProtocols.circadianProtocols
        XCTAssertEqual(protocols.count, 8)
    }

    func testCircadianProtocolContent() {
        let protocols = OptimalHealthProtocols.circadianProtocols

        // Check awakening phase
        if let awakening = protocols.first(where: { $0.phase == .cortisolAwakening }) {
            XCTAssertEqual(awakening.lightColorTemp, 6500, "Should be bright daylight")
            XCTAssertEqual(awakening.lightIntensityLux, 10000, "Should be high intensity")
            XCTAssertFalse(awakening.activityRecommendation.isEmpty)
        } else {
            XCTFail("Should have awakening phase")
        }

        // Check melatonin phase
        if let melatonin = protocols.first(where: { $0.phase == .melatoninOnset }) {
            XCTAssertEqual(melatonin.lightColorTemp, 1800, "Should be candlelight")
            XCTAssertLessThan(melatonin.lightIntensityLux, 50, "Should be dim")
        } else {
            XCTFail("Should have melatonin phase")
        }
    }

    func testCircadianPhaseTimeRanges() {
        XCTAssertEqual(OptimalHealthProtocols.CircadianPhase.deepSleep.timeRange, "00:00-04:00")
        XCTAssertEqual(OptimalHealthProtocols.CircadianPhase.peakAlertness.timeRange, "08:00-12:00")
        XCTAssertEqual(OptimalHealthProtocols.CircadianPhase.melatoninOnset.timeRange, "21:00-00:00")
    }

    // MARK: - Blue Zones Power 9 Tests

    func testBlueZonesPower9Exists() {
        let power9 = OptimalHealthProtocols.blueZonesPower9
        XCTAssertEqual(power9.count, 9, "Should have exactly 9 factors")
    }

    func testBlueZonesFactorContent() {
        let power9 = OptimalHealthProtocols.blueZonesPower9

        // Check natural movement
        if let movement = power9.first(where: { $0.name == "Natural Movement" }) {
            XCTAssertEqual(movement.category, .movement)
            XCTAssertFalse(movement.practicalTips.isEmpty)
            XCTAssertFalse(movement.scientificBasis.isEmpty)
        } else {
            XCTFail("Should have Natural Movement factor")
        }

        // Check 80% rule
        if let hara = power9.first(where: { $0.name == "80% Rule (Hara Hachi Bu)" }) {
            XCTAssertEqual(hara.category, .eating)
        } else {
            XCTFail("Should have 80% Rule factor")
        }
    }

    func testBlueZonesCategories() {
        let power9 = OptimalHealthProtocols.blueZonesPower9
        let categories = Set(power9.map { $0.category })

        XCTAssertTrue(categories.contains(.movement))
        XCTAssertTrue(categories.contains(.purpose))
        XCTAssertTrue(categories.contains(.stress))
        XCTAssertTrue(categories.contains(.eating))
        XCTAssertTrue(categories.contains(.community))
    }

    // MARK: - Super Intelligence Engine Tests

    func testSuperIntelligenceEngineInitialization() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine.shared
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.sessionDuration, 0)
    }

    func testSuperIntelligenceEngineStartStop() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        engine.start()
        XCTAssertTrue(engine.isRunning)

        // Wait a brief moment
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        engine.stop()
        XCTAssertFalse(engine.isRunning)
        XCTAssertGreaterThan(engine.sessionDuration, 0)
    }

    func testSuperIntelligenceEngineBiometricUpdate() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        engine.updateBiometrics(
            heartRate: 65,
            hrvSDNN: 80,
            hrvRMSSD: 45,
            hrvPNN50: 20,
            lfHfRatio: 1.0,
            hrvCoherence: 0.85,
            breathingRate: 6,
            breathingDepth: 0.7,
            rsaAmplitude: 15,
            gsr: 3,
            skinTemperature: 34,
            spo2: 99
        )

        XCTAssertEqual(engine.currentState.heartRate, 65)
        XCTAssertEqual(engine.currentState.hrvSDNN, 80)
        XCTAssertEqual(engine.currentState.hrvCoherence, 0.85)
        XCTAssertEqual(engine.currentState.breathingRate, 6)
    }

    func testOptimalAudioParameters() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        engine.updateBiometrics(
            heartRate: 70,
            hrvSDNN: 60,
            hrvRMSSD: 40,
            hrvCoherence: 0.7,
            breathingRate: 8
        )

        let params = engine.getOptimalAudioParameters()

        // Frequency should be in brainwave range
        XCTAssertGreaterThanOrEqual(params.frequency, 0.5)
        XCTAssertLessThanOrEqual(params.frequency, 100)

        // Carrier should be A4
        XCTAssertEqual(params.carrier, 440.0)

        // Volume should be in safe range
        XCTAssertGreaterThanOrEqual(params.volume, 0.1)
        XCTAssertLessThanOrEqual(params.volume, 1.0)
    }

    func testOptimalLightParameters() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        let params = engine.getOptimalLightParameters()

        // Color temp should be reasonable
        XCTAssertGreaterThanOrEqual(params.colorTemp, 0)
        XCTAssertLessThanOrEqual(params.colorTemp, 10000)

        // Intensity should be positive
        XCTAssertGreaterThanOrEqual(params.intensity, 0)
    }

    func testCircadianRecommendations() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        let recommendations = engine.getCircadianRecommendations()

        XCTAssertFalse(recommendations.activity.isEmpty)
        XCTAssertFalse(recommendations.nutrition.isEmpty)
    }

    func testRelevantCitations() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        engine.updateBiometrics(
            heartRate: 70,
            hrvSDNN: 60,
            hrvRMSSD: 40,
            hrvCoherence: 0.8,
            breathingRate: 6
        )

        let citations = engine.getRelevantCitations()

        // Should always include HRV meta-analysis
        XCTAssertFalse(citations.isEmpty)
        XCTAssertTrue(citations.contains(where: { $0.authors.contains("Lehrer") }))
    }

    func testSessionAnalytics() async {
        let engine = SuperIntelligenceQuantumBioPhysicalEngine()

        engine.start()

        // Update some data
        engine.updateBiometrics(
            heartRate: 65,
            hrvSDNN: 75,
            hrvRMSSD: 42,
            hrvCoherence: 0.82,
            breathingRate: 6
        )

        // Wait briefly
        try? await Task.sleep(nanoseconds: 100_000_000)

        engine.stop()

        let analytics = engine.getSessionAnalytics()

        XCTAssertGreaterThan(analytics.sessionDuration, 0)
        XCTAssertGreaterThanOrEqual(analytics.averageRecoveryScore, 0)
        XCTAssertLessThanOrEqual(analytics.averageRecoveryScore, 100)
    }

    // MARK: - Technology Compatibility Tests

    func testTechnologyCompatibilityLayer() {
        XCTAssertEqual(TechnologyCompatibilityLayer.current, .current)
        XCTAssertEqual(TechnologyCompatibilityLayer.apiVersion, "3.0.0")
        XCTAssertFalse(TechnologyCompatibilityLayer.supportedBiometricSources.isEmpty)
    }

    func testAPIVersionCompatibility() {
        XCTAssertTrue(TechnologyCompatibilityLayer.isCompatible(apiVersion: "3.0.0"))
        XCTAssertTrue(TechnologyCompatibilityLayer.isCompatible(apiVersion: "3.0.1"))
        XCTAssertFalse(TechnologyCompatibilityLayer.isCompatible(apiVersion: "4.0.0"))
        XCTAssertFalse(TechnologyCompatibilityLayer.isCompatible(apiVersion: "2.0.0"))
    }

    // MARK: - Disclaimer Tests

    func testHealthDisclaimerExists() {
        let disclaimer = SuperIntelligenceHealthDisclaimer.fullDisclaimer
        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.contains("NOT a medical device"))
        XCTAssertTrue(disclaimer.contains("NOT FDA"))
    }

    func testShortDisclaimerExists() {
        let disclaimer = SuperIntelligenceHealthDisclaimer.shortDisclaimer
        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.contains("Not a medical device"))
    }

    func testBiometricDisclaimerExists() {
        let disclaimer = SuperIntelligenceHealthDisclaimer.biometricDisclaimer
        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.lowercased().contains("estimate"))
    }

    func testBreathingDisclaimerExists() {
        let disclaimer = SuperIntelligenceHealthDisclaimer.breathingDisclaimer
        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.lowercased().contains("dizzy") || disclaimer.lowercased().contains("uncomfortable"))
    }

    func testLongevityDisclaimerExists() {
        let disclaimer = SuperIntelligenceHealthDisclaimer.longevityDisclaimer
        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.lowercased().contains("population") || disclaimer.lowercased().contains("individual"))
    }

    // MARK: - Edge Case Tests

    func testHealthStateExtremeLowValues() {
        var state = SuperIntelligenceHealthState()
        state.heartRate = 30
        state.hrvSDNN = 5
        state.hrvCoherence = 0
        state.breathingRate = 2

        // Should not crash and should clamp appropriately
        let recovery = state.recoveryScore
        XCTAssertGreaterThanOrEqual(recovery, 0)
        XCTAssertLessThanOrEqual(recovery, 100)

        let stress = state.stressIndex
        XCTAssertGreaterThanOrEqual(stress, 0)
        XCTAssertLessThanOrEqual(stress, 100)
    }

    func testHealthStateExtremeHighValues() {
        var state = SuperIntelligenceHealthState()
        state.heartRate = 220
        state.hrvSDNN = 300
        state.hrvCoherence = 1.0
        state.breathingRate = 40

        // Should not crash and should clamp appropriately
        let recovery = state.recoveryScore
        XCTAssertGreaterThanOrEqual(recovery, 0)
        XCTAssertLessThanOrEqual(recovery, 100)

        let longevity = state.longevityScore
        XCTAssertGreaterThanOrEqual(longevity, 0)
        XCTAssertLessThanOrEqual(longevity, 100)
    }

    func testHealthStateBoundaryValues() {
        var state = SuperIntelligenceHealthState()

        // Test with boundary coherence values
        state.hrvCoherence = 0.0
        XCTAssertGreaterThanOrEqual(state.quantumCoherenceAmplitude, 0)

        state.hrvCoherence = 1.0
        XCTAssertLessThanOrEqual(state.quantumCoherenceAmplitude, 10)

        // Test phase alignment with exact optimal ratio
        state.heartRate = 72
        state.breathingRate = 18  // Exactly 4:1 ratio
        XCTAssertEqual(state.phaseAlignment, 1.0, accuracy: 0.1)
    }

    // MARK: - Performance Tests

    func testHealthScoreCalculationPerformance() {
        var state = SuperIntelligenceHealthState()
        state.heartRate = 70
        state.hrvSDNN = 60
        state.hrvCoherence = 0.7

        measure {
            for _ in 0..<10000 {
                _ = state.recoveryScore
                _ = state.stressIndex
                _ = state.longevityScore
                _ = state.healthspanScore
            }
        }
    }

    func testTimerConfigurationCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = HighPrecisionTimerSystem.TimerConfiguration(frequency: 60)
                _ = HighPrecisionTimerSystem.TimerConfiguration(frequency: 120)
                _ = HighPrecisionTimerSystem.TimerConfiguration.echoelUniversalCore
            }
        }
    }
}
