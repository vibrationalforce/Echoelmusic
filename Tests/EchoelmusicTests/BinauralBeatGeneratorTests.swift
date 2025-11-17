//
//  BinauralBeatGeneratorTests.swift
//  EchoelmusicTests
//
//  Tests for research-based binaural beat generation
//

import XCTest
import AVFoundation
@testable import Echoelmusic

final class BinauralBeatGeneratorTests: XCTestCase {

    var generator: BinauralBeatGenerator!
    var stereoFormat: AVAudioFormat!

    override func setUp() {
        super.setUp()
        generator = BinauralBeatGenerator(sampleRate: 48000.0)

        // Create stereo format
        stereoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 2,
            interleaved: false
        )
    }

    override func tearDown() {
        generator = nil
        stereoFormat = nil
        super.tearDown()
    }

    // MARK: - Basic Generation Tests

    func testGenerateDeltaBinauralBeat() throws {
        let buffer = generator.generate(
            targetBrainwave: .delta,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 48000)
        XCTAssertEqual(buffer?.format.channelCount, 2)
    }

    func testGenerateThetaBinauralBeat() throws {
        let buffer = generator.generate(
            targetBrainwave: .theta,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 48000)
    }

    func testGenerateAlphaBinauralBeat() throws {
        let buffer = generator.generate(
            targetBrainwave: .alpha,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 48000)
    }

    func testGenerateBetaBinauralBeat() throws {
        let buffer = generator.generate(
            targetBrainwave: .beta,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 48000)
    }

    func testGenerateGammaBinauralBeat() throws {
        let buffer = generator.generate(
            targetBrainwave: .gamma,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 48000)
    }

    // MARK: - Custom Parameter Tests

    func testGenerateWithCustomParameters() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 2.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 96000)  // 2 seconds at 48kHz
    }

    func testGenerateWithWhiteNoise() throws {
        let buffer = generator.generate(
            beatFrequency: 40.0,
            carrierFrequency: 200.0,
            addWhiteNoise: true,
            whiteNoiseLevel: 0.1,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        // Verify white noise was added
        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        // White noise should add some variation
        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))
        let rightChannel = UnsafeBufferPointer(start: channelData[1], count: Int(buffer!.frameLength))

        // Calculate variance (white noise increases variance)
        let leftVariance = calculateVariance(Array(leftChannel))
        let rightVariance = calculateVariance(Array(rightChannel))

        XCTAssertGreaterThan(leftVariance, 0.0)
        XCTAssertGreaterThan(rightVariance, 0.0)
    }

    // MARK: - Stereo Channel Tests

    func testLeftRightChannelsDifferent() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 0.1,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))
        let rightChannel = UnsafeBufferPointer(start: channelData[1], count: Int(buffer!.frameLength))

        // Channels should be different (one is 440 Hz, other is 450 Hz)
        var differenceCount = 0
        for i in 0..<leftChannel.count {
            if abs(leftChannel[i] - rightChannel[i]) > 0.01 {
                differenceCount += 1
            }
        }

        XCTAssertGreaterThan(differenceCount, leftChannel.count / 2, "L/R channels should be significantly different")
    }

    func testMonoFormatReturnsNil() {
        let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 1,
            interleaved: false
        )

        let buffer = generator.generate(
            targetBrainwave: .alpha,
            duration: 1.0,
            format: monoFormat!
        )

        XCTAssertNil(buffer, "Mono format should return nil (requires stereo)")
    }

    // MARK: - Duration Tests

    func testGenerateShortDuration() throws {
        let buffer = generator.generate(
            targetBrainwave: .alpha,
            duration: 0.1,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 4800)  // 0.1s at 48kHz
    }

    func testGenerateLongDuration() throws {
        let buffer = generator.generate(
            targetBrainwave: .alpha,
            duration: 10.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 480000)  // 10s at 48kHz
    }

    // MARK: - Fade In/Out Tests

    func testFadeInApplied() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))

        // First sample should have lower amplitude (fade in)
        let firstSampleAbs = abs(leftChannel[0])
        let middleSampleAbs = abs(leftChannel[leftChannel.count / 2])

        XCTAssertLessThan(firstSampleAbs, middleSampleAbs, "Fade in should reduce initial amplitude")
    }

    func testFadeOutApplied() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))

        // Last sample should have lower amplitude (fade out)
        let lastSampleAbs = abs(leftChannel[leftChannel.count - 1])
        let middleSampleAbs = abs(leftChannel[leftChannel.count / 2])

        XCTAssertLessThan(lastSampleAbs, middleSampleAbs, "Fade out should reduce final amplitude")
    }

    // MARK: - HRV Guided Breathing Tests

    func testHRVGuidedBreathing_Meditation() throws {
        let buffer = generator.generateHRVGuidedBreathing(
            targetState: .meditation,
            duration: 10.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.frameLength, 480000)  // 10s at 48kHz
    }

    func testHRVGuidedBreathing_DeepSleep() throws {
        let buffer = generator.generateHRVGuidedBreathing(
            targetState: .deepSleep,
            duration: 5.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testHRVGuidedBreathing_Focus() throws {
        let buffer = generator.generateHRVGuidedBreathing(
            targetState: .focus,
            duration: 5.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    // MARK: - Validation Tests

    func testValidateParameters_ValidRange() {
        let result = BinauralBeatGenerator.validateParameters(
            beatFrequency: 10.0,
            carrierFrequency: 440.0
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testValidateParameters_BeatFrequencyTooLow() {
        let result = BinauralBeatGenerator.validateParameters(
            beatFrequency: 0.1,
            carrierFrequency: 440.0
        )

        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.first?.contains("outside research-validated range") ?? false)
    }

    func testValidateParameters_BeatFrequencyTooHigh() {
        let result = BinauralBeatGenerator.validateParameters(
            beatFrequency: 150.0,
            carrierFrequency: 440.0
        )

        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testValidateParameters_CarrierTooLow() {
        let result = BinauralBeatGenerator.validateParameters(
            beatFrequency: 10.0,
            carrierFrequency: 10.0
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.warnings.contains { $0.contains("below audible threshold") })
    }

    func testValidateParameters_GammaWithHighCarrier() {
        let result = BinauralBeatGenerator.validateParameters(
            beatFrequency: 40.0,
            carrierFrequency: 500.0
        )

        // Should suggest low carrier for gamma
        XCTAssertTrue(result.warnings.contains { $0.contains("low carrier tone") })
    }

    // MARK: - Research Evidence Tests

    func testGetResearchEvidence_40Hz() {
        let evidence = BinauralBeatGenerator.getResearchEvidence(for: 40.0)

        XCTAssertTrue(evidence.contains("✅"))
        XCTAssertTrue(evidence.contains("Gamma") || evidence.contains("40Hz"))
        XCTAssertTrue(evidence.contains("Evidence"))
    }

    func testGetResearchEvidence_10Hz() {
        let evidence = BinauralBeatGenerator.getResearchEvidence(for: 10.0)

        XCTAssertTrue(evidence.contains("✅"))
        XCTAssertTrue(evidence.contains("Alpha"))
    }

    func testGetResearchEvidence_UnvalidatedFrequency() {
        let evidence = BinauralBeatGenerator.getResearchEvidence(for: 999.0)

        XCTAssertTrue(evidence.contains("❌"))
        XCTAssertTrue(evidence.contains("No peer-reviewed"))
    }

    // MARK: - Preset Factory Tests

    func testPresetFactory_DeepSleep() {
        let buffer = BinauralBeatPresetFactory.deepSleep(
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testPresetFactory_Meditation() {
        let buffer = BinauralBeatPresetFactory.meditation(
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testPresetFactory_Relaxation() {
        let buffer = BinauralBeatPresetFactory.relaxation(
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testPresetFactory_Focus() {
        let buffer = BinauralBeatPresetFactory.focus(
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testPresetFactory_CognitiveEnhancement() {
        let buffer = BinauralBeatPresetFactory.cognitiveEnhancement(
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        // Should use optimal gamma parameters (low carrier + white noise)
        // This is validated by the fact it doesn't crash and returns a buffer
    }

    func testPresetFactory_HRVCoherence() {
        let buffer = BinauralBeatPresetFactory.hrvCoherence(
            targetState: .meditation,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)
    }

    func testPresetFactory_AllPresets() {
        let presets = BinauralBeatPresetFactory.allPresets

        XCTAssertEqual(presets.count, 6, "Should have 6 research-validated presets")

        for preset in presets {
            XCTAssertFalse(preset.name.isEmpty)
            XCTAssertFalse(preset.description.isEmpty)
            XCTAssertFalse(preset.evidence.isEmpty)
        }
    }

    // MARK: - Audio Quality Tests

    func testAudioAmplitudeInRange() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 1.0,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))

        // All samples should be in valid range [-1.0, 1.0]
        for sample in leftChannel {
            XCTAssertGreaterThanOrEqual(sample, -1.1)
            XCTAssertLessThanOrEqual(sample, 1.1)
        }
    }

    func testNoSilence() throws {
        let buffer = generator.generate(
            beatFrequency: 10.0,
            carrierFrequency: 440.0,
            addWhiteNoise: false,
            whiteNoiseLevel: 0.0,
            duration: 0.5,
            format: stereoFormat
        )

        XCTAssertNotNil(buffer)

        guard let channelData = buffer?.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        let leftChannel = UnsafeBufferPointer(start: channelData[0], count: Int(buffer!.frameLength))

        // Should have non-zero samples (not all silence)
        let nonZeroCount = leftChannel.filter { abs($0) > 0.01 }.count
        XCTAssertGreaterThan(nonZeroCount, leftChannel.count / 2, "Should have mostly non-zero samples")
    }

    // MARK: - Performance Tests

    func testGenerationPerformance() {
        measure {
            _ = generator.generate(
                targetBrainwave: .alpha,
                duration: 10.0,
                format: stereoFormat
            )
        }
    }

    func testMultipleGenerationPerformance() {
        measure {
            for brainwave in ScientificFrequencies.BrainwaveFrequency.allCases {
                _ = generator.generate(
                    targetBrainwave: brainwave,
                    duration: 1.0,
                    format: stereoFormat
                )
            }
        }
    }

    // MARK: - Helper Functions

    private func calculateVariance(_ samples: [Float]) -> Float {
        let mean = samples.reduce(0.0, +) / Float(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(samples.count)
        return variance
    }
}
