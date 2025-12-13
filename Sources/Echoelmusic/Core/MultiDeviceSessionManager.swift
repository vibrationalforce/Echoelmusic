import Foundation
import Combine
import MultipeerConnectivity
#if canImport(Network)
import Network
#endif

// MARK: - Multi-Device Session Manager
/// Enables synchronized collaborative sessions across all devices
/// Works on: iOS, iPadOS, macOS, watchOS, tvOS, visionOS
/// Research: Network Time Protocol (Mills, 1991), Precision Time Protocol IEEE 1588

public class MultiDeviceSessionManager: NSObject, ObservableObject {

    // MARK: - Singleton
    public static let shared = MultiDeviceSessionManager()

    // MARK: - Published State
    @Published public var connectedDevices: [ConnectedDevice] = []
    @Published public var sessionState: SessionState = .idle
    @Published public var sharedBioData: SharedBioData = SharedBioData()
    @Published public var syncLatency: Double = 0.0  // milliseconds
    @Published public var isHost: Bool = false
    @Published public var currentSession: CollaborativeSession?

    // MARK: - Device Types
    public struct ConnectedDevice: Identifiable, Codable, Hashable {
        public let id: UUID
        public let name: String
        public let platform: DevicePlatform
        public let capabilities: DeviceCapabilities
        public var lastSeen: Date
        public var clockOffset: Int64  // nanoseconds
        public var latency: Double     // milliseconds

        public init(id: UUID = UUID(), name: String, platform: DevicePlatform,
                    capabilities: DeviceCapabilities = DeviceCapabilities()) {
            self.id = id
            self.name = name
            self.platform = platform
            self.capabilities = capabilities
            self.lastSeen = Date()
            self.clockOffset = 0
            self.latency = 0
        }
    }

    public enum DevicePlatform: String, Codable, CaseIterable {
        case iPhone = "iPhone"
        case iPad = "iPad"
        case mac = "Mac"
        case appleWatch = "Apple Watch"
        case appleTV = "Apple TV"
        case visionPro = "Vision Pro"
        case web = "Web Browser"
        case linux = "Linux"
        case windows = "Windows"
        case android = "Android"

        public var icon: String {
            switch self {
            case .iPhone: return "iphone"
            case .iPad: return "ipad"
            case .mac: return "laptopcomputer"
            case .appleWatch: return "applewatch"
            case .appleTV: return "appletv"
            case .visionPro: return "visionpro"
            case .web: return "globe"
            case .linux: return "server.rack"
            case .windows: return "pc"
            case .android: return "candybarphone"
            }
        }

        public var supportsAudio: Bool {
            switch self {
            case .appleWatch: return false  // Limited audio output
            default: return true
            }
        }

        public var supportsBioSensors: Bool {
            switch self {
            case .appleWatch, .visionPro: return true
            case .iPhone, .iPad: return true  // Via HealthKit
            default: return false
            }
        }
    }

    public struct DeviceCapabilities: Codable, Hashable {
        public var canProduceBio: Bool = false
        public var canReceiveBio: Bool = true
        public var canProduceAudio: Bool = true
        public var canReceiveAudio: Bool = true
        public var hasHaptics: Bool = false
        public var hasSpatialAudio: Bool = false
        public var maxChannels: Int = 2
        public var supportedLatencies: [Double] = [3.0, 5.0, 10.0]  // ms

        public init() {}
    }

    // MARK: - Session State
    public enum SessionState: String, Codable {
        case idle = "Idle"
        case discovering = "Discovering"
        case connecting = "Connecting"
        case connected = "Connected"
        case syncing = "Syncing"
        case streaming = "Streaming"
        case error = "Error"

        public var icon: String {
            switch self {
            case .idle: return "circle"
            case .discovering: return "antenna.radiowaves.left.and.right"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .connected: return "checkmark.circle"
            case .syncing: return "clock.arrow.2.circlepath"
            case .streaming: return "waveform"
            case .error: return "exclamationmark.triangle"
            }
        }
    }

