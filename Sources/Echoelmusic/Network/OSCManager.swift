import Foundation
import Network

/// OSC (Open Sound Control) Manager for DAW integration
/// Enables bi-directional communication with Ableton Live, Reaper, Logic Pro, Bitwig
/// OSC protocol: UDP-based message protocol for music and multimedia applications
@MainActor
class OSCManager: ObservableObject {

    // MARK: - Published State

    /// Whether OSC is connected and running
    @Published var isConnected: Bool = false

    /// Current send address (DAW IP:Port)
    @Published var sendAddress: String = "127.0.0.1"
    @Published var sendPort: UInt16 = 9000

    /// Current receive port (for incoming OSC from DAW)
    @Published var receivePort: UInt16 = 9001

    /// Latest received OSC messages (for debugging)
    @Published var receivedMessages: [OSCMessage] = []

    // MARK: - Network Components

    private var sendConnection: NWConnection?
    private var receiveListener: NWListener?

    // MARK: - Message Queue

    private let sendQueue = DispatchQueue(
        label: "com.echoelmusic.osc.send",
        qos: .userInitiated
    )

    private let receiveQueue = DispatchQueue(
        label: "com.echoelmusic.osc.receive",
        qos: .userInitiated
    )

    // MARK: - Callbacks

    var onMessageReceived: ((OSCMessage) -> Void)?

    // MARK: - Initialization

    init() {
        // Will connect when start() is called
    }

    deinit {
        stop()
    }

    // MARK: - Connection Management

    /// Start OSC communication
    func start() throws {
        guard !isConnected else {
            print("[OSC] Already connected")
            return
        }

        // Setup send connection (UDP to DAW)
        try setupSendConnection()

        // Setup receive listener (UDP from DAW)
        try setupReceiveListener()

        isConnected = true
        print("[OSC] ✅ Started - Sending to \(sendAddress):\(sendPort), Receiving on :\(receivePort)")
    }

    /// Stop OSC communication
    func stop() {
        sendConnection?.cancel()
        sendConnection = nil

        receiveListener?.cancel()
        receiveListener = nil

        isConnected = false
        print("[OSC] ⏹️ Stopped")
    }

    // MARK: - Network Setup

