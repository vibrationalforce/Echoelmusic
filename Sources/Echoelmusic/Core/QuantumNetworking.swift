// QuantumNetworking.swift
// Echoelmusic - Quantum Networking Infrastructure
// SPDX-License-Identifier: MIT
//
// WebRTC, mDNS Discovery, Ableton Link, Real-time Audio Streaming

import Foundation
import Network
import Combine

// MARK: - mDNS Service Discovery

/// Bonjour/mDNS service discovery for local network devices
public actor MDNSDiscovery {

    public struct DiscoveredService: Sendable, Identifiable, Hashable {
        public let id: UUID
        public let name: String
        public let type: ServiceType
        public let host: String
        public let port: UInt16
        public let txtRecord: [String: String]
        public let discoveredAt: Date

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public static func == (lhs: DiscoveredService, rhs: DiscoveredService) -> Bool {
            lhs.id == rhs.id
        }
    }

    public enum ServiceType: String, Sendable, CaseIterable {
        case echoelmusic = "_echoelmusic._tcp"
        case abletonLink = "_ableton-link._udp"
        case airplay = "_airplay._tcp"
        case raop = "_raop._tcp" // Remote Audio Output Protocol
        case midi = "_apple-midi._udp"
        case osc = "_osc._udp"
        case http = "_http._tcp"
        case rtsp = "_rtsp._tcp"

        public var displayName: String {
            switch self {
            case .echoelmusic: return "Echoelmusic"
            case .abletonLink: return "Ableton Link"
            case .airplay: return "AirPlay"
            case .raop: return "AirPlay Audio"
            case .midi: return "Network MIDI"
            case .osc: return "OSC"
            case .http: return "HTTP"
            case .rtsp: return "RTSP"
            }
        }
    }

    public enum DiscoveryError: Error, LocalizedError {
        case browserFailed(String)
        case resolutionFailed(String)
        case networkUnavailable
        case permissionDenied

        public var errorDescription: String? {
            switch self {
            case .browserFailed(let msg): return "Service browser failed: \(msg)"
            case .resolutionFailed(let msg): return "Service resolution failed: \(msg)"
            case .networkUnavailable: return "Network unavailable"
            case .permissionDenied: return "Local network permission denied"
            }
        }
    }

    private var discoveredServices: [String: DiscoveredService] = [:]
    private var browsers: [ServiceType: NWBrowser] = [:]
    private var isSearching = false

    private let serviceSubject = PassthroughSubject<DiscoveredService, Never>()
    private let removalSubject = PassthroughSubject<String, Never>()

    public init() {}

    /// Start browsing for services
    public func startBrowsing(for types: [ServiceType] = ServiceType.allCases) {
        guard !isSearching else { return }
        isSearching = true

        for type in types {
            startBrowser(for: type)
        }
    }

    /// Stop all browsing
    public func stopBrowsing() {
        isSearching = false
        for browser in browsers.values {
            browser.cancel()
        }
        browsers.removeAll()
    }

    private func startBrowser(for type: ServiceType) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type.rawValue, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleBrowserState(state, type: type)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { [weak self] in
                await self?.handleBrowseResults(results, changes: changes, type: type)
            }
        }

        browser.start(queue: .main)
        browsers[type] = browser
    }

    private func handleBrowserState(_ state: NWBrowser.State, type: ServiceType) {
        switch state {
        case .ready:
            print("🔍 mDNS browser ready for \(type.displayName)")
        case .failed(let error):
            print("❌ mDNS browser failed for \(type.displayName): \(error)")
        case .cancelled:
            print("🛑 mDNS browser cancelled for \(type.displayName)")
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>, type: ServiceType) {
        for change in changes {
            switch change {
            case .added(let result):
                resolveService(result, type: type)
            case .removed(let result):
                if case .service(let name, _, _, _) = result.endpoint {
                    let key = "\(type.rawValue)_\(name)"
                    discoveredServices.removeValue(forKey: key)
                    removalSubject.send(key)
                }
            default:
                break
            }
        }
    }

    private func resolveService(_ result: NWBrowser.Result, type: ServiceType) {
        guard case .service(let name, _, _, _) = result.endpoint else { return }

        // Extract metadata from result
        var txtRecord: [String: String] = [:]
        if case .bonjour(let txt) = result.metadata {
            // Parse TXT record
            if let txtDict = txt.dictionary as? [String: String] {
                txtRecord = txtDict
            }
        }

        // Create service entry
        let service = DiscoveredService(
            id: UUID(),
            name: name,
            type: type,
            host: "", // Would be resolved via NWConnection
            port: 0,
            txtRecord: txtRecord,
            discoveredAt: Date()
        )

        let key = "\(type.rawValue)_\(name)"
        discoveredServices[key] = service
        serviceSubject.send(service)

        print("✅ Discovered \(type.displayName) service: \(name)")
    }

    /// Get all discovered services
    public func getServices(of type: ServiceType? = nil) -> [DiscoveredService] {
        if let type = type {
            return discoveredServices.values.filter { $0.type == type }
        }
        return Array(discoveredServices.values)
    }

    /// Publisher for new services
    public var serviceDiscovered: AnyPublisher<DiscoveredService, Never> {
        serviceSubject.eraseToAnyPublisher()
    }

    /// Publisher for removed services
    public var serviceRemoved: AnyPublisher<String, Never> {
        removalSubject.eraseToAnyPublisher()
    }
}

