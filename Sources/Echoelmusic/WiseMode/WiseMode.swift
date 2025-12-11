import Foundation
import SwiftUI
import Combine

// MARK: - Wise Mode Core System
/// Zentrale Intelligenz für adaptives Verhalten basierend auf Nutzungskontext
/// Verbindet alle Echoelmusic-Systeme für optimale Performance und UX

/// Wisdom Level - Repräsentiert den Erfahrungs- und Kohärenzgrad
enum WisdomLevel: Int, CaseIterable, Codable {
    case novice = 0      // Neu im System
    case learning = 1    // Grundlagen verstanden
    case practicing = 2  // Regelmäßige Nutzung
    case proficient = 3  // Fortgeschritten
    case expert = 4      // Meister
    case enlightened = 5 // Höchste Stufe

    var displayName: String {
        switch self {
        case .novice: return "Anfänger"
        case .learning: return "Lernender"
        case .practicing: return "Übender"
        case .proficient: return "Fortgeschritten"
        case .expert: return "Experte"
        case .enlightened: return "Erleuchtet"
        }
    }

    var englishName: String {
        switch self {
        case .novice: return "Novice"
        case .learning: return "Learning"
        case .practicing: return "Practicing"
        case .proficient: return "Proficient"
        case .expert: return "Expert"
        case .enlightened: return "Enlightened"
        }
    }

    var icon: String {
        switch self {
        case .novice: return "leaf"
        case .learning: return "book"
        case .practicing: return "figure.mind.and.body"
        case .proficient: return "star"
        case .expert: return "star.fill"
        case .enlightened: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .novice: return .green
        case .learning: return .blue
        case .practicing: return .purple
        case .proficient: return .orange
        case .expert: return .red
        case .enlightened: return .yellow
        }
    }

    /// Mindestanzahl Sitzungen für dieses Level
    var requiredSessions: Int {
        switch self {
        case .novice: return 0
        case .learning: return 5
        case .practicing: return 20
        case .proficient: return 50
        case .expert: return 100
        case .enlightened: return 250
        }
    }

    /// Mindest-Kohärenz-Durchschnitt für dieses Level
    var requiredCoherence: Float {
        switch self {
        case .novice: return 0.0
        case .learning: return 0.3
        case .practicing: return 0.5
        case .proficient: return 0.65
        case .expert: return 0.8
        case .enlightened: return 0.9
        }
    }
}

/// Wise Mode - Hauptmodi für verschiedene Nutzungskontexte
enum WiseMode: String, CaseIterable, Codable, Identifiable {
    case focus = "Focus"           // Tiefe Konzentration
    case flow = "Flow"             // Kreativer Flow-Zustand
    case healing = "Healing"       // Therapeutische Anwendung
    case meditation = "Meditation" // Meditative Praxis
    case energize = "Energize"     // Aktivierung & Energie
    case sleep = "Sleep"           // Schlafvorbereitung
    case social = "Social"         // Gemeinsame Sessions
    case custom = "Custom"         // Benutzerdefiniert

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .flow: return "water.waves"
        case .healing: return "heart.circle"
        case .meditation: return "figure.mind.and.body"
        case .energize: return "bolt.fill"
        case .sleep: return "moon.zzz"
        case .social: return "person.3"
        case .custom: return "slider.horizontal.3"
        }
    }

    var description: String {
        switch self {
        case .focus:
            return "Optimiert für tiefe Konzentration und Produktivität"
        case .flow:
            return "Fördert den kreativen Flow-Zustand"
        case .healing:
            return "Therapeutische Frequenzen für Heilung und Regeneration"
        case .meditation:
            return "Unterstützt meditative Praxis und innere Ruhe"
        case .energize:
            return "Aktivierende Frequenzen für Energie und Vitalität"
        case .sleep:
            return "Entspannende Klänge für erholsamen Schlaf"
        case .social:
            return "Optimiert für gemeinsame Sessions und Gruppenkohärenz"
        case .custom:
            return "Eigene Einstellungen und Kombinationen"
        }
    }

    var color: Color {
        switch self {
        case .focus: return .cyan
        case .flow: return .blue
        case .healing: return .pink
        case .meditation: return .purple
        case .energize: return .orange
        case .sleep: return .indigo
        case .social: return .green
        case .custom: return .gray
        }
    }

    /// Empfohlene Binaural-Beat-Frequenz (Hz)
    var binauralFrequency: Float {
        switch self {
        case .focus: return 14.0      // Low Beta
        case .flow: return 10.0       // Alpha
        case .healing: return 7.83    // Schumann-Resonanz
        case .meditation: return 6.0  // Theta
        case .energize: return 18.0   // Beta
        case .sleep: return 3.0       // Delta
        case .social: return 8.0      // Alpha
        case .custom: return 10.0     // Default Alpha
        }
    }

    /// Empfohlene Session-Dauer (Minuten)
    var recommendedDuration: Int {
        switch self {
        case .focus: return 45
        case .flow: return 60
        case .healing: return 30
        case .meditation: return 20
        case .energize: return 15
        case .sleep: return 45
        case .social: return 30
        case .custom: return 30
        }
    }

    /// Empfohlene Visualisierung
    var recommendedVisualization: String {
        switch self {
        case .focus: return "spectral"
        case .flow: return "particles"
        case .healing: return "mandala"
        case .meditation: return "cymatics"
        case .energize: return "waveform"
        case .sleep: return "cymatics"
        case .social: return "particles"
        case .custom: return "particles"
        }
    }
}

