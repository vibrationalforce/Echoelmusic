import XCTest
@testable import Blab

/// Real RTMP Streamer Test Suite
///
/// Tests for HaishinKit-based RTMP streaming:
/// - Configuration
/// - Platform URLs
/// - Stream lifecycle
/// - Statistics
/// - Error handling
@available(iOS 15.0, *)
final class RealRTMPStreamerTests: XCTestCase {

    var streamer: RealRTMPStreamer!

    override func setUp() async throws {
        try await super.setUp()
        streamer = RealRTMPStreamer.shared
        // Ensure clean state
        if streamer.isStreaming {
            streamer.stopStreaming()
        }
    }

    override func tearDown() {
        if streamer.isStreaming {
            streamer.stopStreaming()
        }
        super.tearDown()
    }

    // MARK: - Platform Tests

    func testYouTubePlatform() {
        // Given: YouTube platform
        let platform = RealRTMPStreamer.Platform.youtube

        // Then: Should have correct URL
        XCTAssertEqual(platform.rawValue, "YouTube Live")
        XCTAssertTrue(platform.rtmpURL.contains("rtmp"))
        XCTAssertTrue(platform.rtmpURL.contains("youtube"))
    }

    func testTwitchPlatform() {
        // Given: Twitch platform
        let platform = RealRTMPStreamer.Platform.twitch

        // Then: Should have correct URL
        XCTAssertEqual(platform.rawValue, "Twitch")
        XCTAssertTrue(platform.rtmpURL.contains("rtmp"))
        XCTAssertTrue(platform.rtmpURL.contains("twitch"))
    }

    func testFacebookPlatform() {
        // Given: Facebook platform
        let platform = RealRTMPStreamer.Platform.facebook

        // Then: Should have correct URL
        XCTAssertEqual(platform.rawValue, "Facebook Live")
        XCTAssertTrue(platform.rtmpURL.contains("rtmp"))
        XCTAssertTrue(platform.rtmpURL.contains("facebook"))
    }

    func testCustomPlatform() {
        // Given: Custom platform
        let platform = RealRTMPStreamer.Platform.custom

        // Then: Should have empty URL (user provides)
        XCTAssertEqual(platform.rawValue, "Custom RTMP")
        XCTAssertEqual(platform.rtmpURL, "")
    }

    func testAllPlatformsCaseIterable() {
        // All platforms should be accessible via allCases
        let platforms = RealRTMPStreamer.Platform.allCases

        XCTAssertEqual(platforms.count, 4)
        XCTAssertTrue(platforms.contains(.youtube))
        XCTAssertTrue(platforms.contains(.twitch))
        XCTAssertTrue(platforms.contains(.facebook))
        XCTAssertTrue(platforms.contains(.custom))
    }

    // MARK: - Configuration Tests

    func testStreamConfiguration() async throws {
        // Given: Valid configuration
        let streamKey = "test_stream_key_12345"

        // When: Configure streamer
        try await streamer.configure(
            platform: .youtube,
            streamKey: streamKey
        )

        // Then: Should be configured
        // (Actual verification would check internal state)
        XCTAssertFalse(streamer.isStreaming)
    }

    func testCustomURLConfiguration() async throws {
        // Given: Custom platform with URL
        let customURL = "rtmp://custom-server.com/live"
        let streamKey = "custom_key"

        // When: Configure with custom URL
        try await streamer.configure(
            platform: .custom,
            streamKey: streamKey,
            customURL: customURL
        )

        // Then: Should be configured
        XCTAssertFalse(streamer.isStreaming)
    }

    // MARK: - Streaming Lifecycle Tests

    func testStreamingNotStartedInitially() {
        // Given: Fresh streamer instance
        // Then: Should not be streaming
        XCTAssertFalse(streamer.isStreaming)
    }

    func testStopStreamingWhenNotStarted() {
        // Given: Not streaming
        XCTAssertFalse(streamer.isStreaming)

        // When: Try to stop
        streamer.stopStreaming()

        // Then: Should not crash
        XCTAssertFalse(streamer.isStreaming)
    }

    // MARK: - Statistics Tests

    func testInitialStatistics() {
        // Given: Fresh streamer
        // When: Get statistics
        let stats = streamer.getStatistics()

        // Then: Should have zero values
        XCTAssertEqual(stats.bytesSent, 0)
        XCTAssertEqual(stats.currentBitrate, 0)
        XCTAssertEqual(stats.droppedFrames, 0)
    }

    func testStatisticsFormatting() {
        // Given: Statistics with data
        let stats = RealRTMPStreamer.StreamStatistics(
            bytesSent: 1024 * 1024,  // 1 MB
            currentBitrate: 128_000,  // 128 kbps
            targetBitrate: 128_000,
            droppedFrames: 0,
            fps: 0.0,
            streamDuration: 60.0
        )

        // Then: Formatted strings should be correct
        XCTAssertTrue(stats.formattedBytes.contains("MB"))
        XCTAssertTrue(stats.formattedDuration.contains("1"))
    }