    // MARK: - Shared Bio Data
    public struct SharedBioData: Codable {
        public var hrv: Double = 0.0
        public var heartRate: Double = 0.0
        public var coherence: Double = 0.0
        public var breathingRate: Double = 0.0
        public var stress: Double = 0.0
        public var energy: Double = 0.0
        public var timestamp: Date = Date()
        public var sourceDeviceId: UUID?

        public init() {}

        public mutating func update(hrv: Double, heartRate: Double, coherence: Double,
                                    breathingRate: Double, source: UUID?) {
            self.hrv = hrv
            self.heartRate = heartRate
            self.coherence = coherence
            self.breathingRate = breathingRate
            self.stress = calculateStress()
            self.energy = calculateEnergy()
            self.timestamp = Date()
            self.sourceDeviceId = source
        }

        private func calculateStress() -> Double {
            // Lower HRV = higher stress, lower coherence = higher stress
            let hrvStress = max(0, 1.0 - (hrv / 100.0))
            let coherenceStress = 1.0 - coherence
            return (hrvStress + coherenceStress) / 2.0
        }

        private func calculateEnergy() -> Double {
            // Heart rate relative to resting (60 bpm baseline)
            let hrEnergy = min(1.0, (heartRate - 50) / 100.0)
            return max(0, hrEnergy)
        }
    }

    // MARK: - Collaborative Session
    public struct CollaborativeSession: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var hostDeviceId: UUID
        public var participants: [UUID]
        public var startTime: Date
        public var sharedState: SharedSessionState
        public var syncPrecision: SyncPrecision

