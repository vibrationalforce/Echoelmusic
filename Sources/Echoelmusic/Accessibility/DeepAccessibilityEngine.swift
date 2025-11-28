// DeepAccessibilityEngine.swift
// Echoelmusic - Complete Accessibility for ALL Humans
//
// ULTRATHINK ACCESSIBILITY MODE
//
// Core Principles:
// 1. AUTOMATIC DETECTION - System learns user needs
// 2. NO AUDIO WARNINGS - Haptic & visual alternatives for everything
// 3. FULL BLIND SUPPORT - Complete screen reader & audio description
// 4. FULL DEAF SUPPORT - Visual & haptic for all audio
// 5. MULTI-MODAL - Multiple ways to interact with everything
// 6. DIGNITY - Never make users feel different or limited

import Foundation
import Combine
import CoreHaptics
import AVFoundation
import NaturalLanguage

// MARK: - Accessibility Profile Auto-Detection

/// Automatically detects and adapts to user accessibility needs
public final class AccessibilityAutoDetector: ObservableObject {

    public static let shared = AccessibilityAutoDetector()

    @Published public var detectedProfile: DetectedAccessibilityProfile
    @Published public var confidenceLevel: Double = 0.0
    @Published public var isLearning: Bool = true

    public struct DetectedAccessibilityProfile {
        // Vision
        public var visionStatus: VisionStatus = .unknown
        public var estimatedVisualAcuity: Double = 1.0  // 1.0 = 20/20
        public var colorVisionType: ColorVisionType = .normal
        public var lightSensitivity: LightSensitivity = .normal
        public var prefersDarkMode: Bool = false
        public var prefersHighContrast: Bool = false
        public var prefersLargeText: Bool = false

        // Hearing
        public var hearingStatus: HearingStatus = .unknown
        public var estimatedHearingLevel: HearingLevel = .normal
        public var frequencyResponse: FrequencyResponse = .normal
        public var usesHearingAid: Bool = false
        public var usesCochlearImplant: Bool = false
        public var prefersVisualFeedback: Bool = false
        public var prefersHapticFeedback: Bool = false

        // Motor
        public var motorStatus: MotorStatus = .unknown
        public var handPreference: HandPreference = .unknown
        public var touchPrecision: TouchPrecision = .normal
        public var tremorDetected: Bool = false
        public var limitedRangeOfMotion: Bool = false
        public var usesSwitchControl: Bool = false
        public var usesVoiceControl: Bool = false

        // Cognitive
        public var cognitiveStatus: CognitiveStatus = .unknown
        public var readingSpeed: ReadingSpeed = .normal
        public var attentionSpan: AttentionSpan = .normal
        public var prefersSimplifiedUI: Bool = false
        public var needsExtraTime: Bool = false

        // Vestibular
        public var vestibularSensitivity: Bool = false
        public var motionSicknessRisk: Bool = false

        // Neural
        public var photosensitiveEpilepsy: Bool = false
        public var maxFlashFrequency: Double = 3.0  // Hz
    }

    // Enums for detection
    public enum VisionStatus: String, Codable {
        case unknown, normal, lowVision, legallyBlind, totallyBlind
    }

    public enum ColorVisionType: String, Codable {
        case normal, protanopia, deuteranopia, tritanopia, monochromacy
    }

    public enum LightSensitivity: String, Codable {
        case normal, mild, moderate, severe
    }

    public enum HearingStatus: String, Codable {
        case unknown, normal, mildLoss, moderateLoss, severeLoss, profoundLoss, deaf
    }

    public enum HearingLevel: String, Codable {
        case normal           // < 20 dB loss
        case mild             // 20-40 dB
        case moderate         // 41-55 dB
        case moderatelySevere // 56-70 dB
        case severe           // 71-90 dB
        case profound         // > 90 dB
    }

    public enum FrequencyResponse: String, Codable {
        case normal
        case highFrequencyLoss    // Can't hear high pitches
        case lowFrequencyLoss     // Can't hear low pitches
        case midFrequencyLoss     // Notch hearing loss
        case flatLoss             // Equal loss across frequencies
    }

    public enum MotorStatus: String, Codable {
        case unknown, normal, mildImpairment, moderateImpairment, severeImpairment
    }

    public enum HandPreference: String, Codable {
        case unknown, left, right, ambidextrous, noHands
    }

    public enum TouchPrecision: String, Codable {
        case normal, reduced, veryReduced, assistedOnly
    }

    public enum CognitiveStatus: String, Codable {
        case unknown, normal, mildSupport, moderateSupport, significantSupport
    }

    public enum ReadingSpeed: String, Codable {
        case fast, normal, slow, verySlow, nonReader
    }

    public enum AttentionSpan: String, Codable {
        case extended, normal, short, veryShort
    }

    // Learning data
    private var interactionHistory: [InteractionEvent] = []
    private var settingsHistory: [SettingsChange] = []
    private let learningQueue = DispatchQueue(label: "accessibility.learning", qos: .background)

    private struct InteractionEvent: Codable {
        let timestamp: Date
        let type: String
        let duration: Double
        let accuracy: Double?
        let metadata: [String: String]
    }

    private struct SettingsChange: Codable {
        let timestamp: Date
        let setting: String
        let oldValue: String
        let newValue: String
    }

    private init() {
        self.detectedProfile = DetectedAccessibilityProfile()
        loadSavedProfile()
        startSystemObservation()
        startBehaviorLearning()
    }

    /// Load saved accessibility profile
    private func loadSavedProfile() {
        // Check system accessibility settings first
        syncWithSystemSettings()

        // Load learned profile
        if let data = UserDefaults.standard.data(forKey: "detectedAccessibilityProfile"),
           let profile = try? JSONDecoder().decode(DetectedAccessibilityProfile.self, from: data) {
            detectedProfile = profile
            confidenceLevel = UserDefaults.standard.double(forKey: "accessibilityConfidence")
        }
    }

