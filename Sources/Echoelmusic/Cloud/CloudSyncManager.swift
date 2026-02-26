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

    private let container: CKContainer?
    private let privateDatabase: CKDatabase?
    private let sharedDatabase: CKDatabase?

    init() {
        // Use CKContainer.default() which NEVER traps, unlike CKContainer(identifier:)
        // which crashes with SIGTRAP if the container isn't configured in the portal.
        // Account availability is checked async when sync is actually requested.
        if FileManager.default.ubiquityIdentityToken != nil {
            let ck = CKContainer.default()
            self.container = ck
            self.privateDatabase = ck.privateCloudDatabase
            self.sharedDatabase = ck.sharedCloudDatabase
            log.log(.info, category: .network, "CloudSyncManager: Initialized with default CloudKit container")
        } else {
            self.container = nil
            self.privateDatabase = nil
            self.sharedDatabase = nil
            log.log(.info, category: .network, "CloudSyncManager: iCloud not available — running offline")
        }
    }

    // MARK: - Enable/Disable Sync

    func enableSync() async throws {
        guard let container = container else {
            throw CloudError.iCloudNotAvailable
        }

        // Check iCloud availability
        let status = try await container.accountStatus()

        guard status == .available else {
            throw CloudError.iCloudNotAvailable
        }

        syncEnabled = true
        log.network("☁️ CloudSyncManager: Sync enabled")
    }

    func disableSync() {
        syncEnabled = false
        log.network("☁️ CloudSyncManager: Sync disabled")
    }

    // MARK: - Save Session

    func saveSession(_ session: Session) async throws {
        guard syncEnabled, let privateDatabase = privateDatabase else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Create CKRecord
        let record = CKRecord(recordType: "Session")
        record["name"] = session.name as CKRecordValue
        record["duration"] = session.duration as CKRecordValue
        record["avgHRV"] = session.averageHRV as CKRecordValue
        record["avgCoherence"] = session.averageCoherence as CKRecordValue

        // Save to private database
        try await privateDatabase.save(record)

        lastSyncDate = Date()
        log.network("☁️ CloudSyncManager: Saved session '\(session.name)'")
    }

    // MARK: - Fetch Sessions

    func fetchSessions() async throws -> [CloudSession] {
        guard syncEnabled, let privateDatabase = privateDatabase else { return [] }

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

        log.network("☁️ CloudSyncManager: Fetched \(sessions.count) sessions")
        return sessions
    }

    // MARK: - Auto Backup

    private var autoBackupTimer: Timer?
    private var currentSessionData: SessionBackupData?
    private var lastBackupDate: Date?

    struct SessionBackupData {
        var name: String
        var startTime: Date
        var hrvReadings: [Float]
        var coherenceReadings: [Float]
        var heartRateReadings: [Float]
        var currentDuration: TimeInterval
    }

    func enableAutoBackup(interval: TimeInterval = 300) {
        // Cancel existing timer if any
        autoBackupTimer?.invalidate()

        // Backup every 5 minutes (or specified interval)
        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.autoBackup()
            }
        }
        log.network("☁️ CloudSyncManager: Auto backup enabled (every \(Int(interval))s)")
    }

    func disableAutoBackup() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
        log.network("☁️ CloudSyncManager: Auto backup disabled")
    }

    /// Update current session data for backup
    func updateSessionData(hrv: Float, coherence: Float, heartRate: Float) {
        if currentSessionData == nil {
            currentSessionData = SessionBackupData(
                name: "Session \(Date().formatted(date: .abbreviated, time: .shortened))",
                startTime: Date(),
                hrvReadings: [],
                coherenceReadings: [],
                heartRateReadings: [],
                currentDuration: 0
            )
        }

        currentSessionData?.hrvReadings.append(hrv)
        currentSessionData?.coherenceReadings.append(coherence)
        currentSessionData?.heartRateReadings.append(heartRate)
        currentSessionData?.currentDuration = Date().timeIntervalSince(currentSessionData?.startTime ?? Date())
    }

    private func autoBackup() async throws {
        guard syncEnabled, let privateDatabase = privateDatabase else {
            log.network("☁️ CloudSyncManager: Auto backup skipped (sync disabled or CloudKit unavailable)")
            return
        }

        guard let sessionData = currentSessionData else {
            log.network("☁️ CloudSyncManager: Auto backup skipped (no active session)")
            return
        }

        // Skip if nothing new to backup
        if let lastBackup = lastBackupDate,
           sessionData.hrvReadings.count < 10 {
            log.network("☁️ CloudSyncManager: Auto backup skipped (insufficient new data)")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Calculate averages
        let avgHRV = sessionData.hrvReadings.reduce(0, +) / Float(max(sessionData.hrvReadings.count, 1))
        let avgCoherence = sessionData.coherenceReadings.reduce(0, +) / Float(max(sessionData.coherenceReadings.count, 1))
        let avgHeartRate = sessionData.heartRateReadings.reduce(0, +) / Float(max(sessionData.heartRateReadings.count, 1))

        // Create backup record
        let record = CKRecord(recordType: "SessionBackup")
        record["name"] = sessionData.name as CKRecordValue
        record["startTime"] = sessionData.startTime as CKRecordValue
        record["duration"] = sessionData.currentDuration as CKRecordValue
        record["avgHRV"] = avgHRV as CKRecordValue
        record["avgCoherence"] = avgCoherence as CKRecordValue
        record["avgHeartRate"] = avgHeartRate as CKRecordValue
        record["dataPointCount"] = sessionData.hrvReadings.count as CKRecordValue
        record["isPartialBackup"] = true as CKRecordValue
        record["backupDate"] = Date() as CKRecordValue

        // Store raw readings as JSON data (for detailed analysis)
        let readings: [String: [Float]] = [
            "hrv": sessionData.hrvReadings,
            "coherence": sessionData.coherenceReadings,
            "heartRate": sessionData.heartRateReadings
        ]

        if let readingsData = try? JSONEncoder().encode(readings) {
            record["readings"] = readingsData as CKRecordValue
        }

        // Save to private database
        do {
            try await privateDatabase.save(record)
            lastBackupDate = Date()
            lastSyncDate = Date()
            log.network("☁️ CloudSyncManager: Auto backup completed - \(sessionData.hrvReadings.count) data points, avg HRV: \(String(format: "%.1f", avgHRV)), avg Coherence: \(String(format: "%.2f", avgCoherence))")
        } catch {
            log.network("❌ CloudSyncManager: Auto backup failed - \(error.localizedDescription)", level: .error)
            throw CloudError.syncFailed
        }
    }

    /// Finalize and save complete session
    func finalizeSession() async throws {
        guard let sessionData = currentSessionData, let privateDatabase = privateDatabase else { return }

        // Calculate final averages
        let avgHRV = sessionData.hrvReadings.reduce(0, +) / Float(max(sessionData.hrvReadings.count, 1))
        let avgCoherence = sessionData.coherenceReadings.reduce(0, +) / Float(max(sessionData.coherenceReadings.count, 1))

        // Save directly to CloudKit with computed averages
        isSyncing = true
        defer { isSyncing = false }

        let record = CKRecord(recordType: "Session")
        record["name"] = sessionData.name as CKRecordValue
        record["duration"] = sessionData.currentDuration as CKRecordValue
        record["avgHRV"] = Double(avgHRV) as CKRecordValue
        record["avgCoherence"] = Double(avgCoherence) as CKRecordValue

        try await privateDatabase.save(record)
        lastSyncDate = Date()

        // Clear current session data
        currentSessionData = nil
        lastBackupDate = nil

        log.network("☁️ CloudSyncManager: Session finalized and saved")
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

// Note: CloudSession struct is defined above at line 242
