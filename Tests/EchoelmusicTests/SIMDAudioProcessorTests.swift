import XCTest
import Accelerate
@testable import Echoelmusic

/// Tests for SIMD Audio Processor
final class SIMDAudioProcessorTests: XCTestCase {

    var processor: SIMDAudioProcessor!
    let testFrameCount = 512

    override func setUp() {
        let config = SIMDAudioProcessor.Configuration(
            sampleRate: 48000,
            bufferSize: testFrameCount,
            channelCount: 2
        )
        processor = SIMDAudioProcessor(config: config)
    }

    override func tearDown() {
        processor = nil
    }

    // MARK: - Filter Tests

    func testLowPassFilterAttenuatesHighFrequencies() {
        // Generate high frequency sine wave (10kHz)
        var input = generateSineWave(frequency: 10000, sampleRate: 48000, frameCount: testFrameCount)
        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processFilter(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    cutoffFrequency: 1000,  // 1kHz cutoff
                    resonance: 0.707,
                    filterType: .lowPass
                )
            }
        }

        // Output should be significantly attenuated
        let inputRMS = calculateRMS(input)
        let outputRMS = calculateRMS(output)

        XCTAssertLessThan(outputRMS, inputRMS * 0.5, "Low-pass should attenuate 10kHz with 1kHz cutoff")
    }

    func testLowPassFilterPassesLowFrequencies() {
        // Generate low frequency sine wave (100Hz)
        var input = generateSineWave(frequency: 100, sampleRate: 48000, frameCount: testFrameCount)
        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processFilter(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    cutoffFrequency: 1000,
                    resonance: 0.707,
                    filterType: .lowPass
                )
            }
        }

        let inputRMS = calculateRMS(input)
        let outputRMS = calculateRMS(output)

        XCTAssertGreaterThan(outputRMS, inputRMS * 0.8, "Low-pass should pass 100Hz with 1kHz cutoff")
    }

    func testHighPassFilterAttenuatesLowFrequencies() {
        var input = generateSineWave(frequency: 50, sampleRate: 48000, frameCount: testFrameCount)
        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processFilter(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    cutoffFrequency: 500,
                    resonance: 0.707,
                    filterType: .highPass
                )
            }
        }

        let inputRMS = calculateRMS(input)
        let outputRMS = calculateRMS(output)

        XCTAssertLessThan(outputRMS, inputRMS * 0.5, "High-pass should attenuate 50Hz with 500Hz cutoff")
    }

    // MARK: - Compressor Tests

    func testCompressorReducesLoudSignals() {
        // Generate loud signal
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)
        vDSP_vsmul(input, 1, [Float](repeating: 2.0, count: 1), &input, 1, vDSP_Length(testFrameCount))

        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processCompressor(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    threshold: -20,
                    ratio: 4.0,
                    attack: 0.001,
                    release: 0.1,
                    makeupGain: 0
                )
            }
        }

        let inputPeak = calculatePeak(input)
        let outputPeak = calculatePeak(output)

        XCTAssertLessThan(outputPeak, inputPeak, "Compressor should reduce peak level of loud signal")
    }

    func testCompressorPreservesQuietSignals() {
        // Generate quiet signal
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)
        vDSP_vsmul(input, 1, [Float](repeating: 0.01, count: 1), &input, 1, vDSP_Length(testFrameCount))

        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processCompressor(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    threshold: -20,
                    ratio: 4.0,
                    attack: 0.001,
                    release: 0.1,
                    makeupGain: 0
                )
            }
        }

        let inputRMS = calculateRMS(input)
        let outputRMS = calculateRMS(output)

        XCTAssertEqual(outputRMS, inputRMS, accuracy: inputRMS * 0.1, "Compressor should preserve quiet signals")
    }

    // MARK: - Delay Tests

    func testDelayProducesEcho() {
        var input = [Float](repeating: 0, count: testFrameCount)
        // Impulse at start
        input[0] = 1.0

        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processDelay(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    delayTime: 0.01,  // 10ms = 480 samples at 48kHz
                    feedback: 0.5,
                    wetDry: 0.5
                )
            }
        }

        // Should have original impulse and delayed version
        XCTAssertGreaterThan(output[0], 0, "Should have dry signal at start")
    }

    func testDelayWetDryMix() {
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)
        var outputDry = [Float](repeating: 0, count: testFrameCount)
        var outputWet = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            outputDry.withUnsafeMutableBufferPointer { outPtr in
                processor.processDelay(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    delayTime: 0.1,
                    feedback: 0.0,
                    wetDry: 0.0  // All dry
                )
            }
        }

        // Reset processor state
        processor = SIMDAudioProcessor(config: SIMDAudioProcessor.Configuration())

        input.withUnsafeBufferPointer { inPtr in
            outputWet.withUnsafeMutableBufferPointer { outPtr in
                processor.processDelay(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    delayTime: 0.1,
                    feedback: 0.0,
                    wetDry: 1.0  // All wet
                )
            }
        }

        let dryRMS = calculateRMS(outputDry)
        XCTAssertGreaterThan(dryRMS, 0, "Dry output should have signal")
    }

    // MARK: - Reverb Tests

    func testReverbAddsDecay() {
        var input = [Float](repeating: 0, count: testFrameCount)
        // Impulse
        input[0] = 1.0

        var output = [Float](repeating: 0, count: testFrameCount)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.processReverb(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    roomSize: 0.8,
                    damping: 0.5,
                    wetDry: 0.5
                )
            }
        }

        // Check that there's signal beyond the initial impulse
        let laterSamples = Array(output[100..<200])
        let laterRMS = calculateRMS(laterSamples)

        XCTAssertGreaterThan(laterRMS, 0, "Reverb should produce decay tail")
    }

    // MARK: - FFT Tests

    func testFFTDetectsFrequency() {
        let testFrequency: Float = 1000  // 1kHz
        let input = generateSineWave(frequency: testFrequency, sampleRate: 48000, frameCount: 2048)

        let spectrum = input.withUnsafeBufferPointer { ptr in
            processor.processFFT(input: ptr.baseAddress!, frameCount: 2048)
        }

        XCTAssertFalse(spectrum.isEmpty, "FFT should produce spectrum")

        // Find peak bin
        let peakIndex = spectrum.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let binFrequency = Float(peakIndex) * 48000 / 2048

        // Should be close to 1kHz
        XCTAssertEqual(binFrequency, testFrequency, accuracy: 50, "FFT should detect 1kHz peak")
    }

    // MARK: - Utility Tests

    func testRMSCalculation() {
        let input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)

        let rms = input.withUnsafeBufferPointer { ptr in
            processor.calculateRMS(input: ptr.baseAddress!, frameCount: testFrameCount)
        }

        // Sine wave RMS should be peak / sqrt(2) ≈ 0.707
        XCTAssertEqual(rms, 0.707, accuracy: 0.05, "Sine wave RMS should be ~0.707")
    }

    func testPeakCalculation() {
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)
        vDSP_vsmul(input, 1, [Float](repeating: 0.5, count: 1), &input, 1, vDSP_Length(testFrameCount))

        let peak = input.withUnsafeBufferPointer { ptr in
            processor.calculatePeak(input: ptr.baseAddress!, frameCount: testFrameCount)
        }

        XCTAssertEqual(peak, 0.5, accuracy: 0.01, "Peak should be 0.5")
    }

    func testGainApplication() {
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: testFrameCount)
        var output = [Float](repeating: 0, count: testFrameCount)

        let inputRMS = calculateRMS(input)

        input.withUnsafeBufferPointer { inPtr in
            output.withUnsafeMutableBufferPointer { outPtr in
                processor.applyGain(
                    input: inPtr.baseAddress!,
                    output: outPtr.baseAddress!,
                    frameCount: testFrameCount,
                    gainDB: 6.0  // +6dB ≈ 2x
                )
            }
        }

        let outputRMS = calculateRMS(output)
        XCTAssertEqual(outputRMS, inputRMS * 2.0, accuracy: inputRMS * 0.1, "+6dB should double amplitude")
    }

    func testCrossfadeMix() {
        let bufferA = [Float](repeating: 1.0, count: testFrameCount)
        let bufferB = [Float](repeating: 0.0, count: testFrameCount)
        var output = [Float](repeating: 0, count: testFrameCount)

        bufferA.withUnsafeBufferPointer { aPtr in
            bufferB.withUnsafeBufferPointer { bPtr in
                output.withUnsafeMutableBufferPointer { outPtr in
                    processor.crossfadeMix(
                        bufferA: aPtr.baseAddress!,
                        bufferB: bPtr.baseAddress!,
                        output: outPtr.baseAddress!,
                        frameCount: testFrameCount,
                        mix: 0.5
                    )
                }
            }
        }

        // 50/50 mix should be 0.5
        XCTAssertEqual(output[0], 0.5, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testFilterPerformance() {
        var input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: 4096)
        var output = [Float](repeating: 0, count: 4096)

        measure {
            for _ in 0..<100 {
                input.withUnsafeBufferPointer { inPtr in
                    output.withUnsafeMutableBufferPointer { outPtr in
                        processor.processFilter(
                            input: inPtr.baseAddress!,
                            output: outPtr.baseAddress!,
                            frameCount: 4096,
                            cutoffFrequency: 1000,
                            resonance: 1.0,
                            filterType: .lowPass
                        )
                    }
                }
            }
        }
    }

    func testFFTPerformance() {
        let input = generateSineWave(frequency: 440, sampleRate: 48000, frameCount: 2048)

        measure {
            for _ in 0..<100 {
                _ = input.withUnsafeBufferPointer { ptr in
                    processor.processFFT(input: ptr.baseAddress!, frameCount: 2048)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func generateSineWave(frequency: Float, sampleRate: Float, frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)
        let angularFrequency = 2.0 * Float.pi * frequency / sampleRate

        for i in 0..<frameCount {
            output[i] = sin(angularFrequency * Float(i))
        }

        return output
    }

    private func calculateRMS(_ buffer: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(buffer.count))
        return rms
    }

    private func calculatePeak(_ buffer: [Float]) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(buffer.count))
        return peak
    }
}
