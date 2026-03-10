#if canImport(Network)
//
//  OSCEngine.swift
//  Echoelmusic — Open Sound Control Engine
//
//  UDP-based OSC sender/receiver using Network.framework.
//  Enables bidirectional communication with external apps:
//  Max/MSP, TouchDesigner, Resolume, Ableton, VCV Rack.
//
//  Protocol: OSC 1.0 (opensoundcontrol.org)
//  Transport: UDP (configurable ports)
//  Target: <5ms LAN latency
//

import Foundation
import Network
import Observation
import Combine

// MARK: - OSC Types

/// OSC type tag characters
public enum OSCTypeTag: Character, Sendable {
    case int32   = "i"
    case float32 = "f"
    case string  = "s"
    case blob    = "b"
    case int64   = "h"
    case float64 = "d"
    case trueBool  = "T"
    case falseBool = "F"
    case nil_     = "N"
}

/// A single OSC argument value
public enum OSCValue: Sendable {
    case int(Int32)
    case float(Float)
    case string(String)
    case blob(Data)
    case int64(Int64)
    case double(Double)
    case bool(Bool)
    case nil_

    var typeTag: Character {
        switch self {
        case .int: return "i"
        case .float: return "f"
        case .string: return "s"
        case .blob: return "b"
        case .int64: return "h"
        case .double: return "d"
        case .bool(true): return "T"
        case .bool(false): return "F"
        case .nil_: return "N"
        }
    }
}

/// An OSC message: address pattern + typed arguments
public struct OSCMessage: Sendable {
    public let address: String
    public let arguments: [OSCValue]

    public init(address: String, arguments: [OSCValue] = []) {
        self.address = address
        self.arguments = arguments
    }

    /// Encode to OSC binary format
    public func encode() -> Data {
        var data = Data()

        // Address pattern (null-terminated, 4-byte aligned)
        data.append(OSCMessage.encodeString(address))

        // Type tag string: comma + type chars + null + padding
        let typeTags = "," + arguments.map { String($0.typeTag) }.joined()
        data.append(OSCMessage.encodeString(typeTags))

        // Arguments
        for arg in arguments {
            switch arg {
            case .int(let v):
                var bigEndian = v.bigEndian
                data.append(Data(bytes: &bigEndian, count: 4))
            case .float(let v):
                var bits = v.bitPattern.bigEndian
                data.append(Data(bytes: &bits, count: 4))
            case .string(let v):
                data.append(OSCMessage.encodeString(v))
            case .blob(let v):
                var size = Int32(v.count).bigEndian
                data.append(Data(bytes: &size, count: 4))
                data.append(v)
                let padding = (4 - (v.count % 4)) % 4
                data.append(Data(repeating: 0, count: padding))
            case .int64(let v):
                var bigEndian = v.bigEndian
                data.append(Data(bytes: &bigEndian, count: 8))
            case .double(let v):
                var bits = v.bitPattern.bigEndian
                data.append(Data(bytes: &bits, count: 8))
            case .bool, .nil_:
                break // No data bytes for these types
            }
        }

        return data
    }

    /// Decode from OSC binary data
    public static func decode(from data: Data) -> OSCMessage? {
        var offset = 0
        guard let address = decodeString(from: data, offset: &offset) else { return nil }
        guard let typeTagStr = decodeString(from: data, offset: &offset) else { return nil }
        guard typeTagStr.hasPrefix(",") else { return nil }

        var arguments: [OSCValue] = []
        let tags = Array(typeTagStr.dropFirst())

        for tag in tags {
            switch tag {
            case "i":
                guard offset + 4 <= data.count else { return nil }
                let value = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
                arguments.append(.int(value))
                offset += 4
            case "f":
                guard offset + 4 <= data.count else { return nil }
                let bits = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                arguments.append(.float(Float(bitPattern: bits)))
                offset += 4
            case "s":
                guard let str = decodeString(from: data, offset: &offset) else { return nil }
                arguments.append(.string(str))
            case "b":
                guard offset + 4 <= data.count else { return nil }
                let size = Int(data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self).bigEndian })
                offset += 4
                guard offset + size <= data.count else { return nil }
                arguments.append(.blob(data.subdata(in: offset..<(offset + size))))
                offset += size
                offset += (4 - (size % 4)) % 4
            case "h":
                guard offset + 8 <= data.count else { return nil }
                let value = data.subdata(in: offset..<(offset + 8)).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
                arguments.append(.int64(value))
                offset += 8
            case "d":
                guard offset + 8 <= data.count else { return nil }
                let bits = data.subdata(in: offset..<(offset + 8)).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                arguments.append(.double(Double(bitPattern: bits)))
                offset += 8
            case "T":
                arguments.append(.bool(true))
            case "F":
                arguments.append(.bool(false))
            case "N":
                arguments.append(.nil_)
            default:
                break
            }
        }

        return OSCMessage(address: address, arguments: arguments)
    }

    // MARK: - String Encoding Helpers

    static func encodeString(_ str: String) -> Data {
        var data = str.data(using: .utf8) ?? Data()
        data.append(0) // null terminator
        let padding = (4 - (data.count % 4)) % 4
        data.append(Data(repeating: 0, count: padding))
        return data
    }

    static func decodeString(from data: Data, offset: inout Int) -> String? {
        guard offset < data.count else { return nil }
        var end = offset
        while end < data.count && data[end] != 0 { end += 1 }
        guard end < data.count else { return nil }
        let str = String(data: data.subdata(in: offset..<end), encoding: .utf8)
        end += 1
        end += (4 - (end % 4)) % 4
        offset = end
        return str
    }
}

