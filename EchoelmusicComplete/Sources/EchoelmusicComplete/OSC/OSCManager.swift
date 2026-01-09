// OSCManager.swift
// OSC (Open Sound Control) for external app integration

import Foundation
import Network

// MARK: - OSC Manager

@MainActor
public final class OSCManager: ObservableObject {
    // MARK: - Published Properties

    @Published public var isConnected: Bool = false
    @Published public var isSending: Bool = false
    @Published public var targetHost: String = "127.0.0.1"
    @Published public var sendPort: UInt16 = AppConstants.oscSendPort
    @Published public var receivePort: UInt16 = AppConstants.oscReceivePort

    // MARK: - Private Properties

    private var sendConnection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.echoelmusic.osc")

    // MARK: - Callbacks

    public var onMessageReceived: ((String, [Any]) -> Void)?

    // MARK: - Initialization

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection

    public func connect() {
        // Setup sender
        let host = NWEndpoint.Host(targetHost)
        let port = NWEndpoint.Port(rawValue: sendPort)!

        sendConnection = NWConnection(host: host, port: port, using: .udp)
        sendConnection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isConnected = true
                case .failed, .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        sendConnection?.start(queue: queue)

        // Setup receiver
        do {
            let params = NWParameters.udp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: receivePort)!)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }
            listener?.start(queue: queue)
        } catch {
            print("OSC listener error: \(error)")
        }

        isSending = true
    }

    public func disconnect() {
        sendConnection?.cancel()
        sendConnection = nil
        listener?.cancel()
        listener = nil
        isConnected = false
        isSending = false
    }

    // MARK: - Send Messages

    public func sendBioData(_ data: BiometricData) {
        guard isSending else { return }

        sendFloat("\(AppConstants.oscAddressPrefix)/bio/heart/rate", value: Float(data.heartRate))
        sendFloat("\(AppConstants.oscAddressPrefix)/bio/heart/hrv", value: Float(data.hrvMs))
        sendFloat("\(AppConstants.oscAddressPrefix)/bio/heart/coherence", value: Float(data.normalizedCoherence))
        sendFloat("\(AppConstants.oscAddressPrefix)/bio/breath/rate", value: Float(data.breathingRate))
        sendFloat("\(AppConstants.oscAddressPrefix)/bio/breath/phase", value: Float(data.breathPhase))
    }

    public func sendFloat(_ address: String, value: Float) {
        let message = createOSCMessage(address: address, arguments: [value])
        sendMessage(message)
    }

    public func sendInt(_ address: String, value: Int32) {
        let message = createOSCMessage(address: address, arguments: [value])
        sendMessage(message)
    }

    public func sendString(_ address: String, value: String) {
        let message = createOSCMessage(address: address, arguments: [value])
        sendMessage(message)
    }

    // MARK: - OSC Message Creation

    private func createOSCMessage(address: String, arguments: [Any]) -> Data {
        var data = Data()

        // Address (null-terminated, padded to 4 bytes)
        data.append(contentsOf: address.utf8)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // Type tag
        var typeTag = ","
        for arg in arguments {
            switch arg {
            case _ as Float: typeTag += "f"
            case _ as Int32: typeTag += "i"
            case _ as String: typeTag += "s"
            default: break
            }
        }
        data.append(contentsOf: typeTag.utf8)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // Arguments
        for arg in arguments {
            switch arg {
            case let f as Float:
                var bigEndian = f.bitPattern.bigEndian
                data.append(Data(bytes: &bigEndian, count: 4))
            case let i as Int32:
                var bigEndian = i.bigEndian
                data.append(Data(bytes: &bigEndian, count: 4))
            case let s as String:
                data.append(contentsOf: s.utf8)
                data.append(0)
                while data.count % 4 != 0 { data.append(0) }
            default:
                break
            }
        }

        return data
    }

    private func sendMessage(_ data: Data) {
        sendConnection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("OSC send error: \(error)")
            }
        })
    }

    // MARK: - Receive

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveMessage(connection)
    }

    private func receiveMessage(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let error = error {
                print("OSC receive error: \(error)")
                return
            }

            if let data = data {
                self?.parseOSCMessage(data)
            }

            self?.receiveMessage(connection)
        }
    }

    private func parseOSCMessage(_ data: Data) {
        // Simplified OSC parsing
        guard let addressEnd = data.firstIndex(of: 0) else { return }
        let address = String(data: data[0..<addressEnd], encoding: .utf8) ?? ""

        Task { @MainActor in
            self.onMessageReceived?(address, [])
        }
    }
}

// MARK: - OSC Address Constants

public enum OSCAddresses {
    public static let heartRate = "\(AppConstants.oscAddressPrefix)/bio/heart/rate"
    public static let hrv = "\(AppConstants.oscAddressPrefix)/bio/heart/hrv"
    public static let coherence = "\(AppConstants.oscAddressPrefix)/bio/heart/coherence"
    public static let breathRate = "\(AppConstants.oscAddressPrefix)/bio/breath/rate"
    public static let breathPhase = "\(AppConstants.oscAddressPrefix)/bio/breath/phase"

    public static let audioFrequency = "\(AppConstants.oscAddressPrefix)/audio/frequency"
    public static let audioVolume = "\(AppConstants.oscAddressPrefix)/audio/volume"

    public static let visualHue = "\(AppConstants.oscAddressPrefix)/visual/color/hue"
    public static let visualPulse = "\(AppConstants.oscAddressPrefix)/visual/pulse/rate"

    public static let sessionTransport = "\(AppConstants.oscAddressPrefix)/session/transport"
}
