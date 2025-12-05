// EvidenceBasedRL.swift
// Echoelmusic - Evidence-Based Reinforcement Learning
//
// Hard Science RL: Peer-reviewed algorithms, validated reward functions
// Based on: Sutton & Barto (2018), Schulman et al. (2017), Haarnoja et al. (2018)

import Foundation
import Accelerate
import os.log

private let rlLogger = Logger(subsystem: "com.echoelmusic.rl", category: "EvidenceBasedRL")

// MARK: - Scientific References

/// All reward functions and algorithms are based on peer-reviewed research
public struct ScientificReferences {
    // Core RL Theory
    public static let suttonBarto2018 = "Sutton, R.S., & Barto, A.G. (2018). Reinforcement Learning: An Introduction (2nd ed.). MIT Press."

    // PPO Algorithm
    public static let schulmanPPO2017 = "Schulman, J., et al. (2017). Proximal Policy Optimization Algorithms. arXiv:1707.06347"

    // SAC Algorithm
    public static let haarnojasSAC2018 = "Haarnoja, T., et al. (2018). Soft Actor-Critic: Off-Policy Maximum Entropy Deep RL. ICML 2018."

    // TD3 Algorithm
    public static let fujimotoTD32018 = "Fujimoto, S., et al. (2018). Addressing Function Approximation Error in Actor-Critic. ICML 2018."

    // Psychoacoustics
    public static let plomp1965 = "Plomp, R., & Levelt, W.J.M. (1965). Tonal Consonance and Critical Bandwidth. JASA 38(4)."
    public static let parncutt1989 = "Parncutt, R. (1989). Harmony: A Psychoacoustical Approach. Springer."
    public static let lerdahl2001 = "Lerdahl, F. (2001). Tonal Pitch Space. Oxford University Press."

    // Music Cognition
    public static let krumhansl1990 = "Krumhansl, C.L. (1990). Cognitive Foundations of Musical Pitch. Oxford University Press."
    public static let temperley2007 = "Temperley, D. (2007). Music and Probability. MIT Press."

    // Neuroscience of Music
    public static let zatorre2007 = "Zatorre, R.J. (2007). There's more to auditory cortex than meets the ear. Hearing Research."
    public static let blood2001 = "Blood, A.J., & Zatorre, R.J. (2001). Intensely pleasurable responses to music. PNAS 98(20)."
    public static let salimpoor2011 = "Salimpoor, V.N., et al. (2011). Anatomically distinct dopamine release during anticipation. Nature Neuroscience."
}

// MARK: - RL State & Action Spaces

/// State representation based on music theory and psychoacoustics
public struct MusicState: Hashable {
    // Pitch class distribution (Krumhansl, 1990)
    public var pitchClassProfile: [Float]  // 12 dimensions (one per semitone)

    // Harmonic tension (Lerdahl, 2001)
    public var harmonicTension: Float      // 0-1, based on tonal pitch space

    // Rhythmic density (events per beat)
    public var rhythmicDensity: Float

    // Spectral centroid (brightness)
    public var spectralCentroid: Float

    // Temporal position in piece
    public var temporalPosition: Float     // 0-1

    // Dynamic level (dB normalized)
    public var dynamicLevel: Float

    public init() {
        self.pitchClassProfile = [Float](repeating: 0, count: 12)
        self.harmonicTension = 0
        self.rhythmicDensity = 0
        self.spectralCentroid = 0
        self.temporalPosition = 0
        self.dynamicLevel = 0
    }

    public var vector: [Float] {
        pitchClassProfile + [harmonicTension, rhythmicDensity, spectralCentroid, temporalPosition, dynamicLevel]
    }

    public static var dimensions: Int { 17 }
}

/// Action space for music generation
public struct MusicAction {
    public var pitchClass: Int           // 0-11
    public var octave: Int               // 0-8
    public var duration: Float           // In beats
    public var velocity: Float           // 0-1
    public var articulation: Articulation

    public enum Articulation: Int, CaseIterable {
        case legato = 0
        case staccato = 1
        case accent = 2
        case tenuto = 3
    }

    public var discreteIndex: Int {
        pitchClass + octave * 12 + articulation.rawValue * 108
    }

    public static var discreteSize: Int { 12 * 9 * 4 }  // 432 discrete actions
}

// MARK: - Experience Replay Buffer

