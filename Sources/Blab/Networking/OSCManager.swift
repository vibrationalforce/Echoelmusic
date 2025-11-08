import Foundation
import Network

/// OSC (Open Sound Control) Manager for remote control and collaboration
///
/// Supports:
/// - OSC message sending/receiving
/// - TouchOSC/Lemur integration
/// - Ableton Live integration
/// - Max/MSP communication
/// - Multi-device collaboration
@MainActor
class OSCManager: ObservableObject {

    // MARK: - Published State

    /// Whether OSC server is running
    @Published var isRunning: Bool = false

    /// Connected clients
    @Published var connectedClients: [OSCClient] = []

    /// Last received message
    @Published var lastMessage: OSCMessage?

    // MARK: - Configuration

    struct OSCConfiguration {
        var receivePort: UInt16 = 8000
        var sendPort: UInt16 = 9000
        var sendHost: String = "192.168.1.100"
        var enableMulticast: Bool = false
        var multicastGroup: String = "224.0.0.1"
    }

    var configuration = OSCConfiguration()

    // MARK: - Networking

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.blab.osc", qos: .userInteractive)

    // MARK: - Message Handlers

    private var messageHandlers: [String: (OSCMessage) -> Void] = [:]

    // MARK: - Public API

    /// Start OSC server
    func startServer() throws {
        guard !isRunning else { return }

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: configuration.receivePort))

        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleListenerState(state)
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
        isRunning = true

        print("🌐 OSC Server started on port \(configuration.receivePort)")
    }

    /// Stop OSC server
    func stopServer() {
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
        isRunning = false
        connectedClients.removeAll()

        print("🌐 OSC Server stopped")
    }

    /// Send OSC message
    func send(address: String, arguments: [OSCArgument]) {
        let message = OSCMessage(address: address, arguments: arguments)
        sendMessage(message, to: configuration.sendHost, port: configuration.sendPort)
    }

    /// Register message handler for address pattern
    func onMessage(address: String, handler: @escaping (OSCMessage) -> Void) {
        messageHandlers[address] = handler
        print("🌐 Registered OSC handler for: \(address)")
    }

    /// Remove message handler
    func removeHandler(for address: String) {
        messageHandlers.removeValue(forKey: address)
    }

    // MARK: - Private Methods

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("🌐 OSC Listener ready")
        case .failed(let error):
            print("❌ OSC Listener failed: \(error)")
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        // Receive data
        receiveData(on: connection)

        // Track client
        if let endpoint = connection.endpoint {
            let client = OSCClient(endpoint: endpoint, connection: connection)
            DispatchQueue.main.async {
                self.connectedClients.append(client)
            }
        }
    }

    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.parseOSCData(data)
            }

            if error == nil && !isComplete {
                self?.receiveData(on: connection)
            }
        }
    }

    private func parseOSCData(_ data: Data) {
        guard let message = OSCMessage.parse(from: data) else {
            print("⚠️  Failed to parse OSC message")
            return
        }

        DispatchQueue.main.async {
            self.lastMessage = message
            self.handleMessage(message)
        }
    }

    private func handleMessage(_ message: OSCMessage) {
        // Find matching handler
        for (pattern, handler) in messageHandlers {
            if message.address.hasPrefix(pattern) {
                handler(message)
                return
            }
        }

        // Default: print unhandled message
        print("🌐 OSC: \(message.address) \(message.arguments.map { "\($0)" }.joined(separator: " "))")
    }

    private func sendMessage(_ message: OSCMessage, to host: String, port: UInt16) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )

        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: queue)

        let data = message.encode()
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ OSC send error: \(error)")
            }
            connection.cancel()
        })
    }

    // MARK: - Preset Mappings

    /// Map BLAB parameters to OSC for DAW integration
    func setupDAWIntegration() {
        // Ableton Live integration
        onMessage(address: "/live/tempo") { message in
            if let tempo = message.arguments.first?.floatValue {
                print("🎵 Ableton tempo: \(tempo) BPM")
                // TODO: Sync with BLAB tempo
            }
        }

        onMessage(address: "/live/track/*/volume") { message in
            // Handle track volume changes
        }
    }

    /// Send BLAB biometric data via OSC
    func sendBiometrics(hrv: Double, heartRate: Double, coherence: Double) {
        send(address: "/blab/bio/hrv", arguments: [.float(Float(hrv))])
        send(address: "/blab/bio/heartrate", arguments: [.float(Float(heartRate))])
        send(address: "/blab/bio/coherence", arguments: [.float(Float(coherence))])
    }

    /// Send MIDI data via OSC
    func sendMIDI(channel: UInt8, note: UInt8, velocity: UInt8) {
        send(address: "/blab/midi/note", arguments: [
            .int(Int32(channel)),
            .int(Int32(note)),
            .int(Int32(velocity))
        ])
    }
}

// MARK: - Supporting Types

