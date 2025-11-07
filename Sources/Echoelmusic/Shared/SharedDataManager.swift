import Foundation
import WidgetKit

/// Shared data manager for communicating with widgets
///
/// **Purpose:** Bridge between main app and WidgetKit extensions
///
/// **Architecture:**
/// - App Groups: group.com.echoelmusic.shared
/// - Shared UserDefaults for simple key-value data
/// - WidgetCenter for triggering widget updates
///
/// **Data Shared:**
/// - Current HRV value
/// - Current coherence score
/// - Current heart rate
/// - Breathing phase
/// - Last updated timestamp
///
/// **Usage:**
/// ```swift
/// let sharedData = SharedDataManager.shared
/// sharedData.updateHRVData(hrv: 67.5, coherence: 75.0, heartRate: 68)
/// ```
///
@MainActor
public class SharedDataManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = SharedDataManager()

    // MARK: - App Group

    private let appGroupID = "group.com.echoelmusic.shared"
    private let sharedDefaults: UserDefaults?

    // MARK: - Initialization

    private init() {
        self.sharedDefaults = UserDefaults(suiteName: appGroupID)

        if sharedDefaults != nil {
            print("[SharedData] 📦 App Group initialized: \(appGroupID)")
        } else {
            print("[SharedData] ⚠️ Failed to initialize App Group")
        }
    }

    // MARK: - HRV Data

    /// Update HRV data for widgets
    public func updateHRVData(
        hrv: Double,
        coherence: Double,
        heartRate: Double,
        breathingPhase: String = "Rest"
    ) {
        guard let defaults = sharedDefaults else {
            print("[SharedData] ⚠️ Shared defaults not available")
            return
        }

        // Write to shared UserDefaults
        defaults.set(hrv, forKey: "currentHRV")
        defaults.set(coherence, forKey: "currentCoherence")
        defaults.set(heartRate, forKey: "currentHeartRate")
        defaults.set(breathingPhase, forKey: "breathingPhase")
        defaults.set(Date(), forKey: "lastUpdated")

        // Synchronize
        defaults.synchronize()

        // Trigger widget update
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        print("[SharedData] ✅ Widget data updated: HRV \(String(format: "%.1f", hrv))ms, Coherence \(String(format: "%.0f", coherence))%")
    }

    /// Read current HRV data
    public func getCurrentHRVData() -> (hrv: Double, coherence: Double, heartRate: Double, breathingPhase: String)? {
        guard let defaults = sharedDefaults else { return nil }

        let hrv = defaults.double(forKey: "currentHRV")
        let coherence = defaults.double(forKey: "currentCoherence")
        let heartRate = defaults.double(forKey: "currentHeartRate")
        let breathingPhase = defaults.string(forKey: "breathingPhase") ?? "Rest"

        guard hrv > 0 else { return nil }

        return (hrv, coherence, heartRate, breathingPhase)
    }

    /// Get last update time
    public func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: "lastUpdated") as? Date
    }

    // MARK: - Session Data

    /// Save completed session for history
    public func saveSession(
        id: String,
        startTime: Date,
        endTime: Date,
        averageHRV: Double,
        averageCoherence: Double
    ) {
        guard let defaults = sharedDefaults else { return }

        // Create session dictionary
        let session: [String: Any] = [
            "id": id,
            "startTime": startTime.timeIntervalSince1970,
            "endTime": endTime.timeIntervalSince1970,
            "averageHRV": averageHRV,
            "averageCoherence": averageCoherence
        ]

        // Load existing sessions
        var sessions = defaults.array(forKey: "sessions") as? [[String: Any]] ?? []

        // Add new session
        sessions.insert(session, at: 0)

        // Keep only last 50 sessions
        if sessions.count > 50 {
            sessions = Array(sessions.prefix(50))
        }

        // Save
        defaults.set(sessions, forKey: "sessions")
        defaults.synchronize()

        print("[SharedData] 💾 Session saved: \(id)")
    }

    /// Get recent sessions
    public func getRecentSessions(limit: Int = 10) -> [[String: Any]] {
        guard let defaults = sharedDefaults else { return [] }

        let sessions = defaults.array(forKey: "sessions") as? [[String: Any]] ?? []

        return Array(sessions.prefix(limit))
    }

    // MARK: - Preferences

    /// Save user preference
    public func savePreference(key: String, value: Any) {
        sharedDefaults?.set(value, forKey: "pref_\(key)")
        sharedDefaults?.synchronize()
    }

    /// Get user preference
    public func getPreference<T>(key: String, defaultValue: T) -> T {
        return sharedDefaults?.object(forKey: "pref_\(key)") as? T ?? defaultValue
    }

    // MARK: - Widget Management

    /// Manually reload all widgets
    public func reloadWidgets() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        print("[SharedData] 🔄 Widgets reloaded")
        #endif
    }

    /// Get current widget timelines
    #if os(iOS)
    public func getCurrentWidgetTimelines() async -> [String] {
        let kind = "EchoelmusicWidget"
        // WidgetCenter doesn't expose timeline info, but we can reload
        return [kind]
    }
    #endif

    // MARK: - Debugging

    /// Print all shared data (for debugging)
    public func printSharedData() {
        guard let defaults = sharedDefaults else {
            print("[SharedData] ⚠️ No shared defaults")
            return
        }

        print("[SharedData] 📊 Current shared data:")
        print("  HRV: \(defaults.double(forKey: "currentHRV"))")
        print("  Coherence: \(defaults.double(forKey: "currentCoherence"))%")
        print("  Heart Rate: \(defaults.double(forKey: "currentHeartRate")) BPM")
        print("  Breathing: \(defaults.string(forKey: "breathingPhase") ?? "Unknown")")

        if let lastUpdated = defaults.object(forKey: "lastUpdated") as? Date {
            print("  Last Updated: \(lastUpdated)")
        }
    }

    /// Clear all shared data
    public func clearAllData() {
        guard let defaults = sharedDefaults else { return }

        let keys = ["currentHRV", "currentCoherence", "currentHeartRate", "breathingPhase", "lastUpdated", "sessions"]

        for key in keys {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()

        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        print("[SharedData] 🗑️ All shared data cleared")
    }
}

// MARK: - Convenience Extensions

public extension SharedDataManager {

    /// Update from BiofeedbackEngine
    func updateFromBiofeedback(
        hrv: Double,
        coherence: Double,
        heartRate: Double
    ) {
        updateHRVData(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            breathingPhase: "Active"
        )
    }

    /// Update during breathing exercise
    func updateDuringBreathing(
        hrv: Double,
        coherence: Double,
        heartRate: Double,
        phase: BreathingPhase
    ) {
        updateHRVData(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            breathingPhase: phase.rawValue
        )
    }
}

// MARK: - Supporting Types

public enum BreathingPhase: String {
    case inhale = "Inhale"
    case hold = "Hold"
    case exhale = "Exhale"
    case rest = "Rest"
}
