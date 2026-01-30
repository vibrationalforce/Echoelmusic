import Foundation
import Combine
import Network

/// Logger alias for CrossPlatformSessionManager
private let log = echoelLog

// MARK: - Cross-Platform Session Manager
// Phase 10000 ULTIMATE - ANY Device Combination Works Together
// Nobel Prize Multitrillion Dollar Company - Ralph Wiggum Lambda Loop
//
// Philosophy: Adaptive Zero-Latency + High Quality
// ALL combinations are possible:
// - iPhone + Windows PC
// - Android tablet + iMac
// - MacBook Air + Android smartphone + Meta glasses
// - Apple Vision Pro + Chromebook
// - Tesla + Apple Watch + Android tablet
// - ANY combination you can imagine!

/// Universal cross-platform session manager for seamless device collaboration
/// Supports ALL device ecosystem combinations with adaptive zero-latency sync
@MainActor
public final class CrossPlatformSessionManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = CrossPlatformSessionManager()

    // MARK: - Published State

    @Published public var activeSession: CrossPlatformSession?
    @Published public var discoveredDevices: [DiscoveredDevice] = []
    @Published public var connectionQuality: ConnectionQuality = .excellent
    @Published public var syncStatus: SessionSyncStatus = .idle

    // MARK: - Network Discovery

    private var browser: NWBrowser?
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]

    // MARK: - Sync Configuration

    private let serviceName = "_echoelmusic._tcp"
    private let syncPort: UInt16 = 41234

    // MARK: - Initialization

    private init() {
        setupNetworkDiscovery()
    }

    // MARK: - Network Setup

    private func setupNetworkDiscovery() {
        // Setup Bonjour/mDNS browser for device discovery
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceName, domain: nil), using: parameters)
        browser?.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                Task { @MainActor in
                    self?.syncStatus = .discovering
                }
            }
        }
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleDiscoveryResults(results)
            }
        }
    }

    private func handleDiscoveryResults(_ results: Set<NWBrowser.Result>) {
        // Convert browser results to discovered devices
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                let device = DiscoveredDevice(
                    id: UUID().uuidString,
                    name: name,
                    endpoint: result.endpoint,
                    platform: detectPlatform(from: name)
                )
                if !discoveredDevices.contains(where: { $0.name == name }) {
                    discoveredDevices.append(device)
                }
            }
        }
    }

    private func detectPlatform(from name: String) -> SessionDevicePlatform {
        let lowercased = name.lowercased()
        if lowercased.contains("iphone") { return .iOS }
        if lowercased.contains("ipad") { return .iPadOS }
        if lowercased.contains("mac") { return .macOS }
        if lowercased.contains("watch") { return .watchOS }
        if lowercased.contains("vision") { return .visionOS }
        if lowercased.contains("android") { return .android }
        if lowercased.contains("pixel") { return .android }
        if lowercased.contains("galaxy") { return .android }
        if lowercased.contains("windows") { return .windows }
        if lowercased.contains("linux") { return .linux }
        if lowercased.contains("chrome") { return .chromeOS }
        if lowercased.contains("quest") { return .questOS }
        if lowercased.contains("tesla") { return .teslaOS }
        return .custom
    }

    // MARK: - Session Management

    /// Start discovering devices on the network
    public func startDiscovery() {
        browser?.start(queue: .main)
        syncStatus = .discovering
    }

    /// Stop discovering devices
    public func stopDiscovery() {
        browser?.cancel()
        syncStatus = .idle
    }

    /// Create a new cross-platform session with any device combination
    public func createSession(
        name: String,
        devices: [SessionDevice],
        syncMode: SyncMode = .adaptive
    ) -> CrossPlatformSession {
        let session = CrossPlatformSession(
            id: UUID().uuidString,
            name: name,
            devices: devices,
            syncMode: syncMode,
            latencyCompensation: LatencyCompensation()
        )
        activeSession = session
        syncStatus = .connected

        // Start sync with all devices
        for device in devices {
            connectToDevice(device)
        }

        return session
    }

    /// Join an existing session
    public func joinSession(sessionId: String, as device: SessionDevice) async throws {
        // Connect to session host
        syncStatus = .connecting
        // Implementation would connect via the sync protocol
        syncStatus = .connected
    }

    /// Leave current session
    public func leaveSession() {
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        activeSession = nil
        syncStatus = .idle
    }

    // MARK: - Device Connection

    private func connectToDevice(_ device: SessionDevice) {
        guard let endpoint = device.networkEndpoint else { return }

        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state, for: device.id)
            }
        }
        connection.start(queue: .main)
        connections[device.id] = connection
    }

    private func handleConnectionState(_ state: NWConnection.State, for deviceId: String) {
        switch state {
        case .ready:
            updateDeviceStatus(deviceId, status: .connected)
        case .failed:
            updateDeviceStatus(deviceId, status: .disconnected)
        case .waiting:
            updateDeviceStatus(deviceId, status: .connecting)
        default:
            break
        }
    }

    private func updateDeviceStatus(_ deviceId: String, status: DeviceConnectionStatus) {
        if let index = activeSession?.devices.firstIndex(where: { $0.id == deviceId }) {
            activeSession?.devices[index].connectionStatus = status
        }
    }

    // MARK: - Data Sync

    /// Sync biometric data across all devices
    public func syncBiometricData(_ data: BiometricSyncData) {
        guard let session = activeSession else { return }

        let packet = SyncPacket(
            type: .biometric,
            timestamp: Date().timeIntervalSince1970,
            data: encodeBiometricData(data),
            latencyCompensation: session.latencyCompensation.currentOffset
        )

        broadcast(packet)
    }

    /// Sync audio parameters across all devices
    public func syncAudioParameters(_ params: AudioSyncParameters) {
        guard let session = activeSession else { return }

        let packet = SyncPacket(
            type: .audio,
            timestamp: Date().timeIntervalSince1970,
            data: encodeAudioParams(params),
            latencyCompensation: session.latencyCompensation.currentOffset
        )

        broadcast(packet)
    }

    /// Sync visual parameters across all devices
    public func syncVisualParameters(_ params: VisualSyncParameters) {
        guard let session = activeSession else { return }

        let packet = SyncPacket(
            type: .visual,
            timestamp: Date().timeIntervalSince1970,
            data: encodeVisualParams(params),
            latencyCompensation: session.latencyCompensation.currentOffset
        )

        broadcast(packet)
    }

    /// Sync lighting/DMX data across all devices
    public func syncLightingData(_ data: LightingSyncData) {
        guard let session = activeSession else { return }

        let packet = SyncPacket(
            type: .lighting,
            timestamp: Date().timeIntervalSince1970,
            data: encodeLightingData(data),
            latencyCompensation: session.latencyCompensation.currentOffset
        )

        broadcast(packet)
    }

    private func broadcast(_ packet: SyncPacket) {
        let data: Data
        do {
            data = try JSONEncoder().encode(packet)
        } catch {
            log.hardware("Failed to encode sync packet: \(error.localizedDescription)", level: .error)
            return
        }

        for (_, connection) in connections {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    // MARK: - Encoding Helpers

    private func encodeBiometricData(_ data: BiometricSyncData) -> Data {
        do {
            return try JSONEncoder().encode(data)
        } catch {
            log.hardware("Failed to encode biometric data: \(error.localizedDescription)", level: .warning)
            return Data()
        }
    }

    private func encodeAudioParams(_ params: AudioSyncParameters) -> Data {
        do {
            return try JSONEncoder().encode(params)
        } catch {
            log.hardware("Failed to encode audio params: \(error.localizedDescription)", level: .warning)
            return Data()
        }
    }

    private func encodeVisualParams(_ params: VisualSyncParameters) -> Data {
        do {
            return try JSONEncoder().encode(params)
        } catch {
            log.hardware("Failed to encode visual params: \(error.localizedDescription)", level: .warning)
            return Data()
        }
    }

    private func encodeLightingData(_ data: LightingSyncData) -> Data {
        do {
            return try JSONEncoder().encode(data)
        } catch {
            log.hardware("Failed to encode lighting data: \(error.localizedDescription)", level: .warning)
            return Data()
        }
    }
}

// MARK: - Cross-Platform Session

public struct CrossPlatformSession: Identifiable {
    public let id: String
    public let name: String
    public var devices: [SessionDevice]
    public var syncMode: SyncMode
    public var latencyCompensation: LatencyCompensation
    public let createdAt: Date = Date()

    /// Check if this is a cross-ecosystem session (Apple + Android, etc.)
    public var isCrossEcosystem: Bool {
        let ecosystems = Set(devices.map { $0.ecosystem })
        return ecosystems.count > 1
    }

    /// Get all unique ecosystems in this session
    public var ecosystems: Set<DeviceEcosystem> {
        Set(devices.map { $0.ecosystem })
    }
}

// MARK: - Session Device

public struct SessionDevice: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: DeviceType
    public let platform: SessionDevicePlatform
    public let ecosystem: DeviceEcosystem
    public var role: DeviceRole
    public var capabilities: Set<DeviceCapability>
    public var connectionStatus: DeviceConnectionStatus = .disconnected
    public var latencyMs: Double = 0
    public var networkEndpoint: NWEndpoint?

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: DeviceType,
        platform: SessionDevicePlatform,
        role: DeviceRole = .participant,
        capabilities: Set<DeviceCapability> = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.platform = platform
        self.ecosystem = DeviceEcosystem.from(platform: platform)
        self.role = role
        self.capabilities = capabilities
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SessionDevice, rhs: SessionDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Device Ecosystem

public enum DeviceEcosystem: String, CaseIterable {
    case apple = "Apple"
    case google = "Google"
    case microsoft = "Microsoft"
    case meta = "Meta"
    case linux = "Linux"
    case tesla = "Tesla"
    case other = "Other"

    public static func from(platform: SessionDevicePlatform) -> DeviceEcosystem {
        switch platform {
        case .iOS, .iPadOS, .macOS, .watchOS, .tvOS, .visionOS, .carPlay:
            return .apple
        case .android, .wearOS, .androidTV, .androidAuto, .chromeOS:
            return .google
        case .windows:
            return .microsoft
        case .questOS:
            return .meta
        case .linux:
            return .linux
        case .teslaOS:
            return .tesla
        default:
            return .other
        }
    }
}

// MARK: - Device Platform (Extended)

public enum SessionDevicePlatform: String, CaseIterable {
    // Apple
    case iOS = "iOS"
    case iPadOS = "iPadOS"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"
    case carPlay = "CarPlay"

    // Google
    case android = "Android"
    case wearOS = "Wear OS"
    case androidTV = "Android TV"
    case androidAuto = "Android Auto"
    case chromeOS = "Chrome OS"

    // Microsoft
    case windows = "Windows"

    // Meta
    case questOS = "Quest OS"

    // Linux
    case linux = "Linux"

    // Tesla
    case teslaOS = "Tesla OS"

    // Other
    case custom = "Custom"
}

// MARK: - Device Role

public enum DeviceRole: String, CaseIterable {
    case host = "Host"              // Controls the session
    case participant = "Participant" // Standard participant
    case bioSource = "Bio Source"    // Provides biometric data (watch, ring)
    case audioSource = "Audio Source" // Provides audio (interface, mic)
    case visualOutput = "Visual Output" // Displays visuals (TV, projector)
    case lightingControl = "Lighting Control" // Controls lights
    case midiControl = "MIDI Control" // MIDI controller
    case observer = "Observer"       // View only
}

// MARK: - Device Connection Status

public enum DeviceConnectionStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case syncing = "Syncing"
    case error = "Error"
}

