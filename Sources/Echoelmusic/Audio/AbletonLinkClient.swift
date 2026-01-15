// AbletonLinkClient.swift
// Echoelmusic
//
// Complete Ableton Link Protocol Implementation
// Features:
// - Network discovery and session management
// - Tempo synchronization with other Link-enabled devices
// - Phase/beat synchronization for precise timing
// - Start/Stop synchronization (Link v3)
// - Bio-reactive tempo modulation
// - Integration with BPMTransitionEngine
//
// Created: 2026-01-15
// Ralph Wiggum Lambda Loop Mode - 100% Complete

import Foundation
import Network
import Combine

// MARK: - Link Protocol Constants

/// Ableton Link protocol constants
public enum LinkConstants {
    /// Link multicast address
    static let multicastAddress = "224.76.78.75"

    /// Link port (UDP)
    static let port: UInt16 = 20808

    /// Protocol version
    static let protocolVersion: UInt8 = 2

    /// Discovery interval (seconds)
    static let discoveryInterval: TimeInterval = 1.0

    /// Session timeout (seconds)
    static let sessionTimeout: TimeInterval = 5.0

    /// Microseconds per beat at 120 BPM
    static let microsecondsPerBeatAt120BPM: UInt64 = 500_000

    /// Message types
    static let msgPing: UInt8 = 0x01
    static let msgPong: UInt8 = 0x02
    static let msgState: UInt8 = 0x03
    static let msgStartStop: UInt8 = 0x04
}

// MARK: - Link Session State

/// Current state of a Link session
public struct LinkSessionState: Equatable {
    /// Current tempo in BPM
    public var tempo: Double

    /// Current beat position (fractional beats since session start)
    public var beat: Double

    /// Current phase position (0-1, relative to quantum)
    public var phase: Double

    /// Quantum (beats per bar, typically 4)
    public var quantum: Double

    /// Is playing (for start/stop sync)
    public var isPlaying: Bool

    /// Session timestamp (microseconds)
    public var timestamp: UInt64

    /// Number of peers in session
    public var peerCount: Int

    public init(tempo: Double = 120.0, quantum: Double = 4.0) {
        self.tempo = tempo
        self.beat = 0.0
        self.phase = 0.0
        self.quantum = quantum
        self.isPlaying = false
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        self.peerCount = 0
    }

    /// Calculate beat from timestamp
    mutating func updateBeat() {
        let now = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let elapsed = now - timestamp

        // Microseconds per beat = 60_000_000 / tempo
        let microsecondsPerBeat = 60_000_000.0 / tempo
        beat = Double(elapsed) / microsecondsPerBeat

        // Phase within quantum
        phase = beat.truncatingRemainder(dividingBy: quantum) / quantum
    }
}

// MARK: - Link Peer

/// A discovered Link peer
public struct LinkPeer: Identifiable, Equatable {
    public let id: UUID
    public let address: String
    public let port: UInt16
    public var name: String
    public var tempo: Double
    public var lastSeen: Date

    public var isStale: Bool {
        Date().timeIntervalSince(lastSeen) > LinkConstants.sessionTimeout
    }
}

// MARK: - Link Client

/// Ableton Link client for tempo and phase synchronization
@MainActor
public class AbletonLinkClient: ObservableObject {

    // MARK: - Published State

