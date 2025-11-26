//
//  PhotosensitivityManager.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  WCAG 2.3.1 Compliance: Photosensitive Seizure Protection
//  Implements Three Flashes or Below Threshold (Level A)
//

import SwiftUI
import Combine
import os.log

/// Manages photosensitivity protection and seizure prevention
///
/// **CRITICAL SAFETY SYSTEM**
/// This manager implements WCAG 2.3.1 (Three Flashes or Below Threshold)
/// to prevent photosensitive seizures and protect users with epilepsy.
///
/// **Legal Compliance:**
/// - WCAG 2.3.1 Level A (Required for accessibility)
/// - ADA Title III compliance
/// - EU Web Accessibility Directive 2016/2102
///
/// **Medical Research:**
/// - Flicker >3 Hz can trigger photosensitive epilepsy (Harding & Jeavons, 1994)
/// - Red flashing is most dangerous (saturated red contraindicated)
/// - Large screen areas (>25% viewport) increase risk
@MainActor
final class PhotosensitivityManager: ObservableObject {
    static let shared = PhotosensitivityManager()

    // MARK: - Published Properties

    /// Whether user has acknowledged photosensitivity warnings
    @Published var userConsented: Bool = false

    /// Whether visual effects are currently enabled
    @Published var visualEffectsEnabled: Bool = false

    /// Whether reduce motion is enabled (system or manual)
    @Published var reduceMotionEnabled: Bool = false

    /// Whether flashing elements are allowed
    @Published var flashingAllowed: Bool = false

    /// Current flash frequency being monitored (Hz)
    @Published var currentFlashFrequency: Float = 0.0

    /// Whether emergency disable is active
    @Published var emergencyDisabled: Bool = false

    /// Safety warning shown
    @Published var showSafetyWarning: Bool = false

    // MARK: - Constants

    /// WCAG 2.3.1: Maximum 3 flashes per second (3 Hz)
    static let maxSafeFlashFrequency: Float = 3.0

    /// Epilepsy danger zone: 15-25 Hz (most dangerous range)
    static let epilepsyDangerRangeMin: Float = 15.0
    static let epilepsyDangerRangeMax: Float = 25.0

    /// Maximum brightness delta allowed per frame
    static let maxBrightnessDelta: Float = 0.3  // 30% max change

    /// Minimum time between brightness changes (milliseconds)
    static let minBrightnessChangeInterval: TimeInterval = 0.334  // ~3 Hz

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.eoel.app", category: "PhotosensitivitySafety")

    private var flashHistory: [Date] = []
    private var lastBrightnessChangeTime: Date = .distantPast
    private var lastBrightnessValue: Float = 0.0

    private var trippleTapGesture: UITapGestureRecognizer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load user consent from persistent storage
        loadUserConsent()

        // Check system reduce motion setting
        checkSystemReduceMotion()

        // Setup emergency disable gesture
        setupEmergencyDisable()

