import XCTest
@testable import Echoelmusic

/// Tests for StreamEngine, RTMPClient, SceneManager, ChatAggregator, and StreamAnalytics
final class StreamEngineTests: XCTestCase {

    // MARK: - StreamDestination Tests

    func testStreamDestinationRTMPURLs() {
        // Twitch
        XCTAssertEqual(
            StreamEngine.StreamDestination.twitch.rtmpURL,
            "rtmp://live.twitch.tv/app/"
        )

        // YouTube
        XCTAssertEqual(
            StreamEngine.StreamDestination.youtube.rtmpURL,
            "rtmp://a.rtmp.youtube.com/live2/"
        )

        // Facebook (RTMPS)
        XCTAssertEqual(
            StreamEngine.StreamDestination.facebook.rtmpURL,
            "rtmps://live-api-s.facebook.com:443/rtmp/"
        )

        // Custom destinations return empty URL
        XCTAssertEqual(StreamEngine.StreamDestination.custom1.rtmpURL, "")
        XCTAssertEqual(StreamEngine.StreamDestination.custom2.rtmpURL, "")
    }

    func testStreamDestinationPorts() {
        XCTAssertEqual(StreamEngine.StreamDestination.twitch.defaultPort, 1935)
        XCTAssertEqual(StreamEngine.StreamDestination.youtube.defaultPort, 1935)
        XCTAssertEqual(StreamEngine.StreamDestination.facebook.defaultPort, 443)
        XCTAssertEqual(StreamEngine.StreamDestination.custom1.defaultPort, 1935)
    }

    func testStreamDestinationIdentifiable() {
        let destinations = StreamEngine.StreamDestination.allCases
        XCTAssertEqual(destinations.count, 5)

        // Check all have unique IDs
        let ids = destinations.map { $0.id }
        XCTAssertEqual(Set(ids).count, destinations.count)
    }

    // MARK: - Resolution Tests

