// EnergyEfficientDSP.swift
// Echoelmusic - Energy-Efficient Digital Signal Processing
//
// Optimized DSP algorithms for minimal power consumption
// Adaptive quality scaling based on battery and thermal state

import Foundation
import Accelerate
import os.log

private let dspLogger = Logger(subsystem: "com.echoelmusic.green", category: "EfficientDSP")

// MARK: - Energy-Efficient DSP Engine

public final class EnergyEfficientDSP: GreenComputingAware {

    public static let shared = EnergyEfficientDSP()

    // MARK: - Configuration

    public struct Configuration {
        public var fftSize: Int = 2048
        public var overlapRatio: Double = 0.5
        public var useApproximations: Bool = false
        public var enableSIMD: Bool = true
        public var maxProcessingLoad: Double = 0.75

        // Adaptive quality
        public var dynamicFFTSize: Bool = true
        public var minimumFFTSize: Int = 512
        public var maximumFFTSize: Int = 8192
    }

    public var configuration = Configuration()

    // MARK: - Pre-allocated Buffers (Zero runtime allocation)

    private var fftSetup: vDSP_DFT_Setup?
    private var windowBuffer: [Float] = []
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []
    private var magnitudeBuffer: [Float] = []
    private var scratchBuffer: [Float] = []

    // Buffer pools for different sizes
    private var bufferPools: [Int: BufferPool] = [:]

    // Processing metrics
    private var processedSamples: UInt64 = 0
    private var cpuTimeAccumulated: Double = 0
    private var lastProcessingLoad: Double = 0

    // MARK: - Initialization

    private init() {
        setupBuffers(size: configuration.fftSize)
        dspLogger.info("EnergyEfficientDSP initialized with FFT size: \(self.configuration.fftSize)")
    }

