import Foundation
import Network
import Combine

/// Open Sound Control (OSC) Integration
/// Enables communication with VJ software, DAWs, and other creative tools
///
/// Supported applications:
/// - TouchDesigner
/// - Resolume Avenue/Arena
/// - VDMX
/// - Max/MSP
/// - Ableton Live (with OSC plugins)
/// - Processing
/// - openFrameworks
///
/// Protocol: OSC 1.0 over UDP/TCP
/// Default ports: 8000 (send), 9000 (receive)

// MARK: - OSC Message

/// OSC message structure
public struct OSCMessage {
    public let address: String // e.g., "/blab/hrv/coherence"
    public let arguments: [OSCArgument]
    public let timestamp: Date

    public init(address: String, arguments: [OSCArgument], timestamp: Date = Date()) {
        self.address = address
        self.arguments = arguments
        self.timestamp = timestamp
    }

    /// Encode to OSC binary format
    func encode() -> Data {
        var data = Data()

        // Address pattern (null-terminated, 4-byte aligned)
        data.append(address.oscString())

        // Type tag string
        var typeTag = ","
        for arg in arguments {
            typeTag += arg.typeTag
        }
        data.append(typeTag.oscString())

        // Arguments
        for arg in arguments {
            data.append(arg.data())
        }

        return data
    }

    /// Decode from OSC binary format
    static func decode(from data: Data) throws -> OSCMessage {
        var offset = 0

        // Read address
        guard let address = data.readOSCString(at: &offset) else {
            throw OSCError.invalidFormat
        }

        // Read type tag
        guard let typeTag = data.readOSCString(at: &offset) else {
            throw OSCError.invalidFormat
        }

        guard typeTag.hasPrefix(",") else {
            throw OSCError.invalidTypeTag
        }

        // Parse arguments
        var arguments: [OSCArgument] = []
        for char in typeTag.dropFirst() {
            let arg = try OSCArgument.read(type: char, from: data, offset: &offset)
            arguments.append(arg)
        }

        return OSCMessage(address: address, arguments: arguments)
    }
}

/// OSC argument types
public enum OSCArgument {
    case int(Int32)
    case float(Float)
    case string(String)
    case blob(Data)
    case true
    case false
    case null
    case impulse

    var typeTag: Character {
        switch self {
        case .int: return "i"
        case .float: return "f"
        case .string: return "s"
        case .blob: return "b"
        case .true: return "T"
        case .false: return "F"
        case .null: return "N"
        case .impulse: return "I"
        }
    }

    func data() -> Data {
        var data = Data()

        switch self {
        case .int(let value):
            var bigEndian = value.bigEndian
            data.append(Data(bytes: &bigEndian, count: 4))

        case .float(let value):
            var bigEndian = value.bitPattern.bigEndian
            data.append(Data(bytes: &bigEndian, count: 4))

        case .string(let value):
            data.append(value.oscString())

        case .blob(let value):
            var size = Int32(value.count).bigEndian
            data.append(Data(bytes: &size, count: 4))
            data.append(value)
            // Pad to 4-byte boundary
            while data.count % 4 != 0 {
                data.append(0)
            }

        case .true, .false, .null, .impulse:
            // No data for these types
            break
        }

        return data
    }

    static func read(type: Character, from data: Data, offset: inout Int) throws -> OSCArgument {
        switch type {
        case "i":
            guard offset + 4 <= data.count else { throw OSCError.insufficientData }
            let value = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
                Int32(bigEndian: $0.load(as: Int32.self))
            }
            offset += 4
            return .int(value)

        case "f":
            guard offset + 4 <= data.count else { throw OSCError.insufficientData }
            let bits = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
                UInt32(bigEndian: $0.load(as: UInt32.self))
            }
            offset += 4
            return .float(Float(bitPattern: bits))

        case "s":
            guard let string = data.readOSCString(at: &offset) else {
                throw OSCError.invalidFormat
            }
            return .string(string)

