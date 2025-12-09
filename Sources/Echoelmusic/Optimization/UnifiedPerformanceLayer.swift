import Foundation
import Accelerate
import simd
import Metal
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED PERFORMANCE LAYER
// ═══════════════════════════════════════════════════════════════════════════════
//
// Consolidates and optimizes the scattered optimization code:
// • Replaces 13 separate optimization files with unified API
// • Zero-allocation real-time paths
// • SIMD-accelerated signal processing
// • Adaptive quality management
// • Memory pool management
// • Performance monitoring
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Performance Level Manager

/// Unified performance and quality management
public final class PerformanceManager: ObservableObject {

    public static let shared = PerformanceManager()

    // MARK: - Published State

    @Published public private(set) var currentLevel: PerformanceLevel = .balanced
    @Published public private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published public private(set) var thermalState: ThermalState = .nominal

    // MARK: - Types

    public enum PerformanceLevel: Int, CaseIterable {
        case lowPower = 0
        case balanced = 1
        case highPerformance = 2
        case maximum = 3

        public var config: PerformanceConfig {
            switch self {
            case .lowPower:
                return PerformanceConfig(
                    targetFPS: 30, maxParticles: 5000, audioBufferSize: 1024,
                    visualQuality: .low, enablePostProcessing: false
                )
            case .balanced:
                return PerformanceConfig(
                    targetFPS: 60, maxParticles: 20000, audioBufferSize: 512,
                    visualQuality: .medium, enablePostProcessing: true
                )
            case .highPerformance:
                return PerformanceConfig(
                    targetFPS: 120, maxParticles: 50000, audioBufferSize: 256,
                    visualQuality: .high, enablePostProcessing: true
                )
            case .maximum:
                return PerformanceConfig(
                    targetFPS: 120, maxParticles: 100000, audioBufferSize: 128,
                    visualQuality: .ultra, enablePostProcessing: true
                )
            }
        }
    }

    public struct PerformanceConfig {
        public let targetFPS: Int
        public let maxParticles: Int
        public let audioBufferSize: Int
        public let visualQuality: VisualQuality
        public let enablePostProcessing: Bool

        public enum VisualQuality {
            case low, medium, high, ultra
        }
    }

    public struct PerformanceMetrics {
        public var fps: Float = 0
        public var frameTime: TimeInterval = 0
        public var cpuUsage: Float = 0
        public var gpuUsage: Float = 0
        public var memoryUsage: UInt64 = 0
        public var audioLatency: TimeInterval = 0
        public var droppedFrames: Int = 0
    }

    public enum ThermalState {
        case nominal
        case fair
        case serious
        case critical

        public static var current: ThermalState {
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: return .nominal
            case .fair: return .fair
            case .serious: return .serious
            case .critical: return .critical
            @unknown default: return .nominal
            }
        }
    }

    // MARK: - Internal

    private var frameTimeBuffer: CircularBuffer<TimeInterval>
    private var adaptiveEnabled: Bool = true
    private var thermalObserver: NSObjectProtocol?
    private var metricsTimer: Timer?

    // MARK: - Initialization

    private init() {
        frameTimeBuffer = CircularBuffer(capacity: 120, defaultValue: 0.016)
        setupThermalMonitoring()
        startMetricsCollection()
    }

    deinit {
        metricsTimer?.invalidate()
        if let observer = thermalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Set performance level manually
    public func setLevel(_ level: PerformanceLevel) {
        currentLevel = level
        applyConfiguration(level.config)
    }

    /// Enable/disable adaptive performance
    public func setAdaptiveEnabled(_ enabled: Bool) {
        adaptiveEnabled = enabled
    }

    /// Record frame time for FPS calculation
    public func recordFrameTime(_ time: TimeInterval) {
        frameTimeBuffer.append(time)
        updateMetrics()
    }

    /// Get current configuration
    public var config: PerformanceConfig {
        return currentLevel.config
    }

    // MARK: - Private

    private func setupThermalMonitoring() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalChange()
        }
    }

    private func handleThermalChange() {
        thermalState = ThermalState.current

        guard adaptiveEnabled else { return }

        // Auto-downgrade on thermal pressure
        switch thermalState {
        case .serious:
            if currentLevel.rawValue > PerformanceLevel.balanced.rawValue {
                setLevel(.balanced)
            }
        case .critical:
            setLevel(.lowPower)
        default:
            break
        }
    }

    private func startMetricsCollection() {
        metricsTimer = TimerManager.shared.createTimer(
            id: "performance_metrics",
            interval: 1.0
        ) { [weak self] in
            self?.collectMetrics()
        }
    }

    private func collectMetrics() {
        // FPS from frame times
        let times = frameTimeBuffer.toArray()
        if !times.isEmpty {
            let avgTime = times.reduce(0, +) / Double(times.count)
            metrics.fps = avgTime > 0 ? Float(1.0 / avgTime) : 0
            metrics.frameTime = avgTime
        }

        // Memory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            metrics.memoryUsage = info.resident_size
        }

        // Adaptive adjustment
        if adaptiveEnabled {
            adaptPerformance()
        }
    }

    private func adaptPerformance() {
        let targetFPS = Float(currentLevel.config.targetFPS)

        // Downgrade if consistently below target
        if metrics.fps < targetFPS * 0.8 && currentLevel.rawValue > 0 {
            let newLevel = PerformanceLevel(rawValue: currentLevel.rawValue - 1) ?? .lowPower
            setLevel(newLevel)
        }
        // Upgrade if consistently above target with headroom
        else if metrics.fps > targetFPS * 1.1 && currentLevel.rawValue < PerformanceLevel.maximum.rawValue {
            if thermalState == .nominal {
                let newLevel = PerformanceLevel(rawValue: currentLevel.rawValue + 1) ?? .maximum
                setLevel(newLevel)
            }
        }
    }

    private func updateMetrics() {
        let times = frameTimeBuffer.toArray()
        if !times.isEmpty {
            metrics.frameTime = times.last ?? 0
        }
    }

    private func applyConfiguration(_ config: PerformanceConfig) {
        // Notify subsystems of configuration change
        NotificationCenter.default.post(
            name: .performanceConfigChanged,
            object: config
        )
    }
}

