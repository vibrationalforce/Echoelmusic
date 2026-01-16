// BioReactiveConfigurable.swift
// Echoelmusic - Unified Bio-Reactive Configuration Protocol
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Provides a unified interface for all bio-reactive components.
// Ensures consistent parameter handling across the entire system.
//
// Supported Platforms: ALL (Swift 5.9+)
// Created 2026-01-16

import Foundation
import Combine

// MARK: - Bio-Reactive Configurable Protocol

/// Protocol for components that respond to biometric data
///
/// Implement this protocol to make your component bio-reactive:
/// - Receive bio data updates at 60Hz
/// - Expose configurable parameters
/// - Support preset loading/saving
///
/// Example:
/// ```swift
/// class MyVisualEffect: BioReactiveConfigurable {
///     var bioReactiveEnabled = true
///     var coherenceMapping = CoherenceMapping.standard
///
///     func updateWithBioData(_ data: TypeSafeBioData) {
///         let intensity = data.normalizedCoherence.floatValue
///         // Apply to visual...
///     }
/// }
/// ```
public protocol BioReactiveConfigurable: AnyObject {

    // MARK: - Required

    /// Whether bio-reactive modulation is enabled
    var bioReactiveEnabled: Bool { get set }

    /// Update with current bio data (called at 60Hz)
    func updateWithBioData(_ data: TypeSafeBioData)

    // MARK: - Optional (with defaults)

    /// Coherence mapping configuration
    var coherenceMapping: CoherenceMapping { get set }

    /// Smoothing factor for bio data (0 = instant, 1 = very slow)
    var bioSmoothingFactor: Float { get set }

    /// Minimum coherence threshold to activate effect
    var coherenceThreshold: NormalizedCoherence { get set }

    /// Current coherence value (smoothed)
    var currentCoherence: NormalizedCoherence { get }

    /// Reset to default state
    func resetBioState()

    /// Get configuration as dictionary
    func getBioConfiguration() -> BioConfiguration

    /// Apply configuration from dictionary
    func applyBioConfiguration(_ config: BioConfiguration)
}

// MARK: - Default Implementations

public extension BioReactiveConfigurable {

    var bioSmoothingFactor: Float {
        get { 0.3 }
        set { /* Override in conforming types */ }
    }

    var coherenceThreshold: NormalizedCoherence {
        get { .zero }
        set { /* Override in conforming types */ }
    }

    var coherenceMapping: CoherenceMapping {
        get { .standard }
        set { /* Override in conforming types */ }
    }

    var currentCoherence: NormalizedCoherence {
        .medium
    }

    func resetBioState() {
        // Default: no-op
    }

    func getBioConfiguration() -> BioConfiguration {
        BioConfiguration(
            enabled: bioReactiveEnabled,
            mapping: coherenceMapping,
            smoothingFactor: bioSmoothingFactor,
            threshold: coherenceThreshold
        )
    }

    func applyBioConfiguration(_ config: BioConfiguration) {
        bioReactiveEnabled = config.enabled
        coherenceMapping = config.mapping
        bioSmoothingFactor = config.smoothingFactor
        coherenceThreshold = config.threshold
    }
}

// MARK: - Coherence Mapping

/// How coherence affects a parameter
public struct CoherenceMapping: Sendable, Codable, Hashable {

    /// Mapping curve type
    public let curve: MappingCurve

    /// Input range (coherence)
    public let inputMin: NormalizedCoherence
    public let inputMax: NormalizedCoherence

    /// Output range (parameter)
    public let outputMin: Float
    public let outputMax: Float

    /// Whether mapping is inverted (high coherence = low output)
    public let inverted: Bool

    /// Dead zone around center
    public let deadZone: Float

    /// Initialize with custom values
    public init(
        curve: MappingCurve = .linear,
        inputMin: NormalizedCoherence = .zero,
        inputMax: NormalizedCoherence = .max,
        outputMin: Float = 0,
        outputMax: Float = 1,
        inverted: Bool = false,
        deadZone: Float = 0
    ) {
        self.curve = curve
        self.inputMin = inputMin
        self.inputMax = inputMax
        self.outputMin = outputMin
        self.outputMax = outputMax
        self.inverted = inverted
        self.deadZone = deadZone
    }

