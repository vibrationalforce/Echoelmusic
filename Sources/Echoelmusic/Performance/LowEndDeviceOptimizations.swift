//
//  LowEndDeviceOptimizations.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Ultra-Low-End Device Support & Cloud Rendering
//
//  Ziel: Echoelmusic läuft auf JEDEM Gerät - auch 100€ Smartphones
//
//  Features:
//  - Cloud Rendering für schwache Geräte
//  - Ultra-Lite Modus (minimal CPU/RAM)
//  - Offline-First mit progressivem Feature-Loading
//  - Batterieschonende Audio-Verarbeitung
//  - Dynamische Feature-Deaktivierung
//

import Foundation
import Combine
import Network

// MARK: - Device Capability Assessment

/// Bewertet Geräteleistung und wählt optimale Strategie
@MainActor
public final class DeviceCapabilityAssessor: ObservableObject {
    public static let shared = DeviceCapabilityAssessor()

    // MARK: - Published State

    @Published public private(set) var deviceTier: DeviceTier = .unknown
    @Published public private(set) var availableRAM: UInt64 = 0
    @Published public private(set) var cpuCoreCount: Int = 0
    @Published public private(set) var gpuCapability: GPUCapability = .basic
    @Published public private(set) var recommendedMode: OperationMode = .standard
    @Published public private(set) var batteryLevel: Float = 1.0
    @Published public private(set) var isLowPowerMode: Bool = false
    @Published public private(set) var thermalState: ThermalState = .nominal

    // MARK: - Device Tiers

    public enum DeviceTier: String, CaseIterable, Comparable {
        case ultraLow = "Ultra-Low (Cloud empfohlen)"
        case low = "Low-End"
        case medium = "Mid-Range"
        case high = "High-End"
        case ultra = "Ultra/Pro"
        case unknown = "Unbekannt"

        public static func < (lhs: DeviceTier, rhs: DeviceTier) -> Bool {
            let order: [DeviceTier] = [.ultraLow, .low, .medium, .high, .ultra, .unknown]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }

        public var maxAudioChannels: Int {
            switch self {
            case .ultraLow: return 2
            case .low: return 8
            case .medium: return 16
            case .high: return 32
            case .ultra: return 64
            case .unknown: return 8
            }
        }

        public var maxVideoResolution: VideoResolution {
            switch self {
            case .ultraLow: return .sd480
            case .low: return .hd720
            case .medium: return .hd1080
            case .high: return .uhd4K
            case .ultra: return .uhd8K
            case .unknown: return .hd720
            }
        }

        public var recommendedSampleRate: Double {
            switch self {
            case .ultraLow: return 22050
            case .low: return 44100
            case .medium: return 48000
            case .high: return 48000
            case .ultra: return 96000
            case .unknown: return 44100
            }
        }

        public var maxParticles: Int {
            switch self {
            case .ultraLow: return 64
            case .low: return 512
            case .medium: return 2048
            case .high: return 8192
            case .ultra: return 32768
            case .unknown: return 512
            }
        }
    }

    public enum GPUCapability {
        case none           // Kein GPU / Software Rendering
        case basic          // OpenGL ES 2.0 / DirectX 9
        case standard       // OpenGL ES 3.0 / DirectX 11
        case advanced       // Metal / Vulkan / DirectX 12
        case professional   // Metal 3 / Vulkan 1.3+
    }

    public enum VideoResolution {
        case sd480, hd720, hd1080, uhd4K, uhd8K

        public var size: (width: Int, height: Int) {
            switch self {
            case .sd480: return (854, 480)
            case .hd720: return (1280, 720)
            case .hd1080: return (1920, 1080)
            case .uhd4K: return (3840, 2160)
            case .uhd8K: return (7680, 4320)
            }
        }
    }

    public enum OperationMode: String, CaseIterable {
        case cloudAssisted = "Cloud-Assisted"
        case ultraLite = "Ultra-Lite"
        case lite = "Lite"
        case standard = "Standard"
        case performance = "Performance"
        case professional = "Professional"
    }

    public enum ThermalState {
        case nominal, fair, serious, critical
    }

    // MARK: - Initialization

    private init() {
        assessDevice()
        startMonitoring()
    }

    // MARK: - Device Assessment

