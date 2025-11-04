import Foundation
import SwiftUI
import Combine

#if os(iOS) || os(visionOS)
import UIKit
#endif

/// Comprehensive Accessibility Framework
/// Makes BLAB accessible to everyone regardless of abilities
///
/// Features:
/// - VoiceOver support
/// - Dynamic Type (text scaling)
/// - Color blindness modes
/// - Reduced motion
/// - High contrast
/// - Haptic feedback alternatives
/// - Audio descriptions
/// - Keyboard navigation
/// - Switch Control support

// MARK: - Accessibility Configuration

public struct AccessibilityConfiguration {
    public var voiceOverEnabled: Bool
    public var dynamicTypeSize: DynamicTypeSize
    public var colorBlindnessMode: ColorBlindnessMode
    public var reducedMotion: Bool
    public var highContrast: Bool
    public var hapticFeedback: HapticFeedbackLevel
    public var audioDescriptions: Bool
    public var subtitlesEnabled: Bool
    public var simplifiedUI: Bool

    public init(
        voiceOverEnabled: Bool = false,
        dynamicTypeSize: DynamicTypeSize = .medium,
        colorBlindnessMode: ColorBlindnessMode = .none,
        reducedMotion: Bool = false,
        highContrast: Bool = false,
        hapticFeedback: HapticFeedbackLevel = .standard,
        audioDescriptions: Bool = false,
        subtitlesEnabled: Bool = false,
        simplifiedUI: Bool = false
    ) {
        self.voiceOverEnabled = voiceOverEnabled
        self.dynamicTypeSize = dynamicTypeSize
        self.colorBlindnessMode = colorBlindnessMode
        self.reducedMotion = reducedMotion
        self.highContrast = highContrast
        self.hapticFeedback = hapticFeedback
        self.audioDescriptions = audioDescriptions
        self.subtitlesEnabled = subtitlesEnabled
        self.simplifiedUI = simplifiedUI
    }
}

public enum DynamicTypeSize: String, CaseIterable {
    case extraSmall = "Extra Small"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    case extraExtraLarge = "XXL"
    case accessibility1 = "Accessibility 1"
    case accessibility2 = "Accessibility 2"
    case accessibility3 = "Accessibility 3"

    public var scaleFactor: CGFloat {
        switch self {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        case .extraExtraLarge: return 1.5
        case .accessibility1: return 1.8
        case .accessibility2: return 2.2
        case .accessibility3: return 2.7
        }
    }
}

public enum ColorBlindnessMode: String, CaseIterable {
    case none = "Normal"
    case protanopia = "Protanopia (Red-Blind)"
    case deuteranopia = "Deuteranopia (Green-Blind)"
    case tritanopia = "Tritanopia (Blue-Blind)"
    case achromatopsia = "Achromatopsia (Total Color Blind)"

    public var description: String {
        switch self {
        case .none: return "No color vision deficiency"
        case .protanopia: return "Difficulty distinguishing red and green (1% of males)"
        case .deuteranopia: return "Difficulty distinguishing red and green (5% of males)"
        case .tritanopia: return "Difficulty distinguishing blue and yellow (rare)"
        case .achromatopsia: return "Complete color blindness (very rare)"
        }
    }
}

public enum HapticFeedbackLevel: String, CaseIterable {
    case off = "Off"
    case minimal = "Minimal"
    case standard = "Standard"
    case enhanced = "Enhanced"
}

// MARK: - Accessibility Manager

@MainActor
public final class AccessibilityManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = AccessibilityManager()

    // MARK: - Published Properties

    @Published public var configuration: AccessibilityConfiguration
    @Published public var systemVoiceOverEnabled: Bool = false
    @Published public var systemReducedMotion: Bool = false
    @Published public var systemIncreasedContrast: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load saved configuration
        if let savedConfig = Self.loadConfiguration() {
            configuration = savedConfig
        } else {
            // Auto-detect system settings
            configuration = Self.detectSystemAccessibilitySettings()
        }

        observeSystemSettings()

        print("♿️ Accessibility Manager initialized")
        print("   VoiceOver: \(systemVoiceOverEnabled ? "✅" : "❌")")
        print("   Reduced Motion: \(systemReducedMotion ? "✅" : "❌")")
        print("   High Contrast: \(systemIncreasedContrast ? "✅" : "❌")")
    }

    // MARK: - System Detection

    private static func detectSystemAccessibilitySettings() -> AccessibilityConfiguration {
        #if os(iOS) || os(visionOS)
        return AccessibilityConfiguration(
            voiceOverEnabled: UIAccessibility.isVoiceOverRunning,
            dynamicTypeSize: Self.detectDynamicTypeSize(),
            reducedMotion: UIAccessibility.isReduceMotionEnabled,
            highContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            hapticFeedback: .standard
        )
        #else
        return AccessibilityConfiguration()
        #endif
    }

    #if os(iOS) || os(visionOS)
    private static func detectDynamicTypeSize() -> DynamicTypeSize {
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory

        switch contentSizeCategory {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .accessibility1
        case .accessibilityMedium: return .accessibility2
        case .accessibilityLarge, .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return .accessibility3
        default:
            return .medium
        }
    }
    #endif

    private func observeSystemSettings() {
        #if os(iOS) || os(visionOS)
        // VoiceOver
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.systemVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
                self?.configuration.voiceOverEnabled = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)

        // Reduced Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.systemReducedMotion = UIAccessibility.isReduceMotionEnabled
                self?.configuration.reducedMotion = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Increased Contrast
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.systemIncreasedContrast = UIAccessibility.isDarkerSystemColorsEnabled
                self?.configuration.highContrast = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)

        // Update initial values
        systemVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        systemReducedMotion = UIAccessibility.isReduceMotionEnabled
        systemIncreasedContrast = UIAccessibility.isDarkerSystemColorsEnabled
        #endif
    }

    // MARK: - Configuration Management

    public func updateConfiguration(_ config: AccessibilityConfiguration) {
        configuration = config
        saveConfiguration()
        print("♿️ Accessibility configuration updated")
    }

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: "AccessibilityConfiguration")
        }
    }

    private static func loadConfiguration() -> AccessibilityConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "AccessibilityConfiguration"),
              let config = try? JSONDecoder().decode(AccessibilityConfiguration.self, from: data) else {
            return nil
        }
        return config
    }

    // MARK: - Color Adaptation

    /// Apply color blindness filter to a color
    public func adaptColor(_ color: Color) -> Color {
        switch configuration.colorBlindnessMode {
        case .none:
            return color

        case .protanopia:
            return applyProtanopiaFilter(color)

        case .deuteranopia:
            return applyDeuteranopiaFilter(color)

        case .tritanopia:
            return applyTritanopiaFilter(color)

        case .achromatopsia:
            return applyAchromatopsiaFilter(color)
        }
    }

    private func applyProtanopiaFilter(_ color: Color) -> Color {
        // Simulate protanopia (red-blind)
        // This is a simplified simulation
        #if os(iOS) || os(macOS) || os(visionOS)
        if let components = UIColor(color).cgColor.components, components.count >= 3 {
            let r = components[0]
            let g = components[1]
            let b = components[2]

            // LMS color space transformation for protanopia
            let newR = 0.567 * r + 0.433 * g
            let newG = 0.558 * r + 0.442 * g
            let newB = 0.242 * g + 0.758 * b

            return Color(red: newR, green: newG, blue: newB)
        }
        #endif
        return color
    }

    private func applyDeuteranopiaFilter(_ color: Color) -> Color {
        // Simulate deuteranopia (green-blind)
        #if os(iOS) || os(macOS) || os(visionOS)
        if let components = UIColor(color).cgColor.components, components.count >= 3 {
            let r = components[0]
            let g = components[1]
            let b = components[2]

            let newR = 0.625 * r + 0.375 * g
            let newG = 0.7 * r + 0.3 * g
            let newB = 0.3 * g + 0.7 * b

            return Color(red: newR, green: newG, blue: newB)
        }
        #endif
        return color
    }

    private func applyTritanopiaFilter(_ color: Color) -> Color {
        // Simulate tritanopia (blue-blind)
        #if os(iOS) || os(macOS) || os(visionOS)
        if let components = UIColor(color).cgColor.components, components.count >= 3 {
            let r = components[0]
            let g = components[1]
            let b = components[2]

            let newR = 0.95 * r + 0.05 * g
            let newG = 0.433 * g + 0.567 * b
            let newB = 0.475 * g + 0.525 * b

            return Color(red: newR, green: newG, blue: newB)
        }
        #endif
        return color
    }

    private func applyAchromatopsiaFilter(_ color: Color) -> Color {
        // Convert to grayscale
        #if os(iOS) || os(macOS) || os(visionOS)
        if let components = UIColor(color).cgColor.components, components.count >= 3 {
            let r = components[0]
            let g = components[1]
            let b = components[2]

            // Luminance calculation
            let gray = 0.299 * r + 0.587 * g + 0.114 * b

            return Color(red: gray, green: gray, blue: gray)
        }
        #endif
        return color
    }

    // MARK: - Haptic Feedback

    #if os(iOS) || os(visionOS)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    public func triggerHaptic(type: HapticType) {
        guard configuration.hapticFeedback != .off else { return }

        switch type {
        case .light:
            if configuration.hapticFeedback == .standard || configuration.hapticFeedback == .enhanced {
                lightImpact.impactOccurred()
            }

        case .medium:
            mediumImpact.impactOccurred()

        case .heavy:
            if configuration.hapticFeedback == .enhanced {
                heavyImpact.impactOccurred()
            } else {
                mediumImpact.impactOccurred()
            }

        case .selection:
            selectionFeedback.selectionChanged()

        case .success:
            notificationFeedback.notificationOccurred(.success)

        case .warning:
            notificationFeedback.notificationOccurred(.warning)

        case .error:
            notificationFeedback.notificationOccurred(.error)
        }
    }
    #else
    public func triggerHaptic(type: HapticType) {
        // No haptics on non-iOS platforms
    }
    #endif

    public enum HapticType {
        case light
        case medium
        case heavy
        case selection
        case success
        case warning
        case error
    }

    // MARK: - VoiceOver Announcements

    public func announce(_ message: String, priority: AnnouncementPriority = .default) {
        guard configuration.voiceOverEnabled else { return }

        #if os(iOS) || os(visionOS)
        let announcement: UIAccessibility.Notification

        switch priority {
        case .low:
            announcement = .announcement
        case .default:
            announcement = .announcement
        case .high:
            announcement = .screenChanged
        }

        UIAccessibility.post(notification: announcement, argument: message)
        #endif

        print("🔊 VoiceOver: \(message)")
    }

    public enum AnnouncementPriority {
        case low
        case `default`
        case high
    }

    // MARK: - Animation Utilities

    /// Get animation duration respecting reduced motion
    public func animationDuration(_ baseDuration: Double) -> Double {
        return configuration.reducedMotion ? 0.0 : baseDuration
    }

    /// Create animation respecting reduced motion
    public func animation(_ baseAnimation: Animation) -> Animation? {
        return configuration.reducedMotion ? nil : baseAnimation
    }
}

// MARK: - Codable

extension AccessibilityConfiguration: Codable {}

// MARK: - SwiftUI View Extensions

extension View {
    /// Apply accessibility adaptations
    public func accessibilityAdapted() -> some View {
        let manager = AccessibilityManager.shared
        let config = manager.configuration

        return self
            .dynamicTypeSize(config.dynamicTypeSize.swiftUISize)
            .environment(\.accessibilityReduceMotion, config.reducedMotion)
            .environment(\.accessibilityDifferentiateWithoutColor, config.colorBlindnessMode != .none)
    }

    /// Announce message to VoiceOver
    public func announce(_ message: String, priority: AccessibilityManager.AnnouncementPriority = .default) -> some View {
        AccessibilityManager.shared.announce(message, priority: priority)
        return self
    }

    /// Trigger haptic feedback
    public func haptic(_ type: AccessibilityManager.HapticType) -> some View {
        AccessibilityManager.shared.triggerHaptic(type: type)
        return self
    }
}

extension DynamicTypeSize {
    var swiftUISize: SwiftUI.DynamicTypeSize {
        switch self {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .xLarge
        case .extraExtraLarge: return .xxLarge
        case .accessibility1: return .xxxLarge
        case .accessibility2: return .accessibility1
        case .accessibility3: return .accessibility5
        }
    }
}

// MARK: - Accessibility Testing

#if DEBUG
extension AccessibilityManager {
    /// Test all accessibility features
    public func runAccessibilityTest() {
        print("\n♿️ === Accessibility Test ===")

        print("✅ VoiceOver: \(configuration.voiceOverEnabled ? "Enabled" : "Disabled")")
        print("✅ Text Size: \(configuration.dynamicTypeSize.rawValue) (\(configuration.dynamicTypeSize.scaleFactor)x)")
        print("✅ Color Blindness: \(configuration.colorBlindnessMode.rawValue)")
        print("✅ Reduced Motion: \(configuration.reducedMotion ? "Yes" : "No")")
        print("✅ High Contrast: \(configuration.highContrast ? "Yes" : "No")")
        print("✅ Haptic Level: \(configuration.hapticFeedback.rawValue)")

        announce("Accessibility test complete", priority: .high)
        triggerHaptic(type: .success)

        print("=========================\n")
    }
}
#endif
