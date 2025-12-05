// AbletonLinkEngine.swift
// Echoelmusic - Ableton Link Integration
// Created by Claude (Phase 4) - December 2025

import Foundation
import Combine

// MARK: - Link Session State

/// Represents the current Link session state
public struct LinkSessionState: Sendable {
    public var tempo: Double  // BPM
    public var beatTime: Double  // Beats since session start
    public var phase: Double  // Position within quantum (0-1)
    public var quantum: Double  // Beats per phase (usually 4)
    public var isPlaying: Bool
    public var numPeers: Int
    public var isConnected: Bool

    public init(tempo: Double = 120, quantum: Double = 4) {
        self.tempo = tempo
        self.beatTime = 0
        self.phase = 0
        self.quantum = quantum
        self.isPlaying = false
        self.numPeers = 0
        self.isConnected = false
    }

    /// Time until next beat in seconds
    public var timeToNextBeat: Double {
        let fractionalBeat = beatTime.truncatingRemainder(dividingBy: 1)
        return (1 - fractionalBeat) * (60.0 / tempo)
    }

    /// Time until next bar (quantum) in seconds
    public var timeToNextBar: Double {
        let fractionalPhase = phase
        return (1 - fractionalPhase) * quantum * (60.0 / tempo)
    }

    /// Current beat within the bar (1-indexed)
    public var currentBeat: Int {
        Int(phase * quantum) + 1
    }
}

// MARK: - Link Timeline

/// Manages beat-synchronized timeline
public final class LinkTimeline: @unchecked Sendable {

    private var startHostTime: UInt64 = 0
    private var beatOrigin: Double = 0
    private var currentTempo: Double = 120

    private let lock = NSLock()

    public init() {
        startHostTime = mach_absolute_time()
    }

    /// Get beat time at given host time
    public func beatAtTime(_ hostTime: UInt64) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let elapsedNanos = hostTimeToNanos(hostTime - startHostTime)
        let elapsedSeconds = Double(elapsedNanos) / 1_000_000_000
        let elapsedBeats = elapsedSeconds * (currentTempo / 60.0)

        return beatOrigin + elapsedBeats
    }

    /// Get host time at given beat
    public func timeAtBeat(_ beat: Double) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        let beatDelta = beat - beatOrigin
        let secondsDelta = beatDelta * (60.0 / currentTempo)
        let nanosDelta = UInt64(secondsDelta * 1_000_000_000)

        return startHostTime + nanosToHostTime(nanosDelta)
    }

    /// Set tempo with optional beat reference
    public func setTempo(_ tempo: Double, atBeat beat: Double? = nil) {
        lock.lock()
        defer { lock.unlock() }

        // Update beat origin to current position before tempo change
        let now = mach_absolute_time()
        let currentBeat = beatAtTimeUnlocked(now)

        beatOrigin = beat ?? currentBeat
        startHostTime = now
        currentTempo = tempo
    }

    /// Request beat at specific time (quantized start)
    public func requestBeatAtTime(_ beat: Double, atTime hostTime: UInt64, quantum: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let currentBeat = beatAtTimeUnlocked(hostTime)
        let phase = currentBeat.truncatingRemainder(dividingBy: quantum)
        let targetPhase = beat.truncatingRemainder(dividingBy: quantum)

        var delta = targetPhase - phase
        if delta < 0 { delta += quantum }

        return currentBeat + delta
    }

    private func beatAtTimeUnlocked(_ hostTime: UInt64) -> Double {
        let elapsedNanos = hostTimeToNanos(hostTime - startHostTime)
        let elapsedSeconds = Double(elapsedNanos) / 1_000_000_000
        let elapsedBeats = elapsedSeconds * (currentTempo / 60.0)
        return beatOrigin + elapsedBeats
    }

    private func hostTimeToNanos(_ hostTime: UInt64) -> UInt64 {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        return hostTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }

    private func nanosToHostTime(_ nanos: UInt64) -> UInt64 {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        return nanos * UInt64(timebaseInfo.denom) / UInt64(timebaseInfo.numer)
    }
}

// MARK: - Link Network Discovery

/// Discovers and connects to Link peers via UDP multicast
public final class LinkNetworkDiscovery: @unchecked Sendable {

