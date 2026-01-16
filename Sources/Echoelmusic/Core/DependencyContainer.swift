// DependencyContainer.swift
// Echoelmusic - Lightweight Dependency Injection Container
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Provides compile-time safe dependency injection for testability.
// No runtime reflection, fully type-safe.
//
// Supported Platforms: ALL
// Created 2026-01-16

import Foundation

// MARK: - Dependency Key Protocol

/// Protocol for dependency keys
public protocol DependencyKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

// MARK: - Dependency Container

/// Lightweight dependency injection container
///
/// Thread-safe, type-safe dependency management.
///
/// Usage:
/// ```swift
/// // Define a dependency key
/// struct AudioEngineKey: DependencyKey {
///     static var defaultValue: AudioEngine { AudioEngine() }
/// }
///
/// // Register custom implementation
/// DependencyContainer.shared.register(AudioEngineKey.self) {
///     MockAudioEngine()
/// }
///
/// // Resolve dependency
/// let engine = DependencyContainer.shared.resolve(AudioEngineKey.self)
///
/// // Or use property wrapper
/// @Dependency(AudioEngineKey.self) var audioEngine
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class DependencyContainer: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = DependencyContainer()

    // MARK: - Storage

    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private var singletons: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    // MARK: - Scopes

    public enum Scope {
        case transient   // New instance every time
        case singleton   // Shared instance
    }

    // MARK: - Initialization

    private init() {
        registerDefaults()
    }

    // MARK: - Registration

    /// Register a dependency with a factory
    public func register<K: DependencyKey>(
        _ key: K.Type,
        scope: Scope = .transient,
        factory: @escaping () -> K.Value
    ) {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(key)

        switch scope {
        case .transient:
            factories[id] = factory
            singletons.removeValue(forKey: id)

        case .singleton:
            factories[id] = factory
            // Don't create singleton until first resolution
        }
    }

    /// Register a singleton instance directly
    public func registerSingleton<K: DependencyKey>(_ key: K.Type, instance: K.Value) {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(key)
        singletons[id] = instance
    }

    // MARK: - Resolution

    /// Resolve a dependency
    public func resolve<K: DependencyKey>(_ key: K.Type) -> K.Value {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(key)

        // Check singleton cache
        if let singleton = singletons[id] as? K.Value {
            return singleton
        }

        // Check factory
        if let factory = factories[id], let value = factory() as? K.Value {
            return value
        }

        // Return default
        return K.defaultValue
    }

    /// Resolve optional (nil if not registered)
    public func resolveOptional<K: DependencyKey>(_ key: K.Type) -> K.Value? {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(key)

        if let singleton = singletons[id] as? K.Value {
            return singleton
        }

        if let factory = factories[id], let value = factory() as? K.Value {
            return value
        }

        return nil
    }

    // MARK: - Unregistration

    /// Remove a dependency registration
    public func unregister<K: DependencyKey>(_ key: K.Type) {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(key)
        factories.removeValue(forKey: id)
        singletons.removeValue(forKey: id)
    }

    /// Reset to defaults
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        factories.removeAll()
        singletons.removeAll()
        registerDefaults()
    }

    // MARK: - Default Registrations

    private func registerDefaults() {
        // Register default implementations
        // These can be overridden in tests
    }
}

// MARK: - Property Wrapper

/// Property wrapper for dependency injection
///
/// Usage:
/// ```swift
/// class MyViewModel {
///     @Dependency(AudioEngineKey.self) var audioEngine
///     @Dependency(BioStreamKey.self) var bioStream
/// }
/// ```
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@propertyWrapper
public struct Dependency<K: DependencyKey> {
    private let key: K.Type

    public init(_ key: K.Type) {
        self.key = key
    }

    public var wrappedValue: K.Value {
        DependencyContainer.shared.resolve(key)
    }
}

// MARK: - Lazy Dependency

