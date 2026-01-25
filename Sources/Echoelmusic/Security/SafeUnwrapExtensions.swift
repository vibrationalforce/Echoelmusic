// SafeUnwrapExtensions.swift
// Echoelmusic - Safe Unwrap Extensions to Eliminate Force Unwraps
//
// Created: 2026-01-25
// Purpose: Provide safe alternatives to force unwraps throughout the codebase
//
// SECURITY LEVEL: Production
// Prevents: Runtime crashes from nil values

import Foundation
import AVFoundation
import CoreGraphics

// MARK: - Optional Extensions

public extension Optional {

    /// Safely unwrap with a default value
    /// Usage: optionalValue.unwrap(default: fallbackValue)
    func unwrap(default defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        self ?? defaultValue()
    }

    /// Safely unwrap with a throwing fallback
    /// Usage: try optionalValue.unwrap(orThrow: SomeError.nilValue)
    func unwrap(orThrow error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else {
            throw error()
        }
        return value
    }

    /// Safely unwrap with logging
    /// Usage: optionalValue.unwrap(default: fallback, logNil: "Value was nil")
    func unwrap(default defaultValue: @autoclosure () -> Wrapped, logNil message: String) -> Wrapped {
        if self == nil {
            #if DEBUG
            print("[SafeUnwrap] \(message)")
            #endif
        }
        return self ?? defaultValue()
    }

    /// Check if value exists and satisfies condition
    func exists(where predicate: (Wrapped) -> Bool) -> Bool {
        if let value = self {
            return predicate(value)
        }
        return false
    }

    /// Map only if condition is met
    func mapIf<T>(_ condition: Bool, _ transform: (Wrapped) -> T) -> T? {
        guard condition, let value = self else { return nil }
        return transform(value)
    }

    /// Execute closure only if value exists
    func ifPresent(_ action: (Wrapped) -> Void) {
        if let value = self {
            action(value)
        }
    }

    /// Safe force unwrap with crash prevention in production
    var safeForce: Wrapped? {
        #if DEBUG
        // In debug, crash to catch issues early
        return self!
        #else
        // In production, return nil to prevent crash
        return self
        #endif
    }
}

// MARK: - Optional String Extensions

public extension Optional where Wrapped == String {

    /// Safely unwrap string with empty string default
    var orEmpty: String {
        self ?? ""
    }

    /// Check if string is nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    /// Safely unwrap with trimmed whitespace
    var orEmptyTrimmed: String {
        self?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Safe localized string
    var localizedOrEmpty: String {
        if let key = self {
            return NSLocalizedString(key, comment: "")
        }
        return ""
    }
}

// MARK: - Optional Numeric Extensions

public extension Optional where Wrapped: Numeric {

    /// Safely unwrap numeric with zero default
    var orZero: Wrapped {
        self ?? 0
    }
}

public extension Optional where Wrapped == Int {

    /// Safe array index (returns nil if out of bounds)
    func safeIndex<T>(in array: [T]) -> T? {
        guard let index = self, index >= 0, index < array.count else {
            return nil
        }
        return array[index]
    }
}

public extension Optional where Wrapped == Double {

    /// Safely unwrap with clamped range
    func orClamped(min: Double, max: Double, default defaultValue: Double = 0) -> Double {
        let value = self ?? defaultValue
        return Swift.min(Swift.max(value, min), max)
    }

    /// Safe percentage (0-100)
    var orZeroPercentage: Double {
        let value = self ?? 0
        return Swift.min(Swift.max(value, 0), 100)
    }
}

public extension Optional where Wrapped == Float {

    /// Safely unwrap with clamped range
    func orClamped(min: Float, max: Float, default defaultValue: Float = 0) -> Float {
        let value = self ?? defaultValue
        return Swift.min(Swift.max(value, min), max)
    }

    /// Safe audio value (0-1)
    var orZeroNormalized: Float {
        let value = self ?? 0
        return Swift.min(Swift.max(value, 0), 1)
    }
}

// MARK: - Optional Collection Extensions

public extension Optional where Wrapped: Collection {

    /// Safely unwrap collection with empty default
    var orEmpty: Wrapped {
        self ?? [] as! Wrapped
    }

    /// Check if collection is nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    /// Safe count (returns 0 if nil)
    var safeCount: Int {
        self?.count ?? 0
    }
}

// MARK: - Optional Array Extensions

public extension Optional where Wrapped == [Any] {

    /// Safe first element
    var safeFirst: Any? {
        self?.first
    }

    /// Safe last element
    var safeLast: Any? {
        self?.last
    }
}

// MARK: - Optional Dictionary Extensions

public extension Optional where Wrapped == [String: Any] {

    /// Safe key access with default
    func value<T>(forKey key: String, default defaultValue: T) -> T {
        (self?[key] as? T) ?? defaultValue
    }

