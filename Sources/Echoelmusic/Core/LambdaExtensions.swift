// LambdaExtensions.swift
// Echoelmusic - Lambda-Style Functional Programming Extensions
// Clean, Declarative, Zero Stress Code Patterns

import Foundation
import Combine
import simd

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   λ FUNCTIONAL CORE - Pure Functions, No Side Effects
// MARK: ═══════════════════════════════════════════════════════════════════

// MARK: - Optional Extensions

public extension Optional {

    /// Unwrap or provide default (cleaner than ??)
    func or(_ defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        self ?? defaultValue()
    }

    /// Unwrap or throw error
    func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else { throw error() }
        return value
    }

    /// Execute closure only if value exists
    func whenSome(_ action: (Wrapped) -> Void) {
        if let value = self { action(value) }
    }

    /// Execute closure only if value is nil
    func whenNone(_ action: () -> Void) {
        if self == nil { action() }
    }

    /// Transform if present, otherwise return nil
    func flatMap<T>(_ transform: (Wrapped) throws -> T?) rethrows -> T? {
        guard let value = self else { return nil }
        return try transform(value)
    }

    /// Check if value matches predicate
    func filter(_ predicate: (Wrapped) -> Bool) -> Wrapped? {
        guard let value = self, predicate(value) else { return nil }
        return value
    }
}

// MARK: - Collection Extensions

public extension Collection {

    /// Safe subscript that returns nil instead of crashing
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    /// Returns element if collection has exactly one element
    var onlyElement: Element? {
        count == 1 ? first : nil
    }

    /// Check if collection is not empty
    var isNotEmpty: Bool {
        !isEmpty
    }
}

public extension Array {

    /// Transform each element with index
    func mapWithIndex<T>(_ transform: (Int, Element) throws -> T) rethrows -> [T] {
        try enumerated().map { try transform($0.offset, $0.element) }
    }

    /// Filter with index access
    func filterWithIndex(_ isIncluded: (Int, Element) throws -> Bool) rethrows -> [Element] {
        try enumerated().filter { try isIncluded($0.offset, $0.element) }.map(\.element)
    }

    /// Compact map in one step
    func compactMapWithIndex<T>(_ transform: (Int, Element) throws -> T?) rethrows -> [T] {
        try enumerated().compactMap { try transform($0.offset, $0.element) }
    }

    /// Partition array by predicate
    func partition(by predicate: (Element) -> Bool) -> (matching: [Element], notMatching: [Element]) {
        var matching: [Element] = []
        var notMatching: [Element] = []
        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                notMatching.append(element)
            }
        }
        return (matching, notMatching)
    }

    /// Group elements by key
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        Dictionary(grouping: self) { $0[keyPath: keyPath] }
    }

    /// Remove duplicates while preserving order
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }

    /// Split into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

public extension Array where Element: Equatable {

    /// Remove duplicates preserving order
    var unique: [Element] {
        var result: [Element] = []
        for element in self where !result.contains(element) {
            result.append(element)
        }
        return result
    }
}

// MARK: - Result Extensions

public extension Result {

    /// Check if result is success
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// Check if result is failure
    var isFailure: Bool {
        !isSuccess
    }

    /// Get success value or nil
    var success: Success? {
        try? get()
    }

    /// Get error or nil
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }

    /// Execute action on success
    func onSuccess(_ action: (Success) -> Void) -> Self {
        if case .success(let value) = self {
            action(value)
        }
        return self
    }

    /// Execute action on failure
    func onFailure(_ action: (Failure) -> Void) -> Self {
        if case .failure(let error) = self {
            action(error)
        }
        return self
    }

    /// Recover from error with default value
    func recover(_ recovery: (Failure) -> Success) -> Success {
        switch self {
        case .success(let value): return value
        case .failure(let error): return recovery(error)
        }
    }
}

// MARK: - String Extensions

public extension String {

