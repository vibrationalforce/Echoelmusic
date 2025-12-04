import Foundation
import Combine
import Accelerate
import os.log
import CoreML

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM WONDER SELF-HEALING ENGINE V2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Super High Quantum Wonder Self Healing Code God Developer Science Mode"
//
// Features:
// • Quantum-Inspired Error Correction
// • ML-Based Predictive Healing
// • Thermal Management Integration
// • Network-Adaptive Optimization
// • Distributed Healing Coordination
// • Cross-Platform Universal Core
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Quantum Self-Healing Extension

extension SelfHealingEngine {

    // MARK: - Quantum Error Correction

    /// Quantum-inspired error correction using superposition-like state management
    /// Maintains multiple potential states and collapses to optimal on measurement
    func quantumErrorCorrection(for errorType: ErrorType) -> QuantumHealingResult {
        // Create superposition of healing strategies
        let strategies = createHealingStrategySuperposition(for: errorType)

        // Evaluate all strategies simultaneously (parallel)
        let evaluations = strategies.map { strategy in
            evaluateStrategy(strategy)
        }

        // Quantum measurement: collapse to best strategy
        let bestStrategy = collapseToOptimal(evaluations)

        // Apply quantum-corrected healing
        let result = applyQuantumHealing(bestStrategy)

        return result
    }

    private func createHealingStrategySuperposition(for errorType: ErrorType) -> [QuantumHealingStrategy] {
        var strategies: [QuantumHealingStrategy] = []

        // Generate multiple potential healing approaches with amplitude coefficients
        let amplitudes = calculateQuantumAmplitudes(for: errorType)

        // Conservative strategy
        strategies.append(QuantumHealingStrategy(
            type: .conservative,
            amplitude: amplitudes.conservative,
            actions: getConservativeActions(for: errorType)
        ))

        // Moderate strategy
        strategies.append(QuantumHealingStrategy(
            type: .moderate,
            amplitude: amplitudes.moderate,
            actions: getModerateActions(for: errorType)
        ))

        // Aggressive strategy
        strategies.append(QuantumHealingStrategy(
            type: .aggressive,
            amplitude: amplitudes.aggressive,
            actions: getAggressiveActions(for: errorType)
        ))

        // Quantum strategy (uses entanglement-like cross-system healing)
        strategies.append(QuantumHealingStrategy(
            type: .quantum,
            amplitude: amplitudes.quantum,
            actions: getQuantumEntangledActions(for: errorType)
        ))

        return strategies
    }

    private func calculateQuantumAmplitudes(for errorType: ErrorType) -> QuantumAmplitudes {
        // Calculate amplitudes based on historical success rates
        let history = getHealingHistory(for: errorType)

        // Quantum amplitude formula: |ψ⟩ = α|conservative⟩ + β|moderate⟩ + γ|aggressive⟩ + δ|quantum⟩
        // where |α|² + |β|² + |γ|² + |δ|² = 1

        let conservativeSuccess = history.conservativeSuccessRate
        let moderateSuccess = history.moderateSuccessRate
        let aggressiveSuccess = history.aggressiveSuccessRate
        let quantumSuccess = history.quantumSuccessRate

        let total = conservativeSuccess + moderateSuccess + aggressiveSuccess + quantumSuccess
        let normalization = total > 0 ? sqrt(total) : 1.0

        return QuantumAmplitudes(
            conservative: sqrt(conservativeSuccess) / normalization,
            moderate: sqrt(moderateSuccess) / normalization,
            aggressive: sqrt(aggressiveSuccess) / normalization,
            quantum: sqrt(quantumSuccess) / normalization
        )
    }

    private func collapseToOptimal(_ evaluations: [StrategyEvaluation]) -> QuantumHealingStrategy {
        // Quantum measurement: probability of selection = |amplitude|²
        var totalProbability: Float = 0
        var weightedScores: [(strategy: QuantumHealingStrategy, cumulativeProb: Float)] = []

        for eval in evaluations {
            let probability = eval.strategy.amplitude * eval.strategy.amplitude * eval.score
            totalProbability += probability
            weightedScores.append((eval.strategy, totalProbability))
        }

        // Collapse: select based on quantum probability
        let randomValue = Float.random(in: 0...totalProbability)
        for (strategy, cumulativeProb) in weightedScores {
            if randomValue <= cumulativeProb {
                return strategy
            }
        }

        return evaluations.max(by: { $0.score < $1.score })?.strategy ?? evaluations[0].strategy
    }

