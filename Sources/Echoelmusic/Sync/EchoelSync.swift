import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELSYNC - REAL-TIME COLLABORATION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Online collaboration features:
// • Real-time session sync
// • Multi-participant bio-coherence
// • Shared audio/visual state
// • Latency-compensated playback
// • Collaborative entrainment
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Sync Protocol Types

/// Participant in a sync session
public struct SyncParticipant: Codable, Identifiable, Sendable {
    public let id: String
    public var displayName: String
    public var avatarURL: String?
    public var role: ParticipantRole
    public var isHost: Bool
    public var joinedAt: TimeInterval
    public var lastSeen: TimeInterval
    public var bioState: ParticipantBioState?
    public var audioState: ParticipantAudioState?

    public enum ParticipantRole: String, Codable, Sendable {
        case host = "host"
        case coHost = "co-host"
        case participant = "participant"
        case observer = "observer"
    }
}

/// Bio state shared between participants
public struct ParticipantBioState: Codable, Sendable {
    public var heartRate: Float
    public var coherence: Float
    public var breathingRate: Float
    public var breathingPhase: Float
    public var entrainmentPhase: Float
}

/// Audio state shared between participants
public struct ParticipantAudioState: Codable, Sendable {
    public var isMuted: Bool
    public var level: Float
    public var isPlaying: Bool
    public var currentTrackId: String?
    public var playbackPosition: TimeInterval
}

/// Sync session configuration
public struct SyncSessionConfig: Codable, Sendable {
    public var sessionName: String
    public var maxParticipants: Int
    public var isPrivate: Bool
    public var accessCode: String?
    public var syncMode: SyncMode
    public var bioShareEnabled: Bool
    public var audioShareEnabled: Bool
    public var visualShareEnabled: Bool

    public enum SyncMode: String, Codable, Sendable {
        case freeform = "freeform"           // Everyone independent
        case hostLed = "host-led"            // Follow host
        case collaborative = "collaborative"  // Merged state
        case entrainment = "entrainment"     // Bio-sync focused
    }
}

/// Real-time sync message
public struct SyncMessage: Codable, Sendable {
    public let type: MessageType
    public let senderId: String
    public let timestamp: TimeInterval
    public let payload: Data

    public enum MessageType: String, Codable, Sendable {
        case join = "join"
        case leave = "leave"
        case bioUpdate = "bio_update"
        case audioUpdate = "audio_update"
        case visualUpdate = "visual_update"
        case parameterChange = "param_change"
        case chat = "chat"
        case reaction = "reaction"
        case syncRequest = "sync_request"
        case syncResponse = "sync_response"
        case ping = "ping"
        case pong = "pong"
    }
}

// MARK: - EchoelSync Engine

/// Main collaboration engine
public final class EchoelSync: ObservableObject {

    public static let shared = EchoelSync()

    // Published state
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var currentSession: SyncSession?
    @Published public private(set) var participants: [SyncParticipant] = []
    @Published public private(set) var groupCoherence: Float = 0
    @Published public private(set) var connectionQuality: ConnectionQuality = .unknown

    // Callbacks
    public var onParticipantJoined: ((SyncParticipant) -> Void)?
    public var onParticipantLeft: ((SyncParticipant) -> Void)?
    public var onBioStateReceived: ((String, ParticipantBioState) -> Void)?
    public var onParameterChange: ((String, Any) -> Void)?
    public var onChatMessage: ((String, String, String) -> Void)?
    public var onReaction: ((String, String) -> Void)?

    // Internal
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5

    private var localParticipantId: String = UUID().uuidString
    private var serverURL: URL?

    // Latency compensation
    private var serverTimeOffset: TimeInterval = 0
    private var roundTripTimes: [TimeInterval] = []

    private init() {
        session = URLSession(configuration: .default)
    }

    // MARK: - Connection Management

    /// Connect to sync server
    public func connect(to url: URL, participantName: String) async throws {
        serverURL = url

        let wsURL = url.appendingPathComponent("ws")
        webSocket = session?.webSocketTask(with: wsURL)
        webSocket?.resume()

        // Start receiving messages
        receiveMessages()

        // Send join message
        let joinPayload = JoinPayload(
            participantId: localParticipantId,
            displayName: participantName,
            clientVersion: "1.0.0"
        )

        try await send(message: SyncMessage(
            type: .join,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(joinPayload)
        ))

        isConnected = true
        startPingTimer()
    }