    /// Map coherence to output value
    @inline(__always)
    public func map(_ coherence: NormalizedCoherence) -> Float {
        // Normalize input to 0-1
        let inputRange = inputMax.value - inputMin.value
        guard inputRange > 0 else { return outputMin }

        var normalized = (coherence.value - inputMin.value) / inputRange
        normalized = max(0, min(1, normalized))

        // Apply dead zone
        if deadZone > 0 {
            let center = 0.5
            let distance = abs(normalized - center)
            if distance < Double(deadZone / 2) {
                normalized = center
            }
        }

        // Apply curve
        let curved = curve.apply(Float(normalized))

        // Invert if needed
        let final = inverted ? 1 - curved : curved

        // Map to output range
        return outputMin + final * (outputMax - outputMin)
    }

    // MARK: - Presets

    /// Standard linear mapping (0-1 → 0-1)
    public static let standard = CoherenceMapping()

    /// Inverted mapping (high coherence = low output)
    public static let inverted = CoherenceMapping(inverted: true)

    /// Exponential mapping (more responsive at high coherence)
    public static let exponential = CoherenceMapping(curve: .exponential)

    /// Logarithmic mapping (more responsive at low coherence)
    public static let logarithmic = CoherenceMapping(curve: .logarithmic)

    /// S-curve mapping (smooth transition)
    public static let sCurve = CoherenceMapping(curve: .sCurve)

    /// Threshold mapping (binary on/off at 60%)
    public static let threshold = CoherenceMapping(
        curve: .stepped(steps: 2),
        inputMin: NormalizedCoherence(0.6),
        inputMax: NormalizedCoherence(0.6)
    )

    /// Filter cutoff mapping (Hz range)
    public static let filterCutoff = CoherenceMapping(
        curve: .exponential,
        outputMin: 200,
        outputMax: 8000
    )

    /// Reverb amount mapping
    public static let reverbAmount = CoherenceMapping(
        curve: .sCurve,
        outputMin: 0.1,
        outputMax: 0.8
    )

    /// Visual intensity mapping
    public static let visualIntensity = CoherenceMapping(
        curve: .exponential,
        outputMin: 0.2,
        outputMax: 1.0
    )

    /// Light brightness mapping
    public static let lightBrightness = CoherenceMapping(
        curve: .linear,
        outputMin: 0.1,
        outputMax: 1.0
    )
}

// MARK: - Mapping Curve

/// Curve type for coherence mapping
public enum MappingCurve: String, Sendable, Codable, CaseIterable {
    case linear
    case exponential
    case logarithmic
    case sCurve
    case sine
    case stepped2 = "stepped_2"
    case stepped4 = "stepped_4"
    case stepped8 = "stepped_8"

    /// Create stepped curve with custom step count
    public static func stepped(steps: Int) -> MappingCurve {
        switch steps {
        case ...2: return .stepped2
        case 3...5: return .stepped4
        default: return .stepped8
        }
    }

    /// Apply curve to normalized value (0-1)
    @inline(__always)
    public func apply(_ x: Float) -> Float {
        switch self {
        case .linear:
            return x

        case .exponential:
            // Quadratic curve
            return x * x

        case .logarithmic:
            // Square root curve
            return sqrt(x)

        case .sCurve:
            // Smoothstep (3x² - 2x³)
            return x * x * (3 - 2 * x)

        case .sine:
            // Sine ease in-out
            return (1 - cos(x * .pi)) / 2

        case .stepped2:
            return floor(x * 2) / 1

        case .stepped4:
            return floor(x * 4) / 3

        case .stepped8:
            return floor(x * 8) / 7
        }
    }
}

// MARK: - Bio Configuration

/// Serializable bio-reactive configuration
public struct BioConfiguration: Sendable, Codable, Hashable {
    public var enabled: Bool
    public var mapping: CoherenceMapping
    public var smoothingFactor: Float
    public var threshold: NormalizedCoherence

    public init(
        enabled: Bool = true,
        mapping: CoherenceMapping = .standard,
        smoothingFactor: Float = 0.3,
        threshold: NormalizedCoherence = .zero
    ) {
        self.enabled = enabled
        self.mapping = mapping
        self.smoothingFactor = smoothingFactor
        self.threshold = threshold
    }

    /// Default configuration
    public static let `default` = BioConfiguration()

    /// Meditation configuration (slower response)
    public static let meditation = BioConfiguration(
        mapping: .sCurve,
        smoothingFactor: 0.8
    )

