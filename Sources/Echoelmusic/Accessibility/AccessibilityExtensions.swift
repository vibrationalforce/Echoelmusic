// AccessibilityExtensions.swift
// Echoelmusic - Accessibility Extensions
// SPDX-License-Identifier: MIT
//
// SwiftUI extensions for consistent accessibility across the app

import SwiftUI

// MARK: - Accessibility View Modifier

public struct EchoelAccessibility: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let value: String?
    let isHidden: Bool

    public init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil,
        isHidden: Bool = false
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
        self.isHidden = isHidden
    }

    public func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
            .accessibilityHidden(isHidden)
    }
}

// MARK: - View Extension

public extension View {

    /// Add Echoelmusic standard accessibility
    func echoelAccessibility(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        modifier(EchoelAccessibility(
            label: label,
            hint: hint,
            traits: traits,
            value: value
        ))
    }

    /// Audio control accessibility
    func audioControlAccessibility(
        name: String,
        value: String,
        hint: String? = nil
    ) -> some View {
        echoelAccessibility(
            label: "\(name) audio control",
            hint: hint ?? "Double tap to adjust \(name.lowercased())",
            traits: .isButton,
            value: value
        )
    }

    /// Slider accessibility
    func sliderAccessibility(
        name: String,
        value: Double,
        range: ClosedRange<Double>,
        unit: String = ""
    ) -> some View {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound) * 100
        let valueString = unit.isEmpty
            ? String(format: "%.0f%%", percentage)
            : String(format: "%.1f %@", value, unit)