    public struct Peer: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let hostAddress: String
        public let port: UInt16
        public var lastSeen: Date
        public var isActive: Bool { Date().timeIntervalSince(lastSeen) < 5 }
    }

    private let multicastGroup = "224.76.78.75"  // Link multicast group
    private let multicastPort: UInt16 = 20808

    private var socket: Int32 = -1
    private var receiveThread: Thread?
    private var isRunning = false

    private let peersLock = NSLock()
    private var discoveredPeers: [String: Peer] = [:]

    public var onPeerDiscovered: ((Peer) -> Void)?
    public var onPeerLost: ((Peer) -> Void)?

    public init() {}

    public func start() throws {
        guard socket == -1 else { return }

        // Create UDP socket
        socket = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard socket >= 0 else {
            throw LinkError.socketCreationFailed
        }

        // Enable address reuse
        var reuse: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // Bind to multicast port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = multicastPort.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(socket)
            socket = -1
            throw LinkError.bindFailed
        }

        // Join multicast group
        var mreq = ip_mreq()
        mreq.imr_multiaddr.s_addr = inet_addr(multicastGroup)
        mreq.imr_interface.s_addr = INADDR_ANY

        setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size))

        // Start receive thread
        isRunning = true
        receiveThread = Thread { [weak self] in
            self?.receiveLoop()
        }
        receiveThread?.start()
    }

    public func stop() {
        isRunning = false
        if socket >= 0 {
            close(socket)
            socket = -1
        }
    }

    private func receiveLoop() {
        var buffer = [UInt8](repeating: 0, count: 1024)
        var senderAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        while isRunning && socket >= 0 {
            let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(socket, &buffer, buffer.count, 0, sockaddrPtr, &addrLen)
                }
            }

            guard bytesRead > 0 else { continue }

            // Parse Link discovery message
            if let message = parseDiscoveryMessage(Data(buffer.prefix(bytesRead))) {
                let hostIP = String(cString: inet_ntoa(senderAddr.sin_addr))

                peersLock.lock()
                let isNew = discoveredPeers[message.sessionId] == nil

                let peer = Peer(
                    id: message.sessionId,
                    name: message.deviceName,
                    hostAddress: hostIP,
                    port: message.port,
                    lastSeen: Date()
                )
                discoveredPeers[message.sessionId] = peer
                peersLock.unlock()

                if isNew {
                    onPeerDiscovered?(peer)
                }
            }
        }
    }

    private struct DiscoveryMessage {
        let sessionId: String
        let deviceName: String
        let port: UInt16
    }

    private func parseDiscoveryMessage(_ data: Data) -> DiscoveryMessage? {
        // Simplified Link protocol parsing
        guard data.count >= 16 else { return nil }

        // Extract session ID (first 8 bytes as hex)
        let sessionId = data.prefix(8).map { String(format: "%02x", $0) }.joined()

        // Device name (next bytes until null terminator or end)
        var nameData = Data()
        for i in 8..<min(data.count, 64) {
            if data[i] == 0 { break }
            nameData.append(data[i])
        }
        let deviceName = String(data: nameData, encoding: .utf8) ?? "Unknown"

        // Port (last 2 bytes, big endian)
        let port = UInt16(data[data.count - 2]) << 8 | UInt16(data[data.count - 1])

        return DiscoveryMessage(sessionId: sessionId, deviceName: deviceName, port: port)
    }

    public func broadcastPresence(sessionId: String, deviceName: String, port: UInt16) {
        guard socket >= 0 else { return }

        // Create discovery message
        var message = Data()

        // Session ID (8 bytes from hex string)
        for i in stride(from: 0, to: min(16, sessionId.count), by: 2) {
            let start = sessionId.index(sessionId.startIndex, offsetBy: i)
            let end = sessionId.index(start, offsetBy: 2)
            if let byte = UInt8(String(sessionId[start..<end]), radix: 16) {
                message.append(byte)
            }
        }
        while message.count < 8 { message.append(0) }

        // Device name (null-terminated)
        message.append(contentsOf: deviceName.utf8)
        message.append(0)

        // Padding
        while message.count < 62 { message.append(0) }

        // Port (big endian)
        message.append(UInt8(port >> 8))
        message.append(UInt8(port & 0xFF))

        // Send to multicast group
        var destAddr = sockaddr_in()
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = multicastPort.bigEndian
        destAddr.sin_addr.s_addr = inet_addr(multicastGroup)

        message.withUnsafeBytes { ptr in
            _ = withUnsafePointer(to: &destAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(socket, ptr.baseAddress, message.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    public var peers: [Peer] {
        peersLock.lock()
        defer { peersLock.unlock() }
        return Array(discoveredPeers.values.filter { $0.isActive })
    }
}

// MARK: - Setlist Manager

/// Manages live performance setlists with cue points
public struct SetlistItem: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var projectPath: String?
    public var tempo: Double
    public var timeSignature: (Int, Int)
    public var cuePoints: [CuePoint]
    public var notes: String
    public var duration: TimeInterval?

    public init(name: String, tempo: Double = 120, timeSignature: (Int, Int) = (4, 4)) {
        self.id = UUID()
        self.name = name
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.cuePoints = []
        self.notes = ""
    }

    enum CodingKeys: String, CodingKey {
        case id, name, projectPath, tempo, cuePoints, notes, duration
        case timeSignatureNumerator, timeSignatureDenominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        tempo = try container.decode(Double.self, forKey: .tempo)
        let num = try container.decode(Int.self, forKey: .timeSignatureNumerator)
        let denom = try container.decode(Int.self, forKey: .timeSignatureDenominator)
        timeSignature = (num, denom)
        cuePoints = try container.decode([CuePoint].self, forKey: .cuePoints)
        notes = try container.decode(String.self, forKey: .notes)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(projectPath, forKey: .projectPath)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(timeSignature.0, forKey: .timeSignatureNumerator)
        try container.encode(timeSignature.1, forKey: .timeSignatureDenominator)
        try container.encode(cuePoints, forKey: .cuePoints)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(duration, forKey: .duration)
    }
}

public struct CuePoint: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var beat: Double
    public var color: CueColor
    public var action: CueAction

    public init(name: String, beat: Double, color: CueColor = .blue, action: CueAction = .marker) {
        self.id = UUID()
        self.name = name
        self.beat = beat
        self.color = color
        self.action = action
    }
}

public enum CueColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink
}

