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
        // Backup current active session automatically
        guard syncEnabled else { return }

        // Get current session from notification center or shared state
        if let currentSession = NotificationCenter.default.currentSession {
            try await saveSession(currentSession)
            print("☁️ CloudSyncManager: Auto backup completed for session '\(currentSession.name)'")
        } else {
            print("☁️ CloudSyncManager: Auto backup triggered (no active session)")
        }
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
struct Session {
    let name: String
    let duration: TimeInterval
    let avgHRV: Float
    let avgCoherence: Float
}

// Extension for accessing current session from NotificationCenter
extension NotificationCenter {
    private static var _currentSession: Session?

    var currentSession: Session? {
        get { NotificationCenter._currentSession }
        set { NotificationCenter._currentSession = newValue }
    }

    func setCurrentSession(_ session: Session?) {
        NotificationCenter._currentSession = session
    }
}
