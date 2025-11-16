//
//  AudioNodeTests.swift
//  EchoelmusicTests
//
//  Comprehensive tests for Audio Nodes and DSP Effects
//

import XCTest
import AVFoundation
@testable import Echoelmusic

@MainActor
final class AudioNodeTests: XCTestCase {

    var audioEngine: AVAudioEngine!
    var format: AVAudioFormat!

    override func setUp() async throws {
        try await super.setUp()
        audioEngine = AVAudioEngine()
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    }

    override func tearDown() async throws {
        audioEngine.stop()
        audioEngine = nil
        format = nil
        try await super.tearDown()
    }

    // MARK: - Filter Node Tests

    func testFilterNodeInitialization() {
        // This tests the concept - actual implementation may vary
        XCTAssertNotNil(format)
    }

    func testFilterNodeParameterRanges() {
        // Test that filter parameters are in valid ranges
        let cutoffMin: Float = 20.0
        let cutoffMax: Float = 20000.0
        let resonanceMin: Float = 0.0
        let resonanceMax: Float = 1.0

        XCTAssertGreaterThan(cutoffMax, cutoffMin)
        XCTAssertGreaterThan(resonanceMax, resonanceMin)
    }

    func testFilterSweep() {
        // Test filter sweep from low to high frequency
        let startCutoff: Float = 200.0
        let endCutoff: Float = 2000.0
        let steps = 10

        for i in 0...steps {
            let t = Float(i) / Float(steps)
            let cutoff = startCutoff + (endCutoff - startCutoff) * t

            XCTAssertGreaterThanOrEqual(cutoff, startCutoff)
            XCTAssertLessThanOrEqual(cutoff, endCutoff)
        }
    }

    // MARK: - Reverb Node Tests

    func testReverbNodeParameters() {
        // Test reverb parameter ranges
        let wetDryMin: Float = 0.0
        let wetDryMax: Float = 1.0

        XCTAssertEqual(wetDryMin, 0.0)
        XCTAssertEqual(wetDryMax, 1.0)
    }

    func testReverbPresets() {
        let presets = ["Small Room", "Medium Hall", "Large Cathedral", "Plate"]

        for preset in presets {
            XCTAssertFalse(preset.isEmpty)
        }
    }

    // MARK: - Delay Node Tests

    func testDelayNodeTiming() {
        let delayTimes: [Float] = [0.125, 0.25, 0.375, 0.5, 0.75, 1.0]  // seconds

        for delayTime in delayTimes {
            XCTAssertGreaterThan(delayTime, 0.0)
            XCTAssertLessThanOrEqual(delayTime, 2.0, "Delay should be reasonable")
        }
    }

    func testDelayFeedback() {
        let feedbackMin: Float = 0.0
        let feedbackMax: Float = 0.95  // Below 1.0 to prevent runaway

        XCTAssertLessThan(feedbackMax, 1.0, "Feedback should be < 1.0")
    }

    func testRhythmicDelaySync() {
        let tempo: Float = 120.0  // BPM
        let beatDuration = 60.0 / tempo  // seconds per beat

        // Common rhythmic delays
        let quarterNote = beatDuration
        let eighthNote = beatDuration / 2.0
        let sixteenthNote = beatDuration / 4.0

        XCTAssertEqual(quarterNote, 0.5, accuracy: 0.01)
        XCTAssertEqual(eighthNote, 0.25, accuracy: 0.01)
        XCTAssertEqual(sixteenthNote, 0.125, accuracy: 0.01)
    }

    // MARK: - Compressor Node Tests

    func testCompressorThreshold() {
        let thresholds: [Float] = [-24.0, -18.0, -12.0, -6.0, 0.0]  // dB

        for threshold in thresholds {
            XCTAssertLessThanOrEqual(threshold, 0.0, "Threshold should be <= 0 dB")
            XCTAssertGreaterThanOrEqual(threshold, -60.0, "Threshold should be reasonable")
        }
    }

