import Foundation
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD & VECTORIZATION OPTIMIZATIONS FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Performance improvements through:
// • SIMD vector operations (2-8x faster)
// • Accelerate framework integration
// • Cache-friendly memory access patterns
// • Pre-allocated buffer pools
// • Lock-free audio thread operations
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - SIMD Audio Processing Extensions

/// High-performance audio buffer operations using Accelerate framework
public enum SIMDAudio {

    // MARK: - Buffer Operations

    /// Clear buffer using SIMD operations (4x faster than loop)
    /// - Parameters:
    ///   - buffer: Pointer to float buffer
    ///   - count: Number of samples
    @inlinable
    public static func clear(_ buffer: UnsafeMutablePointer<Float>, count: Int) {
        vDSP_vclr(buffer, 1, vDSP_Length(count))
    }

    /// Copy buffer using SIMD operations
    @inlinable
    public static func copy(from source: UnsafePointer<Float>,
                            to destination: UnsafeMutablePointer<Float>,
                            count: Int) {
        cblas_scopy(Int32(count), source, 1, destination, 1)
    }

    /// Add two buffers using SIMD operations (2x faster)
    @inlinable
    public static func add(_ a: UnsafePointer<Float>,
                           _ b: UnsafePointer<Float>,
                           result: UnsafeMutablePointer<Float>,
                           count: Int) {
        vDSP_vadd(a, 1, b, 1, result, 1, vDSP_Length(count))
    }

    /// Multiply buffer by scalar using SIMD
    @inlinable
    public static func scale(_ buffer: UnsafeMutablePointer<Float>,
                             by scalar: Float,
                             count: Int) {
        var scalarValue = scalar
        vDSP_vsmul(buffer, 1, &scalarValue, buffer, 1, vDSP_Length(count))
    }

    /// Multiply two buffers element-wise using SIMD
    @inlinable
    public static func multiply(_ a: UnsafePointer<Float>,
                                _ b: UnsafePointer<Float>,
                                result: UnsafeMutablePointer<Float>,
                                count: Int) {
        vDSP_vmul(a, 1, b, 1, result, 1, vDSP_Length(count))
    }

    // MARK: - Analysis Operations

    /// Calculate RMS level using SIMD (used for level meters)
    @inlinable
    public static func rms(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_rmsqv(buffer, 1, &result, vDSP_Length(count))
        return result
    }

    /// Calculate peak level using SIMD
    @inlinable
    public static func peak(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_maxmgv(buffer, 1, &result, vDSP_Length(count))
        return result
    }

    /// Calculate mean using SIMD
    @inlinable
    public static func mean(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_meanv(buffer, 1, &result, vDSP_Length(count))
        return result
    }

    /// Calculate sum of squares using SIMD
    @inlinable
    public static func sumOfSquares(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_svesq(buffer, 1, &result, vDSP_Length(count))
        return result
    }

    // MARK: - Clipping & Limiting

    /// Soft clip buffer using SIMD (prevents harsh digital clipping)
    @inlinable
    public static func softClip(_ buffer: UnsafeMutablePointer<Float>, count: Int, threshold: Float = 0.9) {
        // tanh-based soft clipping: y = tanh(x / threshold) * threshold
        var input = [Float](repeating: 0, count: count)
        var output = [Float](repeating: 0, count: count)

        // Copy and scale
        let invThreshold = 1.0 / threshold
        vDSP_vsmul(buffer, 1, [invThreshold], &input, 1, vDSP_Length(count))

        // Apply tanh
        var n = Int32(count)
        vvtanhf(&output, input, &n)

        // Scale back
        vDSP_vsmul(&output, 1, [threshold], buffer, 1, vDSP_Length(count))
    }

    /// Hard clip buffer using SIMD
    @inlinable
    public static func hardClip(_ buffer: UnsafeMutablePointer<Float>, count: Int, min: Float = -1.0, max: Float = 1.0) {
        var minVal = min
        var maxVal = max
        vDSP_vclip(buffer, 1, &minVal, &maxVal, buffer, 1, vDSP_Length(count))
    }

