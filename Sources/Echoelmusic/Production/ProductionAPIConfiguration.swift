//
//  ProductionAPIConfiguration.swift
//  Echoelmusic
//
//  Created by Claude on 2026-01-07.
//  Copyright © 2026 Echoelmusic. All rights reserved.
//
//  CRITICAL: NO HARDCODED API KEYS
//  All keys must be stored in Keychain or environment variables
//

import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Safe URL Construction

/// Safe URL construction that avoids force unwrapping
/// All API URLs are validated at compile time but we still use safe construction
/// to prevent potential crashes from environment variable interpolation
private enum SafeURLFactory {
    /// Known fallback URL for emergency use (always valid)
    static let fallback = URL(string: "https://api.echoelmusic.com") ?? URL(fileURLWithPath: "/")

    /// Safely construct a URL with fallback
    /// - Parameter string: URL string
    /// - Returns: Valid URL or fallback
    static func make(_ string: String) -> URL {
        URL(string: string) ?? fallback
    }

    /// Safely construct a URL, throwing if invalid
    /// - Parameter string: URL string
    /// - Returns: Valid URL
    /// - Throws: URLError if string is invalid
    static func require(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw URLError(.badURL, userInfo: [NSURLErrorFailingURLStringErrorKey: string])
        }
        return url
    }
}

// MARK: - API Configuration Protocol

/// Protocol for all API configurations
public protocol APIConfiguration {
    /// Base URL for the API
    var baseURL: URL { get }

    /// API key identifier (NOT the actual key)
    var apiKeyIdentifier: String { get }

    /// HTTP headers
    var headers: [String: String] { get }

    /// Request timeout in seconds
    var timeout: TimeInterval { get }

    /// Retry policy
    var retryPolicy: APIRetryPolicy { get }

    /// Rate limit configuration
    var rateLimit: RateLimitConfiguration { get }

    /// Environment this configuration applies to
    var environment: APIEnvironment { get }
}

// MARK: - API Environment

/// Deployment environment
public enum APIEnvironment: String, Codable {
    case development = "dev"
    case staging = "staging"
    case production = "prod"
    case enterprise = "enterprise"

    /// Current environment (can be set via environment variable)
    public static var current: APIEnvironment {
        if let envString = ProcessInfo.processInfo.environment["ECHOELMUSIC_ENV"],
           let env = APIEnvironment(rawValue: envString) {
            return env
        }
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - API Retry Policy

/// Retry policy for failed API requests (renamed to avoid conflict with CircuitBreaker.RetryPolicy)
public struct APIRetryPolicy: Codable {
    public let maxRetries: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let retryableStatusCodes: [Int]

    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        retryableStatusCodes: [Int] = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.retryableStatusCodes = retryableStatusCodes
    }

    public static let `default` = APIRetryPolicy()
    public static let aggressive = APIRetryPolicy(maxRetries: 5, initialDelay: 0.5)
    public static let conservative = APIRetryPolicy(maxRetries: 2, initialDelay: 2.0)
}

// MARK: - Rate Limit Configuration

/// Rate limit configuration
public struct RateLimitConfiguration: Codable {
    public let requestsPerSecond: Int
    public let requestsPerMinute: Int
    public let requestsPerHour: Int
    public let burstSize: Int

    public init(
        requestsPerSecond: Int = 10,
        requestsPerMinute: Int = 600,
        requestsPerHour: Int = 10000,
        burstSize: Int = 20
    ) {
        self.requestsPerSecond = requestsPerSecond
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.burstSize = burstSize
    }