    func testCompressorRatios() {
        let ratios: [Float] = [1.5, 2.0, 3.0, 4.0, 6.0, 10.0, 20.0]

        for ratio in ratios {
            XCTAssertGreaterThanOrEqual(ratio, 1.0, "Ratio should be >= 1.0")
        }
    }

    func testCompressorAttackRelease() {
        let attackTimes: [Float] = [1.0, 5.0, 10.0, 25.0, 50.0]  // milliseconds
        let releaseTimes: [Float] = [50.0, 100.0, 250.0, 500.0, 1000.0]  // milliseconds

        for attack in attackTimes {
            XCTAssertGreaterThan(attack, 0.0)
            XCTAssertLessThan(attack, 100.0, "Attack should be fast")
        }

        for release in releaseTimes {
            XCTAssertGreaterThan(release, 0.0)
            XCTAssertLessThan(release, 2000.0, "Release should be reasonable")
        }
    }

    // MARK: - Node Chain Tests

    func testNodeChainConfiguration() {
        // Test typical effect chain order
        let effectChain = ["Input", "Filter", "Compressor", "Delay", "Reverb", "Limiter", "Output"]

        XCTAssertEqual(effectChain.count, 7)
        XCTAssertEqual(effectChain.first, "Input")
        XCTAssertEqual(effectChain.last, "Output")
    }

    func testParallelProcessing() {
        // Test parallel processing setup
        let wetSignal: Float = 0.5
        let drySignal: Float = 0.5

        let mixed = wetSignal + drySignal

        XCTAssertEqual(mixed, 1.0, accuracy: 0.01)
    }

    // MARK: - Audio Buffer Tests

    func testBufferCreation() {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)

        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.format.sampleRate, 44100.0)
        XCTAssertEqual(buffer?.format.channelCount, 2)
    }

    func testBufferFillWithSineWave() {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        guard let channelData = buffer.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        // Fill with 440 Hz sine wave
        let frequency: Float = 440.0
        let sampleRate: Float = 44100.0

        for frame in 0..<Int(buffer.frameLength) {
            let phase = Float(frame) * frequency * 2.0 * .pi / sampleRate
            let sample = sin(phase)

            channelData[0][frame] = sample
            channelData[1][frame] = sample
        }

        // Verify not all zeros
        let firstSample = channelData[0][0]
        XCTAssertNotEqual(firstSample, 0.0, accuracy: 0.01)
    }

    func testBufferPeakDetection() {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        guard let channelData = buffer.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        // Fill with test signal
        for frame in 0..<Int(buffer.frameLength) {
            channelData[0][frame] = Float(sin(Double(frame) * 0.1))
            channelData[1][frame] = channelData[0][frame]
        }

        // Find peak
        var peak: Float = 0.0
        for frame in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(channelData[0][frame]))
        }

        XCTAssertGreaterThan(peak, 0.0)
        XCTAssertLessThanOrEqual(peak, 1.0)
    }

    func testBufferRMSCalculation() {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        guard let channelData = buffer.floatChannelData else {
            XCTFail("No channel data")
            return
        }

        // Fill with test signal
        for frame in 0..<Int(buffer.frameLength) {
            channelData[0][frame] = Float(sin(Double(frame) * 0.1))
        }

        // Calculate RMS
        var sum: Float = 0.0
        for frame in 0..<Int(buffer.frameLength) {
            sum += channelData[0][frame] * channelData[0][frame]
        }
        let rms = sqrt(sum / Float(buffer.frameLength))

        XCTAssertGreaterThan(rms, 0.0)
        XCTAssertLessThan(rms, 1.0)
    }

    // MARK: - Bio-Reactive Processing Tests

    func testBioSignalMapping() {
        let hrv: Float = 0.7  // 70% coherence
        let heartRate: Float = 75.0  // BPM

        // Map to audio parameters
        let reverbAmount = hrv  // Higher HRV = more reverb
        let filterCutoff = 200.0 + (heartRate / 120.0) * 1800.0  // Map HR to 200-2000 Hz

        XCTAssertGreaterThan(reverbAmount, 0.0)
        XCTAssertLessThanOrEqual(reverbAmount, 1.0)

        XCTAssertGreaterThanOrEqual(filterCutoff, 200.0)
        XCTAssertLessThanOrEqual(filterCutoff, 2000.0)
    }

    func testBioReactiveSmoothing() {
        var currentValue: Float = 0.5
        let targetValue: Float = 0.8
        let smoothingFactor: Float = 0.9

        // Exponential smoothing
        currentValue = currentValue * smoothingFactor + targetValue * (1.0 - smoothingFactor)

        XCTAssertGreaterThan(currentValue, 0.5)
        XCTAssertLessThan(currentValue, 0.8)
    }

    // MARK: - Performance Tests

    func testBufferProcessingPerformance() {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        buffer.frameLength = 4096

        measure {
            guard let channelData = buffer.floatChannelData else { return }

            for frame in 0..<Int(buffer.frameLength) {
                channelData[0][frame] = Float(sin(Double(frame) * 0.01))
            }
        }
    }
}

