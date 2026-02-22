// ProductionConfiguration.swift
// Echoelmusic - Nobel Prize Multitrillion Dollar Production System
//
// Enterprise-grade configuration management for production deployment
// Environment detection, feature flags, secrets management, A/B testing

import Foundation
import Combine
import Security

// MARK: - Production Environment

/// Deployment environment with automatic detection
public enum DeploymentEnvironment: String, CaseIterable, Sendable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    case enterprise = "enterprise"

    /// Automatic environment detection based on build configuration and bundle
    public static var current: DeploymentEnvironment {
        #if DEBUG
        return .development
        #else
        if let env = ProcessInfo.processInfo.environment["ECHOELMUSIC_ENV"] {
            return DeploymentEnvironment(rawValue: env) ?? .production
        }

        // Check for TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .staging
        }

        return .production
        #endif
    }

    public var isProduction: Bool { self == .production || self == .enterprise }
    public var isDevelopment: Bool { self == .development }
    public var isStaging: Bool { self == .staging }
    public var allowsDebugFeatures: Bool { self == .development }
    public var requiresAnalytics: Bool { isProduction }
    public var requiresCrashReporting: Bool { self != .development }
}

// MARK: - Feature Flags

/// Production feature flag system with remote config support
@MainActor
public final class FeatureFlagManager: ObservableObject {
    public static let shared = FeatureFlagManager()

    @Published public private(set) var flags: [String: FeatureFlag] = [:]
    private var remoteConfigURL: URL?
    private var refreshInterval: TimeInterval = 300 // 5 minutes
    private var lastRefresh: Date?

    public struct FeatureFlag: Codable, Sendable {
        public var key: String
        public var enabled: Bool
        public var rolloutPercentage: Double // 0-100
        public var environments: [String] // Which environments this applies to
        public var metadata: [String: String]
        public var expiresAt: Date?

        public init(
            key: String,
            enabled: Bool = true,
            rolloutPercentage: Double = 100,
            environments: [String] = ["production", "staging", "development"],
            metadata: [String: String] = [:],
            expiresAt: Date? = nil
        ) {
            self.key = key
            self.enabled = enabled
            self.rolloutPercentage = rolloutPercentage
            self.environments = environments
            self.metadata = metadata
            self.expiresAt = expiresAt
        }

        public func isEnabledFor(environment: DeploymentEnvironment, userId: String? = nil) -> Bool {
            guard enabled else { return false }
            guard environments.contains(environment.rawValue) else { return false }

            if let expiry = expiresAt, Date() > expiry {
                return false
            }

            if rolloutPercentage < 100 {
                // Deterministic rollout based on user ID hash
                if let userId = userId {
                    let hash = abs(userId.hashValue) % 100
                    return Double(hash) < rolloutPercentage
                }
                return false
            }

            return true
        }
    }

    private init() {
        loadDefaultFlags()
    }

    private func loadDefaultFlags() {
        // Core production feature flags
        let defaultFlags: [FeatureFlag] = [
            // Audio Engine Features
            FeatureFlag(key: "quantum_light_emulator", enabled: true),
            FeatureFlag(key: "orchestral_scoring", enabled: true),
            FeatureFlag(key: "film_score_composer", enabled: true),
            FeatureFlag(key: "binaural_beats", enabled: true),
            FeatureFlag(key: "spatial_audio_4d", enabled: true),

            // Video Features
            FeatureFlag(key: "video_16k_processing", enabled: true, rolloutPercentage: 50),
            FeatureFlag(key: "video_1000fps", enabled: true, rolloutPercentage: 25),
            FeatureFlag(key: "chroma_key_advanced", enabled: true),

            // Streaming Features
            FeatureFlag(key: "rtmp_streaming", enabled: true),
            FeatureFlag(key: "multi_platform_streaming", enabled: true),
            FeatureFlag(key: "webrtc_streaming", enabled: true, rolloutPercentage: 75),

            // AI Features
            FeatureFlag(key: "ai_composition", enabled: true),
            FeatureFlag(key: "ai_stem_separation", enabled: true),
            FeatureFlag(key: "llm_integration", enabled: true, environments: ["production", "staging"]),

            // Lambda Mode
            FeatureFlag(key: "lambda_mode", enabled: true),
            FeatureFlag(key: "quantum_loop_light", enabled: true),
            FeatureFlag(key: "social_coherence", enabled: true),

            // Collaboration
            FeatureFlag(key: "worldwide_collaboration", enabled: true),
            FeatureFlag(key: "shareplay_sessions", enabled: true),

            // Developer Features
            FeatureFlag(key: "developer_console", enabled: true, environments: ["development", "staging"]),
            FeatureFlag(key: "plugin_system", enabled: true),

            // Experimental
            FeatureFlag(key: "experimental_dsp", enabled: false),
            FeatureFlag(key: "beta_features", enabled: true, environments: ["staging"]),

            // Blockchain / NFT — disabled in App Store builds (Guideline 3.1.5)
            FeatureFlag(key: "nft_minting", enabled: false, environments: ["development"]),
        ]

        for flag in defaultFlags {
            flags[flag.key] = flag
        }
    }

