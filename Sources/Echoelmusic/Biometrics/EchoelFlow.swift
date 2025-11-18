// EchoelFlow.swift
// Universal Biometric Data Flow Coordinator
// Master integration hub for all Echoel biometric systems
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

import Foundation
import Combine

/// Unified biometric data stream (all sensors combined)
public struct EchoelBioData {
    // Vision System (EchoelVision™)
    public var gazePosition: SIMD2<Float> = [0.5, 0.5]  // Screen coordinates (0-1, 0-1)
    public var pupilDiameter: Float = 4.5               // mm (2-8mm range)
    public var blinkRate: Float = 15                    // blinks/minute
    public var focusLevel: Float = 0                    // 0-100 (dwell time analysis)

    // Neural System (EchoelMind™)
    public var delta: Float = 0                         // 0.5-4 Hz (deep sleep)
    public var theta: Float = 0                         // 4-8 Hz (meditation, creativity)
    public var alpha: Float = 0                         // 8-13 Hz (relaxed awareness)
    public var beta: Float = 0                          // 13-30 Hz (active thinking)
    public var gamma: Float = 0                         // 30-100 Hz (peak performance)
    public var meditation: Float = 0                    // 0-100 (calmness)
    public var attention: Float = 0                     // 0-100 (focus)

    // Cardiac System (EchoelHeart™)
    public var heartRate: Float = 70                    // BPM (40-200)
    public var hrvRMSSD: Float = 50                     // HRV in ms (20-100+)
    public var coherence: Float = 50                    // 0-100 (HeartMath score)
    public var lfhfRatio: Float = 1.5                   // Stress indicator (0.5-3.0)

    // Respiratory System (EchoelBreath™)
    public var breathRate: Float = 14                   // breaths/minute (8-20)
    public var breathDepth: Float = 50                  // 0-100 (relative)
    public var breathCoherence: Float = 50              // 0-100 (rhythm quality)

    // Dermal System (EchoelSkin™)
    public var skinConductance: Float = 5               // μS (microsiemens)
    public var arousalLevel: Float = 50                 // 0-100 (emotional arousal)
    public var stressIndex: Float = 50                  // 0-100 (stress level)

    // Sleep & Recovery (EchoelRing™)
    public var sleepScore: Float = 0                    // 0-100 (Oura score)
    public var readinessScore: Float = 0                // 0-100 (recovery)
    public var bodyTemperature: Float = 0               // °C deviation from baseline
    public var restingHR: Float = 60                    // BPM (resting)

    // Motion System (EchoelMotion™)
    public var headPosition: SIMD3<Float> = [0, 0, 0]   // 3D space
    public var handPosition: SIMD3<Float> = [0, 0, 0]   // 3D space
    public var gestureConfidence: Float = 0             // 0-100

    // Environment (EchoelEnvironment™)
    public var ambientLight: Float = 300                // Lux (0-100000)
    public var ambientNoise: Float = 40                 // dB (0-120)
    public var temperature: Float = 22                  // °C
    public var airQuality: Float = 50                   // 0-500 (AQI)

    // Metadata
    public var timestamp: UInt64 = 0                    // μs since epoch
    public var confidence: Float = 100                  // 0-100 (data quality)
    public var deviceID: String = "EchoelFlow"          // Source identifier

    public init() {}
}

/// Overall physiological state classification
public enum PhysiologicalState: String {
    case peak = "Peak Performance"                      // All systems optimal
    case focused = "Deep Focus"                         // High attention, low stress
    case creative = "Creative Flow"                     // Theta/alpha dominant
    case relaxed = "Relaxed"                            // Low arousal, balanced
    case stressed = "Stressed"                          // High sympathetic
    case fatigued = "Fatigued"                          // Low energy, poor recovery
    case recovering = "Recovering"                      // Post-exercise recovery
    case meditative = "Meditative"                      // Deep calm state

    var description: String {
        return self.rawValue
    }

    var audioProfile: [String: Float] {
        switch self {
        case .peak:
            return ["energy": 1.0, "clarity": 0.9, "complexity": 0.8]
        case .focused:
            return ["energy": 0.7, "clarity": 1.0, "complexity": 0.5]
        case .creative:
            return ["energy": 0.6, "clarity": 0.7, "complexity": 1.0]
        case .relaxed:
            return ["energy": 0.4, "clarity": 0.6, "complexity": 0.4]
        case .stressed:
            return ["energy": 0.3, "clarity": 0.4, "complexity": 0.2]
        case .fatigued:
            return ["energy": 0.2, "clarity": 0.3, "complexity": 0.1]
        case .recovering:
            return ["energy": 0.5, "clarity": 0.5, "complexity": 0.3]
        case .meditative:
            return ["energy": 0.2, "clarity": 0.8, "complexity": 0.6]
        }
    }
}