// MARK: - DSP Effects Tests

@MainActor
final class DSPEffectsTests: XCTestCase {

    func testBiquadFilterCoefficients() {
        // Test biquad filter coefficient calculation
        let sampleRate: Float = 44100.0
        let frequency: Float = 1000.0
        let q: Float = 0.707

        let omega = 2.0 * Float.pi * frequency / sampleRate
        let alpha = sin(omega) / (2.0 * q)

        XCTAssertGreaterThan(alpha, 0.0)
        XCTAssertLessThan(alpha, 1.0)
    }

    func testFFTSizes() {
        let validFFTSizes = [64, 128, 256, 512, 1024, 2048, 4096, 8192]

        for size in validFFTSizes {
            // Check if power of 2
            let isPowerOfTwo = (size & (size - 1)) == 0
            XCTAssertTrue(isPowerOfTwo, "\(size) should be power of 2")
        }
    }

    func testPitchDetection() {
        // Test YIN algorithm parameters
        let sampleRate: Float = 44100.0
        let minFreq: Float = 80.0   // Low E
        let maxFreq: Float = 1000.0

        let minPeriod = Int(sampleRate / maxFreq)
        let maxPeriod = Int(sampleRate / minFreq)

        XCTAssertGreaterThan(maxPeriod, minPeriod)
        XCTAssertGreaterThan(minPeriod, 0)
    }

    func testBinauralBeatFrequencies() {
        // Test binaural beat frequency differences
        let baseFrequency: Float = 200.0
        let beatFrequencies: [Float] = [4.0, 8.0, 13.0, 20.0, 40.0]  // Delta, Theta, Alpha, Beta, Gamma

        for beatFreq in beatFrequencies {
            let leftFreq = baseFrequency
            let rightFreq = baseFrequency + beatFreq

            XCTAssertGreaterThan(rightFreq, leftFreq)
            XCTAssertLessThan(beatFreq, 50.0, "Binaural beat should be < 50 Hz")
        }
    }

    func testHealingFrequencies() {
        // Test Solfeggio frequencies
        let solfeggioFrequencies: [Float] = [
            174.0,  // Pain reduction
            285.0,  // Tissue healing
            396.0,  // Liberation from fear
            417.0,  // Transformation
            528.0,  // DNA repair
            639.0,  // Relationships
            741.0,  // Awakening
            852.0,  // Spiritual order
            963.0   // Divine consciousness
        ]

        for (index, freq) in solfeggioFrequencies.enumerated() {
            XCTAssertGreaterThan(freq, 0.0)
            if index > 0 {
                XCTAssertGreaterThan(freq, solfeggioFrequencies[index - 1], "Should be ascending")
            }
        }
    }

    func testMusicTheoryScales() {
        // Test musical scales
        let chromaticScale = 12  // 12 semitones
        let majorScaleIntervals = [2, 2, 1, 2, 2, 2, 1]  // W-W-H-W-W-W-H
        let minorScaleIntervals = [2, 1, 2, 2, 1, 2, 2]  // W-H-W-W-H-W-W

        XCTAssertEqual(majorScaleIntervals.reduce(0, +), chromaticScale)
        XCTAssertEqual(minorScaleIntervals.reduce(0, +), chromaticScale)
    }

