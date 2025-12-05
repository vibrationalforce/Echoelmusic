import Foundation
#if canImport(CoreMIDI)
import CoreMIDI
#endif
import Network

// MARK: - MIDI & OSC Controller
// Unified control surface management with MIDI Learn and OSC support
// Features: MIDI Learn, OSC server/client, mapping presets, gesture recognition

@MainActor
public final class MIDIOSCController: ObservableObject {
    public static let shared = MIDIOSCController()

    @Published public private(set) var connectedMIDIDevices: [MIDIDeviceInfo] = []
    @Published public private(set) var oscServerRunning = false
    @Published public private(set) var isLearning = false
    @Published public private(set) var learningParameter: String?
    @Published public private(set) var mappings: [ControlMapping] = []

    // MIDI
    #if canImport(CoreMIDI)
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    #endif

    // OSC
    private var oscServer: OSCServer?
    private var oscClients: [String: OSCClient] = [:]

    // MIDI Learn
    private var learnCallback: ((MIDIMessage) -> Void)?
    private var pendingLearnParameter: String?

    // Configuration
    public struct Configuration {
        public var oscServerPort: UInt16 = 8000
        public var oscClientPort: UInt16 = 9000
        public var enableMIDI: Bool = true
        public var enableOSC: Bool = true
        public var autoConnectMIDI: Bool = true
        public var midiThrough: Bool = false

        public static let `default` = Configuration()
    }

    private var config: Configuration = .default

    public init() {
        setupMIDI()
    }

    // MARK: - MIDI Setup

    private func setupMIDI() {
        #if canImport(CoreMIDI)
        guard config.enableMIDI else { return }

        // Create MIDI client
        let status = MIDIClientCreateWithBlock("EchoelMusic" as CFString, &midiClient) { [weak self] notification in
            Task { @MainActor in
                self?.handleMIDINotification(notification)
            }
        }

        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }

        // Create input port
        MIDIInputPortCreateWithProtocol(
            midiClient,
            "Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIInput(eventList)
        }

        // Create output port
        MIDIOutputPortCreate(midiClient, "Output" as CFString, &outputPort)

        // Scan for devices
        scanMIDIDevices()

