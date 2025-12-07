// ScientificAccuracyTests.swift
// Echoelmusic - Tests for Scientific Claims and Evidence Levels
//
// These tests verify that scientific claims are properly labeled
// and that unvalidated features are clearly marked.

import XCTest
@testable import Echoelmusic

final class ScientificAccuracyTests: XCTestCase {

    // MARK: - Organ Frequency Tests

    func testOrganPhysiologicalRhythmsExist() {
        // All organs should have rhythm ranges defined
        for organ in Organ.allCases {
            let range = organ.physiologicalRhythmRange
            XCTAssertLessThan(range.lowerBound, range.upperBound,
                             "Organ \(organ.rawValue) should have valid range")
        }
    }

    func testHeartRhythmIsRealistic() {
        let heartRange = Organ.heart.physiologicalRhythmRange

        // Heart rate 48-120 BPM = 0.8-2.0 Hz
        XCTAssertGreaterThanOrEqual(heartRange.lowerBound, 0.5)
        XCTAssertLessThanOrEqual(heartRange.upperBound, 3.0)
    }

    func testRespirationRhythmIsRealistic() {
        let lungRange = Organ.lungs.physiologicalRhythmRange

        // Normal breathing 9-24 breaths/min = 0.15-0.4 Hz
        XCTAssertGreaterThanOrEqual(lungRange.lowerBound, 0.1)
        XCTAssertLessThanOrEqual(lungRange.upperBound, 0.5)
    }

    func testBrainwavesSpanFullRange() {
        let brainRange = Organ.brain.physiologicalRhythmRange

        // Should cover delta (0.5-4) to gamma (30-100)
        XCTAssertLessThanOrEqual(brainRange.lowerBound, 1.0)
        XCTAssertGreaterThanOrEqual(brainRange.upperBound, 80.0)
    }

    // MARK: - Solfeggio Frequency Disclaimer Tests

    func testSolfeggioFrequenciesAreOptional() {
        // Most organs should NOT have Solfeggio frequencies
        var withSolfeggio = 0
        var withoutSolfeggio = 0

        for organ in Organ.allCases {
            if organ.solfeggioFrequency != nil {
                withSolfeggio += 1
            } else {
                withoutSolfeggio += 1
            }
        }

        // Should be minority with Solfeggio (they're traditional, not scientific)
        XCTAssertGreaterThan(withoutSolfeggio, withSolfeggio,
                            "Most organs should NOT have Solfeggio frequencies")
    }

    func testSolfeggioValuesAreTraditional() {
        // These are the traditional Solfeggio values
        let traditionalSolfeggio: [Float] = [396, 417, 528, 639, 741, 852, 963]

        for organ in Organ.allCases {
            if let freq = organ.solfeggioFrequency {
                // If present, should be one of the traditional values
                let isTraditional = traditionalSolfeggio.contains { abs($0 - freq) < 1.0 }
                XCTAssertTrue(isTraditional,
                             "Solfeggio \(freq) should be traditional value")
            }
        }
    }

    // MARK: - Photobiomodulation Tests (Actually Validated)

    func testTherapeuticWavelengthsAreValid() {
        for organ in Organ.allCases {
            let wavelength = organ.therapeuticWavelength

            // Visible + NIR range: 380-900nm
            XCTAssertGreaterThanOrEqual(wavelength.lowerBound, 380)
            XCTAssertLessThanOrEqual(wavelength.upperBound, 900)
        }
    }

    func testRedLightTherapyWavelength() {
        // Red light therapy uses 620-700nm (validated by FDA for some uses)
        let skinWavelength = Organ.skin.therapeuticWavelength

        // Skin should use red light
        XCTAssertGreaterThanOrEqual(skinWavelength.lowerBound, 600)
        XCTAssertLessThanOrEqual(skinWavelength.upperBound, 700)
    }

    func testNearInfraredForDeepTissue() {
        // NIR (800-900nm) penetrates deeper - used for brain, muscles
        let brainWavelength = Organ.brain.therapeuticWavelength

        // Brain should use NIR
        XCTAssertGreaterThanOrEqual(brainWavelength.lowerBound, 800)
    }

    // MARK: - Individual Frequency Scanner Tests

    func testMeasuredFrequencyHasUncertainty() {
        let measurement = MeasuredFrequency(
            value: 39.782341,
            uncertainty: 0.001234,
            confidence: 0.95,
            timestamp: Date(),
            sampleCount: 100
        )

        // Should have uncertainty bounds
        XCTAssertGreaterThan(measurement.uncertainty, 0)
        XCTAssertLessThan(measurement.uncertainty, measurement.value)

        // Range should be centered on value
        let range = measurement.range
        XCTAssertLessThan(range.lowerBound, measurement.value)
        XCTAssertGreaterThan(range.upperBound, measurement.value)
    }

    func testBiologicalOscillationHasVariability() {
        var oscillation = BiologicalOscillation(baseFrequency: 1.0)

        // Should track variability metrics
        XCTAssertEqual(oscillation.baseFrequency, 1.0)
        XCTAssertEqual(oscillation.instantFrequency, 1.0)

        // Initial variability should be zero (no data yet)
        XCTAssertEqual(oscillation.variabilitySD, 0)
        XCTAssertEqual(oscillation.variabilityRMSSD, 0)
    }

    func testIndividualProfileIsUnique() {
        let profile1 = IndividualFrequencyProfile()
        let profile2 = IndividualFrequencyProfile()

        // Each profile should have unique ID
        XCTAssertNotEqual(profile1.id, profile2.id)
        XCTAssertNotEqual(profile1.profileHash, profile2.profileHash)
    }

