//
// RecordingIntegrationTests.swift
// Echoelmusic
//
// Recording → Export → Playback integration tests
// Validates: Record → Process → Export → Verify → Playback
//

import XCTest
import AVFoundation
@testable import Echoelmusic

class RecordingIntegrationTests: IntegrationTestBase {

    // MARK: - Recording Pipeline Tests

    func testRecordExportPlaybackFlow() throws {
        // Test complete recording flow: record → process → export → playback

        try createTestDirectory()

        // 1. Start recording
        let outputURL = temporaryTestFileURL(filename: "test_recording.m4a")

        try recordingEngine.startRecording(outputURL: outputURL)
        XCTAssertTrue(recordingEngine.isRecording, "Recording did not start")

        // 2. Feed audio data (simulate microphone input)
        let recordDuration: TimeInterval = 2.0
        let bufferDuration: TimeInterval = 0.1

        let bufferCount = Int(recordDuration / bufferDuration)

        for i in 0..<bufferCount {
            let frequency: Float = 440.0 + Float(i * 5)
            let buffer = generateTestBuffer(
                frequency: frequency,
                duration: bufferDuration
            )

            recordingEngine.appendBuffer(buffer)

            Thread.sleep(forTimeInterval: bufferDuration)
        }

        // 3. Stop recording
        let expectation = self.expectation(description: "Recording stopped")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Stop recording failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // 4. Verify file was created and is valid
        XCTAssertTrue(
            verifyFileValid(at: outputURL),
            "Recording file not created or empty"
        )

        // 5. Verify file duration
        let asset = AVURLAsset(url: outputURL)
        let duration = asset.duration.seconds

        XCTAssertEqual(
            duration,
            recordDuration,
            accuracy: 0.5,
            "Recording duration incorrect"
        )

        // 6. Load and verify audio data
        guard let file = try? AVAudioFile(forReading: outputURL) else {
            XCTFail("Could not read recorded file")
            return
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: frameCount
        ) else {
            XCTFail("Could not create playback buffer")
            return
        }

        try file.read(into: buffer)
        buffer.frameLength = frameCount

        // 7. Verify audio quality
        XCTAssertTrue(verifyBufferValid(buffer), "Recorded audio invalid")
        assertNoAudioArtifacts(buffer)
    }

    func testRecordingWithBioReactiveProcessing() throws {
        // Test recording captures bio-reactive modulation

        try createTestDirectory()

        let outputURL = temporaryTestFileURL(filename: "bio_recording.m4a")

        // Enable bio-reactive processing
        audioEngine.enableBioReactiveProcessing(true)
        injectMockHeartRate(80.0)

        try recordingEngine.startRecording(outputURL: outputURL)

        // Record with varying heart rates
        let heartRates: [Double] = [60, 80, 100, 120]

        for bpm in heartRates {
            injectMockHeartRate(bpm)

            let buffer = generateTestBuffer(
                frequency: 440.0,
                duration: 0.5
            )

            // Process through bio-reactive pipeline
            var processedBuffer: AVAudioPCMBuffer?

            waitForCompletion(description: "Process buffer") { completion in
                self.audioEngine.processBuffer(buffer) { result in
                    if case .success(let processed) = result {
                        processedBuffer = processed
                    }
                    completion()
                }
            }

            if let processed = processedBuffer {
                recordingEngine.appendBuffer(processed)
            }

            Thread.sleep(forTimeInterval: 0.5)
        }

        let expectation = self.expectation(description: "Stop recording")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Stop recording failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // Verify recording exists and is valid
        XCTAssertTrue(verifyFileValid(at: outputURL), "Recording file invalid")
    }

    func testExportFormats() throws {
        // Test exporting to different audio formats

        try createTestDirectory()

        let formats: [(String, AudioFormatID)] = [
            ("test_export.m4a", kAudioFormatMPEG4AAC),
            ("test_export.wav", kAudioFormatLinearPCM),
            ("test_export.aif", kAudioFormatLinearPCM),
        ]

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 1.0)

        for (filename, formatID) in formats {
            let outputURL = temporaryTestFileURL(filename: filename)

            // Export to format
            let expectation = self.expectation(
                description: "Export \(filename)"
            )

            recordingEngine.exportBuffer(
                testBuffer,
                to: outputURL,
                format: formatID
            ) { result in
                XCTAssertTrue(
                    result.isSuccess,
                    "Export to \(filename) failed"
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: testTimeout)

            // Verify file was created
            XCTAssertTrue(
                verifyFileValid(at: outputURL),
                "Exported file \(filename) invalid"
            )

            // Verify can be read back
            XCTAssertNoThrow(
                try AVAudioFile(forReading: outputURL),
                "Cannot read \(filename)"
            )
        }
    }

    func testRecordingQualitySettings() throws {
        // Test different recording quality settings

        try createTestDirectory()

        let qualities: [(String, RecordingQuality)] = [
            ("low_quality.m4a", .low),
            ("medium_quality.m4a", .medium),
            ("high_quality.m4a", .high),
        ]

        for (filename, quality) in qualities {
            let outputURL = temporaryTestFileURL(filename: filename)

            recordingEngine.setQuality(quality)

            try recordingEngine.startRecording(outputURL: outputURL)

            let buffer = generateTestBuffer(frequency: 440.0, duration: 1.0)
            recordingEngine.appendBuffer(buffer)

            let expectation = self.expectation(
                description: "Stop \(quality) recording"
            )

            recordingEngine.stopRecording { result in
                XCTAssertTrue(result.isSuccess, "Recording failed")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: testTimeout)

            // Verify file exists
            XCTAssertTrue(
                verifyFileValid(at: outputURL),
                "\(quality) recording invalid"
            )
        }

        // Verify high quality produces larger file than low quality
        let lowURL = temporaryTestFileURL(filename: "low_quality.m4a")
        let highURL = temporaryTestFileURL(filename: "high_quality.m4a")

        let lowSize = try FileManager.default.attributesOfItem(
            atPath: lowURL.path
        )[.size] as? Int64 ?? 0

        let highSize = try FileManager.default.attributesOfItem(
            atPath: highURL.path
        )[.size] as? Int64 ?? 0

        XCTAssertGreaterThan(
            highSize,
            lowSize,
            "High quality not larger than low quality"
        )
    }