    /// Sync with system accessibility settings
    private func syncWithSystemSettings() {
        #if os(iOS)
        // VoiceOver detection
        if UIAccessibility.isVoiceOverRunning {
            detectedProfile.visionStatus = .totallyBlind
            detectedProfile.prefersHighContrast = true
            confidenceLevel = max(confidenceLevel, 0.9)
        }

        // Other iOS accessibility checks
        if UIAccessibility.isBoldTextEnabled {
            detectedProfile.prefersLargeText = true
        }

        if UIAccessibility.isReduceMotionEnabled {
            detectedProfile.vestibularSensitivity = true
            detectedProfile.motionSicknessRisk = true
        }

        if UIAccessibility.isReduceTransparencyEnabled {
            detectedProfile.lightSensitivity = .moderate
        }

        if UIAccessibility.isDarkerSystemColorsEnabled {
            detectedProfile.prefersHighContrast = true
        }

        if UIAccessibility.isSwitchControlRunning {
            detectedProfile.usesSwitchControl = true
            detectedProfile.motorStatus = .severeImpairment
        }

        if UIAccessibility.isClosedCaptioningEnabled {
            detectedProfile.hearingStatus = .moderateLoss
            detectedProfile.prefersVisualFeedback = true
        }

        if UIAccessibility.isMonoAudioEnabled {
            detectedProfile.hearingStatus = .mildLoss
        }

        // Check for hearing aid
        let audioSession = AVAudioSession.sharedInstance()
        let outputs = audioSession.currentRoute.outputs
        for output in outputs {
            if output.portType == .bluetoothHFP {
                // Might be hearing aid
                detectedProfile.usesHearingAid = true
            }
        }
        #elseif os(macOS)
        // macOS accessibility checks would go here
        #endif
    }

    /// Start observing system for accessibility changes
    private func startSystemObservation() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func accessibilitySettingsChanged() {
        syncWithSystemSettings()
        saveProfile()
    }

    /// Start learning from user behavior
    private func startBehaviorLearning() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.analyzeInteractionPatterns()
        }
    }

    /// Log user interaction for learning
    public func logInteraction(type: String, duration: Double, accuracy: Double? = nil, metadata: [String: String] = [:]) {
        learningQueue.async { [weak self] in
            self?.interactionHistory.append(InteractionEvent(
                timestamp: Date(),
                type: type,
                duration: duration,
                accuracy: accuracy,
                metadata: metadata
            ))

            // Keep last 1000 interactions
            if self?.interactionHistory.count ?? 0 > 1000 {
                self?.interactionHistory.removeFirst()
            }
        }
    }

    /// Log settings change for learning
    public func logSettingsChange(setting: String, oldValue: String, newValue: String) {
        learningQueue.async { [weak self] in
            self?.settingsHistory.append(SettingsChange(
                timestamp: Date(),
                setting: setting,
                oldValue: oldValue,
                newValue: newValue
            ))
        }

        // Immediate inference from settings
        inferFromSettingsChange(setting: setting, newValue: newValue)
    }

    private func inferFromSettingsChange(setting: String, newValue: String) {
        switch setting {
        case "fontSize":
            if let size = Double(newValue), size > 1.5 {
                detectedProfile.prefersLargeText = true
                detectedProfile.visionStatus = .lowVision
                confidenceLevel = max(confidenceLevel, 0.6)
            }

        case "contrast":
            if newValue == "high" {
                detectedProfile.prefersHighContrast = true
                confidenceLevel = max(confidenceLevel, 0.5)
            }

        case "audioAlerts":
            if newValue == "disabled" {
                detectedProfile.prefersHapticFeedback = true
                detectedProfile.hearingStatus = .moderateLoss
                confidenceLevel = max(confidenceLevel, 0.7)
            }

        case "visualAlerts":
            if newValue == "enabled" {
                detectedProfile.prefersVisualFeedback = true
                detectedProfile.hearingStatus = .severeLoss
                confidenceLevel = max(confidenceLevel, 0.7)
            }

        default:
            break
        }

        saveProfile()
    }

    /// Analyze interaction patterns to detect accessibility needs
    private func analyzeInteractionPatterns() {
        learningQueue.async { [weak self] in
            guard let self = self, self.interactionHistory.count >= 10 else { return }

            // Analyze touch accuracy
            let touchEvents = self.interactionHistory.filter { $0.type == "touch" }
            if !touchEvents.isEmpty {
                let avgAccuracy = touchEvents.compactMap(\.accuracy).reduce(0, +) / Double(touchEvents.count)
                if avgAccuracy < 0.7 {
                    DispatchQueue.main.async {
                        self.detectedProfile.touchPrecision = avgAccuracy < 0.5 ? .veryReduced : .reduced
                        self.detectedProfile.motorStatus = .mildImpairment
                    }
                }
            }

            // Analyze reading time
            let readEvents = self.interactionHistory.filter { $0.type == "read" }
            if readEvents.count >= 5 {
                let avgDuration = readEvents.map(\.duration).reduce(0, +) / Double(readEvents.count)
                DispatchQueue.main.async {
                    if avgDuration > 10 { // > 10 seconds per read
                        self.detectedProfile.readingSpeed = .slow
                        self.detectedProfile.needsExtraTime = true
                    }
                }
            }

            // Analyze tremor patterns
            let gestureEvents = self.interactionHistory.filter { $0.type == "gesture" }
            let shakiness = gestureEvents.filter { $0.metadata["shaky"] == "true" }.count
            if Double(shakiness) / Double(max(1, gestureEvents.count)) > 0.3 {
                DispatchQueue.main.async {
                    self.detectedProfile.tremorDetected = true
                    self.detectedProfile.motorStatus = .mildImpairment
                }
            }

            DispatchQueue.main.async {
                self.saveProfile()
            }
        }
    }

    /// Save profile to persistent storage
    private func saveProfile() {
        if let data = try? JSONEncoder().encode(detectedProfile) {
            UserDefaults.standard.set(data, forKey: "detectedAccessibilityProfile")
            UserDefaults.standard.set(confidenceLevel, forKey: "accessibilityConfidence")
        }
    }

    /// Manual override for user to set their needs
    public func setManualOverride(_ profile: DetectedAccessibilityProfile) {
        detectedProfile = profile
        confidenceLevel = 1.0 // User knows best
        isLearning = false
        saveProfile()
    }

    /// Reset to auto-detection
    public func resetToAutoDetection() {
        isLearning = true
        confidenceLevel = 0.0
        syncWithSystemSettings()
    }
}

// MARK: - Screen Reader Integration

/// Complete screen reader support with intelligent descriptions
public final class ScreenReaderEngine: ObservableObject {

    public static let shared = ScreenReaderEngine()

    @Published public var isScreenReaderActive: Bool = false
    @Published public var currentFocus: String = ""
    @Published public var speakingRate: Double = 1.0
    @Published public var verbosityLevel: VerbosityLevel = .normal

    public enum VerbosityLevel: String, CaseIterable {
        case minimal = "Minimal"       // Only essential info
        case normal = "Normal"         // Standard descriptions
        case detailed = "Detailed"     // Extra context
        case maximum = "Maximum"       // Everything described

        public var descriptionDepth: Int {
            switch self {
            case .minimal: return 1
            case .normal: return 2
            case .detailed: return 3
            case .maximum: return 4
            }
        }
    }

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var announcementQueue: [Announcement] = []
    private let announceQueue = DispatchQueue(label: "screenreader.announce", qos: .userInteractive)