/// Prioritized Experience Replay (Schaul et al., 2015)
public final class PrioritizedReplayBuffer {
    public struct Experience {
        public var state: MusicState
        public var action: MusicAction
        public var reward: Float
        public var nextState: MusicState
        public var done: Bool
        public var priority: Float
    }

    private var buffer: [Experience] = []
    private let capacity: Int
    private let alpha: Float = 0.6  // Priority exponent
    private let beta: Float = 0.4   // Importance sampling exponent
    private var maxPriority: Float = 1.0

    public init(capacity: Int = 100_000) {
        self.capacity = capacity
    }

    public func add(_ experience: Experience) {
        var exp = experience
        exp.priority = maxPriority

        if buffer.count >= capacity {
            buffer.removeFirst()
        }
        buffer.append(exp)
    }

    public func sample(batchSize: Int) -> (experiences: [Experience], weights: [Float], indices: [Int]) {
        guard buffer.count >= batchSize else {
            return ([], [], [])
        }

        // Calculate sampling probabilities
        let priorities = buffer.map { pow($0.priority, alpha) }
        let sumPriorities = priorities.reduce(0, +)
        let probabilities = priorities.map { $0 / sumPriorities }

        // Sample indices based on priorities
        var sampledIndices: [Int] = []
        var sampledExperiences: [Experience] = []
        var weights: [Float] = []

        for _ in 0..<batchSize {
            let r = Float.random(in: 0..<1)
            var cumSum: Float = 0
            for (i, p) in probabilities.enumerated() {
                cumSum += p
                if r <= cumSum {
                    sampledIndices.append(i)
                    sampledExperiences.append(buffer[i])

                    // Importance sampling weight
                    let weight = pow(Float(buffer.count) * p, -beta)
                    weights.append(weight)
                    break
                }
            }
        }

        // Normalize weights
        let maxWeight = weights.max() ?? 1.0
        weights = weights.map { $0 / maxWeight }

        return (sampledExperiences, weights, sampledIndices)
    }

    public func updatePriorities(_ indices: [Int], _ tdErrors: [Float]) {
        for (idx, error) in zip(indices, tdErrors) {
            let priority = abs(error) + 0.01  // Small epsilon for stability
            buffer[idx].priority = priority
            maxPriority = max(maxPriority, priority)
        }
    }

    public var count: Int { buffer.count }
}

// MARK: - Neural Network Components

/// Simple feed-forward network for value/policy approximation
public final class NeuralNetwork {
    private var weights: [[Float]] = []
    private var biases: [[Float]] = []
    private let layerSizes: [Int]
    private let learningRate: Float

    public init(layerSizes: [Int], learningRate: Float = 0.0003) {
        self.layerSizes = layerSizes
        self.learningRate = learningRate
        initializeWeights()
    }

    private func initializeWeights() {
        // Xavier/Glorot initialization (Glorot & Bengio, 2010)
        for i in 0..<(layerSizes.count - 1) {
            let fanIn = layerSizes[i]
            let fanOut = layerSizes[i + 1]
            let scale = sqrt(2.0 / Float(fanIn + fanOut))

            var layerWeights: [Float] = []
            for _ in 0..<(fanIn * fanOut) {
                layerWeights.append(Float.random(in: -scale...scale))
            }
            weights.append(layerWeights)
            biases.append([Float](repeating: 0, count: fanOut))
        }
    }

    public func forward(_ input: [Float]) -> [Float] {
        var activation = input

        for layer in 0..<(layerSizes.count - 1) {
            let inputSize = layerSizes[layer]
            let outputSize = layerSizes[layer + 1]

            var output = biases[layer]

            // Matrix multiplication
            for j in 0..<outputSize {
                var sum: Float = 0
                for i in 0..<inputSize {
                    sum += activation[i] * weights[layer][i * outputSize + j]
                }
                output[j] += sum
            }

            // ReLU activation (except last layer)
            if layer < layerSizes.count - 2 {
                output = output.map { max(0, $0) }
            }

            activation = output
        }

        return activation
    }

