import XCTest
import Accelerate
@testable import Echoelmusic

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE BENCHMARKS FOR CI/CD
// ═══════════════════════════════════════════════════════════════════════════════
//
// Automated performance regression tests:
// • DSP operations (FFT, convolution, filtering)
// • SIMD math operations
// • Memory allocation patterns
// • Audio buffer processing
// • Frame timing baselines
//
// Run with: swift test --filter PerformanceBenchmarks
// CI/CD: Set baseline thresholds to catch performance regressions
//
// ═══════════════════════════════════════════════════════════════════════════════

final class PerformanceBenchmarks: XCTestCase {

    // MARK: - Configuration

    /// Number of iterations for averaging
    private static let iterations = 100

    /// Buffer sizes for audio tests
    private static let audioBufferSizes = [256, 512, 1024, 2048, 4096]

    /// Performance thresholds (in seconds) - fail if exceeded
    private struct Thresholds {
        static let fftProcessing = 0.001        // 1ms for 4096 samples
        static let simdMath = 0.0005            // 0.5ms for 4096 samples
        static let bufferAllocation = 0.0001    // 0.1ms per allocation
        static let audioCallback = 0.001        // 1ms audio callback budget
        static let frameRendering = 0.008       // 8ms for 120fps
    }

    // MARK: - DSP Benchmarks

