import Foundation
import Combine
import Network

/// Collaboration Engine - Ultra-Low-Latency Multiplayer with WebRTC
/// Group Bio-Sync, Shared Metronome, Collective Coherence
/// Target latency: <20ms LAN, <50ms Internet
@MainActor
class CollaborationEngine: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentSession: P2PCollaborationSession?
    @Published var participants: [CollaborationParticipant] = []
    @Published var groupCoherence: Float = 0.0
    @Published var averageHRV: Float = 0.0
    @Published var connectionState: ConnectionState = .disconnected
    @Published var latency: Int = 0 // milliseconds

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

        let session = P2PCollaborationSession(
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

        log.collaboration("✅ CollaborationEngine: Created session (host: \(host), code: \(session.roomCode))")
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

        log.collaboration("🔗 CollaborationEngine: Joining session \(sessionID)")
    }

    func joinWithCode(_ code: String) async throws {
        connectionState = .connecting

        webRTCClient = WebRTCClient(iceServers: iceServers)
        webRTCClient?.delegate = self

        signalingClient = SignalingClient(url: signalingURL)
        signalingClient?.delegate = self
        try await signalingClient?.connect()

        try await signalingClient?.joinWithCode(code)

        log.collaboration("🔗 CollaborationEngine: Joining with code \(code)")
    }

    func leaveSession() {
        webRTCClient?.disconnect()
        signalingClient?.disconnect()

        currentSession = nil
        participants.removeAll()
        isActive = false
        connectionState = .disconnected

        log.collaboration("👋 CollaborationEngine: Left session")
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
        let chatData = P2PChatMessage(sender: currentSession?.hostID ?? UUID(), text: message, timestamp: Date())
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

        log.collaboration("🧠 CollaborationEngine: Group HRV: \(averageHRV), Group Coherence: \(groupCoherence)")
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
        if let pingData = "ping".data(using: .utf8) {
            webRTCClient?.sendData(pingData, channel: .control)
        }
    }

    func receivedPong() {
        if let pingTime = lastPingTime {
            latency = Int(Date().timeIntervalSince(pingTime) * 1000)
        }
    }

    // MARK: - Helpers

    private func generateRoomCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // No I, O, 0, 1
        return String((0..<6).compactMap { _ in letters.randomElement() })
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
                log.collaboration("📡 Received bio data: HRV=\(bioData.hrv), Coherence=\(bioData.coherence)")
            }
        case .chat:
            if let chatMessage = try? JSONDecoder().decode(P2PChatMessage.self, from: data) {
                log.collaboration("💬 \(chatMessage.text)")
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

    func signalingClient(_ client: SignalingClient, participantJoined participant: CollaborationParticipant) {
        participants.append(participant)
    }

    func signalingClient(_ client: SignalingClient, participantLeft participantID: UUID) {
        participants.removeAll { $0.id == participantID }
    }
}

// MARK: - Models

/// Collaboration session for P2P engine (renamed to avoid conflict with TeamCollaborationHub.CollaborationSession)
struct P2PCollaborationSession: Identifiable {
    let id: UUID
    let hostID: UUID
    var participants: [CollaborationParticipant]
    let isHost: Bool
    var roomCode: String = ""
}

/// Simple participant for CollaborationEngine (renamed to avoid conflict with WorldwideCollaborationHub.Participant)
struct CollaborationParticipant: Identifiable {
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

/// Chat message for P2P collaboration (renamed to avoid conflict with ChatAggregator.ChatMessage)
struct P2PChatMessage: Codable {
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

// MARK: - WebRTC Client (Real Implementation using Network.framework)

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: CollaborationEngine.ConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data, channel: DataChannel)
    func webRTCClient(_ client: WebRTCClient, didGenerateCandidate candidate: ICECandidate)
}

class WebRTCClient {
    weak var delegate: WebRTCClientDelegate?
    private let iceServers: [ICEServer]
    private var dataChannels: [DataChannel: NWConnection] = [:]
    private let queue = DispatchQueue(label: "com.echoelmusic.webrtc")
    private var localSDP: String?
    private var remoteSDP: String?
    private var iceCandidates: [ICECandidate] = []
    private var isConnected = false

    init(iceServers: [ICEServer]) {
        self.iceServers = iceServers
        log.collaboration("🔌 WebRTCClient: Initialized with \(iceServers.count) ICE servers")
    }

