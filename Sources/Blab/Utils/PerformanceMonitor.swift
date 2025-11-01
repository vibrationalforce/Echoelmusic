import Foundation
import Combine
import os.log

/// Real-time performance monitoring system
/// Tracks CPU usage, memory, FPS, and control loop frequency
@MainActor
final class PerformanceMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published var cpuUsage: Double = 0.0 // Percentage (0-100)
    @Published var memoryUsage: Double = 0.0 // MB
    @Published var fps: Double = 0.0 // Frames per second
    @Published var controlLoopHz: Double = 0.0 // Control loop frequency
    @Published var isPerformanceWarning: Bool = false

    // MARK: - Performance Thresholds

    struct Thresholds {
        static let maxCPU: Double = 30.0 // 30% CPU
        static let maxMemory: Double = 200.0 // 200 MB
        static let minFPS: Double = 50.0 // 50 FPS minimum
        static let targetControlLoopHz: Double = 60.0 // 60 Hz target
        static let minControlLoopHz: Double = 50.0 // 50 Hz minimum
    }

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var frameTimestamps: [TimeInterval] = []
    private var controlLoopTimestamps: [TimeInterval] = []
    private let maxTimestampSamples = 60 // 1 second of samples at 60 Hz

    private let logger = Logger(subsystem: "com.blab.studio", category: "Performance")

    // MARK: - Singleton

    static let shared = PerformanceMonitor()

    private init() {
        startMonitoring()
    }

    // MARK: - Public Methods

    /// Start performance monitoring
    func startMonitoring() {
        stopMonitoring()

        // Update metrics every 0.5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }

        logger.info("Performance monitoring started")
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        logger.info("Performance monitoring stopped")
    }

    /// Record a frame render (call from rendering code)
    func recordFrame() {
        let now = CACurrentMediaTime()
        frameTimestamps.append(now)

        // Keep only recent samples
        if frameTimestamps.count > maxTimestampSamples {
            frameTimestamps.removeFirst()
        }
    }

    /// Record a control loop update (call from UnifiedControlHub)
    func recordControlLoopUpdate() {
        let now = CACurrentMediaTime()
        controlLoopTimestamps.append(now)

        // Keep only recent samples
        if controlLoopTimestamps.count > maxTimestampSamples {
            controlLoopTimestamps.removeFirst()
        }
    }

    // MARK: - Private Methods

    private func updateMetrics() {
        cpuUsage = measureCPUUsage()
        memoryUsage = measureMemoryUsage()
        fps = calculateFPS()
        controlLoopHz = calculateControlLoopHz()

        checkPerformanceThresholds()
        logMetricsIfNeeded()
    }

    private func measureCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)

        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        guard threadsResult == KERN_SUCCESS, let threads = threadsList else {
            return 0.0
        }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        for index in 0..<Int(threadsCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            guard infoResult == KERN_SUCCESS else { continue }

            let threadBasicInfo = threadInfo
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        return totalUsageOfCPU
    }

    private func measureMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0.0 }

        let memoryUsageBytes = taskInfo.resident_size
        let memoryUsageMB = Double(memoryUsageBytes) / 1024.0 / 1024.0

        return memoryUsageMB
    }

    private func calculateFPS() -> Double {
        guard frameTimestamps.count >= 2 else { return 0.0 }

        let timeSpan = frameTimestamps.last! - frameTimestamps.first!
        guard timeSpan > 0 else { return 0.0 }

        let fps = Double(frameTimestamps.count - 1) / timeSpan
        return fps
    }

    private func calculateControlLoopHz() -> Double {
        guard controlLoopTimestamps.count >= 2 else { return 0.0 }

        let timeSpan = controlLoopTimestamps.last! - controlLoopTimestamps.first!
        guard timeSpan > 0 else { return 0.0 }

        let hz = Double(controlLoopTimestamps.count - 1) / timeSpan
        return hz
    }

    private func checkPerformanceThresholds() {
        let cpuExceeded = cpuUsage > Thresholds.maxCPU
        let memoryExceeded = memoryUsage > Thresholds.maxMemory
        let fpsLow = fps > 0 && fps < Thresholds.minFPS
        let controlLoopLow = controlLoopHz > 0 && controlLoopHz < Thresholds.minControlLoopHz

        isPerformanceWarning = cpuExceeded || memoryExceeded || fpsLow || controlLoopLow

        if isPerformanceWarning {
            var warnings: [String] = []
            if cpuExceeded { warnings.append("CPU: \(String(format: "%.1f", cpuUsage))%") }
            if memoryExceeded { warnings.append("Memory: \(String(format: "%.1f", memoryUsage)) MB") }
            if fpsLow { warnings.append("FPS: \(String(format: "%.1f", fps))") }
            if controlLoopLow { warnings.append("Control Loop: \(String(format: "%.1f", controlLoopHz)) Hz") }

            logger.warning("⚠️ Performance warning: \(warnings.joined(separator: ", "))")
        }
    }

    private func logMetricsIfNeeded() {
        // Log every 10 seconds (every 20 updates at 0.5s interval)
        let shouldLog = Int(Date().timeIntervalSince1970) % 10 == 0

        if shouldLog {
            logger.info("""
                📊 Performance Metrics:
                   CPU: \(String(format: "%.1f", self.cpuUsage))%
                   Memory: \(String(format: "%.1f", self.memoryUsage)) MB
                   FPS: \(String(format: "%.1f", self.fps))
                   Control Loop: \(String(format: "%.1f", self.controlLoopHz)) Hz
                """)
        }
    }

    // MARK: - Diagnostic Report

    /// Generate a detailed performance report
    func generateReport() -> PerformanceReport {
        PerformanceReport(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            fps: fps,
            controlLoopHz: controlLoopHz,
            meetsThresholds: !isPerformanceWarning,
            warnings: generateWarnings()
        )
    }

    private func generateWarnings() -> [String] {
        var warnings: [String] = []

        if cpuUsage > Thresholds.maxCPU {
            warnings.append("CPU usage (\(String(format: "%.1f", cpuUsage))%) exceeds threshold (\(Thresholds.maxCPU)%)")
        }
        if memoryUsage > Thresholds.maxMemory {
            warnings.append("Memory usage (\(String(format: "%.1f", memoryUsage)) MB) exceeds threshold (\(Thresholds.maxMemory) MB)")
        }
        if fps > 0 && fps < Thresholds.minFPS {
            warnings.append("FPS (\(String(format: "%.1f", fps))) below minimum (\(Thresholds.minFPS))")
        }
        if controlLoopHz > 0 && controlLoopHz < Thresholds.minControlLoopHz {
            warnings.append("Control loop frequency (\(String(format: "%.1f", controlLoopHz)) Hz) below minimum (\(Thresholds.minControlLoopHz) Hz)")
        }

        return warnings
    }
}

// MARK: - Performance Report

struct PerformanceReport {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let fps: Double
    let controlLoopHz: Double
    let meetsThresholds: Bool
    let warnings: [String]

    var formattedReport: String {
        var report = """
        Performance Report - \(timestamp.formatted())
        ================================================
        CPU Usage:          \(String(format: "%.1f", cpuUsage))% (max: \(PerformanceMonitor.Thresholds.maxCPU)%)
        Memory Usage:       \(String(format: "%.1f", memoryUsage)) MB (max: \(PerformanceMonitor.Thresholds.maxMemory) MB)
        Frame Rate:         \(String(format: "%.1f", fps)) FPS (min: \(PerformanceMonitor.Thresholds.minFPS) FPS)
        Control Loop:       \(String(format: "%.1f", controlLoopHz)) Hz (target: \(PerformanceMonitor.Thresholds.targetControlLoopHz) Hz)

        Status: \(meetsThresholds ? "✅ All thresholds met" : "⚠️ Performance issues detected")
        """

        if !warnings.isEmpty {
            report += "\n\nWarnings:\n"
            for (index, warning) in warnings.enumerated() {
                report += "\(index + 1). \(warning)\n"
            }
        }

        return report
    }
}
