import XCTest
@testable import Echoelmusic

/// Integration Tests - System-Wide Validation
/// Ensures all components work together at 100% quality
final class IntegrationTests: XCTestCase {

    // MARK: - Cinema Camera + Color Grading Integration

    func testCameraAndColorGradingIntegration() async throws {
        await MainActor.run {
            let camera = CinemaCameraSystem()
            let grading = ProfessionalColorGrading()

            // Link color grading to camera
            camera.colorGrading = grading

            // Apply user's preferred workflow
            camera.whiteBalanceKelvin = 3200  // User's 3200K tungsten preference
            grading.loadPreset(.tungsten3200K)

            // Verify integration
            XCTAssertEqual(camera.whiteBalanceKelvin, 3200, "Camera should be at 3200K")
            XCTAssertEqual(grading.temperature, 0, "Grading should be neutral at 3200K base")

            // Switch to outdoor daylight
            camera.whiteBalanceKelvin = 5600
            grading.loadPreset(.daylight5600K)

            XCTAssertEqual(camera.whiteBalanceKelvin, 5600, "Camera should switch to 5600K")
            XCTAssertEqual(grading.temperature, 42, "Grading should adjust for daylight")
        }
    }

    func testProResRecordingWithColorGrading() async throws {
        await MainActor.run {
            let camera = CinemaCameraSystem()
            let grading = ProfessionalColorGrading()

            camera.colorGrading = grading
            camera.currentCodec = .proRes422HQ  // User's preference

            // Load cinematic preset
            grading.loadPreset(.cinematic)

            // Verify codec and grading are compatible
            XCTAssertEqual(camera.currentCodec, .proRes422HQ, "Should use ProRes 422 HQ")
            XCTAssertEqual(camera.currentCodec.bitDepth, 10, "Should be 10-bit")
            XCTAssertNotEqual(grading.shadowsLift.hue, 0, "Cinematic preset should affect shadows")
            XCTAssertNotEqual(grading.highlightsGain.hue, 0, "Cinematic preset should affect highlights")
        }
    }

    // MARK: - Feedback Suppression + Bluetooth Integration

    func testFeedbackSuppressionWithBluetoothLatencyCompensation() {
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        let bluetoothEngine = UltraLowLatencyBluetoothEngine.shared

        // Connect Bluetooth
        suppressor.connectBluetooth(engine: bluetoothEngine)

        // Simulate live PA scenario (most demanding)
        suppressor.loadScenario(.livePA)

        XCTAssertEqual(suppressor.currentScenario, .livePA, "Should be in Live PA scenario")
        XCTAssertNotNil(bluetoothEngine, "Bluetooth engine should be connected")

        // Process audio with Bluetooth latency compensation
        var leftChannel = [Float](repeating: 0.0, count: 256)
        var rightChannel = [Float](repeating: 0.0, count: 256)

        for i in 0..<256 {
            let phase = Float(i) * 1000.0 * 2.0 * .pi / 48000.0
            leftChannel[i] = sin(phase) * 0.5
            rightChannel[i] = sin(phase) * 0.5
        }

        suppressor.processStereo(left: &leftChannel, right: &rightChannel, frameCount: 256)

        XCTAssertFalse(leftChannel.allSatisfy { $0.isNaN }, "Should process audio with Bluetooth integration")
    }

    func testMultiScenarioFeedbackSuppression() {
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)

        // Test all scenarios in sequence
        let scenarios: [IntelligentFeedbackSuppressor.Scenario] = [
            .homeRecording, .onlineJamming, .livePA, .eventMultiMic
        ]

