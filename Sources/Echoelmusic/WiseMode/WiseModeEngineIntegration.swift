import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Wise Mode Engine Integration
/// Verbindet WiseMode mit RecordingEngine, CollaborationEngine und AccessibilityManager
/// Qualitäts-Presets, Group Sync und Mode-spezifische Accessibility

// MARK: - RecordingEngine Integration

/// Qualitäts-Presets für RecordingEngine basierend auf WiseMode
struct WiseRecordingPreset: Codable, Identifiable {
    let id: UUID
    let mode: WiseMode
    let name: String
    var sampleRate: Double
    var bitDepth: Int
    var channelCount: Int
    var retrospectiveBufferDuration: TimeInterval
    var autoNormalize: Bool
    var noiseReduction: NoiseReductionLevel
    var compressionPreset: CompressionPreset

    init(mode: WiseMode) {
        self.id = UUID()
        self.mode = mode
        self.name = "\(mode.rawValue) Recording Preset"

        // Mode-spezifische Defaults
        switch mode {
        case .focus:
            self.sampleRate = 48000
            self.bitDepth = 24
            self.channelCount = 2
            self.retrospectiveBufferDuration = 30
            self.autoNormalize = true
            self.noiseReduction = .medium
            self.compressionPreset = .voice

        case .flow:
            self.sampleRate = 96000
            self.bitDepth = 24
            self.channelCount = 2
            self.retrospectiveBufferDuration = 60
            self.autoNormalize = false
            self.noiseReduction = .light
            self.compressionPreset = .music

        case .healing:
            self.sampleRate = 96000
            self.bitDepth = 32
            self.channelCount = 2
            self.retrospectiveBufferDuration = 120
            self.autoNormalize = false
            self.noiseReduction = .off
            self.compressionPreset = .healing

        case .meditation:
            self.sampleRate = 48000
            self.bitDepth = 24
            self.channelCount = 2
            self.retrospectiveBufferDuration = 90
            self.autoNormalize = true
            self.noiseReduction = .light
            self.compressionPreset = .ambient

        case .energize:
            self.sampleRate = 48000
            self.bitDepth = 16
            self.channelCount = 2
            self.retrospectiveBufferDuration = 30
            self.autoNormalize = true
            self.noiseReduction = .medium
            self.compressionPreset = .energy

        case .sleep:
            self.sampleRate = 44100
            self.bitDepth = 16
            self.channelCount = 2
            self.retrospectiveBufferDuration = 60
            self.autoNormalize = true
            self.noiseReduction = .heavy
            self.compressionPreset = .sleep

        case .social:
            self.sampleRate = 48000
            self.bitDepth = 24
            self.channelCount = 2
            self.retrospectiveBufferDuration = 45
            self.autoNormalize = true
            self.noiseReduction = .medium
            self.compressionPreset = .voice

        case .custom:
            self.sampleRate = 48000
            self.bitDepth = 24
            self.channelCount = 2
            self.retrospectiveBufferDuration = 60
            self.autoNormalize = true
            self.noiseReduction = .medium
            self.compressionPreset = .balanced
        }
    }
}

enum NoiseReductionLevel: String, Codable, CaseIterable {
    case off = "Off"
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"

    var strength: Float {
        switch self {
        case .off: return 0.0
        case .light: return 0.3
        case .medium: return 0.6
        case .heavy: return 0.9
        }
    }
}

enum CompressionPreset: String, Codable, CaseIterable {
    case off = "Off"
    case voice = "Voice"
    case music = "Music"
    case ambient = "Ambient"
    case healing = "Healing"
    case energy = "Energy"
    case sleep = "Sleep"
    case balanced = "Balanced"

    var ratio: Float {
        switch self {
        case .off: return 1.0
        case .voice: return 4.0
        case .music: return 2.0
        case .ambient: return 1.5
        case .healing: return 1.2
        case .energy: return 3.0
        case .sleep: return 1.3
        case .balanced: return 2.5
        }
    }

    var threshold: Float {
        switch self {
        case .off: return 0.0
        case .voice: return -20.0
        case .music: return -15.0
        case .ambient: return -25.0
        case .healing: return -30.0
        case .energy: return -12.0
        case .sleep: return -28.0
        case .balanced: return -18.0
        }
    }
}

/// RecordingEngine Extension für WiseMode
extension RecordingEngine {

    /// Wendet WiseMode-Preset auf Recording an
    func applyWisePreset(_ mode: WiseMode) {
        let preset = WiseRecordingPreset(mode: mode)
        applyRecordingPreset(preset)
    }

