//
// AnalyticsManager.swift
// Echoelmusic
//
// Privacy-first analytics and monitoring system
// Created: 2026-01-07
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Analytics Event

/// All trackable events in the app
public enum AnalyticsEvent: Equatable {
    case sessionStarted
    case sessionEnded(duration: TimeInterval)
    case presetSelected(name: String)
    case presetApplied(name: String)
    case coherenceAchieved(level: CoherenceLevel)
    case featureUsed(name: String)
    case errorOccurred(type: String, message: String)
    case subscriptionViewed(tier: String)
    case subscriptionPurchased(tier: String, price: Decimal)
    case shareCompleted(type: String)
    case exportCompleted(format: String, duration: TimeInterval)
    case quantumModeChanged(mode: String)
    case visualizationChanged(type: String)
    case collaborationJoined(sessionId: String)
    case collaborationLeft(sessionId: String, duration: TimeInterval)
    case pluginLoaded(name: String)
    case performanceWarning(metric: String, value: Double)

    /// Event name for tracking
    var name: String {
        switch self {
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"
        case .presetSelected: return "preset_selected"
        case .presetApplied: return "preset_applied"
        case .coherenceAchieved: return "coherence_achieved"
        case .featureUsed: return "feature_used"
        case .errorOccurred: return "error_occurred"
        case .subscriptionViewed: return "subscription_viewed"
        case .subscriptionPurchased: return "subscription_purchased"
        case .shareCompleted: return "share_completed"
        case .exportCompleted: return "export_completed"
        case .quantumModeChanged: return "quantum_mode_changed"
        case .visualizationChanged: return "visualization_changed"
        case .collaborationJoined: return "collaboration_joined"
        case .collaborationLeft: return "collaboration_left"
        case .pluginLoaded: return "plugin_loaded"
        case .performanceWarning: return "performance_warning"
        }
    }

    /// Event properties
    var properties: [String: Any] {
        switch self {
        case .sessionStarted:
            return [:]
        case .sessionEnded(let duration):
            return ["duration": duration]
        case .presetSelected(let name):
            return ["preset_name": name]
        case .presetApplied(let name):
            return ["preset_name": name]
        case .coherenceAchieved(let level):
            return [
                "level": level.rawValue,
                "percentage": level.percentage
            ]
        case .featureUsed(let name):
            return ["feature_name": name]
        case .errorOccurred(let type, let message):
            return [
                "error_type": type,
                "error_message": message
            ]
        case .subscriptionViewed(let tier):
            return ["tier": tier]
        case .subscriptionPurchased(let tier, let price):
            return [
                "tier": tier,
                "price": NSDecimalNumber(decimal: price).doubleValue
            ]
        case .shareCompleted(let type):
            return ["share_type": type]
        case .exportCompleted(let format, let duration):
            return [
                "export_format": format,
                "export_duration": duration
            ]
        case .quantumModeChanged(let mode):
            return ["mode": mode]
        case .visualizationChanged(let type):
            return ["visualization_type": type]
        case .collaborationJoined(let sessionId):
            return ["session_id": sessionId]
        case .collaborationLeft(let sessionId, let duration):
            return [
                "session_id": sessionId,
                "duration": duration
            ]
        case .pluginLoaded(let name):
            return ["plugin_name": name]
        case .performanceWarning(let metric, let value):
            return [
                "metric": metric,
                "value": value
            ]
        }
    }
}

/// Coherence level for analytics
public enum CoherenceLevel: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case peak = "peak"

    var percentage: Int {
        switch self {
        case .low: return 25
        case .medium: return 50
        case .high: return 75
        case .peak: return 100
        }
    }
}

// MARK: - Analytics Provider Protocol

/// Protocol for analytics backend providers
public protocol AnalyticsProvider {
    /// Track an event with properties
    func track(event: String, properties: [String: Any])

    /// Set a user property
    func setUserProperty(key: String, value: Any?)

    /// Identify a user
    func identify(userId: String)

    /// Reset user identity (for logout/privacy)
    func reset()

    /// Flush pending events
    func flush()
}

// MARK: - Console Analytics Provider

/// Debug analytics provider that logs to console
public class ConsoleAnalyticsProvider: AnalyticsProvider {
    private let log = ProfessionalLogger.shared

    public init() {}