/// EchoelFlow™ - Master Biometric Coordinator
public class EchoelFlowManager {

    public static let shared = EchoelFlowManager()

    // MARK: - Properties

    private var bioDataPublisher = PassthroughSubject<EchoelBioData, Never>()
    private var statePublisher = PassthroughSubject<PhysiologicalState, Never>()

    private var currentBioData = EchoelBioData()
    private var currentState: PhysiologicalState = .relaxed

    private var cancellables = Set<AnyCancellable>()

    private var isActive = false

    // MARK: - Configuration

    public var updateInterval: TimeInterval = 1.0 / 30.0  // 30 Hz default

    private init() {
        setupDataFlow()
    }

    // MARK: - Data Flow Setup

    private func setupDataFlow() {
        #if os(iOS)
        // Subscribe to EchoelVision updates
        if #available(iOS 14.0, *) {
            EchoelVisionManager.shared.subscribeToMetrics()
                .sink { [weak self] eyeMetrics in
                    self?.updateVisionData(eyeMetrics)
                }
                .store(in: &cancellables)
        }
        #endif

        // Subscribe to EchoelMind updates
        EchoelMindManager.shared.subscribeToMetrics()
            .sink { [weak self] neuralMetrics in
                self?.updateNeuralData(neuralMetrics)
            }
            .store(in: &cancellables)

        // Subscribe to EchoelRing updates
        EchoelRingManager.shared.subscribeToSleepData()
            .sink { [weak self] sleepData in
                self?.updateSleepData(sleepData)
            }
            .store(in: &cancellables)

        EchoelRingManager.shared.subscribeToReadinessData()
            .sink { [weak self] readinessData in
                self?.updateReadinessData(readinessData)
            }
            .store(in: &cancellables)