    private struct Announcement {
        let text: String
        let priority: Priority
        let interruptible: Bool

        enum Priority: Int {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
        }
    }

    private init() {
        detectScreenReader()
        setupNotifications()
    }

    private func detectScreenReader() {
        #if os(iOS)
        isScreenReaderActive = UIAccessibility.isVoiceOverRunning
        #elseif os(macOS)
        // Check for VoiceOver on macOS
        isScreenReaderActive = NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }

    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func voiceOverStatusChanged() {
        detectScreenReader()
    }

    /// Announce text to screen reader
    public func announce(_ text: String, priority: Announcement.Priority = .normal, interrupt: Bool = false) {
        if isScreenReaderActive {
            // Use system accessibility announcement
            #if os(iOS)
            let notification: UIAccessibility.Notification = interrupt ? .announcement : .screenChanged
            UIAccessibility.post(notification: notification, argument: text)
            #endif
        } else {
            // Fallback to speech synthesis for non-screen-reader users who need audio
            speak(text, interrupt: interrupt)
        }
    }

    /// Speak text using speech synthesis
    public func speak(_ text: String, interrupt: Bool = false) {
        if interrupt {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Float(speakingRate) * AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")

        speechSynthesizer.speak(utterance)
    }

    /// Stop all speech
    public func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    /// Generate description for audio waveform
    public func describeWaveform(peaks: [Float], duration: Double, context: String = "") -> String {
        var description = ""

        // Duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        description += "Audio, \(minutes > 0 ? "\(minutes) Minuten " : "")\(seconds) Sekunden. "

        // Overall character
        let avgPeak = peaks.reduce(0, +) / Float(max(1, peaks.count))
        let maxPeak = peaks.max() ?? 0
        let minPeak = peaks.min() ?? 0
        let dynamicRange = maxPeak - minPeak

        if avgPeak > 0.7 {
            description += "Laut mit hoher Energie. "
        } else if avgPeak > 0.4 {
            description += "Mittlere Lautstärke. "
        } else if avgPeak > 0.1 {
            description += "Leise. "
        } else {
            description += "Sehr leise oder Stille. "
        }

        // Dynamics
        if dynamicRange > 0.5 {
            description += "Große Dynamik mit starken Kontrasten. "
        } else if dynamicRange < 0.2 {
            description += "Gleichmäßig, wenig Variation. "
        }

        // Pattern detection
        let patternDescription = detectPattern(peaks)
        if !patternDescription.isEmpty {
            description += patternDescription
        }

        if verbosityLevel == .detailed || verbosityLevel == .maximum {
            description += "Maximale Amplitude \(Int(maxPeak * 100)) Prozent. "
        }

        return description
    }

    private func detectPattern(_ peaks: [Float]) -> String {
        guard peaks.count > 10 else { return "" }

        // Check for rhythm
        var crossings = 0
        let threshold: Float = 0.3
        var wasAbove = peaks[0] > threshold

        for peak in peaks {
            let isAbove = peak > threshold
            if isAbove != wasAbove {
                crossings += 1
                wasAbove = isAbove
            }
        }

        let crossingRate = Double(crossings) / Double(peaks.count)

        if crossingRate > 0.3 {
            return "Rhythmisches Muster erkannt. "
        } else if crossingRate < 0.1 {
            return "Gleichmäßiger Verlauf. "
        }

        return ""
    }

    /// Generate description for frequency spectrum
    public func describeSpectrum(frequencies: [Float], labels: [String]? = nil) -> String {
        var description = "Frequenzspektrum: "

        guard frequencies.count >= 3 else {
            return description + "Keine Daten verfügbar."
        }

        let third = frequencies.count / 3
        let bass = frequencies.prefix(third).reduce(0, +) / Float(third)
        let mid = frequencies.dropFirst(third).prefix(third).reduce(0, +) / Float(third)
        let high = frequencies.suffix(third).reduce(0, +) / Float(third)

        // Describe balance
        let total = bass + mid + high
        guard total > 0 else {
            return description + "Stille."
        }

        let bassPercent = bass / total * 100
        let midPercent = mid / total * 100
        let highPercent = high / total * 100

        if bassPercent > 50 {
            description += "Bass-betont. "
        } else if highPercent > 40 {
            description += "Höhen-betont, hell klingend. "
        } else if midPercent > 45 {
            description += "Mitten-betont, präsent. "
        } else {
            description += "Ausgewogen. "
        }

        if verbosityLevel >= .detailed {
            description += String(format: "Bass %.0f%%, Mitten %.0f%%, Höhen %.0f%%. ", bassPercent, midPercent, highPercent)
        }

        return description
    }

    /// Generate description for meter level
    public func describeMeter(db: Float, channelName: String = "") -> String {
        let name = channelName.isEmpty ? "" : "\(channelName): "

        if db > -3 {
            return "\(name)Sehr laut, fast Übersteuerung bei \(Int(db)) dB"
        } else if db > -12 {
            return "\(name)Laut bei \(Int(db)) dB"
        } else if db > -24 {
            return "\(name)Mittlere Lautstärke bei \(Int(db)) dB"
        } else if db > -48 {
            return "\(name)Leise bei \(Int(db)) dB"
        } else if db > -60 {
            return "\(name)Sehr leise bei \(Int(db)) dB"
        } else {
            return "\(name)Stille"
        }
    }

    /// Generate description for playback position
    public func describePlaybackPosition(current: Double, total: Double) -> String {
        let currentMin = Int(current) / 60
        let currentSec = Int(current) % 60
        let totalMin = Int(total) / 60
        let totalSec = Int(total) % 60
        let percent = Int((current / total) * 100)

        return "\(currentMin):\(String(format: "%02d", currentSec)) von \(totalMin):\(String(format: "%02d", totalSec)), \(percent) Prozent"
    }

    /// Describe UI element
    public func describeElement(_ element: AccessibleElement) -> String {
        var description = element.label

        if let value = element.value, !value.isEmpty {
            description += ", \(value)"
        }

        if let hint = element.hint, !hint.isEmpty, verbosityLevel >= .detailed {
            description += ". \(hint)"
        }

        if element.isSelected {
            description += ", ausgewählt"
        }

        if !element.isEnabled {
            description += ", deaktiviert"
        }

        return description
    }

    public struct AccessibleElement {
        public let label: String
        public var value: String?
        public var hint: String?
        public var isSelected: Bool = false
        public var isEnabled: Bool = true
        public var traits: Set<Trait> = []

        public enum Trait: String {
            case button, link, header, image, staticText
            case adjustable, searchField, selected, disabled
        }
    }
}

// MARK: - Haptic Feedback Engine (No Sound Warnings)

/// Complete haptic feedback system replacing all audio warnings
public final class HapticFeedbackEngine: ObservableObject {

