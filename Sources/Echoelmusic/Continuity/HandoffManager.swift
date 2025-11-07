import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Handoff manager for seamless device transitions
///
/// **Purpose:** Enable fluid transitions in the "Erlebnisbad" (experience bath)
///
/// **Scenarios:**
///
/// **Scenario 1: iPhone → Apple Watch**
/// - Start meditation on iPhone
/// - Put phone away
/// - Continue monitoring HRV on Watch
/// **→ Seamless continuation**
///
/// **Scenario 2: Apple Watch → iPhone**
/// - Monitor HRV on Watch during walk
/// - Arrive home
/// - Open iPhone to see detailed analysis
/// **→ Full context available**
///
/// **Scenario 3: iPhone → Apple TV**
/// - Start solo breathing session
/// - Want to share with family
/// - Continue on Apple TV as group session
/// **→ Smooth upgrade to group experience**
///
/// **Scenario 4: Mac → iPhone**
/// - Working on Mac, feeling stressed
/// - Start breathing exercise
/// - Need to leave desk
/// - Continue on iPhone
/// **→ Wellness anywhere**
///
/// **Technical:**
/// - NSUserActivity for state transfer
/// - Continuity framework
/// - Universal Links integration
/// - CloudKit for data sync
///
@MainActor
public class HandoffManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Whether Handoff is available
    @Published public private(set) var isHandoffAvailable: Bool = true

    /// Current activity being advertised
    @Published public private(set) var currentActivity: HandoffActivity?

    // MARK: - Private Properties

    private var userActivity: NSUserActivity?

    // Activity types
    private let sessionActivityType = "com.echoelmusic.session"
    private let breathingActivityType = "com.echoelmusic.breathing"
    private let hrvMonitoringActivityType = "com.echoelmusic.hrv"
    private let groupSessionActivityType = "com.echoelmusic.group"

    // MARK: - Initialization

    public override init() {
        super.init()
        print("[Handoff] 🔄 Seamless device transition manager initialized")
    }

    // MARK: - Start Activity

    /// Start advertising Handoff activity
    public func startActivity(_ activity: HandoffActivity) {
        currentActivity = activity

        let userActivity = NSUserActivity(activityType: activity.type)
        userActivity.title = activity.title
        userActivity.isEligibleForHandoff = true
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true

        // Add user info for state transfer
        userActivity.addUserInfoEntries(from: activity.userInfo)

        // Set keywords for Spotlight
        if let keywords = activity.keywords {
            userActivity.keywords = keywords
        }

        // Make current
        #if os(iOS)
        userActivity.becomeCurrent()
        #endif

        self.userActivity = userActivity

        print("[Handoff] ✅ Activity started: \(activity.title)")
        print("[Handoff] 📱 Available on other devices now")
    }

    /// Stop current Handoff activity
    public func stopActivity() {
        userActivity?.resignCurrent()
        userActivity = nil
        currentActivity = nil

        print("[Handoff] 🛑 Activity stopped")
    }

    // MARK: - Continue Activity

    /// Handle incoming Handoff from another device
    public func continueActivity(_ userActivity: NSUserActivity) -> HandoffActivity? {
        guard let activityType = HandoffActivityType(rawValue: userActivity.activityType) else {
            print("[Handoff] ⚠️ Unknown activity type: \(userActivity.activityType)")
            return nil
        }

        let activity = HandoffActivity(
            type: userActivity.activityType,
            title: userActivity.title ?? "Unknown Activity",
            userInfo: userActivity.userInfo ?? [:],
            activityType: activityType
        )

        print("[Handoff] ✅ Activity received from another device:")
        print("[Handoff] 📱 Type: \(activityType.rawValue)")
        print("[Handoff] 📝 Title: \(activity.title)")

        // Notify app to handle continuation
        NotificationCenter.default.post(
            name: .handoffActivityReceived,
            object: activity
        )

        return activity
    }

    // MARK: - Convenience Methods

    /// Start HRV monitoring session (for Handoff)
    public func startHRVMonitoring(currentHRV: Double, coherence: Double) {
        let activity = HandoffActivity(
            type: hrvMonitoringActivityType,
            title: "HRV Monitoring - \(Int(currentHRV)) ms",
            userInfo: [
                "currentHRV": currentHRV,
                "coherence": coherence,
                "startTime": Date().timeIntervalSince1970
            ],
            activityType: .hrvMonitoring
        )

        startActivity(activity)
    }

    /// Start breathing exercise (for Handoff)
    public func startBreathingExercise(pattern: String, duration: TimeInterval) {
        let activity = HandoffActivity(
            type: breathingActivityType,
            title: "Breathing Exercise - \(pattern)",
            userInfo: [
                "pattern": pattern,
                "duration": duration,
                "startTime": Date().timeIntervalSince1970
            ],
            activityType: .breathing,
            keywords: ["breathing", "meditation", "coherence"]
        )

        startActivity(activity)
    }

    /// Start biofeedback session (for Handoff)
    public func startSession(sessionID: String, sessionType: String) {
        let activity = HandoffActivity(
            type: sessionActivityType,
            title: "Biofeedback Session",
            userInfo: [
                "sessionID": sessionID,
                "sessionType": sessionType,
                "startTime": Date().timeIntervalSince1970
            ],
            activityType: .session
        )

        startActivity(activity)
    }

    /// Start group session (for Handoff)
    public func startGroupSession(sessionID: String, participantCount: Int) {
        let activity = HandoffActivity(
            type: groupSessionActivityType,
            title: "Group Session - \(participantCount) participants",
            userInfo: [
                "sessionID": sessionID,
                "participantCount": participantCount,
                "startTime": Date().timeIntervalSince1970
            ],
            activityType: .groupSession
        )

        startActivity(activity)
    }

    // MARK: - State Restoration

    /// Get state to restore from Handoff
    public func getRestorationState(from activity: HandoffActivity) -> [String: Any] {
        return activity.userInfo
    }

    /// Check if can continue on current device
    public func canContinue(_ activity: HandoffActivity) -> Bool {
        // Check if current device supports the activity type
        switch activity.activityType {
        case .hrvMonitoring:
            // HRV monitoring available on iPhone, Watch, iPad
            #if os(iOS) || os(watchOS)
            return true
            #else
            return false
            #endif

        case .breathing:
            // Breathing available on all platforms
            return true

        case .session:
            // Sessions available on all platforms
            return true

        case .groupSession:
            // Group sessions best on TV, but available everywhere
            return true
        }
    }
}

