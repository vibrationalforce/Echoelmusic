// MemoryPressureHandler.swift
// Echoelmusic - Automatic Memory Management Under Pressure
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Monitors system memory and automatically frees resources when needed.
// Prevents OOM crashes on resource-constrained devices.
//
// Supported Platforms: iOS, macOS, watchOS, tvOS, visionOS
// Created 2026-01-16

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Memory Pressure Level

/// Memory pressure severity
public enum MemoryPressureLevel: Int, Comparable, Sendable {
    case normal = 0
    case warning = 1
    case critical = 2
    case terminal = 3

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .terminal: return "Terminal"
        }
    }
}

// MARK: - Memory Releasable Protocol

/// Protocol for objects that can release memory on demand
public protocol MemoryReleasable: AnyObject {
    /// Priority for memory release (higher = released first)
    var memoryReleasePriority: Int { get }

    /// Estimated memory that can be freed
    var estimatedReleasableMemory: Int { get }

    /// Release memory
    /// - Parameter level: Pressure level indicating how aggressively to release
    func releaseMemory(for level: MemoryPressureLevel)
}

// MARK: - Memory Pressure Handler

/// Central memory pressure handler
///
/// Monitors system memory and coordinates memory release across components.
///
/// Usage:
/// ```swift
/// // Register a component
/// MemoryPressureHandler.shared.register(myCache)
///
/// // Component conforms to MemoryReleasable
/// class MyCache: MemoryReleasable {
///     var memoryReleasePriority: Int { 100 }
///     var estimatedReleasableMemory: Int { cachedItems.count * 1024 }
///
///     func releaseMemory(for level: MemoryPressureLevel) {
///         switch level {
///         case .warning: trimToHalf()
///         case .critical, .terminal: clearAll()
///         default: break
///         }
///     }
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@MainActor
public final class MemoryPressureHandler: ObservableObject {

    // MARK: - Singleton

    public static let shared = MemoryPressureHandler()

    // MARK: - Published State

    @Published public private(set) var currentLevel: MemoryPressureLevel = .normal
    @Published public private(set) var usedMemoryBytes: Int = 0
    @Published public private(set) var availableMemoryBytes: Int = 0

    // MARK: - Configuration

    /// Memory usage thresholds (percentage of total)
    public struct Thresholds {
        public var warning: Double = 0.70    // 70%
        public var critical: Double = 0.85   // 85%
        public var terminal: Double = 0.95   // 95%
    }

    public var thresholds = Thresholds()

    // MARK: - Registered Components

    private var components: [ObjectIdentifier: WeakMemoryReleasable] = [:]

    private class WeakMemoryReleasable {
        weak var value: MemoryReleasable?
        init(_ value: MemoryReleasable) { self.value = value }
    }

    // MARK: - Monitoring

    private var memorySource: DispatchSourceMemoryPressure?
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Statistics

    public private(set) var totalMemoryReleased: Int = 0
    public private(set) var pressureEventCount: Int = 0

    // MARK: - Initialization

    private init() {
        setupMemoryWarningObserver()
        setupDispatchSource()
        startMonitoring()
    }

    deinit {
        memorySource?.cancel()
        monitorTimer?.invalidate()
    }

    // MARK: - Registration

    /// Register a component for memory pressure notifications
    public func register(_ component: MemoryReleasable) {
        let id = ObjectIdentifier(component)
        components[id] = WeakMemoryReleasable(component)
        log.info("MemoryPressureHandler: Registered \(type(of: component))")
    }

    /// Unregister a component
    public func unregister(_ component: MemoryReleasable) {
        let id = ObjectIdentifier(component)
        components.removeValue(forKey: id)
    }

    // MARK: - Setup

    private func setupMemoryWarningObserver() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    private func setupDispatchSource() {
        memorySource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memorySource?.setEventHandler { [weak self] in
            guard let self = self, let source = self.memorySource else { return }
            let event = source.data

            Task { @MainActor in
                if event.contains(.critical) {
                    self.handlePressure(level: .critical)
                } else if event.contains(.warning) {
                    self.handlePressure(level: .warning)
                }
            }
        }

        memorySource?.resume()
    }

