import Foundation
import Combine
import Network

/// OSC (Open Sound Control) Manager for Unreal Engine Integration
///
/// Enables bidirectional communication between BLAB and Unreal Engine via OSC protocol.
///
/// Features:
/// - Real-time parameter streaming to Unreal Engine
/// - Bidirectional communication (send & receive)
/// - Audio parameter mapping
/// - Spatial position updates
/// - Blueprint event triggering
/// - Metasound parameter control
///
/// Use Cases:
/// - Audio-reactive environments
/// - Spatial audio positioning in UE
/// - Music visualization
/// - Interactive installations
/// - VR/AR audio experiences
///
/// Usage:
/// ```swift
/// let osc = OSCManager.shared
/// osc.connect(host: "192.168.1.100", port: 8000)
/// osc.sendAudioLevel(0.8)
/// osc.sendSpatialPosition(x: 1.0, y: 0.5, z: 0.0)
/// ```
///
/// Unreal Engine Setup:
/// 1. Enable OSC Plugin in UE
/// 2. Create OSC Server component
/// 3. Bind OSC addresses to Blueprint events
/// 4. Set listening port (default: 8000)
@available(iOS 15.0, *)
public class OSCManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = OSCManager()

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var host: String = ""
    @Published public private(set) var port: Int = 8000
    @Published public private(set) var messagesSent: Int = 0
    @Published public private(set) var messagesReceived: Int = 0

    // MARK: - Configuration

    public struct Configuration {
        public var sendPort: Int = 8000
        public var receivePort: Int = 8001
        public var updateRate: Double = 60.0  // Hz (60 FPS default)
        public var enableLogging: Bool = false

        public init(
            sendPort: Int = 8000,
            receivePort: Int = 8001,
            updateRate: Double = 60.0,
            enableLogging: Bool = false
        ) {
            self.sendPort = sendPort
            self.receivePort = receivePort
            self.updateRate = updateRate
            self.enableLogging = enableLogging
        }
    }

    public var configuration = Configuration()

    // MARK: - OSC Address Space

    public enum OSCAddress: String {
        // Audio parameters
        case audioLevel = "/blab/audio/level"
        case audioFrequency = "/blab/audio/frequency"
        case audioBPM = "/blab/audio/bpm"
        case audioSpectrum = "/blab/audio/spectrum"

        // Spatial audio
        case spatialPosition = "/blab/spatial/position"
        case spatialRotation = "/blab/spatial/rotation"
        case spatialDistance = "/blab/spatial/distance"

        // Biometric data
        case heartRate = "/blab/bio/heartrate"
        case hrvCoherence = "/blab/bio/hrv"
        case breathingRate = "/blab/bio/breathing"

        // DSP parameters
        case filterCutoff = "/blab/dsp/filter/cutoff"
        case reverbWetness = "/blab/dsp/reverb/wet"
        case delayTime = "/blab/dsp/delay/time"

        // Events
        case trigger = "/blab/event/trigger"
        case beatDetect = "/blab/event/beat"
        case transient = "/blab/event/transient"
    }

    // MARK: - Private Properties

    private var udpConnection: NWConnection?
    private var udpListener: NWListener?
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Cached values for rate limiting
    private var lastAudioLevel: Float = 0.0
    private var lastHeartRate: Float = 0.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Connection

    /// Connect to Unreal Engine via OSC
    public func connect(host: String, port: Int = 8000) {
        guard !isConnected else {
            print("[OSC] Already connected")
            return
        }

        self.host = host
        self.port = port

        // Create UDP connection for sending
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        udpConnection = NWConnection(
            to: endpoint,
            using: .udp
        )

        udpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    print("[OSC] ✅ Connected to \(host):\(port)")
                }
                self?.startUpdateTimer()

            case .failed(let error):
                print("[OSC] ❌ Connection failed: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }

            case .cancelled:
                DispatchQueue.main.async {
                    self?.isConnected = false
                }

            default:
                break
            }
        }

        udpConnection?.start(queue: .global(qos: .userInitiated))

        // Start UDP listener for receiving (optional)
        startListener()
    }

    /// Disconnect from Unreal Engine
    public func disconnect() {
        guard isConnected else {
            print("[OSC] Not connected")
            return
        }

        stopUpdateTimer()
        udpConnection?.cancel()
        udpListener?.cancel()

        isConnected = false
        print("[OSC] ✅ Disconnected")
    }

    // MARK: - Audio Parameters

    /// Send audio level (0.0 - 1.0)
    public func sendAudioLevel(_ level: Float) {
        sendOSCMessage(.audioLevel, arguments: [level])
        lastAudioLevel = level
    }

    /// Send audio frequency in Hz
    public func sendAudioFrequency(_ frequency: Float) {
        sendOSCMessage(.audioFrequency, arguments: [frequency])
    }

    /// Send BPM (beats per minute)
    public func sendBPM(_ bpm: Float) {
        sendOSCMessage(.audioBPM, arguments: [bpm])
    }

    /// Send audio spectrum (array of frequency bands)
    public func sendAudioSpectrum(_ spectrum: [Float]) {
        sendOSCMessage(.audioSpectrum, arguments: spectrum)
    }

    // MARK: - Spatial Audio

    /// Send 3D spatial position
    public func sendSpatialPosition(x: Float, y: Float, z: Float) {
        sendOSCMessage(.spatialPosition, arguments: [x, y, z])
    }

    /// Send 3D rotation (Euler angles in degrees)
    public func sendSpatialRotation(pitch: Float, yaw: Float, roll: Float) {
        sendOSCMessage(.spatialRotation, arguments: [pitch, yaw, roll])
    }

    /// Send distance from listener
    public func sendSpatialDistance(_ distance: Float) {
        sendOSCMessage(.spatialDistance, arguments: [distance])
    }

    // MARK: - Biometric Data

    /// Send heart rate (BPM)
    public func sendHeartRate(_ bpm: Float) {
        sendOSCMessage(.heartRate, arguments: [bpm])
        lastHeartRate = bpm
    }

    /// Send HRV coherence (0.0 - 1.0)
    public func sendHRVCoherence(_ coherence: Float) {
        sendOSCMessage(.hrvCoherence, arguments: [coherence])
    }

    /// Send breathing rate (breaths per minute)
    public func sendBreathingRate(_ rate: Float) {
        sendOSCMessage(.breathingRate, arguments: [rate])
    }

    // MARK: - DSP Parameters

    /// Send filter cutoff frequency
    public func sendFilterCutoff(_ frequency: Float) {
        sendOSCMessage(.filterCutoff, arguments: [frequency])
    }

    /// Send reverb wetness (0.0 - 1.0)
    public func sendReverbWetness(_ wetness: Float) {
        sendOSCMessage(.reverbWetness, arguments: [wetness])
    }

    /// Send delay time (seconds)
    public func sendDelayTime(_ time: Float) {
        sendOSCMessage(.delayTime, arguments: [time])
    }

    // MARK: - Events

    /// Send trigger event with ID
    public func sendTrigger(_ id: String) {
        sendOSCMessage(.trigger, arguments: [id])
    }

    /// Send beat detection event
    public func sendBeatEvent(intensity: Float) {
        sendOSCMessage(.beatDetect, arguments: [intensity])
    }

    /// Send transient detection event
    public func sendTransientEvent(frequency: Float, magnitude: Float) {
        sendOSCMessage(.transient, arguments: [frequency, magnitude])
    }

    // MARK: - Custom Messages

    /// Send custom OSC message
    public func sendCustomMessage(address: String, arguments: [Any]) {
        let message = OSCMessage(address: address, arguments: arguments)
        sendRawMessage(message)
    }

    // MARK: - Private Methods

    private func sendOSCMessage(_ address: OSCAddress, arguments: [Any]) {
        let message = OSCMessage(address: address.rawValue, arguments: arguments)
        sendRawMessage(message)
    }

    private func sendRawMessage(_ message: OSCMessage) {
        guard isConnected, let connection = udpConnection else {
            if configuration.enableLogging {
                print("[OSC] ⚠️ Not connected, message dropped")
            }
            return
        }

        let data = encodeOSCMessage(message)

        connection.send(
            content: data,
            completion: .contentProcessed { [weak self] error in
                if let error = error {
                    print("[OSC] ❌ Send error: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.messagesSent += 1
                    }

                    if self?.configuration.enableLogging == true {
                        print("[OSC] ➡️ \(message.address) \(message.arguments)")
                    }
                }
            }
        )
    }

    private func encodeOSCMessage(_ message: OSCMessage) -> Data {
        var data = Data()

        // OSC address (null-terminated, 4-byte aligned)
        let addressData = message.address.data(using: .utf8)!
        data.append(addressData)
        data.append(0)  // Null terminator
        // Padding to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }

        // Type tag string
        var typeTag = ","
        for arg in message.arguments {
            switch arg {
            case is Float: typeTag += "f"
            case is Int: typeTag += "i"
            case is String: typeTag += "s"
            default: typeTag += "b"  // Blob
            }
        }

        let typeTagData = typeTag.data(using: .utf8)!
        data.append(typeTagData)
        data.append(0)  // Null terminator
        while data.count % 4 != 0 {
            data.append(0)
        }

        // Arguments
        for arg in message.arguments {
            if let floatVal = arg as? Float {
                data.append(contentsOf: withUnsafeBytes(of: floatVal.bitPattern.bigEndian) { Data($0) })
            } else if let intVal = arg as? Int {
                let int32 = Int32(intVal)
                data.append(contentsOf: withUnsafeBytes(of: int32.bigEndian) { Data($0) })
            } else if let stringVal = arg as? String {
                let stringData = stringVal.data(using: .utf8)!
                data.append(stringData)
                data.append(0)
                while data.count % 4 != 0 {
                    data.append(0)
                }
            }
        }

        return data
    }

    // MARK: - UDP Listener

    private func startListener() {
        do {
            udpListener = try NWListener(using: .udp, on: NWEndpoint.Port(integerLiteral: UInt16(configuration.receivePort)))

            udpListener?.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }

            udpListener?.start(queue: .global(qos: .userInitiated))

            if configuration.enableLogging {
                print("[OSC] 🎧 Listening on port \(configuration.receivePort)")
            }
        } catch {
            print("[OSC] ❌ Failed to start listener: \(error)")
        }
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data = data {
                self?.handleIncomingMessage(data)
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func handleIncomingMessage(_ data: Data) {
        // Parse incoming OSC message
        // In real implementation, decode OSC data

        DispatchQueue.main.async {
            self.messagesReceived += 1
        }

        if configuration.enableLogging {
            print("[OSC] ⬅️ Received \(data.count) bytes")
        }
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        let interval = 1.0 / configuration.updateRate

        updateTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.sendPeriodicUpdates()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func sendPeriodicUpdates() {
        // Send periodic updates (if needed)
        // This is called at the configured update rate
    }

    // MARK: - Statistics

    public struct Statistics {
        public var messagesSent: Int
        public var messagesReceived: Int
        public var updateRate: Double
        public var isConnected: Bool

        public var messagesPerSecond: Double {
            return Double(messagesSent) / 60.0  // Rough estimate
        }
    }

    public func getStatistics() -> Statistics {
        return Statistics(
            messagesSent: messagesSent,
            messagesReceived: messagesReceived,
            updateRate: configuration.updateRate,
            isConnected: isConnected
        )
    }

    // MARK: - Supporting Types

    private struct OSCMessage {
        let address: String
        let arguments: [Any]
    }
}