    func testRecordingPauseResume() throws {
        // Test pausing and resuming recording

        try createTestDirectory()

        let outputURL = temporaryTestFileURL(filename: "pause_resume.m4a")

        try recordingEngine.startRecording(outputURL: outputURL)

        // Record for 1 second
        let buffer1 = generateTestBuffer(frequency: 440.0, duration: 1.0)
        recordingEngine.appendBuffer(buffer1)
        Thread.sleep(forTimeInterval: 1.0)

        // Pause
        recordingEngine.pauseRecording()
        XCTAssertTrue(recordingEngine.isPaused, "Recording not paused")

        // Wait during pause (should not be recorded)
        Thread.sleep(forTimeInterval: 0.5)

        // Resume
        recordingEngine.resumeRecording()
        XCTAssertFalse(recordingEngine.isPaused, "Recording not resumed")

        // Record for another second
        let buffer2 = generateTestBuffer(frequency: 880.0, duration: 1.0)
        recordingEngine.appendBuffer(buffer2)
        Thread.sleep(forTimeInterval: 1.0)

        let expectation = self.expectation(description: "Stop recording")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Stop recording failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // Verify total duration (should be ~2 seconds, not 2.5)
        let asset = AVURLAsset(url: outputURL)
        let duration = asset.duration.seconds

        XCTAssertEqual(
            duration,
            2.0,
            accuracy: 0.3,
            "Pause/resume affected duration incorrectly"
        )
    }

    func testConcurrentRecordings() throws {
        // Test multiple recordings can't happen simultaneously

        try createTestDirectory()

        let url1 = temporaryTestFileURL(filename: "recording1.m4a")
        let url2 = temporaryTestFileURL(filename: "recording2.m4a")

        // Start first recording
        try recordingEngine.startRecording(outputURL: url1)
        XCTAssertTrue(recordingEngine.isRecording, "First recording not started")

        // Attempt second recording (should fail)
        XCTAssertThrowsError(
            try recordingEngine.startRecording(outputURL: url2),
            "Second recording should fail"
        )

        // Stop first recording
        let expectation = self.expectation(description: "Stop recording")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Stop failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // Now second recording should succeed
        XCTAssertNoThrow(
            try recordingEngine.startRecording(outputURL: url2),
            "Second recording should succeed after first stopped"
        )

        recordingEngine.stopRecording { _ in }
    }

    func testRecordingMetadata() throws {
        // Test metadata is embedded in exported files

        try createTestDirectory()

        let outputURL = temporaryTestFileURL(filename: "metadata_test.m4a")

        // Set metadata
        recordingEngine.setMetadata([
            "artist": "Echoelmusic User",
            "album": "Bio-Reactive Session",
            "title": "Test Recording",
            "date": Date().description,
        ])

        try recordingEngine.startRecording(outputURL: outputURL)

        let buffer = generateTestBuffer(frequency: 440.0, duration: 1.0)
        recordingEngine.appendBuffer(buffer)

        let expectation = self.expectation(description: "Stop recording")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Recording failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // Verify metadata is embedded
        let asset = AVURLAsset(url: outputURL)
        let metadata = asset.commonMetadata

        let hasTitle = metadata.contains {
            $0.commonKey == .commonKeyTitle
        }

        XCTAssertTrue(hasTitle, "Metadata not embedded")
    }

    func testRecordingBufferOverflow() throws {
        // Test handling of buffer overflow (too much data)

        try createTestDirectory()

        let outputURL = temporaryTestFileURL(filename: "overflow_test.m4a")

        try recordingEngine.startRecording(outputURL: outputURL)

        // Generate many buffers very quickly
        for _ in 0..<100 {
            let buffer = generateTestBuffer(
                frequency: 440.0,
                duration: 0.01
            )

            recordingEngine.appendBuffer(buffer)
        }

        // Should not crash or hang
        XCTAssertTrue(recordingEngine.isRecording, "Recording stopped unexpectedly")

        let expectation = self.expectation(description: "Stop recording")

        recordingEngine.stopRecording { result in
            XCTAssertTrue(result.isSuccess, "Recording failed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: testTimeout)

        // Verify file is valid
        XCTAssertTrue(verifyFileValid(at: outputURL), "Recording file invalid")
    }
}

// MARK: - RecordingEngine Extensions

extension RecordingEngine {
    var isRecording: Bool {
        return false // Test implementation
    }

    var isPaused: Bool {
        return false // Test implementation
    }

    func startRecording(outputURL: URL) throws {
        // Test implementation
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        // Test implementation
    }

    func pauseRecording() {
        // Test implementation
    }

    func resumeRecording() {
        // Test implementation
    }

    func stopRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        // Test implementation
        completion(.success(()))
    }

    func exportBuffer(
        _ buffer: AVAudioPCMBuffer,
        to url: URL,
        format: AudioFormatID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Test implementation
        completion(.success(()))
    }

    func setQuality(_ quality: RecordingQuality) {
        // Test implementation
    }

    func setMetadata(_ metadata: [String: String]) {
        // Test implementation
    }
}

enum RecordingQuality {
    case low
    case medium
    case high
}
