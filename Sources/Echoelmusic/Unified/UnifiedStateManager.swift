import Foundation
import Combine
import SwiftUI

/// Unified state manager - Single source of truth across all platforms
///
/// **Purpose:** Coordinate app state across the entire Apple ecosystem
///
/// **Vision: "Nahtloses Erlebnisbad" (Seamless Experience Bath)**
///
/// **Responsibilities:**
/// - Centralize all app state (session, biometrics, preferences)
/// - Coordinate CloudKit sync, Handoff, Widgets, Live Activities, Top Shelf
/// - Ensure consistency across iOS, iPad, Watch, TV, Mac
/// - Handle state transitions automatically
/// - Provide single source of truth
///
/// **State Flow:**
/// ```
/// BiofeedbackEngine → UnifiedStateManager → {
///     - CloudKitSyncManager (iCloud sync)
///     - HandoffManager (device transitions)
///     - SharedDataManager (Widgets)
///     - LiveActivityManager (Dynamic Island)
///     - TopShelfManager (Apple TV)
/// }
/// ```
///
/// **Platform:** iOS 15.0+, watchOS 7.0+, tvOS 15.0+, macOS 11.0+
///
@MainActor
public class UnifiedStateManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = UnifiedStateManager()

    // MARK: - Published State

    /// Current session state
    @Published public private(set) var sessionState: SessionState = .idle

    /// Current biometric data
    @Published public private(set) var biometricData: BiometricData = .empty

    /// Current breathing state
    @Published public private(set) var breathingState: BreathingState = .inactive

    /// User preferences
    @Published public var preferences: UserPreferences = UserPreferences()

    /// Sync status across devices
    @Published public private(set) var syncStatus: SyncStatus = .idle

    // MARK: - Private Properties

    private var currentSessionID: String?
    private var sessionStartTime: Date?

    private var cancellables = Set<AnyCancellable>()

    // Managers
    private let cloudKitSync = CloudKitSyncManager()
    private let handoffManager = HandoffManager()
    private let sharedData = SharedDataManager.shared

    #if os(iOS)
    @available(iOS 16.1, *)
    private lazy var liveActivity = LiveActivityManager.shared
    #endif

    #if os(tvOS)
    private let topShelf = TopShelfManager.shared
    #endif

    // MARK: - Initialization

    private init() {
        setupObservers()
        loadPreferences()
        print("[UnifiedState] 🌊 Unified state manager initialized")
    }

    // MARK: - Session Management

    /// Start new session
    public func startSession(type: SessionType, targetDuration: TimeInterval? = nil) {
        let sessionID = UUID().uuidString
        let startTime = Date()

        // Update local state
        currentSessionID = sessionID
        sessionStartTime = startTime
        sessionState = .active(type: type, startTime: startTime, targetDuration: targetDuration)

        // Start Handoff
        handoffManager.startSession(sessionID: sessionID, sessionType: type.rawValue)

        // Start Live Activity (iOS 16.1+)
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivity.startActivity(
                sessionType: type.liveActivityType,
                targetDuration: targetDuration
            )
        }
        #endif

        // Update Top Shelf (tvOS)
        #if os(tvOS)
        topShelf.sessionDidStart(id: sessionID, type: type.topShelfType)
        #endif

        // Broadcast to CloudKit (for other devices)
        Task {
            let liveState = LiveSessionState(
                userID: getUserID(),
                currentHRV: 0,
                currentCoherence: 0,
                breathingPhase: "Starting",
                timestamp: Date()
            )
            try? await cloudKitSync.broadcastLiveState(liveState)
        }

        print("[UnifiedState] ✅ Session started: \(type.displayName)")
    }

    /// Update session with new biometric data
    public func updateBiometrics(
        hrv: Double,
        coherence: Double,
        heartRate: Double,
        breathingPhase: BreathingPhase? = nil
    ) {
        // Update local state
        biometricData = BiometricData(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            timestamp: Date()
        )

        if let phase = breathingPhase {
            breathingState = .active(phase: phase)
        }

        // Update widgets
        sharedData.updateHRVData(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            breathingPhase: breathingPhase?.rawValue ?? "Active"
        )

        // Update Live Activity
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivity.updateActivity(
                hrv: hrv,
                coherence: coherence,
                heartRate: heartRate,
                breathingPhase: breathingPhase ?? .rest
            )
        }
        #endif

        // Broadcast to CloudKit (throttled)
        throttledCloudKitUpdate(hrv: hrv, coherence: coherence, heartRate: heartRate, breathingPhase: breathingPhase)
    }

    /// End current session
    public func endSession() {
        guard let sessionID = currentSessionID,
              let startTime = sessionStartTime,
              case .active(let type, _, _) = sessionState else {
            print("[UnifiedState] ⚠️ No active session to end")
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Calculate session stats
        let averageHRV = biometricData.hrv
        let averageCoherence = biometricData.coherence

        // Update local state
        sessionState = .idle
        currentSessionID = nil
        sessionStartTime = nil

        // Create session record
        let session = BiofeedbackSession(
            id: UUID(uuidString: sessionID) ?? UUID(),
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            averageHRV: averageHRV,
            averageCoherence: averageCoherence,
            devicePlatform: currentPlatform
        )

        // Save to CloudKit
        Task {
            try? await cloudKitSync.syncSession(session)
        }

        // End Handoff
        handoffManager.stopActivity()

        // End Live Activity
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivity.endActivity(finalState: .completed)
        }
        #endif

        // Update Top Shelf
        #if os(tvOS)
        topShelf.sessionDidEnd(
            id: sessionID,
            startTime: startTime,
            averageHRV: averageHRV,
            averageCoherence: averageCoherence
        )
        #endif

        // Save to shared data
        sharedData.saveSession(
            id: sessionID,
            startTime: startTime,
            endTime: endTime,
            averageHRV: averageHRV,
            averageCoherence: averageCoherence
        )

        print("[UnifiedState] ✅ Session ended: \(type.displayName), Duration: \(Int(duration))s")
    }

    /// Pause current session
    public func pauseSession() {
        guard case .active(let type, let startTime, let targetDuration) = sessionState else {
            return
        }

        sessionState = .paused(type: type, startTime: startTime, targetDuration: targetDuration)

        // End Live Activity with paused state
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivity.endActivity(finalState: .paused)
        }
        #endif

        print("[UnifiedState] ⏸️ Session paused")
    }

    /// Resume paused session
    public func resumeSession() {
        guard case .paused(let type, let startTime, let targetDuration) = sessionState else {
            return
        }

        sessionState = .active(type: type, startTime: startTime, targetDuration: targetDuration)

        // Restart Live Activity
        #if os(iOS)
        if #available(iOS 16.1, *) {
            liveActivity.startActivity(
                sessionType: type.liveActivityType,
                targetDuration: targetDuration
            )
        }
        #endif

        print("[UnifiedState] ▶️ Session resumed")
    }

    // MARK: - Breathing Management

    /// Start breathing exercise
    public func startBreathingExercise(pattern: String, duration: TimeInterval) {
        startSession(type: .breathing, targetDuration: duration)
        breathingState = .active(phase: .rest)

        handoffManager.startBreathingExercise(pattern: pattern, duration: duration)

        print("[UnifiedState] 🌬️ Breathing exercise started: \(pattern)")
    }

    /// Update breathing phase
    public func updateBreathingPhase(_ phase: BreathingPhase) {
        breathingState = .active(phase: phase)

        // Update with current biometrics
        updateBiometrics(
            hrv: biometricData.hrv,
            coherence: biometricData.coherence,
            heartRate: biometricData.heartRate,
            breathingPhase: phase
        )

        print("[UnifiedState] 🌬️ Breathing phase: \(phase.rawValue)")
    }

    // MARK: - Preferences Management

    /// Update user preferences
    public func updatePreferences(_ preferences: UserPreferences) {
        self.preferences = preferences
        savePreferences()

        // Sync to CloudKit
        Task {
            let prefsDict = preferences.toDictionary()
            try? await cloudKitSync.syncPreferences(prefsDict)
        }

        print("[UnifiedState] ⚙️ Preferences updated")
    }

    /// Toggle sync
    public func toggleSync(enabled: Bool) {
        if enabled {
            cloudKitSync.enableSync()
        } else {
            cloudKitSync.disableSync()
        }

        preferences.isSyncEnabled = enabled
        savePreferences()
    }

    // MARK: - Handoff Management

    /// Handle incoming Handoff from another device
    public func handleHandoff(_ activity: HandoffActivity) {
        print("[UnifiedState] 📱 Handoff received: \(activity.title)")

        // Restore session state from Handoff
        switch activity.activityType {
        case .session:
            if let sessionID = activity.userInfo["sessionID"] as? String,
               let sessionType = activity.userInfo["sessionType"] as? String {
                // Resume session
                print("[UnifiedState] ▶️ Resuming session from Handoff")
            }

        case .breathing:
            if let pattern = activity.userInfo["pattern"] as? String,
               let duration = activity.userInfo["duration"] as? TimeInterval {
                startBreathingExercise(pattern: pattern, duration: duration)
            }

        case .hrvMonitoring:
            startSession(type: .hrvMonitoring)

        case .groupSession:
            if let sessionID = activity.userInfo["sessionID"] as? String {
                // Join group session
                print("[UnifiedState] 👥 Joining group session from Handoff")
            }
        }
    }

    // MARK: - CloudKit Sync

    private var lastCloudKitUpdate = Date.distantPast

    private func throttledCloudKitUpdate(
        hrv: Double,
        coherence: Double,
        heartRate: Double,
        breathingPhase: BreathingPhase?
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastCloudKitUpdate) > 5.0 else { return }

        lastCloudKitUpdate = now

        Task {
            let liveState = LiveSessionState(
                userID: getUserID(),
                currentHRV: hrv,
                currentCoherence: coherence,
                breathingPhase: breathingPhase?.rawValue ?? "Active",
                timestamp: now
            )
            try? await cloudKitSync.broadcastLiveState(liveState)
        }
    }

    // MARK: - State Restoration

    /// Restore state from CloudKit
    public func restoreStateFromCloud() async {
        syncStatus = .syncing

        do {
            // Load recent sessions
            let sessions = try await cloudKitSync.loadRecentSessions(limit: 10)
            print("[UnifiedState] 📥 Loaded \(sessions.count) sessions from iCloud")

            // Check for live states from other devices
            let liveStates = try await cloudKitSync.fetchLiveStates()
            print("[UnifiedState] 📡 Found \(liveStates.count) live sessions")

            syncStatus = .synced
        } catch {
            print("[UnifiedState] ❌ State restoration failed: \(error)")
            syncStatus = .error
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Monitor Handoff activity received
        NotificationCenter.default.publisher(for: .handoffActivityReceived)
            .compactMap { $0.object as? HandoffActivity }
            .sink { [weak self] activity in
                Task { @MainActor [weak self] in
                    self?.handleHandoff(activity)
                }
            }
            .store(in: &cancellables)

        print("[UnifiedState] 📡 Observers configured")
    }

    // MARK: - Persistence

    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "userPreferences")
        }
    }

    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        }
    }

    // MARK: - Helpers

    private func getUserID() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

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
}