    private func assessDevice() {
        // RAM Check
        availableRAM = ProcessInfo.processInfo.physicalMemory
        let ramGB = Double(availableRAM) / 1_073_741_824

        // CPU Cores
        cpuCoreCount = ProcessInfo.processInfo.processorCount

        // Determine tier
        if ramGB < 2 {
            deviceTier = .ultraLow
        } else if ramGB < 3 {
            deviceTier = .low
        } else if ramGB < 6 {
            deviceTier = .medium
        } else if ramGB < 12 {
            deviceTier = .high
        } else {
            deviceTier = .ultra
        }

        // GPU Capability (simplified check)
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            if device.supportsFamily(.metal3) {
                gpuCapability = .professional
            } else if device.supportsFamily(.common3) {
                gpuCapability = .advanced
            } else {
                gpuCapability = .standard
            }
        }
        #else
        gpuCapability = .basic
        #endif

        // Recommend mode
        recommendedMode = determineRecommendedMode()
    }

    private func determineRecommendedMode() -> OperationMode {
        switch deviceTier {
        case .ultraLow:
            return .cloudAssisted
        case .low:
            return isLowPowerMode ? .ultraLite : .lite
        case .medium:
            return isLowPowerMode ? .lite : .standard
        case .high:
            return .performance
        case .ultra:
            return .professional
        case .unknown:
            return .lite
        }
    }

    private func startMonitoring() {
        // Monitor thermal state
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateThermalState()
        }

        // Monitor low power mode
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            self?.recommendedMode = self?.determineRecommendedMode() ?? .standard
        }
    }

    private func updateThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .nominal
        }

        // Downgrade mode if thermal throttling
        if thermalState == .serious || thermalState == .critical {
            if recommendedMode == .professional {
                recommendedMode = .performance
            } else if recommendedMode == .performance {
                recommendedMode = .standard
            }
        }
    }
}

// MARK: - Cloud Rendering Client

/// Cloud-basiertes Rendering für Ultra-Low-End Geräte
@MainActor
public final class CloudRenderingClient: ObservableObject {
    public static let shared = CloudRenderingClient()

    // MARK: - State

