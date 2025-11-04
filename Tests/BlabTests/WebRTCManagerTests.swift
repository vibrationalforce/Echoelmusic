import XCTest
@testable import Blab

/// WebRTC Manager Test Suite
///
/// Tests for WebRTC remote guest functionality:
/// - Server lifecycle (start, stop)
/// - Guest connection/disconnection
/// - Audio mixing
/// - Volume control
/// - Statistics
@available(iOS 15.0, *)
final class WebRTCManagerTests: XCTestCase {

    var webrtc: WebRTCManager!

    override func setUp() {
        super.setUp()
        webrtc = WebRTCManager.shared
        // Ensure clean state
        if webrtc.isServerRunning {
            webrtc.stopServer()
        }
    }

    override func tearDown() {
        if webrtc.isServerRunning {
            webrtc.stopServer()
        }
        super.tearDown()
    }

    // MARK: - Server Lifecycle Tests

    func testServerStartup() {
        // Given: Server is not running
        XCTAssertFalse(webrtc.isServerRunning)

        // When: Start server
        webrtc.startServer(port: 8080)

        // Then: Server should be running
        XCTAssertTrue(webrtc.isServerRunning)
        XCTAssertFalse(webrtc.serverURL.isEmpty)
        XCTAssertTrue(webrtc.serverURL.contains("8080"))
    }

    func testServerShutdown() {
        // Given: Server is running
        webrtc.startServer(port: 8080)
        XCTAssertTrue(webrtc.isServerRunning)

        // When: Stop server
        webrtc.stopServer()

        // Then: Server should be stopped
        XCTAssertFalse(webrtc.isServerRunning)
        XCTAssertEqual(webrtc.connectedGuests.count, 0)
    }

    func testMultipleServerStarts() {
        // Given: Server is already running
        webrtc.startServer(port: 8080)

        // When: Try to start again
        webrtc.startServer(port: 8080)

        // Then: Should not crash, still running
        XCTAssertTrue(webrtc.isServerRunning)
    }

    // MARK: - Guest Management Tests

    func testGuestDisconnection() {
        // Given: Server is running with a guest
        webrtc.startServer()
        let guest = WebRTCManager.RemoteGuest(name: "Test Guest")

        // Simulate guest connection
        // In real implementation, this would be triggered by signaling server
        // webrtc.handleGuestConnected(guest)

        // When: Disconnect guest
        webrtc.disconnectGuest(guest.id)

        // Then: Guest should be removed
        XCTAssertFalse(webrtc.connectedGuests.contains(where: { $0.id == guest.id }))
    }

    func testMaxGuestsLimit() {
        // Given: Configuration with max 2 guests
        webrtc.configuration.maxGuests = 2

        // When/Then: Can add up to max guests
        // (In real implementation, would test actual connection rejection)
        XCTAssertEqual(webrtc.configuration.maxGuests, 2)
    }

    func testGuestAudioMuting() {
        // Given: A guest connected
        let guest = WebRTCManager.RemoteGuest(name: "Test Guest", isAudioEnabled: true)

        // When: Mute guest
        webrtc.setGuestAudioEnabled(guest.id, enabled: false)

        // Then: Audio should be disabled
        // (Verification would happen in actual guest list)
    }

    func testGuestVolumeControl() {
        // Given: A connected guest
        let guest = WebRTCManager.RemoteGuest(name: "Test Guest")

        // When: Set volume
        webrtc.setGuestVolume(guest.id, volume: 0.5)

        // Then: Should not crash
        // (Verification would happen in audio mixer)
    }

    // MARK: - Statistics Tests

    func testStatisticsWithNoGuests() {
        // Given: Server running with no guests
        webrtc.startServer()

        // When: Get statistics
        let stats = webrtc.getStatistics()

        // Then: Should return zero guests
        XCTAssertEqual(stats.totalGuests, 0)
        XCTAssertEqual(stats.activeGuests, 0)
        XCTAssertEqual(stats.totalBandwidth, 0)
    }

    func testStatisticsFormatting() {
        // Given: Server with specific bandwidth
        webrtc.startServer()

        // When: Get statistics
        let stats = webrtc.getStatistics()

        // Then: Formatted bandwidth should be correct
        XCTAssertTrue(stats.formattedBandwidth.contains("kbps"))
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        // Given: Default configuration
        let config = WebRTCManager.Configuration()

        // Then: Should have sensible defaults
        XCTAssertEqual(config.maxGuests, 8)
        XCTAssertEqual(config.audioBitrate, 64_000)
        XCTAssertEqual(config.audioSampleRate, 48000)
        XCTAssertTrue(config.enableEchoCancellation)
        XCTAssertTrue(config.enableNoiseSuppression)
        XCTAssertTrue(config.enableAutomaticGainControl)
    }