        // Auto-connect if enabled
        if config.autoConnectMIDI {
            connectAllMIDIInputs()
        }
        #endif
    }

    #if canImport(CoreMIDI)
    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged:
            scanMIDIDevices()
        default:
            break
        }
    }

    private func handleMIDIInput(_ eventList: UnsafePointer<MIDIEventList>) {
        let events = eventList.unsafeSequence()

        for event in events {
            let message = parseMIDIEvent(event)

            // Handle MIDI Learn
            if isLearning {
                learnCallback?(message)
                continue
            }

            // Process through mappings
            processMessage(message)
        }
    }

    private func parseMIDIEvent(_ event: MIDIEventPacket) -> MIDIMessage {
        let words = event.words

        let status = UInt8((words.0 >> 16) & 0xFF)
        let data1 = UInt8((words.0 >> 8) & 0xFF)
        let data2 = UInt8(words.0 & 0xFF)

        let channel = status & 0x0F
        let messageType = status & 0xF0

        switch messageType {
        case 0x90 where data2 > 0:
            return MIDIMessage(type: .noteOn, channel: channel, data1: data1, data2: data2)
        case 0x90, 0x80:
            return MIDIMessage(type: .noteOff, channel: channel, data1: data1, data2: data2)
        case 0xB0:
            return MIDIMessage(type: .controlChange, channel: channel, data1: data1, data2: data2)
        case 0xE0:
            return MIDIMessage(type: .pitchBend, channel: channel, data1: data1, data2: data2)
        case 0xC0:
            return MIDIMessage(type: .programChange, channel: channel, data1: data1, data2: 0)
        case 0xD0:
            return MIDIMessage(type: .aftertouch, channel: channel, data1: data1, data2: 0)
        default:
            return MIDIMessage(type: .unknown, channel: channel, data1: data1, data2: data2)
        }
    }
    #endif

    // MARK: - MIDI Device Management

    public func scanMIDIDevices() {
        #if canImport(CoreMIDI)
        connectedMIDIDevices.removeAll()

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let info = getMIDIDeviceInfo(source) {
                connectedMIDIDevices.append(info)
            }
        }
        #endif
    }

    #if canImport(CoreMIDI)
    private func getMIDIDeviceInfo(_ endpoint: MIDIEndpointRef) -> MIDIDeviceInfo? {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)

        guard let deviceName = name?.takeRetainedValue() as String? else {
            return nil
        }

        var manufacturer: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)

        return MIDIDeviceInfo(
            id: Int(endpoint),
            name: deviceName,
            manufacturer: manufacturer?.takeRetainedValue() as String? ?? "Unknown",
            isInput: true,
            isOutput: false
        )
    }

    private func connectAllMIDIInputs() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
        }
    }
    #endif

    // MARK: - MIDI Output

    public func sendMIDI(_ message: MIDIMessage, to deviceId: Int? = nil) {
        #if canImport(CoreMIDI)
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3

        let status = (message.type.statusByte & 0xF0) | (message.channel & 0x0F)
        packet.data.0 = status
        packet.data.1 = message.data1
        packet.data.2 = message.data2

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)

        if let deviceId = deviceId {
            let destination = MIDIEndpointRef(deviceId)
            MIDISend(outputPort, destination, &packetList)
        } else {
            // Send to all destinations
            let destCount = MIDIGetNumberOfDestinations()
            for i in 0..<destCount {
                let dest = MIDIGetDestination(i)
                MIDISend(outputPort, dest, &packetList)
            }
        }
        #endif
    }

    // MARK: - MIDI Learn

    /// Start MIDI learn mode for a parameter
    public func startLearn(for parameter: String) {
        isLearning = true
        learningParameter = parameter
        pendingLearnParameter = parameter

        learnCallback = { [weak self] message in
            Task { @MainActor in
                self?.completeLearn(message: message)
            }
        }
    }

    /// Cancel MIDI learn mode
    public func cancelLearn() {
        isLearning = false
        learningParameter = nil
        pendingLearnParameter = nil
        learnCallback = nil
    }

    private func completeLearn(message: MIDIMessage) {
        guard let parameter = pendingLearnParameter else { return }

        // Create mapping
        let mapping = ControlMapping(
            id: UUID(),
            parameter: parameter,
            source: .midi(
                channel: message.channel,
                type: message.type,
                control: message.data1
            ),
            transform: .linear(min: 0, max: 1),
            enabled: true
        )

        mappings.append(mapping)

        // End learn mode
        cancelLearn()

        // Notify
        NotificationCenter.default.post(
            name: .midiLearnCompleted,
            object: nil,
            userInfo: ["mapping": mapping]
        )
    }

    // MARK: - OSC Server

    /// Start OSC server
    public func startOSCServer() async throws {
        guard config.enableOSC else { return }

        oscServer = OSCServer(port: config.oscServerPort)
        oscServer?.messageHandler = { [weak self] message in
            Task { @MainActor in
                self?.handleOSCMessage(message)
            }
        }

        try await oscServer?.start()
        oscServerRunning = true
    }

    /// Stop OSC server
    public func stopOSCServer() {
        oscServer?.stop()
        oscServer = nil
        oscServerRunning = false
    }

    private func handleOSCMessage(_ message: OSCMessage) {
        // Handle OSC Learn
        if isLearning {
            completeOSCLearn(message: message)
            return
        }

        // Process through mappings
        processOSCMessage(message)
    }

    private func completeOSCLearn(message: OSCMessage) {
        guard let parameter = pendingLearnParameter else { return }

        let mapping = ControlMapping(
            id: UUID(),
            parameter: parameter,
            source: .osc(address: message.address),
            transform: .linear(min: 0, max: 1),
            enabled: true
        )

        mappings.append(mapping)
        cancelLearn()
    }

    // MARK: - OSC Client

    /// Connect OSC client to target
    public func connectOSCClient(host: String, port: UInt16, name: String = "default") async throws {
        let client = OSCClient(host: host, port: port)
        try await client.connect()
        oscClients[name] = client
    }

    /// Send OSC message
    public func sendOSC(_ message: OSCMessage, client: String = "default") {
        oscClients[client]?.send(message)
    }

    /// Send OSC value to address
    public func sendOSC(address: String, values: [Any], client: String = "default") {
        let message = OSCMessage(address: address, arguments: values)
        sendOSC(message, client: client)
    }

    // MARK: - Mapping Management

    /// Add control mapping
    public func addMapping(_ mapping: ControlMapping) {
        mappings.append(mapping)
    }

    /// Remove mapping
    public func removeMapping(_ id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    /// Clear all mappings
    public func clearMappings() {
        mappings.removeAll()
    }

    /// Save mappings to file
    public func saveMappings(to url: URL) throws {
        let data = try JSONEncoder().encode(mappings)
        try data.write(to: url)
    }

    /// Load mappings from file
    public func loadMappings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        mappings = try JSONDecoder().decode([ControlMapping].self, from: data)
    }

    // MARK: - Message Processing

    private func processMessage(_ message: MIDIMessage) {
        for mapping in mappings where mapping.enabled {
            if case .midi(let channel, let type, let control) = mapping.source {
                if message.channel == channel &&
                   message.type == type &&
                   message.data1 == control {

                    let value = transformValue(Double(message.data2) / 127.0, mapping.transform)
                    applyMapping(mapping, value: value)
                }
            }
        }

        // MIDI Through
        if config.midiThrough {
            sendMIDI(message)
        }
    }

    private func processOSCMessage(_ message: OSCMessage) {
        for mapping in mappings where mapping.enabled {
            if case .osc(let address) = mapping.source {
                if matchOSCAddress(message.address, pattern: address) {
                    if let value = message.arguments.first as? Float {
                        let transformed = transformValue(Double(value), mapping.transform)
                        applyMapping(mapping, value: transformed)
                    }
                }
            }
        }
    }

    private func transformValue(_ value: Double, _ transform: ControlMapping.Transform) -> Double {
        switch transform {
        case .linear(let min, let max):
            return min + value * (max - min)
        case .exponential(let min, let max, let curve):
            let curved = pow(value, curve)
            return min + curved * (max - min)
        case .logarithmic(let min, let max):
            let logged = log10(1 + value * 9) // 0-1 -> 0-1 logarithmic
            return min + logged * (max - min)
        case .toggle:
            return value > 0.5 ? 1 : 0
        case .custom(let handler):
            return handler(value)
        }
    }

    private func applyMapping(_ mapping: ControlMapping, value: Double) {
        // Post notification with parameter and value
        NotificationCenter.default.post(
            name: .controlValueChanged,
            object: nil,
            userInfo: [
                "parameter": mapping.parameter,
                "value": value
            ]
        )
    }

    private func matchOSCAddress(_ address: String, pattern: String) -> Bool {
        // Simple pattern matching (* for wildcard)
        if pattern.contains("*") {
            let regex = pattern
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "/", with: "\\/")
            return address.range(of: "^\(regex)$", options: .regularExpression) != nil
        }
        return address == pattern
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - MIDI Types

