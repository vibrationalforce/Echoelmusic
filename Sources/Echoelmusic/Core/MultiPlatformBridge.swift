import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC MULTI-PLATFORM BRIDGE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Verbindet ALLE Plattformen, Geräte und Systeme:
//
// DIGITAL SYSTEMS:
// • iOS / iPadOS / watchOS / macOS / visionOS
// • Ableton Live (Link Protocol)
// • TouchDesigner / Resolume / VDMX
// • Max/MSP / Pure Data / SuperCollider
// • Unity / Unreal Engine
// • Web (WebSocket/WebRTC)
//
// ANALOG GEAR:
// • Eurorack Modular (CV/Gate)
// • MIDI Hardware (DIN, USB, Bluetooth)
// • DMX Lighting
// • Art-Net / sACN
// • OSC-capable devices
//
// PROTOCOLS:
// • Ableton Link (tempo/phase sync)
// • OSC (Open Sound Control)
// • MIDI (1.0 and 2.0)
// • CV/Gate (0-10V, ±5V)
// • DMX512 / Art-Net
// • WebSocket / WebRTC
// • Bluetooth LE MIDI
// • Network MIDI (RTP-MIDI)
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Multi-Platform Bridge

@MainActor
final class MultiPlatformBridge: ObservableObject {

    // MARK: - Singleton

    static let shared = MultiPlatformBridge()

    // MARK: - Published State

    @Published var connectedPlatforms: [ConnectedPlatform] = []
    @Published var isLinkEnabled = false
    @Published var linkTempo: Double = 120
    @Published var linkPhase: Double = 0
    @Published var networkLatency: Double = 0

    // MARK: - Protocol Handlers

    private var oscHandler = OSCHandler()
    private var midiHandler = MIDIHandler()
    private var cvGateHandler = CVGateHandler()
    private var dmxHandler = DMXHandler()
    private var webHandler = WebSocketHandler()

    // MARK: - Initialization

    private init() {
        setupHandlers()
    }

    private func setupHandlers() {
        // Setup all protocol handlers
        oscHandler.delegate = self
        midiHandler.delegate = self
        cvGateHandler.delegate = self
        dmxHandler.delegate = self
        webHandler.delegate = self
    }

    // MARK: - Platform Connection

    func connect(to platform: PlatformType, config: PlatformConfig) async throws {
        switch platform {
        case .abletonLink:
            try await connectAbletonLink(config)
        case .touchDesigner:
            try await connectTouchDesigner(config)
        case .resolume:
            try await connectResolume(config)
        case .maxMSP:
            try await connectMaxMSP(config)
        case .unity:
            try await connectUnity(config)
        case .unreal:
            try await connectUnreal(config)
        case .web:
            try await connectWeb(config)
        case .eurorack:
            try await connectEurorack(config)
        case .midiDevice:
            try await connectMIDI(config)
        case .dmxLighting:
            try await connectDMX(config)
        }
    }

    // MARK: - Ableton Link

    private func connectAbletonLink(_ config: PlatformConfig) async throws {
        // Enable Ableton Link
        isLinkEnabled = true

        // Start Link session
        // Note: Requires LinkKit framework from Ableton

        connectedPlatforms.append(ConnectedPlatform(
            type: .abletonLink,
            name: "Ableton Link",
            status: .connected,
            capabilities: [.tempoSync, .phaseSync, .startStop]
        ))
    }

    // MARK: - TouchDesigner

    private func connectTouchDesigner(_ config: PlatformConfig) async throws {
        // OSC connection to TouchDesigner
        let host = config.host ?? "127.0.0.1"
        let sendPort = config.port ?? 7000
        let receivePort = config.receivePort ?? 7001

        try oscHandler.connect(host: host, sendPort: UInt16(sendPort), receivePort: UInt16(receivePort))

        connectedPlatforms.append(ConnectedPlatform(
            type: .touchDesigner,
            name: "TouchDesigner @ \(host)",
            status: .connected,
            capabilities: [.sendOSC, .receiveOSC, .visual]
        ))
    }

    // MARK: - Resolume

    private func connectResolume(_ config: PlatformConfig) async throws {
        let host = config.host ?? "127.0.0.1"
        let port = config.port ?? 7000

        try oscHandler.connect(host: host, sendPort: UInt16(port), receivePort: 0)

        connectedPlatforms.append(ConnectedPlatform(
            type: .resolume,
            name: "Resolume @ \(host)",
            status: .connected,
            capabilities: [.sendOSC, .visual]
        ))
    }

    // MARK: - Max/MSP

