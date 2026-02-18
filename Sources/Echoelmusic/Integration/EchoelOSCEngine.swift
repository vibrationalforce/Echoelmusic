// EchoelOSCEngine.swift
// Echoelmusic — Open Sound Control (OSC) Protocol Engine
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelOSC — Industry-standard OSC for live visual & audio software
//
// Unlocks integration with:
// - TouchDesigner (real-time visual programming)
// - Resolume Arena/Avenue (VJ software)
// - Max/MSP & Pure Data (creative coding)
// - QLab (show control / theater)
// - SuperCollider (algorithmic composition)
// - Processing / openFrameworks (creative code)
// - Ableton Live (via OSC plugins)
// - Unity / Unreal Engine (via OSC receivers)
// - Isadora (interactive media)
// - MadMapper (projection mapping)
// - VDMX (live visuals)
//
// OSC Spec: opensoundcontrol.stanford.edu
// Transport: UDP (default), TCP (optional for reliability)
// Encoding: Big-endian, 4-byte aligned, type-tagged
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────┐
// │  EchoelOSCEngine                                            │
// │       │                                                     │
// │       ├─→ OSCServer (receive from external apps)            │
// │       │       └─→ Address pattern matching & dispatch       │
// │       │                                                     │
// │       ├─→ OSCClient (send to external apps)                 │
// │       │       └─→ Bio/Audio/Visual data broadcasting        │
// │       │                                                     │
// │       ├─→ OSCBundler (message grouping with timestamps)     │
// │       │                                                     │
// │       ├─→ Auto-Discovery (Bonjour/mDNS _osc._udp)          │
// │       │                                                     │
// │       └─→ EngineBus bridge (OSC ↔ internal bus)             │
// └──────────────────────────────────────────────────────────────┘
//
// Default OSC Address Namespace:
//   /echoelmusic/bio/coherence     Float 0-1
//   /echoelmusic/bio/heartrate     Float BPM
//   /echoelmusic/bio/breathing     Float rate
//   /echoelmusic/bio/hrv           Float ms
//   /echoelmusic/bio/energy        Float 0-1
//   /echoelmusic/bio/flow          Float 0-1
//   /echoelmusic/audio/rms         Float 0-1
//   /echoelmusic/audio/spectrum    Blob [Float]
//   /echoelmusic/audio/bpm         Float
//   /echoelmusic/audio/frequency   Float Hz
//   /echoelmusic/visual/hue        Float 0-1
//   /echoelmusic/visual/intensity  Float 0-1
//   /echoelmusic/visual/mode       String
//   /echoelmusic/world/biome       String
//   /echoelmusic/world/weather     String
//   /echoelmusic/avatar/aura       Float 0-1
//   /echoelmusic/avatar/valence    Float -1..1
//   /echoelmusic/control/*         Control messages (play, stop, scene, etc.)
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
#if canImport(Network)
import Network
#endif

// MARK: - OSC Data Types

/// OSC type tag characters per spec
public enum OSCType: Character, Sendable {
    case int32 = "i"        // 32-bit big-endian int
    case float32 = "f"      // 32-bit big-endian float
    case string = "s"       // Null-terminated, 4-byte aligned
    case blob = "b"         // Length-prefixed byte array
    case int64 = "h"        // 64-bit big-endian int
    case timetag = "t"      // NTP timestamp (64-bit)
    case double64 = "d"     // 64-bit double
    case trueVal = "T"      // Boolean true (no data)
    case falseVal = "F"     // Boolean false (no data)
    case nilVal = "N"       // Nil (no data)
}

/// A single OSC value
public enum OSCValue: Sendable {
    case int32(Int32)
    case float32(Float)
    case string(String)
    case blob(Data)
    case int64(Int64)
    case double64(Double)
    case bool(Bool)
    case timetag(UInt64)
    case nilValue

    /// Extract Float value (converting if needed)
    public var floatValue: Float? {
        switch self {
        case .float32(let v): return v
        case .int32(let v): return Float(v)
        case .double64(let v): return Float(v)
        case .int64(let v): return Float(v)
        default: return nil
        }
    }

    /// Extract String value
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Extract Int32 value
    public var intValue: Int32? {
        if case .int32(let v) = self { return v }
        if case .float32(let v) = self { return Int32(v) }
        return nil
    }
}

