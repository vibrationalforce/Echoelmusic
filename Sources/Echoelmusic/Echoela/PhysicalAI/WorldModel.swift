// WorldModel.swift
// Echoelmusic - Echoela Physical AI
//
// JEPA-inspired World Model for bio-reactive state prediction
// Based on Yann LeCun's Joint Embedding Predictive Architecture concept
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import Accelerate

// MARK: - World State

/// Represents the current state of the bio-reactive world
public struct WorldState: Codable, Sendable {
    public let timestamp: Date
    public let biometrics: BiometricState
    public let performance: PerformanceState
    public let environment: EnvironmentState
    public let confidence: Float

    public struct BiometricState: Codable, Sendable {
        public var heartRate: Float          // BPM
        public var hrv: Float                // ms RMSSD
        public var coherence: Float          // 0-1
        public var breathingRate: Float      // breaths/min
        public var motionIntensity: Float    // 0-1 from accelerometer
        public var skinConductance: Float    // GSR if available

        public static let neutral = BiometricState(
            heartRate: 72, hrv: 50, coherence: 0.5,
            breathingRate: 12, motionIntensity: 0.1, skinConductance: 0.5
        )
    }

    public struct PerformanceState: Codable, Sendable {
        public var bpm: Float                // Current tempo
        public var intensity: Float          // 0-1 overall intensity
        public var visualComplexity: Float   // 0-1 visual layer complexity
        public var harmonicTension: Float    // 0-1 musical tension
        public var filterCutoff: Float       // Normalized 0-1
        public var reverbMix: Float          // 0-1

        public static let neutral = PerformanceState(
            bpm: 120, intensity: 0.5, visualComplexity: 0.5,
            harmonicTension: 0.3, filterCutoff: 0.7, reverbMix: 0.3
        )
    }

    public struct EnvironmentState: Codable, Sendable {
        public var ambientLight: Float       // 0-1
        public var noiseLevel: Float         // 0-1
        public var crowdEnergy: Float        // 0-1 (from collaboration)
        public var timeOfDay: Float          // 0-24 hours

        public static let neutral = EnvironmentState(
            ambientLight: 0.5, noiseLevel: 0.3, crowdEnergy: 0.5, timeOfDay: 12
        )
    }

    public static let initial = WorldState(
        timestamp: Date(),
        biometrics: .neutral,
        performance: .neutral,
        environment: .neutral,
        confidence: 0.5
    )
}

// MARK: - Prediction Result

/// Predicted future state with action recommendations
public struct WorldPrediction: Sendable {
    public let predictedState: WorldState
    public let horizon: TimeInterval          // How far ahead (seconds)
    public let confidence: Float              // 0-1
    public let recommendedActions: [RecommendedAction]
    public let emotionalTrajectory: EmotionalTrajectory

    public struct RecommendedAction: Sendable {
        public let parameter: String          // e.g., "filterCutoff", "visualIntensity"
        public let currentValue: Float
        public let targetValue: Float
        public let priority: Priority
        public let rationale: String

        public enum Priority: Int, Sendable, Comparable {
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    public struct EmotionalTrajectory: Sendable {
        public let currentMood: Mood
        public let predictedMood: Mood
        public let transitionConfidence: Float

        public enum Mood: String, Sendable, CaseIterable {
            case calm = "Calm"
            case focused = "Focused"
            case energized = "Energized"
            case euphoric = "Euphoric"
            case introspective = "Introspective"
            case tense = "Tense"
            case fatigued = "Fatigued"
        }
    }
}

// MARK: - Objective

/// High-level objective for Echoela to pursue
public struct EchoelaObjective: Identifiable, Sendable {
    public let id: UUID
    public let type: ObjectiveType
    public let target: Float
    public let tolerance: Float
    public let priority: Int
    public let description: String

    public enum ObjectiveType: String, Sendable, CaseIterable {
        case maintainCoherence = "Maintain Coherence"
        case buildEnergy = "Build Energy"
        case createTension = "Create Tension"
        case releaseTension = "Release Tension"
        case synchronizeWithBio = "Sync with Bio"
        case followEmotionalArc = "Follow Emotional Arc"
        case optimizeFlow = "Optimize Flow State"
        case gentleTransition = "Gentle Transition"
    }