// MARK: - mDNS Service Advertisement

/// Advertise Echoelmusic service on local network
public actor MDNSAdvertiser {

    public struct ServiceInfo: Sendable {
        public let name: String
        public let port: UInt16
        public let txtRecord: [String: String]

        public init(name: String, port: UInt16, txtRecord: [String: String] = [:]) {
            self.name = name
            self.port = port
            self.txtRecord = txtRecord
        }
    }

    private var listener: NWListener?
    private var isAdvertising = false
    private var currentService: ServiceInfo?

    public init() {}

    /// Start advertising service
    public func startAdvertising(_ service: ServiceInfo, type: MDNSDiscovery.ServiceType = .echoelmusic) throws {
        guard !isAdvertising else { return }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        // Create TXT record
        let txtItems = service.txtRecord.map { NWTXTRecord.Entry(key: $0.key, value: $0.value) }
        let txtRecord = NWTXTRecord(txtItems)

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: service.port) ?? .any)

        listener.service = NWListener.Service(
            name: service.name,
            type: type.rawValue,
            domain: "local.",
            txtRecord: txtRecord
        )

        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleListenerState(state)
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleNewConnection(connection)
            }
        }

        listener.start(queue: .main)
        self.listener = listener
        self.currentService = service
        self.isAdvertising = true

        print("📡 Advertising \(service.name) on port \(service.port)")
    }

    /// Stop advertising
    public func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
        currentService = nil
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("✅ mDNS advertiser ready")
        case .failed(let error):
            print("❌ mDNS advertiser failed: \(error)")
            stopAdvertising()
        case .cancelled:
            print("🛑 mDNS advertiser cancelled")
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📥 New connection established")
            case .failed(let error):
                print("❌ Connection failed: \(error)")
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    /// Update TXT record
    public func updateTXTRecord(_ record: [String: String]) {
        guard let service = currentService else { return }
        let txtItems = record.map { NWTXTRecord.Entry(key: $0.key, value: $0.value) }
        let txtRecord = NWTXTRecord(txtItems)

        listener?.service = NWListener.Service(
            name: service.name,
            type: MDNSDiscovery.ServiceType.echoelmusic.rawValue,
            domain: "local.",
            txtRecord: txtRecord
        )
    }
}

// MARK: - Ableton Link Integration

