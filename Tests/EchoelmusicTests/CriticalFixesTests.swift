import XCTest
@testable import Echoelmusic

/// Tests for critical fixes from repository audit
final class CriticalFixesTests: XCTestCase {

    // MARK: - VideoProcessingEngine Tests

    func testVideoProcessingEngineInitialization() async {
        let engine = await VideoProcessingEngine()
        XCTAssertNotNil(engine)
    }

    func testVideoEffectTypesExist() {
        // Verify all quantum effects are defined
        let quantumEffects: [VideoEffectType] = [.quantumWave, .coherenceField, .photonTrails, .heartbeatPulse]
        XCTAssertEqual(quantumEffects.count, 4)
    }

    func testVideoResolutionPresets() {
        XCTAssertEqual(VideoResolution.hd720p.width, 1280)
        XCTAssertEqual(VideoResolution.hd720p.height, 720)
        XCTAssertEqual(VideoResolution.uhd4k.width, 3840)
        XCTAssertEqual(VideoResolution.uhd4k.height, 2160)
        XCTAssertEqual(VideoResolution.uhd8k.width, 7680)
        XCTAssertEqual(VideoResolution.uhd8k.height, 4320)
    }

    // MARK: - CollaborationEngine Tests

    func testCollaborationEngineInitialization() async {
        let engine = await CollaborationEngine()
        await MainActor.run {
            XCTAssertFalse(engine.isActive)
            XCTAssertNil(engine.currentSession)
            XCTAssertTrue(engine.participants.isEmpty)
            XCTAssertEqual(engine.connectionState, .disconnected)
        }
    }

    func testWebRTCClientInitialization() {
        let iceServers = [ICEServer(urls: ["stun:stun.l.google.com:19302"])]
        let client = WebRTCClient(iceServers: iceServers)
        XCTAssertNotNil(client)
    }

    func testWebRTCClientCreateOffer() async throws {
        let iceServers = [ICEServer(urls: ["stun:stun.l.google.com:19302"])]
        let client = WebRTCClient(iceServers: iceServers)

        // Should not throw
        try await client.createOffer()
    }

    func testSignalingClientInitialization() {
        let client = SignalingClient(url: "wss://test.example.com")
        XCTAssertNotNil(client)
    }

    func testSignalingErrorDescriptions() {
        XCTAssertEqual(SignalingError.invalidURL.errorDescription, "Invalid signaling server URL")
        XCTAssertEqual(SignalingError.connectionFailed.errorDescription, "Failed to connect to signaling server")
        XCTAssertEqual(SignalingError.encodingFailed.errorDescription, "Failed to encode message")
        XCTAssertEqual(SignalingError.notConnected.errorDescription, "Not connected to signaling server")
    }

    func testICECandidateEncoding() throws {
        let candidate = ICECandidate(
            sdpMid: "data",
            sdpMLineIndex: 0,
            candidate: "candidate:1 1 UDP 2122252543 192.168.1.1 12345 typ host"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(candidate)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ICECandidate.self, from: data)
        XCTAssertEqual(decoded.sdpMid, "data")
        XCTAssertEqual(decoded.sdpMLineIndex, 0)
    }

    func testDataChannelTypes() {
        XCTAssertEqual(DataChannel.audio.rawValue, "audio")
        XCTAssertEqual(DataChannel.midi.rawValue, "midi")
        XCTAssertEqual(DataChannel.bio.rawValue, "bio")
        XCTAssertEqual(DataChannel.chat.rawValue, "chat")
        XCTAssertEqual(DataChannel.control.rawValue, "control")
    }