// MARK: - Sync Mode

public enum SyncMode: String, CaseIterable {
    case adaptive = "Adaptive"       // Auto-adjusts based on network conditions
    case lowLatency = "Low Latency"  // Prioritize latency over quality
    case highQuality = "High Quality" // Prioritize quality over latency
    case balanced = "Balanced"       // Balance between latency and quality
    case masterSlave = "Master/Slave" // One device controls timing
    case peer = "Peer-to-Peer"       // All devices equal
}

// MARK: - Connection Quality

public enum ConnectionQuality: String {
    case excellent = "Excellent"  // < 10ms latency
    case good = "Good"           // 10-50ms latency
    case fair = "Fair"           // 50-100ms latency
    case poor = "Poor"           // > 100ms latency
}

// MARK: - Sync Status

public enum SessionSyncStatus: String {
    case idle = "Idle"
    case discovering = "Discovering"
    case connecting = "Connecting"
    case connected = "Connected"
    case syncing = "Syncing"
    case error = "Error"
}

// MARK: - Latency Compensation

public struct LatencyCompensation {
    public var enabled: Bool = true
    public var currentOffset: Double = 0  // milliseconds
    public var measurements: [Double] = []
    public var algorithm: LatencyAlgorithm = .adaptive

    public enum LatencyAlgorithm: String, CaseIterable {
        case none = "None"
        case fixed = "Fixed Offset"
        case adaptive = "Adaptive"
        case predictive = "Predictive"
    }

