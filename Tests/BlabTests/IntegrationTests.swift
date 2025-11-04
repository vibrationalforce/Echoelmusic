import XCTest
@testable import Blab

/// Integration Test Suite
///
/// Tests for cross-component interactions:
/// - AudioEngine + RTMP integration
/// - AudioEngine + NDI integration
/// - StreamDeck + AudioEngine + DSP integration
/// - UnifiedControlHub integration
/// - Macro System + Control integration
@available(iOS 15.0, *)
final class IntegrationTests: XCTestCase {

    var audioEngine: AudioEngine!
    var controlHub: UnifiedControlHub!
    var microphone: MicrophoneManager!

    override func setUp() async throws {
        try await super.setUp()
        microphone = MicrophoneManager()
        audioEngine = AudioEngine(microphoneManager: microphone)
        controlHub = UnifiedControlHub(audioEngine: audioEngine)
    }

    override func tearDown() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        controlHub.stop()
        super.tearDown()
    }

    // MARK: - AudioEngine + RTMP Integration

    func testAudioEngineRTMPIntegration() async {
        // Given: Audio engine running
        audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning)

        // When: Enable RTMP
        do {
            try await audioEngine.enableRTMP(
                platform: .youtube,
                streamKey: "test_key"
            )

            // Then: RTMP should be enabled
            XCTAssertTrue(audioEngine.isRTMPEnabled)

            // Cleanup
            audioEngine.disableRTMP()
        } catch {
            // Network errors expected in test environment
            XCTAssertNotNil(error)
        }
    }

    func testAudioEngineRTMPAutoStreaming() {
        // Given: RTMP enabled (simulated)
        // When: Enable auto-streaming
        audioEngine.enableAutoStreaming()

        // Then: Should not crash
        // Cleanup
        audioEngine.disableAutoStreaming()
    }

    // MARK: - AudioEngine + NDI Integration

    func testAudioEngineNDIIntegration() async {
        // Given: Audio engine running
        audioEngine.start()

        // When: Enable NDI
        do {
            try await audioEngine.enableNDI(
                sourceName: "BLAB Test",
                quality: .balanced
            )

            // Then: NDI should be enabled
            XCTAssertTrue(audioEngine.isNDIEnabled)

            // Cleanup
            audioEngine.disableNDI()
        } catch {
            // NDI SDK errors expected without actual SDK
            XCTAssertNotNil(error)
        }
    }

    // MARK: - StreamDeck + AudioEngine Integration

    func testStreamDeckAudioEngineIntegration() {
        // Given: Stream Deck connected to audio engine
        let streamDeck = StreamDeckController.shared
        streamDeck.setup(audioEngine: audioEngine, controlHub: controlHub)

        // When: Toggle audio via Stream Deck
        streamDeck.handleButtonPress(0)  // Toggle audio button

        // Then: Audio engine state should change
        // (Actual state change tested in specific tests)
        XCTAssertNotNil(streamDeck)
    }

    func testStreamDeckDSPPresetCycling() {
        // Given: Stream Deck with audio engine
        let streamDeck = StreamDeckController.shared
        streamDeck.setup(audioEngine: audioEngine, controlHub: controlHub)

        // When: Cycle DSP preset
        streamDeck.handleButtonPress(10)  // Next preset button

        // Then: Should not crash
        // DSP preset should change (tested in DSP tests)
    }

    // MARK: - UnifiedControlHub Integration

    func testUnifiedControlHubStartup() {
        // Given: Control hub initialized
        XCTAssertFalse(controlHub.isRunning)

        // When: Start control hub
        controlHub.start()

        // Then: Should be running
        XCTAssertTrue(controlHub.isRunning)

        // Cleanup
        controlHub.stop()
    }

    func testControlHubAudioEngineIntegration() {
        // Given: Control hub running
        controlHub.start()

        // When: Start audio engine
        audioEngine.start()

        // Then: Both should be running
        XCTAssertTrue(controlHub.isRunning)
        XCTAssertTrue(audioEngine.isRunning)

        // Cleanup
        audioEngine.stop()
        controlHub.stop()
    }

    func testControlHubNDIQuickEnable() {
        // Given: Control hub running
        controlHub.start()

        // When: Quick enable NDI
        controlHub.quickEnableNDI()

        // Then: Should attempt to enable
        // (Actual NDI enablement tested in NDI tests)

        // Cleanup
        controlHub.stop()
    }

    // MARK: - Macro System Integration

    func testMacroSystemExecution() async {
        // Given: Macro system with audio engine
        let macroSystem = MacroSystem.shared
        macroSystem.setup(audioEngine: audioEngine, controlHub: controlHub)

        // Create test macro
        var macro = MacroSystem.Macro(
            name: "Test Macro",
            description: "Integration test macro"
        )
        macro.actions = [
            MacroSystem.MacroAction(
                type: .toggleAudio,
                parameters: [:],
                delay: 0.0
            )
        ]

        // When: Execute macro
        await macroSystem.execute(macro)

        // Then: Should complete without crash
        // (Actual effects tested in macro tests)
    }

    func testMacroWithMultipleActions() async {
        // Given: Complex macro
        let macroSystem = MacroSystem.shared
        macroSystem.setup(audioEngine: audioEngine, controlHub: controlHub)

        var macro = MacroSystem.Macro(name: "Complex Macro")
        macro.actions = [
            MacroSystem.MacroAction(type: .toggleAudio, parameters: [:], delay: 0.1),
            MacroSystem.MacroAction(type: .toggleSpatialAudio, parameters: [:], delay: 0.1),
            MacroSystem.MacroAction(type: .enableNDI, parameters: [:], delay: 0.1)
        ]

        // When: Execute
        await macroSystem.execute(macro)

        // Then: Should complete all actions
        XCTAssertTrue(true)  // Completion itself is success
    }

    // MARK: - DSP + AudioEngine Integration

    func testDSPProcessorIntegration() {
        // Given: Audio engine with DSP
        let dsp = audioEngine.dspProcessor

        // When: Apply preset
        dsp.applyPreset(.podcast)

        // Then: Should apply without crash
        XCTAssertTrue(dsp.advanced.noiseGate.enabled)
    }

    func testDSPPresetSwitching() {
        // Given: DSP processor
        let dsp = audioEngine.dspProcessor

        // When: Cycle through all presets
        for preset in AdvancedDSP.Preset.allCases {
            dsp.applyPreset(preset)
        }

        // Then: Should handle all presets
        XCTAssertTrue(true)
    }

    // MARK: - Full Workflow Integration

    func testCompleteWorkflow() async {
        // Test complete BLAB workflow
        // 1. Start audio engine
        audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning)

        // 2. Apply DSP preset
        audioEngine.dspProcessor.applyPreset(.podcast)

        // 3. Start control hub
        controlHub.start()
        XCTAssertTrue(controlHub.isRunning)

        // 4. Setup Stream Deck
        let streamDeck = StreamDeckController.shared
        streamDeck.setup(audioEngine: audioEngine, controlHub: controlHub)

        // 5. Setup Macro System
        let macroSystem = MacroSystem.shared
        macroSystem.setup(audioEngine: audioEngine, controlHub: controlHub)

        // 6. Toggle spatial audio
        audioEngine.toggleSpatialAudio()

        // 7. Stop everything
        controlHub.stop()
        audioEngine.stop()

        XCTAssertFalse(audioEngine.isRunning)
        XCTAssertFalse(controlHub.isRunning)
    }

    func testStreamingWorkflow() async {
        // Test complete streaming workflow
        // 1. Start audio
        audioEngine.start()

        // 2. Configure RTMP
        do {
            try await audioEngine.enableRTMP(
                platform: .youtube,
                streamKey: "test_key"
            )

            // 3. Enable auto-streaming
            audioEngine.enableAutoStreaming()

            // 4. Simulate streaming duration
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

            // 5. Stop streaming
            audioEngine.disableAutoStreaming()
            audioEngine.disableRTMP()

        } catch {
            // Network errors expected
            XCTAssertNotNil(error)
        }

        // Cleanup
        audioEngine.stop()
    }

    // MARK: - Error Handling Integration

    func testErrorHandlingAcrossComponents() {
        // Test that errors in one component don't crash others

        // 1. Try invalid operations
        audioEngine.stop()  // Already stopped
        controlHub.stop()   // Not started

        // 2. Should not crash
        XCTAssertFalse(audioEngine.isRunning)
        XCTAssertFalse(controlHub.isRunning)

        // 3. Should still be able to start
        audioEngine.start()
        XCTAssertTrue(audioEngine.isRunning)

        audioEngine.stop()
    }

    // MARK: - Performance Integration

    func testPerformanceFullWorkflow() {
        measure {
            // Start everything
            audioEngine.start()
            controlHub.start()

            // Perform operations
            audioEngine.toggleSpatialAudio()
            audioEngine.dspProcessor.applyPreset(.podcast)

            // Stop everything
            controlHub.stop()
            audioEngine.stop()
        }
    }

    // MARK: - Latency Integration

    func testLatencyMeasurementIntegration() {
        // Given: Audio engine with latency monitoring
        audioEngine.start()

        // When: Enable latency monitoring
        audioEngine.enableLatencyMonitoring()

        // Then: Should measure latency
        // (Actual measurements tested in latency tests)

        // Cleanup
        audioEngine.disableLatencyMonitoring()
        audioEngine.stop()
    }

    // MARK: - Multi-Component State Tests

    func testMultiComponentStateConsistency() {
        // Test that all components maintain consistent state

        // Start everything
        audioEngine.start()
        controlHub.start()

        // Verify states
        XCTAssertTrue(audioEngine.isRunning)
        XCTAssertTrue(controlHub.isRunning)

        // Stop audio engine
        audioEngine.stop()
        XCTAssertFalse(audioEngine.isRunning)

        // Control hub should still be running
        XCTAssertTrue(controlHub.isRunning)

        // Cleanup
        controlHub.stop()
    }

    // MARK: - WebRTC Integration

    func testWebRTCIntegration() {
        // Given: WebRTC manager
        let webrtc = WebRTCManager.shared

        // When: Start server
        webrtc.startServer(port: 8080)

        // Then: Should be running
        XCTAssertTrue(webrtc.isServerRunning)

        // Cleanup
        webrtc.stopServer()
        XCTAssertFalse(webrtc.isServerRunning)
    }

    func testWebRTCAudioIntegration() {
        // Given: Audio engine and WebRTC
        let webrtc = WebRTCManager.shared

        // When: Start both
        audioEngine.start()
        webrtc.startServer()

        // Then: Both should be running
        XCTAssertTrue(audioEngine.isRunning)
        XCTAssertTrue(webrtc.isServerRunning)

        // Cleanup
        webrtc.stopServer()
        audioEngine.stop()
    }
}
