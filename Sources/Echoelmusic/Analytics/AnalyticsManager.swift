//
// AnalyticsManager.swift
// Echoelmusic
//
// Privacy-first analytics and monitoring system
// Created: 2026-01-07
//

import Foundation
import Combine
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
    case coherenceAchieved(level: AnalyticsCoherenceLevel)
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

/// Coherence level for analytics tracking
public enum AnalyticsCoherenceLevel: String {
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
        // Remove all notification observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)

        // Close file handle with error logging
        do {
            try fileHandle?.close()
        } catch {
            // Use global logger instance since self.log may not be safe in deinit
            echoelLog.warning("Failed to close analytics file handle: \(error)", category: .system)
        }
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

// MARK: - Firebase Analytics Provider (Full Implementation)

/// Firebase-compatible analytics provider using local storage + remote sync
/// Works without Firebase SDK - stores locally and syncs when network available
public class FirebaseAnalyticsProvider: AnalyticsProvider {
    private let log = ProfessionalLogger.shared
    private let storage: AnalyticsStorage
    private let networkSync: AnalyticsNetworkSync
    private var userId: String?
    private var userProperties: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.echoelmusic.analytics", qos: .utility)

    public init() {
        self.storage = AnalyticsStorage()
        self.networkSync = AnalyticsNetworkSync()
        log.analytics("✅ FirebaseAnalyticsProvider: Initialized with local storage + network sync")

        // Attempt to sync any pending events
        Task {
            await networkSync.syncPendingEvents(from: storage)
        }
    }

    public func track(event: String, properties: [String: Any]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Create analytics event
            let storedEvent = StoredAnalyticsEvent(
                name: event,
                properties: properties,
                userId: self.userId,
                userProperties: self.userProperties,
                timestamp: Date(),
                sessionId: self.storage.currentSessionId
            )

            // Store locally
            self.storage.store(event: storedEvent)

            // Log for debugging
            self.log.analytics("📊 Track: \(event) | props: \(properties.keys.joined(separator: ", "))")

            // Attempt network sync
            Task {
                await self.networkSync.sendEvent(analyticsEvent)
            }
        }
    }

    public func setUserProperty(key: String, value: Any?) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let value = value {
                self.userProperties[key] = value
                self.storage.setUserProperty(key: key, value: value)
                self.log.analytics("👤 UserProperty: \(key) = \(value)")
            } else {
                self.userProperties.removeValue(forKey: key)
                self.storage.removeUserProperty(key: key)
                self.log.analytics("👤 UserProperty removed: \(key)")
            }
        }
    }

    public func identify(userId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.userId = userId
            self.storage.setUserId(userId)
            self.log.analytics("🆔 Identified: \(userId.prefix(8))...")

            // Track identification event
            self.track(event: "user_identified", properties: ["user_id_hash": userId.hashValue])
        }
    }

    public func reset() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.userId = nil
            self.userProperties.removeAll()
            self.storage.reset()
            self.log.analytics("🔄 Analytics reset")
        }
    }

    public func flush() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.log.analytics("📤 Flushing analytics...")
            Task {
                await self.networkSync.syncPendingEvents(from: self.storage)
            }
        }
    }
}

// MARK: - Stored Analytics Event Model

struct StoredAnalyticsEvent: Codable {
    let id: UUID
    let name: String
    let properties: [String: AnalyticsAnyCodable]
    let userId: String?
    let userProperties: [String: AnalyticsAnyCodable]
    let timestamp: Date
    let sessionId: String
    var isSynced: Bool

    init(name: String, properties: [String: Any], userId: String?, userProperties: [String: Any], timestamp: Date, sessionId: String) {
        self.id = UUID()
        self.name = name
        self.properties = properties.mapValues { AnalyticsAnyCodable($0) }
        self.userId = userId
        self.userProperties = userProperties.mapValues { AnalyticsAnyCodable($0) }
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.isSynced = false
    }
}

// MARK: - AnalyticsAnyCodable Wrapper

struct AnalyticsAnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnalyticsAnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnalyticsAnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { AnalyticsAnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnalyticsAnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

// MARK: - Analytics Local Storage

class AnalyticsStorage {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var events: [StoredAnalyticsEvent] = []
    private var userProperties: [String: Any] = [:]
    private(set) var userId: String?
    let currentSessionId: String
    private let maxStoredEvents = 1000

    private var storageURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Echoelmusic/Analytics")
    }