// MARK: - Supporting Types

public enum SessionState: Equatable {
    case idle
    case active(type: SessionType, startTime: Date, targetDuration: TimeInterval?)
    case paused(type: SessionType, startTime: Date, targetDuration: TimeInterval?)

    public static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.active(let lType, let lStart, let lDuration), .active(let rType, let rStart, let rDuration)):
            return lType == rType && lStart == rStart && lDuration == rDuration
        case (.paused(let lType, let lStart, let lDuration), .paused(let rType, let rStart, let rDuration)):
            return lType == rType && lStart == rStart && lDuration == rDuration
        default:
            return false
        }
    }
}

public enum SessionType: String, Codable {
    case hrvMonitoring = "hrv"
    case breathing = "breathing"
    case coherence = "coherence"
    case groupSession = "group"

    var displayName: String {
        switch self {
        case .hrvMonitoring:
            return "HRV Monitoring"
        case .breathing:
            return "Breathing Exercise"
        case .coherence:
            return "Coherence Training"
        case .groupSession:
            return "Group Session"
        }
    }

    #if os(iOS)
    @available(iOS 16.1, *)
    var liveActivityType: LiveActivityManager.SessionType {
        switch self {
        case .hrvMonitoring:
            return .hrvMonitoring
        case .breathing:
            return .breathing
        case .coherence:
            return .coherenceTraining
        case .groupSession:
            return .groupSession
        }
    }
    #endif