    @Published public var isEnabled: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var latency: TimeInterval = 0
    @Published public var quality: StreamQuality = .adaptive
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error(String)
    }

    public enum StreamQuality: String, CaseIterable {
        case low = "Low (250kbps)"
        case medium = "Medium (500kbps)"
        case high = "High (1Mbps)"
        case adaptive = "Adaptive"

        public var bitrate: Int {
            switch self {
            case .low: return 250_000
            case .medium: return 500_000
            case .high: return 1_000_000
            case .adaptive: return 0 // Dynamic
            }
        }
    }

    // MARK: - Configuration

    public struct CloudConfig {
        public var serverURL: URL?
        public var apiKey: String?
        public var preferredRegion: String = "auto"
        public var maxLatency: TimeInterval = 0.1 // 100ms
        public var fallbackToLocal: Bool = true

        public static let `default` = CloudConfig()
    }

    public var config: CloudConfig = .default

    // MARK: - Private

    private var networkMonitor: NWPathMonitor?
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Connection

    public func connect() async throws {
        guard let serverURL = config.serverURL else {
            throw CloudError.notConfigured
        }

        connectionState = .connecting

        // Create WebSocket connection
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()

        // Wait for connection
        try await waitForConnection()

        connectionState = .connected
        isConnected = true

        // Start heartbeat
        startHeartbeat()

        // Start receiving
        receiveMessages()
    }

    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        connectionState = .disconnected
        isConnected = false
    }

    // MARK: - Rendering

    /// Sende Audio-Daten zur Cloud-Verarbeitung
    public func processAudio(
        samples: [Float],
        sampleRate: Double,
        effects: [String]
    ) async throws -> [Float] {
        guard isConnected else {
            throw CloudError.notConnected
        }

        let request = AudioProcessRequest(
            samples: samples,
            sampleRate: sampleRate,
            effects: effects
        )

        let startTime = Date()

        // Send request
        let data = try JSONEncoder().encode(request)
        try await webSocketTask?.send(.data(data))

        // Wait for response
        let response = try await receiveAudioResponse()

        latency = Date().timeIntervalSince(startTime)

        return response.samples
    }

    /// Sende Video-Frame zur Cloud-Verarbeitung
    public func processVideoFrame(
        frameData: Data,
        effects: [String]
    ) async throws -> Data {
        guard isConnected else {
            throw CloudError.notConnected
        }

        // Compress frame for transmission
        let compressedData = compressFrame(frameData)

        let request = VideoProcessRequest(
            frameData: compressedData,
            effects: effects,
            quality: quality
        )

        let startTime = Date()

        let data = try JSONEncoder().encode(request)
        try await webSocketTask?.send(.data(data))

        let response = try await receiveVideoResponse()

        latency = Date().timeIntervalSince(startTime)

        return response.frameData
    }

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status != .satisfied && self?.isConnected == true {
                    self?.connectionState = .reconnecting
                    try? await self?.reconnect()
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }

    private func waitForConnection() async throws {
        // Simplified - real implementation would use proper handshake
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                try? await self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async throws {
        let ping = HeartbeatMessage(timestamp: Date())
        let data = try JSONEncoder().encode(ping)
        try await webSocketTask?.send(.data(data))
    }

    private func receiveMessages() {
        Task {
            while isConnected {
                do {
                    let message = try await webSocketTask?.receive()
                    handleMessage(message)
                } catch {
                    if isConnected {
                        connectionState = .error(error.localizedDescription)
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message?) {
        // Handle incoming messages
    }

    private func reconnect() async throws {
        disconnect()
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        try await connect()
    }

    private func receiveAudioResponse() async throws -> AudioProcessResponse {
        guard let message = try await webSocketTask?.receive() else {
            throw CloudError.noResponse
        }

        switch message {
        case .data(let data):
            return try JSONDecoder().decode(AudioProcessResponse.self, from: data)
        case .string(let string):
            guard let data = string.data(using: .utf8) else {
                throw CloudError.invalidResponse
            }
            return try JSONDecoder().decode(AudioProcessResponse.self, from: data)
        @unknown default:
            throw CloudError.invalidResponse
        }
    }

    private func receiveVideoResponse() async throws -> VideoProcessResponse {
        guard let message = try await webSocketTask?.receive() else {
            throw CloudError.noResponse
        }

        switch message {
        case .data(let data):
            return try JSONDecoder().decode(VideoProcessResponse.self, from: data)
        default:
            throw CloudError.invalidResponse
        }
    }

    private func compressFrame(_ data: Data) -> Data {
        // Simplified - real implementation would use proper compression
        return data
    }
}

// MARK: - Cloud Messages

struct AudioProcessRequest: Codable {
    let samples: [Float]
    let sampleRate: Double
    let effects: [String]
}

struct AudioProcessResponse: Codable {
    let samples: [Float]
    let processingTime: TimeInterval
}

struct VideoProcessRequest: Codable {
    let frameData: Data
    let effects: [String]
    let quality: CloudRenderingClient.StreamQuality
}

struct VideoProcessResponse: Codable {
    let frameData: Data
    let processingTime: TimeInterval
}

struct HeartbeatMessage: Codable {
    let timestamp: Date
}

enum CloudError: LocalizedError {
    case notConfigured
    case notConnected
    case noResponse
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Cloud rendering not configured"
        case .notConnected: return "Not connected to cloud server"
        case .noResponse: return "No response from server"
        case .invalidResponse: return "Invalid response from server"
        case .timeout: return "Connection timeout"
        }
    }
}

// MARK: - Ultra-Lite Audio Processor

/// Minimal-CPU Audio-Verarbeitung für schwache Geräte
public final class UltraLiteAudioProcessor {
    public static let shared = UltraLiteAudioProcessor()

    // MARK: - Configuration

    public struct Config {
        /// Reduzierte Sample-Rate (22.05kHz statt 48kHz)
        public var sampleRate: Double = 22050

        /// Kleine Buffer-Größe für weniger Speicher
        public var bufferSize: Int = 256

        /// Mono statt Stereo
        public var monoMode: Bool = true

        /// Vereinfachte Effekte
        public var simplifiedEffects: Bool = true

        /// Keine Visualisierung
        public var disableVisualization: Bool = true

        public static let ultraLite = Config(
            sampleRate: 22050,
            bufferSize: 256,
            monoMode: true,
            simplifiedEffects: true,
            disableVisualization: true
        )

        public static let lite = Config(
            sampleRate: 44100,
            bufferSize: 512,
            monoMode: false,
            simplifiedEffects: true,
            disableVisualization: false
        )
    }

    public var config: Config = .ultraLite

    private init() {}

    // MARK: - Simplified Effects

    /// Einfacher 1-Band EQ (nur Bass/Treble)
    public func simpleEQ(samples: inout [Float], bass: Float, treble: Float) {
        guard !samples.isEmpty else { return }

        // Sehr einfacher Low-Shelf / High-Shelf
        var prevLow: Float = 0
        var prevHigh: Float = 0

        let bassCoeff = bass * 0.5
        let trebleCoeff = treble * 0.3

        for i in 0..<samples.count {
            let input = samples[i]

            // Simple low-pass for bass
            let low = prevLow + 0.1 * (input - prevLow)
            prevLow = low

            // Simple high-pass for treble
            let high = input - low
            prevHigh = high

            samples[i] = input + (low * bassCoeff) + (high * trebleCoeff)
        }
    }

    /// Einfache Lautstärkeregelung mit Soft-Clipping
    public func simpleGain(samples: inout [Float], gain: Float) {
        for i in 0..<samples.count {
            var s = samples[i] * gain

            // Soft clipping
            if s > 1.0 {
                s = 1.0 - exp(1.0 - s)
            } else if s < -1.0 {
                s = -1.0 + exp(1.0 + s)
            }

            samples[i] = s
        }
    }

    /// Mono-Downmix
    public func stereoToMono(left: [Float], right: [Float]) -> [Float] {
        guard left.count == right.count else { return left }

        return zip(left, right).map { ($0 + $1) * 0.5 }
    }

    /// Sample-Rate Konvertierung (einfach)
    public func downsample(samples: [Float], factor: Int) -> [Float] {
        guard factor > 1 else { return samples }

        var result = [Float]()
        result.reserveCapacity(samples.count / factor)

        for i in stride(from: 0, to: samples.count, by: factor) {
            // Simple averaging
            var sum: Float = 0
            let end = min(i + factor, samples.count)
            for j in i..<end {
                sum += samples[j]
            }
            result.append(sum / Float(end - i))
        }

        return result
    }
}

// MARK: - Progressive Feature Loader

/// Lädt Features progressiv basierend auf Geräteleistung
@MainActor
public final class ProgressiveFeatureLoader: ObservableObject {
    public static let shared = ProgressiveFeatureLoader()

    // MARK: - Feature Flags

    @Published public var enabledFeatures: Set<Feature> = []
    @Published public var loadingProgress: Double = 0
    @Published public var isLoading: Bool = false

    public enum Feature: String, CaseIterable {
        // Tier 1: Essential (alle Geräte)
        case basicPlayback = "Basic Playback"
        case simpleRecording = "Simple Recording"
        case basicMixer = "Basic Mixer"

        // Tier 2: Standard (2GB+ RAM)
        case multiTrack = "Multi-Track"
        case basicEffects = "Basic Effects"
        case midiInput = "MIDI Input"

        // Tier 3: Advanced (4GB+ RAM)
        case advancedEffects = "Advanced Effects"
        case videoPlayback = "Video Playback"
        case biofeedback = "Biofeedback"

        // Tier 4: Pro (8GB+ RAM)
        case multiVideoTrack = "Multi Video Track"
        case advancedVisualization = "Advanced Visualization"
        case liveStreaming = "Live Streaming"

        // Tier 5: Ultra (16GB+ RAM)
        case uhd4K = "4K Video"
        case spatialAudio = "Spatial Audio"
        case mlProcessing = "ML Processing"

        public var requiredRAMGB: Double {
            switch self {
            case .basicPlayback, .simpleRecording, .basicMixer:
                return 1.0
            case .multiTrack, .basicEffects, .midiInput:
                return 2.0
            case .advancedEffects, .videoPlayback, .biofeedback:
                return 4.0
            case .multiVideoTrack, .advancedVisualization, .liveStreaming:
                return 8.0
            case .uhd4K, .spatialAudio, .mlProcessing:
                return 16.0
            }
        }

        public var tier: Int {
            switch requiredRAMGB {
            case ..<2: return 1
            case ..<4: return 2
            case ..<8: return 3
            case ..<16: return 4
            default: return 5
            }
        }
    }

    private init() {}

    // MARK: - Loading

    /// Lade Features progressiv basierend auf verfügbarem RAM
    public func loadFeatures() async {
        isLoading = true
        loadingProgress = 0

        let availableRAMGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        // Sortiere Features nach Tier
        let sortedFeatures = Feature.allCases.sorted { $0.tier < $1.tier }

        for (index, feature) in sortedFeatures.enumerated() {
            // Check RAM requirement
            if feature.requiredRAMGB <= availableRAMGB {
                // Simulate loading time
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

                enabledFeatures.insert(feature)
            }

            loadingProgress = Double(index + 1) / Double(sortedFeatures.count)
        }

        isLoading = false
        loadingProgress = 1.0

        print("📱 Loaded \(enabledFeatures.count)/\(Feature.allCases.count) features for \(String(format: "%.1f", availableRAMGB))GB RAM device")
    }

    /// Prüfe ob Feature verfügbar
    public func isFeatureEnabled(_ feature: Feature) -> Bool {
        enabledFeatures.contains(feature)
    }

    /// Feature on-demand laden
    public func loadFeatureOnDemand(_ feature: Feature) async -> Bool {
        let availableRAMGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        if feature.requiredRAMGB <= availableRAMGB {
            enabledFeatures.insert(feature)
            return true
        }

        return false
    }
}

// MARK: - Battery Saver Mode

/// Batterieschonender Modus
@MainActor
public final class BatterySaverManager: ObservableObject {
    public static let shared = BatterySaverManager()

    @Published public var isEnabled: Bool = false
    @Published public var batteryLevel: Float = 1.0
    @Published public var isCharging: Bool = false
    @Published public var autoEnableThreshold: Float = 0.2 // 20%

    public var currentProfile: BatterySaverProfile {
        if !isEnabled { return .disabled }
        if batteryLevel < 0.1 { return .critical }
        if batteryLevel < 0.2 { return .aggressive }
        return .moderate
    }

    public enum BatterySaverProfile {
        case disabled
        case moderate
        case aggressive
        case critical

        public var maxFPS: Int {
            switch self {
            case .disabled: return 120
            case .moderate: return 60
            case .aggressive: return 30
            case .critical: return 15
            }
        }

        public var audioBufferMultiplier: Int {
            switch self {
            case .disabled: return 1
            case .moderate: return 2
            case .aggressive: return 4
            case .critical: return 8
            }
        }

        public var disableVisualization: Bool {
            switch self {
            case .disabled, .moderate: return false
            case .aggressive, .critical: return true
            }
        }

        public var reduceNetworkActivity: Bool {
            switch self {
            case .disabled: return false
            default: return true
            }
        }
    }

    private init() {
        startBatteryMonitoring()
    }

    private func startBatteryMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBatteryStatus()
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBatteryStatus()
        }

        updateBatteryStatus()
        #endif
    }

    private func updateBatteryStatus() {
        #if os(iOS)
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

        // Auto-enable if below threshold and not charging
        if batteryLevel < autoEnableThreshold && !isCharging && !isEnabled {
            isEnabled = true
            print("🔋 Battery Saver auto-enabled at \(Int(batteryLevel * 100))%")
        }

        // Auto-disable when charging
        if isCharging && isEnabled {
            isEnabled = false
            print("🔌 Battery Saver disabled - charging")
        }
        #endif
    }
}