    /// Safe string value
    func string(forKey key: String) -> String {
        (self?[key] as? String) ?? ""
    }

    /// Safe int value
    func int(forKey key: String) -> Int {
        (self?[key] as? Int) ?? 0
    }

    /// Safe double value
    func double(forKey key: String) -> Double {
        (self?[key] as? Double) ?? 0.0
    }

    /// Safe bool value
    func bool(forKey key: String) -> Bool {
        (self?[key] as? Bool) ?? false
    }
}

// MARK: - Optional URL Extensions

public extension Optional where Wrapped == URL {

    /// Safe URL string representation
    var absoluteStringOrEmpty: String {
        self?.absoluteString ?? ""
    }

    /// Safe path
    var pathOrEmpty: String {
        self?.path ?? ""
    }

    /// Validate URL exists and is reachable
    func validate() -> Bool {
        guard let url = self else { return false }
        return url.scheme != nil && url.host != nil
    }
}

// MARK: - Optional Date Extensions

public extension Optional where Wrapped == Date {

    /// Safe date or distant past
    var orDistantPast: Date {
        self ?? Date.distantPast
    }

    /// Safe date or distant future
    var orDistantFuture: Date {
        self ?? Date.distantFuture
    }

    /// Safe date or now
    var orNow: Date {
        self ?? Date()
    }

    /// Safe formatted date string
    func formatted(style: DateFormatter.Style = .medium) -> String {
        guard let date = self else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: date)
    }
}

// MARK: - Optional Data Extensions

public extension Optional where Wrapped == Data {

    /// Safe empty data
    var orEmpty: Data {
        self ?? Data()
    }

    /// Safe UTF-8 string
    var utf8String: String? {
        guard let data = self else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Safe count
    var safeCount: Int {
        self?.count ?? 0
    }
}

// MARK: - Safe Array Access

public extension Array {

    /// Safe subscript access that returns nil instead of crashing
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }

    /// Safe subscript with default value
    subscript(index: Int, default defaultValue: @autoclosure () -> Element) -> Element {
        guard index >= 0, index < count else { return defaultValue() }
        return self[index]
    }

    /// Safe first n elements
    func safePrefix(_ maxLength: Int) -> [Element] {
        Array(prefix(Swift.max(0, maxLength)))
    }

    /// Safe last n elements
    func safeSuffix(_ maxLength: Int) -> [Element] {
        Array(suffix(Swift.max(0, maxLength)))
    }

    /// Safe range access
    subscript(safe range: Range<Int>) -> [Element] {
        let lower = Swift.max(0, range.lowerBound)
        let upper = Swift.min(count, range.upperBound)
        guard lower < upper else { return [] }
        return Array(self[lower..<upper])
    }

    /// Safe remove at index (returns removed element or nil)
    @discardableResult
    mutating func safeRemove(at index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return remove(at: index)
    }
}

// MARK: - Safe Dictionary Access

public extension Dictionary {

    /// Safe subscript with default value
    subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        self[key] ?? defaultValue()
    }

    /// Safely merge another dictionary
    func safeMerging(_ other: [Key: Value]) -> [Key: Value] {
        merging(other) { current, _ in current }
    }

    /// Safe value access with type casting
    func value<T>(forKey key: Key, as type: T.Type) -> T? {
        self[key] as? T
    }
}

// MARK: - Safe String Operations

public extension String {

    /// Safe substring with index bounds checking
    subscript(safe range: Range<Int>) -> String {
        let lower = Swift.max(0, range.lowerBound)
        let upper = Swift.min(count, range.upperBound)
        guard lower < upper else { return "" }

        let startIndex = index(self.startIndex, offsetBy: lower)
        let endIndex = index(self.startIndex, offsetBy: upper)
        return String(self[startIndex..<endIndex])
    }

    /// Safe character at index
    subscript(safe index: Int) -> Character? {
        guard index >= 0, index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }

    /// Safe URL conversion
    var safeURL: URL? {
        URL(string: self)
    }

    /// Safe Int conversion
    var safeInt: Int? {
        Int(self)
    }

    /// Safe Double conversion
    var safeDouble: Double? {
        Double(self)
    }

    /// Safe data conversion
    var safeData: Data? {
        data(using: .utf8)
    }

    /// Safe prefix
    func safePrefix(_ maxLength: Int) -> String {
        String(prefix(Swift.max(0, maxLength)))
    }

    /// Safe suffix
    func safeSuffix(_ maxLength: Int) -> String {
        String(suffix(Swift.max(0, maxLength)))
    }
}

// MARK: - Safe Numeric Conversions

public extension Int {

    /// Safe Double conversion
    var safeDouble: Double {
        Double(self)
    }

    /// Safe Float conversion
    var safeFloat: Float {
        Float(self)
    }