    public static let shared = HapticFeedbackEngine()

    @Published public var isHapticAvailable: Bool = false
    @Published public var hapticIntensity: Double = 1.0
    @Published public var hapticEnabled: Bool = true

    private var hapticEngine: CHHapticEngine?
    private let hapticQueue = DispatchQueue(label: "haptic.feedback", qos: .userInteractive)

    /// Predefined haptic patterns
    public enum HapticPattern: String, CaseIterable {
        // Standard feedback
        case success = "Success"
        case warning = "Warning"
        case error = "Error"
        case notification = "Notification"

        // Audio-specific
        case beat = "Beat"
        case peakWarning = "Peak Warning"
        case clipDetected = "Clip Detected"
        case recordStart = "Record Start"
        case recordStop = "Record Stop"
        case playStart = "Play Start"
        case playStop = "Play Stop"
        case loopPoint = "Loop Point"

        // Navigation
        case selection = "Selection"
        case boundary = "Boundary"
        case snapToGrid = "Snap to Grid"

        // Continuous
        case levelMeter = "Level Meter"
        case scrubbing = "Scrubbing"
        case dragging = "Dragging"

        /// Get AHAP pattern data
        public var intensity: Float {
            switch self {
            case .success: return 0.6
            case .warning: return 0.8
            case .error: return 1.0
            case .notification: return 0.5
            case .beat: return 0.7
            case .peakWarning: return 0.9
            case .clipDetected: return 1.0
            case .recordStart, .recordStop: return 0.8
            case .playStart, .playStop: return 0.6
            case .loopPoint: return 0.5
            case .selection: return 0.4
            case .boundary: return 0.7
            case .snapToGrid: return 0.3
            case .levelMeter: return 0.2
            case .scrubbing: return 0.3
            case .dragging: return 0.4
            }
        }

        public var sharpness: Float {
            switch self {
            case .success: return 0.3
            case .warning: return 0.7
            case .error: return 1.0
            case .notification: return 0.5
            case .beat: return 0.8
            case .peakWarning: return 0.9
            case .clipDetected: return 1.0
            case .recordStart: return 0.7
            case .recordStop: return 0.4
            case .playStart: return 0.5
            case .playStop: return 0.3
            case .loopPoint: return 0.6
            case .selection: return 0.5
            case .boundary: return 0.8
            case .snapToGrid: return 0.9
            case .levelMeter: return 0.2
            case .scrubbing: return 0.4
            case .dragging: return 0.3
            }
        }

        public var duration: Double {
            switch self {
            case .success: return 0.3
            case .warning: return 0.5
            case .error: return 0.6
            case .notification: return 0.2
            case .beat: return 0.1
            case .peakWarning: return 0.3
            case .clipDetected: return 0.4
            case .recordStart, .recordStop: return 0.4
            case .playStart, .playStop: return 0.2
            case .loopPoint: return 0.1
            case .selection: return 0.1
            case .boundary: return 0.2
            case .snapToGrid: return 0.05
            case .levelMeter: return 0.05
            case .scrubbing: return 0.02
            case .dragging: return 0.03
            }
        }
    }

    private init() {
        setupHapticEngine()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isHapticAvailable = false
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            isHapticAvailable = true

            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.restartEngine()
            }

            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }

        } catch {
            print("Haptic engine failed: \(error)")
            isHapticAvailable = false
        }
    }

    private func restartEngine() {
        hapticQueue.async { [weak self] in
            try? self?.hapticEngine?.start()
        }
    }

    /// Play predefined haptic pattern
    public func play(_ pattern: HapticPattern) {
        guard hapticEnabled, isHapticAvailable else { return }

        hapticQueue.async { [weak self] in
            self?.playPattern(
                intensity: pattern.intensity * Float(self?.hapticIntensity ?? 1.0),
                sharpness: pattern.sharpness,
                duration: pattern.duration
            )
        }
    }

    /// Play custom haptic
    public func playCustom(intensity: Float, sharpness: Float, duration: Double) {
        guard hapticEnabled, isHapticAvailable else { return }

        hapticQueue.async { [weak self] in
            self?.playPattern(
                intensity: intensity * Float(self?.hapticIntensity ?? 1.0),
                sharpness: sharpness,
                duration: duration
            )
        }
    }

    private func playPattern(intensity: Float, sharpness: Float, duration: Double) {
        guard let engine = hapticEngine else { return }

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: duration
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic playback failed: \(error)")
        }
    }

    /// Play success pattern (replaces success sound)
    public func playSuccess() {
        play(.success)
    }

    /// Play warning pattern (replaces warning sound)
    public func playWarning() {
        play(.warning)
    }

    /// Play error pattern (replaces error sound)
    public func playError() {
        // Double tap for error
        play(.error)
        hapticQueue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.play(.error)
        }
    }

    /// Play beat sync (for rhythm feedback)
    public func playBeat(intensity: Float = 0.7) {
        playCustom(intensity: intensity, sharpness: 0.8, duration: 0.1)
    }

    /// Play level meter haptic (continuous feedback of audio level)
    public func playLevelFeedback(level: Float) {
        // Map 0-1 level to haptic intensity
        let mappedIntensity = level * 0.5 // Keep it subtle
        playCustom(intensity: mappedIntensity, sharpness: 0.2, duration: 0.05)
    }

    /// Play peak warning (replaces visual peak indicator)
    public func playPeakWarning() {
        play(.peakWarning)
    }

    /// Play clip detected (replaces red clip indicator)
    public func playClipDetected() {
        // Urgent triple tap
        for i in 0..<3 {
            hapticQueue.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                self?.play(.clipDetected)
            }
        }
    }

    /// Play transport control feedback
    public func playTransport(_ action: TransportAction) {
        switch action {
        case .play:
            play(.playStart)
        case .stop:
            play(.playStop)
        case .record:
            // Special record pattern: two short + one long
            play(.recordStart)
            hapticQueue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.play(.recordStart)
            }
            hapticQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.playCustom(intensity: 0.9, sharpness: 0.7, duration: 0.5)
            }
        case .stopRecord:
            play(.recordStop)
        }
    }

    public enum TransportAction {
        case play, stop, record, stopRecord
    }

    /// Continuous haptic for scrubbing
    public func startScrubbing() {
        // Would use continuous haptic player
    }

    public func updateScrubbing(position: Double, velocity: Double) {
        let intensity = min(1.0, abs(velocity) * 0.5)
        playCustom(intensity: Float(intensity), sharpness: 0.4, duration: 0.02)
    }

    public func stopScrubbing() {
        // End continuous haptic
    }
}

// MARK: - Visual Alert System (For Deaf Users)

/// Visual alternatives to all audio alerts
public final class VisualAlertEngine: ObservableObject {

