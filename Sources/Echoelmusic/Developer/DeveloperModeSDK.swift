// DeveloperModeSDK.swift
// Echoelmusic - 2000% Ralph Wiggum Laser Feuerwehr LKW Fahrer Mode
//
// Developer SDK for creating plugins, extensions, and integrations
// Open API for worldwide developer collaboration
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - SDK Version

/// Echoelmusic SDK version information
public struct SDKVersion: CustomStringConvertible, Sendable {
    public static let current = SDKVersion(major: 2, minor: 0, patch: 0, build: 2000)

    public let major: Int
    public let minor: Int
    public let patch: Int
    public let build: Int
    public let codename = "Ralph Wiggum Laser Feuerwehr LKW Fahrer"

    public var description: String {
        "\(major).\(minor).\(patch) (Build \(build)) - \(codename)"
    }

    public var semver: String {
        "\(major).\(minor).\(patch)"
    }
}

// MARK: - Plugin Protocol

/// Protocol for creating Echoelmusic plugins
public protocol EchoelmusicPlugin: AnyObject {
    /// Unique plugin identifier
    var identifier: String { get }

    /// Human-readable plugin name
    var name: String { get }

    /// Plugin version
    var version: String { get }

    /// Plugin author
    var author: String { get }

    /// Plugin description
    var pluginDescription: String { get }

    /// Required SDK version
    var requiredSDKVersion: String { get }

    /// Plugin capabilities
    var capabilities: Set<PluginCapability> { get }

    /// Called when plugin is loaded
    func onLoad(context: PluginContext) async throws

    /// Called when plugin is unloaded
    func onUnload() async

    /// Called each frame (60Hz) for real-time plugins
    func onFrame(deltaTime: TimeInterval)

    /// Called when bio data is updated
    func onBioDataUpdate(_ bioData: BioData)

    /// Called when quantum state changes
    func onQuantumStateChange(_ state: QuantumPluginState)

    /// Process audio buffer (for audio plugins)
    func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int)

    /// Render visual frame (for visual plugins)
    func renderVisual(context: RenderContext) -> VisualOutput?

    /// Handle user interaction
    func handleInteraction(_ interaction: UserInteraction)
}

// MARK: - Plugin Capability

/// Capabilities a plugin can declare
public enum PluginCapability: String, CaseIterable, Sendable {
    // Audio
    case audioInput = "Audio Input"
    case audioOutput = "Audio Output"
    case audioEffect = "Audio Effect"
    case audioGenerator = "Audio Generator"
    case midiInput = "MIDI Input"
    case midiOutput = "MIDI Output"

    // Visual
    case visualization = "Visualization"
    case shaderEffect = "Shader Effect"
    case particleSystem = "Particle System"
    case threeD = "3D Rendering"

    // Bio
    case bioInput = "Bio Input"
    case bioProcessing = "Bio Processing"
    case hrvAnalysis = "HRV Analysis"
    case coherenceTracking = "Coherence Tracking"

    // Quantum
    case quantumProcessing = "Quantum Processing"
    case quantumVisualization = "Quantum Visualization"
    case quantumEntanglement = "Quantum Entanglement"

    // Control
    case gestureInput = "Gesture Input"
    case voiceInput = "Voice Input"
    case midiControl = "MIDI Control"
    case oscControl = "OSC Control"
    case dmxOutput = "DMX Output"

    // Integration
    case cloudSync = "Cloud Sync"
    case collaboration = "Collaboration"
    case streaming = "Streaming"
    case recording = "Recording"

    // AI
    case aiGeneration = "AI Generation"
    case machineLearning = "Machine Learning"
    case neuralNetwork = "Neural Network"
}

// MARK: - Plugin Context

/// Context provided to plugins when loaded
public struct PluginContext: Sendable {
    public let sdkVersion: SDKVersion
    public let hostAppVersion: String
    public let platform: Platform
    public let deviceCapabilities: DeviceCapabilities
    public let dataDirectory: URL
    public let cacheDirectory: URL
    public let sharedState: SharedPluginState

    public enum Platform: String, Sendable {
        case iOS, macOS, watchOS, tvOS, visionOS
        case android, windows, linux
    }