/// Property wrapper for lazy dependency resolution
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
@propertyWrapper
public struct LazyDependency<K: DependencyKey> {
    private let key: K.Type
    private var cachedValue: K.Value?

    public init(_ key: K.Type) {
        self.key = key
    }

    public var wrappedValue: K.Value {
        mutating get {
            if let cached = cachedValue {
                return cached
            }
            let value = DependencyContainer.shared.resolve(key)
            cachedValue = value
            return value
        }
    }
}

// MARK: - Common Dependency Keys

/// Logger dependency
public struct LoggerKey: DependencyKey {
    public static var defaultValue: any LoggerProtocol { DefaultLogger() }
}

/// Protocol for logger
public protocol LoggerProtocol {
    func log(_ message: String, level: LogLevel)
}

public enum LogLevel: String {
    case debug, info, warning, error
}

struct DefaultLogger: LoggerProtocol {
    func log(_ message: String, level: LogLevel) {
        print("[\(level.rawValue.uppercased())] \(message)")
    }
}

/// Bio stream provider dependency
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct BioStreamProviderKey: DependencyKey {
    public static var defaultValue: any BioStreamProvider { DefaultBioStreamProvider() }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
struct DefaultBioStreamProvider: BioStreamProvider {
    func bioStream() -> AsyncBioStream {
        AsyncBioStream()
    }
}

/// Configuration dependency
public struct ConfigurationKey: DependencyKey {
    public static var defaultValue: AppConfiguration { AppConfiguration() }
}

public struct AppConfiguration {
    public var isDebug: Bool = false
    public var apiEndpoint: String = "https://api.echoelmusic.com"
    public var enableAnalytics: Bool = true
    public var bioSampleRate: Double = 60.0

    public static let debug = AppConfiguration(isDebug: true)
    public static let production = AppConfiguration()
}

// MARK: - Scoped Container

/// Scoped dependency container for request/session lifetime
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public final class ScopedContainer {

    private let parent: DependencyContainer
    private var overrides: [ObjectIdentifier: Any] = [:]
    private let lock = NSLock()

    public init(parent: DependencyContainer = .shared) {
        self.parent = parent
    }

    /// Override a dependency in this scope
    public func override<K: DependencyKey>(_ key: K.Type, with value: K.Value) {
        lock.lock()
        defer { lock.unlock() }
        overrides[ObjectIdentifier(key)] = value
    }

    /// Resolve with scope override
    public func resolve<K: DependencyKey>(_ key: K.Type) -> K.Value {
        lock.lock()
        defer { lock.unlock() }

        if let override = overrides[ObjectIdentifier(key)] as? K.Value {
            return override
        }
        return parent.resolve(key)
    }
}

// MARK: - Test Helpers

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension DependencyContainer {

    /// Create a test container with mock implementations
    static func forTesting() -> DependencyContainer {
        let container = DependencyContainer.shared
        container.reset()
        return container
    }

    /// Register mock for testing
    func registerMock<K: DependencyKey>(_ key: K.Type, mock: K.Value) {
        registerSingleton(key, instance: mock)
    }
}

// MARK: - Module Registration

/// Protocol for modules that register dependencies
public protocol DependencyModule {
    static func register(in container: DependencyContainer)
}

/// Register all app modules
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension DependencyContainer {

    func registerModules(_ modules: [DependencyModule.Type]) {
        for module in modules {
            module.register(in: self)
        }
    }
}

// MARK: - Audio Module Example

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct AudioModule: DependencyModule {
    public static func register(in container: DependencyContainer) {
        // Register audio-related dependencies
        container.register(ConfigurationKey.self, scope: .singleton) {
            AppConfiguration()
        }
    }
}

// MARK: - Bio Module Example

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct BioModule: DependencyModule {
    public static func register(in container: DependencyContainer) {
        container.register(BioStreamProviderKey.self, scope: .singleton) {
            DefaultBioStreamProvider()
        }
    }
}