        return echoelAccessibility(
            label: name,
            hint: "Adjustable. Swipe up or down to change value",
            traits: .allowsDirectInteraction,
            value: valueString
        )
    }

    /// Button accessibility
    func buttonAccessibility(_ label: String, hint: String? = nil) -> some View {
        echoelAccessibility(
            label: label,
            hint: hint ?? "Double tap to activate",
            traits: .isButton
        )
    }

    /// Toggle accessibility
    func toggleAccessibility(_ label: String, isOn: Bool) -> some View {
        echoelAccessibility(
            label: label,
            hint: "Double tap to toggle",
            traits: .isButton,
            value: isOn ? "On" : "Off"
        )
    }

    /// Image accessibility (decorative or meaningful)
    func imageAccessibility(_ label: String?, isDecorative: Bool = false) -> some View {
        if isDecorative {
            return AnyView(accessibilityHidden(true))
        }
        return AnyView(echoelAccessibility(
            label: label ?? "Image",
            traits: .isImage
        ))
    }

    /// Header accessibility
    func headerAccessibility(_ label: String) -> some View {
        echoelAccessibility(
            label: label,
            traits: .isHeader
        )
    }

    /// Link accessibility
    func linkAccessibility(_ label: String, destination: String) -> some View {
        echoelAccessibility(
            label: label,
            hint: "Opens \(destination)",
            traits: .isLink
        )
    }

    /// Tab accessibility
    func tabAccessibility(_ label: String, isSelected: Bool) -> some View {
        echoelAccessibility(
            label: label,
            hint: isSelected ? "Selected" : "Double tap to select",
            traits: isSelected ? [.isSelected, .isButton] : .isButton
        )
    }

    /// MIDI note accessibility
    func midiNoteAccessibility(note: Int, velocity: Int, isPlaying: Bool) -> some View {
        let noteName = MIDINoteNames.name(for: note)
        let octave = (note / 12) - 1
        let state = isPlaying ? "Playing" : "Ready"

        return echoelAccessibility(
            label: "\(noteName)\(octave)",
            hint: "Double tap to play note",
            traits: .isButton,
            value: "\(state), velocity \(velocity)"
        )
    }

    /// Biofeedback value accessibility
    func bioValueAccessibility(
        metric: String,
        value: Double,
        unit: String,
        trend: String? = nil
    ) -> some View {
        var valueString = String(format: "%.1f %@", value, unit)
        if let trend = trend {
            valueString += ", \(trend)"
        }

        return echoelAccessibility(
            label: metric,
            hint: "Current biofeedback reading",
            traits: .updatesFrequently,
            value: valueString
        )
    }

    /// Waveform accessibility
    func waveformAccessibility(
        trackName: String,
        duration: TimeInterval,
        currentPosition: TimeInterval
    ) -> some View {
        let positionPercent = (currentPosition / duration) * 100
        let formattedDuration = formatTime(duration)
        let formattedPosition = formatTime(currentPosition)

        return echoelAccessibility(
            label: "\(trackName) waveform",
            hint: "Audio waveform visualization. Swipe to scrub position",
            traits: .allowsDirectInteraction,
            value: "\(formattedPosition) of \(formattedDuration), \(Int(positionPercent))%"
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Visualization accessibility
    func visualizationAccessibility(mode: String, audioLevel: Float) -> some View {
        let levelPercent = Int(audioLevel * 100)

        return echoelAccessibility(
            label: "\(mode) visualization",
            hint: "Audio-reactive visual display",
            traits: .updatesFrequently,
            value: "Audio level \(levelPercent)%"
        )
    }
}

// MARK: - MIDI Note Names

public enum MIDINoteNames {
    private static let notes = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    public static func name(for midiNote: Int) -> String {
        guard midiNote >= 0 && midiNote <= 127 else { return "?" }
        return notes[midiNote % 12]
    }

    public static func fullName(for midiNote: Int) -> String {
        guard midiNote >= 0 && midiNote <= 127 else { return "?" }
        let octave = (midiNote / 12) - 1
        return "\(notes[midiNote % 12])\(octave)"
    }
}

// MARK: - Accessibility Announcements

public enum AccessibilityAnnouncement {

    /// Announce to VoiceOver users
    public static func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: priority, argument: message)
        #endif
    }

    /// Announce screen change
    public static func screenChanged(_ screenName: String) {
        announce("\(screenName) screen")
    }

    /// Announce layout change
    public static func layoutChanged(_ description: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .layoutChanged, argument: description)
        #endif
    }

    /// Announce recording started
    public static func recordingStarted() {
        announce("Recording started")
    }

    /// Announce recording stopped
    public static func recordingStopped(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        announce("Recording stopped. Duration: \(minutes) minutes, \(seconds) seconds")
    }

    /// Announce playback status
    public static func playbackStatus(isPlaying: Bool) {
        announce(isPlaying ? "Playback started" : "Playback paused")
    }

    /// Announce biofeedback connection
    public static func biofeedbackConnected(sensor: String) {
        announce("\(sensor) connected")
    }

    /// Announce export complete
    public static func exportComplete(filename: String) {
        announce("Export complete: \(filename)")
    }

    /// Announce error
    public static func error(_ message: String) {
        announce("Error: \(message)")
    }
}

// MARK: - Accessibility Focus

public struct AccessibilityFocusState<Value: Hashable>: DynamicProperty {
    @FocusState private var focusedField: Value?

    public var wrappedValue: Value? {
        get { focusedField }
        nonmutating set { focusedField = newValue }
    }

    public init() {}
}

// MARK: - Accessibility Preferences

public class AccessibilityPreferences: ObservableObject {

    public static let shared = AccessibilityPreferences()

    @Published public var reduceMotion: Bool = false
    @Published public var reduceTransparency: Bool = false
    @Published public var increaseContrast: Bool = false
    @Published public var boldText: Bool = false
    @Published public var voiceOverRunning: Bool = false

    private init() {
        updateFromSystem()
        setupNotifications()
    }

    private func updateFromSystem() {
        #if canImport(UIKit)
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        increaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
        boldText = UIAccessibility.isBoldTextEnabled
        voiceOverRunning = UIAccessibility.isVoiceOverRunning
        #endif
    }

    private func setupNotifications() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func accessibilitySettingsChanged() {
        updateFromSystem()
    }
}

// MARK: - Environment Key

private struct AccessibilityPreferencesKey: EnvironmentKey {
    static let defaultValue = AccessibilityPreferences.shared
}

public extension EnvironmentValues {
    var accessibilityPreferences: AccessibilityPreferences {
        get { self[AccessibilityPreferencesKey.self] }
        set { self[AccessibilityPreferencesKey.self] = newValue }
    }
}