    public static func maintainCoherence(target: Float = 0.7) -> EchoelaObjective {
        EchoelaObjective(
            id: UUID(),
            type: .maintainCoherence,
            target: target,
            tolerance: 0.1,
            priority: 1,
            description: "Keep visual intensity aligned with emotional curve"
        )
    }

    public static func buildToClimax(over minutes: Float) -> EchoelaObjective {
        EchoelaObjective(
            id: UUID(),
            type: .buildEnergy,
            target: 1.0,
            tolerance: 0.05,
            priority: 2,
            description: "Gradually build energy over \(Int(minutes)) minutes"
        )
    }
}

// MARK: - World Model (JEPA-inspired)

/// Joint Embedding Predictive Architecture for bio-reactive world modeling
@MainActor
public final class WorldModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = WorldModel()

    // MARK: - Published State

    @Published public private(set) var currentState: WorldState = .initial
    @Published public private(set) var latestPrediction: WorldPrediction?
    @Published public private(set) var activeObjectives: [EchoelaObjective] = []
    @Published public private(set) var modelConfidence: Float = 0.5
    @Published public private(set) var isLearning: Bool = false

    // MARK: - Configuration

    public struct Configuration {
        public var predictionHorizon: TimeInterval = 5.0     // seconds ahead
        public var updateInterval: TimeInterval = 0.05       // 20Hz = 50ms
        public var historyLength: Int = 100                  // states to remember
        public var learningRate: Float = 0.01
        public var momentumDecay: Float = 0.9

        public static let `default` = Configuration()
        public static let highFrequency = Configuration(
            predictionHorizon: 2.0,
            updateInterval: 0.016,  // 60Hz
            historyLength: 200
        )
    }

    private var config: Configuration

    // MARK: - Internal State

    /// State history for temporal modeling
    private var stateHistory: [WorldState] = []

    /// Learned embeddings for state representation (simplified JEPA)
    private var stateEmbedding: [Float] = Array(repeating: 0, count: 64)
    private var predictionEmbedding: [Float] = Array(repeating: 0, count: 64)

    /// Transition model weights (simplified)
    private var transitionWeights: [[Float]] = []

    /// Running statistics for normalization
    private var runningMean: [Float] = Array(repeating: 0, count: 12)
    private var runningVar: [Float] = Array(repeating: 1, count: 12)

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init(config: Configuration = .default) {
        self.config = config
        initializeWeights()
        log.info("WorldModel initialized with JEPA architecture", category: .intelligence)
    }

    private func initializeWeights() {
        // Initialize transition weights with Xavier initialization
        let inputSize = 64
        let outputSize = 64
        let scale = sqrt(2.0 / Float(inputSize + outputSize))

        transitionWeights = (0..<outputSize).map { _ in
            (0..<inputSize).map { _ in Float.random(in: -scale...scale) }
        }
    }

    // MARK: - Public API

    /// Start the world model update loop
    public func start() {
        guard updateTimer == nil else { return }

        updateTimer = Timer.scheduledTimer(withTimeInterval: config.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCycle()
            }
        }

        log.info("WorldModel started at \(1.0/config.updateInterval)Hz", category: .intelligence)
    }