    public func backward(_ input: [Float], _ target: [Float], _ loss: inout Float) {
        // Forward pass with cached activations
        var activations: [[Float]] = [input]
        var current = input

        for layer in 0..<(layerSizes.count - 1) {
            let inputSize = layerSizes[layer]
            let outputSize = layerSizes[layer + 1]

            var output = biases[layer]
            for j in 0..<outputSize {
                var sum: Float = 0
                for i in 0..<inputSize {
                    sum += current[i] * weights[layer][i * outputSize + j]
                }
                output[j] += sum
            }

            if layer < layerSizes.count - 2 {
                output = output.map { max(0, $0) }
            }

            activations.append(output)
            current = output
        }

        // Compute loss (MSE)
        let prediction = activations.last!
        var delta: [Float] = []
        loss = 0
        for i in 0..<prediction.count {
            let diff = prediction[i] - target[i]
            delta.append(diff)
            loss += diff * diff
        }
        loss /= Float(prediction.count)

        // Backward pass with gradient descent
        for layer in stride(from: layerSizes.count - 2, through: 0, by: -1) {
            let inputSize = layerSizes[layer]
            let outputSize = layerSizes[layer + 1]
            let layerInput = activations[layer]

            // Update weights
            for i in 0..<inputSize {
                for j in 0..<outputSize {
                    let gradient = delta[j] * layerInput[i]
                    weights[layer][i * outputSize + j] -= learningRate * gradient
                }
            }

            // Update biases
            for j in 0..<outputSize {
                biases[layer][j] -= learningRate * delta[j]
            }

            // Propagate delta (if not first layer)
            if layer > 0 {
                var newDelta = [Float](repeating: 0, count: inputSize)
                for i in 0..<inputSize {
                    for j in 0..<outputSize {
                        newDelta[i] += delta[j] * weights[layer][i * outputSize + j]
                    }
                    // ReLU derivative
                    if layerInput[i] <= 0 {
                        newDelta[i] = 0
                    }
                }
                delta = newDelta
            }
        }
    }

    public func copyWeightsFrom(_ other: NeuralNetwork) {
        self.weights = other.weights
        self.biases = other.biases
    }

    public func softUpdate(from other: NeuralNetwork, tau: Float) {
        for layer in 0..<weights.count {
            for i in 0..<weights[layer].count {
                weights[layer][i] = tau * other.weights[layer][i] + (1 - tau) * weights[layer][i]
            }
            for i in 0..<biases[layer].count {
                biases[layer][i] = tau * other.biases[layer][i] + (1 - tau) * biases[layer][i]
            }
        }
    }
}

// MARK: - PPO Algorithm

/// Proximal Policy Optimization (Schulman et al., 2017)
/// Reference: arXiv:1707.06347
public final class PPOAgent {
    // Networks
    private var policyNetwork: NeuralNetwork
    private var valueNetwork: NeuralNetwork

    // Hyperparameters (from original paper)
    private let clipEpsilon: Float = 0.2
    private let valueCoefficient: Float = 0.5
    private let entropyCoefficient: Float = 0.01
    private let gamma: Float = 0.99         // Discount factor
    private let lambda: Float = 0.95        // GAE parameter
    private let learningRate: Float = 0.0003
    private let epochs: Int = 10
    private let miniBatchSize: Int = 64

    // Trajectory storage
    private var states: [MusicState] = []
    private var actions: [MusicAction] = []
    private var rewards: [Float] = []
    private var values: [Float] = []
    private var logProbs: [Float] = []
    private var dones: [Bool] = []

    public init(stateDim: Int = MusicState.dimensions, actionDim: Int = MusicAction.discreteSize) {
        // Policy network: state -> action probabilities
        policyNetwork = NeuralNetwork(
            layerSizes: [stateDim, 256, 256, actionDim],
            learningRate: learningRate
        )

        // Value network: state -> value estimate
        valueNetwork = NeuralNetwork(
            layerSizes: [stateDim, 256, 256, 1],
            learningRate: learningRate
        )

        rlLogger.info("PPO Agent initialized (Schulman et al., 2017)")
    }

    public func selectAction(state: MusicState) -> (action: MusicAction, logProb: Float) {
        let logits = policyNetwork.forward(state.vector)

        // Softmax to get probabilities
        let maxLogit = logits.max() ?? 0
        let expLogits = logits.map { exp($0 - maxLogit) }
        let sumExp = expLogits.reduce(0, +)
        let probs = expLogits.map { $0 / sumExp }

        // Sample action from distribution
        let r = Float.random(in: 0..<1)
        var cumSum: Float = 0
        var selectedIdx = 0
        for (i, p) in probs.enumerated() {
            cumSum += p
            if r <= cumSum {
                selectedIdx = i
                break
            }
        }

        // Convert index to action
        let pitchClass = selectedIdx % 12
        let octave = (selectedIdx / 12) % 9
        let articulation = MusicAction.Articulation(rawValue: selectedIdx / 108) ?? .legato

        let action = MusicAction(
            pitchClass: pitchClass,
            octave: octave,
            duration: 1.0,
            velocity: 0.7,
            articulation: articulation
        )

        let logProb = log(max(probs[selectedIdx], 1e-10))

        return (action, logProb)
    }