    /// Calculate optimal latency offset based on measurements
    public mutating func calculateOffset() -> Double {
        guard measurements.count >= 3 else { return 0 }

        switch algorithm {
        case .none:
            return 0
        case .fixed:
            return currentOffset
        case .adaptive:
            // Use median of recent measurements
            let sorted = measurements.suffix(10).sorted()
            return sorted[sorted.count / 2]
        case .predictive:
            // Use exponential moving average with prediction
            let alpha = 0.3
            var ema = measurements[0]
            for measurement in measurements.dropFirst() {
                ema = alpha * measurement + (1 - alpha) * ema
            }
            return ema
        }
    }

    /// Add a new latency measurement
    public mutating func addMeasurement(_ latency: Double) {
        measurements.append(latency)
        if measurements.count > 100 {
            measurements.removeFirst()
        }
        currentOffset = calculateOffset()
    }
}

// MARK: - Sync Packet

public struct SyncPacket: Codable {
    public let type: SyncPacketType
    public let timestamp: Double
    public let data: Data
    public let latencyCompensation: Double

    public enum SyncPacketType: String, Codable {
        case biometric = "biometric"
        case audio = "audio"
        case visual = "visual"
        case lighting = "lighting"
        case midi = "midi"
        case control = "control"
        case heartbeat = "heartbeat"
    }
}

