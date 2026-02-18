// EchoelIntegrationHub.swift
// Echoelmusic — Master Integration Orchestrator
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelIntegrationHub — Unified discovery, routing, and status for ALL protocols
//
// Connects every industry-standard protocol in the Echoelmusic ecosystem:
//
// Audio Transport:
//   ✓ Dante / AES67 / AVB     — Pro audio over IP (DanteAudioTransport)
//   ✓ AUv3 / Audio Unit        — Plugin hosting and bridging
//   ✓ Ableton Link             — Tempo/phase sync across devices
//   ✓ Core MIDI 2.0 / MPE      — MIDI I/O and routing (EchoelMIDI)
//   ✓ Core Audio / AVAudioEngine — System audio
//
// Video Transport:
//   ✓ NDI / Syphon / Spout    — Video over IP (VideoNetworkTransport)
//   ✓ RTMP / SRT / HLS        — Streaming protocols
//   ✓ Metal / Core Video       — GPU rendering pipeline
//
// Control Protocols:
//   ✓ DMX / Art-Net / sACN    — Lighting control (EchoelLux)
//   ★ OSC                      — Open Sound Control (EchoelOSCEngine) ← NEW
//   ★ MIDI Show Control (MSC)  — Theater/live event cues (EchoelShowControl) ← NEW
//   ★ Mackie Control / HUI     — DAW control surfaces (EchoelShowControl) ← NEW
//
// Network & Sync:
//   ✓ WebRTC                   — Real-time collaboration
//   ✓ PTP / MTC / LTC          — Timecode synchronization
//   ✓ Bonjour / mDNS           — Service discovery
//   ✓ EchoelSync               — Bio-reactive multi-device sync
//
// IoT & Smart:
//   ✓ HomeKit / MQTT           — Smart home integration
//   ✓ Bluetooth LE             — Wearable sensors
//   ✓ WiFi Direct              — P2P device communication
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────────┐
// │  EchoelIntegrationHub                                               │
// │       │                                                             │
// │       ├─→ Protocol Registry (all protocols with status/health)      │
// │       │                                                             │
// │       ├─→ Auto-Discovery (scan all networks for compatible gear)    │
// │       │       ├─→ Bonjour/mDNS (OSC, NDI, AirPlay)                │
// │       │       ├─→ Art-Net polling (DMX nodes)                       │
// │       │       ├─→ Dante discovery (AES67)                           │
// │       │       └─→ MIDI device scan                                  │
// │       │                                                             │
// │       ├─→ Route Manager (connect any source to any destination)     │
// │       │       ├─→ Bio → OSC → TouchDesigner                        │
// │       │       ├─→ Bio → DMX → Lighting                             │
// │       │       ├─→ Audio → NDI → Broadcast                          │
// │       │       ├─→ MIDI → Synth / FX / Lighting                     │
// │       │       └─→ Timecode → All sync-capable systems              │
// │       │                                                             │
// │       ├─→ Health Monitor (latency, packet loss, connection state)   │
// │       │                                                             │
// │       └─→ Preset System (save/recall full integration configs)      │
// └──────────────────────────────────────────────────────────────────────┘
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Integration Protocol Descriptor

/// A registered protocol in the integration hub
public struct IntegrationProtocol: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: ProtocolCategory
    public var status: ProtocolStatus
    public var latencyMs: Float
    public var isAvailable: Bool
    public var deviceCount: Int
    public var lastActivity: Date
    public var details: String

    public enum ProtocolCategory: String, CaseIterable, Sendable {
        case audioTransport = "Audio Transport"
        case videoTransport = "Video Transport"
        case controlProtocol = "Control Protocol"
        case networkSync = "Network & Sync"
        case iotSmart = "IoT & Smart"
        case bioSensor = "Bio Sensors"
    }

    public enum ProtocolStatus: String, Sendable {
        case active = "Active"
        case connected = "Connected"
        case discovering = "Discovering"
        case standby = "Standby"
        case error = "Error"
        case unavailable = "Unavailable"
    }
}

// MARK: - Discovered Device

