//
//  CollaborationEngine.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  COLLABORATION ENGINE - Unified coordinator for all collaboration features
//  Integrates: EchoelSync, WebRTC, HeartSync, TrackExchange, AudioStreaming
//  Target latency: <20ms LAN, <50ms Internet
//

import Foundation
import Combine

/// Unified Collaboration Engine coordinating all collaboration subsystems
/// Provides single interface for real-time worldwide music collaboration
@MainActor
class CollaborationEngine: ObservableObject {
    static let shared = CollaborationEngine()

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentSession: CollaborationSession?
    @Published var participants: [Participant] = []
    @Published var groupCoherence: Float = 0.0
    @Published var averageHRV: Float = 0.0
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var latency: TimeInterval = 0
    @Published var syncStatus: SyncStatus = .disconnected

    // MARK: - Subsystems

    private let echoelSync = EchoelSyncEngine.shared
    private let webRTCManager = WebRTCManager.shared
    private let worldwideSync = WorldwideSyncBridge.shared
    private let trackExchange = CollaborativeTrackExchange.shared
    private let audioStreaming = RealtimeAudioStreaming.shared
    private let heartSync = EchoelHeartSync.shared

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // Sync EchoelSync state
        echoelSync.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.syncStatus = connected ? .synced : .disconnected
            }
            .store(in: &cancellables)

        // Monitor latency from WebRTC
        webRTCManager.$currentLatency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lat in
                self?.latency = lat
                self?.updateConnectionQuality(latency: lat)
            }
            .store(in: &cancellables)

        // Aggregate participant bio data from HeartSync
        heartSync.$groupCoherence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coherence in
                self?.groupCoherence = coherence
            }
            .store(in: &cancellables)

        heartSync.$averageHRV
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hrv in
                self?.averageHRV = hrv
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Management

    /// Create a new collaboration session as host
    func createSession(name: String, isPrivate: Bool = false) async throws -> CollaborationSession {
        // Start EchoelSync as host
        try await echoelSync.startHost()

        // Initialize WebRTC signaling server
        try await webRTCManager.createRoom()

        // Create session object
        let session = CollaborationSession(
            id: UUID(),
            name: name,
            hostID: UUID(),
            participants: [],
            isHost: true,
            isPrivate: isPrivate,
            createdAt: Date(),
            sessionCode: generateSessionCode()
        )

        currentSession = session
        isActive = true
        syncStatus = .hosting

        // Add self as first participant
        let selfParticipant = Participant(
            id: session.hostID,
            name: "You (Host)",
            role: .host,
            hrv: 0,
            coherence: 0,
            isMuted: false,
            isDeafened: false,
            latency: 0,
            connectionQuality: .excellent
        )
        participants = [selfParticipant]

        print("✅ CollaborationEngine: Created session '\(name)' with code \(session.sessionCode ?? "N/A")")

        return session
    }

    /// Join an existing session
    func joinSession(sessionCode: String) async throws {
        // Resolve session code to connection info
        guard let connectionInfo = try await worldwideSync.resolveSessionCode(sessionCode) else {
            throw CollaborationError.sessionNotFound
        }

        // Connect via EchoelSync
        try await echoelSync.joinSession(address: connectionInfo.address, port: connectionInfo.port)

        // Connect WebRTC for audio
        try await webRTCManager.joinRoom(roomId: connectionInfo.roomId)

        // Start audio streaming
        try await audioStreaming.startReceiving()

        let session = CollaborationSession(
            id: connectionInfo.sessionId,
            name: connectionInfo.sessionName,
            hostID: connectionInfo.hostId,
            participants: [],
            isHost: false,
            isPrivate: connectionInfo.isPrivate,
            createdAt: connectionInfo.createdAt,
            sessionCode: sessionCode
        )

        currentSession = session
        isActive = true
        syncStatus = .synced

        print("🔗 CollaborationEngine: Joined session '\(connectionInfo.sessionName)'")
    }

    /// Join via direct IP (LAN mode)
    func joinDirectIP(address: String, port: UInt16) async throws {
        try await echoelSync.joinSession(address: address, port: port)

        currentSession = CollaborationSession(
            id: UUID(),
            name: "LAN Session",
            hostID: UUID(),
            participants: [],
            isHost: false,
            isPrivate: true,
            createdAt: Date(),
            sessionCode: nil
        )

        isActive = true
        syncStatus = .synced

        print("🔗 CollaborationEngine: Joined LAN session at \(address):\(port)")
    }

    /// Leave current session
    func leaveSession() async {
        // Disconnect from all subsystems
        await echoelSync.disconnect()
        await webRTCManager.disconnect()
        await audioStreaming.stop()
        heartSync.stopSync()

        currentSession = nil
        participants.removeAll()
        isActive = false
        syncStatus = .disconnected
        latency = 0
        groupCoherence = 0
        averageHRV = 0

        print("👋 CollaborationEngine: Left session")
    }

    // MARK: - Participant Management

    /// Add a participant to the session
    func addParticipant(_ participant: Participant) {
        guard !participants.contains(where: { $0.id == participant.id }) else { return }
        participants.append(participant)

        // Start HeartSync for this participant
        heartSync.addParticipant(id: participant.id)

        print("👤 CollaborationEngine: \(participant.name) joined")
    }

    /// Remove a participant from the session
    func removeParticipant(id: UUID) {
        participants.removeAll { $0.id == id }
        heartSync.removeParticipant(id: id)

        print("👤 CollaborationEngine: Participant \(id) left")
    }

    /// Update participant's bio data
    func updateParticipantBio(id: UUID, hrv: Float, coherence: Float) {
        if let index = participants.firstIndex(where: { $0.id == id }) {
            participants[index].hrv = hrv
            participants[index].coherence = coherence
        }

        // Recalculate group averages
        recalculateGroupMetrics()
    }

    /// Mute/unmute a participant (host only)
    func setParticipantMuted(id: UUID, muted: Bool) {
        guard currentSession?.isHost == true else { return }
        if let index = participants.firstIndex(where: { $0.id == id }) {
            participants[index].isMuted = muted
            webRTCManager.setParticipantMuted(id: id, muted: muted)
        }
    }

    // MARK: - Audio Streaming

    /// Start streaming local audio to session
    func startAudioStream() async throws {
        try await audioStreaming.startStreaming()
        print("🎤 CollaborationEngine: Audio streaming started")
    }

    /// Stop streaming local audio
    func stopAudioStream() async {
        await audioStreaming.stopStreaming()
        print("🎤 CollaborationEngine: Audio streaming stopped")
    }

    /// Set local audio muted state
    func setLocalMuted(_ muted: Bool) {
        audioStreaming.setMuted(muted)
        if let selfIndex = participants.firstIndex(where: { $0.role == .host || $0.name.contains("You") }) {
            participants[selfIndex].isMuted = muted
        }
    }

    // MARK: - Track Exchange

    /// Share a track with session participants
    func shareTrack(_ track: SharedTrack) async throws {
        try await trackExchange.shareTrack(track)
        print("📤 CollaborationEngine: Shared track '\(track.name)'")
    }

    /// Request a track from the session
    func requestTrack(trackId: UUID) async throws -> SharedTrack {
        let track = try await trackExchange.requestTrack(id: trackId)
        print("📥 CollaborationEngine: Received track '\(track.name)'")
        return track
    }

    /// Get list of available shared tracks
    func getAvailableTracks() -> [SharedTrack] {
        return trackExchange.availableTracks
    }

    // MARK: - Sync Control

    /// Sync transport with session (play/pause/seek)
    func syncTransport(action: TransportAction) {
        echoelSync.sendTransportAction(action)
    }

    /// Get current sync tempo
    func getSyncTempo() -> Double {
        return echoelSync.currentTempo
    }

    /// Set sync tempo (host only)
    func setSyncTempo(_ bpm: Double) {
        guard currentSession?.isHost == true else { return }
        echoelSync.setTempo(bpm)
    }

    // MARK: - HeartSync (Bio-Sync)

    /// Start bio-sync for collective coherence
    func startHeartSync() async throws {
        try await heartSync.startSync()
        print("💓 CollaborationEngine: HeartSync started")
    }

    /// Stop bio-sync
    func stopHeartSync() {
        heartSync.stopSync()
        print("💓 CollaborationEngine: HeartSync stopped")
    }

    /// Identify the participant with highest coherence (flow leader)
    func identifyFlowLeader() -> Participant? {
        return participants.max(by: { $0.coherence < $1.coherence })
    }

    /// Get collective coherence state
    func getCollectiveState() -> CollectiveState {
        if groupCoherence > 70 {
            return .highCoherence
        } else if groupCoherence > 40 {
            return .mediumCoherence
        } else {
            return .lowCoherence
        }
    }

    // MARK: - Private Helpers

    private func generateSessionCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    private func updateConnectionQuality(latency: TimeInterval) {
        let latencyMs = latency * 1000
        if latencyMs < 20 {
            connectionQuality = .excellent
        } else if latencyMs < 50 {
            connectionQuality = .good
        } else if latencyMs < 100 {
            connectionQuality = .fair
        } else if latencyMs < 200 {
            connectionQuality = .poor
        } else {
            connectionQuality = .bad
        }
    }

    private func recalculateGroupMetrics() {
        let validParticipants = participants.filter { $0.hrv > 0 || $0.coherence > 0 }
        guard !validParticipants.isEmpty else {
            averageHRV = 0
            groupCoherence = 0
            return
        }

        averageHRV = validParticipants.map { $0.hrv }.reduce(0, +) / Float(validParticipants.count)
        groupCoherence = validParticipants.map { $0.coherence }.reduce(0, +) / Float(validParticipants.count)
    }
}

