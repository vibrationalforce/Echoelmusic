// ServiceContainer.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Lightweight dependency injection container for service resolution
// Enables testability by allowing mock injection
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

// MARK: - Service Protocols

/// Protocol for analytics service injection
public protocol AnalyticsServiceProtocol: AnyObject {
    func track(event: String, properties: [String: Any])
    func identify(userId: String)
}

/// Protocol for logging service injection
public protocol LoggingServiceProtocol: AnyObject {
    func log(_ level: LogLevel, category: LogCategory, _ message: String)
}

/// Protocol for network service injection
public protocol NetworkServiceProtocol: AnyObject {
    func request(endpoint: String, method: String, body: Data?) async throws -> Data
}

/// Protocol for storage service injection
public protocol StorageServiceProtocol: AnyObject {
    func save(key: String, data: Data) throws
    func load(key: String) throws -> Data?
    func delete(key: String) throws
}

/// Protocol for audio engine injection
public protocol AudioEngineProtocol: AnyObject {
    func start() async throws
    func stop() async
    var isRunning: Bool { get }
}

/// Protocol for bio-reactive engine injection
public protocol BioReactiveEngineProtocol: AnyObject {
    var currentCoherence: Float { get }
    var currentHeartRate: Float? { get }
    func startStreaming() async throws
    func stopStreaming() async
}

/// Protocol for spatial audio engine injection
public protocol SpatialAudioProviderProtocol: AnyObject {
    func setMode(_ mode: SpatialAudioEngine.SpatialMode)
    func setPan(_ pan: Float)
    func setReverbBlend(_ blend: Float)
    var currentMode: SpatialAudioEngine.SpatialMode { get }
}

/// Protocol for video engine injection
public protocol VideoEngineProtocol: AnyObject {
    func start() async throws
    func stop() async
    var isProcessing: Bool { get }
}

/// Protocol for lighting/DMX output injection
public protocol LightingProviderProtocol: AnyObject {
    func setScene(_ scene: Int)
    func blackout()
    var isActive: Bool { get }
}

// MARK: - Service Container

/// Lightweight service container for dependency injection
/// Thread-safe, supports lazy initialization and mock injection for testing
@MainActor
public final class ServiceContainer {

    /// Shared production container - use for app-level resolution
    public static let shared = ServiceContainer()

    /// Service registration storage
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private var singletons: [ObjectIdentifier: Any] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a factory that creates a new instance each time
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        factories[ObjectIdentifier(type)] = factory
    }

    /// Register a pre-existing singleton instance
    public func registerSingleton<T>(_ type: T.Type, instance: T) {
        singletons[ObjectIdentifier(type)] = instance
    }

    // MARK: - Resolution

    /// Resolve a registered service. Returns nil if not registered.
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)

        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }

        // Check factories
        if let factory = factories[key], let instance = factory() as? T {
            return instance
        }

        return nil
    }

    /// Resolve a registered service or fall back to the provided default
    public func resolve<T>(_ type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
        return resolve(type) ?? defaultValue()
    }

    // MARK: - Testing Support

    /// Reset all registrations (for testing)
    public func reset() {
        factories.removeAll()
        singletons.removeAll()
    }

    /// Create an isolated container for testing with mock services
    public static func testing() -> ServiceContainer {
        return ServiceContainer()
    }
}

// MARK: - Property Wrapper for Injection

/// Property wrapper for automatic service resolution
/// Returns nil instead of crashing when a service is not registered.
/// Usage: `@Injected var analytics: AnalyticsServiceProtocol?`
@propertyWrapper
public struct Injected<T> {
    private let container: ServiceContainer

    public var wrappedValue: T? {
        nonisolated(unsafe) let c = container
        return c.resolve(T.self)
    }

    @MainActor
    public init(container: ServiceContainer = .shared) {
        self.container = container
    }
}
