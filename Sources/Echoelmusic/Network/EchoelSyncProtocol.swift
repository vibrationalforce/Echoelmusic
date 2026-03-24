#if canImport(Network)
//
//  EchoelSyncProtocol.swift
//  Echoelmusic — Cross-Device Sync Protocol
//
//  Extends OSC with structured session management, clock sync,
//  and state replication across Echoelmusic instances on LAN.
//
//  Features:
//  - Bonjour/mDNS device discovery (NWBrowser)
//  - Session host/join/leave lifecycle
//  - NTP-lite clock synchronization (<5ms LAN accuracy)
//  - State sync: BPM, transport, bio data, visual mode, lighting
//  - Low-latency UDP with reliability layer (seq + ACK)
//  - Peer list management with latency tracking
//
//  Transport: UDP via Network.framework
//  Discovery: Bonjour _echoelmusic._udp
//  Target: <10ms LAN latency
//

import Foundation
import Network
#if canImport(Observation)
import Observation
#endif
#if canImport(Combine)
import Combine
#endif

// MARK: - Sync Data Types

/// A discovered or connected peer in the sync session
public struct SyncPeer: Sendable, Identifiable, Equatable {
    /// Unique peer identifier
    public let id: UUID
    /// Human-readable device name
    public var name: String
    /// Network endpoint address
    public var address: String
    /// Port number
    public var port: UInt16
    /// Measured round-trip latency in milliseconds
    public var latencyMs: Double = 0.0
    /// Last time we received data from this peer
    public var lastSeen: Date = Date()
    /// Whether this peer is the session host
    public var isHost: Bool = false

    public static func == (lhs: SyncPeer, rhs: SyncPeer) -> Bool {
        lhs.id == rhs.id
    }
}

/// Messages exchanged between sync peers
public enum SyncMessage: Sendable {
    /// Transport state: play/stop/seek, BPM, beat position
    case transport(TransportState)
    /// Bio data broadcast
    case bio(BioSyncData)
    /// Visual mode change
    case visual(VisualSyncData)
    /// Lighting scene change
    case lighting(LightingSyncData)
    /// Text chat message
    case chat(ChatMessage)
    /// Clock sync request/response
    case clockSync(ClockSyncPayload)
    /// Session control (join, leave, heartbeat)
    case session(SessionControl)

    /// Message type identifier for serialization
    var typeID: UInt8 {
        switch self {
        case .transport: return 0x01
        case .bio:       return 0x02
        case .visual:    return 0x03
        case .lighting:  return 0x04
        case .chat:      return 0x05
        case .clockSync: return 0x06
        case .session:   return 0x07
        }
    }
}

/// Transport state data
public struct TransportState: Sendable, Codable {
    public var isPlaying: Bool = false
    public var bpm: Double = 120.0
    public var beatPosition: Double = 0.0
    public var timeSignatureNumerator: Int = 4
    public var timeSignatureDenominator: Int = 4
}

/// Bio data for sync broadcast
public struct BioSyncData: Sendable, Codable {
    public var heartRate: Float = 72.0
    public var hrv: Float = 0.5
    public var coherence: Float = 0.5
    public var breathPhase: Float = 0.5
    public var attentionScore: Float = 0.0
    public var meditationScore: Float = 0.0
}

/// Visual mode sync data
public struct VisualSyncData: Sendable, Codable {
    public var mode: String = "spectrum"
    public var intensity: Float = 0.5
    public var colorHue: Float = 0.0
    public var particleCount: Int = 1000
}

/// Lighting scene sync data
public struct LightingSyncData: Sendable, Codable {
    public var sceneIndex: Int = 0
    public var masterDimmer: Float = 1.0
    public var strobeRate: Float = 0.0
    public var colorTemperature: Float = 4000.0
}

/// Chat message
public struct ChatMessage: Sendable, Codable {
    public var senderName: String
    public var text: String
    public var timestamp: TimeInterval
}

/// Clock synchronization payload (NTP-lite)
public struct ClockSyncPayload: Sendable, Codable {
    /// True = request, False = response
    public var isRequest: Bool
    /// Sender's timestamp at send time
    public var originTimestamp: TimeInterval
    /// Responder's timestamp at receive time (response only)
    public var receiveTimestamp: TimeInterval
    /// Responder's timestamp at send time (response only)
    public var transmitTimestamp: TimeInterval
}

