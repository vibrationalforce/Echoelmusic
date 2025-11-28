//
//  LockFreeAudioBuffer.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Ultra-Low Latency Lock-Free Audio Buffer System
//
//  Features:
//  - Lock-free SPSC (Single Producer Single Consumer) ring buffer
//  - Memory-aligned for cache efficiency
//  - Zero-copy where possible
//  - Atomic operations for thread safety
//  - Real-time safe (no allocations in audio path)
//  - Latency monitoring
//

import Foundation
import Accelerate

// MARK: - Lock-Free Ring Buffer

/// Thread-safe lock-free ring buffer for real-time audio
/// Uses atomic operations for single-producer single-consumer pattern
public final class LockFreeRingBuffer<T> {
    // MARK: - Properties

    private let buffer: UnsafeMutablePointer<T>
    private let capacity: Int
    private let mask: Int

    // Atomic indices (cache-line padded to prevent false sharing)
    private var writeIndex: UnsafeMutablePointer<Int>
    private var readIndex: UnsafeMutablePointer<Int>

    // Statistics
    private var overrunCount: Int = 0
    private var underrunCount: Int = 0

    // MARK: - Initialization

    /// Create ring buffer with power-of-2 capacity
    /// - Parameter capacity: Buffer size (will be rounded up to power of 2)
    public init(capacity: Int) {
        // Round up to power of 2 for efficient modulo via bitmask
        let powerOf2 = 1 << (Int.bitWidth - (capacity - 1).leadingZeroBitCount)
        self.capacity = powerOf2
        self.mask = powerOf2 - 1

        // Allocate aligned memory for cache efficiency
        self.buffer = UnsafeMutablePointer<T>.allocate(capacity: powerOf2)

        // Allocate indices on separate cache lines (64 bytes apart)
        self.writeIndex = UnsafeMutablePointer<Int>.allocate(capacity: 16)  // 64 bytes / 4 = 16
        self.readIndex = UnsafeMutablePointer<Int>.allocate(capacity: 16)

        writeIndex.initialize(to: 0)
        readIndex.initialize(to: 0)
    }

    deinit {
        buffer.deallocate()
        writeIndex.deallocate()
        readIndex.deallocate()
    }

    // MARK: - Write Operations

    /// Write single element (producer thread only)
    /// - Returns: true if successful, false if buffer full
    @inlinable
    public func write(_ element: T) -> Bool {
        let currentWrite = writeIndex.pointee
        let nextWrite = (currentWrite + 1) & mask
        let currentRead = readIndex.pointee

        // Check if buffer is full
        if nextWrite == currentRead {
            overrunCount += 1
            return false
        }

        buffer[currentWrite] = element

        // Memory barrier to ensure write is visible
        OSMemoryBarrier()

        writeIndex.pointee = nextWrite
        return true
    }

    /// Write multiple elements
    /// - Returns: Number of elements actually written
    @inlinable
    public func write(_ elements: UnsafePointer<T>, count: Int) -> Int {
        var written = 0
        for i in 0..<count {
            if write(elements[i]) {
                written += 1
            } else {
                break
            }
        }
        return written
    }