    // MARK: - ML-Based Predictive Healing

    /// Machine Learning based error prediction and preemptive healing
    func mlPredictiveHealing() async -> [MLPredictedAction] {
        var actions: [MLPredictedAction] = []

        // Collect system features
        let features = await collectSystemFeatures()

        // Run prediction model
        let predictions = await runMLPrediction(features: features)

        // Generate preemptive actions
        for prediction in predictions where prediction.confidence > 0.7 {
            let action = generatePreemptiveAction(for: prediction)
            actions.append(action)
        }

        return actions
    }

    private func collectSystemFeatures() async -> MLSystemFeatures {
        return MLSystemFeatures(
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            batteryLevel: getCurrentBatteryLevel(),
            thermalState: getCurrentThermalState(),
            networkLatency: getCurrentNetworkLatency(),
            audioBufferFill: getCurrentAudioBufferFill(),
            frameDropRate: getCurrentFrameDropRate(),
            healingEventFrequency: getRecentHealingEventFrequency(),
            flowStateHistory: getRecentFlowStateHistory(),
            timeOfDay: getCurrentTimeOfDay(),
            sessionDuration: getCurrentSessionDuration()
        )
    }

    private func runMLPrediction(features: MLSystemFeatures) async -> [MLErrorPrediction] {
        // Neural network-like prediction using weighted feature analysis
        var predictions: [MLErrorPrediction] = []

        // Memory pressure prediction
        let memoryScore = features.memoryUsage * 0.4 +
                          features.sessionDuration / 3600 * 0.3 +
                          features.healingEventFrequency * 0.3
        if memoryScore > 0.6 {
            predictions.append(MLErrorPrediction(
                errorType: .memoryPressure,
                confidence: memoryScore,
                timeToError: TimeInterval(120 * (1 - memoryScore)),
                suggestedAction: .preemptiveMemoryCleanup
            ))
        }

        // CPU overload prediction
        let cpuScore = features.cpuUsage * 0.5 +
                       features.thermalState.rawValue / 3.0 * 0.3 +
                       features.audioBufferFill * 0.2
        if cpuScore > 0.7 {
            predictions.append(MLErrorPrediction(
                errorType: .cpuOverload,
                confidence: Float(cpuScore),
                timeToError: TimeInterval(60 * (1 - cpuScore)),
                suggestedAction: .reduceProcessingLoad
            ))
        }

        // Audio dropout prediction
        let audioScore = features.audioBufferFill * 0.5 +
                         features.cpuUsage * 0.3 +
                         features.frameDropRate * 0.2
        if audioScore > 0.65 {
            predictions.append(MLErrorPrediction(
                errorType: .audioDropout,
                confidence: Float(audioScore),
                timeToError: TimeInterval(30 * (1 - audioScore)),
                suggestedAction: .increaseAudioBuffer
            ))
        }

        // Thermal throttling prediction
        let thermalScore = features.thermalState.rawValue / 3.0 * 0.6 +
                           features.cpuUsage * 0.2 +
                           features.sessionDuration / 7200 * 0.2
        if thermalScore > 0.5 {
            predictions.append(MLErrorPrediction(
                errorType: .thermalThrottling,
                confidence: Float(thermalScore),
                timeToError: TimeInterval(180 * (1 - thermalScore)),
                suggestedAction: .activateThermalManagement
            ))
        }

        return predictions.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Thermal Management

/// Thermal-aware optimization system
class ThermalManagementEngine: ObservableObject {

    @Published var thermalState: ThermalState = .nominal
    @Published var thermalHeadroom: Float = 1.0
    @Published var throttlingActive: Bool = false

    private var thermalHistory: [ThermalSample] = []
    private var predictionModel: ThermalPredictionModel?

    init() {
        setupThermalMonitoring()
        predictionModel = ThermalPredictionModel()
    }

    private func setupThermalMonitoring() {
        #if os(iOS)
        // Monitor iOS thermal state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        #endif

        // Continuous monitoring
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateThermalState()
        }
    }

    @objc private func thermalStateChanged(_ notification: Notification) {
        Task { @MainActor in
            updateThermalState()
        }
    }

    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState

        thermalState = ThermalState(from: state)
        thermalHistory.append(ThermalSample(state: thermalState, timestamp: Date()))

        // Keep 1 hour of history
        let oneHourAgo = Date().addingTimeInterval(-3600)
        thermalHistory.removeAll { $0.timestamp < oneHourAgo }

        // Calculate headroom
        thermalHeadroom = calculateThermalHeadroom()

        // Predict throttling
        predictThrottling()
    }