    public struct DeviceCapabilities: Sendable {
        public var hasGPU: Bool
        public var hasNeuralEngine: Bool
        public var hasBiometrics: Bool
        public var hasHaptics: Bool
        public var hasSpatialAudio: Bool
        public var maxTextureSize: Int
        public var cpuCores: Int
        public var memoryMB: Int
    }
}

// MARK: - Bio Data

/// Biometric data structure for plugins
public struct BioData: Sendable {
    public var heartRate: Float?
    public var hrvSDNN: Float?
    public var hrvRMSSD: Float?
    public var coherence: Float
    public var breathingRate: Float?
    public var skinConductance: Float?
    public var temperature: Float?
    public var timestamp: Date

    public static let empty = BioData(
        heartRate: nil,
        hrvSDNN: nil,
        hrvRMSSD: nil,
        coherence: 0.5,
        breathingRate: nil,
        skinConductance: nil,
        temperature: nil,
        timestamp: Date()
    )
}

// MARK: - Quantum Plugin State

/// Quantum state information for plugins
public struct QuantumPluginState: Sendable {
    public var coherenceLevel: Float
    public var entanglementStrength: Float
    public var superpositionCount: Int
    public var emulationMode: EmulationMode
    public var timestamp: Date

    public enum EmulationMode: String, Sendable {
        case classical, quantumInspired, fullQuantum, hybridPhotonic, bioCoherent
    }
}

// MARK: - Type Aliases for Protocol Compatibility

/// Type aliases for backward compatibility and protocol conformance
public typealias RenderContext = SDKRenderContext
public typealias VisualOutput = SDKVisualOutput
public typealias UserInteraction = SDKUserInteraction

// MARK: - Render Context

/// Context for visual rendering plugins
public struct SDKRenderContext: Sendable {
    public var width: Int
    public var height: Int
    public var pixelScale: Float
    public var deltaTime: TimeInterval
    public var totalTime: TimeInterval
    public var frameNumber: Int
    public var bioData: BioData
    public var quantumState: QuantumPluginState
}

// MARK: - Visual Output

/// Output from visual plugins
public struct SDKVisualOutput: Sendable {
    public var pixelData: Data?
    public var textureId: UInt32?
    public var shaderUniforms: [String: Float]
    public var blendMode: BlendMode

    public enum BlendMode: String, Sendable {
        case replace, add, multiply, screen, overlay
    }
}

// MARK: - User Interaction

/// User interaction events for plugins
public struct SDKUserInteraction: Sendable {
    public var type: InteractionType
    public var position: SIMD2<Float>?
    public var value: Float?
    public var gesture: String?
    public var timestamp: Date

    public enum InteractionType: String, Sendable {
        case tap, doubleTap, longPress
        case pan, pinch, rotate
        case swipe, drag, drop
        case gesture, voice
        case midi, osc
    }
}

// MARK: - Shared Plugin State

/// Shared state accessible to all plugins
public actor SharedPluginState {
    public var parameters: [String: Double] = [:]
    public var flags: [String: Bool] = [:]
    public var messages: [PluginMessage] = []

    public struct PluginMessage: Sendable {
        public var fromPlugin: String
        public var toPlugin: String?
        public var type: String
        public var data: [String: String]
        public var timestamp: Date
    }

    public func setParameter(_ key: String, value: Double) {
        parameters[key] = value
    }

    public func getParameter(_ key: String) -> Double? {
        parameters[key]
    }

    public func setFlag(_ key: String, value: Bool) {
        flags[key] = value
    }

    public func getFlag(_ key: String) -> Bool {
        flags[key] ?? false
    }

    public func sendMessage(_ message: PluginMessage) {
        messages.append(message)
        // Keep last 100 messages
        if messages.count > 100 {
            messages.removeFirst(messages.count - 100)
        }
    }

    public func getMessages(for pluginId: String?) -> [PluginMessage] {
        if let id = pluginId {
            return messages.filter { $0.toPlugin == nil || $0.toPlugin == id }
        }
        return messages
    }
}

// MARK: - Default Plugin Implementation

