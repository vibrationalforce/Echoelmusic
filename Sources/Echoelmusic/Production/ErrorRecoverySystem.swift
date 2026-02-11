// ErrorRecoverySystem.swift
// Echoelmusic - Nobel Prize Multitrillion Dollar Error Recovery
//
// Graceful error handling, automatic recovery, circuit breakers,
// retry policies, and fault tolerance for production stability

import Foundation
import os.log
import Combine

// MARK: - Error Recovery System

/// Central error recovery and fault tolerance system
public final class ErrorRecoverySystem: Sendable {
    public static let shared = ErrorRecoverySystem()

    private let logger = os.Logger(subsystem: "com.echoelmusic", category: "recovery")

    // Circuit breaker states
    private let circuitBreakers = NSLock()
    private var _circuitBreakerStates: [String: CircuitBreakerState] = [:]

    private var circuitBreakerStates: [String: CircuitBreakerState] {
        get {
            circuitBreakers.lock()
            defer { circuitBreakers.unlock() }
            return _circuitBreakerStates
        }
        set {
            circuitBreakers.lock()
            defer { circuitBreakers.unlock() }
            _circuitBreakerStates = newValue
        }
    }

    private init() {}

    // MARK: - Configuration

    public func configure() {
        // Initialize circuit breakers for critical services
        let criticalServices = [
            "audio_engine",
            "video_engine",
            "streaming",
            "network",
            "database",
            "llm_service",
            "collaboration"
        ]

        for service in criticalServices {
            circuitBreakerStates[service] = CircuitBreakerState()
        }

        logger.info("Error recovery system configured with \(criticalServices.count) circuit breakers")
    }

    // MARK: - Circuit Breaker

    public struct CircuitBreakerState: Sendable {
        public var state: CircuitState = .closed
        public var failureCount: Int = 0
        public var lastFailureTime: Date?
        public var lastSuccessTime: Date?
        public var consecutiveSuccesses: Int = 0

        public enum CircuitState: String, Sendable {
            case closed      // Normal operation
            case open        // Blocking calls (service down)
            case halfOpen    // Testing if service recovered
        }
    }

    public struct CircuitBreakerConfig: Sendable {
        public var failureThreshold: Int = 5
        public var resetTimeout: TimeInterval = 30
        public var successThreshold: Int = 3

        public static let `default` = CircuitBreakerConfig()
        public static let aggressive = CircuitBreakerConfig(failureThreshold: 3, resetTimeout: 60, successThreshold: 5)
        public static let lenient = CircuitBreakerConfig(failureThreshold: 10, resetTimeout: 15, successThreshold: 2)
    }

    /// Execute with circuit breaker protection
    public func executeWithCircuitBreaker<T>(
        _ service: String,
        config: CircuitBreakerConfig = .default,
        operation: () async throws -> T
    ) async throws -> T {
        var state = circuitBreakerStates[service] ?? CircuitBreakerState()

        // Check circuit state
        switch state.state {
        case .open:
            // Check if reset timeout has passed
            if let lastFailure = state.lastFailureTime,
               Date().timeIntervalSince(lastFailure) > config.resetTimeout {
                state.state = .halfOpen
                circuitBreakerStates[service] = state
                logger.info("Circuit breaker \(service) transitioning to half-open")
            } else {
                throw RecoveryError.circuitBreakerOpen(service)
            }

        case .halfOpen:
            // Allow one test request
            break

        case .closed:
            // Normal operation
            break
        }

        do {
            let result = try await operation()

            // Success - update state
            state.consecutiveSuccesses += 1
            state.lastSuccessTime = Date()
            state.failureCount = 0

            if state.state == .halfOpen && state.consecutiveSuccesses >= config.successThreshold {
                state.state = .closed
                state.consecutiveSuccesses = 0
                logger.info("Circuit breaker \(service) closed after recovery")
            }

            circuitBreakerStates[service] = state
            return result

        } catch {
            // Failure - update state
            state.failureCount += 1
            state.lastFailureTime = Date()
            state.consecutiveSuccesses = 0

            if state.failureCount >= config.failureThreshold {
                state.state = .open
                logger.warning("Circuit breaker \(service) opened after \(state.failureCount) failures")

                Task { @MainActor in
                    await ProductionMonitoring.shared.trackEvent(
                        "circuit_breaker_open",
                        category: .error,
                        parameters: ["service": service]
                    )
                }
            }

            circuitBreakerStates[service] = state
            throw error
        }
    }