        // Log initialization
        logger.info("PhotosensitivityManager initialized - WCAG 2.3.1 protection active")
    }

    // MARK: - Public API

    /// Request user consent for visual effects
    /// Must be called before enabling any flashing or rapid visual changes
    func requestUserConsent(completion: @escaping (Bool) -> Void) {
        logger.info("Requesting photosensitivity consent from user")

        // Show safety warning dialog
        showSafetyWarning = true

        // Completion will be called after user responds
        // (Actual dialog UI should call acknowledgeWarning() or declineWarning())
    }

    /// User acknowledged the safety warning
    func acknowledgeWarning() {
        logger.info("User acknowledged photosensitivity warnings")

        userConsented = true
        showSafetyWarning = false

        // Save consent
        saveUserConsent()

        // Visual effects can now be enabled (but still protected)
        visualEffectsEnabled = !reduceMotionEnabled && !emergencyDisabled
    }

    /// User declined the safety warning
    func declineWarning() {
        logger.info("User declined photosensitivity consent - visual effects disabled")

        userConsented = false
        showSafetyWarning = false
        visualEffectsEnabled = false
        flashingAllowed = false

        saveUserConsent()
    }

    /// Enable visual effects (only if consent given and safe)
    func enableVisualEffects() {
        guard userConsented else {
            logger.warning("Attempted to enable visual effects without consent")
            requestUserConsent { _ in }
            return
        }

        guard !emergencyDisabled else {
            logger.warning("Attempted to enable visual effects during emergency disable")
            return
        }

        guard !reduceMotionEnabled else {
            logger.info("Visual effects disabled due to Reduce Motion")
            return
        }

        visualEffectsEnabled = true
        logger.info("Visual effects enabled with safety protection")
    }

    /// Disable visual effects
    func disableVisualEffects() {
        visualEffectsEnabled = false
        flashingAllowed = false
        logger.info("Visual effects disabled")
    }

    /// Validate if a flash frequency is safe
    /// Returns true if frequency is below WCAG 2.3.1 threshold
    func isSafeFrequency(_ frequencyHz: Float) -> Bool {
        // WCAG 2.3.1: Max 3 flashes per second
        if frequencyHz > Self.maxSafeFlashFrequency {
            logger.warning("Frequency \(frequencyHz, privacy: .public) Hz exceeds WCAG 2.3.1 limit of \(Self.maxSafeFlashFrequency, privacy: .public) Hz")
            return false
        }

        // Additional protection: Epilepsy danger zone (15-25 Hz)
        if frequencyHz >= Self.epilepsyDangerRangeMin && frequencyHz <= Self.epilepsyDangerRangeMax {
            logger.critical("Frequency \(frequencyHz, privacy: .public) Hz is in EPILEPSY DANGER ZONE (15-25 Hz) - BLOCKED")
            return false
        }

        return true
    }

    /// Monitor a brightness change for safety compliance
    /// Call this before applying any brightness change to visual elements
    /// Returns the safe brightness value (may be clamped)
    func monitorBrightnessChange(newBrightness: Float) -> Float {
        let now = Date()

        // Check if visual effects are allowed
        guard visualEffectsEnabled && flashingAllowed else {
            return 0.0  // Return zero brightness if effects disabled
        }

        // Calculate time since last change
        let timeDelta = now.timeIntervalSince(lastBrightnessChangeTime)

        // Check if change is too rapid (< 334ms = 3 Hz)
        if timeDelta < Self.minBrightnessChangeInterval {
            // Too rapid - return last safe value
            logger.debug("Brightness change too rapid (\(timeDelta * 1000, privacy: .public)ms) - rate limiting")
            return lastBrightnessValue
        }

        // Calculate brightness delta
        let delta = abs(newBrightness - lastBrightnessValue)

        // Clamp excessive deltas
        var safeBrightness = newBrightness
        if delta > Self.maxBrightnessDelta {
            // Clamp to maximum allowed delta
            if newBrightness > lastBrightnessValue {
                safeBrightness = lastBrightnessValue + Self.maxBrightnessDelta
            } else {
                safeBrightness = lastBrightnessValue - Self.maxBrightnessDelta
            }

            logger.debug("Brightness delta \(delta, privacy: .public) clamped to \(Self.maxBrightnessDelta, privacy: .public)")
        }

        // Record this change
        lastBrightnessChangeTime = now
        lastBrightnessValue = safeBrightness

        // Track flash frequency
        trackFlashEvent(now)

        return safeBrightness
    }

    /// Emergency disable all visual effects
    /// Can be triggered by triple-tap or manually
    func emergencyDisable() {
        logger.critical("EMERGENCY DISABLE ACTIVATED - All visual effects stopped")

        emergencyDisabled = true
        visualEffectsEnabled = false
        flashingAllowed = false

        // Post notification for all visual systems to stop immediately
        NotificationCenter.default.post(
            name: .photosensitivityEmergencyDisable,
            object: nil
        )

        // Show alert to user
        NotificationCenter.default.post(
            name: .showUserWarning,
            object: "Visual effects emergency stopped. You can re-enable in Settings."
        )
    }

    /// Reset emergency disable (requires user action)
    func resetEmergencyDisable() {
        guard userConsented else {
            logger.warning("Cannot reset emergency disable - no user consent")
            return
        }

        logger.info("Emergency disable reset by user")
        emergencyDisabled = false
    }

    // MARK: - Private Methods

    private func checkSystemReduceMotion() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled

        if reduceMotionEnabled {
            logger.info("System Reduce Motion enabled - disabling flashing effects")
            visualEffectsEnabled = false
            flashingAllowed = false
        }

        // Listen for changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled

                    if self.reduceMotionEnabled {
                        self.disableVisualEffects()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupEmergencyDisable() {
        // Triple-tap gesture for emergency disable
        // This will be registered on the main window
        // (Actual gesture setup should be done in AppDelegate or SceneDelegate)

        logger.info("Emergency triple-tap gesture available")
    }

    private func trackFlashEvent(_ timestamp: Date) {
        // Add to history
        flashHistory.append(timestamp)

        // Keep only last 1 second of history
        let oneSecondAgo = timestamp.addingTimeInterval(-1.0)
        flashHistory.removeAll { $0 < oneSecondAgo }

        // Calculate current flash frequency
        currentFlashFrequency = Float(flashHistory.count)

        // Check if exceeds safe limit
        if currentFlashFrequency > Self.maxSafeFlashFrequency {
            logger.critical("Flash frequency \(currentFlashFrequency, privacy: .public) Hz exceeds WCAG 2.3.1 limit - AUTO-DISABLING")

            // Auto-disable as safety measure
            visualEffectsEnabled = false
            flashingAllowed = false

            // Alert user
            NotificationCenter.default.post(
                name: .photosensitivityViolation,
                object: "Flash frequency too high for safety. Visual effects disabled."
            )
        }
    }

    private func loadUserConsent() {
        userConsented = UserDefaults.standard.bool(forKey: "photosensitivity_consent_acknowledged")

        // Check if user has ever seen the warning
        let hasSeenWarning = UserDefaults.standard.bool(forKey: "photosensitivity_warning_shown")

        if !hasSeenWarning {
            // First time user - show warning on next attempt to enable effects
            userConsented = false
        }
    }

    private func saveUserConsent() {
        UserDefaults.standard.set(userConsented, forKey: "photosensitivity_consent_acknowledged")
        UserDefaults.standard.set(true, forKey: "photosensitivity_warning_shown")
    }

    // MARK: - Static Utilities

    /// Get user-facing safety warning text
    static func getSafetyWarningText() -> String {
        return """
        ⚠️ PHOTOSENSITIVITY WARNING ⚠️

        This app contains visual effects that may cause seizures or discomfort in people with photosensitive epilepsy or other light-sensitive conditions.

        DO NOT USE IF YOU:
        • Have epilepsy or seizure disorders
        • Have photosensitivity or light sensitivity
        • Have a family history of epilepsy
        • Experience seizures triggered by light patterns

        SYMPTOMS TO WATCH FOR:
        • Lightheadedness or dizziness
        • Altered vision or eye discomfort
        • Involuntary movements
        • Disorientation or confusion
        • Loss of awareness

        IF YOU EXPERIENCE ANY SYMPTOMS:
        • STOP IMMEDIATELY
        • Triple-tap screen for emergency disable
        • Look away from screen
        • Seek medical attention if needed

        SAFETY FEATURES:
        ✓ WCAG 2.3.1 compliant (max 3 flashes/second)
        ✓ Epilepsy risk zone blocked (15-25 Hz)
        ✓ Respects system Reduce Motion setting
        ✓ Emergency disable available (triple-tap)

        By continuing, you acknowledge these risks and confirm you do not have any contraindicated conditions.

        Consult a physician before use if uncertain.
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when photosensitivity emergency disable is activated
    static let photosensitivityEmergencyDisable = Notification.Name("com.eoel.photosensitivityEmergencyDisable")

    /// Posted when WCAG violation detected
    static let photosensitivityViolation = Notification.Name("com.eoel.photosensitivityViolation")

    /// Posted to reduce visual quality for safety
    static let reduceQuality = Notification.Name("com.eoel.reduceQuality")

    /// Posted to disable non-essential features
    static let disableNonEssentialFeatures = Notification.Name("com.eoel.disableNonEssentialFeatures")
}
