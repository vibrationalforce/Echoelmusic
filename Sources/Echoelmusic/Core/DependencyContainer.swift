//
//  DependencyContainer.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Dependency Injection Container
//
//  Features:
//  - Type-safe dependency registration & resolution
//  - Singleton, transient, and scoped lifetimes
//  - Lazy initialization
//  - Thread-safe access
//  - Mock injection for testing
//  - Circular dependency detection
//

import Foundation
import Combine

// MARK: - Dependency Lifetime

/// Defines how long a dependency lives
public enum DependencyLifetime {
    /// Single instance shared across the app
    case singleton
    /// New instance created each time
    case transient
    /// Single instance within a scope (e.g., per-view)
    case scoped(String)
}

// MARK: - Dependency Registration

/// Describes how to create a dependency
public struct DependencyRegistration<T> {
    let factory: (DependencyContainer) -> T
    let lifetime: DependencyLifetime
}

// MARK: - Dependency Container

/// Thread-safe dependency injection container
@MainActor
public final class DependencyContainer: ObservableObject {
    // MARK: - Shared Instance

    public static let shared = DependencyContainer()

    // MARK: - Storage

    private var registrations: [String: Any] = [:]
    private var singletons: [String: Any] = [:]
    private var scopedInstances: [String: [String: Any]] = [:]
    private var resolutionStack: Set<String> = []

    // MARK: - Initialization

    private init() {
        registerDefaults()
    }

    // MARK: - Registration

    /// Register a dependency with factory
    public func register<T>(_ type: T.Type, lifetime: DependencyLifetime = .singleton, factory: @escaping (DependencyContainer) -> T) {
        let key = String(describing: type)
        registrations[key] = DependencyRegistration(factory: factory, lifetime: lifetime)
    }

    /// Register a singleton instance directly
    public func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }

    /// Register with protocol type
    public func register<Protocol, Implementation>(_ protocolType: Protocol.Type, implementation: Implementation.Type, lifetime: DependencyLifetime = .singleton, factory: @escaping (DependencyContainer) -> Implementation) where Implementation: Protocol {
        let key = String(describing: protocolType)
        registrations[key] = DependencyRegistration<Protocol>(factory: { container in
            factory(container) as Protocol
        }, lifetime: lifetime)
    }

    // MARK: - Resolution

    /// Resolve a dependency
    public func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        // Check for circular dependency
        guard !resolutionStack.contains(key) else {
            fatalError("Circular dependency detected for \(key). Resolution stack: \(resolutionStack)")
        }

        // Check singleton cache first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Get registration
        guard let registration = registrations[key] as? DependencyRegistration<T> else {
            fatalError("No registration found for \(key). Did you forget to register it?")
        }

        // Track resolution to detect circular dependencies
        resolutionStack.insert(key)
        defer { resolutionStack.remove(key) }

        // Create instance based on lifetime
        switch registration.lifetime {
        case .singleton:
            let instance = registration.factory(self)
            singletons[key] = instance
            return instance

        case .transient:
            return registration.factory(self)

        case .scoped(let scope):
            if let scopedInstance = scopedInstances[scope]?[key] as? T {
                return scopedInstance
            }
            let instance = registration.factory(self)
            if scopedInstances[scope] == nil {
                scopedInstances[scope] = [:]
            }
            scopedInstances[scope]?[key] = instance
            return instance
        }
    }

    /// Resolve optional (returns nil if not registered)
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        if let singleton = singletons[key] as? T {
            return singleton
        }

        guard let registration = registrations[key] as? DependencyRegistration<T> else {
            return nil
        }

        resolutionStack.insert(key)
        defer { resolutionStack.remove(key) }

        switch registration.lifetime {
        case .singleton:
            let instance = registration.factory(self)
            singletons[key] = instance
            return instance

        case .transient:
            return registration.factory(self)

        case .scoped(let scope):
            if let scopedInstance = scopedInstances[scope]?[key] as? T {
                return scopedInstance
            }
            let instance = registration.factory(self)
            if scopedInstances[scope] == nil {
                scopedInstances[scope] = [:]
            }
            scopedInstances[scope]?[key] = instance
            return instance
        }
    }

    // MARK: - Scope Management

    /// Create a new scope
    public func createScope(_ name: String) {
        scopedInstances[name] = [:]
    }

    /// Dispose a scope and its instances
    public func disposeScope(_ name: String) {
        scopedInstances.removeValue(forKey: name)
    }

    // MARK: - Testing Support

    /// Replace a registration for testing
    public func override<T>(_ type: T.Type, with instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
    }

    /// Reset all overrides (for testing cleanup)
    public func resetOverrides() {
        singletons.removeAll()
    }

    /// Reset entire container
    public func reset() {
        registrations.removeAll()
        singletons.removeAll()
        scopedInstances.removeAll()
        registerDefaults()
    }

    // MARK: - Default Registrations

    private func registerDefaults() {
        // Audio Services
        register(AudioEngineProtocol.self, implementation: AudioEngineImpl.self) { _ in
            AudioEngineImpl()
        }

        register(MicrophoneManagerProtocol.self, implementation: MicrophoneManagerImpl.self) { _ in
            MicrophoneManagerImpl()
        }

        // Health & Biofeedback
        register(HealthKitManagerProtocol.self, implementation: HealthKitManagerImpl.self) { _ in
            HealthKitManagerImpl()
        }

        register(BinauralBeatGeneratorProtocol.self, implementation: BinauralBeatGeneratorImpl.self) { _ in
            BinauralBeatGeneratorImpl()
        }

        // Video
        register(VideoEditingEngineProtocol.self, implementation: VideoEditingEngineImpl.self) { container in
            VideoEditingEngineImpl(editHistory: container.resolve(EditHistory.self))
        }

        // Core Services
        register(EditHistory.self) { _ in
            EditHistory()
        }

        register(EffectPresetManager.self) { _ in
            EffectPresetManager.shared
        }

        // Lighting
        register(LightingManagerProtocol.self, implementation: UnifiedLightingManagerImpl.self) { _ in
            UnifiedLightingManagerImpl()
        }

        // Platform
        register(AudioDriverProtocol.self) { _ in
            DriverFactory.shared.createAudioDriver()
        }

        register(MIDIDriverProtocol.self) { _ in
            DriverFactory.shared.createMIDIDriver()
        }
    }
}

