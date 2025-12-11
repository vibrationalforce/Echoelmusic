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

    // MARK: - Transition State

    /// Whether a mode transition is in progress
    @Published public private(set) var isTransitioning: Bool = false

    /// Current transition progress (0.0 - 1.0)
    @Published public private(set) var transitionProgress: Float = 0.0

    /// Source mode during transition
    @Published public private(set) var transitionSourceMode: WiseMode?

    // MARK: - Circadian State

    /// Current time of day period
    @Published public private(set) var currentCircadianPhase: CircadianPhase = .day

    /// Recommended mode based on circadian rhythm
    @Published public private(set) var circadianRecommendedMode: WiseMode = .balanced

    // MARK: - Group Session

    /// Whether group mode is active
    @Published public private(set) var isGroupSessionActive: Bool = false

    /// Number of connected participants
    @Published public private(set) var groupParticipantCount: Int = 0

    /// Group coherence average
    @Published public private(set) var groupCoherenceAverage: Float = 0.0

    // MARK: - Prediction State

    /// Predicted optimal mode for next hour
    @Published public private(set) var predictedNextMode: WiseMode?

    /// Prediction confidence (0.0 - 1.0)
    @Published public private(set) var predictionConfidence: Float = 0.0

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
        case circadianAlignment = "Circadian Alignment"
        case groupSync = "Group Synchronization"
        case predictiveMode = "Predictive Mode Selection"
    }

    // MARK: - Circadian Phases

    public enum CircadianPhase: String, CaseIterable {
        case earlyMorning = "Early Morning"   // 5:00 - 8:00
        case morning = "Morning"               // 8:00 - 12:00
        case afternoon = "Afternoon"           // 12:00 - 17:00
        case evening = "Evening"               // 17:00 - 21:00
        case night = "Night"                   // 21:00 - 0:00
        case lateNight = "Late Night"          // 0:00 - 5:00

        var recommendedMode: WiseMode {
            switch self {
            case .earlyMorning: return .balanced      // Waking up
            case .morning: return .energizing         // Peak alertness
            case .afternoon: return .creative         // Creative window
            case .evening: return .healing            // Wind down
            case .night: return .meditative           // Prepare for sleep
            case .lateNight: return .meditative       // Deep rest
            }
        }

        var description: String {
            switch self {
            case .earlyMorning: return "Gentle awakening, building energy"
            case .morning: return "Peak alertness, best for active work"
            case .afternoon: return "Creative window, good for flow states"
            case .evening: return "Wind down, transition to relaxation"
            case .night: return "Prepare for sleep, deep calming"
            case .lateNight: return "Deep rest and recovery"
            }
        }

        static func current() -> CircadianPhase {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<8: return .earlyMorning
            case 8..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            case 21..<24: return .night
            default: return .lateNight  // 0-5
            }
        }
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
    private var transitionTimer: Timer?
    private var circadianTimer: Timer?
    private var predictionTimer: Timer?

    // Transition parameters
    private var transitionDuration: TimeInterval = 3.0
    private var transitionTargetMode: WiseMode?
    private var transitionStartTime: Date?

    // Mode usage tracking for prediction
    private var modeUsageHistory: [(mode: WiseMode, hour: Int, coherence: Double, duration: TimeInterval)] = []

    private struct BioStateSnapshot {
        let timestamp: Date
        let hrvCoherence: Double
        let heartRate: Double
        let activeInputs: Int
    }

    // Group session participants
    private var groupParticipants: [GroupParticipant] = []

    public struct GroupParticipant: Identifiable {
        public let id: UUID
        public let name: String
        public var coherence: Float
        public var isConnected: Bool
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

    /// Set the current wise mode with optional smooth transition
    /// - Parameters:
    ///   - mode: Target wise mode
    ///   - animated: Whether to animate the transition (default: true)
    ///   - duration: Transition duration in seconds (default: 3.0)
    public func setMode(_ mode: WiseMode, animated: Bool = true, duration: TimeInterval = 3.0) {
        guard mode != currentMode else { return }

        let previousMode = currentMode
        modeTransitionHistory.append((from: previousMode, to: mode, timestamp: Date()))

        if animated && isActive {
            startSmoothTransition(to: mode, duration: duration)
        } else {
            currentMode = mode
            if isActive {
                applyCurrentMode()
            }
        }

        logger.info("Wise Mode changed: \(previousMode.rawValue, privacy: .public) → \(mode.rawValue, privacy: .public)")
    }

    // MARK: - Smooth Transitions

    /// Start a smooth transition to a new mode
    private func startSmoothTransition(to targetMode: WiseMode, duration: TimeInterval) {
        // Cancel any existing transition
        transitionTimer?.invalidate()

        transitionSourceMode = currentMode
        transitionTargetMode = targetMode
        transitionDuration = duration
        transitionStartTime = Date()
        isTransitioning = true
        transitionProgress = 0.0

        logger.info("Starting smooth transition: \(self.currentMode.rawValue, privacy: .public) → \(targetMode.rawValue, privacy: .public) (\(duration, privacy: .public)s)")

        // Update transition at 60 Hz
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTransition()
            }
        }
    }

    /// Update the ongoing transition
    private func updateTransition() {
        guard isTransitioning,
              let startTime = transitionStartTime,
              let targetMode = transitionTargetMode else {
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = Float(min(1.0, elapsed / transitionDuration))

        // Use easeInOut curve for smoother feel
        let smoothProgress = easeInOutCubic(progress)
        transitionProgress = smoothProgress

        // Interpolate parameters between modes
        interpolateModeParameters(progress: smoothProgress)

        // Complete transition when done
        if progress >= 1.0 {
            completeTransition(to: targetMode)
        }
    }

    /// Complete the transition
    private func completeTransition(to targetMode: WiseMode) {
        transitionTimer?.invalidate()
        transitionTimer = nil

        currentMode = targetMode
        isTransitioning = false
        transitionProgress = 1.0
        transitionSourceMode = nil
        transitionTargetMode = nil
        transitionStartTime = nil

        applyCurrentMode()

        logger.info("Transition complete: \(targetMode.rawValue, privacy: .public)")
    }

    /// Interpolate parameters between source and target modes
    private func interpolateModeParameters(progress: Float) {
        guard let sourceMode = transitionSourceMode,
              let targetMode = transitionTargetMode else { return }

        // Interpolate update frequency
        let sourceFreq = Float(sourceMode.updateFrequency)
        let targetFreq = Float(targetMode.updateFrequency)
        let interpolatedFreq = sourceFreq + (targetFreq - sourceFreq) * progress

        // Interpolate target coherence
        let sourceCoherence = sourceMode.targetCoherence
        let targetCoherence = targetMode.targetCoherence
        _ = sourceCoherence + (targetCoherence - sourceCoherence) * progress

        // Apply interpolated values to audio engine if available
        if let audio = audioEngine {
            // Interpolate binaural amplitude
            let sourceAmplitude: Float = sourceMode == .meditative || sourceMode == .healing ? 0.3 : 0.0
            let targetAmplitude: Float = targetMode == .meditative || targetMode == .healing ? 0.3 : 0.0
            let interpolatedAmplitude = sourceAmplitude + (targetAmplitude - sourceAmplitude) * progress
            audio.setBinauralAmplitude(interpolatedAmplitude)
        }

        logger.debug("Transition progress: \(Int(progress * 100), privacy: .public)% (freq: \(Int(interpolatedFreq), privacy: .public) Hz)")
    }

    /// Ease-in-out cubic function for smooth animation
    private func easeInOutCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = (2 * t) - 2
            return 0.5 * f * f * f + 1
        }
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

    // MARK: - Circadian Rhythm Integration

    /// Start circadian rhythm monitoring
    public func enableCircadianAlignment() {
        activeOptimizations.insert(.circadianAlignment)

        // Update immediately
        updateCircadianPhase()

        // Check every 15 minutes
        circadianTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCircadianPhase()
            }
        }

        logger.info("Circadian alignment enabled")
    }

    /// Stop circadian rhythm monitoring
    public func disableCircadianAlignment() {
        activeOptimizations.remove(.circadianAlignment)
        circadianTimer?.invalidate()
        circadianTimer = nil
        logger.info("Circadian alignment disabled")
    }

    /// Update the current circadian phase and recommendation
    private func updateCircadianPhase() {
        let newPhase = CircadianPhase.current()

        if newPhase != currentCircadianPhase {
            currentCircadianPhase = newPhase
            circadianRecommendedMode = newPhase.recommendedMode

            // Suggest mode change if significantly different
            if currentMode != circadianRecommendedMode && currentMode != .performance {
                addSuggestion(
                    type: .modeChange,
                    message: "Based on time of day (\(newPhase.rawValue)), \(circadianRecommendedMode.rawValue) mode is recommended.",
                    priority: .low
                )
            }

            logger.info("Circadian phase updated: \(newPhase.rawValue, privacy: .public) → recommends \(self.circadianRecommendedMode.rawValue, privacy: .public)")
        }
    }

    /// Automatically switch to circadian-recommended mode
    public func applyCircadianMode(animated: Bool = true) {
        setMode(circadianRecommendedMode, animated: animated)
    }

    // MARK: - Predictive Mode Selection

    /// Enable predictive mode selection
    public func enablePredictiveMode() {
        activeOptimizations.insert(.predictiveMode)

        // Update prediction every 10 minutes
        predictionTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateModePrediction()
            }
        }

        // Initial prediction
        updateModePrediction()

        logger.info("Predictive mode selection enabled")
    }

    /// Disable predictive mode selection
    public func disablePredictiveMode() {
        activeOptimizations.remove(.predictiveMode)
        predictionTimer?.invalidate()
        predictionTimer = nil
        predictedNextMode = nil
        predictionConfidence = 0.0
        logger.info("Predictive mode selection disabled")
    }

    /// Record current mode usage for learning
    private func recordModeUsage() {
        let hour = Calendar.current.component(.hour, from: Date())
        let coherence = healthKitManager?.hrvCoherence ?? 50.0

        modeUsageHistory.append((
            mode: currentMode,
            hour: hour,
            coherence: coherence,
            duration: 60.0  // Recorded every minute
        ))

        // Keep only last 7 days of history
        if modeUsageHistory.count > 7 * 24 * 60 {
            modeUsageHistory.removeFirst(modeUsageHistory.count - 7 * 24 * 60)
        }
    }

    /// Update mode prediction based on historical data
    private func updateModePrediction() {
        let nextHour = (Calendar.current.component(.hour, from: Date()) + 1) % 24

        // Find most common mode for next hour
        let relevantHistory = modeUsageHistory.filter { $0.hour == nextHour }

        guard !relevantHistory.isEmpty else {
            // Fall back to circadian recommendation
            predictedNextMode = CircadianPhase.current().recommendedMode
            predictionConfidence = 0.3
            return
        }

        // Count mode occurrences
        var modeCounts: [WiseMode: Int] = [:]
        for entry in relevantHistory {
            modeCounts[entry.mode, default: 0] += 1
        }

        // Find most common
        if let (mode, count) = modeCounts.max(by: { $0.value < $1.value }) {
            predictedNextMode = mode
            predictionConfidence = Float(count) / Float(relevantHistory.count)

            logger.debug("Predicted mode for hour \(nextHour, privacy: .public): \(mode.rawValue, privacy: .public) (confidence: \(Int(self.predictionConfidence * 100), privacy: .public)%)")
        }
    }

    /// Apply predicted mode
    public func applyPredictedMode(animated: Bool = true) {
        guard let predicted = predictedNextMode else { return }
        setMode(predicted, animated: animated)
    }

    // MARK: - Group Session

    /// Start a group session
    public func startGroupSession() {
        isGroupSessionActive = true
        activeOptimizations.insert(.groupSync)
        groupParticipants = []
        groupParticipantCount = 1  // Self
        groupCoherenceAverage = wisdomLevel

        logger.info("Group session started")
    }

    /// End the group session
    public func endGroupSession() {
        isGroupSessionActive = false
        activeOptimizations.remove(.groupSync)
        groupParticipants = []
        groupParticipantCount = 0
        groupCoherenceAverage = 0.0

        logger.info("Group session ended")
    }

    /// Add a participant to the group session
    public func addGroupParticipant(id: UUID, name: String, coherence: Float) {
        guard isGroupSessionActive else { return }

        let participant = GroupParticipant(id: id, name: name, coherence: coherence, isConnected: true)
        groupParticipants.append(participant)
        groupParticipantCount = groupParticipants.count + 1  // +1 for self

        updateGroupCoherence()

        logger.info("Participant added: \(name, privacy: .public) (coherence: \(Int(coherence * 100), privacy: .public)%)")
    }

    /// Remove a participant from the group session
    public func removeGroupParticipant(id: UUID) {
        groupParticipants.removeAll { $0.id == id }
        groupParticipantCount = groupParticipants.count + 1

        updateGroupCoherence()
    }

    /// Update a participant's coherence
    public func updateParticipantCoherence(id: UUID, coherence: Float) {
        if let index = groupParticipants.firstIndex(where: { $0.id == id }) {
            groupParticipants[index].coherence = coherence
            updateGroupCoherence()
        }
    }

    /// Calculate and update group coherence average
    private func updateGroupCoherence() {
        let selfCoherence = wisdomLevel
        let participantCoherences = groupParticipants.map { $0.coherence }

        let totalCoherence = selfCoherence + participantCoherences.reduce(0, +)
        let count = Float(groupParticipants.count + 1)

        groupCoherenceAverage = totalCoherence / count

        // Suggest mode if group coherence is high
        if groupCoherenceAverage > 0.8 && currentMode != .meditative {
            addSuggestion(
                type: .modeChange,
                message: "Group coherence is high (\(Int(groupCoherenceAverage * 100))%). Consider Meditative mode for collective experience.",
                priority: .medium
            )
        }
    }

    /// Synchronize mode across group
    public func synchronizeGroupMode(_ mode: WiseMode) {
        guard isGroupSessionActive else { return }

        setMode(mode, animated: true)

        // In real implementation, would broadcast to other participants
        logger.info("Group mode synchronized: \(mode.rawValue, privacy: .public)")
    }

    // MARK: - Wisdom Visualization Data

    /// Get visualization data for wisdom dashboard
    public var wisdomVisualizationData: WisdomVisualizationData {
        WisdomVisualizationData(
            wisdomLevel: wisdomLevel,
            systemHealth: systemHealth,
            currentMode: currentMode,
            isTransitioning: isTransitioning,
            transitionProgress: transitionProgress,
            circadianPhase: currentCircadianPhase,
            circadianRecommendedMode: circadianRecommendedMode,
            predictedNextMode: predictedNextMode,
            predictionConfidence: predictionConfidence,
            isGroupActive: isGroupSessionActive,
            groupParticipantCount: groupParticipantCount,
            groupCoherence: groupCoherenceAverage,
            activeOptimizations: Array(activeOptimizations),
            recentCoherenceHistory: bioStateHistory.suffix(30).map { Float($0.hrvCoherence) / 100.0 }
        )
    }

    public struct WisdomVisualizationData {
        public let wisdomLevel: Float
        public let systemHealth: Int
        public let currentMode: WiseMode
        public let isTransitioning: Bool
        public let transitionProgress: Float
        public let circadianPhase: CircadianPhase
        public let circadianRecommendedMode: WiseMode
        public let predictedNextMode: WiseMode?
        public let predictionConfidence: Float
        public let isGroupActive: Bool
        public let groupParticipantCount: Int
        public let groupCoherence: Float
        public let activeOptimizations: [Optimization]
        public let recentCoherenceHistory: [Float]
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
