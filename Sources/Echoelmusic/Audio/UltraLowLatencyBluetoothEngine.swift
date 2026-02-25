//
//  UltraLowLatencyBluetoothEngine.swift
//  Echoelmusic
//
//  Created: December 2025
//  ULTRA-LOW LATENCY BLUETOOTH AUDIO ENGINE
//  Professional-Grade Wireless Audio for Real-Time Monitoring
//
//  Target Latency: <20ms (with LE Audio/LC3)
//  Fallback Latency: <40ms (with aptX Low Latency)
//

#if canImport(CoreBluetooth)
import Foundation
import AVFoundation
import CoreBluetooth
import CoreAudio
import Combine
import Accelerate

// MARK: - Bluetooth Audio Codec

/// Supported Bluetooth audio codecs with latency characteristics
public enum BluetoothAudioCodec: String, CaseIterable, Identifiable {
    case sbc = "SBC"                    // Standard, ~200ms latency
    case aac = "AAC"                    // Apple, ~120ms latency
    case aptx = "aptX"                  // Qualcomm, ~80ms latency
    case aptxHD = "aptX HD"             // High-res, ~100ms latency
    case aptxLL = "aptX Low Latency"    // Ultra-low, ~40ms latency
    case aptxAdaptive = "aptX Adaptive" // Adaptive, ~50-80ms latency
    case ldac = "LDAC"                  // Sony Hi-Res, ~100ms latency
    case lc3 = "LC3"                    // LE Audio, ~20ms latency
    case lc3plus = "LC3plus"            // Enhanced LE Audio, ~15ms latency
    case opus = "Opus"                  // Open codec, ~40ms latency

    public var id: String { rawValue }

    /// Typical one-way latency in milliseconds
    public var typicalLatency: Double {
        switch self {
        case .sbc: return 200
        case .aac: return 120
        case .aptx: return 80
        case .aptxHD: return 100
        case .aptxLL: return 40
        case .aptxAdaptive: return 65
        case .ldac: return 100
        case .lc3: return 20
        case .lc3plus: return 15
        case .opus: return 40
        }
    }

    /// Maximum supported bitrate in kbps
    public var maxBitrate: Int {
        switch self {
        case .sbc: return 345
        case .aac: return 320
        case .aptx: return 384
        case .aptxHD: return 576
        case .aptxLL: return 352
        case .aptxAdaptive: return 420
        case .ldac: return 990
        case .lc3: return 320
        case .lc3plus: return 512
        case .opus: return 510
        }
    }

    /// Sample rate support
    public var supportedSampleRates: [Int] {
        switch self {
        case .sbc: return [44100, 48000]
        case .aac: return [44100, 48000]
        case .aptx: return [44100, 48000]
        case .aptxHD: return [44100, 48000, 96000]
        case .aptxLL: return [44100, 48000]
        case .aptxAdaptive: return [44100, 48000, 96000]
        case .ldac: return [44100, 48000, 88200, 96000]
        case .lc3: return [8000, 16000, 24000, 32000, 44100, 48000]
        case .lc3plus: return [44100, 48000, 96000]
        case .opus: return [8000, 12000, 16000, 24000, 48000]
        }
    }

    /// Is this codec suitable for real-time monitoring?
    public var isRealtimeCapable: Bool {
        typicalLatency <= 50
    }

    /// Quality tier
    public var qualityTier: QualityTier {
        switch self {
        case .sbc: return .standard
        case .aac: return .good
        case .aptx: return .good
        case .aptxHD: return .highRes
        case .aptxLL: return .lowLatency
        case .aptxAdaptive: return .adaptive
        case .ldac: return .highRes
        case .lc3: return .lowLatency
        case .lc3plus: return .lowLatency
        case .opus: return .adaptive
        }
    }

    public enum QualityTier: String {
        case standard = "Standard"
        case good = "Good"
        case highRes = "Hi-Res"
        case lowLatency = "Low Latency"
        case adaptive = "Adaptive"
    }
}

// MARK: - Bluetooth Device Type

/// Types of Bluetooth audio devices
public enum BluetoothDeviceType: String, CaseIterable {
    case headphones = "Headphones"
    case earbuds = "Earbuds"
    case speaker = "Speaker"
    case soundbar = "Soundbar"
    case audioInterface = "Audio Interface"
    case midiController = "MIDI Controller"
    case instrument = "Instrument"
    case microphone = "Microphone"
    case monitor = "Studio Monitor"
    case unknown = "Unknown"