    private func connectMaxMSP(_ config: PlatformConfig) async throws {
        let host = config.host ?? "127.0.0.1"
        let port = config.port ?? 8000

        try oscHandler.connect(host: host, sendPort: UInt16(port), receivePort: UInt16(port + 1))

        connectedPlatforms.append(ConnectedPlatform(
            type: .maxMSP,
            name: "Max/MSP @ \(host)",
            status: .connected,
            capabilities: [.sendOSC, .receiveOSC, .audio, .visual]
        ))
    }

    // MARK: - Unity

    private func connectUnity(_ config: PlatformConfig) async throws {
        let host = config.host ?? "127.0.0.1"
        let port = config.port ?? 9000

        try oscHandler.connect(host: host, sendPort: UInt16(port), receivePort: 0)

        connectedPlatforms.append(ConnectedPlatform(
            type: .unity,
            name: "Unity @ \(host)",
            status: .connected,
            capabilities: [.sendOSC, .visual, .spatial]
        ))
    }

    // MARK: - Unreal Engine

    private func connectUnreal(_ config: PlatformConfig) async throws {
        let host = config.host ?? "127.0.0.1"
        let port = config.port ?? 9001

        try oscHandler.connect(host: host, sendPort: UInt16(port), receivePort: 0)

        connectedPlatforms.append(ConnectedPlatform(
            type: .unreal,
            name: "Unreal Engine @ \(host)",
            status: .connected,
            capabilities: [.sendOSC, .visual, .spatial]
        ))
    }

    // MARK: - Web (WebSocket)

    private func connectWeb(_ config: PlatformConfig) async throws {
        let host = config.host ?? "0.0.0.0"
        let port = config.port ?? 8080

        try webHandler.startServer(port: UInt16(port))

        connectedPlatforms.append(ConnectedPlatform(
            type: .web,
            name: "Web Server @ \(port)",
            status: .connected,
            capabilities: [.sendJSON, .receiveJSON, .visual]
        ))
    }

    // MARK: - Eurorack

    private func connectEurorack(_ config: PlatformConfig) async throws {
        // CV/Gate output via audio interface DC-coupled outputs
        // Or dedicated CV interface (ES-8, ES-9, etc.)

        try cvGateHandler.initialize(outputChannels: 8, inputChannels: 4)

        connectedPlatforms.append(ConnectedPlatform(
            type: .eurorack,
            name: "Eurorack CV/Gate",
            status: .connected,
            capabilities: [.sendCV, .receiveCV, .sendGate, .receiveGate]
        ))
    }

    // MARK: - MIDI

    private func connectMIDI(_ config: PlatformConfig) async throws {
        let deviceName = config.deviceName ?? "All Devices"

        try midiHandler.initialize(deviceFilter: deviceName)

        connectedPlatforms.append(ConnectedPlatform(
            type: .midiDevice,
            name: "MIDI: \(deviceName)",
            status: .connected,
            capabilities: [.sendMIDI, .receiveMIDI]
        ))
    }

    // MARK: - DMX

    private func connectDMX(_ config: PlatformConfig) async throws {
        let universe = config.dmxUniverse ?? 1
        let host = config.host ?? "255.255.255.255"

        try dmxHandler.initialize(universe: universe, broadcastAddress: host)

        connectedPlatforms.append(ConnectedPlatform(
            type: .dmxLighting,
            name: "DMX Universe \(universe)",
            status: .connected,
            capabilities: [.sendDMX, .lighting]
        ))
    }

    // MARK: - Broadcast State

    func broadcastState(_ state: EchoelUniversalCore.SystemState) {
        // Send to all connected platforms
        for platform in connectedPlatforms where platform.status == .connected {
            switch platform.type {
            case .abletonLink:
                // Link handles tempo/phase automatically
                break

            case .touchDesigner, .resolume, .maxMSP:
                sendOSCState(state, to: platform)

            case .unity, .unreal:
                sendOSCState(state, to: platform)

            case .web:
                sendWebState(state)

            case .eurorack:
                sendCVState(state)

            case .midiDevice:
                sendMIDIState(state)

            case .dmxLighting:
                sendDMXState(state)
            }
        }
    }

    // MARK: - Protocol Specific Sends

