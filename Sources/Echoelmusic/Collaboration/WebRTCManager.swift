// WebRTCManager.swift
// Echoelmusic - Real-Time Collaboration via WebRTC
// Low-Latency Audio/Video/Data for Worldwide Collaboration

import Foundation
import Combine
import AVFoundation

// MARK: - WebRTC Configuration

public struct WebRTCConfiguration {
    public var iceServers: [ICEServer]
    public var audioEnabled: Bool
    public var videoEnabled: Bool
    public var dataChannelEnabled: Bool
    public var maxBitrate: Int
    public var preferredCodec: AudioCodec

    public struct ICEServer {
        public let urls: [String]
        public let username: String?
        public let credential: String?

        public init(urls: [String], username: String? = nil, credential: String? = nil) {
            self.urls = urls
            self.username = username
            self.credential = credential
        }

        // Default STUN/TURN servers
        public static let google = ICEServer(urls: ["stun:stun.l.google.com:19302"])
        public static let twilio = ICEServer(urls: ["stun:global.stun.twilio.com:3478"])
    }

    public enum AudioCodec: String {
        case opus = "opus"
        case pcmu = "PCMU"
        case pcma = "PCMA"
        case g722 = "G722"
    }

    public static let `default` = WebRTCConfiguration(
        iceServers: [.google, .twilio],
        audioEnabled: true,
        videoEnabled: false,
        dataChannelEnabled: true,
        maxBitrate: 128000,
        preferredCodec: .opus
    )

    public static let lowLatency = WebRTCConfiguration(
        iceServers: [.google, .twilio],
        audioEnabled: true,
        videoEnabled: false,
        dataChannelEnabled: true,
        maxBitrate: 256000,
        preferredCodec: .opus
    )
}

// MARK: - Signaling

public enum SignalingMessage: Codable {
    case offer(SessionDescription)
    case answer(SessionDescription)
    case candidate(ICECandidate)
    case bye
    case join(roomId: String, userId: String)
    case leave(userId: String)
    case mute(userId: String, isMuted: Bool)
    case metadata(CollaborationMetadata)

    public struct SessionDescription: Codable {
        public let type: String // "offer" or "answer"
        public let sdp: String
    }

    public struct ICECandidate: Codable {
        public let candidate: String
        public let sdpMLineIndex: Int
        public let sdpMid: String?
    }

    public struct CollaborationMetadata: Codable {
        public let userId: String
        public let username: String
        public let role: ParticipantRole
        public let color: String
        public let instrument: String?
    }

    public enum ParticipantRole: String, Codable {
        case host
        case participant
        case viewer
    }
}

// MARK: - Collaboration Room

public struct CollaborationRoom: Identifiable, Codable {
    public let id: String
    public var name: String
    public var hostId: String
    public var participants: [Participant]
    public var settings: RoomSettings
    public var createdAt: Date
    public var isActive: Bool

    public struct Participant: Identifiable, Codable {
        public let id: String
        public var userId: String
        public var username: String
        public var displayName: String
        public var role: SignalingMessage.ParticipantRole
        public var isMuted: Bool
        public var isVideoEnabled: Bool
        public var color: String
        public var instrument: String?
        public var latency: Int // ms
        public var connectionQuality: ConnectionQuality
        public var joinedAt: Date

        public enum ConnectionQuality: String, Codable {
            case excellent
            case good
            case fair
            case poor
            case disconnected
        }
    }

    public struct RoomSettings: Codable {
        public var maxParticipants: Int
        public var isPrivate: Bool
        public var password: String?
        public var allowVideo: Bool
        public var allowChat: Bool
        public var latencyMode: LatencyMode
        public var sampleRate: Int
        public var bufferSize: Int

        public enum LatencyMode: String, Codable {
            case ultraLow = "Ultra Low (<20ms)"
            case low = "Low (<50ms)"
            case standard = "Standard (<100ms)"
            case adaptive = "Adaptive"
        }

        public static let `default` = RoomSettings(
            maxParticipants: 8,
            isPrivate: false,
            password: nil,
            allowVideo: true,
            allowChat: true,
            latencyMode: .low,
            sampleRate: 48000,
            bufferSize: 256
        )
    }
}