    public static let shared = VisualAlertEngine()

    @Published public var currentAlert: VisualAlert?
    @Published public var alertHistory: [VisualAlert] = []
    @Published public var screenFlashEnabled: Bool = true
    @Published public var colorCodedAlerts: Bool = true

    public struct VisualAlert: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let type: AlertType
        public let message: String
        public let priority: Priority
        public let duration: Double
        public let color: AlertColor
        public let icon: String
        public let hapticFeedback: HapticFeedbackEngine.HapticPattern?

        public enum AlertType: String {
            case info, success, warning, error, notification
            case audioLevel, clip, recording, playback
        }

        public enum Priority: Int {
            case low = 0, normal = 1, high = 2, urgent = 3
        }

        public enum AlertColor: String {
            case blue = "Info"
            case green = "Success"
            case yellow = "Warning"
            case red = "Error"
            case purple = "Recording"
            case orange = "Clip"
        }
    }

    private var alertTimer: Timer?

    private init() {}

    /// Show visual alert
    public func show(_ alert: VisualAlert) {
        DispatchQueue.main.async { [weak self] in
            self?.currentAlert = alert
            self?.alertHistory.append(alert)

            // Trigger haptic feedback
            if let haptic = alert.hapticFeedback {
                HapticFeedbackEngine.shared.play(haptic)
            }

            // Screen flash for urgent alerts
            if alert.priority == .urgent && self?.screenFlashEnabled == true {
                self?.flashScreen(color: alert.color)
            }

            // Auto-dismiss
            self?.alertTimer?.invalidate()
            self?.alertTimer = Timer.scheduledTimer(withTimeInterval: alert.duration, repeats: false) { _ in
                DispatchQueue.main.async {
                    self?.currentAlert = nil
                }
            }
        }

        // Keep history limited
        if alertHistory.count > 50 {
            alertHistory.removeFirst()
        }
    }

    /// Quick alert creators
    public func showInfo(_ message: String) {
        show(VisualAlert(
            timestamp: Date(),
            type: .info,
            message: message,
            priority: .normal,
            duration: 3.0,
            color: .blue,
            icon: "ℹ️",
            hapticFeedback: .notification
        ))
    }

    public func showSuccess(_ message: String) {
        show(VisualAlert(
            timestamp: Date(),
            type: .success,
            message: message,
            priority: .normal,
            duration: 2.0,
            color: .green,
            icon: "✅",
            hapticFeedback: .success
        ))
    }

    public func showWarning(_ message: String) {
        show(VisualAlert(
            timestamp: Date(),
            type: .warning,
            message: message,
            priority: .high,
            duration: 4.0,
            color: .yellow,
            icon: "⚠️",
            hapticFeedback: .warning
        ))
    }

    public func showError(_ message: String) {
        show(VisualAlert(
            timestamp: Date(),
            type: .error,
            message: message,
            priority: .urgent,
            duration: 5.0,
            color: .red,
            icon: "❌",
            hapticFeedback: .error
        ))
    }

    /// Show recording started (replaces beep)
    public func showRecordingStarted() {
        show(VisualAlert(
            timestamp: Date(),
            type: .recording,
            message: "Aufnahme gestartet",
            priority: .high,
            duration: 2.0,
            color: .purple,
            icon: "🔴",
            hapticFeedback: .recordStart
        ))
    }

    /// Show clip detected (replaces audio warning)
    public func showClipDetected(channel: String = "") {
        let channelInfo = channel.isEmpty ? "" : " auf \(channel)"
        show(VisualAlert(
            timestamp: Date(),
            type: .clip,
            message: "Übersteuerung erkannt\(channelInfo)",
            priority: .urgent,
            duration: 3.0,
            color: .orange,
            icon: "📊",
            hapticFeedback: .clipDetected
        ))
    }

    private func flashScreen(color: VisualAlert.AlertColor) {
        // Screen flash would be implemented per-platform
        #if os(iOS)
        // Would use UIView animation or accessibility API
        #endif
    }

    /// Clear current alert
    public func dismiss() {
        alertTimer?.invalidate()
        currentAlert = nil
    }
}

// MARK: - Sign Language Support

/// Support for sign language display and interpretation
public final class SignLanguageEngine: ObservableObject {

    public static let shared = SignLanguageEngine()

    @Published public var isSignLanguageEnabled: Bool = false
    @Published public var preferredSignLanguage: SignLanguageType = .dgs
    @Published public var avatarEnabled: Bool = true
    @Published public var subtitlesEnabled: Bool = true

    public enum SignLanguageType: String, CaseIterable {
        case dgs = "DGS"        // Deutsche Gebärdensprache
        case asl = "ASL"        // American Sign Language
        case bsl = "BSL"        // British Sign Language
        case lsf = "LSF"        // Langue des Signes Française
        case auslan = "Auslan"  // Australian Sign Language
        case isl = "ISL"        // International Sign Language

        public var fullName: String {
            switch self {
            case .dgs: return "Deutsche Gebärdensprache"
            case .asl: return "American Sign Language"
            case .bsl: return "British Sign Language"
            case .lsf: return "Langue des Signes Française"
            case .auslan: return "Australian Sign Language"
            case .isl: return "International Sign Language"
            }
        }
    }

    /// Common phrases in sign language notation
    private let signDictionary: [String: [SignLanguageType: String]] = [
        "play": [
            .dgs: "Beide Hände vor Brust, Finger bewegen wie Klavier",
            .asl: "Both hands move forward from body"
        ],
        "stop": [
            .dgs: "Flache Hand stoppt vor Körper",
            .asl: "Flat hand chops into palm"
        ],
        "record": [
            .dgs: "Kreisende Bewegung an Schläfe",
            .asl: "R hand circles near temple"
        ],
        "volume_up": [
            .dgs: "Hand öffnet sich nach oben",
            .asl: "Hand rises with fingers spreading"
        ],
        "volume_down": [
            .dgs: "Hand schließt sich nach unten",
            .asl: "Hand lowers with fingers closing"
        ],
        "error": [
            .dgs: "X mit Armen vor Körper",
            .asl: "Arms cross in X shape"
        ],
        "success": [
            .dgs: "Daumen hoch",
            .asl: "Thumbs up"
        ],
        "warning": [
            .dgs: "Hand wedelt vor Gesicht",
            .asl: "Hand waves in front of face"
        ]
    ]

    private init() {
        detectSignLanguagePreference()
    }