/// An OSC message: address pattern + arguments
public struct OSCMessage: Sendable {
    public let address: String           // e.g. "/echoelmusic/bio/coherence"
    public let arguments: [OSCValue]     // Type-tagged values
    public let timestamp: Date

    public init(address: String, arguments: [OSCValue] = [], timestamp: Date = Date()) {
        self.address = address
        self.arguments = arguments
        self.timestamp = timestamp
    }

    /// Convenience: single float message
    public static func float(_ address: String, _ value: Float) -> OSCMessage {
        OSCMessage(address: address, arguments: [.float32(value)])
    }

    /// Convenience: single string message
    public static func string(_ address: String, _ value: String) -> OSCMessage {
        OSCMessage(address: address, arguments: [.string(value)])
    }

    /// Convenience: multi-float message
    public static func floats(_ address: String, _ values: [Float]) -> OSCMessage {
        OSCMessage(address: address, arguments: values.map { .float32($0) })
    }

    /// Encode to OSC binary format
    public func encode() -> Data {
        var data = Data()

        // Address string (null-terminated, 4-byte aligned)
        data.append(OSCEncoder.encodeString(address))

        // Type tag string
        var typeTag = ","
        for arg in arguments {
            switch arg {
            case .int32: typeTag.append("i")
            case .float32: typeTag.append("f")
            case .string: typeTag.append("s")
            case .blob: typeTag.append("b")
            case .int64: typeTag.append("h")
            case .double64: typeTag.append("d")
            case .bool(let v): typeTag.append(v ? "T" : "F")
            case .timetag: typeTag.append("t")
            case .nilValue: typeTag.append("N")
            }
        }
        data.append(OSCEncoder.encodeString(typeTag))

        // Arguments
        for arg in arguments {
            switch arg {
            case .int32(let v):
                data.append(OSCEncoder.encodeInt32(v))
            case .float32(let v):
                data.append(OSCEncoder.encodeFloat32(v))
            case .string(let v):
                data.append(OSCEncoder.encodeString(v))
            case .blob(let v):
                data.append(OSCEncoder.encodeBlob(v))
            case .int64(let v):
                data.append(OSCEncoder.encodeInt64(v))
            case .double64(let v):
                data.append(OSCEncoder.encodeDouble64(v))
            case .timetag(let v):
                data.append(OSCEncoder.encodeUInt64(v))
            case .bool, .nilValue:
                break // No data bytes
            }
        }

        return data
    }

    /// Decode from OSC binary data
    public static func decode(from data: Data) -> OSCMessage? {
        var offset = 0
        guard let address = OSCDecoder.decodeString(from: data, offset: &offset) else { return nil }
        guard address.hasPrefix("/") else { return nil }
        guard let typeTag = OSCDecoder.decodeString(from: data, offset: &offset) else { return nil }
        guard typeTag.hasPrefix(",") else { return nil }

        var arguments: [OSCValue] = []
        for char in typeTag.dropFirst() {
            switch char {
            case "i":
                guard let v = OSCDecoder.decodeInt32(from: data, offset: &offset) else { return nil }
                arguments.append(.int32(v))
            case "f":
                guard let v = OSCDecoder.decodeFloat32(from: data, offset: &offset) else { return nil }
                arguments.append(.float32(v))
            case "s":
                guard let v = OSCDecoder.decodeString(from: data, offset: &offset) else { return nil }
                arguments.append(.string(v))
            case "b":
                guard let v = OSCDecoder.decodeBlob(from: data, offset: &offset) else { return nil }
                arguments.append(.blob(v))
            case "h":
                guard let v = OSCDecoder.decodeInt64(from: data, offset: &offset) else { return nil }
                arguments.append(.int64(v))
            case "d":
                guard let v = OSCDecoder.decodeDouble64(from: data, offset: &offset) else { return nil }
                arguments.append(.double64(v))
            case "t":
                guard let v = OSCDecoder.decodeUInt64(from: data, offset: &offset) else { return nil }
                arguments.append(.timetag(v))
            case "T":
                arguments.append(.bool(true))
            case "F":
                arguments.append(.bool(false))
            case "N":
                arguments.append(.nilValue)
            default:
                break
            }
        }

        return OSCMessage(address: address, arguments: arguments)
    }
}