        print("[EchoelFlow] Data flow initialized")
    }

    // MARK: - Start/Stop

    /// Start biometric data flow
    public func start() {
        guard !isActive else { return }

        isActive = true

        // Start all subsystems
        #if os(iOS)
        if #available(iOS 14.0, *) {
            EchoelVisionManager.shared.startTracking()
        }
        #endif

        EchoelMindManager.shared.startMonitoring()
        EchoelRingManager.shared.fetchTodaysData()

        // Start periodic updates
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            self.publishUpdate()
        }

        print("[EchoelFlow] Biometric flow started")
    }

    /// Stop biometric data flow
    public func stop() {
        guard isActive else { return }

        isActive = false

        // Stop all subsystems
        #if os(iOS)
        if #available(iOS 14.0, *) {
            EchoelVisionManager.shared.stopTracking()
        }
        #endif

        EchoelMindManager.shared.stopMonitoring()

        print("[EchoelFlow] Biometric flow stopped")
    }

    // MARK: - Data Updates

    private func updateVisionData(_ metrics: EyeMetrics) {
        currentBioData.gazePosition = SIMD2<Float>(metrics.gazeX, metrics.gazeY)
        currentBioData.pupilDiameter = metrics.pupilDiameter
        currentBioData.blinkRate = metrics.blinkRate
        currentBioData.focusLevel = metrics.cognitiveLoad
    }

    private func updateNeuralData(_ metrics: NeuralMetrics) {
        currentBioData.delta = metrics.bands.delta * 100
        currentBioData.theta = metrics.bands.theta * 100
        currentBioData.alpha = metrics.bands.alpha * 100
        currentBioData.beta = metrics.bands.beta * 100
        currentBioData.gamma = metrics.bands.gamma * 100
        currentBioData.meditation = metrics.meditation
        currentBioData.attention = metrics.attention
    }

    private func updateSleepData(_ sleepData: OuraSleepData) {
        currentBioData.sleepScore = sleepData.sleepScore
        currentBioData.restingHR = sleepData.lowestRestingHR
    }

    private func updateReadinessData(_ readinessData: OuraReadinessData) {
        currentBioData.readinessScore = readinessData.readinessScore
        currentBioData.bodyTemperature = readinessData.bodyTemperature
    }

    private func publishUpdate() {
        currentBioData.timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)

        // Classify overall state
        currentState = classifyPhysiologicalState()

        // Publish updates
        bioDataPublisher.send(currentBioData)
        statePublisher.send(currentState)
    }

    // MARK: - State Classification

    private func classifyPhysiologicalState() -> PhysiologicalState {
        let bio = currentBioData

        // Peak Performance: High gamma, high coherence, low stress, good recovery
        if bio.gamma > 70 && bio.coherence > 70 && bio.stressIndex < 30 && bio.readinessScore > 80 {
            return .peak
        }

        // Deep Focus: High beta/attention, low theta, stable HR
        if bio.attention > 70 && bio.beta > 60 && bio.theta < 40 {
            return .focused
        }

        // Creative Flow: Alpha-theta dominance, moderate coherence
        if bio.alpha > 60 && bio.theta > 50 && abs(bio.alpha - bio.theta) < 20 {
            return .creative
        }

        // Meditative: High alpha, high meditation score, low heart rate
        if bio.alpha > 70 && bio.meditation > 70 && bio.heartRate < 65 {
            return .meditative
        }

        // Stressed: High beta, high LF/HF ratio, high stress index
        if bio.beta > 70 && bio.lfhfRatio > 2.0 && bio.stressIndex > 70 {
            return .stressed
        }

        // Fatigued: Low readiness, high resting HR, low sleep score
        if bio.readinessScore < 40 || bio.sleepScore < 50 || bio.blinkRate > 25 {
            return .fatigued
        }

        // Recovering: Moderate readiness, balanced metrics
        if bio.readinessScore > 50 && bio.readinessScore < 70 {
            return .recovering
        }

        // Default: Relaxed
        return .relaxed
    }

    // MARK: - Subscriptions

    /// Subscribe to unified biometric data stream
    public func subscribeToBioData() -> AnyPublisher<EchoelBioData, Never> {
        return bioDataPublisher.eraseToAnyPublisher()
    }

    /// Subscribe to physiological state changes
    public func subscribeToState() -> AnyPublisher<PhysiologicalState, Never> {
        return statePublisher.eraseToAnyPublisher()
    }

    /// Get current biometric data
    public func getCurrentBioData() -> EchoelBioData {
        return currentBioData
    }

    /// Get current physiological state
    public func getCurrentState() -> PhysiologicalState {
        return currentState
    }

    // MARK: - Audio Parameter Mapping

    /// Map unified biometric data to comprehensive audio parameters
    public func mapToAudioParameters() -> [String: Float] {
        let bio = currentBioData
        let state = currentState

        // Get base profile from state
        let profile = state.audioProfile

        return [
            // Master controls from physiological state
            "master_energy": profile["energy"] ?? 0.5,
            "master_clarity": profile["clarity"] ?? 0.5,
            "master_complexity": profile["complexity"] ?? 0.5,

            // Vision-based controls
            "stereo_pan": bio.gazePosition.x * 2.0 - 1.0,                    // -1 to 1
            "filter_cutoff": 200 + (bio.gazePosition.y * 18000),             // 200-18200 Hz
            "reverb_size": bio.pupilDiameter / 8.0,                          // 0-1

            // Neural-based controls
            "meditation_reverb": bio.meditation / 100.0,
            "attention_compression": 1.0 + (bio.attention / 50.0),           // 1-3 ratio
            "creativity_modulation": bio.theta / 100.0,
            "focus_clarity": bio.beta / 100.0,
            "peak_performance": bio.gamma / 100.0,

            // Cardiac-based controls
            "hrv_filter_mod": bio.hrvRMSSD / 100.0,
            "coherence_harmony": bio.coherence / 100.0,
            "heart_rate_tempo": bio.heartRate,                               // BPM for sync

            // Recovery-based controls
            "sleep_quality": bio.sleepScore / 100.0,
            "readiness_level": bio.readinessScore / 100.0,

            // Stress indicators (inverse controls)
            "stress_reduction": max(0, 1.0 - (bio.stressIndex / 100.0)),
            "fatigue_filter": max(0, 1.0 - (bio.blinkRate / 30.0)),

            // Environmental controls
            "ambient_brightness": bio.ambientLight / 1000.0,                 // Normalized
            "ambient_noise_gate": bio.ambientNoise / 120.0,

            // Confidence weighting
            "data_confidence": bio.confidence / 100.0,
        ]
    }

    // MARK: - Wellness Insights

    /// Get wellness recommendations based on current data
    public func getWellnessInsights() -> [String] {
        var insights: [String] = []
        let bio = currentBioData

        // Sleep insights
        if bio.sleepScore < 60 {
            insights.append("💤 Low sleep score (\(Int(bio.sleepScore))). Consider earlier bedtime.")
        }

        // Recovery insights
        if bio.readinessScore < 50 {
            insights.append("⚡ Low readiness (\(Int(bio.readinessScore))). Take it easy today.")
        }

        // Stress insights
        if bio.stressIndex > 70 {
            insights.append("😰 High stress detected. Try breathing exercises or meditation.")
        }

        // Focus insights
        if bio.attention < 40 && bio.beta < 40 {
            insights.append("🎯 Low focus detected. Consider a short break or coffee.")
        }

        // HRV insights
        if bio.hrvRMSSD < 30 {
            insights.append("❤️ Low HRV. Practice coherence breathing (5.5 breaths/min).")
        }

        // Positive insights
        if bio.coherence > 80 {
            insights.append("✨ Excellent coherence! You're in the zone.")
        }

        if bio.readinessScore > 85 {
            insights.append("🚀 Great recovery! Perfect day for peak performance.")
        }

        if insights.isEmpty {
            insights.append("✅ All metrics looking good. Keep it up!")
        }

        return insights
    }

    // MARK: - Data Export

    /// Export current biometric data as JSON
    public func exportAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            // Create dictionary representation
            let dict: [String: Any] = [
                "timestamp": currentBioData.timestamp,
                "state": currentState.rawValue,
                "vision": [
                    "gaze_x": currentBioData.gazePosition.x,
                    "gaze_y": currentBioData.gazePosition.y,
                    "pupil_diameter": currentBioData.pupilDiameter,
                    "blink_rate": currentBioData.blinkRate,
                    "focus_level": currentBioData.focusLevel,
                ],
                "neural": [
                    "delta": currentBioData.delta,
                    "theta": currentBioData.theta,
                    "alpha": currentBioData.alpha,
                    "beta": currentBioData.beta,
                    "gamma": currentBioData.gamma,
                    "meditation": currentBioData.meditation,
                    "attention": currentBioData.attention,
                ],
                "cardiac": [
                    "heart_rate": currentBioData.heartRate,
                    "hrv_rmssd": currentBioData.hrvRMSSD,
                    "coherence": currentBioData.coherence,
                    "lf_hf_ratio": currentBioData.lfhfRatio,
                ],
                "sleep": [
                    "sleep_score": currentBioData.sleepScore,
                    "readiness_score": currentBioData.readinessScore,
                    "resting_hr": currentBioData.restingHR,
                ],
            ]

            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print("[EchoelFlow] JSON export failed: \(error)")
            return nil
        }
    }
}