    private func calculateThermalHeadroom() -> Float {
        switch thermalState {
        case .nominal: return 1.0
        case .fair: return 0.75
        case .serious: return 0.4
        case .critical: return 0.1
        }
    }

    private func predictThrottling() {
        guard let prediction = predictionModel?.predict(history: thermalHistory) else {
            return
        }

        if prediction.throttlingProbability > 0.7 {
            throttlingActive = true
            applyPreemptiveCooling()
        } else {
            throttlingActive = false
        }
    }

    private func applyPreemptiveCooling() {
        // Reduce processing to prevent thermal throttling
        NotificationCenter.default.post(
            name: .thermalPreemptiveCooling,
            object: ThermalCoolingAction(reductionFactor: 1.0 - thermalHeadroom)
        )
    }

    /// Get recommended processing level based on thermal state
    func getRecommendedProcessingLevel() -> Float {
        return thermalHeadroom * (throttlingActive ? 0.7 : 1.0)
    }
}

// MARK: - Network-Adaptive Optimization

/// Network-aware adaptive optimization for cloud sync and streaming
class NetworkAdaptiveEngine: ObservableObject {

    @Published var networkQuality: NetworkQuality = .good
    @Published var latencyMs: Double = 0
    @Published var bandwidthMbps: Double = 0
    @Published var packetLossPercent: Float = 0

    private var latencyHistory: [Double] = []
    private var bandwidthHistory: [Double] = []

    private let pingQueue = DispatchQueue(label: "network.ping", qos: .utility)

    init() {
        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.measureNetworkQuality()
            }
        }
    }

    func measureNetworkQuality() async {
        // Measure latency
        let latency = await measureLatency()
        latencyMs = latency
        latencyHistory.append(latency)
        if latencyHistory.count > 100 {
            latencyHistory.removeFirst()
        }

        // Estimate bandwidth (based on recent transfers)
        let bandwidth = estimateBandwidth()
        bandwidthMbps = bandwidth
        bandwidthHistory.append(bandwidth)
        if bandwidthHistory.count > 100 {
            bandwidthHistory.removeFirst()
        }

        // Calculate packet loss from latency variance
        packetLossPercent = estimatePacketLoss()

        // Update network quality
        networkQuality = calculateNetworkQuality()
    }

    private func measureLatency() async -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Ping a reliable endpoint
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else {
            return 999
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                return (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            }
        } catch {
            return 999
        }

        return 999
    }

    private func estimateBandwidth() -> Double {
        // Estimate based on latency (inverse relationship)
        let avgLatency = latencyHistory.isEmpty ? 50 : latencyHistory.reduce(0, +) / Double(latencyHistory.count)

        // Rough estimation: lower latency = higher bandwidth
        if avgLatency < 20 { return 100 }
        if avgLatency < 50 { return 50 }
        if avgLatency < 100 { return 20 }
        if avgLatency < 200 { return 10 }
        return 5
    }

    private func estimatePacketLoss() -> Float {
        guard latencyHistory.count >= 10 else { return 0 }

        // High variance in latency indicates packet loss/retransmission
        let mean = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        let variance = latencyHistory.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(latencyHistory.count)
        let stdDev = sqrt(variance)

        // Coefficient of variation
        let cv = stdDev / mean

        // Map CV to estimated packet loss
        return Float(min(cv * 10, 50))  // Cap at 50%
    }

    private func calculateNetworkQuality() -> NetworkQuality {
        if latencyMs < 30 && packetLossPercent < 1 {
            return .excellent
        } else if latencyMs < 100 && packetLossPercent < 5 {
            return .good
        } else if latencyMs < 300 && packetLossPercent < 15 {
            return .fair
        } else {
            return .poor
        }
    }

    /// Get recommended sync strategy based on network quality
    func getRecommendedSyncStrategy() -> SyncStrategy {
        switch networkQuality {
        case .excellent:
            return SyncStrategy(
                syncInterval: 5,
                compressionLevel: .none,
                deltaSync: false,
                offlineBuffer: 10
            )
        case .good:
            return SyncStrategy(
                syncInterval: 15,
                compressionLevel: .low,
                deltaSync: true,
                offlineBuffer: 30
            )
        case .fair:
            return SyncStrategy(
                syncInterval: 60,
                compressionLevel: .high,
                deltaSync: true,
                offlineBuffer: 120
            )
        case .poor:
            return SyncStrategy(
                syncInterval: 300,
                compressionLevel: .maximum,
                deltaSync: true,
                offlineBuffer: 600
            )
        }
    }
}

