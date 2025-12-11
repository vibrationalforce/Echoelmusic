// QuantumPlatform.swift
// Echoelmusic - Quantum Science Cross-Platform Architecture
// SPDX-License-Identifier: MIT
//
// Ultra-safe, cross-platform, thread-safe quantum computing-inspired architecture
// Supporting: iOS, iPadOS, macOS, tvOS, watchOS, visionOS, Linux, Windows

import Foundation
import Combine

// MARK: - Platform Detection

/// Comprehensive platform detection for all operating systems
public enum Platform: String, Codable, Sendable {
    case iOS
    case iPadOS
    case macOS
    case tvOS
    case watchOS
    case visionOS
    case linux
    case windows
    case android
    case unknown

    public static var current: Platform {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPadOS
        }
        return .iOS
        #elseif os(macOS)
        return .macOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(visionOS)
        return .visionOS
        #elseif os(Linux)
        return .linux
        #elseif os(Windows)
        return .windows
        #elseif os(Android)
        return .android
        #else
        return .unknown
        #endif
    }

    public var isApple: Bool {
        switch self {
        case .iOS, .iPadOS, .macOS, .tvOS, .watchOS, .visionOS:
            return true
        default:
            return false
        }
    }

    public var supportsMetal: Bool {
        isApple && self != .watchOS
    }

    public var supportsARKit: Bool {
        switch self {
        case .iOS, .iPadOS, .visionOS:
            return true
        default:
            return false
        }
    }

    public var supportsHealthKit: Bool {
        switch self {
        case .iOS, .iPadOS, .watchOS:
            return true
        default:
            return false
        }
    }

    public var supportsAudioUnit: Bool {
        isApple
    }

    public var maxAudioChannels: Int {
        switch self {
        case .watchOS:
            return 2
        case .tvOS:
            return 8
        case .visionOS:
            return 128 // Spatial audio
        default:
            return 32
        }
    }
}

// MARK: - Safe Unwrapping Utilities

/// Quantum-safe optional handling - eliminates all force unwraps
public enum SafeUnwrap {

    /// Safely unwrap with a default value
    @inlinable
    public static func unwrap<T>(_ optional: T?, default defaultValue: @autoclosure () -> T) -> T {
        optional ?? defaultValue()
    }

    /// Safely unwrap with throwing
    @inlinable
    public static func unwrap<T>(_ optional: T?, or error: Error) throws -> T {
        guard let value = optional else {
            throw error
        }
        return value
    }

    /// Safely unwrap with async default
    @inlinable
    public static func unwrap<T>(_ optional: T?, asyncDefault: () async -> T) async -> T {
        if let value = optional {
            return value
        }
        return await asyncDefault()
    }

    /// Safely unwrap array element
    @inlinable
    public static func element<T>(at index: Int, in array: [T], default defaultValue: @autoclosure () -> T) -> T {
        guard index >= 0 && index < array.count else {
            return defaultValue()
        }
        return array[index]
    }

    /// Safely unwrap dictionary value
    @inlinable
    public static func value<K, V>(for key: K, in dict: [K: V], default defaultValue: @autoclosure () -> V) -> V where K: Hashable {
        dict[key] ?? defaultValue()
    }
}

// MARK: - Safe Optional Extension

public extension Optional {

    /// Safe unwrap with default
    @inlinable
    func safely(_ defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        self ?? defaultValue()
    }

    /// Safe unwrap with throwing error
    @inlinable
    func safelyThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else {
            throw error
        }
        return value
    }

    /// Safe unwrap with logging
    func safelyLog(_ message: String, file: String = #file, line: Int = #line) -> Wrapped? {
        if self == nil {
            print("⚠️ [\(file):\(line)] \(message)")
        }
        return self
    }

    /// Transform if present, return default otherwise
    @inlinable
    func mapOr<T>(_ transform: (Wrapped) -> T, default defaultValue: @autoclosure () -> T) -> T {
        if let value = self {
            return transform(value)
        }
        return defaultValue()
    }

    /// Async safe unwrap
    @inlinable
    func safelyAsync(_ defaultValue: @escaping () async -> Wrapped) async -> Wrapped {
        if let value = self {
            return value
        }
        return await defaultValue()
    }
}

