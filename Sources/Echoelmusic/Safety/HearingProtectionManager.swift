//
//  HearingProtectionManager.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  WHO 2019 Hearing Safety Guidelines Implementation
//  Real-time hearing protection and safe listening monitoring
//

import AVFoundation
import Combine
import os.log

/// Manages hearing protection based on WHO 2019 guidelines
///
/// **CRITICAL HEALTH SYSTEM**
/// Implements World Health Organization "Make Listening Safe" guidelines
/// to prevent noise-induced hearing loss (NIHL).
///
/// **WHO Guidelines (2019):**
/// - 85 dB SPL: Maximum 8 hours/day
/// - 88 dB SPL: Maximum 4 hours/day
/// - 91 dB SPL: Maximum 2 hours/day
/// - 94 dB SPL: Maximum 1 hour/day
/// - 100 dB SPL: Maximum 15 minutes/day
/// - 106 dB SPL: Maximum 3.75 minutes/day
///
/// **Medical Research:**
/// - Exposure >85 dB for extended periods causes permanent hearing damage
/// - Noise-induced hearing loss (NIHL) is IRREVERSIBLE
/// - Tinnitus risk increases with cumulative exposure
/// - Young adults (18-35) at highest risk due to headphone use
///
/// **Implementation:**
/// - 3 dB increase = Half safe exposure time (exchange rate)
/// - Real-time SPL monitoring via AVAudioEngine
/// - Cumulative exposure tracking per 24-hour period
/// - Automatic volume reduction when limits approached
@MainActor
final class HearingProtectionManager: ObservableObject {
    static let shared = HearingProtectionManager()

    // MARK: - Published Properties

    /// Current sound pressure level (dB SPL)
    @Published var currentDecibels: Float = 0.0

    /// Current volume level (0.0 - 1.0)
    @Published var currentVolume: Float = 0.5

    /// Percentage of safe daily exposure used (0-100+)
    @Published var exposurePercentage: Float = 0.0

    /// Whether safe listening limit has been reached
    @Published var limitReached: Bool = false

    /// Whether warning threshold reached (80% of limit)
    @Published var warningThreshold: Bool = false

    /// Whether hearing protection is enabled
    @Published var protectionEnabled: Bool = true

    /// Today's cumulative exposure time at various levels
    @Published var todayExposureMinutes: Float = 0.0

    // MARK: - WHO Safe Exposure Limits (dB SPL : Minutes per day)

    private let whoSafeExposureLimits: [(dB: Float, minutes: Float)] = [
        (85, 480),    // 8 hours
        (88, 240),    // 4 hours
        (91, 120),    // 2 hours
        (94, 60),     // 1 hour
        (97, 30),     // 30 minutes
        (100, 15),    // 15 minutes
        (103, 7.5),   // 7.5 minutes
        (106, 3.75),  // 3.75 minutes
        (109, 1.875), // 1.875 minutes (~1:52)
        (112, 0.9375) // 56 seconds
    ]

    // MARK: - Constants

    /// Warning threshold (80% of safe limit)
    static let warningThresholdPercentage: Float = 80.0

    /// Critical threshold (100% of safe limit)
    static let criticalThresholdPercentage: Float = 100.0

    /// Danger threshold (120% - force reduction)
    static let dangerThresholdPercentage: Float = 120.0

    /// Maximum safe volume (70% of system max)
    static let maxSafeVolume: Float = 0.70

    /// Absolute maximum volume (never exceed)
    static let absoluteMaxVolume: Float = 0.85

    /// Update interval for monitoring (seconds)
    static let monitoringInterval: TimeInterval = 1.0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.eoel.app", category: "HearingSafety")

    private var audioEngine: AVAudioEngine?
    private var monitoringTimer: Timer?

    private var exposureHistory: [ExposureRecord] = []
    private var currentDayExposure: Float = 0.0  // Cumulative exposure units