/// Session control commands
public enum SessionControl: Sendable, Codable {
    case join(peerID: String, name: String)
    case leave(peerID: String)
    case heartbeat(peerID: String)
    case hostTransfer(newHostID: String)
}

/// Session role
public enum SyncSessionRole: String, Sendable {
    case none = "None"
    case host = "Host"
    case client = "Client"
}

// MARK: - Reliability Layer

/// Packet header for reliable UDP delivery
private struct SyncPacketHeader: Sendable {
    /// Message type
    let typeID: UInt8
    /// Sequence number for ordering and deduplication
    let sequenceNumber: UInt32
    /// ACK of last received sequence from this peer
    let ackNumber: UInt32
    /// Sender peer ID (first 8 bytes of UUID)
    let senderID: UInt64
    /// Timestamp for latency measurement
    let timestamp: UInt64

    static let size = 25 // 1 + 4 + 4 + 8 + 8

    func encode() -> Data {
        var data = Data(capacity: Self.size)
        data.append(typeID)
        var seq = sequenceNumber.bigEndian; data.append(Data(bytes: &seq, count: 4))
        var ack = ackNumber.bigEndian; data.append(Data(bytes: &ack, count: 4))
        var sid = senderID.bigEndian; data.append(Data(bytes: &sid, count: 8))
        var ts = timestamp.bigEndian; data.append(Data(bytes: &ts, count: 8))
        return data
    }

    static func decode(from data: Data) -> SyncPacketHeader? {
        guard data.count >= size else { return nil }
        let typeID = data[0]
        let seq = data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let ack = data.subdata(in: 5..<9).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let sid = data.subdata(in: 9..<17).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let ts  = data.subdata(in: 17..<25).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        return SyncPacketHeader(typeID: typeID, sequenceNumber: seq, ackNumber: ack, senderID: sid, timestamp: ts)
    }
}

// MARK: - EchoelSyncProtocol

/// Cross-device synchronization protocol using Network.framework
@preconcurrency @MainActor
@Observable
public final class EchoelSyncProtocol {

    // MARK: - Singleton

    @MainActor public static let shared = EchoelSyncProtocol()

    // MARK: - Observable State

    public var isRunning: Bool = false
    public var sessionRole: SyncSessionRole = .none
    public var sessionName: String = ""
    public var peers: [SyncPeer] = []
    public var localPeerName: String = ""
    public var clockOffsetMs: Double = 0.0
    public var lastError: String?

    /// Current shared transport state
    public var transportState: TransportState = TransportState()

    /// Callback for received messages
    public var onMessageReceived: ((SyncMessage, SyncPeer?) -> Void)?

    // MARK: - Configuration

    private let serviceType = "_echoelmusic._udp"
    private let serviceDomain = "local."
    private let defaultPort: UInt16 = 9876
    private let heartbeatInterval: TimeInterval = 2.0
    private let peerTimeout: TimeInterval = 10.0

    // MARK: - Network Objects

    @ObservationIgnored private nonisolated(unsafe) var listener: NWListener?
    @ObservationIgnored private nonisolated(unsafe) var browser: NWBrowser?
    private var peerConnections: [UUID: NWConnection] = [:]
    private let networkQueue = DispatchQueue(label: "com.echoelmusic.sync", qos: .userInteractive)

    // MARK: - Reliability State

    private var localPeerID: UUID = UUID()
    private var localPeerIDBytes: UInt64 = 0
    private var outgoingSequence: UInt32 = 0
    private var lastReceivedSequence: [UInt64: UInt32] = [:] // peerID -> last seq
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Clock Sync

    private var clockSyncSamples: [(offset: Double, rtt: Double)] = []
    private let clockSyncSampleCount = 8

    // MARK: - Init