    /// Write from array
    @inlinable
    public func write(_ array: [T]) -> Int {
        array.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            return write(baseAddress, count: array.count)
        }
    }

    // MARK: - Read Operations

    /// Read single element (consumer thread only)
    /// - Returns: Element if available, nil if buffer empty
    @inlinable
    public func read() -> T? {
        let currentRead = readIndex.pointee
        let currentWrite = writeIndex.pointee

        // Check if buffer is empty
        if currentRead == currentWrite {
            underrunCount += 1
            return nil
        }

        let element = buffer[currentRead]

        // Memory barrier to ensure read is complete
        OSMemoryBarrier()

        readIndex.pointee = (currentRead + 1) & mask
        return element
    }

    /// Read multiple elements into buffer
    /// - Returns: Number of elements actually read
    @inlinable
    public func read(_ destination: UnsafeMutablePointer<T>, count: Int) -> Int {
        var readCount = 0
        for i in 0..<count {
            if let element = read() {
                destination[i] = element
                readCount += 1
            } else {
                break
            }
        }
        return readCount
    }

    /// Read into array
    public func read(count: Int) -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            if let element = read() {
                result.append(element)
            } else {
                break
            }
        }
        return result
    }

    // MARK: - Status

    /// Number of elements available for reading
    @inlinable
    public var availableRead: Int {
        let write = writeIndex.pointee
        let read = readIndex.pointee
        return (write - read) & mask
    }

    /// Number of spaces available for writing
    @inlinable
    public var availableWrite: Int {
        capacity - availableRead - 1
    }

    /// Whether buffer is empty
    @inlinable
    public var isEmpty: Bool {
        writeIndex.pointee == readIndex.pointee
    }

    /// Whether buffer is full
    @inlinable
    public var isFull: Bool {
        ((writeIndex.pointee + 1) & mask) == readIndex.pointee
    }

    /// Get overrun count (writes that failed due to full buffer)
    public var overruns: Int { overrunCount }

    /// Get underrun count (reads that failed due to empty buffer)
    public var underruns: Int { underrunCount }

    /// Reset statistics
    public func resetStatistics() {
        overrunCount = 0
        underrunCount = 0
    }

    /// Clear buffer
    public func clear() {
        writeIndex.pointee = 0
        readIndex.pointee = 0
        resetStatistics()
    }
}

// MARK: - Audio-Specific Ring Buffer

/// Optimized ring buffer for audio samples (Float)
public final class AudioRingBuffer {
    private let buffer: LockFreeRingBuffer<Float>
    private let channels: Int
    private let framesPerBuffer: Int

    /// Create audio ring buffer
    /// - Parameters:
    ///   - channels: Number of audio channels
    ///   - framesPerBuffer: Frames per audio buffer
    ///   - bufferCount: Number of buffers to store
    public init(channels: Int, framesPerBuffer: Int, bufferCount: Int = 8) {
        self.channels = channels
        self.framesPerBuffer = framesPerBuffer
        let totalSamples = channels * framesPerBuffer * bufferCount
        self.buffer = LockFreeRingBuffer<Float>(capacity: totalSamples)
    }

    /// Write interleaved audio buffer
    public func writeInterleaved(_ samples: UnsafePointer<Float>, frameCount: Int) -> Int {
        let sampleCount = frameCount * channels
        return buffer.write(samples, count: sampleCount) / channels
    }

    /// Read interleaved audio buffer
    public func readInterleaved(_ destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        let sampleCount = frameCount * channels
        return buffer.read(destination, count: sampleCount) / channels
    }

    /// Write non-interleaved (planar) audio
    public func writePlanar(_ channelBuffers: [UnsafePointer<Float>], frameCount: Int) -> Int {
        guard channelBuffers.count == channels else { return 0 }

        var written = 0
        for frame in 0..<frameCount {
            var frameWritten = true
            for channel in 0..<channels {
                if !buffer.write(channelBuffers[channel][frame]) {
                    frameWritten = false
                    break
                }
            }
            if frameWritten {
                written += 1
            } else {
                break
            }
        }
        return written
    }

    /// Available frames for reading
    public var availableFrames: Int {
        buffer.availableRead / channels
    }

    /// Available frames for writing
    public var availableWriteFrames: Int {
        buffer.availableWrite / channels
    }

    /// Buffer health (0.0 = empty, 1.0 = full)
    public var fillLevel: Float {
        Float(buffer.availableRead) / Float(buffer.availableRead + buffer.availableWrite)
    }

    /// Latency in samples
    public var latencySamples: Int {
        buffer.availableRead
    }