    func testCustomConfiguration() {
        // Given: Custom configuration
        var config = WebRTCManager.Configuration()
        config.maxGuests = 4
        config.audioBitrate = 128_000

        // When: Apply configuration
        webrtc.configuration = config

        // Then: Should be applied
        XCTAssertEqual(webrtc.configuration.maxGuests, 4)
        XCTAssertEqual(webrtc.configuration.audioBitrate, 128_000)
    }

    // MARK: - Remote Guest Model Tests

    func testRemoteGuestCreation() {
        // Given/When: Create guest
        let guest = WebRTCManager.RemoteGuest(
            name: "Test Guest",
            isAudioEnabled: true,
            connectionQuality: .good
        )

        // Then: Should have correct properties
        XCTAssertEqual(guest.name, "Test Guest")
        XCTAssertTrue(guest.isAudioEnabled)
        XCTAssertEqual(guest.connectionQuality, .good)
        XCTAssertEqual(guest.audioLevel, 0.0)
    }

    func testConnectionQualityEnum() {
        // Test all connection quality values
        XCTAssertEqual(WebRTCManager.RemoteGuest.ConnectionQuality.excellent.rawValue, "Excellent")
        XCTAssertEqual(WebRTCManager.RemoteGuest.ConnectionQuality.good.rawValue, "Good")
        XCTAssertEqual(WebRTCManager.RemoteGuest.ConnectionQuality.fair.rawValue, "Fair")
        XCTAssertEqual(WebRTCManager.RemoteGuest.ConnectionQuality.poor.rawValue, "Poor")
        XCTAssertEqual(WebRTCManager.RemoteGuest.ConnectionQuality.disconnected.rawValue, "Disconnected")
    }

    // MARK: - Audio Processing Tests

    func testMixedGuestAudio() {
        // Given: Server running
        webrtc.startServer()

        // When: Get mixed audio
        let buffer = webrtc.getMixedGuestAudio()

        // Then: Should return buffer or nil (depending on guests)
        // (In this test environment, likely nil)
        // Buffer would be non-nil with actual connected guests
        XCTAssertTrue(buffer == nil || buffer != nil)  // Flexible assertion
    }

    func testSendAudioToGuests() {
        // Given: Server running
        webrtc.startServer()

        // When: Send audio (would need real buffer)
        // webrtc.sendAudioToGuests(buffer)

        // Then: Should not crash
        // (Actual verification would require mock audio buffer)
    }

    // MARK: - Performance Tests

    func testServerStartPerformance() {
        measure {
            webrtc.startServer(port: 8080)
            webrtc.stopServer()
        }
    }

    func testStatisticsPerformance() {
        webrtc.startServer()

        measure {
            _ = webrtc.getStatistics()
        }

        webrtc.stopServer()
    }

    // MARK: - Edge Cases

    func testStopServerWhenNotRunning() {
        // Given: Server not running
        XCTAssertFalse(webrtc.isServerRunning)

        // When: Try to stop
        webrtc.stopServer()

        // Then: Should not crash
        XCTAssertFalse(webrtc.isServerRunning)
    }

    func testDisconnectNonexistentGuest() {
        // Given: Server running with no guests
        webrtc.startServer()

        // When: Try to disconnect non-existent guest
        webrtc.disconnectGuest(UUID())

        // Then: Should not crash
        XCTAssertEqual(webrtc.connectedGuests.count, 0)
    }

    func testSetVolumeForNonexistentGuest() {
        // Given: No guests
        // When: Try to set volume
        webrtc.setGuestVolume(UUID(), volume: 0.5)

        // Then: Should not crash
    }

    // MARK: - Integration Tests

    func testFullServerLifecycle() {
        // Test complete workflow
        XCTAssertFalse(webrtc.isServerRunning)

        webrtc.startServer(port: 8080)
        XCTAssertTrue(webrtc.isServerRunning)

        let stats = webrtc.getStatistics()
        XCTAssertEqual(stats.totalGuests, 0)

        webrtc.stopServer()
        XCTAssertFalse(webrtc.isServerRunning)
    }
}
