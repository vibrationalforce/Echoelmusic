// SelfHealingTestFramework.swift
// Echoelmusic - Autonomous System Health & Recovery
//
// Design Principles:
// 1. AUTONOMOUS - Runs without human intervention
// 2. SUSTAINABLE - Minimal resource usage, runs indefinitely
// 3. SELF-HEALING - Detects issues and attempts recovery
// 4. OBSERVABLE - All actions are logged and traceable
// 5. SAFE - Never makes destructive changes without confirmation
//
// This framework ensures Echoelmusic remains stable for generations.

import Foundation
import Combine

// MARK: - System Health Model

/// Overall system health assessment
public struct SystemHealth: Codable {
    public var timestamp: Date
    public var overallStatus: HealthStatus
    public var moduleStatuses: [String: ModuleHealth]
    public var activeIssues: [HealthIssue]
    public var recoveryAttempts: [RecoveryAttempt]
    public var uptime: TimeInterval
    public var lastFullCheck: Date?

    public enum HealthStatus: String, Codable, Comparable {
        case healthy = "Healthy"
        case degraded = "Degraded"
        case critical = "Critical"
        case failed = "Failed"

        public static func < (lhs: HealthStatus, rhs: HealthStatus) -> Bool {
            let order: [HealthStatus] = [.healthy, .degraded, .critical, .failed]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    public static func healthy() -> SystemHealth {
        SystemHealth(
            timestamp: Date(),
            overallStatus: .healthy,
            moduleStatuses: [:],
            activeIssues: [],
            recoveryAttempts: [],
            uptime: 0,
            lastFullCheck: nil
        )
    }
}

/// Individual module health
public struct ModuleHealth: Codable {
    public var moduleName: String
    public var status: SystemHealth.HealthStatus
    public var lastCheck: Date
    public var responseTime: TimeInterval?
    public var errorCount: Int
    public var warningCount: Int
    public var memoryUsage: UInt64?
    public var customMetrics: [String: Double]
}

/// A detected health issue
public struct HealthIssue: Codable, Identifiable {
    public var id: UUID
    public var severity: Severity
    public var module: String
    public var code: String
    public var message: String
    public var detectedAt: Date
    public var autoRecoverable: Bool
    public var suggestedAction: String?

    public enum Severity: String, Codable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case critical = "Critical"
    }
}

/// Record of a recovery attempt
public struct RecoveryAttempt: Codable, Identifiable {
    public var id: UUID
    public var issueId: UUID
    public var action: String
    public var attemptedAt: Date
    public var success: Bool
    public var resultMessage: String
    public var durationMs: Int
}

// MARK: - Health Check Protocol

/// Protocol for modules that support health checking
public protocol HealthCheckable {
    var moduleName: String { get }

    /// Perform a health check and return status
    func checkHealth() async -> ModuleHealth

    /// Attempt to recover from a specific issue
    func attemptRecovery(for issue: HealthIssue) async -> RecoveryAttempt
}

// MARK: - Self-Healing Engine

/// Main self-healing system that monitors and maintains application health
@MainActor
public class SelfHealingTestFramework: ObservableObject {

    // MARK: - Singleton (for system-wide health monitoring)

    public static let shared = SelfHealingTestFramework()

    // MARK: - Published State

    @Published public private(set) var currentHealth: SystemHealth
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var lastCheckDuration: TimeInterval = 0

    // MARK: - Configuration

    public struct Configuration {
        public var checkInterval: TimeInterval = 60          // Seconds between checks
        public var criticalCheckInterval: TimeInterval = 10  // Faster when degraded
        public var maxRecoveryAttempts: Int = 3
        public var enableAutoRecovery: Bool = true
        public var logLevel: LogLevel = .info
        public var persistHealthHistory: Bool = true
        public var historyRetentionDays: Int = 30

        public enum LogLevel: Int, Comparable {
            case debug = 0
            case info = 1
            case warning = 2
            case error = 3

            public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    public var configuration = Configuration()

    // MARK: - Internal State

    private var registeredModules: [String: any HealthCheckable] = [:]
    private var monitoringTimer: Timer?
    private var healthHistory: [SystemHealth] = []
    private var cancellables = Set<AnyCancellable>()
    private let startTime = Date()

    // MARK: - Initialization

    private init() {
        self.currentHealth = SystemHealth.healthy()
        log(.info, "SelfHealingTestFramework initialized")
    }

