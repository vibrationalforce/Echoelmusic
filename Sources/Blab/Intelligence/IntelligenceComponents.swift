import Foundation

// MARK: - Bio-Adaptive Predictor

/// Bio-Adaptive Predictor - Predicts optimal states based on biometric feedback
class BioAdaptivePredictor {

    /// Bio-state history (last 1000 states)
    private var bioHistory: [BioState] = []

    /// HRV coherence patterns
    private var hrvPatterns: [Double] = []


    /// Calculate bio-coherence score from current biometrics
    func calculateCoherence(hrv: Double, heartRate: Double) -> Double {
        // HRV coherence formula (0-100 scale)
        // High HRV + optimal HR = high coherence
        let normalizedHRV = min(max(hrv, 0), 100) / 100.0
        let optimalHR = 60.0  // Optimal resting HR
        let hrDeviation = abs(heartRate - optimalHR) / optimalHR
        let hrScore = max(0, 1.0 - hrDeviation)

        let coherence = (normalizedHRV * 0.7 + hrScore * 0.3) * 100.0
        return coherence
    }

    /// Predict optimal state based on current biometrics
    func predictOptimalState(
        currentHRV: Double,
        currentHR: Double,
        currentContext: ActivityContext,
        timestamp: Date
    ) -> BioOptimalState {

        let coherence = calculateCoherence(hrv: currentHRV, heartRate: currentHR)

        // Determine optimal state based on coherence and context
        if coherence > 70 {
            // High coherence - optimal for deep work
            return BioOptimalState(
                recommendedContext: .creative,
                recommendedIntensity: .high,
                confidence: Float(coherence / 100.0)
            )
        } else if coherence > 50 {
            // Medium coherence - good for practice/performance
            return BioOptimalState(
                recommendedContext: currentContext,
                recommendedIntensity: .medium,
                confidence: Float(coherence / 100.0)
            )
        } else {
            // Low coherence - recommend healing/meditation
            return BioOptimalState(
                recommendedContext: .meditation,
                recommendedIntensity: .low,
                confidence: Float(coherence / 100.0)
            )
        }
    }

    /// Record bio-state for learning
    func recordBioState(hrv: Double, hr: Double, coherence: Double) {
        let state = BioState(hrv: hrv, heartRate: hr, coherence: coherence, timestamp: Date())
        bioHistory.append(state)
        hrvPatterns.append(hrv)

        // Keep last 1000 states
        if bioHistory.count > 1000 {
            bioHistory.removeFirst()
        }
        if hrvPatterns.count > 1000 {
            hrvPatterns.removeFirst()
        }
    }

    func export() -> [String: Any] {
        return [
            "bioHistory": bioHistory.map { [
                "hrv": $0.hrv,
                "hr": $0.heartRate,
                "coherence": $0.coherence,
                "timestamp": $0.timestamp.timeIntervalSince1970
            ]},
            "hrvPatterns": hrvPatterns
        ]
    }

    func restore(from data: [String: Any]) {
        if let history = data["bioHistory"] as? [[String: Any]] {
            bioHistory = history.compactMap { dict in
                guard let hrv = dict["hrv"] as? Double,
                      let hr = dict["hr"] as? Double,
                      let coherence = dict["coherence"] as? Double,
                      let timestamp = dict["timestamp"] as? TimeInterval else {
                    return nil
                }
                return BioState(
                    hrv: hrv,
                    heartRate: hr,
                    coherence: coherence,
                    timestamp: Date(timeIntervalSince1970: timestamp)
                )
            }
        }
        hrvPatterns = data["hrvPatterns"] as? [Double] ?? []
    }
}

struct BioState {
    let hrv: Double
    let heartRate: Double
    let coherence: Double
    let timestamp: Date
}

struct BioOptimalState {
    let recommendedContext: ActivityContext
    let recommendedIntensity: IntensityLevel
    let confidence: Float
}

enum IntensityLevel {
    case low, medium, high
}


// MARK: - Anomaly Detector

/// Anomaly Detector - Detects and reports audio system issues
class AnomalyDetector {

    private var latencyHistory: [TimeInterval] = []
    private var cpuHistory: [Float] = []
    private var dropoutCount: Int = 0


    func start() {
        print("🔍 AnomalyDetector started")
    }

    func stop() {
        print("🔍 AnomalyDetector stopped")
    }

