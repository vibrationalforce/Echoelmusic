/*
  ==============================================================================

    WatchBridge.swift
    iOS-side Watch Connectivity Bridge

    Receives bio-data from Apple Watch and sends commands/haptics back.
    Integrates with Ralph Wiggum systems for bio-reactive music.

  ==============================================================================
*/

import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Bridge Protocol

protocol WatchBridgeDelegate: AnyObject {
    func watchBridge(_ bridge: WatchBridge, didReceiveBioData data: BioData)
    func watchBridge(_ bridge: WatchBridge, didReceiveCommand command: WatchCommand)
}

// MARK: - Data Types

struct BioData {
    let coherence: Double
    let hrv: Double
    let heartRate: Double
    let timestamp: Date

    var isHighCoherence: Bool { coherence > 0.7 }
    var isLowCoherence: Bool { coherence < 0.3 }
    var isHighStress: Bool { heartRate > 100 && hrv < 30 }
}

enum WatchCommand {
    case play
    case pause
    case stop
    case record
    case triggerLoop(String)
}

// MARK: - Watch Bridge

class WatchBridge: NSObject, ObservableObject {
    static let shared = WatchBridge()

    // Published properties for SwiftUI
    @Published var isWatchConnected = false
    @Published var isWatchReachable = false
    @Published var latestBioData: BioData?

    // Delegate for non-reactive code
    weak var delegate: WatchBridgeDelegate?

    // Combine publishers
    let bioDataPublisher = PassthroughSubject<BioData, Never>()
    let commandPublisher = PassthroughSubject<WatchCommand, Never>()

    private var session: WCSession?
    private var bioDataHistory: [BioData] = []
    private let maxHistorySize = 60  // 1 minute at 1Hz

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Public Interface

    /// Send haptic feedback to Watch
    func sendHaptic(_ pattern: HapticPattern) {
        sendMessage(["type": "haptic", "pattern": pattern.rawValue])
    }

    /// Notify Watch of transport state change
    func notifyTransportState(_ state: TransportState) {
        sendMessage(["type": "transport", "state": state.rawValue])
    }

    /// Notify Watch of musical event (for haptic sync)
    func notifyMusicalEvent(_ event: MusicalEvent) {
        switch event {
        case .beat:
            sendHaptic(.beat)
        case .downbeat:
            sendHaptic(.downbeat)
        case .loopStart:
            sendHaptic(.notification)
        case .recordStart:
            sendHaptic(.success)
        }
    }

    /// Get average bio data over time window
    func getAverageBioData(seconds: Int = 30) -> BioData? {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let recentData = bioDataHistory.filter { $0.timestamp > cutoff }

        guard !recentData.isEmpty else { return nil }

        let avgCoherence = recentData.map(\.coherence).reduce(0, +) / Double(recentData.count)
        let avgHRV = recentData.map(\.hrv).reduce(0, +) / Double(recentData.count)
        let avgHeartRate = recentData.map(\.heartRate).reduce(0, +) / Double(recentData.count)

        return BioData(
            coherence: avgCoherence,
            hrv: avgHRV,
            heartRate: avgHeartRate,
            timestamp: Date()
        )
    }

    /// Check if user appears to be in flow state
    var isInFlowState: Bool {
        guard let recent = getAverageBioData(seconds: 60) else { return false }
        return recent.coherence > 0.6 && recent.hrv > 40
    }

    /// Check if user appears stressed
    var isStressed: Bool {
        guard let recent = getAverageBioData(seconds: 30) else { return false }
        return recent.isHighStress
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: [String: Any]) {
        guard let session = session, session.isReachable else { return }

        session.sendMessage(message, replyHandler: nil) { error in
            print("Watch message error: \(error.localizedDescription)")
        }
    }

    private func processReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "bioData":
            processBioData(message)
        case "transport":
            processTransportCommand(message)
        case "loop":
            processLoopCommand(message)
        default:
            break
        }
    }

    private func processBioData(_ message: [String: Any]) {
        guard
            let coherence = message["coherence"] as? Double,
            let hrv = message["hrv"] as? Double,
            let heartRate = message["heartRate"] as? Double
        else { return }

        let data = BioData(
            coherence: coherence,
            hrv: hrv,
            heartRate: heartRate,
            timestamp: Date()
        )

        // Update history
        bioDataHistory.append(data)
        if bioDataHistory.count > maxHistorySize {
            bioDataHistory.removeFirst()
        }

        // Publish
        DispatchQueue.main.async {
            self.latestBioData = data
            self.bioDataPublisher.send(data)
            self.delegate?.watchBridge(self, didReceiveBioData: data)
        }
    }

    private func processTransportCommand(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        let command: WatchCommand
        switch action {
        case "play": command = .play
        case "pause": command = .pause
        case "stop": command = .stop
        case "record": command = .record
        default: return
        }

        DispatchQueue.main.async {
            self.commandPublisher.send(command)
            self.delegate?.watchBridge(self, didReceiveCommand: command)
        }
    }

    private func processLoopCommand(_ message: [String: Any]) {
        guard let name = message["name"] as? String else { return }

        DispatchQueue.main.async {
            self.commandPublisher.send(.triggerLoop(name))
            self.delegate?.watchBridge(self, didReceiveCommand: .triggerLoop(name))
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for new watch
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        processReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        processReceivedMessage(message)
        replyHandler(["status": "received"])
    }
}

// MARK: - Supporting Types

enum HapticPattern: String {
    case beat
    case downbeat
    case success
    case notification
}

enum TransportState: String {
    case playing
    case paused
    case stopped
    case recording
}

enum MusicalEvent {
    case beat
    case downbeat
    case loopStart
    case recordStart
}

// MARK: - C++ Bridge (for JUCE integration)

/// Bridge to expose Watch data to C++ code
@objc public class WatchBridgeObjC: NSObject {

    @objc public static let shared = WatchBridgeObjC()

    private let bridge = WatchBridge.shared

    @objc public var isConnected: Bool {
        bridge.isWatchConnected && bridge.isWatchReachable
    }

    @objc public var currentCoherence: Double {
        bridge.latestBioData?.coherence ?? 0.5
    }

    @objc public var currentHRV: Double {
        bridge.latestBioData?.hrv ?? 45.0
    }

    @objc public var currentHeartRate: Double {
        bridge.latestBioData?.heartRate ?? 72.0
    }

    @objc public var isInFlowState: Bool {
        bridge.isInFlowState
    }

    @objc public var isStressed: Bool {
        bridge.isStressed
    }

    @objc public func sendBeatHaptic() {
        bridge.sendHaptic(.beat)
    }

    @objc public func sendDownbeatHaptic() {
        bridge.sendHaptic(.downbeat)
    }

    @objc public func notifyRecordStart() {
        bridge.notifyMusicalEvent(.recordStart)
    }

    @objc public func notifyLoopStart() {
        bridge.notifyMusicalEvent(.loopStart)
    }

    /// Register callback for bio data updates (called from C++)
    private var bioDataCallback: ((Double, Double, Double) -> Void)?

    @objc public func registerBioDataCallback(_ callback: @escaping (Double, Double, Double) -> Void) {
        bioDataCallback = callback

        bridge.delegate = self
    }
}

extension WatchBridgeObjC: WatchBridgeDelegate {
    public func watchBridge(_ bridge: WatchBridge, didReceiveBioData data: BioData) {
        bioDataCallback?(data.coherence, data.hrv, data.heartRate)
    }

    public func watchBridge(_ bridge: WatchBridge, didReceiveCommand command: WatchCommand) {
        // Handle commands - integrate with C++ transport
    }
}
