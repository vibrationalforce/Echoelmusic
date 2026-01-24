import Foundation
import Combine
import WatchConnectivity

// MARK: - Watch Connectivity Manager

/// Manages bidirectional communication between iPhone and Apple Watch
/// Syncs bio-data, session state, and settings
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    /// Is Watch paired and reachable
    @Published private(set) var isWatchReachable: Bool = false

    /// Is Watch app installed
    @Published private(set) var isWatchAppInstalled: Bool = false

    /// Latest bio data received from Watch
    @Published private(set) var watchBioData: WatchBioData?

    /// Latest session data received from Watch
    @Published private(set) var watchSessionData: WatchSessionData?

    /// Sync status
    @Published private(set) var syncStatus: SyncStatus = .idle

    // MARK: - Types

    struct WatchBioData: Codable {
        let heartRate: Double
        let hrv: Double
        let coherence: Double
        let breathingRate: Double
        let stressLevel: Double
        let timestamp: Date

        static let empty = WatchBioData(
            heartRate: 0,
            hrv: 0,
            coherence: 0,
            breathingRate: 6.0,
            stressLevel: 0.5,
            timestamp: Date()
        )
    }

    struct WatchSessionData: Codable {
        let sessionId: UUID
        let type: String
        let duration: TimeInterval
        let startTime: Date
        let averageHeartRate: Double
        let averageHRV: Double
        let averageCoherence: Double
        let breathingCycles: Int
    }

    struct PhoneToWatchMessage: Codable {
        let type: MessageType
        let payload: Data?
        let timestamp: Date

        enum MessageType: String, Codable {
            case startSession
            case stopSession
            case updateSettings
            case requestBioData
            case sendAudioCue
            case hapticFeedback
        }
    }

    struct WatchToPhoneMessage: Codable {
        let type: MessageType
        let payload: Data?
        let timestamp: Date

        enum MessageType: String, Codable {
            case bioDataUpdate
            case sessionComplete
            case sessionStarted
            case complicationUpdate
            case userAction
        }
    }

    enum SyncStatus {
        case idle
        case syncing
        case synced
        case error(String)
    }

    // MARK: - Private Properties

    private let session: WCSession?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Message Keys

    private enum MessageKey {
        static let type = "type"
        static let payload = "payload"
        static let timestamp = "timestamp"
        static let heartRate = "heartRate"
        static let hrv = "hrv"
        static let coherence = "coherence"
        static let breathingRate = "breathingRate"
        static let sessionType = "sessionType"
        static let duration = "duration"
    }

    // MARK: - Initialization

    private override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }

        super.init()

        setupSession()
    }

    // MARK: - Setup

    private func setupSession() {
        guard let session = session else {
            log.info("⌚ WatchConnectivity not supported on this device", category: .system)
            return
        }

        session.delegate = self
        session.activate()

        log.info("⌚ WatchConnectivity session activated", category: .system)
    }

    // MARK: - Public Methods

    /// Send bio data to Watch for display
    func sendBioDataToWatch(heartRate: Double, hrv: Double, coherence: Double) {
        guard let session = session, session.isReachable else {
            log.info("⌚ Watch not reachable", category: .system)
            return
        }

        let message: [String: Any] = [
            MessageKey.type: "bioUpdate",
            MessageKey.heartRate: heartRate,
            MessageKey.hrv: hrv,
            MessageKey.coherence: coherence,
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            log.error("⌚ Failed to send bio data: \(error.localizedDescription)", category: .system)
        }
    }

    /// Request Watch to start a session
    func startWatchSession(type: String, duration: TimeInterval) {
        guard let session = session, session.isReachable else {
            log.info("⌚ Watch not reachable", category: .system)
            return
        }

        let message: [String: Any] = [
            MessageKey.type: "startSession",
            MessageKey.sessionType: type,
            MessageKey.duration: duration,
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { reply in
            log.info("⌚ Watch session started: \(reply)", category: .system)
        }) { error in
            log.error("⌚ Failed to start watch session: \(error.localizedDescription)", category: .system)
        }
    }

    /// Request Watch to stop the current session
    func stopWatchSession() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            MessageKey.type: "stopSession",
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            log.error("⌚ Failed to stop watch session: \(error.localizedDescription)", category: .system)
        }
    }

    /// Send haptic feedback command to Watch
    func triggerWatchHaptic(type: String) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            MessageKey.type: "haptic",
            "hapticType": type,
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Send settings update to Watch
    func updateWatchSettings(_ settings: [String: Any]) {
        guard let session = session else { return }

        do {
            try session.updateApplicationContext(settings)
            log.info("⌚ Watch settings updated", category: .system)
        } catch {
            log.error("⌚ Failed to update watch settings: \(error.localizedDescription)", category: .system)
        }
    }

    /// Request latest bio data from Watch
    func requestBioData() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            MessageKey.type: "requestBioData",
            MessageKey.timestamp: Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.handleBioDataReply(reply)
            }
        }) { error in
            log.error("⌚ Failed to request bio data: \(error.localizedDescription)", category: .system)
        }
    }

    /// Transfer a file to Watch (e.g., audio cues, presets)
    func transferFileToWatch(url: URL, metadata: [String: Any]? = nil) {
        guard let session = session else { return }

        session.transferFile(url, metadata: metadata)
        log.info("⌚ File transfer initiated: \(url.lastPathComponent)", category: .system)
    }

    /// Update Watch complication with latest data
    func updateComplication(heartRate: Double, coherence: Double) {
        guard let session = session, session.isComplicationEnabled else { return }

        let userInfo: [String: Any] = [
            "complicationData": [
                MessageKey.heartRate: heartRate,
                MessageKey.coherence: coherence,
                MessageKey.timestamp: Date().timeIntervalSince1970
            ]
        ]

        session.transferCurrentComplicationUserInfo(userInfo)
        log.info("⌚ Complication updated", category: .system)
    }

    // MARK: - Private Methods

    private func handleBioDataReply(_ reply: [String: Any]) {
        guard let heartRate = reply[MessageKey.heartRate] as? Double,
              let hrv = reply[MessageKey.hrv] as? Double,
              let coherence = reply[MessageKey.coherence] as? Double else {
            return
        }

        let breathingRate = reply[MessageKey.breathingRate] as? Double ?? 6.0
        let stressLevel = reply["stressLevel"] as? Double ?? 0.5

        watchBioData = WatchBioData(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            breathingRate: breathingRate,
            stressLevel: stressLevel,
            timestamp: Date()
        )

        log.info("⌚ Received bio data: HR=\(heartRate), HRV=\(hrv), Coherence=\(coherence)", category: .system)
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message[MessageKey.type] as? String else { return }

        switch type {
        case "bioDataUpdate":
            handleBioDataReply(message)

        case "sessionComplete":
            handleSessionComplete(message)

        case "userAction":
            handleUserAction(message)

        default:
            log.info("⌚ Unknown message type: \(type)", category: .system)
        }
    }

    private func handleSessionComplete(_ message: [String: Any]) {
        guard let sessionId = message["sessionId"] as? String,
              let duration = message[MessageKey.duration] as? TimeInterval,
              let avgHR = message["avgHeartRate"] as? Double,
              let avgHRV = message["avgHRV"] as? Double,
              let avgCoherence = message["avgCoherence"] as? Double else {
            return
        }

        watchSessionData = WatchSessionData(
            sessionId: UUID(uuidString: sessionId) ?? UUID(),
            type: message[MessageKey.sessionType] as? String ?? "unknown",
            duration: duration,
            startTime: Date(timeIntervalSince1970: message["startTime"] as? TimeInterval ?? 0),
            averageHeartRate: avgHR,
            averageHRV: avgHRV,
            averageCoherence: avgCoherence,
            breathingCycles: message["breathingCycles"] as? Int ?? 0
        )

        log.info("⌚ Session complete: \(duration)s, Avg Coherence: \(avgCoherence)", category: .system)

        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .watchSessionCompleted,
            object: nil,
            userInfo: ["sessionData": watchSessionData as Any]
        )
    }

    private func handleUserAction(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        NotificationCenter.default.post(
            name: .watchUserAction,
            object: nil,
            userInfo: ["action": action]
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                log.error("⌚ WCSession activation failed: \(error.localizedDescription)", category: .system)
                syncStatus = .error(error.localizedDescription)
            } else {
                log.info("⌚ WCSession activated: \(activationState.rawValue)", category: .system)
                isWatchReachable = session.isReachable
                isWatchAppInstalled = session.isWatchAppInstalled
                syncStatus = .synced
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        log.info("⌚ WCSession became inactive", category: .system)
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        log.info("⌚ WCSession deactivated", category: .system)
        // Reactivate for switching watches
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            log.info("⌚ Watch reachability changed: \(session.isReachable)", category: .system)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleReceivedMessage(message)

            // Send acknowledgment
            replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            log.info("⌚ Received application context: \(applicationContext)", category: .system)
            // Handle settings sync from Watch
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if let bioData = userInfo["bioData"] as? [String: Any] {
                handleBioDataReply(bioData)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            log.error("⌚ File transfer failed: \(error.localizedDescription)", category: .system)
        } else {
            log.info("⌚ File transfer completed: \(fileTransfer.file.fileURL.lastPathComponent)", category: .system)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchSessionCompleted = Notification.Name("watchSessionCompleted")
    static let watchUserAction = Notification.Name("watchUserAction")
    static let watchBioDataUpdated = Notification.Name("watchBioDataUpdated")
}