// MARK: - Sync Data Types

public struct BiometricSyncData: Codable {
    public var heartRate: Double?
    public var hrv: Double?
    public var coherence: Double?
    public var breathingRate: Double?
    public var bloodOxygen: Double?
    public var temperature: Double?
    public var steps: Int?
    public var sourceDeviceId: String

    public init(
        heartRate: Double? = nil,
        hrv: Double? = nil,
        coherence: Double? = nil,
        breathingRate: Double? = nil,
        bloodOxygen: Double? = nil,
        temperature: Double? = nil,
        steps: Int? = nil,
        sourceDeviceId: String
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.coherence = coherence
        self.breathingRate = breathingRate
        self.bloodOxygen = bloodOxygen
        self.temperature = temperature
        self.steps = steps
        self.sourceDeviceId = sourceDeviceId
    }
}

public struct AudioSyncParameters: Codable {
    public var bpm: Double
    public var volume: Float
    public var pan: Float
    public var reverbMix: Float
    public var delayMix: Float
    public var filterCutoff: Float
    public var isPlaying: Bool
    public var currentBeat: Double
    public var sourceDeviceId: String

    public init(
        bpm: Double = 120,
        volume: Float = 1.0,
        pan: Float = 0,
        reverbMix: Float = 0,
        delayMix: Float = 0,
        filterCutoff: Float = 1.0,
        isPlaying: Bool = false,
        currentBeat: Double = 0,
        sourceDeviceId: String
    ) {
        self.bpm = bpm
        self.volume = volume
        self.pan = pan
        self.reverbMix = reverbMix
        self.delayMix = delayMix
        self.filterCutoff = filterCutoff
        self.isPlaying = isPlaying
        self.currentBeat = currentBeat
        self.sourceDeviceId = sourceDeviceId
    }
}

