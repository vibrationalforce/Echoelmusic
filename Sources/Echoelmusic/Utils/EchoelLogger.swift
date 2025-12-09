import Foundation
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC UNIFIED LOGGING SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Centralized logging for consistent debugging and monitoring across the app.
// Uses Apple's unified logging system (os.log) for optimal performance.
//
// Usage:
//   EchoelLogger.audio.info("Audio engine started")
//   EchoelLogger.bio.error("HealthKit not available")
//   EchoelLogger.dsp.debug("Processing \(samples) samples")
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized logging system for Echoelmusic
/// Provides category-specific loggers for different subsystems
public enum EchoelLogger {

    // MARK: - Subsystem Identifier

    private static let subsystem = "com.echoelmusic"

    // MARK: - Category Loggers

    /// Logger for audio engine and playback
    public static let audio = Logger(subsystem: subsystem, category: "Audio")

    /// Logger for biofeedback and HealthKit
    public static let bio = Logger(subsystem: subsystem, category: "Biofeedback")

    /// Logger for DSP and signal processing
    public static let dsp = Logger(subsystem: subsystem, category: "DSP")

    /// Logger for MIDI operations
    public static let midi = Logger(subsystem: subsystem, category: "MIDI")

    /// Logger for visualization and rendering
    public static let visual = Logger(subsystem: subsystem, category: "Visual")

    /// Logger for self-healing engine
    public static let healing = Logger(subsystem: subsystem, category: "SelfHealing")

    /// Logger for network and sync operations
    public static let network = Logger(subsystem: subsystem, category: "Network")

    /// Logger for performance monitoring
    public static let performance = Logger(subsystem: subsystem, category: "Performance")

    /// Logger for memory management
    public static let memory = Logger(subsystem: subsystem, category: "Memory")

    /// Logger for user interface
    public static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Logger for general app operations
    public static let app = Logger(subsystem: subsystem, category: "App")

    /// Logger for quantum intelligence features
    public static let quantum = Logger(subsystem: subsystem, category: "Quantum")

    /// Logger for hardware integration
    public static let hardware = Logger(subsystem: subsystem, category: "Hardware")

    /// Logger for recording and export
    public static let recording = Logger(subsystem: subsystem, category: "Recording")

    /// Logger for testing and debugging
    public static let debug = Logger(subsystem: subsystem, category: "Debug")

    // MARK: - Convenience Methods

    /// Log a milestone event (visible in Console.app with special formatting)
    public static func milestone(_ message: String) {
        app.notice("🏁 MILESTONE: \(message)")
    }

    /// Log a performance metric
    public static func metric(_ name: String, value: Double, unit: String = "ms") {
        performance.info("📊 \(name): \(value, format: .fixed(precision: 2)) \(unit)")
    }

    /// Log memory usage
    public static func memoryUsage(_ bytes: UInt64) {
        let mb = Double(bytes) / 1_048_576.0
        memory.info("💾 Memory: \(mb, format: .fixed(precision: 2)) MB")
    }

    /// Log an error with context
    public static func error(_ message: String, error: Error, logger: Logger = app) {
        logger.error("❌ \(message): \(error.localizedDescription)")
    }

    /// Log a warning with context
    public static func warning(_ message: String, logger: Logger = app) {
        logger.warning("⚠️ \(message)")
    }

    /// Log a success message
    public static func success(_ message: String, logger: Logger = app) {
        logger.info("✅ \(message)")
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Debug-only logging (stripped in release builds)
    public static func debugLog(_ message: String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        debug.debug("🔍 [\(filename):\(line)] \(message)")
    }
    #else
    /// No-op in release builds
    @inlinable
    public static func debugLog(_ message: String, file: String = #file, line: Int = #line) {
        // Intentionally empty in release builds
    }
    #endif
}

// MARK: - Performance Timing Helper

/// Helper class for measuring performance
public class PerformanceTimer {
    private let name: String
    private let startTime: CFAbsoluteTime
    private let logger: Logger

    public init(name: String, logger: Logger = EchoelLogger.performance) {
        self.name = name
        self.logger = logger
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    /// Stop the timer and log the elapsed time
    public func stop() {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
        logger.info("⏱️ \(self.name): \(elapsed, format: .fixed(precision: 2)) ms")
    }

    /// Stop the timer and return the elapsed time in milliseconds
    @discardableResult
    public func stopAndReturn() -> Double {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("⏱️ \(self.name): \(elapsed, format: .fixed(precision: 2)) ms")
        return elapsed
    }
}

// MARK: - Usage Example
/*
 // In your code:

 // Category-specific logging
 EchoelLogger.audio.info("Audio engine started")
 EchoelLogger.bio.error("HealthKit authorization failed")
 EchoelLogger.dsp.debug("Processing buffer with \(samples) samples")

 // Convenience methods
 EchoelLogger.milestone("App launch complete")
 EchoelLogger.metric("FFT Processing", value: 2.5, unit: "ms")
 EchoelLogger.error("Failed to load", error: someError)

 // Performance timing
 let timer = PerformanceTimer(name: "FFT Analysis")
 // ... do work ...
 timer.stop() // Logs: "⏱️ FFT Analysis: 1.23 ms"

 // Debug-only logging (automatically stripped in release)
 EchoelLogger.debugLog("This only appears in debug builds")
*/