    /// Performance configuration (fast response)
    public static let performance = BioConfiguration(
        mapping: .linear,
        smoothingFactor: 0.1
    )

    /// Ambient configuration (subtle changes)
    public static let ambient = BioConfiguration(
        mapping: CoherenceMapping(
            curve: .logarithmic,
            outputMin: 0.3,
            outputMax: 0.7
        ),
        smoothingFactor: 0.6
    )
}

// MARK: - Bio-Reactive Registry

/// Central registry of all bio-reactive components
///
/// Manages all BioReactiveConfigurable instances in the system.
/// Broadcasts bio data updates efficiently.
@MainActor
public final class BioReactiveRegistry: ObservableObject {

    /// Singleton instance
    public static let shared = BioReactiveRegistry()

    /// All registered components (weak references)
    private var components: [ObjectIdentifier: WeakBox<AnyObject>] = [:]

    /// Current bio data
    @Published public private(set) var currentBioData: TypeSafeBioData = .resting

    /// Number of registered components
    public var componentCount: Int { components.count }

    private init() {}

    // MARK: - Registration

    /// Register a bio-reactive component
    public func register<T: BioReactiveConfigurable>(_ component: T) {
        let id = ObjectIdentifier(component)
        components[id] = WeakBox(component)
        log.lambda("BioReactiveRegistry: Registered \(type(of: component))")
    }

    /// Unregister a component
    public func unregister<T: BioReactiveConfigurable>(_ component: T) {
        let id = ObjectIdentifier(component)
        components.removeValue(forKey: id)
        log.lambda("BioReactiveRegistry: Unregistered \(type(of: component))")
    }

    // MARK: - Update

    /// Broadcast bio data to all registered components
    ///
    /// Called at 60Hz from UnifiedControlHub
    public func broadcast(_ data: TypeSafeBioData) {
        currentBioData = data

        // Clean up dead references and update live ones
        var toRemove: [ObjectIdentifier] = []

        for (id, box) in components {
            if let component = box.value as? BioReactiveConfigurable {
                if component.bioReactiveEnabled {
                    component.updateWithBioData(data)
                }
            } else {
                toRemove.append(id)
            }
        }

        // Remove dead references
        for id in toRemove {
            components.removeValue(forKey: id)
        }
    }

    /// Get all active components
    public func getActiveComponents() -> [BioReactiveConfigurable] {
        components.values.compactMap { $0.value as? BioReactiveConfigurable }
    }

    /// Apply configuration to all components
    public func applyToAll(_ config: BioConfiguration) {
        for component in getActiveComponents() {
            component.applyBioConfiguration(config)
        }
    }

    /// Enable/disable all components
    public func setAllEnabled(_ enabled: Bool) {
        for component in getActiveComponents() {
            component.bioReactiveEnabled = enabled
        }
    }
}

// MARK: - Weak Box Helper

/// Weak reference wrapper for registry
private class WeakBox<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Property Wrapper

/// Property wrapper for bio-reactive parameters
///
/// Automatically applies coherence mapping to the wrapped value.
///
/// Example:
/// ```swift
/// @BioReactive(mapping: .filterCutoff)
/// var cutoffFrequency: Float = 1000
/// ```
@propertyWrapper
public struct BioReactive<Value: BinaryFloatingPoint> {

    private var storedValue: Value
    private var baseValue: Value
    private var lastCoherence: NormalizedCoherence = .medium

    /// The coherence mapping to use
    public var mapping: CoherenceMapping

    /// The current value (modulated by coherence)
    public var wrappedValue: Value {
        get { storedValue }
        set { baseValue = newValue; updateValue() }
    }

    /// Access to the wrapper itself
    public var projectedValue: BioReactive<Value> {
        get { self }
        set { self = newValue }
    }

    /// Initialize with default value and mapping
    public init(wrappedValue: Value, mapping: CoherenceMapping = .standard) {
        self.storedValue = wrappedValue
        self.baseValue = wrappedValue
        self.mapping = mapping
    }

    /// Update with coherence
    public mutating func update(coherence: NormalizedCoherence) {
        lastCoherence = coherence
        updateValue()
    }

    private mutating func updateValue() {
        let mapped = mapping.map(lastCoherence)
        storedValue = Value(mapped)
    }

    /// Get the base (unmodulated) value
    public var base: Value { baseValue }
}