// MARK: - OSC Engine

/// Bidirectional OSC sender/receiver engine
@MainActor
@Observable
public final class OSCEngine {

    // MARK: - Singleton

    nonisolated(unsafe) public static let shared = OSCEngine()

    // MARK: - State

    public var isRunning: Bool = false
    public var sendHost: String = "127.0.0.1"
    public var sendPort: UInt16 = 9000
    public var receivePort: UInt16 = 8000
    public var messageCount: Int = 0
    public var lastReceivedAddress: String = ""

    // MARK: - Callbacks

    /// Handler for incoming OSC messages
    public var onMessageReceived: ((OSCMessage) -> Void)?

    // MARK: - Network

    private var listener: NWListener?
    private var sendConnection: NWConnection?
    private let sendQueue = DispatchQueue(label: "com.echoelmusic.osc.send", qos: .userInteractive)
    private let receiveQueue = DispatchQueue(label: "com.echoelmusic.osc.receive", qos: .userInteractive)

    // MARK: - Lifecycle

    private init() {}

    deinit {
        stopNonisolated()
    }

    private nonisolated func stopNonisolated() {
        listener?.cancel()
        sendConnection?.cancel()
    }

    // MARK: - Start / Stop

    public func start() {
        guard !isRunning else { return }

        startListener()
        startSender()
        isRunning = true

        log.log(.info, category: .audio, "OSC Engine started — send: \(sendHost):\(sendPort), receive: \(receivePort)")
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        sendConnection?.cancel()
        sendConnection = nil
        isRunning = false

        log.log(.info, category: .audio, "OSC Engine stopped")
    }

    // MARK: - Send

    /// Send an OSC message to the configured host:port
    public func send(_ message: OSCMessage) {
        guard isRunning else { return }
        let data = message.encode()
        sendConnection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                log.log(.error, category: .audio, "OSC send error: \(error.localizedDescription)")
            }
        })
        messageCount += 1
    }

    /// Convenience: send a single float value
    public func send(address: String, float value: Float) {
        send(OSCMessage(address: address, arguments: [.float(value)]))
    }

    /// Convenience: send a single int value
    public func send(address: String, int value: Int32) {
        send(OSCMessage(address: address, arguments: [.int(value)]))
    }

    // MARK: - Echoelmusic Bio Addresses

    /// Send all bio parameters in one batch
    public func sendBioData(
        heartRate: Float,
        hrv: Float,
        breathRate: Float,
        breathPhase: Float,
        coherence: Float,
        audioRMS: Float,
        audioPitch: Float
    ) {
        send(address: "/echoelmusic/bio/heart/bpm", float: heartRate)
        send(address: "/echoelmusic/bio/heart/hrv", float: hrv)
        send(address: "/echoelmusic/bio/breath/rate", float: breathRate)
        send(address: "/echoelmusic/bio/breath/phase", float: breathPhase)
        send(address: "/echoelmusic/bio/coherence", float: coherence)
        send(address: "/echoelmusic/audio/rms", float: audioRMS)
        send(address: "/echoelmusic/audio/pitch", float: audioPitch)
    }

    // MARK: - Private

    private func startListener() {
        let params = NWParameters.udp
        do {
            guard let port = NWEndpoint.Port(rawValue: receivePort) else {
                log.log(.error, category: .audio, "OSC invalid port: \(receivePort)")
                return
            }
            listener = try NWListener(using: params, on: port)
        } catch {
            log.log(.error, category: .audio, "OSC listener failed: \(error.localizedDescription)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.receiveQueue ?? .main)
            self?.receiveLoop(connection: connection)
        }

        listener?.start(queue: receiveQueue)
    }

    private nonisolated func receiveLoop(connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data = data, let message = OSCMessage.decode(from: data) {
                Task { @MainActor [weak self] in
                    self?.messageCount += 1
                    self?.lastReceivedAddress = message.address
                    self?.onMessageReceived?(message)
                }
            }
            if error == nil {
                self?.receiveLoop(connection: connection)
            }
        }
    }

    private func startSender() {
        let host = NWEndpoint.Host(sendHost)
        guard let port = NWEndpoint.Port(rawValue: sendPort) else { return }
        sendConnection = NWConnection(host: host, port: port, using: .udp)
        sendConnection?.start(queue: sendQueue)
    }
}

