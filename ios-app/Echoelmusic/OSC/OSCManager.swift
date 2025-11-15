// OSCManager.swift
// iOS OSC Client Implementation Template for Echoelmusic
//
// Usage:
// 1. Copy this file to: ios-app/Echoelmusic/OSC/OSCManager.swift
// 2. Import in your views: import Foundation
// 3. Initialize: let oscManager = OSCManager()
// 4. Connect: oscManager.connect(to: "192.168.1.100")
// 5. Send: oscManager.sendHeartRate(72.5)

import Foundation
import Network

/// Manages OSC communication with Desktop Engine
class OSCManager: ObservableObject {
    // MARK: - Published Properties

    @Published var isConnected: Bool = false
    @Published var latencyMs: Double = 0
    @Published var packetsSent: Int = 0
    @Published var packetsReceived: Int = 0

    // MARK: - Private Properties

    private var connection: NWConnection?
    private let serverPort: UInt16 = 8000
    private var pingTimer: Timer?
    private var lastPingTime: Date?

    // MARK: - Initialization

    init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection Management

    /// Connect to Desktop Engine
    func connect(to host: String) {
        disconnect() // Close existing connection

        let endpoint = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(rawValue: serverPort)!

        connection = NWConnection(
            host: endpoint,
            port: port,
            using: .udp
        )

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.startPingTimer()
                    print("OSC: Connected to \(host):\(self?.serverPort ?? 0)")

                case .failed(let error):
                    self?.isConnected = false
                    print("OSC: Connection failed: \(error)")

                case .cancelled:
                    self?.isConnected = false
                    print("OSC: Connection cancelled")

                default:
                    break
                }
            }
        }

        connection?.start(queue: .global(qos: .userInitiated))

        // Start receiving messages
        receiveMessages()
    }

    /// Disconnect from Desktop Engine
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        print("OSC: Disconnected")
    }

    // MARK: - Send Biofeedback Data

    /// Send heart rate to Desktop
    func sendHeartRate(_ bpm: Float) {
        send(address: "/echoel/bio/heartrate", [.float(bpm)])
    }

    /// Send HRV to Desktop
    func sendHRV(_ ms: Float) {
        send(address: "/echoel/bio/hrv", [.float(ms)])
    }

    /// Send breath rate to Desktop
    func sendBreathRate(_ breaths: Float) {
        send(address: "/echoel/bio/breathrate", [.float(breaths)])
    }

    /// Send voice pitch to Desktop
    func sendPitch(frequency: Float, confidence: Float) {
        send(address: "/echoel/audio/pitch",
             [.float(frequency), .float(confidence)])
    }

    /// Send audio amplitude to Desktop
    func sendAmplitude(_ db: Float) {
        send(address: "/echoel/audio/amplitude", [.float(db)])
    }

    // MARK: - Send Control Messages

    /// Select scene on Desktop
    func selectScene(_ sceneId: Int) {
        send(address: "/echoel/scene/select", [.int(Int32(sceneId))])
    }

    /// Send parameter value to Desktop
    func sendParameter(name: String, value: Float) {
        send(address: "/echoel/param/\(name)", [.float(value)])
    }

    /// Send system control command
    func sendSystemCommand(_ command: String) {
        send(address: "/echoel/system/\(command)", [])
    }

    // MARK: - Ping/Pong (Latency Measurement)

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // ms
        lastPingTime = Date()
        send(address: "/echoel/sync/ping", [.int(Int32(timestamp))])
    }

    private func handlePong(timestamp: Int) {
        guard let pingTime = lastPingTime else { return }
        let now = Date()
        let rtt = now.timeIntervalSince(pingTime) * 1000 // ms
        latencyMs = rtt / 2.0
    }

    // MARK: - Receive Messages

    private func receiveMessages() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            if let error = error {
                print("OSC: Receive error: \(error)")
                return
            }

            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data)
            }

            // Continue receiving
            self?.receiveMessages()
        }
    }

    private func handleReceivedData(_ data: Data) {
        guard let message = OSCMessage.decode(data) else {
            print("OSC: Failed to decode message")
            return
        }

        DispatchQueue.main.async {
            self.packetsReceived += 1
        }

        // Handle specific messages
        switch message.address {
        case "/echoel/analysis/rms":
            if let rms = message.arguments.first?.floatValue {
                // Update UI with RMS level
                NotificationCenter.default.post(
                    name: .oscRMSReceived,
                    object: rms
                )
            }

        case "/echoel/analysis/peak":
            if let peak = message.arguments.first?.floatValue {
                NotificationCenter.default.post(
                    name: .oscPeakReceived,
                    object: peak
                )
            }

        case "/echoel/analysis/spectrum":
            let spectrum = message.arguments.compactMap { $0.floatValue }
            NotificationCenter.default.post(
                name: .oscSpectrumReceived,
                object: spectrum
            )

        case "/echoel/status/cpu":
            if let cpu = message.arguments.first?.floatValue {
                NotificationCenter.default.post(
                    name: .oscCPUReceived,
                    object: cpu
                )
            }

        case "/echoel/sync/pong":
            if let timestamp = message.arguments.first?.intValue {
                handlePong(timestamp: Int(timestamp))
            }

        default:
            print("OSC: Unhandled message: \(message.address)")
        }
    }

    // MARK: - Core Send Function

    private func send(address: String, _ arguments: [OSCArgument]) {
        guard isConnected, let connection = connection else {
            print("OSC: Not connected, cannot send \(address)")
            return
        }

        let message = OSCMessage(address: address, arguments: arguments)
        let data = message.encode()

        connection.send(
            content: data,
            completion: .contentProcessed { [weak self] error in
                if let error = error {
                    print("OSC: Send error: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.packetsSent += 1
                    }
                }
            }
        )
    }
}

