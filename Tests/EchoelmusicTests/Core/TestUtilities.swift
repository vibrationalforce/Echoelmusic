//
//  TestUtilities.swift
//  EchoelmusicTests
//
//  Created: 2025-11-28
//  Comprehensive Test Utilities & Mock Infrastructure
//
//  Features:
//  - Async test helpers
//  - Mock objects for DI
//  - Test fixtures
//  - Performance measurement
//  - Audio buffer generation
//

import XCTest
import Combine
@testable import Echoelmusic

// MARK: - Async Test Helpers

/// Wait for async operation with timeout
public func waitAsync<T>(
    timeout: TimeInterval = 5.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TestError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// Wait for published value
public func waitForPublished<T>(
    publisher: some Publisher<T, Never>,
    timeout: TimeInterval = 5.0,
    where predicate: @escaping (T) -> Bool
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        var cancellable: AnyCancellable?

        let timeoutWork = DispatchWorkItem {
            cancellable?.cancel()
            continuation.resume(throwing: TestError.timeout)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        cancellable = publisher.sink { value in
            if predicate(value) {
                timeoutWork.cancel()
                cancellable?.cancel()
                continuation.resume(returning: value)
            }
        }
    }
}

// MARK: - Test Errors

public enum TestError: Error {
    case timeout
    case invalidSetup(String)
    case assertionFailed(String)
    case mockNotConfigured(String)
}

// MARK: - Test Fixture

/// Base class for test fixtures with common setup/teardown
open class TestFixture {
    public var cancellables = Set<AnyCancellable>()

    public init() {}

    open func setUp() {
        cancellables.removeAll()
    }

    open func tearDown() {
        cancellables.removeAll()
    }
}

// MARK: - Mock Audio Engine

/// Mock audio engine for testing
public final class MockAudioEngine: AudioEngineProtocol {
    public var isRunning: Bool = false
    public var startCallCount = 0
    public var stopCallCount = 0
    public var connectedHealthKit: HealthKitManagerProtocol?

    public var shouldThrowOnStart = false
    public var startError: Error?

    public init() {}

    public func start() throws {
        startCallCount += 1
        if shouldThrowOnStart, let error = startError {
            throw error
        }
        isRunning = true
    }

    public func stop() {
        stopCallCount += 1
        isRunning = false
    }

    public func connectHealthKit(_ manager: HealthKitManagerProtocol) {
        connectedHealthKit = manager
    }

    public func reset() {
        isRunning = false
        startCallCount = 0
        stopCallCount = 0
        connectedHealthKit = nil
        shouldThrowOnStart = false
        startError = nil
    }
}

// MARK: - Mock Microphone Manager

public final class MockMicrophoneManager: MicrophoneManagerProtocol {
    public var isRecording: Bool = false
    public var audioLevel: Float = 0
    public var startCallCount = 0
    public var stopCallCount = 0

    public var shouldThrowOnStart = false
    public var simulatedAudioLevels: [Float] = []
    private var levelIndex = 0

    public init() {}

    public func startRecording() throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw AudioError.permissionDenied
        }
        isRecording = true
    }

    public func stopRecording() {
        stopCallCount += 1
        isRecording = false
    }

    public func simulateNextLevel() -> Float {
        guard !simulatedAudioLevels.isEmpty else { return 0 }
        let level = simulatedAudioLevels[levelIndex % simulatedAudioLevels.count]
        levelIndex += 1
        audioLevel = level
        return level
    }

    public func reset() {
        isRecording = false
        audioLevel = 0
        startCallCount = 0
        stopCallCount = 0
        shouldThrowOnStart = false
        simulatedAudioLevels = []
        levelIndex = 0
    }
}

// MARK: - Mock HealthKit Manager

public final class MockHealthKitManager: HealthKitManagerProtocol {
    public var hrvCoherence: Double = 0
    public var heartRate: Double = 0
    public var isMonitoring: Bool = false

    public var authorizationCallCount = 0
    public var startMonitoringCallCount = 0
    public var stopMonitoringCallCount = 0

    public var shouldThrowOnAuthorization = false
    public var shouldThrowOnStart = false

