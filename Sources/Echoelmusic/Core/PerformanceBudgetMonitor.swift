// PerformanceBudgetMonitor.swift
// Echoelmusic - Performance Budget Monitoring & Enforcement
//
// Inspired by Paperclip's resource budgeting pattern:
// per-session budgets with soft warnings and hard stops.
//
// Tracks CPU, memory, audio latency, and visual frame rate
// against configurable thresholds. Fires callbacks when
// budgets are exceeded so the system can gracefully degrade.
//
// Supported Platforms: iOS, macOS, watchOS, tvOS, visionOS
// Created 2026-03-14

import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(os)
import os
#endif

#if canImport(Darwin)

// MARK: - Budget Threshold

/// Configurable performance thresholds with soft/hard limits
public struct PerformanceBudget: Sendable {
    /// CPU usage thresholds (0-100%)
    public var cpuSoftLimit: Float = 30.0
    public var cpuHardLimit: Float = 50.0

    /// Memory thresholds in MB
    public var memorySoftLimit: Float = 200.0
    public var memoryHardLimit: Float = 300.0

    /// Audio latency thresholds in ms
    public var latencySoftLimit: Float = 10.0
    public var latencyHardLimit: Float = 15.0

    /// Visual frame rate thresholds (minimum acceptable FPS)
    public var fpsSoftLimit: Float = 60.0
    public var fpsHardLimit: Float = 30.0

    /// Bio loop rate thresholds (minimum acceptable Hz)
    public var bioLoopSoftLimit: Float = 60.0
    public var bioLoopHardLimit: Float = 30.0

    public init() {}
}

// MARK: - Budget Violation

/// Describes a budget violation event
public struct BudgetViolation: Sendable {
    public enum Severity: String, Sendable {
        case warning   // Soft limit exceeded
        case critical  // Hard limit exceeded
    }

    public enum Resource: String, Sendable {
        case cpu
        case memory
        case audioLatency
        case visualFPS
        case bioLoopRate
    }

    public let resource: Resource
    public let severity: Severity
    public let currentValue: Float
    public let limit: Float
    public let timestamp: Date

    public var description: String {
        "\(severity.rawValue.uppercased()): \(resource.rawValue) at \(String(format: "%.1f", currentValue)) (limit: \(String(format: "%.1f", limit)))"
    }
}

// MARK: - Performance Snapshot

/// Point-in-time performance reading
public struct PerformanceSnapshot: Sendable {
    public let timestamp: Date
    public let cpuPercent: Float
    public let memoryMB: Float
    public let audioLatencyMs: Float
    public let visualFPS: Float
    public let bioLoopHz: Float
    public let activeViolations: [BudgetViolation]

    /// Overall health: green (all OK), yellow (soft violations), red (hard violations)
    public var health: Health {
        if activeViolations.contains(where: { $0.severity == .critical }) {
            return .red
        }
        if !activeViolations.isEmpty {
            return .yellow
        }
        return .green
    }

    public enum Health: String, Sendable {
        case green  // All within budget
        case yellow // Soft limit exceeded
        case red    // Hard limit exceeded
    }
}

// MARK: - Performance Budget Monitor

/// Monitors system performance against configurable budgets.
///
/// Inspired by Paperclip's per-agent resource budgeting:
/// - Soft limits trigger warnings (reduce visual complexity)
/// - Hard limits trigger degradation (pause non-essential processing)
///
/// Usage:
/// ```swift
/// let monitor = PerformanceBudgetMonitor.shared
/// monitor.onViolation = { violation in
///     if violation.severity == .critical && violation.resource == .cpu {
///         // Reduce DSP complexity
///     }
/// }
/// monitor.startMonitoring()
/// ```
@preconcurrency @MainActor
public final class PerformanceBudgetMonitor: @unchecked Sendable {

    // MARK: - Singleton

    @MainActor public static let shared = PerformanceBudgetMonitor()

    // MARK: - Configuration

    /// Active budget thresholds
    public var budget = PerformanceBudget()

    /// Monitoring interval in seconds
    public var pollingInterval: TimeInterval = 1.0

    /// Maximum history entries (ring buffer)
    public var maxHistorySize: Int = 300

    // MARK: - Callbacks

    /// Called when a budget violation occurs
    public var onViolation: (@Sendable (BudgetViolation) -> Void)?

    /// Called when health status changes
    public var onHealthChange: (@Sendable (PerformanceSnapshot.Health) -> Void)?

    // MARK: - State

    /// Current performance snapshot
    public private(set) var currentSnapshot: PerformanceSnapshot?

    /// Historical snapshots (ring buffer)
    public private(set) var history: [PerformanceSnapshot] = []

    /// Current health status
    public private(set) var currentHealth: PerformanceSnapshot.Health = .green

    /// Whether monitoring is active
    public private(set) var isMonitoring: Bool = false

    // MARK: - Private

    private let log = ProfessionalLogger.shared
    private var monitoringTask: Task<Void, Never>?
    private var lastViolationTime: [BudgetViolation.Resource: Date] = [:]

    /// Minimum interval between violation callbacks for the same resource (debounce)
    private let violationDebounceInterval: TimeInterval = 5.0