// MARK: - Collaboration State

public enum CollaborationState {
    case disconnected
    case connecting
    case connected(CollaborationRoom)
    case reconnecting
    case error(CollaborationError)
}

public enum CollaborationError: Error, LocalizedError {
    case connectionFailed
    case roomNotFound
    case roomFull
    case unauthorized
    case networkError
    case signallingError(String)
    case mediaError(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to collaboration room"
        case .roomNotFound:
            return "Room not found"
        case .roomFull:
            return "Room is full"
        case .unauthorized:
            return "You are not authorized to join this room"
        case .networkError:
            return "Network connection error"
        case .signallingError(let msg):
            return "Signalling error: \(msg)"
        case .mediaError(let msg):
            return "Media error: \(msg)"
        case .timeout:
            return "Connection timed out"
        }
    }
}

// MARK: - WebRTC Manager

@MainActor
public class WebRTCManager: ObservableObject {
    // State
    @Published public private(set) var state: CollaborationState = .disconnected
    @Published public private(set) var currentRoom: CollaborationRoom?
    @Published public private(set) var localParticipant: CollaborationRoom.Participant?
    @Published public private(set) var remoteParticipants: [CollaborationRoom.Participant] = []

    // Audio
    @Published public var isMuted: Bool = false {
        didSet { updateLocalAudioState() }
    }
    @Published public var isDeafened: Bool = false

    // Video
    @Published public var isVideoEnabled: Bool = false {
        didSet { updateLocalVideoState() }
    }

    // Stats
    @Published public private(set) var localLatency: Int = 0
    @Published public private(set) var averageLatency: Int = 0
    @Published public private(set) var packetLoss: Float = 0
    @Published public private(set) var jitter: Float = 0

    // Data Channel
    @Published public private(set) var receivedData: [DataChannelMessage] = []

    // Configuration
    private let configuration: WebRTCConfiguration
    private var signalingConnection: WebSocketConnection?
    private var peerConnections: [String: PeerConnection] = [:]

    // Audio Processing
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?

    // Callbacks
    public var onParticipantJoined: ((CollaborationRoom.Participant) -> Void)?
    public var onParticipantLeft: ((String) -> Void)?
    public var onAudioReceived: ((String, AVAudioPCMBuffer) -> Void)?
    public var onDataReceived: ((DataChannelMessage) -> Void)?
    public var onChatMessage: ((ChatMessage) -> Void)?

    // MARK: - Data Types

    public struct DataChannelMessage: Identifiable {
        public let id: UUID
        public let senderId: String
        public let type: MessageType
        public let payload: Data
        public let timestamp: Date

        public enum MessageType: String {
            case chat
            case midiNote
            case midiCC
            case transport
            case clipTrigger
            case parameter
            case cursor
            case selection
            case custom
        }
    }

    public struct ChatMessage: Identifiable, Codable {
        public let id: UUID
        public let senderId: String
        public let senderName: String
        public let message: String
        public let timestamp: Date
    }

    // MARK: - Initialization

    public init(configuration: WebRTCConfiguration = .default) {
        self.configuration = configuration
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        outputNode = audioEngine?.outputNode
    }

    // MARK: - Room Management

    public func createRoom(name: String, settings: CollaborationRoom.RoomSettings = .default) async throws -> CollaborationRoom {
        state = .connecting

        // Connect to signaling server
        try await connectSignaling()

        // Create room on server
        let roomId = UUID().uuidString
        let room = CollaborationRoom(
            id: roomId,
            name: name,
            hostId: "local-user", // Replace with actual user ID
            participants: [],
            settings: settings,
            createdAt: Date(),
            isActive: true
        )

        // Create local participant
        localParticipant = CollaborationRoom.Participant(
            id: UUID().uuidString,
            userId: "local-user",
            username: "You",
            displayName: "You",
            role: .host,
            isMuted: isMuted,
            isVideoEnabled: isVideoEnabled,
            color: "#00FFFF",
            instrument: nil,
            latency: 0,
            connectionQuality: .excellent,
            joinedAt: Date()
        )

        currentRoom = room
        state = .connected(room)

        // Start audio capture if enabled
        if configuration.audioEnabled {
            try startAudioCapture()
        }

        return room
    }