    /// Disconnect from server
    public func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        isConnected = false
        currentSession = nil
        participants.removeAll()
    }

    /// Create a new session
    public func createSession(config: SyncSessionConfig) async throws -> SyncSession {
        guard isConnected else {
            throw SyncError.notConnected
        }

        let session = SyncSession(
            id: UUID().uuidString,
            config: config,
            hostId: localParticipantId,
            createdAt: Date().timeIntervalSince1970,
            state: .active
        )

        currentSession = session
        return session
    }

    /// Join existing session
    public func joinSession(sessionId: String, accessCode: String? = nil) async throws {
        guard isConnected else {
            throw SyncError.notConnected
        }

        let joinRequest = SessionJoinRequest(
            sessionId: sessionId,
            accessCode: accessCode
        )

        try await send(message: SyncMessage(
            type: .syncRequest,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(joinRequest)
        ))
    }

    /// Leave current session
    public func leaveSession() async throws {
        guard currentSession != nil else { return }

        try await send(message: SyncMessage(
            type: .leave,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: Data()
        ))

        currentSession = nil
    }

    // MARK: - Bio State Sharing

    /// Share local bio state with session
    public func shareBioState(_ state: ParticipantBioState) async throws {
        guard currentSession?.config.bioShareEnabled == true else { return }

        try await send(message: SyncMessage(
            type: .bioUpdate,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(state)
        ))
    }

    /// Calculate group coherence from all participants
    public func calculateGroupCoherence() -> Float {
        let bioStates = participants.compactMap { $0.bioState }
        guard bioStates.count > 1 else { return 0 }

        // Calculate phase coherence of breathing
        var sumCos: Float = 0
        var sumSin: Float = 0

        for state in bioStates {
            let angle = state.breathingPhase * 2 * .pi
            sumCos += cos(angle)
            sumSin += sin(angle)
        }

        let n = Float(bioStates.count)
        let phaseCoherence = sqrt(sumCos * sumCos + sumSin * sumSin) / n

        // Calculate HRV coherence similarity
        var coherenceSum: Float = 0
        for state in bioStates {
            coherenceSum += state.coherence
        }
        let avgCoherence = coherenceSum / n

        // Combine metrics
        groupCoherence = phaseCoherence * 0.5 + avgCoherence * 0.5

        return groupCoherence
    }

    // MARK: - Audio Sync

    /// Share audio state
    public func shareAudioState(_ state: ParticipantAudioState) async throws {
        guard currentSession?.config.audioShareEnabled == true else { return }

        try await send(message: SyncMessage(
            type: .audioUpdate,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(state)
        ))
    }

    /// Request sync to host's playback
    public func syncToHost() async throws {
        guard let session = currentSession else {
            throw SyncError.noActiveSession
        }

        let request = SyncRequest(
            targetId: session.hostId,
            requestType: .playback
        )

        try await send(message: SyncMessage(
            type: .syncRequest,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(request)
        ))
    }

    // MARK: - Parameter Sharing

    /// Share parameter change
    public func shareParameter(name: String, value: Any) async throws {
        let paramData = ParameterChange(
            name: name,
            valueType: String(describing: type(of: value)),
            valueData: try JSONSerialization.data(withJSONObject: ["value": value])
        )

        try await send(message: SyncMessage(
            type: .parameterChange,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(paramData)
        ))
    }

    // MARK: - Chat & Reactions

    /// Send chat message
    public func sendChat(_ message: String) async throws {
        let chatData = ChatMessage(
            text: message,
            senderName: participants.first { $0.id == localParticipantId }?.displayName ?? "Unknown"
        )

        try await send(message: SyncMessage(
            type: .chat,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(chatData)
        ))
    }

    /// Send reaction
    public func sendReaction(_ emoji: String) async throws {
        let reactionData = Reaction(emoji: emoji)

        try await send(message: SyncMessage(
            type: .reaction,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(reactionData)
        ))
    }

    // MARK: - Internal Methods

    private func send(message: SyncMessage) async throws {
        let data = try JSONEncoder().encode(message)
        try await webSocket?.send(.data(data))
    }

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessages()  // Continue receiving

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            do {
                let syncMessage = try JSONDecoder().decode(SyncMessage.self, from: data)
                processMessage(syncMessage)
            } catch {
                print("Failed to decode message: \(error)")
            }

        case .string(let string):
            if let data = string.data(using: .utf8) {
                do {
                    let syncMessage = try JSONDecoder().decode(SyncMessage.self, from: data)
                    processMessage(syncMessage)
                } catch {
                    print("Failed to decode string message: \(error)")
                }
            }

        @unknown default:
            break
        }
    }

    private func processMessage(_ message: SyncMessage) {
        switch message.type {
        case .join:
            handleParticipantJoin(message)

        case .leave:
            handleParticipantLeave(message)

        case .bioUpdate:
            handleBioUpdate(message)

        case .audioUpdate:
            handleAudioUpdate(message)

        case .parameterChange:
            handleParameterChange(message)

        case .chat:
            handleChat(message)

        case .reaction:
            handleReaction(message)

        case .pong:
            handlePong(message)

        case .syncResponse:
            handleSyncResponse(message)

        default:
            break
        }
    }

    private func handleParticipantJoin(_ message: SyncMessage) {
        guard let joinPayload = try? JSONDecoder().decode(JoinPayload.self, from: message.payload) else { return }

        let participant = SyncParticipant(
            id: joinPayload.participantId,
            displayName: joinPayload.displayName,
            role: .participant,
            isHost: false,
            joinedAt: message.timestamp,
            lastSeen: message.timestamp
        )

        if !participants.contains(where: { $0.id == participant.id }) {
            participants.append(participant)
            onParticipantJoined?(participant)
        }
    }

    private func handleParticipantLeave(_ message: SyncMessage) {
        if let index = participants.firstIndex(where: { $0.id == message.senderId }) {
            let participant = participants.remove(at: index)
            onParticipantLeft?(participant)
        }
    }

    private func handleBioUpdate(_ message: SyncMessage) {
        guard let bioState = try? JSONDecoder().decode(ParticipantBioState.self, from: message.payload) else { return }

        if let index = participants.firstIndex(where: { $0.id == message.senderId }) {
            participants[index].bioState = bioState
            participants[index].lastSeen = message.timestamp
        }

        onBioStateReceived?(message.senderId, bioState)
        _ = calculateGroupCoherence()
    }

    private func handleAudioUpdate(_ message: SyncMessage) {
        guard let audioState = try? JSONDecoder().decode(ParticipantAudioState.self, from: message.payload) else { return }

        if let index = participants.firstIndex(where: { $0.id == message.senderId }) {
            participants[index].audioState = audioState
        }
    }

    private func handleParameterChange(_ message: SyncMessage) {
        guard let paramChange = try? JSONDecoder().decode(ParameterChange.self, from: message.payload) else { return }

        if let valueDict = try? JSONSerialization.jsonObject(with: paramChange.valueData) as? [String: Any],
           let value = valueDict["value"] {
            onParameterChange?(paramChange.name, value)
        }
    }

    private func handleChat(_ message: SyncMessage) {
        guard let chat = try? JSONDecoder().decode(ChatMessage.self, from: message.payload) else { return }
        onChatMessage?(message.senderId, chat.senderName, chat.text)
    }

    private func handleReaction(_ message: SyncMessage) {
        guard let reaction = try? JSONDecoder().decode(Reaction.self, from: message.payload) else { return }
        onReaction?(message.senderId, reaction.emoji)
    }

    private func handlePong(_ message: SyncMessage) {
        if let pong = try? JSONDecoder().decode(PongPayload.self, from: message.payload) {
            let rtt = Date().timeIntervalSince1970 - pong.originalTimestamp
            roundTripTimes.append(rtt)
            if roundTripTimes.count > 10 {
                roundTripTimes.removeFirst()
            }

            // Update server time offset
            serverTimeOffset = pong.serverTimestamp - Date().timeIntervalSince1970 - rtt / 2

            // Update connection quality
            let avgRTT = roundTripTimes.reduce(0, +) / Double(roundTripTimes.count)
            if avgRTT < 0.05 {
                connectionQuality = .excellent
            } else if avgRTT < 0.1 {
                connectionQuality = .good
            } else if avgRTT < 0.2 {
                connectionQuality = .fair
            } else {
                connectionQuality = .poor
            }
        }
    }

    private func handleSyncResponse(_ message: SyncMessage) {
        // Handle sync response from server
    }

    private func handleDisconnect() {
        isConnected = false
        connectionQuality = .unknown

        // Attempt reconnect
        if reconnectAttempts < maxReconnectAttempts, let url = serverURL {
            reconnectAttempts += 1
            let delay = Double(reconnectAttempts) * 2.0

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task {
                    try? await self?.connect(to: url, participantName: "")
                }
            }
        }
    }

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                try? await self?.sendPing()
            }
        }
    }

    private func sendPing() async throws {
        let pingPayload = PingPayload(timestamp: Date().timeIntervalSince1970)

        try await send(message: SyncMessage(
            type: .ping,
            senderId: localParticipantId,
            timestamp: currentServerTime(),
            payload: try JSONEncoder().encode(pingPayload)
        ))
    }

    private func currentServerTime() -> TimeInterval {
        return Date().timeIntervalSince1970 + serverTimeOffset
    }
}