    /// Check audio system health
    func checkAudioHealth(
        inputLevel: Float,
        outputLevel: Float,
        latency: TimeInterval,
        cpuUsage: Float,
        dropouts: Int
    ) -> SystemHealth {

        // Record metrics
        latencyHistory.append(latency)
        cpuHistory.append(cpuUsage)
        if latencyHistory.count > 100 { latencyHistory.removeFirst() }
        if cpuHistory.count > 100 { cpuHistory.removeFirst() }

        // Check for critical issues
        if cpuUsage > 0.9 {
            return .critical("CPU usage critical (>90%)")
        }

        if latency > 0.050 {  // > 50ms
            return .critical("Latency too high (\(Int(latency * 1000))ms)")
        }

        if dropouts > 10 {
            return .critical("\(dropouts) audio dropouts detected")
        }

        // Check for warnings
        if cpuUsage > 0.7 {
            return .warning("High CPU usage (\(Int(cpuUsage * 100))%)")
        }

        if latency > 0.020 {  // > 20ms
            return .warning("Latency elevated (\(Int(latency * 1000))ms)")
        }

        if inputLevel > -3.0 {
            return .warning("Input level too high (risk of clipping)")
        }

        if outputLevel > -3.0 {
            return .warning("Output level too high (risk of clipping)")
        }

        if dropouts > 0 {
            return .warning("\(dropouts) audio dropout(s)")
        }

        return .optimal
    }

    func export() -> [String: Any] {
        return [
            "dropoutCount": dropoutCount,
            "avgLatency": latencyHistory.isEmpty ? 0 : latencyHistory.reduce(0, +) / Double(latencyHistory.count),
            "avgCPU": cpuHistory.isEmpty ? 0 : cpuHistory.reduce(0, +) / Float(cpuHistory.count)
        ]
    }

    func restore(from data: [String: Any]) {
        dropoutCount = data["dropoutCount"] as? Int ?? 0
    }
}


// MARK: - Smart Scene Manager

/// Smart Scene Manager - Remembers optimal settings per context
class SmartSceneManager {

    private var scenes: [ActivityContext: Scene] = [:]


    /// Save scene for context
    func saveScene(_ scene: Scene) {
        scenes[scene.context] = scene
        print("💾 Saved scene for \(scene.context.rawValue)")
    }

    /// Recall scene for context
    func recallScene(for context: ActivityContext) -> Scene? {
        return scenes[context]
    }

    func export() -> [String: Any] {
        var sceneData: [[String: Any]] = []

        for (context, scene) in scenes {
            sceneData.append([
                "context": context.rawValue,
                "latencyMode": scene.latencyMode.bufferSize,
                "wetDryMix": scene.wetDryMix,
                "inputGain": scene.inputGain,
                "timestamp": scene.timestamp.timeIntervalSince1970
            ])
        }

        return ["scenes": sceneData]
    }

    func restore(from data: [String: Any]) {
        guard let sceneData = data["scenes"] as? [[String: Any]] else { return }

        for dict in sceneData {
            guard let contextStr = dict["context"] as? String,
                  let context = ActivityContext(rawValue: contextStr),
                  let bufferSize = dict["latencyMode"] as? AVAudioFrameCount,
                  let wetDryMix = dict["wetDryMix"] as? Float,
                  let inputGain = dict["inputGain"] as? Float,
                  let timestamp = dict["timestamp"] as? TimeInterval else {
                continue
            }

            let latencyMode: AudioConfiguration.LatencyMode = {
                switch bufferSize {
                case 128: return .ultraLow
                case 256: return .low
                default: return .normal
                }
            }()

            let scene = Scene(
                context: context,
                latencyMode: latencyMode,
                wetDryMix: wetDryMix,
                inputGain: inputGain,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )

            scenes[context] = scene
        }
    }
}


// MARK: - User Behavior Tracker

/// User Behavior Tracker - Tracks user actions and preferences
class UserBehaviorTracker {

    private var actionHistory: [(action: UserAction, context: ActivityContext, timestamp: Date)] = []
    private var contextPreferences: [ActivityContext: ContextPreferences] = [:]


    /// Record user action
    func recordAction(_ action: UserAction, at time: Date, context: ActivityContext) {
        actionHistory.append((action, context, time))

        // Keep last 1000 actions
        if actionHistory.count > 1000 {
            actionHistory.removeFirst()
        }

        // Update context preferences
        var prefs = contextPreferences[context] ?? ContextPreferences()
        prefs.recordAction(action)
        contextPreferences[context] = prefs
    }

    /// Record context transition
    func recordContextTransition(from: ActivityContext, to: ActivityContext) {
        // Track transitions for pattern learning
    }

    /// Get recent actions
    func getRecentActions(count: Int = 10) -> [UserAction] {
        return Array(actionHistory.suffix(count).map { $0.action })
    }

    /// Get average wet/dry mix for context
    func getAverageMix(for context: ActivityContext) -> Float {
        return contextPreferences[context]?.averageMix ?? 0.3
    }

    func export() -> [String: Any] {
        return [
            "actionHistory": actionHistory.map { [
                "action": $0.action.rawValue,
                "context": $0.context.rawValue,
                "timestamp": $0.timestamp.timeIntervalSince1970
            ]},
            "contextPreferences": contextPreferences.mapValues { $0.toDictionary() }
        ]
    }