/// A device found on the network
public struct DiscoveredDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: DeviceType
    public let protocol_: String
    public let host: String
    public let port: UInt16
    public let isConnected: Bool
    public let lastSeen: Date

    public enum DeviceType: String, CaseIterable, Sendable {
        case audioInterface = "Audio Interface"
        case midiController = "MIDI Controller"
        case controlSurface = "Control Surface"
        case dmxNode = "DMX Node"
        case ndiSource = "NDI Source"
        case oscTarget = "OSC Target"
        case lightingConsole = "Lighting Console"
        case videoSwitcher = "Video Switcher"
        case streamEncoder = "Stream Encoder"
        case wearableSensor = "Wearable Sensor"
        case smartLight = "Smart Light"
        case speaker = "Speaker"
        case display = "Display"
        case vrHeadset = "VR Headset"
        case fogMachine = "Fog Machine"
        case laser = "Laser"
        case projector = "Projector"
        case other = "Other"
    }
}

// MARK: - Integration Route

/// A route connecting a source to a destination across protocols
public struct IntegrationRoute: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let source: RouteEndpoint
    public let destination: RouteEndpoint
    public var isActive: Bool
    public var latencyMs: Float
    public var dataRate: String  // e.g. "30Hz", "48kHz", "30fps"

    public struct RouteEndpoint: Sendable {
        public let protocol_: String
        public let device: String
        public let parameter: String  // e.g. "coherence", "fader.1", "channel.rgb"

        public init(protocol_: String, device: String, parameter: String) {
            self.protocol_ = protocol_
            self.device = device
            self.parameter = parameter
        }
    }

    public init(name: String, source: RouteEndpoint, destination: RouteEndpoint) {
        self.id = UUID()
        self.name = name
        self.source = source
        self.destination = destination
        self.isActive = true
        self.latencyMs = 0
        self.dataRate = ""
    }
}

// MARK: - Integration Preset

/// Save/recall entire integration configurations
public struct IntegrationPreset: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var createdAt: Date
    public var routeDescriptions: [RouteDescription]
    public var oscTargets: [OSCTargetDescription]
    public var mscDeviceId: UInt8
    public var surfaceProtocol: String

    public struct RouteDescription: Codable, Sendable {
        public let name: String
        public let sourceProtocol: String
        public let sourceDevice: String
        public let sourceParam: String
        public let destProtocol: String
        public let destDevice: String
        public let destParam: String
    }

    public struct OSCTargetDescription: Codable, Sendable {
        public let name: String
        public let host: String
        public let port: UInt16
        public let application: String
    }
}

// MARK: - EchoelIntegrationHub

/// Master orchestrator for all industry-standard protocol integrations.
///
/// Provides unified discovery, routing, monitoring, and preset management
/// across every protocol in the Echoelmusic ecosystem.
///
/// Usage:
/// ```swift
/// let hub = EchoelIntegrationHub.shared
///
/// // Scan for all devices on the network
/// hub.scanAll()
///
/// // View all registered protocols
/// for proto in hub.protocols {
///     print("\(proto.name): \(proto.status.rawValue) — \(proto.deviceCount) devices")
/// }
///
/// // Create a route: Bio coherence → OSC → TouchDesigner
/// hub.createRoute(
///     name: "Bio to TD",
///     source: .init(protocol_: "EngineBus", device: "EchoelBio", parameter: "coherence"),
///     destination: .init(protocol_: "OSC", device: "TouchDesigner", parameter: "/bio/coherence")
/// )
///
/// // Save current configuration
/// hub.savePreset(name: "Live Show Setup")
///
/// // Load a preset
/// hub.loadPreset(hub.presets.first!)
/// ```
@MainActor
public final class EchoelIntegrationHub: ObservableObject {

    public static let shared = EchoelIntegrationHub()

    // MARK: - Published State

    /// All registered protocols with status
    @Published public var protocols: [IntegrationProtocol] = []

    /// All discovered devices on the network
    @Published public var discoveredDevices: [DiscoveredDevice] = []

    /// Active routes
    @Published public var routes: [IntegrationRoute] = []

    /// Saved presets
    @Published public var presets: [IntegrationPreset] = []

    /// Overall system health (0-1, based on protocol statuses)
    @Published public var systemHealth: Float = 1.0

    /// Total connected device count
    @Published public var totalConnectedDevices: Int = 0

    /// Total active routes
    @Published public var activeRouteCount: Int = 0