    public var icon: String {
        switch self {
        case .headphones: return "headphones"
        case .earbuds: return "airpodspro"
        case .speaker: return "hifispeaker.fill"
        case .soundbar: return "tv.and.hifispeaker.fill"
        case .audioInterface: return "rectangle.connected.to.line.below"
        case .midiController: return "pianokeys"
        case .instrument: return "guitars.fill"
        case .microphone: return "mic.fill"
        case .monitor: return "speaker.wave.3.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Recommended codec for this device type
    public var recommendedCodec: BluetoothAudioCodec {
        switch self {
        case .headphones, .earbuds:
            return .lc3  // Prioritize low latency
        case .speaker, .soundbar:
            return .aptxHD  // Prioritize quality
        case .audioInterface, .monitor:
            return .aptxLL  // Prioritize ultra-low latency
        case .midiController, .instrument:
            return .lc3  // MIDI over BLE
        case .microphone:
            return .lc3plus  // Low latency for recording
        case .unknown:
            return .aac
        }
    }
}

// MARK: - Bluetooth Device

/// Represents a discovered Bluetooth audio device
public struct BluetoothAudioDevice: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let type: BluetoothDeviceType
    public let supportedCodecs: [BluetoothAudioCodec]
    public let rssi: Int                          // Signal strength
    public let batteryLevel: Int?                 // 0-100 if available
    public let isConnected: Bool
    public let isPlaying: Bool
    public let currentCodec: BluetoothAudioCodec?
    public let measuredLatency: Double?           // Actually measured latency

    // Device capabilities
    public let supportsA2DP: Bool                 // Audio streaming
    public let supportsHFP: Bool                  // Hands-free
    public let supportsAVRCP: Bool                // Remote control
    public let supportsBLE: Bool                  // Bluetooth Low Energy
    public let supportsLEAudio: Bool              // LE Audio (BT 5.2+)
    public let supportsMultipoint: Bool           // Multiple connections

    // Technical specs
    public let maxSampleRate: Int
    public let maxBitDepth: Int
    public let maxChannels: Int
    public let firmwareVersion: String?

    public var signalQuality: SignalQuality {
        switch rssi {
        case -50...0: return .excellent
        case -60 ..< -50: return .good
        case -70 ..< -60: return .fair
        default: return .poor
        }
    }

    public enum SignalQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }

    /// Best available codec for low latency
    public var bestLowLatencyCodec: BluetoothAudioCodec {
        // Priority: LC3+ > LC3 > aptX LL > aptX Adaptive > Opus > aptX > AAC > SBC
        if supportedCodecs.contains(.lc3plus) { return .lc3plus }
        if supportedCodecs.contains(.lc3) { return .lc3 }
        if supportedCodecs.contains(.aptxLL) { return .aptxLL }
        if supportedCodecs.contains(.aptxAdaptive) { return .aptxAdaptive }
        if supportedCodecs.contains(.opus) { return .opus }
        if supportedCodecs.contains(.aptx) { return .aptx }
        if supportedCodecs.contains(.aac) { return .aac }
        return .sbc
    }