/// Group biometric synchronization for collaborative sessions
public class GroupCoherenceSync {

    private var participants: [String: EchoelBioData] = [:]

    /// Add participant's biometric data
    public func addParticipant(id: String, data: EchoelBioData) {
        participants[id] = data
    }

    /// Get group coherence score (0-100)
    public func getGroupCoherence() -> Float {
        guard participants.count > 1 else { return 0 }

        // Calculate average HRV coherence across all participants
        let coherenceScores = participants.values.map { $0.coherence }
        let avgCoherence = coherenceScores.reduce(0, +) / Float(coherenceScores.count)

        // Calculate variance (lower = more synchronized)
        let variance = coherenceScores.map { pow($0 - avgCoherence, 2) }.reduce(0, +) / Float(coherenceScores.count)
        let synchronization = max(0, 100 - variance)

        return (avgCoherence + synchronization) / 2.0
    }

    /// Get optimal tempo for group (average heart rate)
    public func getOptimalTempo() -> Float {
        guard !participants.isEmpty else { return 120 }

        let heartRates = participants.values.map { $0.heartRate }
        return heartRates.reduce(0, +) / Float(heartRates.count)
    }

    /// Get collective emotional state
    public func getCollectiveState() -> PhysiologicalState {
        guard !participants.isEmpty else { return .relaxed }

        // Simplified: use most common state
        let states = participants.values.map { data -> PhysiologicalState in
            // Classify each participant
            if data.gamma > 70 && data.coherence > 70 {
                return .peak
            } else if data.meditation > 70 {
                return .meditative
            } else if data.stressIndex > 70 {
                return .stressed
            }
            return .relaxed
        }

        // Find most common
        let stateFrequency = Dictionary(grouping: states, by: { $0 }).mapValues { $0.count }
        return stateFrequency.max(by: { $0.value < $1.value })?.key ?? .relaxed
    }
}