// MARK: - Offline First Manager

/// Offline-First Modus für instabile Verbindungen
@MainActor
public final class OfflineFirstManager: ObservableObject {
    public static let shared = OfflineFirstManager()

    @Published public var isOnline: Bool = true
    @Published public var pendingSyncItems: Int = 0
    @Published public var lastSyncDate: Date?
    @Published public var offlineStorageUsed: Int64 = 0
    @Published public var offlineStorageLimit: Int64 = 500_000_000 // 500MB default

    private var networkMonitor: NWPathMonitor?

    private init() {
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                if wasOffline && self?.isOnline == true {
                    await self?.syncPendingItems()
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }

    /// Speichere Daten lokal für Offline-Nutzung
    public func cacheForOffline(_ data: Data, key: String) throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let offlineDir = cacheDir.appendingPathComponent("OfflineCache", isDirectory: true)

        try FileManager.default.createDirectory(at: offlineDir, withIntermediateDirectories: true)

        let fileURL = offlineDir.appendingPathComponent(key)
        try data.write(to: fileURL)

        updateStorageUsed()
    }

    /// Lade Offline-gecachte Daten
    public func loadFromOfflineCache(_ key: String) -> Data? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = cacheDir.appendingPathComponent("OfflineCache/\(key)")

        return try? Data(contentsOf: fileURL)
    }

    /// Queue Änderung für späteren Sync
    public func queueForSync(_ item: SyncItem) {
        // Add to sync queue
        pendingSyncItems += 1
    }

    /// Sync pending items when online
    private func syncPendingItems() async {
        guard isOnline, pendingSyncItems > 0 else { return }

        // Sync logic here
        pendingSyncItems = 0
        lastSyncDate = Date()
    }

    private func updateStorageUsed() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let offlineDir = cacheDir.appendingPathComponent("OfflineCache")

        if let contents = try? FileManager.default.contentsOfDirectory(at: offlineDir, includingPropertiesForKeys: [.fileSizeKey]) {
            offlineStorageUsed = contents.reduce(0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + Int64(size)
            }
        }
    }

    public struct SyncItem {
        let id: UUID
        let type: String
        let data: Data
        let timestamp: Date
    }
}
