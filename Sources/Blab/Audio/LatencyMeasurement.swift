import Foundation
import AVFoundation
import Combine

/// Latency Measurement System - Real-time audio latency profiling
///
/// Features:
/// - Round-trip latency measurement (input → processing → output)
/// - Real-time monitoring at 60 Hz
/// - Buffer latency calculation
/// - Processing latency tracking
/// - Total system latency reporting
/// - Historical statistics
/// - Performance alerts
///
/// Usage:
/// ```swift
/// let latencyMonitor = LatencyMeasurement.shared
/// latencyMonitor.start(audioEngine: engine)
/// print("Current latency: \(latencyMonitor.currentLatency)ms")
/// ```
@available(iOS 15.0, *)
public class LatencyMeasurement: ObservableObject {

    // MARK: - Singleton

    public static let shared = LatencyMeasurement()

    // MARK: - Published Properties

    /// Current total latency in milliseconds
    @Published public private(set) var currentLatency: Double = 0

    /// Buffer latency (based on buffer size)
    @Published public private(set) var bufferLatency: Double = 0

    /// Processing latency (actual processing time)
    @Published public private(set) var processingLatency: Double = 0

    /// System latency (OS + hardware)
    @Published public private(set) var systemLatency: Double = 0

    /// Whether monitoring is active
    @Published public private(set) var isMonitoring: Bool = false

    /// Whether latency exceeds target (5ms)
    @Published public private(set) var exceedsTarget: Bool = false

    /// Latency statistics
    @Published public private(set) var statistics: LatencyStatistics = LatencyStatistics()

    // MARK: - Types

    public struct LatencyStatistics {
        public var minimum: Double = 0
        public var maximum: Double = 0
        public var average: Double = 0
        public var median: Double = 0
        public var p95: Double = 0  // 95th percentile
        public var p99: Double = 0  // 99th percentile
        public var sampleCount: Int = 0
        public var startTime: Date = Date()

        public var duration: TimeInterval {
            Date().timeIntervalSince(startTime)
        }
    }

    public enum LatencyAlert: String {
        case normal = "Normal (< 5ms)"
        case warning = "Warning (5-10ms)"
        case critical = "Critical (> 10ms)"

        var emoji: String {
            switch self {
            case .normal: return "✅"
            case .warning: return "⚠️"
            case .critical: return "❌"
            }
        }

        var color: String {
            switch self {
            case .normal: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }

    // MARK: - Private Properties

    private weak var audioEngine: AudioEngine?
    private var cancellables = Set<AnyCancellable>()

    // Measurement data
    private var latencySamples: [Double] = []
    private let maxSamples = 1000  // Keep last 1000 samples

    // Timing
    private var lastMeasurementTime: Date?
    private var measurementTimer: Timer?

    // Performance tracking
    private var processingStartTime: CFAbsoluteTime = 0
    private var processingEndTime: CFAbsoluteTime = 0

    // Thresholds
    private let targetLatency: Double = 5.0  // 5ms target
    private let warningLatency: Double = 10.0  // 10ms warning

    // MARK: - Initialization

    private init() {}

    deinit {
        stop()
    }

    // MARK: - Control

    /// Start latency monitoring
    public func start(audioEngine: AudioEngine) {
        guard !isMonitoring else { return }

        self.audioEngine = audioEngine

        // Start measurement timer (60 Hz)
        measurementTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.measureLatency()
        }

        isMonitoring = true
        statistics = LatencyStatistics()  // Reset statistics

        print("[Latency] 📊 Started latency monitoring @ 60 Hz")
    }

    /// Stop latency monitoring
    public func stop() {
        guard isMonitoring else { return }

        measurementTimer?.invalidate()
        measurementTimer = nil
        audioEngine = nil
        cancellables.removeAll()

        isMonitoring = false

        print("[Latency] 📊 Stopped latency monitoring")
    }

    // MARK: - Measurement

    private func measureLatency() {
        guard let audioEngine = audioEngine else { return }

        // Calculate buffer latency
        let bufferSize = audioEngine.bufferSize
        let sampleRate = audioEngine.sampleRate
        bufferLatency = (Double(bufferSize) / sampleRate) * 1000.0

        // Estimate system latency (iOS audio system)
        // This includes:
        // - Input buffer (1 buffer)
        // - Processing (measured)
        // - Output buffer (1 buffer)
        let inputOutputLatency = bufferLatency * 2  // Input + Output buffers

        // Get processing latency (if we have measurements)
        let currentProcessingLatency = self.processingLatency

        // Calculate total latency
        let totalLatency = inputOutputLatency + currentProcessingLatency

        // Update published properties
        systemLatency = inputOutputLatency
        currentLatency = totalLatency

        // Check if exceeds target
        exceedsTarget = totalLatency > targetLatency

        // Update statistics
        updateStatistics(latency: totalLatency)

        // Record sample
        recordSample(totalLatency)
    }