    /// Wendet Recording-Preset an
    func applyRecordingPreset(_ preset: WiseRecordingPreset) {
        // Configure retrospective buffer
        if isRetrospectiveCaptureEnabled {
            enableRetrospectiveCapture(
                sampleRate: preset.sampleRate,
                channels: preset.channelCount
            )
        }

        print("🎙️ Applied WiseRecordingPreset: \(preset.name)")
        print("   Sample Rate: \(preset.sampleRate) Hz")
        print("   Bit Depth: \(preset.bitDepth)")
        print("   Noise Reduction: \(preset.noiseReduction.rawValue)")
        print("   Compression: \(preset.compressionPreset.rawValue)")
    }
}

// MARK: - CollaborationEngine Integration

/// Group Session Sync für WiseMode
struct WiseGroupSession: Codable, Identifiable {
    let id: UUID
    var hostMode: WiseMode
    var participantModes: [UUID: WiseMode]
    var syncEnabled: Bool
    var coherenceTarget: Float
    var flowLeaderID: UUID?

    init(hostMode: WiseMode) {
        self.id = UUID()
        self.hostMode = hostMode
        self.participantModes = [:]
        self.syncEnabled = true
        self.coherenceTarget = 0.7
        self.flowLeaderID = nil
    }
}

/// Group Coherence State
struct GroupCoherenceState: Codable {
    var averageCoherence: Float
    var coherenceSpread: Float // Standardabweichung
    var syncLevel: Float // 0-1 wie synchron die Gruppe ist
    var flowLeaderID: UUID?
    var dominantMode: WiseMode

    init() {
        self.averageCoherence = 0
        self.coherenceSpread = 0
        self.syncLevel = 0
        self.flowLeaderID = nil
        self.dominantMode = .focus
    }
}