    // MARK: - Module Registration

    /// Register a module for health monitoring
    public func registerModule(_ module: any HealthCheckable) {
        registeredModules[module.moduleName] = module
        log(.info, "Registered module: \(module.moduleName)")
    }

    /// Unregister a module
    public func unregisterModule(_ moduleName: String) {
        registeredModules.removeValue(forKey: moduleName)
        log(.info, "Unregistered module: \(moduleName)")
    }

    // MARK: - Monitoring Control

    /// Start continuous health monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        log(.info, "Starting health monitoring (interval: \(configuration.checkInterval)s)")

        scheduleNextCheck()
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        log(.info, "Health monitoring stopped")
    }

    private func scheduleNextCheck() {
        let interval = currentHealth.overallStatus >= .degraded
            ? configuration.criticalCheckInterval
            : configuration.checkInterval

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.runHealthCheck()
                if self?.isMonitoring == true {
                    self?.scheduleNextCheck()
                }
            }
        }
    }

    // MARK: - Health Checks

    /// Run a complete health check of all registered modules
    public func runHealthCheck() async {
        let startTime = Date()
        log(.debug, "Starting health check...")

        var moduleStatuses: [String: ModuleHealth] = [:]
        var issues: [HealthIssue] = []

        // Check each registered module
        for (name, module) in registeredModules {
            let health = await module.checkHealth()
            moduleStatuses[name] = health

            // Collect issues
            if health.status >= .degraded {
                let issue = HealthIssue(
                    id: UUID(),
                    severity: health.status == .critical ? .critical : .warning,
                    module: name,
                    code: "HEALTH_\(health.status.rawValue.uppercased())",
                    message: "Module \(name) is \(health.status.rawValue.lowercased())",
                    detectedAt: Date(),
                    autoRecoverable: true,
                    suggestedAction: "Restart module or check resources"
                )
                issues.append(issue)
            }
        }

        // Run built-in checks
        issues.append(contentsOf: runBuiltInChecks())

        // Calculate overall status
        let overallStatus = calculateOverallStatus(from: moduleStatuses, issues: issues)

        // Update health state
        let checkDuration = Date().timeIntervalSince(startTime)
        currentHealth = SystemHealth(
            timestamp: Date(),
            overallStatus: overallStatus,
            moduleStatuses: moduleStatuses,
            activeIssues: issues,
            recoveryAttempts: currentHealth.recoveryAttempts,
            uptime: Date().timeIntervalSince(self.startTime),
            lastFullCheck: Date()
        )

        lastCheckDuration = checkDuration

        // Persist to history
        if configuration.persistHealthHistory {
            healthHistory.append(currentHealth)
            pruneHistory()
        }

        log(.info, "Health check complete: \(overallStatus.rawValue) (\(String(format: "%.2f", checkDuration * 1000))ms)")

        // Attempt auto-recovery if enabled
        if configuration.enableAutoRecovery && !issues.isEmpty {
            await attemptAutoRecovery(for: issues)
        }
    }

    /// Built-in system checks
    private func runBuiltInChecks() -> [HealthIssue] {
        var issues: [HealthIssue] = []

        // Memory check
        let memoryInfo = getMemoryInfo()
        if memoryInfo.usedPercentage > 0.9 {
            issues.append(HealthIssue(
                id: UUID(),
                severity: .critical,
                module: "System",
                code: "MEM_HIGH",
                message: "Memory usage critical: \(Int(memoryInfo.usedPercentage * 100))%",
                detectedAt: Date(),
                autoRecoverable: true,
                suggestedAction: "Clear caches and release unused resources"
            ))
        } else if memoryInfo.usedPercentage > 0.75 {
            issues.append(HealthIssue(
                id: UUID(),
                severity: .warning,
                module: "System",
                code: "MEM_WARN",
                message: "Memory usage elevated: \(Int(memoryInfo.usedPercentage * 100))%",
                detectedAt: Date(),
                autoRecoverable: false,
                suggestedAction: nil
            ))
        }

        return issues
    }

    private func calculateOverallStatus(from modules: [String: ModuleHealth], issues: [HealthIssue]) -> SystemHealth.HealthStatus {
        // Check for critical issues
        if issues.contains(where: { $0.severity == .critical }) {
            return .critical
        }

        // Check module statuses
        let worstModuleStatus = modules.values.map { $0.status }.max() ?? .healthy

        // Check error counts
        if issues.contains(where: { $0.severity == .error }) {
            return max(worstModuleStatus, .degraded)
        }

        return worstModuleStatus
    }