    public static let `default` = RateLimitConfiguration()
    public static let streaming = RateLimitConfiguration(
        requestsPerSecond: 5,
        requestsPerMinute: 300,
        requestsPerHour: 5000,
        burstSize: 10
    )
    public static let analytics = RateLimitConfiguration(
        requestsPerSecond: 50,
        requestsPerMinute: 3000,
        requestsPerHour: 50000,
        burstSize: 100
    )
}

// MARK: - Streaming API Configurations

/// YouTube Live API Configuration
public struct YouTubeAPIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://www.googleapis.com/youtube/v3")
    }

    public var apiKeyIdentifier: String {
        "youtube_api_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration.streaming

    /// OAuth 2.0 scopes
    public let scopes = [
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/youtube.force-ssl"
    ]

    /// Maximum bitrate (bps)
    public let maxBitrate = 51_000_000 // 51 Mbps for 4K

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Twitch API Configuration
public struct TwitchAPIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://api.twitch.tv/helix")
    }

    public var apiKeyIdentifier: String {
        "twitch_client_id_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 20,
        requestsPerMinute: 800,
        requestsPerHour: 10000,
        burstSize: 30
    )

    /// Twitch ingest endpoints
    public let ingestEndpoints = [
        "rtmp://live.twitch.tv/app",
        "rtmp://live-fra.twitch.tv/app", // Frankfurt
        "rtmp://live-lax.twitch.tv/app", // Los Angeles
        "rtmp://live-sin.twitch.tv/app"  // Singapore
    ]

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Facebook Live API Configuration
public struct FacebookAPIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://graph.facebook.com/v18.0")
    }

    public var apiKeyIdentifier: String {
        "facebook_app_id_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration.streaming

    /// Permissions
    public let permissions = [
        "publish_video",
        "pages_manage_posts",
        "pages_read_engagement"
    ]

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Instagram Live API Configuration
public struct InstagramAPIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://graph.instagram.com")
    }

    public var apiKeyIdentifier: String {
        "instagram_app_id_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration.streaming

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// TikTok Live API Configuration
public struct TikTokAPIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://open-api.tiktok.com")
    }

    public var apiKeyIdentifier: String {
        "tiktok_client_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration.streaming

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Custom RTMP Endpoint Configuration
public struct CustomRTMPConfiguration: Codable {
    public let name: String
    public let rtmpURL: String
    public let streamKey: String // Encrypted in Keychain
    public let maxBitrate: Int

    public init(name: String, rtmpURL: String, streamKey: String, maxBitrate: Int = 10_000_000) {
        self.name = name
        self.rtmpURL = rtmpURL
        self.streamKey = streamKey
        self.maxBitrate = maxBitrate
    }
}

// MARK: - Cloud Storage API Configurations

/// iCloud CloudKit Configuration
public struct CloudKitConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://api.apple-cloudkit.com")
    }

    public var apiKeyIdentifier: String {
        "cloudkit_api_token_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 60.0
    public let retryPolicy = APIRetryPolicy.conservative
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 40,
        requestsPerMinute: 2400,
        requestsPerHour: 40000,
        burstSize: 100
    )

    /// Container identifier
    public let containerIdentifier = "iCloud.com.echoelmusic.app"

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// AWS S3 Configuration
public struct AWSS3Configuration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        switch environment {
        case .development:
            return SafeURLFactory.make("https://s3.us-west-2.amazonaws.com")
        case .staging:
            return SafeURLFactory.make("https://s3.us-east-1.amazonaws.com")
        case .production, .enterprise:
            return SafeURLFactory.make("https://s3.us-east-1.amazonaws.com")
        }
    }

    public var apiKeyIdentifier: String {
        "aws_access_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 120.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 100,
        requestsPerMinute: 6000,
        requestsPerHour: 100000,
        burstSize: 200
    )

    /// Bucket name
    public var bucketName: String {
        "echoelmusic-\(environment.rawValue)"
    }

    /// Region
    public let region = "us-east-1"

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Google Cloud Storage Configuration
public struct GoogleCloudStorageConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://storage.googleapis.com")
    }

    public var apiKeyIdentifier: String {
        "gcs_service_account_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 120.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 100,
        requestsPerMinute: 6000,
        requestsPerHour: 100000,
        burstSize: 200
    )

    /// Bucket name
    public var bucketName: String {
        "echoelmusic-\(environment.rawValue)"
    }

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Azure Blob Storage Configuration
public struct AzureBlobConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://echoelmusic\(environment.rawValue).blob.core.windows.net")
    }

    public var apiKeyIdentifier: String {
        "azure_storage_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "x-ms-version": "2021-08-06",
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 120.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 100,
        requestsPerMinute: 6000,
        requestsPerHour: 100000,
        burstSize: 200
    )

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