// MARK: - Session

public struct SyncSession: Codable, Identifiable {
    public let id: String
    public var config: SyncSessionConfig
    public var hostId: String
    public var createdAt: TimeInterval
    public var state: SessionState

    public enum SessionState: String, Codable {
        case waiting = "waiting"
        case active = "active"
        case paused = "paused"
        case ended = "ended"
    }
}

// MARK: - Supporting Types

public enum ConnectionQuality {
    case unknown
    case poor
    case fair
    case good
    case excellent
}

public enum SyncError: Error {
    case notConnected
    case noActiveSession
    case invalidSession
    case accessDenied
    case serverError(String)
}

// Internal payload types
struct JoinPayload: Codable {
    let participantId: String
    let displayName: String
    let clientVersion: String
}

struct SessionJoinRequest: Codable {
    let sessionId: String
    let accessCode: String?
}

struct SyncRequest: Codable {
    let targetId: String
    let requestType: RequestType

    enum RequestType: String, Codable {
        case playback
        case parameters
        case fullState
    }
}

struct ParameterChange: Codable {
    let name: String
    let valueType: String
    let valueData: Data
}

struct ChatMessage: Codable {
    let text: String
    let senderName: String
}

struct Reaction: Codable {
    let emoji: String
}

struct PingPayload: Codable {
    let timestamp: TimeInterval
}