        case "b":
            guard offset + 4 <= data.count else { throw OSCError.insufficientData }
            let size = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
                Int(Int32(bigEndian: $0.load(as: Int32.self)))
            }
            offset += 4

            guard offset + size <= data.count else { throw OSCError.insufficientData }
            let blob = data.subdata(in: offset..<(offset + size))
            offset += size

            // Skip padding
            while offset % 4 != 0 && offset < data.count {
                offset += 1
            }

            return .blob(blob)

        case "T": return .true
        case "F": return .false
        case "N": return .null
        case "I": return .impulse

        default:
            throw OSCError.unsupportedType
        }
    }
}

// MARK: - OSC Bundle

/// OSC bundle (multiple messages with timestamp)
public struct OSCBundle {
    public let timestamp: Date
    public let elements: [OSCElement]

    public enum OSCElement {
        case message(OSCMessage)
        case bundle(OSCBundle)
    }

    func encode() -> Data {
        var data = Data()

        // Bundle header
        data.append("#bundle\0".data(using: .ascii)!)

        // Timestamp (NTP format)
        let ntpTime = timestamp.ntpTimestamp()
        var ntpBigEndian = ntpTime.bigEndian
        data.append(Data(bytes: &ntpBigEndian, count: 8))

        // Elements
        for element in elements {
            let elementData: Data
            switch element {
            case .message(let msg):
                elementData = msg.encode()
            case .bundle(let bundle):
                elementData = bundle.encode()
            }

            var size = Int32(elementData.count).bigEndian
            data.append(Data(bytes: &size, count: 4))
            data.append(elementData)
        }

        return data
    }
}

// MARK: - OSC Manager

/// Main OSC communication manager
@MainActor
public final class OSCManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var sendPort: UInt16 = 8000
    @Published public private(set) var receivePort: UInt16 = 9000
    @Published public var remoteHost: String = "127.0.0.1"

    // MARK: - Private Properties

    private var sendConnection: NWConnection?
    private var receiveListener: NWListener?
    private var receiveConnections: [NWConnection] = []

    private let queue = DispatchQueue(label: "com.echoel.osc", qos: .userInitiated)

    // Message handlers
    private var messageHandlers: [String: (OSCMessage) -> Void] = [:]

    // Statistics
    private var messagesSent: Int = 0
    private var messagesReceived: Int = 0

    // MARK: - Initialization

    public init(sendPort: UInt16 = 8000, receivePort: UInt16 = 9000) {
        self.sendPort = sendPort
        self.receivePort = receivePort
    }

    // MARK: - Connection Management

    /// Start OSC communication (sender + receiver)
    public func start() {
        startSender()
        startReceiver()
        isConnected = true
        print("🎛️ OSC Manager started")
        print("   Sending to: \(remoteHost):\(sendPort)")
        print("   Receiving on: *:\(receivePort)")
    }

    /// Stop OSC communication
    public func stop() {
        sendConnection?.cancel()
        sendConnection = nil

        receiveListener?.cancel()
        receiveListener = nil

        for conn in receiveConnections {
            conn.cancel()
        }
        receiveConnections.removeAll()

        isConnected = false
        print("🎛️ OSC Manager stopped")
        print("   Messages sent: \(messagesSent)")
        print("   Messages received: \(messagesReceived)")
    }

    private func startSender() {
        let host = NWEndpoint.Host(remoteHost)
        let port = NWEndpoint.Port(integerLiteral: sendPort)

        sendConnection = NWConnection(host: host, port: port, using: .udp)

        sendConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ OSC sender ready")
            case .failed(let error):
                print("❌ OSC sender failed: \(error)")
            default:
                break
            }
        }

        sendConnection?.start(queue: queue)
    }

    private func startReceiver() {
        do {
            let params = NWParameters.udp
            receiveListener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: receivePort))

            receiveListener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            receiveListener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("✅ OSC receiver listening on port \(self?.receivePort ?? 0)")
                case .failed(let error):
                    print("❌ OSC receiver failed: \(error)")
                default:
                    break
                }
            }

            receiveListener?.start(queue: queue)

        } catch {
            print("❌ Failed to start OSC receiver: \(error)")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        receiveConnections.append(connection)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveData(from: connection)
            }
        }

        connection.start(queue: queue)
    }

    // MARK: - Sending Messages

    /// Send an OSC message
    public func send(_ message: OSCMessage) {
        guard let connection = sendConnection else {
            print("⚠️ OSC not connected")
            return
        }

        let data = message.encode()

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ OSC send error: \(error)")
            } else {
                self?.messagesSent += 1
            }
        })
    }

    /// Send a simple float value
    public func send(address: String, value: Float) {
        let message = OSCMessage(address: address, arguments: [.float(value)])
        send(message)
    }

    /// Send an int value
    public func send(address: String, value: Int32) {
        let message = OSCMessage(address: address, arguments: [.int(value)])
        send(message)
    }

    /// Send a string value
    public func send(address: String, value: String) {
        let message = OSCMessage(address: address, arguments: [.string(value)])
        send(message)
    }

    /// Send multiple values
    public func send(address: String, values: [OSCArgument]) {
        let message = OSCMessage(address: address, arguments: values)
        send(message)
    }

    // MARK: - Receiving Messages

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data)
            }

            if !isComplete {
                self?.receiveData(from: connection)
            }

            if let error = error {
                print("❌ OSC receive error: \(error)")
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        do {
            let message = try OSCMessage.decode(from: data)
            messagesReceived += 1

            // Call registered handler
            if let handler = messageHandlers[message.address] {
                Task { @MainActor in
                    handler(message)
                }
            } else if let wildcardHandler = messageHandlers["*"] {
                Task { @MainActor in
                    wildcardHandler(message)
                }
            }

        } catch {
            print("⚠️ Failed to decode OSC message: \(error)")
        }
    }

    /// Register a handler for OSC messages at a specific address
    public func onMessage(address: String, handler: @escaping (OSCMessage) -> Void) {
        messageHandlers[address] = handler
    }

    /// Register a handler for all OSC messages
    public func onAnyMessage(handler: @escaping (OSCMessage) -> Void) {
        messageHandlers["*"] = handler
    }

    // MARK: - BLAB Integration

    /// Send biofeedback data
    public func sendBiofeedback(hrv: Float, heartRate: Float, coherence: Float) {
        send(address: "/blab/bio/hrv", value: hrv)
        send(address: "/blab/bio/heartrate", value: heartRate)
        send(address: "/blab/bio/coherence", value: coherence)
    }

    /// Send visual parameters
    public func sendVisualParameters(hue: Float, brightness: Float, saturation: Float) {
        send(address: "/blab/visual/hue", value: hue)
        send(address: "/blab/visual/brightness", value: brightness)
        send(address: "/blab/visual/saturation", value: saturation)
    }

    /// Send audio parameters
    public func sendAudioParameters(level: Float, pitch: Float, filter: Float) {
        send(address: "/blab/audio/level", value: level)
        send(address: "/blab/audio/pitch", value: pitch)
        send(address: "/blab/audio/filter", value: filter)
    }

    /// Send gesture data
    public func sendGesture(x: Float, y: Float, z: Float) {
        send(address: "/blab/gesture/position", values: [.float(x), .float(y), .float(z)])
    }
}

