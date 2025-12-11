// StressResistance.swift
// Echoelmusic - Stress Resistenz Wise Mode
// Bulletproof | Resilient | Unbreakable | Zero Crashes

import Foundation
import Combine

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🛡️ STRESS RESISTANCE CORE - Bulletproof Infrastructure
// MARK: ═══════════════════════════════════════════════════════════════════

/// Stress Resistance Mode - Making code unbreakable
@MainActor
public final class StressResistance: ObservableObject {

    // MARK: - Singleton

    public static let shared = StressResistance()

    // MARK: - Health Metrics

    @Published public private(set) var systemHealth: SystemHealth = .optimal
    @Published public private(set) var errorCount: Int = 0
    @Published public private(set) var recoveryCount: Int = 0
    @Published public private(set) var uptimeSeconds: TimeInterval = 0

    // MARK: - Health Status

    public enum SystemHealth: String, CaseIterable {
        case optimal = "🟢 Optimal"
        case good = "🟡 Good"
        case degraded = "🟠 Degraded"
        case critical = "🔴 Critical"

        public var isHealthy: Bool {
            self == .optimal || self == .good
        }

        public var description: String {
            switch self {
            case .optimal: return "All systems running perfectly"
            case .good: return "Minor issues detected, auto-recovering"
            case .degraded: return "Some features running in fallback mode"
            case .critical: return "Critical issues, intervention needed"
            }
        }
    }

    // MARK: - Initialization

    private var uptimeTimer: Timer?
    private var healthCheckTimer: Timer?

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        // Track uptime
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.uptimeSeconds += 1
            }
        }

        // Health checks every 30 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
            }
        }
    }

    // MARK: - Health Check

    private func performHealthCheck() {
        // Calculate health based on error rate
        let errorRate = errorCount > 0 ? Double(errorCount) / max(1, uptimeSeconds / 60) : 0

        if errorRate < 0.1 {
            systemHealth = .optimal
        } else if errorRate < 0.5 {
            systemHealth = .good
        } else if errorRate < 1.0 {
            systemHealth = .degraded
        } else {
            systemHealth = .critical
        }

        Logger.debug("Health check: \(systemHealth.rawValue), errors/min: \(String(format: "%.2f", errorRate))", category: .system)
    }

    // MARK: - Error Recording

    /// Record an error (but don't panic - we handle it!)
    public func recordError(_ error: Error, context: String) {
        errorCount += 1
        Logger.warning("Handled error in \(context): \(error.localizedDescription)", category: .system)
    }

    /// Record a successful recovery
    public func recordRecovery(_ context: String) {
        recoveryCount += 1
        Logger.info("✅ Auto-recovered: \(context)", category: .system)
    }

    // MARK: - Status Report

    public func statusReport() -> String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        let seconds = Int(uptimeSeconds) % 60

        return """
        ╔══════════════════════════════════════════════════════════════╗
        ║            🛡️ STRESS RESISTANCE STATUS REPORT 🛡️              ║
        ╠══════════════════════════════════════════════════════════════╣
        ║  System Health:    \(systemHealth.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0))                  ║
        ║  Uptime:           \(String(format: "%02d:%02d:%02d", hours, minutes, seconds).padding(toLength: 20, withPad: " ", startingAt: 0))                  ║
        ║  Errors Handled:   \(String(errorCount).padding(toLength: 20, withPad: " ", startingAt: 0))                  ║
        ║  Auto-Recoveries:  \(String(recoveryCount).padding(toLength: 20, withPad: " ", startingAt: 0))                  ║
        ╠══════════════════════════════════════════════════════════════╣
        ║  \(systemHealth.description.padding(toLength: 58, withPad: " ", startingAt: 0))  ║
        ╚══════════════════════════════════════════════════════════════╝
        """
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   ⚡ CIRCUIT BREAKER - Prevent Cascade Failures
// MARK: ═══════════════════════════════════════════════════════════════════

