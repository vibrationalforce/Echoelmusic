//
// IntegrationTestBase.swift
// Echoelmusic
//
// Base class for integration tests with common utilities
//

import XCTest
import AVFoundation
import HealthKit
@testable import Echoelmusic

/// Base class for integration tests providing common setup and utilities
class IntegrationTestBase: XCTestCase {

    // MARK: - Properties

    var audioEngine: AudioEngine!
    var healthKitManager: HealthKitManager!
    var recordingEngine: RecordingEngine!
    var testTimeout: TimeInterval = 30.0

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Initialize core components
        audioEngine = AudioEngine()
        healthKitManager = HealthKitManager()
        recordingEngine = RecordingEngine()

        // Configure for testing
        configureForTesting()
    }

    override func tearDownWithError() throws {
        // Clean up resources
        stopAllAudio()
        cleanupTestFiles()

        audioEngine = nil
        healthKitManager = nil
        recordingEngine = nil

        try super.tearDownWithError()
    }

    // MARK: - Test Configuration

    func configureForTesting() {
        // Reduce buffer sizes for faster tests
        audioEngine.bufferSize = 256

        // Disable real HealthKit queries in tests
        healthKitManager.isTestMode = true

        // Use temporary directory for recordings
        recordingEngine.outputDirectory = FileManager.default.temporaryDirectory
    }

    // MARK: - Audio Utilities

    /// Generate test audio buffer with sine wave
    func generateTestBuffer(
        frequency: Float = 440.0,
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100.0
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            XCTFail("Failed to create test buffer")
            fatalError()
        }

        buffer.frameLength = frameCount

        // Generate stereo sine wave
        let leftChannel = buffer.floatChannelData![0]
        let rightChannel = buffer.floatChannelData![1]

        let angularFrequency = 2.0 * Float.pi * frequency / Float(sampleRate)

        for frame in 0..<Int(frameCount) {
            let value = sin(angularFrequency * Float(frame))
            leftChannel[frame] = value
            rightChannel[frame] = value
        }

        return buffer
    }

    /// Verify audio buffer contains valid audio data
    func verifyBufferValid(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard buffer.frameLength > 0 else { return false }

        let leftChannel = buffer.floatChannelData![0]
        var hasNonZero = false
        var hasFinite = true

        for frame in 0..<Int(buffer.frameLength) {
            let value = leftChannel[frame]

            if value != 0.0 {
                hasNonZero = true
            }

            if !value.isFinite {
                hasFinite = false
                break
            }
        }

        return hasNonZero && hasFinite
    }

    /// Calculate RMS level of audio buffer
    func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.frameLength > 0 else { return 0.0 }

        let leftChannel = buffer.floatChannelData![0]
        var sumSquares: Float = 0.0

        for frame in 0..<Int(buffer.frameLength) {
            let value = leftChannel[frame]
            sumSquares += value * value
        }

        let meanSquare = sumSquares / Float(buffer.frameLength)
        return sqrt(meanSquare)
    }

    func stopAllAudio() {
        audioEngine.stop()
        recordingEngine.stopRecording()
    }

    // MARK: - HealthKit Utilities

    /// Create mock heart rate sample for testing
    func createMockHeartRateSample(
        bpm: Double,
        date: Date = Date()
    ) -> HKQuantitySample {
        let heartRateType = HKQuantityType.quantityType(
            forIdentifier: .heartRate
        )!

        let quantity = HKQuantity(
            unit: HKUnit.count().unitDivided(by: .minute()),
            doubleValue: bpm
        )

        return HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: date,
            end: date
        )
    }

    /// Inject mock heart rate data for testing
    func injectMockHeartRate(_ bpm: Double) {
        let sample = createMockHeartRateSample(bpm: bpm)
        healthKitManager.injectTestSample(sample)
    }

    // MARK: - File System Utilities

    /// Get temporary test file URL
    func temporaryTestFileURL(filename: String) -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoelmusicTests")
            .appendingPathComponent(filename)
    }

    /// Create test directory if needed
    func createTestDirectory() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoelmusicTests")

        try FileManager.default.createDirectory(
            at: testDir,
            withIntermediateDirectories: true
        )
    }

    /// Clean up test files
    func cleanupTestFiles() {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoelmusicTests")

        try? FileManager.default.removeItem(at: testDir)
    }

    /// Verify file exists and has content
    func verifyFileValid(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path
        ) else {
            return false
        }

        let fileSize = attributes[.size] as? Int64 ?? 0
        return fileSize > 0
    }

    // MARK: - Async Utilities

    /// Wait for async condition with timeout
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool
    ) -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return false
    }

    /// Wait for async completion with expectation
    func waitForCompletion(
        timeout: TimeInterval = 5.0,
        description: String = "Async operation",
        block: @escaping (@escaping () -> Void) -> Void
    ) {
        let expectation = self.expectation(description: description)

        block {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    // MARK: - Assertion Helpers

    /// Assert audio level is within expected range
    func assertAudioLevel(
        _ level: Float,
        inRange range: ClosedRange<Float>,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            range.contains(level),
            "Audio level \(level) not in expected range \(range)",
            file: file,
            line: line
        )
    }

    /// Assert heart rate is valid
    func assertValidHeartRate(
        _ bpm: Double,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            bpm >= 40.0 && bpm <= 220.0,
            "Heart rate \(bpm) BPM is out of valid range",
            file: file,
            line: line
        )
    }

    /// Assert buffer processing did not introduce artifacts
    func assertNoAudioArtifacts(
        _ buffer: AVAudioPCMBuffer,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let leftChannel = buffer.floatChannelData![0]

        // Check for NaN, Inf, or extreme values
        for frame in 0..<Int(buffer.frameLength) {
            let value = leftChannel[frame]

            XCTAssertTrue(
                value.isFinite,
                "Buffer contains non-finite value at frame \(frame)",
                file: file,
                line: line
            )

            XCTAssertTrue(
                abs(value) <= 10.0,
                "Buffer contains extreme value \(value) at frame \(frame)",
                file: file,
                line: line
            )
        }
    }
}

// MARK: - Test Extensions

extension AudioEngine {
    var isTestMode: Bool {
        get { return false } // Default implementation
        set { }
    }
}

extension HealthKitManager {
    var isTestMode: Bool {
        get { return false }
        set { }
    }

    func injectTestSample(_ sample: HKQuantitySample) {
        // Test implementation - override in real HealthKitManager
    }
}

extension RecordingEngine {
    var outputDirectory: URL {
        get { return FileManager.default.temporaryDirectory }
        set { }
    }
}