// MARK: - Safe Collection Extensions

public extension Collection {

    /// Safe subscript that returns optional
    @inlinable
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    /// Safe first element with default
    @inlinable
    func firstSafe(default defaultValue: @autoclosure () -> Element) -> Element {
        first ?? defaultValue()
    }

    /// Safe last element with default
    @inlinable
    func lastSafe(default defaultValue: @autoclosure () -> Element) -> Element where Self: BidirectionalCollection {
        last ?? defaultValue()
    }
}

public extension Array {

    /// Safe subscript with default value
    @inlinable
    subscript(safe index: Int, default defaultValue: @autoclosure () -> Element) -> Element {
        guard index >= 0 && index < count else {
            return defaultValue()
        }
        return self[index]
    }

    /// Safe first matching predicate
    @inlinable
    func firstSafe(where predicate: (Element) -> Bool, default defaultValue: @autoclosure () -> Element) -> Element {
        first(where: predicate) ?? defaultValue()
    }

    /// Safe remove at index
    @inlinable
    mutating func safeRemove(at index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        return remove(at: index)
    }
}

public extension Dictionary {

    /// Safe subscript with default
    @inlinable
    subscript(safe key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        self[key] ?? defaultValue()
    }
}

// MARK: - Thread-Safe Quantum State

/// Thread-safe state container using actors
public actor QuantumState<T: Sendable> {
    private var value: T
    private var observers: [(T) -> Void] = []

    public init(_ initialValue: T) {
        self.value = initialValue
    }

    public func get() -> T {
        value
    }

    public func set(_ newValue: T) {
        value = newValue
        for observer in observers {
            observer(newValue)
        }
    }

    public func update(_ transform: (inout T) -> Void) {
        transform(&value)
        for observer in observers {
            observer(value)
        }
    }

    public func observe(_ handler: @escaping (T) -> Void) {
        observers.append(handler)
        handler(value)
    }

    /// Compare and swap - atomic operation
    public func compareAndSwap(expected: T, new: T) -> Bool where T: Equatable {
        guard value == expected else {
            return false
        }
        value = new
        return true
    }
}

// MARK: - Quantum Lock

/// High-performance lock for critical sections
public actor QuantumLock {
    private var isLocked = false
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func acquire() async {
        if isLocked {
            await withCheckedContinuation { continuation in
                waitQueue.append(continuation)
            }
        }
        isLocked = true
    }

    public func release() {
        isLocked = false
        if let next = waitQueue.first {
            waitQueue.removeFirst()
            next.resume()
        }
    }

    public func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { Task { await release() } }
        return try await operation()
    }
}

// MARK: - Cross-Platform Abstractions

/// Cross-platform color type
public struct QuantumColor: Codable, Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
        self.alpha = alpha.clamped(to: 0...1)
    }

    public init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.red = Double((rgb & 0xFF0000) >> 16) / 255.0
        self.green = Double((rgb & 0x00FF00) >> 8) / 255.0
        self.blue = Double(rgb & 0x0000FF) / 255.0
        self.alpha = 1.0
    }

    #if canImport(SwiftUI)
    import SwiftUI
    public var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    #endif

    #if canImport(UIKit)
    import UIKit
    public var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    #endif

    #if canImport(AppKit)
    import AppKit
    public var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    #endif

    // Predefined colors
    public static let clear = QuantumColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let white = QuantumColor(red: 1, green: 1, blue: 1)
    public static let black = QuantumColor(red: 0, green: 0, blue: 0)
    public static let red = QuantumColor(red: 1, green: 0, blue: 0)
    public static let green = QuantumColor(red: 0, green: 1, blue: 0)
    public static let blue = QuantumColor(red: 0, green: 0, blue: 1)
    public static let vaporwavePink = QuantumColor(hex: "FF6AD5")
    public static let vaporwaveCyan = QuantumColor(hex: "00FFFF")
    public static let vaporwavePurple = QuantumColor(hex: "9B59B6")
}