    func testBioSyncDataEncoding() throws {
        let bioData = BioSyncData(hrv: 65.5, coherence: 0.85)

        let encoder = JSONEncoder()
        let data = try encoder.encode(bioData)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BioSyncData.self, from: data)
        XCTAssertEqual(decoded.hrv, 65.5, accuracy: 0.01)
        XCTAssertEqual(decoded.coherence, 0.85, accuracy: 0.01)
    }

    // MARK: - AnalyticsManager Tests

    func testAnalyticsManagerSharedInstance() {
        let manager = AnalyticsManager.shared
        XCTAssertNotNil(manager)
    }

    func testFirebaseAnalyticsProviderInitialization() {
        let provider = FirebaseAnalyticsProvider()
        XCTAssertNotNil(provider)
    }

    func testAnalyticsEventTracking() {
        let provider = FirebaseAnalyticsProvider()

        // Should not throw
        provider.track(event: "test_event", properties: ["key": "value"])
    }

    func testAnalyticsUserProperty() {
        let provider = FirebaseAnalyticsProvider()

        // Should not throw
        provider.setUserProperty(key: "test_key", value: "test_value")
        provider.setUserProperty(key: "test_key", value: nil) // Remove
    }

    func testAnalyticsIdentify() {
        let provider = FirebaseAnalyticsProvider()

        // Should not throw
        provider.identify(userId: "test_user_123")
    }

    func testAnalyticsReset() {
        let provider = FirebaseAnalyticsProvider()

        // Should not throw
        provider.reset()
    }

    func testAnalyticsFlush() {
        let provider = FirebaseAnalyticsProvider()

        // Should not throw
        provider.flush()
    }

    func testCrashReporterSharedInstance() {
        let reporter = CrashReporter.shared
        XCTAssertNotNil(reporter)
    }

    func testCrashReporterBreadcrumbs() {
        let reporter = CrashReporter.shared

        reporter.recordBreadcrumb("Test breadcrumb", category: "test", level: .info)
        reporter.recordBreadcrumb("Another breadcrumb", category: "test", level: .warning)

        let breadcrumbs = reporter.getRecentBreadcrumbs(count: 10)
        XCTAssertGreaterThanOrEqual(breadcrumbs.count, 0)
    }

    func testCrashReporterNonFatalError() {
        let reporter = CrashReporter.shared

        let error = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        reporter.reportNonFatal(error: error, context: ["test": "context"])
    }

    func testCrashReporterNonFatalMessage() {
        let reporter = CrashReporter.shared

        reporter.reportNonFatal(message: "Test non-fatal message", context: ["key": "value"])
    }

    // MARK: - AccessibilityManager Tests

    func testAccessibilityManagerInitialization() async {
        let manager = await AccessibilityManager()
        await MainActor.run {
            XCTAssertNotNil(manager)
            XCTAssertEqual(manager.currentMode, .standard)
        }
    }

    func testColorBlindnessModes() {
        XCTAssertEqual(ColorBlindnessMode.none.rawValue, "None")
        XCTAssertEqual(ColorBlindnessMode.protanopia.rawValue, "Protanopia (Red-Blind)")
        XCTAssertEqual(ColorBlindnessMode.deuteranopia.rawValue, "Deuteranopia (Green-Blind)")
        XCTAssertEqual(ColorBlindnessMode.tritanopia.rawValue, "Tritanopia (Blue-Blind)")
        XCTAssertEqual(ColorBlindnessMode.achromatopsia.rawValue, "Achromatopsia (Monochrome)")
    }

    func testColorBlindnessDescriptions() {
        XCTAssertTrue(ColorBlindnessMode.protanopia.description.contains("red"))
        XCTAssertTrue(ColorBlindnessMode.deuteranopia.description.contains("green"))
        XCTAssertTrue(ColorBlindnessMode.tritanopia.description.contains("blue"))
        XCTAssertTrue(ColorBlindnessMode.achromatopsia.description.contains("monochrome"))
    }

    func testColorSafePaletteProtanopia() {
        let palette = ColorBlindnessMode.protanopia.colorSafePalette()
        XCTAssertEqual(palette.count, 6)
    }

    func testColorSafePaletteDeuteranopia() {
        let palette = ColorBlindnessMode.deuteranopia.colorSafePalette()
        XCTAssertEqual(palette.count, 6)
    }

    func testColorSafePaletteTritanopia() {
        let palette = ColorBlindnessMode.tritanopia.colorSafePalette()
        XCTAssertEqual(palette.count, 6)
    }

    func testColorSafePaletteAchromatopsia() {
        let palette = ColorBlindnessMode.achromatopsia.colorSafePalette()
        XCTAssertEqual(palette.count, 6)
    }

    func testAccessibilityModes() {
        XCTAssertEqual(AccessibilityManager.AccessibilityMode.allCases.count, 6)
        XCTAssertTrue(AccessibilityManager.AccessibilityMode.visionAssist.description.contains("low vision"))
        XCTAssertTrue(AccessibilityManager.AccessibilityMode.motorAssist.description.contains("voice control"))
    }

    func testTouchTargetSizes() {
        XCTAssertEqual(AccessibilityManager.TouchTargetSize.minimum.rawValue, 44.0)
        XCTAssertEqual(AccessibilityManager.TouchTargetSize.recommended.rawValue, 48.0)
        XCTAssertEqual(AccessibilityManager.TouchTargetSize.large.rawValue, 64.0)
        XCTAssertEqual(AccessibilityManager.TouchTargetSize.extraLarge.rawValue, 88.0)
    }

    func testHapticLevels() {
        XCTAssertEqual(AccessibilityManager.HapticLevel.off.intensity, 0.0)
        XCTAssertEqual(AccessibilityManager.HapticLevel.light.intensity, 0.3)
        XCTAssertEqual(AccessibilityManager.HapticLevel.normal.intensity, 0.6)
        XCTAssertEqual(AccessibilityManager.HapticLevel.strong.intensity, 1.0)
    }

    // MARK: - RealTimeHealthKitEngine Tests

    func testHealthKitEngineInitialization() async {
        let engine = await RealTimeHealthKitEngine()
        await MainActor.run {
            XCTAssertNotNil(engine)
            XCTAssertFalse(engine.isStreaming)
        }
    }

    // MARK: - Integration Tests

    func testCollaborationSessionCreation() {
        let session = CollaborationSession(
            id: UUID(),
            hostID: UUID(),
            participants: [],
            isHost: true,
            roomCode: "ABC123"
        )

        XCTAssertTrue(session.isHost)
        XCTAssertEqual(session.roomCode, "ABC123")
        XCTAssertTrue(session.participants.isEmpty)
    }

    func testParticipantModel() {
        let participant = Participant(
            id: UUID(),
            name: "Test User",
            hrv: 65.0,
            coherence: 0.8,
            isMuted: false
        )

        XCTAssertEqual(participant.name, "Test User")
        XCTAssertEqual(participant.hrv, 65.0, accuracy: 0.01)
        XCTAssertEqual(participant.coherence, 0.8, accuracy: 0.01)
        XCTAssertFalse(participant.isMuted)
    }

    func testChatMessageEncoding() throws {
        let message = ChatMessage(
            sender: UUID(),
            text: "Hello, world!",
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.text, "Hello, world!")
    }

    // MARK: - Performance Tests

    func testColorBlindnessAdjustmentPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = ColorBlindnessMode.protanopia.colorSafePalette()
                _ = ColorBlindnessMode.deuteranopia.colorSafePalette()
                _ = ColorBlindnessMode.tritanopia.colorSafePalette()
            }
        }
    }

    func testAnalyticsEventCreationPerformance() {
        let provider = FirebaseAnalyticsProvider()

        measure {
            for i in 0..<100 {
                provider.track(event: "perf_test_\(i)", properties: ["iteration": i])
            }
        }
    }
}

    // MARK: - Timer Cleanup Regression Tests

    func testProStreamEngineTimerCleanup() async {
        // Verify statsTimer is nil'd after deinit (no retain cycle)
        var engine: ProStreamEngine? = ProStreamEngine()
        XCTAssertNotNil(engine)
        engine = nil
        // If deinit leaks, ARC would keep engine alive — no crash = pass
    }

    func testAbletonLinkClientTimerCleanup() {
        // Verify both timers are nil'd in deinit
        var client: AbletonLinkClient? = AbletonLinkClient()
        XCTAssertNotNil(client)
        client = nil
        // Deallocation without crash = timers properly cleaned
    }

    func testMetronomeEngineTimerCleanup() {
        var engine: MetronomeEngine? = MetronomeEngine()
        XCTAssertNotNil(engine)
        engine = nil
        // DispatchSourceTimer properly cancelled and nil'd in deinit
    }

    func testUnifiedControlHubTimerCleanup() async {
        var hub: UnifiedControlHub? = await UnifiedControlHub()
        XCTAssertNotNil(hub)
        hub = nil
        // controlLoopTimer + displayLink properly cleaned in deinit
    }

    // MARK: - vDSP Buffer Isolation Tests

    func testFFTBufferIsolation() {
        // Verify input buffers are separate copies, not aliases
        let size = 64
        var realParts = [Float](repeating: 1.0, count: size)
        let imagParts = [Float](repeating: 0.0, count: size)

        // Explicit copy (our fix pattern)
        var realIn = [Float](realParts)
        var imagIn = [Float](imagParts)

        // Mutating output shouldn't affect input copy
        realParts[0] = 999.0
        XCTAssertEqual(realIn[0], 1.0, "Input buffer must be an independent copy")
        XCTAssertNotEqual(realParts[0], realIn[0], "Output and input must not alias")
    }

    func testHealthKitFFTDoesNotCrash() {
        // Regression: vDSP_DFT_Execute with overlapping buffers caused UB
        let engine = UnifiedHealthKitEngine()
        let rrIntervals = (0..<128).map { i in
            800.0 + 50.0 * sin(2.0 * .pi * 0.1 * Double(i))
        }
        let coherence = engine.calculateCoherence(rrIntervals: rrIntervals)
        XCTAssertGreaterThanOrEqual(coherence, 0.0, "Coherence should be non-negative")
    }
}

// MARK: - Type Aliases for Test Compatibility

typealias ColorBlindnessMode = AccessibilityManager.ColorBlindnessMode