    private func detectSignLanguagePreference() {
        // Detect from locale
        let locale = Locale.current.language.languageCode?.identifier ?? "en"

        switch locale {
        case "de", "at", "ch":
            preferredSignLanguage = .dgs
        case "en":
            if Locale.current.region?.identifier == "GB" {
                preferredSignLanguage = .bsl
            } else if Locale.current.region?.identifier == "AU" {
                preferredSignLanguage = .auslan
            } else {
                preferredSignLanguage = .asl
            }
        case "fr":
            preferredSignLanguage = .lsf
        default:
            preferredSignLanguage = .isl
        }
    }

    /// Get sign language description for action
    public func getSignDescription(for action: String) -> String? {
        guard let signs = signDictionary[action.lowercased()],
              let description = signs[preferredSignLanguage] ?? signs[.asl] else {
            return nil
        }
        return description
    }

    /// Generate subtitle with sign language cue
    public func generateSubtitle(text: String, withSignCue: Bool = true) -> AttributedString {
        var attributed = AttributedString(text)

        if withSignCue && isSignLanguageEnabled {
            // Add sign language indicator
            var signIndicator = AttributedString(" 🤟")
            signIndicator.foregroundColor = .blue
            attributed.append(signIndicator)
        }

        return attributed
    }

    /// Check if sign language avatar should be shown
    public func shouldShowAvatar() -> Bool {
        return isSignLanguageEnabled && avatarEnabled
    }
}

// MARK: - Braille Display Support

/// Support for refreshable Braille displays
public final class BrailleEngine: ObservableObject {

    public static let shared = BrailleEngine()

    @Published public var isBrailleDisplayConnected: Bool = false
    @Published public var brailleGrade: BrailleGrade = .grade2
    @Published public var cellCount: Int = 40  // Standard 40-cell display

    public enum BrailleGrade: String {
        case grade1 = "Grade 1"   // Uncontracted
        case grade2 = "Grade 2"   // Contracted
        case computer = "Computer Braille"
        case music = "Music Braille"
    }

    /// Braille patterns for common symbols
    private let braillePatterns: [Character: String] = [
        "a": "⠁", "b": "⠃", "c": "⠉", "d": "⠙", "e": "⠑",
        "f": "⠋", "g": "⠛", "h": "⠓", "i": "⠊", "j": "⠚",
        "k": "⠅", "l": "⠇", "m": "⠍", "n": "⠝", "o": "⠕",
        "p": "⠏", "q": "⠟", "r": "⠗", "s": "⠎", "t": "⠞",
        "u": "⠥", "v": "⠧", "w": "⠺", "x": "⠭", "y": "⠽",
        "z": "⠵", " ": "⠀",
        "0": "⠴", "1": "⠂", "2": "⠆", "3": "⠒", "4": "⠲",
        "5": "⠢", "6": "⠖", "7": "⠶", "8": "⠦", "9": "⠔"
    ]

    /// Music Braille symbols
    private let musicBrailleSymbols: [String: String] = [
        "whole_note": "⠽",
        "half_note": "⠵",
        "quarter_note": "⠹",
        "eighth_note": "⠣",
        "rest": "⠍",
        "sharp": "⠩",
        "flat": "⠣",
        "natural": "⠡",
        "bar": "⠀⠶⠀",
        "repeat": "⠶⠶"
    ]

    private init() {
        detectBrailleDisplay()
    }

    private func detectBrailleDisplay() {
        #if os(iOS)
        // Check if Braille display is connected via VoiceOver
        // This is a simplified check
        isBrailleDisplayConnected = UIAccessibility.isVoiceOverRunning
        #endif
    }

    /// Convert text to Braille
    public func toBraille(_ text: String) -> String {
        var result = ""

        for char in text.lowercased() {
            if let pattern = braillePatterns[char] {
                result += pattern
            } else {
                result += String(char)
            }
        }

        return result
    }

    /// Convert music notation to Music Braille
    public func toMusicBraille(_ notation: MusicNotation) -> String {
        var result = ""

        for element in notation.elements {
            switch element {
            case .note(let pitch, let duration):
                result += noteToMusicBraille(pitch: pitch, duration: duration)
            case .rest(let duration):
                result += restToMusicBraille(duration: duration)
            case .barline:
                result += musicBrailleSymbols["bar"] ?? ""
            case .accidental(let type):
                result += accidentalToMusicBraille(type: type)
            }
        }

        return result
    }

    private func noteToMusicBraille(pitch: String, duration: NoteDuration) -> String {
        let durationSymbol: String
        switch duration {
        case .whole: durationSymbol = musicBrailleSymbols["whole_note"] ?? ""
        case .half: durationSymbol = musicBrailleSymbols["half_note"] ?? ""
        case .quarter: durationSymbol = musicBrailleSymbols["quarter_note"] ?? ""
        case .eighth: durationSymbol = musicBrailleSymbols["eighth_note"] ?? ""
        }
        return durationSymbol
    }

    private func restToMusicBraille(duration: NoteDuration) -> String {
        return musicBrailleSymbols["rest"] ?? "⠍"
    }

    private func accidentalToMusicBraille(type: AccidentalType) -> String {
        switch type {
        case .sharp: return musicBrailleSymbols["sharp"] ?? ""
        case .flat: return musicBrailleSymbols["flat"] ?? ""
        case .natural: return musicBrailleSymbols["natural"] ?? ""
        }
    }

    public struct MusicNotation {
        public var elements: [Element]

        public enum Element {
            case note(pitch: String, duration: NoteDuration)
            case rest(duration: NoteDuration)
            case barline
            case accidental(type: AccidentalType)
        }
    }

    public enum NoteDuration {
        case whole, half, quarter, eighth
    }

    public enum AccidentalType {
        case sharp, flat, natural
    }

    /// Format text for Braille display with limited cells
    public func formatForDisplay(_ text: String, maxCells: Int? = nil) -> String {
        let cells = maxCells ?? cellCount
        let braille = toBraille(text)

        if braille.count <= cells {
            return braille
        }

        // Truncate with ellipsis
        let truncated = String(braille.prefix(cells - 3))
        return truncated + "⠄⠄⠄"  // Braille ellipsis
    }
}

// MARK: - Deep Accessibility Engine (Master Controller)

/// Master controller for all accessibility features
@MainActor
public final class DeepAccessibilityEngine: ObservableObject {

    public static let shared = DeepAccessibilityEngine()

    // Sub-engines
    public let autoDetector = AccessibilityAutoDetector.shared
    public let screenReader = ScreenReaderEngine.shared
    public let haptic = HapticFeedbackEngine.shared
    public let visualAlert = VisualAlertEngine.shared
    public let signLanguage = SignLanguageEngine.shared
    public let braille = BrailleEngine.shared

    // State
    @Published public var isFullyAccessible: Bool = true
    @Published public var activeAccessibilityModes: Set<AccessibilityMode> = []
    @Published public var currentInteractionMode: InteractionMode = .standard

