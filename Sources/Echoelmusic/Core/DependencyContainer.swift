// DependencyContainer.swift
// Echoelmusic - Dependency Injection Container
// Wise Mode Implementation

import Foundation
import Combine

// MARK: - Dependency Container

/// Centralized dependency injection container for managing service lifecycle
@MainActor
public final class DependencyContainer: ObservableObject {

    // MARK: - Singleton

    public static let shared = DependencyContainer()

    // MARK: - Published State

    @Published public private(set) var isInitialized = false
    @Published public private(set) var initializationError: Error?

    // MARK: - Service Storage

    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Register a singleton service instance
    public func register<T>(_ service: T) {
        let key = String(describing: T.self)
        services[key] = service
        Logger.debug("Registered singleton: \(key)", category: .system)
    }

    /// Register a factory for lazy instantiation
    public func registerFactory<T>(_ factory: @escaping () -> T) {
        let key = String(describing: T.self)
        factories[key] = factory
        Logger.debug("Registered factory: \(key)", category: .system)
    }

    /// Register a service with a protocol type
    public func register<T, P>(_ service: T, as protocolType: P.Type) {
        let key = String(describing: P.self)
        services[key] = service
        Logger.debug("Registered \(T.self) as \(key)", category: .system)
    }

    // MARK: - Resolution

    /// Resolve a registered service
    public func resolve<T>() -> T? {
        let key = String(describing: T.self)

        // Check for existing singleton
        if let service = services[key] as? T {
            return service
        }

        // Check for factory
        if let factory = factories[key] {
            let service = factory() as? T
            if let service = service {
                services[key] = service // Cache the instance
                Logger.debug("Created instance from factory: \(key)", category: .system)
            }
            return service
        }

        Logger.warning("Service not found: \(key)", category: .system)
        return nil
    }

    /// Resolve with a default value
    public func resolve<T>(default defaultValue: @autoclosure () -> T) -> T {
        resolve() ?? defaultValue()
    }

    /// Resolve or throw
    public func resolveOrThrow<T>() throws -> T {
        guard let service: T = resolve() else {
            throw AppError.resourceNotFound(name: String(describing: T.self), type: "Service")
        }
        return service
    }

    // MARK: - Lifecycle

    /// Initialize all registered services
    public func initialize() async {
        Logger.info("Initializing dependency container...", category: .system)

        do {
            // Register core services
            await registerCoreServices()

            isInitialized = true
            Logger.info("Dependency container initialized successfully", category: .system)
        } catch {
            initializationError = error
            Logger.error("Dependency container initialization failed", category: .system, error: error)
        }
    }

    /// Reset container (for testing)
    public func reset() {
        services.removeAll()
        factories.removeAll()
        isInitialized = false
        initializationError = nil
        Logger.info("Dependency container reset", category: .system)
    }

    // MARK: - Core Services Registration

    private func registerCoreServices() async {
        // Register protocols with concrete implementations
        // These will be lazily instantiated when first resolved

        registerFactory {
            AudioEngineService()
        }

        registerFactory {
            MIDIService()
        }

        registerFactory {
            SpatialAudioService()
        }

        registerFactory {
            VisualizationService()
        }

        registerFactory {
            BiofeedbackService()
        }

        registerFactory {
            RecordingService()
        }

        registerFactory {
            LEDControlService()
        }

        // Register EventBus singleton
        register(EventBus.shared)

        Logger.info("Core services registered", category: .system)
    }
}

// MARK: - Service Protocols

/// Protocol for audio engine operations
public protocol AudioEngineProtocol {
    var isRunning: Bool { get }
    func start() async throws
    func stop()
    func setVolume(_ volume: Float)
}

/// Protocol for MIDI operations
public protocol MIDIServiceProtocol {
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect()
    func sendNote(note: UInt8, velocity: UInt8, channel: UInt8)
}

/// Protocol for spatial audio operations
public protocol SpatialAudioProtocol {
    var currentMode: SpatialMode { get }
    func setMode(_ mode: SpatialMode)
    func updateListenerPosition(_ position: SIMD3<Float>)
}

/// Protocol for visualization operations
public protocol VisualizationProtocol {
    var currentMode: VisualizationModeType { get }
    func setMode(_ mode: VisualizationModeType)
    func update(audioData: [Float])
}

/// Protocol for biofeedback operations
public protocol BiofeedbackProtocol {
    var isMonitoring: Bool { get }
    func startMonitoring() async throws
    func stopMonitoring()
    var heartRate: Double { get }
    var hrv: Double { get }
    var coherence: Double { get }
}

/// Protocol for recording operations
public protocol RecordingProtocol {
    var isRecording: Bool { get }
    func startRecording() throws
    func stopRecording() -> URL?
    func pauseRecording()
    func resumeRecording()
}

/// Protocol for LED control operations
public protocol LEDControlProtocol {
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect()
    func setColor(r: UInt8, g: UInt8, b: UInt8)
    func setPattern(_ pattern: LEDPattern)
}

// MARK: - Supporting Types

