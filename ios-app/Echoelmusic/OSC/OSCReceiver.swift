// OSCReceiver.swift
// iOS OSC Server for receiving Desktop Engine feedback
//
// Listens on port 8001 for analysis data from Desktop Engine

import Foundation
import Network

/// OSC Server for iOS - receives analysis data from Desktop
class OSCReceiver: ObservableObject {
    @Published var isListening: Bool = false
    @Published var messagesReceived: Int = 0

    private var listener: NWListener?
    private let port: UInt16 = 8001

    // MARK: - Lifecycle

    init() {}

    deinit {
        stopListening()
    }

    // MARK: - Start/Stop Listening

    /// Start OSC server on port 8001
    func startListening() {
        guard listener == nil else {
            print("OSC Receiver: Already listening")
            return
        }

        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                        print("✅ OSC Receiver: Listening on port \(self?.port ?? 0)")

                    case .failed(let error):
                        self?.isListening = false
                        print("❌ OSC Receiver: Failed to listen: \(error)")

                    case .cancelled:
                        self?.isListening = false
                        print("OSC Receiver: Listener cancelled")

                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))

        } catch {
            print("❌ OSC Receiver: Failed to create listener: \(error)")
        }
    }

    /// Stop OSC server
    func stopListening() {
        listener?.cancel()
        listener = nil
        isListening = false
        print("OSC Receiver: Stopped")
    }

    // MARK: - Handle Incoming Connections

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        receiveMessage(on: connection)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let error = error {
                print("OSC Receiver: Receive error: \(error)")
                return
            }

            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data)

                DispatchQueue.main.async {
                    self?.messagesReceived += 1
                }
            }

            // Continue receiving
            self?.receiveMessage(on: connection)
        }
    }

    // MARK: - Message Handling

    private func handleReceivedData(_ data: Data) {
        guard let message = OSCMessage.decode(data) else {
            print("OSC Receiver: Failed to decode message")
            return
        }

        DispatchQueue.main.async {
            self.routeMessage(message)
        }
    }

    private func routeMessage(_ message: OSCMessage) {
        switch message.address {
        case "/echoel/analysis/rms":
            if let rms = message.arguments.first?.floatValue {
                NotificationCenter.default.post(
                    name: .oscRMSReceived,
                    object: rms
                )
                print("📊 OSC: RMS = \(String(format: "%.1f", rms)) dB")
            }

        case "/echoel/analysis/peak":
            if let peak = message.arguments.first?.floatValue {
                NotificationCenter.default.post(
                    name: .oscPeakReceived,
                    object: peak
                )
                print("📊 OSC: Peak = \(String(format: "%.1f", peak)) dB")
            }

        case "/echoel/analysis/spectrum":
            let spectrum = message.arguments.compactMap { $0.floatValue }
            if spectrum.count == 8 {
                NotificationCenter.default.post(
                    name: .oscSpectrumReceived,
                    object: spectrum
                )
                print("📊 OSC: Spectrum received (8 bands)")
            }

        case "/echoel/status/cpu":
            if let cpu = message.arguments.first?.floatValue {
                NotificationCenter.default.post(
                    name: .oscCPUReceived,
                    object: cpu
                )
                print("💻 OSC: CPU = \(String(format: "%.1f", cpu))%")
            }

        default:
            print("OSC Receiver: Unhandled message: \(message.address)")
        }
    }
}