    public func isEnabled(_ key: String, userId: String? = nil) -> Bool {
        guard let flag = flags[key] else { return false }
        return flag.isEnabledFor(environment: DeploymentEnvironment.current, userId: userId)
    }

    public func configure(remoteURL: URL, refreshInterval: TimeInterval = 300) {
        self.remoteConfigURL = remoteURL
        self.refreshInterval = refreshInterval
    }

    public func refreshFromRemote() async throws {
        guard let url = remoteConfigURL else { return }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ProductionError.remoteConfigFailed
        }

        let remoteFlags = try JSONDecoder().decode([FeatureFlag].self, from: data)

        for flag in remoteFlags {
            flags[flag.key] = flag
        }

        lastRefresh = Date()
    }

    public func setFlag(_ key: String, enabled: Bool) {
        if var flag = flags[key] {
            flag.enabled = enabled
            flags[key] = flag
        }
    }
}

// MARK: - Secrets Management

/// Secure secrets management using Keychain
public final class SecretsManager: Sendable {
    public static let shared = SecretsManager()

    private let serviceName = "com.echoelmusic.production"

    public enum SecretKey: String, CaseIterable, Sendable {
        case anthropicAPIKey = "anthropic_api_key"
        case openAIAPIKey = "openai_api_key"
        case streamingKey = "streaming_key"
        case analyticsKey = "analytics_key"
        case crashReportingKey = "crash_reporting_key"
        case encryptionKey = "encryption_key"
        case signingKey = "signing_key"
        case databaseKey = "database_key"
        case pushNotificationKey = "push_notification_key"
        case iapSharedSecret = "iap_shared_secret"
    }

    private init() {}

    /// Store secret securely in Keychain
    public func setSecret(_ value: String, for key: SecretKey) throws {
        let data = Data(value.utf8)

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw ProductionError.keychainError(status)
        }
    }

    /// Retrieve secret from Keychain
    public func getSecret(for key: SecretKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Delete secret from Keychain
    public func deleteSecret(for key: SecretKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProductionError.keychainError(status)
        }
    }

    /// Check if secret exists
    public func hasSecret(for key: SecretKey) -> Bool {
        return getSecret(for: key) != nil
    }

    /// Migrate secrets from environment variables (one-time setup)
    public func migrateFromEnvironment() {
        let mappings: [(String, SecretKey)] = [
            ("ANTHROPIC_API_KEY", .anthropicAPIKey),
            ("OPENAI_API_KEY", .openAIAPIKey),
            ("STREAMING_KEY", .streamingKey),
            ("ANALYTICS_KEY", .analyticsKey)
        ]

        for (envVar, key) in mappings {
            if let value = ProcessInfo.processInfo.environment[envVar],
               !hasSecret(for: key) {
                try? setSecret(value, for: key)
            }
        }
    }
}

// MARK: - Production Configuration

/// Main production configuration container
@MainActor
public final class ProductionConfiguration: ObservableObject {
    public static let shared = ProductionConfiguration()

    @Published public var environment: DeploymentEnvironment
    @Published public var appVersion: String
    @Published public var buildNumber: String
    @Published public var isFirstLaunch: Bool
    @Published public var installDate: Date
    @Published public var lastUpdateDate: Date?

    // API Endpoints
    public struct Endpoints: Sendable {
        public let api: URL
        public let streaming: URL
        public let analytics: URL
        public let crashReporting: URL
        public let remoteConfig: URL
        public let collaboration: URL

        /// Static fallback URL (compile-time guaranteed valid)
        private static let fallbackURL = URL(fileURLWithPath: "/")