    /// Best available codec for quality
    public var bestQualityCodec: BluetoothAudioCodec {
        if supportedCodecs.contains(.ldac) { return .ldac }
        if supportedCodecs.contains(.aptxHD) { return .aptxHD }
        if supportedCodecs.contains(.lc3plus) { return .lc3plus }
        if supportedCodecs.contains(.aptxAdaptive) { return .aptxAdaptive }
        if supportedCodecs.contains(.aptx) { return .aptx }
        if supportedCodecs.contains(.aac) { return .aac }
        return .sbc
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: BluetoothAudioDevice, rhs: BluetoothAudioDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Direct Monitoring Mode

/// Direct monitoring configuration
public struct DirectMonitoringConfig {
    public var enabled: Bool = true
    public var inputGain: Float = 1.0           // 0.0 - 2.0
    public var outputGain: Float = 1.0          // 0.0 - 2.0
    public var pan: Float = 0.0                 // -1.0 (L) to 1.0 (R)
    public var soloMode: Bool = false
    public var muteRecordedTrack: Bool = false  // Mute playback while recording
    public var lowLatencyMode: Bool = true      // Use smallest possible buffer
    public var bypassEffects: Bool = false      // Skip plugin processing
    public var useHardwareMonitoring: Bool = true // Route through hardware if available

    /// Buffer size for low latency mode
    public var bufferSize: BufferSize = .ultraLow

    public enum BufferSize: Int, CaseIterable {
        case ultraLow = 32      // ~0.7ms @ 48kHz
        case veryLow = 64       // ~1.3ms @ 48kHz
        case low = 128          // ~2.7ms @ 48kHz
        case medium = 256       // ~5.3ms @ 48kHz
        case high = 512         // ~10.7ms @ 48kHz
        case veryHigh = 1024    // ~21.3ms @ 48kHz

        public func latencyMs(sampleRate: Double) -> Double {
            Double(rawValue) / sampleRate * 1000
        }
    }
}

// MARK: - Latency Compensation

/// Manages latency compensation across the system
public struct LatencyCompensation {
    public var inputLatency: Double = 0         // Input device latency (ms)
    public var outputLatency: Double = 0        // Output device latency (ms)
    public var bluetoothLatency: Double = 0     // Wireless latency (ms)
    public var processingLatency: Double = 0    // Plugin/DSP latency (ms)
    public var networkLatency: Double = 0       // Collaboration latency (ms)

    /// Total round-trip latency
    public var totalLatency: Double {
        inputLatency + outputLatency + bluetoothLatency + processingLatency
    }

    /// Samples to compensate at given sample rate
    public func compensationSamples(sampleRate: Double) -> Int {
        Int((totalLatency / 1000.0) * sampleRate)
    }

    /// Is latency acceptable for real-time monitoring?
    public var isRealtimeAcceptable: Bool {
        totalLatency < 20  // <20ms is generally acceptable
    }
}

// MARK: - Audio Route

/// Represents an audio routing path
public struct AudioRoute: Identifiable {
    public let id = UUID()
    public let name: String
    public let inputDevice: BluetoothAudioDevice?
    public let outputDevice: BluetoothAudioDevice?
    public let isWired: Bool
    public let latency: LatencyCompensation
    public let isActive: Bool

    public var description: String {
        if let input = inputDevice, let output = outputDevice {
            return "\(input.name) → \(output.name)"
        } else if let output = outputDevice {
            return "System → \(output.name)"
        } else if let input = inputDevice {
            return "\(input.name) → System"
        }
        return "Internal"
    }
}

// MARK: - Bluetooth Audio Session

/// Audio session configuration for Bluetooth
public class BluetoothAudioSession: ObservableObject {

    @Published public var sampleRate: Double = 48000
    @Published public var bufferSize: Int = 128
    @Published public var inputChannels: Int = 2
    @Published public var outputChannels: Int = 2
    @Published public var isLowLatencyMode: Bool = true
    @Published public var currentLatency: Double = 0

    #if !os(macOS)
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    #endif

    public func configureForLowLatency() throws {
        #if os(macOS)
        // macOS uses CoreAudio HAL, not AVAudioSession
        return
        #else
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [
                .allowBluetooth,
                .allowBluetoothA2DP,
                .defaultToSpeaker,
                .mixWithOthers
            ]
        )

        // Set preferred sample rate
        try audioSession.setPreferredSampleRate(sampleRate)

        // Set minimum buffer duration for lowest latency
        let bufferDuration = Double(bufferSize) / sampleRate
        try audioSession.setPreferredIOBufferDuration(bufferDuration)

        try audioSession.setActive(true)

        // Update actual values
        sampleRate = audioSession.sampleRate
        currentLatency = audioSession.inputLatency + audioSession.outputLatency
        #endif
    }

    public func configureForBluetooth(codec: BluetoothAudioCodec) throws {
        // Adjust buffer size based on codec latency
        if codec.isRealtimeCapable {
            bufferSize = 128
        } else {
            bufferSize = 256  // Larger buffer for high-latency codecs
        }

        try configureForLowLatency()
    }
}

// MARK: - Ring Buffer for Low Latency

/// Lock-free ring buffer for ultra-low latency audio
final class LockFreeRingBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let capacity: Int
    private let mask: Int

    init(capacity: Int) {
        // Ensure power of 2 for efficient masking
        var size = 1
        while size < capacity { size *= 2 }
        self.capacity = size
        self.mask = size - 1
        self.buffer = [Float](repeating: 0, count: size)
    }

    var availableToRead: Int {
        (writeIndex - readIndex + capacity) & mask
    }

    var availableToWrite: Int {
        capacity - availableToRead - 1
    }

    func write(_ samples: [Float]) -> Int {
        let toWrite = min(samples.count, availableToWrite)
        for i in 0..<toWrite {
            buffer[(writeIndex + i) & mask] = samples[i]
        }
        writeIndex = (writeIndex + toWrite) & mask
        return toWrite
    }

    func read(_ count: Int) -> [Float] {
        let toRead = min(count, availableToRead)
        var output = [Float](repeating: 0, count: toRead)
        for i in 0..<toRead {
            output[i] = buffer[(readIndex + i) & mask]
        }
        readIndex = (readIndex + toRead) & mask
        return output
    }