    func testResolutionSizes() {
        XCTAssertEqual(StreamEngine.Resolution.hd1280x720.size, CGSize(width: 1280, height: 720))
        XCTAssertEqual(StreamEngine.Resolution.hd1920x1080.size, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(StreamEngine.Resolution.uhd3840x2160.size, CGSize(width: 3840, height: 2160))
    }

    func testResolutionRecommendedBitrates() {
        XCTAssertEqual(StreamEngine.Resolution.hd1280x720.recommendedBitrate, 3500)
        XCTAssertEqual(StreamEngine.Resolution.hd1920x1080.recommendedBitrate, 6000)
        XCTAssertEqual(StreamEngine.Resolution.uhd3840x2160.recommendedBitrate, 12000)
    }

    func testResolutionRawValues() {
        XCTAssertEqual(StreamEngine.Resolution.hd1280x720.rawValue, "720p")
        XCTAssertEqual(StreamEngine.Resolution.hd1920x1080.rawValue, "1080p")
        XCTAssertEqual(StreamEngine.Resolution.uhd3840x2160.rawValue, "4K")
    }

    // MARK: - SceneTransition Tests

    func testSceneTransitionDurations() {
        XCTAssertEqual(SceneTransition.cut.duration, 0.0)
        XCTAssertEqual(SceneTransition.fade.duration, 0.5)
        XCTAssertEqual(SceneTransition.slide.duration, 0.3)
        XCTAssertEqual(SceneTransition.zoom.duration, 0.4)
        XCTAssertEqual(SceneTransition.stinger.duration, 1.0)
    }

    func testSceneTransitionRawValues() {
        XCTAssertEqual(SceneTransition.cut.rawValue, "Cut")
        XCTAssertEqual(SceneTransition.fade.rawValue, "Fade")
        XCTAssertEqual(SceneTransition.slide.rawValue, "Slide")
        XCTAssertEqual(SceneTransition.zoom.rawValue, "Zoom")
        XCTAssertEqual(SceneTransition.stinger.rawValue, "Stinger")
    }

    // MARK: - BioSceneRule Tests

    func testBioSceneRuleCoherenceAbove() {
        let sceneID = UUID()
        let rule = BioSceneRule(
            targetSceneID: sceneID,
            condition: .coherenceAbove,
            threshold: 0.6,
            transition: .fade
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.7, heartRate: 70, hrv: 50))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 50))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.6, heartRate: 70, hrv: 50))
    }

    func testBioSceneRuleCoherenceBelow() {
        let rule = BioSceneRule(
            targetSceneID: UUID(),
            condition: .coherenceBelow,
            threshold: 0.4,
            transition: .cut
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.3, heartRate: 70, hrv: 50))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 50))
    }

    func testBioSceneRuleHeartRateAbove() {
        let rule = BioSceneRule(
            targetSceneID: UUID(),
            condition: .heartRateAbove,
            threshold: 100,
            transition: .zoom
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.5, heartRate: 110, hrv: 50))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 90, hrv: 50))
    }

    func testBioSceneRuleHeartRateBelow() {
        let rule = BioSceneRule(
            targetSceneID: UUID(),
            condition: .heartRateBelow,
            threshold: 60,
            transition: .fade
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.5, heartRate: 55, hrv: 50))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 65, hrv: 50))
    }

    func testBioSceneRuleHRVAbove() {
        let rule = BioSceneRule(
            targetSceneID: UUID(),
            condition: .hrvAbove,
            threshold: 60,
            transition: .slide
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 70))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 50))
    }

    func testBioSceneRuleHRVBelow() {
        let rule = BioSceneRule(
            targetSceneID: UUID(),
            condition: .hrvBelow,
            threshold: 40,
            transition: .cut
        )

        XCTAssertTrue(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 30))
        XCTAssertFalse(rule.shouldTrigger(coherence: 0.5, heartRate: 70, hrv: 50))
    }

    // MARK: - StreamError Tests

    func testStreamErrorDescriptions() {
        XCTAssertEqual(
            StreamError.alreadyStreaming.errorDescription,
            "Stream is already active"
        )

        XCTAssertEqual(
            StreamError.noDestinationsSelected.errorDescription,
            "No stream destinations selected"
        )

        XCTAssertEqual(
            StreamError.missingStreamKey(.twitch).errorDescription,
            "Missing stream key for Twitch"
        )

        XCTAssertEqual(
            StreamError.encodingInitializationFailed.errorDescription,
            "Failed to initialize hardware encoder"
        )

        XCTAssertEqual(
            StreamError.rtmpConnectionFailed("timeout").errorDescription,
            "RTMP connection failed: timeout"
        )
    }

    // MARK: - Scene Tests

    func testSceneCreation() {
        let scene = Scene(name: "Test Scene", sources: [])

        XCTAssertEqual(scene.name, "Test Scene")
        XCTAssertTrue(scene.sources.isEmpty)
        XCTAssertNotNil(scene.id)
    }

    func testSceneWithSources() {
        let cameraSource = CameraSource(name: "Front Camera", cameraPosition: .front)
        let textSource = TextOverlaySource(
            name: "Title",
            text: "Live Stream",
            font: "Helvetica",
            fontSize: 24,
            color: .white,
            scrolling: false
        )

        let scene = Scene(
            name: "Main Scene",
            sources: [
                .camera(cameraSource),
                .textOverlay(textSource)
            ]
        )

        XCTAssertEqual(scene.sources.count, 2)
    }

    // MARK: - SceneSource Tests

    func testSceneSourceIDs() {
        let camera = CameraSource(name: "Camera", cameraPosition: .back)
        let cameraSource = SceneSource.camera(camera)

        XCTAssertEqual(cameraSource.id, camera.id)
    }

    func testEchoelVisualSourceTypes() {
        let visualTypes: [EchoelVisualSource.VisualType] = [
            .cymatics, .mandala, .particles, .waveform, .spectral
        ]

        for type in visualTypes {
            let source = EchoelVisualSource(name: "Visual", type: type)
            XCTAssertEqual(source.type, type)
        }
    }

    func testBioOverlayWidgets() {
        let source = BioOverlaySource(
            name: "Bio Overlay",
            widgets: [.hrvGraph, .heartRateDisplay, .coherenceRing, .breathWave]
        )

        XCTAssertEqual(source.widgets.count, 4)
    }

    // MARK: - ChatMessage Tests

    func testChatMessageCreation() {
        let message = ChatMessage(
            platform: .twitch,
            username: "viewer123",
            text: "Hello stream!",
            timestamp: Date(),
            isModerator: false,
            isSubscriber: true
        )

        XCTAssertEqual(message.platform, .twitch)
        XCTAssertEqual(message.username, "viewer123")
        XCTAssertEqual(message.text, "Hello stream!")
        XCTAssertFalse(message.isModerator)
        XCTAssertTrue(message.isSubscriber)
    }

    func testChatMessagePlatforms() {
        XCTAssertEqual(ChatMessage.Platform.twitch.rawValue, "Twitch")
        XCTAssertEqual(ChatMessage.Platform.youtube.rawValue, "YouTube")
        XCTAssertEqual(ChatMessage.Platform.facebook.rawValue, "Facebook")
    }

    // MARK: - RTMPError Tests

    func testRTMPErrorDescriptions() {
        XCTAssertEqual(RTMPError.invalidURL.errorDescription, "Invalid RTMP URL")
        XCTAssertEqual(RTMPError.connectionFailed.errorDescription, "Failed to connect to RTMP server")
        XCTAssertEqual(RTMPError.notConnected.errorDescription, "Not connected to RTMP server")
        XCTAssertEqual(RTMPError.handshakeFailed.errorDescription, "RTMP handshake failed")
        XCTAssertEqual(RTMPError.publishFailed.errorDescription, "Failed to publish stream")
        XCTAssertEqual(RTMPError.streamClosed.errorDescription, "Stream was closed by server")
    }

    // MARK: - CorrelationResult Tests

    func testCorrelationResult() {
        let result = CorrelationResult(
            metric1: "Viewers",
            metric2: "Coherence",
            correlation: 0.75,
            interpretation: "Strong positive correlation"
        )

        XCTAssertEqual(result.metric1, "Viewers")
        XCTAssertEqual(result.metric2, "Coherence")
        XCTAssertEqual(result.correlation, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.interpretation, "Strong positive correlation")
    }
}

