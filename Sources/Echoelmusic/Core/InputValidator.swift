// InputValidator.swift
// Echoelmusic - Input Validation & Security
// Wise Mode Implementation

import Foundation
import simd

// MARK: - Input Validator

/// Centralized input validation for security and data integrity
public struct InputValidator {

    // MARK: - MIDI Validation

    /// Validate MIDI note value (0-127)
    public static func validateMIDINote(_ note: UInt8) -> UInt8 {
        min(127, note)
    }

    /// Validate MIDI velocity value (0-127)
    public static func validateMIDIVelocity(_ velocity: UInt8) -> UInt8 {
        min(127, velocity)
    }

    /// Validate MIDI channel (0-15 for internal, 1-16 for display)
    public static func validateMIDIChannel(_ channel: UInt8) -> UInt8 {
        min(15, channel)
    }

    /// Validate MIDI control change value (0-127)
    public static func validateMIDICC(_ value: UInt8) -> UInt8 {
        min(127, value)
    }

    /// Validate MIDI pitch bend (0-16383, center at 8192)
    public static func validateMIDIPitchBend(_ value: UInt16) -> UInt16 {
        min(16383, value)
    }

    // MARK: - Audio Validation

    /// Validate audio level (0.0-1.0)
    public static func validateAudioLevel(_ level: Float) -> Float {
        simd_clamp(level, 0.0, 1.0)
    }

    /// Validate audio level in decibels (-80 to +12 dB)
    public static func validateDecibels(_ db: Float) -> Float {
        simd_clamp(db, -80.0, 12.0)
    }

    /// Validate frequency in Hz (20-20000 Hz audible range)
    public static func validateFrequency(_ hz: Float, min: Float = 20.0, max: Float = 20000.0) -> Float {
        simd_clamp(hz, min, max)
    }

    /// Validate sample rate
    public static func validateSampleRate(_ rate: Double) -> Double {
        let validRates: [Double] = [22050, 44100, 48000, 88200, 96000, 176400, 192000]
        return validRates.min(by: { abs($0 - rate) < abs($1 - rate) }) ?? 48000
    }

    /// Validate buffer size (power of 2, 64-8192)
    public static func validateBufferSize(_ size: Int) -> Int {
        let validSizes = [64, 128, 256, 512, 1024, 2048, 4096, 8192]
        return validSizes.min(by: { abs($0 - size) < abs($1 - size) }) ?? 512
    }

    // MARK: - Spatial Validation

    /// Validate 3D position vector
    public static func validatePosition(_ position: SIMD3<Float>, maxDistance: Float = 100.0) -> SIMD3<Float> {
        let length = simd_length(position)
        if length > maxDistance {
            return simd_normalize(position) * maxDistance
        }
        return position
    }

    /// Validate azimuth angle (-180 to 180 degrees)
    public static func validateAzimuth(_ degrees: Float) -> Float {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized > 180 { normalized -= 360 }
        if normalized < -180 { normalized += 360 }
        return normalized
    }

    /// Validate elevation angle (-90 to 90 degrees)
    public static func validateElevation(_ degrees: Float) -> Float {
        simd_clamp(degrees, -90.0, 90.0)
    }

    // MARK: - Time Validation

    /// Validate BPM (20-300)
    public static func validateBPM(_ bpm: Double) -> Double {
        simd_clamp(bpm, 20.0, 300.0)
    }

    /// Validate time in seconds (non-negative)
    public static func validateTime(_ seconds: Double) -> Double {
        max(0, seconds)
    }

    /// Validate duration (positive)
    public static func validateDuration(_ seconds: Double, maxDuration: Double = 3600) -> Double {
        simd_clamp(seconds, 0.001, maxDuration)
    }

    // MARK: - String Validation

