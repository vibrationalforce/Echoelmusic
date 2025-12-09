import Foundation
import Accelerate
import simd
#if canImport(Metal)
import Metal
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ULTRA LOW LATENCY ENGINE - QUANTUM REAL-TIME OPTIMIZATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Critical real-time safe implementations:
// • Lock-free audio processing (NO @MainActor)
// • Zero-allocation audio callbacks
// • Async GPU completion (NO waitUntilCompleted)
// • Cache-optimized data structures
// • SIMD-accelerated DSP
//
// Design Principles:
// • Audio thread budget: 10.67ms @ 48kHz/512 samples
// • Video frame budget: 8.33ms @ 120fps
// • Zero heap allocations in callbacks
// • No locks, no dispatch, no async in hot paths
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Real-Time Safe Protocols

/// Protocol for real-time safe operations - NO allocations, NO locks
public protocol RealTimeSafe {
    /// Process audio in real-time safe manner
    func processRealTime(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int)
}

// MARK: - Lock-Free SPSC Queue (Single Producer Single Consumer)

/// Ultra-fast lock-free queue for audio thread communication
/// O(1) push/pop with zero contention
public final class LockFreeSPSCQueue<T> {

    private let capacity: Int
    private let mask: Int
    private let buffer: UnsafeMutablePointer<T?>

    // Atomic indices - cache line padded to prevent false sharing
    private var _head: Int = 0
    private var _padding1: (Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0)
    private var _tail: Int = 0
    private var _padding2: (Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0)

    /// Initialize with power-of-2 capacity for fast modulo
    public init(capacity: Int) {
        // Round up to power of 2
        let pow2 = 1 << (Int.bitWidth - (capacity - 1).leadingZeroBitCount)
        self.capacity = pow2
        self.mask = pow2 - 1
        self.buffer = .allocate(capacity: pow2)
        self.buffer.initialize(repeating: nil, count: pow2)
    }

    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    /// Push item - returns false if full (producer thread only)
    @inlinable @inline(__always)
    public func push(_ item: T) -> Bool {
        let head = _head
        let nextHead = (head &+ 1) & mask

        // Check if full (tail catching up)
        if nextHead == _tail {
            return false
        }

        buffer[head] = item

        // Memory barrier before publishing
        OSMemoryBarrier()
        _head = nextHead

        return true
    }

    /// Pop item - returns nil if empty (consumer thread only)
    @inlinable @inline(__always)
    public func pop() -> T? {
        let tail = _tail

        // Check if empty
        if tail == _head {
            return nil
        }

        let item = buffer[tail]
        buffer[tail] = nil

        // Memory barrier before updating tail
        OSMemoryBarrier()
        _tail = (tail &+ 1) & mask

        return item
    }

    /// Check if empty (approximate, may race)
    @inlinable
    public var isEmpty: Bool {
        return _head == _tail
    }

    /// Available items (approximate)
    @inlinable
    public var count: Int {
        let head = _head
        let tail = _tail
        return (head &- tail) & mask
    }
}

// MARK: - Real-Time Audio Buffer Pool

/// Pre-allocated buffer pool for zero-allocation audio processing
public final class RealTimeBufferPool {

    public static let shared = RealTimeBufferPool()

    // Pre-allocated buffers by size (power of 2)
    private var pools: [Int: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>]
    private var poolSizes: [Int: Int]
    private var poolIndices: [Int: Int]
    private let maxPoolSize = 32

    private init() {
        pools = [:]
        poolSizes = [:]
        poolIndices = [:]

        // Pre-allocate common sizes
        let commonSizes = [256, 512, 1024, 2048, 4096, 8192]
        for size in commonSizes {
            allocatePool(size: size)
        }
    }

    private func allocatePool(size: Int) {
        let poolPtr = UnsafeMutablePointer<UnsafeMutablePointer<Float>?>.allocate(capacity: maxPoolSize)

        for i in 0..<maxPoolSize {
            let buffer = UnsafeMutablePointer<Float>.allocate(capacity: size)
            buffer.initialize(repeating: 0, count: size)
            poolPtr[i] = buffer
        }

        pools[size] = poolPtr
        poolSizes[size] = maxPoolSize
        poolIndices[size] = 0
    }

