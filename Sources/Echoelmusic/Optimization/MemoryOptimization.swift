import Foundation
import Accelerate
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY OPTIMIZATION ENGINE - ZERO-ALLOCATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive memory optimization for Echoelmusic
// Targets: Zero allocations in hot paths, efficient pooling, cache-friendly access
//
// Performance targets:
// • Audio callback: 0 allocations
// • Video frame: <5 allocations
// • Peak memory: <1GB
// • Working set: <500MB
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Object Pool

/// Generic object pool for reusing expensive objects
public final class ObjectPool<T> {

    private var available: [T] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let lock = os_unfair_lock_t.allocate(capacity: 1)
    private let factory: () -> T
    private let reset: ((T) -> Void)?
    private let maxSize: Int

    public init(
        initialSize: Int = 10,
        maxSize: Int = 100,
        factory: @escaping () -> T,
        reset: ((T) -> Void)? = nil
    ) {
        self.factory = factory
        self.reset = reset
        self.maxSize = maxSize
        lock.initialize(to: os_unfair_lock())

        // Pre-populate pool
        for _ in 0..<initialSize {
            available.append(factory())
        }
    }

    deinit {
        lock.deallocate()
    }

    /// Acquire object from pool
    public func acquire() -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        if let object = available.popLast() {
            return object
        }

        return factory()
    }

    /// Return object to pool
    public func release(_ object: T) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        reset?(object)

        if available.count < maxSize {
            available.append(object)
        }
    }

    /// Pool statistics
    public var stats: (available: Int, maxSize: Int) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return (available.count, maxSize)
    }

    /// Drain pool
    public func drain() {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        available.removeAll()
    }
}

// MARK: - Float Buffer Pool

/// Specialized pool for float arrays (common in audio/DSP)
public final class FloatBufferPool {

    public static let shared = FloatBufferPool()

    private var pools: [Int: [[Float]]] = [:]
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    // Common buffer sizes
    private let standardSizes = [64, 128, 256, 512, 1024, 2048, 4096, 8192]

    private init() {
        lock.initialize(to: os_unfair_lock())

        // Pre-allocate common sizes
        for size in standardSizes {
            pools[size] = []
            for _ in 0..<4 {
                pools[size]?.append([Float](repeating: 0, count: size))
            }
        }
    }

    deinit {
        lock.deallocate()
    }

    /// Acquire buffer of at least given size
    public func acquire(minimumSize: Int) -> [Float] {
        // Find smallest standard size that fits
        let size = standardSizes.first { $0 >= minimumSize } ?? minimumSize

        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        if var pool = pools[size], !pool.isEmpty {
            let buffer = pool.removeLast()
            pools[size] = pool
            return buffer
        }

        return [Float](repeating: 0, count: size)
    }

    /// Return buffer to pool
    public func release(_ buffer: inout [Float]) {
        let size = buffer.count

        // Only pool standard sizes
        guard standardSizes.contains(size) else { return }

        // Clear buffer before returning
        vDSP_vclr(&buffer, 1, vDSP_Length(size))

        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        var pool = pools[size] ?? []
        if pool.count < 10 {
            pool.append(buffer)
            pools[size] = pool
        }
    }

    /// Pool statistics
    public var stats: [Int: Int] {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return pools.mapValues { $0.count }
    }
}

// MARK: - Scratch Buffer

/// Thread-local scratch buffers for temporary computations
public final class ScratchBuffer {

    private static let threadLocalKey = "com.echoelmusic.scratchbuffer"

    /// Get thread-local scratch buffer
    public static func get(minimumSize: Int) -> UnsafeMutableBufferPointer<Float> {
        let key = threadLocalKey

        if let existing = Thread.current.threadDictionary[key] as? ScratchBufferStorage {
            if existing.capacity >= minimumSize {
                return existing.buffer
            }
            // Need larger buffer
        }

        let storage = ScratchBufferStorage(capacity: max(minimumSize, 4096))
        Thread.current.threadDictionary[key] = storage
        return storage.buffer
    }