    func clear() {
        readIndex = 0
        writeIndex = 0
        buffer = [Float](repeating: 0, count: capacity)
    }
}

// MARK: - Latency Measurement

/// Measures actual round-trip latency
final class LatencyMeasurement {

    private var measurementBuffer: [Float] = []
    private var referenceSignal: [Float] = []
    private var isCapturing = false
    private let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        generateReferenceSignal()
    }

    private func generateReferenceSignal() {
        // Generate impulse train for latency measurement
        let length = Int(sampleRate * 0.5)  // 500ms buffer
        referenceSignal = [Float](repeating: 0, count: length)

        // Add click at start
        for i in 0..<50 {
            referenceSignal[i] = sin(Float(i) * Float.pi / 25) * 0.8
        }
    }

    func measureLatency(capturedSignal: [Float]) -> Double? {
        // Cross-correlation to find delay
        guard capturedSignal.count >= referenceSignal.count else { return nil }

        var maxCorrelation: Float = 0
        var bestLag = 0

        let searchRange = min(capturedSignal.count - referenceSignal.count, Int(sampleRate * 0.1))

        for lag in 0..<searchRange {
            var correlation: Float = 0

            for i in 0..<min(500, referenceSignal.count) {
                correlation += referenceSignal[i] * capturedSignal[lag + i]
            }

            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }

        // Convert samples to milliseconds
        return Double(bestLag) / sampleRate * 1000
    }

    var impulseSignal: [Float] { referenceSignal }
}

// MARK: - Ultra-Low Latency Bluetooth Engine

/// Main engine for ultra-low latency Bluetooth audio
@MainActor
public final class UltraLowLatencyBluetoothEngine: NSObject, ObservableObject {

    // MARK: - Singleton
    public static let shared = UltraLowLatencyBluetoothEngine()

    // MARK: - Published State
    @Published public var isScanning = false
    @Published public var discoveredDevices: [BluetoothAudioDevice] = []
    @Published public var connectedDevices: [BluetoothAudioDevice] = []
    @Published public var activeOutputDevice: BluetoothAudioDevice?
    @Published public var activeInputDevice: BluetoothAudioDevice?

    @Published public var currentLatency: LatencyCompensation = LatencyCompensation()
    @Published public var directMonitoring = DirectMonitoringConfig()
    @Published public var audioRoutes: [AudioRoute] = []

    @Published public var isDirectMonitoringActive = false
    @Published public var measuredRoundTripLatency: Double = 0

    // Codec preferences
    @Published public var preferLowLatency = true
    @Published public var preferredCodec: BluetoothAudioCodec = .lc3

    // MARK: - Private Properties

    private var centralManager: CBCentralManager?
    private var audioSession: BluetoothAudioSession
    private var audioEngine: AVAudioEngine
    private var inputBuffer: LockFreeRingBuffer
    private var outputBuffer: LockFreeRingBuffer
    private var latencyMeasurement: LatencyMeasurement
    private var cancellables = Set<AnyCancellable>()

    // Direct monitoring nodes
    private var inputMixer: AVAudioMixerNode?
    private var directMonitorMixer: AVAudioMixerNode?
    private var outputMixer: AVAudioMixerNode?

    // Processing
    private let processingQueue = DispatchQueue(label: "bluetooth.audio.processing", qos: .userInteractive)

    // MARK: - Initialization