// MARK: - Wise Mode Configuration

/// Konfiguration für einen Wise Mode
struct WiseModeConfiguration: Codable, Identifiable {
    let id: UUID
    var mode: WiseMode
    var binauralFrequency: Float
    var carrierFrequency: Float
    var visualizationMode: String
    var colorScheme: WiseColorScheme
    var hapticFeedback: HapticIntensity
    var audioQuality: AudioQuality
    var bioAdaptive: Bool
    var sessionDuration: Int // Minuten

    init(mode: WiseMode) {
        self.id = UUID()
        self.mode = mode
        self.binauralFrequency = mode.binauralFrequency
        self.carrierFrequency = 432.0
        self.visualizationMode = mode.recommendedVisualization
        self.colorScheme = .auto
        self.hapticFeedback = .medium
        self.audioQuality = .high
        self.bioAdaptive = true
        self.sessionDuration = mode.recommendedDuration
    }
}

enum WiseColorScheme: String, Codable, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"
    case nature = "Nature"
    case cosmic = "Cosmic"
    case minimal = "Minimal"
}

enum HapticIntensity: String, Codable, CaseIterable {
    case off = "Off"
    case light = "Light"
    case medium = "Medium"
    case strong = "Strong"

    var value: Float {
        switch self {
        case .off: return 0.0
        case .light: return 0.3
        case .medium: return 0.6
        case .strong: return 1.0
        }
    }
}

enum AudioQuality: String, Codable, CaseIterable {
    case efficient = "Efficient"   // 44.1kHz, niedriger Stromverbrauch
    case standard = "Standard"     // 48kHz
    case high = "High"             // 96kHz
    case studio = "Studio"         // 192kHz

    var sampleRate: Double {
        switch self {
        case .efficient: return 44100.0
        case .standard: return 48000.0
        case .high: return 96000.0
        case .studio: return 192000.0
        }
    }

    var bitDepth: Int {
        switch self {
        case .efficient: return 16
        case .standard: return 24
        case .high: return 24
        case .studio: return 32
        }
    }
}

// MARK: - Wise Mode Transition

/// Repräsentiert einen Mode-Übergang
struct WiseModeTransition: Codable {
    let fromMode: WiseMode
    let toMode: WiseMode
    let timestamp: Date
    let duration: TimeInterval
    let reason: TransitionReason

    enum TransitionReason: String, Codable {
        case userInitiated = "User Initiated"
        case scheduled = "Scheduled"
        case bioAdaptive = "Bio-Adaptive"
        case timeOfDay = "Time of Day"
        case groupSync = "Group Sync"
    }
}

// MARK: - Wise Session Statistics

/// Statistiken einer Wise-Session
struct WiseSessionStats: Codable, Identifiable {
    let id: UUID
    let mode: WiseMode
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var averageCoherence: Float
    var peakCoherence: Float
    var averageHRV: Float
    var flowStateMinutes: Int
    var modeTransitions: [WiseModeTransition]

    init(mode: WiseMode) {
        self.id = UUID()
        self.mode = mode
        self.startTime = Date()
        self.endTime = nil
        self.duration = 0
        self.averageCoherence = 0
        self.peakCoherence = 0
        self.averageHRV = 0
        self.flowStateMinutes = 0
        self.modeTransitions = []
    }
}

// MARK: - Wise Mode Manager

