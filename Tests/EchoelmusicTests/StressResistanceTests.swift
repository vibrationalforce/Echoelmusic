// StressResistanceTests.swift
// Echoelmusic - Stress Resistance Test Suite
// Testing bulletproof, resilient patterns

import XCTest
@testable import Echoelmusic

final class StressResistanceTests: XCTestCase {

    // MARK: - Circuit Breaker Tests

    func testCircuitBreakerStartsClosed() async {
        let breaker = CircuitBreaker(name: "test")
        let state = await breaker.getState()
        XCTAssertEqual(state, .closed)
    }

    func testCircuitBreakerOpensAfterFailures() async {
        let config = CircuitBreaker.Configuration(failureThreshold: 3, successThreshold: 1, timeout: 1, resetTimeout: 1)
        let breaker = CircuitBreaker(name: "test", configuration: config)

        // Simulate failures
        for _ in 0..<3 {
            do {
                _ = try await breaker.execute {
                    throw TestError.simulated
                }
            } catch {}
        }

        let state = await breaker.getState()
        XCTAssertEqual(state, .open)
    }

    func testCircuitBreakerRejectsWhenOpen() async {
        let config = CircuitBreaker.Configuration(failureThreshold: 1, successThreshold: 1, timeout: 1, resetTimeout: 60)
        let breaker = CircuitBreaker(name: "test", configuration: config)

        // Open the circuit
        do {
            _ = try await breaker.execute {
                throw TestError.simulated
            }
        } catch {}

        // Should be rejected
        do {
            _ = try await breaker.execute {
                return "success"
            }
            XCTFail("Should have thrown CircuitBreakerError")
        } catch let error as CircuitBreakerError {
            if case .circuitOpen(let name) = error {
                XCTAssertEqual(name, "test")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testCircuitBreakerWithFallback() async throws {
        let config = CircuitBreaker.Configuration(failureThreshold: 1, successThreshold: 1, timeout: 1, resetTimeout: 60)
        let breaker = CircuitBreaker(name: "test", configuration: config)

        // Open the circuit
        do {
            _ = try await breaker.execute {
                throw TestError.simulated
            }
        } catch {}

        // Use fallback
        let result = try await breaker.execute({
            return "primary"
        }, fallback: {
            return "fallback"
        })

        XCTAssertEqual(result, "fallback")
    }

    // MARK: - Retry Engine Tests

    func testRetryEngineSucceedsFirstAttempt() async throws {
        var attemptCount = 0

        let result = try await RetryEngine.execute(
            configuration: .init(maxAttempts: 3, initialDelay: 0.01)
        ) {
            attemptCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 1)
    }

    func testRetryEngineRetriesOnFailure() async throws {
        var attemptCount = 0

        let result = try await RetryEngine.execute(
            configuration: .init(maxAttempts: 3, initialDelay: 0.01)
        ) {
            attemptCount += 1
            if attemptCount < 3 {
                throw TestError.simulated
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 3)
    }

    func testRetryEngineExhaustsAttempts() async {
        var attemptCount = 0

        do {
            _ = try await RetryEngine.execute(
                configuration: .init(maxAttempts: 3, initialDelay: 0.01)
            ) {
                attemptCount += 1
                throw TestError.simulated
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(attemptCount, 3)
        }
    }

    func testRetryEngineWithFallback() async throws {
        let result = try await RetryEngine.execute(
            configuration: .init(maxAttempts: 2, initialDelay: 0.01),
            operation: {
                throw TestError.simulated
            },
            fallback: {
                return "fallback"
            }
        )

        XCTAssertEqual(result, "fallback")
    }

    // MARK: - Fallback Chain Tests

    func testFallbackChainFirstStrategySucceeds() async throws {
        var chain = FallbackChain<String>(name: "test")
        chain.add { "first" }
        chain.add { "second" }
        chain.add { "third" }

        let result = try await chain.execute()
        XCTAssertEqual(result, "first")
    }

    func testFallbackChainUsesSecondStrategy() async throws {
        var chain = FallbackChain<String>(name: "test")
        chain.add { throw TestError.simulated }
        chain.add { "second" }
        chain.add { "third" }

        let result = try await chain.execute()
        XCTAssertEqual(result, "second")
    }

    func testFallbackChainUsesDefault() async {
        var chain = FallbackChain<String>(name: "test")
        chain.add { throw TestError.simulated }
        chain.add { throw TestError.simulated }

        let result = await chain.execute(default: "default")
        XCTAssertEqual(result, "default")
    }

    // MARK: - Safe Wrapper Tests

    func testSafelyWithSuccess() {
        let result = safely(default: "default", context: "test") {
            return "success"
        }
        XCTAssertEqual(result, "success")
    }

    func testSafelyWithError() {
        let result = safely(default: "default", context: "test") {
            throw TestError.simulated
        }
        XCTAssertEqual(result, "default")
    }

    func testSafelyOptionalWithSuccess() {
        let result: String? = safelyOptional(context: "test") {
            return "success"
        }
        XCTAssertEqual(result, "success")
    }

    func testSafelyOptionalWithError() {
        let result: String? = safelyOptional(context: "test") {
            throw TestError.simulated
        }
        XCTAssertNil(result)
    }

    // MARK: - Defensive Guard Tests

    func testDefensiveGuardPass() {
        let result = defensiveGuard(true, message: "Should pass")
        XCTAssertTrue(result)
    }

    func testDefensiveGuardFail() {
        let result = defensiveGuard(false, message: "Should fail")
        XCTAssertFalse(result)
    }

    // MARK: - Self-Healing Component Tests

    func testSelfHealingComponentCreation() async throws {
        let component = SelfHealingComponent<String>(
            name: "test",
            factory: { "created" },
            healthCheck: { _ in true }
        )

        let result = try await component.get()
        XCTAssertEqual(result, "created")
    }

    func testSelfHealingComponentReusesHealthy() async throws {
        var creationCount = 0

        let component = SelfHealingComponent<String>(
            name: "test",
            factory: {
                creationCount += 1
                return "created-\(creationCount)"
            },
            healthCheck: { _ in true }
        )

        let first = try await component.get()
        let second = try await component.get()

        XCTAssertEqual(first, second)
        XCTAssertEqual(creationCount, 1)
    }

    func testSelfHealingComponentHealsUnhealthy() async throws {
        var creationCount = 0
        var healthCheckCount = 0

        let component = SelfHealingComponent<String>(
            name: "test",
            factory: {
                creationCount += 1
                return "created-\(creationCount)"
            },
            healthCheck: { _ in
                healthCheckCount += 1
                return healthCheckCount > 1 // First check fails, subsequent pass
            }
        )

        let first = try await component.get()
        XCTAssertEqual(first, "created-1")

        // This should trigger healing because health check fails
        let second = try await component.get()
        XCTAssertEqual(second, "created-2")
        XCTAssertEqual(creationCount, 2)
    }

    // MARK: - Feature Flags Tests

    @MainActor
    func testFeatureFlagsDefaultEnabled() {
        let flags = FeatureFlags.shared
        XCTAssertTrue(flags.audioPlaybackEnabled)
        XCTAssertTrue(flags.midiEnabled)
        XCTAssertTrue(flags.spatialAudioEnabled)
    }

    @MainActor
    func testEmergencyModeDisablesNonEssential() {
        let flags = FeatureFlags.shared
        flags.restoreAllFeatures()

        flags.enterEmergencyMode()

        XCTAssertTrue(flags.audioPlaybackEnabled) // Essential stays on
        XCTAssertTrue(flags.midiEnabled) // Essential stays on
        XCTAssertFalse(flags.spatialAudioEnabled) // Non-essential disabled
        XCTAssertFalse(flags.visualizationsEnabled)
        XCTAssertFalse(flags.biofeedbackEnabled)
        XCTAssertFalse(flags.ledControlEnabled)

        // Cleanup
        flags.restoreAllFeatures()
    }

    // MARK: - Health Status Tests

    func testHealthStatusCreation() {
        let healthy = HealthStatus.healthy("All good")
        XCTAssertTrue(healthy.isHealthy)
        XCTAssertEqual(healthy.message, "All good")

        let unhealthy = HealthStatus.unhealthy("Problem detected")
        XCTAssertFalse(unhealthy.isHealthy)
        XCTAssertEqual(unhealthy.message, "Problem detected")
    }
}

// MARK: - Performance Tests

extension StressResistanceTests {

    func testSafelyPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = safely(default: 0) { 42 }
            }
        }
    }

    func testDefensiveGuardPerformance() {
        measure {
            for _ in 0..<100000 {
                _ = defensiveGuard(true, message: "test")
            }
        }
    }
}

// MARK: - Test Helpers

enum TestError: Error {
    case simulated
}

extension CircuitBreaker.State: Equatable {
    public static func == (lhs: CircuitBreaker.State, rhs: CircuitBreaker.State) -> Bool {
        switch (lhs, rhs) {
        case (.closed, .closed), (.open, .open), (.halfOpen, .halfOpen):
            return true
        default:
            return false
        }
    }
}
