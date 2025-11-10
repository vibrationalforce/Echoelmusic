import SwiftUI
import os.log

/// Professional Debug Console for Echoelmusic
/// Real-time logging, error tracking, performance monitoring
/// Critical for testing and debugging during development
@MainActor
class DebugConsole: ObservableObject {

    // MARK: - Published Properties

    @Published var isVisible: Bool = false
    @Published var logs: [LogEntry] = []
    @Published var errors: [ErrorEntry] = []
    @Published var warnings: [WarningEntry] = []
    @Published var selectedTab: DebugTab = .logs
    @Published var filterLevel: LogLevel = .all
    @Published var searchQuery: String = ""
    @Published var performanceMetrics: PerformanceSnapshot = .empty

    // MARK: - Constants

    static let shared = DebugConsole()
    private let maxLogEntries = 10000
    private let maxErrorEntries = 1000

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic.debug", category: "console")

    // MARK: - Debug Tabs

    enum DebugTab: String, CaseIterable {
        case logs = "Logs"
        case errors = "Errors"
        case warnings = "Warnings"
        case performance = "Performance"
        case network = "Network"
        case audio = "Audio"
        case memory = "Memory"
    }

    // MARK: - Log Level

    enum LogLevel: String, CaseIterable, Comparable {
        case all = "All"
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case critical = "Critical"

        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            let order: [LogLevel] = [.all, .debug, .info, .warning, .error, .critical]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }

        var color: Color {
            switch self {
            case .all: return .gray
            case .debug: return .blue
            case .info: return .green
            case .warning: return .yellow
            case .error: return .red
            case .critical: return .purple
            }
        }

