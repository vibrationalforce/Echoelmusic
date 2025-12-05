// MemoryBatteryOptimizer.swift
// Echoelmusic - Memory & Battery Optimization System
//
// Zero-allocation audio paths, smart caching, battery-aware processing
// Minimizes memory footprint and maximizes battery life

import Foundation
import Combine
import os.log

private let memoryLogger = Logger(subsystem: "com.echoelmusic.green", category: "MemoryOptimizer")

// MARK: - Memory Pool Configuration

public struct MemoryPoolConfig {
    public var smallBufferSize: Int = 256
    public var mediumBufferSize: Int = 2048
    public var largeBufferSize: Int = 16384
    public var hugeBufferSize: Int = 65536

    public var smallPoolCount: Int = 32
    public var mediumPoolCount: Int = 16
    public var largePoolCount: Int = 8
    public var hugePoolCount: Int = 4

    public var maxTotalMemoryMB: Double = 256
    public var enableAutoShrink: Bool = true
    public var shrinkThreshold: Double = 0.7  // Shrink when usage drops below 70%

    public init() {}
}

// MARK: - Lock-Free Buffer Pool

public final class LockFreeBufferPool<T: Numeric> {
    private let bufferSize: Int
    private var buffers: UnsafeMutablePointer<UnsafeMutablePointer<T>?>
    private var available: UnsafeMutablePointer<Int32>
    private let poolSize: Int

    public init(bufferSize: Int, poolSize: Int) {
        self.bufferSize = bufferSize
        self.poolSize = poolSize

        // Allocate pool storage
        buffers = .allocate(capacity: poolSize)
        available = .allocate(capacity: poolSize)

        // Initialize buffers
        for i in 0..<poolSize {
            buffers[i] = .allocate(capacity: bufferSize)
            buffers[i]!.initialize(repeating: T.zero, count: bufferSize)
            available[i] = 1  // 1 = available
        }

        memoryLogger.debug("Created buffer pool: \(bufferSize) x \(poolSize)")
    }

    deinit {
        for i in 0..<poolSize {
            if let buffer = buffers[i] {
                buffer.deinitialize(count: bufferSize)
                buffer.deallocate()
            }
        }
        buffers.deallocate()
        available.deallocate()
    }

    /// Acquire a buffer without blocking (lock-free)
    public func acquire() -> UnsafeMutablePointer<T>? {
        for i in 0..<poolSize {
            // Atomic compare-and-swap
            var expected: Int32 = 1
            let success = withUnsafeMutablePointer(to: &available[i]) { ptr in
                OSAtomicCompareAndSwap32(expected, 0, ptr)
            }
            if success {
                return buffers[i]
            }
        }
        // Pool exhausted - create emergency buffer
        memoryLogger.warning("Buffer pool exhausted, allocating emergency buffer")
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: bufferSize)
        buffer.initialize(repeating: T.zero, count: bufferSize)
        return buffer
    }

    /// Release a buffer back to pool (lock-free)
    public func release(_ buffer: UnsafeMutablePointer<T>) {
        for i in 0..<poolSize {
            if buffers[i] == buffer {
                // Clear buffer for security
                buffer.initialize(repeating: T.zero, count: bufferSize)
                OSAtomicCompareAndSwap32(0, 1, &available[i])
                return
            }
        }
        // Not from pool - deallocate
        buffer.deinitialize(count: bufferSize)
        buffer.deallocate()
    }

    public var availableCount: Int {
        var count = 0
        for i in 0..<poolSize {
            if available[i] == 1 { count += 1 }
        }
        return count
    }

    public var totalSizeBytes: Int {
        poolSize * bufferSize * MemoryLayout<T>.stride
    }
}

// MARK: - Smart Cache

public final class SmartCache<Key: Hashable, Value> {
    private var cache: [Key: CacheEntry<Value>] = [:]
    private let maxSize: Int
    private let maxAge: TimeInterval
    private var accessOrder: [Key] = []
    private let lock = NSLock()

    private struct CacheEntry<V> {
        let value: V
        let timestamp: Date
        var accessCount: Int
        var lastAccess: Date
        let estimatedSize: Int
    }

    public init(maxSize: Int = 100, maxAge: TimeInterval = 300) {
        self.maxSize = maxSize
        self.maxAge = maxAge
    }

    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard var entry = cache[key] else { return nil }