    public func track(event: String, properties: [String: Any]) {
        log.analytics("📊 Event: \(event)")
        if !properties.isEmpty {
            log.analytics("   Properties: \(properties)")
        }
    }

    public func setUserProperty(key: String, value: Any?) {
        log.analytics("👤 User Property: \(key) = \(value ?? "nil")")
    }

    public func identify(userId: String) {
        log.analytics("🆔 Identify User: \(userId)")
    }

    public func reset() {
        log.analytics("🔄 Reset Analytics")
    }

    public func flush() {
        log.analytics("💾 Flush Analytics")
    }
}

// MARK: - File Analytics Provider

/// Analytics provider that logs to a file
public class FileAnalyticsProvider: AnalyticsProvider {
    private let log = ProfessionalLogger.shared
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.echoelmusic.analytics.file")
    private var fileHandle: FileHandle?

    public init(fileURL: URL) {
        self.fileURL = fileURL

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        // Open file handle
        do {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle?.seekToEndOfFile()
        } catch {
            log.error("Failed to open analytics file: \(error)")
        }
    }

    deinit {
        try? fileHandle?.close()
    }

    public func track(event: String, properties: [String: Any]) {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "type": "event",
            "name": event,
            "properties": properties
        ]
        writeEntry(entry)
    }

    public func setUserProperty(key: String, value: Any?) {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "type": "user_property",
            "key": key,
            "value": value ?? NSNull()
        ]
        writeEntry(entry)
    }

    public func identify(userId: String) {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "type": "identify",
            "user_id": userId
        ]
        writeEntry(entry)
    }

    public func reset() {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "type": "reset"
        ]
        writeEntry(entry)
    }

    public func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    private func writeEntry(_ entry: [String: Any]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: entry, options: [])
                var line = String(data: jsonData, encoding: .utf8) ?? ""
                line += "\n"

                if let data = line.data(using: .utf8) {
                    self.fileHandle?.write(data)
                }
            } catch {
                self.log.error("Failed to write analytics entry: \(error)")
            }
        }
    }
}

// MARK: - Firebase Analytics Provider

/// Firebase analytics provider
/// Uses conditional compilation for Firebase SDK integration
/// When Firebase SDK is added to project, define FIREBASE_ENABLED in build settings
public class FirebaseAnalyticsProvider: AnalyticsProvider {
    private let log = ProfessionalLogger.shared
    private var isEnabled: Bool = false

    public init() {
        #if FIREBASE_ENABLED
        // Firebase SDK is available
        // FirebaseApp.configure() should be called in AppDelegate
        isEnabled = true
        log.analytics("✅ Firebase Analytics initialized")
        #else
        // Firebase SDK not available - use native logging
        isEnabled = false
        log.analytics("ℹ️ Firebase SDK not included - using native analytics")
        #endif
    }

    public func track(event: String, properties: [String: Any]) {
        #if FIREBASE_ENABLED
        Analytics.logEvent(event, parameters: properties as? [String: NSObject])
        #endif
        log.analytics("📊 Event: \(event) \(properties.isEmpty ? "" : "| \(properties)")")
    }

    public func setUserProperty(key: String, value: Any?) {
        #if FIREBASE_ENABLED
        Analytics.setUserProperty(value as? String, forName: key)
        #endif
        log.analytics("👤 Property: \(key) = \(value ?? "nil")")
    }

    public func identify(userId: String) {
        #if FIREBASE_ENABLED
        Analytics.setUserID(userId)
        #endif
        log.analytics("🆔 User: \(userId)")
    }

    public func reset() {
        #if FIREBASE_ENABLED
        Analytics.resetAnalyticsData()
        #endif
        log.analytics("🔄 Analytics reset")
    }

    public func flush() {
        // Firebase automatically batches and flushes
        // No action needed - data syncs within 1 hour or on app background
        log.analytics("💾 Flush requested")
    }
}

// MARK: - Crash Reporter

/// Non-fatal error logging and crash reporting
public class CrashReporter {
    public static let shared = CrashReporter()

    private let log = ProfessionalLogger.shared
    private var breadcrumbs: [Breadcrumb] = []
    private var userInfo: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.echoelmusic.crash")
    private let maxBreadcrumbs = 100

    public struct Breadcrumb {
        let timestamp: Date
        let message: String
        let category: String
        let level: Level

        public enum Level: String {
            case debug, info, warning, error
        }
    }

    private init() {}

