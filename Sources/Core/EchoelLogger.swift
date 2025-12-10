//
//  EchoelLogger.swift
//  Echoelmusic
//
//  Centralized logging system for Echoelmusic - Swift implementation
//  Replaces scattered print() calls with structured, configurable logging
//
//  Usage:
//    EchoelLogger.info("AudioEngine", "Buffer size: \(bufferSize)")
//    EchoelLogger.error("MIDI", "Connection failed: \(error)")
//    EchoelLogger.debug("DSP", "Processing latency: \(latency)ms")
//    EchoelLogger.perf("Compressor") { /* measured operation */ }
//

import Foundation
import os.log

// MARK: - Log Level

public enum EchoelLogLevel: Int, Comparable {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
    case all = 6

    public static func < (lhs: EchoelLogLevel, rhs: EchoelLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .none: return ""
        case .error: return "🔴"
        case .warning: return "🟡"
        case .info: return "🔵"
        case .debug: return "🟢"
        case .verbose: return "⚪"
        case .all: return "⚪"
        }
    }

    var label: String {
        switch self {
        case .none: return ""
        case .error: return "ERROR"
        case .warning: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .verbose: return "VERBOSE"
        case .all: return "ALL"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .none: return .default
        case .error: return .error
        case .warning: return .fault
        case .info: return .info
        case .debug: return .debug
        case .verbose, .all: return .debug
        }
    }
}

// MARK: - Logger Configuration

public struct EchoelLoggerConfig {
    public var level: EchoelLogLevel = .info
    public var includeTimestamp: Bool = true
    public var includeComponent: Bool = true
    public var includeEmoji: Bool = true
    public var useOSLog: Bool = true
    public var consoleOutput: Bool = true
    public var fileOutput: Bool = false
    public var logFilePath: String = ""

    public init() {}
}

// MARK: - EchoelLogger

public final class EchoelLogger {
    public static let shared = EchoelLogger()

    private var config = EchoelLoggerConfig()
    private let queue = DispatchQueue(label: "com.echoelmusic.logger", qos: .utility)
    private var osLoggers: [String: OSLog] = [:]
    private let loggersLock = NSLock()

    private init() {
        // Set default level based on build configuration
        #if DEBUG
        config.level = .debug
        #else
        config.level = .info
        #endif
    }

    // MARK: - Configuration

    public func configure(_ config: EchoelLoggerConfig) {
        self.config = config
    }

    public func setLogLevel(_ level: EchoelLogLevel) {
        config.level = level
    }

    public var currentLevel: EchoelLogLevel {
        return config.level
    }

    // MARK: - Core Logging

    public func log(
        _ level: EchoelLogLevel,
        _ component: String,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level <= config.level else { return }

        let msg = message()
        let formattedMessage = formatMessage(level: level, component: component, message: msg)

        if config.useOSLog {
            let logger = getOSLog(for: component)
            os_log("%{public}@", log: logger, type: level.osLogType, formattedMessage)
        }

        if config.consoleOutput {
            queue.async {
                print(formattedMessage)
            }
        }

        if config.fileOutput && !config.logFilePath.isEmpty {
            queue.async { [weak self] in
                self?.writeToFile(formattedMessage)
            }
        }
    }

    // MARK: - Convenience Methods

    public static func error(_ component: String, _ message: @autoclosure () -> String) {
        shared.log(.error, component, message())
    }

    public static func warning(_ component: String, _ message: @autoclosure () -> String) {
        shared.log(.warning, component, message())
    }

    public static func info(_ component: String, _ message: @autoclosure () -> String) {
        shared.log(.info, component, message())
    }

    public static func debug(_ component: String, _ message: @autoclosure () -> String) {
        shared.log(.debug, component, message())
    }

    public static func verbose(_ component: String, _ message: @autoclosure () -> String) {
        shared.log(.verbose, component, message())
    }

    // MARK: - Performance Logging

    /// Measure and log execution time of a closure
    @discardableResult
    public static func perf<T>(_ component: String, _ operation: String, _ block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if shared.config.level >= .debug {
            shared.log(.debug, component, "[PERF] \(operation) completed in \(String(format: "%.2f", elapsed))ms")
        }

        return result
    }

    /// Async performance measurement
    @discardableResult
    public static func perfAsync<T>(_ component: String, _ operation: String, _ block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if shared.config.level >= .debug {
            shared.log(.debug, component, "[PERF] \(operation) completed in \(String(format: "%.2f", elapsed))ms")
        }

        return result
    }

    // MARK: - Audio Thread Safe Logging

    /// Non-blocking log for audio thread - drops message if queue is busy
    public static func audioThread(_ component: String, _ message: @autoclosure () -> String) {
        guard shared.config.level >= .verbose else { return }

        // Use tryLock pattern for audio thread safety
        let msg = message()
        DispatchQueue.main.async {
            shared.log(.verbose, component, "[AUDIO] \(msg)")
        }
    }

    // MARK: - Private Helpers

    private func formatMessage(level: EchoelLogLevel, component: String, message: String) -> String {
        var parts: [String] = []

        if config.includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            parts.append("[\(formatter.string(from: Date()))]")
        }

        if config.includeEmoji {
            parts.append(level.emoji)
        }

        parts.append(level.label.padding(toLength: 7, withPad: " ", startingAt: 0))

        if config.includeComponent && !component.isEmpty {
            parts.append("[\(component)]")
        }

        parts.append(message)

        return parts.joined(separator: " ")
    }

    private func getOSLog(for component: String) -> OSLog {
        loggersLock.lock()
        defer { loggersLock.unlock() }

        if let logger = osLoggers[component] {
            return logger
        }

        let logger = OSLog(subsystem: "com.echoelmusic", category: component)
        osLoggers[component] = logger
        return logger
    }

    private func writeToFile(_ message: String) {
        guard !config.logFilePath.isEmpty else { return }

        let url = URL(fileURLWithPath: config.logFilePath)
        let messageWithNewline = message + "\n"

        if let data = messageWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: config.logFilePath) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Convenience Global Functions

/// Quick logging functions for common use
public func logError(_ component: String, _ message: @autoclosure () -> String) {
    EchoelLogger.error(component, message())
}

public func logWarning(_ component: String, _ message: @autoclosure () -> String) {
    EchoelLogger.warning(component, message())
}

public func logInfo(_ component: String, _ message: @autoclosure () -> String) {
    EchoelLogger.info(component, message())
}

public func logDebug(_ component: String, _ message: @autoclosure () -> String) {
    EchoelLogger.debug(component, message())
}

// MARK: - Performance Timer

/// RAII-style performance timer for measuring scope duration
public final class ScopedPerfTimer {
    private let component: String
    private let operation: String
    private let startTime: CFAbsoluteTime

    public init(_ component: String, _ operation: String) {
        self.component = component
        self.operation = operation
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    deinit {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        if EchoelLogger.shared.currentLevel >= .debug {
            EchoelLogger.debug(component, "[PERF] \(operation) completed in \(String(format: "%.2f", elapsed))ms")
        }
    }
}

// MARK: - Debug-Only Logging

#if DEBUG
public func debugLog(_ component: String, _ message: @autoclosure () -> String) {
    EchoelLogger.debug(component, message())
}
#else
@inlinable
public func debugLog(_ component: String, _ message: @autoclosure () -> String) {
    // No-op in release builds
}
#endif