    #if os(tvOS)
    var topShelfType: TopShelfManager.SessionType {
        switch self {
        case .hrvMonitoring:
            return .hrvMonitoring
        case .breathing:
            return .breathing
        case .coherence:
            return .coherence
        case .groupSession:
            return .group
        }
    }
    #endif
}

public struct BiometricData: Equatable {
    public let hrv: Double
    public let coherence: Double
    public let heartRate: Double
    public let timestamp: Date

    public static let empty = BiometricData(
        hrv: 0,
        coherence: 0,
        heartRate: 70,
        timestamp: Date()
    )
}

public enum BreathingState: Equatable {
    case inactive
    case active(phase: BreathingPhase)
}

public enum BreathingPhase: String, Codable {
    case inhale = "Inhale"
    case hold = "Hold"
    case exhale = "Exhale"
    case rest = "Rest"
}

public struct UserPreferences: Codable {
    public var isSyncEnabled: Bool = true
    public var isHandoffEnabled: Bool = true
    public var notificationsEnabled: Bool = true
    public var defaultSessionDuration: TimeInterval = 600 // 10 minutes

    func toDictionary() -> [String: Any] {
        return [
            "isSyncEnabled": isSyncEnabled,
            "isHandoffEnabled": isHandoffEnabled,
            "notificationsEnabled": notificationsEnabled,
            "defaultSessionDuration": defaultSessionDuration
        ]
    }
}

public enum SyncStatus {
    case idle
    case syncing
    case synced
    case error
}