    /// Acquire buffer - O(1) no allocation
    @inlinable @inline(__always)
    public func acquire(size: Int) -> UnsafeMutablePointer<Float>? {
        // Round to next power of 2
        let targetSize = 1 << (Int.bitWidth - (size - 1).leadingZeroBitCount)

        guard let poolPtr = pools[targetSize],
              let poolSize = poolSizes[targetSize],
              var index = poolIndices[targetSize] else {
            return nil
        }

        // Find available buffer
        for _ in 0..<poolSize {
            if let buffer = poolPtr[index] {
                poolPtr[index] = nil
                poolIndices[targetSize] = (index &+ 1) % poolSize
                return buffer
            }
            index = (index &+ 1) % poolSize
        }

        return nil
    }

    /// Release buffer back to pool - O(1)
    @inlinable @inline(__always)
    public func release(_ buffer: UnsafeMutablePointer<Float>, size: Int) {
        let targetSize = 1 << (Int.bitWidth - (size - 1).leadingZeroBitCount)

        guard let poolPtr = pools[targetSize],
              let poolSize = poolSizes[targetSize] else {
            return
        }

        // Find empty slot
        for i in 0..<poolSize {
            if poolPtr[i] == nil {
                poolPtr[i] = buffer
                return
            }
        }
    }
}

// MARK: - Zero-Allocation DSP Processor

/// Real-time safe DSP with pre-allocated scratch space
public final class ZeroAllocDSP {

    // Pre-allocated FFT setup
    private let fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int

    // Pre-allocated scratch buffers
    private let realBuffer: UnsafeMutablePointer<Float>
    private let imagBuffer: UnsafeMutablePointer<Float>
    private let magnitudeBuffer: UnsafeMutablePointer<Float>
    private let windowBuffer: UnsafeMutablePointer<Float>

    // Pre-computed reciprocals
    private let sizeReciprocal: Float
    private let halfSizeReciprocal: Float

    public init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        // Pre-allocate all buffers
        self.realBuffer = .allocate(capacity: fftSize)
        self.imagBuffer = .allocate(capacity: fftSize)
        self.magnitudeBuffer = .allocate(capacity: fftSize / 2)
        self.windowBuffer = .allocate(capacity: fftSize)

        // Initialize buffers
        realBuffer.initialize(repeating: 0, count: fftSize)
        imagBuffer.initialize(repeating: 0, count: fftSize)
        magnitudeBuffer.initialize(repeating: 0, count: fftSize / 2)

        // Pre-compute Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        for i in 0..<fftSize {
            windowBuffer[i] = window[i]
        }

        // Pre-compute reciprocals (avoid division in hot path)
        self.sizeReciprocal = 1.0 / Float(fftSize)
        self.halfSizeReciprocal = 2.0 / Float(fftSize)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
        realBuffer.deallocate()
        imagBuffer.deallocate()
        magnitudeBuffer.deallocate()
        windowBuffer.deallocate()
    }

    /// Compute FFT magnitudes - ZERO allocations
    @inlinable
    public func computeFFTMagnitudes(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        guard let setup = fftSetup else { return }

        let count = min(frameCount, fftSize)

        // Apply window (in-place to real buffer)
        vDSP_vmul(input, 1, windowBuffer, 1, realBuffer, 1, vDSP_Length(count))

        // Zero pad if needed
        if count < fftSize {
            memset(realBuffer.advanced(by: count), 0, (fftSize - count) * MemoryLayout<Float>.size)
        }

        // Clear imaginary
        memset(imagBuffer, 0, fftSize * MemoryLayout<Float>.size)

        // Execute FFT
        vDSP_DFT_Execute(setup, realBuffer, imagBuffer, realBuffer, imagBuffer)

        // Compute magnitudes using SIMD
        var splitComplex = DSPSplitComplex(realp: realBuffer, imagp: imagBuffer)
        vDSP_zvmags(&splitComplex, 1, output, 1, vDSP_Length(fftSize / 2))

        // Scale (using pre-computed reciprocal)
        var scale = halfSizeReciprocal
        vDSP_vsmul(output, 1, &scale, output, 1, vDSP_Length(fftSize / 2))
    }

    /// Apply gain with SIMD - ZERO allocations
    @inlinable @inline(__always)
    public func applyGain(
        _ buffer: UnsafeMutablePointer<Float>,
        gain: Float,
        frameCount: Int
    ) {
        var g = gain
        vDSP_vsmul(buffer, 1, &g, buffer, 1, vDSP_Length(frameCount))
    }

    /// Mix two buffers - ZERO allocations
    @inlinable @inline(__always)
    public func mix(
        _ a: UnsafePointer<Float>,
        _ b: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        mixRatio: Float,
        frameCount: Int
    ) {
        // output = a * (1 - mix) + b * mix
        var oneMinusMix = 1.0 - mixRatio
        var mix = mixRatio

        vDSP_vsmsma(a, 1, &oneMinusMix, b, 1, &mix, output, 1, vDSP_Length(frameCount))
    }

    /// Envelope follower - ZERO allocations
    @inlinable @inline(__always)
    public func envelopeFollow(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        attack: Float,
        release: Float,
        frameCount: Int,
        state: inout Float
    ) {
        for i in 0..<frameCount {
            let sample = abs(input[i])
            let coeff = sample > state ? attack : release
            state = state + coeff * (sample - state)
            output[i] = state
        }
    }
}