    private func sendOSCState(_ state: EchoelUniversalCore.SystemState, to platform: ConnectedPlatform) {
        // Bio data
        oscHandler.send(address: "/echoelmusic/coherence", value: state.coherence)
        oscHandler.send(address: "/echoelmusic/energy", value: state.energy)
        oscHandler.send(address: "/echoelmusic/flow", value: state.flow)
        oscHandler.send(address: "/echoelmusic/creativity", value: state.creativity)

        // System computational state (evidence-based)
        oscHandler.send(address: "/echoelmusic/system/coherence", value: state.systemCoherence)
        oscHandler.send(address: "/echoelmusic/system/generative_complexity", value: state.generativeComplexity)

        // HRV Metrics (Task Force ESC/NASPE 1996 compliant)
        oscHandler.send(address: "/echoelmusic/hrv/rmssd", value: Float(state.hrvRMSSD))
        oscHandler.send(address: "/echoelmusic/hrv/sdnn", value: Float(state.hrvSDNN))
        oscHandler.send(address: "/echoelmusic/hrv/pnn50", value: Float(state.hrvPNN50))
        oscHandler.send(address: "/echoelmusic/hrv/lf_power", value: Float(state.hrvLF))
        oscHandler.send(address: "/echoelmusic/hrv/hf_power", value: Float(state.hrvHF))
        oscHandler.send(address: "/echoelmusic/hrv/lf_hf_ratio", value: Float(state.hrvLFHFRatio))
        oscHandler.send(address: "/echoelmusic/hrv/coherence", value: Float(state.hrvCoherence))

        // Respiration
        oscHandler.send(address: "/echoelmusic/resp/rate", value: Float(state.breathingRate))

        // Timing
        oscHandler.send(address: "/echoelmusic/beat/phase", value: state.beatPhase)
        oscHandler.send(address: "/echoelmusic/breath/phase", value: state.breathPhase)
    }

    private func sendWebState(_ state: EchoelUniversalCore.SystemState) {
        let json: [String: Any] = [
            "coherence": state.coherence,
            "energy": state.energy,
            "flow": state.flow,
            "creativity": state.creativity,
            "system": [
                "coherence": state.systemCoherence,
                "generativeComplexity": state.generativeComplexity
            ],
            "hrv": [
                "rmssd": state.hrvRMSSD,
                "sdnn": state.hrvSDNN,
                "pnn50": state.hrvPNN50,
                "lf": state.hrvLF,
                "hf": state.hrvHF,
                "lfhfRatio": state.hrvLFHFRatio,
                "coherence": state.hrvCoherence
            ],
            "respiration": [
                "rate": state.breathingRate
            ],
            "timing": [
                "beatPhase": state.beatPhase,
                "breathPhase": state.breathPhase,
                "globalTime": state.globalTime
            ]
        ]
        webHandler.broadcast(json: json)
    }

    private func sendCVState(_ state: EchoelUniversalCore.SystemState) {
        // Map state to CV voltages (0-5V range)
        cvGateHandler.setVoltage(channel: 0, voltage: state.coherence * 5.0)
        cvGateHandler.setVoltage(channel: 1, voltage: state.energy * 5.0)
        cvGateHandler.setVoltage(channel: 2, voltage: state.flow * 5.0)
        cvGateHandler.setVoltage(channel: 3, voltage: state.creativity * 5.0)

        // Gate outputs for triggers
        cvGateHandler.setGate(channel: 4, state: state.beatPhase < 0.1)
        cvGateHandler.setGate(channel: 5, state: state.breathPhase < 0.1)
    }

    private func sendMIDIState(_ state: EchoelUniversalCore.SystemState) {
        // CC messages
        midiHandler.sendCC(channel: 0, cc: 1, value: UInt8(state.coherence * 127))
        midiHandler.sendCC(channel: 0, cc: 11, value: UInt8(state.energy * 127))
        midiHandler.sendCC(channel: 0, cc: 74, value: UInt8(state.creativity * 127))
        midiHandler.sendCC(channel: 0, cc: 71, value: UInt8(state.flow * 127))

        // Note triggers on beat
        if state.beatPhase < 0.05 {
            midiHandler.sendNoteOn(channel: 9, note: 36, velocity: UInt8(state.energy * 127))
        }
    }

    private func sendDMXState(_ state: EchoelUniversalCore.SystemState) {
        // Map to DMX channels (0-255)
        dmxHandler.setChannel(1, value: UInt8(state.coherence * 255))
        dmxHandler.setChannel(2, value: UInt8(state.energy * 255))
        dmxHandler.setChannel(3, value: UInt8(state.flow * 255))
        dmxHandler.setChannel(4, value: UInt8(state.creativity * 255))

        // RGB based on quantum state
        let rgb = stateToRGB(state)
        dmxHandler.setChannel(5, value: UInt8(rgb.r * 255))
        dmxHandler.setChannel(6, value: UInt8(rgb.g * 255))
        dmxHandler.setChannel(7, value: UInt8(rgb.b * 255))
    }

    private func stateToRGB(_ state: EchoelUniversalCore.SystemState) -> (r: Float, g: Float, b: Float) {
        // Use coherence to color mapping
        return UnifiedVisualSoundEngine.OctaveTransposition.wavelengthToRGB(
            wavelength: 650 - state.coherence * 120  // Red to Green
        )
    }
}

// MARK: - Data Types

enum PlatformType: String, CaseIterable {
    case abletonLink = "Ableton Link"
    case touchDesigner = "TouchDesigner"
    case resolume = "Resolume"
    case maxMSP = "Max/MSP"
    case unity = "Unity"
    case unreal = "Unreal Engine"
    case web = "Web Browser"
    case eurorack = "Eurorack"
    case midiDevice = "MIDI Device"
    case dmxLighting = "DMX Lighting"
}