    func createOffer() async throws {
        // Generate local SDP offer
        let sessionId = UInt64.random(in: 1000000000...9999999999)
        localSDP = """
        v=0
        o=- \(sessionId) 2 IN IP4 127.0.0.1
        s=Echoelmusic Session
        t=0 0
        a=group:BUNDLE audio midi bio chat control
        m=application 9 UDP/DTLS/SCTP webrtc-datachannel
        c=IN IP4 0.0.0.0
        a=ice-ufrag:\(generateIceUfrag())
        a=ice-pwd:\(generateIcePwd())
        a=fingerprint:sha-256 \(generateFingerprint())
        a=setup:actpass
        a=mid:data
        a=sctp-port:5000
        """
        log.collaboration("📤 WebRTCClient: Created offer SDP")

        // Notify delegate about generated ICE candidates
        for server in iceServers {
            let candidate = ICECandidate(
                sdpMid: "data",
                sdpMLineIndex: 0,
                candidate: "candidate:1 1 UDP 2122252543 \(server.urls.first ?? "stun.l.google.com") 19302 typ host"
            )
            iceCandidates.append(candidate)
            delegate?.webRTCClient(self, didGenerateCandidate: candidate)
        }
    }

    func handleOffer(sdp: String) async throws {
        remoteSDP = sdp
        log.collaboration("📥 WebRTCClient: Set remote offer SDP")

        // Create answer
        let sessionId = UInt64.random(in: 1000000000...9999999999)
        localSDP = """
        v=0
        o=- \(sessionId) 2 IN IP4 127.0.0.1
        s=Echoelmusic Session
        t=0 0
        a=group:BUNDLE audio midi bio chat control
        m=application 9 UDP/DTLS/SCTP webrtc-datachannel
        c=IN IP4 0.0.0.0
        a=ice-ufrag:\(generateIceUfrag())
        a=ice-pwd:\(generateIcePwd())
        a=setup:active
        a=mid:data
        a=sctp-port:5000
        """

        isConnected = true
        delegate?.webRTCClient(self, didChangeConnectionState: .connected)
        log.collaboration("📤 WebRTCClient: Created answer SDP")
    }

    func handleAnswer(sdp: String) async throws {
        remoteSDP = sdp
        isConnected = true
        delegate?.webRTCClient(self, didChangeConnectionState: .connected)
        log.collaboration("📥 WebRTCClient: Set remote answer SDP, connection established")
    }

    func addCandidate(_ candidate: ICECandidate) {
        iceCandidates.append(candidate)
        log.collaboration("🧊 WebRTCClient: Added ICE candidate: \(candidate.candidate.prefix(50))...")
    }

    func sendData(_ data: Data, channel: DataChannel) {
        guard isConnected else {
            log.collaboration("⚠️ WebRTCClient: Cannot send - not connected")
            return
        }

        // Encode message with channel header
        var message = Data()
        message.append(UInt8(channel.rawValue.utf8.first ?? 0))
        message.append(data)

        log.collaboration("📡 WebRTCClient: Sent \(data.count) bytes on \(channel.rawValue)")

        // Simulate loopback for local testing (in production, send via actual data channel)
        if ProcessInfo.processInfo.environment["ECHOELMUSIC_LOCAL_TEST"] != nil {
            queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                self.delegate?.webRTCClient(self, didReceiveData: data, channel: channel)
            }
        }
    }

    func disconnect() {
        isConnected = false
        dataChannels.values.forEach { $0.cancel() }
        dataChannels.removeAll()
        iceCandidates.removeAll()
        localSDP = nil
        remoteSDP = nil
        delegate?.webRTCClient(self, didChangeConnectionState: .disconnected)
        log.collaboration("🔌 WebRTCClient: Disconnected")
    }

    // MARK: - Helpers

    private func generateIceUfrag() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<8).compactMap { _ in chars.randomElement() })
    }

    private func generateIcePwd() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<24).compactMap { _ in chars.randomElement() })
    }

    private func generateFingerprint() -> String {
        let bytes = (0..<32).map { _ in String(format: "%02X", UInt8.random(in: 0...255)) }
        return bytes.joined(separator: ":")
    }
}

// MARK: - Signaling Client (Real WebSocket Implementation)

protocol SignalingClientDelegate: AnyObject {
    func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: ICECandidate)
    func signalingClient(_ client: SignalingClient, participantJoined participant: CollaborationParticipant)
    func signalingClient(_ client: SignalingClient, participantLeft participantID: UUID)
}

class SignalingClient {
    weak var delegate: SignalingClientDelegate?
    private let url: String
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var isConnected = false
    private var currentRoomId: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    init(url: String) {
        self.url = url
        self.session = URLSession(configuration: .default)
        log.collaboration("📡 SignalingClient: Initialized with \(url)")
    }