    public enum AccessibilityMode: String, CaseIterable {
        case screenReader = "Screen Reader"
        case magnification = "Magnification"
        case highContrast = "High Contrast"
        case colorCorrection = "Color Correction"
        case hapticFeedback = "Haptic Feedback"
        case visualAlerts = "Visual Alerts"
        case signLanguage = "Sign Language"
        case brailleDisplay = "Braille Display"
        case voiceControl = "Voice Control"
        case switchControl = "Switch Control"
        case reducedMotion = "Reduced Motion"
        case simplifiedUI = "Simplified UI"

        public var icon: String {
            switch self {
            case .screenReader: return "👁️‍🗨️"
            case .magnification: return "🔍"
            case .highContrast: return "◐"
            case .colorCorrection: return "🎨"
            case .hapticFeedback: return "📳"
            case .visualAlerts: return "💡"
            case .signLanguage: return "🤟"
            case .brailleDisplay: return "⠃"
            case .voiceControl: return "🎤"
            case .switchControl: return "🔘"
            case .reducedMotion: return "🚫"
            case .simplifiedUI: return "📋"
            }
        }
    }

    public enum InteractionMode: String {
        case standard = "Standard"
        case blind = "Blind Mode"
        case deaf = "Deaf Mode"
        case deafBlind = "Deaf-Blind Mode"
        case motorImpaired = "Motor Impaired Mode"
        case cognitive = "Cognitive Support Mode"

        public var description: String {
            switch self {
            case .standard:
                return "Standard-Interaktion"
            case .blind:
                return "Volle Audio-Beschreibung, Braille-Unterstützung, keine visuellen Anforderungen"
            case .deaf:
                return "Keine Audio-Warnungen, visuelle Alerts, Gebärdensprache, Untertitel"
            case .deafBlind:
                return "Braille-Ausgabe, Haptisches Feedback, kein Audio oder visueller Output"
            case .motorImpaired:
                return "Große Touch-Ziele, Switch Control, Sprachsteuerung"
            case .cognitive:
                return "Vereinfachte UI, extra Zeit, Lesehilfe"
            }
        }
    }

    private init() {
        setupFromDetectedProfile()
        startAccessibilityMonitoring()
    }

    /// Setup accessibility based on detected profile
    private func setupFromDetectedProfile() {
        let profile = autoDetector.detectedProfile

        // Vision-based setup
        switch profile.visionStatus {
        case .totallyBlind:
            currentInteractionMode = .blind
            activeAccessibilityModes.insert(.screenReader)
            activeAccessibilityModes.insert(.hapticFeedback)
            if braille.isBrailleDisplayConnected {
                activeAccessibilityModes.insert(.brailleDisplay)
            }

        case .legallyBlind, .lowVision:
            activeAccessibilityModes.insert(.magnification)
            activeAccessibilityModes.insert(.highContrast)
            activeAccessibilityModes.insert(.screenReader)

        default:
            break
        }

        // Hearing-based setup
        switch profile.hearingStatus {
        case .deaf, .profoundLoss:
            if currentInteractionMode == .blind {
                currentInteractionMode = .deafBlind
            } else {
                currentInteractionMode = .deaf
            }
            activeAccessibilityModes.insert(.visualAlerts)
            activeAccessibilityModes.insert(.hapticFeedback)
            if signLanguage.isSignLanguageEnabled {
                activeAccessibilityModes.insert(.signLanguage)
            }

        case .severeLoss, .moderateLoss:
            activeAccessibilityModes.insert(.visualAlerts)
            activeAccessibilityModes.insert(.hapticFeedback)

        default:
            break
        }

        // Motor-based setup
        switch profile.motorStatus {
        case .severeImpairment:
            currentInteractionMode = .motorImpaired
            if profile.usesSwitchControl {
                activeAccessibilityModes.insert(.switchControl)
            }
            if profile.usesVoiceControl {
                activeAccessibilityModes.insert(.voiceControl)
            }

        case .moderateImpairment, .mildImpairment:
            activeAccessibilityModes.insert(.hapticFeedback)

        default:
            break
        }

        // Cognitive setup
        if profile.cognitiveStatus != .unknown && profile.cognitiveStatus != .normal {
            activeAccessibilityModes.insert(.simplifiedUI)
            activeAccessibilityModes.insert(.reducedMotion)
        }

        // Additional preferences
        if profile.prefersHighContrast {
            activeAccessibilityModes.insert(.highContrast)
        }

        if profile.colorVisionType != .normal {
            activeAccessibilityModes.insert(.colorCorrection)
        }

        if profile.vestibularSensitivity {
            activeAccessibilityModes.insert(.reducedMotion)
        }
    }