// MARK: - Async GPU Frame Processor

#if canImport(Metal)
/// GPU processing without blocking waitUntilCompleted()
public final class AsyncGPUProcessor {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // Triple buffer for async processing
    private var frameBuffers: [MTLBuffer?] = [nil, nil, nil]
    private var currentBuffer = 0

    // Completion tracking
    private let completionQueue = DispatchQueue(label: "gpu.completion", qos: .userInteractive)
    private var pendingFrames: [Int: Bool] = [:]

    public init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue

        // Pre-allocate frame buffers
        let bufferSize = 1920 * 1080 * 4 // BGRA
        for i in 0..<3 {
            frameBuffers[i] = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        }
    }

    /// Submit frame for async processing - NON-BLOCKING
    public func submitFrame(
        texture: MTLTexture,
        completion: @escaping (MTLBuffer?) -> Void
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            completion(nil)
            return
        }

        let bufferIndex = currentBuffer
        currentBuffer = (currentBuffer + 1) % 3

        guard let targetBuffer = frameBuffers[bufferIndex] else {
            completion(nil)
            return
        }

        // Setup blit from texture to buffer
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(
                from: texture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                to: targetBuffer,
                destinationOffset: 0,
                destinationBytesPerRow: texture.width * 4,
                destinationBytesPerImage: texture.width * texture.height * 4
            )
            blitEncoder.endEncoding()
        }

        // Async completion - NO waitUntilCompleted!
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.completionQueue.async {
                completion(targetBuffer)
            }
        }

        commandBuffer.commit()
    }

    /// Batch submit multiple frames
    public func submitBatch(
        textures: [MTLTexture],
        completion: @escaping ([MTLBuffer?]) -> Void
    ) {
        let group = DispatchGroup()
        var results = [MTLBuffer?](repeating: nil, count: textures.count)

        for (index, texture) in textures.enumerated() {
            group.enter()
            submitFrame(texture: texture) { buffer in
                results[index] = buffer
                group.leave()
            }
        }

        group.notify(queue: completionQueue) {
            completion(results)
        }
    }
}
#endif

// MARK: - Latency Compensation Engine

/// Precise audio-visual latency compensation
public final class LatencyCompensator {

    /// Measured pipeline latencies
    public struct PipelineLatency {
        public var audioInput: TimeInterval = 0.0106  // 10.6ms @ 48kHz/512
        public var audioProcessing: TimeInterval = 0.002
        public var visualRendering: TimeInterval = 0.008  // 8ms @ 120fps
        public var displayOutput: TimeInterval = 0.004
        public var networkBuffer: TimeInterval = 0.0

        public var total: TimeInterval {
            audioInput + audioProcessing + visualRendering + displayOutput + networkBuffer
        }
    }

    private var latency = PipelineLatency()
    private var compensationEnabled = true

    // Circular buffer for timestamp correlation
    private let timestampBuffer = RingBuffer<(audio: UInt64, visual: UInt64)>(capacity: 64)

    public init() {}

    /// Calculate compensation delay for visual sync
    @inlinable
    public func visualCompensation() -> TimeInterval {
        guard compensationEnabled else { return 0 }
        return latency.audioInput + latency.audioProcessing
    }

    /// Calculate compensation for audio preview
    @inlinable
    public func audioCompensation() -> TimeInterval {
        guard compensationEnabled else { return 0 }
        return latency.visualRendering + latency.displayOutput
    }