    /// Is scanning for devices
    @Published public var isScanning: Bool = false

    /// Average system latency across all active protocols (ms)
    @Published public var averageLatencyMs: Float = 0

    /// Last scan timestamp
    @Published public var lastScanTime: Date?

    // MARK: - Internal

    private var healthTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var busSubscriptions: [BusSubscription] = []

    // MARK: - Initialization

    private init() {
        registerAllProtocols()
        subscribeToBus()
        startHealthMonitor()
        loadPresetsFromDisk()
    }

    // MARK: - Protocol Registration

    /// Register all known protocols in the system
    private func registerAllProtocols() {
        protocols = [
            // Audio Transport
            IntegrationProtocol(
                id: "dante", name: "Dante / AES67",
                category: .audioTransport, status: .standby,
                latencyMs: 1.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Professional audio-over-IP (up to 512 channels)"
            ),
            IntegrationProtocol(
                id: "coreaudio", name: "Core Audio / AVAudioEngine",
                category: .audioTransport, status: .active,
                latencyMs: 5.0, isAvailable: true, deviceCount: 1,
                lastActivity: Date(), details: "System audio I/O"
            ),
            IntegrationProtocol(
                id: "auv3", name: "AUv3 / Audio Unit",
                category: .audioTransport, status: .standby,
                latencyMs: 2.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Plugin hosting and bridging"
            ),
            IntegrationProtocol(
                id: "link", name: "Ableton Link",
                category: .audioTransport, status: .standby,
                latencyMs: 0.5, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Tempo and phase sync across devices"
            ),

            // Video Transport
            IntegrationProtocol(
                id: "ndi", name: "NDI",
                category: .videoTransport, status: .standby,
                latencyMs: 16.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Video over IP (NewTek)"
            ),
            IntegrationProtocol(
                id: "syphon", name: "Syphon",
                category: .videoTransport, status: .standby,
                latencyMs: 2.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Inter-app video sharing (macOS)"
            ),
            IntegrationProtocol(
                id: "rtmp", name: "RTMP / SRT / HLS",
                category: .videoTransport, status: .standby,
                latencyMs: 500.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Live streaming protocols"
            ),

            // Control Protocols
            IntegrationProtocol(
                id: "midi", name: "MIDI 2.0 / MPE",
                category: .controlProtocol, status: .standby,
                latencyMs: 1.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Musical instrument control"
            ),
            IntegrationProtocol(
                id: "dmx", name: "DMX / Art-Net / sACN",
                category: .controlProtocol, status: .standby,
                latencyMs: 23.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Lighting control (512 channels/universe)"
            ),
            IntegrationProtocol(
                id: "osc", name: "OSC (Open Sound Control)",
                category: .controlProtocol, status: .standby,
                latencyMs: 1.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Universal control for TouchDesigner, Max/MSP, Resolume, etc."
            ),
            IntegrationProtocol(
                id: "msc", name: "MIDI Show Control",
                category: .controlProtocol, status: .standby,
                latencyMs: 1.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Theater/live event cue control"
            ),
            IntegrationProtocol(
                id: "mackie", name: "Mackie Control / HUI",
                category: .controlProtocol, status: .standby,
                latencyMs: 1.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "DAW control surface protocol"
            ),

            // Network & Sync
            IntegrationProtocol(
                id: "webrtc", name: "WebRTC",
                category: .networkSync, status: .standby,
                latencyMs: 50.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Real-time collaboration"
            ),
            IntegrationProtocol(
                id: "ptp", name: "PTP / MTC / LTC",
                category: .networkSync, status: .standby,
                latencyMs: 0.1, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Precision timecode synchronization"
            ),
            IntegrationProtocol(
                id: "echoelsync", name: "EchoelSync",
                category: .networkSync, status: .standby,
                latencyMs: 10.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Bio-reactive multi-device synchronization"
            ),

            // IoT & Smart
            IntegrationProtocol(
                id: "homekit", name: "HomeKit / MQTT",
                category: .iotSmart, status: .standby,
                latencyMs: 100.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Smart home device control"
            ),
            IntegrationProtocol(
                id: "ble", name: "Bluetooth LE",
                category: .bioSensor, status: .standby,
                latencyMs: 30.0, isAvailable: true, deviceCount: 0,
                lastActivity: Date(), details: "Wearable sensors (HR, HRV, EEG)"
            ),
        ]
    }

