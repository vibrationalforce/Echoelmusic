//
// AudioPipelineIntegrationTests.swift
// Echoelmusic
//
// End-to-end audio pipeline integration tests
// Validates: Input → Processing → BioReactive Modulation → Output
//

import XCTest
import AVFoundation
@testable import Echoelmusic

class AudioPipelineIntegrationTests: IntegrationTestBase {

    // MARK: - End-to-End Pipeline Tests

    func testEndToEndAudioProcessing() throws {
        // Test complete audio pipeline: input → DSP → output

        // 1. Generate test input
        let inputBuffer = generateTestBuffer(frequency: 440.0, duration: 1.0)
        XCTAssertTrue(verifyBufferValid(inputBuffer), "Input buffer invalid")

        // 2. Start audio engine
        try audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning, "Audio engine failed to start")

        // 3. Process audio through pipeline
        var outputBuffer: AVAudioPCMBuffer?

        let expectation = self.expectation(description: "Audio processed")

        audioEngine.processBuffer(inputBuffer) { result in
            switch result {
            case .success(let buffer):
                outputBuffer = buffer
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Processing failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: testTimeout)

        // 4. Verify output
        guard let output = outputBuffer else {
            XCTFail("No output buffer received")
            return
        }

        XCTAssertTrue(verifyBufferValid(output), "Output buffer invalid")
        assertNoAudioArtifacts(output)

        // 5. Verify audio was processed (not just passed through)
        let inputRMS = calculateRMS(buffer: inputBuffer)
        let outputRMS = calculateRMS(buffer: output)

        // Processing should affect the audio (not exact copy)
        XCTAssertNotEqual(
            inputRMS,
            outputRMS,
            accuracy: 0.001,
            "Audio was not processed (identical input/output)"
        )
    }

