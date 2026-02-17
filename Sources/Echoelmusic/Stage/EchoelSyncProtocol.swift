// EchoelSyncProtocol.swift
// Echoelmusic — EchoelNet: Proprietary Bio-Reactive Sync Protocol
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelSync: Synchronize biometric state, engine parameters, visual state,
// and session data across all connected Echoelmusic instances in real time.
//
// Use Cases:
// - Multi-device performance: iPhone + iPad + Mac + Apple Watch all in sync
// - Collaborative sessions: Multiple artists sharing bio-reactive state
// - Theater installations: Sync audio, visuals, and lighting across devices
// - Clinical settings: Therapist device syncs with patient device
//
// Transport: Multipeer Connectivity + Bonjour (local) / WebSocket (remote)
// Latency target: <10ms local, <50ms remote
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine
import Network

// MARK: - Sync Payload Types

public enum EchoelSyncPayloadType: String, CaseIterable, Sendable {
    case bioSnapshot = "bio"           // BioSnapshot (HRV, HR, breath, coherence)
    case engineState = "engine"        // All engine parameters
    case visualState = "visual"        // Visual mode, hue, brightness, particles
    case audioState = "audio"          // BPM, key, active synth, mix levels
    case timecode = "timecode"         // Shared timeline position
    case cueEvent = "cue"             // Cue triggers for theater/show control
    case sessionControl = "session"    // Start/stop/pause/transport
    case stageRouting = "stage"        // Output routing changes
}

// MARK: - Sync Peer

public struct EchoelSyncPeer: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let deviceType: String
    public let role: PeerRole
    public var lastSeen: Date
    public var latencyMs: Double
    public var coherence: Float

    public enum PeerRole: String, CaseIterable, Sendable {
        case performer = "Performer"
        case audience = "Audience"
        case therapist = "Therapist"
        case director = "Director"
        case technician = "Technician"
        case observer = "Observer"
    }

    public static func == (lhs: EchoelSyncPeer, rhs: EchoelSyncPeer) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Sync Message

public struct EchoelSyncMessage: Sendable {
    public let type: EchoelSyncPayloadType
    public let senderId: String
    public let timestamp: TimeInterval
    public let payload: [String: String]
    public let sequenceNumber: UInt64