        var icon: String {
            switch self {
            case .all: return "doc.text"
            case .debug: return "ant"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "exclamationmark.octagon"
            }
        }
    }

    // MARK: - Log Entry

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let file: String
        let function: String
        let line: Int
        let metadata: [String: String]

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }

    // MARK: - Error Entry

    struct ErrorEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let error: Error
        let context: String
        let stackTrace: [String]
        let severity: ErrorSeverity
        let isResolved: Bool

        enum ErrorSeverity: String {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"

            var color: Color {
                switch self {
                case .low: return .yellow
                case .medium: return .orange
                case .high: return .red
                case .critical: return .purple
                }
            }
        }
    }

    // MARK: - Warning Entry

    struct WarningEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let category: String
        let suggestion: String?
    }

    // MARK: - Performance Snapshot

    struct PerformanceSnapshot {
        var cpuUsage: Double
        var memoryUsage: Double
        var audioLatency: Double
        var droppedFrames: Int
        var activeVoices: Int
        var renderTime: Double

        static let empty = PerformanceSnapshot(
            cpuUsage: 0,
            memoryUsage: 0,
            audioLatency: 0,
            droppedFrames: 0,
            activeVoices: 0,
            renderTime: 0
        )
    }

    // MARK: - Initialization

    private init() {
        log(.info, category: "System", message: "DebugConsole initialized")
    }

    // MARK: - Logging Methods

    /// Log a message with level and category
    func log(
        _ level: LogLevel,
        category: String,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        metadata: [String: String] = [:]
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            metadata: metadata
        )

        logs.append(entry)

        // Trim logs if exceeding limit
        if logs.count > maxLogEntries {
            logs.removeFirst(logs.count - maxLogEntries)
        }

        // Also log to system logger
        switch level {
        case .debug:
            logger.debug("\(category): \(message)")
        case .info:
            logger.info("\(category): \(message)")
        case .warning:
            logger.warning("\(category): \(message)")
        case .error:
            logger.error("\(category): \(message)")
        case .critical:
            logger.critical("\(category): \(message)")
        case .all:
            logger.log("\(category): \(message)")
        }
    }

    /// Log an error with context
    func logError(
        _ error: Error,
        context: String,
        severity: ErrorEntry.ErrorSeverity = .medium,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let stackTrace = Thread.callStackSymbols

        let entry = ErrorEntry(
            timestamp: Date(),
            error: error,
            context: context,
            stackTrace: stackTrace,
            severity: severity,
            isResolved: false
        )

        errors.append(entry)

        // Trim errors if exceeding limit
        if errors.count > maxErrorEntries {
            errors.removeFirst(errors.count - maxErrorEntries)
        }

        // Also log as error
        log(.error, category: "Error", message: "\(context): \(error.localizedDescription)", file: file, function: function, line: line)
    }

    /// Log a warning with suggestion
    func logWarning(
        _ message: String,
        category: String,
        suggestion: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = WarningEntry(
            timestamp: Date(),
            message: message,
            category: category,
            suggestion: suggestion
        )

        warnings.append(entry)

        // Also log as warning level
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }

    // MARK: - Convenience Methods

    func debug(_ message: String, category: String = "Debug") {
        log(.debug, category: category, message: message)
    }

    func info(_ message: String, category: String = "Info") {
        log(.info, category: category, message: message)
    }

    func warning(_ message: String, category: String = "Warning", suggestion: String? = nil) {
        logWarning(message, category: category, suggestion: suggestion)
    }

    func error(_ message: String, category: String = "Error") {
        log(.error, category: category, message: message)
    }

    func critical(_ message: String, category: String = "Critical") {
        log(.critical, category: category, message: message)
    }

    // MARK: - Performance Tracking

    func updatePerformanceMetrics(
        cpuUsage: Double? = nil,
        memoryUsage: Double? = nil,
        audioLatency: Double? = nil,
        droppedFrames: Int? = nil,
        activeVoices: Int? = nil,
        renderTime: Double? = nil
    ) {
        if let cpu = cpuUsage {
            performanceMetrics.cpuUsage = cpu
        }
        if let memory = memoryUsage {
            performanceMetrics.memoryUsage = memory
        }
        if let latency = audioLatency {
            performanceMetrics.audioLatency = latency
        }
        if let frames = droppedFrames {
            performanceMetrics.droppedFrames = frames
        }
        if let voices = activeVoices {
            performanceMetrics.activeVoices = voices
        }
        if let render = renderTime {
            performanceMetrics.renderTime = render
        }

        // Warn if performance issues detected
        if performanceMetrics.cpuUsage > 80.0 {
            logWarning("High CPU usage: \(String(format: "%.1f", performanceMetrics.cpuUsage))%",
                      category: "Performance",
                      suggestion: "Consider reducing polyphony or disabling effects")
        }

        if performanceMetrics.audioLatency > 0.020 {
            logWarning("High audio latency: \(String(format: "%.1f", performanceMetrics.audioLatency * 1000))ms",
                      category: "Performance",
                      suggestion: "Reduce buffer size or sample rate")
        }
    }

    // MARK: - Filtering

    var filteredLogs: [LogEntry] {
        logs.filter { entry in
            // Filter by level
            if filterLevel != .all && entry.level < filterLevel {
                return false
            }

            // Filter by search query
            if !searchQuery.isEmpty {
                let matchesMessage = entry.message.localizedCaseInsensitiveContains(searchQuery)
                let matchesCategory = entry.category.localizedCaseInsensitiveContains(searchQuery)
                return matchesMessage || matchesCategory
            }

            return true
        }
    }

    // MARK: - Clear Methods

    func clearLogs() {
        logs.removeAll()
        log(.info, category: "System", message: "Logs cleared")
    }

    func clearErrors() {
        errors.removeAll()
        log(.info, category: "System", message: "Errors cleared")
    }

    func clearWarnings() {
        warnings.removeAll()
        log(.info, category: "System", message: "Warnings cleared")
    }

    func clearAll() {
        logs.removeAll()
        errors.removeAll()
        warnings.removeAll()
        log(.info, category: "System", message: "All debug data cleared")
    }

    // MARK: - Export

    func exportLogs() -> String {
        var output = "=== Echoelmusic Debug Logs ===\n"
        output += "Generated: \(Date())\n\n"

        for log in logs {
            output += "[\(log.formattedTimestamp)] [\(log.level.rawValue)] [\(log.category)] \(log.message)\n"
            if !log.metadata.isEmpty {
                output += "  Metadata: \(log.metadata)\n"
            }
            output += "  \(log.file):\(log.line) - \(log.function)\n\n"
        }

        return output
    }

    func exportErrors() -> String {
        var output = "=== Echoelmusic Error Report ===\n"
        output += "Generated: \(Date())\n\n"

        for error in errors {
            output += "[\(error.timestamp)] [\(error.severity.rawValue)] \(error.context)\n"
            output += "Error: \(error.error.localizedDescription)\n"
            output += "Stack Trace:\n"
            for line in error.stackTrace.prefix(10) {
                output += "  \(line)\n"
            }
            output += "\n"
        }

        return output
    }

    // MARK: - Toggle Visibility

    func toggle() {
        isVisible.toggle()
    }

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
    }
}

// MARK: - Debug Console View

struct DebugConsoleView: View {
    @ObservedObject var console = DebugConsole.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Console")
                    .font(.headline)

                Spacer()

