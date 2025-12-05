import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════╗
// ║         WEBSOCKET SIGNALING ENGINE - COMPLETE REAL-TIME IMPLEMENTATION            ║
// ║                                                                                    ║
// ║   Full WebSocket signaling for WebRTC collaboration with:                         ║
// ║   • TLS/WSS support                                                               ║
// ║   • Automatic reconnection with exponential backoff                               ║
// ║   • Message queuing during disconnection                                          ║
// ║   • Heartbeat/ping-pong for connection health                                     ║
// ║   • Room management and peer discovery                                            ║
// ║                                                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Signaling Message Types

public enum SignalingMessageType: String, Codable, Sendable {
    case join = "join"
    case leave = "leave"
    case offer = "offer"
    case answer = "answer"
    case iceCandidate = "ice-candidate"
    case peerList = "peer-list"
    case roomInfo = "room-info"
    case error = "error"
    case ping = "ping"
    case pong = "pong"
    case chat = "chat"
    case parameterChange = "parameter-change"
    case midiEvent = "midi-event"
    case bioSync = "bio-sync"
    case transportSync = "transport-sync"
}

public struct SignalingMessage: Codable, Sendable {
    public let type: SignalingMessageType
    public let roomID: String
    public let senderID: String
    public let targetID: String?
    public let payload: [String: AnyCodable]?
    public let timestamp: Date

    public init(
        type: SignalingMessageType,
        roomID: String,
        senderID: String,
        targetID: String? = nil,
        payload: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.roomID = roomID
        self.senderID = senderID
        self.targetID = targetID
        self.payload = payload
        self.timestamp = Date()
    }
}

/// Type-erased Codable wrapper for payload values
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Connection State

public enum WebSocketConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

// MARK: - WebSocket Signaling Engine

