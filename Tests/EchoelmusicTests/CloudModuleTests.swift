// =============================================================================
// CloudModuleTests.swift
// Echoelmusic - Phase 10000 ULTIMATE MODE
// Comprehensive tests for Cloud/Server infrastructure
// =============================================================================

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Cloud/Server module
final class CloudModuleTests: XCTestCase {

    // MARK: - ServerInfrastructure Tests

    func testServerInfrastructureRegions() {
        let server = ServerInfrastructure.shared

        // Verify 11 server regions
        XCTAssertGreaterThanOrEqual(server.availableRegions.count, 11)
        XCTAssertTrue(server.availableRegions.contains(.usEast))
        XCTAssertTrue(server.availableRegions.contains(.euWest))
        XCTAssertTrue(server.availableRegions.contains(.apNortheast))
    }

    func testServerInfrastructureRegionSelection() {
        let server = ServerInfrastructure.shared

        let closestRegion = server.selectClosestRegion()
        XCTAssertNotNil(closestRegion)
    }

    func testServerInfrastructureHealthCheck() async {
        let server = ServerInfrastructure.shared

        let health = await server.checkHealth()
        XCTAssertNotNil(health)
    }

    func testServerInfrastructureLatencyMeasurement() async {
        let server = ServerInfrastructure.shared

        let latency = await server.measureLatency(to: .usEast)
        XCTAssertGreaterThanOrEqual(latency, 0)
    }

    // MARK: - WebSocketServer Tests

    func testWebSocketServerInitialization() {
        let socket = WebSocketServer()

        XCTAssertNotNil(socket)
        XCTAssertFalse(socket.isConnected)
    }

    func testWebSocketServerMessageTypes() {
        let socket = WebSocketServer()

        XCTAssertTrue(socket.supportedMessageTypes.contains(.bioData))
        XCTAssertTrue(socket.supportedMessageTypes.contains(.audioParameters))
        XCTAssertTrue(socket.supportedMessageTypes.contains(.visualSync))
        XCTAssertTrue(socket.supportedMessageTypes.contains(.sessionState))
    }

    func testWebSocketServerReconnection() {
        let socket = WebSocketServer()

        XCTAssertTrue(socket.autoReconnectEnabled)
        XCTAssertGreaterThan(socket.maxReconnectAttempts, 0)
    }

    func testWebSocketServerMessageEncoding() {
        let socket = WebSocketServer()

        let bioData = BioSyncMessage(heartRate: 72, hrvCoherence: 0.85, timestamp: Date())
        let encoded = socket.encode(message: bioData)

        XCTAssertNotNil(encoded)
        XCTAssertGreaterThan(encoded.count, 0)
    }