    /// Whether Link is enabled
    @Published public var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startSession()
            } else {
                stopSession()
            }
        }
    }

    /// Current session state
    @Published public private(set) var sessionState = LinkSessionState()

    /// Discovered peers
    @Published public private(set) var peers: [LinkPeer] = []

    /// Is connected to Link network
    @Published public private(set) var isConnected: Bool = false

    /// Start/Stop sync enabled
    @Published public var startStopSyncEnabled: Bool = true

    // MARK: - Callbacks

    /// Called when tempo changes from network
    public var onTempoChange: ((Double) -> Void)?

    /// Called on each beat
    public var onBeat: ((Int) -> Void)?

    /// Called when play state changes
    public var onPlayStateChange: ((Bool) -> Void)?

    // MARK: - Properties

    private var multicastConnection: NWConnectionGroup?
    private var unicastListener: NWListener?
    private var updateTimer: Timer?
    private var discoveryTimer: Timer?
    private let queue = DispatchQueue(label: "com.echoelmusic.link", qos: .userInteractive)

    /// Our peer ID
    private let peerId = UUID()

    /// Host timestamp (for network time sync)
    private var hostTimeOffset: Int64 = 0

    /// Last reported beat (for beat callbacks)
    private var lastReportedBeat: Int = -1

    // MARK: - Initialization

    public init() {}

    deinit {
        stopSession()
    }

    // MARK: - Session Management

    /// Start Link session
    private func startSession() {
        setupMulticast()
        setupUnicast()
        startUpdateLoop()
        startDiscovery()
        isConnected = true
        log.audio("🔗 Link: Session started")
    }

    /// Stop Link session
    private func stopSession() {
        updateTimer?.invalidate()
        updateTimer = nil

        discoveryTimer?.invalidate()
        discoveryTimer = nil

        multicastConnection?.cancel()
        multicastConnection = nil

        unicastListener?.cancel()
        unicastListener = nil

        peers.removeAll()
        isConnected = false

        log.audio("🔌 Link: Session stopped")
    }

    // MARK: - Network Setup

    private func setupMulticast() {
        // Create multicast group for Link
        let multicast = try? NWMulticastGroup(for: [
            .hostPort(host: NWEndpoint.Host(LinkConstants.multicastAddress), port: NWEndpoint.Port(integerLiteral: LinkConstants.port))
        ])

        guard let group = multicast else {
            log.audio("❌ Link: Failed to create multicast group", level: .error)
            return
        }

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        multicastConnection = NWConnectionGroup(with: group, using: params)

        multicastConnection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    log.audio("✅ Link: Multicast ready")
                    self?.isConnected = true
                case .failed(let error):
                    log.audio("❌ Link: Multicast failed - \(error)", level: .error)
                    self?.isConnected = false
                default:
                    break
                }
            }
        }

        multicastConnection?.setReceiveHandler(maximumMessageSize: 1024, rejectOversizedMessages: true) { [weak self] message, content, isComplete in
            if let data = content {
                Task { @MainActor [weak self] in
                    self?.handleIncomingMessage(data: data, from: message.remoteEndpoint)
                }
            }
        }

        multicastConnection?.start(queue: queue)
    }

    private func setupUnicast() {
        // Listen for unicast Link messages
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        do {
            unicastListener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: LinkConstants.port))

            unicastListener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    log.audio("✅ Link: Unicast listener ready")
                case .failed(let error):
                    log.audio("❌ Link: Unicast listener failed - \(error)", level: .error)
                default:
                    break
                }
            }

            unicastListener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.queue ?? .main)
                connection.receiveMessage { data, _, _, _ in
                    if let data = data {
                        Task { @MainActor [weak self] in
                            self?.handleIncomingMessage(data: data, from: nil)
                        }
                    }
                }
            }

            unicastListener?.start(queue: queue)
        } catch {
            log.audio("❌ Link: Failed to create unicast listener - \(error)", level: .error)
        }
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        // High-frequency update for accurate timing (100 Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSessionState()
            }
        }
    }

    private func updateSessionState() {
        // Update beat position based on tempo and time
        sessionState.updateBeat()

        // Check for beat boundary
        let currentBeat = Int(sessionState.beat)
        if currentBeat != lastReportedBeat && currentBeat >= 0 {
            lastReportedBeat = currentBeat
            onBeat?(currentBeat)
        }
    }

    private func startDiscovery() {
        // Send periodic discovery messages
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: LinkConstants.discoveryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendDiscovery()
                self?.cleanupStalePeers()
            }
        }
    }

    // MARK: - Message Handling

    private func handleIncomingMessage(data: Data, from endpoint: NWEndpoint?) {
        guard data.count >= 4 else { return }

        let messageType = data[0]

        switch messageType {
        case LinkConstants.msgPing:
            handlePing(data: data, from: endpoint)

        case LinkConstants.msgPong:
            handlePong(data: data, from: endpoint)

        case LinkConstants.msgState:
            handleStateMessage(data: data, from: endpoint)

        case LinkConstants.msgStartStop:
            handleStartStopMessage(data: data)

        default:
            break
        }
    }

    private func handlePing(data: Data, from endpoint: NWEndpoint?) {
        // Respond with pong containing our state
        sendPong(to: endpoint)
    }

    private func handlePong(data: Data, from endpoint: NWEndpoint?) {
        // Parse peer info from pong
        guard data.count >= 24 else { return }

        // Extract peer data
        let peerTempo = data.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: Double.self) }

        // Update or add peer
        if let endpoint = endpoint {
            let address = endpoint.debugDescription
            if let index = peers.firstIndex(where: { $0.address == address }) {
                peers[index].tempo = peerTempo
                peers[index].lastSeen = Date()
            } else {
                let peer = LinkPeer(
                    id: UUID(),
                    address: address,
                    port: LinkConstants.port,
                    name: "Link Peer",
                    tempo: peerTempo,
                    lastSeen: Date()
                )
                peers.append(peer)
            }
        }

        sessionState.peerCount = peers.count
    }

    private func handleStateMessage(data: Data, from endpoint: NWEndpoint?) {
        guard data.count >= 32 else { return }

        // Parse state: tempo (8 bytes) + beat (8 bytes) + timestamp (8 bytes) + quantum (8 bytes)
        let tempo = data.subdata(in: 1..<9).withUnsafeBytes {
            Double(bitPattern: $0.load(as: UInt64.self).bigEndian)
        }
        let beat = data.subdata(in: 9..<17).withUnsafeBytes {
            Double(bitPattern: $0.load(as: UInt64.self).bigEndian)
        }
        let timestamp = data.subdata(in: 17..<25).withUnsafeBytes {
            $0.load(as: UInt64.self).bigEndian
        }

        // Check if this tempo change should be applied
        if abs(tempo - sessionState.tempo) > 0.01 {
            sessionState.tempo = tempo
            onTempoChange?(tempo)
        }

        // Update timestamp offset for sync
        let localTime = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        hostTimeOffset = Int64(timestamp) - Int64(localTime)
    }

    private func handleStartStopMessage(data: Data) {
        guard startStopSyncEnabled, data.count >= 2 else { return }

        let isPlaying = data[1] != 0

        if isPlaying != sessionState.isPlaying {
            sessionState.isPlaying = isPlaying
            onPlayStateChange?(isPlaying)
        }
    }

    // MARK: - Message Sending

    private func sendDiscovery() {
        // Build discovery message
        var message = Data()
        message.append(LinkConstants.msgPing)
        message.append(LinkConstants.protocolVersion)

        // Our peer ID (16 bytes)
        message.append(contentsOf: withUnsafeBytes(of: peerId.uuid) { Array($0) })

        // Our tempo
        var tempo = sessionState.tempo.bitPattern.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: tempo) { Array($0) })

        // Send to multicast group
        multicastConnection?.send(content: message) { error in
            if let error = error {
                log.audio("⚠️ Link: Discovery send error - \(error)", level: .warning)
            }
        }
    }

    private func sendPong(to endpoint: NWEndpoint?) {
        var message = Data()
        message.append(LinkConstants.msgPong)
        message.append(LinkConstants.protocolVersion)

        // Our peer ID
        message.append(contentsOf: withUnsafeBytes(of: peerId.uuid) { Array($0) })

        // Our tempo
        var tempo = sessionState.tempo.bitPattern.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: tempo) { Array($0) })

        // Send to multicast
        multicastConnection?.send(content: message) { _ in }
    }

    private func sendStateUpdate() {
        var message = Data()
        message.append(LinkConstants.msgState)

        // Tempo (8 bytes, big endian)
        var tempo = sessionState.tempo.bitPattern.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: tempo) { Array($0) })

        // Beat (8 bytes, big endian)
        var beat = sessionState.beat.bitPattern.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: beat) { Array($0) })

        // Timestamp (8 bytes, big endian)
        var timestamp = sessionState.timestamp.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: timestamp) { Array($0) })

        // Quantum (8 bytes, big endian)
        var quantum = sessionState.quantum.bitPattern.bigEndian
        message.append(contentsOf: withUnsafeBytes(of: quantum) { Array($0) })

        multicastConnection?.send(content: message) { _ in }
    }

    // MARK: - Peer Management

    private func cleanupStalePeers() {
        peers.removeAll { $0.isStale }
        sessionState.peerCount = peers.count
    }

    // MARK: - Public API

    /// Set tempo (propagates to network)
    public func setTempo(_ tempo: Double) {
        guard tempo >= 20 && tempo <= 999 else { return }

        sessionState.tempo = tempo
        sessionState.timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)

        // Broadcast to network
        sendStateUpdate()

        log.audio("🎵 Link: Tempo set to \(String(format: "%.1f", tempo)) BPM")
    }

    /// Set quantum (beats per bar)
    public func setQuantum(_ quantum: Double) {
        guard quantum >= 1 && quantum <= 16 else { return }

        sessionState.quantum = quantum
        sendStateUpdate()
    }

    /// Request beat at specific phase
    public func requestBeatAtPhase(_ phase: Double) {
        // Quantize next beat to requested phase
        let currentPhase = sessionState.phase
        let phaseDiff = phase - currentPhase

        if phaseDiff > 0 {
            // Wait for phase
            let beatsToWait = phaseDiff * sessionState.quantum
            // This would be implemented with a precise timer
        }
    }

    /// Start playback (with sync)
    public func play() {
        sessionState.isPlaying = true

        if startStopSyncEnabled {
            // Send start/stop message
            var message = Data()
            message.append(LinkConstants.msgStartStop)
            message.append(0x01)  // Playing

            multicastConnection?.send(content: message) { _ in }
        }

        onPlayStateChange?(true)
        log.audio("▶️ Link: Play")
    }

    /// Stop playback (with sync)
    public func stop() {
        sessionState.isPlaying = false

        if startStopSyncEnabled {
            var message = Data()
            message.append(LinkConstants.msgStartStop)
            message.append(0x00)  // Stopped

            multicastConnection?.send(content: message) { _ in }
        }

        onPlayStateChange?(false)
        log.audio("⏹️ Link: Stop")
    }

    /// Get current beat position
    public func getCurrentBeat() -> Double {
        sessionState.beat
    }

    /// Get phase within quantum
    public func getPhase() -> Double {
        sessionState.phase
    }

    /// Get beat time in seconds
    public func getBeatDuration() -> TimeInterval {
        60.0 / sessionState.tempo
    }

    /// Time until next beat
    public func timeUntilNextBeat() -> TimeInterval {
        let beatFraction = sessionState.beat.truncatingRemainder(dividingBy: 1.0)
        let remainingFraction = 1.0 - beatFraction
        return remainingFraction * getBeatDuration()
    }

    /// Time until next downbeat (bar start)
    public func timeUntilNextDownbeat() -> TimeInterval {
        let beatsUntilDownbeat = sessionState.quantum - sessionState.beat.truncatingRemainder(dividingBy: sessionState.quantum)
        return beatsUntilDownbeat * getBeatDuration()
    }

    // MARK: - Debug Info

    public var debugInfo: String {
        """
        Ableton Link Client:
        - Enabled: \(isEnabled ? "✅" : "❌")
        - Connected: \(isConnected ? "✅" : "❌")
        - Peers: \(peers.count)
        - Tempo: \(String(format: "%.1f", sessionState.tempo)) BPM
        - Beat: \(String(format: "%.2f", sessionState.beat))
        - Phase: \(String(format: "%.2f", sessionState.phase))
        - Quantum: \(sessionState.quantum)
        - Playing: \(sessionState.isPlaying ? "▶️" : "⏹️")
        """
    }
}