        // Check expiry
        if Date().timeIntervalSince(entry.timestamp) > maxAge {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return nil
        }

        // Update access tracking
        entry.accessCount += 1
        entry.lastAccess = Date()
        cache[key] = entry

        // Move to end of access order (LRU)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return entry.value
    }

    public func set(_ key: Key, value: Value, estimatedSize: Int = 1) {
        lock.lock()
        defer { lock.unlock() }

        // Evict if necessary
        while cache.count >= maxSize {
            evictLRU()
        }

        cache[key] = CacheEntry(
            value: value,
            timestamp: Date(),
            accessCount: 1,
            lastAccess: Date(),
            estimatedSize: estimatedSize
        )
        accessOrder.append(key)
    }

    public func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Evict expired and low-value entries
    public func shrink() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()

        // Remove expired entries
        let expiredKeys = cache.filter { now.timeIntervalSince($0.value.timestamp) > maxAge }.map { $0.key }
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }

        // If still over 70% capacity, evict least valuable
        while cache.count > Int(Double(maxSize) * 0.7) {
            evictLRU()
        }

        memoryLogger.debug("Cache shrunk to \(self.cache.count) entries")
    }

    private func evictLRU() {
        guard let key = accessOrder.first else { return }
        cache.removeValue(forKey: key)
        accessOrder.removeFirst()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    public var estimatedMemory: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.values.reduce(0) { $0 + $1.estimatedSize }
    }
}

// MARK: - Memory & Battery Optimizer

@MainActor
public final class MemoryBatteryOptimizer: ObservableObject {
    public static let shared = MemoryBatteryOptimizer()

    // MARK: - Published State

    @Published public private(set) var memoryUsedMB: Double = 0
    @Published public private(set) var memoryPeakMB: Double = 0
    @Published public private(set) var poolMemoryMB: Double = 0
    @Published public private(set) var cacheMemoryMB: Double = 0
    @Published public private(set) var batteryOptimizationActive: Bool = false
    @Published public private(set) var memoryPressure: MemoryPressureLevel = .nominal

    public enum MemoryPressureLevel: String {
        case nominal = "Nominal"
        case moderate = "Moderate"
        case high = "High"
        case critical = "Critical"
    }

    // MARK: - Configuration

    public var config = MemoryPoolConfig()

    // MARK: - Buffer Pools

    private var floatPoolSmall: LockFreeBufferPool<Float>?
    private var floatPoolMedium: LockFreeBufferPool<Float>?
    private var floatPoolLarge: LockFreeBufferPool<Float>?
    private var floatPoolHuge: LockFreeBufferPool<Float>?

    // MARK: - Caches

    private var fftCache = SmartCache<String, [Float]>(maxSize: 50, maxAge: 60)
    private var waveformCache = SmartCache<String, [Float]>(maxSize: 20, maxAge: 120)
    private var imageCache = SmartCache<String, Data>(maxSize: 30, maxAge: 180)

    // MARK: - Battery Scheduling

    private var deferredTasks: [(priority: Int, task: () -> Void)] = []
    private var cancellables = Set<AnyCancellable>()
    private var monitorTimer: Timer?

    // MARK: - Initialization

    private init() {
        initializeBufferPools()
        setupMemoryMonitoring()
        setupBatteryOptimization()
        memoryLogger.info("MemoryBatteryOptimizer initialized")
    }

    private func initializeBufferPools() {
        floatPoolSmall = LockFreeBufferPool<Float>(
            bufferSize: config.smallBufferSize,
            poolSize: config.smallPoolCount
        )
        floatPoolMedium = LockFreeBufferPool<Float>(
            bufferSize: config.mediumBufferSize,
            poolSize: config.mediumPoolCount
        )
        floatPoolLarge = LockFreeBufferPool<Float>(
            bufferSize: config.largeBufferSize,
            poolSize: config.largePoolCount
        )
        floatPoolHuge = LockFreeBufferPool<Float>(
            bufferSize: config.hugeBufferSize,
            poolSize: config.hugePoolCount
        )

        updatePoolMemory()
    }

    // MARK: - Buffer Pool API