/// Default implementation for optional plugin methods
public extension EchoelmusicPlugin {
    func onFrame(deltaTime: TimeInterval) {}
    func onBioDataUpdate(_ bioData: BioData) {}
    func onQuantumStateChange(_ state: QuantumPluginState) {}
    func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {}
    func renderVisual(context: RenderContext) -> VisualOutput? { nil }
    func handleInteraction(_ interaction: UserInteraction) {}
}

// MARK: - Plugin Manager

/// Manages plugin lifecycle and communication
@MainActor
public final class PluginManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var loadedPlugins: [String: any EchoelmusicPlugin] = [:]
    @Published public private(set) var pluginErrors: [String: String] = [:]
    @Published public var developerModeEnabled: Bool = false

    // MARK: - Shared State

    public let sharedState = SharedPluginState()

    // MARK: - Private Properties

    private var frameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupFrameLoop()
    }

    deinit {
        frameTimer?.invalidate()
    }

    private func setupFrameLoop() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                self?.frameLoop(deltaTime: timer.timeInterval)
            }
        }
    }

    private func frameLoop(deltaTime: TimeInterval) {
        for plugin in loadedPlugins.values {
            plugin.onFrame(deltaTime: deltaTime)
        }
    }

    // MARK: - Plugin Lifecycle

    /// Load a plugin
    public func loadPlugin(_ plugin: any EchoelmusicPlugin) async throws {
        let id = plugin.identifier

        guard loadedPlugins[id] == nil else {
            throw PluginError.alreadyLoaded(id)
        }

        // Create context
        let context = createPluginContext()

        // Validate SDK version
        let requiredVersion = plugin.requiredSDKVersion
        guard isVersionCompatible(requiredVersion) else {
            throw PluginError.incompatibleVersion(required: requiredVersion, current: SDKVersion.current.semver)
        }

        // Load plugin
        do {
            try await plugin.onLoad(context: context)
            loadedPlugins[id] = plugin
            pluginErrors.removeValue(forKey: id)
            log.info("PluginManager: Loaded '\(plugin.name)' (\(id))", category: .plugin)
        } catch {
            pluginErrors[id] = error.localizedDescription
            throw error
        }
    }

    /// Unload a plugin
    public func unloadPlugin(_ identifier: String) async throws {
        guard let plugin = loadedPlugins[identifier] else {
            throw PluginError.notFound(identifier)
        }

        await plugin.onUnload()
        loadedPlugins.removeValue(forKey: identifier)
        log.info("PluginManager: Unloaded '\(plugin.name)' (\(identifier))", category: .plugin)
    }

    /// Reload a plugin
    public func reloadPlugin(_ identifier: String) async throws {
        guard let plugin = loadedPlugins[identifier] else {
            throw PluginError.notFound(identifier)
        }

        try await unloadPlugin(identifier)
        try await loadPlugin(plugin)
    }

    /// Unload all plugins
    public func unloadAllPlugins() async {
        for id in loadedPlugins.keys {
            try? await unloadPlugin(id)
        }
    }

    // MARK: - Plugin Communication

    /// Broadcast bio data to all plugins
    public func broadcastBioData(_ bioData: BioData) {
        for plugin in loadedPlugins.values {
            plugin.onBioDataUpdate(bioData)
        }
    }

    /// Broadcast quantum state to all plugins
    public func broadcastQuantumState(_ state: QuantumPluginState) {
        for plugin in loadedPlugins.values {
            plugin.onQuantumStateChange(state)
        }
    }

    /// Process audio through audio plugins
    public func processAudioChain(buffer: inout [Float], sampleRate: Int, channels: Int) {
        let audioPlugins = loadedPlugins.values.filter { $0.capabilities.contains(.audioEffect) || $0.capabilities.contains(.audioGenerator) }
        for plugin in audioPlugins {
            plugin.processAudio(buffer: &buffer, sampleRate: sampleRate, channels: channels)
        }
    }

    /// Render visuals from visual plugins
    public func renderVisuals(context: RenderContext) -> [VisualOutput] {
        let visualPlugins = loadedPlugins.values.filter { $0.capabilities.contains(.visualization) || $0.capabilities.contains(.shaderEffect) }
        return visualPlugins.compactMap { $0.renderVisual(context: context) }
    }

    /// Send interaction to plugins
    public func handleInteraction(_ interaction: UserInteraction) {
        for plugin in loadedPlugins.values {
            plugin.handleInteraction(interaction)
        }
    }

    // MARK: - Helpers

    private func createPluginContext() -> PluginContext {
        let dataDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plugins")
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plugins")

        return PluginContext(
            sdkVersion: .current,
            hostAppVersion: "2000.0.0",
            platform: detectPlatform(),
            deviceCapabilities: detectCapabilities(),
            dataDirectory: dataDir,
            cacheDirectory: cacheDir,
            sharedState: sharedState
        )
    }

    private func detectPlatform() -> PluginContext.Platform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(visionOS)
        return .visionOS
        #else
        return .macOS
        #endif
    }

    private func detectCapabilities() -> PluginContext.DeviceCapabilities {
        PluginContext.DeviceCapabilities(
            hasGPU: true,
            hasNeuralEngine: true,
            hasBiometrics: true,
            hasHaptics: true,
            hasSpatialAudio: true,
            maxTextureSize: 16384,
            cpuCores: ProcessInfo.processInfo.processorCount,
            memoryMB: Int(ProcessInfo.processInfo.physicalMemory / 1_000_000)
        )
    }

    private func isVersionCompatible(_ required: String) -> Bool {
        // Simple semver comparison
        let current = SDKVersion.current.semver
        return current >= required
    }

    // MARK: - Errors

    public enum PluginError: Error, LocalizedError {
        case alreadyLoaded(String)
        case notFound(String)
        case incompatibleVersion(required: String, current: String)
        case loadFailed(String)
        case invalidCapability(String)

        public var errorDescription: String? {
            switch self {
            case .alreadyLoaded(let id): return "Plugin '\(id)' is already loaded"
            case .notFound(let id): return "Plugin '\(id)' not found"
            case .incompatibleVersion(let req, let cur): return "Incompatible SDK version. Required: \(req), Current: \(cur)"
            case .loadFailed(let reason): return "Failed to load plugin: \(reason)"
            case .invalidCapability(let cap): return "Invalid capability: \(cap)"
            }
        }
    }
}