// MARK: - Analytics API Configurations

/// Firebase Analytics Configuration
public struct FirebaseAnalyticsConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://firebaselogging.googleapis.com/v0cc/log/batch")
    }

    public var apiKeyIdentifier: String {
        "firebase_api_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 10.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration.analytics

    /// Google App ID
    public var googleAppID: String {
        switch environment {
        case .development:
            return "1:123456789:ios:dev"
        case .staging:
            return "1:123456789:ios:staging"
        case .production:
            return "1:123456789:ios:prod"
        case .enterprise:
            return "1:123456789:ios:enterprise"
        }
    }

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Mixpanel Configuration
public struct MixpanelConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://api.mixpanel.com")
    }

    public var apiKeyIdentifier: String {
        "mixpanel_token_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "text/plain"
        ]
    }

    public let timeout: TimeInterval = 10.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration.analytics

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Amplitude Configuration
public struct AmplitudeConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://api2.amplitude.com")
    }

    public var apiKeyIdentifier: String {
        "amplitude_api_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 10.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration.analytics

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

// MARK: - Crash Reporting API Configurations

/// Firebase Crashlytics Configuration
public struct CrashlyticsConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://firebasecrashlyticsreports.googleapis.com")
    }

    public var apiKeyIdentifier: String {
        "firebase_api_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 10,
        requestsPerMinute: 600,
        requestsPerHour: 10000,
        burstSize: 50
    )

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Sentry Configuration
public struct SentryConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://sentry.io/api/0")
    }

    public var apiKeyIdentifier: String {
        "sentry_dsn_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json"
        ]
    }

    public let timeout: TimeInterval = 30.0
    public let retryPolicy = APIRetryPolicy.aggressive
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 10,
        requestsPerMinute: 600,
        requestsPerHour: 10000,
        burstSize: 50
    )

    /// Sentry project slug
    public var projectSlug: String {
        "echoelmusic-\(environment.rawValue)"
    }

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

// MARK: - AI Service API Configurations

/// Apple ML Server Configuration
public struct AppleMLConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        SafeURLFactory.make("https://api.apple-ml.com")
    }

    public var apiKeyIdentifier: String {
        "apple_ml_token_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 60.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 5,
        requestsPerMinute: 300,
        requestsPerHour: 5000,
        burstSize: 10
    )

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

/// Custom AI Model Endpoint Configuration
public struct CustomAIConfiguration: APIConfiguration {
    public let environment: APIEnvironment

    public var baseURL: URL {
        switch environment {
        case .development:
            return SafeURLFactory.make("http://localhost:8080")
        case .staging:
            return SafeURLFactory.make("https://ai-staging.echoelmusic.com")
        case .production, .enterprise:
            return SafeURLFactory.make("https://ai.echoelmusic.com")
        }
    }

    public var apiKeyIdentifier: String {
        "custom_ai_key_\(environment.rawValue)"
    }

    public var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    public let timeout: TimeInterval = 60.0
    public let retryPolicy = APIRetryPolicy.default
    public let rateLimit = RateLimitConfiguration(
        requestsPerSecond: 5,
        requestsPerMinute: 300,
        requestsPerHour: 5000,
        burstSize: 10
    )

    public init(environment: APIEnvironment = .current) {
        self.environment = environment
    }
}

// MARK: - Hardware API Configurations

/// DMX/Art-Net Configuration
public struct DMXConfiguration {
    public let artNetIP: String
    public let artNetPort: UInt16
    public let universes: [Int]
    public let refreshRate: Int // Hz