struct PlatformConfig {
    var host: String?
    var port: Int?
    var receivePort: Int?
    var deviceName: String?
    var dmxUniverse: Int?
    var artNetNode: String?
}

struct ConnectedPlatform: Identifiable {
    let id = UUID()
    var type: PlatformType
    var name: String
    var status: ConnectionStatus
    var capabilities: Set<PlatformCapability>
    var latency: Double = 0

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error
    }
}

enum PlatformCapability {
    // Transport
    case tempoSync
    case phaseSync
    case startStop

    // Data
    case sendOSC
    case receiveOSC
    case sendMIDI
    case receiveMIDI
    case sendCV
    case receiveCV
    case sendGate
    case receiveGate
    case sendDMX
    case sendJSON
    case receiveJSON

    // Content
    case audio
    case visual
    case lighting
    case spatial
}

// MARK: - Protocol Handlers (Stubs)

class OSCHandler {
    weak var delegate: MultiPlatformBridge?

    func connect(host: String, sendPort: UInt16, receivePort: UInt16) throws {
        // UDP socket setup for OSC
    }

    func send(address: String, value: Float) {
        // Send OSC message
    }

    func send(address: String, values: [Float]) {
        // Send OSC message with multiple values
    }
}

class MIDIHandler {
    weak var delegate: MultiPlatformBridge?

    func initialize(deviceFilter: String) throws {
        // CoreMIDI setup
    }

    func sendCC(channel: UInt8, cc: UInt8, value: UInt8) {
        // Send MIDI CC
    }

    func sendNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        // Send MIDI Note On
    }

    func sendNoteOff(channel: UInt8, note: UInt8) {
        // Send MIDI Note Off
    }
}

class CVGateHandler {
    weak var delegate: MultiPlatformBridge?

    func initialize(outputChannels: Int, inputChannels: Int) throws {
        // DC-coupled audio interface setup
    }

    func setVoltage(channel: Int, voltage: Float) {
        // Set CV output voltage
    }

    func setGate(channel: Int, state: Bool) {
        // Set gate output
    }
}

class DMXHandler {
    weak var delegate: MultiPlatformBridge?
    private var dmxBuffer = [UInt8](repeating: 0, count: 512)

    func initialize(universe: Int, broadcastAddress: String) throws {
        // Art-Net setup
    }

    func setChannel(_ channel: Int, value: UInt8) {
        guard channel > 0 && channel <= 512 else { return }
        dmxBuffer[channel - 1] = value
    }

    func flush() {
        // Send DMX universe via Art-Net
    }
}

class WebSocketHandler {
    weak var delegate: MultiPlatformBridge?
    private var clients: [WebSocketClient] = []

    func startServer(port: UInt16) throws {
        // WebSocket server setup
    }

    func broadcast(json: [String: Any]) {
        // Send to all connected clients
    }

    struct WebSocketClient {
        var id: UUID
        var connection: Any  // WebSocket connection
    }
}

// MARK: - Delegate Extensions

extension MultiPlatformBridge: OSCHandlerDelegate,
                                MIDIHandlerDelegate,
                                CVGateHandlerDelegate,
                                DMXHandlerDelegate,
                                WebSocketHandlerDelegate {
    func oscReceived(address: String, values: [Any]) {
        // Handle incoming OSC
    }

    func midiReceived(status: UInt8, data1: UInt8, data2: UInt8) {
        // Handle incoming MIDI
    }

    func cvReceived(channel: Int, voltage: Float) {
        // Handle incoming CV
    }

    func gateReceived(channel: Int, state: Bool) {
        // Handle incoming gate
    }

    func webSocketConnected(client: WebSocketHandler.WebSocketClient) {
        // Handle new WebSocket client
    }

    func webSocketReceived(client: WebSocketHandler.WebSocketClient, message: String) {
        // Handle incoming WebSocket message
    }
}

// Protocol stubs
protocol OSCHandlerDelegate: AnyObject {
    func oscReceived(address: String, values: [Any])
}

protocol MIDIHandlerDelegate: AnyObject {
    func midiReceived(status: UInt8, data1: UInt8, data2: UInt8)
}

protocol CVGateHandlerDelegate: AnyObject {
    func cvReceived(channel: Int, voltage: Float)
    func gateReceived(channel: Int, state: Bool)
}

protocol DMXHandlerDelegate: AnyObject {}

protocol WebSocketHandlerDelegate: AnyObject {
    func webSocketConnected(client: WebSocketHandler.WebSocketClient)
    func webSocketReceived(client: WebSocketHandler.WebSocketClient, message: String)
}
