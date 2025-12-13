import XCTest
import Accelerate
@testable import Echoelmusic

/// Comprehensive Unit Tests for SIMD DSP Algorithms
/// Tests all vectorized operations in AdvancedDSPEffects
@MainActor
final class DSPSIMDTests: XCTestCase {

    // MARK: - Fast Math Tests

    func testFastLinearToDb() throws {
        // Test linear to dB conversion
        let testValues: [(linear: Float, expectedDb: Float)] = [
            (1.0, 0.0),           // 0 dB
            (0.5, -6.02),         // ~-6 dB
            (0.1, -20.0),         // -20 dB
            (0.01, -40.0),        // -40 dB
            (2.0, 6.02),          // ~+6 dB
        ]

        for (linear, expectedDb) in testValues {
            let result = AdvancedDSPEffects.fastLinearToDb(linear)
            XCTAssertEqual(result, expectedDb, accuracy: 0.1,
                          "fastLinearToDb(\(linear)) should be ~\(expectedDb) dB")
        }
    }

    func testFastDbToLinear() throws {
        // Test dB to linear conversion
        let testValues: [(dB: Float, expectedLinear: Float)] = [
            (0.0, 1.0),           // 0 dB = 1.0
            (-6.0, 0.501),        // ~-6 dB ≈ 0.5
            (-20.0, 0.1),         // -20 dB = 0.1
            (6.0, 1.995),         // ~+6 dB ≈ 2.0
            (-40.0, 0.01),        // -40 dB = 0.01
        ]

        for (dB, expectedLinear) in testValues {
            let result = AdvancedDSPEffects.fastDbToLinear(dB)
            XCTAssertEqual(result, expectedLinear, accuracy: 0.01,
                          "fastDbToLinear(\(dB)) should be ~\(expectedLinear)")
        }
    }

    func testDbConversionRoundTrip() throws {
        // Test that conversions are inverse of each other
        let testValues: [Float] = [0.001, 0.01, 0.1, 0.5, 1.0, 2.0, 10.0]

        for linear in testValues {
            let dB = AdvancedDSPEffects.fastLinearToDb(linear)
            let backToLinear = AdvancedDSPEffects.fastDbToLinear(dB)
            XCTAssertEqual(backToLinear, linear, accuracy: 0.001,
                          "Round-trip conversion should preserve value")
        }
    }

    func testVectorLinearToDb() throws {
        let input: [Float] = [1.0, 0.5, 0.1, 0.01, 2.0]
        let result = AdvancedDSPEffects.vectorLinearToDb(input)

        XCTAssertEqual(result.count, input.count, "Output length should match input")
        XCTAssertEqual(result[0], 0.0, accuracy: 0.1, "1.0 should be 0 dB")
        XCTAssertEqual(result[1], -6.02, accuracy: 0.1, "0.5 should be ~-6 dB")
        XCTAssertEqual(result[2], -20.0, accuracy: 0.1, "0.1 should be -20 dB")
    }

    // MARK: - SIMD Biquad Tests

    func testSIMDBiquadPassthrough() throws {
        // Unity gain coefficients (passthrough)
        let coefficients: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) =
            (1.0, 0.0, 0.0, 0.0, 0.0)

        let input = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let output = AdvancedDSPEffects.simdBiquad(input, coefficients: coefficients)

        XCTAssertEqual(output.count, input.count, "Output length should match input")