    private func setupSendConnection() throws {
        let host = NWEndpoint.Host(sendAddress)
        let port = NWEndpoint.Port(rawValue: sendPort)!

        let connection = NWConnection(
            host: host,
            port: port,
            using: .udp
        )

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[OSC] Send connection ready")
            case .failed(let error):
                print("[OSC] Send connection failed: \(error)")
                Task { @MainActor in
                    self?.isConnected = false
                }
            default:
                break
            }
        }

        connection.start(queue: sendQueue)
        self.sendConnection = connection
    }

    private func setupReceiveListener() throws {
        let port = NWEndpoint.Port(rawValue: receivePort)!
        let listener = try NWListener(using: .udp, on: port)

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[OSC] Receive listener ready on port \(port)")
            case .failed(let error):
                print("[OSC] Receive listener failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: receiveQueue)
        self.receiveListener = listener
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: receiveQueue)

        receiveMessage(on: connection)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                // Parse OSC message
                if let message = self?.parseOSCMessage(data) {
                    Task { @MainActor in
                        self?.receivedMessages.append(message)
                        self?.onMessageReceived?(message)
                    }
                }
            }

            if !isComplete {
                // Continue receiving
                self?.receiveMessage(on: connection)
            }
        }
    }

    // MARK: - Send Messages

    /// Send OSC message to DAW
    func send(address: String, arguments: [OSCValue]) {
        guard isConnected, let connection = sendConnection else {
            print("[OSC] ⚠️ Not connected, cannot send message")
            return
        }

        let message = OSCMessage(address: address, arguments: arguments)
        guard let data = encodeOSCMessage(message) else {
            print("[OSC] ❌ Failed to encode message")
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[OSC] ❌ Send error: \(error)")
            }
        })
    }

    /// Send multiple parameter updates as OSC bundle
    func sendBundle(messages: [OSCMessage]) {
        // OSC bundles allow atomically sending multiple messages
        // Format: #bundle <timetag> <message> <message> ...

        guard isConnected, let connection = sendConnection else {
            print("[OSC] ⚠️ Not connected, cannot send bundle")
            return
        }

        guard let data = encodeOSCBundle(messages) else {
            print("[OSC] ❌ Failed to encode bundle")
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[OSC] ❌ Send bundle error: \(error)")
            }
        })
    }

    // MARK: - OSC Encoding/Decoding

    private func encodeOSCMessage(_ message: OSCMessage) -> Data? {
        var data = Data()

        // Address (null-terminated, 4-byte aligned)
        data.append(encodeString(message.address))

        // Type tag string (comma + type chars)
        var typeTag = ","
        for arg in message.arguments {
            typeTag += arg.oscType
        }
        data.append(encodeString(typeTag))

        // Arguments
        for arg in message.arguments {
            data.append(arg.oscData)
        }

        return data
    }

    private func parseOSCMessage(_ data: Data) -> OSCMessage? {
        var offset = 0

        // Parse address
        guard let address = decodeString(data, offset: &offset) else {
            return nil
        }

        // Parse type tag
        guard let typeTag = decodeString(data, offset: &offset) else {
            return nil
        }

        // Parse arguments
        var arguments: [OSCValue] = []
        for char in typeTag.dropFirst() { // Skip comma
            if let arg = decodeArgument(type: char, data: data, offset: &offset) {
                arguments.append(arg)
            }
        }

        return OSCMessage(address: address, arguments: arguments)
    }

    private func encodeOSCBundle(_ messages: [OSCMessage]) -> Data? {
        var data = Data()

        // Bundle identifier
        data.append(encodeString("#bundle"))

        // Time tag (8 bytes) - immediate execution
        let timeTag: UInt64 = 1 // OSC time tag for "now"
        data.append(contentsOf: withUnsafeBytes(of: timeTag.bigEndian) { Data($0) })

        // Encode each message with size prefix
        for message in messages {
            guard let messageData = encodeOSCMessage(message) else { continue }

            // Size prefix (4 bytes, big-endian)
            let size = UInt32(messageData.count).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: size) { Data($0) })

            // Message data
            data.append(messageData)
        }

        return data
    }

    // MARK: - Helper Methods

    private func encodeString(_ string: String) -> Data {
        var data = Data(string.utf8)
        data.append(0) // Null terminator

        // Pad to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }

        return data
    }

    private func decodeString(_ data: Data, offset: inout Int) -> String? {
        guard offset < data.count else { return nil }

        var end = offset
        while end < data.count && data[end] != 0 {
            end += 1
        }

        guard let string = String(data: data[offset..<end], encoding: .utf8) else {
            return nil
        }

        // Move offset to next 4-byte boundary
        offset = ((end + 1) + 3) & ~3

        return string
    }

    private func decodeArgument(type: Character, data: Data, offset: inout Int) -> OSCValue? {
        guard offset + 4 <= data.count else { return nil }

        switch type {
        case "i": // int32
            let value = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }.bigEndian
            offset += 4
            return .int(Int(value))

        case "f": // float32
            let bits = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }.bigEndian
            let value = Float(bitPattern: bits)
            offset += 4
            return .float(value)

        case "s": // string
            if let string = decodeString(data, offset: &offset) {
                return .string(string)
            }

        default:
            break
        }

        return nil
    }

    // MARK: - DAW-Specific Presets

    /// Configure for Ableton Live OSC integration
    func configureForAbleton() {
        sendAddress = "127.0.0.1"
        sendPort = 11000
        receivePort = 11001
        print("[OSC] Configured for Ableton Live")
    }

    /// Configure for Reaper OSC integration
    func configureForReaper() {
        sendAddress = "127.0.0.1"
        sendPort = 8000
        receivePort = 9000
        print("[OSC] Configured for Reaper")
    }

    /// Configure for Logic Pro OSC integration
    func configureForLogic() {
        sendAddress = "127.0.0.1"
        sendPort = 7001
        receivePort = 7000
        print("[OSC] Configured for Logic Pro")
    }
}

// MARK: - OSC Data Types

struct OSCMessage {
    let address: String
    let arguments: [OSCValue]
}

enum OSCValue {
    case int(Int)
    case float(Float)
    case string(String)

    var oscType: String {
        switch self {
        case .int: return "i"
        case .float: return "f"
        case .string: return "s"
        }
    }

    var oscData: Data {
        var data = Data()

        switch self {
        case .int(let value):
            let int32 = Int32(value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: int32) { Data($0) })

        case .float(let value):
            let bits = value.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: bits) { Data($0) })

        case .string(let value):
            data.append(value.data(using: .utf8) ?? Data())
            data.append(0) // Null terminator
            while data.count % 4 != 0 {
                data.append(0) // Padding
            }
        }

        return data
    }
}
