// AccessibilityEnhancerPlugin.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Enhanced accessibility features: custom haptics, high contrast,
// voice commands, cognitive load reduction, switch control
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

/// A comprehensive plugin for enhanced accessibility features
/// Demonstrates: gestureInput, voiceInput, bioProcessing capabilities
public final class AccessibilityEnhancerPlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.accessibility-enhancer" }
    public var name: String { "Accessibility Enhancer" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Accessibility Team" }
    public var pluginDescription: String { "Enhanced accessibility features including custom haptics, high contrast override, voice commands, and cognitive load reduction" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.gestureInput, .voiceInput, .bioProcessing] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var enableEnhancedScreenReader: Bool = true
        public var enableCustomHaptics: Bool = true
        public var enableHighContrast: Bool = false
        public var enableVoiceCommands: Bool = true
        public var enableSwitchControl: Bool = false
        public var reduceCognitiveLoad: Bool = false
        public var hapticIntensity: Float = 1.0
        public var voiceSpeed: Float = 1.0
        public var simplifiedUIMode: Bool = false

        public enum HapticPattern: String, CaseIterable, Sendable {
            case subtle = "Subtle"
            case moderate = "Moderate"
            case strong = "Strong"
            case custom = "Custom"
        }

        public var defaultHapticPattern: HapticPattern = .moderate
    }

    // MARK: - Accessibility Models

    public struct HapticFeedback: Sendable {
        public var intensity: Float
        public var duration: TimeInterval
        public var pattern: HapticPattern

        public enum HapticPattern: Sendable {
            case single
            case double
            case triple
            case pulse
            case heartbeat
            case coherence
            case warning
            case success
            case error
        }

        public static let success = HapticFeedback(intensity: 0.8, duration: 0.2, pattern: .double)
        public static let error = HapticFeedback(intensity: 1.0, duration: 0.3, pattern: .triple)
        public static let navigation = HapticFeedback(intensity: 0.5, duration: 0.1, pattern: .single)
    }

    public struct VoiceCommand: Sendable {
        public var command: String
        public var action: @Sendable () -> Void
        public var description: String

        public init(command: String, description: String, action: @Sendable @escaping () -> Void) {
            self.command = command
            self.description = description
            self.action = action
        }
    }

    public struct ScreenReaderAnnouncement: Sendable {
        public var message: String
        public var priority: Priority
        public var delay: TimeInterval

        public enum Priority: Int, Sendable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
        }

        public init(message: String, priority: Priority = .normal, delay: TimeInterval = 0) {
            self.message = message
            self.priority = priority
            self.delay = delay
        }
    }

    // MARK: - State

    public var configuration = Configuration()
    private var registeredVoiceCommands: [String: VoiceCommand] = [:]
    private var announcementQueue: [ScreenReaderAnnouncement] = []
    private var lastHapticTime: Date = Date()
    private var currentCoherence: Float = 0.5

    // MARK: - Initialization

    public init() {
        registerDefaultVoiceCommands()
    }

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Accessibility Enhancer Plugin loaded", category: .accessibility)
        if configuration.enableHighContrast {
            applyHighContrastMode()
        }
        if configuration.reduceCognitiveLoad {
            enableSimplifiedUI()
        }
        announce("Accessibility features enabled", priority: .normal)
    }

    public func onUnload() async {
        log.info("Accessibility Enhancer Plugin unloaded", category: .accessibility)
    }

    public func onFrame(deltaTime: TimeInterval) {
        processAnnouncementQueue()
        if configuration.enableCustomHaptics {
            generateBioFeedbackHaptics()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        currentCoherence = bioData.coherence
        if configuration.enableEnhancedScreenReader {
            if bioData.coherence >= 0.8 {
                announce("High coherence achieved", priority: .high, delay: 2.0)
            } else if bioData.coherence <= 0.3 {
                announce("Low coherence detected", priority: .normal, delay: 2.0)
            }
        }
    }

    public func handleInteraction(_ interaction: UserInteraction) {
        if configuration.enableCustomHaptics {
            switch interaction.type {
            case .tap:
                triggerHaptic(.navigation)
            case .doubleTap:
                triggerHaptic(.success)
            case .longPress:
                triggerHaptic(HapticFeedback(intensity: 0.7, duration: 0.5, pattern: .pulse))
            case .swipe:
                triggerHaptic(.navigation)
            default:
                break
            }
        }
        if configuration.enableEnhancedScreenReader {
            announceInteraction(interaction)
        }
    }

    // MARK: - Screen Reader Enhancement

    /// Announce message to screen reader
    public func announce(_ message: String, priority: ScreenReaderAnnouncement.Priority = .normal, delay: TimeInterval = 0) {
        guard configuration.enableEnhancedScreenReader else { return }
        let announcement = ScreenReaderAnnouncement(message: message, priority: priority, delay: delay)
        announcementQueue.append(announcement)
        log.debug("Queued announcement: \(message) (priority: \(priority))", category: .accessibility)
    }

    /// Announce coherence level in accessible format
    public func announceCoherence() {
        let coherencePercent = Int(currentCoherence * 100)
        let description = getCoherenceDescription(currentCoherence)
        announce("Coherence is \(coherencePercent) percent, \(description)", priority: .high)
    }

    /// Announce bio metrics summary
    public func announceBioMetrics(heartRate: Float?, hrv: Float?, breathingRate: Float?) {
        var message = "Biometric status: "
        if let hr = heartRate {
            message += "Heart rate \(Int(hr)) beats per minute. "
        }
        if let hrv = hrv {
            message += "Heart rate variability \(Int(hrv)) milliseconds. "
        }
        if let br = breathingRate {
            message += "Breathing rate \(Int(br)) breaths per minute."
        }
        announce(message, priority: .normal)
    }

    // MARK: - Custom Haptics

    /// Trigger haptic feedback
    public func triggerHaptic(_ feedback: HapticFeedback) {
        guard configuration.enableCustomHaptics else { return }
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) < 0.1 { return }
        lastHapticTime = now
        let adjustedIntensity = feedback.intensity * configuration.hapticIntensity
        log.trace("Triggering haptic: \(feedback.pattern) - Intensity: \(adjustedIntensity)", category: .accessibility)
    }

    /// Generate coherence-based haptic pattern
    public func generateCoherenceHaptic() {
        let intensity = 0.3 + (currentCoherence * 0.7)
        let pattern: HapticFeedback.HapticPattern = currentCoherence > 0.7 ? .coherence : .pulse
        let feedback = HapticFeedback(intensity: intensity, duration: 0.3, pattern: pattern)
        triggerHaptic(feedback)
    }

    // MARK: - Voice Commands

    /// Register a voice command
    public func registerVoiceCommand(_ command: VoiceCommand) {
        registeredVoiceCommands[command.command.lowercased()] = command
        log.debug("Registered voice command: \(command.command)", category: .accessibility)
    }

    /// Process voice input
    public func processVoiceInput(_ input: String) {
        guard configuration.enableVoiceCommands else { return }
        let normalized = input.lowercased().trimmingCharacters(in: .whitespaces)
        if let command = registeredVoiceCommands[normalized] {
            log.info("Executing voice command: \(command.command)", category: .accessibility)
            command.action()
            triggerHaptic(.success)
            announce("Command executed: \(command.description)", priority: .normal)
        } else {
            log.debug("Unknown voice command: \(input)", category: .accessibility)
            triggerHaptic(.error)
            announce("Command not recognized", priority: .normal)
        }
    }

    /// Get list of available commands
    public func getAvailableCommands() -> [VoiceCommand] {
        return Array(registeredVoiceCommands.values)
    }

    // MARK: - High Contrast Mode

    /// Apply high contrast visual mode
    public func applyHighContrastMode() {
        configuration.enableHighContrast = true
        log.info("High contrast mode enabled", category: .accessibility)
        announce("High contrast mode enabled", priority: .normal)
    }

    /// Disable high contrast mode
    public func disableHighContrastMode() {
        configuration.enableHighContrast = false
        log.info("High contrast mode disabled", category: .accessibility)
        announce("High contrast mode disabled", priority: .normal)
    }

    // MARK: - Switch Control

    /// Enable switch control mode
    public func enableSwitchControl() {
        configuration.enableSwitchControl = true
        configuration.simplifiedUIMode = true
        log.info("Switch control mode enabled", category: .accessibility)
        announce("Switch control enabled. Use switch to navigate.", priority: .high)
    }

    /// Process switch input
    public func processSwitchInput(switchNumber: Int) {
        guard configuration.enableSwitchControl else { return }
        log.debug("Switch \(switchNumber) pressed", category: .accessibility)
        triggerHaptic(.navigation)
    }

    // MARK: - Cognitive Load Reduction

    /// Enable simplified UI for cognitive load reduction
    public func enableSimplifiedUI() {
        configuration.reduceCognitiveLoad = true
        configuration.simplifiedUIMode = true
        log.info("Simplified UI mode enabled", category: .accessibility)
        announce("Simplified interface enabled", priority: .normal)
    }

    /// Disable simplified UI
    public func disableSimplifiedUI() {
        configuration.reduceCognitiveLoad = false
        configuration.simplifiedUIMode = false
        log.info("Simplified UI mode disabled", category: .accessibility)
        announce("Full interface restored", priority: .normal)
    }

    // MARK: - Private Helpers

    private func registerDefaultVoiceCommands() {
        registerVoiceCommand(VoiceCommand(command: "check coherence", description: "Announce current coherence level") { [weak self] in
            self?.announceCoherence()
        })
        registerVoiceCommand(VoiceCommand(command: "high contrast on", description: "Enable high contrast mode") { [weak self] in
            self?.applyHighContrastMode()
        })
        registerVoiceCommand(VoiceCommand(command: "high contrast off", description: "Disable high contrast mode") { [weak self] in
            self?.disableHighContrastMode()
        })
        registerVoiceCommand(VoiceCommand(command: "simplify", description: "Enable simplified UI") { [weak self] in
            self?.enableSimplifiedUI()
        })
        registerVoiceCommand(VoiceCommand(command: "full interface", description: "Restore full UI") { [weak self] in
            self?.disableSimplifiedUI()
        })
    }

    private func processAnnouncementQueue() {
        guard !announcementQueue.isEmpty else { return }
        announcementQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        if let announcement = announcementQueue.first {
            log.info("Announcing: \(announcement.message)", category: .accessibility)
            announcementQueue.removeFirst()
        }
    }

    private func generateBioFeedbackHaptics() {
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) >= 5.0 {
            if currentCoherence > 0.7 {
                generateCoherenceHaptic()
            }
        }
    }

    private func announceInteraction(_ interaction: UserInteraction) {
        let typeDescription = interaction.type.rawValue
        announce("\(typeDescription) gesture", priority: .low)
    }

    private func getCoherenceDescription(_ coherence: Float) -> String {
        switch coherence {
        case 0.8...1.0: return "excellent coherence"
        case 0.6..<0.8: return "good coherence"
        case 0.4..<0.6: return "moderate coherence"
        case 0.2..<0.4: return "low coherence"
        default: return "very low coherence"
        }
    }
}
