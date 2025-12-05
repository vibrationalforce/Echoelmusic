// SmartResourceManager.swift
// Echoelmusic - Smart Resource Management with Sleep Modes
//
// Intelligent power management: sleep, wake, hibernate, throttle
// Reduces idle power consumption to near-zero

import Foundation
import Combine
import os.log

private let resourceLogger = Logger(subsystem: "com.echoelmusic.green", category: "ResourceManager")

// MARK: - System State

public enum SystemPowerState: String, CaseIterable {
    case active          // Full processing
    case idle            // Reduced processing, quick wake
    case lightSleep      // Minimal processing, fast wake
    case deepSleep       // Near-zero processing, slow wake
    case hibernate       // Suspended, data saved to disk

    public var powerMultiplier: Double {
        switch self {
        case .active: return 1.0
        case .idle: return 0.5
        case .lightSleep: return 0.15
        case .deepSleep: return 0.05
        case .hibernate: return 0.01
        }
    }

    public var wakeLatency: TimeInterval {
        switch self {
        case .active: return 0
        case .idle: return 0.01
        case .lightSleep: return 0.1
        case .deepSleep: return 0.5
        case .hibernate: return 2.0
        }
    }
}

// MARK: - Resource Priority

public enum ResourcePriority: Int, Comparable {
    case critical = 0    // Audio output - never suspend
    case high = 1        // Real-time visuals
    case normal = 2      // Background processing
    case low = 3         // Optional features
    case idle = 4        // Can be fully suspended