/// Ableton Link protocol implementation for tempo sync
public actor AbletonLinkManager {

    public struct LinkState: Sendable {
        public var isEnabled: Bool = false
        public var numPeers: Int = 0
        public var tempo: Double = 120.0
        public var quantum: Double = 4.0 // Beats per bar
        public var phase: Double = 0.0
        public var isPlaying: Bool = false
        public var beatAtTime: Double = 0.0
    }

    public enum LinkError: Error, LocalizedError {
        case notEnabled
        case connectionFailed
        case invalidTempo
        case syncFailed

        public var errorDescription: String? {
            switch self {
            case .notEnabled: return "Ableton Link is not enabled"
            case .connectionFailed: return "Failed to connect to Link network"
            case .invalidTempo: return "Invalid tempo value"
            case .syncFailed: return "Failed to sync with Link peers"
            }
        }
    }

    private var state = LinkState()
    private let stateSubject = CurrentValueSubject<LinkState, Never>(LinkState())

    // Link callback storage
    private var tempoCallback: ((Double) -> Void)?
    private var peersCallback: ((Int) -> Void)?
    private var playStateCallback: ((Bool) -> Void)?

    public init() {}

    /// Enable Link
    public func enable() {
        state.isEnabled = true
        // Would initialize ABLLink here with actual SDK
        // ABLLinkNew(initialTempo)
        publishState()
    }

    /// Disable Link
    public func disable() {
        state.isEnabled = false
        state.numPeers = 0
        // ABLLinkDelete(link)
        publishState()
    }

    /// Set tempo
    public func setTempo(_ bpm: Double) throws {
        guard bpm >= 20 && bpm <= 400 else {
            throw LinkError.invalidTempo
        }
        state.tempo = bpm
        // ABLLinkSetTempo(sessionState, bpm, hostTimeAtOutput)
        publishState()
    }

    /// Get current beat position
    public func getBeatAtTime(_ hostTime: UInt64) -> Double {
        // Would query Link for beat at given time
        // ABLLinkBeatAtTime(sessionState, hostTime, quantum)
        return state.beatAtTime
    }

    /// Get phase within quantum
    public func getPhaseAtTime(_ hostTime: UInt64) -> Double {
        // ABLLinkPhaseAtTime(sessionState, hostTime, quantum)
        return state.phase
    }

    /// Request beat at specific time (for sync)
    public func requestBeatAtTime(_ beat: Double, time: UInt64, quantum: Double) {
        // ABLLinkRequestBeatAtTime(sessionState, beat, time, quantum)
        state.quantum = quantum
        publishState()
    }

    /// Force beat at time (immediate)
    public func forceBeatAtTime(_ beat: Double, time: UInt64, quantum: Double) {
        // ABLLinkForceBeatAtTime(sessionState, beat, time, quantum)
        state.quantum = quantum
        publishState()
    }

    /// Set play state (for Start/Stop sync)
    public func setPlaying(_ playing: Bool, time: UInt64) {
        state.isPlaying = playing
        // ABLLinkSetIsPlayingAndRequestBeatAtTime(sessionState, playing, time, 0.0, quantum)
        publishState()
    }

    /// Get current state
    public func getState() -> LinkState {
        state
    }

    /// State publisher
    public var statePublisher: AnyPublisher<LinkState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private func publishState() {
        stateSubject.send(state)
    }

    /// Register tempo change callback
    public func onTempoChange(_ callback: @escaping (Double) -> Void) {
        tempoCallback = callback
    }

    /// Register peer count callback
    public func onPeersChanged(_ callback: @escaping (Int) -> Void) {
        peersCallback = callback
    }

    /// Register play state callback
    public func onPlayStateChanged(_ callback: @escaping (Bool) -> Void) {
        playStateCallback = callback
    }

    /// Simulate peer update (for testing)
    internal func simulatePeerUpdate(count: Int) {
        state.numPeers = count
        peersCallback?(count)
        publishState()
    }

    /// Simulate tempo update (for testing)
    internal func simulateTempoUpdate(_ bpm: Double) {
        state.tempo = bpm
        tempoCallback?(bpm)
        publishState()
    }
}

// MARK: - WebRTC Signaling