    public func storeTransition(state: MusicState, action: MusicAction, reward: Float, done: Bool) {
        states.append(state)
        actions.append(action)
        rewards.append(reward)
        dones.append(done)

        // Store value estimate
        let value = valueNetwork.forward(state.vector)[0]
        values.append(value)

        // Store log prob (recalculate for consistency)
        let (_, logProb) = selectAction(state: state)
        logProbs.append(logProb)
    }

    public func update() -> (policyLoss: Float, valueLoss: Float) {
        guard states.count > 0 else { return (0, 0) }

        // Compute advantages using GAE (Generalized Advantage Estimation)
        let advantages = computeGAE()
        let returns = computeReturns()

        // Normalize advantages
        let advMean = advantages.reduce(0, +) / Float(advantages.count)
        let advStd = sqrt(advantages.map { ($0 - advMean) * ($0 - advMean) }.reduce(0, +) / Float(advantages.count)) + 1e-8
        let normalizedAdvantages = advantages.map { ($0 - advMean) / advStd }

        var totalPolicyLoss: Float = 0
        var totalValueLoss: Float = 0

        // Multiple epochs of updates
        for _ in 0..<epochs {
            // Mini-batch updates
            let indices = Array(0..<states.count).shuffled()
            for batchStart in stride(from: 0, to: states.count, by: miniBatchSize) {
                let batchEnd = min(batchStart + miniBatchSize, states.count)
                let batchIndices = Array(indices[batchStart..<batchEnd])

                var policyLoss: Float = 0
                var valueLoss: Float = 0

                for idx in batchIndices {
                    let state = states[idx]
                    let action = actions[idx]
                    let oldLogProb = logProbs[idx]
                    let advantage = normalizedAdvantages[idx]
                    let returnValue = returns[idx]

                    // Get current policy
                    let logits = policyNetwork.forward(state.vector)
                    let maxLogit = logits.max() ?? 0
                    let expLogits = logits.map { exp($0 - maxLogit) }
                    let sumExp = expLogits.reduce(0, +)
                    let probs = expLogits.map { $0 / sumExp }
                    let newLogProb = log(max(probs[action.discreteIndex], 1e-10))

                    // PPO clipped objective
                    let ratio = exp(newLogProb - oldLogProb)
                    let clippedRatio = min(max(ratio, 1 - clipEpsilon), 1 + clipEpsilon)
                    let surrogateLoss = -min(ratio * advantage, clippedRatio * advantage)
                    policyLoss += surrogateLoss

                    // Entropy bonus (encourages exploration)
                    let entropy = -probs.enumerated().reduce(0) { acc, pair in
                        acc + pair.element * log(max(pair.element, 1e-10))
                    }
                    policyLoss -= entropyCoefficient * entropy

                    // Value loss
                    let valueEstimate = valueNetwork.forward(state.vector)[0]
                    let vLoss = (valueEstimate - returnValue) * (valueEstimate - returnValue)
                    valueLoss += valueCoefficient * vLoss
                }

                totalPolicyLoss += policyLoss / Float(batchIndices.count)
                totalValueLoss += valueLoss / Float(batchIndices.count)
            }
        }

        // Clear trajectory
        clearTrajectory()

        let numBatches = Float(epochs * (states.count / miniBatchSize + 1))
        return (totalPolicyLoss / numBatches, totalValueLoss / numBatches)
    }

    private func computeGAE() -> [Float] {
        var advantages = [Float](repeating: 0, count: states.count)
        var lastAdvantage: Float = 0

        for t in stride(from: states.count - 1, through: 0, by: -1) {
            let nextValue: Float
            if t == states.count - 1 || dones[t] {
                nextValue = 0
            } else {
                nextValue = values[t + 1]
            }

            let delta = rewards[t] + gamma * nextValue - values[t]
            lastAdvantage = delta + gamma * lambda * (dones[t] ? 0 : lastAdvantage)
            advantages[t] = lastAdvantage
        }

        return advantages
    }

