// ProfessionalLogger.swift
// Echoelmusic - 10000% Ralph Wiggum Loop Mode
//
// Professional structured logging system
// Replaces all print() statements with proper logging
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import os.log

/// Typealias for backwards compatibility
public typealias ProfessionalLogger = EchoelLogger

// MARK: - Log Level

/// Log severity levels
public enum LogLevel: Int, Comparable, CaseIterable, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case notice = 3
    case warning = 4
    case error = 5
    case critical = 6

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var emoji: String {
        switch self {
        case .trace: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .notice: return "📢"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    public var osLogType: OSLogType {
        switch self {
        case .trace, .debug: return .debug
        case .info, .notice: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Log Category

/// Log categories for filtering
public enum LogCategory: String, CaseIterable, Sendable {
    case audio = "Audio"
    case video = "Video"
    case streaming = "Streaming"
    case biofeedback = "Biofeedback"
    case quantum = "Quantum"
    case lambda = "Lambda"
    case orchestral = "Orchestral"
    case midi = "MIDI"
    case network = "Network"
    case ui = "UI"
    case performance = "Performance"
    case accessibility = "Accessibility"
    case plugin = "Plugin"
    case system = "System"
    case collaboration = "Collaboration"
    case scoring = "Scoring"
    case hardware = "Hardware"
    case privacy = "Privacy"
    case recording = "Recording"
    case business = "Business"
    case automation = "Automation"
    case intelligence = "Intelligence"
    case spatial = "Spatial"
    case led = "LED"
    case social = "Social"
    case science = "Science"
    case wellness = "Wellness"
    case analytics = "Analytics"
    case ai = "AI"
    case biosync = "Biosync"

    public var osLog: OSLog {
        OSLog(subsystem: "com.echoelmusic", category: rawValue)
    }
}

// MARK: - Log Entry

/// A single log entry
public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let metadata: [String: String]

    public init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String,
        function: String,
        line: Int,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.metadata = metadata
    }

    public var formattedMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = dateFormatter.string(from: timestamp)

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        return "\(level.emoji) [\(timeString)] [\(category.rawValue)] \(message) (\(fileName):\(line))"
    }
}

// MARK: - Log Output

/// Log output destination
public protocol LogOutput: Sendable {
    func write(_ entry: LogEntry)
}

/// Console output
public final class ConsoleOutput: LogOutput, @unchecked Sendable {
    public static let shared = ConsoleOutput()

    public func write(_ entry: LogEntry) {
        #if DEBUG
        print(entry.formattedMessage)
        #endif

        // Also write to os_log
        os_log(
            "%{public}@",
            log: entry.category.osLog,
            type: entry.level.osLogType,
            entry.message
        )
    }
}

/// File output
public final class FileOutput: LogOutput, @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.echoelmusic.log.file")

    public init(fileName: String = "echoelmusic.log") {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsPath.appendingPathComponent(fileName)
    }

    public func write(_ entry: LogEntry) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let line = "\(entry.formattedMessage)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: self.fileURL)
                }
            }
        }
    }
}

// MARK: - Professional Logger