    public var simulatedHRVValues: [Double] = []
    public var simulatedHeartRates: [Double] = []
    private var valueIndex = 0

    public init() {}

    public func requestAuthorization() async throws {
        authorizationCallCount += 1
        if shouldThrowOnAuthorization {
            throw BiofeedbackError.authorizationDenied
        }
    }

    public func startMonitoring() async throws {
        startMonitoringCallCount += 1
        if shouldThrowOnStart {
            throw BiofeedbackError.sensorNotConnected
        }
        isMonitoring = true
    }

    public func stopMonitoring() {
        stopMonitoringCallCount += 1
        isMonitoring = false
    }

    public func simulateNextReading() {
        if !simulatedHRVValues.isEmpty {
            hrvCoherence = simulatedHRVValues[valueIndex % simulatedHRVValues.count]
        }
        if !simulatedHeartRates.isEmpty {
            heartRate = simulatedHeartRates[valueIndex % simulatedHeartRates.count]
        }
        valueIndex += 1
    }

    public func reset() {
        hrvCoherence = 0
        heartRate = 0
        isMonitoring = false
        authorizationCallCount = 0
        startMonitoringCallCount = 0
        stopMonitoringCallCount = 0
        shouldThrowOnAuthorization = false
        shouldThrowOnStart = false
        simulatedHRVValues = []
        simulatedHeartRates = []
        valueIndex = 0
    }
}

// MARK: - Mock Binaural Beat Generator

public final class MockBinauralBeatGenerator: BinauralBeatGeneratorProtocol {
    public var isPlaying: Bool = false
    public var effectiveBeatFrequency: Float = 10.0

    public var configureCallCount = 0
    public var lastCarrier: Float?
    public var lastBeat: Float?
    public var lastAmplitude: Float?

    public init() {}

    public func configure(carrier: Float, beat: Float, amplitude: Float) {
        configureCallCount += 1
        lastCarrier = carrier
        lastBeat = beat
        lastAmplitude = amplitude
        effectiveBeatFrequency = beat
    }

    public func start() {
        isPlaying = true
    }

    public func stop() {
        isPlaying = false
    }

    public func reset() {
        isPlaying = false
        effectiveBeatFrequency = 10.0
        configureCallCount = 0
        lastCarrier = nil
        lastBeat = nil
        lastAmplitude = nil
    }
}

// MARK: - Audio Buffer Generators

/// Generate test audio buffers
public struct AudioBufferGenerator {
    /// Generate sine wave
    public static func sineWave(
        frequency: Float,
        sampleRate: Double,
        duration: TimeInterval,
        amplitude: Float = 1.0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        let phase = 2.0 * Float.pi * frequency / Float(sampleRate)

        return (0..<sampleCount).map { i in
            amplitude * sin(phase * Float(i))
        }
    }

    /// Generate white noise
    public static func whiteNoise(
        sampleRate: Double,
        duration: TimeInterval,
        amplitude: Float = 1.0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { _ in
            amplitude * Float.random(in: -1...1)
        }
    }

    /// Generate silence
    public static func silence(
        sampleRate: Double,
        duration: TimeInterval
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return [Float](repeating: 0, count: sampleCount)
    }

    /// Generate impulse (click)
    public static func impulse(
        sampleRate: Double,
        duration: TimeInterval,
        position: Double = 0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        let impulsePosition = Int(sampleRate * position)

        return (0..<sampleCount).map { i in
            i == impulsePosition ? 1.0 : 0.0
        }
    }

    /// Generate sweep (chirp)
    public static func sweep(
        startFreq: Float,
        endFreq: Float,
        sampleRate: Double,
        duration: TimeInterval,
        amplitude: Float = 1.0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var phase: Float = 0

        return (0..<sampleCount).map { i in
            let t = Float(i) / Float(sampleCount)
            let freq = startFreq + (endFreq - startFreq) * t
            let phaseIncrement = 2.0 * Float.pi * freq / Float(sampleRate)
            phase += phaseIncrement
            return amplitude * sin(phase)
        }
    }
}

// MARK: - Performance Measurement