struct OSCClient: Identifiable {
    let id = UUID()
    let endpoint: NWEndpoint
    let connection: NWConnection
    let connectedAt = Date()

    var description: String {
        switch endpoint {
        case .hostPort(let host, let port):
            return "\(host):\(port)"
        default:
            return "Unknown"
        }
    }
}

struct OSCMessage {
    let address: String
    let arguments: [OSCArgument]
    let timestamp: Date = Date()

    /// Parse OSC message from data
    static func parse(from data: Data) -> OSCMessage? {
        var offset = 0

        // Parse address (null-terminated string)
        guard let address = parseString(from: data, offset: &offset) else {
            return nil
        }

        // Parse type tag string
        guard let typeTag = parseString(from: data, offset: &offset) else {
            return nil
        }

        // Parse arguments
        var arguments: [OSCArgument] = []
        for char in typeTag.dropFirst() {  // Skip leading ','
            switch char {
            case "i":
                if let value = parseInt32(from: data, offset: &offset) {
                    arguments.append(.int(value))
                }
            case "f":
                if let value = parseFloat(from: data, offset: &offset) {
                    arguments.append(.float(value))
                }
            case "s":
                if let value = parseString(from: data, offset: &offset) {
                    arguments.append(.string(value))
                }
            case "b":
                if let value = parseBlob(from: data, offset: &offset) {
                    arguments.append(.blob(value))
                }
            default:
                break
            }
        }

        return OSCMessage(address: address, arguments: arguments)
    }

    /// Encode OSC message to data
    func encode() -> Data {
        var data = Data()

        // Encode address
        data.append(encodeString(address))

        // Encode type tag
        let typeTag = "," + arguments.map { $0.typeTag }.joined()
        data.append(encodeString(typeTag))

        // Encode arguments
        for arg in arguments {
            data.append(arg.encode())
        }

        return data
    }

    // Encoding helpers
    private func encodeString(_ string: String) -> Data {
        var data = string.data(using: .ascii) ?? Data()
        // Add null terminator and pad to 4-byte boundary
        data.append(0)
        while data.count % 4 != 0 {
            data.append(0)
        }
        return data
    }

    // Parsing helpers
    private static func parseString(from data: Data, offset: inout Int) -> String? {
        guard offset < data.count else { return nil }

        var end = offset
        while end < data.count && data[end] != 0 {
            end += 1
        }

        let string = String(data: data[offset..<end], encoding: .ascii) ?? ""

        // Skip to next 4-byte boundary
        offset = ((end + 4) / 4) * 4

        return string
    }

    private static func parseInt32(from data: Data, offset: inout Int) -> Int32? {
        guard offset + 4 <= data.count else { return nil }

        let value = data[offset..<offset+4].withUnsafeBytes {
            $0.load(as: Int32.self).bigEndian
        }

        offset += 4
        return value
    }

    private static func parseFloat(from data: Data, offset: inout Int) -> Float? {
        guard offset + 4 <= data.count else { return nil }

        let value = data[offset..<offset+4].withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }

        offset += 4
        return Float(bitPattern: value)
    }

    private static func parseBlob(from data: Data, offset: inout Int) -> Data? {
        guard let size = parseInt32(from: data, offset: &offset) else { return nil }
        guard offset + Int(size) <= data.count else { return nil }

        let blob = data[offset..<offset+Int(size)]
        offset = ((offset + Int(size) + 3) / 4) * 4  // Align to 4 bytes

        return blob
    }
}

enum OSCArgument {
    case int(Int32)
    case float(Float)
    case string(String)
    case blob(Data)

    var typeTag: String {
        switch self {
        case .int: return "i"
        case .float: return "f"
        case .string: return "s"
        case .blob: return "b"
        }
    }

    var floatValue: Float? {
        switch self {
        case .float(let value): return value
        case .int(let value): return Float(value)
        default: return nil
        }
    }

    func encode() -> Data {
        var data = Data()

        switch self {
        case .int(let value):
            var bigEndian = value.bigEndian
            data.append(Data(bytes: &bigEndian, count: 4))

        case .float(let value):
            var bitPattern = value.bitPattern.bigEndian
            data.append(Data(bytes: &bitPattern, count: 4))

        case .string(let value):
            data.append(OSCMessage(address: "", arguments: []).encodeString(value))

        case .blob(let blob):
            var size = Int32(blob.count).bigEndian
            data.append(Data(bytes: &size, count: 4))
            data.append(blob)
            // Pad to 4-byte boundary
            while data.count % 4 != 0 {
                data.append(0)
            }
        }

        return data
    }
}

// Helper method for string encoding
extension OSCMessage {
    func encodeString(_ string: String) -> Data {
        var data = string.data(using: .ascii) ?? Data()
        data.append(0)
        while data.count % 4 != 0 {
            data.append(0)
        }
        return data
    }
}