/// WebRTC signaling server for peer-to-peer audio streaming
public actor WebRTCSignaling {

    public enum SignalType: String, Codable, Sendable {
        case offer
        case answer
        case candidate
        case bye
    }

    public struct SignalMessage: Codable, Sendable {
        public let type: SignalType
        public let peerId: String
        public let payload: String
        public let timestamp: Date

        public init(type: SignalType, peerId: String, payload: String) {
            self.type = type
            self.peerId = peerId
            self.payload = payload
            self.timestamp = Date()
        }
    }

    public enum SignalingState: Sendable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    public enum SignalingError: Error, LocalizedError {
        case connectionFailed(String)
        case sendFailed(String)
        case invalidMessage
        case peerNotFound

        public var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Signaling connection failed: \(msg)"
            case .sendFailed(let msg): return "Failed to send signal: \(msg)"
            case .invalidMessage: return "Invalid signaling message"
            case .peerNotFound: return "Peer not found"
            }
        }
    }

    private var webSocket: URLSessionWebSocketTask?
    private var state: SignalingState = .disconnected
    private let messageSubject = PassthroughSubject<SignalMessage, Never>()
    private let stateSubject = CurrentValueSubject<SignalingState, Never>(.disconnected)
    private var localPeerId: String = UUID().uuidString

    public init() {}

    /// Connect to signaling server
    public func connect(to url: URL) async throws {
        state = .connecting
        stateSubject.send(state)

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        // Start receiving messages
        receiveMessages()

        // Send join message
        let joinMessage = SignalMessage(
            type: .candidate,
            peerId: localPeerId,
            payload: "{\"action\":\"join\"}"
        )
        try await send(joinMessage)

        state = .connected
        stateSubject.send(state)
    }

    /// Disconnect from signaling server
    public func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        state = .disconnected
        stateSubject.send(state)
    }

    /// Send offer to peer
    public func sendOffer(to peerId: String, sdp: String) async throws {
        let message = SignalMessage(type: .offer, peerId: peerId, payload: sdp)
        try await send(message)
    }

    /// Send answer to peer
    public func sendAnswer(to peerId: String, sdp: String) async throws {
        let message = SignalMessage(type: .answer, peerId: peerId, payload: sdp)
        try await send(message)
    }

    /// Send ICE candidate
    public func sendCandidate(to peerId: String, candidate: String) async throws {
        let message = SignalMessage(type: .candidate, peerId: peerId, payload: candidate)
        try await send(message)
    }

    /// Send bye (disconnect from peer)
    public func sendBye(to peerId: String) async throws {
        let message = SignalMessage(type: .bye, peerId: peerId, payload: "")
        try await send(message)
    }

    private func send(_ message: SignalMessage) async throws {
        guard let webSocket = webSocket else {
            throw SignalingError.connectionFailed("Not connected")
        }

        let data = try JSONEncoder().encode(message)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SignalingError.invalidMessage
        }

        try await webSocket.send(.string(string))
    }

    private func receiveMessages() {
        Task {
            guard let webSocket = webSocket else { return }

            do {
                let message = try await webSocket.receive()
                handleMessage(message)
                receiveMessages() // Continue receiving
            } catch {
                state = .error(error.localizedDescription)
                stateSubject.send(state)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let signal = try? JSONDecoder().decode(SignalMessage.self, from: data) {
                messageSubject.send(signal)
            }
        case .data(let data):
            if let signal = try? JSONDecoder().decode(SignalMessage.self, from: data) {
                messageSubject.send(signal)
            }
        @unknown default:
            break
        }
    }

    /// Message publisher
    public var messages: AnyPublisher<SignalMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    /// State publisher
    public var statePublisher: AnyPublisher<SignalingState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// Get local peer ID
    public func getLocalPeerId() -> String {
        localPeerId
    }
}

// MARK: - Real-Time Audio Transport

/// Low-latency audio transport over network
public actor RealTimeAudioTransport {

    public struct TransportConfig: Sendable {
        public var sampleRate: Double = 48000
        public var channelCount: Int = 2
        public var bufferSize: Int = 256
        public var codec: AudioCodec = .opus
        public var bitrate: Int = 128000 // 128 kbps
        public var jitterBufferMs: Int = 20

        public init() {}
    }

    public enum AudioCodec: String, Codable, Sendable {
        case opus // Best for real-time
        case aac
        case flac
        case pcm
    }

    public struct AudioPacket: Sendable {
        public let sequenceNumber: UInt32
        public let timestamp: UInt64
        public let data: Data
        public let codec: AudioCodec
    }

    public enum TransportState: Sendable {
        case idle
        case connecting
        case streaming
        case paused
        case error(String)
    }

    private var config = TransportConfig()
    private var state: TransportState = .idle
    private var sequenceNumber: UInt32 = 0
    private var jitterBuffer: [UInt32: AudioPacket] = [:]
    private var lastPlayedSequence: UInt32 = 0

    // Network stats
    private var packetsSent: UInt64 = 0
    private var packetsReceived: UInt64 = 0
    private var packetsLost: UInt64 = 0
    private var averageLatencyMs: Double = 0

    public init() {}

    /// Configure transport
    public func configure(_ config: TransportConfig) {
        self.config = config
    }

    /// Start streaming
    public func startStreaming() {
        state = .streaming
        sequenceNumber = 0
    }

    /// Stop streaming
    public func stopStreaming() {
        state = .idle
        jitterBuffer.removeAll()
    }

    /// Pause streaming
    public func pause() {
        state = .paused
    }

    /// Resume streaming
    public func resume() {
        state = .streaming
    }

    /// Send audio buffer
    public func send(samples: [Float], timestamp: UInt64) -> AudioPacket {
        sequenceNumber += 1

        // Encode samples (would use actual codec)
        let data = samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer.bindMemory(to: UInt8.self))
        }

        let packet = AudioPacket(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            data: data,
            codec: config.codec
        )

        packetsSent += 1
        return packet
    }

    /// Receive audio packet
    public func receive(_ packet: AudioPacket) -> [Float]? {
        packetsReceived += 1

        // Check for packet loss
        let expectedSeq = lastPlayedSequence + 1
        if packet.sequenceNumber > expectedSeq {
            packetsLost += UInt64(packet.sequenceNumber - expectedSeq)
        }

        // Add to jitter buffer
        jitterBuffer[packet.sequenceNumber] = packet

        // Clean old packets
        let minSeq = packet.sequenceNumber > 100 ? packet.sequenceNumber - 100 : 0
        jitterBuffer = jitterBuffer.filter { $0.key >= minSeq }

        // Get next packet from jitter buffer
        let nextSeq = lastPlayedSequence + 1
        guard let nextPacket = jitterBuffer[nextSeq] else {
            return nil // Wait for more packets
        }

        jitterBuffer.removeValue(forKey: nextSeq)
        lastPlayedSequence = nextSeq

        // Decode samples
        return nextPacket.data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    /// Get transport statistics
    public func getStats() -> (sent: UInt64, received: UInt64, lost: UInt64, latency: Double) {
        (packetsSent, packetsReceived, packetsLost, averageLatencyMs)
    }

    /// Calculate packet loss percentage
    public func getPacketLossPercent() -> Double {
        guard packetsSent > 0 else { return 0 }
        return Double(packetsLost) / Double(packetsSent) * 100
    }
}