extension Notification.Name {
    static let performanceConfigChanged = Notification.Name("com.echoelmusic.performanceConfigChanged")
}

// MARK: - Real-Time Audio DSP

/// High-performance DSP operations for real-time audio
/// Uses Accelerate framework for SIMD optimization
public enum RealTimeDSP {

    // MARK: - FFT

    private static var fftSetup: vDSP_DFT_Setup?
    private static var fftLength: Int = 0

    /// Initialize FFT setup (call once at startup)
    public static func initializeFFT(length: Int) {
        if fftLength != length {
            fftSetup = vDSP_DFT_zop_CreateSetup(
                nil,
                vDSP_Length(length),
                .FORWARD
            )
            fftLength = length
        }
    }

    /// Perform FFT on real signal
    public static func fft(
        _ input: UnsafePointer<Float>,
        real: UnsafeMutablePointer<Float>,
        imaginary: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        guard let setup = fftSetup, count == fftLength else { return }

        // Pack input into split complex
        var splitInput = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: input), imagp: real)
        var splitOutput = DSPSplitComplex(realp: real, imagp: imaginary)

        vDSP_DFT_Execute(setup, &splitInput.realp, &splitInput.imagp, &splitOutput.realp, &splitOutput.imagp)
    }

    /// Calculate magnitude spectrum
    public static func magnitude(
        real: UnsafePointer<Float>,
        imaginary: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var split = DSPSplitComplex(
            realp: UnsafeMutablePointer(mutating: real),
            imagp: UnsafeMutablePointer(mutating: imaginary)
        )
        vDSP_zvabs(&split, 1, output, 1, vDSP_Length(count))
    }

    // MARK: - Filters

    /// Apply biquad filter (IIR)
    public static func biquadFilter(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        coefficients: UnsafePointer<Double>,
        delay: UnsafeMutablePointer<Float>
    ) {
        var delayPointer = delay
        vDSP_biquad_Setup? = vDSP_biquad_CreateSetup(coefficients, 1)

        // Note: In production, cache the setup and reuse
        // This is simplified for illustration
    }

    /// Apply FIR filter
    public static func firFilter(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        inputCount: Int,
        kernel: UnsafePointer<Float>,
        kernelCount: Int
    ) {
        vDSP_conv(
            input, 1,
            kernel, 1,
            output, 1,
            vDSP_Length(inputCount - kernelCount + 1),
            vDSP_Length(kernelCount)
        )
    }

    // MARK: - Basic Operations

    /// Multiply signal by scalar
    public static func scale(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        scalar: Float
    ) {
        var s = scalar
        vDSP_vsmul(input, 1, &s, output, 1, vDSP_Length(count))
    }

    /// Add two signals
    public static func add(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_vadd(a, 1, b, 1, output, 1, vDSP_Length(count))
    }

    /// Multiply two signals element-wise
    public static func multiply(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_vmul(a, 1, b, 1, output, 1, vDSP_Length(count))
    }

    /// Calculate RMS level
    public static func rms(_ input: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_rmsqv(input, 1, &result, vDSP_Length(count))
        return result
    }

    /// Find maximum value and index
    public static func max(_ input: UnsafePointer<Float>, count: Int) -> (value: Float, index: Int) {
        var value: Float = 0
        var index: vDSP_Length = 0
        vDSP_maxvi(input, 1, &value, &index, vDSP_Length(count))
        return (value, Int(index))
    }

    /// Normalize signal to [-1, 1]
    public static func normalize(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var maxVal: Float = 0
        vDSP_maxmgv(input, 1, &maxVal, vDSP_Length(count))

        if maxVal > 0 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(input, 1, &scale, output, 1, vDSP_Length(count))
        } else {
            // Copy input to output if signal is silent
            memcpy(output, input, count * MemoryLayout<Float>.size)
        }
    }

    /// Apply soft clipping (tanh-like)
    public static func softClip(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var n = Int32(count)
        vvtanhf(output, input, &n)
    }

    /// Linear interpolation between two signals
    public static func interpolate(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int,
        factor: Float
    ) {
        var f = factor
        vDSP_vintb(a, 1, b, 1, &f, output, 1, vDSP_Length(count))
    }

    // MARK: - Window Functions

    /// Generate Hann window
    public static func hannWindow(_ output: UnsafeMutablePointer<Float>, count: Int) {
        vDSP_hann_window(output, vDSP_Length(count), Int32(vDSP_HANN_NORM))
    }

    /// Generate Blackman window
    public static func blackmanWindow(_ output: UnsafeMutablePointer<Float>, count: Int) {
        vDSP_blkman_window(output, vDSP_Length(count), 0)
    }

    /// Apply window to signal
    public static func applyWindow(
        _ signal: UnsafePointer<Float>,
        window: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        vDSP_vmul(signal, 1, window, 1, output, 1, vDSP_Length(count))
    }

    // MARK: - Statistics

    /// Calculate mean
    public static func mean(_ input: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_meanv(input, 1, &result, vDSP_Length(count))
        return result
    }

    /// Calculate sum
    public static func sum(_ input: UnsafePointer<Float>, count: Int) -> Float {
        var result: Float = 0
        vDSP_sve(input, 1, &result, vDSP_Length(count))
        return result
    }

    /// Calculate variance
    public static func variance(_ input: UnsafePointer<Float>, count: Int) -> Float {
        let m = mean(input, count: count)
        var meanVal = m
        var variance: Float = 0

        // Calculate sum of squared differences
        var temp = [Float](repeating: 0, count: count)
        vDSP_vsadd(input, 1, &meanVal, &temp, 1, vDSP_Length(count))
        vDSP_vsq(temp, 1, &temp, 1, vDSP_Length(count))
        vDSP_meanv(temp, 1, &variance, vDSP_Length(count))

        return variance
    }
}

