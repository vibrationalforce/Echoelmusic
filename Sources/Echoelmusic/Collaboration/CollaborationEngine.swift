import Foundation
import Combine
import Network

/// Collaboration Engine - Ultra-Low-Latency Multiplayer with WebRTC
/// Group Bio-Sync, Shared Metronome, Collective Coherence
/// Target latency: <20ms LAN, <50ms Internet
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class CollaborationEngine {

    // MARK: - Observable State

    var isActive: Bool = false
    var currentSession: CollaborationSession?
    var participants: [Participant] = []
    var groupCoherence: Float = 0.0
    var averageHRV: Float = 0.0
    var connectionState: ConnectionState = .disconnected
    var latency: Int = 0 // milliseconds

    // MARK: - WebRTC Configuration

    private var webRTCClient: WebRTCClient?
    private var signalingClient: SignalingClient?

    /// ICE Server configuration
    private let iceServers: [ICEServer] = [
        ICEServer(urls: ["stun:stun.l.google.com:19302"]),
        ICEServer(urls: ["stun:stun1.l.google.com:19302"]),
        // TURN servers for NAT traversal (would be configured in production)
        // ICEServer(urls: ["turn:turn.echoelmusic.com:3478"], username: "user", credential: "pass")
    ]

    /// Signaling server URL
    private let signalingURL = "wss://signaling.echoelmusic.com"

    // MARK: - Connection State

    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
        case reconnecting = "Reconnecting"
        case failed = "Failed"
    }

    // MARK: - Session Management

    func createSession(as host: Bool) async throws {
        connectionState = .connecting

        // Initialize WebRTC
        webRTCClient = WebRTCClient(iceServers: iceServers)
        webRTCClient?.delegate = self

        // Connect to signaling server
        signalingClient = SignalingClient(url: signalingURL)
        signalingClient?.delegate = self
        try await signalingClient?.connect()

        let session = CollaborationSession(
            id: UUID(),
            hostID: UUID(),
            participants: [],
            isHost: host,
            roomCode: generateRoomCode()
        )

        currentSession = session
        isActive = true
        connectionState = .connected

        // Create offer if host
        if host {
            try await webRTCClient?.createOffer()
        }

        #if DEBUG
        debugLog("✅", "CollaborationEngine: Created session (host: \(host), code: \(session.roomCode))")
        #endif
    }

    func joinSession(sessionID: UUID) async throws {
        connectionState = .connecting

        // Initialize WebRTC
        webRTCClient = WebRTCClient(iceServers: iceServers)
        webRTCClient?.delegate = self

        // Connect to signaling server
        signalingClient = SignalingClient(url: signalingURL)
        signalingClient?.delegate = self
        try await signalingClient?.connect()

        // Request to join session
        try await signalingClient?.joinRoom(sessionID: sessionID)

        #if DEBUG
        debugLog("🔗", "CollaborationEngine: Joining session \(sessionID)")
        #endif
    }

    func joinWithCode(_ code: String) async throws {
        connectionState = .connecting

        webRTCClient = WebRTCClient(iceServers: iceServers)
        webRTCClient?.delegate = self

        signalingClient = SignalingClient(url: signalingURL)
        signalingClient?.delegate = self
        try await signalingClient?.connect()

        try await signalingClient?.joinWithCode(code)

        #if DEBUG
        debugLog("🔗", "CollaborationEngine: Joining with code \(code)")
        #endif
    }

    func leaveSession() {
        webRTCClient?.disconnect()
        signalingClient?.disconnect()

        currentSession = nil
        participants.removeAll()
        isActive = false
        connectionState = .disconnected

        #if DEBUG
        debugLog("👋", "CollaborationEngine: Left session")
        #endif
    }

    // MARK: - Data Channels

    /// Send audio data to all participants
    func sendAudioData(_ data: Data) {
        webRTCClient?.sendData(data, channel: .audio)
    }

    /// Send MIDI data to all participants
    func sendMIDIData(_ data: Data) {
        webRTCClient?.sendData(data, channel: .midi)
    }

    /// Send bio data to all participants
    func sendBioData(hrv: Float, coherence: Float) {
        let bioData = BioSyncData(hrv: hrv, coherence: coherence)
        if let data = try? JSONEncoder().encode(bioData) {
            webRTCClient?.sendData(data, channel: .bio)
        }
    }

    /// Send chat message
    func sendChatMessage(_ message: String) {
        let chatData = ChatMessage(sender: currentSession?.hostID ?? UUID(), text: message, timestamp: Date())
        if let data = try? JSONEncoder().encode(chatData) {
            webRTCClient?.sendData(data, channel: .chat)
        }
    }

    // MARK: - Group Bio-Sync

    func updateGroupBio(participantBio: [(id: UUID, hrv: Float, coherence: Float)]) {
        guard !participantBio.isEmpty else {
            averageHRV = 0.0
            groupCoherence = 0.0
            return
        }

        let count = Float(participantBio.count)
        averageHRV = participantBio.map { $0.hrv }.reduce(0, +) / count
        groupCoherence = participantBio.map { $0.coherence }.reduce(0, +) / count

        #if DEBUG
        debugLog("🧠", "CollaborationEngine: Group HRV: \(averageHRV), Group Coherence: \(groupCoherence)")
        #endif
    }

    func identifyFlowLeader() -> UUID? {
        return participants.max(by: { $0.coherence < $1.coherence })?.id
    }

    // MARK: - Latency Measurement

    private var pingTimer: Timer?
    private var lastPingTime: Date?

    func startLatencyMeasurement() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendPing()
            }
        }
    }

    private func sendPing() {
        lastPingTime = Date()
        webRTCClient?.sendData("ping".data(using: .utf8)!, channel: .control)
    }

    func receivedPong() {
        if let pingTime = lastPingTime {
            latency = Int(Date().timeIntervalSince(pingTime) * 1000)
        }
    }

    // MARK: - Helpers

    private func generateRoomCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No I, O, 0, 1
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}