    /// Mark start of audio processing
    /// Call this at the beginning of audio render callback
    public func markProcessingStart() {
        processingStartTime = CFAbsoluteTimeGetCurrent()
    }

    /// Mark end of audio processing
    /// Call this at the end of audio render callback
    public func markProcessingEnd() {
        processingEndTime = CFAbsoluteTimeGetCurrent()

        // Calculate processing time in milliseconds
        let processingTime = (processingEndTime - processingStartTime) * 1000.0
        processingLatency = processingTime
    }

    // MARK: - Statistics

    private func updateStatistics(latency: Double) {
        statistics.sampleCount += 1

        // Update min/max
        if statistics.sampleCount == 1 {
            statistics.minimum = latency
            statistics.maximum = latency
            statistics.average = latency
        } else {
            statistics.minimum = min(statistics.minimum, latency)
            statistics.maximum = max(statistics.maximum, latency)

            // Update running average
            let n = Double(statistics.sampleCount)
            statistics.average = (statistics.average * (n - 1) + latency) / n
        }

        // Update percentiles (calculated from samples)
        calculatePercentiles()
    }

    private func recordSample(_ latency: Double) {
        latencySamples.append(latency)

        // Keep only last N samples
        if latencySamples.count > maxSamples {
            latencySamples.removeFirst()
        }
    }

    private func calculatePercentiles() {
        guard !latencySamples.isEmpty else { return }

        let sorted = latencySamples.sorted()

        // Median (50th percentile)
        let medianIndex = sorted.count / 2
        statistics.median = sorted[medianIndex]

        // 95th percentile
        let p95Index = Int(Double(sorted.count) * 0.95)
        statistics.p95 = sorted[min(p95Index, sorted.count - 1)]

        // 99th percentile
        let p99Index = Int(Double(sorted.count) * 0.99)
        statistics.p99 = sorted[min(p99Index, sorted.count - 1)]
    }

    // MARK: - Alerts

    /// Get current latency alert level
    public func getAlert() -> LatencyAlert {
        if currentLatency < targetLatency {
            return .normal
        } else if currentLatency < warningLatency {
            return .warning
        } else {
            return .critical
        }
    }

    /// Get user-friendly status message
    public func getStatusMessage() -> String {
        let alert = getAlert()
        let latency = String(format: "%.2f", currentLatency)

        switch alert {
        case .normal:
            return "✅ Excellent: \(latency)ms latency"
        case .warning:
            return "⚠️ Acceptable: \(latency)ms latency (target: \(targetLatency)ms)"
        case .critical:
            return "❌ High: \(latency)ms latency (reduce buffer size or optimize)"
        }
    }

    /// Get optimization recommendations
    public func getOptimizationTips() -> [String] {
        var tips: [String] = []
        let alert = getAlert()

        switch alert {
        case .critical:
            tips.append("🔧 Reduce audio buffer size (current contributes \(String(format: "%.2f", bufferLatency))ms)")
            tips.append("🔧 Disable heavy effects/processing")
            tips.append("🔧 Close background apps")
            tips.append("🔧 Reduce sample rate if possible")

        case .warning:
            tips.append("💡 Consider reducing buffer size for lower latency")
            tips.append("💡 Monitor CPU usage - may be approaching limits")

        case .normal:
            tips.append("✅ Latency is optimal for live performance")
            tips.append("💡 Current buffer size provides good stability/latency balance")
        }

        // Processing-specific tips
        if processingLatency > 1.0 {
            tips.append("⚡ Processing takes \(String(format: "%.2f", processingLatency))ms - consider optimization")
        }

        return tips
    }

    // MARK: - Reporting