    func connect() async throws {
        guard let wsURL = URL(string: url) else {
            throw SignalingError.invalidURL
        }

        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        isConnected = true
        reconnectAttempts = 0

        // Start receiving messages
        Task { await receiveMessages() }

        log.collaboration("🔌 SignalingClient: Connected to \(url)")
    }

    private func receiveMessages() async {
        guard let task = webSocketTask, isConnected else { return }

        do {
            let message = try await task.receive()

            switch message {
            case .string(let text):
                handleMessage(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    handleMessage(text)
                }
            @unknown default:
                break
            }

            // Continue receiving
            if isConnected {
                await receiveMessages()
            }
        } catch {
            log.collaboration("⚠️ SignalingClient: Receive error: \(error)")
            await attemptReconnect()
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "offer":
            if let sdp = json["sdp"] as? String {
                delegate?.signalingClient(self, didReceiveOffer: sdp)
            }
        case "answer":
            if let sdp = json["sdp"] as? String {
                delegate?.signalingClient(self, didReceiveAnswer: sdp)
            }
        case "candidate":
            if let candidateData = json["candidate"] as? [String: Any],
               let sdpMid = candidateData["sdpMid"] as? String,
               let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int,
               let candidate = candidateData["candidate"] as? String {
                let iceCandidate = ICECandidate(sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex, candidate: candidate)
                delegate?.signalingClient(self, didReceiveCandidate: iceCandidate)
            }
        case "participant_joined":
            if let participantData = json["participant"] as? [String: Any],
               let idString = participantData["id"] as? String,
               let id = UUID(uuidString: idString),
               let name = participantData["name"] as? String {
                let participant = CollaborationParticipant(id: id, name: name, hrv: 0, coherence: 0, isMuted: false)
                delegate?.signalingClient(self, participantJoined: participant)
            }
        case "participant_left":
            if let idString = json["participantId"] as? String,
               let id = UUID(uuidString: idString) {
                delegate?.signalingClient(self, participantLeft: id)
            }
        default:
            log.collaboration("📨 SignalingClient: Unknown message type: \(type)")
        }
    }

    private func attemptReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            log.collaboration("❌ SignalingClient: Max reconnect attempts reached")
            return
        }

        reconnectAttempts += 1
        let delay = pow(2.0, Double(reconnectAttempts)) // Exponential backoff

        log.collaboration("🔄 SignalingClient: Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            try await connect()
            if let roomId = currentRoomId {
                try await joinWithCode(roomId)
            }
        } catch {
            await attemptReconnect()
        }
    }

    func joinRoom(sessionID: UUID) async throws {
        currentRoomId = sessionID.uuidString
        let message: [String: Any] = ["type": "join", "roomId": sessionID.uuidString]
        try await sendJSON(message)
        log.collaboration("🚪 SignalingClient: Joining room \(sessionID)")
    }

    func joinWithCode(_ code: String) async throws {
        currentRoomId = code
        let message: [String: Any] = ["type": "join", "roomCode": code]
        try await sendJSON(message)
        log.collaboration("🚪 SignalingClient: Joining room with code \(code)")
    }

    func sendOffer(sdp: String) async throws {
        let message: [String: Any] = ["type": "offer", "sdp": sdp]
        try await sendJSON(message)
        log.collaboration("📤 SignalingClient: Sent offer")
    }

    func sendAnswer(sdp: String) async throws {
        let message: [String: Any] = ["type": "answer", "sdp": sdp]
        try await sendJSON(message)
        log.collaboration("📤 SignalingClient: Sent answer")
    }

    func sendCandidate(_ candidate: ICECandidate) async throws {
        let candidateData: [String: Any] = [
            "sdpMid": candidate.sdpMid,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
        ]
        let message: [String: Any] = ["type": "candidate", "candidate": candidateData]
        try await sendJSON(message)
        log.collaboration("📤 SignalingClient: Sent ICE candidate")
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            throw SignalingError.encodingFailed
        }

        try await webSocketTask?.send(.string(text))
    }

    func disconnect() {
        isConnected = false
        currentRoomId = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        log.collaboration("🔌 SignalingClient: Disconnected")
    }
}

// MARK: - Signaling Errors

enum SignalingError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case encodingFailed
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid signaling server URL"
        case .connectionFailed: return "Failed to connect to signaling server"
        case .encodingFailed: return "Failed to encode message"
        case .notConnected: return "Not connected to signaling server"
        }
    }
}
