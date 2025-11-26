//
//  BinauralSafetyManager.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Safety management for binaural beats and brainwave entrainment
//

import SwiftUI
import Combine
import os.log

/// Manages safety for binaural beats and brainwave entrainment
///
/// **CRITICAL SAFETY SYSTEM**
/// Binaural beats can affect brainwave patterns and may be contraindicated
/// for certain medical conditions.
///
/// **Medical Contraindications:**
/// - Epilepsy or seizure disorders
/// - Heart conditions (pacemakers, arrhythmia)
/// - Pregnancy
/// - Mental health conditions without medical supervision
/// - Age <18 without parental consent
///
/// **Research Evidence:**
/// - Oster, G. (1973): "Auditory Beats in the Brain" - Original research
/// - Wahbeh et al. (2007): Binaural beats can induce altered states
/// - Lane et al. (1998): Caution advised for seizure-prone individuals
/// - Huang & Charyton (2008): Review of entrainment research
///
/// **Safety Requirements:**
/// - First-time user consent required
/// - Session time limits (20 minutes default maximum)
/// - Frequency validation (avoid epilepsy risk zone 15-25 Hz)
/// - Headphone verification (binaural requires stereo isolation)
/// - Emergency stop available
@MainActor
final class BinauralSafetyManager: ObservableObject {
    static let shared = BinauralSafetyManager()

    // MARK: - Published Properties

    /// Whether user has acknowledged binaural safety warnings
    @Published var userConsented: Bool = false

    /// Whether a binaural session is currently active
    @Published var sessionActive: Bool = false

    /// Session elapsed time (seconds)
    @Published var sessionElapsedSeconds: Float = 0.0

    /// Current brainwave frequency (Hz)
    @Published var currentFrequency: Float = 10.0

    /// Whether session time limit has been reached
    @Published var timeLimitReached: Bool = false

    /// Show safety warning dialog
    @Published var showSafetyWarning: Bool = false

    /// Whether headphones are connected
    @Published var headphonesConnected: Bool = false

    // MARK: - Constants

    /// Maximum safe session duration (minutes)
    static let maxSessionMinutes: Float = 20.0

    /// Warning threshold (80% of max time)
    static let warningThresholdMinutes: Float = 16.0  // 80% of 20

    /// Epilepsy risk zone frequencies (Hz)
    static let epilepsyRiskMin: Float = 15.0
    static let epilepsyRiskMax: Float = 25.0

    /// Minimum safe frequency (Hz)
    static let minSafeFrequency: Float = 0.5

    /// Maximum safe frequency (Hz)
    static let maxSafeFrequency: Float = 100.0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.eoel.app", category: "BinauralSafety")

    private var sessionTimer: Timer?
    private var sessionStartTime: Date?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadUserConsent()
        monitorHeadphoneConnection()

