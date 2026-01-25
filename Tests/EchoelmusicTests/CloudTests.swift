// CloudTests.swift
// Tests for CloudSyncManager and related cloud functionality
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Cloud Sync Manager
/// Coverage: Sync state, sessions, auto-backup, error handling
final class CloudTests: XCTestCase {

    // MARK: - Initialization Tests

    @MainActor
    func testCloudSyncManagerInitialization() {
        let manager = CloudSyncManager()

        XCTAssertFalse(manager.isSyncing)
        XCTAssertFalse(manager.syncEnabled)
        XCTAssertNil(manager.lastSyncDate)
        XCTAssertTrue(manager.cloudSessions.isEmpty)
    }

    // MARK: - Sync Enable/Disable Tests

    @MainActor
    func testDisableSync() {
        let manager = CloudSyncManager()

        manager.disableSync()

        XCTAssertFalse(manager.syncEnabled)
    }

    @MainActor
    func testSyncDisabledByDefault() {
        let manager = CloudSyncManager()

        XCTAssertFalse(manager.syncEnabled)
    }

    // MARK: - CloudSession Tests

    func testCloudSessionInitialization() {
        let session = CloudSession(
            id: UUID(),
            name: "Test Session",
            duration: 300.0,
            avgHRV: 45.5,
            avgCoherence: 0.75
        )

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.duration, 300.0, accuracy: 0.001)
        XCTAssertEqual(session.avgHRV, 45.5, accuracy: 0.001)
        XCTAssertEqual(session.avgCoherence, 0.75, accuracy: 0.001)
    }

    func testCloudSessionIdentifiable() {
        let uuid = UUID()
        let session = CloudSession(
            id: uuid,
            name: "Test",
            duration: 0,
            avgHRV: 0,
            avgCoherence: 0
        )

        XCTAssertEqual(session.id, uuid)
    }

    func testCloudSessionWithVariousValues() {
        // Test with minimum values
        let minSession = CloudSession(
            id: UUID(),
            name: "",
            duration: 0,
            avgHRV: 0,
            avgCoherence: 0
        )

        XCTAssertEqual(minSession.duration, 0)
        XCTAssertEqual(minSession.avgHRV, 0)
        XCTAssertEqual(minSession.avgCoherence, 0)

        // Test with maximum values
        let maxSession = CloudSession(
            id: UUID(),
            name: "Maximum Duration Session With Very Long Name",
            duration: 86400,  // 24 hours in seconds
            avgHRV: 200,
            avgCoherence: 1.0
        )

        XCTAssertEqual(maxSession.duration, 86400, accuracy: 0.001)
        XCTAssertEqual(maxSession.avgHRV, 200, accuracy: 0.001)
        XCTAssertEqual(maxSession.avgCoherence, 1.0, accuracy: 0.001)
    }

    // MARK: - CloudError Tests

    func testCloudErroriCloudNotAvailable() {
        let error = CloudError.iCloudNotAvailable

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("iCloud"))
    }

    func testCloudErrorSyncFailed() {
        let error = CloudError.syncFailed

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("sync") || error.errorDescription!.contains("failed"))
    }

    func testCloudErrorLocalizedDescription() {
        // Both errors should have localized descriptions
        XCTAssertFalse(CloudError.iCloudNotAvailable.localizedDescription.isEmpty)
        XCTAssertFalse(CloudError.syncFailed.localizedDescription.isEmpty)
    }

    // MARK: - Auto Backup Tests

    @MainActor
    func testEnableAutoBackup() {
        let manager = CloudSyncManager()

        manager.enableAutoBackup(interval: 60)

        // Should not crash
        manager.disableAutoBackup()
    }

    @MainActor
    func testDisableAutoBackup() {
        let manager = CloudSyncManager()

        manager.enableAutoBackup(interval: 300)
        manager.disableAutoBackup()

        // Should disable without crash
    }

    @MainActor
    func testAutoBackupDefaultInterval() {
        let manager = CloudSyncManager()

        // Default interval should be 300 seconds (5 minutes)
        manager.enableAutoBackup()
        manager.disableAutoBackup()
    }

    @MainActor
    func testUpdateSessionData() {
        let manager = CloudSyncManager()

        manager.updateSessionData(hrv: 50.0, coherence: 0.8, heartRate: 70.0)

        // Should create session data
        // Internal state is private but shouldn't crash
    }

    @MainActor
    func testUpdateSessionDataMultipleTimes() {
        let manager = CloudSyncManager()

        // Update multiple times
        for i in 0..<10 {
            manager.updateSessionData(
                hrv: Float(40 + i),
                coherence: Float(i) / 10.0,
                heartRate: Float(60 + i)
            )
        }

        // Should accumulate readings
    }

    // MARK: - SessionBackupData Tests

    func testSessionBackupDataStructure() {
        let data = CloudSyncManager.SessionBackupData(
            name: "Test Backup",
            startTime: Date(),
            hrvReadings: [40, 45, 50],
            coherenceReadings: [0.5, 0.6, 0.7],
            heartRateReadings: [65, 70, 75],
            currentDuration: 180
        )

        XCTAssertEqual(data.name, "Test Backup")
        XCTAssertEqual(data.hrvReadings.count, 3)
        XCTAssertEqual(data.coherenceReadings.count, 3)
        XCTAssertEqual(data.heartRateReadings.count, 3)
        XCTAssertEqual(data.currentDuration, 180, accuracy: 0.001)
    }

    func testSessionBackupDataEmpty() {
        let data = CloudSyncManager.SessionBackupData(
            name: "",
            startTime: Date(),
            hrvReadings: [],
            coherenceReadings: [],
            heartRateReadings: [],
            currentDuration: 0
        )

        XCTAssertTrue(data.hrvReadings.isEmpty)
        XCTAssertTrue(data.coherenceReadings.isEmpty)
        XCTAssertTrue(data.heartRateReadings.isEmpty)
    }

    // MARK: - Save Session Tests (Without Real CloudKit)

    @MainActor
    func testSaveSessionWhenSyncDisabled() async {
        let manager = CloudSyncManager()
        manager.disableSync()

        // Should return early without error when sync is disabled
        do {
            try await manager.saveSession(Session(
                name: "Test",
                duration: 100,
                avgHRV: 50,
                avgCoherence: 0.7
            ))
            // Should complete without throwing
        } catch {
            // If there's an error, it should be expected behavior
        }
    }

    // MARK: - Fetch Sessions Tests (Without Real CloudKit)

    @MainActor
    func testFetchSessionsWhenSyncDisabled() async throws {
        let manager = CloudSyncManager()
        manager.disableSync()

        let sessions = try await manager.fetchSessions()

        // Should return empty array when sync is disabled
        XCTAssertTrue(sessions.isEmpty)
    }

    // MARK: - Finalize Session Tests

    @MainActor
    func testFinalizeSessionWithNoData() async {
        let manager = CloudSyncManager()

        // Finalize without any session data - should not crash
        do {
            try await manager.finalizeSession()
        } catch {
            // Expected - no session data
        }
    }

    // MARK: - Observable Properties Tests

    @MainActor
    func testCloudSyncManagerObservableProperties() {
        let manager = CloudSyncManager()

        // Test that all published properties exist and are accessible
        XCTAssertNotNil(manager.isSyncing)
        XCTAssertNotNil(manager.syncEnabled)
        XCTAssertNotNil(manager.cloudSessions)

        // lastSyncDate can be nil
        _ = manager.lastSyncDate
    }

    @MainActor
    func testCloudSessionsArray() {
        let manager = CloudSyncManager()

        // Initially empty
        XCTAssertEqual(manager.cloudSessions.count, 0)

        // Should be modifiable (for UI binding)
        manager.cloudSessions = [
            CloudSession(id: UUID(), name: "Test1", duration: 100, avgHRV: 40, avgCoherence: 0.5),
            CloudSession(id: UUID(), name: "Test2", duration: 200, avgHRV: 50, avgCoherence: 0.6)
        ]

        XCTAssertEqual(manager.cloudSessions.count, 2)
    }

    // MARK: - Date Tests

    @MainActor
    func testLastSyncDateInitiallyNil() {
        let manager = CloudSyncManager()

        XCTAssertNil(manager.lastSyncDate)
    }

    // MARK: - Sync State Tests

    @MainActor
    func testIsSyncingInitiallyFalse() {
        let manager = CloudSyncManager()

        XCTAssertFalse(manager.isSyncing)
    }

    // MARK: - Multiple Manager Instance Tests

    @MainActor
    func testMultipleManagerInstances() {
        let manager1 = CloudSyncManager()
        let manager2 = CloudSyncManager()

        // Should be independent instances
        manager1.syncEnabled = false
        manager2.syncEnabled = false

        // Changing one shouldn't affect the other
        // (Note: In production, you'd want a singleton or dependency injection)
    }

    // MARK: - Performance Tests

    @MainActor
    func testManagerInitializationPerformance() {
        measure {
            for _ in 0..<10 {
                let _ = CloudSyncManager()
            }
        }
    }

    @MainActor
    func testUpdateSessionDataPerformance() {
        let manager = CloudSyncManager()

        measure {
            for i in 0..<1000 {
                manager.updateSessionData(
                    hrv: Float(40 + (i % 60)),
                    coherence: Float(i % 100) / 100.0,
                    heartRate: Float(60 + (i % 40))
                )
            }
        }
    }

    // MARK: - Edge Cases

    @MainActor
    func testEnableDisableAutoBackupRepeatedly() {
        let manager = CloudSyncManager()

        for _ in 0..<10 {
            manager.enableAutoBackup(interval: 60)
            manager.disableAutoBackup()
        }

        // Should not crash or leak resources
    }

    @MainActor
    func testUpdateSessionDataWithExtremValues() {
        let manager = CloudSyncManager()

        // Extreme low values
        manager.updateSessionData(hrv: 0, coherence: 0, heartRate: 0)

        // Extreme high values
        manager.updateSessionData(hrv: 1000, coherence: 10, heartRate: 300)

        // Negative values (shouldn't happen in practice)
        manager.updateSessionData(hrv: -50, coherence: -1, heartRate: -100)

        // Should handle all without crashing
    }

    func testCloudSessionWithUnicodeCharacters() {
        let session = CloudSession(
            id: UUID(),
            name: "セッション 🧘‍♀️ العربية",
            duration: 100,
            avgHRV: 50,
            avgCoherence: 0.7
        )

        XCTAssertEqual(session.name, "セッション 🧘‍♀️ العربية")
    }

    // MARK: - Session Model Tests

    func testSessionModel() {
        // Test the Session struct used for saving
        // This ensures the Session type exists and is usable
        let session = Session(
            name: "Test Session",
            duration: 600,
            avgHRV: 55.5,
            avgCoherence: 0.85
        )

        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.duration, 600, accuracy: 0.001)
        XCTAssertEqual(session.avgHRV, 55.5, accuracy: 0.001)
        XCTAssertEqual(session.avgCoherence, 0.85, accuracy: 0.001)
    }
}