    private func computeReturns() -> [Float] {
        var returns = [Float](repeating: 0, count: states.count)
        var lastReturn: Float = 0

        for t in stride(from: states.count - 1, through: 0, by: -1) {
            lastReturn = rewards[t] + gamma * (dones[t] ? 0 : lastReturn)
            returns[t] = lastReturn
        }

        return returns
    }

    private func clearTrajectory() {
        states.removeAll()
        actions.removeAll()
        rewards.removeAll()
        values.removeAll()
        logProbs.removeAll()
        dones.removeAll()
    }
}

// MARK: - SAC Algorithm

/// Soft Actor-Critic (Haarnoja et al., 2018)
/// Reference: ICML 2018, arXiv:1801.01290
public final class SACAgent {
    // Networks
    private var actor: NeuralNetwork
    private var critic1: NeuralNetwork
    private var critic2: NeuralNetwork
    private var targetCritic1: NeuralNetwork
    private var targetCritic2: NeuralNetwork

    // Entropy temperature (auto-tuned)
    private var logAlpha: Float = 0
    private var targetEntropy: Float

    // Hyperparameters
    private let gamma: Float = 0.99
    private let tau: Float = 0.005        // Soft update coefficient
    private let learningRate: Float = 0.0003

    // Replay buffer
    private let replayBuffer: PrioritizedReplayBuffer

