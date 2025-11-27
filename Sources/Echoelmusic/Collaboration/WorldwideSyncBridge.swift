//
//  WorldwideSyncBridge.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  WORLDWIDE SYNC BRIDGE
//  Unified synchronization across local networks AND the internet
//
//  Architecture:
//  - Local Network: EchoelSync (UDP multicast, sub-millisecond latency)
//  - Internet: WebRTC (STUN/TURN, NAT traversal, ~50-200ms latency)
//  - Hybrid: Auto-selects best method based on peer location
//
//  Use Cases:
//  1. Same room: Direct EchoelSync (< 1ms)
//  2. Same building/LAN: EchoelSync multicast (< 5ms)
//  3. Same city: WebRTC direct (20-50ms)
//  4. Same country: WebRTC with relay (50-100ms)
//  5. Worldwide: WebRTC TURN relay (100-300ms)
//

import Foundation
import Combine
import Network

// MARK: - Worldwide Sync Bridge

@MainActor
public class WorldwideSyncBridge: ObservableObject {

    // Singleton
    public static let shared = WorldwideSyncBridge()

    // MARK: - Published State

    @Published public var connectionMode: ConnectionMode = .disconnected
    @Published public var globalPeers: [GlobalPeer] = []
    @Published public var localPeers: [EchoelSyncEngine.Peer] = []
    @Published public var currentSession: GlobalSession?
    @Published public var syncQuality: SyncQuality = .unknown

    // Statistics
    @Published public var averageLatency: Double = 0
    @Published public var worstLatency: Double = 0
    @Published public var syncDrift: Double = 0  // Beat drift in ms

    // MARK: - Connection Mode

    public enum ConnectionMode: String {
        case disconnected = "Disconnected"
        case localOnly = "Local Network"
        case internetOnly = "Internet (WebRTC)"
        case hybrid = "Hybrid (Local + Internet)"

        var icon: String {
            switch self {
            case .disconnected: return "wifi.slash"
            case .localOnly: return "wifi"
            case .internetOnly: return "globe"
            case .hybrid: return "globe.badge.chevron.backward"
            }
        }
    }

    public enum SyncQuality: String {
        case unknown = "Unknown"
        case perfect = "Perfect (<10ms)"
        case excellent = "Excellent (<30ms)"
        case good = "Good (<50ms)"
        case acceptable = "Acceptable (<100ms)"
        case poor = "Poor (>100ms)"

        var color: String {
            switch self {
            case .unknown: return "gray"
            case .perfect: return "green"
            case .excellent: return "blue"
            case .good: return "cyan"
            case .acceptable: return "yellow"
            case .poor: return "red"
            }
        }
    }

    // MARK: - Global Peer

    public struct GlobalPeer: Identifiable {
        public let id: UUID
        public let userId: String
        public let username: String
        public let location: String  // City, Country
        public let connectionType: ConnectionType
        public var latency: Double
        public var tempo: Double
        public var currentBeat: Double
        public var isPlaying: Bool
        public var isHost: Bool
        public var instruments: [String]
        public var lastSeen: Date

        public enum ConnectionType {
            case local      // Same LAN
            case direct     // WebRTC direct (same ISP/region)
            case relayed    // WebRTC via TURN server

            var description: String {
                switch self {
                case .local: return "Local"
                case .direct: return "Direct"
                case .relayed: return "Relayed"
                }
            }
        }
    }

    // MARK: - Global Session

    public struct GlobalSession: Identifiable {
        public let id: String
        public var name: String
        public var hostId: String
        public var hostLocation: String
        public var genre: String?
        public var tempo: Double
        public var isPublic: Bool
        public var password: String?
        public var maxParticipants: Int
        public var currentParticipants: Int
        public var createdAt: Date

        // Sync state
        public var isPlaying: Bool = false
        public var currentBeat: Double = 0
        public var timeSignature: (numerator: Int, denominator: Int) = (4, 4)
    }

    // MARK: - Components

    private let echoelSync = EchoelSyncEngine.shared
    private let webRTC = WebRTCManager(configuration: .lowLatency)

    // Global discovery
    private var discoveryTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?

    // MARK: - Global Server List

    private let globalServerURL = "https://sync.echoelmusic.com/api/v1"

    public struct ServerListResponse: Codable {
        let sessions: [SessionInfo]

        struct SessionInfo: Codable {
            let id: String
            let name: String
            let hostId: String
            let hostLocation: String
            let genre: String?
            let tempo: Double
            let isPublic: Bool
            let maxParticipants: Int
            let currentParticipants: Int
            let createdAt: String
        }
    }

    // MARK: - Initialization