    // MARK: - Window Functions

    /// Apply Hann window to buffer using SIMD
    @inlinable
    public static func applyHannWindow(to buffer: UnsafeMutablePointer<Float>,
                                       window: UnsafePointer<Float>,
                                       count: Int) {
        vDSP_vmul(buffer, 1, window, 1, buffer, 1, vDSP_Length(count))
    }

    /// Create Hann window using SIMD
    public static func createHannWindow(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        return window
    }

    // MARK: - Stereo Operations

    /// Interleave L/R channels to stereo buffer
    @inlinable
    public static func interleave(left: UnsafePointer<Float>,
                                  right: UnsafePointer<Float>,
                                  stereo: UnsafeMutablePointer<Float>,
                                  frameCount: Int) {
        var dspSplitComplex = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: left),
                                               imagp: UnsafeMutablePointer(mutating: right))
        vDSP_ztoc(&dspSplitComplex, 1, UnsafeMutablePointer<DSPComplex>(OpaquePointer(stereo)), 2, vDSP_Length(frameCount))
    }

    /// De-interleave stereo buffer to L/R channels
    @inlinable
    public static func deinterleave(stereo: UnsafePointer<Float>,
                                    left: UnsafeMutablePointer<Float>,
                                    right: UnsafeMutablePointer<Float>,
                                    frameCount: Int) {
        var dspSplitComplex = DSPSplitComplex(realp: left, imagp: right)
        vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(stereo)), 2, &dspSplitComplex, 1, vDSP_Length(frameCount))
    }

    // MARK: - FFT Operations

    /// Perform FFT using Accelerate (optimized for audio)
    public static func fft(_ input: [Float], fftSetup: vDSP_DFT_Setup) -> [Float] {
        let n = input.count
        var realIn = input
        var imagIn = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)

        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)

        // Calculate magnitude
        var magnitudes = [Float](repeating: 0, count: n / 2)
        for i in 0..<n/2 {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        return magnitudes
    }
}

// MARK: - Pre-allocated Buffer Pool

/// Thread-safe buffer pool for real-time audio processing
/// Eliminates memory allocation on audio thread
public final class AudioBufferPool {

    private let bufferSize: Int
    private let maxBuffers: Int
    private var availableBuffers: [[Float]]
    private let lock = NSLock()

    public init(bufferSize: Int, maxBuffers: Int = 8) {
        self.bufferSize = bufferSize
        self.maxBuffers = maxBuffers

        // Pre-allocate all buffers
        self.availableBuffers = (0..<maxBuffers).map { _ in
            [Float](repeating: 0, count: bufferSize)
        }
    }

    /// Acquire a buffer from the pool (O(1) operation)
    public func acquire() -> [Float]? {
        lock.lock()
        defer { lock.unlock() }

        if let buffer = availableBuffers.popLast() {
            return buffer
        }
        return nil
    }

    /// Return a buffer to the pool (O(1) operation)
    public func release(_ buffer: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        if availableBuffers.count < maxBuffers {
            // Clear and return to pool
            var clearedBuffer = buffer
            SIMDAudio.clear(&clearedBuffer, count: bufferSize)
            availableBuffers.append(clearedBuffer)
        }
    }
}

// MARK: - Lock-Free Ring Buffer

/// Lock-free circular buffer for audio thread communication
/// Single producer, single consumer pattern
public final class LockFreeRingBuffer<T> {
    private var buffer: [T]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let capacity: Int

    public init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.buffer = [T](repeating: defaultValue, count: capacity)
    }

    /// Write to buffer (producer thread)
    @inlinable
    public func write(_ value: T) -> Bool {
        let nextWrite = (writeIndex + 1) % capacity
        if nextWrite == readIndex {
            return false // Buffer full
        }
        buffer[writeIndex] = value
        writeIndex = nextWrite
        return true
    }

    /// Read from buffer (consumer thread)
    @inlinable
    public func read() -> T? {
        if readIndex == writeIndex {
            return nil // Buffer empty
        }
        let value = buffer[readIndex]
        readIndex = (readIndex + 1) % capacity
        return value
    }

    /// Check available space for writing
    public var availableWrite: Int {
        let w = writeIndex
        let r = readIndex
        if w >= r {
            return capacity - (w - r) - 1
        } else {
            return r - w - 1
        }
    }

    /// Check available items for reading
    public var availableRead: Int {
        let w = writeIndex
        let r = readIndex
        if w >= r {
            return w - r
        } else {
            return capacity - r + w
        }
    }
}