// MARK: - OSC Settings View

#if canImport(SwiftUI)
import SwiftUI

/// Settings panel for OSC configuration
public struct OSCSettingsView: View {
    @Bindable private var engine = OSCEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: EchoelSpacing.medium) {
            VaporwaveSectionHeader(title: "OSC Network", icon: "network")

            GlassCard {
                VStack(spacing: EchoelSpacing.small) {
                    // Status
                    HStack {
                        Circle()
                            .fill(engine.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(engine.isRunning ? "Connected" : "Disconnected")
                            .font(EchoelBrandFont.body())
                        Spacer()
                        Text("\(engine.messageCount) msgs")
                            .font(EchoelBrandFont.caption())
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Send config
                    HStack {
                        Text("Send to:")
                            .font(EchoelBrandFont.label())
                        TextField("Host", text: $engine.sendHost)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 140)
                        Text(":")
                        TextField("Port", value: $engine.sendPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 70)
                    }

                    // Receive config
                    HStack {
                        Text("Listen on:")
                            .font(EchoelBrandFont.label())
                        Spacer()
                        TextField("Port", value: $engine.receivePort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 70)
                    }

                    Divider()

                    // Toggle
                    Button(action: {
                        if engine.isRunning {
                            engine.stop()
                        } else {
                            engine.start()
                        }
                    }) {
                        Text(engine.isRunning ? "Stop OSC" : "Start OSC")
                            .font(EchoelBrandFont.body())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EchoelSpacing.small)
                            .background(engine.isRunning ? Color.red.opacity(0.3) : EchoelBrand.accentPrimary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if !engine.lastReceivedAddress.isEmpty {
                        Text("Last: \(engine.lastReceivedAddress)")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(EchoelSpacing.medium)
            }

            // Predefined addresses
            GlassCard {
                VStack(alignment: .leading, spacing: EchoelSpacing.tiny) {
                    Text("Echoelmusic OSC Addresses")
                        .font(EchoelBrandFont.label())
                        .foregroundStyle(.secondary)

                    Group {
                        oscAddressRow("/echoelmusic/bio/heart/bpm", "float [40-200]")
                        oscAddressRow("/echoelmusic/bio/heart/hrv", "float [0-1]")
                        oscAddressRow("/echoelmusic/bio/breath/rate", "float [4-30]")
                        oscAddressRow("/echoelmusic/bio/breath/phase", "float [0-1]")
                        oscAddressRow("/echoelmusic/bio/coherence", "float [0-1]")
                        oscAddressRow("/echoelmusic/audio/rms", "float [0-1]")
                        oscAddressRow("/echoelmusic/audio/pitch", "float Hz")
                    }
                }
                .padding(EchoelSpacing.medium)
            }
        }
    }

    private func oscAddressRow(_ address: String, _ type: String) -> some View {
        HStack {
            Text(address)
                .font(EchoelBrandFont.dataSmall())
                .foregroundStyle(EchoelBrand.accentPrimary)
            Spacer()
            Text(type)
                .font(EchoelBrandFont.dataSmall())
                .foregroundStyle(.secondary)
        }
    }
}
#endif

#endif // canImport(Network)
