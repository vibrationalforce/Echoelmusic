// Logger.swift
// Echoelmusic - Structured Logging Infrastructure
// Wise Mode Implementation

import Foundation
import os.log

// MARK: - Log Categories

/// Categories for structured logging across the application
public enum LogCategory: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case visual = "Visual"
    case spatial = "Spatial"
    case biofeedback = "Bio"
    case performance = "Perf"
    case network = "Network"
    case led = "LED"
    case recording = "Recording"
    case video = "Video"
    case system = "System"
    case ui = "UI"
    case security = "Security"
    case export = "Export"
    case social = "Social"
    case cloud = "Cloud"
    case privacy = "Privacy"
    case business = "Business"
    case integration = "Integration"
    case accessibility = "A11y"
}

// MARK: - Log Level

/// Log levels with severity ordering
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "[DEBUG]"
        case .info: return "[INFO]"
        case .warning: return "[WARN]"
        case .error: return "[ERROR]"
        case .critical: return "[CRITICAL]"
        }
    }
}

// MARK: - Logger

/// Centralized logging system with structured output and performance signposts
@MainActor
public final class Logger {

    // MARK: - Properties

    private static let subsystem = "com.echoelmusic"

    /// Minimum log level to output (configurable)
    public static var minimumLevel: LogLevel = .debug

    /// Enable console output (disable in production for performance)
    public static var consoleOutputEnabled: Bool = true

    /// Log history for debugging (limited buffer)
    private static var logHistory: [LogEntry] = []
    private static let maxHistorySize = 1000

    // MARK: - Log Entry

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let level: LogLevel
        public let category: LogCategory
        public let message: String
        public let file: String
        public let function: String
        public let line: Int
        public let error: Error?

        var formattedMessage: String {
            let fileName = (file as NSString).lastPathComponent
            return "\(level.emoji) [\(category.rawValue)] \(message) (\(fileName):\(line))"
        }
    }

    // MARK: - Logging Methods

    /// Log a debug message
    public static func debug(
        _ message: String,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    /// Log an info message
    public static func info(
        _ message: String,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    /// Log a warning message
    public static func warning(
        _ message: String,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    /// Log an error message
    public static func error(
        _ message: String,
        category: LogCategory,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, category: category, error: error, file: file, function: function, line: line)
    }

    /// Log a critical message
    public static func critical(
        _ message: String,
        category: LogCategory,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, message: message, category: category, error: error, file: file, function: function, line: line)
    }

    // MARK: - Core Log Method

    private static func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        error: Error? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= minimumLevel else { return }

        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            error: error
        )

        // Add to history
        logHistory.append(entry)
        if logHistory.count > maxHistorySize {
            logHistory.removeFirst()
        }

        // OS Log output
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        if let error = error {
            os_log("%{public}@: %{public}@", log: log, type: level.osLogType, message, error.localizedDescription)
        } else {
            os_log("%{public}@", log: log, type: level.osLogType, message)
        }

        // Console output (development)
        #if DEBUG
        if consoleOutputEnabled {
            var output = entry.formattedMessage
            if let error = error {
                output += " - Error: \(error.localizedDescription)"
            }
            print(output)
        }
        #endif
    }

    // MARK: - Performance Signposts

    /// Create a signposter for performance measurements
    public static func signposter(for category: LogCategory) -> OSSignposter {
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        return OSSignposter(logHandle: log)
    }

    /// Measure execution time of a block
    public static func measure<T>(
        _ name: StaticString,
        category: LogCategory,
        block: () throws -> T
    ) rethrows -> T {
        let signposter = signposter(for: category)
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try block()
    }

    /// Async measure execution time
    public static func measureAsync<T>(
        _ name: StaticString,
        category: LogCategory,
        block: () async throws -> T
    ) async rethrows -> T {
        let signposter = signposter(for: category)
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try await block()
    }

    // MARK: - History Access

    /// Get recent log entries
    public static func getHistory(level: LogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        var filtered = logHistory

        if let level = level {
            filtered = filtered.filter { $0.level >= level }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        return filtered
    }

    /// Clear log history
    public static func clearHistory() {
        logHistory.removeAll()
    }

    /// Export logs as string
    public static func exportLogs() -> String {
        let formatter = ISO8601DateFormatter()
        return logHistory.map { entry in
            let timestamp = formatter.string(from: entry.timestamp)
            var line = "\(timestamp) \(entry.formattedMessage)"
            if let error = entry.error {
                line += " - Error: \(error.localizedDescription)"
            }
            return line
        }.joined(separator: "\n")
    }
}