    private func startMonitoring() {
        // Poll memory usage every 5 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
            }
        }
    }

    // MARK: - Memory Stats

    private func updateMemoryStats() {
        let stats = getMemoryStats()
        usedMemoryBytes = stats.used
        availableMemoryBytes = stats.available

        let usageRatio = Double(stats.used) / Double(stats.total)

        let newLevel: MemoryPressureLevel
        if usageRatio >= thresholds.terminal {
            newLevel = .terminal
        } else if usageRatio >= thresholds.critical {
            newLevel = .critical
        } else if usageRatio >= thresholds.warning {
            newLevel = .warning
        } else {
            newLevel = .normal
        }

        if newLevel != currentLevel {
            currentLevel = newLevel
            if newLevel > .normal {
                handlePressure(level: newLevel)
            }
        }
    }

    private func getMemoryStats() -> (used: Int, available: Int, total: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let used = result == KERN_SUCCESS ? Int(info.resident_size) : 0
        let total = Int(ProcessInfo.processInfo.physicalMemory)
        let available = total - used

        return (used, available, total)
    }

    // MARK: - Pressure Handling

    private func handleMemoryWarning() {
        log.warning("MemoryPressureHandler: System memory warning received")
        handlePressure(level: .critical)
    }

    private func handlePressure(level: MemoryPressureLevel) {
        pressureEventCount += 1
        log.warning("MemoryPressureHandler: Handling \(level.description) pressure")

        // Clean up dead references
        components = components.filter { $0.value.value != nil }

        // Sort by priority (higher first)
        let activeComponents = components.values
            .compactMap { $0.value }
            .sorted { $0.memoryReleasePriority > $1.memoryReleasePriority }

        var memoryFreed = 0

        for component in activeComponents {
            let before = getMemoryStats().used
            component.releaseMemory(for: level)
            let after = getMemoryStats().used
            memoryFreed += max(0, before - after)

            // Check if we've freed enough
            if level < .terminal {
                let currentUsage = Double(after) / Double(getMemoryStats().total)
                if currentUsage < thresholds.warning {
                    break
                }
            }
        }

        totalMemoryReleased += memoryFreed
        log.info("MemoryPressureHandler: Released ~\(memoryFreed / 1024)KB")

        // Force garbage collection hint
        #if canImport(ObjectiveC)
        autoreleasepool { }
        #endif
    }

    // MARK: - Manual Control

    /// Manually trigger memory release
    public func releaseMemory(level: MemoryPressureLevel = .warning) {
        handlePressure(level: level)
    }

    /// Get current memory usage
    public var memoryUsage: MemoryUsage {
        let stats = getMemoryStats()
        return MemoryUsage(
            usedBytes: stats.used,
            availableBytes: stats.available,
            totalBytes: stats.total,
            usagePercent: Double(stats.used) / Double(stats.total) * 100
        )
    }

    /// Memory usage information
    public struct MemoryUsage: Sendable {
        public let usedBytes: Int
        public let availableBytes: Int
        public let totalBytes: Int
        public let usagePercent: Double

        public var usedMB: Double { Double(usedBytes) / 1_048_576 }
        public var availableMB: Double { Double(availableBytes) / 1_048_576 }
        public var totalMB: Double { Double(totalBytes) / 1_048_576 }
    }

    /// Estimated total releasable memory
    public var estimatedReleasableMemory: Int {
        components.values
            .compactMap { $0.value?.estimatedReleasableMemory }
            .reduce(0, +)
    }
}

// MARK: - Convenience Extensions

extension MemoryPressureHandler {

    /// Register Metal resource pools for automatic cleanup
    #if canImport(Metal)
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
    public func registerMetalPools() {
        if let resourceManager = MetalResourceManager.shared {
            // Create a wrapper that conforms to MemoryReleasable
            let wrapper = MetalPoolsWrapper(manager: resourceManager)
            register(wrapper)
        }
    }

    private class MetalPoolsWrapper: MemoryReleasable {
        let manager: MetalResourceManager

        init(manager: MetalResourceManager) {
            self.manager = manager
        }

        var memoryReleasePriority: Int { 50 }
        var estimatedReleasableMemory: Int { 10_000_000 } // ~10MB estimate

        func releaseMemory(for level: MemoryPressureLevel) {
            Task { @MainActor in
                switch level {
                case .warning:
                    manager.trimPools()
                case .critical, .terminal:
                    manager.clearPools()
                default:
                    break
                }
            }
        }
    }
    #endif
}

// MARK: - Memory Cache Base Class

/// Base class for memory-pressure-aware caches
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
open class MemoryAwareCache<Key: Hashable, Value>: MemoryReleasable {

    private var cache: [Key: CacheEntry] = [:]
    private let lock = NSLock()

    private struct CacheEntry {
        let value: Value
        let size: Int
        var lastAccess: Date
    }

    /// Maximum cache size in bytes
    public var maxSize: Int

    /// Current cache size in bytes
    public private(set) var currentSize: Int = 0

    public init(maxSize: Int = 50_000_000) { // 50MB default
        self.maxSize = maxSize
        MemoryPressureHandler.shared.register(self)
    }

    // MARK: - Cache Operations

    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        if var entry = cache[key] {
            entry.lastAccess = Date()
            cache[key] = entry
            return entry.value
        }
        return nil
    }

    public func set(_ key: Key, value: Value, size: Int) {
        lock.lock()
        defer { lock.unlock() }

        // Remove old entry if exists
        if let old = cache[key] {
            currentSize -= old.size
        }

        // Evict if needed
        while currentSize + size > maxSize && !cache.isEmpty {
            evictOldest()
        }

        cache[key] = CacheEntry(value: value, size: size, lastAccess: Date())
        currentSize += size
    }

    public func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }

        if let entry = cache.removeValue(forKey: key) {
            currentSize -= entry.size
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        currentSize = 0
    }

    private func evictOldest() {
        guard let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) else {
            return
        }
        currentSize -= oldest.value.size
        cache.removeValue(forKey: oldest.key)
    }

    // MARK: - MemoryReleasable

    public var memoryReleasePriority: Int { 100 }

    public var estimatedReleasableMemory: Int { currentSize }

    public func releaseMemory(for level: MemoryPressureLevel) {
        lock.lock()
        defer { lock.unlock() }

        switch level {
        case .warning:
            // Remove oldest 50%
            let targetSize = currentSize / 2
            while currentSize > targetSize && !cache.isEmpty {
                evictOldest()
            }

        case .critical:
            // Remove oldest 80%
            let targetSize = currentSize / 5
            while currentSize > targetSize && !cache.isEmpty {
                evictOldest()
            }

        case .terminal:
            // Clear everything
            cache.removeAll()
            currentSize = 0

        case .normal:
            break
        }
    }
}