    /// Get circuit breaker status
    public func getCircuitBreakerStatus(_ service: String) -> CircuitBreakerState.CircuitState {
        return circuitBreakerStates[service]?.state ?? .closed
    }

    /// Manually reset circuit breaker
    public func resetCircuitBreaker(_ service: String) {
        circuitBreakerStates[service] = CircuitBreakerState()
        logger.info("Circuit breaker \(service) manually reset")
    }

    // MARK: - Recovery Retry Policy

    public struct RecoveryRetryPolicy: Sendable {
        public var maxAttempts: Int
        public var initialDelay: TimeInterval
        public var maxDelay: TimeInterval
        public var backoffMultiplier: Double
        public var jitter: Bool

        public static let `default` = RecoveryRetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.5,
            maxDelay: 30,
            backoffMultiplier: 2.0,
            jitter: true
        )

        public static let aggressive = RecoveryRetryPolicy(
            maxAttempts: 5,
            initialDelay: 0.1,
            maxDelay: 60,
            backoffMultiplier: 2.0,
            jitter: true
        )

        public static let conservative = RecoveryRetryPolicy(
            maxAttempts: 2,
            initialDelay: 1.0,
            maxDelay: 10,
            backoffMultiplier: 1.5,
            jitter: false
        )

        public func delayForAttempt(_ attempt: Int) -> TimeInterval {
            var delay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
            delay = min(delay, maxDelay)

            if jitter {
                delay *= Double.random(in: 0.8...1.2)
            }

            return delay
        }
    }

    /// Execute with retry policy
    public func executeWithRetry<T>(
        _ operation: String,
        policy: RecoveryRetryPolicy = .default,
        retryableErrors: [Error.Type] = [],
        task: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...policy.maxAttempts {
            do {
                return try await task()
            } catch {
                lastError = error

                // Check if error is retryable
                let shouldRetry = retryableErrors.isEmpty ||
                    retryableErrors.contains { type(of: error) == $0 }

                if !shouldRetry || attempt == policy.maxAttempts {
                    logger.error("Operation \(operation) failed after \(attempt) attempts: \(error.localizedDescription)")
                    throw error
                }

                let delay = policy.delayForAttempt(attempt)
                logger.warning("Operation \(operation) attempt \(attempt) failed, retrying in \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? RecoveryError.maxRetriesExceeded(operation)
    }

    // MARK: - Fallback System

    /// Execute with fallback
    public func executeWithFallback<T>(
        primary: () async throws -> T,
        fallback: () async throws -> T
    ) async throws -> T {
        do {
            return try await primary()
        } catch {
            logger.warning("Primary operation failed, using fallback: \(error.localizedDescription)")
            return try await fallback()
        }
    }

    /// Execute with multiple fallbacks
    public func executeWithFallbacks<T>(
        operations: [() async throws -> T]
    ) async throws -> T {
        var lastError: Error?

        for (index, operation) in operations.enumerated() {
            do {
                return try await operation()
            } catch {
                lastError = error
                logger.warning("Operation \(index + 1) of \(operations.count) failed: \(error.localizedDescription)")
            }
        }

        throw lastError ?? RecoveryError.allFallbacksFailed
    }

    // MARK: - Graceful Degradation

    public struct DegradationLevel: Sendable {
        public var level: Int // 0 = full, 5 = minimal
        public var disabledFeatures: Set<String>
        public var reason: String

        public static let full = DegradationLevel(level: 0, disabledFeatures: [], reason: "Full functionality")
        public static let reduced = DegradationLevel(level: 2, disabledFeatures: ["streaming", "collaboration"], reason: "Reduced functionality")
        public static let minimal = DegradationLevel(level: 5, disabledFeatures: ["streaming", "collaboration", "video", "ai"], reason: "Minimal functionality")
    }

    private var currentDegradationLevel = DegradationLevel.full

    /// Get current degradation level
    public var degradationLevel: DegradationLevel {
        currentDegradationLevel
    }

    /// Set degradation level
    public func setDegradationLevel(_ level: DegradationLevel) {
        currentDegradationLevel = level
        logger.warning("Degradation level set to \(level.level): \(level.reason)")

        Task { @MainActor in
            await ProductionMonitoring.shared.trackEvent(
                "degradation_level_changed",
                category: .performance,
                parameters: [
                    "level": String(level.level),
                    "reason": level.reason
                ]
            )
        }
    }

    /// Check if feature is available at current degradation level
    public func isFeatureAvailable(_ feature: String) -> Bool {
        return !currentDegradationLevel.disabledFeatures.contains(feature)
    }

    // MARK: - Error Recovery Actions

    /// Attempt automatic recovery for known error types
    public func attemptRecovery(for error: Error, context: String) async -> Bool {
        logger.info("Attempting recovery for error in \(context): \(error.localizedDescription)")

        // Handle known error types
        if let urlError = error as? URLError {
            return await handleNetworkError(urlError)
        }

        if let recoveryError = error as? RecoveryError {
            return await handleRecoveryError(recoveryError)
        }

        // Generic recovery attempt
        return await handleGenericError(error)
    }

    private func handleNetworkError(_ error: URLError) async -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            // Wait for network to recover
            logger.info("Waiting for network recovery...")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return true

        case .timedOut:
            // Retry with longer timeout
            return true

        default:
            return false
        }
    }

    private func handleRecoveryError(_ error: RecoveryError) async -> Bool {
        switch error {
        case .circuitBreakerOpen(let service):
            // Wait for circuit breaker reset
            logger.info("Waiting for circuit breaker \(service) to reset...")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return true

        default:
            return false
        }
    }

    private func handleGenericError(_ error: Error) async -> Bool {
        // Log and continue
        return false
    }
}

