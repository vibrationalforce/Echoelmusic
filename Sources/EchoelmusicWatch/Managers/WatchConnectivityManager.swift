import Foundation
import WatchConnectivity
import Combine

/// Manages communication between Apple Watch and iPhone
/// Syncs HRV, heart rate, and breathing session data
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Whether the session is activated and reachable
    @Published private(set) var isReachable: Bool = false

    /// Whether iPhone companion app is installed
    @Published private(set) var isCompanionAppInstalled: Bool = false

    /// Last sync time
    @Published private(set) var lastSyncTime: Date?

    // MARK: - Private Properties

    private var session: WCSession?
    private let healthKitManager: WatchHealthKitManager

    private var syncTimer: Timer?

    // MARK: - Initialization

    init(healthKitManager: WatchHealthKitManager) {
        self.healthKitManager = healthKitManager

        super.init()

        setupSession()
    }

    // MARK: - Session Setup

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[WatchConnectivity] ⚠️  WCSession not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        self.session = session

        print("[WatchConnectivity] ✅ Session setup complete")
    }

    // MARK: - Data Sync

    /// Start automatic syncing every 30 seconds
    func startAutoSync() {
        stopAutoSync()

        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncHealthData()
            }
        }

        print("[WatchConnectivity] ▶️  Auto-sync started (30s interval)")
    }

    /// Stop automatic syncing
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("[WatchConnectivity] ⏹️  Auto-sync stopped")
    }

    /// Sync current health data to iPhone
    func syncHealthData() async {
        guard let session = session, session.isReachable else {
            print("[WatchConnectivity] ⚠️  iPhone not reachable")
            return
        }

        let data: [String: Any] = [
            "type": "healthUpdate",
            "hrv": healthKitManager.currentHRV,
            "heartRate": healthKitManager.heartRate,
            "hrvCoherence": healthKitManager.hrvCoherence,
            "hrvTrend": trendString(healthKitManager.hrvTrend),
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(data, replyHandler: { response in
            Task { @MainActor in
                self.lastSyncTime = Date()
                print("[WatchConnectivity] ✅ Health data synced")
            }
        }, errorHandler: { error in
            print("[WatchConnectivity] ❌ Sync failed: \(error.localizedDescription)")
        })
    }

    /// Send breathing session complete notification
    func sendBreathingSessionComplete(duration: TimeInterval, coherenceImprovement: Double) {
        guard let session = session, session.isReachable else {
            print("[WatchConnectivity] ⚠️  iPhone not reachable")
            return
        }

        let data: [String: Any] = [
            "type": "breathingSessionComplete",
            "duration": duration,
            "coherenceImprovement": coherenceImprovement,
            "finalCoherence": healthKitManager.hrvCoherence,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(data, replyHandler: nil, errorHandler: { error in
            print("[WatchConnectivity] ❌ Session complete send failed: \(error.localizedDescription)")
        })
    }

    // MARK: - Receive Data from iPhone

    private func handleMessage(_ message: [String: Any]) {
        guard let messageType = message["type"] as? String else {
            print("[WatchConnectivity] ⚠️  Unknown message type")
            return
        }

        switch messageType {
        case "breathingConfig":
            handleBreathingConfig(message)

        case "startBreathing":
            handleStartBreathing(message)

        case "stopBreathing":
            handleStopBreathing(message)

        default:
            print("[WatchConnectivity] ⚠️  Unhandled message type: \(messageType)")
        }
    }

    private func handleBreathingConfig(_ message: [String: Any]) {
        // Update breathing configuration from iPhone
        if let inhaleTime = message["inhaleTime"] as? Double,
           let holdTime = message["holdTime"] as? Double,
           let exhaleTime = message["exhaleTime"] as? Double {

            print("[WatchConnectivity] 📥 Breathing config updated: \(inhaleTime)s / \(holdTime)s / \(exhaleTime)s")

            // TODO: Update BreathingGuideView configuration
            // This would require making breathing times @Published or using NotificationCenter
        }
    }

    private func handleStartBreathing(_ message: [String: Any]) {
        print("[WatchConnectivity] 📥 Received start breathing request from iPhone")

        // TODO: Trigger breathing session start
        // This could post a notification that BreathingGuideView listens to
        NotificationCenter.default.post(name: .startBreathingFromiPhone, object: nil)
    }

    private func handleStopBreathing(_ message: [String: Any]) {
        print("[WatchConnectivity] 📥 Received stop breathing request from iPhone")

        // TODO: Trigger breathing session stop
        NotificationCenter.default.post(name: .stopBreathingFromiPhone, object: nil)
    }

    // MARK: - Helpers

    private func trendString(_ trend: HRVTrend) -> String {
        switch trend {
        case .increasing:
            return "increasing"
        case .decreasing:
            return "decreasing"
        case .stable:
            return "stable"
        }
    }

    // MARK: - Cleanup

    deinit {
        stopAutoSync()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[WatchConnectivity] ❌ Activation failed: \(error.localizedDescription)")
                return
            }

            switch activationState {
            case .activated:
                print("[WatchConnectivity] ✅ Session activated")
                self.isCompanionAppInstalled = session.isCompanionAppInstalled

            case .inactive:
                print("[WatchConnectivity] ⚠️  Session inactive")

            case .notActivated:
                print("[WatchConnectivity] ⚠️  Session not activated")

            @unknown default:
                print("[WatchConnectivity] ⚠️  Unknown activation state")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            print("[WatchConnectivity] 📱 Reachability changed: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleMessage(message)

            // Send acknowledgment
            replyHandler(["status": "received"])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startBreathingFromiPhone = Notification.Name("startBreathingFromiPhone")
    static let stopBreathingFromiPhone = Notification.Name("stopBreathingFromiPhone")
}