public struct VisualSyncParameters: Codable {
    public var mode: String
    public var intensity: Float
    public var colorHue: Float
    public var speed: Float
    public var complexity: Float
    public var bioReactivity: Float
    public var sourceDeviceId: String

    public init(
        mode: String = "default",
        intensity: Float = 1.0,
        colorHue: Float = 0.5,
        speed: Float = 1.0,
        complexity: Float = 0.5,
        bioReactivity: Float = 1.0,
        sourceDeviceId: String
    ) {
        self.mode = mode
        self.intensity = intensity
        self.colorHue = colorHue
        self.speed = speed
        self.complexity = complexity
        self.bioReactivity = bioReactivity
        self.sourceDeviceId = sourceDeviceId
    }
}

public struct LightingSyncData: Codable {
    public var dmxUniverse: Int
    public var channels: [Int: UInt8]  // channel -> value
    public var fixtures: [FixtureState]
    public var scene: String?
    public var sourceDeviceId: String

    public struct FixtureState: Codable {
        public var fixtureId: String
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8
        public var white: UInt8?
        public var dimmer: UInt8
        public var pan: UInt16?
        public var tilt: UInt16?
    }

    public init(
        dmxUniverse: Int = 0,
        channels: [Int: UInt8] = [:],
        fixtures: [FixtureState] = [],
        scene: String? = nil,
        sourceDeviceId: String
    ) {
        self.dmxUniverse = dmxUniverse
        self.channels = channels
        self.fixtures = fixtures
        self.scene = scene
        self.sourceDeviceId = sourceDeviceId
    }
}

// MARK: - Discovered Device

public struct DiscoveredDevice: Identifiable {
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint
    public let platform: SessionDevicePlatform
    public var lastSeen: Date = Date()
}

// MARK: - Cross-Platform Sync Protocol

/// Universal sync protocol that works across all ecosystems
public struct CrossPlatformSyncProtocol {

    // MARK: - Protocol Layers

    /// Layer 1: Discovery (Bonjour/mDNS, UDP broadcast)
    public enum DiscoveryMethod: String, CaseIterable {
        case bonjour = "Bonjour/mDNS"      // Apple, Linux
        case upnp = "UPnP/SSDP"            // Universal
        case broadcast = "UDP Broadcast"    // Universal
        case bluetooth = "Bluetooth LE"     // Mobile
        case manual = "Manual IP"           // Fallback
    }

    /// Layer 2: Transport (TCP, UDP, WebSocket)
    public enum TransportProtocol: String, CaseIterable {
        case tcp = "TCP"                    // Reliable
        case udp = "UDP"                    // Low latency
        case webSocket = "WebSocket"        // Web compatible
        case webRTC = "WebRTC"              // P2P, NAT traversal
        case quic = "QUIC"                  // Modern, multiplexed
    }

    /// Layer 3: Sync (Clock, Data, State)
    public enum SyncProtocol: String, CaseIterable {
        case ntp = "NTP"                    // Time sync
        case ptp = "PTP/IEEE 1588"          // Precision time
        case custom = "Echoelmusic Sync"    // Our protocol
        case abletonLink = "Ableton Link"   // Audio sync
        case midi = "MIDI Clock"            // MIDI sync
    }

