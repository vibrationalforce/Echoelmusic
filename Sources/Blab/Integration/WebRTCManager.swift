import Foundation
import Combine

#if canImport(WebRTC)
import WebRTC
#endif

/// WebRTC Integration for Real-time Audio/Video/Data Streaming
/// Supports:
/// - Multi-user jam sessions
/// - Low-latency audio streaming
/// - Video streaming of visual engines
/// - Bio-data synchronization
/// - Control data exchange
///
/// Use cases:
/// - Remote collaboration
/// - Live performances with multiple artists
/// - Audience participation
/// - Networked installations

// MARK: - WebRTC Configuration

public struct WebRTCConfiguration {
    public let iceServers: [ICEServer]
    public let audioEnabled: Bool
    public let videoEnabled: Bool
    public let dataChannelEnabled: Bool

    public init(
        iceServers: [ICEServer] = ICEServer.defaultServers,
        audioEnabled: Bool = true,
        videoEnabled: Bool = false,
        dataChannelEnabled: Bool = true
    ) {
        self.iceServers = iceServers
        self.audioEnabled = audioEnabled
        self.videoEnabled = videoEnabled
        self.dataChannelEnabled = dataChannelEnabled
    }

    public struct ICEServer {
        public let urls: [String]
        public let username: String?
        public let credential: String?

        public init(urls: [String], username: String? = nil, credential: String? = nil) {
            self.urls = urls
            self.username = username
            self.credential = credential
        }

        public static let defaultServers = [
            ICEServer(urls: ["stun:stun.l.google.com:19302"]),
            ICEServer(urls: ["stun:stun1.l.google.com:19302"]),
        ]
    }
}

// MARK: - Peer Connection State

public enum PeerConnectionState {
    case new
    case connecting
    case connected
    case disconnected
    case failed
    case closed
}

// MARK: - WebRTC Message Types

public enum WebRTCMessage: Codable {
    case bioData(BiofeedbackData)
    case visualParameters(VisualParameters)
    case audioParameters(AudioParameters)
    case gestureData(GestureData)
    case chat(String)
    case sync(TimeSync)

    public struct BiofeedbackData: Codable {
        public let hrv: Float
        public let heartRate: Float
        public let coherence: Float
        public let timestamp: Date
    }

    public struct VisualParameters: Codable {
        public let mode: String
        public let hue: Float
        public let brightness: Float
        public let saturation: Float
    }

    public struct AudioParameters: Codable {
        public let frequency: Float
        public let amplitude: Float
        public let filter: Float
    }

    public struct GestureData: Codable {
        public let type: String
        public let position: [Float]
        public let velocity: [Float]
    }

    public struct TimeSync: Codable {
        public let localTime: Date
        public let serverTime: Date?
    }
}

// MARK: - WebRTC Manager