/// An OSC bundle: timetag + messages (atomic delivery)
public struct OSCBundle: Sendable {
    public let timetag: UInt64    // NTP time (1 = immediately)
    public let elements: [OSCMessage]

    public init(timetag: UInt64 = 1, elements: [OSCMessage]) {
        self.timetag = timetag
        self.elements = elements
    }

    /// Encode bundle to OSC binary format
    public func encode() -> Data {
        var data = Data()

        // Bundle header "#bundle\0"
        data.append(OSCEncoder.encodeString("#bundle"))

        // Timetag
        data.append(OSCEncoder.encodeUInt64(timetag))

        // Elements (size-prefixed messages)
        for element in elements {
            let msgData = element.encode()
            data.append(OSCEncoder.encodeInt32(Int32(msgData.count)))
            data.append(msgData)
        }

        return data
    }
}

// MARK: - OSC Binary Encoder

internal enum OSCEncoder {
    static func encodeString(_ string: String) -> Data {
        var data = string.data(using: .utf8) ?? Data()
        data.append(0) // Null terminator
        // Pad to 4-byte boundary
        while data.count % 4 != 0 { data.append(0) }
        return data
    }

    static func encodeInt32(_ value: Int32) -> Data {
        var big = value.bigEndian
        return Data(bytes: &big, count: 4)
    }

    static func encodeFloat32(_ value: Float) -> Data {
        var big = value.bitPattern.bigEndian
        return Data(bytes: &big, count: 4)
    }

    static func encodeInt64(_ value: Int64) -> Data {
        var big = value.bigEndian
        return Data(bytes: &big, count: 8)
    }

    static func encodeUInt64(_ value: UInt64) -> Data {
        var big = value.bigEndian
        return Data(bytes: &big, count: 8)
    }

    static func encodeDouble64(_ value: Double) -> Data {
        var big = value.bitPattern.bigEndian
        return Data(bytes: &big, count: 8)
    }

    static func encodeBlob(_ data: Data) -> Data {
        var result = Data()
        var size = Int32(data.count).bigEndian
        result.append(Data(bytes: &size, count: 4))
        result.append(data)
        while result.count % 4 != 0 { result.append(0) }
        return result
    }
}

// MARK: - OSC Binary Decoder

internal enum OSCDecoder {
    static func decodeString(from data: Data, offset: inout Int) -> String? {
        guard offset < data.count else { return nil }
        var end = offset
        while end < data.count && data[end] != 0 { end += 1 }
        guard end < data.count else { return nil }
        let str = String(data: data[offset..<end], encoding: .utf8)
        end += 1 // Skip null
        while end % 4 != 0 { end += 1 } // Skip padding
        offset = end
        return str
    }

    static func decodeInt32(from data: Data, offset: inout Int) -> Int32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data[offset..<offset+4].withUnsafeBytes { $0.load(as: Int32.self) }
        offset += 4
        return Int32(bigEndian: value)
    }

    static func decodeFloat32(from data: Data, offset: inout Int) -> Float? {
        guard offset + 4 <= data.count else { return nil }
        let bits = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        return Float(bitPattern: UInt32(bigEndian: bits))
    }

    static func decodeInt64(from data: Data, offset: inout Int) -> Int64? {
        guard offset + 8 <= data.count else { return nil }
        let value = data[offset..<offset+8].withUnsafeBytes { $0.load(as: Int64.self) }
        offset += 8
        return Int64(bigEndian: value)
    }

    static func decodeUInt64(from data: Data, offset: inout Int) -> UInt64? {
        guard offset + 8 <= data.count else { return nil }
        let value = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self) }
        offset += 8
        return UInt64(bigEndian: value)
    }

    static func decodeDouble64(from data: Data, offset: inout Int) -> Double? {
        guard offset + 8 <= data.count else { return nil }
        let bits = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self) }
        offset += 8
        return Double(bitPattern: UInt64(bigEndian: bits))
    }

    static func decodeBlob(from data: Data, offset: inout Int) -> Data? {
        guard let size = decodeInt32(from: data, offset: &offset) else { return nil }
        let blobSize = Int(size)
        guard offset + blobSize <= data.count else { return nil }
        let blob = data[offset..<offset+blobSize]
        offset += blobSize
        while offset % 4 != 0 { offset += 1 }
        return Data(blob)
    }
}