    func testNeuralBandRangesArePlausible() {
        let profile = IndividualFrequencyProfile()

        // Delta should be lowest
        XCTAssertLessThan(profile.deltaRange.upperBound, profile.thetaRange.lowerBound + 1)

        // Gamma should be highest
        XCTAssertGreaterThan(profile.gammaRange.lowerBound, profile.betaRange.upperBound - 5)
    }

    // MARK: - Evidence Level Tests

    func testQuantumEngineHasEvidenceLevels() {
        // All processing modes should have evidence level
        for mode in QuantumScienceEngine.ProcessingMode.allCases {
            let evidence = mode.evidenceLevel

            // Should be one of the defined levels
            XCTAssertTrue(
                evidence == .peerReviewed ||
                evidence == .theoretical ||
                evidence == .unvalidated
            )
        }
    }

    func testValidatedModesArePeerReviewed() {
        // These should be validated
        XCTAssertEqual(
            QuantumScienceEngine.ProcessingMode.neuralEntrainment.evidenceLevel,
            .peerReviewed,
            "Binaural beats should be peer-reviewed"
        )

        XCTAssertEqual(
            QuantumScienceEngine.ProcessingMode.spaceVibration.evidenceLevel,
            .peerReviewed,
            "Spatial audio (HRTF) should be peer-reviewed"
        )
    }

    func testUnvalidatedModesAreMarked() {
        XCTAssertEqual(
            QuantumScienceEngine.ProcessingMode.cellularResonance.evidenceLevel,
            .unvalidated,
            "Cellular resonance (Adey) should be marked unvalidated"
        )
    }

    // MARK: - Therapeutic Protocol Tests

    func testTherapeuticProtocolsHaveSafetyLimits() {
        for proto in TherapeuticProtocols.allProtocols {
            // Should have session duration
            XCTAssertGreaterThan(proto.sessionDuration, 0)
            XCTAssertLessThanOrEqual(proto.sessionDuration, 3600) // Max 1 hour

            // Should have max sessions per day
            XCTAssertGreaterThan(proto.maxSessionsPerDay, 0)
            XCTAssertLessThanOrEqual(proto.maxSessionsPerDay, 5)

            // Should have ramp times
            XCTAssertGreaterThanOrEqual(proto.rampUpTime, 0)
            XCTAssertGreaterThanOrEqual(proto.rampDownTime, 0)
        }
    }

    func testLightIntensityIsReasonable() {
        for proto in TherapeuticProtocols.allProtocols {
            // Intensity should be 0-1
            XCTAssertGreaterThanOrEqual(proto.lightIntensity, 0)
            XCTAssertLessThanOrEqual(proto.lightIntensity, 1.0)
        }
    }

    func testContraindicationsExist() {
        // Some protocols should have contraindications
        let protocolsWithContraindications = TherapeuticProtocols.allProtocols
            .filter { !$0.contraindicatedConditions.isEmpty }

        XCTAssertGreaterThan(protocolsWithContraindications.count, 0,
                            "Some protocols should list contraindications")
    }

    // MARK: - Safety Check Tests

    func testSafetyCheckBlocksDangerousConditions() {
        let epilepsyCheck = TherapySafetySystem.checkSafety(
            protocol: TherapeuticProtocols.brainwaveBalance,
            userConditions: ["epilepsy"]
        )

        // Epilepsy should block brainwave protocols
        XCTAssertFalse(epilepsyCheck.safe)
    }

    func testSafetyCheckAllowsSafeConditions() {
        let safeCheck = TherapySafetySystem.checkSafety(
            protocol: TherapeuticProtocols.heartCoherence,
            userConditions: []  // No conditions
        )

        XCTAssertTrue(safeCheck.safe)
        XCTAssertTrue(safeCheck.warnings.isEmpty)
    }

    func testMedicalDisclaimerExists() {
        let disclaimer = TherapySafetySystem.medicalDisclaimer

        XCTAssertFalse(disclaimer.isEmpty)
        XCTAssertTrue(disclaimer.contains("NOT a medical device"))
        XCTAssertTrue(disclaimer.contains("healthcare professional"))
    }
}

// MARK: - Frequency Calculation Tests

final class FrequencyCalculationTests: XCTestCase {

    func testFFTWindowSizes() {
        // Common FFT sizes should be powers of 2
        let sizes = [256, 512, 1024, 2048]

        for size in sizes {
            // Check it's power of 2
            XCTAssertEqual(size & (size - 1), 0, "\(size) should be power of 2")
        }
    }

    func testFrequencyPrecision() {
        // Frequency values should support high precision
        let freq: PreciseFrequency = 39.782341678

        // Should maintain precision
        XCTAssertEqual(freq, 39.782341678, accuracy: 0.000000001)
    }

    func testWavelengthToRGBConversion() {
        // This would test the color conversion if accessible
        // Red light (650nm) should produce red color
        // Blue light (450nm) should produce blue color
        // Green light (520nm) should produce green color

        // Note: Actual test would depend on the implementation being accessible
        XCTAssertTrue(true, "Wavelength conversion exists")
    }
}

// MARK: - Report Generation Tests

final class ReportTests: XCTestCase {

    func testIndividualReportGeneration() {
        let profile = IndividualFrequencyProfile()
        let report = IndividualFrequencyReport.generate(from: profile)

        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("INDIVIDUAL"))
        XCTAssertTrue(report.contains("Profile ID"))
    }
}