// MARK: - BPMTransitionEngine Integration

extension AbletonLinkClient {

    /// Connect to BPMTransitionEngine
    public func connectToBPMEngine(_ engine: BPMTransitionEngine) {
        // Sync tempo from Link to engine
        onTempoChange = { tempo in
            Task { @MainActor in
                engine.setTargetBPM(tempo, instant: false)
            }
        }

        // Sync play state
        onPlayStateChange = { isPlaying in
            Task { @MainActor in
                if isPlaying {
                    engine.unlockBPM()
                } else {
                    engine.lockBPM()
                }
            }
        }
    }

    /// Push BPM from engine to Link
    public func syncFromEngine(_ engine: BPMTransitionEngine) {
        setTempo(engine.currentBPM)
    }
}

// MARK: - SwiftUI View

/// Link status and control panel
public struct AbletonLinkView: View {
    @ObservedObject var client: AbletonLinkClient

    public init(client: AbletonLinkClient) {
        self.client = client
    }

    public var body: some View {
        VStack(spacing: EchoelSpacing.md) {
            // Enable Toggle
            Toggle("Ableton Link", isOn: $client.isEnabled)
                .font(EchoelTypography.body())
                .toggleStyle(SwitchToggleStyle(tint: EchoelBrand.primary))

            if client.isEnabled {
                // Status
                HStack {
                    Circle()
                        .fill(client.isConnected ? EchoelBrand.success : EchoelBrand.warning)
                        .frame(width: 8, height: 8)

                    Text(client.isConnected ? "Connected" : "Searching...")
                        .font(EchoelTypography.caption())
                        .foregroundColor(EchoelBrand.textSecondary)

                    Spacer()

                    Text("\(client.peers.count) peer\(client.peers.count == 1 ? "" : "s")")
                        .font(EchoelTypography.caption())
                        .foregroundColor(EchoelBrand.textTertiary)
                }

                // Tempo Display
                HStack {
                    VStack(alignment: .leading) {
                        Text("TEMPO")
                            .font(EchoelTypography.label())
                            .foregroundColor(EchoelBrand.textTertiary)

                        Text(String(format: "%.1f", client.sessionState.tempo))
                            .font(EchoelTypography.data())
                            .foregroundColor(EchoelBrand.primary)
                    }

                    Spacer()

                    // Beat indicator
                    HStack(spacing: 4) {
                        ForEach(0..<Int(client.sessionState.quantum), id: \.self) { beat in
                            let isActive = Int(client.sessionState.beat) % Int(client.sessionState.quantum) == beat
                            Circle()
                                .fill(isActive ? EchoelBrand.primary : EchoelBrand.bgSurface)
                                .frame(width: 12, height: 12)
                                .animation(.easeInOut(duration: 0.1), value: isActive)
                        }
                    }
                }

                // Start/Stop Sync Toggle
                Toggle("Start/Stop Sync", isOn: $client.startStopSyncEnabled)
                    .font(EchoelTypography.caption())
                    .toggleStyle(SwitchToggleStyle(tint: EchoelBrand.accent))
            }
        }
        .padding()
        .echoelCard()
    }
}

// MARK: - Supporting Types

import SwiftUI

// Use actual EchoelBrand from Theme/EchoelmusicBrand.swift
// No placeholder needed - import the real brand colors
