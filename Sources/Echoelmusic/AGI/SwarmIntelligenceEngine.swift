// SwarmIntelligenceEngine.swift
// Echoelmusic - Swarm Intelligence for Collaborative Music Creation
//
// Distributed AI agents collaborating like a hive mind
// Emergent creativity through collective behavior

import Foundation
import Combine
import os.log

private let swarmLogger = Logger(subsystem: "com.echoelmusic.agi", category: "Swarm")

// MARK: - Swarm Agent

public protocol SwarmAgent: AnyObject, Identifiable {
    var id: UUID { get }
    var position: SwarmPosition { get set }
    var velocity: SwarmVelocity { get set }
    var fitness: Double { get set }
    var personalBest: SwarmPosition { get set }
    var agentType: SwarmAgentType { get }

    func evaluate(in environment: SwarmEnvironment) -> Double
    func update(globalBest: SwarmPosition, neighbors: [any SwarmAgent])
    func contribute() -> MusicalContribution
}

public enum SwarmAgentType: String, CaseIterable {
    case harmonySeeker = "Harmony Seeker"
    case melodySculptor = "Melody Sculptor"
    case rhythmWeaver = "Rhythm Weaver"
    case timbreExplorer = "Timbre Explorer"
    case structureArchitect = "Structure Architect"
    case emotionGuide = "Emotion Guide"
    case noiseReducer = "Noise Reducer"
    case innovator = "Innovator"
    case conservator = "Conservator"
    case bridgeBuilder = "Bridge Builder"
}

// MARK: - Swarm Position & Velocity

public struct SwarmPosition: Equatable {
    public var dimensions: [Double]

    public init(dimensions: Int) {
        self.dimensions = [Double](repeating: 0, count: dimensions)
    }

    public init(from values: [Double]) {
        self.dimensions = values
    }

    public static func random(dimensions: Int, range: ClosedRange<Double>) -> SwarmPosition {
        SwarmPosition(from: (0..<dimensions).map { _ in Double.random(in: range) })
    }

    public static func + (lhs: SwarmPosition, rhs: SwarmVelocity) -> SwarmPosition {
        var result = lhs
        for i in 0..<min(lhs.dimensions.count, rhs.components.count) {
            result.dimensions[i] += rhs.components[i]
        }
        return result
    }

    public static func - (lhs: SwarmPosition, rhs: SwarmPosition) -> SwarmVelocity {
        var components = [Double](repeating: 0, count: lhs.dimensions.count)
        for i in 0..<min(lhs.dimensions.count, rhs.dimensions.count) {
            components[i] = lhs.dimensions[i] - rhs.dimensions[i]
        }
        return SwarmVelocity(components: components)
    }

