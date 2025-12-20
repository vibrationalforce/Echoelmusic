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
    @Published var lastBackupDate: Date?
    @Published var cloudSessions: [CloudSession] = []
    @Published var autoBackupEnabled: Bool = false

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    // Current session reference for auto-backup
    private weak var currentSessionProvider: SessionProvider?
    private var autoBackupTimer: Timer?

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

    /// Set the session provider for auto-backup functionality
    func setSessionProvider(_ provider: SessionProvider) {
        self.currentSessionProvider = provider
    }

    /// Enable automatic backup of current session at specified interval
    func enableAutoBackup(interval: TimeInterval = 300) {
        // Cancel existing timer if any
        autoBackupTimer?.invalidate()

        // Backup every 5 minutes (default)
        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.autoBackup()
            }
        }
        autoBackupEnabled = true
        print("☁️ CloudSyncManager: Auto backup enabled (every \(Int(interval))s)")
    }

    /// Disable automatic backup
    func disableAutoBackup() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
        autoBackupEnabled = false
        print("☁️ CloudSyncManager: Auto backup disabled")
    }

    /// Perform automatic backup of current session
    private func autoBackup() async throws {
        guard syncEnabled else {
            print("☁️ CloudSyncManager: Skipping backup - sync not enabled")
            return
        }

        guard let provider = currentSessionProvider,
              let currentSession = provider.currentSession else {
            print("☁️ CloudSyncManager: Skipping backup - no active session")
            return
        }

        // Check if session has meaningful content
        guard currentSession.duration > 0 else {
            print("☁️ CloudSyncManager: Skipping backup - session is empty")
            return
        }

        print("☁️ CloudSyncManager: Auto backup triggered for '\(currentSession.name)'")

        // Save session to cloud
        try await saveSession(currentSession)

        lastBackupDate = Date()
        print("☁️ CloudSyncManager: Auto backup completed successfully")
    }

    /// Force immediate backup of current session
    func backupNow() async throws {
        try await autoBackup()
    }
}

// MARK: - Session Provider Protocol

/// Protocol for providing current session for backup
protocol SessionProvider: AnyObject {
    var currentSession: Session? { get }
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
