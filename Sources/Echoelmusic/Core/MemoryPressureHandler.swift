#if canImport(Combine)
// MemoryPressureHandler.swift
// Echoelmusic - Automatic Memory Management Under Pressure
//
// Monitors system memory and automatically frees resources when needed.
// Prevents OOM crashes on resource-constrained devices.
//
// Supported Platforms: iOS, macOS, watchOS, tvOS, visionOS
// Created 2026-01-16

import Foundation
#if canImport(Combine)
import Combine
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
import Observation
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

@preconcurrency @MainActor
@Observable
public final class MemoryPressureHandler {

    // MARK: - Singleton

    @MainActor public static let shared = MemoryPressureHandler()

    // MARK: - Published State

    /// The highest pressure this run has actually been told about. Since #1201 it has exactly
    /// ONE writer — `handlePressure(level:)` — and every path into that function is a real
    /// signal: the system's `DispatchSourceMemoryPressure`,
    /// `UIApplication.didReceiveMemoryWarningNotification`, or an explicit
    /// `releaseMemory(level:)` call. It is never derived from a ratio this type computes for
    /// itself; see `updateMemoryStats` for what that ratio got wrong.
    ///
    /// ⚠️ It does not fall back to `.normal`. iOS raises pressure and does not announce relief,
    /// so a recovery would be a guess of the same kind #1201 removed.
    public private(set) var currentLevel: MemoryPressureLevel = .normal

    /// ⚠️ NOT this app's memory footprint. It is `physicalMemory − os_proc_available_memory()`,
    /// i.e. system RAM minus THIS PROCESS's remaining headroom — two different quantities, so
    /// their difference names nothing. Kept because it is public API (#1201 removed the
    /// DECISION that rested on it, not the property). Do not build a reading, a threshold or a
    /// user-facing number on this value; measure the real footprint with Instruments.
    public private(set) var usedMemoryBytes: Int = 0

    /// This process's remaining headroom before jetsam, straight from
    /// `os_proc_available_memory()`. The one figure here that means what its name says.
    public private(set) var availableMemoryBytes: Int = 0

    // MARK: - Configuration

    /// ⚠️ SINCE #1201 THESE DECIDE NOTHING. They describe a percentage of a total this type
    /// cannot measure (see `updateMemoryStats`), and the poll that compared against them is
    /// gone.
    ///
    /// ⛔ THE FIRST DRAFT OF THIS NOTE SAID "NOTHING READS THESE" AND THAT WAS FALSE — measured
    /// after writing it, which is the wrong order. `handlePressure` still reads
    /// `thresholds.warning` in its early-break test. That reader is inside a loop over the
    /// registered components, and `MemoryReleasable` has ZERO conformers in `Sources/`, so the
    /// loop body never runs — the read is unreachable, not absent. The difference matters: a
    /// session told "nothing reads it" would delete the property and break a compile.
    ///
    /// Kept as public API and as the natural home for real thresholds if a future slice
    /// measures a real footprint. Today no shipped behaviour turns on them, and a session
    /// reading them should not conclude that a 70 % rule is in force.
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

    @ObservationIgnored nonisolated(unsafe) private var memorySource: DispatchSourceMemoryPressure?
    @ObservationIgnored nonisolated(unsafe) private var monitorTimer: Timer?
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

        nonisolated(unsafe) weak var weakSelf = self
        nonisolated(unsafe) let src = memorySource
        memorySource?.setEventHandler { @Sendable in
            guard let source = src else { return }
            let event = source.data

            // DispatchSource on .main queue — already on main thread
            MainActor.assumeIsolated {
                if event.contains(.critical) {
                    weakSelf?.handlePressure(level: .critical)
                } else if event.contains(.warning) {
                    weakSelf?.handlePressure(level: .warning)
                }
            }
        }