/// Circuit Breaker pattern - stops calling failing services
public actor CircuitBreaker {

    // MARK: - State

    public enum State {
        case closed      // Normal operation
        case open        // Failing, reject calls
        case halfOpen    // Testing if recovered

        public var description: String {
            switch self {
            case .closed: return "🟢 Closed (Normal)"
            case .open: return "🔴 Open (Blocking)"
            case .halfOpen: return "🟡 Half-Open (Testing)"
            }
        }
    }

    // MARK: - Configuration

    public struct Configuration {
        public let failureThreshold: Int
        public let successThreshold: Int
        public let timeout: TimeInterval
        public let resetTimeout: TimeInterval

        public init(
            failureThreshold: Int = 5,
            successThreshold: Int = 2,
            timeout: TimeInterval = 30,
            resetTimeout: TimeInterval = 60
        ) {
            self.failureThreshold = failureThreshold
            self.successThreshold = successThreshold
            self.timeout = timeout
            self.resetTimeout = resetTimeout
        }

        public static let `default` = Configuration()
        public static let aggressive = Configuration(failureThreshold: 3, successThreshold: 1, timeout: 10, resetTimeout: 30)
        public static let relaxed = Configuration(failureThreshold: 10, successThreshold: 3, timeout: 60, resetTimeout: 120)
    }

    // MARK: - Properties

    private let name: String
    private let configuration: Configuration
    private var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?

    // MARK: - Initialization

    public init(name: String, configuration: Configuration = .default) {
        self.name = name
        self.configuration = configuration
    }

    // MARK: - Execute

    /// Execute an operation through the circuit breaker
    public func execute<T>(_ operation: () async throws -> T) async throws -> T {
        // Check if we should try
        guard await shouldAttempt() else {
            throw CircuitBreakerError.circuitOpen(name: name)
        }

        do {
            let result = try await operation()
            await recordSuccess()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }

    /// Execute with fallback
    public func execute<T>(
        _ operation: () async throws -> T,
        fallback: () async throws -> T
    ) async throws -> T {
        do {
            return try await execute(operation)
        } catch is CircuitBreakerError {
            Logger.warning("Circuit '\(name)' open, using fallback", category: .system)
            return try await fallback()
        }
    }

    // MARK: - State Management

    private func shouldAttempt() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            // Check if reset timeout has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= configuration.resetTimeout {
                state = .halfOpen
                Logger.info("Circuit '\(name)' entering half-open state", category: .system)
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }

    private func recordSuccess() {
        failureCount = 0

        switch state {
        case .halfOpen:
            successCount += 1
            if successCount >= configuration.successThreshold {
                state = .closed
                successCount = 0
                Logger.info("Circuit '\(name)' closed (recovered)", category: .system)
                Task { @MainActor in
                    StressResistance.shared.recordRecovery("Circuit '\(name)' recovered")
                }
            }
        case .closed, .open:
            break
        }
    }

    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        switch state {
        case .closed:
            if failureCount >= configuration.failureThreshold {
                state = .open
                Logger.warning("Circuit '\(name)' opened after \(failureCount) failures", category: .system)
            }
        case .halfOpen:
            state = .open
            successCount = 0
            Logger.warning("Circuit '\(name)' re-opened (test failed)", category: .system)
        case .open:
            break
        }

        Task { @MainActor in
            StressResistance.shared.recordError(
                CircuitBreakerError.circuitOpen(name: name),
                context: "Circuit '\(name)'"
            )
        }
    }

    // MARK: - Status

    public func getState() -> State { state }
    public func getFailureCount() -> Int { failureCount }
}

/// Circuit Breaker errors
public enum CircuitBreakerError: LocalizedError {
    case circuitOpen(name: String)
    case timeout(name: String)

    public var errorDescription: String? {
        switch self {
        case .circuitOpen(let name):
            return "Circuit '\(name)' is open - service temporarily unavailable"
        case .timeout(let name):
            return "Circuit '\(name)' operation timed out"
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🔄 RETRY ENGINE - Persistent Operation Execution
// MARK: ═══════════════════════════════════════════════════════════════════

/// Retry configuration and execution
public struct RetryEngine {

    // MARK: - Configuration

    public struct Configuration {
        public let maxAttempts: Int
        public let initialDelay: TimeInterval
        public let maxDelay: TimeInterval
        public let multiplier: Double
        public let jitter: Bool

        public init(
            maxAttempts: Int = 3,
            initialDelay: TimeInterval = 1.0,
            maxDelay: TimeInterval = 30.0,
            multiplier: Double = 2.0,
            jitter: Bool = true
        ) {
            self.maxAttempts = maxAttempts
            self.initialDelay = initialDelay
            self.maxDelay = maxDelay
            self.multiplier = multiplier
            self.jitter = jitter
        }

        public static let `default` = Configuration()
        public static let aggressive = Configuration(maxAttempts: 5, initialDelay: 0.5, multiplier: 1.5)
        public static let patient = Configuration(maxAttempts: 10, initialDelay: 2.0, maxDelay: 60.0, multiplier: 2.0)
        public static let instant = Configuration(maxAttempts: 3, initialDelay: 0.1, maxDelay: 1.0, multiplier: 2.0)
    }

    // MARK: - Execute

    /// Execute with retry
    public static func execute<T>(
        configuration: Configuration = .default,
        operation: () async throws -> T
    ) async throws -> T {
        var currentDelay = configuration.initialDelay
        var lastError: Error?

        for attempt in 1...configuration.maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    Logger.info("Retry succeeded on attempt \(attempt)", category: .system)
                    Task { @MainActor in
                        StressResistance.shared.recordRecovery("Operation succeeded after \(attempt) attempts")
                    }
                }
                return result
            } catch {
                lastError = error
                Logger.warning("Attempt \(attempt)/\(configuration.maxAttempts) failed: \(error.localizedDescription)", category: .system)

                if attempt < configuration.maxAttempts {
                    // Calculate delay with optional jitter
                    var delay = currentDelay
                    if configuration.jitter {
                        delay *= Double.random(in: 0.8...1.2)
                    }

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    currentDelay = min(currentDelay * configuration.multiplier, configuration.maxDelay)
                }
            }
        }

        Task { @MainActor in
            StressResistance.shared.recordError(lastError ?? AppError.internalError(description: "Retry exhausted"), context: "RetryEngine")
        }

        throw lastError ?? AppError.internalError(description: "All retry attempts failed")
    }

