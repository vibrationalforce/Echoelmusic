// CoherenceTypes.swift
// Echoelmusic - Type-Safe Coherence Value Types
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Prevents mixing up HeartMath scale (0-100) with normalized scale (0-1).
// Compile-time safety for bio-reactive parameter passing.
//
// Supported Platforms: ALL (Swift 5.9+)
// Created 2026-01-16

import Foundation

// MARK: - HeartMath Coherence (0-100 Scale)

/// HeartMath coherence value (0-100 scale)
///
/// This is the standard scale used by:
/// - HeartMath Institute research
/// - HealthKitManager.hrvCoherence
/// - Raw biofeedback device readings
///
/// Scale interpretation (HeartMath):
/// - 0-40: Low coherence (stress/anxiety)
/// - 40-60: Medium coherence (transitional)
/// - 60-100: High coherence (optimal/flow state)
///
/// Use `.normalized` to convert to 0-1 scale for audio/visual parameters.
@frozen
public struct HeartMathCoherence: Sendable, Hashable {

    /// Raw value on 0-100 scale
    public let value: Double

    /// Create a HeartMath coherence value
    ///
    /// - Parameter value: Coherence on 0-100 scale (clamped automatically)
    @inline(__always)
    public init(_ value: Double) {
        self.value = max(0, min(100, value))
    }

    /// Create from Float
    @inline(__always)
    public init(_ value: Float) {
        self.init(Double(value))
    }

    /// Create from Int
    @inline(__always)
    public init(_ value: Int) {
        self.init(Double(value))
    }

    // MARK: - Conversion

    /// Convert to normalized (0-1) scale
    @inline(__always)
    public var normalized: NormalizedCoherence {
        NormalizedCoherence(value / 100.0)
    }

    /// Float value for audio processing
    @inline(__always)
    public var floatValue: Float {
        Float(value)
    }

    // MARK: - State Detection

    /// Whether this is high coherence (>= 60)
    @inline(__always)
    public var isHigh: Bool {
        value >= AudioConstants.Coherence.highThreshold
    }

    /// Whether this is low coherence (< 40)
    @inline(__always)
    public var isLow: Bool {
        value < AudioConstants.Coherence.lowThreshold
    }

    /// Whether this is medium coherence (40-60)
    @inline(__always)
    public var isMedium: Bool {
        value >= AudioConstants.Coherence.lowThreshold &&
        value < AudioConstants.Coherence.highThreshold
    }

    // MARK: - Presets

    /// Zero coherence
    public static let zero = HeartMathCoherence(0)

    /// Low coherence threshold
    public static let low = HeartMathCoherence(AudioConstants.Coherence.lowThreshold)

    /// Medium coherence
    public static let medium = HeartMathCoherence(50)

    /// High coherence threshold
    public static let high = HeartMathCoherence(AudioConstants.Coherence.highThreshold)

    /// Maximum coherence
    public static let max = HeartMathCoherence(100)
}

// MARK: - Normalized Coherence (0-1 Scale)

/// Normalized coherence value (0-1 scale)
///
/// This is the scale used by:
/// - Visual effects (intensity, color, etc.)
/// - Audio parameters (filter, reverb, etc.)
/// - Light output (DMX, ILDA, Art-Net)
/// - Lambda Mode visual state
///
/// Use `.heartMath` to convert back to 0-100 scale if needed.
@frozen
public struct NormalizedCoherence: Sendable, Hashable {

    /// Raw value on 0-1 scale
    public let value: Double

    /// Create a normalized coherence value
    ///
    /// - Parameter value: Coherence on 0-1 scale (clamped automatically)
    @inline(__always)
    public init(_ value: Double) {
        self.value = max(0, min(1, value))
    }

    /// Create from Float
    @inline(__always)
    public init(_ value: Float) {
        self.init(Double(value))
    }

    // MARK: - Conversion

    /// Convert to HeartMath (0-100) scale
    @inline(__always)
    public var heartMath: HeartMathCoherence {
        HeartMathCoherence(value * 100.0)
    }

    /// Float value for audio/visual processing
    @inline(__always)
    public var floatValue: Float {
        Float(value)
    }

    // MARK: - State Detection

    /// Whether this is high coherence (>= 0.6)
    @inline(__always)
    public var isHigh: Bool {
        value >= 0.6
    }

    /// Whether this is low coherence (< 0.4)
    @inline(__always)
    public var isLow: Bool {
        value < 0.4
    }

    /// Whether this is medium coherence (0.4-0.6)
    @inline(__always)
    public var isMedium: Bool {
        value >= 0.4 && value < 0.6
    }

    // MARK: - Interpolation

    /// Linear interpolation between two coherence values
    ///
    /// - Parameters:
    ///   - other: Target coherence
    ///   - t: Interpolation factor (0 = self, 1 = other)
    /// - Returns: Interpolated coherence
    @inline(__always)
    public func lerp(to other: NormalizedCoherence, t: Double) -> NormalizedCoherence {
        NormalizedCoherence(value + (other.value - value) * t)
    }