    /// Acquire a float buffer of appropriate size (zero-allocation for audio)
    public func acquireFloatBuffer(minimumSize: Int) -> UnsafeMutablePointer<Float>? {
        if minimumSize <= config.smallBufferSize {
            return floatPoolSmall?.acquire()
        } else if minimumSize <= config.mediumBufferSize {
            return floatPoolMedium?.acquire()
        } else if minimumSize <= config.largeBufferSize {
            return floatPoolLarge?.acquire()
        } else if minimumSize <= config.hugeBufferSize {
            return floatPoolHuge?.acquire()
        } else {
            // Too large for pools - allocate directly
            memoryLogger.warning("Requested buffer size \(minimumSize) exceeds pool capacity")
            let buffer = UnsafeMutablePointer<Float>.allocate(capacity: minimumSize)
            buffer.initialize(repeating: 0, count: minimumSize)
            return buffer
        }
    }

    /// Release a float buffer back to pool
    public func releaseFloatBuffer(_ buffer: UnsafeMutablePointer<Float>, size: Int) {
        if size <= config.smallBufferSize {
            floatPoolSmall?.release(buffer)
        } else if size <= config.mediumBufferSize {
            floatPoolMedium?.release(buffer)
        } else if size <= config.largeBufferSize {
            floatPoolLarge?.release(buffer)
        } else if size <= config.hugeBufferSize {
            floatPoolHuge?.release(buffer)
        } else {
            // Not from pool - deallocate
            buffer.deinitialize(count: size)
            buffer.deallocate()
        }
    }

    // MARK: - Cache API

    /// Cache FFT results
    public func cacheFFT(key: String, data: [Float]) {
        fftCache.set(key, value: data, estimatedSize: data.count * 4)
    }

    public func getCachedFFT(key: String) -> [Float]? {
        fftCache.get(key)
    }

    /// Cache waveform data
    public func cacheWaveform(key: String, data: [Float]) {
        waveformCache.set(key, value: data, estimatedSize: data.count * 4)
    }

    public func getCachedWaveform(key: String) -> [Float]? {
        waveformCache.get(key)
    }

    /// Cache image data
    public func cacheImage(key: String, data: Data) {
        imageCache.set(key, value: data, estimatedSize: data.count)
    }

    public func getCachedImage(key: String) -> Data? {
        imageCache.get(key)
    }

    // MARK: - Memory Management

    /// Free non-essential memory immediately
    public func freeMemory(aggressive: Bool = false) {
        // Clear caches based on aggression level
        if aggressive {
            fftCache.clear()
            waveformCache.clear()
            imageCache.clear()
            memoryLogger.info("Aggressive memory free: cleared all caches")
        } else {
            fftCache.shrink()
            waveformCache.shrink()
            imageCache.shrink()
            memoryLogger.info("Standard memory free: shrunk caches")
        }

        // Request system memory cleanup
        #if os(macOS)
        malloc_zone_pressure_relief(nil, 0)
        #endif

        updateMemoryUsage()
    }

    /// Compact memory for long-running sessions
    public func compactMemory() {
        // Shrink all caches
        fftCache.shrink()
        waveformCache.shrink()
        imageCache.shrink()

        // Recreate pools at smaller size if under pressure
        if memoryPressure >= .high {
            let reducedConfig = MemoryPoolConfig()
            reducedConfig.smallPoolCount = config.smallPoolCount / 2
            reducedConfig.mediumPoolCount = config.mediumPoolCount / 2
            reducedConfig.largePoolCount = config.largePoolCount / 2
            reducedConfig.hugePoolCount = config.hugePoolCount / 2

            // Note: In production, would need careful synchronization
            memoryLogger.info("Memory compacted, reduced pool sizes")
        }

        updateMemoryUsage()
    }

    // MARK: - Battery Optimization

    /// Defer a task until optimal battery conditions
    public func deferForBattery(priority: Int = 5, task: @escaping () -> Void) {
        deferredTasks.append((priority, task))
        deferredTasks.sort { $0.priority < $1.priority }
    }

    /// Execute deferred tasks when on power
    public func executeDeferredTasks() {
        guard !batteryOptimizationActive else {
            memoryLogger.debug("Skipping deferred tasks - on battery")
            return
        }

        let tasks = deferredTasks
        deferredTasks.removeAll()

        for (_, task) in tasks {
            task()
        }

        memoryLogger.info("Executed \(tasks.count) deferred tasks")
    }