// MARK: - Convenience Extensions

extension Logger {

    /// Log audio-specific message
    public static func audio(_ message: String, level: LogLevel = .debug) {
        switch level {
        case .debug: debug(message, category: .audio)
        case .info: info(message, category: .audio)
        case .warning: warning(message, category: .audio)
        case .error: error(message, category: .audio)
        case .critical: critical(message, category: .audio)
        }
    }

    /// Log MIDI-specific message
    public static func midi(_ message: String, level: LogLevel = .debug) {
        switch level {
        case .debug: debug(message, category: .midi)
        case .info: info(message, category: .midi)
        case .warning: warning(message, category: .midi)
        case .error: error(message, category: .midi)
        case .critical: critical(message, category: .midi)
        }
    }

    /// Log performance metric
    public static func perf(_ message: String, level: LogLevel = .debug) {
        switch level {
        case .debug: debug(message, category: .performance)
        case .info: info(message, category: .performance)
        case .warning: warning(message, category: .performance)
        case .error: error(message, category: .performance)
        case .critical: critical(message, category: .performance)
        }
    }

    /// Log visual/rendering message
    public static func visual(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .visual, file: #file, function: #function, line: #line)
    }

    /// Log biofeedback message
    public static func bio(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .biofeedback, file: #file, function: #function, line: #line)
    }

    /// Log network message
    public static func network(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .network, file: #file, function: #function, line: #line)
    }

    /// Log recording message
    public static func recording(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .recording, file: #file, function: #function, line: #line)
    }

    /// Log video message
    public static func video(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .video, file: #file, function: #function, line: #line)
    }

    /// Log security message
    public static func security(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .security, file: #file, function: #function, line: #line)
    }

    /// Log export message
    public static func export(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .export, file: #file, function: #function, line: #line)
    }

    /// Log social/sharing message
    public static func social(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .social, file: #file, function: #function, line: #line)
    }

    /// Log cloud sync message
    public static func cloud(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .cloud, file: #file, function: #function, line: #line)
    }

    /// Log privacy message
    public static func privacy(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .privacy, file: #file, function: #function, line: #line)
    }

    /// Log business/subscription message
    public static func business(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .business, file: #file, function: #function, line: #line)
    }

    /// Log device integration message
    public static func integration(_ message: String, level: LogLevel = .info) {
        log(level: level, message: message, category: .integration, file: #file, function: #function, line: #line)
    }

    /// Log spatial audio message
    public static func spatial(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .spatial, file: #file, function: #function, line: #line)
    }

    /// Log UI message
    public static func ui(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .ui, file: #file, function: #function, line: #line)
    }

    /// Log system message
    public static func system(_ message: String, level: LogLevel = .info) {
        log(level: level, message: message, category: .system, file: #file, function: #function, line: #line)
    }

    /// Log LED message
    public static func led(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .led, file: #file, function: #function, line: #line)
    }

    /// Log accessibility message
    public static func a11y(_ message: String, level: LogLevel = .debug) {
        log(level: level, message: message, category: .accessibility, file: #file, function: #function, line: #line)
    }

    // MARK: - Emoji-free logging (production style)

    /// Log success message
    public static func success(_ message: String, category: LogCategory) {
        info("SUCCESS: \(message)", category: category)
    }

    /// Log failure message
    public static func failure(_ message: String, category: LogCategory, error: Error? = nil) {
        self.error("FAILURE: \(message)", category: category, error: error)
    }

    /// Log connection status
    public static func connected(_ device: String, category: LogCategory = .integration) {
        info("Connected: \(device)", category: category)
    }

    /// Log disconnection
    public static func disconnected(_ device: String, category: LogCategory = .integration) {
        info("Disconnected: \(device)", category: category)
    }

    /// Log initialization
    public static func initialized(_ component: String, category: LogCategory = .system) {
        info("Initialized: \(component)", category: category)
    }

    /// Log configuration
    public static func configured(_ setting: String, value: Any, category: LogCategory = .system) {
        debug("Configured \(setting) = \(value)", category: category)
    }
}
