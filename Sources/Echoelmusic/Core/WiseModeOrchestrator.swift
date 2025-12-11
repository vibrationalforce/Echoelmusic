import Foundation
import Combine
import os.log

/// WiseModeOrchestrator - Intelligent System Coordination Layer
///
/// "Wise Mode" represents the highest level of system intelligence where all
/// subsystems work in harmony based on the user's biometric and creative state.
///
/// Features:
/// - Adaptive parameter optimization based on HRV coherence
/// - Intelligent conflict resolution between input modalities
/// - Predictive preset suggestions based on usage patterns
/// - Automatic mode switching based on bio-state detection
/// - Energy-efficient operation with smart duty cycling
///
/// Integration:
/// - UnifiedControlHub: Receives orchestration commands
/// - EchoelUniversalCore: Quantum field synchronization
/// - HealthKitManager: Bio-state monitoring
/// - All mappers: Coordinated parameter updates
@MainActor
public final class WiseModeOrchestrator: ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic", category: "WiseMode")

    // MARK: - Singleton

    public static let shared = WiseModeOrchestrator()

    // MARK: - Published State

    /// Whether Wise Mode is active
    @Published public private(set) var isActive: Bool = false

    /// Current wisdom level (0.0 - 1.0) based on system coherence
    @Published public private(set) var wisdomLevel: Float = 0.0

    /// Current adaptive mode
    @Published public private(set) var currentMode: WiseMode = .balanced

    /// System health score (0-100)
    @Published public private(set) var systemHealth: Int = 100

    /// Active optimizations
    @Published public private(set) var activeOptimizations: Set<Optimization> = []

    /// Suggested actions for the user
    @Published public private(set) var suggestions: [WiseSuggestion] = []

    // MARK: - Wise Modes

    public enum WiseMode: String, CaseIterable {
        case performance = "Performance"       // Maximum responsiveness
        case balanced = "Balanced"             // Default intelligent balance
        case healing = "Healing"               // Optimized for bio-coherence
        case creative = "Creative"             // Maximum creative freedom
        case meditative = "Meditative"         // Deep relaxation focus
        case energizing = "Energizing"         // High-energy activation

        var description: String {
            switch self {
            case .performance: return "Ultra-low latency, all sensors active"
            case .balanced: return "Intelligent balance of features and efficiency"
            case .healing: return "Bio-coherence optimized, healing frequencies"
            case .creative: return "Maximum creative expression, all modalities"
            case .meditative: return "Calm visuals, slow transitions, binaural focus"
            case .energizing: return "Dynamic responses, bright visuals, active tracking"
            }
        }

        var targetCoherence: Float {
            switch self {
            case .performance: return 0.5
            case .balanced: return 0.6
            case .healing: return 0.9
            case .creative: return 0.7
            case .meditative: return 0.95
            case .energizing: return 0.4
            }
        }

        var updateFrequency: Double {
            switch self {
            case .performance: return 120.0  // 120 Hz
            case .balanced: return 60.0      // 60 Hz
            case .healing: return 30.0       // 30 Hz (smoother)
            case .creative: return 60.0      // 60 Hz
            case .meditative: return 20.0    // 20 Hz (very smooth)
            case .energizing: return 90.0    // 90 Hz
            }
        }
    }

    // MARK: - Optimizations

    public enum Optimization: String, CaseIterable {
        case adaptiveLatency = "Adaptive Latency"
        case bioCoherenceSync = "Bio-Coherence Sync"
        case predictiveLoading = "Predictive Loading"
        case energySaving = "Energy Saving"
        case spatialOptimization = "Spatial Optimization"
        case visualSmoothing = "Visual Smoothing"
        case gestureCalibration = "Gesture Calibration"
    }

    // MARK: - Suggestions

    public struct WiseSuggestion: Identifiable {
        public let id = UUID()
        public let type: SuggestionType
        public let message: String
        public let action: (() -> Void)?
        public let priority: Priority

        public enum SuggestionType {
            case modeChange
            case parameterTweak
            case healthAlert
            case performanceTip
            case creativeSuggestion
        }

        public enum Priority: Int, Comparable {
            case low = 1
            case medium = 2
            case high = 3

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - Dependencies

    private weak var controlHub: UnifiedControlHub?
    private weak var healthKitManager: HealthKitManager?
    private weak var audioEngine: AudioEngine?

    // MARK: - State Tracking

    private var bioStateHistory: [BioStateSnapshot] = []
    private var modeTransitionHistory: [(from: WiseMode, to: WiseMode, timestamp: Date)] = []
    private var cancellables = Set<AnyCancellable>()
    private var wisdomUpdateTimer: Timer?

    private struct BioStateSnapshot {
        let timestamp: Date
        let hrvCoherence: Double
        let heartRate: Double
        let activeInputs: Int
    }

    // MARK: - Initialization

    private init() {
        logger.info("WiseModeOrchestrator initialized")
    }

    // MARK: - Configuration

    /// Configure with system dependencies
    public func configure(
        controlHub: UnifiedControlHub,
        healthKitManager: HealthKitManager?,
        audioEngine: AudioEngine?
    ) {
        self.controlHub = controlHub
        self.healthKitManager = healthKitManager
        self.audioEngine = audioEngine

        setupBioObservation()

        logger.info("WiseModeOrchestrator configured with dependencies")
    }

    // MARK: - Activation

    /// Activate Wise Mode
    public func activate() {
        guard !isActive else { return }

        isActive = true
        startWisdomLoop()
        applyCurrentMode()

        logger.info("Wise Mode ACTIVATED - Mode: \(currentMode.rawValue, privacy: .public)")
    }

    /// Deactivate Wise Mode
    public func deactivate() {
        guard isActive else { return }

        isActive = false
        stopWisdomLoop()
        activeOptimizations.removeAll()

        logger.info("Wise Mode deactivated")
    }

    /// Set the current wise mode
    public func setMode(_ mode: WiseMode) {
        let previousMode = currentMode
        currentMode = mode

        modeTransitionHistory.append((from: previousMode, to: mode, timestamp: Date()))

        if isActive {
            applyCurrentMode()
        }

        logger.info("Wise Mode changed: \(previousMode.rawValue, privacy: .public) → \(mode.rawValue, privacy: .public)")
    }

    // MARK: - Wisdom Loop

    private func startWisdomLoop() {
        stopWisdomLoop()

        wisdomUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWisdom()
            }
        }
    }

    private func stopWisdomLoop() {
        wisdomUpdateTimer?.invalidate()
        wisdomUpdateTimer = nil
    }

    private func updateWisdom() {
        guard isActive else { return }

        // Calculate wisdom level from multiple factors
        calculateWisdomLevel()

        // Record bio state
        recordBioState()

        // Analyze patterns and generate suggestions
        analyzePatterns()

        // Auto-adjust mode if needed
        autoAdjustMode()

        // Update system health
        updateSystemHealth()
    }

    // MARK: - Wisdom Calculation

    private func calculateWisdomLevel() {
        var wisdom: Float = 0.0

        // Factor 1: Bio-coherence (40% weight)
        if let healthKit = healthKitManager {
            let coherenceNormalized = Float(healthKit.hrvCoherence) / 100.0
            wisdom += coherenceNormalized * 0.4
        } else {
            wisdom += 0.2  // Default if no bio data
        }

        // Factor 2: System stability (30% weight)
        let stabilityScore = calculateStabilityScore()
        wisdom += stabilityScore * 0.3

        // Factor 3: Mode alignment (30% weight)
        let alignmentScore = calculateModeAlignment()
        wisdom += alignmentScore * 0.3

        wisdomLevel = min(1.0, max(0.0, wisdom))
    }

    private func calculateStabilityScore() -> Float {
        // Check recent bio state variance
        guard bioStateHistory.count >= 5 else { return 0.5 }

        let recentStates = bioStateHistory.suffix(10)
        let hrvValues = recentStates.map { Float($0.hrvCoherence) }

        // Calculate variance
        let mean = hrvValues.reduce(0, +) / Float(hrvValues.count)
        let variance = hrvValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(hrvValues.count)

        // Lower variance = higher stability (normalize to 0-1)
        let stabilityScore = max(0, 1.0 - sqrt(variance) / 50.0)
        return stabilityScore
    }

    private func calculateModeAlignment() -> Float {
        guard let healthKit = healthKitManager else { return 0.5 }

        let currentCoherence = Float(healthKit.hrvCoherence) / 100.0
        let targetCoherence = currentMode.targetCoherence

        // How close are we to the target?
        let distance = abs(currentCoherence - targetCoherence)
        return max(0, 1.0 - distance * 2.0)
    }

    // MARK: - Mode Application

    private func applyCurrentMode() {
        // Apply mode-specific optimizations
        activeOptimizations.removeAll()

        switch currentMode {
        case .performance:
            activeOptimizations.insert(.adaptiveLatency)
            activeOptimizations.insert(.gestureCalibration)

        case .balanced:
            activeOptimizations.insert(.adaptiveLatency)
            activeOptimizations.insert(.bioCoherenceSync)
            activeOptimizations.insert(.energySaving)

        case .healing:
            activeOptimizations.insert(.bioCoherenceSync)
            activeOptimizations.insert(.visualSmoothing)
            activeOptimizations.insert(.spatialOptimization)

        case .creative:
            activeOptimizations.insert(.adaptiveLatency)
            activeOptimizations.insert(.gestureCalibration)
            activeOptimizations.insert(.predictiveLoading)

        case .meditative:
            activeOptimizations.insert(.bioCoherenceSync)
            activeOptimizations.insert(.visualSmoothing)
            activeOptimizations.insert(.energySaving)

        case .energizing:
            activeOptimizations.insert(.adaptiveLatency)
            activeOptimizations.insert(.spatialOptimization)
        }

        // Apply to audio engine
        applyAudioSettings()

        // Apply to visuals
        applyVisualSettings()

        logger.debug("Applied mode settings: \(self.activeOptimizations.map { $0.rawValue }.joined(separator: ", "), privacy: .public)")
    }

    private func applyAudioSettings() {
        guard let audio = audioEngine else { return }

        switch currentMode {
        case .healing, .meditative:
            // Enable binaural beats for healing/meditative modes
            if !audio.binauralBeatsEnabled {
                audio.toggleBinauralBeats()
            }
            audio.setBrainwaveState(currentMode == .meditative ? .theta : .alpha)
            audio.setBinauralAmplitude(0.3)

        case .energizing:
            if !audio.binauralBeatsEnabled {
                audio.toggleBinauralBeats()
            }
            audio.setBrainwaveState(.beta)
            audio.setBinauralAmplitude(0.2)

        case .creative:
            if !audio.binauralBeatsEnabled {
                audio.toggleBinauralBeats()
            }
            audio.setBrainwaveState(.alpha)
            audio.setBinauralAmplitude(0.15)

        default:
            // Disable for performance/balanced
            if audio.binauralBeatsEnabled {
                audio.toggleBinauralBeats()
            }
        }
    }

    private func applyVisualSettings() {
        // Visual settings would be applied to MIDIToVisualMapper
        // This is handled through the control hub
    }

    // MARK: - Bio Observation

    private func setupBioObservation() {
        guard let healthKit = healthKitManager else { return }

        healthKit.$hrvCoherence
            .sink { [weak self] coherence in
                self?.handleCoherenceChange(coherence)
            }
            .store(in: &cancellables)
    }

    private func handleCoherenceChange(_ coherence: Double) {
        guard isActive else { return }

        // Significant coherence changes might trigger mode suggestions
        if coherence > 80 && currentMode != .meditative && currentMode != .healing {
            addSuggestion(
                type: .modeChange,
                message: "High coherence detected. Switch to Healing mode for optimal bio-sync?",
                priority: .medium
            )
        } else if coherence < 30 && currentMode == .meditative {
            addSuggestion(
                type: .modeChange,
                message: "Coherence dropped. Try Balanced mode for better responsiveness?",
                priority: .medium
            )
        }
    }

    private func recordBioState() {
        guard let healthKit = healthKitManager else { return }

        let snapshot = BioStateSnapshot(
            timestamp: Date(),
            hrvCoherence: healthKit.hrvCoherence,
            heartRate: healthKit.heartRate,
            activeInputs: 0  // Would get from control hub
        )

        bioStateHistory.append(snapshot)

        // Keep only last 5 minutes of history
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        bioStateHistory.removeAll { $0.timestamp < fiveMinutesAgo }
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns() {
        guard bioStateHistory.count >= 10 else { return }

        // Check for trending coherence
        let recentCoherence = bioStateHistory.suffix(5).map { $0.hrvCoherence }
        let olderCoherence = bioStateHistory.prefix(5).map { $0.hrvCoherence }

        let recentAvg = recentCoherence.reduce(0, +) / Double(recentCoherence.count)
        let olderAvg = olderCoherence.reduce(0, +) / Double(olderCoherence.count)

        if recentAvg > olderAvg + 15 {
            addSuggestion(
                type: .performanceTip,
                message: "Great progress! Your coherence is improving steadily.",
                priority: .low
            )
        }
    }

    private func autoAdjustMode() {
        guard isActive else { return }
        guard let healthKit = healthKitManager else { return }

        // Only auto-adjust in balanced mode
        guard currentMode == .balanced else { return }

        let coherence = healthKit.hrvCoherence

        // Very high coherence - suggest meditative
        if coherence > 85 && wisdomLevel > 0.8 {
            addSuggestion(
                type: .modeChange,
                message: "You're in a deep coherent state. Meditative mode recommended.",
                priority: .high
            )
        }
    }

    // MARK: - System Health

    private func updateSystemHealth() {
        var health = 100

        // Deduct for issues
        if wisdomLevel < 0.3 {
            health -= 20
        }

        if bioStateHistory.isEmpty {
            health -= 10  // No bio data
        }

        systemHealth = max(0, health)
    }

    // MARK: - Suggestions

    private func addSuggestion(type: WiseSuggestion.SuggestionType, message: String, priority: WiseSuggestion.Priority, action: (() -> Void)? = nil) {
        // Avoid duplicate suggestions
        guard !suggestions.contains(where: { $0.message == message }) else { return }

        let suggestion = WiseSuggestion(type: type, message: message, action: action, priority: priority)
        suggestions.append(suggestion)

        // Keep only top 5 suggestions
        suggestions.sort { $0.priority > $1.priority }
        if suggestions.count > 5 {
            suggestions = Array(suggestions.prefix(5))
        }
    }

    public func dismissSuggestion(_ suggestion: WiseSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    public func clearSuggestions() {
        suggestions.removeAll()
    }

    // MARK: - Status

    public var statusSummary: String {
        """
        Wise Mode: \(isActive ? "ACTIVE" : "Inactive")
        Current Mode: \(currentMode.rawValue)
        Wisdom Level: \(Int(wisdomLevel * 100))%
        System Health: \(systemHealth)%
        Active Optimizations: \(activeOptimizations.count)
        Bio History: \(bioStateHistory.count) samples
        Suggestions: \(suggestions.count)
        """
    }
}

// MARK: - SwiftUI Preview Support

extension WiseModeOrchestrator {

    /// Get a preview instance with mock data
    static var preview: WiseModeOrchestrator {
        let orchestrator = WiseModeOrchestrator.shared
        orchestrator.wisdomLevel = 0.75
        orchestrator.systemHealth = 92
        orchestrator.activeOptimizations = [.bioCoherenceSync, .visualSmoothing]
        return orchestrator
    }
}
