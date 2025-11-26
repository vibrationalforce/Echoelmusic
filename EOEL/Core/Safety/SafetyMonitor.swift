//
//  SafetyMonitor.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Comprehensive safety monitoring and protection system
//

import Foundation
import AVFoundation
import os.log

/// Safety monitoring and protection system
@MainActor
final class SafetyMonitor: ObservableObject {
    static let shared = SafetyMonitor()

    // MARK: - Published Properties

    @Published var audioLevelWarning = false
    @Published var heatingWarning = false
    @Published var batteryWarning = false
    @Published var dataIntegrityWarning = false

    // MARK: - Safety Limits

    struct SafetyLimits {
        static let maxAudioLevel: Float = 0.95        // 95% of max to prevent clipping
        static let maxContinuousLevel: Float = 0.85   // 85% for extended periods
        static let maxTemperature: Double = 45.0      // 45°C device temperature
        static let minBatteryLevel: Float = 0.10      // 10% battery minimum
        static let maxFileSize: UInt64 = 1_000_000_000 // 1GB file size limit
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.eoel.app", category: "Safety")
    private var audioLevelHistory: [Float] = []
    private var monitoringTimer: Timer?

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performSafetyChecks()
            }
        }
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func performSafetyChecks() {
        checkAudioLevels()
        checkDeviceTemperature()
        checkBatteryLevel()
        checkDataIntegrity()
    }

    // MARK: - Audio Safety

    func checkAudioLevel(_ level: Float) {
        // Check instantaneous level
        if level > SafetyLimits.maxAudioLevel {
            audioLevelWarning = true
            logger.warning("Audio level dangerously high: \(level * 100, privacy: .public)%")

            // Apply soft limiter
            applySoftLimiter()
        }

        // Track level history
        audioLevelHistory.append(level)
        if audioLevelHistory.count > 60 {  // Keep 60 seconds
            audioLevelHistory.removeFirst()
        }

        // Check sustained high levels
        let avgLevel = audioLevelHistory.reduce(0, +) / Float(audioLevelHistory.count)
        if avgLevel > SafetyLimits.maxContinuousLevel {
            logger.warning("Sustained high audio level: \(avgLevel * 100, privacy: .public)%")
            NotificationCenter.default.post(name: .audioLevelWarning, object: avgLevel)
        }
    }

    private func checkAudioLevels() {
        // Periodic audio level check
        // In production, this would check current audio engine levels
    }

    private func applySoftLimiter() {
        // Apply soft limiting to prevent clipping
        NotificationCenter.default.post(name: .applySoftLimiter, object: nil)
    }

    // MARK: - Temperature Safety

    private func checkDeviceTemperature() {
        // iOS doesn't directly expose temperature, but we can infer from thermal state
        #if !os(macOS)
        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
        case .critical:
            heatingWarning = true
            logger.critical("Device temperature CRITICAL - reducing performance")
            handleCriticalTemperature()

        case .serious:
            heatingWarning = true
            logger.warning("Device temperature serious")
            handleHighTemperature()

        case .fair:
            logger.info("Device temperature elevated")

        case .nominal:
            heatingWarning = false

        @unknown default:
            break
        }
        #endif
    }

    private func handleHighTemperature() {
        // Reduce processing load
        NotificationCenter.default.post(name: .reduceQuality, object: nil)

        // Reduce screen brightness
        #if !os(macOS)
        UIScreen.main.brightness = max(UIScreen.main.brightness - 0.2, 0.3)
        #endif
    }

    private func handleCriticalTemperature() {
        // Emergency cooling measures
        logger.critical("Applying emergency thermal management")

        // Stop all non-essential processing
        NotificationCenter.default.post(name: .disableNonEssentialFeatures, object: nil)

        // Reduce audio processing quality
        NotificationCenter.default.post(name: .reduceAudioQuality, object: nil)

        // Show warning to user
        NotificationCenter.default.post(
            name: .showUserWarning,
            object: "Device is overheating. Reducing performance to cool down."
        )
    }

    // MARK: - Battery Safety

    private func checkBatteryLevel() {
        #if !os(macOS)
        let batteryLevel = UIDevice.current.batteryLevel

        if batteryLevel > 0 && batteryLevel < SafetyLimits.minBatteryLevel {
            batteryWarning = true
            logger.warning("Battery critically low: \(batteryLevel * 100, privacy: .public)%")

            // Enable low power mode features
            enableLowPowerMode()
        } else {
            batteryWarning = false
        }

        // Check if charging
        let batteryState = UIDevice.current.batteryState
        if batteryState == .charging || batteryState == .full {
            // Can enable higher performance features
            NotificationCenter.default.post(name: .deviceCharging, object: nil)
        }
        #endif
    }

    private func enableLowPowerMode() {
        logger.info("Enabling low power mode features")

        // Reduce frame rate
        NotificationCenter.default.post(name: .reduceFPS, object: 30)  // 30 fps instead of 60

        // Reduce audio quality
        NotificationCenter.default.post(name: .reduceAudioQuality, object: nil)

        // Disable animations
        NotificationCenter.default.post(name: .disableAnimations, object: nil)

        // Reduce screen brightness
        #if !os(macOS)
        UIScreen.main.brightness = max(UIScreen.main.brightness - 0.3, 0.2)
        #endif
    }

    // MARK: - Data Integrity

    private func checkDataIntegrity() {
        // Verify critical data integrity
        // This would check checksums, file integrity, etc.
    }

    func verifyFileIntegrity(at url: URL) -> Bool {
        do {
            // Check file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.error("File does not exist: \(url.path, privacy: .public)")
                return false
            }

            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0

            if fileSize > SafetyLimits.maxFileSize {
                logger.warning("File size exceeds safe limit: \(fileSize / 1_000_000, privacy: .public) MB")
                return false
            }

            // Check if file is readable
            let data = try Data(contentsOf: url)
            if data.isEmpty {
                logger.warning("File is empty: \(url.path, privacy: .public)")
                return false
            }

            return true

        } catch {
            logger.error("File integrity check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Crash Prevention

    func setupCrashPrevention() {
        // Setup signal handlers for graceful crash handling
        signal(SIGABRT, { signal in
            let logger = Logger(subsystem: "com.eoel.app", category: "Crash")
            logger.critical("SIGABRT received - attempting graceful shutdown")

            // Save critical data
            NotificationCenter.default.post(name: .emergencyDataSave, object: nil)
        })

        signal(SIGSEGV, { signal in
            let logger = Logger(subsystem: "com.eoel.app", category: "Crash")
            logger.critical("SIGSEGV received - segmentation fault")
        })

        signal(SIGBUS, { signal in
            let logger = Logger(subsystem: "com.eoel.app", category: "Crash")
            logger.critical("SIGBUS received - bus error")
        })
    }

    // MARK: - Memory Safety

    func checkMemoryPressure() -> MemoryPressure {
        let memoryUsage = getMemoryUsage()
        let totalMemory = getTotalMemory()

        let usagePercentage = Double(memoryUsage) / Double(totalMemory)

        switch usagePercentage {
        case 0..<0.5:
            return .normal
        case 0.5..<0.7:
            return .elevated
        case 0.7..<0.9:
            return .critical
        default:
            return .emergency
        }
    }

    private func getMemoryUsage() -> UInt64 {
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

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func getTotalMemory() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }

    enum MemoryPressure {
        case normal
        case elevated
        case critical
        case emergency
    }

    // MARK: - Audio Safety Features

    func enableHearingSafetyMode() {
        logger.info("Enabling hearing safety mode")

        // Limit maximum volume
        let maxSafeVolume: Float = 0.70  // 70% max volume

        NotificationCenter.default.post(
            name: .limitMaxVolume,
            object: maxSafeVolume
        )

        // Enable audio level monitoring
        NotificationCenter.default.post(name: .enableAudioLevelMonitoring, object: nil)
    }

    func disableHearingSafetyMode() {
        logger.info("Disabling hearing safety mode")

        NotificationCenter.default.post(name: .disableAudioLevelMonitoring, object: nil)
    }

    // MARK: - System Health Check

    func performHealthCheck() -> SystemHealth {
        var issues: [String] = []

        // Check audio
        if audioLevelWarning {
            issues.append("Audio levels dangerously high")
        }

        // Check temperature
        if heatingWarning {
            issues.append("Device overheating")
        }

        // Check battery
        if batteryWarning {
            issues.append("Battery critically low")
        }

        // Check data integrity
        if dataIntegrityWarning {
            issues.append("Data integrity compromised")
        }

        // Check memory
        let memoryPressure = checkMemoryPressure()
        if memoryPressure == .critical || memoryPressure == .emergency {
            issues.append("Memory pressure \(memoryPressure)")
        }

        return SystemHealth(
            isHealthy: issues.isEmpty,
            issues: issues,
            timestamp: Date()
        )
    }
}

// MARK: - System Health

struct SystemHealth {
    let isHealthy: Bool
    let issues: [String]
    let timestamp: Date

    var criticalIssues: [String] {
        issues.filter { issue in
            issue.contains("critical") || issue.contains("dangerously") || issue.contains("compromised")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let audioLevelWarning = Notification.Name("com.eoel.audioLevelWarning")
    static let applySoftLimiter = Notification.Name("com.eoel.applySoftLimiter")
    static let reduceAudioQuality = Notification.Name("com.eoel.reduceAudioQuality")
    static let deviceCharging = Notification.Name("com.eoel.deviceCharging")
    static let reduceFPS = Notification.Name("com.eoel.reduceFPS")
    static let disableAnimations = Notification.Name("com.eoel.disableAnimations")
    static let emergencyDataSave = Notification.Name("com.eoel.emergencyDataSave")
    static let limitMaxVolume = Notification.Name("com.eoel.limitMaxVolume")
    static let enableAudioLevelMonitoring = Notification.Name("com.eoel.enableAudioLevelMonitoring")
    static let disableAudioLevelMonitoring = Notification.Name("com.eoel.disableAudioLevelMonitoring")
    static let showUserWarning = Notification.Name("com.eoel.showUserWarning")
}