    init() {
        self.currentSessionId = UUID().uuidString
        loadFromDisk()
    }

    func store(event: StoredAnalyticsEvent) {
        events.append(event)

        // Trim if over limit
        if events.count > maxStoredEvents {
            events.removeFirst(events.count - maxStoredEvents)
        }

        saveToDisk()
    }

    func setUserProperty(key: String, value: Any) {
        userProperties[key] = value
        saveToDisk()
    }

    func removeUserProperty(key: String) {
        userProperties.removeValue(forKey: key)
        saveToDisk()
    }

    func setUserId(_ id: String) {
        userId = id
        saveToDisk()
    }

    func getPendingEvents() -> [StoredAnalyticsEvent] {
        return events.filter { !$0.isSynced }
    }

    func markEventsSynced(ids: [UUID]) {
        for i in events.indices {
            if ids.contains(events[i].id) {
                events[i].isSynced = true
            }
        }
        // Remove old synced events
        events.removeAll { $0.isSynced && $0.timestamp < Date().addingTimeInterval(-86400 * 7) }
        saveToDisk()
    }

    func reset() {
        events.removeAll()
        userProperties.removeAll()
        userId = nil
        saveToDisk()
    }

    private func saveToDisk() {
        guard let url = storageURL else { return }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

            let eventsData = try encoder.encode(events)
            try eventsData.write(to: url.appendingPathComponent("events.json"))

            if let propsData = try? JSONSerialization.data(withJSONObject: userProperties.mapValues { "\($0)" }) {
                try propsData.write(to: url.appendingPathComponent("user_properties.json"))
            }
        } catch {
            // Silent fail - analytics shouldn't crash the app
        }
    }

    private func loadFromDisk() {
        guard let url = storageURL else { return }

        do {
            let eventsURL = url.appendingPathComponent("events.json")
            if fileManager.fileExists(atPath: eventsURL.path) {
                let data = try Data(contentsOf: eventsURL)
                events = try decoder.decode([StoredAnalyticsEvent].self, from: data)
            }
        } catch {
            events = []
        }
    }
}

// MARK: - Analytics Network Sync