    /// Update latency measurement
    public func measureLatency(audioTimestamp: UInt64, visualTimestamp: UInt64) {
        timestampBuffer.push((audio: audioTimestamp, visual: visualTimestamp))

        // Calculate running average
        guard timestampBuffer.count >= 16 else { return }

        var totalDiff: UInt64 = 0
        var count = 0

        for i in 0..<min(timestampBuffer.count, 32) {
            if let sample = timestampBuffer.peek(at: i) {
                if sample.visual > sample.audio {
                    totalDiff += sample.visual - sample.audio
                    count += 1
                }
            }
        }

        if count > 0 {
            let avgDiffNs = totalDiff / UInt64(count)
            let measuredLatency = TimeInterval(avgDiffNs) / 1_000_000_000.0

            // Smooth update
            latency.visualRendering = latency.visualRendering * 0.9 + measuredLatency * 0.1
        }
    }

    /// Configure latencies
    public func configure(
        audioInput: TimeInterval? = nil,
        audioProcessing: TimeInterval? = nil,
        visualRendering: TimeInterval? = nil,
        displayOutput: TimeInterval? = nil,
        networkBuffer: TimeInterval? = nil
    ) {
        if let ai = audioInput { latency.audioInput = ai }
        if let ap = audioProcessing { latency.audioProcessing = ap }
        if let vr = visualRendering { latency.visualRendering = vr }
        if let d = displayOutput { latency.displayOutput = d }
        if let nb = networkBuffer { latency.networkBuffer = nb }
    }
}

// MARK: - Ring Buffer (Optimized)

/// Cache-optimized ring buffer
public struct RingBuffer<T> {
    private var buffer: [T?]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private let capacity: Int
    private let mask: Int

    public init(capacity: Int) {
        // Power of 2 for fast modulo
        let pow2 = 1 << (Int.bitWidth - (capacity - 1).leadingZeroBitCount)
        self.capacity = pow2
        self.mask = pow2 - 1
        self.buffer = [T?](repeating: nil, count: pow2)
    }

    @inlinable
    public mutating func push(_ value: T) {
        buffer[writeIndex] = value
        writeIndex = (writeIndex &+ 1) & mask

        // Overwrite oldest if full
        if writeIndex == readIndex {
            readIndex = (readIndex &+ 1) & mask
        }
    }

    @inlinable
    public mutating func pop() -> T? {
        guard readIndex != writeIndex else { return nil }
        let value = buffer[readIndex]
        buffer[readIndex] = nil
        readIndex = (readIndex &+ 1) & mask
        return value
    }

    @inlinable
    public func peek(at offset: Int = 0) -> T? {
        let index = (readIndex &+ offset) & mask
        return buffer[index]
    }

    @inlinable
    public var count: Int {
        return (writeIndex &- readIndex) & mask
    }

    @inlinable
    public var isEmpty: Bool {
        return readIndex == writeIndex
    }
}

// MARK: - Easing Functions (Visual Quality)

/// High-quality easing functions for smooth animations
@frozen
public struct Easing {

    // Pre-computed coefficients
    private static let c1: Float = 1.70158
    private static let c2: Float = c1 * 1.525
    private static let c3: Float = c1 + 1
    private static let c4: Float = (2 * .pi) / 3
    private static let c5: Float = (2 * .pi) / 4.5

    // MARK: - Basic Easing

    @inlinable @inline(__always)
    public static func linear(_ t: Float) -> Float {
        return t
    }

    @inlinable @inline(__always)
    public static func easeInQuad(_ t: Float) -> Float {
        return t * t
    }

    @inlinable @inline(__always)
    public static func easeOutQuad(_ t: Float) -> Float {
        return 1 - (1 - t) * (1 - t)
    }