        /// Safely create URL from string, with fallback for malformed URLs
        private static func safeURL(_ string: String) -> URL {
            guard let url = URL(string: string) else {
                // Log error and return fallback - should never happen with hardcoded valid URLs
                assertionFailure("Invalid URL string: \(string)")
                return URL(string: "https://echoelmusic.com") ?? fallbackURL
            }
            return url
        }

        public static func forEnvironment(_ env: DeploymentEnvironment) -> Endpoints {
            switch env {
            case .development:
                return Endpoints(
                    api: safeURL("https://dev-api.echoelmusic.com/v2"),
                    streaming: safeURL("rtmp://dev-stream.echoelmusic.com/live"),
                    analytics: safeURL("https://dev-analytics.echoelmusic.com"),
                    crashReporting: safeURL("https://dev-crashes.echoelmusic.com"),
                    remoteConfig: safeURL("https://dev-config.echoelmusic.com/flags"),
                    collaboration: safeURL("wss://dev-collab.echoelmusic.com")
                )
            case .staging:
                return Endpoints(
                    api: safeURL("https://staging-api.echoelmusic.com/v2"),
                    streaming: safeURL("rtmp://staging-stream.echoelmusic.com/live"),
                    analytics: safeURL("https://staging-analytics.echoelmusic.com"),
                    crashReporting: safeURL("https://staging-crashes.echoelmusic.com"),
                    remoteConfig: safeURL("https://staging-config.echoelmusic.com/flags"),
                    collaboration: safeURL("wss://staging-collab.echoelmusic.com")
                )
            case .production, .enterprise:
                return Endpoints(
                    api: safeURL("https://api.echoelmusic.com/v2"),
                    streaming: safeURL("rtmp://stream.echoelmusic.com/live"),
                    analytics: safeURL("https://analytics.echoelmusic.com"),
                    crashReporting: safeURL("https://crashes.echoelmusic.com"),
                    remoteConfig: safeURL("https://config.echoelmusic.com/flags"),
                    collaboration: safeURL("wss://collab.echoelmusic.com")
                )
            }
        }
    }

    public var endpoints: Endpoints {
        Endpoints.forEnvironment(environment)
    }

    // Performance Configuration
    public struct PerformanceConfig: Sendable {
        public var maxConcurrentOperations: Int
        public var audioBufferSize: Int
        public var videoBufferFrames: Int
        public var networkTimeoutSeconds: TimeInterval
        public var cacheMaxSizeMB: Int
        public var enableMetalGPU: Bool
        public var enableLowPowerMode: Bool

        public static let production = PerformanceConfig(
            maxConcurrentOperations: 8,
            audioBufferSize: 512,
            videoBufferFrames: 3,
            networkTimeoutSeconds: 30,
            cacheMaxSizeMB: 500,
            enableMetalGPU: true,
            enableLowPowerMode: false
        )

        public static let lowPower = PerformanceConfig(
            maxConcurrentOperations: 4,
            audioBufferSize: 1024,
            videoBufferFrames: 2,
            networkTimeoutSeconds: 60,
            cacheMaxSizeMB: 200,
            enableMetalGPU: true,
            enableLowPowerMode: true
        )
    }

    public var performance: PerformanceConfig {
        ProcessInfo.processInfo.isLowPowerModeEnabled
            ? .lowPower
            : .production
    }

    private init() {
        self.environment = DeploymentEnvironment.current
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let defaults = UserDefaults.standard
        self.isFirstLaunch = !defaults.bool(forKey: "echoelmusic.hasLaunched")
        self.installDate = defaults.object(forKey: "echoelmusic.installDate") as? Date ?? Date()
        self.lastUpdateDate = defaults.object(forKey: "echoelmusic.lastUpdateDate") as? Date

        if isFirstLaunch {
            defaults.set(true, forKey: "echoelmusic.hasLaunched")
            defaults.set(Date(), forKey: "echoelmusic.installDate")

            // Migrate secrets from environment
            SecretsManager.shared.migrateFromEnvironment()
        }

        // Check for version update
        let lastVersion = defaults.string(forKey: "echoelmusic.lastVersion")
        if lastVersion != appVersion {
            defaults.set(appVersion, forKey: "echoelmusic.lastVersion")
            defaults.set(Date(), forKey: "echoelmusic.lastUpdateDate")
            self.lastUpdateDate = Date()
        }
    }