struct PongPayload: Codable {
    let originalTimestamp: TimeInterval
    let serverTimestamp: TimeInterval
}

// MARK: - Group Entrainment Manager

/// Manages bio-entrainment across participants
public final class GroupEntrainmentManager {

    public static let shared = GroupEntrainmentManager()

    // Target entrainment parameters
    public var targetBreathingRate: Float = 6.0  // Coherent breathing rate
    public var targetPhase: Float = 0

    // Group state
    @Published public private(set) var groupPhaseCoherence: Float = 0
    @Published public private(set) var groupHRVCoherence: Float = 0
    @Published public private(set) var entrainmentLevel: EntrainmentLevel = .none

    public enum EntrainmentLevel: String {
        case none = "None"
        case emerging = "Emerging"
        case partial = "Partial"
        case strong = "Strong"
        case synchronized = "Synchronized"
    }

    private init() {}

    /// Update group entrainment from participant bio states
    public func updateEntrainment(participants: [SyncParticipant]) {
        let bioStates = participants.compactMap { $0.bioState }
        guard bioStates.count > 1 else {
            entrainmentLevel = .none
            groupPhaseCoherence = 0
            return
        }

        // Calculate breathing phase coherence
        var sumCos: Float = 0
        var sumSin: Float = 0

        for state in bioStates {
            let angle = state.breathingPhase * 2 * .pi
            sumCos += cos(angle)
            sumSin += sin(angle)
        }

        let n = Float(bioStates.count)
        groupPhaseCoherence = sqrt(sumCos * sumCos + sumSin * sumSin) / n

        // Calculate HRV coherence average
        groupHRVCoherence = bioStates.map { $0.coherence }.reduce(0, +) / n

        // Determine entrainment level
        let combined = groupPhaseCoherence * 0.6 + groupHRVCoherence * 0.4

        if combined > 0.9 {
            entrainmentLevel = .synchronized
        } else if combined > 0.7 {
            entrainmentLevel = .strong
        } else if combined > 0.5 {
            entrainmentLevel = .partial
        } else if combined > 0.3 {
            entrainmentLevel = .emerging
        } else {
            entrainmentLevel = .none
        }
    }

    /// Get guidance for improving group entrainment
    public func getEntrainmentGuidance() -> String {
        switch entrainmentLevel {
        case .none:
            return "Begin breathing together at \(Int(targetBreathingRate)) breaths per minute"
        case .emerging:
            return "Good start! Continue synchronizing your breathing rhythm"
        case .partial:
            return "Getting closer! Focus on the shared breathing pace"
        case .strong:
            return "Excellent synchronization! Maintain this rhythm"
        case .synchronized:
            return "Perfect entrainment achieved! You are in sync"
        }
    }

    /// Calculate optimal target phase for a participant
    public func getTargetPhase(for participant: SyncParticipant, allParticipants: [SyncParticipant]) -> Float {
        // If host, use their phase as reference
        if let host = allParticipants.first(where: { $0.isHost }),
           let hostBio = host.bioState {
            return hostBio.breathingPhase
        }

        // Otherwise, use group average phase
        let phases = allParticipants.compactMap { $0.bioState?.breathingPhase }
        guard !phases.isEmpty else { return targetPhase }

        // Calculate circular mean
        var sumCos: Float = 0
        var sumSin: Float = 0
        for phase in phases {
            let angle = phase * 2 * .pi
            sumCos += cos(angle)
            sumSin += sin(angle)
        }

        let meanAngle = atan2(sumSin, sumCos)
        return (meanAngle / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
    }
}
