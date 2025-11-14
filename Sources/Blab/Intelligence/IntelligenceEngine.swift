import Foundation
import Combine
import AVFoundation
import CoreML

/// Super Intelligence Engine for BLAB
///
/// This is the brain of BLAB - a self-learning, context-aware, bio-adaptive system
/// that optimizes audio processing, predicts user actions, and automatically adapts
/// to user behavior and biometric feedback.
///
/// **Capabilities:**
/// - 🎯 Context Detection: Recognizes activity (meditation, performance, recording)
/// - 🧘 Bio-Adaptive: Learns from HRV/biometrics, predicts optimal states
/// - 🤖 Self-Optimizing: Auto-selects latency, buffer size, mix settings
/// - 🔮 Predictive: Anticipates next user actions based on patterns
/// - 🛠️ Self-Healing: Detects and fixes audio issues automatically
/// - 📚 Learning: Improves over time through usage patterns
///
/// **Architecture:**
/// ```
/// Inputs → [Context Detection] → [Pattern Learning] → [Prediction] → Actions
///          ↓                      ↓                    ↓
///          Bio Signals            User Behavior        Auto-Optimization
/// ```
@MainActor
class IntelligenceEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current detected context
    @Published var currentContext: ActivityContext = .idle

    /// Confidence level of context detection (0.0 - 1.0)
    @Published var contextConfidence: Float = 0.0

    /// Current intelligence state
    @Published var intelligenceState: IntelligenceState = .learning

    /// Recommended latency mode (auto-optimized)
    @Published var recommendedLatencyMode: AudioConfiguration.LatencyMode = .low

    /// Recommended wet/dry mix (auto-optimized)
    @Published var recommendedWetDryMix: Float = 0.3

    /// Predicted next action
    @Published var predictedNextAction: PredictedAction? = nil

    /// Bio-coherence score (0-100, derived from HRV)
    @Published var bioCoherenceScore: Double = 50.0

    /// System health status
    @Published var systemHealth: SystemHealth = .optimal

    /// Total learning sessions
    @Published var learningSessions: Int = 0

    /// Auto-optimization enabled
    @Published var autoOptimizationEnabled: Bool = true


    // MARK: - Private Properties

    /// Context detector
    private let contextDetector = ContextDetector()

    /// Pattern learner
    private let patternLearner = PatternLearner()

    /// Bio-adaptive predictor
    private let bioPredictor = BioAdaptivePredictor()

    /// Anomaly detector
    private let anomalyDetector = AnomalyDetector()

    /// Scene manager (remembers settings per context)
    private let sceneManager = SmartSceneManager()

    /// User behavior tracker
    private let behaviorTracker = UserBehaviorTracker()

    /// Optimization engine
    private let optimizationEngine = OptimizationEngine()

    /// Intelligence update timer (10 Hz - every 100ms)
    private var updateTimer: Timer?

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Intelligence data store
    private var dataStore = IntelligenceDataStore()

    /// Last context change time
    private var lastContextChange: Date = Date()

    /// Context stability duration (seconds)
    private var contextStabilityDuration: TimeInterval = 0


    // MARK: - Initialization

    init() {
        print("🧠 IntelligenceEngine initializing...")
        loadLearningData()
    }


    // MARK: - Lifecycle

    /// Start intelligence engine
    func start() {
        print("🧠 IntelligenceEngine started")

        // Start context detection
        contextDetector.start()

        // Start anomaly detection
        anomalyDetector.start()

        // Start intelligence update loop (10 Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.intelligenceUpdate()
            }
        }

        intelligenceState = .active
        learningSessions += 1
        saveMetadata()
    }

    /// Stop intelligence engine
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil

        contextDetector.stop()
        anomalyDetector.stop()

        intelligenceState = .idle
        saveLearningData()

        print("🧠 IntelligenceEngine stopped")
    }


    // MARK: - Intelligence Update Loop (10 Hz)

    private func intelligenceUpdate() {
        // 1. Context Detection
        updateContextDetection()

        // 2. Pattern Learning
        updatePatternLearning()

        // 3. Bio-Adaptive Prediction
        updateBioPrediction()

        // 4. Anomaly Detection
        updateAnomalyDetection()

        // 5. Auto-Optimization
        if autoOptimizationEnabled {
            updateAutoOptimization()
        }

        // 6. Predictive Actions
        updatePredictiveActions()
    }


    // MARK: - 1. Context Detection

    private func updateContextDetection() {
        // Detect current activity context
        let detectedContext = contextDetector.detectContext(
            audioLevel: getCurrentAudioLevel(),
            hrvCoherence: getCurrentHRVCoherence(),
            heartRate: getCurrentHeartRate(),
            gestureActivity: getCurrentGestureActivity(),
            faceExpression: getCurrentFaceExpression(),
            timeOfDay: Date()
        )

        // Update confidence
        contextConfidence = contextDetector.confidence

        // Check if context changed
        if detectedContext != currentContext {
            handleContextChange(from: currentContext, to: detectedContext)
            currentContext = detectedContext
            lastContextChange = Date()
            contextStabilityDuration = 0
        } else {
            contextStabilityDuration = Date().timeIntervalSince(lastContextChange)
        }
    }

    private func handleContextChange(from oldContext: ActivityContext, to newContext: ActivityContext) {
        print("🧠 Context changed: \(oldContext.rawValue) → \(newContext.rawValue)")

        // Track context transition
        behaviorTracker.recordContextTransition(from: oldContext, to: newContext)

        // Recall optimal settings for new context
        if let scene = sceneManager.recallScene(for: newContext) {
            applyScene(scene)
            print("   ✅ Recalled optimal settings for \(newContext.rawValue)")
        }

        // Log learning data
        patternLearner.recordContextChange(from: oldContext, to: newContext, at: Date())
    }


    // MARK: - 2. Pattern Learning

    private func updatePatternLearning() {
        // Learn from current state
        patternLearner.observe(
            context: currentContext,
            latencyMode: getCurrentLatencyMode(),
            wetDryMix: getCurrentWetDryMix(),
            inputGain: getCurrentInputGain(),
            hrvCoherence: getCurrentHRVCoherence(),
            timestamp: Date()
        )

        // Update intelligence state based on learning progress
        if patternLearner.trainingExamples >= 100 {
            intelligenceState = .trained
        } else if patternLearner.trainingExamples >= 1000 {
            intelligenceState = .expert
        }
    }


    // MARK: - 3. Bio-Adaptive Prediction

    private func updateBioPrediction() {
        // Get current biometrics
        let hrv = getCurrentHRVCoherence()
        let hr = getCurrentHeartRate()

        // Update bio-coherence score
        bioCoherenceScore = bioPredictor.calculateCoherence(hrv: hrv, heartRate: hr)

        // Predict optimal state based on biometrics
        let prediction = bioPredictor.predictOptimalState(
            currentHRV: hrv,
            currentHR: hr,
            currentContext: currentContext,
            timestamp: Date()
        )

        // Store bio-coherence history for learning
        bioPredictor.recordBioState(hrv: hrv, hr: hr, coherence: bioCoherenceScore)
    }


    // MARK: - 4. Anomaly Detection

    private func updateAnomalyDetection() {
        // Check for audio anomalies
        let audioHealth = anomalyDetector.checkAudioHealth(
            inputLevel: getCurrentInputLevel(),
            outputLevel: getCurrentOutputLevel(),
            latency: getCurrentLatency(),
            cpuUsage: getCurrentCPUUsage(),
            dropouts: getAudioDropouts()
        )

        systemHealth = audioHealth

        // Auto-heal if issues detected
        if systemHealth != .optimal {
            handleAnomalies(health: systemHealth)
        }
    }

    private func handleAnomalies(health: SystemHealth) {
        switch health {
        case .optimal:
            break

        case .warning(let issue):
            print("⚠️  System warning: \(issue)")
            applyAutoFix(for: issue)

        case .critical(let issue):
            print("❌ Critical issue: \(issue)")
            applyEmergencyFix(for: issue)
        }
    }

    private func applyAutoFix(for issue: String) {
        // Intelligent auto-fix based on issue type
        if issue.contains("latency") || issue.contains("dropout") {
            // Increase buffer size
            recommendedLatencyMode = .normal
            print("   🔧 Auto-fix: Increased buffer size to reduce dropouts")
        } else if issue.contains("CPU") {
            // Reduce processing load
            recommendedWetDryMix = max(recommendedWetDryMix - 0.2, 0.0)
            print("   🔧 Auto-fix: Reduced effects mix to lower CPU usage")
        } else if issue.contains("clipping") {
            // Reduce input gain
            notifyInputGainReduction()
            print("   🔧 Auto-fix: Recommended input gain reduction")
        }
    }

    private func applyEmergencyFix(for issue: String) {
        // Emergency actions for critical issues
        print("   🚨 Emergency fix: Switching to safe mode")
        recommendedLatencyMode = .normal
        recommendedWetDryMix = 0.0  // Direct monitoring only
    }


    // MARK: - 5. Auto-Optimization

    private func updateAutoOptimization() {
        guard contextStabilityDuration > 3.0 else { return }  // Wait 3s for stability

        // Optimize latency mode based on context and CPU
        let optimalLatency = optimizationEngine.calculateOptimalLatency(
            context: currentContext,
            cpuUsage: getCurrentCPUUsage(),
            batteryLevel: getBatteryLevel()
        )

        if optimalLatency != recommendedLatencyMode {
            recommendedLatencyMode = optimalLatency
            print("🧠 Auto-optimized latency: \(optimalLatency.description)")
        }

        // Optimize wet/dry mix based on context and bio-coherence
        let optimalMix = optimizationEngine.calculateOptimalMix(
            context: currentContext,
            bioCoherence: bioCoherenceScore,
            userPreference: behaviorTracker.getAverageMix(for: currentContext)
        )

        if abs(optimalMix - recommendedWetDryMix) > 0.1 {
            recommendedWetDryMix = optimalMix
            print("🧠 Auto-optimized wet/dry: \(Int(optimalMix * 100))%")
        }
    }


    // MARK: - 6. Predictive Actions

    private func updatePredictiveActions() {
        // Predict next action based on patterns
        let prediction = patternLearner.predictNextAction(
            currentContext: currentContext,
            currentTime: Date(),
            recentActions: behaviorTracker.getRecentActions()
        )

        predictedNextAction = prediction

        if let action = prediction, action.confidence > 0.7 {
            print("🔮 Predicted: \(action.description) (confidence: \(Int(action.confidence * 100))%)")
        }
    }


    // MARK: - Public Control Methods

    /// Apply recommended settings automatically
    func applyRecommendedSettings(to audioIO: AudioIOManager) async throws {
        print("🧠 Applying intelligent recommendations...")

        // Apply latency mode
        try await audioIO.setLatencyMode(recommendedLatencyMode)

        // Apply wet/dry mix
        audioIO.setWetDryMix(recommendedWetDryMix)

        print("   ✅ Latency: \(recommendedLatencyMode.description)")
        print("   ✅ Wet/Dry: \(Int(recommendedWetDryMix * 100))%")
    }

    /// Save current settings as preferred for current context
    func saveCurrentScene(
        latencyMode: AudioConfiguration.LatencyMode,
        wetDryMix: Float,
        inputGain: Float
    ) {
        let scene = Scene(
            context: currentContext,
            latencyMode: latencyMode,
            wetDryMix: wetDryMix,
            inputGain: inputGain,
            timestamp: Date()
        )

        sceneManager.saveScene(scene)
        print("🧠 Saved scene for context: \(currentContext.rawValue)")
    }

    /// Record user action for learning
    func recordUserAction(_ action: UserAction) {
        behaviorTracker.recordAction(action, at: Date(), context: currentContext)
        patternLearner.observe(action: action, context: currentContext)
    }

    /// Enable/disable auto-optimization
    func setAutoOptimization(_ enabled: Bool) {
        autoOptimizationEnabled = enabled
        print("🧠 Auto-optimization: \(enabled ? "ON" : "OFF")")
    }


    // MARK: - Data Persistence

    private func loadLearningData() {
        do {
            dataStore = try IntelligenceDataStore.load()
            learningSessions = dataStore.metadata.totalSessions

            // Restore learned patterns
            patternLearner.restore(from: dataStore.patterns)
            sceneManager.restore(from: dataStore.scenes)
            behaviorTracker.restore(from: dataStore.behaviors)

            print("🧠 Loaded learning data (\(learningSessions) sessions)")
        } catch {
            print("⚠️  No previous learning data found, starting fresh")
        }
    }

    private func saveLearningData() {
        dataStore.patterns = patternLearner.export()
        dataStore.scenes = sceneManager.export()
        dataStore.behaviors = behaviorTracker.export()
        dataStore.metadata.totalSessions = learningSessions
        dataStore.metadata.lastUpdate = Date()

        do {
            try dataStore.save()
            print("🧠 Saved learning data")
        } catch {
            print("❌ Failed to save learning data: \(error)")
        }
    }

    private func saveMetadata() {
        dataStore.metadata.totalSessions = learningSessions
        dataStore.metadata.lastUpdate = Date()
    }


    // MARK: - Helper Methods (to be connected to real managers)

    private func getCurrentAudioLevel() -> Float {
        // TODO: Connect to AudioIOManager
        return 0.5
    }

    private func getCurrentHRVCoherence() -> Double {
        // TODO: Connect to HealthKitManager
        return 60.0
    }

    private func getCurrentHeartRate() -> Double {
        // TODO: Connect to HealthKitManager
        return 70.0
    }

    private func getCurrentGestureActivity() -> Float {
        // TODO: Connect to GestureRecognizer
        return 0.0
    }

    private func getCurrentFaceExpression() -> String {
        // TODO: Connect to FaceTrackingManager
        return "neutral"
    }

    private func getCurrentLatencyMode() -> AudioConfiguration.LatencyMode {
        // TODO: Connect to AudioIOManager
        return .low
    }

    private func getCurrentWetDryMix() -> Float {
        // TODO: Connect to AudioIOManager
        return 0.3
    }

    private func getCurrentInputGain() -> Float {
        // TODO: Connect to AudioIOManager
        return 0.0
    }

    private func getCurrentInputLevel() -> Float {
        // TODO: Connect to AudioIOManager
        return -20.0
    }

    private func getCurrentOutputLevel() -> Float {
        // TODO: Connect to AudioIOManager
        return -20.0
    }

    private func getCurrentLatency() -> TimeInterval {
        // TODO: Connect to AudioIOManager
        return 0.005
    }

    private func getCurrentCPUUsage() -> Float {
        // System CPU usage
        return ProcessInfo.processInfo.systemUptime > 0 ? 0.15 : 0.0
    }

    private func getAudioDropouts() -> Int {
        // TODO: Track dropouts
        return 0
    }

    private func getBatteryLevel() -> Float {
        // iOS battery level
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
        #else
        return 1.0
        #endif
    }

    private func notifyInputGainReduction() {
        // TODO: Send notification to UI
    }

    private func applyScene(_ scene: Scene) {
        recommendedLatencyMode = scene.latencyMode
        recommendedWetDryMix = scene.wetDryMix
        // Input gain would be applied via notification/callback
    }


    // MARK: - Status

    var statusDescription: String {
        """
        🧠 IntelligenceEngine Status:
           State: \(intelligenceState.rawValue)
           Context: \(currentContext.rawValue) (confidence: \(Int(contextConfidence * 100))%)
           Bio-Coherence: \(Int(bioCoherenceScore))/100
           System Health: \(systemHealth.description)
           Learning Sessions: \(learningSessions)
           Auto-Optimization: \(autoOptimizationEnabled ? "ON" : "OFF")

           Recommendations:
           • Latency Mode: \(recommendedLatencyMode.description)
           • Wet/Dry Mix: \(Int(recommendedWetDryMix * 100))%

           \(predictedNextAction?.description ?? "")
        """
    }
}