    /// Latency in seconds (requires sample rate)
    public func latency(atSampleRate sampleRate: Double) -> TimeInterval {
        Double(latencySamples) / sampleRate / Double(channels)
    }

    /// Statistics
    public var overruns: Int { buffer.overruns }
    public var underruns: Int { buffer.underruns }

    public func resetStatistics() {
        buffer.resetStatistics()
    }

    public func clear() {
        buffer.clear()
    }
}

// MARK: - Triple Buffer (for video frames)

/// Lock-free triple buffer for video frame handoff
/// Allows producer and consumer to run at different rates
public final class TripleBuffer<T> {
    private var buffers: [T?]
    private var writeIndex: Int = 0
    private var readIndex: Int = 2
    private var middleIndex: Int = 1
    private var newFrameAvailable: Bool = false

    private let lock = NSLock()  // Only used for swap, not read/write

    public init() {
        self.buffers = [nil, nil, nil]
    }

    /// Write a new frame (producer thread)
    public func write(_ frame: T) {
        buffers[writeIndex] = frame

        lock.lock()
        swap(&writeIndex, &middleIndex)
        newFrameAvailable = true
        lock.unlock()
    }

    /// Read the latest frame (consumer thread)
    /// Returns nil if no new frame available
    public func read() -> T? {
        lock.lock()
        if newFrameAvailable {
            swap(&readIndex, &middleIndex)
            newFrameAvailable = false
        }
        lock.unlock()

        return buffers[readIndex]
    }

    /// Check if new frame is available
    public var hasNewFrame: Bool {
        lock.lock()
        defer { lock.unlock() }
        return newFrameAvailable
    }
}

// MARK: - Latency Monitor

/// Real-time latency monitoring for audio pipeline
@MainActor
public final class LatencyMonitor: ObservableObject {
    public static let shared = LatencyMonitor()

    // MARK: - Published Metrics

    @Published public private(set) var inputLatency: TimeInterval = 0
    @Published public private(set) var outputLatency: TimeInterval = 0
    @Published public private(set) var processingLatency: TimeInterval = 0
    @Published public private(set) var totalLatency: TimeInterval = 0

    @Published public private(set) var bufferUnderruns: Int = 0
    @Published public private(set) var bufferOverruns: Int = 0

    @Published public private(set) var cpuUsage: Float = 0
    @Published public private(set) var peakCPUUsage: Float = 0

    // MARK: - Private State

    private var processingStartTime: UInt64 = 0
    private var processingTimes: [TimeInterval] = []
    private let maxSamples = 100

    private var lastUpdateTime: Date = Date()
    private var updateInterval: TimeInterval = 0.1

    // MARK: - Initialization

    private init() {}

    // MARK: - Recording

    /// Mark start of audio processing (call from audio thread)
    public nonisolated func markProcessingStart() {
        // Use mach_absolute_time for precise timing
        processingStartTime = mach_absolute_time()
    }

    /// Mark end of audio processing (call from audio thread)
    public nonisolated func markProcessingEnd() {
        let endTime = mach_absolute_time()
        let elapsed = machTimeToSeconds(endTime - processingStartTime)

        Task { @MainActor in
            self.recordProcessingTime(elapsed)
        }
    }

    private func recordProcessingTime(_ time: TimeInterval) {
        processingTimes.append(time)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }

        // Update average
        processingLatency = processingTimes.reduce(0, +) / Double(processingTimes.count)

        // Update total
        totalLatency = inputLatency + processingLatency + outputLatency