    /// Print detailed latency report
    public func printReport() {
        let alert = getAlert()

        print("""

        ════════════════════════════════════════════════════════════
        📊 LATENCY MEASUREMENT REPORT
        ════════════════════════════════════════════════════════════

        CURRENT LATENCY:
          Total:       \(String(format: "%6.2f", currentLatency))ms  \(alert.emoji) \(alert.rawValue)
          Buffer:      \(String(format: "%6.2f", bufferLatency))ms  (Input/Output buffers)
          Processing:  \(String(format: "%6.2f", processingLatency))ms  (Audio DSP)
          System:      \(String(format: "%6.2f", systemLatency))ms  (iOS audio system)

        STATISTICS (\(statistics.sampleCount) samples, \(String(format: "%.0f", statistics.duration))s):
          Minimum:     \(String(format: "%6.2f", statistics.minimum))ms  (Best achieved)
          Average:     \(String(format: "%6.2f", statistics.average))ms  (Mean)
          Median:      \(String(format: "%6.2f", statistics.median))ms  (50th percentile)
          P95:         \(String(format: "%6.2f", statistics.p95))ms  (95% below this)
          P99:         \(String(format: "%6.2f", statistics.p99))ms  (99% below this)
          Maximum:     \(String(format: "%6.2f", statistics.maximum))ms  (Worst case)

        PERFORMANCE:
          Target:      \(String(format: "%6.2f", targetLatency))ms  \(currentLatency <= targetLatency ? "✅ MET" : "❌ NOT MET")
          Variance:    \(String(format: "%6.2f", statistics.maximum - statistics.minimum))ms  (Max - Min)
          Stability:   \(getStabilityRating())

        CONFIGURATION:
          Sample Rate: \(audioEngine?.sampleRate ?? 0) Hz
          Buffer Size: \(audioEngine?.bufferSize ?? 0) frames
          Monitoring:  60 Hz

        ════════════════════════════════════════════════════════════

        RECOMMENDATIONS:
        """)

        for tip in getOptimizationTips() {
            print("  \(tip)")
        }

        print("\n════════════════════════════════════════════════════════════\n")
    }

    /// Get stability rating (0-100)
    public func getStabilityRating() -> String {
        guard statistics.sampleCount > 10 else { return "N/A (collecting data)" }

        let variance = statistics.maximum - statistics.minimum

        if variance < 1.0 {
            return "Excellent (< 1ms variance)"
        } else if variance < 2.0 {
            return "Good (< 2ms variance)"
        } else if variance < 5.0 {
            return "Fair (< 5ms variance)"
        } else {
            return "Poor (\(String(format: "%.1f", variance))ms variance)"
        }
    }

    /// Export statistics as dictionary (for logging/analytics)
    public func exportStatistics() -> [String: Any] {
        return [
            "currentLatency": currentLatency,
            "bufferLatency": bufferLatency,
            "processingLatency": processingLatency,
            "systemLatency": systemLatency,
            "statistics": [
                "minimum": statistics.minimum,
                "average": statistics.average,
                "median": statistics.median,
                "p95": statistics.p95,
                "p99": statistics.p99,
                "maximum": statistics.maximum,
                "sampleCount": statistics.sampleCount,
                "duration": statistics.duration
            ],
            "alert": getAlert().rawValue,
            "meetsTarget": currentLatency <= targetLatency,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }

    // MARK: - Reset

    /// Reset all statistics
    public func resetStatistics() {
        statistics = LatencyStatistics()
        latencySamples.removeAll()
        print("[Latency] 📊 Statistics reset")
    }
}

// MARK: - AudioEngine Integration

@available(iOS 15.0, *)
extension AudioEngine {

    /// Enable latency monitoring
    /// This should be called when audio engine starts
    public func enableLatencyMonitoring() {
        LatencyMeasurement.shared.start(audioEngine: self)
        print("[AudioEngine] 📊 Latency monitoring enabled")
    }

    /// Disable latency monitoring
    public func disableLatencyMonitoring() {
        LatencyMeasurement.shared.stop()
        print("[AudioEngine] 📊 Latency monitoring disabled")
    }

    /// Get current latency in milliseconds
    public var currentLatency: Double {
        LatencyMeasurement.shared.currentLatency
    }

    /// Check if latency meets target (< 5ms)
    public var meetsLatencyTarget: Bool {
        !LatencyMeasurement.shared.exceedsTarget
    }
}

// MARK: - Performance Dashboard Helper

@available(iOS 15.0, *)
extension LatencyMeasurement {

    /// Get formatted latency for display
    public var formattedLatency: String {
        String(format: "%.2f ms", currentLatency)
    }

    /// Get color for UI display
    public var displayColor: String {
        getAlert().color
    }

    /// Get summary for quick display
    public var summary: String {
        let alert = getAlert()
        return "\(alert.emoji) \(formattedLatency) - \(alert.rawValue)"
    }
}