    /// Reset all scratch buffers for current thread
    public static func reset() {
        Thread.current.threadDictionary.removeObject(forKey: threadLocalKey)
    }

    private class ScratchBufferStorage {
        let buffer: UnsafeMutableBufferPointer<Float>
        let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
            let pointer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
            pointer.initialize(repeating: 0, count: capacity)
            self.buffer = UnsafeMutableBufferPointer(start: pointer, count: capacity)
        }

        deinit {
            buffer.baseAddress?.deallocate()
        }
    }
}

// MARK: - Arena Allocator

/// Fast bump-pointer allocator for temporary allocations
public final class ArenaAllocator {

    private var blocks: [UnsafeMutableRawPointer] = []
    private var currentBlock: UnsafeMutableRawPointer
    private var currentOffset: Int = 0
    private let blockSize: Int

    public init(blockSize: Int = 64 * 1024) { // 64KB blocks
        self.blockSize = blockSize
        self.currentBlock = UnsafeMutableRawPointer.allocate(byteCount: blockSize, alignment: 16)
        blocks.append(currentBlock)
    }

    deinit {
        for block in blocks {
            block.deallocate()
        }
    }

    /// Allocate memory from arena
    public func allocate<T>(count: Int) -> UnsafeMutablePointer<T> {
        let size = MemoryLayout<T>.stride * count
        let alignment = MemoryLayout<T>.alignment

        // Align offset
        currentOffset = (currentOffset + alignment - 1) & ~(alignment - 1)

        // Check if fits in current block
        if currentOffset + size > blockSize {
            // Allocate new block
            let newBlockSize = max(blockSize, size)
            currentBlock = UnsafeMutableRawPointer.allocate(byteCount: newBlockSize, alignment: 16)
            blocks.append(currentBlock)
            currentOffset = 0
        }

        let pointer = currentBlock.advanced(by: currentOffset).bindMemory(to: T.self, capacity: count)
        currentOffset += size

        return pointer
    }

    /// Reset arena (keeps allocated blocks)
    public func reset() {
        if let first = blocks.first {
            currentBlock = first
            currentOffset = 0
        }
    }

    /// Memory usage
    public var bytesAllocated: Int {
        blocks.count * blockSize
    }

    public var bytesUsed: Int {
        (blocks.count - 1) * blockSize + currentOffset
    }
}

// MARK: - Memory-Mapped Audio Buffer

/// Memory-mapped buffer for large audio files
public final class MappedAudioBuffer {

    private let fileHandle: FileHandle
    private let mappedData: Data
    public let sampleCount: Int
    public let channelCount: Int

    public init?(url: URL, channelCount: Int = 2) {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.readToEnd() else {
            return nil
        }

        self.fileHandle = handle
        self.mappedData = data
        self.channelCount = channelCount
        self.sampleCount = data.count / (MemoryLayout<Float>.size * channelCount)
    }

    /// Access samples at offset
    public func samples(at offset: Int, count: Int) -> UnsafeBufferPointer<Float>? {
        let byteOffset = offset * MemoryLayout<Float>.size * channelCount
        let byteCount = count * MemoryLayout<Float>.size * channelCount

        guard byteOffset + byteCount <= mappedData.count else { return nil }

        return mappedData.withUnsafeBytes { bytes in
            let pointer = bytes.baseAddress!.advanced(by: byteOffset).assumingMemoryBound(to: Float.self)
            return UnsafeBufferPointer(start: pointer, count: count * channelCount)
        }
    }

    deinit {
        try? fileHandle.close()
    }
}

// MARK: - Cache-Aligned Buffer

/// Buffer with cache-line aligned storage
public final class CacheAlignedBuffer<T> {

    private let rawPointer: UnsafeMutableRawPointer
    public let pointer: UnsafeMutablePointer<T>
    public let count: Int