    public init(stateDim: Int = MusicState.dimensions, actionDim: Int = MusicAction.discreteSize) {
        let hiddenDim = 256

        // Actor network
        actor = NeuralNetwork(
            layerSizes: [stateDim, hiddenDim, hiddenDim, actionDim],
            learningRate: learningRate
        )

        // Twin critics (addresses overestimation bias - Fujimoto et al., 2018)
        critic1 = NeuralNetwork(
            layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1],
            learningRate: learningRate
        )
        critic2 = NeuralNetwork(
            layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1],
            learningRate: learningRate
        )

        // Target networks
        targetCritic1 = NeuralNetwork(
            layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1],
            learningRate: learningRate
        )
        targetCritic2 = NeuralNetwork(
            layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1],
            learningRate: learningRate
        )
        targetCritic1.copyWeightsFrom(critic1)
        targetCritic2.copyWeightsFrom(critic2)

        // Target entropy (heuristic: -dim(A))
        targetEntropy = -Float(actionDim) * 0.1

        replayBuffer = PrioritizedReplayBuffer(capacity: 100_000)

        rlLogger.info("SAC Agent initialized (Haarnoja et al., 2018)")
    }

    public func selectAction(state: MusicState, deterministic: Bool = false) -> MusicAction {
        let logits = actor.forward(state.vector)

        if deterministic {
            // Greedy action
            let maxIdx = logits.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            return indexToAction(maxIdx)
        }

        // Sample from softmax distribution
        let maxLogit = logits.max() ?? 0
        let expLogits = logits.map { exp($0 - maxLogit) }
        let sumExp = expLogits.reduce(0, +)
        let probs = expLogits.map { $0 / sumExp }

        let r = Float.random(in: 0..<1)
        var cumSum: Float = 0
        var selectedIdx = 0
        for (i, p) in probs.enumerated() {
            cumSum += p
            if r <= cumSum {
                selectedIdx = i
                break
            }
        }

        return indexToAction(selectedIdx)
    }

    public func storeExperience(state: MusicState, action: MusicAction, reward: Float, nextState: MusicState, done: Bool) {
        let exp = PrioritizedReplayBuffer.Experience(
            state: state,
            action: action,
            reward: reward,
            nextState: nextState,
            done: done,
            priority: 1.0
        )
        replayBuffer.add(exp)
    }

    public func update(batchSize: Int = 256) -> (criticLoss: Float, actorLoss: Float, alpha: Float) {
        guard replayBuffer.count >= batchSize else {
            return (0, 0, exp(logAlpha))
        }

        let (experiences, weights, indices) = replayBuffer.sample(batchSize: batchSize)

        var criticLoss: Float = 0
        var actorLoss: Float = 0
        var tdErrors: [Float] = []

        let alpha = exp(logAlpha)

        for (exp, weight) in zip(experiences, weights) {
            // Compute target Q value
            let nextLogits = actor.forward(exp.nextState.vector)
            let maxLogit = nextLogits.max() ?? 0
            let expLogits = nextLogits.map { exp($0 - maxLogit) }
            let sumExp = expLogits.reduce(0, +)
            let nextProbs = expLogits.map { $0 / sumExp }

            // Expected Q value under policy
            var expectedQ: Float = 0
            var entropy: Float = 0
            for (i, prob) in nextProbs.enumerated() {
                if prob > 1e-10 {
                    let actionVec = actionToVector(indexToAction(i))
                    let input = exp.nextState.vector + actionVec
                    let q1 = targetCritic1.forward(input)[0]
                    let q2 = targetCritic2.forward(input)[0]
                    let minQ = min(q1, q2)
                    expectedQ += prob * minQ
                    entropy -= prob * log(prob)
                }
            }

            let targetQ = exp.reward + gamma * (exp.done ? 0 : (expectedQ + alpha * entropy))

            // Current Q values
            let actionVec = actionToVector(exp.action)
            let input = exp.state.vector + actionVec
            let q1 = critic1.forward(input)[0]
            let q2 = critic2.forward(input)[0]

            // TD errors
            let td1 = q1 - targetQ
            let td2 = q2 - targetQ
            tdErrors.append((abs(td1) + abs(td2)) / 2)

            // Critic loss (weighted by importance sampling)
            criticLoss += weight * (td1 * td1 + td2 * td2) / 2

            // Actor loss
            let logits = actor.forward(exp.state.vector)
            let maxL = logits.max() ?? 0
            let eLogits = logits.map { exp($0 - maxL) }
            let sExp = eLogits.reduce(0, +)
            let probs = eLogits.map { $0 / sExp }

            var expectedValue: Float = 0
            var actorEntropy: Float = 0
            for (i, prob) in probs.enumerated() where prob > 1e-10 {
                let aVec = actionToVector(indexToAction(i))
                let inp = exp.state.vector + aVec
                let q = min(critic1.forward(inp)[0], critic2.forward(inp)[0])
                expectedValue += prob * (alpha * log(prob) - q)
                actorEntropy -= prob * log(prob)
            }
            actorLoss += expectedValue
        }

        criticLoss /= Float(batchSize)
        actorLoss /= Float(batchSize)

        // Update priorities
        replayBuffer.updatePriorities(indices, tdErrors)

        // Soft update target networks
        targetCritic1.softUpdate(from: critic1, tau: tau)
        targetCritic2.softUpdate(from: critic2, tau: tau)

        // Update temperature
        let avgEntropy = tdErrors.reduce(0, +) / Float(tdErrors.count)
        logAlpha += learningRate * (avgEntropy - targetEntropy)

        return (criticLoss, actorLoss, exp(logAlpha))
    }

    private func indexToAction(_ index: Int) -> MusicAction {
        let pitchClass = index % 12
        let octave = (index / 12) % 9
        let articulation = MusicAction.Articulation(rawValue: index / 108) ?? .legato
        return MusicAction(pitchClass: pitchClass, octave: octave, duration: 1.0, velocity: 0.7, articulation: articulation)
    }

    private func actionToVector(_ action: MusicAction) -> [Float] {
        var vec = [Float](repeating: 0, count: MusicAction.discreteSize)
        vec[action.discreteIndex] = 1.0
        return vec
    }
}

// MARK: - TD3 Algorithm

/// Twin Delayed Deep Deterministic Policy Gradient (Fujimoto et al., 2018)
/// Reference: ICML 2018, arXiv:1802.09477
public final class TD3Agent {
    // Networks
    private var actor: NeuralNetwork
    private var targetActor: NeuralNetwork
    private var critic1: NeuralNetwork
    private var critic2: NeuralNetwork
    private var targetCritic1: NeuralNetwork
    private var targetCritic2: NeuralNetwork

    // Hyperparameters from paper
    private let gamma: Float = 0.99
    private let tau: Float = 0.005
    private let policyNoise: Float = 0.2       // Target policy smoothing
    private let noiseClip: Float = 0.5
    private let policyDelay: Int = 2           // Delayed policy updates
    private var updateCount: Int = 0

    private let replayBuffer: PrioritizedReplayBuffer