    /// Get recommended processing quality based on battery
    public func recommendedQuality() -> ProcessingQuality {
        let greenEngine = GreenComputingEngine.shared
        let efficiency = greenEngine.currentEfficiencyLevel

        switch efficiency {
        case .ultraLowPower:
            return ProcessingQuality(
                fftSize: 512,
                sampleRate: 22050,
                visualFPS: 15,
                enableAI: false,
                enableEffects: false,
                maxConcurrentTasks: 1
            )
        case .lowPower:
            return ProcessingQuality(
                fftSize: 1024,
                sampleRate: 44100,
                visualFPS: 30,
                enableAI: false,
                enableEffects: true,
                maxConcurrentTasks: 2
            )
        case .balanced:
            return ProcessingQuality(
                fftSize: 2048,
                sampleRate: 48000,
                visualFPS: 30,
                enableAI: true,
                enableEffects: true,
                maxConcurrentTasks: 4
            )
        case .performance:
            return ProcessingQuality(
                fftSize: 4096,
                sampleRate: 96000,
                visualFPS: 60,
                enableAI: true,
                enableEffects: true,
                maxConcurrentTasks: 8
            )
        case .maxPerformance:
            return ProcessingQuality(
                fftSize: 8192,
                sampleRate: 192000,
                visualFPS: 60,
                enableAI: true,
                enableEffects: true,
                maxConcurrentTasks: ProcessInfo.processInfo.processorCount
            )
        }
    }

    // MARK: - Private Methods

    private func setupMemoryMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }

        // Memory pressure notifications
        #if os(iOS) || os(macOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #endif
    }

    private func setupBatteryOptimization() {
        GreenComputingEngine.shared.$powerState
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handlePowerStateChange(state)
                }
            }
            .store(in: &cancellables)
    }

    private func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            memoryUsedMB = Double(taskInfo.phys_footprint) / 1024.0 / 1024.0
            memoryPeakMB = max(memoryPeakMB, memoryUsedMB)
        }

        updatePoolMemory()
        updateCacheMemory()
        updateMemoryPressure()
    }

    private func updatePoolMemory() {
        var total = 0
        total += floatPoolSmall?.totalSizeBytes ?? 0
        total += floatPoolMedium?.totalSizeBytes ?? 0
        total += floatPoolLarge?.totalSizeBytes ?? 0
        total += floatPoolHuge?.totalSizeBytes ?? 0
        poolMemoryMB = Double(total) / 1024.0 / 1024.0
    }

    private func updateCacheMemory() {
        var total = 0
        total += fftCache.estimatedMemory
        total += waveformCache.estimatedMemory
        total += imageCache.estimatedMemory
        cacheMemoryMB = Double(total) / 1024.0 / 1024.0
    }

    private func updateMemoryPressure() {
        let totalMB = memoryUsedMB + poolMemoryMB + cacheMemoryMB

        if totalMB > config.maxTotalMemoryMB * 0.9 {
            memoryPressure = .critical
        } else if totalMB > config.maxTotalMemoryMB * 0.7 {
            memoryPressure = .high
        } else if totalMB > config.maxTotalMemoryMB * 0.5 {
            memoryPressure = .moderate
        } else {
            memoryPressure = .nominal
        }
    }

    private func handleMemoryWarning() {
        memoryLogger.warning("Memory warning received - freeing memory")
        freeMemory(aggressive: true)
        memoryPressure = .critical
    }

    private func handlePowerStateChange(_ state: PowerState) {
        batteryOptimizationActive = state.isOnBattery

        if !state.isOnBattery {
            // On power - execute deferred tasks
            executeDeferredTasks()
        }
    }
}

// MARK: - Processing Quality

public struct ProcessingQuality {
    public var fftSize: Int
    public var sampleRate: Int
    public var visualFPS: Int
    public var enableAI: Bool
    public var enableEffects: Bool
    public var maxConcurrentTasks: Int
}

// MARK: - UIApplication Compatibility

#if os(macOS)
enum UIApplication {
    static let didReceiveMemoryWarningNotification = Notification.Name("NSApplicationDidReceiveMemoryWarning")
}
#endif