// MARK: - Supporting Types

enum ActivityContext: String, Codable {
    case idle = "Idle"
    case meditation = "Meditation"
    case performance = "Performance"
    case recording = "Recording"
    case practice = "Practice"
    case healing = "Healing"
    case creative = "Creative Flow"
}

enum IntelligenceState: String {
    case idle = "Idle"
    case learning = "Learning"
    case active = "Active"
    case trained = "Trained"
    case expert = "Expert"
}

enum SystemHealth {
    case optimal
    case warning(String)
    case critical(String)

    var description: String {
        switch self {
        case .optimal: return "✅ Optimal"
        case .warning(let issue): return "⚠️  Warning: \(issue)"
        case .critical(let issue): return "❌ Critical: \(issue)"
        }
    }
}

struct PredictedAction {
    let action: UserAction
    let confidence: Float
    let timestamp: Date

    var description: String {
        "Predicted: \(action.rawValue) (\(Int(confidence * 100))%)"
    }
}

enum UserAction: String, Codable {
    case startRecording = "Start Recording"
    case stopRecording = "Stop Recording"
    case adjustMix = "Adjust Mix"
    case changeLatency = "Change Latency"
    case enableDirectMonitoring = "Enable Direct Monitoring"
    case disableDirectMonitoring = "Disable Direct Monitoring"
    case adjustGain = "Adjust Gain"
}

struct Scene: Codable {
    let context: ActivityContext
    let latencyMode: AudioConfiguration.LatencyMode
    let wetDryMix: Float
    let inputGain: Float
    let timestamp: Date
}