    // MARK: - Protocol Selection

    /// Select best protocol based on device combination
    public static func selectProtocols(for devices: [SessionDevice]) -> ProtocolStack {
        let ecosystems = Set(devices.map { $0.ecosystem })

        // Cross-ecosystem: use universal protocols
        if ecosystems.count > 1 {
            return ProtocolStack(
                discovery: .broadcast,
                transport: .webSocket,  // Works everywhere
                sync: .custom
            )
        }

        // Apple-only: use optimized Apple protocols
        if ecosystems == [.apple] {
            return ProtocolStack(
                discovery: .bonjour,
                transport: .tcp,
                sync: .custom
            )
        }

        // Google-only: use Android-optimized
        if ecosystems == [.google] {
            return ProtocolStack(
                discovery: .broadcast,
                transport: .udp,
                sync: .custom
            )
        }

        // Default: universal
        return ProtocolStack(
            discovery: .broadcast,
            transport: .webSocket,
            sync: .custom
        )
    }

    public struct ProtocolStack {
        public let discovery: DiscoveryMethod
        public let transport: TransportProtocol
        public let sync: SyncProtocol
    }
}

// MARK: - Predefined Device Combinations

public struct DeviceCombinationPresets {

    /// All possible cross-ecosystem combinations
    public static let crossEcosystemCombinations: [DeviceCombination] = [
        // Apple + Google
        DeviceCombination(
            name: "iPhone + Windows PC",
            devices: [
                (type: .iPhone, platform: .iOS, role: .bioSource),
                (type: .windowsPC, platform: .windows, role: .host)
            ],
            syncMode: .adaptive,
            notes: "Bio from iPhone, production on Windows"
        ),
        DeviceCombination(
            name: "Android Tablet + iMac",
            devices: [
                (type: .androidTablet, platform: .android, role: .midiControl),
                (type: .mac, platform: .macOS, role: .host)
            ],
            syncMode: .lowLatency,
            notes: "Touch control from Android, audio from Mac"
        ),
        DeviceCombination(
            name: "MacBook + Android Phone + Meta Glasses",
            devices: [
                (type: .mac, platform: .macOS, role: .host),
                (type: .androidPhone, platform: .android, role: .bioSource),
                (type: .metaGlasses, platform: .questOS, role: .visualOutput)
            ],
            syncMode: .adaptive,
            notes: "Production on Mac, bio from Android, AR visuals on Meta"
        ),
        DeviceCombination(
            name: "Vision Pro + Chromebook",
            devices: [
                (type: .visionPro, platform: .visionOS, role: .visualOutput),
                (type: .linuxPC, platform: .chromeOS, role: .audioSource)
            ],
            syncMode: .highQuality,
            notes: "Immersive visuals, audio production on Chromebook"
        ),
        DeviceCombination(
            name: "Tesla + Apple Watch + Android Tablet",
            devices: [
                (type: .tesla, platform: .teslaOS, role: .visualOutput),
                (type: .appleWatch, platform: .watchOS, role: .bioSource),
                (type: .androidTablet, platform: .android, role: .midiControl)
            ],
            syncMode: .adaptive,
            notes: "In-car experience with bio-reactive ambient lighting"
        ),
        DeviceCombination(
            name: "iPad + Windows + Android Watch",
            devices: [
                (type: .iPad, platform: .iPadOS, role: .host),
                (type: .windowsPC, platform: .windows, role: .audioSource),
                (type: .wearOS, platform: .wearOS, role: .bioSource)
            ],
            syncMode: .balanced,
            notes: "Control from iPad, audio from Windows, bio from Wear OS"
        ),
        DeviceCombination(
            name: "Meta Quest + iPhone + Linux PC",
            devices: [
                (type: .metaQuest, platform: .questOS, role: .visualOutput),
                (type: .iPhone, platform: .iOS, role: .bioSource),
                (type: .linuxPC, platform: .linux, role: .host)
            ],
            syncMode: .lowLatency,
            notes: "VR experience with iOS bio, Linux audio processing"
        ),
        DeviceCombination(
            name: "Apple TV + Android Phone + Windows Lighting",
            devices: [
                (type: .appleTv, platform: .tvOS, role: .visualOutput),
                (type: .androidPhone, platform: .android, role: .midiControl),
                (type: .windowsPC, platform: .windows, role: .lightingControl)
            ],
            syncMode: .balanced,
            notes: "Big screen visuals, Android control, Windows DMX"
        ),
        DeviceCombination(
            name: "Galaxy Watch + MacBook + Meta Glasses",
            devices: [
                (type: .wearOS, platform: .wearOS, role: .bioSource),
                (type: .mac, platform: .macOS, role: .host),
                (type: .metaGlasses, platform: .questOS, role: .visualOutput)
            ],
            syncMode: .adaptive,
            notes: "Samsung bio, Mac production, Ray-Ban AR visuals"
        ),
        DeviceCombination(
            name: "Full Studio: All Ecosystems",
            devices: [
                (type: .mac, platform: .macOS, role: .host),
                (type: .windowsPC, platform: .windows, role: .audioSource),
                (type: .linuxPC, platform: .linux, role: .lightingControl),
                (type: .iPhone, platform: .iOS, role: .midiControl),
                (type: .androidTablet, platform: .android, role: .visualOutput),
                (type: .appleWatch, platform: .watchOS, role: .bioSource),
                (type: .metaQuest, platform: .questOS, role: .visualOutput)
            ],
            syncMode: .masterSlave,
            notes: "Ultimate studio: Mac host, Windows audio, Linux DMX, mobile control, VR output"
        ),
    ]