/// Main WebRTC manager for peer-to-peer communication
@MainActor
public final class WebRTCManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionState: PeerConnectionState = .new
    @Published public private(set) var connectedPeers: [String] = [] // Peer IDs
    @Published public private(set) var audioLevel: Float = 0
    @Published public var isMuted: Bool = false

    // MARK: - Configuration

    private let configuration: WebRTCConfiguration
    private let peerID: String

    // MARK: - WebRTC Components (when available)

    #if canImport(WebRTC)
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnections: [String: RTCPeerConnection] = [:]
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoTrack: RTCVideoTrack?
    private var dataChannels: [String: RTCDataChannel] = [:]
    private var audioSource: RTCAudioSource?
    private var videoSource: RTCVideoSource?
    #endif

    // Signaling (needs external server implementation)
    private var signalingClient: SignalingClient?

    // MARK: - Callbacks

    public var onRemoteAudioReceived: ((Data) -> Void)?
    public var onRemoteVideoReceived: ((Data) -> Void)?
    public var onDataReceived: ((WebRTCMessage) -> Void)?
    public var onPeerConnected: ((String) -> Void)?
    public var onPeerDisconnected: ((String) -> Void)?

    // MARK: - Initialization

    public init(configuration: WebRTCConfiguration = WebRTCConfiguration(), peerID: String = UUID().uuidString) {
        self.configuration = configuration
        self.peerID = peerID

        #if canImport(WebRTC)
        setupWebRTC()
        #else
        print("⚠️ WebRTC not available on this platform")
        #endif
    }

    #if canImport(WebRTC)
    private func setupWebRTC() {
        // Initialize WebRTC
        RTCInitializeSSL()

        // Create peer connection factory
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()

        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        // Setup audio session
        configureAudioSession()

        print("🌐 WebRTC initialized")
        print("   Peer ID: \(peerID)")
    }

    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try session.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    #endif

    // MARK: - Connection Management

    /// Connect to signaling server and join room
    public func connect(signalingServerURL: URL, roomID: String) async throws {
        signalingClient = SignalingClient(url: signalingServerURL, peerID: peerID, roomID: roomID)

        signalingClient?.onOffer = { [weak self] offer, fromPeer in
            Task { @MainActor in
                await self?.handleRemoteOffer(offer, from: fromPeer)
            }
        }

        signalingClient?.onAnswer = { [weak self] answer, fromPeer in
            Task { @MainActor in
                await self?.handleRemoteAnswer(answer, from: fromPeer)
            }
        }

        signalingClient?.onIceCandidate = { [weak self] candidate, fromPeer in
            Task { @MainActor in
                await self?.handleRemoteIceCandidate(candidate, from: fromPeer)
            }
        }

        try await signalingClient?.connect()

        isConnected = true
        print("🌐 Connected to signaling server")
    }

    /// Disconnect from all peers
    public func disconnect() {
        #if canImport(WebRTC)
        for (_, connection) in peerConnections {
            connection.close()
        }
        peerConnections.removeAll()
        dataChannels.removeAll()
        #endif

        signalingClient?.disconnect()
        signalingClient = nil

        isConnected = false
        connectedPeers.removeAll()
        connectionState = .closed

        print("🌐 Disconnected from WebRTC")
    }

    // MARK: - Peer Connection

    #if canImport(WebRTC)
    private func createPeerConnection(for peerID: String) -> RTCPeerConnection? {
        guard let factory = peerConnectionFactory else { return nil }

        let config = RTCConfiguration()
        config.iceServers = configuration.iceServers.map { server in
            RTCIceServer(urlStrings: server.urls, username: server.username, credential: server.credential)
        }
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            return nil
        }

        // Add local tracks
        if configuration.audioEnabled, let audioTrack = getOrCreateAudioTrack() {
            peerConnection.add(audioTrack, streamIds: ["local_stream"])
        }

        if configuration.videoEnabled, let videoTrack = getOrCreateVideoTrack() {
            peerConnection.add(videoTrack, streamIds: ["local_stream"])
        }

        // Create data channel
        if configuration.dataChannelEnabled {
            let dataChannelConfig = RTCDataChannelConfiguration()
            dataChannelConfig.isOrdered = true

            if let dataChannel = peerConnection.dataChannel(forLabel: "blab_data", configuration: dataChannelConfig) {
                dataChannels[peerID] = dataChannel
                dataChannel.delegate = self
            }
        }

        peerConnections[peerID] = peerConnection

        return peerConnection
    }

    private func getOrCreateAudioTrack() -> RTCAudioTrack? {
        if let track = localAudioTrack {
            return track
        }

        guard let factory = peerConnectionFactory else { return nil }

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: constraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")

        self.audioSource = audioSource
        self.localAudioTrack = audioTrack

        return audioTrack
    }

    private func getOrCreateVideoTrack() -> RTCVideoTrack? {
        if let track = localVideoTrack {
            return track
        }

        guard let factory = peerConnectionFactory else { return nil }

        let videoSource = factory.videoSource()

        // TODO: Capture from visual engine
        // This would require rendering visual output to CVPixelBuffer and feeding to RTCVideoSource

        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")

        self.videoSource = videoSource
        self.localVideoTrack = videoTrack

        return videoTrack
    }
    #endif

    // MARK: - Signaling

    private func handleRemoteOffer(_ offer: String, from peerID: String) async {
        #if canImport(WebRTC)
        guard let peerConnection = createPeerConnection(for: peerID) else { return }

        let sessionDescription = RTCSessionDescription(type: .offer, sdp: offer)

        do {
            try await peerConnection.setRemoteDescription(sessionDescription)

            // Create answer
            let answer = try await peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))

            try await peerConnection.setLocalDescription(answer)

            // Send answer back through signaling
            await signalingClient?.sendAnswer(answer.sdp, to: peerID)

            connectedPeers.append(peerID)
            onPeerConnected?(peerID)

            print("✅ Answered offer from \(peerID)")

        } catch {
            print("❌ Failed to handle offer: \(error)")
        }
        #endif
    }

    private func handleRemoteAnswer(_ answer: String, from peerID: String) async {
        #if canImport(WebRTC)
        guard let peerConnection = peerConnections[peerID] else { return }

        let sessionDescription = RTCSessionDescription(type: .answer, sdp: answer)

        do {
            try await peerConnection.setRemoteDescription(sessionDescription)
            print("✅ Received answer from \(peerID)")
        } catch {
            print("❌ Failed to set remote answer: \(error)")
        }
        #endif
    }

    private func handleRemoteIceCandidate(_ candidate: String, from peerID: String) async {
        #if canImport(WebRTC)
        guard let peerConnection = peerConnections[peerID] else { return }

        // Parse ICE candidate (simplified - real implementation needs proper parsing)
        let parts = candidate.components(separatedBy: " ")
        guard parts.count >= 3 else { return }

        let iceCandidate = RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: 0,
            sdpMid: "0"
        )

        do {
            try await peerConnection.add(iceCandidate)
            print("✅ Added ICE candidate from \(peerID)")
        } catch {
            print("❌ Failed to add ICE candidate: \(error)")
        }
        #endif
    }

    // MARK: - Data Channel Communication

    /// Send WebRTC message to all connected peers
    public func broadcast(_ message: WebRTCMessage) {
        for peerID in connectedPeers {
            send(message, to: peerID)
        }
    }

    /// Send WebRTC message to specific peer
    public func send(_ message: WebRTCMessage, to peerID: String) {
        #if canImport(WebRTC)
        guard let dataChannel = dataChannels[peerID],
              dataChannel.readyState == .open else {
            print("⚠️ Data channel not ready for \(peerID)")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let buffer = RTCDataBuffer(data: data, isBinary: true)
            dataChannel.sendData(buffer)
        } catch {
            print("❌ Failed to send message: \(error)")
        }
        #endif
    }

    // MARK: - Audio Control

    public func mute() {
        isMuted = true
        #if canImport(WebRTC)
        localAudioTrack?.isEnabled = false
        #endif
    }

    public func unmute() {
        isMuted = false
        #if canImport(WebRTC)
        localAudioTrack?.isEnabled = true
        #endif
    }

    // MARK: - Statistics

    public func getConnectionStats(for peerID: String) async -> [String: Any]? {
        #if canImport(WebRTC)
        guard let peerConnection = peerConnections[peerID] else { return nil }

        // Get RTC stats
        // This would require implementing RTCPeerConnectionDelegate and collecting stats

        return [
            "state": connectionState,
            "connectedPeers": connectedPeers.count,
            "audioLevel": audioLevel
        ]
        #else
        return nil
        #endif
    }
}