public struct MIDIDeviceInfo: Identifiable {
    public let id: Int
    public let name: String
    public let manufacturer: String
    public let isInput: Bool
    public let isOutput: Bool
}

public struct MIDIMessage {
    public let type: MessageType
    public let channel: UInt8
    public let data1: UInt8
    public let data2: UInt8

    public enum MessageType {
        case noteOn
        case noteOff
        case controlChange
        case pitchBend
        case programChange
        case aftertouch
        case unknown

        var statusByte: UInt8 {
            switch self {
            case .noteOn: return 0x90
            case .noteOff: return 0x80
            case .controlChange: return 0xB0
            case .pitchBend: return 0xE0
            case .programChange: return 0xC0
            case .aftertouch: return 0xD0
            case .unknown: return 0x00
            }
        }
    }
}

// MARK: - Control Mapping

public struct ControlMapping: Codable, Identifiable {
    public let id: UUID
    public var parameter: String
    public var source: ControlSource
    public var transform: Transform
    public var enabled: Bool

    public enum ControlSource: Codable {
        case midi(channel: UInt8, type: MIDIMessage.MessageType, control: UInt8)
        case osc(address: String)
        case keyboard(key: String, modifiers: [String])

        // Codable implementation
        enum CodingKeys: String, CodingKey {
            case type, channel, messageType, control, address, key, modifiers
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "midi":
                let channel = try container.decode(UInt8.self, forKey: .channel)
                let control = try container.decode(UInt8.self, forKey: .control)
                self = .midi(channel: channel, type: .controlChange, control: control)
            case "osc":
                let address = try container.decode(String.self, forKey: .address)
                self = .osc(address: address)
            default:
                self = .osc(address: "/unknown")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .midi(let channel, _, let control):
                try container.encode("midi", forKey: .type)
                try container.encode(channel, forKey: .channel)
                try container.encode(control, forKey: .control)
            case .osc(let address):
                try container.encode("osc", forKey: .type)
                try container.encode(address, forKey: .address)
            case .keyboard(let key, let modifiers):
                try container.encode("keyboard", forKey: .type)
                try container.encode(key, forKey: .key)
                try container.encode(modifiers, forKey: .modifiers)
            }
        }
    }

    public enum Transform: Codable {
        case linear(min: Double, max: Double)
        case exponential(min: Double, max: Double, curve: Double)
        case logarithmic(min: Double, max: Double)
        case toggle
        case custom((Double) -> Double)

        enum CodingKeys: String, CodingKey {
            case type, min, max, curve
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "linear":
                let min = try container.decode(Double.self, forKey: .min)
                let max = try container.decode(Double.self, forKey: .max)
                self = .linear(min: min, max: max)
            case "toggle":
                self = .toggle
            default:
                self = .linear(min: 0, max: 1)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .linear(let min, let max):
                try container.encode("linear", forKey: .type)
                try container.encode(min, forKey: .min)
                try container.encode(max, forKey: .max)
            case .toggle:
                try container.encode("toggle", forKey: .type)
            default:
                try container.encode("linear", forKey: .type)
            }
        }
    }
}