        memorySource?.resume()
    }

    private func startMonitoring() {
        // Poll memory usage every 5 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateMemoryStats()
            }
        }
    }

    // MARK: - Memory Stats

    /// ⛔ #1201 — THIS POLL NO LONGER DERIVES A PRESSURE LEVEL, because the ratio it used was a
    /// CATEGORY ERROR and it fired on a healthy device, on every launch.
    ///
    /// The arithmetic that stood here was `used = physicalMemory − os_proc_available_memory()`
    /// and then `used / physicalMemory`. Those two quantities describe DIFFERENT THINGS:
    /// `physicalMemory` is the system's RAM, `os_proc_available_memory()` is THIS PROCESS's
    /// remaining headroom before jetsam. Subtracting one from the other does not give this
    /// app's footprint — it gives "system RAM minus my headroom", which on an 8 GB phone with
    /// ~2 GB of headroom reads as 6 GB "used" by an app that is using a few hundred MB.
    ///
    /// The consequence was not academic. 6/8 = 0.75 is above the 0.70 warning threshold, so
    /// `currentLevel` went to `.warning` within five seconds of every launch, on every device,
    /// and `handlePressure` wrote "Handling Warning pressure" into the log. That is the log a
    /// founder pastes when they report high memory use — an instrument that manufactures the
    /// very finding it is being consulted about. (It logged ONCE, not repeatedly: the level is
    /// only acted on when it CHANGES. One false line in the log is still one too many for a
    /// line that reads as a measurement.)
    ///
    /// ⭐ WHAT REPLACES IT: nothing new. iOS's own `DispatchSourceMemoryPressure` is already
    /// wired in `setupMonitoring` and is the authority on this question — it is the signal the
    /// system actually raises, `handlePressure` is already its handler, and it needs no
    /// denominator of ours. This poll keeps doing the one thing it could do honestly: publish
    /// the headroom figure it can actually read.
    ///
    /// ⚠️ `usedMemoryBytes` KEEPS ITS SUBTRACTION and is deliberately NOT deleted — it is
    /// `public private(set)` API, and removing a published property is a bigger change than
    /// this slice. It is documented at its declaration as not being this app's footprint.
    /// Do not build a reading on it.
    private func updateMemoryStats() {
        let stats = getMemoryStats()
        usedMemoryBytes = stats.used
        availableMemoryBytes = stats.available
    }

    private func getMemoryStats() -> (used: Int, available: Int, total: Int) {
        let total = Int(ProcessInfo.processInfo.physicalMemory)
        // Use os_proc_available_memory which is concurrency-safe (no mach_task_self_)
        if #available(iOS 13.0, macOS 10.15, *) {
            let available = Int(os_proc_available_memory())
            let used = total - available
            return (used, available, total)
        }
        return (0, total, total)
    }

    // MARK: - Pressure Handling

    private func handleMemoryWarning() {
        log.warning("MemoryPressureHandler: System memory warning received")
        handlePressure(level: .critical)
    }

    private func handlePressure(level: MemoryPressureLevel) {
        // #1201 — THE PUBLISHED LEVEL IS SET HERE NOW, and it has to be: removing the poll's
        // ratio removed the ONLY writer of `currentLevel`, which would have left it pinned at
        // `.normal` for the life of the process — a silently dead readout instead of a lying
        // one, which is not an improvement. This is the right home for it anyway: every path
        // that reaches this function is a real signal (the system's
        // `DispatchSourceMemoryPressure`, `UIApplication.didReceiveMemoryWarning`, or an
        // explicit `releaseMemory(level:)`), so the published level now says what iOS said.
        //
        // ⚠️ It is deliberately NOT lowered back to `.normal` anywhere. iOS raises pressure; it
        // does not announce relief, so inventing a recovery here would be the same category of
        // guess this slice just removed. A reader gets "the highest pressure seen so far",
        // which is a true statement about the run.
        currentLevel = level
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
            usagePercent: stats.total > 0 ? Double(stats.used) / Double(stats.total) * 100 : 0
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

    /// Force a memory cleanup cycle
    public func forceCleanup() {
        handlePressure(level: .warning)
    }
}

// MARK: - Memory Cache Base Class

/// Base class for memory-pressure-aware caches

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
        nonisolated(unsafe) let cache = self
        Task { @MainActor in
            MemoryPressureHandler.shared.register(cache)
        }
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
#endif