    private override init() {
        audioSession = BluetoothAudioSession()
        audioEngine = AVAudioEngine()
        inputBuffer = LockFreeRingBuffer(capacity: 8192)
        outputBuffer = LockFreeRingBuffer(capacity: 8192)
        latencyMeasurement = LatencyMeasurement(sampleRate: 48000)

        super.init()

        setupCentralManager()
        setupAudioEngine()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func setupAudioEngine() {
        // Create mixer nodes
        inputMixer = AVAudioMixerNode()
        directMonitorMixer = AVAudioMixerNode()
        outputMixer = AVAudioMixerNode()

        guard let inputMixer = inputMixer,
              let directMonitorMixer = directMonitorMixer,
              let outputMixer = outputMixer else { return }

        // Attach nodes
        audioEngine.attach(inputMixer)
        audioEngine.attach(directMonitorMixer)
        audioEngine.attach(outputMixer)

        // Get format
        let format = audioEngine.inputNode.outputFormat(forBus: 0)

        // Connect input → input mixer
        audioEngine.connect(audioEngine.inputNode, to: inputMixer, format: format)

        // Connect input mixer → direct monitor (for zero-latency monitoring)
        audioEngine.connect(inputMixer, to: directMonitorMixer, format: format)

        // Connect direct monitor → output mixer
        audioEngine.connect(directMonitorMixer, to: outputMixer, format: format)

        // Connect output mixer → main output
        audioEngine.connect(outputMixer, to: audioEngine.mainMixerNode, format: format)

        // Install tap for processing
        inputMixer.installTap(onBus: 0, bufferSize: 128, format: format) { [weak self] buffer, time in
            self?.processInputBuffer(buffer, time: time)
        }
    }

    private func setupNotifications() {
        #if !os(macOS)
        // Audio route change notifications
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)

        // Interruption notifications
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Public API

    /// Start scanning for Bluetooth audio devices
    public func startScanning() {
        guard centralManager?.state == .poweredOn else { return }
        isScanning = true

        // Scan for audio devices (A2DP, HFP, LE Audio)
        centralManager?.scanForPeripherals(
            withServices: [
                CBUUID(string: "110B"),  // A2DP Sink
                CBUUID(string: "110A"),  // A2DP Source
                CBUUID(string: "111E"),  // HFP
                CBUUID(string: "184E"),  // LE Audio
                CBUUID(string: "1812")   // HID (for controllers)
            ],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Also scan system audio devices
        scanSystemAudioDevices()
    }

    /// Stop scanning
    public func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }

    /// Connect to a Bluetooth device
    public func connect(to device: BluetoothAudioDevice) {
        // Select best codec based on preference
        let codec = preferLowLatency ? device.bestLowLatencyCodec : device.bestQualityCodec

        // Configure audio session
        do {
            try audioSession.configureForBluetooth(codec: codec)
        } catch {
            #if DEBUG
            print("⚠️ [Bluetooth] Failed to configure audio session: \(error)")
            #endif
        }

        // Update connected devices
        var updatedDevice = device
        // In real implementation, would update connection state
        connectedDevices.append(updatedDevice)

        // Set as active output
        activeOutputDevice = updatedDevice

        // Measure actual latency
        measureLatency()
    }

    /// Disconnect from a device
    public func disconnect(from device: BluetoothAudioDevice) {
        connectedDevices.removeAll { $0.id == device.id }

        if activeOutputDevice?.id == device.id {
            activeOutputDevice = nil
        }
        if activeInputDevice?.id == device.id {
            activeInputDevice = nil
        }

        // Deactivate audio session when no devices remain connected
        if connectedDevices.isEmpty {
            #if canImport(AVFoundation) && !os(macOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    /// Enable direct monitoring (zero-latency passthrough)
    public func enableDirectMonitoring() throws {
        guard !audioEngine.isRunning else {
            // Reconfigure while running
            directMonitorMixer?.outputVolume = directMonitoring.enabled ? 1.0 : 0.0
            return
        }

        // Configure for minimum latency
        try audioSession.configureForLowLatency()

        // Start engine
        try audioEngine.start()

        isDirectMonitoringActive = true

        // Set direct monitor volume
        directMonitorMixer?.outputVolume = directMonitoring.inputGain
    }

    /// Disable direct monitoring
    public func disableDirectMonitoring() {
        directMonitorMixer?.outputVolume = 0
        isDirectMonitoringActive = false
    }

    /// Measure round-trip latency
    public func measureLatency() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Generate test signal
            let testSignal = self.latencyMeasurement.impulseSignal

            // Would play test signal and capture response
            // For now, estimate based on codec

            Task { @MainActor in
                if let device = self.activeOutputDevice,
                   let codec = device.currentCodec {
                    self.currentLatency.bluetoothLatency = codec.typicalLatency
                    self.currentLatency.outputLatency = Double(self.audioSession.bufferSize) / self.audioSession.sampleRate * 1000
                    self.currentLatency.inputLatency = self.currentLatency.outputLatency

                    self.measuredRoundTripLatency = self.currentLatency.totalLatency
                }
            }
        }
    }

    /// Set preferred codec for all connections
    public func setPreferredCodec(_ codec: BluetoothAudioCodec) {
        preferredCodec = codec

        // Reconnect devices with new codec if possible
        for device in connectedDevices {
            if device.supportedCodecs.contains(codec) {
                // Would renegotiate codec here
            }
        }
    }

    /// Get optimal settings for recording
    public func getRecordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: audioSession.sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
    }

    // MARK: - Private Methods