public enum SpatialMode: String, CaseIterable {
    case stereo = "Stereo"
    case surround3D = "3D"
    case orbital4D = "4D Orbital"
    case afa = "AFA"
    case binaural = "Binaural"
    case ambisonics = "Ambisonics"
}

public enum VisualizationModeType: String, CaseIterable {
    case cymatics = "Cymatics"
    case mandala = "Mandala"
    case waveform = "Waveform"
    case spectral = "Spectral"
    case particles = "Particles"
}

public enum LEDPattern: String, CaseIterable {
    case solid = "Solid"
    case pulse = "Pulse"
    case rainbow = "Rainbow"
    case chase = "Chase"
    case breathe = "Breathe"
    case reactive = "Reactive"
    case spectrum = "Spectrum"
}

// MARK: - Placeholder Service Implementations

/// Placeholder audio engine service
public final class AudioEngineService: AudioEngineProtocol {
    public private(set) var isRunning = false

    public func start() async throws {
        isRunning = true
        Logger.info("Audio engine started", category: .audio)
    }

    public func stop() {
        isRunning = false
        Logger.info("Audio engine stopped", category: .audio)
    }

    public func setVolume(_ volume: Float) {
        let validated = InputValidator.validateAudioLevel(volume)
        Logger.debug("Volume set to \(validated)", category: .audio)
    }
}

/// Placeholder MIDI service
public final class MIDIService: MIDIServiceProtocol {
    public private(set) var isConnected = false

    public func connect() async throws {
        isConnected = true
        Logger.info("MIDI connected", category: .midi)
    }

    public func disconnect() {
        isConnected = false
        Logger.info("MIDI disconnected", category: .midi)
    }

    public func sendNote(note: UInt8, velocity: UInt8, channel: UInt8) {
        let validNote = InputValidator.validateMIDINote(note)
        let validVelocity = InputValidator.validateMIDIVelocity(velocity)
        let validChannel = InputValidator.validateMIDIChannel(channel)
        Logger.debug("MIDI Note: \(validNote) vel:\(validVelocity) ch:\(validChannel)", category: .midi)
    }
}

/// Placeholder spatial audio service
public final class SpatialAudioService: SpatialAudioProtocol {
    public private(set) var currentMode: SpatialMode = .stereo

    public func setMode(_ mode: SpatialMode) {
        currentMode = mode
        Logger.info("Spatial mode: \(mode.rawValue)", category: .spatial)
    }

    public func updateListenerPosition(_ position: SIMD3<Float>) {
        let validated = InputValidator.validatePosition(position)
        Logger.debug("Listener position: \(validated)", category: .spatial)
    }
}

/// Placeholder visualization service
public final class VisualizationService: VisualizationProtocol {
    public private(set) var currentMode: VisualizationModeType = .cymatics

    public func setMode(_ mode: VisualizationModeType) {
        currentMode = mode
        Logger.info("Visualization mode: \(mode.rawValue)", category: .visual)
    }

    public func update(audioData: [Float]) {
        // Process audio data for visualization
    }
}

/// Placeholder biofeedback service
public final class BiofeedbackService: BiofeedbackProtocol {
    public private(set) var isMonitoring = false
    public private(set) var heartRate: Double = 0
    public private(set) var hrv: Double = 0
    public private(set) var coherence: Double = 0

    public func startMonitoring() async throws {
        isMonitoring = true
        Logger.info("Biofeedback monitoring started", category: .biofeedback)
    }

    public func stopMonitoring() {
        isMonitoring = false
        Logger.info("Biofeedback monitoring stopped", category: .biofeedback)
    }
}

/// Placeholder recording service
public final class RecordingService: RecordingProtocol {
    public private(set) var isRecording = false

    public func startRecording() throws {
        isRecording = true
        Logger.info("Recording started", category: .recording)
    }

    public func stopRecording() -> URL? {
        isRecording = false
        Logger.info("Recording stopped", category: .recording)
        return nil
    }

    public func pauseRecording() {
        Logger.info("Recording paused", category: .recording)
    }

    public func resumeRecording() {
        Logger.info("Recording resumed", category: .recording)
    }
}

/// Placeholder LED control service
public final class LEDControlService: LEDControlProtocol {
    public private(set) var isConnected = false

    public func connect() async throws {
        isConnected = true
        Logger.info("LED controller connected", category: .led)
    }

    public func disconnect() {
        isConnected = false
        Logger.info("LED controller disconnected", category: .led)
    }

    public func setColor(r: UInt8, g: UInt8, b: UInt8) {
        Logger.debug("LED color: R\(r) G\(g) B\(b)", category: .led)
    }

    public func setPattern(_ pattern: LEDPattern) {
        Logger.info("LED pattern: \(pattern.rawValue)", category: .led)
    }
}

// MARK: - Property Wrapper for Injection

/// Property wrapper for dependency injection
@propertyWrapper
public struct Injected<T> {
    private var service: T?

    public var wrappedValue: T {
        mutating get {
            if service == nil {
                service = DependencyContainer.shared.resolve()
            }
            guard let service = service else {
                fatalError("Service \(T.self) not registered in DependencyContainer")
            }
            return service
        }
    }

    public init() {}
}