    public static func < (lhs: ResourcePriority, rhs: ResourcePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Managed Resource

public protocol ManagedResource: AnyObject {
    var resourceID: String { get }
    var resourcePriority: ResourcePriority { get }
    var isActive: Bool { get }

    func suspend()
    func resume()
    func hibernate()
    func wake()
}

// MARK: - Smart Resource Manager

@MainActor
public final class SmartResourceManager: ObservableObject {
    public static let shared = SmartResourceManager()

    // MARK: - Published State

    @Published public private(set) var currentState: SystemPowerState = .active
    @Published public private(set) var idleTime: TimeInterval = 0
    @Published public private(set) var activeResources: Int = 0
    @Published public private(set) var suspendedResources: Int = 0
    @Published public private(set) var powerSavings: Double = 0 // Percentage

    // MARK: - Configuration

    public struct Configuration {
        public var idleThreshold: TimeInterval = 30          // Seconds before idle
        public var lightSleepThreshold: TimeInterval = 120   // Seconds before light sleep
        public var deepSleepThreshold: TimeInterval = 300    // Seconds before deep sleep
        public var hibernateThreshold: TimeInterval = 600    // Seconds before hibernate

        public var enableAutoSleep: Bool = true
        public var enableAggresivePowerSaving: Bool = false
        public var keepAudioAlive: Bool = true               // Never suspend audio
        public var wakeOnMIDI: Bool = true
        public var wakeOnNetwork: Bool = false

        public init() {}
    }

    public var configuration = Configuration()

    // MARK: - Private State

    private var managedResources: [String: WeakResourceWrapper] = [:]
    private var resourceStates: [String: SystemPowerState] = [:]
    private var lastActivityTime: Date = Date()
    private var idleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Activity tracking
    private var activityCounters: [String: Int] = [:]
    private let activityLock = NSLock()

    // MARK: - Initialization

    private init() {
        setupIdleDetection()
        setupActivityMonitoring()
        resourceLogger.info("SmartResourceManager initialized")
    }

    // MARK: - Resource Registration

    /// Register a resource for smart management
    public func register(_ resource: ManagedResource) {
        managedResources[resource.resourceID] = WeakResourceWrapper(resource)
        resourceStates[resource.resourceID] = .active
        updateResourceCounts()
        resourceLogger.debug("Registered resource: \(resource.resourceID)")
    }

    /// Unregister a resource
    public func unregister(_ resourceID: String) {
        managedResources.removeValue(forKey: resourceID)
        resourceStates.removeValue(forKey: resourceID)
        updateResourceCounts()
        resourceLogger.debug("Unregistered resource: \(resourceID)")
    }

    // MARK: - Activity Tracking

    /// Report user activity to reset idle timer
    public func reportActivity(_ source: String = "user") {
        lastActivityTime = Date()
        idleTime = 0

        // Wake system if sleeping
        if currentState != .active {
            wakeSystem()
        }

        // Track activity source
        activityLock.lock()
        activityCounters[source, default: 0] += 1
        activityLock.unlock()
    }

    /// Report continuous processing (prevents sleep during active work)
    public func reportProcessing(_ resourceID: String) {
        if managedResources[resourceID] != nil {
            resourceStates[resourceID] = .active
        }
        reportActivity(resourceID)
    }

    // MARK: - Power State Control

    /// Force a specific power state
    public func setSystemState(_ state: SystemPowerState) {
        guard state != currentState else { return }

        let previousState = currentState
        currentState = state

        // Apply state to all resources
        applyStateToResources(state)

        resourceLogger.info("System state changed: \(previousState.rawValue) → \(state.rawValue)")

        // Calculate power savings
        powerSavings = (1.0 - state.powerMultiplier) * 100
    }

    /// Wake the system from any sleep state
    public func wakeSystem() {
        setSystemState(.active)
        lastActivityTime = Date()
    }

    /// Request immediate power saving
    public func requestPowerSaving() {
        if configuration.enableAggresivePowerSaving {
            setSystemState(.deepSleep)
        } else {
            setSystemState(.lightSleep)
        }
    }

    // MARK: - Intelligent Scheduling

    /// Schedule a task with power awareness
    public func scheduleTask(
        priority: ResourcePriority,
        deadline: TimeInterval? = nil,
        task: @escaping () async -> Void
    ) {
        // Determine if we should wake for this task
        let shouldWake = priority <= .high || deadline != nil

        if shouldWake && currentState != .active {
            wakeSystem()
        }

        // Queue task based on priority
        Task {
            switch priority {
            case .critical:
                await task()
            case .high:
                await task()
            case .normal:
                // Wait if system is sleeping
                while currentState == .deepSleep || currentState == .hibernate {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                await task()
            case .low, .idle:
                // Only run when system is active or idle
                while currentState != .active && currentState != .idle {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
                await task()
            }
        }
    }

    /// Batch low-priority tasks to reduce wake cycles
    private var batchedTasks: [() async -> Void] = []
    private var batchTimer: Timer?

    public func batchTask(_ task: @escaping () async -> Void) {
        batchedTasks.append(task)

        // Execute batch after delay or when threshold reached
        if batchedTasks.count >= 10 {
            executeBatch()
        } else if batchTimer == nil {
            batchTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.executeBatch()
                }
            }
        }
    }

    private func executeBatch() {
        batchTimer?.invalidate()
        batchTimer = nil

        let tasks = batchedTasks
        batchedTasks.removeAll()

        guard !tasks.isEmpty else { return }

        // Execute all batched tasks
        Task {
            for task in tasks {
                await task()
            }
        }
    }

    // MARK: - Memory Management

    /// Release cached memory during low-power states
    public func releaseNonEssentialMemory() {
        // Notify all resources to release caches
        for (_, wrapper) in managedResources {
            if let resource = wrapper.resource,
               resource.resourcePriority >= .normal {
                resource.hibernate()
            }
        }

        // Request system memory cleanup
        #if os(iOS)
        // iOS handles this automatically
        #elseif os(macOS)
        // Hint to system
        malloc_zone_pressure_relief(nil, 0)
        #endif

        resourceLogger.info("Non-essential memory released")
    }

    // MARK: - Private Methods

    private func setupIdleDetection() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIdleState()
            }
        }
    }

    private func setupActivityMonitoring() {
        // Monitor for system events that indicate activity
        NotificationCenter.default.publisher(for: .greenComputingEfficiencyChanged)
            .sink { [weak self] _ in
                self?.reportActivity("system")
            }
            .store(in: &cancellables)
    }

    private func updateIdleState() {
        idleTime = Date().timeIntervalSince(lastActivityTime)

        guard configuration.enableAutoSleep else { return }

        // Determine appropriate state based on idle time
        let targetState: SystemPowerState
        if idleTime >= configuration.hibernateThreshold {
            targetState = .hibernate
        } else if idleTime >= configuration.deepSleepThreshold {
            targetState = .deepSleep
        } else if idleTime >= configuration.lightSleepThreshold {
            targetState = .lightSleep
        } else if idleTime >= configuration.idleThreshold {
            targetState = .idle
        } else {
            targetState = .active
        }

        if targetState != currentState {
            setSystemState(targetState)
        }
    }

    private func applyStateToResources(_ state: SystemPowerState) {
        for (resourceID, wrapper) in managedResources {
            guard let resource = wrapper.resource else {
                // Clean up dead references
                managedResources.removeValue(forKey: resourceID)
                continue
            }

            // Skip critical resources unless hibernating
            if resource.resourcePriority == .critical && state != .hibernate {
                resourceStates[resourceID] = .active
                continue
            }

            // Skip audio if configured
            if configuration.keepAudioAlive &&
               resourceID.lowercased().contains("audio") &&
               state != .hibernate {
                resourceStates[resourceID] = .active
                continue
            }

            // Apply state based on priority
            switch state {
            case .active:
                resource.resume()
            case .idle:
                if resource.resourcePriority >= .low {
                    resource.suspend()
                }
            case .lightSleep:
                if resource.resourcePriority >= .normal {
                    resource.suspend()
                }
            case .deepSleep:
                if resource.resourcePriority >= .high {
                    resource.suspend()
                }
            case .hibernate:
                resource.hibernate()
            }

            resourceStates[resourceID] = state
        }

        updateResourceCounts()
    }

    private func updateResourceCounts() {
        var active = 0
        var suspended = 0

        for (_, state) in resourceStates {
            if state == .active || state == .idle {
                active += 1
            } else {
                suspended += 1
            }
        }

        activeResources = active
        suspendedResources = suspended
    }
}