// MARK: - Supporting Types

public struct HandoffActivity {
    public let type: String
    public let title: String
    public let userInfo: [String: Any]
    public let activityType: HandoffActivityType
    public let keywords: Set<String>?

    public init(
        type: String,
        title: String,
        userInfo: [String: Any],
        activityType: HandoffActivityType,
        keywords: Set<String>? = nil
    ) {
        self.type = type
        self.title = title
        self.userInfo = userInfo
        self.activityType = activityType
        self.keywords = keywords
    }
}

public enum HandoffActivityType: String {
    case session = "com.echoelmusic.session"
    case breathing = "com.echoelmusic.breathing"
    case hrvMonitoring = "com.echoelmusic.hrv"
    case groupSession = "com.echoelmusic.group"

    public var displayName: String {
        switch self {
        case .session:
            return "Biofeedback Session"
        case .breathing:
            return "Breathing Exercise"
        case .hrvMonitoring:
            return "HRV Monitoring"
        case .groupSession:
            return "Group Session"
        }
    }

    public var icon: String {
        switch self {
        case .session:
            return "waveform.path.ecg"
        case .breathing:
            return "wind"
        case .hrvMonitoring:
            return "heart.fill"
        case .groupSession:
            return "person.3.fill"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let handoffActivityReceived = Notification.Name("handoffActivityReceived")
}

// MARK: - Universal Links Support

extension HandoffManager {

    /// Create Universal Link for sharing activity
    public func createUniversalLink(for activity: HandoffActivity) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "echoelmusic.com"

        switch activity.activityType {
        case .session:
            components.path = "/session"
            if let sessionID = activity.userInfo["sessionID"] as? String {
                components.queryItems = [
                    URLQueryItem(name: "id", value: sessionID)
                ]
            }

        case .breathing:
            components.path = "/breathing"
            if let pattern = activity.userInfo["pattern"] as? String {
                components.queryItems = [
                    URLQueryItem(name: "pattern", value: pattern)
                ]
            }

        case .hrvMonitoring:
            components.path = "/hrv"

        case .groupSession:
            components.path = "/group"
            if let sessionID = activity.userInfo["sessionID"] as? String {
                components.queryItems = [
                    URLQueryItem(name: "id", value: sessionID)
                ]
            }
        }

        return components.url
    }

    /// Handle Universal Link
    public func handleUniversalLink(_ url: URL) -> HandoffActivity? {
        guard url.host == "echoelmusic.com" else { return nil }

        let path = url.path
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        var activityType: HandoffActivityType?
        var userInfo: [String: Any] = [:]

        switch path {
        case "/session":
            activityType = .session
            if let id = queryItems.first(where: { $0.name == "id" })?.value {
                userInfo["sessionID"] = id
            }

        case "/breathing":
            activityType = .breathing
            if let pattern = queryItems.first(where: { $0.name == "pattern" })?.value {
                userInfo["pattern"] = pattern
            }

        case "/hrv":
            activityType = .hrvMonitoring

        case "/group":
            activityType = .groupSession
            if let id = queryItems.first(where: { $0.name == "id" })?.value {
                userInfo["sessionID"] = id
            }

        default:
            return nil
        }

        guard let type = activityType else { return nil }

        let activity = HandoffActivity(
            type: type.rawValue,
            title: type.displayName,
            userInfo: userInfo,
            activityType: type
        )

        return activity
    }
}