    /// Check if string is not empty and not just whitespace
    var isNotBlank: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Safely get substring
    subscript(safe range: Range<Int>) -> String? {
        guard range.lowerBound >= 0,
              range.upperBound <= count else { return nil }
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return String(self[start..<end])
    }

    /// Truncate with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String {
        count > length ? String(prefix(length)) + trailing : self
    }

    /// Convert to URL safely
    var asURL: URL? {
        URL(string: self)
    }

    /// Convert to Int safely
    var asInt: Int? {
        Int(self)
    }

    /// Convert to Double safely
    var asDouble: Double? {
        Double(self)
    }
}

// MARK: - Numeric Extensions

public extension Comparable {

    /// Clamp value to range
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension BinaryFloatingPoint {

    /// Linear interpolation
    func lerp(to target: Self, amount: Self) -> Self {
        self + (target - self) * amount
    }

    /// Map from one range to another
    func mapped(from source: ClosedRange<Self>, to destination: ClosedRange<Self>) -> Self {
        let normalized = (self - source.lowerBound) / (source.upperBound - source.lowerBound)
        return destination.lowerBound + normalized * (destination.upperBound - destination.lowerBound)
    }
}

public extension Float {

    /// Convert to decibels
    var toDecibels: Float {
        20 * log10(max(self, 0.000001))
    }

    /// Convert from decibels to linear
    var fromDecibels: Float {
        pow(10, self / 20)
    }

    /// Normalize to 0-1 range
    func normalized(min: Float, max: Float) -> Float {
        (self - min) / (max - min)
    }
}

// MARK: - SIMD Extensions

public extension SIMD3 where Scalar == Float {

    /// Zero vector
    static var zero: SIMD3<Float> { .init(0, 0, 0) }

    /// Unit vectors
    static var up: SIMD3<Float> { .init(0, 1, 0) }
    static var down: SIMD3<Float> { .init(0, -1, 0) }
    static var left: SIMD3<Float> { .init(-1, 0, 0) }
    static var right: SIMD3<Float> { .init(1, 0, 0) }
    static var forward: SIMD3<Float> { .init(0, 0, -1) }
    static var backward: SIMD3<Float> { .init(0, 0, 1) }

    /// Magnitude (length)
    var magnitude: Float {
        simd_length(self)
    }

    /// Normalized (unit) vector
    var normalized: SIMD3<Float> {
        simd_normalize(self)
    }

    /// Distance to another point
    func distance(to other: SIMD3<Float>) -> Float {
        simd_distance(self, other)
    }

    /// Dot product
    func dot(_ other: SIMD3<Float>) -> Float {
        simd_dot(self, other)
    }

    /// Cross product
    func cross(_ other: SIMD3<Float>) -> SIMD3<Float> {
        simd_cross(self, other)
    }

    /// Linear interpolation
    func lerp(to target: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        simd_mix(self, target, SIMD3<Float>(repeating: t))
    }
}

// MARK: - Function Composition

/// Pipe operator: x |> f = f(x)
infix operator |>: AdditionPrecedence

public func |> <A, B>(value: A, function: (A) -> B) -> B {
    function(value)
}

/// Compose operator: f >>> g = { x in g(f(x)) }
infix operator >>>: AdditionPrecedence

public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
    { a in g(f(a)) }
}

// MARK: - Curry Functions

/// Curry a 2-argument function
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    { a in { b in f(a, b) } }
}

/// Curry a 3-argument function
public func curry<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
    { a in { b in { c in f(a, b, c) } } }
}

// MARK: - Memoization