/// Main professional logging system (renamed from Logger to avoid os.log.Logger conflict)
public final class EchoelLogger: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = EchoelLogger()

    // MARK: - Properties

    public var minimumLevel: LogLevel = .debug
    public var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
    private var outputs: [any LogOutput] = [ConsoleOutput.shared]
    private let queue = DispatchQueue(label: "com.echoelmusic.logger", qos: .utility)

    // MARK: - In-Memory Log Storage

    private var entries: [LogEntry] = []
    private let maxEntries: Int = 10000

    // MARK: - Configuration

    /// Add output destination
    public func addOutput(_ output: any LogOutput) {
        outputs.append(output)
    }

    /// Enable file logging
    public func enableFileLogging(fileName: String = "echoelmusic.log") {
        addOutput(FileOutput(fileName: fileName))
    }

    /// Set minimum log level
    public func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    /// Enable specific categories only
    public func setEnabledCategories(_ categories: Set<LogCategory>) {
        enabledCategories = categories
    }

    // MARK: - Logging Methods

    /// Core logging method
    public func log(
        _ level: LogLevel,
        category: LogCategory,
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel else { return }
        guard enabledCategories.contains(category) else { return }

        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )

        queue.async { [weak self] in
            guard let self = self else { return }

            // Store entry
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }

            // Write to outputs
            for output in self.outputs {
                output.write(entry)
            }
        }
    }

    // MARK: - Convenience Methods

    public func trace(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.trace, category: category, message, file: file, function: function, line: line)
    }

    public func debug(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message, file: file, function: function, line: line)
    }

    public func info(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message, file: file, function: function, line: line)
    }

    public func notice(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.notice, category: category, message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message, file: file, function: function, line: line)
    }

    public func error(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message, file: file, function: function, line: line)
    }

    public func critical(_ message: String, category: LogCategory = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message, file: file, function: function, line: line)
    }

    // MARK: - Category-Specific Loggers

    public func audio(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .audio, message, file: file, function: function, line: line)
    }

    public func video(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .video, message, file: file, function: function, line: line)
    }

    public func streaming(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .streaming, message, file: file, function: function, line: line)
    }

    public func biofeedback(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .biofeedback, message, file: file, function: function, line: line)
    }

    public func quantum(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .quantum, message, file: file, function: function, line: line)
    }

    public func lambda(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .lambda, message, file: file, function: function, line: line)
    }

    public func orchestral(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .orchestral, message, file: file, function: function, line: line)
    }

    public func midi(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .midi, message, file: file, function: function, line: line)
    }

    public func network(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .network, message, file: file, function: function, line: line)
    }

    public func performance(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .performance, message, file: file, function: function, line: line)
    }

    public func scoring(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .scoring, message, file: file, function: function, line: line)
    }

    public func hardware(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .hardware, message, file: file, function: function, line: line)
    }

    public func privacy(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .privacy, message, file: file, function: function, line: line)
    }

    public func recording(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .recording, message, file: file, function: function, line: line)
    }

    public func business(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .business, message, file: file, function: function, line: line)
    }

    public func automation(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .automation, message, file: file, function: function, line: line)
    }

    public func intelligence(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .intelligence, message, file: file, function: function, line: line)
    }

    public func spatial(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .spatial, message, file: file, function: function, line: line)
    }

    public func led(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .led, message, file: file, function: function, line: line)
    }

    public func social(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .social, message, file: file, function: function, line: line)
    }

    public func science(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .science, message, file: file, function: function, line: line)
    }

    public func wellness(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .wellness, message, file: file, function: function, line: line)
    }

    public func accessibility(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .accessibility, message, file: file, function: function, line: line)
    }

    public func analytics(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .analytics, message, file: file, function: function, line: line)
    }

    public func ai(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, category: .ai, message, file: file, function: function, line: line)
    }

    // MARK: - Log Retrieval

    /// Get recent log entries
    public func getRecentEntries(count: Int = 100, level: LogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        var filtered = entries

        if let level = level {
            filtered = filtered.filter { $0.level >= level }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        return Array(filtered.suffix(count))
    }

    /// Export logs as string
    public func exportLogs(since: Date? = nil) -> String {
        var filtered = entries

        if let since = since {
            filtered = filtered.filter { $0.timestamp >= since }
        }

        return filtered.map { $0.formattedMessage }.joined(separator: "\n")
    }

    /// Clear all logs
    public func clear() {
        queue.async { [weak self] in
            self?.entries.removeAll()
        }
    }
}

// MARK: - Global Logger Access

/// Global logger instance
public let echoelLog = EchoelLogger.shared

/// Alias for backward compatibility (many files use 'log')
public let log = EchoelLogger.shared