    private init() {
        setupEchoelSyncCallbacks()
        setupWebRTCCallbacks()
    }

    private func setupEchoelSyncCallbacks() {
        // Listen for local peer changes
        Task {
            for await _ in echoelSync.$connectedPeers.values {
                await MainActor.run {
                    self.localPeers = echoelSync.connectedPeers
                    self.updateConnectionMode()
                }
            }
        }
    }

    private func setupWebRTCCallbacks() {
        webRTC.onParticipantJoined = { [weak self] participant in
            Task { @MainActor in
                self?.handleWebRTCPeerJoined(participant)
            }
        }

        webRTC.onParticipantLeft = { [weak self] peerId in
            Task { @MainActor in
                self?.handleWebRTCPeerLeft(peerId)
            }
        }

        webRTC.onDataReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleWebRTCData(message)
            }
        }
    }

    // MARK: - Session Management

    /// Create a new worldwide session
    public func createSession(
        name: String,
        genre: String? = nil,
        isPublic: Bool = true,
        password: String? = nil,
        maxParticipants: Int = 8
    ) async throws -> GlobalSession {

        // Start local EchoelSync
        try echoelSync.enable()
        let localSessionId = echoelSync.createSession(name: name)

        // Create WebRTC room
        let webRTCRoom = try await webRTC.createRoom(name: name)

        // Register with global server
        let session = GlobalSession(
            id: localSessionId,
            name: name,
            hostId: "local-user",
            hostLocation: await getMyLocation(),
            genre: genre,
            tempo: echoelSync.tempo,
            isPublic: isPublic,
            password: password,
            maxParticipants: maxParticipants,
            currentParticipants: 1,
            createdAt: Date()
        )

        if isPublic {
            try await registerSessionWithGlobalServer(session)
        }

        currentSession = session
        connectionMode = .hybrid

        // Start sync broadcasting
        startSyncBroadcast()

        return session
    }

    /// Join a session (works for both local and internet)
    public func joinSession(_ sessionId: String, password: String? = nil) async throws {
        // Try local first (faster)
        if let localPeer = localPeers.first(where: { _ in true }) {
            // Join via EchoelSync
            try await echoelSync.joinSession(sessionId, peerAddress: localPeer.ipAddress, password: password)
            connectionMode = .localOnly
        }

        // Also connect via WebRTC for reliability
        try await webRTC.joinRoom(roomId: sessionId, password: password)

        if connectionMode == .localOnly {
            connectionMode = .hybrid
        } else {
            connectionMode = .internetOnly
        }

        // Start sync listening
        startSyncBroadcast()
    }

    /// Leave current session
    public func leaveSession() async {
        echoelSync.leaveSession()
        await webRTC.leaveRoom()

        if let session = currentSession, session.isPublic {
            try? await unregisterSessionFromGlobalServer(session.id)
        }

        currentSession = nil
        globalPeers.removeAll()
        connectionMode = .disconnected

        stopSyncBroadcast()
    }

    // MARK: - Global Server Discovery

    /// Discover public sessions worldwide
    public func discoverGlobalSessions(
        genre: String? = nil,
        minTempo: Double? = nil,
        maxTempo: Double? = nil,
        region: String? = nil
    ) async throws -> [GlobalSession] {

        var urlComponents = URLComponents(string: "\(globalServerURL)/sessions")!
        var queryItems: [URLQueryItem] = []

        if let genre = genre {
            queryItems.append(URLQueryItem(name: "genre", value: genre))
        }
        if let minTempo = minTempo {
            queryItems.append(URLQueryItem(name: "minTempo", value: String(minTempo)))
        }
        if let maxTempo = maxTempo {
            queryItems.append(URLQueryItem(name: "maxTempo", value: String(maxTempo)))
        }
        if let region = region {
            queryItems.append(URLQueryItem(name: "region", value: region))
        }

        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents.url else {
            throw WorldwideSyncError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ServerListResponse.self, from: data)

        return response.sessions.map { info in
            GlobalSession(
                id: info.id,
                name: info.name,
                hostId: info.hostId,
                hostLocation: info.hostLocation,
                genre: info.genre,
                tempo: info.tempo,
                isPublic: true,
                password: nil,
                maxParticipants: info.maxParticipants,
                currentParticipants: info.currentParticipants,
                createdAt: ISO8601DateFormatter().date(from: info.createdAt) ?? Date()
            )
        }
    }

    /// Start continuous discovery
    public func startDiscovery() {
        // Local discovery
        echoelSync.startMulticastDiscovery()

        // Global discovery (poll every 30 seconds)
        discoveryTask = Task {
            while !Task.isCancelled {
                do {
                    let sessions = try await discoverGlobalSessions()
                    // Update UI with discovered sessions
                    print("Discovered \(sessions.count) global sessions")
                } catch {
                    print("Discovery error: \(error)")
                }

                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }

    public func stopDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
    }

    // MARK: - Sync Broadcasting

    private func startSyncBroadcast() {
        syncTask = Task {
            while !Task.isCancelled {
                await broadcastSyncState()
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms = 100Hz
            }
        }
    }

    private func stopSyncBroadcast() {
        syncTask?.cancel()
        syncTask = nil
    }

    private func broadcastSyncState() async {
        let state = SyncStateMessage(
            tempo: echoelSync.tempo,
            beat: echoelSync.currentBeat,
            phase: echoelSync.currentBeat.truncatingRemainder(dividingBy: 1.0),
            isPlaying: echoelSync.isPlaying,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1_000_000)  // microseconds
        )

        // Broadcast to WebRTC peers
        if let data = try? JSONEncoder().encode(state) {
            webRTC.sendData(data, type: .transport)
        }

        // EchoelSync broadcasts automatically via its own protocol
    }

    // MARK: - Sync State Message

    struct SyncStateMessage: Codable {
        let tempo: Double
        let beat: Double
        let phase: Double
        let isPlaying: Bool
        let timestamp: UInt64
    }

    // MARK: - WebRTC Handlers

    private func handleWebRTCPeerJoined(_ participant: CollaborationRoom.Participant) {
        let globalPeer = GlobalPeer(
            id: UUID(),
            userId: participant.userId,
            username: participant.displayName,
            location: "Unknown",  // Get from metadata
            connectionType: .direct,  // Determine based on ICE candidates
            latency: Double(participant.latency),
            tempo: echoelSync.tempo,
            currentBeat: echoelSync.currentBeat,
            isPlaying: echoelSync.isPlaying,
            isHost: participant.role == .host,
            instruments: participant.instrument.map { [$0] } ?? [],
            lastSeen: Date()
        )

        globalPeers.append(globalPeer)
        updateSyncQuality()
    }

    private func handleWebRTCPeerLeft(_ peerId: String) {
        globalPeers.removeAll { $0.userId == peerId }
        updateSyncQuality()
    }

    private func handleWebRTCData(_ message: WebRTCManager.DataChannelMessage) {
        guard message.type == .transport else { return }

        do {
            let syncState = try JSONDecoder().decode(SyncStateMessage.self, from: message.payload)

            // Update peer state
            if let index = globalPeers.firstIndex(where: { $0.userId == message.senderId }) {
                globalPeers[index].tempo = syncState.tempo
                globalPeers[index].currentBeat = syncState.beat
                globalPeers[index].isPlaying = syncState.isPlaying
                globalPeers[index].lastSeen = Date()

                // Calculate drift
                let localBeat = echoelSync.currentBeat
                let drift = abs(localBeat - syncState.beat)
                let driftMs = drift * (60.0 / syncState.tempo) * 1000

                if driftMs > syncDrift {
                    syncDrift = driftMs
                }
            }

            // If we're not the host, follow the sync state
            if currentSession?.hostId != "local-user" {
                // Adjust local playback to match
                if syncState.isPlaying != echoelSync.isPlaying {
                    if syncState.isPlaying {
                        echoelSync.play()
                    } else {
                        echoelSync.stop()
                    }
                }

                // Adjust tempo if different
                if abs(syncState.tempo - echoelSync.tempo) > 0.1 {
                    echoelSync.setTempo(syncState.tempo)
                }
            }

        } catch {
            print("Failed to decode sync state: \(error)")
        }
    }

    // MARK: - Helpers

    private func updateConnectionMode() {
        let hasLocal = !localPeers.isEmpty
        let hasGlobal = !globalPeers.isEmpty

        switch (hasLocal, hasGlobal) {
        case (false, false):
            connectionMode = currentSession != nil ? .internetOnly : .disconnected
        case (true, false):
            connectionMode = .localOnly
        case (false, true):
            connectionMode = .internetOnly
        case (true, true):
            connectionMode = .hybrid
        }
    }

    private func updateSyncQuality() {
        let latencies = globalPeers.map { $0.latency } + localPeers.map { $0.latency }

        guard !latencies.isEmpty else {
            syncQuality = .unknown
            return
        }

        averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        worstLatency = latencies.max() ?? 0

        switch worstLatency {
        case 0..<10:
            syncQuality = .perfect
        case 10..<30:
            syncQuality = .excellent
        case 30..<50:
            syncQuality = .good
        case 50..<100:
            syncQuality = .acceptable
        default:
            syncQuality = .poor
        }
    }

    private func getMyLocation() async -> String {
        // In production, use IP geolocation or device location
        return "Unknown Location"
    }

    private func registerSessionWithGlobalServer(_ session: GlobalSession) async throws {
        let url = URL(string: "\(globalServerURL)/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "id": session.id,
            "name": session.name,
            "hostLocation": session.hostLocation,
            "genre": session.genre ?? "",
            "tempo": session.tempo,
            "maxParticipants": session.maxParticipants
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw WorldwideSyncError.registrationFailed
        }
    }

    private func unregisterSessionFromGlobalServer(_ sessionId: String) async throws {
        let url = URL(string: "\(globalServerURL)/sessions/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Errors

public enum WorldwideSyncError: Error, LocalizedError {
    case invalidURL
    case registrationFailed
    case connectionFailed
    case sessionNotFound
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .registrationFailed:
            return "Failed to register session with global server"
        case .connectionFailed:
            return "Failed to connect to peer"
        case .sessionNotFound:
            return "Session not found"
        case .unauthorized:
            return "Not authorized to join this session"
        }
    }
}

