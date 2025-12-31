import Foundation
import os.log

// MARK: - Debug Logger
// Replaces 943 print() statements with conditional logging
// Ralph Wiggum Mode: "My cat's breath smells like cat food!" 🚒

/// Production-safe logging system
/// All logs are stripped from release builds
public enum EchoelLog {

    // MARK: - Log Categories

    private static let subsystem = "com.echoel.echoelmusic"

    private static let audioLog = OSLog(subsystem: subsystem, category: "Audio")
    private static let healthLog = OSLog(subsystem: subsystem, category: "HealthKit")
    private static let networkLog = OSLog(subsystem: subsystem, category: "Network")
    private static let uiLog = OSLog(subsystem: subsystem, category: "UI")
    private static let generalLog = OSLog(subsystem: subsystem, category: "General")

    public enum Category {
        case audio
        case health
        case network
        case ui
        case general

        var osLog: OSLog {
            switch self {
            case .audio: return EchoelLog.audioLog
            case .health: return EchoelLog.healthLog
            case .network: return EchoelLog.networkLog
            case .ui: return EchoelLog.uiLog
            case .general: return EchoelLog.generalLog
            }
        }
    }

    // MARK: - Log Levels

    /// Debug log - Only in DEBUG builds
    @inlinable
    public static func debug(_ message: @autoclosure () -> String, category: Category = .general, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        os_log(.debug, log: category.osLog, "%{public}@ [%{public}@:%{public}d]", message(), fileName, line)
        #endif
    }

    /// Info log - Important operational information
    @inlinable
    public static func info(_ message: @autoclosure () -> String, category: Category = .general) {
        #if DEBUG
        os_log(.info, log: category.osLog, "%{public}@", message())
        #endif
    }

    /// Warning log - Potential issues
    @inlinable
    public static func warning(_ message: @autoclosure () -> String, category: Category = .general) {
        #if DEBUG
        os_log(.default, log: category.osLog, "⚠️ %{public}@", message())
        #endif
    }

    /// Error log - Errors (also logged in release for crash reporting)
    @inlinable
    public static func error(_ message: @autoclosure () -> String, category: Category = .general, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        os_log(.error, log: category.osLog, "❌ %{public}@ [%{public}@:%{public}d]", message(), fileName, line)
    }

    /// Success log - Successful operations
    @inlinable
    public static func success(_ message: @autoclosure () -> String, category: Category = .general) {
        #if DEBUG
        os_log(.info, log: category.osLog, "✅ %{public}@", message())
        #endif
    }

    // MARK: - Convenience Methods for Common Patterns

    /// Audio system log
    @inlinable
    public static func audio(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: audioLog, "🎵 %{public}@", message())
        #endif
    }

    /// HealthKit log
    @inlinable
    public static func health(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: healthLog, "💓 %{public}@", message())
        #endif
    }

    /// Network/Streaming log
    @inlinable
    public static func network(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: networkLog, "📡 %{public}@", message())
        #endif
    }

    /// UI log
    @inlinable
    public static func ui(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: uiLog, "🖼️ %{public}@", message())
        #endif
    }

    // MARK: - Performance Measurement

    /// Measure execution time of a block
    @inlinable
    public static func measure<T>(_ label: String, category: Category = .general, block: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        os_log(.debug, log: category.osLog, "⏱️ %{public}@: %.2fms", label, elapsed)
        return result
        #else
        return try block()
        #endif
    }

    /// Async version of measure
    @inlinable
    public static func measureAsync<T>(_ label: String, category: Category = .general, block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        os_log(.debug, log: category.osLog, "⏱️ %{public}@: %.2fms", label, elapsed)
        return result
        #else
        return try await block()
        #endif
    }
}

// MARK: - Global Convenience Function

/// Quick debug print - completely stripped from release builds
@inlinable
public func debugLog(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] \(message())")
    #endif
}

/// Quick debug print with emoji category
@inlinable
public func debugLog(_ emoji: String, _ message: @autoclosure () -> String) {
    #if DEBUG
    print("\(emoji) \(message())")
    #endif
}

// MARK: - Assertion Helpers

/// Debug-only assertion with message
@inlinable
public func debugAssert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
    #if DEBUG
    if !condition() {
        let fileName = (file as NSString).lastPathComponent
        EchoelLog.error("Assertion failed: \(message())", file: file, line: line)
        assertionFailure(message(), file: file, line: UInt(line))
    }
    #endif
}

// MARK: - Memory Debugging

#if DEBUG
public enum MemoryDebug {

    /// Log current memory usage
    public static func logMemoryUsage(label: String = "") {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            print("🧠 Memory \(label): \(String(format: "%.2f", usedMB)) MB")
        }
    }

    /// Track object allocation/deallocation
    public static func trackObject(_ object: AnyObject, label: String) {
        print("📦 Allocated: \(label) [\(Unmanaged.passUnretained(object).toOpaque())]")
    }
}
#endif

// MARK: - Thread Safety Debugging

#if DEBUG
public enum ThreadDebug {

    /// Assert we're on the main thread
    @inlinable
    public static func assertMainThread(file: String = #file, line: Int = #line) {
        assert(Thread.isMainThread, "Expected main thread at \(file):\(line)")
    }

    /// Assert we're NOT on the main thread
    @inlinable
    public static func assertBackgroundThread(file: String = #file, line: Int = #line) {
        assert(!Thread.isMainThread, "Expected background thread at \(file):\(line)")
    }

    /// Log current thread info
    public static func logThread(label: String = "") {
        let thread = Thread.current
        let isMain = thread.isMainThread
        let name = thread.name ?? "unnamed"
        print("🧵 Thread \(label): \(isMain ? "MAIN" : name)")
    }
}
#endif
