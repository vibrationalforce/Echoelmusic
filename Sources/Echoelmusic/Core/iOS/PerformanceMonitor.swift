// PerformanceMonitor.swift
// Intelligentes Performance- und Thermal-Management für iOS
//
// Features:
// - Real-time Performance Tracking
// - Thermal State Monitoring
// - Automatic Quality Scaling
// - Battery-aware Optimization
// - Network Quality Detection
//
// Kompatibilität: iOS 15+

import Foundation
import UIKit
import os.log

@available(iOS 15.0, *)
@MainActor
public class PerformanceMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published public private(set) var performanceMode: PerformanceMode = .balanced
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published public private(set) var recommendations: [PerformanceRecommendation] = []

    // MARK: - Performance Metrics

    public struct PerformanceMetrics {
        // CPU & Memory
        public var cpuUsagePercent: Double = 0
        public var memoryUsageGB: Double = 0
        public var availableMemoryGB: Double = 0

        // Audio
        public var audioLatencyMs: Double = 0
        public var audioDropouts: Int = 0
        public var audioBufferUtilization: Double = 0

        // Thermal
        public var thermalState: ProcessInfo.ThermalState = .nominal
        public var estimatedTemperatureC: Double? = nil

        // Battery
        public var batteryLevel: Float = 1.0
        public var batteryState: UIDevice.BatteryState = .unknown
        public var isLowPowerMode: Bool = false

        // Network (for streaming)
        public var networkBandwidthMbps: Double = 0
        public var networkLatencyMs: Double = 0

        public var isHealthy: Bool {
            return audioDropouts == 0 &&
                   thermalState != .critical &&
                   cpuUsagePercent < 80
        }
    }

    // MARK: - Performance Mode

    public enum PerformanceMode: String, CaseIterable {
        case maximum = "Maximum Quality"
        case balanced = "Balanced"
        case efficient = "Efficient"
        case ultraEfficient = "Ultra Efficient"

        /// Audio buffer size for this mode
        public var audioBufferSize: Int {
            switch self {
            case .maximum: return 64
            case .balanced: return 128
            case .efficient: return 256
            case .ultraEfficient: return 512
            }
        }

        /// Video quality for this mode
        public var videoQuality: String {
            switch self {
            case .maximum: return "4K60"
            case .balanced: return "1080p60"
            case .efficient: return "1080p30"
            case .ultraEfficient: return "720p30"
            }
        }
    }

    // MARK: - Performance Recommendation

    public struct PerformanceRecommendation: Identifiable {
        public let id = UUID()
        public let severity: Severity
        public let message: String
        public let action: String?

        public enum Severity {
            case info
            case warning
            case critical
        }
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.echoelmusic.performance", category: "Monitor")
    private let processInfo = ProcessInfo.processInfo

    private var monitoringTimer: Timer?
    private var thermalStateObserver: NSObjectProtocol?

    // MARK: - Initialization

    public init() {
        setupThermalStateObserver()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Start performance monitoring
    public func startMonitoring(interval: TimeInterval = 0.5) {
        stopMonitoring() // Stop existing timer

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
                self?.analyzeAndOptimize()
            }
        }

        logger.info("✅ Performance monitoring started (interval: \(interval)s)")
    }

    /// Stop performance monitoring
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("✅ Performance monitoring stopped")
    }

    /// Manually set performance mode
    /// - Parameter mode: Desired performance mode
    public func setPerformanceMode(_ mode: PerformanceMode) {
        performanceMode = mode
        applyPerformanceMode(mode)
        logger.info("✅ Performance mode set to: \(mode.rawValue)")
    }

    // MARK: - Metrics Gathering

    private func updateMetrics() async {
        var metrics = PerformanceMetrics()

        // CPU Usage
        metrics.cpuUsagePercent = getCPUUsage()

        // Memory Usage
        let memory = getMemoryUsage()
        metrics.memoryUsageGB = memory.used
        metrics.availableMemoryGB = memory.available

        // Thermal State
        metrics.thermalState = processInfo.thermalState
        self.thermalState = metrics.thermalState

        // Battery
        UIDevice.current.isBatteryMonitoringEnabled = true
        metrics.batteryLevel = UIDevice.current.batteryLevel
        metrics.batteryState = UIDevice.current.batteryState
        metrics.isLowPowerMode = processInfo.isLowPowerModeEnabled

        // Network (simplified)
        metrics.networkBandwidthMbps = await measureNetworkBandwidth()

        currentMetrics = metrics
    }

    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList = UnsafeMutablePointer<thread_act_t?>(mutating: [thread_act_t]())
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))

        return totalUsageOfCPU
    }

    private func getMemoryUsage() -> (used: Double, available: Double) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0)
        }

        let usedGB = Double(taskInfo.phys_footprint) / 1_073_741_824 // Bytes to GB
        let totalGB = Double(processInfo.physicalMemory) / 1_073_741_824

        return (usedGB, totalGB - usedGB)
    }

    private func measureNetworkBandwidth() async -> Double {
        // Simplified: Return estimated bandwidth
        // Real implementation would perform actual speed test
        return 50.0 // 50 Mbps default
    }

    // MARK: - Analysis & Optimization

    private func analyzeAndOptimize() {
        recommendations.removeAll()

        // Check thermal state
        switch currentMetrics.thermalState {
        case .nominal:
            // All good
            break

        case .fair:
            recommendations.append(PerformanceRecommendation(
                severity: .info,
                message: "Device is warming up",
                action: nil
            ))

        case .serious:
            recommendations.append(PerformanceRecommendation(
                severity: .warning,
                message: "Device is hot, reducing quality",
                action: "Switch to Efficient mode"
            ))

            if performanceMode == .maximum {
                setPerformanceMode(.balanced)
            }

        case .critical:
            recommendations.append(PerformanceRecommendation(
                severity: .critical,
                message: "Device is overheating!",
                action: "Switch to Ultra Efficient mode"
            ))

            setPerformanceMode(.ultraEfficient)

        @unknown default:
            break
        }

        // Check CPU usage
        if currentMetrics.cpuUsagePercent > 80 {
            recommendations.append(PerformanceRecommendation(
                severity: .warning,
                message: "High CPU usage (\(Int(currentMetrics.cpuUsagePercent))%)",
                action: "Reduce audio effects or video quality"
            ))
        }

        // Check memory
        if currentMetrics.memoryUsageGB > 2.0 {
            recommendations.append(PerformanceRecommendation(
                severity: .warning,
                message: "High memory usage (\(currentMetrics.memoryUsageGB, format: .fixed(precision: 1))GB)",
                action: "Close other apps"
            ))
        }

        // Check battery
        if currentMetrics.batteryLevel < 0.2 && currentMetrics.batteryState != .charging {
            recommendations.append(PerformanceRecommendation(
                severity: .warning,
                message: "Low battery (\(Int(currentMetrics.batteryLevel * 100))%)",
                action: "Enable Low Power Mode"
            ))
        }

        // Check Low Power Mode
        if currentMetrics.isLowPowerMode && performanceMode == .maximum {
            setPerformanceMode(.efficient)
            recommendations.append(PerformanceRecommendation(
                severity: .info,
                message: "Low Power Mode detected",
                action: "Switched to Efficient mode"
            ))
        }

        // Check audio dropouts
        if currentMetrics.audioDropouts > 0 {
            recommendations.append(PerformanceRecommendation(
                severity: .critical,
                message: "Audio dropouts detected!",
                action: "Increase buffer size"
            ))
        }
    }

    private func applyPerformanceMode(_ mode: PerformanceMode) {
        // This would be called by AudioEngine and VideoEngine
        // For now, just log the intended changes

        logger.info("""
            📊 Applying performance mode: \(mode.rawValue)
               Audio Buffer: \(mode.audioBufferSize) samples
               Video Quality: \(mode.videoQuality)
            """)

        // Post notification for other components to react
        NotificationCenter.default.post(
            name: .performanceModeChanged,
            object: mode
        )
    }

    // MARK: - Thermal State Observer

    private func setupThermalStateObserver() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleThermalStateChange()
            }
        }
    }

    private func handleThermalStateChange() async {
        let newState = processInfo.thermalState
        thermalState = newState

        logger.info("🌡 Thermal state changed: \(String(describing: newState))")

        // Trigger immediate optimization
        await updateMetrics()
        analyzeAndOptimize()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let performanceModeChanged = Notification.Name("performanceModeChanged")
}