    @inlinable @inline(__always)
    public static func easeInOutQuad(_ t: Float) -> Float {
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    // MARK: - Cubic Easing

    @inlinable @inline(__always)
    public static func easeInCubic(_ t: Float) -> Float {
        return t * t * t
    }

    @inlinable @inline(__always)
    public static func easeOutCubic(_ t: Float) -> Float {
        return 1 - pow(1 - t, 3)
    }

    @inlinable @inline(__always)
    public static func easeInOutCubic(_ t: Float) -> Float {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    // MARK: - Exponential Easing

    @inlinable @inline(__always)
    public static func easeInExpo(_ t: Float) -> Float {
        return t == 0 ? 0 : pow(2, 10 * t - 10)
    }

    @inlinable @inline(__always)
    public static func easeOutExpo(_ t: Float) -> Float {
        return t == 1 ? 1 : 1 - pow(2, -10 * t)
    }

    @inlinable @inline(__always)
    public static func easeInOutExpo(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        return t < 0.5
            ? pow(2, 20 * t - 10) / 2
            : (2 - pow(2, -20 * t + 10)) / 2
    }

    // MARK: - Elastic Easing (Musical)

    @inlinable @inline(__always)
    public static func easeInElastic(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        return -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * c4)
    }

    @inlinable @inline(__always)
    public static func easeOutElastic(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }

    @inlinable @inline(__always)
    public static func easeInOutElastic(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        return t < 0.5
            ? -(pow(2, 20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
            : (pow(2, -20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1
    }

    // MARK: - Back Easing (Overshoot)

    @inlinable @inline(__always)
    public static func easeInBack(_ t: Float) -> Float {
        return c3 * t * t * t - c1 * t * t
    }

    @inlinable @inline(__always)
    public static func easeOutBack(_ t: Float) -> Float {
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    @inlinable @inline(__always)
    public static func easeInOutBack(_ t: Float) -> Float {
        return t < 0.5
            ? (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
            : (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    }

    // MARK: - Bounce Easing

    @inlinable @inline(__always)
    public static func easeOutBounce(_ t: Float) -> Float {
        let n1: Float = 7.5625
        let d1: Float = 2.75

        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            let t1 = t - 1.5 / d1
            return n1 * t1 * t1 + 0.75
        } else if t < 2.5 / d1 {
            let t1 = t - 2.25 / d1
            return n1 * t1 * t1 + 0.9375
        } else {
            let t1 = t - 2.625 / d1
            return n1 * t1 * t1 + 0.984375
        }
    }

    @inlinable @inline(__always)
    public static func easeInBounce(_ t: Float) -> Float {
        return 1 - easeOutBounce(1 - t)
    }

    @inlinable @inline(__always)
    public static func easeInOutBounce(_ t: Float) -> Float {
        return t < 0.5
            ? (1 - easeOutBounce(1 - 2 * t)) / 2
            : (1 + easeOutBounce(2 * t - 1)) / 2
    }

    // MARK: - Bio-Reactive Smooth (Custom for Echoelmusic)

    /// Smooth easing optimized for bio-reactive transitions
    @inlinable @inline(__always)
    public static func bioSmooth(_ t: Float, coherence: Float = 0.5) -> Float {
        // Blend between smooth and elastic based on coherence
        let smooth = easeInOutCubic(t)
        let elastic = easeOutElastic(t)
        return smooth * (1 - coherence) + elastic * coherence
    }

    /// Musical beat-synced easing
    @inlinable @inline(__always)
    public static func beatSync(_ t: Float, intensity: Float = 0.5) -> Float {
        // Quick attack, smooth release
        let attack = easeOutExpo(t)
        let release = easeOutCubic(t)
        return attack * intensity + release * (1 - intensity)
    }
}

// MARK: - Optimized Color Processing

/// SIMD-accelerated color operations
@frozen
public struct SIMDColor {

    /// HSV to RGB conversion (vectorized for batch processing)
    @inlinable
    public static func hsvToRGB(
        h: Float, s: Float, v: Float
    ) -> SIMD3<Float> {
        let c = v * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = v - c

        let segment = Int(h * 6) % 6

        var rgb: SIMD3<Float>
        switch segment {
        case 0: rgb = SIMD3(c, x, 0)
        case 1: rgb = SIMD3(x, c, 0)
        case 2: rgb = SIMD3(0, c, x)
        case 3: rgb = SIMD3(0, x, c)
        case 4: rgb = SIMD3(x, 0, c)
        default: rgb = SIMD3(c, 0, x)
        }

        return rgb + SIMD3(repeating: m)
    }

    /// RGB to HSV conversion
    @inlinable
    public static func rgbToHSV(
        _ rgb: SIMD3<Float>
    ) -> SIMD3<Float> {
        let maxC = rgb.max()
        let minC = rgb.min()
        let delta = maxC - minC

        var h: Float = 0
        if delta > 0.00001 {
            if maxC == rgb.x {
                h = fmod((rgb.y - rgb.z) / delta, 6) / 6
            } else if maxC == rgb.y {
                h = ((rgb.z - rgb.x) / delta + 2) / 6
            } else {
                h = ((rgb.x - rgb.y) / delta + 4) / 6
            }
        }

        let s = maxC > 0 ? delta / maxC : 0

        return SIMD3(h < 0 ? h + 1 : h, s, maxC)
    }

    /// Batch HSV to RGB using Accelerate
    @inlinable
    public static func batchHSVtoRGB(
        hue: UnsafePointer<Float>,
        saturation: UnsafePointer<Float>,
        value: UnsafePointer<Float>,
        red: UnsafeMutablePointer<Float>,
        green: UnsafeMutablePointer<Float>,
        blue: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        for i in 0..<count {
            let rgb = hsvToRGB(h: hue[i], s: saturation[i], v: value[i])
            red[i] = rgb.x
            green[i] = rgb.y
            blue[i] = rgb.z
        }
    }

    /// Apply gamma correction (SIMD)
    @inlinable
    public static func applyGamma(
        _ color: SIMD3<Float>,
        gamma: Float = 2.2
    ) -> SIMD3<Float> {
        let invGamma = 1.0 / gamma
        return SIMD3(
            pow(color.x, invGamma),
            pow(color.y, invGamma),
            pow(color.z, invGamma)
        )
    }

    /// Linear to sRGB conversion
    @inlinable
    public static func linearToSRGB(_ linear: SIMD3<Float>) -> SIMD3<Float> {
        func convert(_ c: Float) -> Float {
            return c <= 0.0031308
                ? c * 12.92
                : 1.055 * pow(c, 1.0 / 2.4) - 0.055
        }
        return SIMD3(convert(linear.x), convert(linear.y), convert(linear.z))
    }

    /// sRGB to Linear conversion
    @inlinable
    public static func sRGBToLinear(_ srgb: SIMD3<Float>) -> SIMD3<Float> {
        func convert(_ c: Float) -> Float {
            return c <= 0.04045
                ? c / 12.92
                : pow((c + 0.055) / 1.055, 2.4)
        }
        return SIMD3(convert(srgb.x), convert(srgb.y), convert(srgb.z))
    }
}

// MARK: - Performance Metrics

/// Real-time performance monitoring
public final class PerformanceMetrics {

    public static let shared = PerformanceMetrics()

    // Circular buffers for metrics
    private var audioCallbackTimes = RingBuffer<UInt64>(capacity: 128)
    private var renderFrameTimes = RingBuffer<UInt64>(capacity: 128)
    private var gpuFrameTimes = RingBuffer<UInt64>(capacity: 128)

    // Thresholds (in nanoseconds)
    private let audioThreshold: UInt64 = 5_000_000  // 5ms
    private let renderThreshold: UInt64 = 8_000_000  // 8ms @ 120fps
    private let gpuThreshold: UInt64 = 16_000_000   // 16ms @ 60fps

    // Statistics
    private(set) public var audioDropouts: Int = 0
    private(set) public var frameMisses: Int = 0

    private init() {}

    /// Record audio callback duration
    @inlinable
    public func recordAudioCallback(durationNs: UInt64) {
        audioCallbackTimes.push(durationNs)
        if durationNs > audioThreshold {
            audioDropouts &+= 1
        }
    }

    /// Record render frame duration
    @inlinable
    public func recordRenderFrame(durationNs: UInt64) {
        renderFrameTimes.push(durationNs)
        if durationNs > renderThreshold {
            frameMisses &+= 1
        }
    }

    /// Get average audio callback time (ms)
    public var avgAudioTime: Double {
        var total: UInt64 = 0
        var count = 0
        for i in 0..<min(audioCallbackTimes.count, 64) {
            if let t = audioCallbackTimes.peek(at: i) {
                total &+= t
                count += 1
            }
        }
        return count > 0 ? Double(total) / Double(count) / 1_000_000.0 : 0
    }

    /// Get average render frame time (ms)
    public var avgRenderTime: Double {
        var total: UInt64 = 0
        var count = 0
        for i in 0..<min(renderFrameTimes.count, 64) {
            if let t = renderFrameTimes.peek(at: i) {
                total &+= t
                count += 1
            }
        }
        return count > 0 ? Double(total) / Double(count) / 1_000_000.0 : 0
    }

    /// Reset statistics
    public func reset() {
        audioDropouts = 0
        frameMisses = 0
    }
}