/// Zentrale Verwaltung des Wise Mode Systems
@MainActor
class WiseModeManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseModeManager()

    // MARK: - Published State

    @Published var currentMode: WiseMode = .focus
    @Published var wisdomLevel: WisdomLevel = .novice
    @Published var currentConfiguration: WiseModeConfiguration
    @Published var isTransitioning: Bool = false
    @Published var transitionProgress: Float = 0.0
    @Published var currentSessionStats: WiseSessionStats?
    @Published var isActive: Bool = false

    // MARK: - Analytics

    @Published var totalSessions: Int = 0
    @Published var totalMinutes: Int = 0
    @Published var averageCoherence: Float = 0.0
    @Published var streakDays: Int = 0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var transitionTimer: Timer?
    private let transitionDuration: TimeInterval = 2.0
    private let userDefaults = UserDefaults.standard

    // MARK: - Callbacks für Engine-Integration

    var onModeChange: ((WiseMode, WiseModeConfiguration) -> Void)?
    var onWisdomLevelChange: ((WisdomLevel) -> Void)?
    var onTransitionComplete: ((WiseModeTransition) -> Void)?

    // MARK: - Initialization

    private init() {
        self.currentConfiguration = WiseModeConfiguration(mode: .focus)
        loadPersistedState()
        setupBindings()

        print("🧠 WiseModeManager: Initialized")
        print("   Current Mode: \(currentMode.rawValue)")
        print("   Wisdom Level: \(wisdomLevel.displayName)")
    }

    // MARK: - Mode Control

    /// Wechselt zu einem neuen Wise Mode
    func switchMode(to newMode: WiseMode, reason: WiseModeTransition.TransitionReason = .userInitiated) {
        guard newMode != currentMode else { return }
        guard !isTransitioning else { return }

        let transition = WiseModeTransition(
            fromMode: currentMode,
            toMode: newMode,
            timestamp: Date(),
            duration: transitionDuration,
            reason: reason
        )

        isTransitioning = true
        transitionProgress = 0.0

        // Smooth transition animation
        startTransition(to: newMode, transition: transition)
    }

    private func startTransition(to newMode: WiseMode, transition: WiseModeTransition) {
        let startTime = Date()

        transitionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startTime)
                self.transitionProgress = Float(min(elapsed / self.transitionDuration, 1.0))

                if elapsed >= self.transitionDuration {
                    timer.invalidate()
                    self.completeTransition(to: newMode, transition: transition)
                }
            }
        }
    }

    private func completeTransition(to newMode: WiseMode, transition: WiseModeTransition) {
        let oldMode = currentMode
        currentMode = newMode
        currentConfiguration = WiseModeConfiguration(mode: newMode)
        isTransitioning = false
        transitionProgress = 1.0

        // Update session stats
        currentSessionStats?.modeTransitions.append(transition)

        // Notify listeners
        onModeChange?(newMode, currentConfiguration)
        onTransitionComplete?(transition)

        // Persist state
        persistState()

        print("✨ WiseMode: Transitioned from \(oldMode.rawValue) to \(newMode.rawValue)")
    }

    // MARK: - Session Control

    /// Startet eine neue Wise-Session
    func startSession() {
        guard !isActive else { return }

        isActive = true
        currentSessionStats = WiseSessionStats(mode: currentMode)
        totalSessions += 1

        persistState()

        print("🎬 WiseSession: Started (\(currentMode.rawValue))")
    }

    /// Beendet die aktuelle Session
    func endSession() {
        guard isActive, var stats = currentSessionStats else { return }

        stats.endTime = Date()
        stats.duration = Date().timeIntervalSince(stats.startTime)

        // Update totals
        totalMinutes += Int(stats.duration / 60)

        // Update wisdom level
        updateWisdomLevel()

        // Save session stats
        saveSessionStats(stats)

        isActive = false
        currentSessionStats = nil

        persistState()

        print("🏁 WiseSession: Ended (Duration: \(Int(stats.duration / 60)) min)")
    }

    /// Aktualisiert Session-Stats mit Bio-Daten
    func updateBioData(coherence: Float, hrv: Float) {
        guard var stats = currentSessionStats else { return }

        // Update peak coherence
        if coherence > stats.peakCoherence {
            stats.peakCoherence = coherence
        }

        // Running average (simplified)
        let alpha: Float = 0.1
        stats.averageCoherence = stats.averageCoherence * (1 - alpha) + coherence * alpha
        stats.averageHRV = stats.averageHRV * (1 - alpha) + hrv * alpha

        // Count flow state minutes (coherence > 0.7)
        if coherence > 0.7 {
            stats.flowStateMinutes += 1
        }

        currentSessionStats = stats
    }

    // MARK: - Wisdom Level

    private func updateWisdomLevel() {
        let newLevel = calculateWisdomLevel()

        if newLevel != wisdomLevel {
            wisdomLevel = newLevel
            onWisdomLevelChange?(newLevel)

            print("🌟 Wisdom Level Up: \(newLevel.displayName)")
        }
    }

    private func calculateWisdomLevel() -> WisdomLevel {
        for level in WisdomLevel.allCases.reversed() {
            if totalSessions >= level.requiredSessions && averageCoherence >= level.requiredCoherence {
                return level
            }
        }
        return .novice
    }

    // MARK: - Configuration

    /// Aktualisiert die Konfiguration
    func updateConfiguration(_ config: WiseModeConfiguration) {
        currentConfiguration = config
        onModeChange?(currentMode, config)
        persistState()
    }

    /// Setzt Mode-spezifische Parameter
    func setParameter<T>(_ keyPath: WritableKeyPath<WiseModeConfiguration, T>, value: T) {
        currentConfiguration[keyPath: keyPath] = value
        onModeChange?(currentMode, currentConfiguration)
        persistState()
    }

    // MARK: - Persistence

    private func persistState() {
        userDefaults.set(currentMode.rawValue, forKey: "wiseMode.currentMode")
        userDefaults.set(wisdomLevel.rawValue, forKey: "wiseMode.wisdomLevel")
        userDefaults.set(totalSessions, forKey: "wiseMode.totalSessions")
        userDefaults.set(totalMinutes, forKey: "wiseMode.totalMinutes")
        userDefaults.set(averageCoherence, forKey: "wiseMode.averageCoherence")
        userDefaults.set(streakDays, forKey: "wiseMode.streakDays")

        if let configData = try? JSONEncoder().encode(currentConfiguration) {
            userDefaults.set(configData, forKey: "wiseMode.configuration")
        }
    }

    private func loadPersistedState() {
        if let modeRaw = userDefaults.string(forKey: "wiseMode.currentMode"),
           let mode = WiseMode(rawValue: modeRaw) {
            currentMode = mode
            currentConfiguration = WiseModeConfiguration(mode: mode)
        }

        if let levelRaw = userDefaults.integer(forKey: "wiseMode.wisdomLevel") as Int?,
           let level = WisdomLevel(rawValue: levelRaw) {
            wisdomLevel = level
        }

        totalSessions = userDefaults.integer(forKey: "wiseMode.totalSessions")
        totalMinutes = userDefaults.integer(forKey: "wiseMode.totalMinutes")
        averageCoherence = userDefaults.float(forKey: "wiseMode.averageCoherence")
        streakDays = userDefaults.integer(forKey: "wiseMode.streakDays")

        if let configData = userDefaults.data(forKey: "wiseMode.configuration"),
           let config = try? JSONDecoder().decode(WiseModeConfiguration.self, from: configData) {
            currentConfiguration = config
        }
    }

    private func saveSessionStats(_ stats: WiseSessionStats) {
        // Load existing stats
        var allStats = loadAllSessionStats()
        allStats.append(stats)

        // Keep only last 100 sessions
        if allStats.count > 100 {
            allStats = Array(allStats.suffix(100))
        }

        if let data = try? JSONEncoder().encode(allStats) {
            userDefaults.set(data, forKey: "wiseMode.sessionStats")
        }
    }

    func loadAllSessionStats() -> [WiseSessionStats] {
        guard let data = userDefaults.data(forKey: "wiseMode.sessionStats"),
              let stats = try? JSONDecoder().decode([WiseSessionStats].self, from: data) else {
            return []
        }
        return stats
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Auto-update streak
        checkAndUpdateStreak()
    }

    private func checkAndUpdateStreak() {
        let lastSession = userDefaults.object(forKey: "wiseMode.lastSessionDate") as? Date
        let today = Calendar.current.startOfDay(for: Date())

        if let last = lastSession {
            let lastDay = Calendar.current.startOfDay(for: last)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                streakDays += 1
            } else if daysDiff > 1 {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }

        userDefaults.set(Date(), forKey: "wiseMode.lastSessionDate")
    }

    // MARK: - Quick Actions

    /// Schnellwechsel zu Focus-Mode
    func quickFocus() {
        switchMode(to: .focus, reason: .userInitiated)
    }

    /// Schnellwechsel zu Flow-Mode
    func quickFlow() {
        switchMode(to: .flow, reason: .userInitiated)
    }

    /// Schnellwechsel zu Meditation
    func quickMeditation() {
        switchMode(to: .meditation, reason: .userInitiated)
    }

    /// Schnellwechsel zu Sleep
    func quickSleep() {
        switchMode(to: .sleep, reason: .userInitiated)
    }
}

// MARK: - Wise Mode View Modifier

extension View {
    /// Wendet Wise Mode Styling auf eine View an
    func wiseModeStyle(_ mode: WiseMode) -> some View {
        self
            .foregroundColor(mode.color)
            .animation(.easeInOut(duration: 0.3), value: mode)
    }
}
