import Foundation
import QuartzCore
import os.signpost

/// Performance Profiler for Echoelmusic
/// Tracks: Audio latency, Frame times, Memory usage, CPU load
/// Provides real-time metrics and historical analysis
@MainActor
class PerformanceProfiler: ObservableObject {

    // MARK: - Published Metrics

    @Published var audioLatencyMs: Double = 0
    @Published var renderTimeMs: Double = 0
    @Published var frameRate: Double = 60
    @Published var memoryUsageMB: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var audioBufferUnderruns: Int = 0
    @Published var isProfilingActive: Bool = false

    // MARK: - Metric History

    private var audioLatencyHistory: RingBuffer<Double>
    private var renderTimeHistory: RingBuffer<Double>
    private var frameTimeHistory: RingBuffer<Double>
    private var memoryHistory: RingBuffer<Double>
    private var cpuHistory: RingBuffer<Double>

    // MARK: - Signpost Logging

    private let signpostLog = OSLog(subsystem: "com.echoelmusic", category: "Performance")
    private let pointsOfInterest = OSLog(subsystem: "com.echoelmusic", category: .pointsOfInterest)

    // MARK: - Timing

    private var frameStartTime: CFTimeInterval = 0
    private var audioProcessStartTime: CFTimeInterval = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var updateTimer: Timer?

    // MARK: - Thresholds

    struct Thresholds {
        static let maxAudioLatencyMs: Double = 10.0
        static let maxRenderTimeMs: Double = 16.0  // 60fps
        static let maxMemoryMB: Double = 500.0
        static let maxCPUPercent: Double = 80.0
        static let minFrameRate: Double = 30.0
    }

    // MARK: - Initialization

    init(historySize: Int = 1000) {
        audioLatencyHistory = RingBuffer(capacity: historySize)
        renderTimeHistory = RingBuffer(capacity: historySize)
        frameTimeHistory = RingBuffer(capacity: historySize)
        memoryHistory = RingBuffer(capacity: historySize)
        cpuHistory = RingBuffer(capacity: historySize)
    }

    deinit {
        stopProfiling()
    }

    // MARK: - Profiling Control

    func startProfiling() {
        guard !isProfilingActive else { return }

        isProfilingActive = true

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }

        os_signpost(.begin, log: signpostLog, name: "Profiling Session")
        print("📊 Performance profiling started")
    }

    func stopProfiling() {
        guard isProfilingActive else { return }

        updateTimer?.invalidate()
        updateTimer = nil
        isProfilingActive = false

        os_signpost(.end, log: signpostLog, name: "Profiling Session")
        print("📊 Performance profiling stopped")
    }

    // MARK: - Audio Profiling

    func beginAudioProcess() {
        audioProcessStartTime = CACurrentMediaTime()
        os_signpost(.begin, log: signpostLog, name: "Audio Process")
    }

    func endAudioProcess() {
        let duration = (CACurrentMediaTime() - audioProcessStartTime) * 1000.0
        audioLatencyMs = duration
        audioLatencyHistory.append(duration)

        os_signpost(.end, log: signpostLog, name: "Audio Process")

        // Check for issues
        if duration > Thresholds.maxAudioLatencyMs {
            os_signpost(.event, log: pointsOfInterest, name: "Audio Latency Spike", "%{public}f ms", duration)
        }
    }

    func recordBufferUnderrun() {
        audioBufferUnderruns += 1
        os_signpost(.event, log: pointsOfInterest, name: "Buffer Underrun")
    }

    // MARK: - Render Profiling

    func beginFrame() {
        frameStartTime = CACurrentMediaTime()
        os_signpost(.begin, log: signpostLog, name: "Frame Render")
    }

    func endFrame() {
        let currentTime = CACurrentMediaTime()
        let duration = (currentTime - frameStartTime) * 1000.0
        renderTimeMs = duration
        renderTimeHistory.append(duration)

        // Calculate frame rate
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimeHistory.append(frameTime * 1000.0)
            frameRate = 1.0 / frameTime
        }
        lastFrameTime = currentTime

        os_signpost(.end, log: signpostLog, name: "Frame Render")

        // Check for dropped frames
        if duration > Thresholds.maxRenderTimeMs {
            os_signpost(.event, log: pointsOfInterest, name: "Frame Drop", "%{public}f ms", duration)
        }
    }

    // MARK: - Memory Profiling

    func measureMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            memoryUsageMB = memoryMB
            memoryHistory.append(memoryMB)

            if memoryMB > Thresholds.maxMemoryMB {
                os_signpost(.event, log: pointsOfInterest, name: "High Memory", "%{public}f MB", memoryMB)
            }

            return memoryMB
        }

        return 0
    }

    // MARK: - CPU Profiling

    func measureCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t()

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else {
            return 0
        }

        var totalCPU: Double = 0

        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }

            if result == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        // Deallocate thread list
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride))

        cpuUsage = totalCPU
        cpuHistory.append(totalCPU)

        if totalCPU > Thresholds.maxCPUPercent {
            os_signpost(.event, log: pointsOfInterest, name: "High CPU", "%{public}f%%", totalCPU)
        }

        return totalCPU
    }

    // MARK: - Periodic Update

    private func updateMetrics() {
        _ = measureMemory()
        _ = measureCPU()
    }

    // MARK: - Statistics

    func getAudioLatencyStats() -> Statistics {
        return calculateStats(from: audioLatencyHistory.toArray())
    }

    func getRenderTimeStats() -> Statistics {
        return calculateStats(from: renderTimeHistory.toArray())
    }

    func getFrameRateStats() -> Statistics {
        let frameTimes = frameTimeHistory.toArray()
        let frameRates = frameTimes.map { 1000.0 / max($0, 0.001) }
        return calculateStats(from: frameRates)
    }

    func getMemoryStats() -> Statistics {
        return calculateStats(from: memoryHistory.toArray())
    }

    func getCPUStats() -> Statistics {
        return calculateStats(from: cpuHistory.toArray())
    }

    private func calculateStats(from values: [Double]) -> Statistics {
        guard !values.isEmpty else {
            return Statistics(min: 0, max: 0, average: 0, p95: 0, p99: 0)
        }

        let sorted = values.sorted()
        let count = sorted.count

        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let average = sorted.reduce(0, +) / Double(count)
        let p95 = sorted[Int(Double(count) * 0.95)]
        let p99 = sorted[Int(Double(count) * 0.99)]

        return Statistics(min: min, max: max, average: average, p95: p95, p99: p99)
    }

    // MARK: - Health Check

    func performHealthCheck() -> HealthReport {
        let audioStats = getAudioLatencyStats()
        let renderStats = getRenderTimeStats()
        let frameStats = getFrameRateStats()
        let memStats = getMemoryStats()
        let cpuStats = getCPUStats()

        var issues: [HealthIssue] = []

        // Check audio latency
        if audioStats.p95 > Thresholds.maxAudioLatencyMs {
            issues.append(HealthIssue(
                severity: .warning,
                component: "Audio",
                message: "High audio latency (P95: \(String(format: "%.1f", audioStats.p95))ms)"
            ))
        }

        // Check buffer underruns
        if audioBufferUnderruns > 0 {
            issues.append(HealthIssue(
                severity: audioBufferUnderruns > 10 ? .critical : .warning,
                component: "Audio",
                message: "\(audioBufferUnderruns) buffer underruns detected"
            ))
        }

        // Check frame rate
        if frameStats.average < Thresholds.minFrameRate {
            issues.append(HealthIssue(
                severity: .warning,
                component: "Graphics",
                message: "Low frame rate (avg: \(String(format: "%.1f", frameStats.average)) fps)"
            ))
        }

        // Check memory
        if memStats.max > Thresholds.maxMemoryMB {
            issues.append(HealthIssue(
                severity: .warning,
                component: "Memory",
                message: "High memory usage (max: \(String(format: "%.0f", memStats.max))MB)"
            ))
        }

        // Check CPU
        if cpuStats.p95 > Thresholds.maxCPUPercent {
            issues.append(HealthIssue(
                severity: .warning,
                component: "CPU",
                message: "High CPU usage (P95: \(String(format: "%.0f", cpuStats.p95))%)"
            ))
        }

        let overallHealth: HealthStatus = {
            let criticalCount = issues.filter { $0.severity == .critical }.count
            let warningCount = issues.filter { $0.severity == .warning }.count

            if criticalCount > 0 { return .critical }
            if warningCount > 2 { return .degraded }
            if warningCount > 0 { return .warning }
            return .healthy
        }()

        return HealthReport(
            status: overallHealth,
            issues: issues,
            audioLatency: audioStats,
            renderTime: renderStats,
            frameRate: frameStats,
            memory: memStats,
            cpu: cpuStats,
            bufferUnderruns: audioBufferUnderruns,
            timestamp: Date()
        )
    }

    // MARK: - Report Generation

    func generateReport() -> String {
        let health = performHealthCheck()

        return """
        ╔═══════════════════════════════════════════════════════════╗
        ║           ECHOELMUSIC PERFORMANCE REPORT                  ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ Status: \(health.status.emoji) \(health.status.rawValue.padding(toLength: 44, withPad: " ", startingAt: 0)) ║
        ║ Generated: \(formatDate(health.timestamp).padding(toLength: 41, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ AUDIO PERFORMANCE                                         ║
        ║   Latency (avg):  \(formatMs(health.audioLatency.average).padding(toLength: 36, withPad: " ", startingAt: 0)) ║
        ║   Latency (P95):  \(formatMs(health.audioLatency.p95).padding(toLength: 36, withPad: " ", startingAt: 0)) ║
        ║   Buffer Underruns: \(String(health.bufferUnderruns).padding(toLength: 33, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ GRAPHICS PERFORMANCE                                      ║
        ║   Frame Rate (avg): \(formatFps(health.frameRate.average).padding(toLength: 33, withPad: " ", startingAt: 0)) ║
        ║   Render Time (P95): \(formatMs(health.renderTime.p95).padding(toLength: 32, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ SYSTEM RESOURCES                                          ║
        ║   Memory (avg):  \(formatMB(health.memory.average).padding(toLength: 37, withPad: " ", startingAt: 0)) ║
        ║   Memory (max):  \(formatMB(health.memory.max).padding(toLength: 37, withPad: " ", startingAt: 0)) ║
        ║   CPU (avg):     \(formatPercent(health.cpu.average).padding(toLength: 37, withPad: " ", startingAt: 0)) ║
        ║   CPU (P95):     \(formatPercent(health.cpu.p95).padding(toLength: 37, withPad: " ", startingAt: 0)) ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ ISSUES (\(health.issues.count))                                                   ║
        \(health.issues.isEmpty ? "║   No issues detected                                        ║\n" : health.issues.map { "║   \($0.severity.emoji) [\($0.component)] \($0.message.padding(toLength: 40, withPad: " ", startingAt: 0))║" }.joined(separator: "\n") + "\n")╚═══════════════════════════════════════════════════════════╝
        """
    }

    private func formatMs(_ value: Double) -> String {
        String(format: "%.2f ms", value)
    }

    private func formatFps(_ value: Double) -> String {
        String(format: "%.1f fps", value)
    }

    private func formatMB(_ value: Double) -> String {
        String(format: "%.1f MB", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - Types

    struct Statistics {
        let min: Double
        let max: Double
        let average: Double
        let p95: Double
        let p99: Double
    }

    enum HealthStatus: String {
        case healthy = "Healthy"
        case warning = "Warning"
        case degraded = "Degraded"
        case critical = "Critical"

        var emoji: String {
            switch self {
            case .healthy: return "✅"
            case .warning: return "⚠️"
            case .degraded: return "🟠"
            case .critical: return "🔴"
            }
        }
    }

    enum IssueSeverity {
        case info
        case warning
        case critical

        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .critical: return "🔴"
            }
        }
    }

    struct HealthIssue {
        let severity: IssueSeverity
        let component: String
        let message: String
    }

    struct HealthReport {
        let status: HealthStatus
        let issues: [HealthIssue]
        let audioLatency: Statistics
        let renderTime: Statistics
        let frameRate: Statistics
        let memory: Statistics
        let cpu: Statistics
        let bufferUnderruns: Int
        let timestamp: Date
    }
}

// MARK: - Ring Buffer

struct RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private var count = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [T?](repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    func toArray() -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let index = (writeIndex - count + i + capacity) % capacity
            if let element = buffer[index] {
                result.append(element)
            }
        }

        return result
    }

    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }
}