    private init() {
        localPeerName = ProcessInfo.processInfo.hostName
        localPeerIDBytes = withUnsafeBytes(of: localPeerID.uuid) { ptr in
            // Use first 8 bytes of UUID
            var value: UInt64 = 0
            withUnsafeMutableBytes(of: &value) { dest in
                dest.copyBytes(from: ptr.prefix(8))
            }
            return value
        }

        // Actually compute the bytes from the UUID
        let uuid = localPeerID.uuid
        localPeerIDBytes = UInt64(uuid.0) << 56 | UInt64(uuid.1) << 48 |
                           UInt64(uuid.2) << 40 | UInt64(uuid.3) << 32 |
                           UInt64(uuid.4) << 24 | UInt64(uuid.5) << 16 |
                           UInt64(uuid.6) << 8  | UInt64(uuid.7)
    }

    deinit {
        stopNonisolated()
    }

    private nonisolated func stopNonisolated() {
        listener?.cancel()
        browser?.cancel()
    }

    // MARK: - Session Lifecycle

    /// Host a new sync session
    public func hostSession(name: String) {
        guard !isRunning else { return }

        sessionName = name
        sessionRole = .host

        startListener()
        startBrowsing()
        startHeartbeat()

        isRunning = true
        log.log(.info, category: .network, "Sync: Hosting session '\(name)' on port \(defaultPort)")
    }

    /// Join an existing session via discovered peer
    public func joinSession(peer: SyncPeer) {
        guard !isRunning || sessionRole == .none else { return }

        sessionRole = .client

        connectToPeer(address: peer.address, port: peer.port, peerID: peer.id)
        startBrowsing()
        startHeartbeat()

        isRunning = true
        log.log(.info, category: .network, "Sync: Joining session at \(peer.address):\(peer.port)")
    }

    /// Leave current session
    public func leaveSession() {
        // Notify peers before leaving
        let leaveMsg = SyncMessage.session(.leave(peerID: localPeerID.uuidString))
        broadcastMessage(leaveMsg)

        // Cleanup
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil

        for (_, connection) in peerConnections {
            connection.cancel()
        }
        peerConnections.removeAll()
        peers.removeAll()
        cancellables.removeAll()
        lastReceivedSequence.removeAll()
        clockSyncSamples.removeAll()

        sessionRole = .none
        isRunning = false
        outgoingSequence = 0
        clockOffsetMs = 0

        log.log(.info, category: .network, "Sync: Left session")
    }

    // MARK: - Bonjour Discovery