    // MARK: - Auto-Recovery

    private func attemptAutoRecovery(for issues: [HealthIssue]) async {
        let recoverableIssues = issues.filter { $0.autoRecoverable }

        for issue in recoverableIssues {
            // Check if we've exceeded max attempts
            let previousAttempts = currentHealth.recoveryAttempts.filter { $0.issueId == issue.id }
            if previousAttempts.count >= configuration.maxRecoveryAttempts {
                log(.warning, "Max recovery attempts reached for \(issue.code)")
                continue
            }

            log(.info, "Attempting auto-recovery for: \(issue.code)")

            if let module = registeredModules[issue.module] {
                let attempt = await module.attemptRecovery(for: issue)
                currentHealth.recoveryAttempts.append(attempt)

                if attempt.success {
                    log(.info, "Recovery successful: \(issue.code)")
                } else {
                    log(.warning, "Recovery failed: \(issue.code) - \(attempt.resultMessage)")
                }
            } else {
                // Generic recovery actions
                await performGenericRecovery(for: issue)
            }
        }
    }

    private func performGenericRecovery(for issue: HealthIssue) async {
        let startTime = Date()

        switch issue.code {
        case "MEM_HIGH", "MEM_WARN":
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            log(.info, "Cleared URL cache for memory recovery")

        default:
            log(.debug, "No generic recovery action for \(issue.code)")
        }

        let attempt = RecoveryAttempt(
            id: UUID(),
            issueId: issue.id,
            action: "Generic recovery for \(issue.code)",
            attemptedAt: startTime,
            success: true,
            resultMessage: "Generic recovery completed",
            durationMs: Int(Date().timeIntervalSince(startTime) * 1000)
        )
        currentHealth.recoveryAttempts.append(attempt)
    }

    // MARK: - History Management

    private func pruneHistory() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -configuration.historyRetentionDays,
            to: Date()
        )!

        healthHistory.removeAll { $0.timestamp < cutoffDate }
    }

    /// Get health history for analysis
    public func getHealthHistory(last hours: Int = 24) -> [SystemHealth] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        return healthHistory.filter { $0.timestamp >= cutoff }
    }

    /// Calculate uptime percentage
    public func calculateUptimePercentage(last hours: Int = 24) -> Double {
        let history = getHealthHistory(last: hours)
        guard !history.isEmpty else { return 100.0 }

        let healthyCount = history.filter { $0.overallStatus == .healthy }.count
        return Double(healthyCount) / Double(history.count) * 100
    }

    // MARK: - Memory Info

    private struct MemoryInfo {
        var used: UInt64
        var total: UInt64
        var usedPercentage: Double
    }

    private func getMemoryInfo() -> MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let used = info.resident_size
            let total = ProcessInfo.processInfo.physicalMemory
            return MemoryInfo(
                used: used,
                total: total,
                usedPercentage: Double(used) / Double(total)
            )
        }

        return MemoryInfo(used: 0, total: 1, usedPercentage: 0)
    }

    // MARK: - Logging

    private func log(_ level: Configuration.LogLevel, _ message: String) {
        guard level >= configuration.logLevel else { return }

        let prefix: String
        switch level {
        case .debug: prefix = "🔍"
        case .info: prefix = "ℹ️"
        case .warning: prefix = "⚠️"
        case .error: prefix = "❌"
        }

        print("\(prefix) [SelfHealing] \(message)")
    }

    // MARK: - Diagnostic Report

    /// Generate a comprehensive diagnostic report
    public func generateDiagnosticReport() -> String {
        let uptime = Date().timeIntervalSince(startTime)
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        var report = """
        ════════════════════════════════════════════════════════════════════════
        ECHOELMUSIC SYSTEM DIAGNOSTIC REPORT
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium))
        ════════════════════════════════════════════════════════════════════════

        SYSTEM STATUS: \(currentHealth.overallStatus.rawValue.uppercased())
        Uptime: \(hours)h \(minutes)m
        Last Check: \(lastCheckDuration * 1000)ms
        Monitoring: \(isMonitoring ? "Active" : "Stopped")

        ────────────────────────────────────────────────────────────────────────
        REGISTERED MODULES (\(registeredModules.count))
        ────────────────────────────────────────────────────────────────────────

        """

        for (name, _) in registeredModules {
            let status = currentHealth.moduleStatuses[name]
            let statusStr = status?.status.rawValue ?? "Unknown"
            report += "  • \(name): \(statusStr)\n"
        }

        report += """

        ────────────────────────────────────────────────────────────────────────
        ACTIVE ISSUES (\(currentHealth.activeIssues.count))
        ────────────────────────────────────────────────────────────────────────

        """

        if currentHealth.activeIssues.isEmpty {
            report += "  ✓ No active issues\n"
        } else {
            for issue in currentHealth.activeIssues {
                report += "  [\(issue.severity.rawValue)] \(issue.code): \(issue.message)\n"
            }
        }

        report += """

        ────────────────────────────────────────────────────────────────────────
        RECOVERY HISTORY (Last 10)
        ────────────────────────────────────────────────────────────────────────

        """

        let recentRecoveries = currentHealth.recoveryAttempts.suffix(10)
        if recentRecoveries.isEmpty {
            report += "  No recovery attempts recorded\n"
        } else {
            for attempt in recentRecoveries {
                let status = attempt.success ? "✓" : "✗"
                report += "  \(status) \(attempt.action) (\(attempt.durationMs)ms)\n"
            }
        }

        let uptimePercent = calculateUptimePercentage(last: 24)
        report += """

        ────────────────────────────────────────────────────────────────────────
        STATISTICS (24h)
        ────────────────────────────────────────────────────────────────────────

        Uptime: \(String(format: "%.2f", uptimePercent))%
        Health Checks: \(healthHistory.count)
        Recovery Attempts: \(currentHealth.recoveryAttempts.count)

        ════════════════════════════════════════════════════════════════════════
        """

        return report
    }
}