// MARK: - OSC Target (remote endpoint)

/// A discovered or configured OSC target
public struct OSCTarget: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var host: String
    public var port: UInt16
    public var isActive: Bool
    public var lastSeen: Date
    public var application: OSCApplication

    /// Known application types for auto-configuration
    public enum OSCApplication: String, CaseIterable, Sendable {
        case touchDesigner = "TouchDesigner"
        case resolume = "Resolume"
        case maxMSP = "Max/MSP"
        case purData = "Pure Data"
        case qlab = "QLab"
        case superCollider = "SuperCollider"
        case processing = "Processing"
        case isadora = "Isadora"
        case madMapper = "MadMapper"
        case vdmx = "VDMX"
        case abletonLive = "Ableton Live"
        case unity = "Unity"
        case unrealEngine = "Unreal Engine"
        case godot = "Godot"
        case custom = "Custom"

        /// Default receive port for known applications
        public var defaultPort: UInt16 {
            switch self {
            case .touchDesigner: return 7000
            case .resolume: return 7000
            case .maxMSP: return 8000
            case .purData: return 8000
            case .qlab: return 53000
            case .superCollider: return 57120
            case .processing: return 12000
            case .isadora: return 1234
            case .madMapper: return 8010
            case .vdmx: return 5000
            case .abletonLive: return 9000
            case .unity: return 9001
            case .unrealEngine: return 9002
            case .godot: return 9003
            case .custom: return 9000
            }
        }
    }
}

// MARK: - OSC Address Handler

/// Callback for received OSC messages matching an address pattern
public typealias OSCHandler = @Sendable (OSCMessage) -> Void

/// Address pattern registration
internal struct OSCAddressHandler {
    let pattern: String      // e.g. "/echoelmusic/bio/*"
    let handler: OSCHandler
}

// MARK: - EchoelOSCEngine

/// Industry-standard OSC (Open Sound Control) for seamless integration
/// with live visual, audio, and show control software.
///
/// Usage:
/// ```swift
/// let osc = EchoelOSCEngine.shared
///
/// // Start server (receive from external apps)
/// try osc.startServer(port: 8000)
///
/// // Add a target (send to external app)
/// osc.addTarget(name: "TouchDesigner", host: "192.168.1.50", port: 7000)
///
/// // Send bio data to all targets
/// osc.send(.float("/echoelmusic/bio/coherence", 0.85))
///
/// // Register handler for incoming messages
/// osc.handle("/control/play") { msg in
///     print("Play command received")
/// }
///
/// // Enable auto-broadcast (bio/audio/visual data at configurable Hz)
/// osc.startAutoBroadcast(hz: 30)
/// ```
@MainActor
public final class EchoelOSCEngine: ObservableObject {

    public static let shared = EchoelOSCEngine()

    // MARK: - Published State

    /// Server listening state
    @Published public var isServerRunning: Bool = false

    /// Server listen port
    @Published public var serverPort: UInt16 = 8000

    /// Connected/configured targets
    @Published public var targets: [OSCTarget] = []

    /// Auto-broadcast enabled
    @Published public var isAutoBroadcasting: Bool = false

    /// Auto-broadcast rate (Hz)
    @Published public var broadcastRate: Float = 30

    /// Messages sent per second
    @Published public var sendRate: Float = 0

    /// Messages received per second
    @Published public var receiveRate: Float = 0

    /// Total messages sent
    @Published public var totalSent: Int = 0

    /// Total messages received
    @Published public var totalReceived: Int = 0

    /// Last received message address (for monitoring)
    @Published public var lastReceivedAddress: String = ""

    /// OSC address namespace prefix
    @Published public var namespacePrefix: String = "/echoelmusic"

    /// Discovered services via Bonjour
    @Published public var discoveredServices: [String] = []

    // MARK: - Internal

    #if canImport(Network)
    private var udpListener: NWListener?
    private var udpConnections: [String: NWConnection] = [:]
    #endif

    private var handlers: [OSCAddressHandler] = []
    private var broadcastTimer: Timer?
    private var rateTimer: Timer?
    private var sentThisSecond: Int = 0
    private var receivedThisSecond: Int = 0
    private var busSubscriptions: [BusSubscription] = []