/// Measure execution time of code blocks
public struct PerformanceMeasurement {
    /// Measure execution time
    public static func measure<T>(
        label: String = "Operation",
        iterations: Int = 1,
        block: () throws -> T
    ) rethrows -> (result: T, averageTime: TimeInterval) {
        var totalTime: TimeInterval = 0
        var result: T!

        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            result = try block()
            let end = CFAbsoluteTimeGetCurrent()
            totalTime += end - start

            if i == 0 {
                print("\(label) - First run: \((end - start) * 1000)ms")
            }
        }

        let average = totalTime / Double(iterations)
        print("\(label) - Average over \(iterations) runs: \(average * 1000)ms")

        return (result, average)
    }

    /// Measure async execution time
    public static func measureAsync<T>(
        label: String = "Operation",
        iterations: Int = 1,
        block: () async throws -> T
    ) async rethrows -> (result: T, averageTime: TimeInterval) {
        var totalTime: TimeInterval = 0
        var result: T!

        for i in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            result = try await block()
            let end = CFAbsoluteTimeGetCurrent()
            totalTime += end - start

            if i == 0 {
                print("\(label) - First run: \((end - start) * 1000)ms")
            }
        }

        let average = totalTime / Double(iterations)
        print("\(label) - Average over \(iterations) runs: \(average * 1000)ms")

        return (result, average)
    }
}

// MARK: - XCTest Extensions

public extension XCTestCase {
    /// Assert array is approximately equal
    func XCTAssertArrayEqual(
        _ actual: [Float],
        _ expected: [Float],
        tolerance: Float,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, "Array lengths differ", file: file, line: line)

        for (i, (a, e)) in zip(actual, expected).enumerated() {
            XCTAssertEqual(a, e, accuracy: tolerance, "Values differ at index \(i)", file: file, line: line)
        }
    }

    /// Assert RMS level of audio
    func XCTAssertRMSLevel(
        _ samples: [Float],
        expectedRMS: Float,
        tolerance: Float,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
        XCTAssertEqual(rms, expectedRMS, accuracy: tolerance, "RMS level differs", file: file, line: line)
    }

    /// Assert peak level of audio
    func XCTAssertPeakLevel(
        _ samples: [Float],
        expectedPeak: Float,
        tolerance: Float,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let peak = samples.map { abs($0) }.max() ?? 0
        XCTAssertEqual(peak, expectedPeak, accuracy: tolerance, "Peak level differs", file: file, line: line)
    }

    /// Assert audio is silent
    func XCTAssertSilent(
        _ samples: [Float],
        threshold: Float = 0.0001,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let peak = samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(peak, threshold, "Audio is not silent", file: file, line: line)
    }

    /// Assert audio is not silent
    func XCTAssertNotSilent(
        _ samples: [Float],
        threshold: Float = 0.0001,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let peak = samples.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(peak, threshold, "Audio is silent", file: file, line: line)
    }

    /// Wait for expectation with async
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        description: String = "Async operation",
        operation: @escaping () async throws -> Void
    ) async throws {
        let expectation = expectation(description: description)

        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: timeout)
    }
}

// MARK: - Test Data Fixtures

/// Common test data fixtures
public struct TestFixtures {
    /// Standard sample rates for testing
    public static let sampleRates: [Double] = [44100, 48000, 96000]

    /// Standard buffer sizes for testing
    public static let bufferSizes: [Int] = [64, 128, 256, 512, 1024, 2048]

    /// Standard test frequencies
    public static let testFrequencies: [Float] = [100, 440, 1000, 5000, 10000]

    /// Biofeedback test HRV values (normal range)
    public static let normalHRVValues: [Double] = [45, 52, 48, 55, 60, 58, 50, 47]

    /// Biofeedback test heart rates (normal range)
    public static let normalHeartRates: [Double] = [65, 68, 70, 72, 75, 73, 71, 69]

    /// Create a temporary test file
    public static func createTempFile(contents: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString
        let fileURL = tempDir.appendingPathComponent(fileName)
        try contents.write(to: fileURL)
        return fileURL
    }

    /// Clean up temporary file
    public static func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