// MARK: - Supporting Types

struct CollaborationSession: Identifiable {
    let id: UUID
    var name: String
    let hostID: UUID
    var participants: [Participant]
    let isHost: Bool
    var isPrivate: Bool
    let createdAt: Date
    var sessionCode: String?

    var participantCount: Int { participants.count }
    var isPublic: Bool { !isPrivate }
}

struct Participant: Identifiable {
    let id: UUID
    var name: String
    var role: ParticipantRole
    var hrv: Float
    var coherence: Float
    var isMuted: Bool
    var isDeafened: Bool
    var latency: TimeInterval
    var connectionQuality: ConnectionQuality

    enum ParticipantRole: String {
        case host, coHost, participant, spectator
    }
}

struct SharedTrack: Identifiable {
    let id: UUID
    var name: String
    var ownerID: UUID
    var duration: TimeInterval
    var fileSize: Int64
    var format: AudioFormat
    var isLocked: Bool

    enum AudioFormat: String {
        case wav, aiff, mp3, flac, aac
    }
}

enum ConnectionQuality: String {
    case excellent, good, fair, poor, bad, unknown

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "green"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .bad: return "red"
        case .unknown: return "gray"
        }
    }
}

enum SyncStatus: String {
    case disconnected, connecting, synced, hosting, error
}