// MARK: - OSC Errors

public enum OSCError: Error {
    case invalidFormat
    case invalidTypeTag
    case insufficientData
    case unsupportedType
}

// MARK: - Helper Extensions

extension String {
    /// Encode string as OSC string (null-terminated, 4-byte aligned)
    func oscString() -> Data {
        var data = self.data(using: .ascii) ?? Data()
        data.append(0) // Null terminator

        // Pad to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }

        return data
    }
}

extension Data {
    /// Read OSC string at offset
    func readOSCString(at offset: inout Int) -> String? {
        var endIndex = offset

        // Find null terminator
        while endIndex < count && self[endIndex] != 0 {
            endIndex += 1
        }

        guard endIndex < count else { return nil }

        let stringData = subdata(in: offset..<endIndex)
        let string = String(data: stringData, encoding: .ascii)

        // Skip to next 4-byte boundary
        offset = endIndex + 1
        while offset % 4 != 0 {
            offset += 1
        }

        return string
    }
}

extension Date {
    /// Convert to NTP timestamp (seconds since 1900-01-01)
    func ntpTimestamp() -> UInt64 {
        let secondsSince1900 = self.timeIntervalSince1970 + 2208988800.0
        let seconds = UInt32(secondsSince1900)
        let fraction = UInt32((secondsSince1900 - Double(seconds)) * 4294967296.0)
        return (UInt64(seconds) << 32) | UInt64(fraction)
    }
}