// MARK: - API Client

/// REST API client for Echoelmusic cloud services
public final class EchoelmusicAPIClient {

    public static let shared = EchoelmusicAPIClient()

    public var baseURL: URL {
        URL(string: "https://api.echoelmusic.com/v2") ?? URL(fileURLWithPath: "/")
    }

    // MARK: - Authentication

    public private(set) var apiKey: String?
    public var authToken: String?

    // MARK: - Endpoints

    public enum Endpoint: String {
        case plugins = "/plugins"
        case presets = "/presets"
        case sessions = "/sessions"
        case users = "/users"
        case analytics = "/analytics"
        case quantum = "/quantum"
        case collaboration = "/collaboration"
    }

    // MARK: - Requests

    public func request<T: Decodable>(_ endpoint: Endpoint, method: String = "GET", body: Encodable? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.rawValue))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public enum APIError: Error, LocalizedError {
        case requestFailed
        case unauthorized
        case notFound
        case serverError

        public var errorDescription: String? {
            switch self {
            case .requestFailed: return "API request failed"
            case .unauthorized: return "Unauthorized access"
            case .notFound: return "Resource not found"
            case .serverError: return "Server error occurred"
            }
        }
    }
}

// MARK: - Developer Console

/// In-app developer console for debugging
@MainActor
public final class DeveloperConsole: ObservableObject {

    public static let shared = DeveloperConsole()

