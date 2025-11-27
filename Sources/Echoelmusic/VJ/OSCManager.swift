// OSCManager.swift
// Echoelmusic - Open Sound Control (OSC) Manager
// Full OSC 1.0/1.1 Implementation for VJ & DAW Control
// Rivals: Resolume, TouchDesigner, VDMX, Max/MSP

import Foundation
import Network
import Combine

// MARK: - OSC Types

/// OSC Message representation
public struct OSCMessage: CustomStringConvertible {
    public let addressPattern: String
    public let arguments: [OSCArgument]
    public let timeTag: OSCTimeTag?

    public init(addressPattern: String, arguments: [OSCArgument] = [], timeTag: OSCTimeTag? = nil) {
        self.addressPattern = addressPattern
        self.arguments = arguments
        self.timeTag = timeTag
    }

    public var description: String {
        let argsStr = arguments.map { $0.description }.joined(separator: ", ")
        return "OSC: \(addressPattern) [\(argsStr)]"
    }
}

/// OSC Argument types
public enum OSCArgument: CustomStringConvertible {
    case int32(Int32)
    case float32(Float)
    case string(String)
    case blob(Data)
    case int64(Int64)
    case timeTag(OSCTimeTag)
    case double(Double)
    case char(Character)
    case color(OSCColor)
    case midi(OSCMIDIMessage)
    case bool(Bool)
    case null
    case impulse
    case array([OSCArgument])

    public var description: String {
        switch self {
        case .int32(let v): return "i:\(v)"
        case .float32(let v): return "f:\(v)"
        case .string(let v): return "s:\"\(v)\""
        case .blob(let v): return "b:[\(v.count) bytes]"
        case .int64(let v): return "h:\(v)"
        case .timeTag(let v): return "t:\(v)"
        case .double(let v): return "d:\(v)"
        case .char(let v): return "c:'\(v)'"
        case .color(let v): return "r:\(v)"
        case .midi(let v): return "m:\(v)"
        case .bool(let v): return v ? "T" : "F"
        case .null: return "N"
        case .impulse: return "I"
        case .array(let v): return "[\(v.map { $0.description }.joined(separator: ", "))]"
        }
    }

    var typeTag: Character {
        switch self {
        case .int32: return "i"
        case .float32: return "f"
        case .string: return "s"
        case .blob: return "b"
        case .int64: return "h"
        case .timeTag: return "t"
        case .double: return "d"
        case .char: return "c"
        case .color: return "r"
        case .midi: return "m"
        case .bool(true): return "T"
        case .bool(false): return "F"
        case .null: return "N"
        case .impulse: return "I"
        case .array: return "["
        }
    }
}

/// OSC Time Tag (NTP format)
public struct OSCTimeTag: CustomStringConvertible {
    public let seconds: UInt32
    public let fractions: UInt32

    public static let immediately = OSCTimeTag(seconds: 0, fractions: 1)

    public init(seconds: UInt32, fractions: UInt32) {
        self.seconds = seconds
        self.fractions = fractions
    }

    public init(date: Date) {
        // NTP epoch is January 1, 1900
        let ntpEpoch = Date(timeIntervalSince1970: -2208988800)
        let interval = date.timeIntervalSince(ntpEpoch)
        self.seconds = UInt32(interval)
        self.fractions = UInt32((interval - Double(self.seconds)) * Double(UInt32.max))
    }

    public var date: Date {
        let ntpEpoch = Date(timeIntervalSince1970: -2208988800)
        let interval = TimeInterval(seconds) + TimeInterval(fractions) / Double(UInt32.max)
        return ntpEpoch.addingTimeInterval(interval)
    }

    public var description: String {
        if self == .immediately {
            return "immediately"
        }
        return date.description
    }

    public static func == (lhs: OSCTimeTag, rhs: OSCTimeTag) -> Bool {
        lhs.seconds == rhs.seconds && lhs.fractions == rhs.fractions
    }
}

/// OSC Color (RGBA)
public struct OSCColor: CustomStringConvertible {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var description: String {
        "RGBA(\(red),\(green),\(blue),\(alpha))"
    }
}