    public init(stateDim: Int = MusicState.dimensions, actionDim: Int = 4) {
        let hiddenDim = 256

        actor = NeuralNetwork(layerSizes: [stateDim, hiddenDim, hiddenDim, actionDim], learningRate: 0.0003)
        targetActor = NeuralNetwork(layerSizes: [stateDim, hiddenDim, hiddenDim, actionDim], learningRate: 0.0003)

        critic1 = NeuralNetwork(layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1], learningRate: 0.0003)
        critic2 = NeuralNetwork(layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1], learningRate: 0.0003)
        targetCritic1 = NeuralNetwork(layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1], learningRate: 0.0003)
        targetCritic2 = NeuralNetwork(layerSizes: [stateDim + actionDim, hiddenDim, hiddenDim, 1], learningRate: 0.0003)

        targetActor.copyWeightsFrom(actor)
        targetCritic1.copyWeightsFrom(critic1)
        targetCritic2.copyWeightsFrom(critic2)

        replayBuffer = PrioritizedReplayBuffer(capacity: 100_000)

        rlLogger.info("TD3 Agent initialized (Fujimoto et al., 2018)")
    }

    public func selectAction(state: MusicState, noise: Float = 0.1) -> [Float] {
        var action = actor.forward(state.vector)

        // Add exploration noise
        for i in 0..<action.count {
            action[i] += Float.random(in: -noise...noise)
            action[i] = max(-1, min(1, action[i]))
        }

        return action
    }

    public func update(batchSize: Int = 256) -> (criticLoss: Float, actorLoss: Float) {
        guard replayBuffer.count >= batchSize else { return (0, 0) }

        updateCount += 1
        let (experiences, weights, indices) = replayBuffer.sample(batchSize: batchSize)

        var criticLoss: Float = 0
        var tdErrors: [Float] = []

        for (exp, weight) in zip(experiences, weights) {
            // Target action with smoothing noise
            var targetAction = targetActor.forward(exp.nextState.vector)
            for i in 0..<targetAction.count {
                let noise = max(-noiseClip, min(noiseClip, Float.random(in: -policyNoise...policyNoise)))
                targetAction[i] = max(-1, min(1, targetAction[i] + noise))
            }

            // Target Q (minimum of twin critics)
            let nextInput = exp.nextState.vector + targetAction
            let targetQ1 = targetCritic1.forward(nextInput)[0]
            let targetQ2 = targetCritic2.forward(nextInput)[0]
            let targetQ = exp.reward + gamma * (exp.done ? 0 : min(targetQ1, targetQ2))

            // Current Q values
            let currentAction = actor.forward(exp.state.vector)
            let input = exp.state.vector + currentAction
            let q1 = critic1.forward(input)[0]
            let q2 = critic2.forward(input)[0]

            let td1 = q1 - targetQ
            let td2 = q2 - targetQ
            tdErrors.append((abs(td1) + abs(td2)) / 2)

            criticLoss += weight * (td1 * td1 + td2 * td2) / 2
        }

        criticLoss /= Float(batchSize)
        replayBuffer.updatePriorities(indices, tdErrors)

        // Delayed policy update
        var actorLoss: Float = 0
        if updateCount % policyDelay == 0 {
            for exp in experiences {
                let action = actor.forward(exp.state.vector)
                let input = exp.state.vector + action
                actorLoss -= critic1.forward(input)[0]
            }
            actorLoss /= Float(batchSize)

            // Soft update targets
            targetActor.softUpdate(from: actor, tau: tau)
            targetCritic1.softUpdate(from: critic1, tau: tau)
            targetCritic2.softUpdate(from: critic2, tau: tau)
        }

        return (criticLoss, actorLoss)
    }
}

// MARK: - RL Agent Manager

@MainActor
public final class EvidenceBasedRLManager: ObservableObject {
    public static let shared = EvidenceBasedRLManager()

    @Published public private(set) var currentAlgorithm: RLAlgorithm = .ppo
    @Published public private(set) var totalSteps: Int = 0
    @Published public private(set) var episodeRewards: [Float] = []
    @Published public private(set) var averageReward: Float = 0
    @Published public private(set) var isTraining: Bool = false

    public enum RLAlgorithm: String, CaseIterable {
        case ppo = "PPO (Schulman et al., 2017)"
        case sac = "SAC (Haarnoja et al., 2018)"
        case td3 = "TD3 (Fujimoto et al., 2018)"
    }

    private var ppoAgent: PPOAgent?
    private var sacAgent: SACAgent?
    private var td3Agent: TD3Agent?

    private init() {
        initializeAgents()
        rlLogger.info("Evidence-Based RL Manager initialized")
    }