@MainActor
public final class WebSocketSignalingEngine: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectedPeers: [String] = []
    @Published public private(set) var currentRoom: String?
    @Published public private(set) var latencyMs: Double = 0
    @Published public private(set) var messagesReceived: Int = 0
    @Published public private(set) var messagesSent: Int = 0

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let serverURL: URL
        public let userID: String
        public let reconnectAttempts: Int
        public let reconnectBaseDelay: TimeInterval
        public let heartbeatInterval: TimeInterval
        public let messageTimeout: TimeInterval

        public init(
            serverURL: URL,
            userID: String,
            reconnectAttempts: Int = 10,
            reconnectBaseDelay: TimeInterval = 1.0,
            heartbeatInterval: TimeInterval = 30.0,
            messageTimeout: TimeInterval = 10.0
        ) {
            self.serverURL = serverURL
            self.userID = userID
            self.reconnectAttempts = reconnectAttempts
            self.reconnectBaseDelay = reconnectBaseDelay
            self.heartbeatInterval = heartbeatInterval
            self.messageTimeout = messageTimeout
        }
    }

    private let config: Configuration
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectAttempt = 0
    private var pingTimestamp: Date?

    // Message queue for offline/reconnection
    private var messageQueue: [SignalingMessage] = []
    private let maxQueueSize = 100

    // Heartbeat timer
    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Callbacks
    public var onMessage: ((SignalingMessage) -> Void)?
    public var onPeerJoined: ((String) -> Void)?
    public var onPeerLeft: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private let logger = Logger(subsystem: "com.echoelmusic", category: "WebSocket")

    // MARK: - Initialization

    public init(config: Configuration) {
        self.config = config
        super.init()

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.timeoutIntervalForRequest = config.messageTimeout
        self.urlSession = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: .main)
    }

    deinit {
        heartbeatTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Connection Management

    public func connect() async throws {
        guard connectionState != .connected && connectionState != .connecting else {
            logger.info("Already connected or connecting")
            return
        }

        connectionState = .connecting
        reconnectAttempt = 0

        try await establishConnection()
    }

    private func establishConnection() async throws {
        guard let urlSession = urlSession else {
            throw SignalingError.notConfigured
        }

        webSocketTask = urlSession.webSocketTask(with: config.serverURL)
        webSocketTask?.resume()

        // Start receiving messages
        startReceiving()

        // Wait for connection confirmation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Send a ping to verify connection
            webSocketTask?.sendPing { [weak self] error in
                if let error = error {
                    self?.connectionState = .failed
                    continuation.resume(throwing: error)
                } else {
                    Task { @MainActor in
                        self?.connectionState = .connected
                        self?.isConnected = true
                        self?.startHeartbeat()
                        self?.processQueuedMessages()
                        continuation.resume()
                    }
                }
            }
        }

        logger.info("✅ WebSocket connected to \(self.config.serverURL.absoluteString)")
    }

    public func disconnect() async {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        if let room = currentRoom {
            try? await leave(room: room)
        }

        webSocketTask?.cancel(with: .normalClosure, reason: "User disconnected".data(using: .utf8))
        webSocketTask = nil

        connectionState = .disconnected
        isConnected = false
        connectedPeers.removeAll()
        currentRoom = nil

        logger.info("WebSocket disconnected")
    }

    // MARK: - Reconnection Logic

    private func scheduleReconnect() {
        guard reconnectAttempt < config.reconnectAttempts else {
            connectionState = .failed
            logger.error("❌ Max reconnection attempts reached")
            onError?(SignalingError.maxReconnectAttemptsReached)
            return
        }

        connectionState = .reconnecting
        reconnectAttempt += 1

        let delay = config.reconnectBaseDelay * pow(2.0, Double(reconnectAttempt - 1))
        let jitter = Double.random(in: 0...0.5) * delay
        let totalDelay = min(delay + jitter, 60.0) // Cap at 60 seconds

        logger.info("Reconnecting in \(String(format: "%.1f", totalDelay))s (attempt \(self.reconnectAttempt)/\(self.config.reconnectAttempts))")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))

            guard connectionState == .reconnecting else { return }

            do {
                try await establishConnection()

                // Rejoin room if we were in one
                if let room = currentRoom {
                    try await join(room: room)
                }

                reconnectAttempt = 0
                logger.info("✅ Reconnected successfully")
            } catch {
                scheduleReconnect()
            }
        }
    }

    // MARK: - Room Management

    public func join(room: String) async throws {
        guard isConnected else {
            throw SignalingError.notConnected
        }

        let message = SignalingMessage(
            type: .join,
            roomID: room,
            senderID: config.userID
        )

        try await send(message)
        currentRoom = room

        logger.info("Joined room: \(room)")
    }

    public func leave(room: String) async throws {
        guard isConnected else { return }

        let message = SignalingMessage(
            type: .leave,
            roomID: room,
            senderID: config.userID
        )

        try await send(message)

        if currentRoom == room {
            currentRoom = nil
            connectedPeers.removeAll()
        }

        logger.info("Left room: \(room)")
    }

    // MARK: - Message Sending

    public func send(_ message: SignalingMessage) async throws {
        guard isConnected, let webSocketTask = webSocketTask else {
            // Queue message for later if disconnected
            queueMessage(message)
            throw SignalingError.notConnected
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        try await webSocketTask.send(.data(data))
        messagesSent += 1

        logger.debug("Sent: \(message.type.rawValue) to \(message.targetID ?? "all")")
    }

    public func sendOffer(to peerID: String, sdp: String) async throws {
        guard let room = currentRoom else {
            throw SignalingError.notInRoom
        }

        let message = SignalingMessage(
            type: .offer,
            roomID: room,
            senderID: config.userID,
            targetID: peerID,
            payload: ["sdp": AnyCodable(sdp)]
        )

        try await send(message)
    }

    public func sendAnswer(to peerID: String, sdp: String) async throws {
        guard let room = currentRoom else {
            throw SignalingError.notInRoom
        }

        let message = SignalingMessage(
            type: .answer,
            roomID: room,
            senderID: config.userID,
            targetID: peerID,
            payload: ["sdp": AnyCodable(sdp)]
        )

        try await send(message)
    }

    public func sendICECandidate(to peerID: String, candidate: String, sdpMid: String, sdpMLineIndex: Int) async throws {
        guard let room = currentRoom else {
            throw SignalingError.notInRoom
        }

        let message = SignalingMessage(
            type: .iceCandidate,
            roomID: room,
            senderID: config.userID,
            targetID: peerID,
            payload: [
                "candidate": AnyCodable(candidate),
                "sdpMid": AnyCodable(sdpMid),
                "sdpMLineIndex": AnyCodable(sdpMLineIndex)
            ]
        )

        try await send(message)
    }

    public func sendMIDIEvent(note: Int, velocity: Int, channel: Int, isNoteOn: Bool) async throws {
        guard let room = currentRoom else { return }

        let message = SignalingMessage(
            type: .midiEvent,
            roomID: room,
            senderID: config.userID,
            payload: [
                "note": AnyCodable(note),
                "velocity": AnyCodable(velocity),
                "channel": AnyCodable(channel),
                "isNoteOn": AnyCodable(isNoteOn)
            ]
        )

        try await send(message)
    }

    public func sendParameterChange(name: String, value: Float) async throws {
        guard let room = currentRoom else { return }

        let message = SignalingMessage(
            type: .parameterChange,
            roomID: room,
            senderID: config.userID,
            payload: [
                "parameter": AnyCodable(name),
                "value": AnyCodable(Double(value))
            ]
        )

        try await send(message)
    }

    public func sendBioSync(hrv: Double, coherence: Double, heartRate: Double) async throws {
        guard let room = currentRoom else { return }

        let message = SignalingMessage(
            type: .bioSync,
            roomID: room,
            senderID: config.userID,
            payload: [
                "hrv": AnyCodable(hrv),
                "coherence": AnyCodable(coherence),
                "heartRate": AnyCodable(heartRate)
            ]
        )

        try await send(message)
    }

    public func sendChat(_ text: String) async throws {
        guard let room = currentRoom else { return }

        let message = SignalingMessage(
            type: .chat,
            roomID: room,
            senderID: config.userID,
            payload: ["text": AnyCodable(text)]
        )

        try await send(message)
    }

    // MARK: - Message Receiving

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                self?.handleReceiveResult(result)
            }
        }
    }

    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            handleMessage(message)
            // Continue receiving
            startReceiving()

        case .failure(let error):
            logger.error("Receive error: \(error.localizedDescription)")
            handleDisconnection(error: error)
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        messagesReceived += 1

        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            data = s.data(using: .utf8) ?? Data()
        @unknown default:
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let signalingMessage = try decoder.decode(SignalingMessage.self, from: data)
            processSignalingMessage(signalingMessage)
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }

    private func processSignalingMessage(_ message: SignalingMessage) {
        logger.debug("Received: \(message.type.rawValue) from \(message.senderID)")

        switch message.type {
        case .peerList:
            if let peers = message.payload?["peers"]?.value as? [String] {
                connectedPeers = peers.filter { $0 != config.userID }
            }

        case .join:
            if message.senderID != config.userID && !connectedPeers.contains(message.senderID) {
                connectedPeers.append(message.senderID)
                onPeerJoined?(message.senderID)
            }

        case .leave:
            connectedPeers.removeAll { $0 == message.senderID }
            onPeerLeft?(message.senderID)

        case .pong:
            if let pingTime = pingTimestamp {
                latencyMs = Date().timeIntervalSince(pingTime) * 1000
            }

        case .error:
            if let errorMessage = message.payload?["message"]?.value as? String {
                logger.error("Server error: \(errorMessage)")
                onError?(SignalingError.serverError(errorMessage))
            }

        default:
            break
        }

        onMessage?(message)
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: config.heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        pingTimestamp = Date()
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.logger.warning("Ping failed: \(error.localizedDescription)")
                    self?.handleDisconnection(error: error)
                }
            }
        }
    }

    // MARK: - Disconnection Handling

    private func handleDisconnection(error: Error) {
        guard connectionState != .disconnected && connectionState != .reconnecting else { return }

        isConnected = false
        webSocketTask = nil
        heartbeatTimer?.invalidate()

        logger.warning("Connection lost: \(error.localizedDescription)")
        scheduleReconnect()
    }

    // MARK: - Message Queue

    private func queueMessage(_ message: SignalingMessage) {
        guard messageQueue.count < maxQueueSize else {
            logger.warning("Message queue full, dropping oldest message")
            messageQueue.removeFirst()
            return
        }

        messageQueue.append(message)
        logger.debug("Queued message: \(message.type.rawValue) (queue size: \(self.messageQueue.count))")
    }

    private func processQueuedMessages() {
        guard !messageQueue.isEmpty else { return }

        logger.info("Processing \(messageQueue.count) queued messages")

        let messages = messageQueue
        messageQueue.removeAll()

        Task {
            for message in messages {
                try? await send(message)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between messages
            }
        }
    }
}

// MARK: - Errors

public enum SignalingError: LocalizedError {
    case notConfigured
    case notConnected
    case notInRoom
    case connectionFailed
    case maxReconnectAttemptsReached
    case serverError(String)
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "WebSocket not configured"
        case .notConnected:
            return "Not connected to signaling server"
        case .notInRoom:
            return "Not in a collaboration room"
        case .connectionFailed:
            return "Failed to connect to signaling server"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnection attempts reached"
        case .serverError(let message):
            return "Server error: \(message)"
        case .encodingFailed:
            return "Failed to encode message"
        case .decodingFailed:
            return "Failed to decode message"
        }
    }
}

// MARK: - Convenience Extension for Room Codes

extension WebSocketSignalingEngine {

    /// Generate a random room code (6 characters, excludes confusing characters)
    public static func generateRoomCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes I, O, 0, 1
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    /// Validate room code format
    public static func isValidRoomCode(_ code: String) -> Bool {
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return code.count == 6 && code.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }
}