    /// Check if a combination is valid
    public static func validateCombination(_ devices: [SessionDevice]) -> CombinationValidation {
        // All combinations are valid! We support everything.
        let ecosystems = Set(devices.map { $0.ecosystem })
        let hasHost = devices.contains { $0.role == .host }
        let hasBioSource = devices.contains { $0.role == .bioSource }

        var warnings: [String] = []
        var recommendations: [String] = []

        if !hasHost {
            recommendations.append("Consider designating a device as Host for best sync")
        }

        if !hasBioSource && devices.count > 1 {
            recommendations.append("Add a wearable (Watch, Ring) for bio-reactive features")
        }

        if ecosystems.count > 2 {
            warnings.append("Complex multi-ecosystem setup - ensure good network connectivity")
        }

        return CombinationValidation(
            isValid: true,  // Always valid!
            ecosystems: ecosystems,
            warnings: warnings,
            recommendations: recommendations,
            suggestedSyncMode: ecosystems.count > 1 ? .adaptive : .lowLatency
        )
    }

    public struct DeviceCombination {
        public let name: String
        public let devices: [(type: DeviceType, platform: SessionDevicePlatform, role: DeviceRole)]
        public let syncMode: SyncMode
        public let notes: String
    }

    public struct CombinationValidation {
        public let isValid: Bool
        public let ecosystems: Set<DeviceEcosystem>
        public let warnings: [String]
        public let recommendations: [String]
        public let suggestedSyncMode: SyncMode
    }
}

// MARK: - Adaptive Zero-Latency Engine

public final class AdaptiveZeroLatencyEngine {

    public static let shared = AdaptiveZeroLatencyEngine()

    // MARK: - Configuration

    public struct LatencyConfig {
        public var targetLatency: Double = 10.0  // ms
        public var maxLatency: Double = 50.0     // ms
        public var bufferSize: Int = 128         // samples
        public var adaptiveMode: Bool = true
        public var prioritizeQuality: Bool = false
    }

    public var config = LatencyConfig()

    // MARK: - Measurements

    private var latencyHistory: [String: [Double]] = [:]  // deviceId -> latencies
    private var jitterHistory: [String: [Double]] = [:]   // deviceId -> jitter

