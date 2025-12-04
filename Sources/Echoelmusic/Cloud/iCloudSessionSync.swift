import Foundation
import CloudKit
import Combine

/// iCloud Session Sync Manager
/// Handles automatic backup, sync, and restoration of Echoelmusic sessions
/// Features: Auto-save, Conflict resolution, Offline support, Delta sync
@MainActor
class iCloudSessionSync: ObservableObject {

    // MARK: - Published State

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges: Int = 0
    @Published var isCloudAvailable: Bool = false
    @Published var syncProgress: Double = 0

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.com.echoelmusic.sessions"
    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var subscriptionID: CKSubscription.ID?

    // MARK: - Local Storage

    private let fileManager = FileManager.default
    private var localSessionsURL: URL?
    private var pendingUploads: [URL] = []
    private var pendingDownloads: [CKRecord.ID] = []

    // MARK: - Auto-save Timer

    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 30.0  // 30 seconds

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupCloudKit()
        setupLocalStorage()
        setupAutoSave()
        checkCloudAvailability()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - CloudKit Setup

    private func setupCloudKit() {
        container = CKContainer(identifier: containerIdentifier)
        privateDatabase = container?.privateCloudDatabase

        // Subscribe to remote changes
        setupSubscription()
    }

    private func setupSubscription() {
        guard let database = privateDatabase else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "session-changes")

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true

        subscription.notificationInfo = notificationInfo