/// Cross-platform point type
public struct QuantumPoint: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = QuantumPoint(x: 0, y: 0)

    public func distance(to other: QuantumPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    #if canImport(CoreGraphics)
    import CoreGraphics
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }
    #endif
}

/// Cross-platform 3D point
public struct QuantumPoint3D: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = QuantumPoint3D(x: 0, y: 0, z: 0)

    public func distance(to other: QuantumPoint3D) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public var normalized: QuantumPoint3D {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return QuantumPoint3D(x: x / mag, y: y / mag, z: z / mag)
    }
}

/// Cross-platform size type
public struct QuantumSize: Codable, Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public static let zero = QuantumSize(width: 0, height: 0)

    public var area: Double { width * height }
    public var aspectRatio: Double { height > 0 ? width / height : 0 }

    #if canImport(CoreGraphics)
    import CoreGraphics
    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }

    public init(_ cgSize: CGSize) {
        self.width = Double(cgSize.width)
        self.height = Double(cgSize.height)
    }
    #endif
}

// MARK: - Quantum Result Type

/// Enhanced result type with quantum-inspired features
public enum QuantumResult<Success, Failure: Error>: Sendable where Success: Sendable, Failure: Sendable {
    case success(Success)
    case failure(Failure)
    case superposition([Result<Success, Failure>]) // Multiple possible outcomes

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var value: Success? {
        if case .success(let v) = self { return v }
        return nil
    }

    public var error: Failure? {
        if case .failure(let e) = self { return e }
        return nil
    }

    public func map<T>(_ transform: (Success) -> T) -> QuantumResult<T, Failure> where T: Sendable {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        case .superposition(let results):
            return .superposition(results.map { result in
                result.map(transform)
            })
        }
    }

    public func flatMap<T>(_ transform: (Success) -> QuantumResult<T, Failure>) -> QuantumResult<T, Failure> where T: Sendable {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        case .superposition:
            // Collapse superposition to most likely success
            if let firstSuccess = superpositionSuccesses.first {
                return transform(firstSuccess)
            }
            if let firstError = superpositionFailures.first {
                return .failure(firstError)
            }
            fatalError("Empty superposition")
        }
    }

    private var superpositionSuccesses: [Success] {
        guard case .superposition(let results) = self else { return [] }
        return results.compactMap { try? $0.get() }
    }

    private var superpositionFailures: [Failure] {
        guard case .superposition(let results) = self else { return [] }
        return results.compactMap { result in
            if case .failure(let error) = result { return error }
            return nil
        }
    }

    /// Collapse superposition to single result
    /// - Note: Returns first result if superposition contains any, preferring successes
    public func collapse() -> Result<Success, Failure>? {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        case .superposition(let results):
            // Prefer success over failure
            if let success = results.first(where: { if case .success = $0 { return true }; return false }) {
                return success
            }
            // Return first failure if no successes, or nil if empty
            return results.first
        }
    }
}

// MARK: - Numeric Clamping

public extension Comparable {
    @inlinable
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension BinaryFloatingPoint {
    @inlinable
    var normalized: Self {
        clamped(to: 0...1)
    }

    @inlinable
    var signedNormalized: Self {
        clamped(to: -1...1)
    }

    @inlinable
    func lerp(to: Self, t: Self) -> Self {
        self + (to - self) * t.normalized
    }
}

// MARK: - Safe Casting

public enum SafeCast {

    /// Safe numeric cast
    @inlinable
    public static func numeric<T: BinaryInteger, U: BinaryInteger>(_ value: T) -> U? {
        U(exactly: value)
    }