    /// Initialize production systems
    public func initializeProductionSystems() async {
        // Configure feature flags
        FeatureFlagManager.shared.configure(
            remoteURL: endpoints.remoteConfig,
            refreshInterval: 300
        )

        // Refresh remote config if in production
        if environment.isProduction {
            try? await FeatureFlagManager.shared.refreshFromRemote()
        }

        // Initialize monitoring
        await ProductionMonitoring.shared.initialize()

        // Initialize error recovery
        ErrorRecoverySystem.shared.configure()

        // Initialize rate limiter
        RateLimiter.shared.configure(for: environment)
    }
}

// MARK: - A/B Testing

/// Production A/B testing system
@MainActor
public final class ABTestManager: ObservableObject {
    public static let shared = ABTestManager()

    public struct Experiment: Identifiable, Codable, Sendable {
        public var id: String
        public var name: String
        public var variants: [Variant]
        public var isActive: Bool
        public var startDate: Date
        public var endDate: Date?

        public struct Variant: Identifiable, Codable, Sendable {
            public var id: String
            public var name: String
            public var weight: Double // Percentage 0-100
            public var metadata: [String: String]
        }
    }

    @Published public private(set) var experiments: [String: Experiment] = [:]
    @Published public private(set) var assignments: [String: String] = [:] // experimentId -> variantId

    private init() {
        loadAssignments()
    }

    private func loadAssignments() {
        if let data = UserDefaults.standard.data(forKey: "echoelmusic.abAssignments"),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            assignments = saved
        }
    }

    private func saveAssignments() {
        if let data = try? JSONEncoder().encode(assignments) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.abAssignments")
        }
    }

    public func getVariant(for experimentId: String) -> Experiment.Variant? {
        guard let experiment = experiments[experimentId],
              experiment.isActive else { return nil }

        // Check existing assignment
        if let variantId = assignments[experimentId],
           let variant = experiment.variants.first(where: { $0.id == variantId }) {
            return variant
        }

        // Assign to variant based on weights
        let random = Double.random(in: 0..<100)
        var cumulative: Double = 0

        for variant in experiment.variants {
            cumulative += variant.weight
            if random < cumulative {
                assignments[experimentId] = variant.id
                saveAssignments()
                return variant
            }
        }

        return experiment.variants.first
    }

    public func trackConversion(experimentId: String, event: String) {
        guard let variantId = assignments[experimentId] else { return }

        // Track to analytics
        Task {
            await ProductionMonitoring.shared.trackEvent(
                "ab_conversion",
                parameters: [
                    "experiment_id": experimentId,
                    "variant_id": variantId,
                    "event": event
                ]
            )
        }
    }
}

// MARK: - Production Errors

public enum ProductionError: Error, LocalizedError, Sendable {
    case keychainError(OSStatus)
    case remoteConfigFailed
    case featureFlagNotFound(String)
    case experimentNotActive(String)
    case rateLimitExceeded
    case securityValidationFailed
    case configurationMissing(String)

    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .remoteConfigFailed:
            return "Failed to fetch remote configuration"
        case .featureFlagNotFound(let key):
            return "Feature flag not found: \(key)"
        case .experimentNotActive(let id):
            return "A/B experiment not active: \(id)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .securityValidationFailed:
            return "Security validation failed"
        case .configurationMissing(let key):
            return "Configuration missing: \(key)"
        }
    }
}

// MARK: - Launch Configuration

/// App launch configuration and validation
public struct LaunchConfiguration: Sendable {
    public static func validate() -> [String] {
        var warnings: [String] = []

        let env = DeploymentEnvironment.current

        // Check required secrets in production
        if env.isProduction {
            let requiredSecrets: [SecretsManager.SecretKey] = [
                .analyticsKey,
                .crashReportingKey
            ]

            for secret in requiredSecrets {
                if !SecretsManager.shared.hasSecret(for: secret) {
                    warnings.append("Missing required secret: \(secret.rawValue)")
                }
            }
        }

        // Check minimum iOS version
        if #available(iOS 15, *) {
            // OK
        } else {
            warnings.append("iOS 15+ required for full functionality")
        }

        return warnings
    }

    public static func performPreflightChecks() async -> Bool {
        let warnings = validate()

        for warning in warnings {
            await ProductionMonitoring.shared.trackWarning(warning)
        }

        return warnings.isEmpty
    }
}