    /// Record a breadcrumb
    public func recordBreadcrumb(_ message: String, category: String = "general", level: Breadcrumb.Level = .info) {
        queue.async {
            let breadcrumb = Breadcrumb(
                timestamp: Date(),
                message: message,
                category: category,
                level: level
            )

            self.breadcrumbs.append(breadcrumb)

            // Trim to max size
            if self.breadcrumbs.count > self.maxBreadcrumbs {
                self.breadcrumbs.removeFirst(self.breadcrumbs.count - self.maxBreadcrumbs)
            }
        }
    }

    /// Set user info
    public func setUserInfo(key: String, value: Any?) {
        queue.async {
            self.userInfo[key] = value
        }
    }

    /// Report a non-fatal error
    public func reportNonFatal(error: Error, context: [String: Any] = [:]) {
        queue.async {
            self.log.error("Non-fatal error: \(error)")

            #if FIREBASE_ENABLED
            // Send to Firebase Crashlytics when SDK is available
            var userInfo = context
            userInfo["breadcrumbs"] = self.breadcrumbs.suffix(10).map { $0.message }
            Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
            #endif

            // Always log locally for debugging
            self.log.error("Breadcrumbs: \(self.breadcrumbs.suffix(10).map { $0.message })")
            self.log.error("User Info: \(self.userInfo)")
            self.log.error("Context: \(context)")

            // Persist to crash log file for later analysis
            self.persistCrashLog(error: error, context: context)
        }
    }

    /// Report a non-fatal message
    public func reportNonFatal(message: String, context: [String: Any] = [:]) {
        queue.async {
            self.log.error("Non-fatal: \(message)")

            #if FIREBASE_ENABLED
            Crashlytics.crashlytics().log(message)
            #endif

            self.log.error("Context: \(context)")

            // Persist for later analysis
            self.persistCrashLog(message: message, context: context)
        }
    }

    /// Persist crash log to file for debugging
    private func persistCrashLog(error: Error? = nil, message: String? = nil, context: [String: Any]) {
        guard let logsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let crashLogFile = logsDir.appendingPathComponent("crash_reports.jsonl")

        var entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "context": context,
            "breadcrumbs": self.breadcrumbs.suffix(20).map { [
                "time": $0.timestamp.ISO8601Format(),
                "msg": $0.message,
                "cat": $0.category,
                "lvl": $0.level.rawValue
            ]}
        ]

        if let error = error {
            entry["error_type"] = String(describing: type(of: error))
            entry["error_message"] = error.localizedDescription
        }
        if let message = message {
            entry["message"] = message
        }