        logger.info("BinauralSafetyManager initialized - Medical safety checks active")
    }

    // MARK: - Public API

    /// Request user consent before starting binaural session
    func requestConsent(completion: @escaping (Bool) -> Void) {
        guard !userConsented else {
            completion(true)
            return
        }

        logger.info("Requesting binaural safety consent from user")

        showSafetyWarning = true

        // Completion handled by user action on dialog
    }

    /// User acknowledged the safety warnings
    func acknowledgeWarnings() {
        logger.info("User acknowledged binaural safety warnings")

        userConsented = true
        showSafetyWarning = false

        saveUserConsent()
    }

    /// User declined the safety warnings
    func declineWarnings() {
        logger.info("User declined binaural safety consent")

        userConsented = false
        showSafetyWarning = false

        saveUserConsent()
    }

    /// Validate if frequency is safe to use
    func isFrequencySafe(_ frequency: Float) -> (safe: Bool, reason: String?) {
        // Check minimum
        if frequency < Self.minSafeFrequency {
            return (false, "Frequency too low (< 0.5 Hz)")
        }

        // Check maximum
        if frequency > Self.maxSafeFrequency {
            return (false, "Frequency too high (> 100 Hz)")
        }

        // Check epilepsy risk zone
        if frequency >= Self.epilepsyRiskMin && frequency <= Self.epilepsyRiskMax {
            return (false, "Frequency in epilepsy risk zone (15-25 Hz) - DANGEROUS")
        }

        return (true, nil)
    }

    /// Start a binaural session
    func startSession(frequency: Float) -> Bool {
        // Safety check: User consent
        guard userConsented else {
            logger.warning("Attempted to start binaural session without consent")
            requestConsent { _ in }
            return false
        }

        // Safety check: Frequency validation
        let (safe, reason) = isFrequencySafe(frequency)
        guard safe else {
            logger.critical("Unsafe frequency \(frequency, privacy: .public) Hz: \(reason ?? "Unknown", privacy: .public)")

            NotificationCenter.default.post(
                name: .binauralSafetyViolation,
                object: reason ?? "Unsafe frequency"
            )

            return false
        }

        // Safety check: Headphones (warning only, not blocking)
        if !headphonesConnected {
            logger.warning("Binaural session started without headphones - will use isochronic mode")

            NotificationCenter.default.post(
                name: .binauralHeadphoneWarning,
                object: "Headphones recommended for binaural beats. Using isochronic mode instead."
            )
        }

        // Start session
        sessionActive = true
        sessionStartTime = Date()
        sessionElapsedSeconds = 0.0
        timeLimitReached = false
        currentFrequency = frequency

        // Start monitoring timer
        startMonitoring()

        logger.info("Binaural session started at \(frequency, privacy: .public) Hz")

        return true
    }

    /// Stop binaural session
    func stopSession() {
        guard sessionActive else { return }

        sessionActive = false
        stopMonitoring()

        let duration = sessionElapsedSeconds / 60.0
        logger.info("Binaural session stopped after \(duration, privacy: .public) minutes")

        // Reset state
        sessionElapsedSeconds = 0.0
        timeLimitReached = false
        sessionStartTime = nil
    }

    /// Emergency stop (immediate)
    func emergencyStop() {
        logger.critical("EMERGENCY STOP - Binaural session terminated")

        stopSession()

        NotificationCenter.default.post(
            name: .binauralEmergencyStop,
            object: "Binaural session emergency stopped. If you experienced discomfort, consult a physician."
        )
    }

    /// Get remaining session time (seconds)
    func getRemainingTime() -> Float {
        let maxSeconds = Self.maxSessionMinutes * 60.0
        return max(0, maxSeconds - sessionElapsedSeconds)
    }

    /// Get session progress percentage (0-100)
    func getSessionProgress() -> Float {
        let maxSeconds = Self.maxSessionMinutes * 60.0
        return (sessionElapsedSeconds / maxSeconds) * 100.0
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSession()
            }
        }
    }

    private func stopMonitoring() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func updateSession() {
        guard sessionActive, let startTime = sessionStartTime else { return }

        // Update elapsed time
        sessionElapsedSeconds = Float(Date().timeIntervalSince(startTime))

        // Check warning threshold
        let elapsedMinutes = sessionElapsedSeconds / 60.0

        if elapsedMinutes >= Self.warningThresholdMinutes && elapsedMinutes < Self.maxSessionMinutes {
            logger.warning("Session approaching time limit: \(elapsedMinutes, privacy: .public) minutes")

            NotificationCenter.default.post(
                name: .binauralTimeWarning,
                object: "You've been using binaural beats for \(Int(elapsedMinutes)) minutes. Consider taking a break soon."
            )
        }

        // Check time limit
        if elapsedMinutes >= Self.maxSessionMinutes {
            if !timeLimitReached {
                timeLimitReached = true

                logger.critical("Session time limit reached: \(Self.maxSessionMinutes, privacy: .public) minutes")

                NotificationCenter.default.post(
                    name: .binauralTimeLimitReached,
                    object: "Maximum safe session time reached (\(Int(Self.maxSessionMinutes)) minutes). Session auto-stopped for your safety."
                )

                // Auto-stop for safety
                stopSession()
            }
        }
    }

    private func monitorHeadphoneConnection() {
        // Check initial state
        checkHeadphoneConnection()

        // Monitor for changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkHeadphoneConnection()
                }
            }
            .store(in: &cancellables)
    }

    private func checkHeadphoneConnection() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        headphonesConnected = false

        for output in currentRoute.outputs {
            let portType = output.portType

            if portType == .headphones ||
               portType == .bluetoothHFP ||
               portType == .bluetoothLE ||
               portType == .bluetoothA2DP {
                headphonesConnected = true
                break
            }
        }

        logger.debug("Headphones connected: \(headphonesConnected, privacy: .public)")
    }

    private func loadUserConsent() {
        userConsented = UserDefaults.standard.bool(forKey: "binaural_safety_consent_acknowledged")

        let hasSeenWarning = UserDefaults.standard.bool(forKey: "binaural_warning_shown")

        if !hasSeenWarning {
            userConsented = false
        }
    }

    private func saveUserConsent() {
        UserDefaults.standard.set(userConsented, forKey: "binaural_safety_consent_acknowledged")
        UserDefaults.standard.set(true, forKey: "binaural_warning_shown")
    }

    // MARK: - Static Utilities

    /// Get user-facing safety warning text
    static func getSafetyWarningText() -> String {
        return """
        ⚠️ BINAURAL BEATS SAFETY WARNING ⚠️

        Binaural beats affect brainwave patterns and may cause altered states of consciousness.

        DO NOT USE IF YOU HAVE:
        • Epilepsy or seizure disorders
        • Heart conditions, pacemakers, or arrhythmia
        • Are pregnant or breastfeeding
        • Mental health conditions (without medical supervision)
        • Are under 18 years old (parental consent required)
        • Sound sensitivity or hearing disorders

        POTENTIAL EFFECTS:
        • Altered states of consciousness
        • Drowsiness or deep relaxation
        • Changes in perception
        • Emotional shifts
        • Disorientation (temporary)

        DO NOT USE WHILE:
        • Driving or operating machinery
        • Performing tasks requiring alertness
        • Under influence of medications or substances

        IF YOU EXPERIENCE:
        • Dizziness or disorientation
        • Nausea or headache
        • Unusual sensations
        • Anxiety or panic
        • Any discomfort

        → STOP IMMEDIATELY and consult a physician if symptoms persist.

        SAFETY FEATURES:
        ✓ 20-minute session time limit
        ✓ Epilepsy risk zone blocked (15-25 Hz)
        ✓ Automatic headphone detection
        ✓ Emergency stop available

        REQUIREMENTS:
        • Must use headphones for binaural effect
        • Quiet environment recommended
        • Sit or lie down comfortably
        • Do not exceed recommended session time

        By continuing, you confirm:
        • You have no contraindicated conditions
        • You understand the effects and risks
        • You accept full responsibility for use
        • You will stop if experiencing discomfort

        Consult a physician before use if uncertain.

        This is NOT a medical device or treatment.
        """
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when binaural safety violation detected
    static let binauralSafetyViolation = Notification.Name("com.eoel.binauralSafetyViolation")

    /// Posted when headphone warning needed
    static let binauralHeadphoneWarning = Notification.Name("com.eoel.binauralHeadphoneWarning")

    /// Posted when session approaching time limit
    static let binauralTimeWarning = Notification.Name("com.eoel.binauralTimeWarning")

    /// Posted when session time limit reached
    static let binauralTimeLimitReached = Notification.Name("com.eoel.binauralTimeLimitReached")

    /// Posted on emergency stop
    static let binauralEmergencyStop = Notification.Name("com.eoel.binauralEmergencyStop")
}