// MARK: - OSC Message Structure

struct OSCMessage {
    let address: String
    let arguments: [OSCArgument]

    func encode() -> Data {
        var data = Data()

        // 1. Address (null-terminated, 4-byte aligned)
        data.append(address.data(using: .utf8)!)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // 2. Type tag string
        var typeTag = ","
        for arg in arguments {
            typeTag += arg.typeTag
        }
        data.append(typeTag.data(using: .utf8)!)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // 3. Arguments
        for arg in arguments {
            data.append(arg.encode())
        }

        return data
    }

    static func decode(_ data: Data) -> OSCMessage? {
        var offset = 0

        // 1. Read address
        guard let address = data.readNullTerminatedString(at: &offset) else {
            return nil
        }

        // 2. Read type tag
        guard let typeTag = data.readNullTerminatedString(at: &offset) else {
            return nil
        }

        guard typeTag.hasPrefix(",") else { return nil }
        let types = String(typeTag.dropFirst())

        // 3. Read arguments
        var arguments: [OSCArgument] = []
        for type in types {
            switch type {
            case "f":
                if let float = data.readFloat32(at: &offset) {
                    arguments.append(.float(float))
                }
            case "i":
                if let int = data.readInt32(at: &offset) {
                    arguments.append(.int(int))
                }
            default:
                break
            }
        }

        return OSCMessage(address: address, arguments: arguments)
    }
}

// MARK: - OSC Argument Types

enum OSCArgument {
    case float(Float)
    case int(Int32)

    var typeTag: String {
        switch self {
        case .float: return "f"
        case .int: return "i"
        }
    }

    func encode() -> Data {
        var data = Data()
        switch self {
        case .float(let value):
            var bigEndian = value.bitPattern.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bigEndian) { Data($0) })
        case .int(let value):
            var bigEndian = value.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &bigEndian) { Data($0) })
        }
        return data
    }

    var floatValue: Float? {
        if case .float(let value) = self { return value }
        return nil
    }

    var intValue: Int32? {
        if case .int(let value) = self { return value }
        return nil
    }
}

// MARK: - Data Extensions

extension Data {
    func readNullTerminatedString(at offset: inout Int) -> String? {
        guard offset < count else { return nil }

        var end = offset
        while end < count && self[end] != 0 {
            end += 1
        }

        let stringData = subdata(in: offset..<end)
        let string = String(data: stringData, encoding: .utf8)

        // Advance to next 4-byte boundary
        offset = end + 1
        while offset % 4 != 0 && offset < count {
            offset += 1
        }

        return string
    }

    func readFloat32(at offset: inout Int) -> Float? {
        guard offset + 4 <= count else { return nil }

        let bytes = subdata(in: offset..<offset+4)
        let bitPattern = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        let value = Float(bitPattern: UInt32(bigEndian: bitPattern))

        offset += 4
        return value
    }

    func readInt32(at offset: inout Int) -> Int32? {
        guard offset + 4 <= count else { return nil }

        let bytes = subdata(in: offset..<offset+4)
        let value = bytes.withUnsafeBytes { $0.load(as: Int32.self) }

        offset += 4
        return Int32(bigEndian: value)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let oscRMSReceived = Notification.Name("oscRMSReceived")
    static let oscPeakReceived = Notification.Name("oscPeakReceived")
    static let oscSpectrumReceived = Notification.Name("oscSpectrumReceived")
    static let oscCPUReceived = Notification.Name("oscCPUReceived")
}