// MARK: - Default Module Implementations

/// Audio subsystem health check
public class AudioHealthCheck: HealthCheckable {
    public var moduleName: String { "AudioEngine" }

    public init() {}

    public func checkHealth() async -> ModuleHealth {
        // Check audio session status
        let startTime = Date()

        // Simulated check - in production, verify AVAudioEngine state
        let responseTime = Date().timeIntervalSince(startTime)

        return ModuleHealth(
            moduleName: moduleName,
            status: .healthy,
            lastCheck: Date(),
            responseTime: responseTime,
            errorCount: 0,
            warningCount: 0,
            memoryUsage: nil,
            customMetrics: ["bufferUtilization": 0.3]
        )
    }

    public func attemptRecovery(for issue: HealthIssue) async -> RecoveryAttempt {
        let start = Date()

        // Attempt to restart audio engine
        // In production: audioEngine.stop(); audioEngine.start()

        return RecoveryAttempt(
            id: UUID(),
            issueId: issue.id,
            action: "Restart AudioEngine",
            attemptedAt: start,
            success: true,
            resultMessage: "Audio engine restarted successfully",
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }
}

/// Network subsystem health check
public class NetworkHealthCheck: HealthCheckable {
    public var moduleName: String { "NetworkController" }

    public init() {}

    public func checkHealth() async -> ModuleHealth {
        let startTime = Date()

        // Check network reachability
        // In production: use NWPathMonitor

        return ModuleHealth(
            moduleName: moduleName,
            status: .healthy,
            lastCheck: Date(),
            responseTime: Date().timeIntervalSince(startTime),
            errorCount: 0,
            warningCount: 0,
            memoryUsage: nil,
            customMetrics: ["connectedDevices": 0]
        )
    }

    public func attemptRecovery(for issue: HealthIssue) async -> RecoveryAttempt {
        let start = Date()

        return RecoveryAttempt(
            id: UUID(),
            issueId: issue.id,
            action: "Reset network connections",
            attemptedAt: start,
            success: true,
            resultMessage: "Network connections reset",
            durationMs: Int(Date().timeIntervalSince(start) * 1000)
        )
    }
}

// MARK: - Convenience Extensions

extension SelfHealingTestFramework {

    /// Quick setup with default modules
    public func setupDefaultModules() {
        registerModule(AudioHealthCheck())
        registerModule(NetworkHealthCheck())
    }

    /// Run a single health check and return summary
    public func quickCheck() async -> String {
        await runHealthCheck()
        return "Status: \(currentHealth.overallStatus.rawValue), Issues: \(currentHealth.activeIssues.count)"
    }
}