// MARK: - WebRTC Client Delegate

extension CollaborationEngine: WebRTCClientDelegate {

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: ConnectionState) {
        connectionState = state
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data, channel: DataChannel) {
        switch channel {
        case .audio:
            // Handle incoming audio
            break
        case .midi:
            // Handle incoming MIDI
            break
        case .bio:
            if let bioData = try? JSONDecoder().decode(BioSyncData.self, from: data) {
                // Update participant bio
                #if DEBUG
                debugLog("📡", "Received bio data: HRV=\(bioData.hrv), Coherence=\(bioData.coherence)")
                #endif
            }
        case .chat:
            if let chatMessage = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                #if DEBUG
                debugLog("💬", chatMessage.text)
                #endif
            }
        case .control:
            if String(data: data, encoding: .utf8) == "pong" {
                receivedPong()
            }
        }
    }

    func webRTCClient(_ client: WebRTCClient, didGenerateCandidate candidate: ICECandidate) {
        Task {
            try? await signalingClient?.sendCandidate(candidate)
        }
    }
}

// MARK: - Signaling Client Delegate

extension CollaborationEngine: SignalingClientDelegate {

    func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String) {
        Task {
            try? await webRTCClient?.handleOffer(sdp: sdp)
        }
    }

    func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String) {
        Task {
            try? await webRTCClient?.handleAnswer(sdp: sdp)
        }
    }

    func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: ICECandidate) {
        webRTCClient?.addCandidate(candidate)
    }

    func signalingClient(_ client: SignalingClient, participantJoined participant: Participant) {
        participants.append(participant)
    }

    func signalingClient(_ client: SignalingClient, participantLeft participantID: UUID) {
        participants.removeAll { $0.id == participantID }
    }
}

// MARK: - Models

struct CollaborationSession: Identifiable {
    let id: UUID
    let hostID: UUID
    var participants: [Participant]
    let isHost: Bool
    var roomCode: String = ""
}

struct Participant: Identifiable {
    let id: UUID
    var name: String
    var hrv: Float
    var coherence: Float
    var isMuted: Bool
}