// MARK: - Quick Connect

extension WorldwideSyncBridge {

    /// Quick connect to a public session with matching tempo
    public func quickConnect(nearTempo: Double, tolerance: Double = 5.0) async throws -> GlobalSession? {
        let sessions = try await discoverGlobalSessions(
            minTempo: nearTempo - tolerance,
            maxTempo: nearTempo + tolerance
        )

        // Find best match (lowest latency, closest tempo)
        guard let bestSession = sessions
            .filter({ $0.currentParticipants < $0.maxParticipants })
            .sorted(by: { abs($0.tempo - nearTempo) < abs($1.tempo - nearTempo) })
            .first else {
            return nil
        }

        try await joinSession(bestSession.id)
        return bestSession
    }

    /// Host a jam at specific tempo (creates public session)
    public func hostJam(name: String, tempo: Double, genre: String? = nil) async throws -> GlobalSession {
        echoelSync.setTempo(tempo)
        return try await createSession(name: name, genre: genre, isPublic: true)
    }
}

// MARK: - Two Project Sync

extension WorldwideSyncBridge {

    /// Sync two different projects at same tempo
    /// Each person keeps their own project but shares tempo/transport
    public func syncProjectsOnly() {
        // This mode only syncs tempo and transport, not project data
        // Each user has their own project file but plays in sync

        // 1. Share tempo changes
        // 2. Share play/stop
        // 3. Share beat position (quantized to bars)
        // 4. Don't share: tracks, clips, effects, etc.

        print("Project sync mode: Tempo and transport only")
    }
}

