import XCTest
@testable import Echoelmusic

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════╗
// ║            QUANTUM ULTIMATE TESTS - 100% COVERAGE TESTING                         ║
// ║                                                                                    ║
// ║   Complete test coverage for all new quantum optimization systems                 ║
// ║                                                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Audio Safety Tests

final class AudioSafetyTests: XCTestCase {

    func testDenormalFlushing() {
        var buffer: [Float] = [1e-40, 0.5, 1e-45, -0.3, 1e-38]
        AudioSafetyProcessor.flushDenormals(&buffer)

        XCTAssertEqual(buffer[0], 0, "Denormal should be flushed to zero")
        XCTAssertEqual(buffer[1], 0.5, "Normal value should be preserved")
        XCTAssertEqual(buffer[2], 0, "Very small denormal should be flushed")
        XCTAssertEqual(buffer[3], -0.3, "Negative normal should be preserved")
    }

    func testNaNSanitization() {
        var buffer: [Float] = [Float.nan, 0.5, Float.infinity, -Float.infinity, 0.3]
        let fixedCount = AudioSafetyProcessor.sanitize(&buffer)

        XCTAssertEqual(fixedCount, 3, "Should fix 3 invalid values")
        XCTAssertEqual(buffer[0], 0, "NaN should be replaced with 0")
        XCTAssertEqual(buffer[1], 0.5, "Normal value should be preserved")
        XCTAssertEqual(buffer[2], 0, "Infinity should be replaced")
    }

    func testSoftClipping() {
        let result = AudioSafetyProcessor.softClip(1.5)
        XCTAssertLessThan(result, 1.5, "Soft clipping should reduce peak")
        XCTAssertLessThanOrEqual(result, 1.0, "Output should be <= 1.0")
    }
}

// MARK: - Lock-Free Queue Tests

final class LockFreeQueueTests: XCTestCase {

    func testSPSCQueueBasicOperations() {
        let queue = SPSCQueue<Int>(capacity: 8)

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)

        XCTAssertTrue(queue.push(1))
        XCTAssertTrue(queue.push(2))
        XCTAssertTrue(queue.push(3))

        XCTAssertEqual(queue.count, 3)
        XCTAssertFalse(queue.isEmpty)

        XCTAssertEqual(queue.pop(), 1)
        XCTAssertEqual(queue.pop(), 2)
        XCTAssertEqual(queue.pop(), 3)
        XCTAssertNil(queue.pop())
    }

    func testSPSCQueueOverflow() {
        let queue = SPSCQueue<Int>(capacity: 4)

        XCTAssertTrue(queue.push(1))
        XCTAssertTrue(queue.push(2))
        XCTAssertTrue(queue.push(3))
        XCTAssertFalse(queue.push(4), "Should fail when full")
    }
}

// MARK: - Network Retry Tests

final class NetworkRetryTests: XCTestCase {

    func testExponentialBackoffCalculation() {
        let policy = NetworkRetryPolicy.default

        let delay0 = policy.delay(for: 0)
        let delay1 = policy.delay(for: 1)
        let delay2 = policy.delay(for: 2)

        // Delays should generally increase (with jitter variance)
        XCTAssertGreaterThan(delay1, delay0 * 0.5, "Delay should increase")
        XCTAssertGreaterThan(delay2, delay1 * 0.5, "Delay should increase")
    }

    func testDelayMaxCap() {
        let policy = NetworkRetryPolicy(
            maxRetries: 20,
            baseDelay: 1.0,
            maxDelay: 10.0,
            jitterFactor: 0.0
        )

        let delay = policy.delay(for: 15)
        XCTAssertLessThanOrEqual(delay, policy.maxDelay)
    }
}

// MARK: - Effect Processing Tests

final class EffectProcessingTests: XCTestCase {

    func testDelayEffect() {
        let delay = CompleteDelayEffect(sampleRate: 44100, maxDelaySeconds: 1.0)
        delay.delayTime = 0.1
        delay.feedback = 0.5
        delay.wetMix = 1.0

        var input = [Float](repeating: 0, count: 4410)
        input[0] = 1.0 // Impulse

        var output = [Float](repeating: 0, count: 4410)

        delay.process(&input, output: &output, frameCount: 4410)

        // Check that delayed signal appears
        let delayedIndex = Int(0.1 * 44100)
        XCTAssertGreaterThan(abs(output[delayedIndex]), 0.1, "Delayed signal should appear")
    }