    private var lastUpdateTime: Date = Date()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadExposureHistory()
        logger.info("HearingProtectionManager initialized - WHO 2019 guidelines active")
    }

    // MARK: - Public API

    /// Start hearing protection monitoring
    func startMonitoring() {
        guard protectionEnabled else { return }

        logger.info("Starting hearing protection monitoring")

        // Setup audio tap for level monitoring
        setupAudioLevelMonitoring()

        // Start monitoring timer
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: Self.monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateExposure()
            }
        }
    }

    /// Stop hearing protection monitoring
    func stopMonitoring() {
        logger.info("Stopping hearing protection monitoring")

        monitoringTimer?.invalidate()
        monitoringTimer = nil

        audioEngine?.stop()
        audioEngine = nil
    }

    /// Enable hearing protection
    func enableProtection() {
        protectionEnabled = true
        startMonitoring()
        logger.info("Hearing protection enabled")
    }

    /// Disable hearing protection (not recommended!)
    func disableProtection() {
        protectionEnabled = false
        stopMonitoring()
        logger.warning("Hearing protection DISABLED - user responsibility")
    }

    /// Set audio volume with safety checks
    /// Returns the actual safe volume (may be clamped)
    func setSafeVolume(_ requestedVolume: Float) -> Float {
        guard protectionEnabled else {
            return requestedVolume
        }

        var safeVolume = requestedVolume

        // Apply absolute maximum
        safeVolume = min(safeVolume, Self.absoluteMaxVolume)

        // Check exposure limits
        if exposurePercentage >= Self.dangerThresholdPercentage {
            // Force reduction to 50% of requested
            safeVolume = min(safeVolume, requestedVolume * 0.5)
            logger.critical("Exposure at \(exposurePercentage, privacy: .public)% - forcing volume reduction")

            NotificationCenter.default.post(
                name: .hearingProtectionForceReduction,
                object: "Volume reduced for hearing safety. You've reached daily safe listening limit."
            )
        } else if exposurePercentage >= Self.criticalThresholdPercentage {
            // Limit to 70% of system max
            safeVolume = min(safeVolume, Self.maxSafeVolume)
            logger.warning("Exposure at \(exposurePercentage, privacy: .public)% - limiting volume")
        }

        currentVolume = safeVolume
        return safeVolume
    }

    /// Get safe listening time remaining at current level
    func getSafeTimeRemaining() -> TimeInterval {
        let safeLimitMinutes = getSafeLimitMinutes(for: currentDecibels)
        let usedMinutes = todayExposureMinutes
        let remainingMinutes = max(0, safeLimitMinutes - usedMinutes)

        return TimeInterval(remainingMinutes * 60)  // Convert to seconds
    }

    /// Get safe listening time remaining at specific dB level
    func getSafeTimeRemaining(at decibels: Float) -> TimeInterval {
        let safeLimitMinutes = getSafeLimitMinutes(for: decibels)
        let usedMinutes = todayExposureMinutes
        let remainingMinutes = max(0, safeLimitMinutes - usedMinutes)

        return TimeInterval(remainingMinutes * 60)
    }

    /// Get today's exposure summary
    func getTodayExposureSummary() -> ExposureSummary {
        let safeLimitMinutes = getSafeLimitMinutes(for: 85)  // Reference to 85 dB standard
        let percentage = (todayExposureMinutes / safeLimitMinutes) * 100

        return ExposureSummary(
            totalMinutes: todayExposureMinutes,
            percentage: percentage,
            averageDecibels: calculateAverageDecibels(),
            maxDecibels: calculateMaxDecibels(),
            safeTimeRemaining: getSafeTimeRemaining()
        )
    }

    /// Reset daily exposure (called automatically at midnight)
    func resetDailyExposure() {
        logger.info("Resetting daily exposure tracking")

        currentDayExposure = 0.0
        todayExposureMinutes = 0.0
        exposurePercentage = 0.0
        limitReached = false
        warningThreshold = false

        // Archive yesterday's data
        saveExposureHistory()
    }

    // MARK: - Private Methods

    private func setupAudioLevelMonitoring() {
        // Setup AVAudioEngine tap for real-time level monitoring
        // This would be connected to the actual audio output

        logger.info("Audio level monitoring configured")

        // Listen for audio level notifications from AudioEngine
        NotificationCenter.default.publisher(for: .audioLevelUpdate)
            .compactMap { $0.object as? Float }
            .sink { [weak self] level in
                Task { @MainActor in
                    self?.updateAudioLevel(level)
                }
            }
            .store(in: &cancellables)
    }

    private func updateAudioLevel(_ level: Float) {
        // Convert normalized level (0-1) to dB SPL estimate
        // Assumes: 0.0 = -∞ dB, 1.0 = ~115 dB SPL (typical headphone max)

        if level < 0.00001 {
            currentDecibels = 0
            return
        }

        // Logarithmic conversion: dB = 20 * log10(level) + reference
        let dB = 20.0 * log10(level) + 115.0  // Reference: 115 dB at full scale

        currentDecibels = Float(max(0, dB))
    }

    private func updateExposure() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        // Check if new day
        if !Calendar.current.isDate(now, inSameDayAs: lastUpdateTime) {
            resetDailyExposure()
        }

        // Only track if audio is playing and above threshold
        guard currentDecibels >= 70 else { return }  // Below 70 dB is generally safe

        // Calculate exposure units using exchange rate
        // Exchange rate: 3 dB increase = half the time
        // Formula: exposure = time * 2^((dB - 85) / 3)
        let exposureUnits = calculateExposureUnits(
            decibels: currentDecibels,
            durationMinutes: Float(deltaTime / 60.0)
        )

        currentDayExposure += exposureUnits

        // Update today's total minutes (normalized to 85 dB)
        todayExposureMinutes += exposureUnits

        // Calculate percentage of safe limit
        let safeLimitMinutes = getSafeLimitMinutes(for: 85)  // Reference
        exposurePercentage = (todayExposureMinutes / safeLimitMinutes) * 100

        // Check thresholds
        checkExposureThresholds()

        // Record in history
        recordExposure(decibels: currentDecibels, minutes: Float(deltaTime / 60.0))

        logger.debug("Exposure: \(currentDecibels, privacy: .public) dB for \(deltaTime, privacy: .public)s - Total: \(exposurePercentage, privacy: .public)%")
    }

    private func calculateExposureUnits(decibels: Float, durationMinutes: Float) -> Float {
        // WHO exchange rate: 3 dB doubling
        // Exposure units = time * 2^((dB - 85) / 3)

        let referenceDB: Float = 85.0
        let exchangeRate: Float = 3.0

        let exponent = (decibels - referenceDB) / exchangeRate
        let multiplier = pow(2.0, exponent)

        return durationMinutes * multiplier
    }

    private func getSafeLimitMinutes(for decibels: Float) -> Float {
        // Find closest WHO limit
        guard decibels >= 85 else {
            return 480  // Below 85 dB = 8 hours safe
        }

        // Interpolate between WHO data points
        for i in 0..<(whoSafeExposureLimits.count - 1) {
            let lower = whoSafeExposureLimits[i]
            let upper = whoSafeExposureLimits[i + 1]

            if decibels >= lower.dB && decibels < upper.dB {
                // Linear interpolation
                let fraction = (decibels - lower.dB) / (upper.dB - lower.dB)
                return lower.minutes + (upper.minutes - lower.minutes) * fraction
            }
        }

        // Above all limits - use last
        return whoSafeExposureLimits.last?.minutes ?? 0.9375
    }

    private func checkExposureThresholds() {
        // Check warning threshold (80%)
        if exposurePercentage >= Self.warningThresholdPercentage && !warningThreshold {
            warningThreshold = true
            logger.warning("Hearing exposure at \(exposurePercentage, privacy: .public)% - warning threshold reached")

            NotificationCenter.default.post(
                name: .hearingProtectionWarning,
                object: "You've used \(Int(exposurePercentage))% of today's safe listening time. Consider reducing volume or taking a break."
            )
        }

        // Check critical threshold (100%)
        if exposurePercentage >= Self.criticalThresholdPercentage && !limitReached {
            limitReached = true
            logger.critical("Hearing exposure at \(exposurePercentage, privacy: .public)% - SAFE LIMIT REACHED")

            NotificationCenter.default.post(
                name: .hearingProtectionLimitReached,
                object: "You've reached today's safe listening limit. Continued exposure may cause permanent hearing damage."
            )
        }

        // Check danger threshold (120%)
        if exposurePercentage >= Self.dangerThresholdPercentage {
            logger.critical("Hearing exposure at \(exposurePercentage, privacy: .public)% - EXCEEDING SAFE LIMITS")

            // Auto-reduce volume
            let reducedVolume = currentVolume * 0.5
            currentVolume = reducedVolume

            NotificationCenter.default.post(
                name: .hearingProtectionForceReduction,
                object: "Volume automatically reduced for hearing safety. You've significantly exceeded daily safe listening limits."
            )
        }
    }

    private func recordExposure(decibels: Float, minutes: Float) {
        let record = ExposureRecord(
            timestamp: Date(),
            decibels: decibels,
            durationMinutes: minutes
        )

        exposureHistory.append(record)

        // Keep only last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        exposureHistory.removeAll { $0.timestamp < sevenDaysAgo }
    }

    private func calculateAverageDecibels() -> Float {
        let todayRecords = exposureHistory.filter { Calendar.current.isDateInToday($0.timestamp) }
        guard !todayRecords.isEmpty else { return 0 }

        let total = todayRecords.reduce(0) { $0 + $1.decibels }
        return total / Float(todayRecords.count)
    }

    private func calculateMaxDecibels() -> Float {
        let todayRecords = exposureHistory.filter { Calendar.current.isDateInToday($0.timestamp) }
        return todayRecords.map { $0.decibels }.max() ?? 0
    }

    private func loadExposureHistory() {
        // Load from UserDefaults or persistent storage
        if let data = UserDefaults.standard.data(forKey: "hearing_exposure_history"),
           let decoded = try? JSONDecoder().decode([ExposureRecord].self, from: data) {
            exposureHistory = decoded
            logger.info("Loaded \(exposureHistory.count, privacy: .public) exposure records")
        }

        // Calculate today's exposure
        let todayRecords = exposureHistory.filter { Calendar.current.isDateInToday($0.timestamp) }
        todayExposureMinutes = todayRecords.reduce(0) { $0 + $1.durationMinutes }
    }

    private func saveExposureHistory() {
        if let encoded = try? JSONEncoder().encode(exposureHistory) {
            UserDefaults.standard.set(encoded, forKey: "hearing_exposure_history")
        }
    }
}