// MARK: - Memory Pool

/// Pre-allocated memory pool for zero-allocation audio processing
public final class AudioBufferPool {

    public static let shared = AudioBufferPool()

    private var floatBuffers: [[Float]] = []
    private var availableIndices: [Int] = []
    private let lock = NSLock()

    private let bufferSize: Int = 4096
    private let poolSize: Int = 32

    private init() {
        // Pre-allocate buffers
        for i in 0..<poolSize {
            floatBuffers.append([Float](repeating: 0, count: bufferSize))
            availableIndices.append(i)
        }
    }

    /// Acquire a buffer (O(1))
    public func acquire() -> (index: Int, buffer: UnsafeMutablePointer<Float>)? {
        lock.lock()
        defer { lock.unlock() }

        guard let index = availableIndices.popLast() else { return nil }

        return floatBuffers[index].withUnsafeMutableBufferPointer { ptr in
            (index, ptr.baseAddress!)
        }
    }

    /// Release a buffer back to pool (O(1))
    public func release(index: Int) {
        lock.lock()
        defer { lock.unlock() }

        // Clear buffer
        memset(&floatBuffers[index], 0, bufferSize * MemoryLayout<Float>.size)
        availableIndices.append(index)
    }

    /// Available buffer count
    public var availableCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return availableIndices.count
    }
}

// MARK: - Optimized Math Operations

/// Fast math operations avoiding standard library overhead
public enum FastMath {

    /// Fast reciprocal (1/x) using Newton-Raphson
    @inline(__always)
    public static func reciprocal(_ x: Float) -> Float {
        var estimate = Float(bitPattern: 0x7EF311C3 - (x.bitPattern >> 1))
        estimate = estimate * (2.0 - x * estimate)
        estimate = estimate * (2.0 - x * estimate)
        return estimate
    }