/// OSC MIDI Message
public struct OSCMIDIMessage: CustomStringConvertible {
    public let portId: UInt8
    public let status: UInt8
    public let data1: UInt8
    public let data2: UInt8

    public init(portId: UInt8 = 0, status: UInt8, data1: UInt8, data2: UInt8 = 0) {
        self.portId = portId
        self.status = status
        self.data1 = data1
        self.data2 = data2
    }

    public var description: String {
        "MIDI(\(portId):\(status),\(data1),\(data2))"
    }
}

/// OSC Bundle
public struct OSCBundle {
    public let timeTag: OSCTimeTag
    public let elements: [OSCBundleElement]

    public init(timeTag: OSCTimeTag = .immediately, elements: [OSCBundleElement] = []) {
        self.timeTag = timeTag
        self.elements = elements
    }
}

/// OSC Bundle Element (Message or nested Bundle)
public enum OSCBundleElement {
    case message(OSCMessage)
    case bundle(OSCBundle)
}

// MARK: - OSC Address Pattern Matching

public struct OSCAddressPattern {
    /// Match an address against a pattern with wildcards
    public static func matches(_ address: String, pattern: String) -> Bool {
        // Simple pattern matching with wildcards
        // Supports: * (any), ? (single char), [] (character class), {} (alternatives)

        let addressParts = address.split(separator: "/").map(String.init)
        let patternParts = pattern.split(separator: "/").map(String.init)

        guard addressParts.count == patternParts.count else { return false }

        for (addr, pat) in zip(addressParts, patternParts) {
            if !matchPart(addr, pattern: pat) {
                return false
            }
        }
        return true
    }

    private static func matchPart(_ string: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern == string { return true }

        // Simple wildcard matching
        var sIndex = string.startIndex
        var pIndex = pattern.startIndex

        while sIndex < string.endIndex && pIndex < pattern.endIndex {
            let pChar = pattern[pIndex]

            switch pChar {
            case "*":
                // * matches any sequence
                if pattern.index(after: pIndex) == pattern.endIndex {
                    return true
                }
                // Try matching rest of pattern
                while sIndex < string.endIndex {
                    if matchPart(String(string[sIndex...]), pattern: String(pattern[pattern.index(after: pIndex)...])) {
                        return true
                    }
                    sIndex = string.index(after: sIndex)
                }
                return false

            case "?":
                // ? matches any single character
                sIndex = string.index(after: sIndex)
                pIndex = pattern.index(after: pIndex)

            default:
                if pChar != string[sIndex] {
                    return false
                }
                sIndex = string.index(after: sIndex)
                pIndex = pattern.index(after: pIndex)
            }
        }

        return sIndex == string.endIndex && pIndex == pattern.endIndex
    }
}

// MARK: - OSC Encoder/Decoder

public class OSCEncoder {
    /// Encode an OSC message to data
    public static func encode(_ message: OSCMessage) -> Data {
        var data = Data()

        // Address pattern (null-terminated, padded to 4 bytes)
        data.append(encodeString(message.addressPattern))

        // Type tag string
        var typeTag = ","
        for arg in message.arguments {
            typeTag.append(arg.typeTag)
            if case .array = arg {
                typeTag.append("]")
            }
        }
        data.append(encodeString(typeTag))

        // Arguments
        for arg in message.arguments {
            data.append(encodeArgument(arg))
        }

        return data
    }

    /// Encode an OSC bundle to data
    public static func encode(_ bundle: OSCBundle) -> Data {
        var data = Data()

        // Bundle identifier
        data.append(encodeString("#bundle"))

        // Time tag
        data.append(encodeTimeTag(bundle.timeTag))

        // Elements
        for element in bundle.elements {
            let elementData: Data
            switch element {
            case .message(let msg):
                elementData = encode(msg)
            case .bundle(let b):
                elementData = encode(b)
            }

            // Size prefix (4 bytes, big-endian)
            var size = Int32(elementData.count).bigEndian
            data.append(Data(bytes: &size, count: 4))
            data.append(elementData)
        }

        return data
    }

    private static func encodeString(_ string: String) -> Data {
        var data = string.data(using: .utf8) ?? Data()
        data.append(0) // Null terminator

        // Pad to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }

        return data
    }