// MARK: - SceneManager Tests

final class SceneManagerTests: XCTestCase {

    @MainActor
    func testLoadDefaultScenes() async {
        let manager = SceneManager()
        let scenes = manager.loadScenes()

        XCTAssertEqual(scenes.count, 4)
        XCTAssertEqual(scenes[0].name, "Main")
        XCTAssertEqual(scenes[1].name, "Meditation")
        XCTAssertEqual(scenes[2].name, "Performance")
        XCTAssertEqual(scenes[3].name, "BRB")
    }

    @MainActor
    func testAddScene() async {
        let manager = SceneManager()
        let scene = Scene(name: "Custom Scene", sources: [])

        manager.addScene(scene)

        XCTAssertEqual(manager.scenes.count, 1)
        XCTAssertEqual(manager.scenes.first?.name, "Custom Scene")
    }

    @MainActor
    func testRemoveScene() async {
        let manager = SceneManager()
        let scene = Scene(name: "To Remove", sources: [])

        manager.addScene(scene)
        XCTAssertEqual(manager.scenes.count, 1)

        manager.removeScene(scene.id)
        XCTAssertEqual(manager.scenes.count, 0)
    }

    @MainActor
    func testBioReactiveSettings() async {
        let manager = SceneManager()

        XCTAssertFalse(manager.bioReactiveEnabled)
        XCTAssertTrue(manager.bioSceneRules.isEmpty)

        manager.bioReactiveEnabled = true
        manager.bioSceneRules = [
            BioSceneRule(
                targetSceneID: UUID(),
                condition: .coherenceAbove,
                threshold: 0.7,
                transition: .fade
            )
        ]

        XCTAssertTrue(manager.bioReactiveEnabled)
        XCTAssertEqual(manager.bioSceneRules.count, 1)
    }
}

// MARK: - ChatAggregator Tests

final class ChatAggregatorTests: XCTestCase {

    @MainActor
    func testStartStop() async {
        let aggregator = ChatAggregator()

        XCTAssertFalse(aggregator.isActive)

        aggregator.start()
        XCTAssertTrue(aggregator.isActive)

        aggregator.stop()
        XCTAssertFalse(aggregator.isActive)
    }