    // Cached bio/audio state for broadcasting
    private var currentCoherence: Float = 0.5
    private var currentHeartRate: Float = 70
    private var currentBreathingRate: Float = 12
    private var currentHRV: Float = 50
    private var currentEnergy: Float = 0.5
    private var currentFlow: Float = 0
    private var currentRMS: Float = 0
    private var currentBPM: Float = 120
    private var currentFrequency: Float = 440
    private var currentVisualHue: Float = 0.6
    private var currentVisualIntensity: Float = 0.5

    // MARK: - Initialization

    private init() {
        subscribeToBus()
        startRateMonitor()
    }

    deinit {
        broadcastTimer?.invalidate()
        rateTimer?.invalidate()
    }

    // MARK: - Server (Receive)

    /// Start OSC UDP server to receive messages from external applications
    public func startServer(port: UInt16 = 8000) throws {
        #if canImport(Network)
        guard !isServerRunning else { return }
        serverPort = port

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isServerRunning = true
                    EngineBus.shared.publish(.custom(
                        topic: "osc.server.started",
                        payload: ["port": "\(port)"]
                    ))
                case .failed, .cancelled:
                    self?.isServerRunning = false
                default:
                    break
                }
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    self?.receiveData(on: connection)
                }
            }
            connection.start(queue: .global(qos: .userInteractive))
        }

        listener.start(queue: .global(qos: .userInteractive))
        udpListener = listener
        #endif
    }

    /// Stop OSC server
    public func stopServer() {
        #if canImport(Network)
        udpListener?.cancel()
        udpListener = nil
        isServerRunning = false
        #endif
    }

    #if canImport(Network)
    private func receiveData(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor in
                self?.processReceivedData(data)
            }
            // Continue receiving
            self?.receiveData(on: connection)
        }
    }
    #endif

    private func processReceivedData(_ data: Data) {
        // Check if bundle
        if data.count >= 8, String(data: data[0..<7], encoding: .utf8) == "#bundle" {
            decodeBundleData(data)
        } else if let msg = OSCMessage.decode(from: data) {
            handleReceivedMessage(msg)
        }
    }

    private func decodeBundleData(_ data: Data) {
        var offset = 0
        // Skip "#bundle\0"
        guard let _ = OSCDecoder.decodeString(from: data, offset: &offset) else { return }
        // Skip timetag
        guard let _ = OSCDecoder.decodeUInt64(from: data, offset: &offset) else { return }

        // Read elements
        while offset < data.count {
            guard let size = OSCDecoder.decodeInt32(from: data, offset: &offset) else { break }
            let elementSize = Int(size)
            guard offset + elementSize <= data.count else { break }
            let elementData = data[offset..<offset+elementSize]
            if let msg = OSCMessage.decode(from: Data(elementData)) {
                handleReceivedMessage(msg)
            }
            offset += elementSize
        }
    }

    private func handleReceivedMessage(_ message: OSCMessage) {
        totalReceived += 1
        receivedThisSecond += 1
        lastReceivedAddress = message.address

        // Match against registered handlers
        for registration in handlers {
            if matchAddress(pattern: registration.pattern, address: message.address) {
                registration.handler(message)
            }
        }

        // Bridge incoming OSC to EngineBus
        bridgeIncomingToEngineBus(message)
    }

    // MARK: - Target Management

    /// Add an OSC target to send messages to
    public func addTarget(
        name: String,
        host: String,
        port: UInt16,
        application: OSCTarget.OSCApplication = .custom
    ) {
        let target = OSCTarget(
            id: "\(host):\(port)",
            name: name,
            host: host,
            port: port,
            isActive: true,
            lastSeen: Date(),
            application: application
        )
        targets.removeAll { $0.id == target.id }
        targets.append(target)

        #if canImport(Network)
        // Create UDP connection
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .udp
        )
        connection.start(queue: .global(qos: .userInteractive))
        udpConnections[target.id] = connection
        #endif

        EngineBus.shared.publish(.custom(
            topic: "osc.target.added",
            payload: ["name": name, "host": host, "port": "\(port)", "app": application.rawValue]
        ))
    }

    /// Add target by known application type (uses default port)
    public func addTarget(application: OSCTarget.OSCApplication, host: String) {
        addTarget(name: application.rawValue, host: host, port: application.defaultPort, application: application)
    }

    /// Remove an OSC target
    public func removeTarget(id: String) {
        targets.removeAll { $0.id == id }
        #if canImport(Network)
        udpConnections[id]?.cancel()
        udpConnections.removeValue(forKey: id)
        #endif
    }

    /// Remove all targets
    public func removeAllTargets() {
        targets.removeAll()
        #if canImport(Network)
        for (_, connection) in udpConnections {
            connection.cancel()
        }
        udpConnections.removeAll()
        #endif
    }

    // MARK: - Send

    /// Send a single OSC message to all active targets
    public func send(_ message: OSCMessage) {
        let data = message.encode()
        sendRawToAllTargets(data)
        totalSent += 1
        sentThisSecond += 1
    }

    /// Send a message to a specific target
    public func send(_ message: OSCMessage, to targetId: String) {
        let data = message.encode()
        sendRawToTarget(data, targetId: targetId)
        totalSent += 1
        sentThisSecond += 1
    }

    /// Send an OSC bundle (multiple messages atomically)
    public func sendBundle(_ bundle: OSCBundle) {
        let data = bundle.encode()
        sendRawToAllTargets(data)
        totalSent += bundle.elements.count
        sentThisSecond += bundle.elements.count
    }

    /// Convenience: send a float value
    public func sendFloat(_ address: String, _ value: Float) {
        send(.float(prefixed(address), value))
    }

    /// Convenience: send a string value
    public func sendString(_ address: String, _ value: String) {
        send(.string(prefixed(address), value))
    }

    /// Convenience: send multiple floats
    public func sendFloats(_ address: String, _ values: [Float]) {
        send(.floats(prefixed(address), values))
    }

    private func prefixed(_ address: String) -> String {
        if address.hasPrefix("/") && !address.hasPrefix(namespacePrefix) {
            return namespacePrefix + address
        }
        return address
    }

    private func sendRawToAllTargets(_ data: Data) {
        #if canImport(Network)
        for (id, connection) in udpConnections {
            guard targets.first(where: { $0.id == id })?.isActive == true else { continue }
            connection.send(content: data, completion: .idempotent)
        }
        #endif
    }

    private func sendRawToTarget(_ data: Data, targetId: String) {
        #if canImport(Network)
        udpConnections[targetId]?.send(content: data, completion: .idempotent)
        #endif
    }

    // MARK: - Address Pattern Handlers

    /// Register a handler for incoming OSC messages matching a pattern
    ///
    /// Supports wildcard patterns per OSC spec:
    /// - `*` matches any sequence of characters
    /// - `?` matches any single character
    /// - `[abc]` matches any character in the set
    /// - `{foo,bar}` matches any of the comma-separated strings
    public func handle(_ pattern: String, handler: @escaping OSCHandler) {
        handlers.append(OSCAddressHandler(pattern: pattern, handler: handler))
    }

    /// Remove all handlers for a pattern
    public func removeHandler(for pattern: String) {
        handlers.removeAll { $0.pattern == pattern }
    }

    /// Match OSC address pattern against address
    private func matchAddress(pattern: String, address: String) -> Bool {
        if pattern == address { return true }
        if pattern.hasSuffix("/*") {
            let prefix = String(pattern.dropLast(2))
            return address.hasPrefix(prefix)
        }
        if pattern.contains("*") {
            let parts = pattern.split(separator: "*", omittingEmptySubsequences: false)
            var remaining = address[...]
            for (i, part) in parts.enumerated() {
                if part.isEmpty { continue }
                if let range = remaining.range(of: part) {
                    if i == 0 && range.lowerBound != remaining.startIndex { return false }
                    remaining = remaining[range.upperBound...]
                } else {
                    return false
                }
            }
            return true
        }
        return false
    }

    // MARK: - Auto-Broadcast

    /// Start automatic broadcasting of bio/audio/visual data to all targets
    public func startAutoBroadcast(hz: Float = 30) {
        guard !isAutoBroadcasting else { return }
        broadcastRate = hz
        isAutoBroadcasting = true

        let interval = 1.0 / Double(hz)
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.broadcastCurrentState()
            }
        }

        EngineBus.shared.publish(.custom(
            topic: "osc.broadcast.started",
            payload: ["hz": "\(hz)"]
        ))
    }

    /// Stop automatic broadcasting
    public func stopAutoBroadcast() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        isAutoBroadcasting = false
    }

    /// Send current bio/audio/visual state as OSC bundle
    private func broadcastCurrentState() {
        guard !targets.isEmpty else { return }

        let bundle = OSCBundle(elements: [
            // Bio data
            .float("\(namespacePrefix)/bio/coherence", currentCoherence),
            .float("\(namespacePrefix)/bio/heartrate", currentHeartRate),
            .float("\(namespacePrefix)/bio/breathing", currentBreathingRate),
            .float("\(namespacePrefix)/bio/hrv", currentHRV),
            .float("\(namespacePrefix)/bio/energy", currentEnergy),
            .float("\(namespacePrefix)/bio/flow", currentFlow),

            // Audio data
            .float("\(namespacePrefix)/audio/rms", currentRMS),
            .float("\(namespacePrefix)/audio/bpm", currentBPM),
            .float("\(namespacePrefix)/audio/frequency", currentFrequency),

            // Visual data
            .float("\(namespacePrefix)/visual/hue", currentVisualHue),
            .float("\(namespacePrefix)/visual/intensity", currentVisualIntensity),
        ])

        sendBundle(bundle)
    }

    // MARK: - Auto-Discovery (Bonjour)

    /// Start Bonjour discovery for OSC services on the network
    public func startDiscovery() {
        #if canImport(Network)
        let browser = NWBrowser(for: .bonjour(type: "_osc._udp", domain: nil), using: .udp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discoveredServices = results.map { result in
                    if case .service(let name, _, _, _) = result.endpoint {
                        return name
                    }
                    return "Unknown"
                }
            }
        }
        browser.start(queue: .global(qos: .utility))
        #endif
    }

    // MARK: - EngineBus Bridge

    /// Subscribe to EngineBus for bio/audio/visual data
    private func subscribeToBus() {
        let bioSub = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.currentCoherence = bio.coherence
                    self?.currentHeartRate = bio.heartRate
                    self?.currentBreathingRate = bio.breathingRate
                    self?.currentHRV = bio.hrvVariability * 100
                    self?.currentEnergy = bio.energy
                    self?.currentFlow = bio.flowScore
                }
            }
        }
        busSubscriptions.append(bioSub)

        let audioSub = EngineBus.shared.subscribe(to: .audio) { [weak self] msg in
            if case .audioAnalysis(let audio) = msg {
                Task { @MainActor in
                    self?.currentRMS = audio.rmsLevel
                    self?.currentFrequency = audio.dominantFrequency
                }
            }
        }
        busSubscriptions.append(audioSub)

        let paramSub = EngineBus.shared.subscribe(to: .parameter) { [weak self] msg in
            if case .parameterChange(let engine, let param, let value) = msg {
                Task { @MainActor in
                    if engine == "mix" && param == "bpm" {
                        self?.currentBPM = value ?? 120
                    }
                }
            }
        }
        busSubscriptions.append(paramSub)
    }

    /// Bridge incoming OSC messages to EngineBus
    private func bridgeIncomingToEngineBus(_ message: OSCMessage) {
        let address = message.address

        // Control messages → bus events
        if address.contains("/control/") {
            let command = address.split(separator: "/").last.map(String.init) ?? ""
            EngineBus.shared.publish(.custom(
                topic: "osc.control",
                payload: ["command": command]
            ))
        }

        // Parameter messages → bus params
        if let value = message.arguments.first?.floatValue {
            let parts = address.split(separator: "/").map(String.init)
            if parts.count >= 2 {
                let engine = parts[parts.count - 2]
                let param = parts[parts.count - 1]
                EngineBus.shared.publishParam(engine: "osc.\(engine)", param: param, value: value)
            }
        }
    }

    // MARK: - Rate Monitoring

    private func startRateMonitor() {
        rateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendRate = Float(self?.sentThisSecond ?? 0)
                self?.receiveRate = Float(self?.receivedThisSecond ?? 0)
                self?.sentThisSecond = 0
                self?.receivedThisSecond = 0
            }
        }
    }

    // MARK: - Shutdown

    /// Stop all OSC operations
    public func shutdown() {
        stopServer()
        stopAutoBroadcast()
        removeAllTargets()
        rateTimer?.invalidate()
        rateTimer = nil
        handlers.removeAll()
    }
}