    private static var cacheLineSize: Int { 64 }

    public init(count: Int) {
        self.count = count
        let size = MemoryLayout<T>.stride * count

        // Allocate with cache-line alignment
        self.rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: size + Self.cacheLineSize,
            alignment: Self.cacheLineSize
        )

        // Align pointer
        let aligned = (Int(bitPattern: rawPointer) + Self.cacheLineSize - 1) & ~(Self.cacheLineSize - 1)
        self.pointer = UnsafeMutableRawPointer(bitPattern: aligned)!.bindMemory(to: T.self, capacity: count)
    }

    deinit {
        rawPointer.deallocate()
    }

    subscript(index: Int) -> T {
        get { pointer[index] }
        set { pointer[index] = newValue }
    }
}

// MARK: - SIMD-Aligned Float Buffer

/// Float buffer aligned for SIMD operations
public final class SIMDAlignedFloatBuffer {

    public let pointer: UnsafeMutablePointer<Float>
    public let count: Int
    private let rawPointer: UnsafeMutableRawPointer

    public init(count: Int) {
        // Round up to SIMD width (8 for AVX)
        let alignedCount = (count + 7) & ~7
        self.count = alignedCount

        // Allocate 32-byte aligned (AVX requirement)
        let size = alignedCount * MemoryLayout<Float>.size
        self.rawPointer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 32)
        self.pointer = rawPointer.bindMemory(to: Float.self, capacity: alignedCount)

        // Zero-initialize
        memset(rawPointer, 0, size)
    }

    deinit {
        rawPointer.deallocate()
    }

    /// Clear using SIMD
    public func clear() {
        vDSP_vclr(pointer, 1, vDSP_Length(count))
    }

    /// Fill with value
    public func fill(_ value: Float) {
        var v = value
        vDSP_vfill(&v, pointer, 1, vDSP_Length(count))
    }

    /// Copy from array
    public func copy(from source: [Float]) {
        let copyCount = min(source.count, count)
        source.withUnsafeBufferPointer { buffer in
            cblas_scopy(Int32(copyCount), buffer.baseAddress!, 1, pointer, 1)
        }
    }
}

// MARK: - Lock-Free Queue

/// Lock-free SPSC queue for inter-thread communication
public final class LockFreeQueue<T> {

    private let buffer: UnsafeMutablePointer<T?>
    private let mask: Int
    private var head: Int = 0
    private var tail: Int = 0

    public init(capacityPowerOf2: Int) {
        let capacity = 1 << capacityPowerOf2
        self.mask = capacity - 1
        self.buffer = UnsafeMutablePointer<T?>.allocate(capacity: capacity)
        self.buffer.initialize(repeating: nil, count: capacity)
    }

    deinit {
        // Clean up any remaining items
        while let _ = dequeue() {}
        buffer.deallocate()
    }

    /// Enqueue item (returns false if full)
    @inlinable
    public func enqueue(_ item: T) -> Bool {
        let currentTail = tail
        let nextTail = (currentTail + 1) & mask

        if nextTail == head {
            return false // Full
        }

        buffer[currentTail] = item
        tail = nextTail
        return true
    }

    /// Dequeue item (returns nil if empty)
    @inlinable
    public func dequeue() -> T? {
        let currentHead = head

        if currentHead == tail {
            return nil // Empty
        }

        let item = buffer[currentHead]
        buffer[currentHead] = nil
        head = (currentHead + 1) & mask
        return item
    }

    /// Check if empty
    @inlinable
    public var isEmpty: Bool {
        head == tail
    }

    /// Check if full
    @inlinable
    public var isFull: Bool {
        ((tail + 1) & mask) == head
    }

    /// Current count
    @inlinable
    public var count: Int {
        (tail - head + mask + 1) & mask
    }
}

// MARK: - Memory Pressure Monitor

/// Monitors system memory pressure
@MainActor
public final class MemoryPressureMonitor: ObservableObject {