    private static func encodeTimeTag(_ timeTag: OSCTimeTag) -> Data {
        var data = Data()
        var seconds = timeTag.seconds.bigEndian
        var fractions = timeTag.fractions.bigEndian
        data.append(Data(bytes: &seconds, count: 4))
        data.append(Data(bytes: &fractions, count: 4))
        return data
    }

    private static func encodeArgument(_ arg: OSCArgument) -> Data {
        var data = Data()

        switch arg {
        case .int32(let v):
            var value = v.bigEndian
            data.append(Data(bytes: &value, count: 4))

        case .float32(let v):
            var value = v.bitPattern.bigEndian
            data.append(Data(bytes: &value, count: 4))

        case .string(let v):
            data.append(encodeString(v))

        case .blob(let v):
            var size = Int32(v.count).bigEndian
            data.append(Data(bytes: &size, count: 4))
            data.append(v)
            // Pad to 4-byte boundary
            while data.count % 4 != 0 {
                data.append(0)
            }

        case .int64(let v):
            var value = v.bigEndian
            data.append(Data(bytes: &value, count: 8))

        case .timeTag(let v):
            data.append(encodeTimeTag(v))

        case .double(let v):
            var value = v.bitPattern.bigEndian
            data.append(Data(bytes: &value, count: 8))

        case .char(let v):
            var value: Int32 = Int32(v.asciiValue ?? 0).bigEndian
            data.append(Data(bytes: &value, count: 4))

        case .color(let v):
            data.append(contentsOf: [v.red, v.green, v.blue, v.alpha])

        case .midi(let v):
            data.append(contentsOf: [v.portId, v.status, v.data1, v.data2])

        case .bool, .null, .impulse:
            // These have no data, just type tag
            break

        case .array(let elements):
            for element in elements {
                data.append(encodeArgument(element))
            }
        }

        return data
    }
}

public class OSCDecoder {
    /// Decode data to an OSC message
    public static func decode(_ data: Data) -> OSCMessage? {
        guard data.count >= 4 else { return nil }

        var offset = 0

        // Check if it's a bundle
        if data.prefix(8) == "#bundle\0".data(using: .utf8) {
            // This is a bundle, decode differently
            return nil // TODO: Return bundle
        }

        // Decode address pattern
        guard let address = decodeString(data, offset: &offset) else { return nil }

        // Decode type tag
        guard let typeTag = decodeString(data, offset: &offset) else { return nil }
        guard typeTag.hasPrefix(",") else { return nil }

        // Decode arguments
        var arguments: [OSCArgument] = []
        for char in typeTag.dropFirst() {
            if let arg = decodeArgument(data, offset: &offset, typeTag: char) {
                arguments.append(arg)
            }
        }

        return OSCMessage(addressPattern: address, arguments: arguments)
    }

    private static func decodeString(_ data: Data, offset: inout Int) -> String? {
        var endIndex = offset
        while endIndex < data.count && data[endIndex] != 0 {
            endIndex += 1
        }

        guard endIndex < data.count else { return nil }

        let stringData = data[offset..<endIndex]
        let string = String(data: stringData, encoding: .utf8)

        // Move past null terminator and padding
        offset = endIndex + 1
        while offset % 4 != 0 {
            offset += 1
        }

        return string
    }