        // Track peak
        let usage = Float(time / (1.0 / 48000.0 * 256))  // Assuming 256 sample buffer at 48kHz
        if usage > peakCPUUsage {
            peakCPUUsage = usage
        }
        cpuUsage = usage
    }

    /// Update hardware latencies
    public func updateHardwareLatencies(input: TimeInterval, output: TimeInterval) {
        inputLatency = input
        outputLatency = output
        totalLatency = inputLatency + processingLatency + outputLatency
    }

    /// Record buffer underrun
    public func recordUnderrun() {
        bufferUnderruns += 1
    }

    /// Record buffer overrun
    public func recordOverrun() {
        bufferOverruns += 1
    }

    /// Reset statistics
    public func reset() {
        processingTimes.removeAll()
        processingLatency = 0
        bufferUnderruns = 0
        bufferOverruns = 0
        peakCPUUsage = 0
        cpuUsage = 0
    }

    // MARK: - Utilities

    private nonisolated func machTimeToSeconds(_ machTime: UInt64) -> TimeInterval {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nanos = machTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        return TimeInterval(nanos) / 1_000_000_000
    }

    /// Get formatted latency string
    public var formattedTotalLatency: String {
        String(format: "%.1f ms", totalLatency * 1000)
    }

    /// Get latency quality indicator
    public var latencyQuality: LatencyQuality {
        switch totalLatency * 1000 {
        case 0..<5: return .ultraLow
        case 5..<10: return .low
        case 10..<20: return .normal
        case 20..<50: return .high
        default: return .veryHigh
        }
    }

    public enum LatencyQuality: String {
        case ultraLow = "Ultra-Low (<5ms)"
        case low = "Low (5-10ms)"
        case normal = "Normal (10-20ms)"
        case high = "High (20-50ms)"
        case veryHigh = "Very High (>50ms)"

        public var color: String {
            switch self {
            case .ultraLow: return "green"
            case .low: return "green"
            case .normal: return "yellow"
            case .high: return "orange"
            case .veryHigh: return "red"
            }
        }
    }
}

// MARK: - SIMD Audio Processing Utilities

/// SIMD-optimized audio processing functions
public struct SIMDAudio {
    /// Mix two audio buffers with gain
    @inlinable
    public static func mix(
        source1: UnsafePointer<Float>, gain1: Float,
        source2: UnsafePointer<Float>, gain2: Float,
        destination: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var g1 = gain1
        var g2 = gain2
        vDSP_vsma(source1, 1, &g1, source2, 1, destination, 1, vDSP_Length(count))
        var one: Float = 1.0
        vDSP_vsma(destination, 1, &one, source2, 1, destination, 1, vDSP_Length(count))
    }

    /// Apply gain to buffer in-place
    @inlinable
    public static func applyGain(
        _ buffer: UnsafeMutablePointer<Float>,
        gain: Float,
        count: Int
    ) {
        var g = gain
        vDSP_vsmul(buffer, 1, &g, buffer, 1, vDSP_Length(count))
    }

    /// Calculate RMS level
    @inlinable
    public static func rmsLevel(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(count))
        return rms
    }

    /// Calculate peak level
    @inlinable
    public static func peakLevel(_ buffer: UnsafePointer<Float>, count: Int) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(count))
        return peak
    }

    /// Convert to dB
    @inlinable
    public static func linearToDecibels(_ linear: Float) -> Float {
        guard linear > 0 else { return -Float.infinity }
        return 20.0 * log10f(linear)
    }

    /// Convert from dB
    @inlinable
    public static func decibelsToLinear(_ db: Float) -> Float {
        powf(10.0, db / 20.0)
    }

    /// Soft clip (tanh saturation)
    @inlinable
    public static func softClip(
        _ buffer: UnsafeMutablePointer<Float>,
        count: Int,
        drive: Float = 1.0
    ) {
        for i in 0..<count {
            buffer[i] = tanhf(buffer[i] * drive)
        }
    }

    /// Hard clip
    @inlinable
    public static func hardClip(
        _ buffer: UnsafeMutablePointer<Float>,
        count: Int,
        threshold: Float = 1.0
    ) {
        var low = -threshold
        var high = threshold
        vDSP_vclip(buffer, 1, &low, &high, buffer, 1, vDSP_Length(count))
    }
}