// MARK: - Network Quality Monitor

/// Monitor network conditions for adaptive streaming
public actor NetworkQualityMonitor {

    public enum QualityLevel: Int, Sendable, Comparable {
        case excellent = 4
        case good = 3
        case fair = 2
        case poor = 1
        case offline = 0

        public static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var recommendedBitrate: Int {
            switch self {
            case .excellent: return 256000
            case .good: return 192000
            case .fair: return 128000
            case .poor: return 64000
            case .offline: return 0
            }
        }

        public var recommendedBufferMs: Int {
            switch self {
            case .excellent: return 10
            case .good: return 20
            case .fair: return 50
            case .poor: return 100
            case .offline: return 0
            }
        }
    }

    public struct NetworkStats: Sendable {
        public var latencyMs: Double = 0
        public var jitterMs: Double = 0
        public var packetLossPercent: Double = 0
        public var bandwidthBps: Double = 0
        public var qualityLevel: QualityLevel = .offline
    }

    private var stats = NetworkStats()
    private var latencyHistory: [Double] = []
    private var pathMonitor: NWPathMonitor?
    private var isMonitoring = false

    private let statsSubject = CurrentValueSubject<NetworkStats, Never>(NetworkStats())

    public init() {}

    /// Start monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.handlePathUpdate(path)
            }
        }
        pathMonitor?.start(queue: .global(qos: .background))
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    private func handlePathUpdate(_ path: NWPath) {
        if path.status == .satisfied {
            // Network available
            if path.isExpensive {
                stats.qualityLevel = .fair
            } else if path.isConstrained {
                stats.qualityLevel = .good
            } else {
                stats.qualityLevel = .excellent
            }
        } else {
            stats.qualityLevel = .offline
        }
        statsSubject.send(stats)
    }

    /// Update latency measurement
    public func updateLatency(_ latencyMs: Double) {
        latencyHistory.append(latencyMs)
        if latencyHistory.count > 100 {
            latencyHistory.removeFirst()
        }

        stats.latencyMs = latencyMs

        // Calculate jitter (variation in latency)
        if latencyHistory.count > 1 {
            var jitterSum = 0.0
            for i in 1..<latencyHistory.count {
                jitterSum += abs(latencyHistory[i] - latencyHistory[i-1])
            }
            stats.jitterMs = jitterSum / Double(latencyHistory.count - 1)
        }

        updateQualityLevel()
        statsSubject.send(stats)
    }

    /// Update packet loss
    public func updatePacketLoss(_ percent: Double) {
        stats.packetLossPercent = percent
        updateQualityLevel()
        statsSubject.send(stats)
    }

    /// Update bandwidth estimate
    public func updateBandwidth(_ bps: Double) {
        stats.bandwidthBps = bps
        updateQualityLevel()
        statsSubject.send(stats)
    }

    private func updateQualityLevel() {
        // Determine quality based on metrics
        if stats.latencyMs < 20 && stats.jitterMs < 5 && stats.packetLossPercent < 0.1 {
            stats.qualityLevel = .excellent
        } else if stats.latencyMs < 50 && stats.jitterMs < 15 && stats.packetLossPercent < 1 {
            stats.qualityLevel = .good
        } else if stats.latencyMs < 100 && stats.jitterMs < 30 && stats.packetLossPercent < 3 {
            stats.qualityLevel = .fair
        } else {
            stats.qualityLevel = .poor
        }
    }

    /// Get current stats
    public func getStats() -> NetworkStats {
        stats
    }

    /// Stats publisher
    public var statsPublisher: AnyPublisher<NetworkStats, Never> {
        statsSubject.eraseToAnyPublisher()
    }
}