        public init(name: String, hostDeviceId: UUID, syncPrecision: SyncPrecision = .standard) {
            self.id = UUID()
            self.name = name
            self.hostDeviceId = hostDeviceId
            self.participants = [hostDeviceId]
            self.startTime = Date()
            self.sharedState = SharedSessionState()
            self.syncPrecision = syncPrecision
        }
    }

    public struct SharedSessionState: Codable {
        public var isPlaying: Bool = false
        public var bpm: Double = 120.0
        public var position: Double = 0.0  // beats
        public var masterVolume: Float = 0.8
        public var bioReactiveEnabled: Bool = true
        public var sharedPreset: String = "default"

        public init() {}
    }

    public enum SyncPrecision: String, Codable, CaseIterable {
        case relaxed = "Relaxed (~50ms)"        // Good for casual jam
        case standard = "Standard (~10ms)"      // Normal sync
        case tight = "Tight (~3ms)"             // Pro studio
        case quantum = "Quantum (<1ms)"         // Ultra precision

        public var targetLatency: Double {
            switch self {
            case .relaxed: return 50.0
            case .standard: return 10.0
            case .tight: return 3.0
            case .quantum: return 1.0
            }
        }
    }

    // MARK: - Message Types
    public enum MessageType: String, Codable {
        case ping
        case pong
        case clockSync
        case bioData
        case sessionState
        case transportControl
        case parameterChange
        case preset
        case chat
    }

    public struct SessionMessage: Codable {
        public let type: MessageType
        public let timestamp: Int64  // nanoseconds since reference
        public let senderId: UUID
        public let payload: Data

        public init(type: MessageType, senderId: UUID, payload: Data) {
            self.type = type
            self.timestamp = Self.currentNanoseconds()
            self.senderId = senderId
            self.payload = payload
        }

        private static func currentNanoseconds() -> Int64 {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            var timebase = mach_timebase_info_data_t()
            mach_timebase_info(&timebase)
            let machTime = mach_absolute_time()
            return Int64(machTime * UInt64(timebase.numer) / UInt64(timebase.denom))
            #else
            return Int64(Date().timeIntervalSince1970 * 1_000_000_000)
            #endif
        }
    }

    // MARK: - Private Properties
    private let serviceType = "echoelmusic"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var cancellables = Set<AnyCancellable>()
    private let localDeviceId = UUID()
    private var clockSyncTimer: Timer?
    private var bioSyncTimer: Timer?

    // Clock synchronization state
    private var clockOffsets: [UUID: [Int64]] = [:]  // Store multiple samples
    private let clockSyncSamples = 10

    // MARK: - Initialization
    private override init() {
        super.init()
        setupMultipeerConnectivity()
        setupTimers()
    }

    private func setupMultipeerConnectivity() {
        let deviceName = getDeviceName()
        peerID = MCPeerID(displayName: deviceName)

        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        // Discovery info with capabilities
        let discoveryInfo: [String: String] = [
            "deviceId": localDeviceId.uuidString,
            "platform": getCurrentPlatform().rawValue,
            "version": "1.0"
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: serviceType
        )
        browser.delegate = self
    }

    private func setupTimers() {
        // Clock sync every 5 seconds
        clockSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performClockSync()
        }

        // Bio data sync every 100ms for smooth updates
        bioSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.broadcastBioData()
        }
    }

    // MARK: - Public API

    /// Start discovering nearby devices
    public func startDiscovery() {
        sessionState = .discovering
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        print("🔍 Started device discovery")
    }

    /// Stop discovering
    public func stopDiscovery() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        if connectedDevices.isEmpty {
            sessionState = .idle
        }
        print("⏹️ Stopped device discovery")
    }

    /// Create a new collaborative session as host
    public func createSession(name: String, precision: SyncPrecision = .standard) {
        isHost = true
        currentSession = CollaborativeSession(
            name: name,
            hostDeviceId: localDeviceId,
            syncPrecision: precision
        )
        sessionState = .connected
        startDiscovery()
        print("🎵 Created session: \(name)")
    }

    /// Join an existing session
    public func joinSession(_ session: CollaborativeSession) {
        isHost = false
        currentSession = session
        sessionState = .syncing
        performClockSync()
        print("🤝 Joined session: \(session.name)")
    }

    /// Leave current session
    public func leaveSession() {
        session.disconnect()
        currentSession = nil
        connectedDevices.removeAll()
        sessionState = .idle
        isHost = false
        print("👋 Left session")
    }

    /// Send bio data to all connected devices
    public func shareBioData(_ data: SharedBioData) {
        var updatedData = data
        updatedData.sourceDeviceId = localDeviceId

        do {
            let payload = try JSONEncoder().encode(updatedData)
            let message = SessionMessage(type: .bioData, senderId: localDeviceId, payload: payload)
            let messageData = try JSONEncoder().encode(message)
            try session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Failed to share bio data: \(error)")
        }
    }

    /// Send transport control (play/stop/seek)
    public func sendTransportControl(isPlaying: Bool, position: Double, bpm: Double) {
        guard var session = currentSession else { return }

        session.sharedState.isPlaying = isPlaying
        session.sharedState.position = position
        session.sharedState.bpm = bpm
        currentSession = session

        do {
            let payload = try JSONEncoder().encode(session.sharedState)
            let message = SessionMessage(type: .transportControl, senderId: localDeviceId, payload: payload)
            let messageData = try JSONEncoder().encode(message)
            try self.session.send(messageData, toPeers: self.session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Failed to send transport: \(error)")
        }
    }

    /// Send parameter change to all devices
    public func sendParameterChange(parameterId: String, value: Float) {
        let change = ParameterChange(parameterId: parameterId, value: value)

        do {
            let payload = try JSONEncoder().encode(change)
            let message = SessionMessage(type: .parameterChange, senderId: localDeviceId, payload: payload)
            let messageData = try JSONEncoder().encode(message)
            try session.send(messageData, toPeers: session.connectedPeers, with: .unreliable)
        } catch {
            print("❌ Failed to send parameter: \(error)")
        }
    }

    // MARK: - Clock Synchronization

    private func performClockSync() {
        guard !session.connectedPeers.isEmpty else { return }

        // Send ping to all peers
        do {
            let pingData = PingMessage(sendTime: currentNanoseconds())
            let payload = try JSONEncoder().encode(pingData)
            let message = SessionMessage(type: .ping, senderId: localDeviceId, payload: payload)
            let messageData = try JSONEncoder().encode(message)
            try session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Clock sync failed: \(error)")
        }
    }

    private func handlePing(_ message: SessionMessage, from peer: MCPeerID) {
        // Respond with pong immediately
        do {
            let pongData = PongMessage(
                originalSendTime: message.timestamp,
                receiveTime: currentNanoseconds()
            )
            let payload = try JSONEncoder().encode(pongData)
            let response = SessionMessage(type: .pong, senderId: localDeviceId, payload: payload)
            let responseData = try JSONEncoder().encode(response)
            try session.send(responseData, toPeers: [peer], with: .reliable)
        } catch {
            print("❌ Pong failed: \(error)")
        }
    }

    private func handlePong(_ message: SessionMessage, from peer: MCPeerID) {
        guard let pongData = try? JSONDecoder().decode(PongMessage.self, from: message.payload) else {
            return
        }

        let now = currentNanoseconds()
        let roundTrip = now - pongData.originalSendTime
        let latencyNs = roundTrip / 2

        // Calculate clock offset
        let offset = message.timestamp - (pongData.originalSendTime + latencyNs)

        // Store samples for averaging
        if clockOffsets[message.senderId] == nil {
            clockOffsets[message.senderId] = []
        }
        clockOffsets[message.senderId]?.append(offset)

        // Keep only last N samples
        if (clockOffsets[message.senderId]?.count ?? 0) > clockSyncSamples {
            clockOffsets[message.senderId]?.removeFirst()
        }

        // Update device info with averaged offset
        if let samples = clockOffsets[message.senderId], !samples.isEmpty {
            let avgOffset = samples.reduce(0, +) / Int64(samples.count)
            let latencyMs = Double(latencyNs) / 1_000_000.0

            DispatchQueue.main.async {
                if let index = self.connectedDevices.firstIndex(where: { $0.id == message.senderId }) {
                    self.connectedDevices[index].clockOffset = avgOffset
                    self.connectedDevices[index].latency = latencyMs
                    self.connectedDevices[index].lastSeen = Date()
                }
                self.syncLatency = latencyMs
            }
        }
    }

    private func broadcastBioData() {
        guard !session.connectedPeers.isEmpty else { return }
        shareBioData(sharedBioData)
    }

    // MARK: - Helper Types

    private struct PingMessage: Codable {
        let sendTime: Int64
    }

    private struct PongMessage: Codable {
        let originalSendTime: Int64
        let receiveTime: Int64
    }

    private struct ParameterChange: Codable {
        let parameterId: String
        let value: Float
    }

    // MARK: - Utilities

    private func currentNanoseconds() -> Int64 {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let machTime = mach_absolute_time()
        return Int64(machTime * UInt64(timebase.numer) / UInt64(timebase.denom))
        #else
        return Int64(Date().timeIntervalSince1970 * 1_000_000_000)
        #endif
    }

    private func getDeviceName() -> String {
        #if os(iOS) || os(tvOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #else
        return "Echoelmusic Device"
        #endif
    }

    private func getCurrentPlatform() -> DevicePlatform {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }
        return .iPhone
        #elseif os(macOS)
        return .mac
        #elseif os(watchOS)
        return .appleWatch
        #elseif os(tvOS)
        return .appleTV
        #elseif os(visionOS)
        return .visionPro
        #else
        return .linux
        #endif
    }

    private func makeDeviceCapabilities() -> DeviceCapabilities {
        var caps = DeviceCapabilities()
        let platform = getCurrentPlatform()

        caps.canProduceBio = platform.supportsBioSensors
        caps.canProduceAudio = platform.supportsAudio
        caps.hasHaptics = [.iPhone, .appleWatch, .visionPro].contains(platform)
        caps.hasSpatialAudio = [.iPhone, .iPad, .mac, .appleTV, .visionPro].contains(platform)

        switch platform {
        case .visionPro:
            caps.maxChannels = 24  // Full spatial
        case .mac:
            caps.maxChannels = 128 // Pro audio interface
        case .iPad, .iPhone:
            caps.maxChannels = 8
        default:
            caps.maxChannels = 2
        }

        return caps
    }
}