    // MARK: - Externally Updated Metrics

    /// Updated by audio engine
    public var reportedAudioLatencyMs: Float = 0.0

    /// Updated by visual engine
    public var reportedVisualFPS: Float = 120.0

    /// Updated by bio loop
    public var reportedBioLoopHz: Float = 120.0

    // MARK: - Init

    private init() {}

    // MARK: - Control

    /// Start periodic performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.collectAndEvaluate()
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
            }
        }

        log.log(.info, category: .system, "Performance budget monitoring started (poll: \(pollingInterval)s)")
    }

    /// Stop monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
        log.log(.info, category: .system, "Performance budget monitoring stopped")
    }

    // MARK: - Collection

    /// Collect current metrics and evaluate against budget
    private func collectAndEvaluate() async {
        let cpu = measureCPU()
        let memory = measureMemory()
        let latency = reportedAudioLatencyMs
        let fps = reportedVisualFPS
        let bioHz = reportedBioLoopHz

        var violations: [BudgetViolation] = []
        let now = Date()

        // CPU check
        if cpu >= budget.cpuHardLimit {
            violations.append(BudgetViolation(resource: .cpu, severity: .critical, currentValue: cpu, limit: budget.cpuHardLimit, timestamp: now))
        } else if cpu >= budget.cpuSoftLimit {
            violations.append(BudgetViolation(resource: .cpu, severity: .warning, currentValue: cpu, limit: budget.cpuSoftLimit, timestamp: now))
        }

        // Memory check
        if memory >= budget.memoryHardLimit {
            violations.append(BudgetViolation(resource: .memory, severity: .critical, currentValue: memory, limit: budget.memoryHardLimit, timestamp: now))
        } else if memory >= budget.memorySoftLimit {
            violations.append(BudgetViolation(resource: .memory, severity: .warning, currentValue: memory, limit: budget.memorySoftLimit, timestamp: now))
        }

        // Audio latency check
        if latency >= budget.latencyHardLimit {
            violations.append(BudgetViolation(resource: .audioLatency, severity: .critical, currentValue: latency, limit: budget.latencyHardLimit, timestamp: now))
        } else if latency >= budget.latencySoftLimit {
            violations.append(BudgetViolation(resource: .audioLatency, severity: .warning, currentValue: latency, limit: budget.latencySoftLimit, timestamp: now))
        }

        // Visual FPS check (lower = worse)
        if fps <= budget.fpsHardLimit {
            violations.append(BudgetViolation(resource: .visualFPS, severity: .critical, currentValue: fps, limit: budget.fpsHardLimit, timestamp: now))
        } else if fps <= budget.fpsSoftLimit {
            violations.append(BudgetViolation(resource: .visualFPS, severity: .warning, currentValue: fps, limit: budget.fpsSoftLimit, timestamp: now))
        }

        // Bio loop rate check (lower = worse)
        if bioHz <= budget.bioLoopHardLimit {
            violations.append(BudgetViolation(resource: .bioLoopRate, severity: .critical, currentValue: bioHz, limit: budget.bioLoopHardLimit, timestamp: now))
        } else if bioHz <= budget.bioLoopSoftLimit {
            violations.append(BudgetViolation(resource: .bioLoopRate, severity: .warning, currentValue: bioHz, limit: budget.bioLoopSoftLimit, timestamp: now))
        }

        let snapshot = PerformanceSnapshot(
            timestamp: now,
            cpuPercent: cpu,
            memoryMB: memory,
            audioLatencyMs: latency,
            visualFPS: fps,
            bioLoopHz: bioHz,
            activeViolations: violations
        )

        await MainActor.run {
            self.currentSnapshot = snapshot
            self.history.append(snapshot)
            if self.history.count > self.maxHistorySize {
                self.history.removeFirst(self.history.count - self.maxHistorySize)
            }

            // Fire violation callbacks (debounced per resource)
            for violation in violations {
                if self.shouldFireViolation(violation) {
                    self.lastViolationTime[violation.resource] = now
                    self.onViolation?(violation)
                    self.log.log(.warning, category: .system, violation.description)
                }
            }

            // Health status change
            if snapshot.health != self.currentHealth {
                let oldHealth = self.currentHealth
                self.currentHealth = snapshot.health
                self.onHealthChange?(snapshot.health)
                self.log.log(.info, category: .system, "Performance health: \(oldHealth.rawValue) → \(snapshot.health.rawValue)")
            }
        }
    }

    private func shouldFireViolation(_ violation: BudgetViolation) -> Bool {
        guard let lastTime = lastViolationTime[violation.resource] else { return true }
        return Date().timeIntervalSince(lastTime) >= violationDebounceInterval
    }

    // MARK: - System Metrics

    private func measureCPU() -> Float {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }

        var totalCPU: Float = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info_data_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { rawPtr in
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), rawPtr, &infoCount)
                }
            }

            if kr == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalCPU += Float(info.cpu_usage) / Float(TH_USAGE_SCALE) * 100.0
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))

        return totalCPU
    }

    private func measureMemory() -> Float {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Float(info.phys_footprint) / (1024 * 1024) // Bytes → MB
    }
}

#endif // canImport(Darwin)