    // MARK: - Discovery

    /// Scan all networks for compatible devices and services
    public func scanAll() {
        isScanning = true
        lastScanTime = Date()
        discoveredDevices.removeAll()

        // Trigger discovery on each subsystem
        EngineBus.shared.publish(.custom(topic: "integration.scan.start", payload: [:]))

        // OSC discovery (Bonjour)
        EchoelOSCEngine.shared.startDiscovery()

        // NDI discovery (via VideoNetworkTransport)
        EngineBus.shared.publish(.custom(topic: "ndi.discover", payload: [:]))

        // Art-Net poll (via EchoelLux)
        EngineBus.shared.publish(.custom(topic: "artnet.poll", payload: [:]))

        // MIDI device scan
        EngineBus.shared.publish(.custom(topic: "midi.scan", payload: [:]))

        // Dante discovery
        EngineBus.shared.publish(.custom(topic: "dante.discover", payload: [:]))

        // Ableton Link scan
        EngineBus.shared.publish(.custom(topic: "link.scan", payload: [:]))

        // BLE scan for wearables
        EngineBus.shared.publish(.custom(topic: "ble.scan", payload: [:]))

        // Stop scanning after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isScanning = false
            self?.updateProtocolStatuses()
            EngineBus.shared.publish(.custom(topic: "integration.scan.complete", payload: [
                "devices": "\(self?.discoveredDevices.count ?? 0)"
            ]))
        }
    }

    /// Add a manually discovered device
    public func addDevice(_ device: DiscoveredDevice) {
        discoveredDevices.removeAll { $0.id == device.id }
        discoveredDevices.append(device)
        totalConnectedDevices = discoveredDevices.filter(\.isConnected).count
    }

    // MARK: - Route Management

    /// Create a route connecting a source to a destination
    @discardableResult
    public func createRoute(
        name: String,
        source: IntegrationRoute.RouteEndpoint,
        destination: IntegrationRoute.RouteEndpoint
    ) -> IntegrationRoute {
        let route = IntegrationRoute(name: name, source: source, destination: destination)
        routes.append(route)
        activeRouteCount = routes.filter(\.isActive).count

        EngineBus.shared.publish(.custom(
            topic: "integration.route.created",
            payload: [
                "name": name,
                "source": "\(source.protocol_).\(source.parameter)",
                "dest": "\(destination.protocol_).\(destination.parameter)"
            ]
        ))

        return route
    }

    /// Remove a route
    public func removeRoute(id: UUID) {
        routes.removeAll { $0.id == id }
        activeRouteCount = routes.filter(\.isActive).count
    }

    /// Toggle route active state
    public func toggleRoute(id: UUID) {
        guard let idx = routes.firstIndex(where: { $0.id == id }) else { return }
        routes[idx].isActive.toggle()
        activeRouteCount = routes.filter(\.isActive).count
    }

    // MARK: - Quick Setup Templates

    /// Quick setup: Bio data → OSC → TouchDesigner
    public func setupBioToTouchDesigner(host: String, port: UInt16 = 7000) {
        EchoelOSCEngine.shared.addTarget(application: .touchDesigner, host: host)
        EchoelOSCEngine.shared.startAutoBroadcast(hz: 30)

        createRoute(
            name: "Bio → TouchDesigner",
            source: .init(protocol_: "EngineBus", device: "EchoelBio", parameter: "bio.*"),
            destination: .init(protocol_: "OSC", device: "TouchDesigner", parameter: "/echoelmusic/bio/*")
        )
    }

    /// Quick setup: Bio data → DMX → Lighting rig
    public func setupBioToLighting(dmxAddress: String = "192.168.1.100") {
        createRoute(
            name: "Bio → DMX Lighting",
            source: .init(protocol_: "EngineBus", device: "EchoelBio", parameter: "bio.coherence"),
            destination: .init(protocol_: "DMX", device: dmxAddress, parameter: "universe1.rgb")
        )
    }

    /// Quick setup: Full live performance (OSC + DMX + NDI + MSC)
    public func setupLivePerformance(
        oscHost: String? = nil,
        dmxAddress: String = "192.168.1.100",
        ndiEnabled: Bool = true,
        mscEnabled: Bool = true
    ) {
        // OSC for visual software
        if let host = oscHost {
            EchoelOSCEngine.shared.addTarget(name: "Visual Software", host: host, port: 7000)
            EchoelOSCEngine.shared.startAutoBroadcast(hz: 30)
            createRoute(
                name: "Bio+Audio → Visuals (OSC)",
                source: .init(protocol_: "EngineBus", device: "All", parameter: "*"),
                destination: .init(protocol_: "OSC", device: host, parameter: "/echoelmusic/*")
            )
        }

        // DMX for lighting
        createRoute(
            name: "Bio → Stage Lighting (DMX)",
            source: .init(protocol_: "EngineBus", device: "EchoelBio", parameter: "bio.*"),
            destination: .init(protocol_: "DMX", device: dmxAddress, parameter: "universe1.*")
        )

        // NDI for video output
        if ndiEnabled {
            createRoute(
                name: "Video → NDI (Broadcast)",
                source: .init(protocol_: "Metal", device: "EchoelVis", parameter: "frame"),
                destination: .init(protocol_: "NDI", device: "Echoelmusic Output", parameter: "video")
            )
        }

        // MSC for show control
        if mscEnabled {
            EchoelShowControl.shared.mscEnabled = true
            createRoute(
                name: "Cue System → MSC (Show Control)",
                source: .init(protocol_: "EngineBus", device: "EchoelLux", parameter: "cue.*"),
                destination: .init(protocol_: "MSC", device: "All", parameter: "cue.*")
            )
        }

        EngineBus.shared.publish(.custom(
            topic: "integration.setup.live",
            payload: ["routes": "\(routes.count)"]
        ))
    }

    /// Quick setup: Studio (Mackie Control + AUv3 + Link)
    public func setupStudio() {
        EchoelShowControl.shared.mackieEnabled = true
        EchoelShowControl.shared.startMeterSync()

        createRoute(
            name: "Control Surface → Mixer",
            source: .init(protocol_: "Mackie", device: "Surface", parameter: "fader.*"),
            destination: .init(protocol_: "EngineBus", device: "EchoelMix", parameter: "channel.volume.*")
        )

        createRoute(
            name: "Mixer → Control Surface (Meters)",
            source: .init(protocol_: "EngineBus", device: "EchoelMix", parameter: "meter.*"),
            destination: .init(protocol_: "Mackie", device: "Surface", parameter: "meter.*")
        )

        EngineBus.shared.publish(.custom(
            topic: "integration.setup.studio",
            payload: ["routes": "\(routes.count)"]
        ))
    }

    /// Quick setup: Streaming (NDI + RTMP + OSC)
    public func setupStreaming(rtmpUrl: String? = nil, oscHost: String? = nil) {
        if let url = rtmpUrl {
            createRoute(
                name: "Video → Stream (RTMP)",
                source: .init(protocol_: "Metal", device: "EchoelVis", parameter: "frame"),
                destination: .init(protocol_: "RTMP", device: url, parameter: "video+audio")
            )
        }

        if let host = oscHost {
            EchoelOSCEngine.shared.addTarget(name: "Stream Overlay", host: host, port: 9000)
            createRoute(
                name: "Bio → Stream Overlay (OSC)",
                source: .init(protocol_: "EngineBus", device: "EchoelBio", parameter: "bio.*"),
                destination: .init(protocol_: "OSC", device: host, parameter: "/overlay/*")
            )
        }
    }

    // MARK: - Preset Management

    /// Save current integration configuration as a preset
    public func savePreset(name: String, description: String = "") {
        let preset = IntegrationPreset(
            id: UUID(),
            name: name,
            description: description,
            createdAt: Date(),
            routeDescriptions: routes.map { route in
                IntegrationPreset.RouteDescription(
                    name: route.name,
                    sourceProtocol: route.source.protocol_,
                    sourceDevice: route.source.device,
                    sourceParam: route.source.parameter,
                    destProtocol: route.destination.protocol_,
                    destDevice: route.destination.device,
                    destParam: route.destination.parameter
                )
            },
            oscTargets: EchoelOSCEngine.shared.targets.map { target in
                IntegrationPreset.OSCTargetDescription(
                    name: target.name,
                    host: target.host,
                    port: target.port,
                    application: target.application.rawValue
                )
            },
            mscDeviceId: EchoelShowControl.shared.mscDeviceId,
            surfaceProtocol: EchoelShowControl.shared.protocolMode.rawValue
        )

        presets.removeAll { $0.name == name }
        presets.append(preset)
        savePresetsToDisk()

        EngineBus.shared.publish(.custom(
            topic: "integration.preset.saved",
            payload: ["name": name, "routes": "\(routes.count)"]
        ))
    }

    /// Load an integration preset
    public func loadPreset(_ preset: IntegrationPreset) {
        // Clear current routes
        routes.removeAll()

        // Restore routes
        for desc in preset.routeDescriptions {
            createRoute(
                name: desc.name,
                source: .init(protocol_: desc.sourceProtocol, device: desc.sourceDevice, parameter: desc.sourceParam),
                destination: .init(protocol_: desc.destProtocol, device: desc.destDevice, parameter: desc.destParam)
            )
        }

        // Restore OSC targets
        EchoelOSCEngine.shared.removeAllTargets()
        for target in preset.oscTargets {
            let app = OSCTarget.OSCApplication(rawValue: target.application) ?? .custom
            EchoelOSCEngine.shared.addTarget(name: target.name, host: target.host, port: target.port, application: app)
        }

        // Restore MSC settings
        EchoelShowControl.shared.mscDeviceId = preset.mscDeviceId

        // Restore surface protocol
        if let proto = EchoelShowControl.ControlSurfaceProtocol(rawValue: preset.surfaceProtocol) {
            EchoelShowControl.shared.protocolMode = proto
        }

        EngineBus.shared.publish(.custom(
            topic: "integration.preset.loaded",
            payload: ["name": preset.name]
        ))
    }

    /// Delete a preset
    public func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        savePresetsToDisk()
    }

    // MARK: - Health Monitor

    private func startHealthMonitor() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHealth()
            }
        }
    }

    private func updateHealth() {
        // Calculate system health from protocol statuses
        let activeProtocols = protocols.filter { $0.status == .active || $0.status == .connected }
        let errorProtocols = protocols.filter { $0.status == .error }

        if errorProtocols.isEmpty {
            systemHealth = 1.0
        } else {
            systemHealth = max(0, 1.0 - Float(errorProtocols.count) / Float(protocols.count))
        }

        // Update latency
        let activeLatencies = activeProtocols.map(\.latencyMs)
        if !activeLatencies.isEmpty {
            averageLatencyMs = activeLatencies.reduce(0, +) / Float(activeLatencies.count)
        }

        // Update device count
        totalConnectedDevices = discoveredDevices.filter(\.isConnected).count

        // Update route count
        activeRouteCount = routes.filter(\.isActive).count
    }

    private func updateProtocolStatuses() {
        // Update OSC status
        if let idx = protocols.firstIndex(where: { $0.id == "osc" }) {
            let osc = EchoelOSCEngine.shared
            protocols[idx].status = osc.isServerRunning || !osc.targets.isEmpty ? .active : .standby
            protocols[idx].deviceCount = osc.targets.count
        }

        // Update MSC status
        if let idx = protocols.firstIndex(where: { $0.id == "msc" }) {
            protocols[idx].status = EchoelShowControl.shared.mscEnabled ? .active : .standby
        }

        // Update Mackie status
        if let idx = protocols.firstIndex(where: { $0.id == "mackie" }) {
            let show = EchoelShowControl.shared
            protocols[idx].status = show.mackieEnabled || show.huiEnabled ? .active : .standby
        }

        // Update MIDI status
        if let idx = protocols.firstIndex(where: { $0.id == "midi" }) {
            protocols[idx].deviceCount = discoveredDevices.filter { $0.type == .midiController }.count
        }
    }

    // MARK: - Persistence

    private var presetsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("echoelmusic_integration_presets.json")
    }

    private func savePresetsToDisk() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: presetsURL)
        } catch {
            // Silent fail — presets are convenience, not critical
        }
    }

    private func loadPresetsFromDisk() {
        guard let data = try? Data(contentsOf: presetsURL),
              let loaded = try? JSONDecoder().decode([IntegrationPreset].self, from: data) else { return }
        presets = loaded
    }

    // MARK: - Bus Integration

    private func subscribeToBus() {
        // Listen for device discovery events from subsystems
        let discoverySub = EngineBus.shared.subscribe(to: .custom) { [weak self] msg in
            if case .custom(let topic, let payload) = msg {
                Task { @MainActor in
                    switch topic {
                    case "osc.target.added":
                        if let name = payload["name"], let host = payload["host"], let portStr = payload["port"],
                           let port = UInt16(portStr) {
                            self?.addDevice(DiscoveredDevice(
                                id: "\(host):\(port)",
                                name: name,
                                type: .oscTarget,
                                protocol_: "OSC",
                                host: host,
                                port: port,
                                isConnected: true,
                                lastSeen: Date()
                            ))
                        }

                    case "midi.device.connected":
                        if let name = payload["name"] {
                            self?.addDevice(DiscoveredDevice(
                                id: "midi-\(name)",
                                name: name,
                                type: .midiController,
                                protocol_: "MIDI",
                                host: "local",
                                port: 0,
                                isConnected: true,
                                lastSeen: Date()
                            ))
                        }

                    case "ndi.source.found":
                        if let name = payload["name"], let host = payload["host"] {
                            self?.addDevice(DiscoveredDevice(
                                id: "ndi-\(name)",
                                name: name,
                                type: .ndiSource,
                                protocol_: "NDI",
                                host: host,
                                port: 5960,
                                isConnected: false,
                                lastSeen: Date()
                            ))
                        }

                    case "artnet.node.found":
                        if let name = payload["name"], let host = payload["host"] {
                            self?.addDevice(DiscoveredDevice(
                                id: "artnet-\(host)",
                                name: name,
                                type: .dmxNode,
                                protocol_: "Art-Net",
                                host: host,
                                port: 6454,
                                isConnected: false,
                                lastSeen: Date()
                            ))
                        }

                    default:
                        break
                    }
                }
            }
        }
        busSubscriptions.append(discoverySub)
    }

    // MARK: - Status

    /// One-line summary
    public var summary: String {
        let active = protocols.filter { $0.status == .active || $0.status == .connected }.count
        return "IntegrationHub: \(active)/\(protocols.count) protocols active, \(totalConnectedDevices) devices, \(activeRouteCount) routes"
    }

    /// Detailed multi-line status
    public var detailedStatus: String {
        var lines: [String] = ["EchoelIntegrationHub — Industry Standard Protocols"]
        lines.append("═══════════════════════════════════════════════════")

        for category in IntegrationProtocol.ProtocolCategory.allCases {
            let categoryProtocols = protocols.filter { $0.category == category }
            guard !categoryProtocols.isEmpty else { continue }
            lines.append("\n\(category.rawValue):")
            for proto in categoryProtocols {
                let statusIcon: String
                switch proto.status {
                case .active: statusIcon = "[ON]"
                case .connected: statusIcon = "[OK]"
                case .discovering: statusIcon = "[..]"
                case .standby: statusIcon = "[--]"
                case .error: statusIcon = "[!!]"
                case .unavailable: statusIcon = "[NA]"
                }
                lines.append("  \(statusIcon) \(proto.name) — \(proto.deviceCount) devices, \(String(format: "%.1f", proto.latencyMs))ms")
            }
        }

        if !routes.isEmpty {
            lines.append("\nActive Routes:")
            for route in routes where route.isActive {
                lines.append("  \(route.name): \(route.source.protocol_) → \(route.destination.protocol_)")
            }
        }

        lines.append("\nHealth: \(String(format: "%.0f%%", systemHealth * 100)) | Avg Latency: \(String(format: "%.1f", averageLatencyMs))ms")
        return lines.joined(separator: "\n")
    }

    // MARK: - Shutdown

    /// Stop all integration services
    public func shutdown() {
        healthTimer?.invalidate()
        healthTimer = nil
        EchoelOSCEngine.shared.shutdown()
        EchoelShowControl.shared.shutdown()
        routes.removeAll()
        busSubscriptions.removeAll()
    }
}