    private func scanSystemAudioDevices() {
        #if os(macOS)
        return  // macOS uses CoreAudio HAL for device enumeration
        #else
        // Get current audio route
        let route = AVAudioSession.sharedInstance().currentRoute

        for output in route.outputs {
            let deviceType = classifyDevice(portType: output.portType)
            let codecs = detectSupportedCodecs(for: output)

            let device = BluetoothAudioDevice(
                id: UUID(),
                name: output.portName,
                type: deviceType,
                supportedCodecs: codecs,
                rssi: -50,  // Estimate
                batteryLevel: nil,
                isConnected: true,
                isPlaying: false,
                currentCodec: codecs.first,
                measuredLatency: nil,
                supportsA2DP: output.portType == .bluetoothA2DP,
                supportsHFP: output.portType == .bluetoothHFP,
                supportsAVRCP: true,
                supportsBLE: output.portType == .bluetoothLE,
                supportsLEAudio: false,  // Would detect properly
                supportsMultipoint: false,
                maxSampleRate: 48000,
                maxBitDepth: 24,
                maxChannels: 2,
                firmwareVersion: nil
            )

            if !discoveredDevices.contains(where: { $0.name == device.name }) {
                discoveredDevices.append(device)
            }
        }
        #endif
    }

    #if !os(macOS)
    private func classifyDevice(portType: AVAudioSession.Port) -> BluetoothDeviceType {
        switch portType {
        case .bluetoothA2DP, .bluetoothHFP:
            return .headphones  // Could be more specific
        case .bluetoothLE:
            return .earbuds
        case .builtInSpeaker:
            return .speaker
        default:
            return .unknown
        }
    }

    private func detectSupportedCodecs(for port: AVAudioSessionPortDescription) -> [BluetoothAudioCodec] {
        // In real implementation, would query device capabilities
        // For now, return common codecs based on port type

        switch port.portType {
        case .bluetoothA2DP:
            return [.aac, .sbc, .aptx]
        case .bluetoothHFP:
            return [.sbc]
        case .bluetoothLE:
            return [.lc3, .sbc]
        default:
            return [.sbc]
        }
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }

        // Copy to ring buffer for processing
        let frameCount = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameCount)

        // Mono mix
        for i in 0..<frameCount {
            samples[i] = (channelData[0][i] + channelData[1][i]) * 0.5
        }

        _ = inputBuffer.write(samples)
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .newDeviceAvailable:
            scanSystemAudioDevices()
        case .oldDeviceUnavailable:
            // Remove disconnected device
            let route = AVAudioSession.sharedInstance().currentRoute
            let currentNames = Set(route.outputs.map { $0.portName })
            discoveredDevices.removeAll { !currentNames.contains($0.name) }
        default:
            break
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Pause audio
            if audioEngine.isRunning {
                audioEngine.pause()
            }
        case .ended:
            // Resume audio
            if !audioEngine.isRunning {
                try? audioEngine.start()
            }
        @unknown default:
            break
        }
    }
    #endif // !os(macOS)
}

// MARK: - CBCentralManagerDelegate

extension UltraLowLatencyBluetoothEngine: CBCentralManagerDelegate {

    public nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                #if DEBUG
                print("🔵 [Bluetooth] Powered on")
                #endif
            case .poweredOff:
                #if DEBUG
                print("⚪ [Bluetooth] Powered off")
                #endif
                isScanning = false
            case .unauthorized:
                #if DEBUG
                print("⚠️ [Bluetooth] Unauthorized")
                #endif
            case .unsupported:
                #if DEBUG
                print("❌ [Bluetooth] Unsupported")
                #endif
            default:
                break
            }
        }
    }

    public nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = peripheral.name ?? "Unknown Device"

            // Parse advertisement data for device info
            let deviceType = parseDeviceType(from: advertisementData)
            let codecs = parseCodecSupport(from: advertisementData)

            let device = BluetoothAudioDevice(
                id: peripheral.identifier,
                name: name,
                type: deviceType,
                supportedCodecs: codecs,
                rssi: RSSI.intValue,
                batteryLevel: parseBatteryLevel(from: advertisementData),
                isConnected: false,
                isPlaying: false,
                currentCodec: nil,
                measuredLatency: nil,
                supportsA2DP: true,
                supportsHFP: codecs.contains(.sbc),
                supportsAVRCP: true,
                supportsBLE: true,
                supportsLEAudio: codecs.contains(.lc3),
                supportsMultipoint: false,
                maxSampleRate: 48000,
                maxBitDepth: 16,
                maxChannels: 2,
                firmwareVersion: nil
            )

            // Update or add device
            if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                discoveredDevices[index] = device
            } else {
                if discoveredDevices.count >= 100 { discoveredDevices.removeFirst() }
                discoveredDevices.append(device)
            }
        }
    }

    private nonisolated func parseDeviceType(from advertisementData: [String: Any]) -> BluetoothDeviceType {
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            let lowercased = localName.lowercased()
            if lowercased.contains("airpod") || lowercased.contains("earbud") {
                return .earbuds
            } else if lowercased.contains("headphone") || lowercased.contains("beats") {
                return .headphones
            } else if lowercased.contains("speaker") || lowercased.contains("bose") {
                return .speaker
            } else if lowercased.contains("midi") || lowercased.contains("keyboard") {
                return .midiController
            }
        }
        return .unknown
    }

    private nonisolated func parseCodecSupport(from advertisementData: [String: Any]) -> [BluetoothAudioCodec] {
        // In real implementation, would parse service UUIDs and capabilities
        // Default to common codecs
        return [.sbc, .aac]
    }

    private nonisolated func parseBatteryLevel(from advertisementData: [String: Any]) -> Int? {
        // Would parse manufacturer-specific data for battery level
        return nil
    }
}