        // Check first few samples match (passthrough)
        for i in 2..<min(100, output.count) {
            XCTAssertEqual(output[i], input[i], accuracy: 0.001,
                          "Passthrough filter should preserve signal")
        }
    }

    func testSIMDBiquadLowPass() throws {
        // Low-pass filter coefficients (simplified)
        // These are approximate coefficients for a low-pass at fc=0.1*fs
        let coefficients: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) =
            (0.0675, 0.135, 0.0675, -1.143, 0.413)

        let input = (0..<1024).map { Float(sin(Double($0) * 0.5)) }  // High frequency
        let output = AdvancedDSPEffects.simdBiquad(input, coefficients: coefficients)

        XCTAssertEqual(output.count, input.count, "Output length should match input")

        // Low-pass should attenuate high frequencies
        let inputRMS = sqrt(input.map { $0 * $0 }.reduce(0, +) / Float(input.count))
        let outputRMS = sqrt(output.map { $0 * $0 }.reduce(0, +) / Float(output.count))

        XCTAssertLessThan(outputRMS, inputRMS, "Low-pass should attenuate high frequencies")
    }

    func testSIMDBiquadEmptyInput() throws {
        let coefficients: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) =
            (1.0, 0.0, 0.0, 0.0, 0.0)

        let output = AdvancedDSPEffects.simdBiquad([], coefficients: coefficients)
        XCTAssertTrue(output.isEmpty, "Empty input should produce empty output")
    }

    // MARK: - SIMD Basic Operations Tests

    func testSIMDAbs() throws {
        let input: [Float] = [-1.0, 0.5, -0.5, 1.0, 0.0, -2.5]
        let output = AdvancedDSPEffects.simdAbs(input)

        XCTAssertEqual(output.count, input.count, "Output length should match")

        for i in 0..<input.count {
            XCTAssertEqual(output[i], abs(input[i]), accuracy: 0.0001,
                          "simdAbs should match abs()")
        }
    }

    func testSIMDAdd() throws {
        let a: [Float] = [1.0, 2.0, 3.0, 4.0]
        let b: [Float] = [0.5, 0.5, 0.5, 0.5]
        let output = AdvancedDSPEffects.simdAdd(a, b)

        XCTAssertEqual(output.count, a.count, "Output length should match")

        for i in 0..<a.count {
            XCTAssertEqual(output[i], a[i] + b[i], accuracy: 0.0001,
                          "simdAdd should compute element-wise sum")
        }
    }

    func testSIMDAddMismatchedLengths() throws {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [0.5, 0.5]  // Different length
        let output = AdvancedDSPEffects.simdAdd(a, b)

        // Should return first array unchanged when lengths mismatch
        XCTAssertEqual(output, a, "Mismatched lengths should return first array")
    }

    func testSIMDScalarMultiply() throws {
        let input: [Float] = [1.0, 2.0, 3.0, 4.0]
        let scalar: Float = 0.5
        let output = AdvancedDSPEffects.simdScalarMultiply(input, scalar)

        XCTAssertEqual(output.count, input.count, "Output length should match")

        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i] * scalar, accuracy: 0.0001,
                          "simdScalarMultiply should multiply by scalar")
        }
    }

    func testSIMDMultiplyAdd() throws {
        let a: [Float] = [1.0, 2.0, 3.0, 4.0]
        let b: [Float] = [2.0, 2.0, 2.0, 2.0]
        let c: [Float] = [0.5, 0.5, 0.5, 0.5]
        let output = AdvancedDSPEffects.simdMultiplyAdd(a, b, c)

        XCTAssertEqual(output.count, a.count, "Output length should match")

        for i in 0..<a.count {
            XCTAssertEqual(output[i], a[i] * b[i] + c[i], accuracy: 0.0001,
                          "simdMultiplyAdd should compute a*b+c")
        }
    }

    func testSIMDClamp() throws {
        let input: [Float] = [-2.0, -0.5, 0.0, 0.5, 2.0]
        let output = AdvancedDSPEffects.simdClamp(input, min: -1.0, max: 1.0)

        XCTAssertEqual(output.count, input.count, "Output length should match")

        let expected: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        for i in 0..<input.count {
            XCTAssertEqual(output[i], expected[i], accuracy: 0.0001,
                          "simdClamp should clamp values to range")
        }
    }

    // MARK: - SIMD Metering Tests

    func testSIMDRMS() throws {
        // DC signal of 1.0 should have RMS of 1.0
        let dcSignal = [Float](repeating: 1.0, count: 1024)
        let dcRMS = AdvancedDSPEffects.simdRMS(dcSignal)
        XCTAssertEqual(dcRMS, 1.0, accuracy: 0.001, "DC signal RMS should be 1.0")

        // Sine wave with amplitude 1.0 should have RMS of ~0.707
        let sineSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let sineRMS = AdvancedDSPEffects.simdRMS(sineSignal)
        XCTAssertEqual(sineRMS, 0.707, accuracy: 0.05, "Sine RMS should be ~0.707")

        // Silence should have RMS of 0
        let silence = [Float](repeating: 0.0, count: 1024)
        let silenceRMS = AdvancedDSPEffects.simdRMS(silence)
        XCTAssertEqual(silenceRMS, 0.0, accuracy: 0.0001, "Silence RMS should be 0")
    }

    func testSIMDPeak() throws {
        // Sine wave with amplitude 1.0 should have peak of 1.0
        let sineSignal = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let sinePeak = AdvancedDSPEffects.simdPeak(sineSignal)
        XCTAssertEqual(sinePeak, 1.0, accuracy: 0.01, "Sine peak should be 1.0")

        // Signal with known peak
        var signal: [Float] = [Float](repeating: 0.5, count: 100)
        signal[50] = 2.5  // Peak value
        let peak = AdvancedDSPEffects.simdPeak(signal)
        XCTAssertEqual(peak, 2.5, accuracy: 0.001, "Should detect peak of 2.5")

        // Negative peak
        signal[75] = -3.0
        let negativePeak = AdvancedDSPEffects.simdPeak(signal)
        XCTAssertEqual(negativePeak, 3.0, accuracy: 0.001, "Should detect magnitude of negative peak")
    }

    // MARK: - Performance Tests

    func testSIMDBiquadPerformance() throws {
        let input = (0..<44100).map { Float(sin(Double($0) * 0.1)) }  // 1 second at 44.1kHz
        let coefficients: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) =
            (0.5, 0.0, -0.5, -0.5, 0.25)

        measure {
            _ = AdvancedDSPEffects.simdBiquad(input, coefficients: coefficients)
        }
    }

    func testSIMDRMSPerformance() throws {
        let input = (0..<44100).map { Float(sin(Double($0) * 0.1)) }

        measure {
            for _ in 0..<100 {
                _ = AdvancedDSPEffects.simdRMS(input)
            }
        }
    }

    func testVectorDbConversionPerformance() throws {
        let input = (0..<44100).map { Float.random(in: 0.001...1.0) }

        measure {
            _ = AdvancedDSPEffects.vectorLinearToDb(input)
        }
    }

    // MARK: - Buffer Pool Tests

    func testDSPBufferPoolAcquireRelease() throws {
        let pool = AdvancedDSPEffects.DSPBufferPool.shared

        // Acquire buffer
        let buffer = pool.acquireFloatBuffer(size: 1024)
        XCTAssertEqual(buffer.count, 1024, "Should return buffer of requested size")

        // Release buffer
        pool.releaseFloatBuffer(buffer)
        // No assertion needed - just verify no crash
    }

    func testDSPBufferPoolMultipleAcquire() throws {
        let pool = AdvancedDSPEffects.DSPBufferPool.shared

        // Acquire multiple buffers
        var buffers: [[Float]] = []
        for _ in 0..<10 {
            buffers.append(pool.acquireFloatBuffer(size: 512))
        }

        XCTAssertEqual(buffers.count, 10, "Should acquire 10 buffers")

        // Release all
        for buffer in buffers {
            pool.releaseFloatBuffer(buffer)
        }
    }

    // MARK: - DSP Effects Integration Tests

    func testParametricEQBandProcessing() throws {
        let eq = AdvancedDSPEffects.ParametricEQ(bands: 4, sampleRate: 48000)

        // Configure a band
        eq.bands[0] = AdvancedDSPEffects.ParametricEQ.Band(
            frequency: 1000,
            gain: 6.0,
            q: 1.0,
            type: .bell
        )

        let testSignal = (0..<1024).map { Float(sin(Double($0) * 2.0 * .pi * 1000.0 / 48000.0)) }
        let processed = eq.process(testSignal)

        XCTAssertEqual(processed.count, testSignal.count, "Output length should match")

        // Signal at 1kHz should be boosted
        let inputRMS = sqrt(testSignal.map { $0 * $0 }.reduce(0, +) / Float(testSignal.count))
        let outputRMS = sqrt(processed.map { $0 * $0 }.reduce(0, +) / Float(processed.count))

        XCTAssertGreaterThan(outputRMS, inputRMS * 1.5, "1kHz signal should be boosted by +6dB EQ band")
    }

    func testStereoImagerWidth() throws {
        let imager = AdvancedDSPEffects.StereoImager()

        // Create stereo signal with phase difference
        let left = (0..<1024).map { Float(sin(Double($0) * 0.1)) }
        let right = (0..<1024).map { Float(sin(Double($0) * 0.1 + 0.5)) }

        // Test mono (width = 0)
        imager.width = 0.0
        let (monoL, monoR) = imager.process(left: left, right: right)

        // Mono should have identical L and R
        for i in 0..<min(100, monoL.count) {
            XCTAssertEqual(monoL[i], monoR[i], accuracy: 0.001,
                          "Mono width should produce identical L/R")
        }

        // Test wide (width = 2)
        imager.width = 2.0
        let (wideL, wideR) = imager.process(left: left, right: right)

        // Wide should have more stereo separation
        var correlation: Float = 0
        for i in 0..<min(100, wideL.count) {
            correlation += wideL[i] * wideR[i]
        }
        correlation /= 100

        XCTAssertLessThan(correlation, 0.8, "Wide stereo should have less L/R correlation")
    }

    func testMultibandCompressorBandSplit() throws {
        let compressor = AdvancedDSPEffects.MultibandCompressor(bands: 4, sampleRate: 48000)

        let testSignal = (0..<2048).map { Float(sin(Double($0) * 0.1)) * 1.5 }  // Hot signal
        let compressed = compressor.process(testSignal)

        XCTAssertEqual(compressed.count, testSignal.count, "Output length should match")

        // Compression should reduce peaks
        let inputPeak = testSignal.map { abs($0) }.max() ?? 0
        let outputPeak = compressed.map { abs($0) }.max() ?? 0

        XCTAssertLessThan(outputPeak, inputPeak, "Multiband compressor should reduce peaks")
    }

    func testConvolutionReverbMix() throws {
        let reverb = AdvancedDSPEffects.ConvolutionReverb(sampleRate: 48000)

        // Create simple impulse response (exponential decay)
        let ir = (0..<500).map { Float(exp(-Float($0) / 50.0)) }
        reverb.loadImpulseResponse(ir)

        // Test dry (mix = 0)
        let impulse = (0..<1024).map { $0 == 0 ? Float(1.0) : Float(0.0) }
        let dry = reverb.process(impulse, mix: 0.0)

        XCTAssertEqual(dry[0], 1.0, accuracy: 0.01, "Dry should pass through impulse")

        // Test wet (mix = 1)
        let wet = reverb.process(impulse, mix: 1.0)

        // Wet should have reverb tail
        let tailEnergy = wet[100..<200].map { $0 * $0 }.reduce(0, +)
        XCTAssertGreaterThan(tailEnergy, 0.001, "Wet should have reverb tail")
    }
}