struct BioSyncData: Codable {
    let hrv: Float
    let coherence: Float
}

struct ChatMessage: Codable {
    let sender: UUID
    let text: String
    let timestamp: Date
}

// MARK: - WebRTC Types

struct ICEServer {
    let urls: [String]
    var username: String?
    var credential: String?
}

struct ICECandidate: Codable {
    let sdpMid: String
    let sdpMLineIndex: Int
    let candidate: String
}

enum DataChannel: String {
    case audio
    case midi
    case bio
    case chat
    case control
}

// MARK: - WebRTC Client (Stub - requires WebRTC framework)

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: CollaborationEngine.ConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data, channel: DataChannel)
    func webRTCClient(_ client: WebRTCClient, didGenerateCandidate candidate: ICECandidate)
}

class WebRTCClient {
    weak var delegate: WebRTCClientDelegate?
    private let iceServers: [ICEServer]

    init(iceServers: [ICEServer]) {
        self.iceServers = iceServers
        #if DEBUG
        debugLog("🔌", "WebRTCClient: Initialized with \(iceServers.count) ICE servers")
        #endif
    }

    func createOffer() async throws {
        // In production: Create WebRTC offer SDP
        #if DEBUG
        debugLog("📤", "WebRTCClient: Creating offer")
        #endif
    }

    func handleOffer(sdp: String) async throws {
        // In production: Set remote description, create answer
        #if DEBUG
        debugLog("📥", "WebRTCClient: Handling offer")
        #endif
    }

    func handleAnswer(sdp: String) async throws {
        // In production: Set remote description
        #if DEBUG
        debugLog("📥", "WebRTCClient: Handling answer")
        #endif
    }

    func addCandidate(_ candidate: ICECandidate) {
        // In production: Add ICE candidate
        #if DEBUG
        debugLog("🧊", "WebRTCClient: Adding ICE candidate")
        #endif
    }

    func sendData(_ data: Data, channel: DataChannel) {
        // In production: Send via data channel
        #if DEBUG
        debugLog("📡", "WebRTCClient: Sending \(data.count) bytes on \(channel.rawValue)")
        #endif
    }

    func disconnect() {
        #if DEBUG
        debugLog("🔌", "WebRTCClient: Disconnecting")
        #endif
    }
}

// MARK: - Signaling Client (Stub - requires WebSocket)

protocol SignalingClientDelegate: AnyObject {
    func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: ICECandidate)
    func signalingClient(_ client: SignalingClient, participantJoined participant: Participant)
    func signalingClient(_ client: SignalingClient, participantLeft participantID: UUID)
}

class SignalingClient {
    weak var delegate: SignalingClientDelegate?
    private let url: String

    init(url: String) {
        self.url = url
        #if DEBUG
        debugLog("📡", "SignalingClient: Initialized with \(url)")
        #endif
    }

    func connect() async throws {
        // In production: Connect to WebSocket
        #if DEBUG
        debugLog("🔌", "SignalingClient: Connecting to \(url)")
        #endif
    }

    func joinRoom(sessionID: UUID) async throws {
        #if DEBUG
        debugLog("🚪", "SignalingClient: Joining room \(sessionID)")
        #endif
    }

    func joinWithCode(_ code: String) async throws {
        #if DEBUG
        debugLog("🚪", "SignalingClient: Joining room with code \(code)")
        #endif
    }

    func sendOffer(sdp: String) async throws {
        #if DEBUG
        debugLog("📤", "SignalingClient: Sending offer")
        #endif
    }

    func sendAnswer(sdp: String) async throws {
        #if DEBUG
        debugLog("📤", "SignalingClient: Sending answer")
        #endif
    }

    func sendCandidate(_ candidate: ICECandidate) async throws {
        #if DEBUG
        debugLog("📤", "SignalingClient: Sending ICE candidate")
        #endif
    }

    func disconnect() {
        #if DEBUG
        debugLog("🔌", "SignalingClient: Disconnecting")
        #endif
    }
}

// MARK: - Backward Compatibility

extension CollaborationEngine: ObservableObject { }