    public func joinRoom(roomId: String, password: String? = nil) async throws {
        state = .connecting

        // Connect to signaling server
        try await connectSignaling()

        // Send join message
        let joinMessage = SignalingMessage.join(roomId: roomId, userId: "local-user")
        try await sendSignalingMessage(joinMessage)

        // Wait for room info and other participants' offers
        // This would be handled by the signaling message handler

        // Create local participant
        localParticipant = CollaborationRoom.Participant(
            id: UUID().uuidString,
            userId: "local-user",
            username: "You",
            displayName: "You",
            role: .participant,
            isMuted: isMuted,
            isVideoEnabled: isVideoEnabled,
            color: "#FF00FF",
            instrument: nil,
            latency: 0,
            connectionQuality: .excellent,
            joinedAt: Date()
        )

        // Start audio capture if enabled
        if configuration.audioEnabled {
            try startAudioCapture()
        }
    }

    public func leaveRoom() async {
        // Send leave message
        if let participant = localParticipant {
            let leaveMessage = SignalingMessage.leave(userId: participant.userId)
            try? await sendSignalingMessage(leaveMessage)
        }

        // Close all peer connections
        for (_, connection) in peerConnections {
            connection.close()
        }
        peerConnections.removeAll()

        // Stop audio
        stopAudioCapture()

        // Disconnect signaling
        disconnectSignaling()

        // Reset state
        currentRoom = nil
        localParticipant = nil
        remoteParticipants.removeAll()
        state = .disconnected
    }

    // MARK: - Signaling

    private func connectSignaling() async throws {
        let url = URL(string: "wss://collab.echoelmusic.com/ws")!
        signalingConnection = WebSocketConnection(url: url)
        signalingConnection?.onMessage = { [weak self] data in
            self?.handleSignalingMessage(data)
        }
        signalingConnection?.onDisconnect = { [weak self] in
            Task { @MainActor in
                self?.handleSignalingDisconnect()
            }
        }
        try await signalingConnection?.connect()
    }

    private func disconnectSignaling() {
        signalingConnection?.disconnect()
        signalingConnection = nil
    }