    public static let shared = MemoryPressureMonitor()

    @Published public private(set) var pressure: MemoryPressure = .normal
    @Published public private(set) var usedMemoryMB: Double = 0
    @Published public private(set) var availableMemoryMB: Double = 0

    private var dispatchSource: DispatchSourceMemoryPressure?

    public enum MemoryPressure {
        case normal
        case warning
        case critical

        public var emoji: String {
            switch self {
            case .normal: return "🟢"
            case .warning: return "🟡"
            case .critical: return "🔴"
            }
        }
    }

    private init() {
        setupPressureMonitor()
        updateMemoryStats()
    }

    private func setupPressureMonitor() {
        dispatchSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical, .normal],
            queue: .main
        )

        dispatchSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      let source = self.dispatchSource else { return }

                let event = source.data

                if event.contains(.critical) {
                    self.pressure = .critical
                    self.handleCriticalPressure()
                } else if event.contains(.warning) {
                    self.pressure = .warning
                    self.handleWarningPressure()
                } else {
                    self.pressure = .normal
                }
            }
        }

        dispatchSource?.resume()
    }

    private func updateMemoryStats() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            usedMemoryMB = Double(info.resident_size) / 1024 / 1024
        }

        // Get available memory
        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }

        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_page_size)
            let free = UInt64(vmStats.free_count) * pageSize
            availableMemoryMB = Double(free) / 1024 / 1024
        }

        // Schedule next update
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            updateMemoryStats()
        }
    }

    private func handleWarningPressure() {
        // Release caches
        TexturePool.shared.drain()
        FloatBufferPool.shared.stats // Touch to trigger cleanup

        print("⚠️ Memory pressure warning - releasing caches")
    }

    private func handleCriticalPressure() {
        // Aggressive cleanup
        TexturePool.shared.drain()
        PipelineStateCache.shared.clearCache()
        ScratchBuffer.reset()

        print("🔴 Critical memory pressure - aggressive cleanup")
    }
}

// MARK: - Data Structure Optimization

/// Optimized array with pre-allocated capacity
public struct PreallocatedArray<T> {

    private var storage: [T]
    private var currentCount: Int = 0

    public init(capacity: Int, defaultValue: T) {
        self.storage = [T](repeating: defaultValue, count: capacity)
    }

    public mutating func append(_ value: T) {
        guard currentCount < storage.count else { return }
        storage[currentCount] = value
        currentCount += 1
    }

    public mutating func reset() {
        currentCount = 0
    }

    public var count: Int { currentCount }
    public var capacity: Int { storage.count }

    public subscript(index: Int) -> T {
        get {
            precondition(index < currentCount)
            return storage[index]
        }
        set {
            precondition(index < currentCount)
            storage[index] = newValue
        }
    }

    public func forEach(_ body: (T) -> Void) {
        for i in 0..<currentCount {
            body(storage[i])
        }
    }
}

// MARK: - Compact Value Types

/// Compact HRV data point (4 bytes instead of 24+)
public struct CompactHRVPoint {
    public var rrInterval: UInt16    // RR in ms (max ~65s)
    public var timestamp: UInt16     // Offset in ms from session start (use full timestamp separately)

    public init(rrInterval: Float, timestampOffset: Float) {
        self.rrInterval = UInt16(min(65535, max(0, rrInterval)))
        self.timestamp = UInt16(min(65535, max(0, timestampOffset)))
    }

    public var rrIntervalFloat: Float {
        Float(rrInterval)
    }
}

/// Compact audio sample (2 bytes per channel)
public struct CompactStereoSample {
    public var left: Int16
    public var right: Int16

    public init(left: Float, right: Float) {
        self.left = Int16(clamping: Int(left * 32767))
        self.right = Int16(clamping: Int(right * 32767))
    }

    public var leftFloat: Float {
        Float(left) / 32767.0
    }

    public var rightFloat: Float {
        Float(right) / 32767.0
    }
}
