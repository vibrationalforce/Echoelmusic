import Foundation
import TVServices

/// Top Shelf content manager for tvOS app
///
/// **Purpose:** Update Top Shelf content when app state changes
///
/// **Triggers:**
/// - Session starts → Show active session
/// - Session ends → Show recent sessions
/// - Achievement unlocked → Show in achievements section
/// - App launched → Refresh all content
///
/// **Platform:** tvOS 15.0+
///
@MainActor
public class TopShelfManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = TopShelfManager()

    // MARK: - Private Properties

    private let sharedDefaults = UserDefaults(suiteName: "group.com.echoelmusic.shared")

    // MARK: - Initialization

    private init() {
        print("[TopShelf] 📺 Top Shelf manager initialized")
    }

    // MARK: - Active Session

    /// Set active session (shows in Top Shelf)
    public func setActiveSession(id: String, type: String) {
        sharedDefaults?.set(id, forKey: "activeSessionID")
        sharedDefaults?.set(type, forKey: "activeSessionType")
        sharedDefaults?.synchronize()

        reloadTopShelf()

        print("[TopShelf] ✅ Active session set: \(type)")
    }

    /// Clear active session
    public func clearActiveSession() {
        sharedDefaults?.removeObject(forKey: "activeSessionID")
        sharedDefaults?.removeObject(forKey: "activeSessionType")
        sharedDefaults?.synchronize()

        reloadTopShelf()

        print("[TopShelf] 🗑️ Active session cleared")
    }

    // MARK: - Recent Sessions

    /// Add recent session to Top Shelf
    public func addRecentSession(
        id: String,
        startTime: Date,
        averageHRV: Double,
        averageCoherence: Double
    ) {
        guard let defaults = sharedDefaults else { return }

        // Create session dictionary
        let session: [String: Any] = [
            "id": id,
            "startTime": startTime.timeIntervalSince1970,
            "averageHRV": averageHRV,
            "averageCoherence": averageCoherence
        ]

        // Load existing sessions
        var sessions = defaults.array(forKey: "sessions") as? [[String: Any]] ?? []

        // Add new session at beginning
        sessions.insert(session, at: 0)

        // Keep only last 10 sessions
        if sessions.count > 10 {
            sessions = Array(sessions.prefix(10))
        }

        // Save
        defaults.set(sessions, forKey: "sessions")
        defaults.synchronize()

        reloadTopShelf()

        print("[TopShelf] 💾 Recent session added")
    }

    // MARK: - Achievements

    /// Add achievement to Top Shelf
    public func addAchievement(
        id: String,
        title: String,
        description: String
    ) {
        guard let defaults = sharedDefaults else { return }

        // Create achievement dictionary
        let achievement: [String: Any] = [
            "id": id,
            "title": title,
            "description": description,
            "date": Date().timeIntervalSince1970
        ]

        // Load existing achievements
        var achievements = defaults.array(forKey: "achievements") as? [[String: Any]] ?? []

        // Add new achievement
        achievements.insert(achievement, at: 0)

        // Keep only last 5 achievements
        if achievements.count > 5 {
            achievements = Array(achievements.prefix(5))
        }

        // Save
        defaults.set(achievements, forKey: "achievements")
        defaults.synchronize()

        reloadTopShelf()

        print("[TopShelf] 🏆 Achievement added: \(title)")
    }

    // MARK: - Reload

    /// Reload Top Shelf content
    public func reloadTopShelf() {
        TVTopShelfContentProvider.topShelfContentDidChange()
        print("[TopShelf] 🔄 Content reloaded")
    }

    // MARK: - Clear All

    /// Clear all Top Shelf data
    public func clearAllData() {
        sharedDefaults?.removeObject(forKey: "activeSessionID")
        sharedDefaults?.removeObject(forKey: "activeSessionType")
        sharedDefaults?.removeObject(forKey: "sessions")
        sharedDefaults?.removeObject(forKey: "achievements")
        sharedDefaults?.synchronize()

        reloadTopShelf()

        print("[TopShelf] 🗑️ All Top Shelf data cleared")
    }

    // MARK: - Debugging

    /// Print current Top Shelf data
    public func printTopShelfData() {
        guard let defaults = sharedDefaults else {
            print("[TopShelf] ⚠️ No shared defaults")
            return
        }

        print("[TopShelf] 📊 Current Top Shelf data:")

        if let sessionID = defaults.string(forKey: "activeSessionID"),
           let sessionType = defaults.string(forKey: "activeSessionType") {
            print("  Active Session: \(sessionType) (\(sessionID))")
        } else {
            print("  Active Session: None")
        }

        if let sessions = defaults.array(forKey: "sessions") as? [[String: Any]] {
            print("  Recent Sessions: \(sessions.count)")
        } else {
            print("  Recent Sessions: None")
        }

        if let achievements = defaults.array(forKey: "achievements") as? [[String: Any]] {
            print("  Achievements: \(achievements.count)")
        } else {
            print("  Achievements: None")
        }
    }
}

// MARK: - Integration Extensions

public extension TopShelfManager {

    /// Update when session starts
    func sessionDidStart(id: String, type: SessionType) {
        setActiveSession(id: id, type: type.rawValue)
    }

    /// Update when session ends
    func sessionDidEnd(
        id: String,
        startTime: Date,
        averageHRV: Double,
        averageCoherence: Double
    ) {
        clearActiveSession()
        addRecentSession(
            id: id,
            startTime: startTime,
            averageHRV: averageHRV,
            averageCoherence: averageCoherence
        )
    }

    /// Update when achievement unlocked
    func achievementUnlocked(id: String, title: String, description: String) {
        addAchievement(id: id, title: title, description: description)
    }
}

// MARK: - Session Type

public enum SessionType: String {
    case hrvMonitoring = "hrv"
    case breathing = "breathing"
    case coherence = "coherence"
    case group = "group"

    var displayName: String {
        switch self {
        case .hrvMonitoring:
            return "HRV Monitoring"
        case .breathing:
            return "Breathing Exercise"
        case .coherence:
            return "Coherence Training"
        case .group:
            return "Group Session"
        }
    }
}