    /// Sanitize user input string
    public static func sanitizeUserInput(_ input: String, maxLength: Int = 1000) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .prefix(maxLength)
            .description
    }

    /// Validate filename (alphanumeric, dashes, underscores)
    public static func validateFilename(_ filename: String) -> String? {
        let sanitized = filename
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
            .prefix(255)
            .description

        guard !sanitized.isEmpty,
              !sanitized.hasPrefix("."),
              sanitized != "." && sanitized != ".." else {
            return nil
        }

        return sanitized
    }

    /// Validate session/track name
    public static func validateName(_ name: String, maxLength: Int = 100) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(maxLength)
            .description
    }

    // MARK: - URL Validation

    /// Validate URL string
    public static func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    /// Validate local file URL
    public static func validateFileURL(_ url: URL) -> URL? {
        guard url.isFileURL,
              !url.path.contains("..") else {
            return nil
        }
        return url
    }

    // MARK: - Color Validation

    /// Validate RGB color component (0.0-1.0)
    public static func validateColorComponent(_ value: Float) -> Float {
        simd_clamp(value, 0.0, 1.0)
    }

    /// Validate RGB color
    public static func validateRGB(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        (
            validateColorComponent(r),
            validateColorComponent(g),
            validateColorComponent(b)
        )
    }

    /// Validate RGBA color
    public static func validateRGBA(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> (Float, Float, Float, Float) {
        (
            validateColorComponent(r),
            validateColorComponent(g),
            validateColorComponent(b),
            validateColorComponent(a)
        )
    }

    /// Validate DMX value (0-255)
    public static func validateDMX(_ value: UInt8) -> UInt8 {
        value // Already constrained by UInt8
    }

    // MARK: - Network Validation

    /// Validate IP address
    public static func validateIPAddress(_ ip: String) -> String? {
        let ipv4Pattern = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        let ipv6Pattern = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"

        if ip.range(of: ipv4Pattern, options: .regularExpression) != nil ||
           ip.range(of: ipv6Pattern, options: .regularExpression) != nil {
            return ip
        }
        return nil
    }

    /// Validate port number
    public static func validatePort(_ port: Int) -> UInt16? {
        guard port > 0 && port <= 65535 else { return nil }
        return UInt16(port)
    }

    // MARK: - Array Validation

    /// Validate array index
    public static func validateIndex<T>(_ index: Int, in array: [T]) -> Int? {
        guard index >= 0 && index < array.count else { return nil }
        return index
    }

    /// Validate array bounds
    public static func validateBounds<T>(_ range: Range<Int>, in array: [T]) -> Range<Int> {
        let lower = max(0, range.lowerBound)
        let upper = min(array.count, range.upperBound)
        return lower..<max(lower, upper)
    }
}

// MARK: - Secure Storage

import Security

/// Secure storage using Keychain
public final class SecureStorage {

    public enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case encodingFailed
        case decodingFailed

        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed with status \(status)"
            case .loadFailed(let status):
                return "Keychain load failed with status \(status)"
            case .deleteFailed(let status):
                return "Keychain delete failed with status \(status)"
            case .encodingFailed:
                return "Failed to encode data for keychain"
            case .decodingFailed:
                return "Failed to decode data from keychain"
            }
        }
    }

    private static let service = "com.echoelmusic"

    /// Save data to keychain
    public static func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Load data from keychain
    public static func load(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }

        return result as? Data
    }

    /// Delete data from keychain
    public static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Save Codable object to keychain
    public static func save<T: Codable>(_ object: T, forKey key: String) throws {
        guard let data = try? JSONEncoder().encode(object) else {
            throw KeychainError.encodingFailed
        }
        try save(data, forKey: key)
    }

    /// Load Codable object from keychain
    public static func load<T: Codable>(forKey key: String) throws -> T? {
        guard let data = try load(forKey: key) else {
            return nil
        }
        guard let object = try? JSONDecoder().decode(T.self, from: data) else {
            throw KeychainError.decodingFailed
        }
        return object
    }
}

// MARK: - Rate Limiter

/// Rate limiter for API calls and resource-intensive operations
public actor RateLimiter {
    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var requests: [Date] = []

    public init(maxRequests: Int, windowSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    /// Check if request is allowed
    public func isAllowed() -> Bool {
        cleanOldRequests()
        return requests.count < maxRequests
    }

    /// Record a request (call after isAllowed returns true)
    public func recordRequest() {
        cleanOldRequests()
        requests.append(Date())
    }

    /// Get time until next allowed request
    public func timeUntilAllowed() -> TimeInterval {
        cleanOldRequests()
        guard requests.count >= maxRequests,
              let oldest = requests.first else {
            return 0
        }
        return windowSeconds - Date().timeIntervalSince(oldest)
    }

    private func cleanOldRequests() {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        requests.removeAll { $0 < cutoff }
    }
}