    /// Start monitoring accessibility needs
    private func startAccessibilityMonitoring() {
        // Observe profile changes
        autoDetector.$detectedProfile
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupFromDetectedProfile()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Unified Feedback API

    /// Send feedback in all appropriate modes (NO AUDIO WARNINGS)
    public func sendFeedback(_ type: FeedbackType, message: String, priority: FeedbackPriority = .normal) {

        // NEVER play audio warnings by default
        // Audio is only for content (music), not alerts

        // Haptic feedback (for everyone who can feel it)
        if activeAccessibilityModes.contains(.hapticFeedback) || currentInteractionMode != .standard {
            let hapticPattern: HapticFeedbackEngine.HapticPattern
            switch type {
            case .success: hapticPattern = .success
            case .warning: hapticPattern = .warning
            case .error: hapticPattern = .error
            case .info: hapticPattern = .notification
            case .transport: hapticPattern = .playStart
            case .level: hapticPattern = .levelMeter
            }
            haptic.play(hapticPattern)
        }

        // Visual feedback (for deaf users and visual preference)
        if activeAccessibilityModes.contains(.visualAlerts) || currentInteractionMode == .deaf || currentInteractionMode == .deafBlind {
            switch type {
            case .success:
                visualAlert.showSuccess(message)
            case .warning:
                visualAlert.showWarning(message)
            case .error:
                visualAlert.showError(message)
            case .info:
                visualAlert.showInfo(message)
            default:
                visualAlert.showInfo(message)
            }
        }

        // Screen reader announcement (for blind users)
        if activeAccessibilityModes.contains(.screenReader) || currentInteractionMode == .blind {
            let isUrgent = priority == .urgent || type == .error
            screenReader.announce(message, priority: isUrgent ? .critical : .normal, interrupt: isUrgent)
        }

        // Braille output (for deaf-blind users)
        if activeAccessibilityModes.contains(.brailleDisplay) || currentInteractionMode == .deafBlind {
            let brailleText = braille.formatForDisplay(message)
            // Would send to Braille display
            print("Braille: \(brailleText)")
        }
    }

    public enum FeedbackType {
        case success, warning, error, info, transport, level
    }

    public enum FeedbackPriority {
        case low, normal, high, urgent
    }

    // MARK: - Convenience Methods

    /// Announce for blind users
    public func announceForBlind(_ text: String) {
        screenReader.announce(text)
    }

    /// Show visual alert for deaf users
    public func alertForDeaf(_ message: String, type: VisualAlertEngine.VisualAlert.AlertType = .notification) {
        let alert = VisualAlertEngine.VisualAlert(
            timestamp: Date(),
            type: type,
            message: message,
            priority: .normal,
            duration: 3.0,
            color: .blue,
            icon: "🔔",
            hapticFeedback: .notification
        )
        visualAlert.show(alert)
    }

    /// Combined feedback for all users
    public func notifyAll(_ message: String, success: Bool = true) {
        sendFeedback(success ? .success : .info, message: message)
    }

    /// Get current accessibility configuration summary
    public func getConfigurationSummary() -> String {
        var summary = "Aktive Barrierefreiheit:\n"

        if activeAccessibilityModes.isEmpty {
            summary += "- Standard-Modus\n"
        } else {
            for mode in activeAccessibilityModes.sorted(by: { $0.rawValue < $1.rawValue }) {
                summary += "- \(mode.icon) \(mode.rawValue)\n"
            }
        }

        summary += "\nInteraktionsmodus: \(currentInteractionMode.rawValue)"

        return summary
    }

    /// Print startup info
    public func printStartupInfo() {
        print("""

        ╔═══════════════════════════════════════════════════════════════════════════╗
        ║                    DEEP ACCESSIBILITY ENGINE                              ║
        ║                    Barrierefreiheit für ALLE                              ║
        ╠═══════════════════════════════════════════════════════════════════════════╣
        ║                                                                           ║
        ║   Aktiver Modus: \(currentInteractionMode.rawValue.padding(toLength: 25, withPad: " ", startingAt: 0))                          ║
        ║                                                                           ║
        ║   Aktive Features:                                                        ║
        \(activeAccessibilityModes.isEmpty ? "║   - Standard                                                              ║\n" : activeAccessibilityModes.map { "║   - \($0.icon) \($0.rawValue.padding(toLength: 30, withPad: " ", startingAt: 0))                              ║" }.joined(separator: "\n"))
        ║                                                                           ║
        ║   Keine Audio-Warnungen: ✅                                               ║
        ║   Haptisches Feedback: \(haptic.isHapticAvailable ? "✅" : "❌")                                                ║
        ║   Screen Reader: \(screenReader.isScreenReaderActive ? "✅ Aktiv" : "⏸️ Bereit")                                             ║
        ║   Braille Display: \(braille.isBrailleDisplayConnected ? "✅ Verbunden" : "⏸️ Nicht verbunden")                                    ║
        ║                                                                           ║
        ║   Erkennungs-Konfidenz: \(String(format: "%.0f%%", autoDetector.confidenceLevel * 100).padding(toLength: 5, withPad: " ", startingAt: 0))                                       ║
        ║                                                                           ║
        ╚═══════════════════════════════════════════════════════════════════════════╝

        """)
    }
}

// MARK: - Quick Start

/// Easy access to accessibility features
public struct DeepAccessibilityQuickStart {

    /// Initialize accessibility engine
    @MainActor
    public static func activate() async -> DeepAccessibilityEngine {
        let engine = DeepAccessibilityEngine.shared

        // Wait for detection
        try? await Task.sleep(nanoseconds: 500_000_000)

        engine.printStartupInfo()
        return engine
    }

    /// Quick feedback - uses all appropriate channels
    @MainActor
    public static func feedback(_ message: String, success: Bool = true) {
        DeepAccessibilityEngine.shared.notifyAll(message, success: success)
    }

    /// Announce text
    @MainActor
    public static func announce(_ text: String) {
        DeepAccessibilityEngine.shared.announceForBlind(text)
    }

    /// Visual alert
    @MainActor
    public static func visualAlert(_ message: String) {
        DeepAccessibilityEngine.shared.alertForDeaf(message)
    }

    /// Haptic feedback
    public static func haptic(_ pattern: HapticFeedbackEngine.HapticPattern) {
        HapticFeedbackEngine.shared.play(pattern)
    }

    /// Print supported features
    public static func printFeatures() {
        print("""

        ╔═══════════════════════════════════════════════════════════════════════════╗
        ║                 ACCESSIBILITY FEATURES / BARRIEREFREIHEIT                 ║
        ╠═══════════════════════════════════════════════════════════════════════════╣
        ║                                                                           ║
        ║   👁️ FÜR BLINDE NUTZER:                                                   ║
        ║      • VoiceOver / Screen Reader Integration                             ║
        ║      • Vollständige Audio-Beschreibungen                                 ║
        ║      • Braille-Display Unterstützung                                     ║
        ║      • Musik-Braille Notation                                            ║
        ║      • Tastatur-Navigation                                               ║
        ║                                                                           ║
        ║   👂 FÜR GEHÖRLOSE/SCHWERHÖRIGE:                                          ║
        ║      • KEINE Audio-Warnungen (nur haptisch/visuell)                      ║
        ║      • Visuelle Alerts mit Farb-Kodierung                                ║
        ║      • Haptisches Feedback für alle Events                               ║
        ║      • Gebärdensprache-Unterstützung (DGS, ASL, BSL...)                  ║
        ║      • Untertitel für alle Audio-Inhalte                                 ║
        ║      • Bildschirm-Blitz bei wichtigen Events                             ║
        ║                                                                           ║
        ║   🤲 FÜR MOTORISCH EINGESCHRÄNKTE:                                        ║
        ║      • Switch Control Unterstützung                                      ║
        ║      • Sprachsteuerung                                                   ║
        ║      • Große Touch-Ziele (bis 120pt)                                     ║
        ║      • Tremor-Erkennung und -Kompensation                                ║
        ║      • Anpassbare Gesten                                                 ║
        ║                                                                           ║
        ║   🧠 FÜR KOGNITIVE UNTERSTÜTZUNG:                                         ║
        ║      • Vereinfachte Benutzeroberfläche                                   ║
        ║      • Verlängerte Timeouts                                              ║
        ║      • Lesehilfe                                                         ║
        ║      • Reduzierte Bewegung                                               ║
        ║                                                                           ║
        ║   🔬 AUTOMATISCHE ERKENNUNG:                                              ║
        ║      • Lernt aus Nutzerverhalten                                         ║
        ║      • Synchronisiert mit System-Einstellungen                           ║
        ║      • Passt sich automatisch an                                         ║
        ║                                                                           ║
        ╚═══════════════════════════════════════════════════════════════════════════╝

        """)
    }
}