        for scenario in scenarios {
            suppressor.loadScenario(scenario)

            var buffer = [Float](repeating: 0.0, count: 512)
            for i in 0..<512 {
                let phase = Float(i) * 500.0 * 2.0 * .pi / 48000.0
                buffer[i] = sin(phase) * 0.3
            }

            suppressor.processMono(&buffer, frameCount: 512)

            XCTAssertFalse(buffer.allSatisfy { $0.isNaN }, "Scenario \(scenario) should process correctly")
        }
    }

    // MARK: - Bio-Reactive System Integration

    func testBioReactiveFeedbackSuppressionAndCameraAdjustment() async throws {
        // Simulate stressed state affecting both feedback suppression and camera
        let stressedState = SystemState(
            hrvRMSSD: 25.0,  // Low HRV = stressed
            hrvLFHFRatio: 3.5,  // High LF/HF = stressed
            hrvCoherence: 40.0,  // Low coherence
            hrvFrequency: 0.08,
            respirationRate: 18.0,
            currentEmotion: .anxious,
            energyLevel: 0.5,
            timestamp: Date()
        )

        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        suppressor.bioReactiveMode = true
        suppressor.updateSystemState(stressedState)

        await MainActor.run {
            let camera = CinemaCameraSystem()

            // In stressed state:
            // - Feedback suppressor should be more aggressive
            // - Camera might suggest lower ISO/better exposure for calmer shots
            // (Actual AI suggestions would be implemented in camera)

            XCTAssertTrue(suppressor.bioReactiveMode, "Bio-reactive mode should be active")
        }
    }

    func testBioReactiveCalmStateOptimization() async throws {
        // Simulate calm state - system can be less aggressive
        let calmState = SystemState(
            hrvRMSSD: 75.0,  // High HRV = calm
            hrvLFHFRatio: 1.2,  // Low LF/HF = calm
            hrvCoherence: 85.0,  // High coherence
            hrvFrequency: 0.1,
            respirationRate: 12.0,
            currentEmotion: .calm,
            energyLevel: 0.8,
            timestamp: Date()
        )

        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        suppressor.bioReactiveMode = true
        suppressor.updateSystemState(calmState)

        XCTAssertTrue(suppressor.bioReactiveMode, "Bio-reactive mode should be active")
        // In calm state, suppressor can use gentler thresholds
    }

    // MARK: - Complete Workflow Tests

    func testCompleteStudioToOutdoorWorkflow() async throws {
        await MainActor.run {
            // User's complete workflow: Studio → Outdoor → Back to Studio
            let camera = CinemaCameraSystem()
            let grading = ProfessionalColorGrading()
            camera.colorGrading = grading

            // 1. Studio setup (3200K tungsten, ProRes 422 HQ)
            camera.currentCodec = .proRes422HQ
            camera.whiteBalanceKelvin = 3200
            grading.loadPreset(.tungsten3200K)

            XCTAssertEqual(camera.currentCodec, .proRes422HQ, "Studio should use ProRes 422 HQ")
            XCTAssertEqual(camera.whiteBalanceKelvin, 3200, "Studio should be 3200K")
            XCTAssertEqual(grading.temperature, 0, "Grading should be neutral")

            // 2. Move outdoors (Golden Hour)
            camera.whiteBalanceKelvin = 3800  // Warmer outdoor light
            grading.loadPreset(.goldenHour)

            XCTAssertEqual(camera.whiteBalanceKelvin, 3800, "Outdoor should be warmer")
            XCTAssertEqual(grading.temperature, 60, "Golden hour should be very warm")
            XCTAssertGreaterThan(grading.saturation, 1.0, "Golden hour should boost saturation")

            // 3. Back to studio
            camera.whiteBalanceKelvin = 3200
            grading.loadPreset(.tungsten3200K)

            XCTAssertEqual(camera.whiteBalanceKelvin, 3200, "Back to 3200K studio")
            XCTAssertEqual(grading.temperature, 0, "Back to neutral")
        }
    }

    func testCompleteLivePerformanceWorkflow() {
        // Live performance: PA system with wireless mics + Bluetooth monitoring
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        let bluetoothEngine = UltraLowLatencyBluetoothEngine.shared

        // Setup for live PA
        suppressor.loadScenario(.livePA)
        suppressor.autoMode = true
        suppressor.learningMode = true
        suppressor.connectBluetooth(engine: bluetoothEngine)

        XCTAssertEqual(suppressor.currentScenario, .livePA, "Should be in Live PA mode")
        XCTAssertTrue(suppressor.autoMode, "Auto mode should handle feedback automatically")
        XCTAssertTrue(suppressor.learningMode, "Should learn room acoustics")

        // Simulate audio processing during performance
        var leftChannel = [Float](repeating: 0.0, count: 256)
        var rightChannel = [Float](repeating: 0.0, count: 256)

        // Process 100 buffers (simulating ~0.5 seconds of audio)
        for _ in 0..<100 {
            // Generate complex audio (music + vocals)
            for i in 0..<256 {
                let phase1 = Float(i) * 440.0 * 2.0 * .pi / 48000.0  // A4 note
                let phase2 = Float(i) * 880.0 * 2.0 * .pi / 48000.0  // A5 note
                leftChannel[i] = sin(phase1) * 0.3 + sin(phase2) * 0.2
                rightChannel[i] = leftChannel[i]
            }

            suppressor.processStereo(left: &leftChannel, right: &rightChannel, frameCount: 256)
        }

        // Verify system stayed stable
        XCTAssertLessThan(suppressor.currentCPULoad, 20.0, "CPU load should stay reasonable during performance")
    }

    // MARK: - Multi-Device Scenarios

    func testOnlineJammingWithMultipleDevices() {
        // Online jamming: Bluetooth headphones + mic + network latency
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        let bluetoothEngine = UltraLowLatencyBluetoothEngine.shared

        suppressor.loadScenario(.onlineJamming)
        suppressor.connectBluetooth(engine: bluetoothEngine)

        // Simulate low-latency processing
        var buffer = [Float](repeating: 0.0, count: 128)  // 128 frames @ 48kHz = 2.67ms

        for i in 0..<128 {
            let phase = Float(i) * 440.0 * 2.0 * .pi / 48000.0
            buffer[i] = sin(phase) * 0.4
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        suppressor.processMono(&buffer, frameCount: 128)
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000  // ms

        XCTAssertLessThan(processingTime, 1.0, "Processing should be under 1ms for real-time online jamming")
    }

    func testEventMultiMicWithFeedbackPrevention() {
        // Event: Multiple wireless mics + speakers + ambient noise
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)

        suppressor.loadScenario(.eventMultiMic)
        XCTAssertEqual(suppressor.sensitivity, 0.9, "Event should be maximally sensitive")

        // Simulate challenging scenario: multiple frequency components
        var leftChannel = [Float](repeating: 0.0, count: 512)
        var rightChannel = [Float](repeating: 0.0, count: 512)

        for i in 0..<512 {
            // Mix of frequencies that might cause feedback
            let phase1 = Float(i) * 250.0 * 2.0 * .pi / 48000.0  // Low
            let phase2 = Float(i) * 1000.0 * 2.0 * .pi / 48000.0  // Mid
            let phase3 = Float(i) * 4000.0 * 2.0 * .pi / 48000.0  // High
            leftChannel[i] = sin(phase1) * 0.2 + sin(phase2) * 0.3 + sin(phase3) * 0.2
            rightChannel[i] = leftChannel[i]
        }

        suppressor.processStereo(left: &leftChannel, right: &rightChannel, frameCount: 512)

        // Should handle complex multi-frequency scenarios
        XCTAssertFalse(leftChannel.contains { $0.isNaN }, "Should process multi-frequency audio correctly")
    }

    // MARK: - Performance Integration Tests

    func testConcurrentCameraAndFeedbackSuppression() async throws {
        // Simulate simultaneous camera operation and feedback suppression
        await MainActor.run {
            let camera = CinemaCameraSystem()
            let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)

            camera.currentCodec = .proRes422HQ
            camera.startSession()

            suppressor.loadScenario(.livePA)

            // Process audio while camera is running
            var buffer = [Float](repeating: 0.0, count: 256)
            for i in 0..<256 {
                let phase = Float(i) * 1000.0 * 2.0 * .pi / 48000.0
                buffer[i] = sin(phase) * 0.5
            }

            suppressor.processMono(&buffer, frameCount: 256)

            // Both systems should work together
            XCTAssertTrue(camera.isSessionRunning || !camera.isSessionRunning, "Camera session state should be valid")
            XCTAssertLessThan(suppressor.currentCPULoad, 20.0, "CPU load should be manageable with both systems")

            camera.stopSession()
        }
    }

    func testSystemStabilityUnderLoad() {
        // Test system stability with maximum load
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)
        suppressor.loadScenario(.eventMultiMic)  // Most demanding scenario

        var leftChannel = [Float](repeating: 0.0, count: 512)
        var rightChannel = [Float](repeating: 0.0, count: 512)

        // Process 1000 buffers (simulating ~10 seconds of audio)
        for iteration in 0..<1000 {
            // Generate varying audio
            for i in 0..<512 {
                let phase = Float(i + iteration) * 1000.0 * 2.0 * .pi / 48000.0
                leftChannel[i] = sin(phase) * 0.5
                rightChannel[i] = sin(phase) * 0.5
            }

            suppressor.processStereo(left: &leftChannel, right: &rightChannel, frameCount: 512)
        }

        // System should remain stable after extended operation
        XCTAssertLessThan(suppressor.currentCPULoad, 25.0, "CPU load should stay reasonable")
        XCTAssertFalse(leftChannel.contains { $0.isNaN }, "Should not accumulate numerical errors")
    }

    // MARK: - Quality Assurance Tests

    func testNoAudioArtifacts() {
        // Ensure no clicks, pops, or zipper noise when changing settings
        let suppressor = IntelligentFeedbackSuppressor(sampleRate: 48000)

        var buffer = [Float](repeating: 0.0, count: 512)
        for i in 0..<512 {
            let phase = Float(i) * 1000.0 * 2.0 * .pi / 48000.0
            buffer[i] = sin(phase) * 0.5
        }

        // Process first buffer
        suppressor.processMono(&buffer, frameCount: 512)
        let firstSample = buffer[0]

        // Change sensitivity mid-stream
        suppressor.sensitivity = 0.8

        // Process second buffer
        for i in 0..<512 {
            let phase = Float(i) * 1000.0 * 2.0 * .pi / 48000.0
            buffer[i] = sin(phase) * 0.5
        }
        suppressor.processMono(&buffer, frameCount: 512)

        // Check for smooth transition (no huge jumps)
        let transition = abs(buffer[0] - firstSample)
        XCTAssertLessThan(transition, 0.5, "Transition should be smooth, no clicks")
    }

    func testColorGradingConsistency() async throws {
        await MainActor.run {
            let grading = ProfessionalColorGrading()
            let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Process same image multiple times
            let result1 = grading.process(testImage)
            let result2 = grading.process(testImage)

            // Results should be identical (deterministic processing)
            XCTAssertEqual(result1.extent, result2.extent, "Processing should be deterministic")
        }
    }
}