    @MainActor
    func testAddMessage() async {
        let aggregator = ChatAggregator()
        aggregator.start()

        let message = ChatMessage(
            platform: .youtube,
            username: "testUser",
            text: "Test message",
            timestamp: Date(),
            isModerator: false,
            isSubscriber: false
        )

        aggregator.addMessage(message)

        XCTAssertEqual(aggregator.messages.count, 1)
        XCTAssertEqual(aggregator.messages.first?.text, "Test message")
    }

    @MainActor
    func testModerationBlocksToxicMessages() async {
        let aggregator = ChatAggregator()
        aggregator.moderationEnabled = true
        aggregator.start()

        let toxicMessage = ChatMessage(
            platform: .twitch,
            username: "badUser",
            text: "This is spam content",
            timestamp: Date(),
            isModerator: false,
            isSubscriber: false
        )

        aggregator.addMessage(toxicMessage)

        XCTAssertEqual(aggregator.messages.count, 0)
        XCTAssertEqual(aggregator.toxicMessagesBlocked, 1)
    }

    @MainActor
    func testModerationDisabled() async {
        let aggregator = ChatAggregator()
        aggregator.moderationEnabled = false
        aggregator.start()

        let message = ChatMessage(
            platform: .facebook,
            username: "user",
            text: "This message contains spam word",
            timestamp: Date(),
            isModerator: false,
            isSubscriber: false
        )

        aggregator.addMessage(message)

        // With moderation disabled, message should be added
        XCTAssertEqual(aggregator.messages.count, 1)
    }
}

// MARK: - StreamAnalytics Tests

final class StreamAnalyticsTests: XCTestCase {

    @MainActor
    func testSessionLifecycle() async {
        let analytics = StreamAnalytics()

        analytics.startSession()

        XCTAssertEqual(analytics.currentViewers, 0)
        XCTAssertEqual(analytics.peakViewers, 0)
        XCTAssertEqual(analytics.framesSent, 0)

        analytics.endSession()
    }

    @MainActor
    func testRecordFrame() async {
        let analytics = StreamAnalytics()
        analytics.startSession()

        XCTAssertEqual(analytics.framesSent, 0)

        analytics.recordFrame()
        XCTAssertEqual(analytics.framesSent, 1)

        analytics.recordFrame()
        analytics.recordFrame()
        XCTAssertEqual(analytics.framesSent, 3)
    }

    @MainActor
    func testRecordViewers() async {
        let analytics = StreamAnalytics()
        analytics.startSession()

        analytics.recordViewers(100)
        XCTAssertEqual(analytics.currentViewers, 100)
        XCTAssertEqual(analytics.peakViewers, 100)

        analytics.recordViewers(150)
        XCTAssertEqual(analytics.currentViewers, 150)
        XCTAssertEqual(analytics.peakViewers, 150)

        analytics.recordViewers(120)
        XCTAssertEqual(analytics.currentViewers, 120)
        XCTAssertEqual(analytics.peakViewers, 150) // Peak should remain
    }

    @MainActor
    func testRecordBioData() async {
        let analytics = StreamAnalytics()
        analytics.startSession()

        // Record bio data with coherence > 0.6 (flow state)
        analytics.recordBioData(hrv: 60, coherence: 0.7, heartRate: 70)

        XCTAssertEqual(analytics.timeInFlowState, 1.0)

        // Record bio data with coherence < 0.6 (not flow state)
        analytics.recordBioData(hrv: 50, coherence: 0.4, heartRate: 75)

        XCTAssertEqual(analytics.timeInFlowState, 1.0) // Should not increase
    }

    @MainActor
    func testAveragesAfterSession() async {
        let analytics = StreamAnalytics()
        analytics.startSession()

        // Record some viewer data
        analytics.recordViewers(100)
        analytics.recordViewers(200)
        analytics.recordViewers(150)

        // Record some bio data
        analytics.recordBioData(hrv: 50, coherence: 0.5, heartRate: 70)
        analytics.recordBioData(hrv: 60, coherence: 0.6, heartRate: 72)

        analytics.endSession()

        XCTAssertEqual(analytics.averageViewers, 150.0, accuracy: 0.01)
        XCTAssertEqual(analytics.avgHRV, 55.0, accuracy: 0.01)
        XCTAssertEqual(analytics.avgCoherence, 0.55, accuracy: 0.01)
        XCTAssertEqual(analytics.avgHeartRate, 71.0, accuracy: 0.01)
    }
}