    private func sendSignalingMessage(_ message: SignalingMessage) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        try await signalingConnection?.send(data)
    }

    private func handleSignalingMessage(_ data: Data) {
        let decoder = JSONDecoder()
        guard let message = try? decoder.decode(SignalingMessage.self, from: data) else {
            return
        }

        Task { @MainActor in
            switch message {
            case .offer(let sdp):
                await handleOffer(sdp)
            case .answer(let sdp):
                await handleAnswer(sdp)
            case .candidate(let candidate):
                await handleCandidate(candidate)
            case .join(let roomId, let userId):
                await handlePeerJoin(roomId: roomId, userId: userId)
            case .leave(let userId):
                handlePeerLeave(userId: userId)
            case .mute(let userId, let isMuted):
                handlePeerMute(userId: userId, isMuted: isMuted)
            case .metadata(let metadata):
                handlePeerMetadata(metadata)
            case .bye:
                await leaveRoom()
            }
        }
    }

    private func handleSignalingDisconnect() {
        if case .connected = state {
            state = .reconnecting
            // Attempt reconnection
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                try? await connectSignaling()
            }
        }
    }

    // MARK: - Peer Connection

    private func createPeerConnection(for peerId: String) -> PeerConnection {
        let connection = PeerConnection(
            peerId: peerId,
            configuration: configuration
        )

        connection.onLocalCandidate = { [weak self] candidate in
            Task {
                let msg = SignalingMessage.candidate(candidate)
                try? await self?.sendSignalingMessage(msg)
            }
        }

        connection.onRemoteTrack = { [weak self] track in
            self?.handleRemoteTrack(track, from: peerId)
        }

        connection.onDataChannelMessage = { [weak self] message in
            self?.handleDataChannelMessage(message, from: peerId)
        }

        connection.onConnectionStateChange = { [weak self] state in
            self?.handleConnectionStateChange(state, for: peerId)
        }

        peerConnections[peerId] = connection
        return connection
    }

    private func handleOffer(_ sdp: SignalingMessage.SessionDescription) async {
        // Create peer connection and set remote description
        let peerId = "remote-peer" // This should come from the offer
        let connection = createPeerConnection(for: peerId)

        await connection.setRemoteDescription(sdp)
        let answer = await connection.createAnswer()

        if let answer = answer {
            try? await sendSignalingMessage(.answer(answer))
        }
    }

    private func handleAnswer(_ sdp: SignalingMessage.SessionDescription) async {
        // Find peer connection and set remote description
        for (_, connection) in peerConnections {
            await connection.setRemoteDescription(sdp)
        }
    }

    private func handleCandidate(_ candidate: SignalingMessage.ICECandidate) async {
        // Add ICE candidate to peer connections
        for (_, connection) in peerConnections {
            await connection.addICECandidate(candidate)
        }
    }

    private func handlePeerJoin(roomId: String, userId: String) async {
        // Create peer connection and send offer
        let connection = createPeerConnection(for: userId)
        let offer = await connection.createOffer()

        if let offer = offer {
            try? await sendSignalingMessage(.offer(offer))
        }

        // Add to participants
        let participant = CollaborationRoom.Participant(
            id: userId,
            userId: userId,
            username: "Participant",
            displayName: "Participant",
            role: .participant,
            isMuted: false,
            isVideoEnabled: false,
            color: "#00FF00",
            instrument: nil,
            latency: 0,
            connectionQuality: .good,
            joinedAt: Date()
        )
        remoteParticipants.append(participant)
        onParticipantJoined?(participant)
    }

    private func handlePeerLeave(userId: String) {
        peerConnections[userId]?.close()
        peerConnections.removeValue(forKey: userId)
        remoteParticipants.removeAll { $0.userId == userId }
        onParticipantLeft?(userId)
    }

    private func handlePeerMute(userId: String, isMuted: Bool) {
        if let index = remoteParticipants.firstIndex(where: { $0.userId == userId }) {
            remoteParticipants[index].isMuted = isMuted
        }
    }

    private func handlePeerMetadata(_ metadata: SignalingMessage.CollaborationMetadata) {
        if let index = remoteParticipants.firstIndex(where: { $0.userId == metadata.userId }) {
            remoteParticipants[index].username = metadata.username
            remoteParticipants[index].role = metadata.role
            remoteParticipants[index].color = metadata.color
            remoteParticipants[index].instrument = metadata.instrument
        }
    }

    private func handleRemoteTrack(_ track: Any, from peerId: String) {
        // Handle incoming audio/video track
        // This would typically involve connecting to the audio engine
    }

    private func handleDataChannelMessage(_ message: DataChannelMessage, from peerId: String) {
        receivedData.append(message)
        onDataReceived?(message)

        // Handle specific message types
        if message.type == .chat, let chatMessage = try? JSONDecoder().decode(ChatMessage.self, from: message.payload) {
            onChatMessage?(chatMessage)
        }
    }

    private func handleConnectionStateChange(_ state: PeerConnectionState, for peerId: String) {
        if let index = remoteParticipants.firstIndex(where: { $0.userId == peerId }) {
            switch state {
            case .connected:
                remoteParticipants[index].connectionQuality = .good
            case .disconnected:
                remoteParticipants[index].connectionQuality = .disconnected
            case .failed:
                remoteParticipants[index].connectionQuality = .poor
            default:
                break
            }
        }
    }

    // MARK: - Audio

    private func startAudioCapture() throws {
        guard let audioEngine = audioEngine else { return }

        let format = inputNode?.outputFormat(forBus: 0)

        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }

        try audioEngine.start()
    }

    private func stopAudioCapture() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard !isMuted else { return }

        // Send audio to all peer connections
        for (_, connection) in peerConnections {
            connection.sendAudio(buffer)
        }
    }

    private func updateLocalAudioState() {
        // Notify peers of mute state change
        if let participant = localParticipant {
            let message = SignalingMessage.mute(userId: participant.userId, isMuted: isMuted)
            Task {
                try? await sendSignalingMessage(message)
            }
        }
    }

    private func updateLocalVideoState() {
        // Handle video state change
    }

    // MARK: - Data Channel

    public func sendData(_ data: Data, type: DataChannelMessage.MessageType) {
        let message = DataChannelMessage(
            id: UUID(),
            senderId: localParticipant?.userId ?? "",
            type: type,
            payload: data,
            timestamp: Date()
        )

        for (_, connection) in peerConnections {
            connection.sendData(message)
        }
    }

    public func sendChatMessage(_ text: String) {
        guard let participant = localParticipant else { return }

        let chatMessage = ChatMessage(
            id: UUID(),
            senderId: participant.userId,
            senderName: participant.displayName,
            message: text,
            timestamp: Date()
        )

        if let data = try? JSONEncoder().encode(chatMessage) {
            sendData(data, type: .chat)
        }
    }

    public func sendMIDINote(note: UInt8, velocity: UInt8, channel: UInt8) {
        let midiData = Data([0x90 | channel, note, velocity])
        sendData(midiData, type: .midiNote)
    }

    public func sendMIDICC(controller: UInt8, value: UInt8, channel: UInt8) {
        let midiData = Data([0xB0 | channel, controller, value])
        sendData(midiData, type: .midiCC)
    }

    public func sendTransportState(isPlaying: Bool, position: Double, tempo: Double) {
        struct TransportState: Codable {
            let isPlaying: Bool
            let position: Double
            let tempo: Double
        }

        let state = TransportState(isPlaying: isPlaying, position: position, tempo: tempo)
        if let data = try? JSONEncoder().encode(state) {
            sendData(data, type: .transport)
        }
    }

    // MARK: - Stats

    public func updateStats() async {
        var totalLatency = 0
        var count = 0

        for (peerId, connection) in peerConnections {
            let stats = await connection.getStats()

            if let index = remoteParticipants.firstIndex(where: { $0.userId == peerId }) {
                remoteParticipants[index].latency = stats.roundTripTime
                totalLatency += stats.roundTripTime
                count += 1
            }

            packetLoss = stats.packetLoss
            jitter = stats.jitter
        }

        if count > 0 {
            averageLatency = totalLatency / count
        }
    }
}

