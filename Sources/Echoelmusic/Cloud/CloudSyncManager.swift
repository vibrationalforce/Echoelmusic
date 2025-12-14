import Foundation
import CloudKit
import Combine

/// Cloud Sync Manager - CloudKit Integration
/// Session sync across devices, collaborative cloud sessions, automatic backup
@MainActor
class CloudSyncManager: ObservableObject {

    @Published var isSyncing: Bool = false
    @Published var syncEnabled: Bool = false
    @Published var lastSyncDate: Date?
    @Published var cloudSessions: [CloudSession] = []

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    init() {
        self.container = CKContainer(identifier: "iCloud.com.echoelmusic.app")
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        print("✅ CloudSyncManager: Initialized")
    }

    // MARK: - Enable/Disable Sync

    func enableSync() async throws {
        // Check iCloud availability
        let status = try await container.accountStatus()

        guard status == .available else {
            throw CloudError.iCloudNotAvailable
        }

        syncEnabled = true
        print("☁️ CloudSyncManager: Sync enabled")
    }

    func disableSync() {
        syncEnabled = false
        print("☁️ CloudSyncManager: Sync disabled")
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
        print("☁️ CloudSyncManager: Saved session '\(session.name)'")
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

        print("☁️ CloudSyncManager: Fetched \(sessions.count) sessions")
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
        print("☁️ CloudSyncManager: Auto backup enabled (every \(Int(interval))s)")
    }

    private func autoBackup() async throws {
        guard syncEnabled else { return }

        // Get current session from SessionManager
        guard let currentSession = SessionManager.shared.currentSession else {
            print("☁️ CloudSyncManager: No active session to backup")
            return
        }

        // Create backup record
        let backupRecord = CKRecord(recordType: "SessionBackup")
        backupRecord["sessionId"] = currentSession.id.uuidString as CKRecordValue
        backupRecord["name"] = currentSession.name as CKRecordValue
        backupRecord["duration"] = currentSession.duration as CKRecordValue
        backupRecord["avgHRV"] = currentSession.avgHRV as CKRecordValue
        backupRecord["avgCoherence"] = currentSession.avgCoherence as CKRecordValue
        backupRecord["backupTimestamp"] = Date() as CKRecordValue
        backupRecord["isAutoBackup"] = true as CKRecordValue

        // Serialize session data as JSON
        if let sessionData = try? JSONEncoder().encode(currentSession) {
            backupRecord["sessionData"] = sessionData as CKRecordValue
        }

        // Save to private database
        try await privateDatabase.save(backupRecord)

        lastSyncDate = Date()
        print("☁️ CloudSyncManager: Auto backup completed for '\(currentSession.name)'")
    }

    // MARK: - Restore from Backup

    func restoreFromBackup(backupId: CKRecord.ID) async throws -> Session? {
        guard syncEnabled else { return nil }

        let record = try await privateDatabase.record(for: backupId)

        guard let sessionData = record["sessionData"] as? Data,
              let session = try? JSONDecoder().decode(Session.self, from: sessionData) else {
            throw CloudError.syncFailed
        }

        print("☁️ CloudSyncManager: Restored session from backup")
        return session
    }

    // MARK: - List Backups

    func listBackups() async throws -> [CKRecord] {
        guard syncEnabled else { return [] }

        let query = CKQuery(recordType: "SessionBackup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "backupTimestamp", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var backups: [CKRecord] = []
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                backups.append(record)
            }
        }

        return backups
    }
}

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
struct Session: Codable, Identifiable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let avgHRV: Float
    let avgCoherence: Float

    init(name: String, duration: TimeInterval, avgHRV: Float, avgCoherence: Float) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.avgHRV = avgHRV
        self.avgCoherence = avgCoherence
    }
}

// SessionManager singleton for current session access
@MainActor
class SessionManager {
    static let shared = SessionManager()
    var currentSession: Session?
    private init() {}
}
