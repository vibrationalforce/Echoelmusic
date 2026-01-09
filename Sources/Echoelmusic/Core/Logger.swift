import Foundation
import os.log

/// Centralized logging utility for Echoelmusic
/// Provides structured, conditional logging with emoji prefixes
/// Only logs in DEBUG builds to avoid production overhead
public enum Logger {

    // MARK: - Log Levels

    public enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case audio = "🎵"
        case midi = "🎹"
        case bio = "🫀"
        case spatial = "🌐"
        case visual = "🎨"
        case performance = "⚡"
    }

    // MARK: - Subsystems

    public enum Subsystem: String {
        case audio = "Audio"
        case midi = "MIDI"
        case healthKit = "HealthKit"
        case spatial = "Spatial"
        case visual = "Visual"
        case led = "LED"
        case control = "Control"
        case export = "Export"
        case network = "Network"
        case general = "General"
    }

    // MARK: - Private Properties

    private static let osLog = OSLog(subsystem: "com.echoelmusic", category: "App")

    // MARK: - Public Methods

    /// Log a debug message (only in DEBUG builds)
    public static func debug(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, subsystem: subsystem, file: file, line: line)
        #endif
    }

    /// Log an info message
    public static func info(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .info, subsystem: subsystem, file: file, line: line)
        #endif
    }

    /// Log a success message
    public static func success(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .success, subsystem: subsystem, file: file, line: line)
        #endif
    }

    /// Log a warning message
    public static func warning(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .warning, subsystem: subsystem, file: file, line: line)
        os_log(.info, log: osLog, "⚠️ %{public}@", message)
        #endif
    }

    /// Log an error message (always logs, even in release)
    public static func error(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log(message, level: .error, subsystem: subsystem, file: file, line: line)
        os_log(.error, log: osLog, "❌ %{public}@", message)
    }

    /// Log an audio-related message
    public static func audio(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .audio, subsystem: .audio, file: file, line: line)
        #endif
    }

    /// Log a MIDI-related message
    public static func midi(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .midi, subsystem: .midi, file: file, line: line)
        #endif
    }

    /// Log a biofeedback-related message
    public static func bio(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .bio, subsystem: .healthKit, file: file, line: line)
        #endif
    }

    /// Log a spatial audio message
    public static func spatial(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .spatial, subsystem: .spatial, file: file, line: line)
        #endif
    }

    /// Log a visual/rendering message
    public static func visual(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .visual, subsystem: .visual, file: file, line: line)
        #endif
    }

    /// Log a performance metric
    public static func performance(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        log(message, level: .performance, subsystem: .general, file: file, line: line)
        #endif
    }

    // MARK: - Private Methods

    private static func log(_ message: String, level: Level, subsystem: Subsystem, file: String, line: Int) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
        print("\(level.rawValue) [\(subsystem.rawValue)] \(message)")
        // Verbose mode with file/line (uncomment for debugging):
        // print("\(level.rawValue) [\(subsystem.rawValue)] \(filename):\(line) - \(message)")
        #endif
    }

    // MARK: - Performance Measurement

    /// Measure execution time of a block
    @discardableResult
    public static func measure<T>(_ label: String, block: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()
        let duration = (end - start) * 1000 // Convert to milliseconds
        performance("\(label): \(String(format: "%.2f", duration))ms")
        return result
        #else
        return try block()
        #endif
    }

    /// Measure async execution time
    public static func measureAsync<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let end = CFAbsoluteTimeGetCurrent()
        let duration = (end - start) * 1000
        performance("\(label): \(String(format: "%.2f", duration))ms")
        return result
        #else
        return try await block()
        #endif
    }
}

// MARK: - Convenience Extensions

extension Logger {

    /// Log control loop tick (rate limited to avoid spam)
    private static var lastControlLogTime: CFAbsoluteTime = 0

    public static func controlLoop(_ message: String) {
        #if DEBUG
        let now = CFAbsoluteTimeGetCurrent()
        // Only log once per second to avoid spam
        if now - lastControlLogTime > 1.0 {
            log(message, level: .info, subsystem: .control, file: #file, line: #line)
            lastControlLogTime = now
        }
        #endif
    }
}