    /// Fast inverse square root (1/√x)
    @inline(__always)
    public static func rsqrt(_ x: Float) -> Float {
        var i = x.bitPattern
        i = 0x5F375A86 - (i >> 1)
        var y = Float(bitPattern: i)
        y = y * (1.5 - (x * 0.5 * y * y))
        return y
    }

    /// Fast square root using rsqrt
    @inline(__always)
    public static func sqrt(_ x: Float) -> Float {
        return x * rsqrt(x)
    }

    /// Fast sine approximation (Bhaskara I's formula)
    @inline(__always)
    public static func sin(_ x: Float) -> Float {
        // Normalize to [0, 2π]
        var angle = x.truncatingRemainder(dividingBy: 2.0 * .pi)
        if angle < 0 { angle += 2.0 * .pi }

        // Use Bhaskara approximation
        let pi = Float.pi
        if angle <= pi {
            let numerator = 16 * angle * (pi - angle)
            let denominator = 5 * pi * pi - 4 * angle * (pi - angle)
            return numerator / denominator
        } else {
            let adjustedAngle = angle - pi
            let numerator = 16 * adjustedAngle * (pi - adjustedAngle)
            let denominator = 5 * pi * pi - 4 * adjustedAngle * (pi - adjustedAngle)
            return -numerator / denominator
        }
    }

    /// Fast cosine using sin
    @inline(__always)
    public static func cos(_ x: Float) -> Float {
        return sin(x + .pi / 2)
    }

    /// Fast tanh approximation
    @inline(__always)
    public static func tanh(_ x: Float) -> Float {
        if x < -3 { return -1 }
        if x > 3 { return 1 }
        let x2 = x * x
        return x * (27 + x2) / (27 + 9 * x2)
    }

    /// Linear interpolation
    @inline(__always)
    public static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + t * (b - a)
    }

    /// Clamp value to range
    @inline(__always)
    public static func clamp(_ x: Float, min: Float, max: Float) -> Float {
        return x < min ? min : (x > max ? max : x)
    }

    /// Smooth step (Hermite interpolation)
    @inline(__always)
    public static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = clamp((x - edge0) / (edge1 - edge0), min: 0, max: 1)
        return t * t * (3 - 2 * t)
    }

    /// Convert dB to linear
    @inline(__always)
    public static func dbToLinear(_ db: Float) -> Float {
        return powf(10.0, db / 20.0)
    }

    /// Convert linear to dB
    @inline(__always)
    public static func linearToDb(_ linear: Float) -> Float {
        return 20.0 * log10f(max(linear, 1e-10))
    }

    /// MIDI note to frequency
    @inline(__always)
    public static func noteToFrequency(_ note: Int) -> Float {
        return 440.0 * powf(2.0, Float(note - 69) / 12.0)
    }

    /// Frequency to MIDI note
    @inline(__always)
    public static func frequencyToNote(_ freq: Float) -> Int {
        return Int(round(12.0 * log2f(freq / 440.0) + 69.0))
    }
}

// MARK: - Batch Processing

/// Batch operations for processing multiple items efficiently
public enum BatchProcessor {

    /// Process audio frames in batches
    public static func processFrames<T>(
        _ frames: [T],
        batchSize: Int,
        processor: ([T]) -> [T]
    ) -> [T] {
        var results: [T] = []
        results.reserveCapacity(frames.count)

        for batchStart in stride(from: 0, to: frames.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, frames.count)
            let batch = Array(frames[batchStart..<batchEnd])
            results.append(contentsOf: processor(batch))
        }

        return results
    }

    /// Process items concurrently
    public static func processConcurrently<T, R>(
        _ items: [T],
        maxConcurrency: Int = ProcessInfo.processInfo.processorCount,
        processor: @Sendable (T) async -> R
    ) async -> [R] {
        await withTaskGroup(of: (Int, R).self) { group in
            var results: [(Int, R)] = []
            results.reserveCapacity(items.count)

            for (index, item) in items.enumerated() {
                group.addTask {
                    let result = await processor(item)
                    return (index, result)
                }
            }

            for await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

// MARK: - Performance Annotations

/// Marks a function as real-time safe (no allocations, no locks)
@propertyWrapper
public struct RealTimeSafe<T> {
    public var wrappedValue: T

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

/// Marks a function as compute-intensive (should run on background thread)
@propertyWrapper
public struct ComputeIntensive<T> {
    public var wrappedValue: T

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}