// MARK: - RTCDataChannelDelegate

#if canImport(WebRTC)
extension WebRTCManager: RTCDataChannelDelegate {
    public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("📡 Data channel state: \(dataChannel.readyState)")

        if dataChannel.readyState == .open {
            connectionState = .connected
        }
    }

    public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        do {
            let message = try JSONDecoder().decode(WebRTCMessage.self, from: buffer.data)
            onDataReceived?(message)
        } catch {
            print("❌ Failed to decode data channel message: \(error)")
        }
    }
}
#endif

// MARK: - Signaling Client

/// WebSocket-based signaling client for WebRTC peer discovery
/// This is a simplified implementation - production would use a proper signaling server
final class SignalingClient {

    private let url: URL
    private let peerID: String
    private let roomID: String

    private var webSocketTask: URLSessionWebSocketTask?

    var onOffer: ((String, String) -> Void)?
    var onAnswer: ((String, String) -> Void)?
    var onIceCandidate: ((String, String) -> Void)?

    init(url: URL, peerID: String, roomID: String) {
        self.url = url
        self.peerID = peerID
        self.roomID = roomID
    }

    func connect() async throws {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Send join message
        let joinMessage = [
            "type": "join",
            "room": roomID,
            "peer": peerID
        ]

        try await send(message: joinMessage)

        // Start receiving
        receiveMessages()

        print("📡 Signaling connected")
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    func sendOffer(_ offer: String, to peerID: String) async {
        let message = [
            "type": "offer",
            "from": self.peerID,
            "to": peerID,
            "sdp": offer
        ]

        try? await send(message: message)
    }

    func sendAnswer(_ answer: String, to peerID: String) async {
        let message = [
            "type": "answer",
            "from": self.peerID,
            "to": peerID,
            "sdp": answer
        ]

        try? await send(message: message)
    }

    private func send(message: [String: String]) async throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8)!

        try await webSocketTask?.send(.string(string))
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessages() // Continue receiving

            case .failure(let error):
                print("❌ WebSocket error: \(error)")
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }

        do {
            let json = try JSONSerialization.jsonObject(with: text.data(using: .utf8)!) as? [String: Any]

            guard let type = json?["type"] as? String,
                  let from = json?["from"] as? String else {
                return
            }

            switch type {
            case "offer":
                if let sdp = json?["sdp"] as? String {
                    onOffer?(sdp, from)
                }

            case "answer":
                if let sdp = json?["sdp"] as? String {
                    onAnswer?(sdp, from)
                }

            case "ice_candidate":
                if let candidate = json?["candidate"] as? String {
                    onIceCandidate?(candidate, from)
                }

            default:
                break
            }

        } catch {
            print("❌ Failed to parse signaling message: \(error)")
        }
    }
}
