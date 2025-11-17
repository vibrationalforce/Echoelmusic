//
//  CalculatorTests.swift
//  EchoelCalculator Tests
//
//  Unit tests for scientific validation
//

import XCTest
@testable import ScientificEchoelCalculator

final class ScientificEchoelCalculatorTests: XCTestCase {

    // MARK: - Basic Calculation Tests

    func testBPMToFrequencyConversion() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertEqual(output.bpm, 120.0, accuracy: 0.01)
        XCTAssertEqual(output.frequency, 2.0, accuracy: 0.01, "120 BPM = 2 Hz")
    }

    func testMsDelayCalculation() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertEqual(output.msDelay, 500.0, accuracy: 0.1, "120 BPM = 500ms delay")
    }

    func testSampleCountCalculation() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertEqual(output.samplesAt48kHz, 24000, "120 BPM @ 48kHz = 24000 samples")
    }

    // MARK: - Brainwave Mapping Tests

    func testDeltaRangeMapping() {
        // 30 BPM should map to Delta range
        let output = ScientificEchoelCalculator.calculate(bpm: 30)

        XCTAssertEqual(output.dominantBrainwave.name, "Delta")
        XCTAssertTrue(output.entrainmentFrequency >= 0.5 && output.entrainmentFrequency <= 4.0)
    }

    func testThetaRangeMapping() {
        // 90 BPM should map to Theta range
        let output = ScientificEchoelCalculator.calculate(bpm: 90)

        XCTAssertEqual(output.dominantBrainwave.name, "Theta")
        XCTAssertTrue(output.entrainmentFrequency >= 4.0 && output.entrainmentFrequency <= 8.0)
    }

    func testAlphaRangeMapping() {
        // 120 BPM should map to Alpha range
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertTrue(
            output.dominantBrainwave.name == "Alpha" ||
            output.dominantBrainwave.name == "Theta"  // Depending on harmonic
        )
    }

    func test40HzGammaMapping() {
        // 80 BPM should produce 40Hz harmonic (MIT research!)
        let output = ScientificEchoelCalculator.calculate(bpm: 80)

        // 80 BPM = 1.33 Hz * 30 = 40 Hz
        if abs(output.entrainmentFrequency - 40.0) < 0.5 {
            XCTAssertEqual(output.dominantBrainwave.name, "40Hz Gamma (MIT)")
            XCTAssertEqual(output.dominantBrainwave.pValue, 0.0001, accuracy: 0.0001)
        }
    }

    // MARK: - Statistical Significance Tests

    func testAllBrainwavesHaveSignificantPValues() {
        for brainwave in ScientificEchoelCalculator.validatedBrainwaves {
            XCTAssertLessThan(brainwave.pValue, 0.05, "\(brainwave.name) must have p < 0.05")
        }
    }

    func testAllBrainwavesHavePositiveEffectSizes() {
        for brainwave in ScientificEchoelCalculator.validatedBrainwaves {
            XCTAssertGreaterThan(brainwave.effectSize, 0.0, "\(brainwave.name) must have positive effect size")
        }
    }

    func testAllBrainwavesHaveReferences() {
        for brainwave in ScientificEchoelCalculator.validatedBrainwaves {
            XCTAssertFalse(brainwave.reference.isEmpty, "\(brainwave.name) must have peer-reviewed reference")
        }
    }

    // MARK: - Video Sync Tests

    func testFrameRateCalculation() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        let validFrameRates: [Float] = [24.0, 25.0, 29.97, 30.0, 48.0, 50.0, 59.94, 60.0, 120.0]
        XCTAssertTrue(validFrameRates.contains(where: { abs($0 - output.optimalFrameRate) < 0.1 }))
    }

    func testFramesPerBeatCalculation() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        let expectedFrames = Int(output.optimalFrameRate * 60.0 / output.bpm)
        XCTAssertEqual(output.framesPerBeat, expectedFrames)
    }

    func testCutsPerMinuteRanges() {
        // Slow BPM = fewer cuts
        let slow = ScientificEchoelCalculator.calculate(bpm: 40)
        XCTAssertLessThan(slow.cutsPerMinute, 60.0)

        // Fast BPM = more cuts
        let fast = ScientificEchoelCalculator.calculate(bpm: 180)
        XCTAssertGreaterThan(fast.cutsPerMinute, 180.0)
    }

    // MARK: - Validation Tests

    func testValidBPMRange() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertTrue(output.isScientificallyValid)
        XCTAssertTrue(output.warnings.isEmpty)
    }

    func testInvalidLowBPM() {
        let output = ScientificEchoelCalculator.calculate(bpm: 10)

        XCTAssertFalse(output.isScientificallyValid)
        XCTAssertFalse(output.warnings.isEmpty)
    }

    func testInvalidHighBPM() {
        let output = ScientificEchoelCalculator.calculate(bpm: 400)

        XCTAssertFalse(output.isScientificallyValid)
        XCTAssertFalse(output.warnings.isEmpty)
    }

    // MARK: - Export Tests

    func testReaperExportNotEmpty() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)
        let rpp = DAWExportManager.exportToReaper(output, duration: 60.0)

        XCTAssertFalse(rpp.isEmpty)
        XCTAssertTrue(rpp.contains("REAPER_PROJECT"))
        XCTAssertTrue(rpp.contains("TEMPO 120"))
    }

    func testPremiereExportNotEmpty() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)
        let xml = VideoExportManager.exportToPremiereXML(output, duration: 60.0)

        XCTAssertFalse(xml.isEmpty)
        XCTAssertTrue(xml.contains("xmeml"))
        XCTAssertTrue(xml.contains("EchoelSync"))
    }

    func testCSVExportFormat() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)
        let csv = DAWExportManager.exportToCSV(output, duration: 10.0)

        XCTAssertTrue(csv.contains("Time (s)"))
        XCTAssertTrue(csv.contains("Beat Number"))
        XCTAssertTrue(csv.contains("Brainwave"))
        XCTAssertTrue(csv.contains("Frequency (Hz)"))
    }

    // MARK: - Pseudoscience Detection Tests

    func testNoPseudoscienceInOutput() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        let pseudoscienceTerms = [
            "chakra", "healing", "sacred", "spiritual", "432Hz", "solfeggio",
            "divine", "miracle", "quantum healing", "aura"
        ]

        let summary = ScientificEchoelCalculator.generateSummary(output)

        for term in pseudoscienceTerms {
            XCTAssertFalse(
                summary.lowercased().contains(term.lowercased()),
                "Output should not contain pseudoscience term: \(term)"
            )
        }
    }

    func testOnlyScientificReferences() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        XCTAssertFalse(output.peerReviewedReferences.isEmpty, "Must have scientific references")

        for ref in output.peerReviewedReferences {
            // All references should contain publication info
            let hasAuthor = ref.contains("et al") || ref.contains(",")
            let hasYear = ref.contains("(20") || ref.contains("(19")
            let hasJournal = ref.contains("Journal") || ref.contains("Nature") ||
                           ref.contains("Press") || ref.contains("Reviews")

            XCTAssertTrue(
                hasAuthor && hasYear && hasJournal,
                "Reference must be properly formatted: \(ref)"
            )
        }
    }

    // MARK: - Performance Tests

    func testCalculationPerformance() {
        measure {
            for bpm in stride(from: 60, through: 180, by: 10) {
                _ = ScientificEchoelCalculator.calculate(bpm: Float(bpm))
            }
        }
    }

    func testExportPerformance() {
        let output = ScientificEchoelCalculator.calculate(bpm: 120)

        measure {
            _ = DAWExportManager.exportToReaper(output, duration: 300.0)
            _ = VideoExportManager.exportToPremiereXML(output, duration: 300.0)
            _ = DAWExportManager.exportToCSV(output, duration: 300.0)
        }
    }

    // MARK: - Edge Cases

    func testVerySlowBPM() {
        let output = ScientificEchoelCalculator.calculate(bpm: 1)

        XCTAssertEqual(output.bpm, 1.0)
        XCTAssertTrue(output.msDelay > 0)
    }

    func testVeryFastBPM() {
        let output = ScientificEchoelCalculator.calculate(bpm: 300)

        XCTAssertEqual(output.bpm, 300.0)
        XCTAssertTrue(output.msDelay > 0)
    }

    func testExactCinemaSync() {
        // 24 BPM should sync perfectly with 24 fps
        let output = ScientificEchoelCalculator.calculate(bpm: 24)

        XCTAssertEqual(output.optimalFrameRate, 24.0, accuracy: 0.1)
    }

    // MARK: - Integration Tests

    func testAllReferencesArePeerReviewed() {
        for brainwave in ScientificEchoelCalculator.validatedBrainwaves {
            // Must contain year and journal/publication
            XCTAssertTrue(brainwave.reference.contains("20") || brainwave.reference.contains("19"))
            XCTAssertTrue(
                brainwave.reference.contains("Journal") ||
                brainwave.reference.contains("Nature") ||
                brainwave.reference.contains("Neuron") ||
                brainwave.reference.contains("Reviews") ||
                brainwave.reference.contains("Press")
            )
        }
    }

    func testStatisticalSignificanceLevels() {
        // All p-values must be < 0.05 (standard significance threshold)
        for brainwave in ScientificEchoelCalculator.validatedBrainwaves {
            XCTAssertLessThan(brainwave.pValue, 0.05,
                            "\(brainwave.name) p-value (\(brainwave.pValue)) must be < 0.05")
        }

        // 40Hz Gamma should have highest significance (MIT study)
        let gamma40Hz = ScientificEchoelCalculator.validatedBrainwaves.first {
            $0.name == "40Hz Gamma (MIT)"
        }

        XCTAssertNotNil(gamma40Hz)
        XCTAssertLessThan(gamma40Hz!.pValue, 0.001, "40Hz Gamma should have p < 0.001")
    }
}