// MARK: - OSC Types

public struct OSCMessage {
    public let address: String
    public let arguments: [Any]

    public init(address: String, arguments: [Any] = []) {
        self.address = address
        self.arguments = arguments
    }

    /// Encode to OSC packet
    public func encode() -> Data {
        var data = Data()

        // Address
        data.append(encodeOSCString(address))

        // Type tag
        var typeTag = ","
        for arg in arguments {
            switch arg {
            case is Int32: typeTag += "i"
            case is Float: typeTag += "f"
            case is String: typeTag += "s"
            case is Data: typeTag += "b"
            default: break
            }
        }
        data.append(encodeOSCString(typeTag))

        // Arguments
        for arg in arguments {
            switch arg {
            case let i as Int32:
                var value = i.bigEndian
                data.append(Data(bytes: &value, count: 4))
            case let f as Float:
                var value = f.bitPattern.bigEndian
                data.append(Data(bytes: &value, count: 4))
            case let s as String:
                data.append(encodeOSCString(s))
            case let b as Data:
                var size = Int32(b.count).bigEndian
                data.append(Data(bytes: &size, count: 4))
                data.append(b)
                // Pad to 4-byte boundary
                let padding = (4 - b.count % 4) % 4
                data.append(Data(repeating: 0, count: padding))
            default:
                break
            }
        }

        return data
    }

    private func encodeOSCString(_ string: String) -> Data {
        var data = string.data(using: .utf8) ?? Data()
        data.append(0) // Null terminator
        // Pad to 4-byte boundary
        let padding = (4 - data.count % 4) % 4
        data.append(Data(repeating: 0, count: padding))
        return data
    }

    /// Decode from OSC packet
    public static func decode(_ data: Data) -> OSCMessage? {
        // Simplified decoding
        guard let nullIndex = data.firstIndex(of: 0) else { return nil }
        let address = String(data: data[0..<nullIndex], encoding: .utf8) ?? ""
        return OSCMessage(address: address)
    }
}

// MARK: - OSC Server

public class OSCServer {
    private let port: UInt16
    private var listener: NWListener?
    public var messageHandler: ((OSCMessage) -> Void)?

    public init(port: UInt16) {
        self.port = port
    }

    public func start() async throws {
        let params = NWParameters.udp
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global())
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data = data, let message = OSCMessage.decode(data) {
                self?.messageHandler?(message)
            }
        }
    }
}

// MARK: - OSC Client

public class OSCClient {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .udp
        )
        connection?.start(queue: .global())
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
    }

    public func send(_ message: OSCMessage) {
        let data = message.encode()
        connection?.send(content: data, completion: .idempotent)
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let midiLearnCompleted = Notification.Name("midiLearnCompleted")
    public static let controlValueChanged = Notification.Name("controlValueChanged")
}

// MARK: - MIDI Message Type Codable

extension MIDIMessage.MessageType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "noteOn": self = .noteOn
        case "noteOff": self = .noteOff
        case "controlChange": self = .controlChange
        case "pitchBend": self = .pitchBend
        case "programChange": self = .programChange
        case "aftertouch": self = .aftertouch
        default: self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .noteOn: try container.encode("noteOn")
        case .noteOff: try container.encode("noteOff")
        case .controlChange: try container.encode("controlChange")
        case .pitchBend: try container.encode("pitchBend")
        case .programChange: try container.encode("programChange")
        case .aftertouch: try container.encode("aftertouch")
        case .unknown: try container.encode("unknown")
        }
    }
}
