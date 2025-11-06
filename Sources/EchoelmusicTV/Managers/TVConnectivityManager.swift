import Foundation
import Network
import Combine

/// Manages connections between Apple TV and iPhone devices
/// Uses Bonjour/Network framework for local discovery
@MainActor
class TVConnectivityManager: ObservableObject {

    // MARK: - Published Properties

    /// Connected iPhone devices
    @Published private(set) var connectedDevices: [ConnectedDevice] = []

    /// Discovery active
    @Published private(set) var isDiscovering: Bool = false

    /// Last sync time
    @Published private(set) var lastSyncTime: Date?

    // MARK: - Private Properties

    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]

    // MARK: - Discovery

    /// Start discovering iPhone devices on local network
    func startDiscovery() {
        guard !isDiscovering else { return }

        do {
            // Create listener on TCP port (using Bonjour for local discovery)
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            // Advertise service
            let service = NWListener.Service(name: "Echoelmusic TV", type: "_echoelmusic._tcp")
            listener = try NWListener(using: parameters, on: .any)
            listener?.service = service

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .main)
            isDiscovering = true

            print("[TVConnectivity] 🔍 Discovery started - waiting for iPhone connections")

        } catch {
            print("[TVConnectivity] ❌ Failed to start discovery: \(error)")
        }
    }

    /// Stop discovering devices
    func stopDiscovery() {
        listener?.cancel()
        listener = nil
        isDiscovering = false

        print("[TVConnectivity] 🔍 Discovery stopped")
    }

    // MARK: - Connection Handling

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("[TVConnectivity] ✅ Listener ready")

        case .failed(let error):
            print("[TVConnectivity] ❌ Listener failed: \(error)")
            isDiscovering = false

        case .cancelled:
            print("[TVConnectivity] ⏹️ Listener cancelled")
            isDiscovering = false

        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let deviceId = UUID()

        print("[TVConnectivity] 📱 New connection from iPhone")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state, deviceId: deviceId, connection: connection)
            }
        }

        connection.start(queue: .main)
        connections[deviceId] = connection

        // Start receiving data
        receiveData(from: connection, deviceId: deviceId)
    }

    private func handleConnectionState(_ state: NWConnection.State, deviceId: UUID, connection: NWConnection) {
        switch state {
        case .ready:
            print("[TVConnectivity] ✅ iPhone connected: \(deviceId)")

            // Add to connected devices (with placeholder data)
            let device = ConnectedDevice(
                id: deviceId,
                name: "iPhone",
                hrv: 0,
                heartRate: 70,
                coherence: 50
            )
            connectedDevices.append(device)

        case .failed(let error):
            print("[TVConnectivity] ❌ Connection failed: \(error)")
            disconnectDevice(deviceId)

        case .cancelled:
            print("[TVConnectivity] 📱 iPhone disconnected: \(deviceId)")
            disconnectDevice(deviceId)

        default:
            break
        }
    }

    // MARK: - Data Reception

    private func receiveData(from connection: NWConnection, deviceId: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let data = data, !data.isEmpty {
                    self.processReceivedData(data, from: deviceId)
                }

                if !isComplete && error == nil {
                    // Continue receiving
                    self.receiveData(from: connection, deviceId: deviceId)
                } else if let error = error {
                    print("[TVConnectivity] ❌ Receive error: \(error)")
                    self.disconnectDevice(deviceId)
                }
            }
        }
    }

    private func processReceivedData(_ data: Data, from deviceId: UUID) {
        do {
            // Parse JSON data from iPhone
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleMessage(json, from: deviceId)
            }
        } catch {
            print("[TVConnectivity] ⚠️ Failed to parse data: \(error)")
        }
    }

    private func handleMessage(_ message: [String: Any], from deviceId: UUID) {
        guard let messageType = message["type"] as? String else { return }

        switch messageType {
        case "healthUpdate":
            updateDeviceHealth(deviceId, message: message)

        case "deviceInfo":
            updateDeviceInfo(deviceId, message: message)

        default:
            print("[TVConnectivity] ⚠️ Unknown message type: \(messageType)")
        }
    }

    private func updateDeviceHealth(_ deviceId: UUID, message: [String: Any]) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        if let hrv = message["hrv"] as? Double {
            connectedDevices[index].hrv = hrv
        }

        if let heartRate = message["heartRate"] as? Double {
            connectedDevices[index].heartRate = heartRate
        }

        if let coherence = message["coherence"] as? Double {
            connectedDevices[index].coherence = coherence
        }

        lastSyncTime = Date()

        print("[TVConnectivity] 📊 Health data updated for \(connectedDevices[index].name)")
    }

    private func updateDeviceInfo(_ deviceId: UUID, message: [String: Any]) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == deviceId }) else { return }

        if let name = message["name"] as? String {
            connectedDevices[index].name = name
        }

        print("[TVConnectivity] 📱 Device info updated: \(connectedDevices[index].name)")
    }

    // MARK: - Disconnection

    private func disconnectDevice(_ deviceId: UUID) {
        connections[deviceId]?.cancel()
        connections.removeValue(forKey: deviceId)
        connectedDevices.removeAll { $0.id == deviceId }
    }

    func disconnectAll() {
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        connectedDevices.removeAll()

        print("[TVConnectivity] 📱 All devices disconnected")
    }

    // MARK: - Cleanup

    deinit {
        stopDiscovery()
        disconnectAll()
    }
}

// MARK: - Supporting Types

struct ConnectedDevice: Identifiable {
    let id: UUID
    var name: String
    var hrv: Double
    var heartRate: Double
    var coherence: Double
}