    @Published public var isVisible: Bool = false
    @Published public private(set) var logs: [LogEntry] = []
    @Published public var logLevel: LogLevel = .info

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public var timestamp: Date
        public var level: LogLevel
        public var source: String
        public var message: String
    }

    public enum LogLevel: String, CaseIterable, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            let order: [LogLevel] = [.debug, .info, .warning, .error]
            let lhsIndex = order.firstIndex(of: lhs) ?? 0
            let rhsIndex = order.firstIndex(of: rhs) ?? 0
            return lhsIndex < rhsIndex
        }
    }

    public func logMessage(_ message: String, level: LogLevel = .info, source: String = "App") {
        guard level >= logLevel else { return }

        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            source: source,
            message: message
        )

        logs.append(entry)

        // Keep last 1000 logs
        if logs.count > 1000 {
            logs.removeFirst(logs.count - 1000)
        }

        ProfessionalLogger.shared.info("[\(level.rawValue)] [\(source)] \(message)", category: .plugin)
    }

    public func debug(_ message: String, source: String = "App") {
        logMessage(message, level: .debug, source: source)
    }

    public func info(_ message: String, source: String = "App") {
        logMessage(message, level: .info, source: source)
    }

    public func warning(_ message: String, source: String = "App") {
        logMessage(message, level: .warning, source: source)
    }

    public func error(_ message: String, source: String = "App") {
        logMessage(message, level: .error, source: source)
    }

    public func clear() {
        logs.removeAll()
    }

    public func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        return logs.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.source)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

// MARK: - Performance Monitor

/// Real-time performance monitoring
@MainActor
public final class PerformanceMonitor: ObservableObject {

    public static let shared = PerformanceMonitor()

    @Published public private(set) var fps: Double = 0
    @Published public private(set) var cpuUsage: Double = 0
    @Published public private(set) var memoryUsage: Int64 = 0
    @Published public private(set) var gpuUsage: Double = 0
    @Published public private(set) var audioLatency: TimeInterval = 0
    @Published public private(set) var networkLatency: TimeInterval = 0

    private var frameCount: Int = 0
    private var lastFPSUpdate: Date = Date()
    private var timer: Timer?

    public func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func recordFrame() {
        frameCount += 1
    }

    private func updateMetrics() {
        // Calculate FPS
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        fps = Double(frameCount) / elapsed
        frameCount = 0
        lastFPSUpdate = now

        // Get CPU usage
        cpuUsage = getCPUUsage()

        // Get memory usage
        memoryUsage = getMemoryUsage()

        // Simulate GPU usage
        gpuUsage = Double.random(in: 0.1...0.4)

        // Simulate latencies
        audioLatency = TimeInterval.random(in: 0.005...0.015)
        networkLatency = TimeInterval.random(in: 0.01...0.1)
    }

    private func getCPUUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)

        let total = user + system + idle + nice
        return (user + system) / total
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    public struct Snapshot: Sendable {
        public var timestamp: Date
        public var fps: Double
        public var cpuUsage: Double
        public var memoryUsage: Int64
        public var gpuUsage: Double
        public var audioLatency: TimeInterval
        public var networkLatency: TimeInterval
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            timestamp: Date(),
            fps: fps,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            gpuUsage: gpuUsage,
            audioLatency: audioLatency,
            networkLatency: networkLatency
        )
    }
}

// MARK: - Sample Plugin

/// Sample plugin demonstrating the SDK
public final class SampleVisualizerPlugin: EchoelmusicPlugin {

    public var identifier: String { "com.echoelmusic.sample-visualizer" }
    public var name: String { "Sample Visualizer" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Team" }
    public var pluginDescription: String { "A sample plugin demonstrating the Echoelmusic SDK" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.visualization, .bioProcessing] }

    private var currentCoherence: Float = 0.5
    private var frameTime: TimeInterval = 0

    public init() {}

    public func onLoad(context: PluginContext) async throws {
        await DeveloperConsole.shared.info("Sample Visualizer loaded", source: identifier)
    }

    public func onUnload() async {
        await DeveloperConsole.shared.info("Sample Visualizer unloaded", source: identifier)
    }

    public func onFrame(deltaTime: TimeInterval) {
        frameTime += deltaTime
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        currentCoherence = bioData.coherence
    }

    public func renderVisual(context: RenderContext) -> VisualOutput? {
        // Generate simple visualization based on coherence
        let intensity = currentCoherence
        let pulse = Float(sin(context.totalTime * 2) * 0.5 + 0.5)

        return VisualOutput(
            pixelData: nil,
            textureId: nil,
            shaderUniforms: [
                "coherence": intensity,
                "pulse": pulse,
                "time": Float(context.totalTime)
            ],
            blendMode: .add
        )
    }
}
