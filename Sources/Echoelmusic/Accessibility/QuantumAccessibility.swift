//
//  QuantumAccessibility.swift
//  Echoelmusic
//
//  A+++ Accessibility Support for Quantum Light Features
//  WCAG AAA Compliant - Universal Design
//
//  Created: 2026-01-05
//

import Foundation
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Quantum Accessibility Manager

@MainActor
public class QuantumAccessibilityManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var isReducedMotionEnabled: Bool = false
    @Published public var isVoiceOverRunning: Bool = false
    @Published public var preferredColorScheme: AccessibleColorScheme = .standard
    @Published public var audioDescriptionEnabled: Bool = false
    @Published public var hapticFeedbackEnabled: Bool = true
    @Published public var sonificationEnabled: Bool = true

    // MARK: - Accessibility Profiles

    public enum AccessibilityProfile: String, CaseIterable {
        case standard = "Standard"
        case lowVision = "Low Vision"
        case colorBlind = "Color Blind"
        case motionSensitive = "Motion Sensitive"
        case cognitive = "Cognitive Support"
        case screenReader = "Screen Reader"
        case fullAccessibility = "Full Accessibility"
    }

    public enum AccessibleColorScheme: String, CaseIterable {
        case standard = "Standard Spectrum"
        case deuteranopia = "Deuteranopia Safe"
        case protanopia = "Protanopia Safe"
        case tritanopia = "Tritanopia Safe"
        case highContrast = "High Contrast"
        case monochrome = "Monochrome"
    }

    // MARK: - Current Profile

    @Published public var currentProfile: AccessibilityProfile = .standard

    // MARK: - Singleton

    public static let shared = QuantumAccessibilityManager()

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupSystemAccessibilityObservers()
        loadUserPreferences()
    }

    // MARK: - Setup

    private func setupSystemAccessibilityObservers() {
        #if canImport(UIKit) && !os(watchOS)
        // Observe system accessibility settings
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)

        // Initial values
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        #endif
    }

    private func loadUserPreferences() {
        if let profileString = UserDefaults.standard.string(forKey: "quantum_accessibility_profile"),
           let profile = AccessibilityProfile(rawValue: profileString) {
            currentProfile = profile
            applyProfile(profile)
        }
    }

    // MARK: - Profile Application

    public func applyProfile(_ profile: AccessibilityProfile) {
        currentProfile = profile
        UserDefaults.standard.set(profile.rawValue, forKey: "quantum_accessibility_profile")

        switch profile {
        case .standard:
            audioDescriptionEnabled = false
            preferredColorScheme = .standard
            hapticFeedbackEnabled = true
            sonificationEnabled = false

        case .lowVision:
            audioDescriptionEnabled = true
            preferredColorScheme = .highContrast
            hapticFeedbackEnabled = true
            sonificationEnabled = true

        case .colorBlind:
            audioDescriptionEnabled = false
            preferredColorScheme = .deuteranopia
            hapticFeedbackEnabled = true
            sonificationEnabled = false

        case .motionSensitive:
            audioDescriptionEnabled = true
            preferredColorScheme = .standard
            hapticFeedbackEnabled = true
            sonificationEnabled = true

        case .cognitive:
            audioDescriptionEnabled = true
            preferredColorScheme = .standard
            hapticFeedbackEnabled = true
            sonificationEnabled = true

        case .screenReader:
            audioDescriptionEnabled = true
            preferredColorScheme = .highContrast
            hapticFeedbackEnabled = true
            sonificationEnabled = true

        case .fullAccessibility:
            audioDescriptionEnabled = true
            preferredColorScheme = .highContrast
            hapticFeedbackEnabled = true
            sonificationEnabled = true
        }
    }

    // MARK: - Color Adaptation

    public func adaptColor(_ color: SIMD3<Float>) -> SIMD3<Float> {
        switch preferredColorScheme {
        case .standard:
            return color

        case .deuteranopia:
            // Shift green to blue/yellow
            return SIMD3<Float>(
                color.x,
                color.y * 0.5,
                color.z + color.y * 0.5
            )

        case .protanopia:
            // Shift red to blue/green
            return SIMD3<Float>(
                color.x * 0.5,
                color.y + color.x * 0.3,
                color.z + color.x * 0.2
            )

        case .tritanopia:
            // Shift blue to red/green
            return SIMD3<Float>(
                color.x + color.z * 0.3,
                color.y + color.z * 0.3,
                color.z * 0.5
            )

        case .highContrast:
            // Increase saturation and contrast
            let luminance = color.x * 0.299 + color.y * 0.587 + color.z * 0.114
            if luminance > 0.5 {
                return SIMD3<Float>(1, 1, 1)
            } else {
                return SIMD3<Float>(0, 0, 0)
            }

        case .monochrome:
            let gray = color.x * 0.299 + color.y * 0.587 + color.z * 0.114
            return SIMD3<Float>(gray, gray, gray)
        }
    }

    // MARK: - Motion Adaptation

    public func adaptedAnimationDuration(_ duration: Double) -> Double {
        if isReducedMotionEnabled {
            return 0 // Instant transitions
        }
        return duration
    }

    public func shouldShowAnimation() -> Bool {
        !isReducedMotionEnabled
    }

    // MARK: - Audio Descriptions

    public func describeQuantumState(_ state: QuantumAudioState) -> String {
        let coherencePercent = Int(state.coherence * 100)
        let stateCount = state.amplitudes.count
        let maxProbIndex = state.probabilities.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0

        var description = "Quantum state with \(stateCount) superposed components. "
        description += "Coherence level: \(coherencePercent) percent. "
        description += "Most probable outcome: state \(maxProbIndex + 1). "

        if state.entanglementFactor > 0.5 {
            description += "Strongly entangled with other systems. "
        }

        return description
    }

    public func describeLightField(_ field: LightField) -> String {
        let photonCount = field.photons.count
        let geometry = field.geometry.rawValue
        let coherencePercent = Int(field.coherenceLevel * 100)

        var description = "\(geometry) light field with \(photonCount) photons. "
        description += "Field coherence: \(coherencePercent) percent. "

        // Describe dominant colors
        let avgWavelength = field.photons.map(\.wavelength).reduce(0, +) / Float(max(1, photonCount))
        let colorName = wavelengthToColorName(avgWavelength)
        description += "Dominant color: \(colorName). "

        return description
    }

    public func describeVisualization(_ type: PhotonicsVisualizationEngine.VisualizationType) -> String {
        switch type {
        case .interferencePattern:
            return "Interference pattern showing wave interactions. Bright areas indicate constructive interference, dark areas show destructive interference."

        case .waveFunction:
            return "Quantum wave function visualization. Brightness indicates probability amplitude of finding a particle at each location."

        case .coherenceField:
            return "Coherence field display. Organized patterns indicate high quantum coherence, random patterns show decoherence."

        case .photonFlow:
            return "Flowing photon particles. Each dot represents a light particle moving through space."

        case .sacredGeometry:
            return "Sacred geometry patterns including the Flower of Life. Interlocking circles representing universal harmony."

        case .quantumTunnel:
            return "Quantum tunnel visualization. A spiraling vortex representing particle tunneling through energy barriers."

        case .biophotonAura:
            return "Coherence aura visualization. Colored layers represent bio-reactive visual feedback based on HRV coherence levels. HINWEIS: Rein kreative Visualisierung, keine wissenschaftlichen Energiefelder."

        case .lightMandala:
            return "Rotating light mandala. Symmetrical patterns with multiple layers spinning in harmony."

        case .holographicDisplay:
            return "Holographic interference display. Shimmering patterns created by light wave interactions."

        case .cosmicWeb:
            return "Cosmic web visualization. Interconnected nodes representing the large-scale structure of the universe."
        }
    }

    private func wavelengthToColorName(_ wavelength: Float) -> String {
        if wavelength < 450 { return "violet" }
        if wavelength < 490 { return "blue" }
        if wavelength < 520 { return "cyan" }
        if wavelength < 565 { return "green" }
        if wavelength < 590 { return "yellow" }
        if wavelength < 625 { return "orange" }
        return "red"
    }

    // MARK: - Haptic Feedback

    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    public func provideHapticFeedback(for event: QuantumHapticEvent) {
        guard hapticFeedbackEnabled else { return }

        switch event {
        case .stateCollapse:
            impactGenerator.impactOccurred(intensity: 1.0)

        case .coherenceHigh:
            notificationGenerator.notificationOccurred(.success)

        case .coherenceLow:
            notificationGenerator.notificationOccurred(.warning)

        case .entanglementFormed:
            impactGenerator.impactOccurred(intensity: 0.7)

        case .photonBurst:
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                    self?.impactGenerator.impactOccurred(intensity: CGFloat(1.0 - Float(i) * 0.3))
                }
            }

        case .modeChange:
            impactGenerator.impactOccurred(intensity: 0.5)
        }
    }
    #else
    public func provideHapticFeedback(for event: QuantumHapticEvent) {
        // Haptics not available on this platform
    }
    #endif

    public enum QuantumHapticEvent {
        case stateCollapse
        case coherenceHigh
        case coherenceLow
        case entanglementFormed
        case photonBurst
        case modeChange
    }

    // MARK: - Sonification

    public func sonifyCoherence(_ coherence: Float) -> SonificationParameters {
        // Convert coherence to audio parameters
        let frequency = 220 + coherence * 660 // 220Hz (low) to 880Hz (high)
        let volume = 0.3 + coherence * 0.4 // Louder when more coherent
        let harmonics = Int(coherence * 4) + 1 // More harmonics when coherent

        return SonificationParameters(
            baseFrequency: frequency,
            volume: volume,
            harmonicCount: harmonics,
            waveform: coherence > 0.5 ? .sine : .triangle
        )
    }

    public struct SonificationParameters {
        public let baseFrequency: Float
        public let volume: Float
        public let harmonicCount: Int
        public let waveform: Waveform

        public enum Waveform {
            case sine, triangle, square, sawtooth
        }
    }
}