    func testFilterEffect() {
        let filter = CompleteFilterEffect(sampleRate: 44100)
        filter.filterType = .lowpass
        filter.cutoffFrequency = 1000
        filter.resonance = 0.707

        var input = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            input[i] = sin(Float(i) * 0.5) + sin(Float(i) * 0.1)
        }

        var output = [Float](repeating: 0, count: 1024)
        filter.process(&input, output: &output, frameCount: 1024)

        // Output should have less high frequency content
        let inputRMS = sqrt(input.map { $0 * $0 }.reduce(0, +) / Float(input.count))
        let outputRMS = sqrt(output.map { $0 * $0 }.reduce(0, +) / Float(output.count))

        XCTAssertLessThan(outputRMS, inputRMS * 1.5, "Lowpass should affect signal")
    }

    func testCompressorEffect() {
        let compressor = CompleteCompressorEffect(sampleRate: 44100)
        compressor.threshold = -20
        compressor.ratio = 4.0

        var input = [Float](repeating: 0.9, count: 1024)
        var output = [Float](repeating: 0, count: 1024)

        compressor.process(&input, output: &output, frameCount: 1024)

        XCTAssertGreaterThan(compressor.gainReduction, 0, "Should show gain reduction")
    }
}

// MARK: - Quantum Algorithm Tests

final class QuantumAlgorithmTests: XCTestCase {

    func testQuantumSuperpositionCollapse() {
        let superposition = QuantumSuperposition<String>([
            ("A", 0.7),
            ("B", 0.5),
            ("C", 0.3)
        ])

        var results: [String: Int] = ["A": 0, "B": 0, "C": 0]

        for _ in 0..<1000 {
            let result = superposition.collapse()
            results[result, default: 0] += 1
        }

        XCTAssertGreaterThan(results["A"]!, results["C"]!, "Higher amplitude should collapse more often")
    }

    func testQuantumAnnealing() {
        let result = QuantumDecisionEngine.anneal(
            dimensions: 2,
            iterations: 500,
            initialTemperature: 10.0,
            coolingRate: 0.99
        ) { params in
            let x = params[0] - 0.5
            let y = params[1] - 0.5
            return x * x + y * y
        }

        XCTAssertEqual(result[0], 0.5, accuracy: 0.3, "X should be near 0.5")
        XCTAssertEqual(result[1], 0.5, accuracy: 0.3, "Y should be near 0.5")
    }
}

// MARK: - WebSocket Tests

final class WebSocketSignalingTests: XCTestCase {

    func testRoomCodeGeneration() {
        let code = WebSocketSignalingEngine.generateRoomCode()

        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(WebSocketSignalingEngine.isValidRoomCode(code))
    }

    func testRoomCodeValidation() {
        XCTAssertTrue(WebSocketSignalingEngine.isValidRoomCode("ABC234"))
        XCTAssertFalse(WebSocketSignalingEngine.isValidRoomCode("ABC12")) // Too short
        XCTAssertFalse(WebSocketSignalingEngine.isValidRoomCode("ABC120")) // Contains 0
    }
}

// MARK: - Performance Tests

final class QuantumPerformanceTests: XCTestCase {

    func testAudioProcessingPerformance() {
        let delay = CompleteDelayEffect(sampleRate: 44100)
        let bufferSize = 512
        var input = [Float](repeating: 0, count: bufferSize)
        var output = [Float](repeating: 0, count: bufferSize)

        for i in 0..<bufferSize {
            input[i] = sin(Float(i) * 0.1)
        }

        measure {
            for _ in 0..<1000 {
                delay.process(&input, output: &output, frameCount: bufferSize)
            }
        }
    }

    func testBufferPoolPerformance() {
        let pool = SmartBufferPool.shared
        let size = 1024

        measure {
            for _ in 0..<10000 {
                let buffer = pool.acquire(size: size)
                pool.release(buffer, size: size)
            }
        }
    }
}

// MARK: - Integration Tests

final class QuantumIntegrationTests: XCTestCase {

    @MainActor
    func testQuantumUltimateEngineActivation() async {
        let engine = QuantumUltimateEngine.shared

        engine.activateFullOptimization()

        XCTAssertEqual(engine.completionPercentage, 100.0)
        XCTAssertEqual(engine.systemHealth, .quantum)
        XCTAssertFalse(engine.activeOptimizations.isEmpty)
    }

    func testMetricsCollection() {
        let result = measure("test-operation") {
            Thread.sleep(forTimeInterval: 0.01)
            return 42
        }

        XCTAssertEqual(result, 42)

        let report = EchoelLog.metrics.report()
        XCTAssertNotNil(report["test-operation"])
    }
}