// MARK: - Universal Cross-Platform Core

/// Universal feature detection and platform-specific optimization
@MainActor
class UniversalPlatformCore: ObservableObject {

    @Published var currentPlatform: Platform = .unknown
    @Published var capabilities: PlatformCapabilities = PlatformCapabilities()
    @Published var optimizationProfile: OptimizationProfile = .balanced

    static let shared = UniversalPlatformCore()

    private init() {
        detectPlatform()
        detectCapabilities()
        selectOptimizationProfile()
    }

    private func detectPlatform() {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            currentPlatform = .iPad
        } else {
            currentPlatform = .iPhone
        }
        #elseif os(macOS)
        currentPlatform = .macOS
        #elseif os(watchOS)
        currentPlatform = .watchOS
        #elseif os(tvOS)
        currentPlatform = .tvOS
        #elseif os(visionOS)
        currentPlatform = .visionOS
        #elseif os(Linux)
        currentPlatform = .linux
        #elseif os(Windows)
        currentPlatform = .windows
        #elseif os(Android)
        currentPlatform = .android
        #else
        currentPlatform = .unknown
        #endif
    }

    private func detectCapabilities() {
        capabilities = PlatformCapabilities(
            // Hardware
            hasGPU: detectGPU(),
            gpuType: detectGPUType(),
            hasSIMD: true,  // All modern platforms
            hasNeuralEngine: detectNeuralEngine(),
            coreCount: ProcessInfo.processInfo.processorCount,
            memoryGB: Float(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000,

            // Audio
            hasLowLatencyAudio: detectLowLatencyAudio(),
            maxAudioChannels: detectMaxAudioChannels(),
            supportsSpatialAudio: detectSpatialAudioSupport(),
            supportsHRTF: detectHRTFSupport(),

            // Display
            maxRefreshRate: detectMaxRefreshRate(),
            supportsHDR: detectHDRSupport(),
            supportsProMotion: detectProMotionSupport(),

            // Sensors
            hasHeartRateSensor: detectHeartRateSensor(),
            hasAccelerometer: detectAccelerometer(),
            hasGyroscope: detectGyroscope(),
            hasFaceTracking: detectFaceTracking(),
            hasHandTracking: detectHandTracking(),

            // Platform-specific
            supportsBackgroundAudio: detectBackgroundAudioSupport(),
            supportsMultitasking: detectMultitaskingSupport(),
            supportsExternalDisplay: detectExternalDisplaySupport()
        )
    }

    private func selectOptimizationProfile() {
        // Select based on capabilities
        if capabilities.hasNeuralEngine && capabilities.coreCount >= 6 && capabilities.memoryGB >= 6 {
            optimizationProfile = .performance
        } else if capabilities.memoryGB < 3 || capabilities.coreCount < 4 {
            optimizationProfile = .efficiency
        } else {
            optimizationProfile = .balanced
        }
    }

    /// Get optimal audio buffer size for platform
    func getOptimalAudioBufferSize() -> Int {
        switch currentPlatform {
        case .iPhone, .iPad:
            return capabilities.hasLowLatencyAudio ? 128 : 256
        case .macOS:
            return 256
        case .watchOS:
            return 512
        case .visionOS:
            return 128
        case .android:
            return 512
        case .windows, .linux:
            return 256
        default:
            return 512
        }
    }

    /// Get optimal visual settings for platform
    func getOptimalVisualSettings() -> VisualSettings {
        VisualSettings(
            targetFrameRate: Int(detectMaxRefreshRate()),
            renderScale: optimizationProfile == .efficiency ? 0.75 : 1.0,
            particleCount: optimizationProfile == .performance ? 10000 : 5000,
            shadowQuality: optimizationProfile == .efficiency ? .low : .high,
            antiAliasing: optimizationProfile == .efficiency ? .none : .msaa4x
        )
    }

    // MARK: - Detection Methods

    private func detectGPU() -> Bool {
        #if canImport(Metal)
        return MTLCreateSystemDefaultDevice() != nil
        #else
        return false
        #endif
    }

    private func detectGPUType() -> GPUType {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else { return .unknown }
        let name = device.name.lowercased()
        if name.contains("m1") || name.contains("m2") || name.contains("m3") || name.contains("m4") {
            return .appleSilicon
        } else if name.contains("a1") {
            return .appleGPU
        } else if name.contains("intel") {
            return .intelIntegrated
        } else if name.contains("amd") || name.contains("radeon") {
            return .amdDiscrete
        } else if name.contains("nvidia") || name.contains("geforce") {
            return .nvidiaDiscrete
        }
        return .unknown
        #else
        return .unknown
        #endif
    }

    private func detectNeuralEngine() -> Bool {
        #if os(iOS) || os(macOS)
        if #available(iOS 15.0, macOS 12.0, *) {
            return true  // All A11+ and M1+ have Neural Engine
        }
        #endif
        return false
    }

    private func detectLowLatencyAudio() -> Bool {
        #if os(iOS)
        return true  // All modern iOS devices
        #elseif os(macOS)
        return true
        #else
        return false
        #endif
    }

    private func detectMaxAudioChannels() -> Int {
        #if os(iOS) || os(macOS)
        return 8  // Spatial audio
        #else
        return 2
        #endif
    }

    private func detectSpatialAudioSupport() -> Bool {
        #if os(iOS)
        if #available(iOS 15.0, *) { return true }
        #elseif os(macOS)
        if #available(macOS 12.0, *) { return true }
        #elseif os(visionOS)
        return true
        #endif
        return false
    }

    private func detectHRTFSupport() -> Bool {
        return detectSpatialAudioSupport()
    }

    private func detectMaxRefreshRate() -> Float {
        #if os(iOS)
        return 120  // ProMotion
        #elseif os(macOS)
        return 120
        #elseif os(visionOS)
        return 90
        #else
        return 60
        #endif
    }

    private func detectHDRSupport() -> Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }

    private func detectProMotionSupport() -> Bool {
        #if os(iOS)
        return UIScreen.main.maximumFramesPerSecond >= 120
        #else
        return false
        #endif
    }

    private func detectHeartRateSensor() -> Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }

    private func detectAccelerometer() -> Bool {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }

    private func detectGyroscope() -> Bool {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }

    private func detectFaceTracking() -> Bool {
        #if os(iOS)
        return ARFaceTrackingConfiguration.isSupported
        #elseif os(visionOS)
        return true
        #else
        return false
        #endif
    }

    private func detectHandTracking() -> Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }

    private func detectBackgroundAudioSupport() -> Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }

    private func detectMultitaskingSupport() -> Bool {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad { return true }
        #elseif os(macOS)
        return true
        #endif
        return false
    }

    private func detectExternalDisplaySupport() -> Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Supporting Types