// MARK: - Weak Resource Wrapper

private final class WeakResourceWrapper {
    weak var resource: ManagedResource?

    init(_ resource: ManagedResource) {
        self.resource = resource
    }
}

// MARK: - Default Resource Implementation

open class BaseManagedResource: ManagedResource {
    public let resourceID: String
    public var resourcePriority: ResourcePriority
    public private(set) var isActive: Bool = true

    private var savedState: Data?

    public init(id: String, priority: ResourcePriority = .normal) {
        self.resourceID = id
        self.resourcePriority = priority
    }

    open func suspend() {
        isActive = false
        resourceLogger.debug("Resource suspended: \(self.resourceID)")
    }

    open func resume() {
        isActive = true
        resourceLogger.debug("Resource resumed: \(self.resourceID)")
    }

    open func hibernate() {
        // Override to save state
        suspend()
        resourceLogger.debug("Resource hibernated: \(self.resourceID)")
    }

    open func wake() {
        // Override to restore state
        resume()
        resourceLogger.debug("Resource woke: \(self.resourceID)")
    }
}

// MARK: - Power-Aware Task Queue

public actor PowerAwareTaskQueue {
    private var pendingTasks: [(priority: ResourcePriority, task: () async -> Void)] = []
    private var isProcessing = false

    public init() {}

    public func enqueue(priority: ResourcePriority, task: @escaping () async -> Void) {
        pendingTasks.append((priority, task))
        pendingTasks.sort { $0.priority < $1.priority }

        if !isProcessing {
            Task { await processTasks() }
        }
    }

    private func processTasks() async {
        isProcessing = true
        defer { isProcessing = false }

        while !pendingTasks.isEmpty {
            let (priority, task) = pendingTasks.removeFirst()

            // Check power state before executing
            let state = await MainActor.run { SmartResourceManager.shared.currentState }

            // Skip low-priority tasks during power saving
            if priority >= .low && state >= .lightSleep {
                // Re-queue for later
                pendingTasks.append((priority, task))
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }

            await task()

            // Small delay between tasks to prevent CPU spikes
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }
}

// MARK: - Convenience Extensions

extension SmartResourceManager {
    /// Get power state summary
    public var powerStateSummary: String {
        """
        State: \(currentState.rawValue)
        Idle: \(Int(idleTime))s
        Active: \(activeResources)
        Suspended: \(suspendedResources)
        Savings: \(Int(powerSavings))%
        """
    }

    /// Check if system can handle intensive operations
    public var canPerformIntensiveWork: Bool {
        currentState == .active && idleTime < 5
    }
}