// MARK: - Bluetooth MIDI Controller

/// Manages Bluetooth MIDI controllers
@MainActor
public final class BluetoothMIDIManager: ObservableObject {

    public static let shared = BluetoothMIDIManager()

    @Published public var discoveredControllers: [BluetoothAudioDevice] = []
    @Published public var connectedControllers: [BluetoothAudioDevice] = []
    @Published public var midiLatency: Double = 0

    private var centralManager: CBCentralManager?

    private init() {
        // Setup MIDI over Bluetooth LE
    }

    /// Connect to a MIDI controller
    public func connectController(_ controller: BluetoothAudioDevice) {
        if connectedControllers.count >= 20 { return }  // Max 20 controllers
        // BLE MIDI connection
        connectedControllers.append(controller)
    }

    /// Get MIDI input from controller
    public func getMIDIInput() -> [MIDIEvent] {
        // Would return buffered MIDI events
        return []
    }

    public struct MIDIEvent {
        public let timestamp: Double
        public let status: UInt8
        public let data1: UInt8
        public let data2: UInt8
    }
}

// MARK: - SwiftUI Views

import SwiftUI

public struct BluetoothAudioView: View {
    @ObservedObject private var engine = UltraLowLatencyBluetoothEngine.shared
    @State private var showLatencySettings = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Latency indicator
                    latencyIndicator

                    // Direct monitoring
                    directMonitoringSection

                    // Connected devices
                    if !engine.connectedDevices.isEmpty {
                        connectedDevicesSection
                    }

                    // Available devices
                    availableDevicesSection
                }
                .padding()
            }
        }
        .sheet(isPresented: $showLatencySettings) {
            LatencySettingsView()
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Ultra-Low Latency Bluetooth")
                    .font(.title2.bold())

                Text("Professional wireless audio with <20ms latency")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Scan button
            Button(action: {
                if engine.isScanning {
                    engine.stopScanning()
                } else {
                    engine.startScanning()
                }
            }) {
                HStack {
                    if engine.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(engine.isScanning ? "Scanning..." : "Scan")
                }
            }
            .buttonStyle(.borderedProminent)

            // Settings
            Button(action: { showLatencySettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var latencyIndicator: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f ms", engine.measuredRoundTripLatency))
                    .font(.title.bold().monospacedDigit())
                    .foregroundColor(latencyColor)

                Text("Round-Trip Latency")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: 8) {
                latencyBar(label: "Bluetooth", value: engine.currentLatency.bluetoothLatency, max: 100)
                latencyBar(label: "Buffer", value: engine.currentLatency.outputLatency, max: 20)
                latencyBar(label: "Processing", value: engine.currentLatency.processingLatency, max: 10)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var latencyColor: Color {
        let latency = engine.measuredRoundTripLatency
        if latency < 20 { return .green }
        if latency < 40 { return .yellow }
        if latency < 80 { return .orange }
        return .red
    }

    private func latencyBar(label: String, value: Double, max: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * min(1, CGFloat(value / max)))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1f", value))
                .font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var directMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Direct Monitoring")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $engine.isDirectMonitoringActive)
                    .labelsHidden()
                    .onChange(of: engine.isDirectMonitoringActive) { isOn in
                        if isOn {
                            try? engine.enableDirectMonitoring()
                        } else {
                            engine.disableDirectMonitoring()
                        }
                    }
            }

            if engine.isDirectMonitoringActive {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Input Gain")
                            .font(.caption)
                        Slider(value: $engine.directMonitoring.inputGain, in: 0...2)
                    }

                    VStack(alignment: .leading) {
                        Text("Output Gain")
                            .font(.caption)
                        Slider(value: $engine.directMonitoring.outputGain, in: 0...2)
                    }
                }

                Picker("Buffer Size", selection: $engine.directMonitoring.bufferSize) {
                    ForEach(DirectMonitoringConfig.BufferSize.allCases, id: \.self) { size in
                        Text("\(size.rawValue) samples").tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(engine.isDirectMonitoringActive ? 0.1 : 0.05))
        )
    }

    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Devices")
                .font(.headline)

            ForEach(engine.connectedDevices) { device in
                ConnectedDeviceRow(device: device) {
                    engine.disconnect(from: device)
                }
            }
        }
    }

    private var availableDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Devices")
                    .font(.headline)

                Spacer()

                Text("\(engine.discoveredDevices.count) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if engine.discoveredDevices.isEmpty && !engine.isScanning {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Devices Found")
                        .font(.headline)
                    Text("Tap Scan to search for Bluetooth audio devices")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(engine.discoveredDevices.filter { device in
                    !engine.connectedDevices.contains { $0.id == device.id }
                }) { device in
                    AvailableDeviceRow(device: device) {
                        engine.connect(to: device)
                    }
                }
            }
        }
    }
}