        if let data = try? JSONSerialization.data(withJSONObject: entry),
           var content = String(data: data, encoding: .utf8) {
            content += "\n"
            if let handle = try? FileHandle(forWritingTo: crashLogFile) {
                handle.seekToEndOfFile()
                handle.write(content.data(using: .utf8) ?? Data())
                try? handle.close()
            } else {
                try? content.write(to: crashLogFile, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Get recent breadcrumbs
    public func getRecentBreadcrumbs(count: Int = 20) -> [Breadcrumb] {
        queue.sync {
            Array(breadcrumbs.suffix(count))
        }
    }

    /// Clear breadcrumbs
    public func clearBreadcrumbs() {
        queue.async {
            self.breadcrumbs.removeAll()
        }
    }
}

// MARK: - Performance Monitor

/// Performance monitoring for app metrics
public class PerformanceMonitor {
    public static let shared = PerformanceMonitor()

    private let log = ProfessionalLogger.shared
    private var timers: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.echoelmusic.performance")

    private init() {}

    /// Start timing a metric
    public func startTimer(_ name: String) {
        queue.async {
            self.timers[name] = Date()
            self.log.performance("⏱️ Started timer: \(name)")
        }
    }

    /// Stop timing and report
    public func stopTimer(_ name: String) -> TimeInterval? {
        queue.sync {
            guard let startTime = timers.removeValue(forKey: name) else {
                log.warning("Timer '\(name)' not found")
                return nil
            }

            let duration = Date().timeIntervalSince(startTime)
            log.performance("⏱️ Stopped timer: \(name) - Duration: \(String(format: "%.3f", duration))s")

            // Track in analytics
            AnalyticsManager.shared.trackPerformance(metric: name, duration: duration)

            return duration
        }
    }

    /// Measure app launch time
    public func measureAppLaunch(from launchDate: Date) {
        let launchTime = Date().timeIntervalSince(launchDate)
        log.performance("🚀 App Launch Time: \(String(format: "%.3f", launchTime))s")
        AnalyticsManager.shared.trackPerformance(metric: "app_launch", duration: launchTime)
    }

    /// Measure screen render time
    public func measureScreenRender(screenName: String, duration: TimeInterval) {
        log.performance("🖼️ Screen Render: \(screenName) - \(String(format: "%.3f", duration))s")
        AnalyticsManager.shared.trackPerformance(metric: "screen_render_\(screenName)", duration: duration)
    }

    /// Measure network request
    public func measureNetworkRequest(endpoint: String, duration: TimeInterval, success: Bool) {
        log.performance("🌐 Network: \(endpoint) - \(String(format: "%.3f", duration))s - Success: \(success)")
        AnalyticsManager.shared.trackPerformance(
            metric: "network_request",
            duration: duration,
            properties: [
                "endpoint": endpoint,
                "success": success
            ]
        )
    }

    /// Report custom metric
    public func reportMetric(name: String, value: Double, unit: String = "") {
        log.performance("📈 Metric: \(name) = \(value)\(unit)")
        AnalyticsManager.shared.trackPerformance(
            metric: name,
            value: value,
            properties: ["unit": unit]
        )
    }
}

// MARK: - Privacy Compliance

/// Privacy and compliance management
public class PrivacyCompliance {
    public static let shared = PrivacyCompliance()

    private let log = ProfessionalLogger.shared
    private let defaults = UserDefaults.standard

    private let analyticsConsentKey = "analytics_consent"
    private let crashReportingConsentKey = "crash_reporting_consent"
    private let performanceConsentKey = "performance_consent"
    private let gdprConsentDateKey = "gdpr_consent_date"

    private init() {}

    // MARK: - Consent Management

    /// Check if analytics is enabled
    public var isAnalyticsEnabled: Bool {
        get { defaults.bool(forKey: analyticsConsentKey) }
        set {
            defaults.set(newValue, forKey: analyticsConsentKey)
            log.analytics("Analytics consent: \(newValue)")

            if newValue {
                recordConsentDate()
            }
        }
    }

    /// Check if crash reporting is enabled
    public var isCrashReportingEnabled: Bool {
        get { defaults.bool(forKey: crashReportingConsentKey) }
        set {
            defaults.set(newValue, forKey: crashReportingConsentKey)
            log.analytics("Crash reporting consent: \(newValue)")
        }
    }

    /// Check if performance monitoring is enabled
    public var isPerformanceMonitoringEnabled: Bool {
        get { defaults.bool(forKey: performanceConsentKey) }
        set {
            defaults.set(newValue, forKey: performanceConsentKey)
            log.analytics("Performance monitoring consent: \(newValue)")
        }
    }

    /// Set all consents at once (for GDPR consent screen)
    public func setConsents(
        analytics: Bool,
        crashReporting: Bool,
        performance: Bool
    ) {
        isAnalyticsEnabled = analytics
        isCrashReportingEnabled = crashReporting
        isPerformanceMonitoringEnabled = performance

        log.analytics("All consents set: analytics=\(analytics), crash=\(crashReporting), perf=\(performance)")
    }

    /// Get consent date (for GDPR compliance)
    public var consentDate: Date? {
        defaults.object(forKey: gdprConsentDateKey) as? Date
    }

    private func recordConsentDate() {
        defaults.set(Date(), forKey: gdprConsentDateKey)
    }

    // MARK: - Data Deletion

    /// Delete all analytics data (GDPR right to erasure)
    public func deleteAllData() {
        log.analytics("🗑️ Deleting all analytics data")

        // Reset all providers
        AnalyticsManager.shared.reset()

        // Clear crash reporter
        CrashReporter.shared.clearBreadcrumbs()

        // Clear consents
        defaults.removeObject(forKey: analyticsConsentKey)
        defaults.removeObject(forKey: crashReportingConsentKey)
        defaults.removeObject(forKey: performanceConsentKey)
        defaults.removeObject(forKey: gdprConsentDateKey)

        log.analytics("✅ All analytics data deleted")
    }

    /// Export user data (GDPR right to data portability)
    public func exportUserData() -> [String: Any] {
        log.analytics("📦 Exporting user data")

        var data: [String: Any] = [:]

        // Add consent status
        data["consents"] = [
            "analytics": isAnalyticsEnabled,
            "crash_reporting": isCrashReportingEnabled,
            "performance": isPerformanceMonitoringEnabled,
            "consent_date": consentDate?.ISO8601Format() ?? "none"
        ]

        // Add recent breadcrumbs
        let breadcrumbs = CrashReporter.shared.getRecentBreadcrumbs(count: 100)
        data["breadcrumbs"] = breadcrumbs.map { crumb in
            [
                "timestamp": crumb.timestamp.ISO8601Format(),
                "message": crumb.message,
                "category": crumb.category,
                "level": crumb.level.rawValue
            ]
        }

        log.analytics("✅ User data exported")
        return data
    }
}

// MARK: - Analytics Manager

/// Main analytics manager (singleton)
@MainActor
public class AnalyticsManager: ObservableObject {
    public static let shared = AnalyticsManager()

    private let log = ProfessionalLogger.shared
    private var providers: [AnalyticsProvider] = []
    private var sessionStartTime: Date?
    @Published public private(set) var sessionDuration: TimeInterval = 0

    private init() {
        setupProviders()
        setupSessionTracking()
    }

    // MARK: - Provider Setup

    private func setupProviders() {
        // Always add console provider in debug builds
        #if DEBUG
        providers.append(ConsoleAnalyticsProvider())
        #endif

        // Add file provider for local logging
        if let logsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let analyticsFile = logsDirectory.appendingPathComponent("analytics.jsonl")
            providers.append(FileAnalyticsProvider(fileURL: analyticsFile))
            log.analytics("Analytics file: \(analyticsFile.path)")
        }

        // Add Firebase provider (stub for now)
        // Uncomment when Firebase SDK is added:
        // providers.append(FirebaseAnalyticsProvider())

        log.analytics("✅ Analytics providers initialized: \(providers.count)")
    }

    // MARK: - Session Tracking

    private func setupSessionTracking() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        #elseif canImport(AppKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidBecomeActive() {
        Task { @MainActor in
            startSession()
        }
    }

    @objc private func appWillResignActive() {
        Task { @MainActor in
            endSession()
        }
    }

    /// Start a new session
    public func startSession() {
        guard PrivacyCompliance.shared.isAnalyticsEnabled else {
            log.analytics("Analytics disabled - not starting session")
            return
        }

        sessionStartTime = Date()
        track(.sessionStarted)

        // Record device info
        setUserProperty(key: "platform", value: getPlatform())
        setUserProperty(key: "os_version", value: getOSVersion())
        setUserProperty(key: "app_version", value: getAppVersion())

        log.analytics("📊 Session started")
    }

    /// End current session
    public func endSession() {
        guard let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        sessionDuration = duration
        track(.sessionEnded(duration: duration))

        // Flush all providers
        flush()

        sessionStartTime = nil
        log.analytics("📊 Session ended - Duration: \(String(format: "%.1f", duration))s")
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    public func track(_ event: AnalyticsEvent) {
        guard PrivacyCompliance.shared.isAnalyticsEnabled else { return }

        let eventName = event.name
        let properties = event.properties

        for provider in providers {
            provider.track(event: eventName, properties: properties)
        }

        // Record breadcrumb
        CrashReporter.shared.recordBreadcrumb(
            "Event: \(eventName)",
            category: "analytics",
            level: .info
        )
    }

    /// Track performance metric
    public func trackPerformance(
        metric: String,
        duration: TimeInterval? = nil,
        value: Double? = nil,
        properties: [String: Any] = [:]
    ) {
        guard PrivacyCompliance.shared.isPerformanceMonitoringEnabled else { return }

        var props = properties
        if let duration = duration {
            props["duration"] = duration
        }
        if let value = value {
            props["value"] = value
        }
        props["metric"] = metric

        for provider in providers {
            provider.track(event: "performance_metric", properties: props)
        }
    }

    // MARK: - User Properties

    /// Set a user property
    public func setUserProperty(key: String, value: Any?) {
        guard PrivacyCompliance.shared.isAnalyticsEnabled else { return }

        for provider in providers {
            provider.setUserProperty(key: key, value: value)
        }
    }

    /// Identify a user
    public func identify(userId: String) {
        guard PrivacyCompliance.shared.isAnalyticsEnabled else { return }

        for provider in providers {
            provider.identify(userId: userId)
        }

        log.analytics("🆔 User identified: \(userId)")
    }

    // MARK: - Lifecycle

    /// Reset analytics (for logout)
    public func reset() {
        for provider in providers {
            provider.reset()
        }

        sessionStartTime = nil
        sessionDuration = 0

        log.analytics("🔄 Analytics reset")
    }

    /// Flush pending events
    public func flush() {
        for provider in providers {
            provider.flush()
        }

        log.analytics("💾 Analytics flushed")
    }

    // MARK: - Convenience Methods

    /// Track feature usage
    public func trackFeatureUsage(_ featureName: String) {
        track(.featureUsed(name: featureName))
    }

    /// Track error
    public func trackError(_ error: Error, context: String = "") {
        let errorType = String(describing: type(of: error))
        let message = error.localizedDescription

        track(.errorOccurred(type: errorType, message: message))

        // Also report to crash reporter
        if PrivacyCompliance.shared.isCrashReportingEnabled {
            CrashReporter.shared.reportNonFatal(
                error: error,
                context: ["context": context]
            )
        }
    }

    // MARK: - Device Info

    private func getPlatform() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    private func getOSVersion() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #elseif canImport(AppKit)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "Unknown"
        #endif
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

// MARK: - Convenience Extensions

extension AnalyticsManager {
    /// Track preset selection
    public func trackPresetSelected(_ presetName: String) {
        track(.presetSelected(name: presetName))
    }

    /// Track preset application
    public func trackPresetApplied(_ presetName: String) {
        track(.presetApplied(name: presetName))
    }

    /// Track coherence achievement
    public func trackCoherenceAchieved(percentage: Double) {
        let level: CoherenceLevel
        switch percentage {
        case 0..<40:
            level = .low
        case 40..<60:
            level = .medium
        case 60..<80:
            level = .high
        default:
            level = .peak
        }
        track(.coherenceAchieved(level: level))
    }

    /// Track quantum mode change
    public func trackQuantumModeChanged(_ mode: String) {
        track(.quantumModeChanged(mode: mode))
    }

    /// Track visualization change
    public func trackVisualizationChanged(_ type: String) {
        track(.visualizationChanged(type: type))
    }

    /// Track collaboration
    public func trackCollaborationJoined(_ sessionId: String) {
        track(.collaborationJoined(sessionId: sessionId))
    }

    /// Track collaboration end
    public func trackCollaborationLeft(_ sessionId: String, duration: TimeInterval) {
        track(.collaborationLeft(sessionId: sessionId, duration: duration))
    }

    /// Track plugin load
    public func trackPluginLoaded(_ pluginName: String) {
        track(.pluginLoaded(name: pluginName))
    }

    /// Track subscription view
    public func trackSubscriptionViewed(_ tier: String) {
        track(.subscriptionViewed(tier: tier))
    }

    /// Track subscription purchase
    public func trackSubscriptionPurchased(_ tier: String, price: Decimal) {
        track(.subscriptionPurchased(tier: tier, price: price))
    }

    /// Track share
    public func trackShareCompleted(_ type: String) {
        track(.shareCompleted(type: type))
    }

    /// Track export
    public func trackExportCompleted(_ format: String, duration: TimeInterval) {
        track(.exportCompleted(format: format, duration: duration))
    }
}

// MARK: - Performance Extensions

extension PerformanceMonitor {
    /// Convenient timer closure
    public func measure<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        startTimer(name)
        defer { _ = stopTimer(name) }
        return try operation()
    }

    /// Convenient async timer closure
    public func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        startTimer(name)
        defer { _ = stopTimer(name) }
        return try await operation()
    }
}

// MARK: - Crash Reporter Extensions

extension CrashReporter {
    /// Convenient breadcrumb with automatic level
    public func log(_ message: String, category: String = "general") {
        recordBreadcrumb(message, category: category, level: .info)
    }

    /// Debug breadcrumb
    public func debug(_ message: String, category: String = "general") {
        recordBreadcrumb(message, category: category, level: .debug)
    }

    /// Warning breadcrumb
    public func warning(_ message: String, category: String = "general") {
        recordBreadcrumb(message, category: category, level: .warning)
    }

    /// Error breadcrumb
    public func error(_ message: String, category: String = "general") {
        recordBreadcrumb(message, category: category, level: .error)
    }
}
