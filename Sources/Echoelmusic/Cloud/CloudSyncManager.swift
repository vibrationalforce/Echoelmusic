import Foundation
import CloudKit
import Combine

/// Cloud Sync Manager - CloudKit Integration
/// Session sync across devices, collaborative cloud sessions, automatic backup
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class CloudSyncManager {

    var isSyncing: Bool = false
    var syncEnabled: Bool = false
    var lastSyncDate: Date?
    var cloudSessions: [CloudSession] = []

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    init() {
        self.container = CKContainer(identifier: "iCloud.com.echoelmusic.app")
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        #if DEBUG
        debugLog("✅", "CloudSyncManager: Initialized")
        #endif
    }

    // MARK: - Enable/Disable Sync

    func enableSync() async throws {
        // Check iCloud availability
        let status = try await container.accountStatus()

        guard status == .available else {
            throw CloudError.iCloudNotAvailable
        }

        syncEnabled = true
        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Sync enabled")
        #endif
    }

    func disableSync() {
        syncEnabled = false
        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Sync disabled")
        #endif
    }

    // MARK: - Save Session

    func saveSession(_ session: Session) async throws {
        guard syncEnabled else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Create CKRecord
        let record = CKRecord(recordType: "Session")
        record["name"] = session.name as CKRecordValue
        record["duration"] = session.duration as CKRecordValue
        record["avgHRV"] = session.avgHRV as CKRecordValue
        record["avgCoherence"] = session.avgCoherence as CKRecordValue

        // Save to private database
        try await privateDatabase.save(record)

        lastSyncDate = Date()
        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Saved session '\(session.name)'")
        #endif
    }

    // MARK: - Fetch Sessions

    func fetchSessions() async throws -> [CloudSession] {
        guard syncEnabled else { return [] }

        isSyncing = true
        defer { isSyncing = false }

        let query = CKQuery(recordType: "Session", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var sessions: [CloudSession] = []
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                let session = CloudSession(
                    id: UUID(),
                    name: record["name"] as? String ?? "Untitled",
                    duration: record["duration"] as? TimeInterval ?? 0,
                    avgHRV: record["avgHRV"] as? Float ?? 0,
                    avgCoherence: record["avgCoherence"] as? Float ?? 0
                )
                sessions.append(session)
            }
        }

        cloudSessions = sessions
        lastSyncDate = Date()

        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Fetched \(sessions.count) sessions")
        #endif
        return sessions
    }

    // MARK: - Auto Backup

    func enableAutoBackup(interval: TimeInterval = 300) {
        // Backup every 5 minutes
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.autoBackup()
            }
        }
        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Auto backup enabled (every \(Int(interval))s)")
        #endif
    }

    private func autoBackup() async throws {
        // TODO: Backup current session automatically
        #if DEBUG
        debugLog("☁️", "CloudSyncManager: Auto backup triggered")
        #endif
    }
}

// MARK: - ObservableObject Conformance (Backward Compatibility)

/// Allows CloudSyncManager to work with older SwiftUI code expecting ObservableObject
extension CloudSyncManager: ObservableObject { }

struct CloudSession: Identifiable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let avgHRV: Float
    let avgCoherence: Float
}

enum CloudError: LocalizedError {
    case iCloudNotAvailable
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .syncFailed:
            return "Cloud sync failed"
        }
    }
}

// Session struct placeholder
struct Session {
    let name: String
    let duration: TimeInterval
    let avgHRV: Float
    let avgCoherence: Float
}