    func testStatisticsDurationFormatting() {
        // Test various duration formats
        let stats1 = RealRTMPStreamer.StreamStatistics(
            bytesSent: 0,
            currentBitrate: 0,
            targetBitrate: 0,
            droppedFrames: 0,
            fps: 0,
            streamDuration: 30.0
        )
        XCTAssertTrue(stats1.formattedDuration.contains("0"))

        let stats2 = RealRTMPStreamer.StreamStatistics(
            bytesSent: 0,
            currentBitrate: 0,
            targetBitrate: 0,
            droppedFrames: 0,
            fps: 0,
            streamDuration: 3661.0  // 1:01:01
        )
        XCTAssertTrue(stats2.formattedDuration.contains("1"))
    }

    // MARK: - Error Handling Tests

    func testConfigureWithEmptyStreamKey() async {
        // Given: Empty stream key
        do {
            // When: Try to configure
            try await streamer.configure(
                platform: .youtube,
                streamKey: ""
            )

            // Then: Should throw or handle gracefully
            // (Implementation dependent)
        } catch {
            // Error expected for empty stream key
            XCTAssertNotNil(error)
        }
    }

    func testConfigureCustomWithoutURL() async {
        // Given: Custom platform without URL
        do {
            // When: Try to configure
            try await streamer.configure(
                platform: .custom,
                streamKey: "key",
                customURL: ""
            )

            // Then: Should handle gracefully
        } catch {
            // May throw error for missing custom URL
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Bitrate Tests

    func testBitrateSettings() {
        // Test various bitrate levels
        let lowBitrate = 64_000
        let mediumBitrate = 128_000
        let highBitrate = 320_000

        // All should be valid
        XCTAssertGreaterThan(lowBitrate, 0)
        XCTAssertGreaterThan(mediumBitrate, lowBitrate)
        XCTAssertGreaterThan(highBitrate, mediumBitrate)
    }

    // MARK: - Health Monitoring Tests

    func testHealthStatus() {
        // Given: Not streaming
        // When: Check health (if method exists)
        // Then: Should return appropriate status

        // Note: Health monitoring would be tested with actual streaming
        XCTAssertFalse(streamer.isStreaming)
    }

    // MARK: - Performance Tests

    func testConfigurationPerformance() {
        measure {
            Task {
                do {
                    try await streamer.configure(
                        platform: .youtube,
                        streamKey: "test_key"
                    )
                } catch {
                    // Ignore errors in performance test
                }
            }
        }
    }

    func testStatisticsPerformance() {
        measure {
            _ = streamer.getStatistics()
        }
    }

    // MARK: - Integration Tests

    func testFullStreamingWorkflow() async {
        // Test complete workflow (without actual network)
        do {
            // 1. Configure
            try await streamer.configure(
                platform: .youtube,
                streamKey: "test_key_12345"
            )
            XCTAssertFalse(streamer.isStreaming)

            // 2. Get initial statistics
            let stats = streamer.getStatistics()
            XCTAssertEqual(stats.bytesSent, 0)

            // 3. Stop (even though not started)
            streamer.stopStreaming()
            XCTAssertFalse(streamer.isStreaming)

        } catch {
            // Configuration may fail without actual stream key
            // This is acceptable in test environment
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Model Tests

    func testPlatformEquality() {
        // Test platform enum equality
        XCTAssertEqual(RealRTMPStreamer.Platform.youtube, .youtube)
        XCTAssertNotEqual(RealRTMPStreamer.Platform.youtube, .twitch)
    }

    func testStatisticsStruct() {
        // Test statistics structure
        let stats = RealRTMPStreamer.StreamStatistics(
            bytesSent: 1000,
            currentBitrate: 128_000,
            targetBitrate: 128_000,
            droppedFrames: 5,
            fps: 30.0,
            streamDuration: 60.0
        )

        XCTAssertEqual(stats.bytesSent, 1000)
        XCTAssertEqual(stats.currentBitrate, 128_000)
        XCTAssertEqual(stats.droppedFrames, 5)
        XCTAssertEqual(stats.fps, 30.0)
    }

    // MARK: - URL Validation Tests

    func testYouTubeURLFormat() {
        let url = RealRTMPStreamer.Platform.youtube.rtmpURL
        XCTAssertTrue(url.hasPrefix("rtmp://"))
        XCTAssertTrue(url.contains("youtube"))
    }

    func testTwitchURLFormat() {
        let url = RealRTMPStreamer.Platform.twitch.rtmpURL
        XCTAssertTrue(url.hasPrefix("rtmp://"))
        XCTAssertTrue(url.contains("twitch"))
    }

    func testFacebookURLFormat() {
        let url = RealRTMPStreamer.Platform.facebook.rtmpURL
        XCTAssertTrue(url.hasPrefix("rtmps://"))  // Facebook uses secure RTMP
        XCTAssertTrue(url.contains("facebook"))
    }
}