struct QuantumHealingStrategy {
    let type: StrategyType
    let amplitude: Float  // Quantum amplitude coefficient
    let actions: [HealingAction]

    enum StrategyType {
        case conservative
        case moderate
        case aggressive
        case quantum
    }
}

struct QuantumAmplitudes {
    let conservative: Float
    let moderate: Float
    let aggressive: Float
    let quantum: Float
}

struct QuantumHealingResult {
    let success: Bool
    let strategy: QuantumHealingStrategy
    let energyUsed: Float
    let effectivenessScore: Float
}

struct StrategyEvaluation {
    let strategy: QuantumHealingStrategy
    let score: Float
}

struct HealingAction {
    let type: ActionType
    let parameter: Float

    enum ActionType {
        case reduceQuality
        case increaseBuffer
        case clearCache
        case throttleCPU
        case disableFeature
        case restartSubsystem
    }
}

struct MLSystemFeatures {
    var cpuUsage: Float
    var memoryUsage: Float
    var batteryLevel: Float
    var thermalState: ThermalState
    var networkLatency: Double
    var audioBufferFill: Float
    var frameDropRate: Float
    var healingEventFrequency: Float
    var flowStateHistory: [FlowState]
    var timeOfDay: Float
    var sessionDuration: TimeInterval
}