    public init(
        artNetIP: String = "192.168.1.100",
        artNetPort: UInt16 = 6454,
        universes: [Int] = [0, 1, 2, 3],
        refreshRate: Int = 44
    ) {
        self.artNetIP = artNetIP
        self.artNetPort = artNetPort
        self.universes = universes
        self.refreshRate = refreshRate
    }

    public static let `default` = DMXConfiguration()
}

/// OSC Configuration
public struct OSCConfiguration {
    public let host: String
    public let port: UInt16
    public let addressSpace: [String]

    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 8000,
        addressSpace: [String] = ["/echoelmusic", "/bio", "/quantum"]
    ) {
        self.host = host
        self.port = port
        self.addressSpace = addressSpace
    }

    public static let `default` = OSCConfiguration()
}

/// MIDI Network Configuration
public struct MIDINetworkConfiguration {
    public let sessionName: String
    public let bonjourName: String
    public let port: UInt16

    public init(
        sessionName: String = "Echoelmusic MIDI",
        bonjourName: String = "_apple-midi._udp",
        port: UInt16 = 5004
    ) {
        self.sessionName = sessionName
        self.bonjourName = bonjourName
        self.port = port
    }

    public static let `default` = MIDINetworkConfiguration()
}

/// Ableton Link Configuration
public struct AbletonLinkConfiguration {
    public let enableAtStartup: Bool
    public let quantum: Double

    public init(
        enableAtStartup: Bool = true,
        quantum: Double = 4.0
    ) {
        self.enableAtStartup = enableAtStartup
        self.quantum = quantum
    }

    public static let `default` = AbletonLinkConfiguration()
}

// MARK: - Secure API Key Manager

/// Secure API Key Manager using Keychain
@MainActor
public final class SecureAPIKeyManager {
    public static let shared = SecureAPIKeyManager()

    private let serviceName = "com.echoelmusic.api"

    private init() {}

    // MARK: - Keychain Operations

    /// Store API key securely in Keychain
    public func storeAPIKey(_ key: String, identifier: String) throws {
        #if canImport(Security)
        guard let data = key.data(using: .utf8) else {
            throw APIKeyError.keychainStoreFailed(status: errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw APIKeyError.keychainStoreFailed(status: status)
        }
        #else
        // Fallback for non-Apple platforms - throw error for security
        log.warning("Keychain not available on this platform, API key storage not supported")
        throw APIKeyError.keychainNotAvailable
        #endif
    }

    /// Retrieve API key from Keychain
    public func retrieveAPIKey(identifier: String) throws -> String {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw APIKeyError.keychainRetrieveFailed(status: status)
        }

        return key
        #else
        // Fallback for non-Apple platforms
        throw APIKeyError.keychainNotAvailable
        #endif
    }

    /// Delete API key from Keychain
    public func deleteAPIKey(identifier: String) throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyError.keychainDeleteFailed(status: status)
        }
        #else
        log.warning("Keychain not available on this platform, cannot delete API key")
        throw APIKeyError.keychainNotAvailable
        #endif
    }

    /// Clear all API keys
    public func clearAllKeys() throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyError.keychainDeleteFailed(status: status)
        }
        #else
        log.warning("Keychain not available on this platform, cannot clear API keys")
        throw APIKeyError.keychainNotAvailable
        #endif
    }

    // MARK: - Environment Variable Support

    /// Load API key from environment variable or Keychain
    public func loadAPIKey(identifier: String, envVar: String? = nil) -> String? {
        // Try environment variable first
        if let envVar = envVar,
           let key = ProcessInfo.processInfo.environment[envVar],
           !key.isEmpty {
            return key
        }

        // Fallback to Keychain
        return try? retrieveAPIKey(identifier: identifier)
    }

    // MARK: - Obfuscation (for compiled keys in binaries)

    /// Obfuscate a string (simple XOR, NOT cryptographically secure)
    /// Use only for build-time obfuscation, NOT for sensitive keys
    public func obfuscate(_ string: String, salt: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        let bytes = Array(string.utf8)

        for (index, byte) in bytes.enumerated() {
            let saltByte = salt[index % salt.count]
            result.append(byte ^ saltByte)
        }

        return result
    }

    /// Deobfuscate a byte array (simple XOR)
    public func deobfuscate(_ bytes: [UInt8], salt: [UInt8]) -> String? {
        var result: [UInt8] = []

        for (index, byte) in bytes.enumerated() {
            let saltByte = salt[index % salt.count]
            result.append(byte ^ saltByte)
        }

        return String(bytes: result, encoding: .utf8)
    }
}