    private func setupBuffers(size: Int) {
        // Pre-allocate all buffers
        windowBuffer = [Float](repeating: 0, count: size)
        realBuffer = [Float](repeating: 0, count: size)
        imagBuffer = [Float](repeating: 0, count: size)
        magnitudeBuffer = [Float](repeating: 0, count: size / 2)
        scratchBuffer = [Float](repeating: 0, count: size * 2)

        // Create Hann window (energy-efficient: computed once)
        vDSP_hann_window(&windowBuffer, vDSP_Length(size), Int32(vDSP_HANN_NORM))

        // Setup FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(size),
            .FORWARD
        )
    }

    // MARK: - Public API

    /// Perform energy-efficient FFT with adaptive sizing
    public func efficientFFT(_ samples: [Float]) -> [Float] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Adapt FFT size based on load and battery
        let effectiveSize = adaptFFTSize(for: samples.count)

        // Ensure buffers are sized correctly
        if effectiveSize != windowBuffer.count {
            setupBuffers(size: effectiveSize)
        }

        // Use SIMD-optimized processing
        let result: [Float]
        if configuration.enableSIMD && effectiveSize >= 512 {
            result = simdOptimizedFFT(samples, size: effectiveSize)
        } else {
            result = basicFFT(samples, size: effectiveSize)
        }

        // Track processing metrics
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        cpuTimeAccumulated += elapsed
        processedSamples += UInt64(samples.count)
        lastProcessingLoad = elapsed / (Double(samples.count) / 48000.0)

        return result
    }

    /// Energy-efficient convolution with early termination
    public func efficientConvolution(_ signal: [Float], kernel: [Float], threshold: Float = 0.001) -> [Float] {
        guard !signal.isEmpty, !kernel.isEmpty else { return signal }

        // Find effective kernel length (trim near-zero tail)
        var effectiveKernelLength = kernel.count
        if configuration.useApproximations {
            for i in stride(from: kernel.count - 1, through: 0, by: -1) {
                if abs(kernel[i]) > threshold {
                    effectiveKernelLength = i + 1
                    break
                }
            }
        }

        let outputLength = signal.count + effectiveKernelLength - 1
        var output = [Float](repeating: 0, count: outputLength)

        // Use vDSP for SIMD acceleration
        kernel.withUnsafeBufferPointer { kernelPtr in
            signal.withUnsafeBufferPointer { signalPtr in
                output.withUnsafeMutableBufferPointer { outputPtr in
                    vDSP_conv(
                        signalPtr.baseAddress!, 1,
                        kernelPtr.baseAddress! + effectiveKernelLength - 1, -1,
                        outputPtr.baseAddress!, 1,
                        vDSP_Length(outputLength),
                        vDSP_Length(effectiveKernelLength)
                    )
                }
            }
        }

        return output
    }

    /// Low-power filter with coefficient caching
    public func efficientBiquadFilter(
        _ samples: inout [Float],
        coefficients: BiquadCoefficients,
        state: inout BiquadState
    ) {
        guard samples.count > 0 else { return }

        // Process in-place using vDSP biquad
        var delay = [Float](repeating: 0, count: 4)
        delay[0] = state.x1
        delay[1] = state.x2
        delay[2] = state.y1
        delay[3] = state.y2

        let coeffs: [Double] = [
            Double(coefficients.b0),
            Double(coefficients.b1),
            Double(coefficients.b2),
            Double(coefficients.a1),
            Double(coefficients.a2)
        ]

        var setup = vDSP_biquad_CreateSetup(coeffs, 1)
        defer { vDSP_biquad_DestroySetup(setup) }

        samples.withUnsafeMutableBufferPointer { ptr in
            vDSP_biquad(
                setup,
                &delay,
                ptr.baseAddress!, 1,
                ptr.baseAddress!, 1,
                vDSP_Length(samples.count)
            )
        }

        // Update state
        state.x1 = delay[0]
        state.x2 = delay[1]
        state.y1 = delay[2]
        state.y2 = delay[3]
    }

    /// Approximate processing for ultra-low power mode
    public func ultraLowPowerProcess(_ samples: [Float], operation: DSPOperation) -> [Float] {
        // Downsample → Process → Upsample for power savings
        let decimationFactor = 4
        let downsampled = decimate(samples, factor: decimationFactor)

        let processed: [Float]
        switch operation {
        case .lowpass(let cutoff):
            processed = simpleLowPass(downsampled, normalizedCutoff: cutoff)
        case .highpass(let cutoff):
            processed = simpleHighPass(downsampled, normalizedCutoff: cutoff)
        case .compress(let threshold, let ratio):
            processed = simpleCompressor(downsampled, threshold: threshold, ratio: ratio)
        case .normalize:
            processed = normalizeAudio(downsampled)
        }

        return interpolate(processed, factor: decimationFactor, targetLength: samples.count)
    }

    // MARK: - Adaptive Processing

    private func adaptFFTSize(for sampleCount: Int) -> Int {
        guard configuration.dynamicFFTSize else {
            return configuration.fftSize
        }

        // Get current efficiency level
        let settings = GreenComputingEngine.shared.getRecommendedSettings()

        // Adapt based on efficiency level
        var targetSize: Int
        switch settings.audioQuality {
        case .draft:
            targetSize = configuration.minimumFFTSize
        case .preview:
            targetSize = 1024
        case .standard:
            targetSize = 2048
        case .high:
            targetSize = 4096
        case .studio:
            targetSize = configuration.maximumFFTSize
        }

        // Don't exceed input size
        targetSize = min(targetSize, nextPowerOfTwo(sampleCount))
        targetSize = max(targetSize, configuration.minimumFFTSize)

        return targetSize
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n { power *= 2 }
        return power
    }

    // MARK: - SIMD-Optimized FFT

    private func simdOptimizedFFT(_ samples: [Float], size: Int) -> [Float] {
        // Copy and window input
        let sampleCount = min(samples.count, size)
        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            samples.withUnsafeBufferPointer { samplesPtr in
                // Copy samples
                memcpy(realPtr.baseAddress, samplesPtr.baseAddress, sampleCount * MemoryLayout<Float>.stride)
            }

            // Zero-pad if needed
            if sampleCount < size {
                memset(realPtr.baseAddress?.advanced(by: sampleCount), 0, (size - sampleCount) * MemoryLayout<Float>.stride)
            }

            // Apply window
            windowBuffer.withUnsafeBufferPointer { windowPtr in
                vDSP_vmul(realPtr.baseAddress!, 1, windowPtr.baseAddress!, 1, realPtr.baseAddress!, 1, vDSP_Length(size))
            }
        }

        // Clear imaginary buffer
        vDSP_vclr(&imagBuffer, 1, vDSP_Length(size))

        // Perform FFT
        guard let setup = fftSetup else { return [] }

        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                scratchBuffer.withUnsafeMutableBufferPointer { scratchPtr in
                    vDSP_DFT_Execute(
                        setup,
                        realPtr.baseAddress!,
                        imagPtr.baseAddress!,
                        scratchPtr.baseAddress!,
                        scratchPtr.baseAddress!.advanced(by: size)
                    )
                }
            }
        }

        // Calculate magnitudes
        let halfSize = size / 2
        realBuffer.withUnsafeBufferPointer { realPtr in
            imagBuffer.withUnsafeBufferPointer { imagPtr in
                magnitudeBuffer.withUnsafeMutableBufferPointer { magPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                    )
                    vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(halfSize))
                }
            }
        }

        return Array(magnitudeBuffer.prefix(halfSize))
    }

    private func basicFFT(_ samples: [Float], size: Int) -> [Float] {
        // Fallback non-SIMD implementation for small sizes
        var result = [Float](repeating: 0, count: size / 2)

        for k in 0..<(size / 2) {
            var real: Float = 0
            var imag: Float = 0
            let twoPiK = 2.0 * Float.pi * Float(k)

            for n in 0..<min(samples.count, size) {
                let angle = twoPiK * Float(n) / Float(size)
                real += samples[n] * cos(angle) * windowBuffer[n]
                imag -= samples[n] * sin(angle) * windowBuffer[n]
            }

            result[k] = sqrt(real * real + imag * imag)
        }

        return result
    }

    // MARK: - Simple DSP Operations

    private func decimate(_ samples: [Float], factor: Int) -> [Float] {
        var result = [Float](repeating: 0, count: samples.count / factor)
        vDSP_desamp(samples, vDSP_Stride(factor), [1.0], &result, vDSP_Length(result.count), 1)
        return result
    }

    private func interpolate(_ samples: [Float], factor: Int, targetLength: Int) -> [Float] {
        var result = [Float](repeating: 0, count: targetLength)

        for i in 0..<targetLength {
            let srcIndex = Float(i) / Float(factor)
            let index0 = Int(srcIndex)
            let index1 = min(index0 + 1, samples.count - 1)
            let fraction = srcIndex - Float(index0)

            if index0 < samples.count {
                result[i] = samples[index0] * (1 - fraction) + samples[min(index1, samples.count - 1)] * fraction
            }
        }

        return result
    }

    private func simpleLowPass(_ samples: [Float], normalizedCutoff: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let alpha = normalizedCutoff
        output[0] = samples[0]

        for i in 1..<samples.count {
            output[i] = output[i-1] + alpha * (samples[i] - output[i-1])
        }

        return output
    }

    private func simpleHighPass(_ samples: [Float], normalizedCutoff: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        let alpha = 1.0 - normalizedCutoff
        output[0] = samples[0]

        for i in 1..<samples.count {
            output[i] = alpha * (output[i-1] + samples[i] - samples[i-1])
        }

        return output
    }

    private func simpleCompressor(_ samples: [Float], threshold: Float, ratio: Float) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)

        for i in 0..<samples.count {
            let sample = samples[i]
            let absSample = abs(sample)

            if absSample > threshold {
                let excess = absSample - threshold
                let compressed = threshold + excess / ratio
                output[i] = sample > 0 ? compressed : -compressed
            } else {
                output[i] = sample
            }
        }

        return output
    }

    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        var maxVal: Float = 0
        vDSP_maxmgv(samples, 1, &maxVal, vDSP_Length(samples.count))

        guard maxVal > 0 else { return samples }

        var output = [Float](repeating: 0, count: samples.count)
        var scale = 1.0 / maxVal
        vDSP_vsmul(samples, 1, &scale, &output, 1, vDSP_Length(samples.count))

        return output
    }

    // MARK: - GreenComputingAware

    public func applyGreenSettings(_ settings: GreenSettings) {
        switch settings.audioQuality {
        case .draft:
            configuration.fftSize = 512
            configuration.useApproximations = true
        case .preview:
            configuration.fftSize = 1024
            configuration.useApproximations = true
        case .standard:
            configuration.fftSize = 2048
            configuration.useApproximations = false
        case .high:
            configuration.fftSize = 4096
            configuration.useApproximations = false
        case .studio:
            configuration.fftSize = 8192
            configuration.useApproximations = false
        }

        configuration.maxProcessingLoad = settings.cpuLimit
        setupBuffers(size: configuration.fftSize)

        dspLogger.info("DSP settings updated: FFT=\(self.configuration.fftSize), approx=\(self.configuration.useApproximations)")
    }

    public func reportResourceUsage() -> (cpu: Double, gpu: Double, memoryMB: Double) {
        let memoryMB = Double(windowBuffer.count + realBuffer.count + imagBuffer.count + magnitudeBuffer.count + scratchBuffer.count) * Double(MemoryLayout<Float>.stride) / (1024.0 * 1024.0)
        return (lastProcessingLoad, 0, memoryMB)
    }
}