/// Memoize a single-argument function
public func memoize<Input: Hashable, Output>(_ function: @escaping (Input) -> Output) -> (Input) -> Output {
    var cache: [Input: Output] = [:]
    return { input in
        if let cached = cache[input] {
            return cached
        }
        let result = function(input)
        cache[input] = result
        return result
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🔄 ASYNC EXTENSIONS - Clean Async/Await Patterns
// MARK: ═══════════════════════════════════════════════════════════════════

public extension Task where Success == Never, Failure == Never {

    /// Sleep for specified seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Sleep for specified milliseconds
    static func sleep(milliseconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

/// Retry an async operation with exponential backoff
public func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 30.0,
    multiplier: Double = 2.0,
    operation: () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(seconds: currentDelay)
                currentDelay = min(currentDelay * multiplier, maxDelay)
            }
        }
    }

    throw lastError ?? AppError.internalError(description: "Retry failed")
}

/// Execute with timeout
public func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(seconds: seconds)
            throw NetworkError.timeout(operation: "Operation", seconds: Int(seconds))
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🎨 BUILDER PATTERN - Fluent Configuration
// MARK: ═══════════════════════════════════════════════════════════════════

/// Protocol for builder pattern
public protocol Builder {
    associatedtype Product
    func build() -> Product
}

/// Configurable protocol for fluent API
public protocol Configurable {}

public extension Configurable {

    /// Configure self and return self (fluent pattern)
    @discardableResult
    func configured(_ configure: (inout Self) -> Void) -> Self {
        var copy = self
        configure(&copy)
        return copy
    }
}

/// Apply configuration to any type
@discardableResult
public func configure<T>(_ value: T, _ configure: (inout T) -> Void) -> T {
    var mutableValue = value
    configure(&mutableValue)
    return mutableValue
}

/// With pattern for reference types
@discardableResult
public func with<T: AnyObject>(_ object: T, _ configure: (T) -> Void) -> T {
    configure(object)
    return object
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🛡️ SAFE OPERATIONS - Zero Runtime Crashes
// MARK: ═══════════════════════════════════════════════════════════════════

/// Safe division (returns nil on divide by zero)
public func safeDivide<T: BinaryFloatingPoint>(_ numerator: T, by denominator: T) -> T? {
    guard denominator != 0 else { return nil }
    return numerator / denominator
}

/// Safe division with default
public func safeDivide<T: BinaryFloatingPoint>(_ numerator: T, by denominator: T, default: T) -> T {
    safeDivide(numerator, by: denominator) ?? `default`
}

/// Safe array access
public func safeGet<T>(_ array: [T], at index: Int) -> T? {
    guard index >= 0 && index < array.count else { return nil }
    return array[index]
}

/// Safe dictionary access with transform
public func safeGet<K, V, T>(_ dict: [K: V], key: K, transform: (V) -> T?) -> T? {
    guard let value = dict[key] else { return nil }
    return transform(value)
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   📦 TYPE-SAFE IDENTIFIERS
// MARK: ═══════════════════════════════════════════════════════════════════

/// Type-safe identifier wrapper
public struct Identifier<T>: Hashable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static func random() -> Identifier<T> {
        Identifier(UUID().uuidString)
    }
}

/// Type aliases for common identifiers
public typealias TrackID = Identifier<RecordingTrack>
public typealias SessionID = Identifier<RecordingSession>

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🎵 AUDIO-SPECIFIC LAMBDA EXTENSIONS
// MARK: ═══════════════════════════════════════════════════════════════════

public extension Array where Element == Float {

    /// Calculate RMS (Root Mean Square)
    var rms: Float {
        guard !isEmpty else { return 0 }
        let sumOfSquares = reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(count))
    }

    /// Calculate peak amplitude
    var peak: Float {
        map(abs).max() ?? 0
    }

    /// Normalize to -1...1 range
    var normalized: [Float] {
        guard let maxVal = map(abs).max(), maxVal > 0 else { return self }
        return map { $0 / maxVal }
    }

    /// Apply gain
    func withGain(_ gain: Float) -> [Float] {
        map { $0 * gain }
    }

    /// Apply soft clipping
    var softClipped: [Float] {
        map { tanh($0) }
    }

    /// Downsample by factor
    func downsampled(by factor: Int) -> [Float] {
        stride(from: 0, to: count, by: factor).compactMap { self[safe: $0] }
    }
}
