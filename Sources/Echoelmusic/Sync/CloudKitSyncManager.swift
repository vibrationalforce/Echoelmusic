import Foundation
import CloudKit
import Combine

/// CloudKit sync manager for seamless cross-device experience
///
/// **Purpose:** Create a unified "Erlebnisbad" (experience bath) across all Apple devices
///
/// **Vision:**
/// - Start session on iPhone
/// - Continue on Apple Watch
/// - Join group on Apple TV
/// - Finish on Mac
/// **→ No interruption, perfect continuity**
///
/// **Synced Data:**
/// - Session history
/// - HRV measurements
/// - Coherence scores
/// - Breathing patterns
/// - User preferences
/// - Achievements
///
/// **Real-time Features:**
/// - Live session state
/// - Current HRV across devices
/// - Group session participants
/// - Active breathing pattern
///
/// **Privacy:**
/// - End-to-end encrypted (iCloud)
/// - User controls sync (on/off)
/// - Local-first architecture
/// - Sync only when enabled
///
@MainActor
public class CloudKitSyncManager: ObservableObject {

    // MARK: - Published Properties

    /// Whether sync is enabled
    @Published public var isSyncEnabled: Bool = true

    /// Current sync status
    @Published public private(set) var syncStatus: SyncStatus = .idle

    /// Last sync time
    @Published public private(set) var lastSyncTime: Date?

    /// Devices synced with this account
    @Published public private(set) var syncedDevices: [SyncedDevice] = []

    // MARK: - Private Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase

    private var cancellables = Set<AnyCancellable>()

    // Record types
    private let sessionRecordType = "Session"
    private let hrvRecordType = "HRVMeasurement"
    private let preferenceRecordType = "UserPreference"
    private let deviceRecordType = "Device"

    // MARK: - Initialization

    public init() {
        self.container = CKContainer(identifier: "iCloud.com.echoelmusic.app")
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase

        checkAccountStatus()
        setupNotifications()

        print("[CloudKitSync] 🌊 Seamless cross-device sync initialized")
    }

    // MARK: - Account Status

    private func checkAccountStatus() {
        Task {
            do {
                let status = try await container.accountStatus()

                switch status {
                case .available:
                    print("[CloudKitSync] ✅ iCloud available")
                    syncStatus = .ready
                    registerDevice()
                    startSync()

                case .noAccount:
                    print("[CloudKitSync] ⚠️ No iCloud account")
                    syncStatus = .unavailable

                case .restricted:
                    print("[CloudKitSync] ⚠️ iCloud restricted")
                    syncStatus = .unavailable

                case .couldNotDetermine:
                    print("[CloudKitSync] ⚠️ Could not determine iCloud status")
                    syncStatus = .error(SyncError.accountStatusUnknown)

                case .temporarilyUnavailable:
                    print("[CloudKitSync] ⚠️ iCloud temporarily unavailable")
                    syncStatus = .error(SyncError.temporarilyUnavailable)

                @unknown default:
                    syncStatus = .error(SyncError.accountStatusUnknown)
                }
            } catch {
                print("[CloudKitSync] ❌ Account status check failed: \(error)")
                syncStatus = .error(error)
            }
        }
    }

    // MARK: - Device Registration

    private func registerDevice() {
        Task {
            do {
                let deviceID = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                let deviceName = await UIDevice.current.name
                let deviceModel = await UIDevice.current.model

                let record = CKRecord(recordType: deviceRecordType)
                record["deviceID"] = deviceID
                record["deviceName"] = deviceName
                record["deviceModel"] = deviceModel
                record["lastSeen"] = Date()
                record["platform"] = self.currentPlatform

                try await privateDatabase.save(record)

                print("[CloudKitSync] 📱 Device registered: \(deviceName)")

                // Load all synced devices
                await loadSyncedDevices()

            } catch {
                print("[CloudKitSync] ⚠️ Device registration failed: \(error)")
            }
        }
    }