    func restore(from data: [String: Any]) {
        if let history = data["actionHistory"] as? [[String: Any]] {
            actionHistory = history.compactMap { dict in
                guard let actionStr = dict["action"] as? String,
                      let action = UserAction(rawValue: actionStr),
                      let contextStr = dict["context"] as? String,
                      let context = ActivityContext(rawValue: contextStr),
                      let timestamp = dict["timestamp"] as? TimeInterval else {
                    return nil
                }
                return (action, context, Date(timeIntervalSince1970: timestamp))
            }
        }

        if let prefs = data["contextPreferences"] as? [String: [String: Any]] {
            for (contextStr, prefDict) in prefs {
                if let context = ActivityContext(rawValue: contextStr) {
                    contextPreferences[context] = ContextPreferences(from: prefDict)
                }
            }
        }
    }
}

struct ContextPreferences {
    var mixValues: [Float] = []
    var actionCounts: [UserAction: Int] = [:]

    var averageMix: Float {
        guard !mixValues.isEmpty else { return 0.3 }
        return mixValues.reduce(0, +) / Float(mixValues.count)
    }

    mutating func recordAction(_ action: UserAction) {
        actionCounts[action, default: 0] += 1
    }

    func toDictionary() -> [String: Any] {
        return [
            "mixValues": mixValues,
            "actionCounts": actionCounts.mapKeys { $0.rawValue }
        ]
    }

    init() {}

    init(from dict: [String: Any]) {
        mixValues = dict["mixValues"] as? [Float] ?? []
        if let counts = dict["actionCounts"] as? [String: Int] {
            actionCounts = counts.compactMapKeys { UserAction(rawValue: $0) }
        }
    }
}


// MARK: - Optimization Engine

/// Optimization Engine - Calculates optimal settings
class OptimizationEngine {

    /// Calculate optimal latency mode based on context and system state
    func calculateOptimalLatency(
        context: ActivityContext,
        cpuUsage: Float,
        batteryLevel: Float
    ) -> AudioConfiguration.LatencyMode {

        // Critical: High CPU or low battery → normal mode
        if cpuUsage > 0.8 || batteryLevel < 0.2 {
            return .normal
        }

        // Context-based optimization
        switch context {
        case .performance, .recording:
            // Ultra-low latency for live performance
            return cpuUsage < 0.5 ? .ultraLow : .low

        case .practice:
            // Low latency for practice
            return .low

        case .meditation, .healing, .idle:
            // Battery-friendly for meditation
            return .normal

        case .creative:
            // Balanced for creative work
            return .low
        }
    }

    /// Calculate optimal wet/dry mix
    func calculateOptimalMix(
        context: ActivityContext,
        bioCoherence: Double,
        userPreference: Float?
    ) -> Float {

        // Start with context defaults
        var optimalMix: Float

        switch context {
        case .performance:
            // Performance: prefer direct monitoring
            optimalMix = 0.2

        case .recording:
            // Recording: some effects for monitoring
            optimalMix = 0.3

        case .meditation, .healing:
            // Meditation: more effects (reverb, etc.)
            optimalMix = 0.6

        case .creative:
            // Creative: balanced
            optimalMix = 0.4

        case .practice:
            // Practice: direct + some effects
            optimalMix = 0.3

        case .idle:
            // Idle: default
            optimalMix = 0.3
        }

        // Adjust based on bio-coherence
        // High coherence → can handle more processing
        let coherenceFactor = Float(bioCoherence / 100.0)
        optimalMix = optimalMix * (0.7 + coherenceFactor * 0.3)

        // Blend with user preference if available
        if let userPref = userPreference {
            optimalMix = optimalMix * 0.6 + userPref * 0.4
        }

        return min(max(optimalMix, 0.0), 1.0)
    }
}


// MARK: - Intelligence Data Store

/// Intelligence Data Store - Persistent storage for learned data
struct IntelligenceDataStore: Codable {
    var patterns: [String: Any] = [:]
    var scenes: [String: Any] = [:]
    var behaviors: [String: Any] = [:]
    var metadata: Metadata = Metadata()

    struct Metadata: Codable {
        var totalSessions: Int = 0
        var lastUpdate: Date = Date()
    }

    enum CodingKeys: String, CodingKey {
        case metadata
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }

    init() {}

    static func load() throws -> IntelligenceDataStore {
        let url = getStorageURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(IntelligenceDataStore.self, from: data)
    }

    func save() throws {
        let url = Self.getStorageURL()
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }

    static func getStorageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("IntelligenceData.json")
    }
}


// MARK: - Dictionary Extensions

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }

    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        return mapKeys(transform)
    }
}