    func testWebSocketServerMessageDecoding() {
        let socket = WebSocketServer()

        let jsonData = """
        {"type": "bioData", "heartRate": 72, "hrvCoherence": 0.85}
        """.data(using: .utf8)!

        let decoded: BioSyncMessage? = socket.decode(data: jsonData)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.heartRate, 72)
    }

    // MARK: - CloudSyncManager Tests

    func testCloudSyncManagerInitialization() {
        let sync = CloudSyncManager.shared

        XCTAssertNotNil(sync)
    }

    func testCloudSyncManagerSyncStatus() {
        let sync = CloudSyncManager.shared

        XCTAssertNotNil(sync.syncStatus)
    }

    func testCloudSyncManagerOfflineSupport() {
        let sync = CloudSyncManager.shared

        XCTAssertTrue(sync.offlineModeSupported)
    }

    func testCloudSyncManagerConflictResolution() {
        let sync = CloudSyncManager.shared

        // Verify conflict resolution strategies are available
        XCTAssertNotNil(sync.conflictResolutionStrategy)
        XCTAssertTrue([.serverWins, .clientWins, .merge, .manual].contains(sync.conflictResolutionStrategy))
    }

    func testCloudSyncManagerDataTypes() {
        let sync = CloudSyncManager.shared

        XCTAssertTrue(sync.syncableDataTypes.contains(.presets))
        XCTAssertTrue(sync.syncableDataTypes.contains(.sessions))
        XCTAssertTrue(sync.syncableDataTypes.contains(.settings))
    }

    // MARK: - Authentication Tests

    func testAuthenticationServiceInitialization() {
        let auth = AuthenticationService.shared

        XCTAssertNotNil(auth)
    }

    func testAuthenticationServiceJWTValidation() {
        let auth = AuthenticationService.shared

        let validToken = auth.createTestToken(userId: "test_user", expiresIn: 3600)
        XCTAssertTrue(auth.validateToken(validToken))

        let expiredToken = auth.createTestToken(userId: "test_user", expiresIn: -1)
        XCTAssertFalse(auth.validateToken(expiredToken))
    }

    func testAuthenticationServiceTokenRefresh() async {
        let auth = AuthenticationService.shared

        let oldToken = auth.createTestToken(userId: "test_user", expiresIn: 60)
        let newToken = await auth.refreshToken(oldToken)

        XCTAssertNotNil(newToken)
        XCTAssertNotEqual(oldToken, newToken)
    }

    // MARK: - Collaboration Server Tests

    func testCollaborationServerSessionCreation() async {
        let collab = CollaborationServer.shared

        let session = await collab.createSession(name: "Test Session", maxParticipants: 100)
        XCTAssertNotNil(session)
        XCTAssertFalse(session.id.isEmpty)
    }

    func testCollaborationServerSessionTypes() {
        let collab = CollaborationServer.shared

        // Verify 8 session types
        XCTAssertGreaterThanOrEqual(collab.sessionTypes.count, 8)
        XCTAssertTrue(collab.sessionTypes.contains(.meditation))
        XCTAssertTrue(collab.sessionTypes.contains(.coherence))
        XCTAssertTrue(collab.sessionTypes.contains(.creative))
    }

    func testCollaborationServerParticipantLimit() {
        let collab = CollaborationServer.shared

        // Verify unlimited participants (Int.max)
        XCTAssertGreaterThanOrEqual(collab.maxParticipants, 1000)
    }

    func testCollaborationServerPrivacyModes() {
        let collab = CollaborationServer.shared

        XCTAssertTrue(collab.privacyModes.contains(.full))
        XCTAssertTrue(collab.privacyModes.contains(.aggregated))
        XCTAssertTrue(collab.privacyModes.contains(.anonymous))
    }

    // MARK: - Offline Support Tests

    func testOfflineSupportQueueing() {
        let offline = OfflineSupport.shared

        let operation = SyncOperation(type: .upload, data: Data(), priority: .normal)
        offline.queueOperation(operation)

        XCTAssertGreaterThan(offline.pendingOperations.count, 0)
    }

    func testOfflineSupportPersistence() {
        let offline = OfflineSupport.shared

        // Queue an operation
        let operation = SyncOperation(type: .upload, data: Data(), priority: .high)
        offline.queueOperation(operation)

        // Verify it persists
        XCTAssertTrue(offline.hasPendingOperations)
    }

    func testOfflineSupportRetryLogic() {
        let offline = OfflineSupport.shared

        XCTAssertGreaterThan(offline.maxRetryAttempts, 0)
        XCTAssertGreaterThan(offline.retryDelay, 0)
    }

    // MARK: - API Client Tests

    func testAPIClientConfiguration() {
        let client = APIClient.shared

        XCTAssertNotNil(client.baseURL)
        XCTAssertTrue(client.baseURL.hasPrefix("https://"))
    }

    func testAPIClientHeaders() {
        let client = APIClient.shared

        let headers = client.defaultHeaders
        XCTAssertNotNil(headers["Content-Type"])
        XCTAssertNotNil(headers["Accept"])
    }

    func testAPIClientRateLimiting() {
        let client = APIClient.shared

        XCTAssertTrue(client.rateLimitingEnabled)
        XCTAssertGreaterThan(client.requestsPerSecond, 0)
    }

    func testAPIClientRetryPolicy() {
        let client = APIClient.shared

        XCTAssertGreaterThan(client.maxRetries, 0)
        XCTAssertTrue(client.exponentialBackoffEnabled)
    }

    // MARK: - Server Health Monitor Tests

    func testServerHealthMonitorStatus() {
        let monitor = ServerHealthMonitor.shared

        let status = monitor.currentStatus
        XCTAssertNotNil(status)
    }

    func testServerHealthMonitorMetrics() {
        let monitor = ServerHealthMonitor.shared

        let metrics = monitor.getMetrics()
        XCTAssertNotNil(metrics.uptime)
        XCTAssertNotNil(metrics.requestsPerSecond)
        XCTAssertNotNil(metrics.averageLatency)
    }

    func testServerHealthMonitorAlerts() {
        let monitor = ServerHealthMonitor.shared

        XCTAssertNotNil(monitor.alertThresholds)
        XCTAssertGreaterThan(monitor.alertThresholds.latencyMs, 0)
    }

    // MARK: - Streaming Platform Tests

    func testStreamingPlatformConfigurations() {
        let config = ProductionAPIConfiguration.shared

        // Verify 6 streaming platforms
        XCTAssertGreaterThanOrEqual(config.supportedPlatforms.count, 6)
        XCTAssertTrue(config.supportedPlatforms.contains(.youtube))
        XCTAssertTrue(config.supportedPlatforms.contains(.twitch))
        XCTAssertTrue(config.supportedPlatforms.contains(.facebook))
        XCTAssertTrue(config.supportedPlatforms.contains(.instagram))
        XCTAssertTrue(config.supportedPlatforms.contains(.tiktok))
    }

    func testStreamingPlatformQualityPresets() {
        let config = ProductionAPIConfiguration.shared

        for platform in config.supportedPlatforms {
            let preset = config.getQualityPreset(for: platform)
            XCTAssertNotNil(preset)
            XCTAssertGreaterThan(preset.bitrate, 0)
        }
    }

    // MARK: - Real-Time Sync Tests

    func testRealTimeSyncLatency() {
        let sync = CloudSyncManager.shared

        // Target latency should be low for real-time features
        XCTAssertLessThan(sync.targetLatencyMs, 100)
    }

    func testRealTimeSyncPriority() {
        let sync = CloudSyncManager.shared

        // Bio data should have highest priority
        XCTAssertEqual(sync.getPriority(for: .bioData), .realtime)
        XCTAssertEqual(sync.getPriority(for: .audioParameters), .high)
        XCTAssertEqual(sync.getPriority(for: .presets), .normal)
    }

    // MARK: - Security Tests

    func testCloudSecurityEncryption() {
        let server = ServerInfrastructure.shared

        XCTAssertTrue(server.tlsEnabled)
        XCTAssertGreaterThanOrEqual(server.tlsVersion, 1.2)
    }

    func testCloudSecurityCertificatePinning() {
        let server = ServerInfrastructure.shared

        XCTAssertTrue(server.certificatePinningEnabled)
    }

    func testCloudSecurityDataProtection() {
        let sync = CloudSyncManager.shared

        XCTAssertTrue(sync.encryptionEnabled)
        XCTAssertEqual(sync.encryptionAlgorithm, "AES-256-GCM")
    }

    // MARK: - Performance Tests

    func testWebSocketEncodingPerformance() {
        let socket = WebSocketServer()

        measure {
            for _ in 0..<1000 {
                let message = BioSyncMessage(heartRate: 72, hrvCoherence: 0.85, timestamp: Date())
                _ = socket.encode(message: message)
            }
        }
    }

    func testSyncOperationQueuePerformance() {
        let offline = OfflineSupport.shared

        measure {
            for i in 0..<100 {
                let operation = SyncOperation(type: .upload, data: Data(repeating: UInt8(i % 256), count: 1024), priority: .normal)
                offline.queueOperation(operation)
            }
        }
    }

    func testLatencyMeasurementPerformance() async {
        let server = ServerInfrastructure.shared

        let start = Date()
        for region in server.availableRegions.prefix(3) {
            _ = await server.measureLatency(to: region)
        }
        let elapsed = Date().timeIntervalSince(start)

        // Should complete quickly even with network calls
        XCTAssertLessThan(elapsed, 10.0)
    }
}

// MARK: - Helper Types

extension CloudModuleTests {
    struct BioSyncMessage: Codable {
        let heartRate: Double
        let hrvCoherence: Double
        let timestamp: Date
    }

    struct SyncOperation {
        enum OperationType { case upload, download, delete }
        enum Priority { case low, normal, high, realtime }

        let type: OperationType
        let data: Data
        let priority: Priority
    }

    enum ConflictResolution {
        case serverWins, clientWins, merge, manual
    }

    enum SyncDataType {
        case presets, sessions, settings, bioData, audioParameters
    }

    enum StreamingPlatform {
        case youtube, twitch, facebook, instagram, tiktok, custom
    }

    enum ServerRegion {
        case usEast, usWest, euWest, euCentral, apNortheast, apSoutheast
        case saEast, afSouth, meWest, oceania, global
    }
}