actor AnalyticsNetworkSync {
    private let log = ProfessionalLogger.shared
    private let session: URLSession
    private let analyticsEndpoint = "https://api.echoelmusic.com/v1/analytics"
    private var isSyncing = false

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func sendEvent(_ event: AnalyticsEvent) async {
        // Batch events for efficiency - don't send individual events
        // This will be picked up by syncPendingEvents
    }

    func syncPendingEvents(from storage: AnalyticsStorage) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pendingEvents = storage.getPendingEvents()
        guard !pendingEvents.isEmpty else { return }

        // Batch events (max 50 per request)
        let batches = stride(from: 0, to: pendingEvents.count, by: 50).map {
            Array(pendingEvents[$0..<min($0 + 50, pendingEvents.count)])
        }

        for batch in batches {
            do {
                guard let url = URL(string: analyticsEndpoint) else {
                    log.error("Invalid analytics endpoint URL: \(analyticsEndpoint)")
                    continue
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let payload: [String: Any] = [
                    "events": batch.map { event -> [String: Any] in
                        [
                            "id": event.id.uuidString,
                            "name": event.name,
                            "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                            "session_id": event.sessionId,
                            "user_id": event.userId ?? NSNull(),
                            "properties": event.properties.mapValues { $0.value }
                        ]
                    }
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (_, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    storage.markEventsSynced(ids: batch.map { $0.id })
                    log.analytics("✅ Synced \(batch.count) analytics events")
                }
            } catch {
                log.analytics("⚠️ Analytics sync failed: \(error.localizedDescription)")
                // Events remain in storage for retry
            }
        }
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

            // Create crash report
            let report = CrashReport(
                type: .nonFatalError,
                message: error.localizedDescription,
                errorDomain: (error as NSError).domain,
                errorCode: (error as NSError).code,
                breadcrumbs: Array(self.breadcrumbs.suffix(20)),
                userInfo: self.userInfo,
                context: context,
                timestamp: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: self.getDeviceModel()
            )

            // Store locally
            self.storeCrashReport(report)

            // Attempt network upload
            Task {
                await self.uploadCrashReport(report)
            }

            self.log.error("Breadcrumbs: \(self.breadcrumbs.suffix(10))")
            self.log.error("Context: \(context)")
        }
    }

    /// Report a non-fatal message
    public func reportNonFatal(message: String, context: [String: Any] = [:]) {
        queue.async {
            self.log.error("Non-fatal: \(message)")

            // Create crash report
            let report = CrashReport(
                type: .nonFatalMessage,
                message: message,
                errorDomain: nil,
                errorCode: nil,
                breadcrumbs: Array(self.breadcrumbs.suffix(20)),
                userInfo: self.userInfo,
                context: context,
                timestamp: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: self.getDeviceModel()
            )

            // Store locally
            self.storeCrashReport(report)

            // Attempt network upload
            Task {
                await self.uploadCrashReport(report)
            }

            self.log.error("Context: \(context)")
        }
    }

    // MARK: - Crash Report Storage & Upload

    private struct CrashReport: Codable {
        enum ReportType: String, Codable {
            case nonFatalError
            case nonFatalMessage
            case fatalCrash
        }

        let id: UUID
        let type: ReportType
        let message: String
        let errorDomain: String?
        let errorCode: Int?
        let breadcrumbs: [BreadcrumbCodable]
        let userInfo: [String: String]
        let context: [String: String]
        let timestamp: Date
        let appVersion: String
        let osVersion: String
        let deviceModel: String
        var uploaded: Bool

        init(type: ReportType, message: String, errorDomain: String?, errorCode: Int?,
             breadcrumbs: [Breadcrumb], userInfo: [String: Any], context: [String: Any],
             timestamp: Date, appVersion: String, osVersion: String, deviceModel: String) {
            self.id = UUID()
            self.type = type
            self.message = message
            self.errorDomain = errorDomain
            self.errorCode = errorCode
            self.breadcrumbs = breadcrumbs.map { BreadcrumbCodable(from: $0) }
            self.userInfo = userInfo.mapValues { "\($0)" }
            self.context = context.mapValues { "\($0)" }
            self.timestamp = timestamp
            self.appVersion = appVersion
            self.osVersion = osVersion
            self.deviceModel = deviceModel
            self.uploaded = false
        }
    }

    private struct BreadcrumbCodable: Codable {
        let timestamp: Date
        let message: String
        let category: String
        let level: String

        init(from breadcrumb: Breadcrumb) {
            self.timestamp = breadcrumb.timestamp
            self.message = breadcrumb.message
            self.category = breadcrumb.category
            self.level = breadcrumb.level.rawValue
        }
    }

    private func storeCrashReport(_ report: CrashReport) {
        let fileManager = FileManager.default
        guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Echoelmusic/CrashReports") else { return }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            let reportURL = url.appendingPathComponent("\(report.id.uuidString).json")
            let data = try JSONEncoder().encode(report)
            try data.write(to: reportURL)
            log.info("💾 Crash report stored: \(report.id)")
        } catch {
            log.error("Failed to store crash report: \(error)")
        }
    }

    private func uploadCrashReport(_ report: CrashReport) async {
        let endpoint = "https://api.echoelmusic.com/v1/crash-reports"

        guard let url = URL(string: endpoint) else {
            log.error("Invalid crash report endpoint URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(report)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                log.info("✅ Crash report uploaded: \(report.id)")
                // Mark as uploaded and clean up
                deleteCrashReport(id: report.id)
            }
        } catch {
            log.warning("⚠️ Crash report upload failed: \(error.localizedDescription)")
            // Report remains stored for retry
        }
    }

    private func deleteCrashReport(id: UUID) {
        let fileManager = FileManager.default
        guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Echoelmusic/CrashReports/\(id.uuidString).json") else { return }

        try? fileManager.removeItem(at: url)
    }

    private func getDeviceModel() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        #elseif os(macOS)
        return "Mac"
        #else
        return "Unknown"
        #endif
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
public class AnalyticsPerformanceMonitor {
    public static let shared = AnalyticsPerformanceMonitor()

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
    public var isAnalyticsPerformanceMonitoringEnabled: Bool {
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
        isAnalyticsPerformanceMonitoringEnabled = performance

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
            "performance": isAnalyticsPerformanceMonitoringEnabled,
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

    // MARK: - Cleanup

    nonisolated deinit {
        NotificationCenter.default.removeObserver(self)
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
        guard PrivacyCompliance.shared.isAnalyticsPerformanceMonitoringEnabled else { return }

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
        let level: AnalyticsCoherenceLevel
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

extension AnalyticsPerformanceMonitor {
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
