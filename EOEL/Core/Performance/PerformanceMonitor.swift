//
//  PerformanceMonitor.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Real-time performance monitoring and optimization
//

import Foundation
import AVFoundation
import Combine
import os.log

/// Performance monitoring and optimization manager
@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Published Properties

    @Published var audioLatency: TimeInterval = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: UInt64 = 0
    @Published var batteryLevel: Float = 1.0
    @Published var batteryDrainRate: Float = 0.0
    @Published var fps: Int = 60
    @Published var networkLatency: TimeInterval = 0.0

    // MARK: - Performance Targets

    struct PerformanceTargets {
        static let maxAudioLatency: TimeInterval = 0.002  // 2ms
        static let maxCPUUsage: Double = 70.0             // 70%
        static let maxMemoryUsage: UInt64 = 500_000_000   // 500 MB
        static let maxBatteryDrain: Float = 0.20          // 20% per hour
        static let minFPS: Int = 55                        // 55 fps (allow 5fps drop)
        static let maxNetworkLatency: TimeInterval = 0.200 // 200ms
    }

    // MARK: - Performance State

    enum PerformanceState {
        case optimal      // All metrics within targets
        case degraded     // Some metrics exceed targets
        case critical     // Multiple metrics exceed targets
        case emergency    // System resources critically low
    }

    @Published var currentState: PerformanceState = .optimal

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private let logger = Logger(subsystem: "com.eoel.app", category: "Performance")

    private var lastBatteryLevel: Float = 1.0
    private var lastBatteryCheckTime = Date()

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Monitor every second
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }

        // Enable battery monitoring
        #if !os(macOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func updateMetrics() {
        updateCPUUsage()
        updateMemoryUsage()
        updateBatteryMetrics()
        updatePerformanceState()
    }

    // MARK: - CPU Usage

    private func updateCPUUsage() {
        var totalUsage: Double = 0.0
        var threadCount: mach_msg_type_number_t = 0
        var threads: thread_act_array_t?

        let result = task_threads(mach_task_self_, &threads, &threadCount)

        guard result == KERN_SUCCESS, let threads = threads else {
            return
        }

        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(
                        threads[i],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        $0,
                        &threadInfoCount
                    )
                }
            }

            guard infoResult == KERN_SUCCESS else { continue }

            if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount))

        cpuUsage = totalUsage

        if totalUsage > PerformanceTargets.maxCPUUsage {
            logger.warning("CPU usage high: \(totalUsage, privacy: .public)%")
        }
    }

    // MARK: - Memory Usage

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return }

        memoryUsage = info.resident_size

        if memoryUsage > PerformanceTargets.maxMemoryUsage {
            logger.warning("Memory usage high: \(memoryUsage / 1_000_000, privacy: .public) MB")
            handleHighMemory()
        }
    }

    private func handleHighMemory() {
        // Clear caches
        URLCache.shared.removeAllCachedResponses()

        // Post notification for other components to reduce memory
        NotificationCenter.default.post(name: .memoryWarning, object: nil)
    }

    // MARK: - Battery Metrics

    private func updateBatteryMetrics() {
        #if !os(macOS)
        let currentLevel = UIDevice.current.batteryLevel
        batteryLevel = currentLevel

        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastBatteryCheckTime)

        if timeElapsed >= 60.0 {  // Calculate drain rate per hour
            let levelDrop = lastBatteryLevel - currentLevel
            batteryDrainRate = (levelDrop / Float(timeElapsed)) * 3600.0

            lastBatteryLevel = currentLevel
            lastBatteryCheckTime = now

            if batteryDrainRate > PerformanceTargets.maxBatteryDrain {
                logger.warning("Battery drain rate high: \(batteryDrainRate * 100, privacy: .public)%/hour")
            }
        }
        #endif
    }

    // MARK: - Audio Latency

    func measureAudioLatency() -> TimeInterval {
        // Measure round-trip latency
        let startTime = CACurrentMediaTime()

        // Simulate audio buffer processing
        // In real implementation, this would measure actual audio pipeline latency
        let bufferSize = AVAudioSession.sharedInstance().ioBufferDuration
        let sampleRate = AVAudioSession.sharedInstance().sampleRate

        let latency = (Double(bufferSize) * 1000.0) / sampleRate * 2.0  // Round trip

        audioLatency = latency / 1000.0  // Convert to seconds

        if audioLatency > PerformanceTargets.maxAudioLatency {
            logger.warning("Audio latency high: \(audioLatency * 1000, privacy: .public) ms")
        }

        return audioLatency
    }

    // MARK: - Network Latency

    func measureNetworkLatency(to url: URL) async -> TimeInterval {
        let startTime = CACurrentMediaTime()

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let endTime = CACurrentMediaTime()

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let latency = endTime - startTime
                networkLatency = latency

                if latency > PerformanceTargets.maxNetworkLatency {
                    logger.warning("Network latency high: \(latency * 1000, privacy: .public) ms")
                }

                return latency
            }
        } catch {
            logger.error("Network latency measurement failed: \(error.localizedDescription, privacy: .public)")
        }

        return 0.0
    }

    // MARK: - FPS Monitoring

    func updateFPS(_ newFPS: Int) {
        fps = newFPS

        if fps < PerformanceTargets.minFPS {
            logger.warning("FPS dropped: \(fps, privacy: .public)")
        }
    }

    // MARK: - Performance State

    private func updatePerformanceState() {
        var issueCount = 0

        if audioLatency > PerformanceTargets.maxAudioLatency { issueCount += 1 }
        if cpuUsage > PerformanceTargets.maxCPUUsage { issueCount += 1 }
        if memoryUsage > PerformanceTargets.maxMemoryUsage { issueCount += 1 }
        if batteryDrainRate > PerformanceTargets.maxBatteryDrain { issueCount += 1 }
        if fps < PerformanceTargets.minFPS { issueCount += 1 }
        if networkLatency > PerformanceTargets.maxNetworkLatency { issueCount += 1 }

        switch issueCount {
        case 0:
            currentState = .optimal
        case 1...2:
            currentState = .degraded
        case 3...4:
            currentState = .critical
        default:
            currentState = .emergency
            handleEmergencyState()
        }
    }

    private func handleEmergencyState() {
        logger.critical("Performance in EMERGENCY state - taking corrective actions")

        // Reduce quality
        NotificationCenter.default.post(name: .reduceQuality, object: nil)

        // Clear all caches
        handleHighMemory()

        // Disable non-essential features
        NotificationCenter.default.post(name: .disableNonEssentialFeatures, object: nil)
    }

    // MARK: - Performance Report

    func generateReport() -> PerformanceReport {
        PerformanceReport(
            audioLatency: audioLatency,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            batteryLevel: batteryLevel,
            batteryDrainRate: batteryDrainRate,
            fps: fps,
            networkLatency: networkLatency,
            state: currentState,
            timestamp: Date()
        )
    }
}