// MARK: - Accessible Quantum View Modifier

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct AccessibleQuantumModifier: ViewModifier {
    @ObservedObject private var accessibility = QuantumAccessibilityManager.shared
    let emulator: QuantumLightEmulator

    public func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(generateAccessibilityLabel())
            .accessibilityValue(generateAccessibilityValue())
            .accessibilityHint("Double tap to interact with quantum state")
            .accessibilityAction(.default) {
                // Trigger state collapse
                let options = ["harmonize", "expand", "contract"]
                _ = emulator.collapseToDecision(options: options)
            }
            .accessibilityAction(named: "Change Mode") {
                // Cycle through modes
                let modes = QuantumLightEmulator.EmulationMode.allCases
                if let currentIndex = modes.firstIndex(of: emulator.emulationMode) {
                    let nextIndex = (currentIndex + 1) % modes.count
                    emulator.setMode(modes[nextIndex])
                }
            }
            .accessibilityAction(named: "Describe Visualization") {
                // Speak description
                if let state = emulator.currentQuantumState {
                    let description = accessibility.describeQuantumState(state)
                    #if canImport(UIKit) && !os(watchOS)
                    UIAccessibility.post(notification: .announcement, argument: description)
                    #endif
                }
            }
    }

    private func generateAccessibilityLabel() -> String {
        "Quantum Light Emulator, \(emulator.emulationMode.rawValue) mode"
    }

    private func generateAccessibilityValue() -> String {
        let coherence = Int(emulator.coherenceLevel * 100)
        let photons = emulator.currentEmulatorLightField?.photons.count ?? 0
        return "Coherence \(coherence) percent, \(photons) photons active"
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func accessibleQuantum(_ emulator: QuantumLightEmulator) -> some View {
        modifier(AccessibleQuantumModifier(emulator: emulator))
    }
}

// MARK: - Accessible Color Extensions

public extension Color {
    @MainActor static func accessibleQuantumColor(
        hue: Double,
        saturation: Double = 0.8,
        brightness: Double = 0.8
    ) -> Color {
        let manager = QuantumAccessibilityManager.shared
        let originalColor = SIMD3<Float>(
            Float(hue),
            Float(saturation),
            Float(brightness)
        )

        let adapted = manager.adaptColor(originalColor)

        return Color(
            hue: Double(adapted.x),
            saturation: Double(adapted.y),
            brightness: Double(adapted.z)
        )
    }
}

// MARK: - VoiceOver Announcements

public class QuantumVoiceOverAnnouncer {

    public static func announceCoherenceChange(from oldValue: Float, to newValue: Float) {
        #if canImport(UIKit) && !os(watchOS)
        guard UIAccessibility.isVoiceOverRunning else { return }

        let change = newValue - oldValue
        let announcement: String

        if abs(change) < 0.05 {
            return // Ignore small changes
        } else if change > 0.2 {
            announcement = "Coherence significantly increased to \(Int(newValue * 100)) percent"
        } else if change > 0 {
            announcement = "Coherence increased to \(Int(newValue * 100)) percent"
        } else if change < -0.2 {
            announcement = "Coherence significantly decreased to \(Int(newValue * 100)) percent"
        } else {
            announcement = "Coherence decreased to \(Int(newValue * 100)) percent"
        }

        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }

    public static func announceModeChange(_ mode: QuantumLightEmulator.EmulationMode) {
        #if canImport(UIKit) && !os(watchOS)
        guard UIAccessibility.isVoiceOverRunning else { return }

        let announcement = "Quantum mode changed to \(mode.rawValue)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }

    public static func announceEntanglement(deviceId: String, strength: Float) {
        #if canImport(UIKit) && !os(watchOS)
        guard UIAccessibility.isVoiceOverRunning else { return }

        let announcement = "Quantum entanglement formed with \(deviceId) at \(Int(strength * 100)) percent strength"
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }
}
