//
//  PubMedResearchTests.swift
//  EchoelmusicTests
//
//  Tests for PubMed research integration and validation
//

import XCTest
@testable import Echoelmusic

final class PubMedResearchTests: XCTestCase {

    // MARK: - Binaural Beats Research Tests

    func testBinauralBeatsOptimalParameters_Delta() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 2.0)

        XCTAssertEqual(params.beatFrequency, 2.0, accuracy: 0.1)
        XCTAssertEqual(params.carrierFrequency, 200.0, accuracy: 1.0)
        XCTAssertFalse(params.addWhiteNoise, "Delta should not have white noise")
        XCTAssertEqual(params.whiteNoiseLevel, 0.0)
        XCTAssertTrue(params.evidence.contains("sleep") || params.evidence.contains("Padmanabhan"))
    }

    func testBinauralBeatsOptimalParameters_Theta() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 6.0)

        XCTAssertEqual(params.beatFrequency, 6.0, accuracy: 0.1)
        XCTAssertEqual(params.carrierFrequency, 220.0, accuracy: 1.0)  // A3
        XCTAssertFalse(params.addWhiteNoise)
        XCTAssertTrue(params.evidence.contains("Memory") || params.evidence.contains("Ingendoh"))
    }

    func testBinauralBeatsOptimalParameters_Alpha() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 10.0)

        XCTAssertEqual(params.beatFrequency, 10.0, accuracy: 0.1)
        XCTAssertEqual(params.carrierFrequency, 261.63, accuracy: 1.0)  // C4
        XCTAssertFalse(params.addWhiteNoise)
        XCTAssertTrue(params.evidence.contains("Anxiety") || params.evidence.contains("Garcia-Argibay"))
    }

    func testBinauralBeatsOptimalParameters_Beta() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 20.0)

        XCTAssertEqual(params.beatFrequency, 20.0, accuracy: 0.1)
        XCTAssertTrue(params.evidence.contains("Attention") || params.evidence.contains("Garcia-Argibay"))
    }

    func testBinauralBeatsOptimalParameters_Gamma() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 40.0)

        XCTAssertEqual(params.beatFrequency, 40.0, accuracy: 0.1)
        XCTAssertEqual(params.carrierFrequency, 200.0, accuracy: 1.0, "Gamma should use low carrier (2024 research)")
        XCTAssertTrue(params.addWhiteNoise, "Gamma should have white noise (2024 research)")
        XCTAssertEqual(params.whiteNoiseLevel, 0.1, accuracy: 0.01)
        XCTAssertTrue(params.evidence.contains("2024") || params.evidence.contains("attention"))
    }

    func testBinauralBeatsLeftRightFrequencies() {
        let params = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: 10.0)

        XCTAssertEqual(params.leftEarFrequency, params.carrierFrequency)
        XCTAssertEqual(params.rightEarFrequency, params.carrierFrequency + params.beatFrequency)
        XCTAssertEqual(params.rightEarFrequency - params.leftEarFrequency, 10.0, accuracy: 0.1)
    }

    // MARK: - HRV Coherence Research Tests

    func testHRVCoherenceOptimalFrequency() {
        let optimalFreq = PubMedResearchIntegration.HRVCoherenceResearch.optimalBreathingFrequency

        XCTAssertEqual(optimalFreq, 0.10, accuracy: 0.01, "Optimal frequency should be 0.10 Hz (2025 research)")

        let breathsPerMin = PubMedResearchIntegration.HRVCoherenceResearch.breathsPerMinute(from: optimalFreq)
        XCTAssertEqual(breathsPerMin, 6.0, accuracy: 0.1, "0.10 Hz = 6 breaths/min")
    }

    func testHRVCoherenceParameters_DeepSleep() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .deepSleep
        )

        XCTAssertEqual(params.targetFrequency, 0.08, accuracy: 0.01)
        XCTAssertEqual(params.breathsPerMinute, 4.8, accuracy: 0.1)
        XCTAssertEqual(params.recommendedMusicTempo, 40.0, accuracy: 1.0)
        XCTAssertTrue(params.evidence.contains("Delta") || params.evidence.contains("sleep"))
    }

    func testHRVCoherenceParameters_Meditation() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .meditation
        )

        XCTAssertEqual(params.targetFrequency, 0.10, accuracy: 0.01, "Should use optimal frequency")
        XCTAssertEqual(params.breathsPerMinute, 6.0, accuracy: 0.1)
        XCTAssertEqual(params.recommendedMusicTempo, 60.0, accuracy: 1.0)
        XCTAssertTrue(params.evidence.contains("2025") || params.evidence.contains("optimal"))
    }

    func testHRVCoherenceParameters_Relaxation() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .relaxation
        )

        XCTAssertEqual(params.targetFrequency, 0.12, accuracy: 0.01)
        XCTAssertEqual(params.breathsPerMinute, 7.2, accuracy: 0.1)
        XCTAssertTrue(params.evidence.contains("Alpha") || params.evidence.contains("relaxation"))
    }

    func testHRVCoherenceParameters_Focus() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .focus
        )

        XCTAssertEqual(params.targetFrequency, 0.15, accuracy: 0.01)
        XCTAssertEqual(params.breathsPerMinute, 9.0, accuracy: 0.1)
        XCTAssertTrue(params.evidence.contains("Beta") || params.evidence.contains("focus"))
    }

    func testHRVCoherenceParameters_Energize() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .energize
        )

        XCTAssertEqual(params.targetFrequency, 0.18, accuracy: 0.01)
        XCTAssertEqual(params.breathsPerMinute, 10.8, accuracy: 0.1)
    }

    func testHRVBreathingCycleDuration() {
        let params = PubMedResearchIntegration.HRVCoherenceResearch.getCoherenceParameters(
            targetState: .meditation
        )

        let cycleDuration = params.breathingCycleDuration
        XCTAssertEqual(cycleDuration, 10.0, accuracy: 0.1, "0.10 Hz = 10 second cycle")
    }

    // MARK: - 40Hz Gamma Research Tests

    func testGammaOptimalFrequency() {
        let freq = PubMedResearchIntegration.GammaOscillationResearch.optimal40HzFrequency

        XCTAssertEqual(freq, 40.0, accuracy: 0.1)
    }

    func testGammaExposureDuration() {
        let duration = PubMedResearchIntegration.GammaOscillationResearch.recommendedExposureDuration

        XCTAssertEqual(duration, 3600.0, accuracy: 1.0, "Recommended 1 hour exposure")
    }

    func testGammaClinicalApplications() {
        let apps = PubMedResearchIntegration.GammaOscillationResearch.clinicalApplications

        XCTAssertFalse(apps.isEmpty)
        XCTAssertTrue(apps.contains { $0.contains("Cognitive") || $0.contains("cognitive") })
        XCTAssertTrue(apps.contains { $0.contains("Alzheimer") || $0.contains("Attention") })
    }

    func testMITStudyMetadata() {
        let study = PubMedResearchIntegration.GammaOscillationResearch.mitAlzheimerStudy2016

        XCTAssertEqual(study.year, 2016)
        XCTAssertEqual(study.journal, "Nature")
        XCTAssertTrue(study.authors.contains("Iaccarino MA"))
        XCTAssertEqual(study.doi, "10.1038/nature20587")
        XCTAssertTrue(study.isHighQuality, "MIT study should be high quality")
    }

    // MARK: - Research Study Metadata Tests

    func testResearchStudyCitation_APA() {
        let study = PubMedResearchIntegration.BinauralBeatsResearch.systematicReview2023

        let citation = study.citationAPA

        XCTAssertTrue(citation.contains("Ingendoh"))
        XCTAssertTrue(citation.contains("2023"))
        XCTAssertTrue(citation.contains("PLOS ONE"))
        XCTAssertTrue(citation.contains("10.1371/journal.pone.0286023"))
    }

    func testResearchStudyQuality_HighQuality() {
        let study = PubMedResearchIntegration.GammaOscillationResearch.mitAlzheimerStudy2016

        XCTAssertNotNil(study.statisticalSignificance)
        XCTAssertNotNil(study.effectSize)
        XCTAssertTrue(study.isHighQuality)
        XCTAssertEqual(study.statisticalSignificance, 0.001, accuracy: 0.0001)
        XCTAssertEqual(study.effectSize, 0.9, accuracy: 0.1)
    }

    func testResearchStudyKeyFindings() {
        let study = PubMedResearchIntegration.BinauralBeatsResearch.systematicReview2023

        XCTAssertFalse(study.keyFindings.isEmpty)
        XCTAssertTrue(study.keyFindings.count >= 3)
        XCTAssertTrue(study.keyFindings.contains { $0.contains("theta") || $0.contains("gamma") })
    }

    // MARK: - Research Validation Tests

    func testValidateAgainstResearch_DeltaFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(2.0)

        XCTAssertTrue(validation.isValidated)
        XCTAssertEqual(validation.category, "Delta Binaural Beats")
        XCTAssertNotNil(validation.effectSize)
        XCTAssertFalse(validation.clinicalApplications.isEmpty)
        XCTAssertTrue(validation.evidence.contains("Ingendoh") || validation.evidence.contains("PLOS"))
    }

    func testValidateAgainstResearch_ThetaFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(6.0)

        XCTAssertTrue(validation.isValidated)
        XCTAssertEqual(validation.category, "Theta Binaural Beats")
        XCTAssertTrue(validation.clinicalApplications.contains { $0.contains("Meditation") || $0.contains("Memory") })
    }

    func testValidateAgainstResearch_AlphaFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(10.0)

        XCTAssertTrue(validation.isValidated)
        XCTAssertEqual(validation.category, "Alpha Binaural Beats")
        XCTAssertTrue(validation.clinicalApplications.contains { $0.contains("Anxiety") || $0.contains("Relaxation") })
    }

    func testValidateAgainstResearch_40HzGamma() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(40.0)

        XCTAssertTrue(validation.isValidated)
        XCTAssertTrue(validation.category.contains("40Hz") || validation.category.contains("Gamma"))
        XCTAssertNotNil(validation.effectSize)
        XCTAssertGreaterThan(validation.effectSize ?? 0.0, 0.5, "40Hz should have strong effect size")
        XCTAssertTrue(validation.evidence.contains("MIT") || validation.evidence.contains("Nature"))
    }

    func testValidateAgainstResearch_HRVCoherence() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(0.10)

        XCTAssertTrue(validation.isValidated)
        XCTAssertTrue(validation.category.contains("HRV") || validation.category.contains("Coherence"))
        XCTAssertTrue(validation.clinicalApplications.contains { $0.contains("HRV") || $0.contains("Stress") })
        XCTAssertTrue(validation.evidence.contains("2025") || validation.evidence.contains("1.8"))
    }

    func testValidateAgainstResearch_ISOMusicalFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(440.0)

        XCTAssertTrue(validation.isValidated)
        XCTAssertEqual(validation.category, "ISO Musical Standard")
        XCTAssertTrue(validation.evidence.contains("ISO"))
    }

    func testValidateAgainstResearch_UnvalidatedFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(123.45)

        XCTAssertFalse(validation.isValidated)
        XCTAssertEqual(validation.category, "Unvalidated")
        XCTAssertTrue(validation.evidence.contains("No peer-reviewed"))
    }

    func testValidationQualityRating_LargeEffect() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(40.0)

        XCTAssertTrue(validation.qualityRating.contains("Large effect"))
    }

    func testValidationQualityRating_MediumEffect() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(10.0)

        XCTAssertTrue(
            validation.qualityRating.contains("Medium effect") ||
            validation.qualityRating.contains("Large effect")
        )
    }

    // MARK: - Integration with ScientificFrequencies Tests

    func testScientificFrequenciesUpdatedWithPubMed() {
        let effects = ScientificFrequencies.FrequencyEffect.validated

        // Should have new entries from PubMed research
        XCTAssertTrue(effects.count >= 8, "Should have at least 8 validated frequency effects")

        // Check for HRV coherence entry
        let hrvEntry = effects.first { $0.frequency == 0.10 }
        XCTAssertNotNil(hrvEntry, "Should have 0.10 Hz HRV coherence entry")
        XCTAssertTrue(hrvEntry?.evidence.contains("2025") ?? false)

        // Check for gamma binaural beat entry
        let gammaEntries = effects.filter { $0.frequency == 40.0 }
        XCTAssertGreaterThan(gammaEntries.count, 0, "Should have at least one 40Hz gamma entry")
    }

    // MARK: - Breathing Rate Conversion Tests

    func testBreathsPerMinuteConversion() {
        XCTAssertEqual(
            PubMedResearchIntegration.HRVCoherenceResearch.breathsPerMinute(from: 0.10),
            6.0,
            accuracy: 0.1
        )

        XCTAssertEqual(
            PubMedResearchIntegration.HRVCoherenceResearch.breathsPerMinute(from: 0.08),
            4.8,
            accuracy: 0.1
        )

        XCTAssertEqual(
            PubMedResearchIntegration.HRVCoherenceResearch.breathsPerMinute(from: 0.15),
            9.0,
            accuracy: 0.1
        )
    }

    // MARK: - Edge Cases

    func testValidateResearch_BoundaryFrequencies() {
        // Test boundary cases
        let deltaLow = PubMedResearchIntegration.validateAgainstResearch(0.5)
        XCTAssertTrue(deltaLow.isValidated)

        let gammaHigh = PubMedResearchIntegration.validateAgainstResearch(100.0)
        XCTAssertTrue(gammaHigh.isValidated)
    }

    func testValidateResearch_NegativeFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(-10.0)
        XCTAssertFalse(validation.isValidated)
    }

    func testValidateResearch_ZeroFrequency() {
        let validation = PubMedResearchIntegration.validateAgainstResearch(0.0)
        XCTAssertFalse(validation.isValidated)
    }

    // MARK: - Performance Tests

    func testValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = PubMedResearchIntegration.validateAgainstResearch(Float.random(in: 1.0...100.0))
            }
        }
    }

    func testParameterGenerationPerformance() {
        measure {
            for freq in stride(from: 1.0, through: 100.0, by: 1.0) {
                _ = PubMedResearchIntegration.BinauralBeatsResearch.getOptimalParameters(for: Float(freq))
            }
        }
    }
}