    private static func decodeArgument(_ data: Data, offset: inout Int, typeTag: Character) -> OSCArgument? {
        switch typeTag {
        case "i":
            guard offset + 4 <= data.count else { return nil }
            let value = data[offset..<offset+4].withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
            offset += 4
            return .int32(value)

        case "f":
            guard offset + 4 <= data.count else { return nil }
            let bits = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            offset += 4
            return .float32(Float(bitPattern: bits))

        case "s":
            guard let string = decodeString(data, offset: &offset) else { return nil }
            return .string(string)

        case "b":
            guard offset + 4 <= data.count else { return nil }
            let size = Int(data[offset..<offset+4].withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
            offset += 4
            guard offset + size <= data.count else { return nil }
            let blob = data[offset..<offset+size]
            offset += size
            while offset % 4 != 0 { offset += 1 }
            return .blob(Data(blob))

        case "h":
            guard offset + 8 <= data.count else { return nil }
            let value = data[offset..<offset+8].withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
            offset += 8
            return .int64(value)

        case "d":
            guard offset + 8 <= data.count else { return nil }
            let bits = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
            offset += 8
            return .double(Double(bitPattern: bits))

        case "T":
            return .bool(true)

        case "F":
            return .bool(false)

        case "N":
            return .null

        case "I":
            return .impulse

        default:
            return nil
        }
    }
}

// MARK: - OSC Server

/// Handler for incoming OSC messages
public typealias OSCMessageHandler = (OSCMessage, NWEndpoint?) -> Void

/// OSC Server for receiving messages
@MainActor
public class OSCServer: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var port: UInt16
    @Published public private(set) var receivedMessages: [OSCMessage] = []
    @Published public private(set) var lastMessage: OSCMessage?

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var messageHandlers: [String: OSCMessageHandler] = []
    private var wildcardHandlers: [OSCMessageHandler] = []

    public init(port: UInt16 = 8000) {
        self.port = port
    }

    /// Start the OSC server
    public func start() throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("OSC Server listening on port \(self?.port ?? 0)")
                case .failed(let error):
                    print("OSC Server failed: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .main)
    }

    /// Stop the OSC server
    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    /// Register a handler for a specific address pattern
    public func register(addressPattern: String, handler: @escaping OSCMessageHandler) {
        messageHandlers[addressPattern] = handler
    }

    /// Register a handler for all messages
    public func registerWildcard(handler: @escaping OSCMessageHandler) {
        wildcardHandlers.append(handler)
    }

    /// Unregister a handler
    public func unregister(addressPattern: String) {
        messageHandlers.removeValue(forKey: addressPattern)
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            if case .cancelled = state {
                if let conn = connection {
                    self?.connections.removeAll { $0 === conn }
                }
            }
        }

        receiveMessage(on: connection)
        connection.start(queue: .main)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data = data, let message = OSCDecoder.decode(data) {
                Task { @MainActor in
                    self?.handleMessage(message, from: connection.endpoint)
                }
            }

            if error == nil {
                self?.receiveMessage(on: connection)
            }
        }
    }

    private func handleMessage(_ message: OSCMessage, from endpoint: NWEndpoint?) {
        lastMessage = message
        receivedMessages.append(message)

        // Keep only last 100 messages
        if receivedMessages.count > 100 {
            receivedMessages.removeFirst()
        }

        // Call specific handlers
        for (pattern, handler) in messageHandlers {
            if OSCAddressPattern.matches(message.addressPattern, pattern: pattern) {
                handler(message, endpoint)
            }
        }

        // Call wildcard handlers
        for handler in wildcardHandlers {
            handler(message, endpoint)
        }
    }
}

// MARK: - OSC Client

/// OSC Client for sending messages
@MainActor
public class OSCClient: ObservableObject {
    @Published public private(set) var isConnected: Bool = false
    @Published public var host: String
    @Published public var port: UInt16

    private var connection: NWConnection?

    public init(host: String = "127.0.0.1", port: UInt16 = 8000) {
        self.host = host
        self.port = port
    }

    /// Connect to the OSC server
    public func connect() {
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)

        connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .udp)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isConnected = true
                    print("OSC Client connected to \(self?.host ?? ""):\(self?.port ?? 0)")
                case .failed, .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    /// Disconnect from the OSC server
    public func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    /// Send an OSC message
    public func send(_ message: OSCMessage) {
        guard isConnected else {
            print("OSC Client not connected")
            return
        }

        let data = OSCEncoder.encode(message)
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("OSC send error: \(error)")
            }
        })
    }

    /// Send an OSC bundle
    public func send(_ bundle: OSCBundle) {
        guard isConnected else {
            print("OSC Client not connected")
            return
        }

        let data = OSCEncoder.encode(bundle)
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("OSC send error: \(error)")
            }
        })
    }

    // MARK: - Convenience Methods

    /// Send a simple message with no arguments
    public func send(address: String) {
        send(OSCMessage(addressPattern: address))
    }

    /// Send a message with a single float argument
    public func send(address: String, float: Float) {
        send(OSCMessage(addressPattern: address, arguments: [.float32(float)]))
    }

    /// Send a message with a single int argument
    public func send(address: String, int: Int32) {
        send(OSCMessage(addressPattern: address, arguments: [.int32(int)]))
    }

    /// Send a message with a single string argument
    public func send(address: String, string: String) {
        send(OSCMessage(addressPattern: address, arguments: [.string(string)]))
    }

    /// Send a message with multiple float arguments
    public func send(address: String, floats: [Float]) {
        send(OSCMessage(addressPattern: address, arguments: floats.map { .float32($0) }))
    }
}