                // Tab picker
                Picker("Tab", selection: $console.selectedTab) {
                    ForEach(DebugConsole.DebugTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                Spacer()

                // Close button
                Button(action: {
                    console.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Content
            switch console.selectedTab {
            case .logs:
                LogsView(console: console)
            case .errors:
                ErrorsView(console: console)
            case .warnings:
                WarningsView(console: console)
            case .performance:
                PerformanceView(console: console)
            case .network:
                NetworkView()
            case .audio:
                AudioDebugView()
            case .memory:
                MemoryView()
            }
        }
        .frame(height: 400)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Logs View

struct LogsView: View {
    @ObservedObject var console: DebugConsole

    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                // Level filter
                Picker("Level", selection: $console.filterLevel) {
                    ForEach(DebugConsole.LogLevel.allCases, id: \.self) { level in
                        Label(level.rawValue, systemImage: level.icon)
                            .tag(level)
                    }
                }
                .pickerStyle(.menu)

                // Search
                TextField("Search logs...", text: $console.searchQuery)
                    .textFieldStyle(.roundedBorder)

                // Clear button
                Button("Clear") {
                    console.clearLogs()
                }

                // Export button
                Button("Export") {
                    let logs = console.exportLogs()
                    // Save to file or clipboard
                    print(logs)
                }
            }
            .padding()

            Divider()

            // Log entries
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(console.filteredLogs) { log in
                        LogEntryRow(entry: log)
                    }
                }
                .padding()
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: DebugConsole.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                // Timestamp
                Text(entry.formattedTimestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                // Level badge
                Label(entry.level.rawValue, systemImage: entry.level.icon)
                    .font(.caption)
                    .foregroundColor(entry.level.color)

                // Category
                Text("[\(entry.category)]")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // File location
                Text("\(entry.file):\(entry.line)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Errors View

struct ErrorsView: View {
    @ObservedObject var console: DebugConsole

    var body: some View {
        VStack {
            HStack {
                Text("\(console.errors.count) errors")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Clear") {
                    console.clearErrors()
                }
            }
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(console.errors) { error in
                        ErrorEntryRow(entry: error)
                    }
                }
                .padding()
            }
        }
    }
}

struct ErrorEntryRow: View {
    let entry: DebugConsole.ErrorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.caption)

                Text(entry.severity.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.severity.color.opacity(0.2))
                    .cornerRadius(4)
            }

            Text(entry.context)
                .font(.headline)

            Text(entry.error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Warnings View

struct WarningsView: View {
    @ObservedObject var console: DebugConsole

    var body: some View {
        VStack {
            HStack {
                Text("\(console.warnings.count) warnings")
                    .foregroundColor(.secondary)

                Spacer()

                Button("Clear") {
                    console.clearWarnings()
                }
            }
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(console.warnings) { warning in
                        WarningEntryRow(entry: warning)
                    }
                }
                .padding()
            }
        }
    }
}

struct WarningEntryRow: View {
    let entry: DebugConsole.WarningEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)

                Text(entry.category)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(entry.message)
                .font(.body)

            if let suggestion = entry.suggestion {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.blue)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Performance View

struct PerformanceView: View {
    @ObservedObject var console: DebugConsole

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // CPU
                MetricCard(
                    title: "CPU Usage",
                    value: "\(String(format: "%.1f", console.performanceMetrics.cpuUsage))%",
                    icon: "cpu",
                    color: console.performanceMetrics.cpuUsage > 80 ? .red : .green
                )

                // Memory
                MetricCard(
                    title: "Memory Usage",
                    value: "\(String(format: "%.1f", console.performanceMetrics.memoryUsage)) MB",
                    icon: "memorychip",
                    color: console.performanceMetrics.memoryUsage > 500 ? .orange : .green
                )

                // Audio Latency
                MetricCard(
                    title: "Audio Latency",
                    value: "\(String(format: "%.1f", console.performanceMetrics.audioLatency * 1000)) ms",
                    icon: "waveform",
                    color: console.performanceMetrics.audioLatency > 0.020 ? .red : .green
                )

                // Active Voices
                MetricCard(
                    title: "Active Voices",
                    value: "\(console.performanceMetrics.activeVoices)",
                    icon: "music.note",
                    color: .blue
                )

                // Render Time
                MetricCard(
                    title: "Render Time",
                    value: "\(String(format: "%.2f", console.performanceMetrics.renderTime * 1000)) ms",
                    icon: "timer",
                    color: .cyan
                )
            }
            .padding()
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title2)
                    .bold()
            }

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views

struct NetworkView: View {
    var body: some View {
        VStack {
            Text("Network Monitor")
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
    }
}

struct AudioDebugView: View {
    var body: some View {
        VStack {
            Text("Audio Debug")
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
    }
}

struct MemoryView: View {
    var body: some View {
        VStack {
            Text("Memory Monitor")
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Global Access Extension

extension Color {
    #if os(macOS)
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
    #endif
}