// MARK: - API Key Errors

public enum APIKeyError: Error, LocalizedError {
    case keychainStoreFailed(status: OSStatus)
    case keychainRetrieveFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case keychainNotAvailable
    case invalidKey

    public var errorDescription: String? {
        switch self {
        case .keychainStoreFailed(let status):
            return "Failed to store API key in Keychain (status: \(status))"
        case .keychainRetrieveFailed(let status):
            return "Failed to retrieve API key from Keychain (status: \(status))"
        case .keychainDeleteFailed(let status):
            return "Failed to delete API key from Keychain (status: \(status))"
        case .keychainNotAvailable:
            return "Keychain not available on this platform"
        case .invalidKey:
            return "Invalid API key format"
        }
    }
}

// MARK: - API Health Checker

/// API Health Checker to validate all configurations
@MainActor
public final class APIHealthChecker {
    public static let shared = APIHealthChecker()

    private init() {}

    /// Health check result
    public struct HealthCheckResult {
        public let apiName: String
        public let isHealthy: Bool
        public let latencyMs: Double?
        public let error: Error?
        public let timestamp: Date

        public init(apiName: String, isHealthy: Bool, latencyMs: Double? = nil, error: Error? = nil) {
            self.apiName = apiName
            self.isHealthy = isHealthy
            self.latencyMs = latencyMs
            self.error = error
            self.timestamp = Date()
        }
    }

    /// Check health of an API endpoint
    public func checkHealth(configuration: APIConfiguration) async -> HealthCheckResult {
        let startTime = Date()

        do {
            // Create health check request
            var request = URLRequest(url: configuration.baseURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 10.0

            // Add headers
            for (key, value) in configuration.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            // Perform request
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return HealthCheckResult(
                    apiName: String(describing: type(of: configuration)),
                    isHealthy: false,
                    error: NSError(domain: "InvalidResponse", code: -1)
                )
            }

            let latency = Date().timeIntervalSince(startTime) * 1000
            let isHealthy = (200...299).contains(httpResponse.statusCode)

            return HealthCheckResult(
                apiName: String(describing: type(of: configuration)),
                isHealthy: isHealthy,
                latencyMs: latency,
                error: isHealthy ? nil : NSError(domain: "HTTPError", code: httpResponse.statusCode)
            )

        } catch {
            return HealthCheckResult(
                apiName: String(describing: type(of: configuration)),
                isHealthy: false,
                error: error
            )
        }
    }

    /// Check all APIs
    public func checkAllAPIs() async -> [HealthCheckResult] {
        let configs: [APIConfiguration] = [
            YouTubeAPIConfiguration(),
            TwitchAPIConfiguration(),
            FacebookAPIConfiguration(),
            InstagramAPIConfiguration(),
            TikTokAPIConfiguration(),
            CloudKitConfiguration(),
            AWSS3Configuration(),
            GoogleCloudStorageConfiguration(),
            AzureBlobConfiguration(),
            FirebaseAnalyticsConfiguration(),
            MixpanelConfiguration(),
            AmplitudeConfiguration(),
            CrashlyticsConfiguration(),
            SentryConfiguration(),
            AppleMLConfiguration(),
            CustomAIConfiguration()
        ]

        var results: [HealthCheckResult] = []

        for config in configs {
            let result = await checkHealth(configuration: config)
            results.append(result)
        }

        return results
    }