    public init(type: EchoelSyncPayloadType, senderId: String, payload: [String: String]) {
        self.type = type
        self.senderId = senderId
        self.timestamp = Date().timeIntervalSince1970
        self.payload = payload
        self.sequenceNumber = UInt64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - EchoelSync Protocol Manager

/// Manages the EchoelSync bio-reactive synchronization protocol
@MainActor
public final class EchoelSyncProtocol: ObservableObject {

    public static let shared = EchoelSyncProtocol()

    // MARK: - Published State

    @Published public var connectedPeers: [EchoelSyncPeer] = []
    @Published public var isHosting: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var sessionName: String = ""
    @Published public var syncRate: Double = 60.0     // Hz
    @Published public var averageLatencyMs: Double = 0

    // MARK: - Subscriptions

    @Published public var subscribedPayloads: Set<EchoelSyncPayloadType> = Set(EchoelSyncPayloadType.allCases)

    // MARK: - Callbacks

    public var onMessageReceived: ((EchoelSyncMessage) -> Void)?

    // MARK: - Private

    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private var busSubscription: BusSubscription?
    private var syncTimer: Timer?

    // MARK: - Initialization

    private init() {
        subscribeToBus()
    }

    // MARK: - Host Session

    /// Start hosting an EchoelSync session
    public func startHosting(sessionName: String, role: EchoelSyncPeer.PeerRole = .performer) {
        self.sessionName = sessionName
        self.isHosting = true

        // Advertise via Bonjour
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let txtRecord = NWTXTRecord()
            txtRecord["session"] = sessionName
            txtRecord["role"] = role.rawValue

            listener = try NWListener(using: params)
            listener?.service = NWListener.Service(
                name: sessionName,
                type: "_echoelsync._tcp"
            )
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            listener?.start(queue: .main)

            log.log(.info, category: .system, "EchoelSync hosting: \(sessionName)")

            EngineBus.shared.publish(.custom(
                topic: "net.echoelsync.hosting",
                payload: ["session": sessionName, "role": role.rawValue]
            ))
        } catch {
            log.log(.error, category: .system, "EchoelSync host failed: \(error)")
        }
    }

    /// Stop hosting
    public func stopHosting() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        connectedPeers.removeAll()
        isHosting = false
        isConnected = false
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Join Session

    /// Browse and join an EchoelSync session
    public func joinSession(hostId: String, role: EchoelSyncPeer.PeerRole = .audience) {
        // Connect to discovered host via NWConnection
        log.log(.info, category: .system, "EchoelSync joining session: \(hostId)")

        EngineBus.shared.publish(.custom(
            topic: "net.echoelsync.joining",
            payload: ["host": hostId, "role": role.rawValue]
        ))
    }

    /// Leave current session
    public func leaveSession() {
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        connectedPeers.removeAll()
        isConnected = false
    }

    // MARK: - Send Data

    /// Broadcast a sync message to all connected peers
    public func broadcast(_ message: EchoelSyncMessage) {
        guard isConnected || isHosting else { return }

        let data = encodeMessage(message)
        for (_, connection) in connections {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    log.log(.warning, category: .system, "EchoelSync send error: \(error)")
                }
            })
        }
    }

    /// Send bio-reactive state to all peers
    public func broadcastBioState(coherence: Float, heartRate: Float, breathPhase: Float) {
        let message = EchoelSyncMessage(
            type: .bioSnapshot,
            senderId: "self",
            payload: [
                "coherence": "\(coherence)",
                "heartRate": "\(heartRate)",
                "breathPhase": "\(breathPhase)"
            ]
        )
        broadcast(message)
    }

    /// Send cue trigger (theater/show control)
    public func triggerCue(cueId: String, cueName: String) {
        let message = EchoelSyncMessage(
            type: .cueEvent,
            senderId: "self",
            payload: ["cueId": cueId, "cueName": cueName]
        )
        broadcast(message)

        EngineBus.shared.publish(.custom(
            topic: "net.echoelsync.cue",
            payload: ["cueId": cueId, "cueName": cueName]
        ))
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let peerId = UUID().uuidString
        connections[peerId] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    let peer = EchoelSyncPeer(
                        id: peerId,
                        name: "Peer-\(peerId.prefix(4))",
                        deviceType: "Unknown",
                        role: .audience,
                        lastSeen: Date(),
                        latencyMs: 0,
                        coherence: 0
                    )
                    self?.connectedPeers.append(peer)
                    self?.isConnected = true
                case .failed, .cancelled:
                    self?.connections.removeValue(forKey: peerId)
                    self?.connectedPeers.removeAll { $0.id == peerId }
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        receiveMessages(from: connection, peerId: peerId)
    }

    private func receiveMessages(from connection: NWConnection, peerId: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data, let message = self?.decodeMessage(data) {
                Task { @MainActor in
                    self?.onMessageReceived?(message)

                    // Forward to EngineBus
                    EngineBus.shared.publish(.custom(
                        topic: "net.echoelsync.message",
                        payload: message.payload
                    ))
                }
            }
            if error == nil {
                self?.receiveMessages(from: connection, peerId: peerId)
            }
        }
    }

    // MARK: - Serialization

    private func encodeMessage(_ message: EchoelSyncMessage) -> Data {
        var dict = message.payload
        dict["_type"] = message.type.rawValue
        dict["_sender"] = message.senderId
        dict["_ts"] = "\(message.timestamp)"
        dict["_seq"] = "\(message.sequenceNumber)"

        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    private func decodeMessage(_ data: Data) -> EchoelSyncMessage? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let typeStr = dict["_type"],
              let type = EchoelSyncPayloadType(rawValue: typeStr),
              let sender = dict["_sender"] else {
            return nil
        }

        var payload = dict
        payload.removeValue(forKey: "_type")
        payload.removeValue(forKey: "_sender")
        payload.removeValue(forKey: "_ts")
        payload.removeValue(forKey: "_seq")

        return EchoelSyncMessage(type: type, senderId: sender, payload: payload)
    }

    // MARK: - Bus Integration

    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            Task { @MainActor in
                guard self?.isConnected == true || self?.isHosting == true else { return }
                if case .bioUpdate(let bio) = msg {
                    self?.broadcastBioState(
                        coherence: bio.coherence,
                        heartRate: bio.heartRate,
                        breathPhase: bio.breathPhase
                    )
                }
            }
        }
    }
}
