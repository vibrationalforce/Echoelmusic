import Foundation
import os.log

// =============================================================================
// UNIFIED LOGGER - Backward Compatibility Layer
// =============================================================================
// This file provides backward compatibility with the old Logger enum API
// while delegating to ProfessionalLogger (log singleton) for implementation.
//
// Usage:
//   Logger.debug("message")     // Old API (still works)
//   log.debug("message")        // New API (preferred)
//
// Migration: Replace Logger.X() calls with log.X() for new code.
// The ProfessionalLogger provides: file logging, log storage, category filtering.
// =============================================================================

/// Legacy Logger API - backward compatibility layer
/// All methods delegate to ProfessionalLogger.shared (accessed via `log`)
public enum Logger {

    // MARK: - Legacy Types (kept for compatibility)

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

        fileprivate var toCategory: LogCategory {
            switch self {
            case .audio: return .audio
            case .midi: return .midi
            case .healthKit: return .biofeedback
            case .spatial: return .spatial
            case .visual: return .ui
            case .led: return .led
            case .control: return .system
            case .export: return .recording
            case .network: return .network
            case .general: return .system
            }
        }
    }

    // MARK: - Delegating Methods

    public static func debug(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log.debug(message, category: subsystem.toCategory, file: file, line: line)
    }

    public static func info(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log.info(message, category: subsystem.toCategory, file: file, line: line)
    }

    public static func success(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log.notice(message, category: subsystem.toCategory, file: file, line: line)
    }

    public static func warning(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log.warning(message, category: subsystem.toCategory, file: file, line: line)
    }

    public static func error(_ message: String, subsystem: Subsystem = .general, file: String = #file, line: Int = #line) {
        log.error(message, category: subsystem.toCategory, file: file, line: line)
    }

    public static func audio(_ message: String, file: String = #file, line: Int = #line) {
        log.audio(message, file: file, line: line)
    }

    public static func midi(_ message: String, file: String = #file, line: Int = #line) {
        log.midi(message, file: file, line: line)
    }

    public static func bio(_ message: String, file: String = #file, line: Int = #line) {
        log.biofeedback(message, file: file, line: line)
    }

    public static func spatial(_ message: String, file: String = #file, line: Int = #line) {
        log.spatial(message, file: file, line: line)
    }

    public static func visual(_ message: String, file: String = #file, line: Int = #line) {
        log.info(message, category: .ui, file: file, line: line)
    }

    public static func performance(_ message: String, file: String = #file, line: Int = #line) {
        log.performance(message, file: file, line: line)
    }

    // MARK: - Performance Measurement

    @discardableResult
    public static func measure<T>(_ label: String, block: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        log.performance("\(label): \(String(format: "%.2f", duration))ms")
        return result
        #else
        return try block()
        #endif
    }

    public static func measureAsync<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        log.performance("\(label): \(String(format: "%.2f", duration))ms")
        return result
        #else
        return try await block()
        #endif
    }
}

// MARK: - Rate-Limited Logging

extension Logger {
    private static var lastControlLogTime: CFAbsoluteTime = 0

    public static func controlLoop(_ message: String) {
        #if DEBUG
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastControlLogTime > 1.0 {
            log.debug(message, category: .system)
            lastControlLogTime = now
        }
        #endif
    }
}

// MARK: - Analytics Stub Extension

extension EchoelCore.Lambda.Logger {
    /// Analytics event logging (Firebase stub)
    /// TODO: Replace with Firebase Analytics SDK
    public func analytics(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        self.log(.debug, category: .business, "📊 [Analytics] \(message)", file: file, function: function, line: line)
        #endif
    }
}