    /// Generate health report
    public func generateHealthReport() async -> String {
        let results = await checkAllAPIs()

        var report = """
        ========================================
        Echoelmusic API Health Report
        ========================================
        Generated: \(Date().ISO8601Format())
        Environment: \(APIEnvironment.current.rawValue)

        """

        for result in results {
            let status = result.isHealthy ? "✅ HEALTHY" : "❌ UNHEALTHY"
            let latency = result.latencyMs.map { String(format: "%.2f ms", $0) } ?? "N/A"
            let error = result.error?.localizedDescription ?? "None"

            report += """

            \(result.apiName):
              Status: \(status)
              Latency: \(latency)
              Error: \(error)

            """
        }

        report += """
        ========================================
        """

        return report
    }
}

// MARK: - Production API Manager

/// Central API Manager for production
@MainActor
public final class ProductionAPIManager {
    public static let shared = ProductionAPIManager()

    private let keyManager = SecureAPIKeyManager.shared
    private let healthChecker = APIHealthChecker.shared

    // API Configurations
    public let youtube: YouTubeAPIConfiguration
    public let twitch: TwitchAPIConfiguration
    public let facebook: FacebookAPIConfiguration
    public let instagram: InstagramAPIConfiguration
    public let tiktok: TikTokAPIConfiguration
    public let cloudKit: CloudKitConfiguration
    public let s3: AWSS3Configuration
    public let gcs: GoogleCloudStorageConfiguration
    public let azure: AzureBlobConfiguration
    public let firebaseAnalytics: FirebaseAnalyticsConfiguration
    public let mixpanel: MixpanelConfiguration
    public let amplitude: AmplitudeConfiguration
    public let crashlytics: CrashlyticsConfiguration
    public let sentry: SentryConfiguration
    public let appleML: AppleMLConfiguration
    public let customAI: CustomAIConfiguration

    // Hardware Configurations
    public let dmx: DMXConfiguration
    public let osc: OSCConfiguration
    public let midiNetwork: MIDINetworkConfiguration
    public let abletonLink: AbletonLinkConfiguration

    private init() {
        let env = APIEnvironment.current

        self.youtube = YouTubeAPIConfiguration(environment: env)
        self.twitch = TwitchAPIConfiguration(environment: env)
        self.facebook = FacebookAPIConfiguration(environment: env)
        self.instagram = InstagramAPIConfiguration(environment: env)
        self.tiktok = TikTokAPIConfiguration(environment: env)
        self.cloudKit = CloudKitConfiguration(environment: env)
        self.s3 = AWSS3Configuration(environment: env)
        self.gcs = GoogleCloudStorageConfiguration(environment: env)
        self.azure = AzureBlobConfiguration(environment: env)
        self.firebaseAnalytics = FirebaseAnalyticsConfiguration(environment: env)
        self.mixpanel = MixpanelConfiguration(environment: env)
        self.amplitude = AmplitudeConfiguration(environment: env)
        self.crashlytics = CrashlyticsConfiguration(environment: env)
        self.sentry = SentryConfiguration(environment: env)
        self.appleML = AppleMLConfiguration(environment: env)
        self.customAI = CustomAIConfiguration(environment: env)

        self.dmx = DMXConfiguration.default
        self.osc = OSCConfiguration.default
        self.midiNetwork = MIDINetworkConfiguration.default
        self.abletonLink = AbletonLinkConfiguration.default
    }

    // MARK: - API Key Management

    /// Initialize API keys from environment or Keychain
    public func initializeAPIKeys() async throws {
        // Load keys from environment variables if available
        // Otherwise, they should already be in Keychain

        // Example: YouTube
        if let youtubeKey = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] {
            try keyManager.storeAPIKey(youtubeKey, identifier: youtube.apiKeyIdentifier)
        }