    func testFFTPerformance() throws {
        let sizes = [1024, 2048, 4096]

        for size in sizes {
            let input = (0..<size).map { Float(sin(Double($0) * 0.1)) }
            var magnitudes = [Float](repeating: 0, count: size / 2)

            let startTime = CFAbsoluteTimeGetCurrent()

            for _ in 0..<Self.iterations {
                computeFFTMagnitudes(input: input, output: &magnitudes)
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let avgTime = elapsed / Double(Self.iterations)

            print("FFT (\(size) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")

            // Assert performance threshold
            if size == 4096 {
                XCTAssertLessThan(avgTime, Thresholds.fftProcessing,
                    "FFT processing exceeded \(Thresholds.fftProcessing * 1000)ms threshold")
            }
        }
    }

    func testBiquadFilterPerformance() throws {
        let bufferSize = 4096
        var input = (0..<bufferSize).map { Float(sin(Double($0) * 0.05)) }
        var output = [Float](repeating: 0, count: bufferSize)

        // Lowpass filter coefficients
        let b: [Double] = [0.0675, 0.1349, 0.0675]
        let a: [Double] = [1.0, -1.1430, 0.4128]

        guard let setup = vDSP_biquad_CreateSetup(b, a, 1) else {
            XCTFail("Failed to create biquad setup")
            return
        }
        defer { vDSP_biquad_DestroySetup(setup) }

        var delay = [Float](repeating: 0, count: 4)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            vDSP_biquad(setup, &delay, &input, 1, &output, 1, vDSP_Length(bufferSize))
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("Biquad Filter (\(bufferSize) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.audioCallback,
            "Biquad filter exceeded audio callback budget")
    }

    func testConvolutionPerformance() throws {
        let signalSize = 4096
        let kernelSize = 256

        let signal = (0..<signalSize).map { Float(sin(Double($0) * 0.02)) }
        let kernel = (0..<kernelSize).map { Float.random(in: -1...1) }
        var output = [Float](repeating: 0, count: signalSize + kernelSize - 1)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            vDSP_conv(signal, 1, kernel, 1, &output, 1,
                     vDSP_Length(signalSize), vDSP_Length(kernelSize))
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("Convolution (\(signalSize)x\(kernelSize)): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.audioCallback,
            "Convolution exceeded audio callback budget")
    }

    // MARK: - SIMD Math Benchmarks

    func testSIMDSinCosPerformance() throws {
        let count = 4096
        var input = (0..<count).map { Float($0) * 0.01 }
        var sinOut = [Float](repeating: 0, count: count)
        var cosOut = [Float](repeating: 0, count: count)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            var n = Int32(count)
            vvsinf(&sinOut, &input, &n)
            vvcosf(&cosOut, &input, &n)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("SIMD Sin+Cos (\(count) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.simdMath,
            "SIMD sin/cos exceeded threshold")
    }

    func testSIMDExpLogPerformance() throws {
        let count = 4096
        var input = (0..<count).map { Float($0) * 0.001 + 0.001 }
        var expOut = [Float](repeating: 0, count: count)
        var logOut = [Float](repeating: 0, count: count)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            var n = Int32(count)
            vvexpf(&expOut, &input, &n)
            vvlogf(&logOut, &input, &n)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("SIMD Exp+Log (\(count) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.simdMath,
            "SIMD exp/log exceeded threshold")
    }

    func testVectorMultiplyAddPerformance() throws {
        let count = 4096
        var a = (0..<count).map { _ in Float.random(in: -1...1) }
        var b = (0..<count).map { _ in Float.random(in: -1...1) }
        var c = (0..<count).map { _ in Float.random(in: -1...1) }
        var result = [Float](repeating: 0, count: count)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            // result = a * b + c (fused multiply-add)
            vDSP_vma(&a, 1, &b, 1, &c, 1, &result, 1, vDSP_Length(count))
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("Vector Multiply-Add (\(count) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.simdMath,
            "Vector multiply-add exceeded threshold")
    }

    // MARK: - Memory Benchmarks

    func testBufferAllocationPerformance() throws {
        let bufferSize = 4096
        let allocations = 1000

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<allocations {
            let buffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
            buffer.initialize(repeating: 0, count: bufferSize)
            buffer.deallocate()
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(allocations)

        print("Buffer Allocation (\(bufferSize) floats): \(String(format: "%.6f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.bufferAllocation,
            "Buffer allocation too slow")
    }

    func testArrayCopyPerformance() throws {
        let count = 4096
        let source = (0..<count).map { Float($0) }
        var destination = [Float](repeating: 0, count: count)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations * 10 {
            source.withUnsafeBufferPointer { srcPtr in
                destination.withUnsafeMutableBufferPointer { dstPtr in
                    memcpy(dstPtr.baseAddress!, srcPtr.baseAddress!, count * MemoryLayout<Float>.size)
                }
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations * 10)

        print("Array Copy (\(count) floats): \(String(format: "%.6f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.bufferAllocation,
            "Array copy too slow")
    }

    func testRingBufferPerformance() throws {
        let capacity = 1024
        var buffer = RingBufferBenchmark<Float>(capacity: capacity)
        let testData = (0..<capacity).map { Float($0) }

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations * 100 {
            // Fill buffer
            for value in testData.prefix(100) {
                buffer.push(value)
            }
            // Drain buffer
            for _ in 0..<100 {
                _ = buffer.pop()
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations * 100)

        print("Ring Buffer (100 push/pop): \(String(format: "%.6f", avgTime * 1000))ms avg")
    }

    // MARK: - Audio Processing Benchmarks

    func testAudioCallbackSimulation() throws {
        // Simulate typical audio callback workload
        let bufferSize = 512 // Typical audio buffer
        let channels = 2

        var leftChannel = (0..<bufferSize).map { Float(sin(Double($0) * 0.1)) }
        var rightChannel = (0..<bufferSize).map { Float(cos(Double($0) * 0.1)) }
        var outputLeft = [Float](repeating: 0, count: bufferSize)
        var outputRight = [Float](repeating: 0, count: bufferSize)

        var gain: Float = 0.8

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations * 10 {
            // Apply gain
            vDSP_vsmul(&leftChannel, 1, &gain, &outputLeft, 1, vDSP_Length(bufferSize))
            vDSP_vsmul(&rightChannel, 1, &gain, &outputRight, 1, vDSP_Length(bufferSize))

            // Mix channels
            var half: Float = 0.5
            vDSP_vasm(&outputLeft, 1, &outputRight, 1, &half, &outputLeft, 1, vDSP_Length(bufferSize))
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations * 10)

        print("Audio Callback Simulation (\(bufferSize)x\(channels)): \(String(format: "%.4f", avgTime * 1000))ms avg")

        XCTAssertLessThan(avgTime, Thresholds.audioCallback,
            "Audio callback simulation exceeded budget")
    }

    func testBinauralBeatGeneration() throws {
        let sampleRate: Float = 44100
        let bufferSize = 4096
        let baseFreq: Float = 200
        let beatFreq: Float = 10

        var leftOutput = [Float](repeating: 0, count: bufferSize)
        var rightOutput = [Float](repeating: 0, count: bufferSize)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<Self.iterations {
            var phase: Float = 0
            let leftInc = (baseFreq - beatFreq / 2) / sampleRate * 2 * .pi
            let rightInc = (baseFreq + beatFreq / 2) / sampleRate * 2 * .pi

            for i in 0..<bufferSize {
                leftOutput[i] = sin(phase)
                rightOutput[i] = sin(phase + Float(i) * (rightInc - leftInc))
                phase += leftInc
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = elapsed / Double(Self.iterations)

        print("Binaural Beat Generation (\(bufferSize) samples): \(String(format: "%.4f", avgTime * 1000))ms avg")
    }

    // MARK: - Frame Timing Benchmarks

    func testFrameTimingBaseline() throws {
        // Simulate frame processing workload
        let width = 1920
        let height = 1080
        let pixelCount = width * height

        var frameData = [UInt8](repeating: 0, count: pixelCount * 4) // RGBA

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<60 { // 1 second of frames
            // Simulate frame processing
            for i in stride(from: 0, to: pixelCount * 4, by: 4) {
                frameData[i] = UInt8(truncatingIfNeeded: i & 0xFF)     // R
                frameData[i + 1] = UInt8(truncatingIfNeeded: (i >> 8) & 0xFF) // G
                frameData[i + 2] = UInt8(truncatingIfNeeded: (i >> 16) & 0xFF) // B
                frameData[i + 3] = 255 // A
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgFrameTime = elapsed / 60.0

        print("Frame Processing (\(width)x\(height)): \(String(format: "%.2f", avgFrameTime * 1000))ms avg")

        // Note: This is CPU baseline, GPU would be much faster
    }

    // MARK: - Comparative Benchmarks

    func testOptimizedVsNaiveComparison() throws {
        let count = 4096
        var data = (0..<count).map { Float($0) * 0.01 }

        // Naive sin computation
        let naiveStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<Self.iterations {
            for i in 0..<count {
                data[i] = sin(data[i])
            }
        }
        let naiveTime = CFAbsoluteTimeGetCurrent() - naiveStart

        // Reset data
        data = (0..<count).map { Float($0) * 0.01 }

        // SIMD sin computation
        var output = [Float](repeating: 0, count: count)
        let simdStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<Self.iterations {
            var n = Int32(count)
            vvsinf(&output, &data, &n)
        }
        let simdTime = CFAbsoluteTimeGetCurrent() - simdStart

        let speedup = naiveTime / simdTime

        print("Naive sin: \(String(format: "%.2f", naiveTime * 1000))ms total")
        print("SIMD sin:  \(String(format: "%.2f", simdTime * 1000))ms total")
        print("Speedup:   \(String(format: "%.1f", speedup))x")

        XCTAssertGreaterThan(speedup, 2.0, "SIMD should be at least 2x faster than naive")
    }

    // MARK: - Helper Methods

    private func computeFFTMagnitudes(input: [Float], output: inout [Float]) {
        let count = input.count
        guard count > 0 && (count & (count - 1)) == 0 else { return }

        let log2n = vDSP_Length(log2(Float(count)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realp = [Float](repeating: 0, count: count / 2)
        var imagp = [Float](repeating: 0, count: count / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        input.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: count / 2) { ptr in
                vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(count / 2))
            }
        }

        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
        vDSP_zvmags(&splitComplex, 1, &output, 1, vDSP_Length(min(output.count, count / 2)))
    }
}

// MARK: - Benchmark Support Types

private struct RingBufferBenchmark<T> {
    private var buffer: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [T?](repeating: nil, count: capacity)
    }

    mutating func push(_ value: T) {
        buffer[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
    }

    mutating func pop() -> T? {
        guard buffer[readIndex] != nil else { return nil }
        let value = buffer[readIndex]
        buffer[readIndex] = nil
        readIndex = (readIndex + 1) % capacity
        return value
    }
}

// MARK: - CI/CD Integration

extension PerformanceBenchmarks {

    /// Run all benchmarks and generate report
    static func generateCIReport() -> String {
        return """
        ══════════════════════════════════════════════════════════════
        ECHOELMUSIC PERFORMANCE BENCHMARK REPORT
        ══════════════════════════════════════════════════════════════

        Thresholds:
        • FFT Processing:      < \(Thresholds.fftProcessing * 1000)ms
        • SIMD Math:           < \(Thresholds.simdMath * 1000)ms
        • Buffer Allocation:   < \(Thresholds.bufferAllocation * 1000)ms
        • Audio Callback:      < \(Thresholds.audioCallback * 1000)ms
        • Frame Rendering:     < \(Thresholds.frameRendering * 1000)ms

        Run: swift test --filter PerformanceBenchmarks

        ══════════════════════════════════════════════════════════════
        """
    }
}