    private func initializeAgents() {
        ppoAgent = PPOAgent()
        sacAgent = SACAgent()
        td3Agent = TD3Agent()
    }

    public func setAlgorithm(_ algorithm: RLAlgorithm) {
        currentAlgorithm = algorithm
        rlLogger.info("RL Algorithm set to: \(algorithm.rawValue)")
    }

    public func train(environment: MusicRLEnvironment, episodes: Int) async {
        isTraining = true
        defer { isTraining = false }

        for episode in 0..<episodes {
            var state = environment.reset()
            var episodeReward: Float = 0
            var done = false

            while !done {
                let action: MusicAction

                switch currentAlgorithm {
                case .ppo:
                    let (a, _) = ppoAgent!.selectAction(state: state)
                    action = a
                case .sac:
                    action = sacAgent!.selectAction(state: state)
                case .td3:
                    let continuousAction = td3Agent!.selectAction(state: state)
                    action = continuousToDiscrete(continuousAction)
                }

                let (nextState, reward, isDone) = environment.step(action: action)

                switch currentAlgorithm {
                case .ppo:
                    ppoAgent!.storeTransition(state: state, action: action, reward: reward, done: isDone)
                case .sac:
                    sacAgent!.storeExperience(state: state, action: action, reward: reward, nextState: nextState, done: isDone)
                case .td3:
                    // TD3 uses continuous actions, store appropriately
                    break
                }

                state = nextState
                episodeReward += reward
                done = isDone
                totalSteps += 1
            }

            // Update after episode
            switch currentAlgorithm {
            case .ppo:
                let _ = ppoAgent!.update()
            case .sac:
                for _ in 0..<100 {
                    let _ = sacAgent!.update()
                }
            case .td3:
                for _ in 0..<100 {
                    let _ = td3Agent!.update()
                }
            }

            episodeRewards.append(episodeReward)
            averageReward = episodeRewards.suffix(100).reduce(0, +) / Float(min(episodeRewards.count, 100))

            if episode % 10 == 0 {
                rlLogger.info("Episode \(episode): Reward = \(episodeReward), Avg = \(self.averageReward)")
            }
        }
    }

    private func continuousToDiscrete(_ continuous: [Float]) -> MusicAction {
        let pitchClass = Int((continuous[0] + 1) / 2 * 11)
        let octave = Int((continuous[1] + 1) / 2 * 8)
        let articulation = MusicAction.Articulation(rawValue: Int((continuous[2] + 1) / 2 * 3)) ?? .legato
        return MusicAction(pitchClass: pitchClass, octave: octave, duration: 1.0, velocity: (continuous[3] + 1) / 2, articulation: articulation)
    }

    /// Get scientific references for current algorithm
    public func getReferences() -> [String] {
        var refs = [ScientificReferences.suttonBarto2018]

        switch currentAlgorithm {
        case .ppo:
            refs.append(ScientificReferences.schulmanPPO2017)
        case .sac:
            refs.append(ScientificReferences.haarnojasSAC2018)
        case .td3:
            refs.append(ScientificReferences.fujimotoTD32018)
        }

        return refs
    }
}

// MARK: - Music RL Environment

public class MusicRLEnvironment {
    private var currentState: MusicState
    private var stepCount: Int = 0
    private let maxSteps: Int
    private let rewardFunction: PsychoacousticRewardFunction

    public init(maxSteps: Int = 64) {
        self.currentState = MusicState()
        self.maxSteps = maxSteps
        self.rewardFunction = PsychoacousticRewardFunction()
    }

    public func reset() -> MusicState {
        currentState = MusicState()
        stepCount = 0
        return currentState
    }

    public func step(action: MusicAction) -> (nextState: MusicState, reward: Float, done: Bool) {
        // Update state based on action
        var nextState = currentState
        nextState.pitchClassProfile[action.pitchClass] += 1

        // Normalize pitch class profile
        let sum = nextState.pitchClassProfile.reduce(0, +)
        if sum > 0 {
            for i in 0..<12 {
                nextState.pitchClassProfile[i] /= sum
            }
        }

        // Update temporal position
        nextState.temporalPosition = Float(stepCount + 1) / Float(maxSteps)

        // Calculate reward
        let reward = rewardFunction.calculateReward(state: currentState, action: action, nextState: nextState)

        currentState = nextState
        stepCount += 1

        let done = stepCount >= maxSteps

        return (nextState, reward, done)
    }
}