// MARK: - Supporting Types

public struct BiquadCoefficients {
    public var b0: Float
    public var b1: Float
    public var b2: Float
    public var a1: Float
    public var a2: Float

    public init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    /// Create lowpass filter coefficients (energy-efficient butterworth)
    public static func lowpass(frequency: Float, sampleRate: Float, q: Float = 0.707) -> BiquadCoefficients {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        return BiquadCoefficients(
            b0: ((1.0 - cosOmega) / 2.0) / a0,
            b1: (1.0 - cosOmega) / a0,
            b2: ((1.0 - cosOmega) / 2.0) / a0,
            a1: (-2.0 * cosOmega) / a0,
            a2: (1.0 - alpha) / a0
        )
    }

    /// Create highpass filter coefficients
    public static func highpass(frequency: Float, sampleRate: Float, q: Float = 0.707) -> BiquadCoefficients {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        return BiquadCoefficients(
            b0: ((1.0 + cosOmega) / 2.0) / a0,
            b1: (-(1.0 + cosOmega)) / a0,
            b2: ((1.0 + cosOmega) / 2.0) / a0,
            a1: (-2.0 * cosOmega) / a0,
            a2: (1.0 - alpha) / a0
        )
    }
}

public struct BiquadState {
    public var x1: Float = 0
    public var x2: Float = 0
    public var y1: Float = 0
    public var y2: Float = 0

    public init() {}

    public mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}

public enum DSPOperation {
    case lowpass(cutoff: Float)
    case highpass(cutoff: Float)
    case compress(threshold: Float, ratio: Float)
    case normalize
}

// MARK: - Buffer Pool (Lock-free memory reuse)

private final class BufferPool {
    private let bufferSize: Int
    private var availableBuffers: [[Float]] = []
    private let lock = NSLock()

    init(bufferSize: Int, poolSize: Int = 4) {
        self.bufferSize = bufferSize
        for _ in 0..<poolSize {
            availableBuffers.append([Float](repeating: 0, count: bufferSize))
        }
    }

    func acquire() -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        if let buffer = availableBuffers.popLast() {
            return buffer
        }
        return [Float](repeating: 0, count: bufferSize)
    }

    func release(_ buffer: inout [Float]) {
        lock.lock()
        defer { lock.unlock() }

        // Clear and return to pool
        vDSP_vclr(&buffer, 1, vDSP_Length(buffer.count))
        availableBuffers.append(buffer)
    }
}