struct MLErrorPrediction {
    let errorType: ErrorType
    let confidence: Float
    let timeToError: TimeInterval
    let suggestedAction: MLPredictedAction
}

enum MLPredictedAction {
    case preemptiveMemoryCleanup
    case reduceProcessingLoad
    case increaseAudioBuffer
    case activateThermalManagement
    case enableNetworkCaching
    case reduceSyncFrequency
}

enum ThermalState: Int {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    init(from processInfoState: ProcessInfo.ThermalState) {
        switch processInfoState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

struct ThermalSample {
    let state: ThermalState
    let timestamp: Date
}

struct ThermalCoolingAction {
    let reductionFactor: Float
}

class ThermalPredictionModel {
    func predict(history: [ThermalSample]) -> ThermalPrediction? {
        guard history.count >= 10 else { return nil }

        // Calculate trend
        let recentSamples = history.suffix(10)
        let avgState = Float(recentSamples.map { $0.state.rawValue }.reduce(0, +)) / Float(recentSamples.count)
        let trend = avgState / 3.0

        return ThermalPrediction(
            throttlingProbability: trend,
            timeToThrottling: TimeInterval((1.0 - trend) * 300)
        )
    }
}

struct ThermalPrediction {
    let throttlingProbability: Float
    let timeToThrottling: TimeInterval
}

enum NetworkQuality {
    case excellent
    case good
    case fair
    case poor
}

struct SyncStrategy {
    let syncInterval: TimeInterval
    let compressionLevel: CompressionLevel
    let deltaSync: Bool
    let offlineBuffer: TimeInterval

    enum CompressionLevel {
        case none, low, high, maximum
    }
}

enum Platform {
    case iPhone, iPad, macOS, watchOS, tvOS, visionOS
    case android, windows, linux
    case unknown
}

struct PlatformCapabilities {
    // Hardware
    var hasGPU: Bool = false
    var gpuType: GPUType = .unknown
    var hasSIMD: Bool = false
    var hasNeuralEngine: Bool = false
    var coreCount: Int = 1
    var memoryGB: Float = 2

    // Audio
    var hasLowLatencyAudio: Bool = false
    var maxAudioChannels: Int = 2
    var supportsSpatialAudio: Bool = false
    var supportsHRTF: Bool = false

    // Display
    var maxRefreshRate: Float = 60
    var supportsHDR: Bool = false
    var supportsProMotion: Bool = false

    // Sensors
    var hasHeartRateSensor: Bool = false
    var hasAccelerometer: Bool = false
    var hasGyroscope: Bool = false
    var hasFaceTracking: Bool = false
    var hasHandTracking: Bool = false

    // Platform-specific
    var supportsBackgroundAudio: Bool = false
    var supportsMultitasking: Bool = false
    var supportsExternalDisplay: Bool = false
}

enum GPUType {
    case appleSilicon
    case appleGPU
    case intelIntegrated
    case amdDiscrete
    case nvidiaDiscrete
    case unknown
}

enum OptimizationProfile {
    case performance
    case balanced
    case efficiency
}

struct VisualSettings {
    var targetFrameRate: Int
    var renderScale: Double
    var particleCount: Int
    var shadowQuality: ShadowQuality
    var antiAliasing: AntiAliasing

    enum ShadowQuality { case low, medium, high }
    enum AntiAliasing { case none, msaa2x, msaa4x, msaa8x }
}

// MARK: - Notifications

extension Notification.Name {
    static let thermalPreemptiveCooling = Notification.Name("thermalPreemptiveCooling")
    static let networkQualityChanged = Notification.Name("networkQualityChanged")
    static let platformCapabilitiesUpdated = Notification.Name("platformCapabilitiesUpdated")
}

// MARK: - ARKit Import for Face Tracking Detection

#if os(iOS)
import ARKit
#endif

#if canImport(Metal)
import Metal
#endif

#if os(iOS)
import UIKit
#endif