// MARK: - Performance Report

struct PerformanceReport: Codable {
    let audioLatency: TimeInterval
    let cpuUsage: Double
    let memoryUsage: UInt64
    let batteryLevel: Float
    let batteryDrainRate: Float
    let fps: Int
    let networkLatency: TimeInterval
    let state: PerformanceMonitor.PerformanceState
    let timestamp: Date

    var isHealthy: Bool {
        audioLatency <= PerformanceMonitor.PerformanceTargets.maxAudioLatency &&
        cpuUsage <= PerformanceMonitor.PerformanceTargets.maxCPUUsage &&
        memoryUsage <= PerformanceMonitor.PerformanceTargets.maxMemoryUsage &&
        batteryDrainRate <= PerformanceMonitor.PerformanceTargets.maxBatteryDrain &&
        fps >= PerformanceMonitor.PerformanceTargets.minFPS &&
        networkLatency <= PerformanceMonitor.PerformanceTargets.maxNetworkLatency
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryWarning = Notification.Name("com.eoel.memoryWarning")
    static let reduceQuality = Notification.Name("com.eoel.reduceQuality")
    static let disableNonEssentialFeatures = Notification.Name("com.eoel.disableNonEssentialFeatures")
}

// MARK: - Performance State Codable

extension PerformanceMonitor.PerformanceState: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)

        switch rawValue {
        case "optimal": self = .optimal
        case "degraded": self = .degraded
        case "critical": self = .critical
        case "emergency": self = .emergency
        default: self = .optimal
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let rawValue: String
        switch self {
        case .optimal: rawValue = "optimal"
        case .degraded: rawValue = "degraded"
        case .critical: rawValue = "critical"
        case .emergency: rawValue = "emergency"
        }

        try container.encode(rawValue, forKey: .rawValue)
    }
}

// MARK: - Launch Time Optimizer

final class LaunchTimeOptimizer {
    static let shared = LaunchTimeOptimizer()

    private var launchStartTime: CFAbsoluteTime = 0
    private var isFirstLaunch = true

    func markLaunchStart() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
    }

    func markLaunchComplete() {
        let launchTime = CFAbsoluteTimeGetCurrent() - launchStartTime

        let logger = Logger(subsystem: "com.eoel.app", category: "Launch")
        logger.info("App launch time: \(launchTime, privacy: .public)s")

        if launchTime > 2.0 {
            logger.warning("Launch time exceeded 2s target: \(launchTime, privacy: .public)s")
        }

        isFirstLaunch = false
    }

    func deferredInitialization() {
        // Defer heavy initialization to background
        DispatchQueue.global(qos: .utility).async {
            // Preload audio engine
            // Preload lighting controller
            // Preload other heavy components
        }
    }
}
