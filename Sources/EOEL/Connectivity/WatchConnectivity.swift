//
//  WatchConnectivity.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  WATCH CONNECTIVITY - iPhone ↔ Watch Real-Time Sync
//  Bidirectional biofeedback data streaming
//

import Foundation
import WatchConnectivity
import Combine

#if os(iOS) || os(watchOS)

/// Manages real-time communication between iPhone and Apple Watch
/// Syncs biofeedback data, sessions, and settings bidirectionally
@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    /// Connection status
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false

    /// Received data from counterpart
    @Published var receivedBioData: BioDataMessage?
    @Published var receivedSession: SessionMessage?

    // MARK: - Private Properties

    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()

    // Message queue for when watch is unreachable
    private var messageQueue: [String: Any] = [:]
    private let maxQueueSize = 50

    // MARK: - Data Models

    struct BioDataMessage: Codable {
        let heartRate: Double
        let hrv: Double
        let coherence: Double
        let timestamp: Date
        let source: DataSource

        enum DataSource: String, Codable {
            case iPhone
            case watch
        }
    }

    struct SessionMessage: Codable {
        let sessionType: String
        let duration: TimeInterval
        let avgHeartRate: Double
        let avgHRV: Double
        let avgCoherence: Double
        let startDate: Date
        let endDate: Date
    }

    struct SettingsMessage: Codable {
        let breathingRate: Double
        let hapticEnabled: Bool
        let audioEnabled: Bool
        let targetCoherence: Double
    }

    // MARK: - Initialization

    override private init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("⌚ WatchConnectivity initialized")
        } else {
            print("⚠️ WatchConnectivity not supported on this device")
        }
    }

    // MARK: - Send Methods

    /// Send real-time biofeedback data
    func sendBioData(heartRate: Double, hrv: Double, coherence: Double) {
        let message = BioDataMessage(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            timestamp: Date(),
            source: determineSource()
        )

        let dict: [String: Any] = [
            "type": "bioData",
            "heartRate": heartRate,
            "hrv": hrv,
            "coherence": coherence,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "source": message.source.rawValue
        ]

        sendMessage(dict, replyHandler: { reply in
            print("⌚ Bio data acknowledged: \(reply)")
        }, errorHandler: { error in
            print("⚠️ Failed to send bio data: \(error.localizedDescription)")
        })
    }

    /// Send completed session data
    func sendSession(_ session: SessionMessage) {
        let dict: [String: Any] = [
            "type": "session",
            "sessionType": session.sessionType,
            "duration": session.duration,
            "avgHeartRate": session.avgHeartRate,
            "avgHRV": session.avgHRV,
            "avgCoherence": session.avgCoherence,
            "startDate": session.startDate.timeIntervalSince1970,
            "endDate": session.endDate.timeIntervalSince1970
        ]

        transferUserInfo(dict)
        print("⌚ Session data queued for transfer")
    }

    /// Send settings update
    func sendSettings(_ settings: SettingsMessage) {
        let dict: [String: Any] = [
            "type": "settings",
            "breathingRate": settings.breathingRate,
            "hapticEnabled": settings.hapticEnabled,
            "audioEnabled": settings.audioEnabled,
            "targetCoherence": settings.targetCoherence
        ]

        updateApplicationContext(dict)
        print("⌚ Settings synced to counterpart")
    }

    /// Send command (start/stop session, change mode, etc.)
    func sendCommand(_ command: String, parameters: [String: Any] = [:]) {
        var dict = parameters
        dict["type"] = "command"
        dict["command"] = command

        sendMessage(dict, replyHandler: { reply in
            print("⌚ Command '\(command)' acknowledged: \(reply)")
        }, errorHandler: { error in
            print("⚠️ Command '\(command)' failed: \(error.localizedDescription)")
        })
    }

    // MARK: - Private Send Helpers

    private func sendMessage(_ message: [String: Any],
                            replyHandler: (([String: Any]) -> Void)? = nil,
                            errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
        } else {
            // Queue message for later
            queueMessage(message)
        }
    }

    private func transferUserInfo(_ userInfo: [String: Any]) {
        guard let session = session else { return }
        session.transferUserInfo(userInfo)
    }

    private func updateApplicationContext(_ context: [String: Any]) {
        guard let session = session else { return }

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("⚠️ Failed to update application context: \(error.localizedDescription)")
        }
    }

    private func queueMessage(_ message: [String: Any]) {
        let id = UUID().uuidString
        messageQueue[id] = message

        // Limit queue size
        if messageQueue.count > maxQueueSize {
            // Remove oldest message (first key)
            if let firstKey = messageQueue.keys.first {
                messageQueue.removeValue(forKey: firstKey)
            }
        }

        print("⌚ Message queued (\(messageQueue.count) in queue)")
    }

    private func flushMessageQueue() {
        guard isReachable, !messageQueue.isEmpty else { return }

        print("⌚ Flushing \(messageQueue.count) queued messages")

        for (id, message) in messageQueue {
            if let dict = message as? [String: Any] {
                sendMessage(dict, replyHandler: { _ in
                    self.messageQueue.removeValue(forKey: id)
                }, errorHandler: { error in
                    print("⚠️ Queued message failed: \(error.localizedDescription)")
                })
            }
        }
    }

    private func determineSource() -> BioDataMessage.DataSource {
        #if os(iOS)
        return .iPhone
        #elseif os(watchOS)
        return .watch
        #endif
    }

    // MARK: - File Transfer (for session recordings, etc.)

    func transferFile(at url: URL, metadata: [String: Any]? = nil) {
        guard let session = session else { return }

        session.transferFile(url, metadata: metadata)
        print("⌚ File transfer started: \(url.lastPathComponent)")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("⚠️ WCSession activation failed: \(error.localizedDescription)")
            return
        }

        switch activationState {
        case .activated:
            print("✅ WCSession activated")
            updateStatus()
        case .inactive:
            print("⚠️ WCSession inactive")
        case .notActivated:
            print("⚠️ WCSession not activated")
        @unknown default:
            print("⚠️ WCSession unknown state")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WCSession deactivated")
        // Reactivate session
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateStatus()

            if session.isReachable {
                print("✅ Watch is reachable - flushing queue")
                flushMessageQueue()
            }
        }
    }

    // MARK: - Receive Messages

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(userInfo)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(applicationContext)
        }
    }

    // MARK: - File Transfer

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            print("⌚ Received file: \(file.fileURL.lastPathComponent)")
            // Handle received file (session recording, etc.)
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("⚠️ File transfer failed: \(error.localizedDescription)")
        } else {
            print("✅ File transfer completed")
        }
    }

    // MARK: - Message Handling

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            print("⚠️ Received message without type")
            return
        }

        switch type {
        case "bioData":
            handleBioData(message)
        case "session":
            handleSession(message)
        case "settings":
            handleSettings(message)
        case "command":
            handleCommand(message)
        default:
            print("⚠️ Unknown message type: \(type)")
        }
    }

    private func handleBioData(_ message: [String: Any]) {
        guard let heartRate = message["heartRate"] as? Double,
              let hrv = message["hrv"] as? Double,
              let coherence = message["coherence"] as? Double,
              let timestampInterval = message["timestamp"] as? TimeInterval,
              let sourceString = message["source"] as? String,
              let source = BioDataMessage.DataSource(rawValue: sourceString) else {
            print("⚠️ Invalid bio data message")
            return
        }

        let bioData = BioDataMessage(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            timestamp: Date(timeIntervalSince1970: timestampInterval),
            source: source
        )

        receivedBioData = bioData
        print("⌚ Received bio data from \(source.rawValue): HR=\(Int(heartRate)), HRV=\(Int(hrv)), Coherence=\(Int(coherence))")
    }

    private func handleSession(_ message: [String: Any]) {
        guard let sessionType = message["sessionType"] as? String,
              let duration = message["duration"] as? TimeInterval,
              let avgHeartRate = message["avgHeartRate"] as? Double,
              let avgHRV = message["avgHRV"] as? Double,
              let avgCoherence = message["avgCoherence"] as? Double,
              let startDateInterval = message["startDate"] as? TimeInterval,
              let endDateInterval = message["endDate"] as? TimeInterval else {
            print("⚠️ Invalid session message")
            return
        }

        let session = SessionMessage(
            sessionType: sessionType,
            duration: duration,
            avgHeartRate: avgHeartRate,
            avgHRV: avgHRV,
            avgCoherence: avgCoherence,
            startDate: Date(timeIntervalSince1970: startDateInterval),
            endDate: Date(timeIntervalSince1970: endDateInterval)
        )

        receivedSession = session
        print("⌚ Received session: \(sessionType), Duration: \(Int(duration))s")
    }

    private func handleSettings(_ message: [String: Any]) {
        print("⌚ Received settings update")
        // Apply settings to local app
    }

    private func handleCommand(_ message: [String: Any]) {
        guard let command = message["command"] as? String else {
            print("⚠️ Invalid command message")
            return
        }

        print("⌚ Received command: \(command)")

        switch command {
        case "startSession":
            // Trigger session start on counterpart
            break
        case "stopSession":
            // Trigger session stop on counterpart
            break
        case "syncNow":
            // Force sync all data
            break
        default:
            print("⚠️ Unknown command: \(command)")
        }
    }

    // MARK: - Status Updates

    private func updateStatus() {
        guard let session = session else { return }

        isReachable = session.isReachable

        #if os(iOS)
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled

        print("⌚ Status: Paired=\(isPaired), Installed=\(isWatchAppInstalled), Reachable=\(isReachable)")
        #elseif os(watchOS)
        print("⌚ Status: Reachable=\(isReachable)")
        #endif
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// SwiftUI view modifier for WatchConnectivity
struct WatchConnectivityModifier: ViewModifier {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(connectivity)
            .onChange(of: connectivity.isReachable) { newValue in
                print("⌚ Reachability changed: \(newValue)")
            }
    }
}

extension View {
    func withWatchConnectivity() -> some View {
        modifier(WatchConnectivityModifier())
    }
}

#endif