// MARK: - Protocol Definitions

/// Protocol for AudioEngine
public protocol AudioEngineProtocol: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
    func connectHealthKit(_ manager: HealthKitManagerProtocol)
}

/// Protocol for MicrophoneManager
public protocol MicrophoneManagerProtocol: AnyObject {
    var isRecording: Bool { get }
    var audioLevel: Float { get }
    func startRecording() throws
    func stopRecording()
}

/// Protocol for HealthKitManager
public protocol HealthKitManagerProtocol: AnyObject {
    var hrvCoherence: Double { get }
    var heartRate: Double { get }
    var isMonitoring: Bool { get }
    func requestAuthorization() async throws
    func startMonitoring() async throws
    func stopMonitoring()
}

/// Protocol for BinauralBeatGenerator
public protocol BinauralBeatGeneratorProtocol: AnyObject {
    var isPlaying: Bool { get }
    var effectiveBeatFrequency: Float { get }
    func configure(carrier: Float, beat: Float, amplitude: Float)
    func start()
    func stop()
}

/// Protocol for VideoEditingEngine
public protocol VideoEditingEngineProtocol: AnyObject {
    var timeline: VideoTimeline { get }
    func addClip(_ clip: VideoClip, toTrack: Int)
    func removeClip(_ clipId: UUID)
    func moveClip(_ clipId: UUID, toTrack: Int, atTime: Double)
}

/// Protocol for LightingManager
public protocol LightingManagerProtocol: AnyObject {
    func connectArtNet() async throws
    func connectSACN() async throws
    func sendDMX(universe: Int, channels: [UInt8]) async throws
    func disconnect()
}

// MARK: - Placeholder Implementations (Real implementations in respective files)

class AudioEngineImpl: AudioEngineProtocol {
    var isRunning: Bool = false
    func start() throws { isRunning = true }
    func stop() { isRunning = false }
    func connectHealthKit(_ manager: HealthKitManagerProtocol) {}
}

class MicrophoneManagerImpl: MicrophoneManagerProtocol {
    var isRecording: Bool = false
    var audioLevel: Float = 0
    func startRecording() throws { isRecording = true }
    func stopRecording() { isRecording = false }
}

class HealthKitManagerImpl: HealthKitManagerProtocol {
    var hrvCoherence: Double = 0
    var heartRate: Double = 0
    var isMonitoring: Bool = false
    func requestAuthorization() async throws {}
    func startMonitoring() async throws { isMonitoring = true }
    func stopMonitoring() { isMonitoring = false }
}

class BinauralBeatGeneratorImpl: BinauralBeatGeneratorProtocol {
    var isPlaying: Bool = false
    var effectiveBeatFrequency: Float = 10.0
    func configure(carrier: Float, beat: Float, amplitude: Float) {}
    func start() { isPlaying = true }
    func stop() { isPlaying = false }
}

class VideoEditingEngineImpl: VideoEditingEngineProtocol {
    var timeline = VideoTimeline()
    private let editHistory: EditHistory

    init(editHistory: EditHistory) {
        self.editHistory = editHistory
    }

    func addClip(_ clip: VideoClip, toTrack: Int) {}
    func removeClip(_ clipId: UUID) {}
    func moveClip(_ clipId: UUID, toTrack: Int, atTime: Double) {}
}

class UnifiedLightingManagerImpl: LightingManagerProtocol {
    func connectArtNet() async throws {}
    func connectSACN() async throws {}
    func sendDMX(universe: Int, channels: [UInt8]) async throws {}
    func disconnect() {}
}

// MARK: - Video Timeline Types

public struct VideoTimeline {
    public var tracks: [VideoTrack] = []
    public var duration: Double = 0
}

public struct VideoTrack {
    public let id: UUID
    public var clips: [VideoClip] = []
}

public struct VideoClip: Identifiable {
    public let id: UUID
    public var startTime: Double
    public var duration: Double
    public var sourceURL: URL?
}

// MARK: - Property Wrapper for Injection

/// Property wrapper for easy dependency injection
@propertyWrapper
public struct Injected<T> {
    private var service: T?

    public init() {}

    @MainActor
    public var wrappedValue: T {
        mutating get {
            if service == nil {
                service = DependencyContainer.shared.resolve(T.self)
            }
            return service!
        }
    }
}

/// Property wrapper for optional injection
@propertyWrapper
public struct InjectedOptional<T> {
    private var service: T?
    private var resolved = false

    public init() {}

    @MainActor
    public var wrappedValue: T? {
        mutating get {
            if !resolved {
                service = DependencyContainer.shared.resolveOptional(T.self)
                resolved = true
            }
            return service
        }
    }
}

// MARK: - SwiftUI Environment Integration

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    public var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    public func withDependencyContainer(_ container: DependencyContainer) -> some View {
        environment(\.dependencyContainer, container)
    }
}