// MARK: - MCSessionDelegate

extension MultiDeviceSessionManager: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("✅ Connected to: \(peerID.displayName)")
                self.sessionState = .connected
                // Request device info
                self.requestDeviceInfo(from: peerID)

            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
                self.sessionState = .connecting

            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                // Remove from connected devices
                self.connectedDevices.removeAll { device in
                    device.name == peerID.displayName
                }
                if self.connectedDevices.isEmpty && self.currentSession == nil {
                    self.sessionState = .idle
                }

            @unknown default:
                break
            }
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SessionMessage.self, from: data) else {
            return
        }

        switch message.type {
        case .ping:
            handlePing(message, from: peerID)

        case .pong:
            handlePong(message, from: peerID)

        case .bioData:
            if let bioData = try? JSONDecoder().decode(SharedBioData.self, from: message.payload) {
                DispatchQueue.main.async {
                    self.sharedBioData = bioData
                }
            }

        case .sessionState:
            if let state = try? JSONDecoder().decode(SharedSessionState.self, from: message.payload) {
                DispatchQueue.main.async {
                    self.currentSession?.sharedState = state
                }
            }

        case .transportControl:
            if let state = try? JSONDecoder().decode(SharedSessionState.self, from: message.payload) {
                DispatchQueue.main.async {
                    self.currentSession?.sharedState = state
                    // Notify audio engine of transport change
                    NotificationCenter.default.post(
                        name: .multiDeviceTransportChanged,
                        object: nil,
                        userInfo: ["state": state]
                    )
                }
            }

        case .parameterChange:
            if let change = try? JSONDecoder().decode(ParameterChange.self, from: message.payload) {
                NotificationCenter.default.post(
                    name: .multiDeviceParameterChanged,
                    object: nil,
                    userInfo: ["change": change]
                )
            }

        case .clockSync, .preset, .chat:
            break  // Handle as needed
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle audio streams if needed
    }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }

    private func requestDeviceInfo(from peer: MCPeerID) {
        // Add device with basic info, will be updated with full capabilities
        let device = ConnectedDevice(
            name: peer.displayName,
            platform: .iPhone,  // Will be updated
            capabilities: DeviceCapabilities()
        )

        DispatchQueue.main.async {
            if !self.connectedDevices.contains(where: { $0.name == peer.displayName }) {
                self.connectedDevices.append(device)
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultiDeviceSessionManager: MCNearbyServiceAdvertiserDelegate {

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations (could add UI prompt)
        print("📨 Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Advertising failed: \(error)")
        DispatchQueue.main.async {
            self.sessionState = .error
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultiDeviceSessionManager: MCNearbyServiceBrowserDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("🔍 Found peer: \(peerID.displayName)")

        // Auto-invite to session
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("👋 Lost peer: \(peerID.displayName)")
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Browsing failed: \(error)")
        DispatchQueue.main.async {
            self.sessionState = .error
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let multiDeviceTransportChanged = Notification.Name("multiDeviceTransportChanged")
    static let multiDeviceParameterChanged = Notification.Name("multiDeviceParameterChanged")
    static let multiDeviceBioDataReceived = Notification.Name("multiDeviceBioDataReceived")
}

// MARK: - Multi-Device Session View

// MARK: - QuantumUltraCore Integration

extension MultiDeviceSessionManager {

    /// Synchronize with QuantumUltraCore for ultra-precision timing
    public func enableQuantumSync() {
        Task { @MainActor in
            let quantumCore = QuantumUltraCore.shared

            // Use quantum precision for clock sync
            let quantumSync = quantumCore.quantumSync

            // Configure session based on platform capabilities
            let platform = quantumCore.platformBridge
            if platform.capabilities.minLatencyMs < 3.0 {
                currentSession?.syncPrecision = .quantum
            } else if platform.capabilities.minLatencyMs < 10.0 {
                currentSession?.syncPrecision = .tight
            }

            // Apply optimal buffer configuration
            let latencyEngine = quantumCore.latencyEngine
            print("⚛️ Quantum sync enabled: \(latencyEngine.currentLatency)ms latency")
        }
    }

    /// Synchronize device clock using QuantumSyncEngine
    public func quantumSyncDevice(_ device: ConnectedDevice) {
        Task { @MainActor in
            let quantumCore = QuantumUltraCore.shared
            let deviceSync = QuantumSyncEngine.DeviceSync(
                deviceId: device.id.uuidString,
                clockOffset: device.clockOffset,
                jitter: device.latency * 1_000_000,  // Convert ms to ns
                isLocked: device.latency < 10.0
            )
            quantumCore.quantumSync.synchronizeDevice(deviceSync)
        }
    }

    /// Get synchronized timestamp compensated for device clock offset
    public func getSynchronizedTimestamp(for deviceId: UUID) -> Int64 {
        let baseTime = currentNanoseconds()

        if let device = connectedDevices.first(where: { $0.id == deviceId }) {
            return baseTime - device.clockOffset
        }

        return baseTime
    }

    /// Configure session for optimal platform performance
    public func optimizeForPlatform() {
        Task { @MainActor in
            let quantumCore = QuantumUltraCore.shared
            let platform = quantumCore.platformBridge.currentPlatform

            switch platform {
            case .iOS, .iPadOS:
                // Mobile: Balance latency and battery
                currentSession?.syncPrecision = .standard
            case .macOS:
                // Desktop: Maximum precision
                currentSession?.syncPrecision = .quantum
            case .watchOS:
                // Wearable: Bio-data focus, relaxed sync
                currentSession?.syncPrecision = .relaxed
            case .visionOS:
                // Spatial: Tight sync for immersion
                currentSession?.syncPrecision = .tight
            default:
                currentSession?.syncPrecision = .standard
            }

            print("🎯 Optimized for \(platform.rawValue): \(currentSession?.syncPrecision.rawValue ?? "standard")")
        }
    }

    /// Enable immersive mode with haptic feedback
    public func enableImmersiveSync() {
        Task { @MainActor in
            let immersiveCore = QuantumUltraCore.shared.immersiveCore

            // Configure spatial mode
            immersiveCore.spatialMode = .binaural

            // Enable haptic feedback on supported devices
            #if os(iOS) || os(watchOS)
            immersiveCore.hapticIntensity = 0.7
            #endif

            print("🌟 Immersive sync enabled: \(immersiveCore.spatialMode.rawValue)")
        }
    }
}

// MARK: - Bio-Reactive Multi-Device Sync

extension MultiDeviceSessionManager {

    /// Broadcast bio-reactive parameters to all devices
    public func broadcastBioReactiveState(hrv: Double, coherence: Double, heartRate: Double, breathingRate: Double) {
        var bioData = SharedBioData()
        bioData.update(hrv: hrv, heartRate: heartRate, coherence: coherence,
                       breathingRate: breathingRate, source: localDeviceId)
        sharedBioData = bioData
        shareBioData(bioData)
    }

    /// Get aggregated bio data from all connected bio-capable devices
    public func getAggregatedBioData() -> SharedBioData {
        // For now, return the shared bio data (could aggregate from multiple sources)
        return sharedBioData
    }

    /// Check if any connected device has bio sensors
    public var hasBioCapableDevice: Bool {
        return connectedDevices.contains { $0.capabilities.canProduceBio }
    }
}

// MARK: - Session State Persistence

extension MultiDeviceSessionManager {

    /// Save session state to UserDefaults for quick reconnection
    public func persistSessionState() {
        guard let session = currentSession else { return }

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(session) {
            UserDefaults.standard.set(data, forKey: "lastSession")
        }
    }

    /// Restore last session if available
    public func restoreLastSession() -> CollaborativeSession? {
        guard let data = UserDefaults.standard.data(forKey: "lastSession"),
              let session = try? JSONDecoder().decode(CollaborativeSession.self, from: data) else {
            return nil
        }
        return session
    }

    /// Clear persisted session
    public func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: "lastSession")
    }
}

#if canImport(SwiftUI)
import SwiftUI

public struct MultiDeviceSessionView: View {
    @StateObject private var sessionManager = MultiDeviceSessionManager.shared
    @State private var sessionName = "Echoelmusic Session"
    @State private var showCreateSession = false

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                // Session Status
                Section("Session Status") {
                    HStack {
                        Image(systemName: sessionManager.sessionState.icon)
                            .foregroundColor(sessionManager.sessionState == .connected ? .green : .orange)
                        Text(sessionManager.sessionState.rawValue)
                        Spacer()
                        if sessionManager.isHost {
                            Text("HOST")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    if sessionManager.syncLatency > 0 {
                        HStack {
                            Image(systemName: "clock")
                            Text("Sync Latency")
                            Spacer()
                            Text(String(format: "%.1f ms", sessionManager.syncLatency))
                                .foregroundColor(sessionManager.syncLatency < 10 ? .green : .orange)
                        }
                    }
                }

                // Connected Devices
                Section("Connected Devices (\(sessionManager.connectedDevices.count))") {
                    if sessionManager.connectedDevices.isEmpty {
                        Text("No devices connected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sessionManager.connectedDevices) { device in
                            DeviceRow(device: device)
                        }
                    }
                }

                // Shared Bio Data
                if sessionManager.sessionState == .connected || sessionManager.sessionState == .streaming {
                    Section("Shared Bio Data") {
                        BioDataRow(label: "Heart Rate", value: sessionManager.sharedBioData.heartRate, unit: "BPM", icon: "heart.fill")
                        BioDataRow(label: "HRV", value: sessionManager.sharedBioData.hrv, unit: "ms", icon: "waveform.path.ecg")
                        BioDataRow(label: "Coherence", value: sessionManager.sharedBioData.coherence * 100, unit: "%", icon: "brain.head.profile")
                        BioDataRow(label: "Breathing", value: sessionManager.sharedBioData.breathingRate, unit: "/min", icon: "lungs.fill")
                    }
                }

                // Actions
                Section("Actions") {
                    if sessionManager.currentSession == nil {
                        Button(action: { showCreateSession = true }) {
                            Label("Create Session", systemImage: "plus.circle")
                        }

                        Button(action: { sessionManager.startDiscovery() }) {
                            Label("Find Sessions", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    } else {
                        Button(action: { sessionManager.leaveSession() }) {
                            Label("Leave Session", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Multi-Device Session")
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet(sessionName: $sessionName) { name, precision in
                    sessionManager.createSession(name: name, precision: precision)
                    showCreateSession = false
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: MultiDeviceSessionManager.ConnectedDevice

    var body: some View {
        HStack {
            Image(systemName: device.platform.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                Text(device.platform.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(String(format: "%.1f ms", device.latency))
                    .font(.caption)
                    .foregroundColor(device.latency < 10 ? .green : .orange)

                HStack(spacing: 4) {
                    if device.capabilities.canProduceBio {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    if device.capabilities.hasSpatialAudio {
                        Image(systemName: "hifispeaker.2")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct BioDataRow: View {
    let label: String
    let value: Double
    let unit: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.red)
            Text(label)
            Spacer()
            Text(String(format: "%.1f %@", value, unit))
                .foregroundColor(.secondary)
        }
    }
}

struct CreateSessionSheet: View {
    @Binding var sessionName: String
    @State private var precision: MultiDeviceSessionManager.SyncPrecision = .standard
    let onCreate: (String, MultiDeviceSessionManager.SyncPrecision) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Session Name") {
                    TextField("Enter name", text: $sessionName)
                }

                Section("Sync Precision") {
                    Picker("Precision", selection: $precision) {
                        ForEach(MultiDeviceSessionManager.SyncPrecision.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Target latency: \(String(format: "%.0f ms", precision.targetLatency))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Create Session") {
                        onCreate(sessionName, precision)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MultiDeviceSessionView()
}
#endif
