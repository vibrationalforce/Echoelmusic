// EchoelVDSPKitTests.swift
// Tests for EchoelVDSPKit — Real FFT, Convolution, Biquad, Decimator

import XCTest
@testable import Echoelmusic

final class EchoelVDSPKitTests: XCTestCase {

    // MARK: - Real FFT

    func testRealFFTInit() {
        let fft = EchoelRealFFT(size: 1024)
        XCTAssertEqual(fft.size, 1024)
        XCTAssertEqual(fft.log2n, 10)
    }

    func testRealFFTSineWaveDetection() {
        let fft = EchoelRealFFT(size: 2048, window: .hann)
        let sampleRate: Float = 48000
        let frequency: Float = 440.0

        // Generate 440Hz sine wave
        var signal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            signal[i] = sin(2.0 * Float.pi * frequency * Float(i) / sampleRate)
        }

        let (magnitudes, _) = fft.forward(signal)
        XCTAssertFalse(magnitudes.isEmpty)

        // Find peak bin
        var maxVal: Float = 0
        var maxIdx = 0
        for i in 0..<magnitudes.count {
            if magnitudes[i] > maxVal {
                maxVal = magnitudes[i]
                maxIdx = i
            }
        }

        let detectedFreq = fft.frequencyForBin(maxIdx, sampleRate: sampleRate)
        XCTAssertEqual(detectedFreq, frequency, accuracy: 30.0) // Within 30Hz tolerance
    }

    func testPowerSpectrumNonNegative() {
        let fft = EchoelRealFFT(size: 1024)
        let signal = (0..<1024).map { Float.random(in: -1...1) * Float($0) / 1024.0 }
        let power = fft.powerSpectrum(signal)
        XCTAssertFalse(power.isEmpty)
        for val in power {
            XCTAssertGreaterThanOrEqual(val, 0)
        }
    }

    func testDifferentWindowTypes() {
        for windowType in EchoelRealFFT.WindowType.allCases {
            let fft = EchoelRealFFT(size: 512, window: windowType)
            let signal = [Float](repeating: 0.5, count: 512)
            let power = fft.powerSpectrum(signal)
            XCTAssertEqual(power.count, 256, "Window \(windowType) failed")
        }
    }

    func testBlackmanWindowBetterSidelobes() {
        let sampleRate: Float = 48000
        let freq: Float = 1000.0
        var signal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            signal[i] = sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
        }

        let hannFFT = EchoelRealFFT(size: 2048, window: .hann)
        let blackmanFFT = EchoelRealFFT(size: 2048, window: .blackman)

        let hannPower = hannFFT.powerSpectrum(signal)
        let blackmanPower = blackmanFFT.powerSpectrum(signal)

        // Find peak bin
        let peakBin = Int(freq / (sampleRate / 2048.0))
        let farBin = min(peakBin + 100, hannPower.count - 1)

        // Blackman should have lower sidelobes far from peak
        XCTAssertLessThanOrEqual(blackmanPower[farBin], hannPower[farBin] * 1.1)
    }

    // MARK: - Convolution

    func testConvolutionIdentity() {
        // Delta function kernel → output = input
        let kernel: [Float] = [1.0]
        let conv = EchoelConvolution(kernel: kernel)
        let input: [Float] = [1, 2, 3, 4, 5]
        let output = conv.process(input)
        XCTAssertEqual(output.count, input.count)
        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i], accuracy: 0.001)
        }
    }

    func testLowpassKernelSum() {
        let kernel = EchoelConvolution.lowpassKernel(cutoffHz: 1000, sampleRate: 48000, taps: 63)
        XCTAssertEqual(kernel.count, 63)
        var sum: Float = 0
        for val in kernel { sum += val }
        XCTAssertEqual(sum, 1.0, accuracy: 0.01) // Normalized
    }

    func testHighpassKernel() {
        let kernel = EchoelConvolution.highpassKernel(cutoffHz: 5000, sampleRate: 48000, taps: 63)
        XCTAssertEqual(kernel.count, 63)
    }

    func testBandpassKernel() {
        let kernel = EchoelConvolution.bandpassKernel(lowHz: 200, highHz: 2000, sampleRate: 48000, taps: 63)
        XCTAssertEqual(kernel.count, 63)
    }

    func testConvolutionStreaming() {
        let kernel: [Float] = [0.25, 0.5, 0.25]
        let conv = EchoelConvolution(kernel: kernel)

        // Process two consecutive blocks
        let block1: [Float] = [1, 0, 0, 0]
        let block2: [Float] = [0, 0, 0, 1]

        let out1 = conv.process(block1)
        let out2 = conv.process(block2)

        XCTAssertEqual(out1.count, 4)
        XCTAssertEqual(out2.count, 4)
    }

    // MARK: - Biquad Cascade

    func testBiquadCascadePassthrough() {
        let biquad = EchoelBiquadCascade(sectionCount: 2)
        let input: [Float] = [1, 0, -1, 0, 1]
        let output = biquad.process(input)
        XCTAssertEqual(output.count, 5)
        // Default is passthrough — should be roughly identity
        for i in 0..<input.count {
            XCTAssertEqual(output[i], input[i], accuracy: 0.01)
        }
    }

    func testBiquadLowpass() {
        let biquad = EchoelBiquadCascade(sectionCount: 4)
        biquad.setLowpass(section: 0, frequency: 1000, q: 0.707, sampleRate: 48000)

        // Generate high frequency signal
        var input = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            input[i] = sin(2.0 * Float.pi * 10000.0 * Float(i) / 48000.0)
        }

        let output = biquad.process(input)
        XCTAssertEqual(output.count, 256)

        // RMS of output should be lower than input (filtered)
        let inputRMS = sqrt(input.map { $0 * $0 }.reduce(0, +) / Float(input.count))
        let outputRMS = sqrt(output.map { $0 * $0 }.reduce(0, +) / Float(output.count))
        XCTAssertLessThan(outputRMS, inputRMS)
    }

    func testBiquadReset() {
        let biquad = EchoelBiquadCascade(sectionCount: 2)
        biquad.setLowpass(section: 0, frequency: 500, sampleRate: 48000)
        let _ = biquad.process([1, 0, 0, 0])
        biquad.reset()
        let output = biquad.process([0, 0, 0, 0])
        // After reset, all zeros in should give all zeros out
        for val in output {
            XCTAssertEqual(val, 0, accuracy: 0.001)
        }
    }

    func testBiquadParametricEQ() {
        let biquad = EchoelBiquadCascade(sectionCount: 4)
        biquad.setParametricEQ(section: 0, frequency: 1000, gain: 6.0, q: 1.0, sampleRate: 48000)
        biquad.setParametricEQ(section: 1, frequency: 5000, gain: -3.0, q: 0.7, sampleRate: 48000)

        let input = [Float](repeating: 0.5, count: 128)
        let output = biquad.process(input)
        XCTAssertEqual(output.count, 128)
    }

    // MARK: - Decimator

    func testDecimatorOutput() {
        let decimator = EchoelDecimator(factor: 4)
        let input = [Float](repeating: 1.0, count: 256)
        let output = decimator.process(input)
        XCTAssertEqual(output.count, 64)
    }

    func testDecimatorFactorTwo() {
        let decimator = EchoelDecimator(factor: 2)
        var input = [Float](repeating: 0, count: 100)
        for i in 0..<100 { input[i] = Float(i) }
        let output = decimator.process(input)
        XCTAssertEqual(output.count, 50)
    }

    // MARK: - Spectral Analyzer

    func testSpectralAnalyzerBandPower() {
        let analyzer = EchoelSpectralAnalyzer(size: 2048, sampleRate: 48000)
        var signal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            signal[i] = sin(2.0 * Float.pi * 440.0 * Float(i) / 48000.0)
        }

        let power = analyzer.bandPower(signal, band: 400...500)
        let outsidePower = analyzer.bandPower(signal, band: 2000...3000)
        XCTAssertGreaterThan(power, outsidePower)
    }

    func testSpectralCentroid() {
        let analyzer = EchoelSpectralAnalyzer(size: 2048, sampleRate: 48000)

        // Low frequency signal
        var lowSignal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            lowSignal[i] = sin(2.0 * Float.pi * 200.0 * Float(i) / 48000.0)
        }

        // High frequency signal
        var highSignal = [Float](repeating: 0, count: 2048)
        for i in 0..<2048 {
            highSignal[i] = sin(2.0 * Float.pi * 5000.0 * Float(i) / 48000.0)
        }

        let lowCentroid = analyzer.spectralCentroid(lowSignal)
        let highCentroid = analyzer.spectralCentroid(highSignal)
        XCTAssertLessThan(lowCentroid, highCentroid)
    }

    func testDominantFrequency() {
        let analyzer = EchoelSpectralAnalyzer(size: 4096, sampleRate: 48000, window: .blackman)
        var signal = [Float](repeating: 0, count: 4096)
        let targetFreq: Float = 1000.0
        for i in 0..<4096 {
            signal[i] = sin(2.0 * Float.pi * targetFreq * Float(i) / 48000.0)
        }

        let detected = analyzer.dominantFrequency(signal, band: 500...1500)
        XCTAssertEqual(detected, targetFreq, accuracy: 20.0)
    }

    // MARK: - Performance

    func testRealFFTPerformance() {
        let fft = EchoelRealFFT(size: 2048, window: .blackman)
        let signal = (0..<2048).map { _ in Float.random(in: -1...1) }

        measure {
            for _ in 0..<100 {
                let _ = fft.powerSpectrum(signal)
            }
        }
    }

    func testConvolutionPerformance() {
        let kernel = EchoelConvolution.lowpassKernel(cutoffHz: 1000, sampleRate: 48000, taps: 127)
        let conv = EchoelConvolution(kernel: kernel)
        let input = (0..<512).map { _ in Float.random(in: -1...1) }

        measure {
            for _ in 0..<100 {
                let _ = conv.process(input)
            }
        }
    }

    func testBiquadCascadePerformance() {
        let biquad = EchoelBiquadCascade(sectionCount: 4)
        biquad.setLowpass(section: 0, frequency: 200, sampleRate: 48000)
        biquad.setParametricEQ(section: 1, frequency: 1000, gain: 3, q: 1.0, sampleRate: 48000)
        biquad.setHighpass(section: 2, frequency: 50, sampleRate: 48000)

        let input = (0..<512).map { _ in Float.random(in: -1...1) }

        measure {
            for _ in 0..<1000 {
                let _ = biquad.process(input)
            }
        }
    }
}