// MARK: - Supporting Types

enum PeerConnectionState {
    case new
    case connecting
    case connected
    case disconnected
    case failed
    case closed
}

class PeerConnection {
    let peerId: String
    let configuration: WebRTCConfiguration

    var onLocalCandidate: ((SignalingMessage.ICECandidate) -> Void)?
    var onRemoteTrack: ((Any) -> Void)?
    var onDataChannelMessage: ((WebRTCManager.DataChannelMessage) -> Void)?
    var onConnectionStateChange: ((PeerConnectionState) -> Void)?

    init(peerId: String, configuration: WebRTCConfiguration) {
        self.peerId = peerId
        self.configuration = configuration
    }

    func createOffer() async -> SignalingMessage.SessionDescription? {
        // In production, use WebRTC framework to create offer
        return SignalingMessage.SessionDescription(type: "offer", sdp: "v=0...")
    }

    func createAnswer() async -> SignalingMessage.SessionDescription? {
        // In production, use WebRTC framework to create answer
        return SignalingMessage.SessionDescription(type: "answer", sdp: "v=0...")
    }

    func setRemoteDescription(_ sdp: SignalingMessage.SessionDescription) async {
        // Set remote SDP
    }

    func addICECandidate(_ candidate: SignalingMessage.ICECandidate) async {
        // Add ICE candidate
    }

    func sendAudio(_ buffer: AVAudioPCMBuffer) {
        // Send audio over WebRTC
    }

    func sendData(_ message: WebRTCManager.DataChannelMessage) {
        // Send data over data channel
    }

    func getStats() async -> ConnectionStats {
        // Get connection statistics
        return ConnectionStats(roundTripTime: 25, packetLoss: 0.01, jitter: 2.5)
    }

    func close() {
        // Close peer connection
    }

    struct ConnectionStats {
        let roundTripTime: Int // ms
        let packetLoss: Float // 0-1
        let jitter: Float // ms
    }
}

class WebSocketConnection {
    let url: URL
    private var webSocketTask: URLSessionWebSocketTask?

    var onMessage: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    func connect() async throws {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    func send(_ data: Data) async throws {
        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.onMessage?(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self?.onMessage?(data)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessages()
            case .failure:
                self?.onDisconnect?()
            }
        }
    }
}