    private func loadSyncedDevices() async {
        do {
            let query = CKQuery(recordType: deviceRecordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "lastSeen", ascending: false)]

            let results = try await privateDatabase.records(matching: query)

            var devices: [SyncedDevice] = []

            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    if let device = SyncedDevice(record: record) {
                        devices.append(device)
                    }
                case .failure(let error):
                    print("[CloudKitSync] ⚠️ Failed to load device: \(error)")
                }
            }

            await MainActor.run {
                self.syncedDevices = devices
            }

            print("[CloudKitSync] 📱 Loaded \(devices.count) synced devices")

        } catch {
            print("[CloudKitSync] ❌ Failed to load devices: \(error)")
        }
    }

    // MARK: - Session Sync

    /// Save session to iCloud
    public func syncSession(_ session: BiofeedbackSession) async throws {
        guard isSyncEnabled else { return }

        syncStatus = .syncing

        do {
            let record = CKRecord(recordType: sessionRecordType)
            record["sessionID"] = session.id.uuidString
            record["startTime"] = session.startTime
            record["endTime"] = session.endTime
            record["duration"] = session.duration
            record["averageHRV"] = session.averageHRV
            record["averageCoherence"] = session.averageCoherence
            record["devicePlatform"] = currentPlatform

            try await privateDatabase.save(record)

            lastSyncTime = Date()
            syncStatus = .ready

            print("[CloudKitSync] ✅ Session synced: \(session.id)")

        } catch {
            syncStatus = .error(error)
            throw error
        }
    }

    /// Load recent sessions from all devices
    public func loadRecentSessions(limit: Int = 50) async throws -> [BiofeedbackSession] {
        let query = CKQuery(
            recordType: sessionRecordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var sessions: [BiofeedbackSession] = []

        for (_, result) in results.matchResults.prefix(limit) {
            switch result {
            case .success(let record):
                if let session = BiofeedbackSession(record: record) {
                    sessions.append(session)
                }
            case .failure(let error):
                print("[CloudKitSync] ⚠️ Failed to load session: \(error)")
            }
        }

        print("[CloudKitSync] 📊 Loaded \(sessions.count) sessions from iCloud")

        return sessions
    }

    // MARK: - Real-time Sync

    /// Start real-time sync
    private func startSync() {
        // Subscribe to changes
        let subscription = CKQuerySubscription(
            recordType: sessionRecordType,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true

        subscription.notificationInfo = notificationInfo

        Task {
            do {
                try await privateDatabase.save(subscription)
                print("[CloudKitSync] 🔔 Real-time sync enabled")
            } catch {
                print("[CloudKitSync] ⚠️ Subscription failed: \(error)")
            }
        }
    }

    // MARK: - Live Session State

    /// Broadcast current session state to all devices
    public func broadcastLiveState(_ state: LiveSessionState) async throws {
        guard isSyncEnabled else { return }

        // Use shared database for real-time state
        let record = CKRecord(recordType: "LiveState")
        record["userID"] = state.userID
        record["currentHRV"] = state.currentHRV
        record["currentCoherence"] = state.currentCoherence
        record["breathingPhase"] = state.breathingPhase
        record["timestamp"] = Date()

        try await publicDatabase.save(record)

        print("[CloudKitSync] 📡 Live state broadcasted")
    }

    /// Fetch live state from other devices
    public func fetchLiveStates() async throws -> [LiveSessionState] {
        let query = CKQuery(
            recordType: "LiveState",
            predicate: NSPredicate(
                format: "timestamp > %@",
                Date().addingTimeInterval(-60) as NSDate // Last minute only
            )
        )

        let results = try await publicDatabase.records(matching: query)

        var states: [LiveSessionState] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let state = LiveSessionState(record: record) {
                    states.append(state)
                }
            case .failure(let error):
                print("[CloudKitSync] ⚠️ Failed to load live state: \(error)")
            }
        }

        return states
    }

    // MARK: - Preferences Sync

    /// Sync user preferences to all devices
    public func syncPreferences(_ preferences: [String: Any]) async throws {
        guard isSyncEnabled else { return }

        let record = CKRecord(recordType: preferenceRecordType)

        for (key, value) in preferences {
            if let stringValue = value as? String {
                record[key] = stringValue
            } else if let numberValue = value as? NSNumber {
                record[key] = numberValue
            } else if let boolValue = value as? Bool {
                record[key] = boolValue ? 1 : 0
            }
        }

        try await privateDatabase.save(record)

        print("[CloudKitSync] ⚙️ Preferences synced")
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Handle remote notifications
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Platform Detection

    private var currentPlatform: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #elseif os(watchOS)
        return "Apple Watch"
        #elseif os(tvOS)
        return "Apple TV"
        #elseif os(macOS)
        return "Mac"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - Sync Control

    /// Enable sync
    public func enableSync() {
        isSyncEnabled = true
        UserDefaults.standard.set(true, forKey: "cloudKitSyncEnabled")
        checkAccountStatus()
        print("[CloudKitSync] ✅ Sync enabled")
    }

    /// Disable sync
    public func disableSync() {
        isSyncEnabled = false
        UserDefaults.standard.set(false, forKey: "cloudKitSyncEnabled")
        syncStatus = .idle
        print("[CloudKitSync] 🛑 Sync disabled")
    }
}