enum TransportAction {
    case play
    case pause
    case stop
    case seek(position: TimeInterval)
    case setTempo(bpm: Double)
}

enum CollectiveState {
    case lowCoherence      // < 40%
    case mediumCoherence   // 40-70%
    case highCoherence     // > 70%

    var description: String {
        switch self {
        case .lowCoherence: return "Building Coherence"
        case .mediumCoherence: return "Growing Connection"
        case .highCoherence: return "Flow State Achieved"
        }
    }
}

enum CollaborationError: Error, LocalizedError {
    case sessionNotFound
    case connectionFailed
    case authenticationFailed
    case sessionFull
    case kicked
    case networkError

    var errorDescription: String? {
        switch self {
        case .sessionNotFound: return "Session not found. Check the code and try again."
        case .connectionFailed: return "Failed to connect. Check your network."
        case .authenticationFailed: return "Authentication failed."
        case .sessionFull: return "This session is full."
        case .kicked: return "You were removed from the session."
        case .networkError: return "Network error occurred."
        }
    }
}

// MARK: - Connection Info (from WorldwideSyncBridge)

struct SessionConnectionInfo {
    let sessionId: UUID
    let sessionName: String
    let hostId: UUID
    let address: String
    let port: UInt16
    let roomId: String
    let isPrivate: Bool
    let createdAt: Date
}