        // Example: Twitch
        if let twitchClientID = ProcessInfo.processInfo.environment["TWITCH_CLIENT_ID"] {
            try keyManager.storeAPIKey(twitchClientID, identifier: twitch.apiKeyIdentifier)
        }

        // Add more as needed...
    }

    /// Validate all API keys are present
    public func validateAPIKeys() -> [String] {
        var missingKeys: [String] = []

        let identifiers = [
            youtube.apiKeyIdentifier,
            twitch.apiKeyIdentifier,
            facebook.apiKeyIdentifier,
            instagram.apiKeyIdentifier,
            tiktok.apiKeyIdentifier,
            cloudKit.apiKeyIdentifier,
            s3.apiKeyIdentifier,
            gcs.apiKeyIdentifier,
            azure.apiKeyIdentifier,
            firebaseAnalytics.apiKeyIdentifier,
            mixpanel.apiKeyIdentifier,
            amplitude.apiKeyIdentifier,
            crashlytics.apiKeyIdentifier,
            sentry.apiKeyIdentifier,
            appleML.apiKeyIdentifier,
            customAI.apiKeyIdentifier
        ]

        for identifier in identifiers {
            if keyManager.loadAPIKey(identifier: identifier) == nil {
                missingKeys.append(identifier)
            }
        }

        return missingKeys
    }

    // MARK: - Health Checks

    /// Perform health check on all APIs
    public func performHealthCheck() async -> [APIHealthChecker.HealthCheckResult] {
        await healthChecker.checkAllAPIs()
    }

    /// Generate health report
    public func generateHealthReport() async -> String {
        await healthChecker.generateHealthReport()
    }
}

// MARK: - Usage Example Documentation

/*
 USAGE EXAMPLE:

 // 1. Store API keys (once, typically during app setup)
 let keyManager = SecureAPIKeyManager.shared
 try await keyManager.storeAPIKey("YOUR_YOUTUBE_API_KEY", identifier: "youtube_api_key_prod")
 try await keyManager.storeAPIKey("YOUR_TWITCH_CLIENT_ID", identifier: "twitch_client_id_prod")

 // 2. Access configurations
 let apiManager = ProductionAPIManager.shared

 // YouTube streaming
 let youtubeConfig = apiManager.youtube
 let youtubeKey = keyManager.loadAPIKey(identifier: youtubeConfig.apiKeyIdentifier)

 // 3. Validate all keys are present
 let missingKeys = apiManager.validateAPIKeys()
 if !missingKeys.isEmpty {
     echoelLog.warning("Missing API keys: \(missingKeys)", category: .network)
 }

 // 4. Perform health checks
 let healthResults = await apiManager.performHealthCheck()
 for result in healthResults {
     echoelLog.info("\(result.apiName): \(result.isHealthy ? "healthy" : "unhealthy")", category: .network)
 }

 // 5. Generate health report
 let report = await apiManager.generateHealthReport()
 echoelLog.info(report, category: .network)

 // 6. Environment variable support
 // Set in Xcode scheme or CI/CD:
 // ECHOELMUSIC_ENV=production
 // YOUTUBE_API_KEY=your_key_here

 // 7. For RTMP streaming
 let twitchConfig = apiManager.twitch
 let rtmpURL = twitchConfig.ingestEndpoints[0] // "rtmp://live.twitch.tv/app"
 let streamKey = keyManager.loadAPIKey(identifier: "twitch_stream_key_prod")

 // 8. For custom RTMP endpoints
 let customRTMP = CustomRTMPConfiguration(
     name: "My Server",
     rtmpURL: "rtmp://my-server.com/live",
     streamKey: "my-stream-key",
     maxBitrate: 8_000_000
 )

 // 9. Hardware configurations
 let dmxConfig = apiManager.dmx
 // Connect to Art-Net at dmxConfig.artNetIP:dmxConfig.artNetPort

 // 10. Clear all keys (e.g., logout)
 try await keyManager.clearAllKeys()
 */