    public func distance(to other: SwarmPosition) -> Double {
        var sum: Double = 0
        for i in 0..<min(dimensions.count, other.dimensions.count) {
            let diff = dimensions[i] - other.dimensions[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
}

public struct SwarmVelocity {
    public var components: [Double]

    public init(components: [Double]) {
        self.components = components
    }

    public static func * (lhs: Double, rhs: SwarmVelocity) -> SwarmVelocity {
        SwarmVelocity(components: rhs.components.map { lhs * $0 })
    }

    public static func + (lhs: SwarmVelocity, rhs: SwarmVelocity) -> SwarmVelocity {
        var result = lhs
        for i in 0..<min(lhs.components.count, rhs.components.count) {
            result.components[i] += rhs.components[i]
        }
        return result
    }

    public mutating func clamp(maxSpeed: Double) {
        var speed: Double = 0
        for c in components { speed += c * c }
        speed = sqrt(speed)

        if speed > maxSpeed {
            let scale = maxSpeed / speed
            for i in 0..<components.count {
                components[i] *= scale
            }
        }
    }
}

// MARK: - Musical Contribution

public struct MusicalContribution {
    public var type: ContributionType
    public var data: [Double]
    public var confidence: Double
    public var timestamp: Date

    public enum ContributionType {
        case harmony([String])
        case melody([Int])
        case rhythm([Double])
        case timbre([Double])
        case structure(String)
        case dynamics([Double])
        case articulation([Double])
    }
}

// MARK: - Swarm Environment

public struct SwarmEnvironment {
    public var currentState: MusicalState
    public var targetEmotion: EmotionalVector
    public var constraints: [SwarmConstraint]
    public var fitnessFunction: FitnessFunction

    public struct MusicalState {
        public var harmony: [Double]
        public var melody: [Double]
        public var rhythm: [Double]
        public var timbre: [Double]
        public var energy: Double
        public var complexity: Double
    }

    public struct SwarmConstraint {
        public var type: ConstraintType
        public var value: Any
        public var weight: Double

        public enum ConstraintType {
            case key, tempo, density, range, style
        }
    }

    public enum FitnessFunction {
        case emotionalAlignment
        case musicalCoherence
        case novelty
        case humanPreference
        case custom((SwarmPosition) -> Double)
    }
}

// MARK: - Concrete Swarm Agents

public final class HarmonySeekerAgent: SwarmAgent {
    public let id = UUID()
    public var position: SwarmPosition
    public var velocity: SwarmVelocity
    public var fitness: Double = 0
    public var personalBest: SwarmPosition
    public let agentType: SwarmAgentType = .harmonySeeker

    // Harmony-specific knowledge
    private var chordKnowledge: [String: Double] = [:]
    private var progressionMemory: [[String]] = []

    public init(dimensions: Int) {
        self.position = SwarmPosition.random(dimensions: dimensions, range: -1...1)
        self.velocity = SwarmVelocity(components: [Double](repeating: 0, count: dimensions))
        self.personalBest = position
        loadChordKnowledge()
    }

    public func evaluate(in environment: SwarmEnvironment) -> Double {
        // Evaluate harmonic fitness
        var score = 0.0

        // Consonance score
        let consonance = evaluateConsonance(position.dimensions)
        score += consonance * 0.4

        // Progression coherence
        let progression = evaluateProgressionCoherence(position.dimensions)
        score += progression * 0.3

        // Emotional alignment
        let emotional = evaluateEmotionalAlignment(position.dimensions, target: environment.targetEmotion)
        score += emotional * 0.3

        return score
    }

    public func update(globalBest: SwarmPosition, neighbors: [any SwarmAgent]) {
        let w = 0.7    // Inertia
        let c1 = 1.5   // Cognitive (personal best attraction)
        let c2 = 1.5   // Social (global best attraction)
        let c3 = 0.5   // Local (neighbor attraction)

        // Calculate neighbor centroid
        var neighborCentroid = position
        if !neighbors.isEmpty {
            neighborCentroid = SwarmPosition(dimensions: position.dimensions.count)
            for neighbor in neighbors {
                for i in 0..<position.dimensions.count {
                    neighborCentroid.dimensions[i] += neighbor.position.dimensions[i]
                }
            }
            for i in 0..<position.dimensions.count {
                neighborCentroid.dimensions[i] /= Double(neighbors.count)
            }
        }

        // PSO velocity update
        let r1 = Double.random(in: 0...1)
        let r2 = Double.random(in: 0...1)
        let r3 = Double.random(in: 0...1)

        let cognitive = c1 * r1 * (personalBest - position)
        let social = c2 * r2 * (globalBest - position)
        let local = c3 * r3 * (neighborCentroid - position)

        velocity = (w * velocity) + cognitive + social + local
        velocity.clamp(maxSpeed: 0.5)

        position = position + velocity

        // Clamp position to valid range
        for i in 0..<position.dimensions.count {
            position.dimensions[i] = max(-1, min(1, position.dimensions[i]))
        }
    }

    public func contribute() -> MusicalContribution {
        // Convert position to chord progression
        let chords = positionToChords(position)

        return MusicalContribution(
            type: .harmony(chords),
            data: position.dimensions,
            confidence: fitness,
            timestamp: Date()
        )
    }

    private func loadChordKnowledge() {
        chordKnowledge = [
            "I": 1.0, "IV": 0.9, "V": 0.95, "vi": 0.85,
            "ii": 0.75, "iii": 0.7, "viio": 0.5
        ]
    }

    private func evaluateConsonance(_ dims: [Double]) -> Double {
        // Higher values = more consonant intervals
        return dims.enumerated().reduce(0.0) { acc, pair in
            let (i, val) = pair
            let intervalQuality = abs(val) < 0.5 ? 1.0 : 0.5
            return acc + intervalQuality
        } / Double(dims.count)
    }

    private func evaluateProgressionCoherence(_ dims: [Double]) -> Double {
        // Check if progression follows voice leading rules
        var coherence = 0.0
        for i in 1..<dims.count {
            let step = abs(dims[i] - dims[i-1])
            coherence += step < 0.3 ? 1.0 : 0.5  // Prefer small steps
        }
        return coherence / Double(max(dims.count - 1, 1))
    }

    private func evaluateEmotionalAlignment(_ dims: [Double], target: EmotionalVector) -> Double {
        // Map dimensions to emotional space
        let valence = dims.first ?? 0
        let arousal = dims.count > 1 ? dims[1] : 0
        let distance = sqrt(pow(valence - target.valence, 2) + pow(arousal - target.arousal, 2))
        return 1.0 / (1.0 + distance)
    }

    private func positionToChords(_ pos: SwarmPosition) -> [String] {
        let chordOptions = ["I", "ii", "iii", "IV", "V", "vi", "viio"]
        return pos.dimensions.prefix(4).map { val in
            let index = Int((val + 1) / 2 * Double(chordOptions.count - 1))
            return chordOptions[max(0, min(index, chordOptions.count - 1))]
        }
    }
}

public final class MelodySculptorAgent: SwarmAgent {
    public let id = UUID()
    public var position: SwarmPosition
    public var velocity: SwarmVelocity
    public var fitness: Double = 0
    public var personalBest: SwarmPosition
    public let agentType: SwarmAgentType = .melodySculptor

    public init(dimensions: Int) {
        self.position = SwarmPosition.random(dimensions: dimensions, range: -1...1)
        self.velocity = SwarmVelocity(components: [Double](repeating: 0, count: dimensions))
        self.personalBest = position
    }

    public func evaluate(in environment: SwarmEnvironment) -> Double {
        var score = 0.0

        // Contour smoothness
        score += evaluateContourSmoothness() * 0.3

        // Range appropriateness
        score += evaluateRange() * 0.2

        // Rhythmic interest
        score += evaluateRhythmicVariety() * 0.2

        // Emotional expression
        score += evaluateExpression(target: environment.targetEmotion) * 0.3

        return score
    }

    public func update(globalBest: SwarmPosition, neighbors: [any SwarmAgent]) {
        let w = 0.6
        let c1 = 1.8
        let c2 = 1.2

        let r1 = Double.random(in: 0...1)
        let r2 = Double.random(in: 0...1)

        let cognitive = c1 * r1 * (personalBest - position)
        let social = c2 * r2 * (globalBest - position)

        velocity = (w * velocity) + cognitive + social
        velocity.clamp(maxSpeed: 0.4)

        position = position + velocity
    }

    public func contribute() -> MusicalContribution {
        let pitches = positionToPitches(position)

        return MusicalContribution(
            type: .melody(pitches),
            data: position.dimensions,
            confidence: fitness,
            timestamp: Date()
        )
    }

    private func evaluateContourSmoothness() -> Double {
        var smoothness = 0.0
        for i in 1..<position.dimensions.count {
            let interval = abs(position.dimensions[i] - position.dimensions[i-1])
            smoothness += interval < 0.2 ? 1.0 : (interval < 0.4 ? 0.7 : 0.3)
        }
        return smoothness / Double(max(position.dimensions.count - 1, 1))
    }

    private func evaluateRange() -> Double {
        guard let min = position.dimensions.min(),
              let max = position.dimensions.max() else { return 0 }
        let range = max - min
        // Prefer moderate range (0.5-0.8)
        if range >= 0.5 && range <= 0.8 { return 1.0 }
        if range >= 0.3 && range <= 1.0 { return 0.7 }
        return 0.4
    }

    private func evaluateRhythmicVariety() -> Double {
        // Check for varied durations (encoded in alternating dimensions)
        var variety = Set<Int>()
        for i in stride(from: 1, to: position.dimensions.count, by: 2) {
            let quantized = Int(position.dimensions[i] * 4)
            variety.insert(quantized)
        }
        return Double(variety.count) / 4.0
    }

    private func evaluateExpression(_ target: EmotionalVector) -> Double {
        // Rising melodies = positive valence
        var direction = 0.0
        for i in 1..<position.dimensions.count {
            direction += position.dimensions[i] - position.dimensions[i-1]
        }
        let directionScore = direction > 0 ? target.valence : -target.valence
        return (directionScore + 1) / 2
    }

    private func positionToPitches(_ pos: SwarmPosition) -> [Int] {
        let baseNote = 60  // Middle C
        return pos.dimensions.map { val in
            baseNote + Int(val * 12)  // ±12 semitones
        }
    }
}

// MARK: - Swarm Intelligence Engine

@MainActor
public final class SwarmIntelligenceEngine: ObservableObject {
    public static let shared = SwarmIntelligenceEngine()

    // MARK: - Published State

    @Published public private(set) var agents: [any SwarmAgent] = []
    @Published public private(set) var globalBest: SwarmPosition?
    @Published public private(set) var globalBestFitness: Double = 0
    @Published public private(set) var iteration: Int = 0
    @Published public private(set) var isOptimizing: Bool = false
    @Published public private(set) var convergenceHistory: [Double] = []

    // MARK: - Configuration

    public var swarmSize: Int = 50
    public var dimensions: Int = 16
    public var maxIterations: Int = 100
    public var convergenceThreshold: Double = 0.001
    public var neighborhoodSize: Int = 5

    // MARK: - Internal State

    private var environment: SwarmEnvironment?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        swarmLogger.info("Swarm Intelligence Engine initialized")
    }

    // MARK: - Public API

    /// Initialize swarm with agents
    public func initializeSwarm(
        environment: SwarmEnvironment,
        agentDistribution: [SwarmAgentType: Int]? = nil
    ) {
        self.environment = environment
        agents.removeAll()
        convergenceHistory.removeAll()
        iteration = 0
        globalBest = nil
        globalBestFitness = 0

        // Create agents based on distribution or default
        let distribution = agentDistribution ?? defaultDistribution()

        for (type, count) in distribution {
            for _ in 0..<count {
                let agent = createAgent(type: type, dimensions: dimensions)
                agents.append(agent)
            }
        }

        swarmLogger.info("Swarm initialized with \(self.agents.count) agents")
    }

    /// Run optimization
    public func optimize() async -> SwarmResult {
        guard let environment = environment else {
            return SwarmResult(success: false, message: "No environment set")
        }

        isOptimizing = true
        defer { isOptimizing = false }

        var previousBest = globalBestFitness

        for i in 0..<maxIterations {
            iteration = i

            // Evaluate all agents
            await evaluateAgents(in: environment)

            // Update global best
            updateGlobalBest()

            // Update all agents
            updateAgents()

            // Track convergence
            convergenceHistory.append(globalBestFitness)

            // Check convergence
            let improvement = globalBestFitness - previousBest
            if improvement < convergenceThreshold && i > 10 {
                swarmLogger.info("Converged at iteration \(i)")
                break
            }
            previousBest = globalBestFitness

            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        // Collect contributions from best agents
        let contributions = collectContributions()

        return SwarmResult(
            success: true,
            message: "Optimization complete",
            bestPosition: globalBest,
            bestFitness: globalBestFitness,
            contributions: contributions,
            iterations: iteration
        )
    }

    /// Single step optimization (for interactive use)
    public func step() async {
        guard let environment = environment else { return }

        await evaluateAgents(in: environment)
        updateGlobalBest()
        updateAgents()
        convergenceHistory.append(globalBestFitness)
        iteration += 1
    }

    /// Get current swarm composition
    public func getComposition() -> SwarmComposition {
        let contributions = agents.map { $0.contribute() }

        // Merge contributions by type
        var composition = SwarmComposition()

        for contribution in contributions {
            switch contribution.type {
            case .harmony(let chords):
                composition.harmony.append(contentsOf: chords)
            case .melody(let pitches):
                composition.melody.append(contentsOf: pitches)
            case .rhythm(let pattern):
                composition.rhythm.append(contentsOf: pattern)
            case .timbre(let params):
                composition.timbre.append(contentsOf: params)
            case .dynamics(let dynamics):
                composition.dynamics.append(contentsOf: dynamics)
            default:
                break
            }
        }

        return composition
    }

    /// Add agent dynamically
    public func addAgent(type: SwarmAgentType) {
        let agent = createAgent(type: type, dimensions: dimensions)
        agents.append(agent)
    }

    /// Remove agent
    public func removeAgent(id: UUID) {
        agents.removeAll { $0.id == id }
    }

    // MARK: - Private Methods

    private func defaultDistribution() -> [SwarmAgentType: Int] {
        [
            .harmonySeeker: 15,
            .melodySculptor: 15,
            .rhythmWeaver: 10,
            .emotionGuide: 5,
            .innovator: 3,
            .conservator: 2
        ]
    }

    private func createAgent(type: SwarmAgentType, dimensions: Int) -> any SwarmAgent {
        switch type {
        case .harmonySeeker:
            return HarmonySeekerAgent(dimensions: dimensions)
        case .melodySculptor:
            return MelodySculptorAgent(dimensions: dimensions)
        default:
            return HarmonySeekerAgent(dimensions: dimensions)  // Default
        }
    }

    private func evaluateAgents(in environment: SwarmEnvironment) async {
        await withTaskGroup(of: (UUID, Double).self) { group in
            for agent in agents {
                group.addTask {
                    let fitness = agent.evaluate(in: environment)
                    return (agent.id, fitness)
                }
            }

            for await (id, fitness) in group {
                if let index = agents.firstIndex(where: { $0.id == id }) {
                    agents[index].fitness = fitness

                    // Update personal best
                    if fitness > agents[index].personalBest.dimensions.reduce(0, +) {
                        agents[index].personalBest = agents[index].position
                    }
                }
            }
        }
    }

    private func updateGlobalBest() {
        for agent in agents {
            if agent.fitness > globalBestFitness {
                globalBestFitness = agent.fitness
                globalBest = agent.position
            }
        }
    }

    private func updateAgents() {
        guard let globalBest = globalBest else { return }

        for i in 0..<agents.count {
            // Find neighbors
            let neighbors = findNeighbors(for: agents[i])
            agents[i].update(globalBest: globalBest, neighbors: neighbors)
        }
    }

    private func findNeighbors(for agent: any SwarmAgent) -> [any SwarmAgent] {
        // Find k nearest neighbors
        var distances: [(agent: any SwarmAgent, distance: Double)] = []

        for other in agents where other.id != agent.id {
            let distance = agent.position.distance(to: other.position)
            distances.append((other, distance))
        }

        distances.sort { $0.distance < $1.distance }
        return Array(distances.prefix(neighborhoodSize).map { $0.agent })
    }

    private func collectContributions() -> [MusicalContribution] {
        // Get contributions from top performers
        let topAgents = agents.sorted { $0.fitness > $1.fitness }.prefix(10)
        return topAgents.map { $0.contribute() }
    }
}

// MARK: - Supporting Types

public struct SwarmResult {
    public var success: Bool
    public var message: String
    public var bestPosition: SwarmPosition?
    public var bestFitness: Double = 0
    public var contributions: [MusicalContribution] = []
    public var iterations: Int = 0
}

public struct SwarmComposition {
    public var harmony: [String] = []
    public var melody: [Int] = []
    public var rhythm: [Double] = []
    public var timbre: [Double] = []
    public var dynamics: [Double] = []
}