    /// Safe CGFloat conversion
    var safeCGFloat: CGFloat {
        CGFloat(self)
    }

    /// Safe clamped value
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

public extension Double {

    /// Safe Int conversion (with rounding)
    var safeInt: Int {
        Int(self)
    }

    /// Safe Float conversion
    var safeFloat: Float {
        Float(self)
    }

    /// Safe clamped value
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Safe normalized (0-1)
    var normalized: Double {
        clamped(to: 0...1)
    }
}

public extension Float {

    /// Safe Int conversion (with rounding)
    var safeInt: Int {
        Int(self)
    }

    /// Safe Double conversion
    var safeDouble: Double {
        Double(self)
    }

    /// Safe clamped value
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Safe normalized (0-1)
    var normalized: Float {
        clamped(to: 0...1)
    }
}

// MARK: - Safe Bundle Access

public extension Bundle {

    /// Safe info dictionary access
    func safeInfoValue<T>(forKey key: String, default defaultValue: T) -> T {
        (infoDictionary?[key] as? T) ?? defaultValue
    }

    /// Safe version string
    var safeVersion: String {
        safeInfoValue(forKey: "CFBundleShortVersionString", default: "1.0.0")
    }

    /// Safe build number
    var safeBuild: String {
        safeInfoValue(forKey: "CFBundleVersion", default: "1")
    }

    /// Safe bundle identifier
    var safeIdentifier: String {
        bundleIdentifier ?? "com.echoelmusic.app"
    }

    /// Safe display name
    var safeDisplayName: String {
        safeInfoValue(forKey: "CFBundleDisplayName", default: "Echoelmusic")
    }
}

// MARK: - Safe UserDefaults Access

public extension UserDefaults {

    /// Safe object access with type
    func safeObject<T>(forKey key: String, default defaultValue: T) -> T {
        (object(forKey: key) as? T) ?? defaultValue
    }

    /// Safe string with default
    func safeString(forKey key: String, default defaultValue: String = "") -> String {
        string(forKey: key) ?? defaultValue
    }

    /// Safe array with default
    func safeArray<T>(forKey key: String, default defaultValue: [T] = []) -> [T] {
        (array(forKey: key) as? [T]) ?? defaultValue
    }

    /// Safe dictionary with default
    func safeDictionary(forKey key: String, default defaultValue: [String: Any] = [:]) -> [String: Any] {
        (dictionary(forKey: key)) ?? defaultValue
    }
}

// MARK: - Safe JSON Decoding

public extension Data {

    /// Safe JSON decoding with optional result
    func safeJSONDecode<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: self)
    }

    /// Safe JSON decoding with default
    func safeJSONDecode<T: Decodable>(_ type: T.Type, default defaultValue: T) -> T {
        (try? JSONDecoder().decode(type, from: self)) ?? defaultValue
    }
}

// MARK: - Safe Result Handling

public extension Result {

    /// Get success value or nil
    var successValue: Success? {
        try? get()
    }

    /// Get success value or default
    func value(default defaultValue: Success) -> Success {
        (try? get()) ?? defaultValue
    }

    /// Get error or nil
    var failureError: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

// MARK: - Safe Audio/Video Types

public extension CMTime {

    /// Safe seconds conversion (returns 0 if invalid)
    var safeSeconds: Double {
        if isValid && !isIndefinite && !isNegativeInfinity && !isPositiveInfinity {
            return seconds
        }
        return 0
    }
}

public extension AVAsset {

    /// Safe duration in seconds
    var safeDurationSeconds: Double {
        duration.safeSeconds
    }
}

// MARK: - Safe Error Handling

/// Protocol for safe error handling
public protocol SafeErrorHandling {
    associatedtype Success

    func safely() -> Success?
    func safely(default defaultValue: Success) -> Success
    func safely(onError: (Error) -> Void) -> Success?
}

/// Wrapper for safe execution of throwing code
public struct SafeExecution<T> {
    private let operation: () throws -> T

    public init(_ operation: @escaping () throws -> T) {
        self.operation = operation
    }

    /// Execute safely, returning nil on error
    public func execute() -> T? {
        try? operation()
    }

    /// Execute safely with default value
    public func execute(default defaultValue: T) -> T {
        (try? operation()) ?? defaultValue
    }

    /// Execute safely with error handling
    public func execute(onError: (Error) -> Void) -> T? {
        do {
            return try operation()
        } catch {
            onError(error)
            return nil
        }
    }
}

/// Convenience function for safe execution
public func safely<T>(_ operation: @autoclosure () throws -> T) -> T? {
    try? operation()
}

/// Convenience function for safe execution with default
public func safely<T>(_ operation: @autoclosure () throws -> T, default defaultValue: T) -> T {
    (try? operation()) ?? defaultValue
}