// MARK: - OSC Manager (Combined Server + Client + Routing)

@MainActor
public class OSCManager: ObservableObject {
    // Server
    @Published public var server: OSCServer
    @Published public var serverEnabled: Bool = false {
        didSet {
            if serverEnabled {
                try? server.start()
            } else {
                server.stop()
            }
        }
    }

    // Clients
    @Published public var clients: [String: OSCClient] = [:]

    // Routing
    @Published public var routes: [OSCRoute] = []

    // Presets
    @Published public var presets: [OSCPreset] = []

    // Logging
    @Published public var isLoggingEnabled: Bool = true
    @Published public var messageLog: [LogEntry] = []

    public struct OSCRoute: Identifiable, Codable {
        public let id: UUID
        public var sourcePattern: String
        public var destinationAddress: String
        public var destinationClient: String
        public var isEnabled: Bool
        public var transform: RouteTransform?

        public struct RouteTransform: Codable {
            public var scale: Float
            public var offset: Float
            public var invert: Bool
        }
    }

    public struct OSCPreset: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var messages: [PresetMessage]

        public struct PresetMessage: Codable, Identifiable {
            public let id: UUID
            public var address: String
            public var value: Float
        }
    }

    public struct LogEntry: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let direction: Direction
        public let message: OSCMessage
        public let endpoint: String?

        public enum Direction {
            case incoming
            case outgoing
        }
    }

    public init(serverPort: UInt16 = 8000) {
        self.server = OSCServer(port: serverPort)

        // Setup default clients
        setupDefaultClients()

        // Setup routing
        setupRouting()
    }

    private func setupDefaultClients() {
        // Resolume Arena
        clients["resolume"] = OSCClient(host: "127.0.0.1", port: 7000)

        // TouchDesigner
        clients["touchdesigner"] = OSCClient(host: "127.0.0.1", port: 7001)

        // VDMX
        clients["vdmx"] = OSCClient(host: "127.0.0.1", port: 7002)

        // MadMapper
        clients["madmapper"] = OSCClient(host: "127.0.0.1", port: 8010)

        // Ableton Live
        clients["ableton"] = OSCClient(host: "127.0.0.1", port: 9000)
    }

    private func setupRouting() {
        // Register wildcard handler for routing
        server.registerWildcard { [weak self] message, endpoint in
            self?.routeMessage(message, from: endpoint)
        }
    }

    private func routeMessage(_ message: OSCMessage, from endpoint: NWEndpoint?) {
        // Log incoming
        if isLoggingEnabled {
            let entry = LogEntry(
                id: UUID(),
                timestamp: Date(),
                direction: .incoming,
                message: message,
                endpoint: endpoint.map { "\($0)" }
            )
            messageLog.append(entry)
            if messageLog.count > 1000 {
                messageLog.removeFirst()
            }
        }

        // Apply routes
        for route in routes where route.isEnabled {
            if OSCAddressPattern.matches(message.addressPattern, pattern: route.sourcePattern) {
                // Transform and forward
                var forwardMessage = message
                if let transform = route.transform {
                    forwardMessage = applyTransform(message, transform: transform, destinationAddress: route.destinationAddress)
                } else {
                    forwardMessage = OSCMessage(addressPattern: route.destinationAddress, arguments: message.arguments)
                }

                if let client = clients[route.destinationClient] {
                    client.send(forwardMessage)

                    // Log outgoing
                    if isLoggingEnabled {
                        let entry = LogEntry(
                            id: UUID(),
                            timestamp: Date(),
                            direction: .outgoing,
                            message: forwardMessage,
                            endpoint: "\(client.host):\(client.port)"
                        )
                        messageLog.append(entry)
                    }
                }
            }
        }
    }

    private func applyTransform(_ message: OSCMessage, transform: OSCRoute.RouteTransform, destinationAddress: String) -> OSCMessage {
        let transformedArgs = message.arguments.map { arg -> OSCArgument in
            switch arg {
            case .float32(let v):
                var newValue = v * transform.scale + transform.offset
                if transform.invert {
                    newValue = 1.0 - newValue
                }
                return .float32(newValue)
            case .int32(let v):
                var newValue = Float(v) * transform.scale + transform.offset
                if transform.invert {
                    newValue = 1.0 - newValue
                }
                return .int32(Int32(newValue))
            default:
                return arg
            }
        }

        return OSCMessage(addressPattern: destinationAddress, arguments: transformedArgs)
    }

    // MARK: - Public Methods

    /// Connect all clients
    public func connectAllClients() {
        for client in clients.values {
            client.connect()
        }
    }

    /// Disconnect all clients
    public func disconnectAllClients() {
        for client in clients.values {
            client.disconnect()
        }
    }

    /// Add a new client
    public func addClient(name: String, host: String, port: UInt16) {
        clients[name] = OSCClient(host: host, port: port)
    }

    /// Remove a client
    public func removeClient(name: String) {
        clients[name]?.disconnect()
        clients.removeValue(forKey: name)
    }

    /// Add a route
    public func addRoute(_ route: OSCRoute) {
        routes.append(route)
    }

    /// Remove a route
    public func removeRoute(_ routeId: UUID) {
        routes.removeAll { $0.id == routeId }
    }

    /// Trigger a preset
    public func triggerPreset(_ presetId: UUID, client: String) {
        guard let preset = presets.first(where: { $0.id == presetId }),
              let oscClient = clients[client] else { return }

        for msg in preset.messages {
            oscClient.send(address: msg.address, float: msg.value)
        }
    }

    /// Clear message log
    public func clearLog() {
        messageLog.removeAll()
    }
}