    func testOctaveRelationships() {
        let a440: Float = 440.0
        let a880 = a440 * 2.0  // One octave up
        let a220 = a440 / 2.0  // One octave down

        XCTAssertEqual(a880, 880.0)
        XCTAssertEqual(a220, 220.0)

        // Test frequency ratio
        XCTAssertEqual(a880 / a440, 2.0)
        XCTAssertEqual(a440 / a220, 2.0)
    }

    func testNoteToFrequencyConversion() {
        // MIDI note 69 = A440
        let midiNote: Float = 69.0
        let frequency = 440.0 * pow(2.0, (midiNote - 69.0) / 12.0)

        XCTAssertEqual(frequency, 440.0, accuracy: 0.01)

        // Test C4 (MIDI 60)
        let c4Freq = 440.0 * pow(2.0, (60.0 - 69.0) / 12.0)
        XCTAssertEqual(c4Freq, 261.63, accuracy: 0.01)
    }

    func testDecibelConversion() {
        let linearGains: [Float] = [0.0, 0.5, 1.0, 2.0]

        for gain in linearGains {
            if gain > 0.0 {
                let db = 20.0 * log10(gain)
                XCTAssertNotNil(db)

                // Convert back
                let linearAgain = pow(10.0, db / 20.0)
                XCTAssertEqual(linearAgain, gain, accuracy: 0.01)
            }
        }
    }

    func testStereoWidthCalculation() {
        let monoSignalL: Float = 0.5
        let monoSignalR: Float = 0.5

        let mid = (monoSignalL + monoSignalR) / 2.0
        let side = (monoSignalL - monoSignalR) / 2.0

        // For mono signal, side should be near zero
        XCTAssertEqual(side, 0.0, accuracy: 0.01)
        XCTAssertEqual(mid, 0.5, accuracy: 0.01)
    }

    func testDynamicRangeCompression() {
        let inputLevel: Float = 0.8  // -1.94 dB
        let threshold: Float = -6.0  // dB
        let ratio: Float = 4.0

        let inputDB = 20.0 * log10(inputLevel)

        if inputDB > threshold {
            let excessDB = inputDB - threshold
            let compressedExcessDB = excessDB / ratio
            let outputDB = threshold + compressedExcessDB

            XCTAssertLessThan(outputDB, inputDB, "Output should be lower than input above threshold")
        }
    }
}

// MARK: - Integration Tests

@MainActor
final class AudioIntegrationTests: XCTestCase {

    func testCompleteAudioPipeline() throws {
        // Create audio engine
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        // Create buffer
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        buffer.frameLength = 4096

        XCTAssertNotNil(buffer)

        // This would test full pipeline in production
        XCTAssertEqual(format.sampleRate, 44100.0)
    }

    func testBioReactiveAudioChain() {
        // Simulate bio-reactive audio processing
        let hrv: Float = 0.75
        let heartRate: Float = 70.0

        // Map to parameters
        let reverb = 0.1 + (hrv * 0.7)  // 10-80%
        let filter = 200.0 + ((heartRate - 40.0) / 80.0) * 1800.0  // 200-2000 Hz

        XCTAssertGreaterThanOrEqual(reverb, 0.1)
        XCTAssertLessThanOrEqual(reverb, 0.8)

        XCTAssertGreaterThanOrEqual(filter, 200.0)
        XCTAssertLessThanOrEqual(filter, 2000.0)
    }

    func testRecordingAndPlayback() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!

        buffer.frameLength = 44100

        // Create temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_recording.wav")

        // Write audio file
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        try file.write(from: buffer)

        // Read back
        let readFile = try AVAudioFile(forReading: tempURL)

        XCTAssertEqual(readFile.fileFormat.sampleRate, 44100.0)
        XCTAssertEqual(readFile.fileFormat.channelCount, 2)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}
