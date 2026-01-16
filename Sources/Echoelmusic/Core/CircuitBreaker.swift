// CircuitBreaker.swift
// Echoelmusic - Network Resilience with Circuit Breaker Pattern
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Prevents cascade failures by automatically detecting and handling
// service outages. Essential for streaming, API calls, and DMX/Art-Net.
//
// States: CLOSED → OPEN → HALF_OPEN → CLOSED
//
// Supported Platforms: ALL
// Created 2026-01-16

import Foundation
import Combine

// MARK: - Circuit Breaker

/// Circuit Breaker for fault-tolerant network operations
///
/// Implements the Circuit Breaker pattern to prevent cascade failures:
/// - CLOSED: Normal operation, requests pass through
/// - OPEN: Failures exceeded threshold, requests fail fast
/// - HALF_OPEN: Testing if service recovered
///
/// Usage:
/// ```swift
/// let breaker = CircuitBreaker(name: "StreamAPI")
///
/// try await breaker.execute {
///     try await streamEngine.connect()
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public actor CircuitBreaker {

    // MARK: - Types

    /// Circuit breaker state
    public enum State: String, Sendable {
        case closed     // Normal operation
        case open       // Failing fast
        case halfOpen   // Testing recovery
    }

    /// Circuit breaker configuration
    public struct Configuration: Sendable {
        /// Number of failures before opening circuit
        public var failureThreshold: Int

        /// Time to wait before attempting recovery
        public var recoveryTimeout: TimeInterval

        /// Number of successes needed to close circuit
        public var successThreshold: Int

        /// Time window for counting failures
        public var failureWindow: TimeInterval

        /// Whether to use exponential backoff
        public var useExponentialBackoff: Bool

        /// Maximum backoff time
        public var maxBackoff: TimeInterval

        public init(
            failureThreshold: Int = 5,
            recoveryTimeout: TimeInterval = 30,
            successThreshold: Int = 2,
            failureWindow: TimeInterval = 60,
            useExponentialBackoff: Bool = true,
            maxBackoff: TimeInterval = 300
        ) {
            self.failureThreshold = failureThreshold
            self.recoveryTimeout = recoveryTimeout
            self.successThreshold = successThreshold
            self.failureWindow = failureWindow
            self.useExponentialBackoff = useExponentialBackoff
            self.maxBackoff = maxBackoff
        }

        /// Default configuration
        public static let `default` = Configuration()

        /// Aggressive configuration for critical services
        public static let aggressive = Configuration(
            failureThreshold: 3,
            recoveryTimeout: 10,
            successThreshold: 1
        )

        /// Relaxed configuration for non-critical services
        public static let relaxed = Configuration(
            failureThreshold: 10,
            recoveryTimeout: 60,
            successThreshold: 3
        )

        /// Streaming configuration (low latency tolerance)
        public static let streaming = Configuration(
            failureThreshold: 3,
            recoveryTimeout: 5,
            successThreshold: 1,
            failureWindow: 30,
            useExponentialBackoff: false
        )
    }

    /// Circuit breaker error
    public enum CircuitBreakerError: Error, LocalizedError {
        case circuitOpen(name: String, remainingTime: TimeInterval)
        case executionFailed(underlying: Error)
        case timeout

        public var errorDescription: String? {
            switch self {
            case .circuitOpen(let name, let time):
                return "Circuit '\(name)' is open. Retry in \(Int(time))s"
            case .executionFailed(let error):
                return "Execution failed: \(error.localizedDescription)"
            case .timeout:
                return "Operation timed out"
            }
        }
    }

    // MARK: - Properties

    /// Circuit breaker name (for logging)
    public let name: String

    /// Configuration
    public let config: Configuration

    /// Current state
    public private(set) var state: State = .closed

    /// Failure timestamps within the window
    private var failureTimestamps: [Date] = []

    /// Success count in half-open state
    private var halfOpenSuccesses: Int = 0

    /// Time when circuit was opened
    private var openedAt: Date?

    /// Current backoff multiplier
    private var backoffMultiplier: Int = 1

    /// State change publisher
    private let stateSubject = PassthroughSubject<State, Never>()

    /// Statistics
    private var stats = Statistics()

    // MARK: - Initialization

    public init(name: String, config: Configuration = .default) {
        self.name = name
        self.config = config
    }

    // MARK: - Execution

    /// Execute an operation with circuit breaker protection
    ///
    /// - Parameters:
    ///   - timeout: Optional timeout for the operation
    ///   - operation: The operation to execute
    /// - Returns: The operation result
    /// - Throws: CircuitBreakerError if circuit is open or operation fails
    public func execute<T>(
        timeout: TimeInterval? = nil,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Check if circuit allows execution
        try await checkCircuit()

        stats.totalRequests += 1

        do {
            // Execute with optional timeout
            let result: T
            if let timeout = timeout {
                result = try await withTimeout(timeout) {
                    try await operation()
                }
            } else {
                result = try await operation()
            }

            // Success - record it
            await recordSuccess()
            return result

        } catch {
            // Failure - record it
            await recordFailure(error)
            throw CircuitBreakerError.executionFailed(underlying: error)
        }
    }

    /// Execute with automatic retry
    public func executeWithRetry<T>(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await execute(operation)
            } catch {
                lastError = error

                // Don't retry if circuit is open
                if case CircuitBreakerError.circuitOpen = error {
                    throw error
                }

                // Wait before retry (with jitter)
                let jitter = Double.random(in: 0.8...1.2)
                let delay = retryDelay * Double(attempt + 1) * jitter
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? CircuitBreakerError.timeout
    }

    // MARK: - State Management

    private func checkCircuit() async throws {
        switch state {
        case .closed:
            // Normal operation
            break

        case .open:
            // Check if recovery timeout has passed
            if let openedAt = openedAt {
                let elapsed = Date().timeIntervalSince(openedAt)
                let timeout = config.recoveryTimeout * Double(backoffMultiplier)

                if elapsed >= timeout {
                    // Transition to half-open
                    transitionTo(.halfOpen)
                } else {
                    stats.rejectedRequests += 1
                    throw CircuitBreakerError.circuitOpen(
                        name: name,
                        remainingTime: timeout - elapsed
                    )
                }
            }

        case .halfOpen:
            // Allow limited requests through
            break
        }
    }

    private func recordSuccess() async {
        stats.successfulRequests += 1

        switch state {
        case .closed:
            // Reset failure count on success
            cleanupOldFailures()

        case .halfOpen:
            halfOpenSuccesses += 1
            if halfOpenSuccesses >= config.successThreshold {
                // Recovered - close circuit
                transitionTo(.closed)
                backoffMultiplier = 1
            }

        case .open:
            // Shouldn't happen
            break
        }
    }

    private func recordFailure(_ error: Error) async {
        stats.failedRequests += 1
        failureTimestamps.append(Date())
        cleanupOldFailures()

        switch state {
        case .closed:
            if failureTimestamps.count >= config.failureThreshold {
                transitionTo(.open)
            }

        case .halfOpen:
            // Failed during recovery - reopen
            transitionTo(.open)
            if config.useExponentialBackoff {
                backoffMultiplier = min(backoffMultiplier * 2, 10)
            }

        case .open:
            // Already open
            break
        }
    }

    private func transitionTo(_ newState: State) {
        let oldState = state
        state = newState

        switch newState {
        case .closed:
            openedAt = nil
            halfOpenSuccesses = 0
            failureTimestamps.removeAll()
            log.info("CircuitBreaker[\(name)]: CLOSED (recovered)")

        case .open:
            openedAt = Date()
            halfOpenSuccesses = 0
            stats.timesOpened += 1
            log.warning("CircuitBreaker[\(name)]: OPEN (failures: \(failureTimestamps.count))")

        case .halfOpen:
            halfOpenSuccesses = 0
            log.info("CircuitBreaker[\(name)]: HALF_OPEN (testing recovery)")
        }

        stateSubject.send(newState)
    }

    private func cleanupOldFailures() {
        let cutoff = Date().addingTimeInterval(-config.failureWindow)
        failureTimestamps.removeAll { $0 < cutoff }
    }

    // MARK: - Manual Control

    /// Force circuit open
    public func forceOpen() {
        transitionTo(.open)
    }

    /// Force circuit closed
    public func forceClose() {
        transitionTo(.closed)
    }

    /// Reset circuit breaker
    public func reset() {
        state = .closed
        failureTimestamps.removeAll()
        halfOpenSuccesses = 0
        openedAt = nil
        backoffMultiplier = 1
        stats = Statistics()
    }

    // MARK: - Statistics

    public struct Statistics: Sendable {
        public var totalRequests: Int = 0
        public var successfulRequests: Int = 0
        public var failedRequests: Int = 0
        public var rejectedRequests: Int = 0
        public var timesOpened: Int = 0

        public var successRate: Double {
            guard totalRequests > 0 else { return 1.0 }
            return Double(successfulRequests) / Double(totalRequests)
        }
    }

    public var statistics: Statistics { stats }

    /// State change publisher
    public var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Timeout Helper

    private func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CircuitBreakerError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Circuit Breaker Registry

/// Central registry for all circuit breakers
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@MainActor
public final class CircuitBreakerRegistry {

    /// Shared instance
    public static let shared = CircuitBreakerRegistry()

    /// All registered circuit breakers
    private var breakers: [String: CircuitBreaker] = [:]

    private init() {}

    /// Get or create a circuit breaker
    public func breaker(
        for name: String,
        config: CircuitBreaker.Configuration = .default
    ) -> CircuitBreaker {
        if let existing = breakers[name] {
            return existing
        }

        let breaker = CircuitBreaker(name: name, config: config)
        breakers[name] = breaker
        return breaker
    }

    /// Get all breaker statistics
    public func allStatistics() async -> [String: CircuitBreaker.Statistics] {
        var result: [String: CircuitBreaker.Statistics] = [:]
        for (name, breaker) in breakers {
            result[name] = await breaker.statistics
        }
        return result
    }

    /// Reset all breakers
    public func resetAll() async {
        for breaker in breakers.values {
            await breaker.reset()
        }
    }

    // MARK: - Predefined Breakers

    /// Circuit breaker for streaming API
    public var streaming: CircuitBreaker {
        breaker(for: "streaming", config: .streaming)
    }

    /// Circuit breaker for HealthKit
    public var healthKit: CircuitBreaker {
        breaker(for: "healthKit", config: .relaxed)
    }

    /// Circuit breaker for DMX/Art-Net
    public var lighting: CircuitBreaker {
        breaker(for: "lighting", config: .aggressive)
    }

    /// Circuit breaker for cloud sync
    public var cloudSync: CircuitBreaker {
        breaker(for: "cloudSync", config: .default)
    }
}

// MARK: - Retry Policy

/// Configurable retry policy
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    public let jitterFactor: Double

    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        jitterFactor: Double = 0.2
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.jitterFactor = jitterFactor
    }

    /// Calculate delay for attempt
    public func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)
        let jitter = Double.random(in: (1 - jitterFactor)...(1 + jitterFactor))
        return cappedDelay * jitter
    }

    /// Default policy
    public static let `default` = RetryPolicy()

    /// Aggressive retry for critical operations
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 10.0
    )

    /// No retry
    public static let none = RetryPolicy(maxAttempts: 1)
}