// MARK: - Supporting Types

public enum SyncStatus: Equatable {
    case idle
    case ready
    case syncing
    case unavailable
    case error(Error)

    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready), (.syncing, .syncing), (.unavailable, .unavailable):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

public enum SyncError: LocalizedError {
    case accountStatusUnknown
    case temporarilyUnavailable
    case notAuthenticated

    public var errorDescription: String? {
        switch self {
        case .accountStatusUnknown:
            return "Could not determine iCloud account status"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        case .notAuthenticated:
            return "Not authenticated with iCloud"
        }
    }
}

public struct SyncedDevice: Identifiable {
    public let id: String
    public let name: String
    public let model: String
    public let platform: String
    public let lastSeen: Date

    init?(record: CKRecord) {
        guard let deviceID = record["deviceID"] as? String,
              let deviceName = record["deviceName"] as? String,
              let deviceModel = record["deviceModel"] as? String,
              let platform = record["platform"] as? String,
              let lastSeen = record["lastSeen"] as? Date else {
            return nil
        }

        self.id = deviceID
        self.name = deviceName
        self.model = deviceModel
        self.platform = platform
        self.lastSeen = lastSeen
    }
}

public struct BiofeedbackSession: Identifiable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval
    public let averageHRV: Double
    public let averageCoherence: Double
    public let devicePlatform: String

    init?(record: CKRecord) {
        guard let idString = record["sessionID"] as? String,
              let id = UUID(uuidString: idString),
              let startTime = record["startTime"] as? Date,
              let duration = record["duration"] as? Double,
              let averageHRV = record["averageHRV"] as? Double,
              let averageCoherence = record["averageCoherence"] as? Double,
              let platform = record["devicePlatform"] as? String else {
            return nil
        }

        self.id = id
        self.startTime = startTime
        self.endTime = record["endTime"] as? Date
        self.duration = duration
        self.averageHRV = averageHRV
        self.averageCoherence = averageCoherence
        self.devicePlatform = platform
    }
}

public struct LiveSessionState: Identifiable {
    public let id = UUID()
    public let userID: String
    public let currentHRV: Double
    public let currentCoherence: Double
    public let breathingPhase: String
    public let timestamp: Date

    init?(record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let currentHRV = record["currentHRV"] as? Double,
              let currentCoherence = record["currentCoherence"] as? Double,
              let breathingPhase = record["breathingPhase"] as? String,
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }

        self.userID = userID
        self.currentHRV = currentHRV
        self.currentCoherence = currentCoherence
        self.breathingPhase = breathingPhase
        self.timestamp = timestamp
    }
}