// MARK: - Debug

#if DEBUG
extension WorldwideSyncBridge {

    func simulateGlobalSession() async {
        print("Simulating global session...")

        // Add fake global peers
        let peer1 = GlobalPeer(
            id: UUID(),
            userId: "user-berlin",
            username: "DJ_Berlin",
            location: "Berlin, Germany",
            connectionType: .direct,
            latency: 45,
            tempo: 128,
            currentBeat: 0,
            isPlaying: true,
            isHost: true,
            instruments: ["Synth", "Drums"],
            lastSeen: Date()
        )

        let peer2 = GlobalPeer(
            id: UUID(),
            userId: "user-tokyo",
            username: "Producer_Tokyo",
            location: "Tokyo, Japan",
            connectionType: .relayed,
            latency: 180,
            tempo: 128,
            currentBeat: 0,
            isPlaying: true,
            isHost: false,
            instruments: ["Bass", "Keys"],
            lastSeen: Date()
        )

        let peer3 = GlobalPeer(
            id: UUID(),
            userId: "user-nyc",
            username: "Beatmaker_NYC",
            location: "New York, USA",
            connectionType: .direct,
            latency: 95,
            tempo: 128,
            currentBeat: 0,
            isPlaying: true,
            isHost: false,
            instruments: ["MPC", "Guitar"],
            lastSeen: Date()
        )

        globalPeers = [peer1, peer2, peer3]

        currentSession = GlobalSession(
            id: UUID().uuidString,
            name: "Global Jam Session",
            hostId: "user-berlin",
            hostLocation: "Berlin, Germany",
            genre: "Techno",
            tempo: 128,
            isPublic: true,
            password: nil,
            maxParticipants: 8,
            currentParticipants: 4,
            createdAt: Date()
        )

        connectionMode = .hybrid
        updateSyncQuality()

        print("Simulation complete:")
        print("  Peers: \(globalPeers.count)")
        print("  Mode: \(connectionMode.rawValue)")
        print("  Quality: \(syncQuality.rawValue)")
        print("  Avg Latency: \(averageLatency)ms")
    }
}
#endif