    /// Stop the update loop
    public func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        log.info("WorldModel stopped", category: .intelligence)
    }

    /// Update with new sensor data
    public func updateBiometrics(_ biometrics: WorldState.BiometricState) {
        var newState = currentState
        newState = WorldState(
            timestamp: Date(),
            biometrics: biometrics,
            performance: currentState.performance,
            environment: currentState.environment,
            confidence: calculateConfidence(biometrics: biometrics)
        )

        pushState(newState)
    }

    /// Update performance parameters
    public func updatePerformance(_ performance: WorldState.PerformanceState) {
        let newState = WorldState(
            timestamp: Date(),
            biometrics: currentState.biometrics,
            performance: performance,
            environment: currentState.environment,
            confidence: currentState.confidence
        )

        pushState(newState)
    }

    /// Add an objective for Echoela to pursue
    public func addObjective(_ objective: EchoelaObjective) {
        activeObjectives.append(objective)
        activeObjectives.sort { $0.priority < $1.priority }
        log.info("Objective added: \(objective.type.rawValue)", category: .intelligence)
    }

    /// Remove an objective
    public func removeObjective(id: UUID) {
        activeObjectives.removeAll { $0.id == id }
    }

    /// Get prediction for specific horizon
    public func predict(horizon: TimeInterval) -> WorldPrediction {
        let embedding = encodeState(currentState)
        let futureEmbedding = predictEmbedding(embedding, steps: Int(horizon / config.updateInterval))
        let predictedState = decodeEmbedding(futureEmbedding)

        let actions = generateActions(from: currentState, to: predictedState)
        let trajectory = analyzeEmotionalTrajectory()

        return WorldPrediction(
            predictedState: predictedState,
            horizon: horizon,
            confidence: modelConfidence,
            recommendedActions: actions,
            emotionalTrajectory: trajectory
        )
    }

    /// Force immediate prediction update
    public func forceUpdate() {
        updateCycle()
    }

    // MARK: - JEPA Core Logic

    private func updateCycle() {
        // 1. Encode current state to embedding
        stateEmbedding = encodeState(currentState)

        // 2. Predict future embedding
        let steps = Int(config.predictionHorizon / config.updateInterval)
        predictionEmbedding = predictEmbedding(stateEmbedding, steps: steps)

        // 3. Decode to predicted state
        let predictedState = decodeEmbedding(predictionEmbedding)

        // 4. Generate actions based on objectives
        let actions = evaluateObjectives(current: currentState, predicted: predictedState)

        // 5. Analyze emotional trajectory
        let trajectory = analyzeEmotionalTrajectory()

        // 6. Update prediction
        latestPrediction = WorldPrediction(
            predictedState: predictedState,
            horizon: config.predictionHorizon,
            confidence: modelConfidence,
            recommendedActions: actions,
            emotionalTrajectory: trajectory
        )

        // 7. Learn from history (if enabled)
        if isLearning && stateHistory.count >= 2 {
            learnFromTransition()
        }
    }

    /// Encode world state to embedding vector
    private func encodeState(_ state: WorldState) -> [Float] {
        // Flatten state to feature vector
        let features: [Float] = [
            state.biometrics.heartRate / 200.0,
            state.biometrics.hrv / 100.0,
            state.biometrics.coherence,
            state.biometrics.breathingRate / 30.0,
            state.biometrics.motionIntensity,
            state.biometrics.skinConductance,
            state.performance.bpm / 200.0,
            state.performance.intensity,
            state.performance.visualComplexity,
            state.performance.harmonicTension,
            state.performance.filterCutoff,
            state.performance.reverbMix
        ]

        // Normalize
        let normalized = zip(features, zip(runningMean, runningVar)).map { (f, stats) in
            (f - stats.0) / sqrt(stats.1 + 1e-8)
        }

        // Project to embedding space (simple linear for now)
        var embedding = [Float](repeating: 0, count: 64)
        for i in 0..<64 {
            for (j, feat) in normalized.enumerated() {
                embedding[i] += feat * Float.random(in: -0.1...0.1) // Simplified projection
            }
            embedding[i] = tanh(embedding[i])
        }

        return embedding
    }

    /// Predict future embedding using transition model
    private func predictEmbedding(_ embedding: [Float], steps: Int) -> [Float] {
        var current = embedding

        for _ in 0..<min(steps, 100) {
            var next = [Float](repeating: 0, count: 64)

            // Matrix multiply with transition weights
            for i in 0..<64 {
                for j in 0..<64 {
                    next[i] += current[j] * transitionWeights[i][j]
                }
                next[i] = tanh(next[i]) // Non-linearity
            }

            // Residual connection
            for i in 0..<64 {
                current[i] = 0.9 * next[i] + 0.1 * current[i]
            }
        }

        return current
    }

    /// Decode embedding back to world state
    private func decodeEmbedding(_ embedding: [Float]) -> WorldState {
        // Simple linear decoding (reverse of encoding)
        let summed = embedding.reduce(0, +) / Float(embedding.count)
        let variance = embedding.map { ($0 - summed) * ($0 - summed) }.reduce(0, +) / Float(embedding.count)

        // Use embedding statistics to modulate predicted state
        let energyFactor = (summed + 1) / 2  // Map from [-1,1] to [0,1]
        let varianceFactor = min(sqrt(variance), 1.0)

        return WorldState(
            timestamp: Date().addingTimeInterval(config.predictionHorizon),
            biometrics: WorldState.BiometricState(
                heartRate: currentState.biometrics.heartRate * (0.9 + 0.2 * energyFactor),
                hrv: currentState.biometrics.hrv * (0.8 + 0.4 * (1 - varianceFactor)),
                coherence: min(1, max(0, currentState.biometrics.coherence + (energyFactor - 0.5) * 0.1)),
                breathingRate: currentState.biometrics.breathingRate,
                motionIntensity: currentState.biometrics.motionIntensity * (0.8 + 0.4 * energyFactor),
                skinConductance: currentState.biometrics.skinConductance
            ),
            performance: WorldState.PerformanceState(
                bpm: currentState.performance.bpm,
                intensity: min(1, max(0, currentState.performance.intensity + (energyFactor - 0.5) * 0.2)),
                visualComplexity: min(1, max(0, varianceFactor)),
                harmonicTension: currentState.performance.harmonicTension,
                filterCutoff: currentState.performance.filterCutoff,
                reverbMix: currentState.performance.reverbMix
            ),
            environment: currentState.environment,
            confidence: modelConfidence * 0.9 + Float.random(in: 0...0.1)
        )
    }

    /// Evaluate objectives and generate actions
    private func evaluateObjectives(current: WorldState, predicted: WorldState) -> [WorldPrediction.RecommendedAction] {
        var actions: [WorldPrediction.RecommendedAction] = []

        for objective in activeObjectives {
            switch objective.type {
            case .maintainCoherence:
                if abs(predicted.biometrics.coherence - objective.target) > objective.tolerance {
                    let delta = objective.target - predicted.biometrics.coherence
                    actions.append(WorldPrediction.RecommendedAction(
                        parameter: "visualIntensity",
                        currentValue: current.performance.intensity,
                        targetValue: current.performance.intensity - delta * 0.5,
                        priority: delta > 0.2 ? .high : .medium,
                        rationale: "Adjust visual intensity to support coherence target"
                    ))
                }

            case .buildEnergy:
                if predicted.performance.intensity < objective.target - objective.tolerance {
                    actions.append(WorldPrediction.RecommendedAction(
                        parameter: "intensity",
                        currentValue: current.performance.intensity,
                        targetValue: min(1, current.performance.intensity + 0.05),
                        priority: .medium,
                        rationale: "Gradually increase energy toward climax"
                    ))
                }

            case .synchronizeWithBio:
                let bioIntensity = (current.biometrics.heartRate - 60) / 100
                if abs(current.performance.intensity - bioIntensity) > 0.2 {
                    actions.append(WorldPrediction.RecommendedAction(
                        parameter: "intensity",
                        currentValue: current.performance.intensity,
                        targetValue: bioIntensity,
                        priority: .high,
                        rationale: "Sync performance with biometric intensity"
                    ))
                }

            case .optimizeFlow:
                // Flow state: high coherence + moderate challenge
                if current.biometrics.coherence > 0.6 && current.performance.harmonicTension < 0.4 {
                    actions.append(WorldPrediction.RecommendedAction(
                        parameter: "harmonicTension",
                        currentValue: current.performance.harmonicTension,
                        targetValue: 0.5,
                        priority: .low,
                        rationale: "Increase musical tension to maintain flow"
                    ))
                }

            default:
                break
            }
        }

        return actions.sorted { $0.priority > $1.priority }
    }

    /// Analyze emotional trajectory from history
    private func analyzeEmotionalTrajectory() -> WorldPrediction.EmotionalTrajectory {
        let currentMood = classifyMood(currentState)

        // Predict mood based on trends
        var predictedMood = currentMood
        var confidence: Float = 0.5

        if stateHistory.count >= 10 {
            let recentCoherence = stateHistory.suffix(10).map { $0.biometrics.coherence }
            guard let lastCoherence = recentCoherence.last, let firstCoherence = recentCoherence.first else {
                return WorldPrediction.EmotionalTrajectory(currentMood: currentMood, predictedMood: currentMood, transitionConfidence: 0.5)
            }
            let trend = lastCoherence - firstCoherence

            if trend > 0.1 {
                predictedMood = currentMood == .tense ? .focused : .energized
                confidence = 0.7
            } else if trend < -0.1 {
                predictedMood = currentMood == .energized ? .focused : .fatigued
                confidence = 0.6
            }
        }

        return WorldPrediction.EmotionalTrajectory(
            currentMood: currentMood,
            predictedMood: predictedMood,
            transitionConfidence: confidence
        )
    }

    private func classifyMood(_ state: WorldState) -> WorldPrediction.EmotionalTrajectory.Mood {
        let hr = state.biometrics.heartRate
        let coherence = state.biometrics.coherence
        let hrv = state.biometrics.hrv

        if coherence > 0.7 && hr < 80 {
            return .calm
        } else if coherence > 0.6 && hr >= 80 && hr < 100 {
            return .focused
        } else if hr >= 100 && coherence > 0.5 {
            return .energized
        } else if hr >= 120 && coherence > 0.7 {
            return .euphoric
        } else if hrv > 60 && hr < 70 {
            return .introspective
        } else if coherence < 0.3 {
            return .tense
        } else if hrv < 30 {
            return .fatigued
        }

        return .focused
    }

    /// Learn from state transition (simplified online learning)
    private func learnFromTransition() {
        guard stateHistory.count >= 2 else { return }

        let previous = stateHistory[stateHistory.count - 2]
        let current = stateHistory[stateHistory.count - 1]

        let prevEmbedding = encodeState(previous)
        let currEmbedding = encodeState(current)
        let predictedEmbedding = predictEmbedding(prevEmbedding, steps: 1)

        // Compute prediction error
        var error: Float = 0
        for i in 0..<64 {
            let diff = currEmbedding[i] - predictedEmbedding[i]
            error += diff * diff

            // Update weights (simplified gradient descent)
            for j in 0..<64 {
                transitionWeights[i][j] += config.learningRate * diff * prevEmbedding[j]
            }
        }

        // Update model confidence based on prediction error
        let normalizedError = sqrt(error / 64)
        modelConfidence = modelConfidence * config.momentumDecay + (1 - normalizedError) * (1 - config.momentumDecay)
    }

    // MARK: - Helpers

    private func pushState(_ state: WorldState) {
        currentState = state
        stateHistory.append(state)

        // Trim history
        if stateHistory.count > config.historyLength {
            stateHistory.removeFirst(stateHistory.count - config.historyLength)
        }

        // Update running statistics
        updateRunningStats(state)
    }

    private func updateRunningStats(_ state: WorldState) {
        let features: [Float] = [
            state.biometrics.heartRate / 200.0,
            state.biometrics.hrv / 100.0,
            state.biometrics.coherence,
            state.biometrics.breathingRate / 30.0,
            state.biometrics.motionIntensity,
            state.biometrics.skinConductance,
            state.performance.bpm / 200.0,
            state.performance.intensity,
            state.performance.visualComplexity,
            state.performance.harmonicTension,
            state.performance.filterCutoff,
            state.performance.reverbMix
        ]

        let momentum: Float = 0.99
        for (i, feat) in features.enumerated() {
            runningMean[i] = momentum * runningMean[i] + (1 - momentum) * feat
            let diff = feat - runningMean[i]
            runningVar[i] = momentum * runningVar[i] + (1 - momentum) * diff * diff
        }
    }

    private func calculateConfidence(biometrics: WorldState.BiometricState) -> Float {
        // Confidence based on data quality indicators
        var confidence: Float = 1.0

        // Heart rate in physiological range
        if biometrics.heartRate < 40 || biometrics.heartRate > 200 {
            confidence *= 0.5
        }

        // HRV in reasonable range
        if biometrics.hrv < 5 || biometrics.hrv > 200 {
            confidence *= 0.7
        }

        // Coherence must be 0-1
        if biometrics.coherence < 0 || biometrics.coherence > 1 {
            confidence *= 0.3
        }

        return confidence
    }

    private func generateActions(from current: WorldState, to predicted: WorldState) -> [WorldPrediction.RecommendedAction] {
        evaluateObjectives(current: current, predicted: predicted)
    }
}