/// Wise Collaboration Manager
@MainActor
class WiseCollaborationManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseCollaborationManager()

    // MARK: - Published State

    @Published var currentGroupSession: WiseGroupSession?
    @Published var groupCoherence: GroupCoherenceState = GroupCoherenceState()
    @Published var isSyncEnabled: Bool = true
    @Published var participantWisdomLevels: [UUID: WisdomLevel] = [:]

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private weak var collaborationEngine: CollaborationEngine?
    private weak var wiseModeManager: WiseModeManager?

    // MARK: - Initialization

    private init() {
        wiseModeManager = WiseModeManager.shared

        // Listen for mode changes
        setupModeChangeListener()

        print("👥 WiseCollaborationManager: Initialized")
    }

    // MARK: - Connection

    func connect(to collaborationEngine: CollaborationEngine) {
        self.collaborationEngine = collaborationEngine

        print("🔗 WiseCollaborationManager: Connected to CollaborationEngine")
    }

    // MARK: - Group Session

    /// Erstellt eine neue Gruppen-Session mit WiseMode
    func createGroupSession(mode: WiseMode) {
        let session = WiseGroupSession(hostMode: mode)
        currentGroupSession = session

        // Synchronize mode with collaboration
        broadcastModeChange(mode)

        print("👥 Created WiseGroupSession: \(mode.rawValue)")
    }

    /// Tritt einer bestehenden Session bei
    func joinGroupSession(sessionID: UUID, participantID: UUID) {
        if var session = currentGroupSession {
            session.participantModes[participantID] = wiseModeManager?.currentMode ?? .focus
            currentGroupSession = session
        }
    }

    /// Verlässt die aktuelle Session
    func leaveGroupSession() {
        currentGroupSession = nil
        groupCoherence = GroupCoherenceState()
    }

    // MARK: - Mode Synchronization

    /// Synchronisiert Mode mit allen Teilnehmern
    func syncModeWithGroup(_ mode: WiseMode) {
        guard isSyncEnabled, var session = currentGroupSession else { return }

        session.hostMode = mode
        currentGroupSession = session

        broadcastModeChange(mode)

        print("📡 Synced mode with group: \(mode.rawValue)")
    }

    private func broadcastModeChange(_ mode: WiseMode) {
        let data: [String: Any] = [
            "type": "wise_mode_change",
            "mode": mode.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            collaborationEngine?.sendMIDIData(jsonData)
        }
    }

    /// Empfängt Mode-Änderung von anderem Teilnehmer
    func receiveModeChange(from participantID: UUID, mode: WiseMode) {
        guard var session = currentGroupSession else { return }

        session.participantModes[participantID] = mode
        currentGroupSession = session

        // Update dominant mode
        updateDominantMode()

        print("📥 Received mode change from \(participantID): \(mode.rawValue)")
    }

    // MARK: - Group Coherence

    /// Aktualisiert Gruppen-Kohärenz
    func updateGroupCoherence(participantData: [(id: UUID, coherence: Float, hrv: Float)]) {
        guard !participantData.isEmpty else { return }

        let coherences = participantData.map { $0.coherence }
        let count = Float(coherences.count)

        // Durchschnitt
        let average = coherences.reduce(0, +) / count

        // Standardabweichung
        let variance = coherences.map { pow($0 - average, 2) }.reduce(0, +) / count
        let spread = sqrt(variance)

        // Sync Level (wie ähnlich sind die Werte)
        let maxSpread: Float = 0.5
        let syncLevel = max(0, 1 - (spread / maxSpread))

        // Flow Leader (höchste Kohärenz)
        let leader = participantData.max(by: { $0.coherence < $1.coherence })?.id

        groupCoherence = GroupCoherenceState(
            averageCoherence: average,
            coherenceSpread: spread,
            syncLevel: syncLevel,
            flowLeaderID: leader,
            dominantMode: currentGroupSession?.hostMode ?? .focus
        )

        // Broadcast to group
        broadcastGroupCoherence()
    }

    private func broadcastGroupCoherence() {
        let data: [String: Any] = [
            "type": "group_coherence",
            "average": groupCoherence.averageCoherence,
            "spread": groupCoherence.coherenceSpread,
            "syncLevel": groupCoherence.syncLevel
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            collaborationEngine?.sendMIDIData(jsonData)
        }
    }

    private func updateDominantMode() {
        guard let session = currentGroupSession else { return }

        var modeCounts: [WiseMode: Int] = [:]
        modeCounts[session.hostMode] = 1

        for mode in session.participantModes.values {
            modeCounts[mode, default: 0] += 1
        }

        if let dominant = modeCounts.max(by: { $0.value < $1.value })?.key {
            groupCoherence.dominantMode = dominant
        }
    }

    // MARK: - Mode Change Listener

    private func setupModeChangeListener() {
        wiseModeManager?.$currentMode
            .sink { [weak self] mode in
                if self?.isSyncEnabled == true {
                    self?.syncModeWithGroup(mode)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - AccessibilityManager Integration

/// Mode-spezifische Accessibility-Konfiguration
struct WiseAccessibilityConfig: Codable {
    let mode: WiseMode
    var voiceGuidanceEnabled: Bool
    var hapticIntensity: Float
    var visualCuesEnabled: Bool
    var soundCuesEnabled: Bool
    var reducedMotion: Bool
    var highContrast: Bool
    var largerText: Bool
    var autoRead: Bool

    init(mode: WiseMode) {
        self.mode = mode

        switch mode {
        case .focus:
            self.voiceGuidanceEnabled = false // Minimize interruptions
            self.hapticIntensity = 0.3
            self.visualCuesEnabled = true
            self.soundCuesEnabled = false
            self.reducedMotion = true
            self.highContrast = false
            self.largerText = false
            self.autoRead = false

        case .flow:
            self.voiceGuidanceEnabled = false
            self.hapticIntensity = 0.5
            self.visualCuesEnabled = true
            self.soundCuesEnabled = true
            self.reducedMotion = false
            self.highContrast = false
            self.largerText = false
            self.autoRead = false

        case .healing:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.3
            self.visualCuesEnabled = true
            self.soundCuesEnabled = true
            self.reducedMotion = true
            self.highContrast = false
            self.largerText = true
            self.autoRead = true

        case .meditation:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.2
            self.visualCuesEnabled = false // Minimize visual distraction
            self.soundCuesEnabled = true
            self.reducedMotion = true
            self.highContrast = false
            self.largerText = false
            self.autoRead = true

        case .energize:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.8
            self.visualCuesEnabled = true
            self.soundCuesEnabled = true
            self.reducedMotion = false
            self.highContrast = true
            self.largerText = false
            self.autoRead = false

        case .sleep:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.1
            self.visualCuesEnabled = false
            self.soundCuesEnabled = true
            self.reducedMotion = true
            self.highContrast = false
            self.largerText = true
            self.autoRead = true

        case .social:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.5
            self.visualCuesEnabled = true
            self.soundCuesEnabled = true
            self.reducedMotion = false
            self.highContrast = false
            self.largerText = false
            self.autoRead = false

        case .custom:
            self.voiceGuidanceEnabled = true
            self.hapticIntensity = 0.5
            self.visualCuesEnabled = true
            self.soundCuesEnabled = true
            self.reducedMotion = false
            self.highContrast = false
            self.largerText = false
            self.autoRead = false
        }
    }
}

/// Wise Accessibility Manager
@MainActor
class WiseAccessibilityManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseAccessibilityManager()

    // MARK: - Published State

    @Published var currentConfig: WiseAccessibilityConfig
    @Published var isWiseAccessibilityEnabled: Bool = true
    @Published var announceModeLchanges: Bool = true
    @Published var modeTransitionHaptics: Bool = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private weak var accessibilityManager: AccessibilityManager?

    // MARK: - Initialization

    private init() {
        self.currentConfig = WiseAccessibilityConfig(mode: .focus)
        setupModeChangeListener()

        print("♿️ WiseAccessibilityManager: Initialized")
    }

    // MARK: - Connection

    func connect(to accessibilityManager: AccessibilityManager) {
        self.accessibilityManager = accessibilityManager

        print("🔗 WiseAccessibilityManager: Connected to AccessibilityManager")
    }

    // MARK: - Mode Changes

    func handleModeChange(to mode: WiseMode) {
        let oldConfig = currentConfig
        currentConfig = WiseAccessibilityConfig(mode: mode)

        // Announce change if enabled
        if announceModeLchanges {
            announceMode(mode)
        }

        // Haptic feedback for transition
        if modeTransitionHaptics {
            provideModeTransitionHaptic(from: oldConfig.mode, to: mode)
        }

        // Apply accessibility settings
        applyAccessibilityConfig(currentConfig)

        print("♿️ Updated accessibility for mode: \(mode.rawValue)")
    }

    // MARK: - Announcements

    private func announceMode(_ mode: WiseMode) {
        let message: String

        switch mode {
        case .focus:
            message = "Focus mode aktiviert. Optimiert für Konzentration."
        case .flow:
            message = "Flow mode aktiviert. Bereit für kreative Arbeit."
        case .healing:
            message = "Healing mode aktiviert. Therapeutische Frequenzen aktiv."
        case .meditation:
            message = "Meditation mode aktiviert. Finde deine innere Ruhe."
        case .energize:
            message = "Energize mode aktiviert. Zeit für Energie und Motivation."
        case .sleep:
            message = "Sleep mode aktiviert. Bereite dich auf erholsamen Schlaf vor."
        case .social:
            message = "Social mode aktiviert. Verbinde dich mit anderen."
        case .custom:
            message = "Custom mode aktiviert. Deine persönlichen Einstellungen."
        }

        accessibilityManager?.announce(message, priority: .normal)
    }

    // MARK: - Haptic Feedback

    private func provideModeTransitionHaptic(from: WiseMode, to: WiseMode) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: CGFloat(currentConfig.hapticIntensity))

        // Additional pattern based on mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let style: UIImpactFeedbackGenerator.FeedbackStyle

            switch to {
            case .focus: style = .rigid
            case .flow: style = .soft
            case .healing: style = .light
            case .meditation: style = .soft
            case .energize: style = .heavy
            case .sleep: style = .light
            case .social: style = .medium
            case .custom: style = .medium
            }

            let secondGenerator = UIImpactFeedbackGenerator(style: style)
            secondGenerator.impactOccurred()
        }
        #endif
    }

    /// Bietet Haptic Feedback für Bio-Events
    func provideBioFeedback(coherence: Float, threshold: Float = 0.7) {
        guard currentConfig.hapticIntensity > 0 else { return }

        #if os(iOS)
        if coherence >= threshold {
            // Erfolgs-Haptic bei hoher Kohärenz
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else if coherence >= threshold * 0.8 {
            // Leichtes Feedback wenn nahe am Ziel
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: CGFloat(currentConfig.hapticIntensity * 0.5))
        }
        #endif
    }

    // MARK: - Apply Config

    private func applyAccessibilityConfig(_ config: WiseAccessibilityConfig) {
        guard let manager = accessibilityManager else { return }

        // Update haptic level
        if config.hapticIntensity == 0 {
            manager.hapticFeedbackLevel = .off
        } else if config.hapticIntensity < 0.4 {
            manager.hapticFeedbackLevel = .light
        } else if config.hapticIntensity < 0.7 {
            manager.hapticFeedbackLevel = .normal
        } else {
            manager.hapticFeedbackLevel = .strong
        }

        // Update animation speed based on reduced motion
        if config.reducedMotion {
            manager.animationSpeed = .off
        } else {
            manager.animationSpeed = .normal
        }

        // Audio descriptions for voice guidance
        manager.audioDescriptionsEnabled = config.voiceGuidanceEnabled
    }

    // MARK: - Mode Change Listener

    private func setupModeChangeListener() {
        WiseModeManager.shared.$currentMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.handleModeChange(to: mode)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Convenience Extensions

extension WiseModeManager {

    /// Registriert Engine-Callbacks
    func setupEngineIntegration(
        recordingEngine: RecordingEngine?,
        collaborationEngine: CollaborationEngine?,
        accessibilityManager: AccessibilityManager?
    ) {
        // Recording Engine Integration
        onModeChange = { [weak recordingEngine] mode, config in
            recordingEngine?.applyWisePreset(mode)
        }

        // Collaboration Integration
        if let collab = collaborationEngine {
            WiseCollaborationManager.shared.connect(to: collab)
        }

        // Accessibility Integration
        if let access = accessibilityManager {
            WiseAccessibilityManager.shared.connect(to: access)
        }

        print("🔗 WiseModeManager: Engine integration complete")
    }
}
