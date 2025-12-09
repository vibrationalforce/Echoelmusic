import XCTest
import AVFoundation
import Metal
@testable import Echoelmusic

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING PIPELINE INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// End-to-end tests for the streaming pipeline:
// • Scene rendering pipeline
// • Encoding flow
// • Chat aggregation
// • Analytics collection
// • Multi-destination streaming
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class StreamingIntegrationTests: XCTestCase {

    // MARK: - Scene Management Tests

    func testSceneCreation() throws {
        // Test basic scene structure
        let scene = Scene(
            id: UUID(),
            name: "Test Scene",
            layers: [],
            backgroundColor: .black
        )

        XCTAssertEqual(scene.name, "Test Scene")
        XCTAssertTrue(scene.layers.isEmpty)
    }

    func testSceneLayerOrdering() throws {
        var scene = Scene(
            id: UUID(),
            name: "Layered Scene",
            layers: [],
            backgroundColor: .black
        )

        // Add layers with different z-indices
        let layer1 = SceneLayer(
            id: UUID(),
            name: "Background",
            type: .image(URL(fileURLWithPath: "/bg.png")),
            zIndex: 0,
            isVisible: true
        )

        let layer2 = SceneLayer(
            id: UUID(),
            name: "Overlay",
            type: .text(TextLayerConfig(text: "Test", fontSize: 24)),
            zIndex: 10,
            isVisible: true
        )

        let layer3 = SceneLayer(
            id: UUID(),
            name: "Midground",
            type: .image(URL(fileURLWithPath: "/mid.png")),
            zIndex: 5,
            isVisible: true
        )

        scene.layers = [layer1, layer2, layer3]

        // Sort layers
        let sorted = scene.layers.sorted { $0.zIndex < $1.zIndex }

        XCTAssertEqual(sorted[0].name, "Background", "First layer should be background (z=0)")
        XCTAssertEqual(sorted[1].name, "Midground", "Second layer should be midground (z=5)")
        XCTAssertEqual(sorted[2].name, "Overlay", "Third layer should be overlay (z=10)")
    }

    // MARK: - Encoding Configuration Tests

    func testEncodingResolutions() {
        // Test all resolution presets
        let resolutions: [(StreamEngine.Resolution, CGSize)] = [
            (.hd1280x720, CGSize(width: 1280, height: 720)),
            (.hd1920x1080, CGSize(width: 1920, height: 1080)),
            (.uhd3840x2160, CGSize(width: 3840, height: 2160))
        ]

        for (resolution, expectedSize) in resolutions {
            XCTAssertEqual(resolution.size, expectedSize,
                          "\(resolution.rawValue) should have correct size")
        }
    }

    func testBitrateRecommendations() {
        // Test bitrate recommendations are reasonable
        XCTAssertEqual(StreamEngine.Resolution.hd1280x720.recommendedBitrate, 3500,
                      "720p should recommend 3500 kbps")
        XCTAssertEqual(StreamEngine.Resolution.hd1920x1080.recommendedBitrate, 6000,
                      "1080p should recommend 6000 kbps")
        XCTAssertEqual(StreamEngine.Resolution.uhd3840x2160.recommendedBitrate, 12000,
                      "4K should recommend 12000 kbps")
    }

    // MARK: - Stream Destination Tests

    func testStreamDestinationURLs() {
        XCTAssertTrue(StreamEngine.StreamDestination.twitch.rtmpURL.contains("twitch"),
                     "Twitch URL should contain 'twitch'")
        XCTAssertTrue(StreamEngine.StreamDestination.youtube.rtmpURL.contains("youtube"),
                     "YouTube URL should contain 'youtube'")
        XCTAssertTrue(StreamEngine.StreamDestination.facebook.rtmpURL.contains("facebook"),
                     "Facebook URL should contain 'facebook'")
    }

    func testStreamDestinationPorts() {
        XCTAssertEqual(StreamEngine.StreamDestination.twitch.defaultPort, 1935,
                      "Twitch should use port 1935")
        XCTAssertEqual(StreamEngine.StreamDestination.youtube.defaultPort, 1935,
                      "YouTube should use port 1935")
        XCTAssertEqual(StreamEngine.StreamDestination.facebook.defaultPort, 443,
                      "Facebook should use port 443 (RTMPS)")
    }

    // MARK: - Stream Status Tests

    func testStreamStatusTracking() {
        var status = StreamEngine.StreamStatus(
            isConnected: true,
            framesSent: 0,
            bytesTransferred: 0,
            currentBitrate: 6000,
            packetLoss: 0.0,
            error: nil
        )

        // Simulate streaming
        status.framesSent += 1800 // 1 minute at 30fps
        status.bytesTransferred += 45_000_000 // ~6 Mbps for 1 min

        XCTAssertTrue(status.isConnected)
        XCTAssertEqual(status.framesSent, 1800)
        XCTAssertEqual(status.bytesTransferred, 45_000_000)
        XCTAssertNil(status.error)
    }

    // MARK: - Chat Moderation Tests

    func testModerationCategories() {
        // Test all moderation categories have thresholds
        for category in AIContentModerator.ModerationCategory.allCases {
            XCTAssertGreaterThan(category.threshold, 0, "\(category) should have positive threshold")
            XCTAssertLessThanOrEqual(category.threshold, 1, "\(category) threshold should be <= 1")
        }
    }

    func testModerationSensitivity() {
        // Test sensitivity multipliers
        XCTAssertLessThan(AIContentModerator.ModerationSensitivity.relaxed.multiplier, 1.0,
                         "Relaxed should have multiplier < 1")
        XCTAssertEqual(AIContentModerator.ModerationSensitivity.balanced.multiplier, 1.0,
                      "Balanced should have multiplier = 1")
        XCTAssertGreaterThan(AIContentModerator.ModerationSensitivity.strict.multiplier, 1.0,
                            "Strict should have multiplier > 1")
        XCTAssertGreaterThan(AIContentModerator.ModerationSensitivity.maximum.multiplier,
                            AIContentModerator.ModerationSensitivity.strict.multiplier,
                            "Maximum should be stricter than strict")
    }

    // MARK: - Analytics Tests

    func testStreamAnalyticsInitialization() {
        let analytics = StreamAnalytics()

        // Initial state
        XCTAssertFalse(analytics.isRecording, "Should not be recording initially")
        XCTAssertEqual(analytics.peakViewers, 0, "Peak viewers should start at 0")
    }

    // MARK: - RTMP Protocol Tests

    func testRTMPClientConfiguration() {
        let client = RTMPClient(
            url: "rtmp://test.server.com/live",
            streamKey: "test-key-12345",
            port: 1935
        )

        XCTAssertNotNil(client, "RTMP client should initialize")
    }

    // MARK: - Bio-Reactive Scene Tests

    func testBioReactiveSceneTransition() {
        // Test coherence-based scene selection
        let lowCoherenceScene = "Calming"
        let highCoherenceScene = "Energetic"

        func selectScene(coherence: Float) -> String {
            coherence > 0.6 ? highCoherenceScene : lowCoherenceScene
        }

        XCTAssertEqual(selectScene(coherence: 0.3), lowCoherenceScene)
        XCTAssertEqual(selectScene(coherence: 0.8), highCoherenceScene)
    }
}

// MARK: - Supporting Types for Tests

struct Scene {
    let id: UUID
    var name: String
    var layers: [SceneLayer]
    var backgroundColor: SceneColor

    enum SceneColor {
        case black, white, custom(r: Float, g: Float, b: Float)
    }
}

struct SceneLayer {
    let id: UUID
    var name: String
    var type: LayerType
    var zIndex: Int
    var isVisible: Bool

    enum LayerType {
        case image(URL)
        case text(TextLayerConfig)
        case video(URL)
        case browser(URL)
    }
}

struct TextLayerConfig {
    var text: String
    var fontSize: CGFloat
    var fontName: String = "Helvetica"
    var color: (r: Float, g: Float, b: Float, a: Float) = (1, 1, 1, 1)
}