// MARK: - DSP Accuracy Tests

@MainActor
final class DSPAccuracyTests: XCTestCase {

    func testLinkwitzRileyCrossover() throws {
        // Test Linkwitz-Riley crossover characteristics
        // LR24 should have -6dB at crossover frequency and flat summed response

        let sampleRate: Float = 48000
        let crossoverFreq: Float = 1000

        // Generate test tone at crossover frequency
        let testTone = (0..<4096).map {
            Float(sin(Double($0) * 2.0 * .pi * Double(crossoverFreq) / Double(sampleRate)))
        }

        // Process through LR24 filter (using biquad cascade)
        // b0, b1, b2, a1, a2 for Butterworth LPF (one stage)
        let omega = 2.0 * Float.pi * crossoverFreq / sampleRate
        let sn = sin(omega)
        let cs = cos(omega)
        let alpha = sn / sqrt(2.0)  // Q = 0.707 for Butterworth

        let b0 = (1.0 - cs) / 2.0
        let b1 = 1.0 - cs
        let b2 = (1.0 - cs) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cs
        let a2 = 1.0 - alpha

        let coefficients = (
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )

        let filtered = AdvancedDSPEffects.simdBiquad(testTone, coefficients: coefficients)

        // At crossover, single Butterworth stage should be -3dB
        let inputRMS = AdvancedDSPEffects.simdRMS(testTone)
        let outputRMS = AdvancedDSPEffects.simdRMS(Array(filtered.suffix(2048)))  // Skip transient
        let gainDb = 20.0 * log10(outputRMS / inputRMS)

        XCTAssertEqual(gainDb, -3.0, accuracy: 0.5, "Butterworth at fc should be -3dB")
    }