public enum CueAction: String, Codable {
    case marker      // Visual marker only
    case jump        // Jump to this point
    case loop        // Start loop
    case stop        // Stop playback
    case fadeOut     // Fade out
    case nextSong    // Transition to next song
    case tempoChange // Change tempo
    case midiTrigger // Send MIDI
}

public actor SetlistManager {

    private var setlist: [SetlistItem] = []
    private var currentIndex: Int = 0

    public var currentItem: SetlistItem? {
        guard currentIndex < setlist.count else { return nil }
        return setlist[currentIndex]
    }

    public var nextItem: SetlistItem? {
        guard currentIndex + 1 < setlist.count else { return nil }
        return setlist[currentIndex + 1]
    }

    public func add(_ item: SetlistItem) {
        setlist.append(item)
    }

    public func remove(at index: Int) {
        guard index < setlist.count else { return }
        setlist.remove(at: index)
        if currentIndex >= setlist.count {
            currentIndex = max(0, setlist.count - 1)
        }
    }

    public func move(from source: Int, to destination: Int) {
        guard source < setlist.count && destination < setlist.count else { return }
        let item = setlist.remove(at: source)
        setlist.insert(item, at: destination)
    }

    public func goToNext() -> SetlistItem? {
        guard currentIndex + 1 < setlist.count else { return nil }
        currentIndex += 1
        return setlist[currentIndex]
    }

    public func goToPrevious() -> SetlistItem? {
        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return setlist[currentIndex]
    }

    public func goTo(index: Int) -> SetlistItem? {
        guard index >= 0 && index < setlist.count else { return nil }
        currentIndex = index
        return setlist[currentIndex]
    }

    public func updateItem(_ item: SetlistItem) {
        if let index = setlist.firstIndex(where: { $0.id == item.id }) {
            setlist[index] = item
        }
    }

    public func addCuePoint(to itemId: UUID, cue: CuePoint) {
        if let index = setlist.firstIndex(where: { $0.id == itemId }) {
            setlist[index].cuePoints.append(cue)
            setlist[index].cuePoints.sort { $0.beat < $1.beat }
        }
    }

    public func getAll() -> [SetlistItem] {
        setlist
    }

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(setlist)
        try data.write(to: url)
    }

    public func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        setlist = try JSONDecoder().decode([SetlistItem].self, from: data)
        currentIndex = 0
    }
}