    func testBioReactiveModulation() throws {
        // Test bio-reactive modulation affects audio processing

        // 1. Process audio without bio-reactive modulation
        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        try audioEngine.start()

        var outputWithoutBio: AVAudioPCMBuffer?

        waitForCompletion(description: "Process without bio") { completion in
            audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputWithoutBio = buffer
                }
                completion()
            }
        }

        // 2. Inject heart rate and process with bio-reactive modulation
        injectMockHeartRate(80.0)
        audioEngine.enableBioReactiveProcessing(true)

        var outputWithBio: AVAudioPCMBuffer?

        waitForCompletion(description: "Process with bio") { completion in
            audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputWithBio = buffer
                }
                completion()
            }
        }

        // 3. Verify bio-reactive modulation changed the output
        guard let noBio = outputWithoutBio, let withBio = outputWithBio else {
            XCTFail("Missing output buffers")
            return
        }

        let rmsNoBio = calculateRMS(buffer: noBio)
        let rmsWithBio = calculateRMS(buffer: withBio)

        XCTAssertNotEqual(
            rmsNoBio,
            rmsWithBio,
            accuracy: 0.01,
            "Bio-reactive modulation had no effect"
        )
    }

    func testHeartRateToFilterModulation() throws {
        // Test heart rate directly modulates filter parameters

        try audioEngine.start()
        audioEngine.enableBioReactiveProcessing(true)

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.5)

        // Test with low heart rate (60 BPM)
        injectMockHeartRate(60.0)

        var outputLowHR: AVAudioPCMBuffer?
        waitForCompletion(description: "Low HR processing") { completion in
            audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputLowHR = buffer
                }
                completion()
            }
        }

        // Test with high heart rate (120 BPM)
        injectMockHeartRate(120.0)

        var outputHighHR: AVAudioPCMBuffer?
        waitForCompletion(description: "High HR processing") { completion in
            audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputHighHR = buffer
                }
                completion()
            }
        }

        // Verify different heart rates produce different audio
        guard let lowHR = outputLowHR, let highHR = outputHighHR else {
            XCTFail("Missing output buffers")
            return
        }

        let rmsLow = calculateRMS(buffer: lowHR)
        let rmsHigh = calculateRMS(buffer: highHR)

        XCTAssertNotEqual(
            rmsLow,
            rmsHigh,
            accuracy: 0.01,
            "Heart rate changes did not affect audio processing"
        )
    }

    func testRealtimeBufferProcessing() throws {
        // Test processing multiple buffers in sequence (simulates real-time)

        try audioEngine.start()

        let bufferCount = 10
        let bufferDuration: TimeInterval = 0.1 // 100ms buffers

        var processedBuffers: [AVAudioPCMBuffer] = []
        let expectation = self.expectation(description: "Process buffers")
        expectation.expectedFulfillmentCount = bufferCount

        // Process multiple buffers sequentially
        for i in 0..<bufferCount {
            let frequency: Float = 440.0 + Float(i * 10) // Varying frequency
            let buffer = generateTestBuffer(
                frequency: frequency,
                duration: bufferDuration
            )

            audioEngine.processBuffer(buffer) { result in
                if case .success(let processed) = result {
                    processedBuffers.append(processed)
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: testTimeout)

        // Verify all buffers processed successfully
        XCTAssertEqual(
            processedBuffers.count,
            bufferCount,
            "Not all buffers were processed"
        )

        // Verify no dropouts or artifacts
        for buffer in processedBuffers {
            XCTAssertTrue(verifyBufferValid(buffer), "Buffer invalid")
            assertNoAudioArtifacts(buffer)
        }
    }

    func testDSPChainProcessing() throws {
        // Test complete DSP chain: Filter → Compressor → Reverb → Delay

        try audioEngine.start()

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 1.0)

        // Enable all DSP effects
        audioEngine.enableFilter(true)
        audioEngine.enableCompressor(true)
        audioEngine.enableReverb(true)
        audioEngine.enableDelay(true)

        var outputAllEffects: AVAudioPCMBuffer?

        waitForCompletion(description: "Full DSP chain") { completion in
            audioEngine.processBuffer(testBuffer) { result in
                if case .success(let buffer) = result {
                    outputAllEffects = buffer
                }
                completion()
            }
        }

        guard let output = outputAllEffects else {
            XCTFail("No output from DSP chain")
            return
        }

        // Verify processing
        XCTAssertTrue(verifyBufferValid(output), "Output invalid")
        assertNoAudioArtifacts(output)

        // Verify reverb added tail (output longer than input)
        XCTAssertGreaterThanOrEqual(
            output.frameLength,
            testBuffer.frameLength,
            "Reverb did not add tail"
        )
    }

    func testLowLatencyProcessing() throws {
        // Test processing latency is acceptable (< 10ms)

        try audioEngine.start()

        let testBuffer = generateTestBuffer(frequency: 440.0, duration: 0.1)

        var processingTime: TimeInterval = 0

        waitForCompletion(description: "Latency test") { completion in
            let startTime = Date()

            audioEngine.processBuffer(testBuffer) { result in
                processingTime = Date().timeIntervalSince(startTime)
                completion()
            }
        }

        // Audio processing should be < 10ms for real-time
        XCTAssertLessThan(
            processingTime,
            0.010,
            "Processing latency too high: \(processingTime * 1000)ms"
        )
    }

    func testMemoryStabilityUnderLoad() throws {
        // Test memory usage remains stable under sustained load

        try audioEngine.start()

        let initialMemory = getMemoryUsage()

        // Process 100 buffers
        for _ in 0..<100 {
            let buffer = generateTestBuffer(frequency: 440.0, duration: 0.1)

            autoreleasepool {
                audioEngine.processBuffer(buffer) { _ in }
            }

            // Allow processing to complete
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        let finalMemory = getMemoryUsage()

        // Memory should not grow significantly (< 10MB increase)
        let memoryGrowth = finalMemory - initialMemory
        XCTAssertLessThan(
            memoryGrowth,
            10_000_000,
            "Memory grew by \(memoryGrowth / 1_000_000)MB"
        )
    }

    func testBufferFormatCompatibility() throws {
        // Test various buffer formats are handled correctly

        try audioEngine.start()

        let testFormats: [(Double, UInt32)] = [
            (44100.0, 1),  // 44.1kHz mono
            (44100.0, 2),  // 44.1kHz stereo
            (48000.0, 2),  // 48kHz stereo
            (96000.0, 2),  // 96kHz stereo
        ]

        for (sampleRate, channels) in testFormats {
            let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: channels
            )!

            let frameCount = AVAudioFrameCount(sampleRate * 0.1) // 100ms

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            ) else {
                XCTFail("Failed to create buffer for \(sampleRate)Hz, \(channels)ch")
                continue
            }

            buffer.frameLength = frameCount

            // Fill with test data
            for ch in 0..<Int(channels) {
                let channelData = buffer.floatChannelData![ch]
                for frame in 0..<Int(frameCount) {
                    channelData[frame] = sin(Float(frame) * 0.01)
                }
            }

            // Process buffer
            var processed = false

            waitForCompletion(description: "Format test") { completion in
                audioEngine.processBuffer(buffer) { result in
                    processed = result.isSuccess
                    completion()
                }
            }

            XCTAssertTrue(
                processed,
                "Failed to process \(sampleRate)Hz, \(channels)ch"
            )
        }
    }

    // MARK: - Utilities

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