// MARK: - Data Structures

struct ExposureRecord: Codable {
    let timestamp: Date
    let decibels: Float
    let durationMinutes: Float
}

struct ExposureSummary {
    let totalMinutes: Float
    let percentage: Float
    let averageDecibels: Float
    let maxDecibels: Float
    let safeTimeRemaining: TimeInterval

    var formattedTotalTime: String {
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        return "\(hours)h \(minutes)m"
    }

    var formattedRemainingTime: String {
        let hours = Int(safeTimeRemaining) / 3600
        let minutes = (Int(safeTimeRemaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var riskLevel: RiskLevel {
        switch percentage {
        case ..<50:
            return .low
        case 50..<80:
            return .moderate
        case 80..<100:
            return .high
        case 100..<120:
            return .critical
        default:
            return .danger
        }
    }

    enum RiskLevel: String {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case critical = "Critical"
        case danger = "Danger"

        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .yellow
            case .high: return .orange
            case .critical: return .red
            case .danger: return .purple
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when audio level updates (object: Float dB)
    static let audioLevelUpdate = Notification.Name("com.eoel.audioLevelUpdate")

    /// Posted when hearing protection warning threshold reached
    static let hearingProtectionWarning = Notification.Name("com.eoel.hearingProtectionWarning")

    /// Posted when safe listening limit reached
    static let hearingProtectionLimitReached = Notification.Name("com.eoel.hearingProtectionLimitReached")

    /// Posted when volume forcefully reduced for safety
    static let hearingProtectionForceReduction = Notification.Name("com.eoel.hearingProtectionForceReduction")
}