// MARK: - Link Errors

public enum LinkError: Error {
    case socketCreationFailed
    case bindFailed
    case notConnected
    case syncFailed
}

// MARK: - Ableton Link Engine

/// Main Ableton Link integration engine
public actor AbletonLinkEngine {

    public static let shared = AbletonLinkEngine()

    // Core components
    private let timeline = LinkTimeline()
    private let networkDiscovery = LinkNetworkDiscovery()
    private let setlistManager = SetlistManager()

    // State
    private var state = LinkSessionState()
    private var sessionId: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
    private var isEnabled = false

    // Callbacks
    public var onTempoChanged: ((Double) -> Void)?
    public var onPeersChanged: ((Int) -> Void)?
    public var onPhaseChanged: ((Double) -> Void)?
    public var onPlayStateChanged: ((Bool) -> Void)?

    // Timer for state updates
    private var updateTask: Task<Void, Never>?

    private init() {
        setupNetworkCallbacks()
    }

    private func setupNetworkCallbacks() {
        networkDiscovery.onPeerDiscovered = { [weak self] peer in
            Task { [weak self] in
                await self?.handlePeerDiscovered(peer)
            }
        }

        networkDiscovery.onPeerLost = { [weak self] peer in
            Task { [weak self] in
                await self?.handlePeerLost(peer)
            }
        }
    }

    private func handlePeerDiscovered(_ peer: LinkNetworkDiscovery.Peer) {
        state.numPeers = networkDiscovery.peers.count
        onPeersChanged?(state.numPeers)
    }

    private func handlePeerLost(_ peer: LinkNetworkDiscovery.Peer) {
        state.numPeers = networkDiscovery.peers.count
        onPeersChanged?(state.numPeers)
    }

    // MARK: - Enable/Disable

    public func enable() async throws {
        guard !isEnabled else { return }

        try networkDiscovery.start()
        isEnabled = true
        state.isConnected = true

        // Start broadcasting presence
        startBroadcasting()

        // Start state update loop
        startUpdateLoop()
    }

    public func disable() async {
        isEnabled = false
        state.isConnected = false
        networkDiscovery.stop()
        updateTask?.cancel()
        updateTask = nil
    }

    private func startBroadcasting() {
        Task {
            while isEnabled {
                networkDiscovery.broadcastPresence(
                    sessionId: sessionId,
                    deviceName: "Echoelmusic",
                    port: 20808
                )
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // Every 1 second
            }
        }
    }

    private func startUpdateLoop() {
        updateTask = Task {
            while !Task.isCancelled && isEnabled {
                await updateState()
                try? await Task.sleep(nanoseconds: 10_000_000)  // 100 Hz update
            }
        }
    }

    private func updateState() {
        let hostTime = mach_absolute_time()
        let beatTime = timeline.beatAtTime(hostTime)

        let oldPhase = state.phase
        state.beatTime = beatTime
        state.phase = beatTime.truncatingRemainder(dividingBy: state.quantum) / state.quantum

        // Detect phase wrap (new bar)
        if state.phase < oldPhase {
            onPhaseChanged?(state.phase)
        }
    }

    // MARK: - Tempo Control

    public func setTempo(_ tempo: Double) {
        state.tempo = max(20, min(999, tempo))
        timeline.setTempo(state.tempo)
        onTempoChanged?(state.tempo)
    }

    public func getTempo() -> Double {
        state.tempo
    }

    public func tapTempo() {
        // Would track tap intervals and calculate average tempo
        // Simplified: just increment by 1 BPM
        setTempo(state.tempo + 1)
    }

    // MARK: - Transport Control

    public func play() {
        state.isPlaying = true
        onPlayStateChanged?(true)
    }

    public func stop() {
        state.isPlaying = false
        onPlayStateChanged?(false)
    }

    public func toggle() {
        if state.isPlaying {
            stop()
        } else {
            play()
        }
    }

    /// Start playback quantized to next bar
    public func playQuantized() {
        let now = mach_absolute_time()
        let currentBeat = timeline.beatAtTime(now)
        let nextBar = ceil(currentBeat / state.quantum) * state.quantum

        // Schedule play at next bar
        let playTime = timeline.timeAtBeat(nextBar)
        let delayNanos = hostTimeToNanos(playTime - now)

        Task {
            try? await Task.sleep(nanoseconds: delayNanos)
            await play()
        }
    }

    private func hostTimeToNanos(_ hostTime: UInt64) -> UInt64 {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        return hostTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }

    // MARK: - Quantum (Phase Length)

    public func setQuantum(_ beats: Double) {
        state.quantum = max(1, min(16, beats))
    }

    public func getQuantum() -> Double {
        state.quantum
    }

    // MARK: - State Access

    public func getState() -> LinkSessionState {
        state
    }

    public func getBeatTime() -> Double {
        let hostTime = mach_absolute_time()
        return timeline.beatAtTime(hostTime)
    }

    public func getPhase() -> Double {
        state.phase
    }

    public func getPeerCount() -> Int {
        networkDiscovery.peers.count
    }

    public func getPeers() -> [LinkNetworkDiscovery.Peer] {
        networkDiscovery.peers
    }

    // MARK: - Setlist Access

    public func getSetlistManager() -> SetlistManager {
        setlistManager
    }

    // MARK: - Audio Sync Helpers

    /// Get sample offset to align with Link beat grid
    public func getSampleOffset(sampleRate: Double) -> Int {
        let now = mach_absolute_time()
        let currentBeat = timeline.beatAtTime(now)
        let fractionalBeat = currentBeat.truncatingRemainder(dividingBy: 1)

        // Samples until next beat
        let secondsToNextBeat = (1 - fractionalBeat) * (60.0 / state.tempo)
        return Int(secondsToNextBeat * sampleRate)
    }

    /// Check if we're at a beat boundary (within tolerance)
    public func isOnBeat(toleranceMs: Double = 10) -> Bool {
        let fractionalBeat = state.beatTime.truncatingRemainder(dividingBy: 1)
        let msIntoBeat = fractionalBeat * (60000.0 / state.tempo)
        return msIntoBeat < toleranceMs || msIntoBeat > (60000.0 / state.tempo) - toleranceMs
    }

    /// Check if we're at a bar boundary
    public func isOnBar(toleranceMs: Double = 10) -> Bool {
        let fractionalPhase = state.phase
        let msIntoBar = fractionalPhase * state.quantum * (60000.0 / state.tempo)
        let barDurationMs = state.quantum * (60000.0 / state.tempo)
        return msIntoBar < toleranceMs || msIntoBar > barDurationMs - toleranceMs
    }
}

// MARK: - Link Status View Model

/// Observable state for UI binding
@MainActor
public final class LinkStatusViewModel: ObservableObject {
    @Published public var tempo: Double = 120
    @Published public var beatTime: Double = 0
    @Published public var phase: Double = 0
    @Published public var isPlaying: Bool = false
    @Published public var peerCount: Int = 0
    @Published public var isConnected: Bool = false
    @Published public var currentBeat: Int = 1

    private var updateTask: Task<Void, Never>?

    public init() {}

    public func startUpdating() {
        updateTask = Task {
            while !Task.isCancelled {
                await updateFromEngine()
                try? await Task.sleep(nanoseconds: 50_000_000)  // 20 Hz UI update
            }
        }
    }

    public func stopUpdating() {
        updateTask?.cancel()
    }

    private func updateFromEngine() async {
        let state = await AbletonLinkEngine.shared.getState()

        tempo = state.tempo
        beatTime = state.beatTime
        phase = state.phase
        isPlaying = state.isPlaying
        peerCount = state.numPeers
        isConnected = state.isConnected
        currentBeat = state.currentBeat
    }
}
