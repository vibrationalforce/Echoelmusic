import Foundation
import ActivityKit
import Combine

/// Live Activity manager for real-time session updates
///
/// **Purpose:** Manage Dynamic Island and Lock Screen Live Activities
///
/// **Features:**
/// - Start Live Activity when session begins
/// - Update every 1-5 seconds with new HRV/coherence data
/// - End Live Activity when session completes
/// - Automatic cleanup on app termination
///
/// **Platform:** iOS 16.1+ (Live Activities)
///
/// **Usage:**
/// ```swift
/// let manager = LiveActivityManager.shared
///
/// // Start session
/// manager.startActivity(sessionType: .hrvMonitoring)
///
/// // Update during session
/// manager.updateActivity(hrv: 67.5, coherence: 75.0, heartRate: 68)
///
/// // End session
/// manager.endActivity()
/// ```
///
@available(iOS 16.1, *)
@MainActor
public class LiveActivityManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = LiveActivityManager()

    // MARK: - Published Properties

    /// Whether Live Activity is currently active
    @Published public private(set) var isActive: Bool = false

    /// Current activity ID
    @Published public private(set) var currentActivityID: String?

    // MARK: - Private Properties

    private var currentActivity: Activity<BiofeedbackActivityAttributes>?
    private var sessionStartTime: Date?
    private var sessionID: String?
    private var sessionType: SessionType?
    private var targetDuration: TimeInterval?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNotifications()
        print("[LiveActivity] 🎬 Dynamic Island manager initialized")
    }

    // MARK: - Start Activity

    /// Start Live Activity for biofeedback session
    public func startActivity(
        sessionType: SessionType,
        targetDuration: TimeInterval? = nil,
        userName: String? = nil
    ) {
        // Check if already active
        guard !isActive else {
            print("[LiveActivity] ⚠️ Activity already active")
            return
        }

        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] ⚠️ Live Activities not enabled")
            return
        }

        // Generate session ID
        let sessionID = UUID().uuidString
        let startTime = Date()

        // Create attributes (static data)
        let attributes = BiofeedbackActivityAttributes(
            sessionID: sessionID,
            sessionType: sessionType,
            startTime: startTime,
            userName: userName
        )

        // Create initial content state (dynamic data)
        let contentState = BiofeedbackActivityAttributes.ContentState(
            currentHRV: 0.0,
            currentCoherence: 0.0,
            currentHeartRate: 70.0,
            breathingPhase: .rest,
            elapsedTime: 0,
            targetDuration: targetDuration
        )

        do {
            // Request activity
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )

            // Store activity
            self.currentActivity = activity
            self.sessionStartTime = startTime
            self.sessionID = sessionID
            self.sessionType = sessionType
            self.targetDuration = targetDuration
            self.currentActivityID = activity.id
            self.isActive = true

            print("[LiveActivity] ✅ Activity started: \(sessionType.displayName)")
            print("[LiveActivity] 🎬 Dynamic Island now showing session")

        } catch {
            print("[LiveActivity] ❌ Failed to start activity: \(error)")
        }
    }

    // MARK: - Update Activity

    /// Update Live Activity with new biometric data
    public func updateActivity(
        hrv: Double,
        coherence: Double,
        heartRate: Double,
        breathingPhase: BreathingPhase = .rest
    ) {
        guard let activity = currentActivity,
              let startTime = sessionStartTime else {
            return
        }

        // Calculate elapsed time
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Create updated content state
        let contentState = BiofeedbackActivityAttributes.ContentState(
            currentHRV: hrv,
            currentCoherence: coherence,
            currentHeartRate: heartRate,
            breathingPhase: breathingPhase,
            elapsedTime: elapsedTime,
            targetDuration: targetDuration
        )

        // Update activity
        Task {
            await activity.update(
                .init(state: contentState, staleDate: nil)
            )

            // Debug log (throttled)
            if Int(elapsedTime) % 5 == 0 {
                print("[LiveActivity] 🔄 Updated: HRV \(String(format: "%.1f", hrv))ms, Coherence \(String(format: "%.0f", coherence))%")
            }
        }
    }

    /// Update breathing phase only
    public func updateBreathingPhase(_ phase: BreathingPhase) {
        guard currentActivity != nil else { return }

        // This will trigger an update with the new phase
        // The caller should provide current HRV/coherence values
        print("[LiveActivity] 🌬️ Breathing phase: \(phase.rawValue)")
    }

    // MARK: - End Activity

    /// End Live Activity (session completed)
    public func endActivity(finalState: SessionEndState = .completed) {
        guard let activity = currentActivity else {
            print("[LiveActivity] ⚠️ No active activity to end")
            return
        }

        Task {
            // Determine dismissal policy
            let dismissalPolicy: ActivityUIDismissalPolicy

            switch finalState {
            case .completed:
                // Show for 4 hours on Lock Screen after completion
                dismissalPolicy = .default

            case .cancelled:
                // Dismiss immediately
                dismissalPolicy = .immediate

            case .paused:
                // Show for 1 hour
                dismissalPolicy = .after(Date().addingTimeInterval(3600))
            }

            // End activity
            await activity.end(
                .init(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: dismissalPolicy
            )

            // Clear state
            await MainActor.run {
                self.currentActivity = nil
                self.sessionStartTime = nil
                self.sessionID = nil
                self.sessionType = nil
                self.targetDuration = nil
                self.currentActivityID = nil
                self.isActive = false
            }

            print("[LiveActivity] 🛑 Activity ended: \(finalState)")
        }
    }

    // MARK: - Activity State

    /// Get current activity state
    public func getCurrentState() -> BiofeedbackActivityAttributes.ContentState? {
        return currentActivity?.content.state
    }

    /// Get session elapsed time
    public func getElapsedTime() -> TimeInterval? {
        guard let startTime = sessionStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    /// Check if target duration reached
    public func isTargetDurationReached() -> Bool {
        guard let target = targetDuration,
              let elapsed = getElapsedTime() else {
            return false
        }

        return elapsed >= target
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Monitor activity state changes
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // End activity when app terminates
                    self?.endActivity(finalState: .paused)
                }
            }
            .store(in: &cancellables)

        print("[LiveActivity] 📡 Notifications configured")
    }

    // MARK: - Activity Info

    /// Check if Live Activities are enabled
    public static func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Get activity authorization status
    public static func getAuthorizationStatus() -> ActivityAuthorizationInfo {
        return ActivityAuthorizationInfo()
    }

    // MARK: - Debugging

    /// Print current activity info
    public func printActivityInfo() {
        guard let activity = currentActivity else {
            print("[LiveActivity] ℹ️ No active activity")
            return
        }

        print("[LiveActivity] 📊 Activity Info:")
        print("  ID: \(activity.id)")
        print("  Session ID: \(sessionID ?? "unknown")")
        print("  Session Type: \(sessionType?.displayName ?? "unknown")")
        print("  Start Time: \(sessionStartTime?.formatted() ?? "unknown")")
        print("  Elapsed Time: \(getElapsedTime() ?? 0) seconds")
        print("  HRV: \(activity.content.state.currentHRV) ms")
        print("  Coherence: \(activity.content.state.currentCoherence)%")
        print("  Heart Rate: \(activity.content.state.currentHeartRate) BPM")
        print("  Breathing: \(activity.content.state.breathingPhase.rawValue)")
    }
}

// MARK: - Supporting Types

@available(iOS 16.1, *)
public enum SessionEndState {
    case completed
    case cancelled
    case paused
}

// MARK: - Convenience Extensions

@available(iOS 16.1, *)
public extension LiveActivityManager {

    /// Start HRV monitoring session
    func startHRVMonitoring(targetDuration: TimeInterval? = nil) {
        startActivity(sessionType: .hrvMonitoring, targetDuration: targetDuration)
    }

    /// Start breathing exercise
    func startBreathingExercise(targetDuration: TimeInterval) {
        startActivity(sessionType: .breathing, targetDuration: targetDuration)
    }

    /// Start coherence training
    func startCoherenceTraining(targetDuration: TimeInterval) {
        startActivity(sessionType: .coherenceTraining, targetDuration: targetDuration)
    }

    /// Start group session
    func startGroupSession(userName: String) {
        startActivity(sessionType: .groupSession, userName: userName)
    }
}