    /// Smoothed coherence using exponential moving average
    ///
    /// - Parameters:
    ///   - newValue: New coherence reading
    ///   - alpha: Smoothing factor (0 = no change, 1 = instant)
    /// - Returns: Smoothed coherence
    @inline(__always)
    public func smoothed(with newValue: NormalizedCoherence, alpha: Double = 0.3) -> NormalizedCoherence {
        lerp(to: newValue, t: alpha)
    }

    // MARK: - Presets

    /// Zero coherence
    public static let zero = NormalizedCoherence(0)

    /// Low coherence threshold
    public static let low = NormalizedCoherence(0.4)

    /// Medium coherence
    public static let medium = NormalizedCoherence(0.5)

    /// High coherence threshold
    public static let high = NormalizedCoherence(0.6)

    /// Maximum coherence
    public static let max = NormalizedCoherence(1.0)
}

// MARK: - Comparable

extension HeartMathCoherence: Comparable {
    @inline(__always)
    public static func < (lhs: HeartMathCoherence, rhs: HeartMathCoherence) -> Bool {
        lhs.value < rhs.value
    }
}

extension NormalizedCoherence: Comparable {
    @inline(__always)
    public static func < (lhs: NormalizedCoherence, rhs: NormalizedCoherence) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - CustomStringConvertible

extension HeartMathCoherence: CustomStringConvertible {
    public var description: String {
        String(format: "%.1f (HeartMath)", value)
    }
}

extension NormalizedCoherence: CustomStringConvertible {
    public var description: String {
        String(format: "%.3f (normalized)", value)
    }
}

// MARK: - Codable

extension HeartMathCoherence: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(Double.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension NormalizedCoherence: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(Double.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - ExpressibleByFloatLiteral

extension HeartMathCoherence: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension NormalizedCoherence: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension HeartMathCoherence: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension NormalizedCoherence: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

// MARK: - Arithmetic Operations

extension NormalizedCoherence {
    /// Multiply coherence by a factor
    @inline(__always)
    public static func * (lhs: NormalizedCoherence, rhs: Double) -> NormalizedCoherence {
        NormalizedCoherence(lhs.value * rhs)
    }

    /// Add two coherence values (clamped)
    @inline(__always)
    public static func + (lhs: NormalizedCoherence, rhs: NormalizedCoherence) -> NormalizedCoherence {
        NormalizedCoherence(lhs.value + rhs.value)
    }

    /// Subtract coherence values (clamped)
    @inline(__always)
    public static func - (lhs: NormalizedCoherence, rhs: NormalizedCoherence) -> NormalizedCoherence {
        NormalizedCoherence(lhs.value - rhs.value)
    }
}

// MARK: - Bio Data Extension

/// Extension to hold type-safe bio data
public struct TypeSafeBioData: Sendable {
    /// Heart rate in BPM
    public let heartRate: Float

    /// HRV coherence (HeartMath scale)
    public let coherence: HeartMathCoherence

    /// Breathing phase (0-1)
    public let breathPhase: Float

    /// GSR (galvanic skin response)
    public let gsr: Float

    /// SpO2 (blood oxygen saturation percentage)
    public let spO2: Float

    /// Normalized coherence for audio/visual use
    @inline(__always)
    public var normalizedCoherence: NormalizedCoherence {
        coherence.normalized
    }

    /// Initialize with raw values
    public init(
        heartRate: Float = 72,
        coherence: Double = 50,
        breathPhase: Float = 0,
        gsr: Float = 0.5,
        spO2: Float = 98
    ) {
        self.heartRate = heartRate
        self.coherence = HeartMathCoherence(coherence)
        self.breathPhase = breathPhase
        self.gsr = gsr
        self.spO2 = spO2
    }

    /// Initialize with type-safe coherence
    public init(
        heartRate: Float,
        coherence: HeartMathCoherence,
        breathPhase: Float,
        gsr: Float,
        spO2: Float
    ) {
        self.heartRate = heartRate
        self.coherence = coherence
        self.breathPhase = breathPhase
        self.gsr = gsr
        self.spO2 = spO2
    }

    /// Default resting state
    public static let resting = TypeSafeBioData(
        heartRate: 72,
        coherence: 50,
        breathPhase: 0,
        gsr: 0.5,
        spO2: 98
    )

    /// High coherence flow state
    public static let flow = TypeSafeBioData(
        heartRate: 65,
        coherence: 80,
        breathPhase: 0.5,
        gsr: 0.4,
        spO2: 99
    )

    /// Low coherence stress state
    public static let stressed = TypeSafeBioData(
        heartRate: 95,
        coherence: 25,
        breathPhase: 0.2,
        gsr: 0.8,
        spO2: 97
    )
}