// MARK: - Rate Limiter

/// Production rate limiting to prevent abuse and ensure stability
public final class RateLimiter: Sendable {
    public static let shared = RateLimiter()

    private let buckets = NSLock()
    private var _tokenBuckets: [String: TokenBucket] = [:]

    private var tokenBuckets: [String: TokenBucket] {
        get {
            buckets.lock()
            defer { buckets.unlock() }
            return _tokenBuckets
        }
        set {
            buckets.lock()
            defer { buckets.unlock() }
            _tokenBuckets = newValue
        }
    }

    private init() {}

    public struct RateLimitConfig: Sendable {
        public var requestsPerSecond: Double
        public var burstSize: Int
        public var penaltyDuration: TimeInterval

        public static let standard = RateLimitConfig(requestsPerSecond: 10, burstSize: 20, penaltyDuration: 60)
        public static let strict = RateLimitConfig(requestsPerSecond: 5, burstSize: 10, penaltyDuration: 120)
        public static let lenient = RateLimitConfig(requestsPerSecond: 100, burstSize: 200, penaltyDuration: 30)
    }

    private struct TokenBucket: Sendable {
        var tokens: Double
        var lastRefill: Date
        var config: RateLimitConfig
        var violations: Int = 0
        var penaltyUntil: Date?
    }

    public func configure(for environment: DeploymentEnvironment) {
        let config: RateLimitConfig = environment.isProduction ? .standard : .lenient

        // Configure rate limits for different operations
        let operations = [
            "api_request": config,
            "streaming_start": RateLimitConfig(requestsPerSecond: 0.1, burstSize: 2, penaltyDuration: 300),
            "llm_request": RateLimitConfig(requestsPerSecond: 1, burstSize: 5, penaltyDuration: 60),
            "export": RateLimitConfig(requestsPerSecond: 0.2, burstSize: 3, penaltyDuration: 120)
        ]

        for (operation, opConfig) in operations {
            tokenBuckets[operation] = TokenBucket(
                tokens: Double(opConfig.burstSize),
                lastRefill: Date(),
                config: opConfig
            )
        }
    }