    /// Safe floating point cast
    @inlinable
    public static func float<T: BinaryFloatingPoint, U: BinaryFloatingPoint>(_ value: T) -> U {
        U(value)
    }

    /// Safe type cast with default
    @inlinable
    public static func cast<T>(_ value: Any, to type: T.Type, default defaultValue: @autoclosure () -> T) -> T {
        (value as? T) ?? defaultValue()
    }

    /// Safe downcast
    @inlinable
    public static func downcast<T, U>(_ value: T, to type: U.Type) -> U? {
        value as? U
    }
}

// MARK: - Quantum Validation

/// Input validation with quantum certainty levels
public actor QuantumValidator {

    public enum Certainty: Double, Sendable {
        case absolute = 1.0      // 100% certain
        case veryHigh = 0.99     // 99% certain
        case high = 0.95         // 95% certain
        case medium = 0.80       // 80% certain
        case low = 0.50          // 50% certain
        case veryLow = 0.20      // 20% certain
        case uncertain = 0.0     // 0% certain
    }

    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let certainty: Certainty
        public let errors: [String]
        public let warnings: [String]

        public static func valid(certainty: Certainty = .absolute) -> ValidationResult {
            ValidationResult(isValid: true, certainty: certainty, errors: [], warnings: [])
        }

        public static func invalid(errors: [String], certainty: Certainty = .absolute) -> ValidationResult {
            ValidationResult(isValid: false, certainty: certainty, errors: errors, warnings: [])
        }
    }

    public init() {}

    // MIDI validation (0-127)
    public func validateMIDI(_ value: Int) -> ValidationResult {
        if value >= 0 && value <= 127 {
            return .valid()
        }
        return .invalid(errors: ["MIDI value must be 0-127, got \(value)"])
    }

    // Audio level validation (0.0-1.0)
    public func validateAudioLevel(_ value: Double) -> ValidationResult {
        if value >= 0.0 && value <= 1.0 {
            return .valid()
        }
        if value < 0 {
            return .invalid(errors: ["Audio level cannot be negative: \(value)"])
        }
        return .invalid(errors: ["Audio level cannot exceed 1.0: \(value)"])
    }

    // Frequency validation (20Hz-20kHz audible range)
    public func validateFrequency(_ hz: Double, extended: Bool = false) -> ValidationResult {
        let minHz = extended ? 0.1 : 20.0
        let maxHz = extended ? 100_000.0 : 20_000.0

        if hz >= minHz && hz <= maxHz {
            return .valid()
        }
        return .invalid(errors: ["Frequency \(hz)Hz outside range \(minHz)-\(maxHz)Hz"])
    }

    // Spatial position validation (-1.0 to 1.0 normalized)
    public func validateSpatialPosition(_ position: QuantumPoint3D) -> ValidationResult {
        var errors: [String] = []

        if position.x < -1.0 || position.x > 1.0 {
            errors.append("X position \(position.x) outside -1.0 to 1.0 range")
        }
        if position.y < -1.0 || position.y > 1.0 {
            errors.append("Y position \(position.y) outside -1.0 to 1.0 range")
        }
        if position.z < -1.0 || position.z > 1.0 {
            errors.append("Z position \(position.z) outside -1.0 to 1.0 range")
        }

        if errors.isEmpty {
            return .valid()
        }
        return .invalid(errors: errors)
    }

    // BPM validation
    public func validateBPM(_ bpm: Double) -> ValidationResult {
        if bpm >= 20 && bpm <= 400 {
            return .valid()
        }
        return .invalid(errors: ["BPM \(bpm) outside reasonable range 20-400"])
    }

    // Sample rate validation
    public func validateSampleRate(_ rate: Double) -> ValidationResult {
        let validRates: Set<Double> = [8000, 11025, 22050, 44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000]
        if validRates.contains(rate) {
            return .valid()
        }
        return .invalid(errors: ["Sample rate \(rate)Hz is non-standard"])
    }
}

// MARK: - Platform-Specific Imports Helper

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif
