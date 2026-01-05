import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Inclusive Mobility Manager

/// Comprehensive accessibility and inclusive mobility system
/// Ensures Echoelmusic is usable by everyone, regardless of ability
@MainActor
class InclusiveMobilityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = InclusiveMobilityManager()

    // MARK: - Published State

    @Published var activeProfile: AccessibilityProfile?
    @Published var enabledFeatures: Set<InclusiveFeature> = []
    @Published var voiceControlActive: Bool = false
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var reducedMotionEnabled: Bool = false
    @Published var highContrastEnabled: Bool = false

    // MARK: - Profiles

    @Published var savedProfiles: [AccessibilityProfile] = []

    // MARK: - Initialization

    private init() {
        loadSystemPreferences()
        setupDefaultProfiles()
        print("✅ InclusiveMobilityManager: Initialized")
    }

    // MARK: - System Integration

    private func loadSystemPreferences() {
        #if canImport(UIKit) && !os(watchOS)
        reducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        highContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled

        // Listen for system changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAccessibilityChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func systemAccessibilityChanged() {
        #if canImport(UIKit) && !os(watchOS)
        reducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        highContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        #endif
    }

    // MARK: - Profile Management

    private func setupDefaultProfiles() {
        savedProfiles = [
            AccessibilityProfile(
                name: "Vision Support",
                description: "Optimized for users with visual impairments",
                features: [.screenReaderOptimized, .highContrast, .largeText, .voiceOver],
                inputMethods: [.voice, .gesture],
                feedbackModes: [.haptic, .audio]
            ),
            AccessibilityProfile(
                name: "Hearing Support",
                description: "Optimized for users who are deaf or hard of hearing",
                features: [.visualBeatIndicators, .closedCaptions, .signLanguageAvatar, .bassEnhanced],
                inputMethods: [.touch, .gesture, .eyeTracking],
                feedbackModes: [.visual, .haptic]
            ),
            AccessibilityProfile(
                name: "Motor Support",
                description: "Optimized for users with motor impairments",
                features: [.voiceControl, .switchAccess, .dwellSelection, .largeTargets, .stickyKeys],
                inputMethods: [.voice, .switch, .eyeTracking],
                feedbackModes: [.visual, .audio]
            ),
            AccessibilityProfile(
                name: "Cognitive Support",
                description: "Optimized for users with cognitive differences",
                features: [.simplifiedUI, .focusMode, .readingGuide, .stepByStepInstructions, .memoryAids],
                inputMethods: [.touch, .voice],
                feedbackModes: [.visual, .audio, .haptic]
            ),
            AccessibilityProfile(
                name: "Sensory Sensitive",
                description: "Reduced sensory input for sensitive users",
                features: [.reducedMotion, .reducedBrightness, .quietMode, .calmColors],
                inputMethods: [.touch, .gesture],
                feedbackModes: [.haptic]
            )
        ]
    }

    func activateProfile(_ profile: AccessibilityProfile) {
        activeProfile = profile
        enabledFeatures = Set(profile.features)

        // Apply profile settings
        applyProfileSettings(profile)

        print("♿ InclusiveMobilityManager: Activated profile '\(profile.name)'")
    }

    func deactivateProfile() {
        activeProfile = nil
        enabledFeatures.removeAll()
        resetToDefaults()
    }

    private func applyProfileSettings(_ profile: AccessibilityProfile) {
        for feature in profile.features {
            enableFeature(feature)
        }
    }

    private func resetToDefaults() {
        voiceControlActive = false
        reducedMotionEnabled = false
        highContrastEnabled = false
    }

    // MARK: - Feature Management

    func enableFeature(_ feature: InclusiveFeature) {
        enabledFeatures.insert(feature)

        switch feature {
        case .voiceControl:
            voiceControlActive = true
        case .reducedMotion:
            reducedMotionEnabled = true
        case .highContrast:
            highContrastEnabled = true
        case .hapticFeedback:
            hapticFeedbackEnabled = true
        default:
            break
        }

        print("♿ Enabled: \(feature.rawValue)")
    }

    func disableFeature(_ feature: InclusiveFeature) {
        enabledFeatures.remove(feature)

        switch feature {
        case .voiceControl:
            voiceControlActive = false
        case .reducedMotion:
            reducedMotionEnabled = false
        case .highContrast:
            highContrastEnabled = false
        case .hapticFeedback:
            hapticFeedbackEnabled = false
        default:
            break
        }

        print("♿ Disabled: \(feature.rawValue)")
    }

    // MARK: - Voice Control

    func processVoiceCommand(_ command: String) -> VoiceCommandResult {
        let normalized = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse command
        if let action = parseVoiceCommand(normalized) {
            return VoiceCommandResult(
                success: true,
                action: action,
                feedback: "Executing: \(action.description)"
            )
        }

        return VoiceCommandResult(
            success: false,
            action: nil,
            feedback: "Command not recognized. Try 'help' for available commands."
        )
    }

    private func parseVoiceCommand(_ command: String) -> VoiceAction? {
        // Navigation
        if command.contains("go to") || command.contains("open") {
            if command.contains("home") { return .navigate(.home) }
            if command.contains("settings") { return .navigate(.settings) }
            if command.contains("project") { return .navigate(.projects) }
            if command.contains("record") { return .navigate(.recording) }
        }

        // Playback
        if command.contains("play") { return .playback(.play) }
        if command.contains("pause") || command.contains("stop") { return .playback(.pause) }
        if command.contains("skip") || command.contains("next") { return .playback(.next) }
        if command.contains("previous") || command.contains("back") { return .playback(.previous) }

        // Volume
        if command.contains("volume up") || command.contains("louder") { return .volume(.increase) }
        if command.contains("volume down") || command.contains("quieter") { return .volume(.decrease) }
        if command.contains("mute") { return .volume(.mute) }

        // Recording
        if command.contains("start recording") { return .recording(.start) }
        if command.contains("stop recording") { return .recording(.stop) }

        // Bio-feedback
        if command.contains("show coherence") { return .bioFeedback(.showCoherence) }
        if command.contains("start meditation") { return .bioFeedback(.startMeditation) }
        if command.contains("calibrate") { return .bioFeedback(.calibrate) }

        // Help
        if command.contains("help") { return .help }

        return nil
    }

    // MARK: - Haptic Feedback

    func provideHapticFeedback(_ type: HapticFeedbackType) {
        guard hapticFeedbackEnabled else { return }

        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        let generator: UIFeedbackGenerator

        switch type {
        case .light:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            return
        case .medium:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            return
        case .heavy:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            return
        case .success:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            return
        case .warning:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.warning)
            return
        case .error:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
            return
        case .selection:
            let selection = UISelectionFeedbackGenerator()
            selection.selectionChanged()
            return
        case .heartbeat:
            // Custom heartbeat pattern
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                impact.impactOccurred()
            }
            return
        case .breathIn, .breathOut:
            // Soft feedback for breathing exercises
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            return
        }
        #endif
    }

    // MARK: - Visual Indicators

    func getVisualBeatIndicator(bpm: Double, coherence: Double) -> VisualBeatIndicator {
        VisualBeatIndicator(
            bpm: bpm,
            pulseColor: coherenceColor(coherence),
            pulseSize: 1.0 + (coherence * 0.3),
            showWaveform: enabledFeatures.contains(.visualBeatIndicators)
        )
    }

    private func coherenceColor(_ coherence: Double) -> Color {
        switch coherence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }

    // MARK: - Adaptive UI

    func getAdaptiveUISettings() -> AdaptiveUISettings {
        AdaptiveUISettings(
            textScale: enabledFeatures.contains(.largeText) ? 1.5 : 1.0,
            targetSize: enabledFeatures.contains(.largeTargets) ? 60 : 44,
            spacing: enabledFeatures.contains(.largeTargets) ? 16 : 8,
            useHighContrast: highContrastEnabled,
            reduceMotion: reducedMotionEnabled,
            simplifyUI: enabledFeatures.contains(.simplifiedUI),
            showLabels: enabledFeatures.contains(.screenReaderOptimized)
        )
    }

    // MARK: - Alternative Input

    func configureSwitchControl(switches: [SwitchConfiguration]) {
        // Configure external switches for users with motor impairments
        for switchConfig in switches {
            print("♿ Configured switch: \(switchConfig.name) → \(switchConfig.action)")
        }
    }

    func configureEyeTracking(sensitivity: Double, dwellTime: TimeInterval) {
        // Configure eye tracking settings
        print("♿ Eye tracking: Sensitivity \(sensitivity), Dwell \(dwellTime)s")
    }

    // MARK: - Audio Description

    func generateAudioDescription(for content: ContentDescription) -> String {
        var description = content.title

        if let mood = content.mood {
            description += ". The mood is \(mood)."
        }

        if let coherence = content.bioMetrics?.coherence {
            let coherenceLevel = coherence > 0.7 ? "high" : coherence > 0.4 ? "moderate" : "building"
            description += " Your coherence level is \(coherenceLevel)."
        }

        if let visualElements = content.visualElements {
            description += " Visual elements include: \(visualElements.joined(separator: ", "))."
        }

        return description
    }

    // MARK: - Closed Captions

    func generateClosedCaptions(for session: AudioSession) -> [ClosedCaption] {
        var captions: [ClosedCaption] = []

        // Add session start
        captions.append(ClosedCaption(
            timestamp: 0,
            text: "♫ \(session.name) begins",
            type: .musicDescription
        ))

        // Add bio-reactive descriptions
        for event in session.bioEvents {
            captions.append(ClosedCaption(
                timestamp: event.timestamp,
                text: describeBioEvent(event),
                type: .bioDescription
            ))
        }

        // Add instrument cues
        for cue in session.instrumentCues {
            captions.append(ClosedCaption(
                timestamp: cue.timestamp,
                text: "♫ \(cue.instrument): \(cue.description)",
                type: .instrumentCue
            ))
        }

        return captions.sorted { $0.timestamp < $1.timestamp }
    }

    private func describeBioEvent(_ event: BioEvent) -> String {
        switch event.type {
        case .coherenceChange:
            return "💚 Coherence \(event.direction == .up ? "rising" : "falling")"
        case .heartRateChange:
            return "❤️ Heart rate \(event.direction == .up ? "increasing" : "decreasing")"
        case .breathingCue:
            return "🌬️ \(event.direction == .up ? "Breathe in" : "Breathe out")"
        case .meditationPhase:
            return "🧘 \(event.description ?? "Phase change")"
        }
    }
}

// MARK: - Types

struct AccessibilityProfile: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var features: [InclusiveFeature]
    var inputMethods: [InputMethod]
    var feedbackModes: [FeedbackMode]
    var customSettings: [String: Any] = [:]
}

enum InclusiveFeature: String, CaseIterable {
    // Vision
    case screenReaderOptimized = "Screen Reader Optimized"
    case voiceOver = "VoiceOver Support"
    case highContrast = "High Contrast"
    case largeText = "Large Text"
    case colorBlindSupport = "Color Blind Support"
    case reducedBrightness = "Reduced Brightness"

    // Hearing
    case visualBeatIndicators = "Visual Beat Indicators"
    case closedCaptions = "Closed Captions"
    case signLanguageAvatar = "Sign Language Avatar"
    case bassEnhanced = "Bass Enhanced (Tactile)"
    case visualAlerts = "Visual Alerts"

    // Motor
    case voiceControl = "Voice Control"
    case switchAccess = "Switch Access"
    case dwellSelection = "Dwell Selection"
    case largeTargets = "Large Touch Targets"
    case stickyKeys = "Sticky Keys"
    case headTracking = "Head Tracking Control"

    // Cognitive
    case simplifiedUI = "Simplified UI"
    case focusMode = "Focus Mode"
    case readingGuide = "Reading Guide"
    case stepByStepInstructions = "Step-by-Step Instructions"
    case memoryAids = "Memory Aids"
    case timeExtensions = "Time Extensions"

    // Sensory
    case reducedMotion = "Reduced Motion"
    case quietMode = "Quiet Mode"
    case calmColors = "Calm Color Palette"
    case hapticFeedback = "Haptic Feedback"

    var category: AccessibilityCategory {
        switch self {
        case .screenReaderOptimized, .voiceOver, .highContrast, .largeText, .colorBlindSupport, .reducedBrightness:
            return .vision
        case .visualBeatIndicators, .closedCaptions, .signLanguageAvatar, .bassEnhanced, .visualAlerts:
            return .hearing
        case .voiceControl, .switchAccess, .dwellSelection, .largeTargets, .stickyKeys, .headTracking:
            return .motor
        case .simplifiedUI, .focusMode, .readingGuide, .stepByStepInstructions, .memoryAids, .timeExtensions:
            return .cognitive
        case .reducedMotion, .quietMode, .calmColors, .hapticFeedback:
            return .sensory
        }
    }

    enum AccessibilityCategory: String {
        case vision, hearing, motor, cognitive, sensory
    }
}

enum InputMethod: String {
    case touch = "Touch"
    case voice = "Voice"
    case gesture = "Gesture"
    case `switch` = "Switch"
    case eyeTracking = "Eye Tracking"
    case headTracking = "Head Tracking"
    case brainInterface = "Brain-Computer Interface"
}

enum FeedbackMode: String {
    case visual = "Visual"
    case audio = "Audio"
    case haptic = "Haptic"
}

// MARK: - Voice Control

struct VoiceCommandResult {
    var success: Bool
    var action: VoiceAction?
    var feedback: String
}

enum VoiceAction {
    case navigate(NavigationDestination)
    case playback(PlaybackAction)
    case volume(VolumeAction)
    case recording(RecordingAction)
    case bioFeedback(BioFeedbackAction)
    case help

    var description: String {
        switch self {
        case .navigate(let dest): return "Navigate to \(dest.rawValue)"
        case .playback(let action): return "Playback: \(action.rawValue)"
        case .volume(let action): return "Volume: \(action.rawValue)"
        case .recording(let action): return "Recording: \(action.rawValue)"
        case .bioFeedback(let action): return "Bio-feedback: \(action.rawValue)"
        case .help: return "Show help"
        }
    }

    enum NavigationDestination: String {
        case home, settings, projects, recording, library, profile
    }

    enum PlaybackAction: String {
        case play, pause, stop, next, previous, seekForward, seekBackward
    }

    enum VolumeAction: String {
        case increase, decrease, mute, unmute, setLevel
    }

    enum RecordingAction: String {
        case start, stop, pause, resume, discard
    }

    enum BioFeedbackAction: String {
        case showCoherence, startMeditation, calibrate, showHistory
    }
}

// MARK: - Haptic Feedback

enum HapticFeedbackType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    case heartbeat
    case breathIn
    case breathOut
}

// MARK: - Visual Indicators

struct VisualBeatIndicator {
    var bpm: Double
    var pulseColor: Color
    var pulseSize: Double
    var showWaveform: Bool
}

// MARK: - Adaptive UI

struct AdaptiveUISettings {
    var textScale: Double
    var targetSize: CGFloat
    var spacing: CGFloat
    var useHighContrast: Bool
    var reduceMotion: Bool
    var simplifyUI: Bool
    var showLabels: Bool

    var animationDuration: Double {
        reduceMotion ? 0 : 0.3
    }
}

// MARK: - Switch Control

struct SwitchConfiguration: Identifiable {
    let id = UUID()
    var name: String
    var action: SwitchAction
    var holdDuration: TimeInterval?
    var repeatRate: TimeInterval?

    enum SwitchAction: String {
        case select, next, previous, back, menu, custom
    }
}

// MARK: - Audio Description

struct ContentDescription {
    var title: String
    var mood: String?
    var bioMetrics: BioMetricsDescription?
    var visualElements: [String]?
}

struct BioMetricsDescription {
    var coherence: Double
    var heartRate: Double
    var breathingRate: Double
}

// MARK: - Closed Captions

struct ClosedCaption: Identifiable {
    let id = UUID()
    var timestamp: TimeInterval
    var text: String
    var type: CaptionType
    var speaker: String?

    enum CaptionType {
        case speech
        case musicDescription
        case soundEffect
        case bioDescription
        case instrumentCue
    }
}

struct AudioSession {
    var name: String
    var bioEvents: [BioEvent]
    var instrumentCues: [InstrumentCue]
}

struct BioEvent {
    var timestamp: TimeInterval
    var type: BioEventType
    var direction: Direction
    var description: String?

    enum BioEventType {
        case coherenceChange
        case heartRateChange
        case breathingCue
        case meditationPhase
    }

    enum Direction {
        case up, down, stable
    }
}

struct InstrumentCue {
    var timestamp: TimeInterval
    var instrument: String
    var description: String
}

// MARK: - SwiftUI View Modifiers

struct AccessibleModifier: ViewModifier {
    @ObservedObject var manager = InclusiveMobilityManager.shared

    func body(content: Content) -> some View {
        let settings = manager.getAdaptiveUISettings()

        content
            .scaleEffect(settings.textScale)
            .animation(settings.reduceMotion ? nil : .easeInOut(duration: settings.animationDuration), value: settings.textScale)
    }
}

extension View {
    func accessibilityOptimized() -> some View {
        modifier(AccessibleModifier())
    }
}

// MARK: - Accessibility-First Button

struct AccessibleButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    @ObservedObject private var accessibility = InclusiveMobilityManager.shared

    var body: some View {
        let settings = accessibility.getAdaptiveUISettings()

        Button(action: {
            accessibility.provideHapticFeedback(.selection)
            action()
        }) {
            label()
                .frame(minWidth: settings.targetSize, minHeight: settings.targetSize)
                .padding(settings.spacing)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Beat View

struct VisualBeatView: View {
    let indicator: VisualBeatIndicator
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(indicator.pulseColor)
            .frame(width: 60 * indicator.pulseSize, height: 60 * indicator.pulseSize)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(
                .easeInOut(duration: 60.0 / indicator.bpm)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
            .accessibilityLabel("Heart beat at \(Int(indicator.bpm)) beats per minute")
    }
}