    /// Execute with retry and fallback
    public static func execute<T>(
        configuration: Configuration = .default,
        operation: () async throws -> T,
        fallback: () async throws -> T
    ) async throws -> T {
        do {
            return try await execute(configuration: configuration, operation: operation)
        } catch {
            Logger.warning("All retries failed, using fallback", category: .system)
            return try await fallback()
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🎯 FALLBACK CHAIN - Graceful Degradation
// MARK: ═══════════════════════════════════════════════════════════════════

/// Fallback chain - try multiple strategies until one works
public struct FallbackChain<T> {

    private var strategies: [() async throws -> T] = []
    private let name: String

    public init(name: String = "FallbackChain") {
        self.name = name
    }

    /// Add a strategy to the chain
    public mutating func add(_ strategy: @escaping () async throws -> T) {
        strategies.append(strategy)
    }

    /// Add a strategy with a name for logging
    public mutating func add(name: String, _ strategy: @escaping () async throws -> T) {
        strategies.append {
            Logger.debug("Trying strategy: \(name)", category: .system)
            return try await strategy()
        }
    }

    /// Execute the chain until one strategy succeeds
    public func execute() async throws -> T {
        var lastError: Error?

        for (index, strategy) in strategies.enumerated() {
            do {
                let result = try await strategy()
                if index > 0 {
                    Logger.info("Fallback chain '\(name)' succeeded on strategy \(index + 1)", category: .system)
                    Task { @MainActor in
                        StressResistance.shared.recordRecovery("Fallback chain '\(name)' strategy \(index + 1)")
                    }
                }
                return result
            } catch {
                lastError = error
                Logger.warning("Fallback chain '\(name)' strategy \(index + 1) failed: \(error.localizedDescription)", category: .system)
            }
        }

        throw lastError ?? AppError.internalError(description: "All fallback strategies failed")
    }

    /// Execute with a final default value
    public func execute(default defaultValue: T) async -> T {
        do {
            return try await execute()
        } catch {
            Logger.warning("All fallbacks failed, using default value", category: .system)
            return defaultValue
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🏥 SELF-HEALING - Automatic Recovery
// MARK: ═══════════════════════════════════════════════════════════════════

/// Self-healing wrapper for components
public actor SelfHealingComponent<T> {

    private var component: T?
    private let factory: () async throws -> T
    private let healthCheck: (T) async -> Bool
    private let name: String
    private var failureCount: Int = 0
    private let maxFailures: Int

    public init(
        name: String,
        maxFailures: Int = 3,
        factory: @escaping () async throws -> T,
        healthCheck: @escaping (T) async -> Bool = { _ in true }
    ) {
        self.name = name
        self.maxFailures = maxFailures
        self.factory = factory
        self.healthCheck = healthCheck
    }

    /// Get the component, creating or healing if necessary
    public func get() async throws -> T {
        // Check if we have a healthy component
        if let existing = component {
            if await healthCheck(existing) {
                failureCount = 0
                return existing
            } else {
                Logger.warning("Component '\(name)' health check failed, healing...", category: .system)
                component = nil
            }
        }

        // Create new component
        do {
            let newComponent = try await factory()
            component = newComponent
            failureCount = 0
            Logger.info("Component '\(name)' created/healed successfully", category: .system)
            Task { @MainActor in
                StressResistance.shared.recordRecovery("Component '\(name)' healed")
            }
            return newComponent
        } catch {
            failureCount += 1
            Logger.error("Failed to create/heal component '\(name)' (attempt \(failureCount)/\(maxFailures))", category: .system, error: error)

            if failureCount >= maxFailures {
                throw SelfHealingError.healingFailed(component: name, attempts: failureCount)
            }

            throw error
        }
    }

    /// Force recreation of the component
    public func reset() async throws {
        component = nil
        _ = try await get()
    }

    /// Check if component is healthy
    public func isHealthy() async -> Bool {
        guard let existing = component else { return false }
        return await healthCheck(existing)
    }
}

/// Self-healing errors
public enum SelfHealingError: LocalizedError {
    case healingFailed(component: String, attempts: Int)

    public var errorDescription: String? {
        switch self {
        case .healingFailed(let component, let attempts):
            return "Component '\(component)' failed to heal after \(attempts) attempts"
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🔒 SAFE WRAPPERS - Bulletproof Operations
// MARK: ═══════════════════════════════════════════════════════════════════

/// Safe execution that never throws
public func safely<T>(
    default defaultValue: T,
    context: String = "Operation",
    operation: () throws -> T
) -> T {
    do {
        return try operation()
    } catch {
        Logger.warning("Safe execution caught error in \(context): \(error.localizedDescription)", category: .system)
        Task { @MainActor in
            StressResistance.shared.recordError(error, context: context)
        }
        return defaultValue
    }
}

/// Safe async execution that never throws
public func safelyAsync<T>(
    default defaultValue: T,
    context: String = "Operation",
    operation: () async throws -> T
) async -> T {
    do {
        return try await operation()
    } catch {
        Logger.warning("Safe async execution caught error in \(context): \(error.localizedDescription)", category: .system)
        Task { @MainActor in
            StressResistance.shared.recordError(error, context: context)
        }
        return defaultValue
    }
}

/// Safe execution that returns nil on error
public func safelyOptional<T>(
    context: String = "Operation",
    operation: () throws -> T
) -> T? {
    do {
        return try operation()
    } catch {
        Logger.warning("Safe optional caught error in \(context): \(error.localizedDescription)", category: .system)
        Task { @MainActor in
            StressResistance.shared.recordError(error, context: context)
        }
        return nil
    }
}

/// Safe async execution that returns nil on error
public func safelyOptionalAsync<T>(
    context: String = "Operation",
    operation: () async throws -> T
) async -> T? {
    do {
        return try await operation()
    } catch {
        Logger.warning("Safe optional async caught error in \(context): \(error.localizedDescription)", category: .system)
        Task { @MainActor in
            StressResistance.shared.recordError(error, context: context)
        }
        return nil
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   📊 HEALTH MONITOR - System-wide Health Tracking
// MARK: ═══════════════════════════════════════════════════════════════════

/// Health check protocol
public protocol HealthCheckable {
    var componentName: String { get }
    func performHealthCheck() async -> HealthStatus
}

/// Health status
public struct HealthStatus {
    public let isHealthy: Bool
    public let message: String
    public let timestamp: Date

    public init(isHealthy: Bool, message: String) {
        self.isHealthy = isHealthy
        self.message = message
        self.timestamp = Date()
    }

    public static func healthy(_ message: String = "OK") -> HealthStatus {
        HealthStatus(isHealthy: true, message: message)
    }

    public static func unhealthy(_ message: String) -> HealthStatus {
        HealthStatus(isHealthy: false, message: message)
    }
}

/// System-wide health monitor
@MainActor
public final class HealthMonitor: ObservableObject {

    public static let shared = HealthMonitor()

    @Published public private(set) var componentStatuses: [String: HealthStatus] = [:]
    @Published public private(set) var overallHealth: StressResistance.SystemHealth = .optimal

    private var components: [HealthCheckable] = []

    private init() {}

    /// Register a component for health monitoring
    public func register(_ component: HealthCheckable) {
        components.append(component)
    }

    /// Run all health checks
    public func checkAll() async {
        for component in components {
            let status = await component.performHealthCheck()
            componentStatuses[component.componentName] = status
        }

        updateOverallHealth()
    }

    private func updateOverallHealth() {
        let unhealthyCount = componentStatuses.values.filter { !$0.isHealthy }.count
        let total = componentStatuses.count

        if unhealthyCount == 0 {
            overallHealth = .optimal
        } else if unhealthyCount <= total / 4 {
            overallHealth = .good
        } else if unhealthyCount <= total / 2 {
            overallHealth = .degraded
        } else {
            overallHealth = .critical
        }
    }

    /// Get formatted health report
    public func healthReport() -> String {
        var report = """
        ╔══════════════════════════════════════════════════════════════╗
        ║               🏥 SYSTEM HEALTH REPORT 🏥                      ║
        ╠══════════════════════════════════════════════════════════════╣
        ║  Overall: \(overallHealth.rawValue.padding(toLength: 30, withPad: " ", startingAt: 0))                     ║
        ╠══════════════════════════════════════════════════════════════╣
        """

        for (name, status) in componentStatuses.sorted(by: { $0.key < $1.key }) {
            let icon = status.isHealthy ? "✅" : "❌"
            let line = "║  \(icon) \(name.padding(toLength: 20, withPad: " ", startingAt: 0)): \(status.message.padding(toLength: 30, withPad: " ", startingAt: 0))  ║"
            report += "\n" + line
        }

        report += "\n╚══════════════════════════════════════════════════════════════╝"
        return report
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🎛️ GRACEFUL DEGRADATION - Feature Flags
// MARK: ═══════════════════════════════════════════════════════════════════

/// Feature flag for graceful degradation
@MainActor
public final class FeatureFlags: ObservableObject {

    public static let shared = FeatureFlags()

    // Core features (always try to keep enabled)
    @Published public var audioPlaybackEnabled: Bool = true
    @Published public var midiEnabled: Bool = true

    // Enhanced features (can degrade)
    @Published public var spatialAudioEnabled: Bool = true
    @Published public var visualizationsEnabled: Bool = true
    @Published public var biofeedbackEnabled: Bool = true
    @Published public var ledControlEnabled: Bool = true

    // Experimental features
    @Published public var experimentalFeaturesEnabled: Bool = false
    @Published public var debugModeEnabled: Bool = false

    private init() {}

    /// Degrade a feature (disable it gracefully)
    public func degradeFeature(_ feature: WritableKeyPath<FeatureFlags, Bool>, reason: String) {
        self[keyPath: feature] = false
        Logger.warning("Feature degraded: \(feature) - \(reason)", category: .system)
    }

    /// Restore a feature
    public func restoreFeature(_ feature: WritableKeyPath<FeatureFlags, Bool>) {
        self[keyPath: feature] = true
        Logger.info("Feature restored: \(feature)", category: .system)
    }

    /// Emergency mode - disable all non-essential features
    public func enterEmergencyMode() {
        spatialAudioEnabled = false
        visualizationsEnabled = false
        biofeedbackEnabled = false
        ledControlEnabled = false
        experimentalFeaturesEnabled = false

        Logger.warning("⚠️ EMERGENCY MODE ACTIVATED - Non-essential features disabled", category: .system)
    }

    /// Restore all features
    public func restoreAllFeatures() {
        audioPlaybackEnabled = true
        midiEnabled = true
        spatialAudioEnabled = true
        visualizationsEnabled = true
        biofeedbackEnabled = true
        ledControlEnabled = true

        Logger.info("✅ All features restored", category: .system)
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🛡️ DEFENSIVE UTILITIES
// MARK: ═══════════════════════════════════════════════════════════════════

/// Defensive guard that logs instead of crashing
public func defensiveGuard(
    _ condition: Bool,
    message: String,
    file: String = #file,
    line: Int = #line
) -> Bool {
    if !condition {
        let filename = (file as NSString).lastPathComponent
        Logger.warning("Defensive guard failed: \(message) at \(filename):\(line)", category: .system)
    }
    return condition
}

/// Assert in debug, log in release
public func defensiveAssert(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String,
    file: String = #file,
    line: Int = #line
) {
    #if DEBUG
    assert(condition(), message(), file: file, line: line)
    #else
    if !condition() {
        let filename = (file as NSString).lastPathComponent
        Logger.error("Assertion would have failed: \(message()) at \(filename):\(line)", category: .system)
    }
    #endif
}

/// Precondition in debug, log in release
public func defensivePrecondition(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String,
    file: String = #file,
    line: Int = #line
) {
    #if DEBUG
    precondition(condition(), message(), file: file, line: line)
    #else
    if !condition() {
        let filename = (file as NSString).lastPathComponent
        Logger.error("Precondition would have failed: \(message()) at \(filename):\(line)", category: .system)
    }
    #endif
}

/// Safe fatalError - logs in release instead of crashing
public func defensiveFatalError(
    _ message: @autoclosure () -> String,
    file: String = #file,
    line: Int = #line
) -> Never {
    let msg = message()
    let filename = (file as NSString).lastPathComponent
    Logger.critical("Fatal error: \(msg) at \(filename):\(line)", category: .system)

    #if DEBUG
    fatalError(msg, file: file, line: line)
    #else
    // In release, we still need to stop execution
    // but we've logged the error for debugging
    fatalError("Critical error occurred. Check logs for details.")
    #endif
}