    private func startBrowsing() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: serviceDomain)
        browser = NWBrowser(for: descriptor, using: .udp)

        nonisolated(unsafe) weak var weakSelf = self

        browser?.browseResultsChangedHandler = { results, changes in
            Task { @MainActor in
                weakSelf?.handleBrowseResults(results)
            }
        }

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log.log(.info, category: .network, "Sync: Bonjour browser ready")
            case .failed(let error):
                log.log(.error, category: .network, "Sync: Browser failed — \(error.localizedDescription)")
            default:
                break
            }
        }

        browser?.start(queue: networkQueue)
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, let type, let domain, _) = result.endpoint {
                // Don't connect to ourselves
                guard name != localPeerName else { continue }
                log.log(.info, category: .network, "Sync: Discovered peer '\(name)' (\(type) in \(domain))")

                // Resolve and connect
                let connection = NWConnection(to: result.endpoint, using: .udp)
                let peerID = UUID()
                let peer = SyncPeer(
                    id: peerID,
                    name: name,
                    address: result.endpoint.debugDescription,
                    port: defaultPort
                )

                if !peers.contains(where: { $0.name == name }) {
                    peers.append(peer)
                    setupConnection(connection, peerID: peerID)
                }
            }
        }
    }

    // MARK: - Network Listener

    private func startListener() {
        let params = NWParameters.udp
        params.includePeerToPeer = true

        let listenPort: NWEndpoint.Port
        do {
            guard let p = NWEndpoint.Port(rawValue: defaultPort) else { return }
            listenPort = p
            listener = try NWListener(using: params, on: listenPort)
        } catch {
            log.log(.error, category: .network, "Sync: Listener creation failed — \(error.localizedDescription)")
            return
        }

        // Advertise via Bonjour
        listener?.service = NWListener.Service(name: localPeerName, type: serviceType)

        nonisolated(unsafe) weak var weakSelf = self
        let capturedQueue = networkQueue

        listener?.newConnectionHandler = { connection in
            Task { @MainActor in
                let peerID = UUID()
                weakSelf?.setupConnection(connection, peerID: peerID)
                log.log(.info, category: .network, "Sync: Incoming connection from peer")
            }
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log.log(.info, category: .network, "Sync: Listener ready on port \(listenPort)")
            case .failed(let error):
                log.log(.error, category: .network, "Sync: Listener failed — \(error.localizedDescription)")
            default:
                break
            }
        }

        listener?.start(queue: capturedQueue)
    }

    // MARK: - Connection Management

    private func connectToPeer(address: String, port: UInt16, peerID: UUID) {
        let host = NWEndpoint.Host(address)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let connection = NWConnection(host: host, port: nwPort, using: .udp)
        setupConnection(connection, peerID: peerID)
    }

    private func setupConnection(_ connection: NWConnection, peerID: UUID) {
        peerConnections[peerID] = connection

        nonisolated(unsafe) weak var weakSelf = self

        connection.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .ready:
                    // Send join message
                    let joinMsg = SyncMessage.session(.join(
                        peerID: weakSelf?.localPeerID.uuidString ?? "",
                        name: weakSelf?.localPeerName ?? ""
                    ))
                    weakSelf?.sendMessage(joinMsg, to: peerID)
                    // Initiate clock sync
                    weakSelf?.requestClockSync(peerID: peerID)
                case .failed(let error):
                    log.log(.error, category: .network, "Sync: Connection to peer failed — \(error.localizedDescription)")
                    weakSelf?.removePeer(id: peerID)
                default:
                    break
                }
            }
        }

        connection.start(queue: networkQueue)
        receiveLoop(connection: connection, peerID: peerID)
    }

    private nonisolated func receiveLoop(connection: NWConnection, peerID: UUID) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data {
                Task { @MainActor [weak self] in
                    self?.handleReceivedData(data, from: peerID)
                }
            }
            if error == nil {
                self?.receiveLoop(connection: connection, peerID: peerID)
            }
        }
    }

    // MARK: - Message Sending

    /// Broadcast a message to all connected peers
    public func broadcastMessage(_ message: SyncMessage) {
        for peerID in peerConnections.keys {
            sendMessage(message, to: peerID)
        }
    }

    /// Send a message to a specific peer
    public func sendMessage(_ message: SyncMessage, to peerID: UUID) {
        guard let connection = peerConnections[peerID] else { return }

        outgoingSequence += 1
        let lastAck = lastReceivedSequence[localPeerIDBytes] ?? 0
        let now = UInt64(Date().timeIntervalSince1970 * 1_000_000) // microseconds

        let header = SyncPacketHeader(
            typeID: message.typeID,
            sequenceNumber: outgoingSequence,
            ackNumber: lastAck,
            senderID: localPeerIDBytes,
            timestamp: now
        )

        var packet = header.encode()

        // Encode payload
        let encoder = JSONEncoder()
        let payloadData: Data?

        switch message {
        case .transport(let state):   payloadData = try? encoder.encode(state)
        case .bio(let data):          payloadData = try? encoder.encode(data)
        case .visual(let data):       payloadData = try? encoder.encode(data)
        case .lighting(let data):     payloadData = try? encoder.encode(data)
        case .chat(let msg):          payloadData = try? encoder.encode(msg)
        case .clockSync(let payload): payloadData = try? encoder.encode(payload)
        case .session(let ctrl):      payloadData = try? encoder.encode(ctrl)
        }

        if let payload = payloadData {
            packet.append(payload)
        }

        connection.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                log.log(.error, category: .network, "Sync: Send error — \(error.localizedDescription)")
            }
        })
    }

    // MARK: - Message Receiving

    private func handleReceivedData(_ data: Data, from peerID: UUID) {
        guard let header = SyncPacketHeader.decode(from: data) else { return }

        // Deduplication: skip if we already processed this sequence from this sender
        if let lastSeq = lastReceivedSequence[header.senderID], header.sequenceNumber <= lastSeq {
            return
        }
        lastReceivedSequence[header.senderID] = header.sequenceNumber

        // Update peer last-seen
        if let idx = peers.firstIndex(where: { $0.id == peerID }) {
            peers[idx].lastSeen = Date()
        }

        // Calculate latency from timestamp
        let now = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let rttMicros = now - header.timestamp
        let rttMs = Double(rttMicros) / 1000.0
        if let idx = peers.firstIndex(where: { $0.id == peerID }) {
            peers[idx].latencyMs = rttMs / 2.0 // One-way estimate
        }

        // Decode payload
        let payloadData = data.subdata(in: SyncPacketHeader.size..<data.count)
        let decoder = JSONDecoder()

        let message: SyncMessage?
        switch header.typeID {
        case 0x01: message = (try? decoder.decode(TransportState.self, from: payloadData)).map { .transport($0) }
        case 0x02: message = (try? decoder.decode(BioSyncData.self, from: payloadData)).map { .bio($0) }
        case 0x03: message = (try? decoder.decode(VisualSyncData.self, from: payloadData)).map { .visual($0) }
        case 0x04: message = (try? decoder.decode(LightingSyncData.self, from: payloadData)).map { .lighting($0) }
        case 0x05: message = (try? decoder.decode(ChatMessage.self, from: payloadData)).map { .chat($0) }
        case 0x06: message = (try? decoder.decode(ClockSyncPayload.self, from: payloadData)).map { .clockSync($0) }
        case 0x07: message = (try? decoder.decode(SessionControl.self, from: payloadData)).map { .session($0) }
        default: message = nil
        }

        guard let msg = message else { return }

        // Handle internal protocol messages
        switch msg {
        case .session(let ctrl):
            handleSessionControl(ctrl, from: peerID)
        case .clockSync(let payload):
            handleClockSync(payload, from: peerID)
        case .transport(let state):
            transportState = state
            onMessageReceived?(msg, peers.first(where: { $0.id == peerID }))
        default:
            onMessageReceived?(msg, peers.first(where: { $0.id == peerID }))
        }
    }

    // MARK: - Session Control

    private func handleSessionControl(_ control: SessionControl, from peerID: UUID) {
        switch control {
        case .join(let remotePeerID, let name):
            if !peers.contains(where: { $0.id == peerID }) {
                let peer = SyncPeer(
                    id: peerID,
                    name: name,
                    address: remotePeerID,
                    port: defaultPort
                )
                peers.append(peer)
                log.log(.info, category: .network, "Sync: Peer joined — \(name)")
            }

        case .leave(let remotePeerID):
            removePeer(id: peerID)
            log.log(.info, category: .network, "Sync: Peer left — \(remotePeerID)")

        case .heartbeat:
            if let idx = peers.firstIndex(where: { $0.id == peerID }) {
                peers[idx].lastSeen = Date()
            }

        case .hostTransfer(let newHostID):
            if newHostID == localPeerID.uuidString {
                sessionRole = .host
                log.log(.info, category: .network, "Sync: Host role transferred to us")
            }
        }
    }

    private func removePeer(id: UUID) {
        peers.removeAll(where: { $0.id == id })
        peerConnections[id]?.cancel()
        peerConnections.removeValue(forKey: id)
    }

    // MARK: - Clock Synchronization (NTP-lite)

    /// Request clock sync from a peer
    private func requestClockSync(peerID: UUID) {
        let payload = ClockSyncPayload(
            isRequest: true,
            originTimestamp: Date().timeIntervalSince1970,
            receiveTimestamp: 0,
            transmitTimestamp: 0
        )
        sendMessage(.clockSync(payload), to: peerID)
    }

    private func handleClockSync(_ payload: ClockSyncPayload, from peerID: UUID) {
        if payload.isRequest {
            // Respond with our timestamps
            let response = ClockSyncPayload(
                isRequest: false,
                originTimestamp: payload.originTimestamp,
                receiveTimestamp: Date().timeIntervalSince1970,
                transmitTimestamp: Date().timeIntervalSince1970
            )
            sendMessage(.clockSync(response), to: peerID)
        } else {
            // Calculate clock offset using NTP algorithm
            let t0 = payload.originTimestamp                  // Client send time
            let t1 = payload.receiveTimestamp                 // Server receive time
            let t2 = payload.transmitTimestamp                // Server send time
            let t3 = Date().timeIntervalSince1970             // Client receive time

            let rtt = (t3 - t0) - (t2 - t1)
            let offset = ((t1 - t0) + (t2 - t3)) / 2.0

            clockSyncSamples.append((offset: offset * 1000.0, rtt: rtt * 1000.0)) // Convert to ms

            // Keep only recent samples
            if clockSyncSamples.count > clockSyncSampleCount {
                clockSyncSamples.removeFirst()
            }

            // Use median offset (robust to outliers)
            let sorted = clockSyncSamples.sorted(by: { $0.offset < $1.offset })
            let medianIdx = sorted.count / 2
            clockOffsetMs = sorted[medianIdx].offset

            log.log(.info, category: .network, "Sync: Clock offset = \(String(format: "%.2f", clockOffsetMs))ms, RTT = \(String(format: "%.2f", rtt * 1000))ms")
        }
    }

    // MARK: - Heartbeat & Peer Cleanup

    private func startHeartbeat() {
        let timer = Timer.publish(every: heartbeatInterval, on: .main, in: .common).autoconnect()
        timer.sink { [weak self] _ in
            guard let self = self, self.isRunning else { return }

            // Send heartbeat
            let heartbeat = SyncMessage.session(.heartbeat(peerID: self.localPeerID.uuidString))
            self.broadcastMessage(heartbeat)

            // Remove stale peers
            let cutoff = Date().addingTimeInterval(-self.peerTimeout)
            let stalePeers = self.peers.filter { $0.lastSeen < cutoff }
            for peer in stalePeers {
                self.removePeer(id: peer.id)
                log.log(.warning, category: .network, "Sync: Peer timed out — \(peer.name)")
            }

            // Periodic clock sync with all peers
            for peerID in self.peerConnections.keys {
                self.requestClockSync(peerID: peerID)
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Convenience Senders

    /// Broadcast current transport state
    public func broadcastTransport(_ state: TransportState) {
        transportState = state
        broadcastMessage(.transport(state))
    }

    /// Broadcast bio data to all peers
    public func broadcastBio(_ data: BioSyncData) {
        broadcastMessage(.bio(data))
    }

    /// Broadcast visual mode change
    public func broadcastVisual(_ data: VisualSyncData) {
        broadcastMessage(.visual(data))
    }

    /// Broadcast lighting scene
    public func broadcastLighting(_ data: LightingSyncData) {
        broadcastMessage(.lighting(data))
    }

    /// Send chat message to all peers
    public func sendChat(_ text: String) {
        let msg = ChatMessage(
            senderName: localPeerName,
            text: text,
            timestamp: Date().timeIntervalSince1970
        )
        broadcastMessage(.chat(msg))
    }

    /// Get adjusted timestamp accounting for clock offset
    public func adjustedTimestamp() -> TimeInterval {
        Date().timeIntervalSince1970 + (clockOffsetMs / 1000.0)
    }
}

#else
// Non-Network platforms (Linux without NIO, etc.)
import Foundation
#if canImport(Observation)
import Observation
#endif

public struct SyncPeer: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var address: String
    public var port: UInt16
    public var latencyMs: Double = 0.0
    public var lastSeen: Date = Date()
    public var isHost: Bool = false
}

public enum SyncSessionRole: String, Sendable {
    case none = "None"
    case host = "Host"
    case client = "Client"
}

public struct TransportState: Sendable, Codable {
    public var isPlaying: Bool = false
    public var bpm: Double = 120.0
    public var beatPosition: Double = 0.0
}

@preconcurrency @MainActor
@Observable
public final class EchoelSyncProtocol {
    @MainActor public static let shared = EchoelSyncProtocol()
    public var isRunning: Bool = false
    public var sessionRole: SyncSessionRole = .none
    public var peers: [SyncPeer] = []
    public var transportState: TransportState = TransportState()
    public var clockOffsetMs: Double = 0.0
    private init() {}
    public func hostSession(name: String) {}
    public func joinSession(peer: SyncPeer) {}
    public func leaveSession() {}
}
#endif // canImport(Network)