    // MARK: - Adaptive Optimization

    /// Optimize settings for current network conditions
    public func optimize(for devices: [SessionDevice]) -> OptimizationResult {
        var result = OptimizationResult()

        for device in devices {
            let deviceLatency = averageLatency(for: device.id)
            let deviceJitter = averageJitter(for: device.id)

            // Calculate optimal buffer size
            let optimalBuffer = calculateOptimalBuffer(
                latency: deviceLatency,
                jitter: deviceJitter
            )

            result.deviceSettings[device.id] = DeviceOptimization(
                bufferSize: optimalBuffer,
                latencyOffset: deviceLatency,
                qualityLevel: determineQualityLevel(latency: deviceLatency)
            )
        }

        // Calculate global sync offset
        result.globalSyncOffset = calculateGlobalSyncOffset(devices: devices)

        return result
    }

    private func averageLatency(for deviceId: String) -> Double {
        let history = latencyHistory[deviceId] ?? []
        guard !history.isEmpty else { return 20.0 } // Default 20ms
        return history.reduce(0, +) / Double(history.count)
    }

    private func averageJitter(for deviceId: String) -> Double {
        let history = jitterHistory[deviceId] ?? []
        guard !history.isEmpty else { return 5.0 } // Default 5ms
        return history.reduce(0, +) / Double(history.count)
    }

    private func calculateOptimalBuffer(latency: Double, jitter: Double) -> Int {
        // Higher latency/jitter = larger buffer needed
        let baseBuffer = 128
        let latencyFactor = max(1.0, latency / 10.0)
        let jitterFactor = max(1.0, jitter / 5.0)

        let optimalBuffer = Int(Double(baseBuffer) * latencyFactor * jitterFactor)

        // Clamp to power of 2
        let powers = [64, 128, 256, 512, 1024, 2048]
        return powers.first { $0 >= optimalBuffer } ?? 2048
    }

    private func determineQualityLevel(latency: Double) -> QualityLevel {
        switch latency {
        case ..<10: return .ultra
        case 10..<25: return .high
        case 25..<50: return .medium
        case 50..<100: return .low
        default: return .minimum
        }
    }

    private func calculateGlobalSyncOffset(devices: [SessionDevice]) -> Double {
        // Find the device with highest latency
        var maxLatency: Double = 0
        for device in devices {
            let latency = averageLatency(for: device.id)
            maxLatency = max(maxLatency, latency)
        }
        return maxLatency
    }

    /// Record a latency measurement
    public func recordLatency(_ latency: Double, for deviceId: String) {
        if latencyHistory[deviceId] == nil {
            latencyHistory[deviceId] = []
        }
        latencyHistory[deviceId]?.append(latency)

        // Keep last 100 measurements
        if let count = latencyHistory[deviceId]?.count, count > 100 {
            latencyHistory[deviceId]?.removeFirst()
        }
    }

    /// Record jitter measurement
    public func recordJitter(_ jitter: Double, for deviceId: String) {
        if jitterHistory[deviceId] == nil {
            jitterHistory[deviceId] = []
        }
        jitterHistory[deviceId]?.append(jitter)

        if let count = jitterHistory[deviceId]?.count, count > 100 {
            jitterHistory[deviceId]?.removeFirst()
        }
    }

    // MARK: - Result Types

    public struct OptimizationResult {
        public var deviceSettings: [String: DeviceOptimization] = [:]
        public var globalSyncOffset: Double = 0
    }

    public struct DeviceOptimization {
        public var bufferSize: Int
        public var latencyOffset: Double
        public var qualityLevel: QualityLevel
    }

    public enum QualityLevel: String, CaseIterable {
        case ultra = "Ultra"       // < 10ms, full quality
        case high = "High"         // 10-25ms, high quality
        case medium = "Medium"     // 25-50ms, balanced
        case low = "Low"           // 50-100ms, reduced quality
        case minimum = "Minimum"   // > 100ms, minimal quality
    }
}