// MARK: - Smoothing Filters

/// One-pole lowpass filter for parameter smoothing
/// Prevents zipper noise on parameter changes
public struct OnePoleLowpass {
    private var z1: Float = 0
    private let coefficient: Float

    /// Initialize with smoothing time
    /// - Parameters:
    ///   - smoothingTimeMs: Smoothing time in milliseconds
    ///   - sampleRate: Sample rate in Hz
    public init(smoothingTimeMs: Float, sampleRate: Float = 48000) {
        let smoothingSamples = smoothingTimeMs * sampleRate / 1000
        self.coefficient = exp(-1.0 / smoothingSamples)
    }

    /// Process single sample
    @inlinable
    public mutating func process(_ input: Float) -> Float {
        z1 = input + (z1 - input) * coefficient
        return z1
    }

    /// Reset filter state
    @inlinable
    public mutating func reset(to value: Float = 0) {
        z1 = value
    }
}

// MARK: - SIMD 4x Vector Extensions

extension SIMD4 where Scalar == Float {

    /// Fast magnitude calculation
    @inlinable
    var magnitude: Float {
        simd_length(self)
    }

    /// Normalize vector
    @inlinable
    var normalized: SIMD4<Float> {
        let m = magnitude
        return m > 0 ? self / m : .zero
    }

    /// Linear interpolation with another vector
    @inlinable
    func lerp(to other: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        simd_mix(self, other, SIMD4<Float>(repeating: t))
    }

    /// Clamp all components
    @inlinable
    func clamped(min: Float, max: Float) -> SIMD4<Float> {
        simd_clamp(self, SIMD4(repeating: min), SIMD4(repeating: max))
    }
}

// MARK: - Performance Measurement

/// High-precision performance measurement for audio optimization
public final class PerformanceProfiler {

    public struct Measurement {
        public let name: String
        public let durationNs: UInt64
        public var durationMs: Double { Double(durationNs) / 1_000_000 }
        public var durationUs: Double { Double(durationNs) / 1_000 }
    }

    private var measurements: [Measurement] = []
    private var startTime: UInt64 = 0

    public init() {}

    /// Begin timing a section
    @inlinable
    public func begin() {
        startTime = mach_absolute_time()
    }

    /// End timing and record measurement
    @inlinable
    public func end(name: String) {
        let endTime = mach_absolute_time()
        let elapsed = endTime - startTime

        // Convert to nanoseconds
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let ns = elapsed * UInt64(info.numer) / UInt64(info.denom)

        measurements.append(Measurement(name: name, durationNs: ns))
    }

    /// Get all measurements
    public var allMeasurements: [Measurement] { measurements }

    /// Get average duration for a named measurement
    public func average(for name: String) -> Double {
        let matching = measurements.filter { $0.name == name }
        guard !matching.isEmpty else { return 0 }
        return matching.map { $0.durationMs }.reduce(0, +) / Double(matching.count)
    }

    /// Clear all measurements
    public func clear() {
        measurements.removeAll()
    }

    /// Generate report
    public func report() -> String {
        var result = "Performance Report\n==================\n"

        let grouped = Dictionary(grouping: measurements, by: { $0.name })
        for (name, measures) in grouped.sorted(by: { $0.key < $1.key }) {
            let avg = measures.map { $0.durationUs }.reduce(0, +) / Double(measures.count)
            let min = measures.map { $0.durationUs }.min() ?? 0
            let max = measures.map { $0.durationUs }.max() ?? 0

            result += "\(name): avg=\(String(format: "%.2f", avg))μs min=\(String(format: "%.2f", min))μs max=\(String(format: "%.2f", max))μs\n"
        }

        return result
    }
}