    func testFrequencyResponseAccuracy() throws {
        // Test that SIMD biquad matches expected frequency response
        let sampleRate: Float = 48000
        let frequencies: [Float] = [100, 500, 1000, 5000, 10000]

        // Low-pass at 2kHz
        let fc: Float = 2000
        let omega = 2.0 * Float.pi * fc / sampleRate
        let sn = sin(omega)
        let cs = cos(omega)
        let alpha = sn / sqrt(2.0)

        let b0 = (1.0 - cs) / 2.0
        let b1 = 1.0 - cs
        let b2 = (1.0 - cs) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cs
        let a2 = 1.0 - alpha

        let coefficients = (
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )

        for freq in frequencies {
            let testTone = (0..<4096).map {
                Float(sin(Double($0) * 2.0 * .pi * Double(freq) / Double(sampleRate)))
            }

            let filtered = AdvancedDSPEffects.simdBiquad(testTone, coefficients: coefficients)

            let inputRMS = AdvancedDSPEffects.simdRMS(testTone)
            let outputRMS = AdvancedDSPEffects.simdRMS(Array(filtered.suffix(2048)))
            let gainDb = 20.0 * log10(outputRMS / inputRMS)

            // Below cutoff should be ~0dB, above cutoff should attenuate
            if freq < fc {
                XCTAssertGreaterThan(gainDb, -3.0, "\(freq)Hz should be in passband")
            } else if freq > fc * 2 {
                XCTAssertLessThan(gainDb, -6.0, "\(freq)Hz should be attenuated")
            }
        }
    }
}