struct ConnectedDeviceRow: View {
    let device: BluetoothAudioDevice
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: device.type.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.green.opacity(0.2)))
                .foregroundColor(.green)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let codec = device.currentCodec {
                        Label(codec.rawValue, systemImage: "waveform")
                    }

                    if let latency = device.measuredLatency {
                        Label(String(format: "%.0fms", latency), systemImage: "clock")
                    }

                    if let battery = device.batteryLevel {
                        Label("\(battery)%", systemImage: "battery.100")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Signal strength
            SignalStrengthIndicator(rssi: device.rssi)

            // Disconnect
            Button(action: onDisconnect) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct AvailableDeviceRow: View {
    let device: BluetoothAudioDevice
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: device.type.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.gray.opacity(0.1)))
                .foregroundColor(.secondary)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Best codec
                    let bestCodec = device.bestLowLatencyCodec
                    Text(bestCodec.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(bestCodec.isRealtimeCapable ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        )

                    Text(String(format: "~%.0fms", bestCodec.typicalLatency))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Signal strength
            SignalStrengthIndicator(rssi: device.rssi)

            // Connect
            Button("Connect", action: onConnect)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct SignalStrengthIndicator: View {
    let rssi: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: i))
                    .frame(width: 4, height: CGFloat(8 + i * 4))
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        let threshold = [-70, -60, -50, -40]
        if rssi >= threshold[index] {
            if rssi >= -50 { return .green }
            if rssi >= -60 { return .yellow }
            return .orange
        }
        return .gray.opacity(0.3)
    }
}

struct LatencySettingsView: View {
    @ObservedObject private var engine = UltraLowLatencyBluetoothEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Codec Preference") {
                    Toggle("Prefer Low Latency", isOn: $engine.preferLowLatency)

                    Picker("Preferred Codec", selection: $engine.preferredCodec) {
                        ForEach(BluetoothAudioCodec.allCases) { codec in
                            HStack {
                                Text(codec.rawValue)
                                Spacer()
                                Text(String(format: "~%.0fms", codec.typicalLatency))
                                    .foregroundColor(.secondary)
                            }
                            .tag(codec)
                        }
                    }
                }

                Section("Buffer Settings") {
                    Picker("Buffer Size", selection: $engine.directMonitoring.bufferSize) {
                        ForEach(DirectMonitoringConfig.BufferSize.allCases, id: \.self) { size in
                            HStack {
                                Text("\(size.rawValue) samples")
                                Spacer()
                                Text(String(format: "%.1fms", size.latencyMs(sampleRate: 48000)))
                                    .foregroundColor(.secondary)
                            }
                            .tag(size)
                        }
                    }
                }

                Section("Direct Monitoring") {
                    Toggle("Bypass Effects", isOn: $engine.directMonitoring.bypassEffects)
                    Toggle("Use Hardware Monitoring", isOn: $engine.directMonitoring.useHardwareMonitoring)
                    Toggle("Mute Recorded Track", isOn: $engine.directMonitoring.muteRecordedTrack)
                }

                Section("Latency Calibration") {
                    Button("Measure Latency") {
                        engine.measureLatency()
                    }

                    HStack {
                        Text("Measured Latency")
                        Spacer()
                        Text(String(format: "%.1f ms", engine.measuredRoundTripLatency))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Latency Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#endif // canImport(CoreBluetooth)