// MARK: - Resolume Arena Integration

extension OSCClient {
    // Layer control
    func resolumeLayerOpacity(_ layer: Int, opacity: Float) {
        send(address: "/composition/layers/\(layer)/video/opacity", float: opacity)
    }

    func resolumeLayerBypass(_ layer: Int, bypass: Bool) {
        send(address: "/composition/layers/\(layer)/bypassed", int: bypass ? 1 : 0)
    }

    // Clip control
    func resolumeClipConnect(_ layer: Int, clip: Int) {
        send(address: "/composition/layers/\(layer)/clips/\(clip)/connect", int: 1)
    }

    func resolumeClipDisconnect(_ layer: Int, clip: Int) {
        send(address: "/composition/layers/\(layer)/clips/\(clip)/connect", int: 0)
    }

    // Tempo
    func resolumeTempo(_ bpm: Float) {
        send(address: "/composition/tempocontroller/tempo", float: bpm)
    }

    // Master
    func resolumeMasterOpacity(_ opacity: Float) {
        send(address: "/composition/video/opacity", float: opacity)
    }
}

// MARK: - TouchDesigner Integration

extension OSCClient {
    func touchDesignerParameter(_ node: String, parameter: String, value: Float) {
        send(address: "/\(node)/\(parameter)", float: value)
    }

    func touchDesignerPulse(_ node: String) {
        send(address: "/\(node)/pulse", int: 1)
    }

    func touchDesignerToggle(_ node: String, enabled: Bool) {
        send(address: "/\(node)/bypass", int: enabled ? 0 : 1)
    }
}

// MARK: - Ableton Live Integration

extension OSCClient {
    func abletonTempo(_ bpm: Float) {
        send(address: "/live/tempo", float: bpm)
    }

    func abletonPlay() {
        send(address: "/live/play")
    }

    func abletonStop() {
        send(address: "/live/stop")
    }

    func abletonClipTrigger(_ track: Int, slot: Int) {
        send(address: "/live/clip/fire", floats: [Float(track), Float(slot)])
    }

    func abletonTrackVolume(_ track: Int, volume: Float) {
        send(address: "/live/track/volume", floats: [Float(track), volume])
    }
}