        database.save(subscription) { [weak self] savedSubscription, error in
            if let error = error {
                print("⚠️ CloudKit subscription error: \(error.localizedDescription)")
            } else {
                self?.subscriptionID = savedSubscription?.subscriptionID
                print("✅ CloudKit subscription active")
            }
        }
    }

    // MARK: - Local Storage Setup

    private func setupLocalStorage() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        localSessionsURL = documentsURL.appendingPathComponent("Sessions", isDirectory: true)

        // Create sessions directory if needed
        if let url = localSessionsURL, !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Auto-save Setup

    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.autoSaveAllSessions()
            }
        }
    }

    // MARK: - Cloud Availability

    private func checkCloudAvailability() {
        container?.accountStatus { [weak self] status, error in
            Task { @MainActor [weak self] in
                switch status {
                case .available:
                    self?.isCloudAvailable = true
                    print("✅ iCloud available")
                case .noAccount:
                    self?.isCloudAvailable = false
                    print("⚠️ No iCloud account")
                case .restricted, .couldNotDetermine, .temporarilyUnavailable:
                    self?.isCloudAvailable = false
                    print("⚠️ iCloud restricted or unavailable")
                @unknown default:
                    self?.isCloudAvailable = false
                }
            }
        }
    }

    // MARK: - Session Operations

    /// Save session to local storage and queue for cloud sync
    func saveSession(_ session: SessionData) async throws {
        guard let localURL = localSessionsURL else {
            throw SyncError.localStorageUnavailable
        }

        let sessionURL = localURL.appendingPathComponent("\(session.id.uuidString).session")

        // Encode session data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        // Write to local storage
        try data.write(to: sessionURL)

        // Queue for upload
        pendingUploads.append(sessionURL)
        pendingChanges = pendingUploads.count

        print("💾 Session saved locally: \(session.name)")

        // Trigger sync if cloud is available
        if isCloudAvailable {
            await syncPendingChanges()
        }
    }

    /// Load session from local storage
    func loadSession(id: UUID) async throws -> SessionData {
        guard let localURL = localSessionsURL else {
            throw SyncError.localStorageUnavailable
        }

        let sessionURL = localURL.appendingPathComponent("\(id.uuidString).session")

        guard fileManager.fileExists(atPath: sessionURL.path) else {
            throw SyncError.sessionNotFound
        }

        let data = try Data(contentsOf: sessionURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(SessionData.self, from: data)
    }

    /// Delete session from local and cloud storage
    func deleteSession(id: UUID) async throws {
        guard let localURL = localSessionsURL else {
            throw SyncError.localStorageUnavailable
        }

        let sessionURL = localURL.appendingPathComponent("\(id.uuidString).session")

        // Delete locally
        if fileManager.fileExists(atPath: sessionURL.path) {
            try fileManager.removeItem(at: sessionURL)
        }

        // Delete from cloud
        if isCloudAvailable {
            await deleteFromCloud(sessionID: id)
        }

        print("🗑️ Session deleted: \(id)")
    }

    /// List all local sessions
    func listLocalSessions() async throws -> [SessionMetadata] {
        guard let localURL = localSessionsURL else {
            throw SyncError.localStorageUnavailable
        }

        let contents = try fileManager.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )

        var sessions: [SessionMetadata] = []

        for url in contents where url.pathExtension == "session" {
            if let data = try? Data(contentsOf: url),
               let session = try? JSONDecoder().decode(SessionData.self, from: data) {
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let modDate = attributes?[.modificationDate] as? Date

                sessions.append(SessionMetadata(
                    id: session.id,
                    name: session.name,
                    lastModified: modDate ?? Date(),
                    trackCount: session.tracks.count,
                    duration: session.duration,
                    isCloudSynced: session.cloudSynced
                ))
            }
        }

        return sessions.sorted { $0.lastModified > $1.lastModified }
    }

    // MARK: - Cloud Sync Operations

    /// Sync all pending changes to cloud
    func syncPendingChanges() async {
        guard isCloudAvailable else {
            print("⚠️ Cloud not available, skipping sync")
            return
        }

        syncStatus = .syncing

        do {
            // Upload pending sessions
            for url in pendingUploads {
                try await uploadToCloud(fileURL: url)
                syncProgress = Double(pendingUploads.firstIndex(of: url) ?? 0) / Double(pendingUploads.count)
            }

            pendingUploads.removeAll()
            pendingChanges = 0
            lastSyncDate = Date()
            syncStatus = .synced

            print("✅ Sync completed")
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("❌ Sync error: \(error.localizedDescription)")
        }
    }

    /// Full sync - download all cloud sessions
    func performFullSync() async {
        guard isCloudAvailable else { return }

        syncStatus = .syncing

        do {
            // Fetch all session records from cloud
            let records = try await fetchAllCloudSessions()

            for record in records {
                try await downloadFromCloud(record: record)
            }

            // Upload any local sessions not in cloud
            await syncPendingChanges()

            syncStatus = .synced
            lastSyncDate = Date()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - CloudKit Operations

    private func uploadToCloud(fileURL: URL) async throws {
        guard let database = privateDatabase else {
            throw SyncError.cloudUnavailable
        }

        let data = try Data(contentsOf: fileURL)
        let session = try JSONDecoder().decode(SessionData.self, from: data)

        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: "Session", recordID: recordID)

        // Set record fields
        record["name"] = session.name
        record["duration"] = session.duration
        record["trackCount"] = session.tracks.count
        record["bpm"] = session.bpm
        record["createdAt"] = session.createdAt
        record["modifiedAt"] = Date()

        // Save session data as asset
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        record["sessionData"] = CKAsset(fileURL: tempURL)

        // Save to CloudKit
        _ = try await database.save(record)

        // Clean up temp file
        try? fileManager.removeItem(at: tempURL)

        // Mark session as cloud synced
        var updatedSession = session
        updatedSession.cloudSynced = true
        let updatedData = try JSONEncoder().encode(updatedSession)
        try updatedData.write(to: fileURL)

        print("☁️ Uploaded to cloud: \(session.name)")
    }

    private func downloadFromCloud(record: CKRecord) async throws {
        guard let localURL = localSessionsURL else {
            throw SyncError.localStorageUnavailable
        }

        guard let asset = record["sessionData"] as? CKAsset,
              let assetURL = asset.fileURL else {
            throw SyncError.invalidCloudData
        }

        let sessionID = record.recordID.recordName
        let destinationURL = localURL.appendingPathComponent("\(sessionID).session")

        // Check if local version is newer
        if fileManager.fileExists(atPath: destinationURL.path) {
            let localAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let localModDate = localAttributes[.modificationDate] as? Date ?? Date.distantPast
            let cloudModDate = record["modifiedAt"] as? Date ?? Date.distantPast

            if localModDate > cloudModDate {
                print("📱 Local version is newer, skipping download")
                return
            }
        }

        // Copy from cloud asset to local storage
        try fileManager.copyItem(at: assetURL, to: destinationURL)

        print("⬇️ Downloaded from cloud: \(record["name"] ?? "Unknown")")
    }

    private func deleteFromCloud(sessionID: UUID) async {
        guard let database = privateDatabase else { return }

        let recordID = CKRecord.ID(recordName: sessionID.uuidString)

        do {
            try await database.deleteRecord(withID: recordID)
            print("☁️ Deleted from cloud: \(sessionID)")
        } catch {
            print("⚠️ Cloud delete error: \(error.localizedDescription)")
        }
    }

    private func fetchAllCloudSessions() async throws -> [CKRecord] {
        guard let database = privateDatabase else {
            throw SyncError.cloudUnavailable
        }

        let query = CKQuery(recordType: "Session", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        let (results, _) = try await database.records(matching: query)

        return results.compactMap { _, result in
            try? result.get()
        }
    }

    // MARK: - Auto-save

    private func autoSaveAllSessions() async {
        guard let localURL = localSessionsURL else { return }

        // Find sessions that need saving
        let contents = try? fileManager.contentsOfDirectory(at: localURL, includingPropertiesForKeys: nil)

        for url in contents ?? [] where url.pathExtension == "session" {
            if !pendingUploads.contains(url) {
                // Check if modified since last sync
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let modDate = attributes?[.modificationDate] as? Date ?? Date.distantPast

                if let lastSync = lastSyncDate, modDate > lastSync {
                    pendingUploads.append(url)
                }
            }
        }

        pendingChanges = pendingUploads.count

        // Sync if there are pending changes
        if pendingChanges > 0 && isCloudAvailable {
            await syncPendingChanges()
        }
    }

    // MARK: - Types

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case error(String)

        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.synced, .synced):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    enum SyncError: LocalizedError {
        case localStorageUnavailable
        case cloudUnavailable
        case sessionNotFound
        case invalidCloudData
        case conflictResolutionFailed

        var errorDescription: String? {
            switch self {
            case .localStorageUnavailable: return "Local storage is not available"
            case .cloudUnavailable: return "iCloud is not available"
            case .sessionNotFound: return "Session not found"
            case .invalidCloudData: return "Invalid data in cloud"
            case .conflictResolutionFailed: return "Could not resolve sync conflict"
            }
        }
    }
}

// MARK: - Session Data Models

struct SessionData: Codable, Identifiable {
    let id: UUID
    var name: String
    var tracks: [TrackData]
    var bpm: Double
    var duration: Double
    var createdAt: Date
    var modifiedAt: Date
    var cloudSynced: Bool

    init(id: UUID = UUID(), name: String, bpm: Double = 120) {
        self.id = id
        self.name = name
        self.tracks = []
        self.bpm = bpm
        self.duration = 0
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.cloudSynced = false
    }
}

struct TrackData: Codable, Identifiable {
    let id: UUID
    var name: String
    var volume: Float
    var pan: Float
    var muted: Bool
    var solo: Bool
    var audioFileURL: String?
    var midiData: Data?
}

struct SessionMetadata: Identifiable {
    let id: UUID
    let name: String
    let lastModified: Date
    let trackCount: Int
    let duration: Double
    let isCloudSynced: Bool
}