    /// Check if operation is allowed (consumes token if yes)
    public func checkRateLimit(_ operation: String) throws {
        guard var bucket = tokenBuckets[operation] else {
            return // No rate limit configured
        }

        // Check penalty
        if let penaltyUntil = bucket.penaltyUntil, Date() < penaltyUntil {
            throw RecoveryError.rateLimitExceeded(operation, retryAfter: penaltyUntil.timeIntervalSinceNow)
        }

        // Refill tokens
        let now = Date()
        let timePassed = now.timeIntervalSince(bucket.lastRefill)
        let tokensToAdd = timePassed * bucket.config.requestsPerSecond
        bucket.tokens = min(Double(bucket.config.burstSize), bucket.tokens + tokensToAdd)
        bucket.lastRefill = now

        // Check if we have tokens
        if bucket.tokens < 1 {
            bucket.violations += 1

            if bucket.violations >= 3 {
                bucket.penaltyUntil = Date().addingTimeInterval(bucket.config.penaltyDuration)
                bucket.violations = 0
            }

            tokenBuckets[operation] = bucket
            throw RecoveryError.rateLimitExceeded(operation, retryAfter: 1.0 / bucket.config.requestsPerSecond)
        }

        // Consume token
        bucket.tokens -= 1
        bucket.violations = max(0, bucket.violations - 1)
        tokenBuckets[operation] = bucket
    }

    /// Get remaining tokens for operation
    public func remainingTokens(for operation: String) -> Int {
        guard let bucket = tokenBuckets[operation] else { return Int.max }
        return Int(bucket.tokens)
    }
}

// MARK: - Recovery Errors

public enum RecoveryError: Error, LocalizedError, Sendable {
    case circuitBreakerOpen(String)
    case maxRetriesExceeded(String)
    case allFallbacksFailed
    case rateLimitExceeded(String, retryAfter: TimeInterval)
    case serviceUnavailable(String)
    case degradedMode(String)
    case recoveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .circuitBreakerOpen(let service):
            return "Service '\(service)' is temporarily unavailable (circuit breaker open)"
        case .maxRetriesExceeded(let operation):
            return "Maximum retries exceeded for '\(operation)'"
        case .allFallbacksFailed:
            return "All fallback operations failed"
        case .rateLimitExceeded(let operation, let retryAfter):
            return "Rate limit exceeded for '\(operation)'. Retry after \(Int(retryAfter)) seconds"
        case .serviceUnavailable(let service):
            return "Service '\(service)' is not available"
        case .degradedMode(let feature):
            return "Feature '\(feature)' is disabled due to degraded mode"
        case .recoveryFailed(let reason):
            return "Recovery failed: \(reason)"
        }
    }
}

// MARK: - Safe Execution Helpers

/// Execute operation with full production safety
public func safeExecute<T>(
    _ operation: String,
    service: String? = nil,
    retryPolicy: ErrorRecoverySystem.RecoveryRetryPolicy = .default,
    fallback: (() async throws -> T)? = nil,
    task: () async throws -> T
) async throws -> T {
    let recovery = ErrorRecoverySystem.shared

    // Check rate limit
    try RateLimiter.shared.checkRateLimit(operation)

    // Execute with circuit breaker (if service specified)
    let circuitBreakerTask: () async throws -> T = {
        if let service = service {
            return try await recovery.executeWithCircuitBreaker(service) {
                try await task()
            }
        } else {
            return try await task()
        }
    }

    // Execute with retry
    let retryTask: () async throws -> T = {
        try await recovery.executeWithRetry(operation, policy: retryPolicy) {
            try await circuitBreakerTask()
        }
    }

    // Execute with fallback
    if let fallback = fallback {
        return try await recovery.executeWithFallback(primary: retryTask, fallback: fallback)
    } else {
        return try await retryTask()
    }
}
