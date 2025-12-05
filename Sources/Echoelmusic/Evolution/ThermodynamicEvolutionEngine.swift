import Foundation
import Combine

// MARK: - Thermodynamic Evolution Engine
// Self-evolving system inspired by Extropic's thermodynamic computing
// Treats parameters/configurations as states in an energy landscape
// Uses stochastic sampling to find optimal configurations

@MainActor
public final class ThermodynamicEvolutionEngine: ObservableObject {
    public static let shared = ThermodynamicEvolutionEngine()

    @Published public private(set) var isEvolving = true
    @Published public private(set) var currentEnergy: Double = 1.0
    @Published public private(set) var temperature: Double = 1.0
    @Published public private(set) var generationCount: Int = 0
    @Published public private(set) var optimizationHistory: [OptimizationRecord] = []
    @Published public private(set) var activeGenomes: [SystemGenome] = []

    // The system's DNA - all optimizable parameters
    private var parameterSpace: ParameterSpace
    private var currentGenome: SystemGenome

    // Energy function evaluators
    private var energyEvaluators: [EnergyEvaluator] = []

    // Metropolis-Hastings sampler
    private var sampler: MetropolisSampler

    // Learning system
    private var usageTracker: UsageTracker
    private var patternRecognizer: PatternRecognizer
    private var performanceMonitor: PerformanceMonitor

    // Persistence
    private var genomeStorage: GenomeStorage

    // Configuration
    public struct Configuration {
        public var evolutionRate: Double = 0.1
        public var initialTemperature: Double = 1.0
        public var coolingRate: Double = 0.995
        public var minTemperature: Double = 0.01
        public var populationSize: Int = 10
        public var mutationRate: Double = 0.1
        public var crossoverRate: Double = 0.3
        public var elitismCount: Int = 2
        public var evaluationInterval: TimeInterval = 60  // seconds
        public var persistInterval: TimeInterval = 300    // 5 minutes

        public static let `default` = Configuration()
        public static let aggressive = Configuration(
            evolutionRate: 0.2,
            mutationRate: 0.2,
            evaluationInterval: 30
        )
        public static let conservative = Configuration(
            evolutionRate: 0.05,
            mutationRate: 0.05,
            evaluationInterval: 120
        )
    }

    private var config = Configuration.default

    public init() {
        self.parameterSpace = ParameterSpace()
        self.currentGenome = SystemGenome.createDefault()
        self.sampler = MetropolisSampler()
        self.usageTracker = UsageTracker()
        self.patternRecognizer = PatternRecognizer()
        self.performanceMonitor = PerformanceMonitor()
        self.genomeStorage = GenomeStorage()

        setupEnergyEvaluators()
        loadPersistedGenome()
        startEvolutionLoop()
    }

    // MARK: - Evolution Control

    /// Start the evolution process
    public func startEvolution() {
        isEvolving = true
        startEvolutionLoop()
    }

    /// Pause evolution
    public func pauseEvolution() {
        isEvolving = false
    }

    /// Reset to default genome
    public func resetToDefault() {
        currentGenome = SystemGenome.createDefault()
        applyGenome(currentGenome)
        temperature = config.initialTemperature
        generationCount = 0
    }

    /// Force a mutation step
    public func forceMutation() {
        let mutated = mutate(currentGenome)
        let newEnergy = evaluateEnergy(mutated)

        if acceptTransition(from: currentEnergy, to: newEnergy) {
            currentGenome = mutated
            currentEnergy = newEnergy
            applyGenome(currentGenome)
        }
    }

    // MARK: - Parameter Registration

    /// Register a parameter for evolution
    public func registerParameter(
        _ name: String,
        category: ParameterCategory,
        range: ClosedRange<Double>,
        currentValue: Double,
        importance: Double = 1.0
    ) {
        let param = EvolvableParameter(
            name: name,
            category: category,
            range: range,
            currentValue: currentValue,
            importance: importance
        )
        parameterSpace.register(param)
        currentGenome.genes[name] = currentValue
    }

    /// Update parameter value (from user interaction)
    public func updateParameter(_ name: String, value: Double) {
        currentGenome.genes[name] = value
        usageTracker.recordInteraction(parameter: name, value: value)

        // Learn from user preference
        patternRecognizer.learnPreference(parameter: name, value: value)
    }

    // MARK: - Energy Evaluation

    private func setupEnergyEvaluators() {
        // Performance energy - lower is better
        energyEvaluators.append(PerformanceEnergyEvaluator())

        // Latency energy
        energyEvaluators.append(LatencyEnergyEvaluator())

        // Memory energy
        energyEvaluators.append(MemoryEnergyEvaluator())

        // User satisfaction energy (from implicit feedback)
        energyEvaluators.append(UserSatisfactionEnergyEvaluator())

        // Audio quality energy
        energyEvaluators.append(AudioQualityEnergyEvaluator())
    }

    private func evaluateEnergy(_ genome: SystemGenome) -> Double {
        var totalEnergy: Double = 0
        var totalWeight: Double = 0

        for evaluator in energyEvaluators {
            let energy = evaluator.evaluate(genome, context: getEvaluationContext())
            totalEnergy += energy * evaluator.weight
            totalWeight += evaluator.weight
        }

        return totalEnergy / totalWeight
    }

    private func getEvaluationContext() -> EvaluationContext {
        return EvaluationContext(
            cpuUsage: performanceMonitor.cpuUsage,
            memoryUsage: performanceMonitor.memoryUsage,
            gpuUsage: performanceMonitor.gpuUsage,
            audioLatency: performanceMonitor.audioLatency,
            frameRate: performanceMonitor.frameRate,
            userPatterns: patternRecognizer.patterns,
            deviceCapabilities: getDeviceCapabilities()
        )
    }

    // MARK: - Metropolis-Hastings Sampling

    private func acceptTransition(from oldEnergy: Double, to newEnergy: Double) -> Bool {
        if newEnergy < oldEnergy {
            return true
        }

        // Boltzmann acceptance probability
        let probability = exp(-(newEnergy - oldEnergy) / temperature)
        return Double.random(in: 0...1) < probability
    }

    private func mutate(_ genome: SystemGenome) -> SystemGenome {
        var mutated = genome

        for (name, value) in genome.genes {
            if Double.random(in: 0...1) < config.mutationRate {
                guard let param = parameterSpace.parameters[name] else { continue }

                // Gaussian mutation
                let stdDev = (param.range.upperBound - param.range.lowerBound) * 0.1
                let delta = gaussianRandom() * stdDev
                let newValue = max(param.range.lowerBound, min(param.range.upperBound, value + delta))

                mutated.genes[name] = newValue
            }
        }

        return mutated
    }

    private func crossover(_ genome1: SystemGenome, _ genome2: SystemGenome) -> SystemGenome {
        var child = SystemGenome()

        for (name, value1) in genome1.genes {
            if let value2 = genome2.genes[name] {
                // Blend crossover
                let alpha = Double.random(in: 0...1)
                child.genes[name] = alpha * value1 + (1 - alpha) * value2
            } else {
                child.genes[name] = value1
            }
        }

        return child
    }

    // MARK: - Evolution Loop

    private func startEvolutionLoop() {
        Task {
            while isEvolving {
                try? await Task.sleep(nanoseconds: UInt64(config.evaluationInterval * 1_000_000_000))

                await evolutionStep()
            }
        }
    }

    private func evolutionStep() async {
        generationCount += 1

        // Generate candidate genomes
        var candidates: [(SystemGenome, Double)] = []

        // Keep elites
        let sortedGenomes = activeGenomes.sorted { $0.fitness > $1.fitness }
        for elite in sortedGenomes.prefix(config.elitismCount) {
            candidates.append((elite, evaluateEnergy(elite)))
        }

        // Generate new candidates through mutation and crossover
        while candidates.count < config.populationSize {
            var newGenome: SystemGenome

            if Double.random(in: 0...1) < config.crossoverRate && activeGenomes.count >= 2 {
                // Crossover
                let parent1 = selectParent()
                let parent2 = selectParent()
                newGenome = crossover(parent1, parent2)
            } else {
                // Mutation
                newGenome = mutate(currentGenome)
            }

            let energy = evaluateEnergy(newGenome)
            newGenome.fitness = 1.0 / (1.0 + energy) // Convert energy to fitness
            candidates.append((newGenome, energy))
        }

        // Select best candidate using Metropolis criterion
        for (genome, energy) in candidates {
            if acceptTransition(from: currentEnergy, to: energy) {
                currentGenome = genome
                currentEnergy = energy
                applyGenome(currentGenome)
                break
            }
        }

        // Update population
        activeGenomes = candidates.map { $0.0 }

        // Cool down temperature
        temperature = max(config.minTemperature, temperature * config.coolingRate)

        // Record history
        optimizationHistory.append(OptimizationRecord(
            generation: generationCount,
            energy: currentEnergy,
            temperature: temperature,
            timestamp: Date()
        ))

        // Persist periodically
        if generationCount % Int(config.persistInterval / config.evaluationInterval) == 0 {
            await persistGenome()
        }
    }

    private func selectParent() -> SystemGenome {
        // Tournament selection
        let tournamentSize = 3
        var best: SystemGenome? = nil
        var bestFitness: Double = -Double.infinity

        for _ in 0..<tournamentSize {
            if let candidate = activeGenomes.randomElement() {
                if candidate.fitness > bestFitness {
                    best = candidate
                    bestFitness = candidate.fitness
                }
            }
        }

        return best ?? currentGenome
    }

    // MARK: - Genome Application

    private func applyGenome(_ genome: SystemGenome) {
        // Apply to audio system
        applyAudioParameters(genome)

        // Apply to visual system
        applyVisualParameters(genome)

        // Apply to AI system
        applyAIParameters(genome)

        // Apply to network system
        applyNetworkParameters(genome)

        // Notify listeners
        NotificationCenter.default.post(
            name: .genomeChanged,
            object: genome
        )
    }

    private func applyAudioParameters(_ genome: SystemGenome) {
        if let bufferSize = genome.genes["audio.bufferSize"] {
            // Apply buffer size (quantized)
            let sizes = [64, 128, 256, 512, 1024, 2048]
            let index = min(sizes.count - 1, max(0, Int(bufferSize * Double(sizes.count))))
            // AudioEngine.shared.setBufferSize(sizes[index])
        }

        if let latencyMode = genome.genes["audio.latencyMode"] {
            // Apply latency mode
        }
    }

    private func applyVisualParameters(_ genome: SystemGenome) {
        if let particleCount = genome.genes["visual.particleCount"] {
            // Adjust particle count based on performance
        }

        if let quality = genome.genes["visual.quality"] {
            // Adjust render quality
        }
    }

    private func applyAIParameters(_ genome: SystemGenome) {
        if let modelQuality = genome.genes["ai.modelQuality"] {
            // Select appropriate model size
        }

        if let batchSize = genome.genes["ai.batchSize"] {
            // Adjust inference batch size
        }
    }

    private func applyNetworkParameters(_ genome: SystemGenome) {
        if let compressionLevel = genome.genes["network.compression"] {
            // Adjust network compression
        }

        if let bufferSize = genome.genes["network.bufferSize"] {
            // Adjust network buffer
        }
    }

    // MARK: - Persistence

    private func loadPersistedGenome() {
        if let genome = genomeStorage.load() {
            currentGenome = genome
            applyGenome(genome)
        }
    }

    private func persistGenome() async {
        genomeStorage.save(currentGenome)
    }

    // MARK: - Device Capabilities

    private func getDeviceCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            cpuCores: ProcessInfo.processInfo.processorCount,
            memoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            hasGPU: true,
            gpuMemoryGB: 4,
            isPluggedIn: true
        )
    }

    // MARK: - Helpers

    private func gaussianRandom() -> Double {
        // Box-Muller transform
        let u1 = Double.random(in: 0.0001...0.9999)
        let u2 = Double.random(in: 0.0001...0.9999)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - System Genome

public struct SystemGenome: Identifiable {
    public let id = UUID()
    public var genes: [String: Double] = [:]
    public var fitness: Double = 0
    public var createdAt: Date = Date()

    public static func createDefault() -> SystemGenome {
        var genome = SystemGenome()

        // Audio parameters
        genome.genes["audio.bufferSize"] = 0.3        // Maps to 256 samples
        genome.genes["audio.latencyMode"] = 0.5       // Medium latency
        genome.genes["audio.quality"] = 0.8           // High quality

        // Visual parameters
        genome.genes["visual.particleCount"] = 0.5    // 50K particles
        genome.genes["visual.quality"] = 0.7          // High quality
        genome.genes["visual.frameRate"] = 0.75       // 60fps target

        // AI parameters
        genome.genes["ai.modelQuality"] = 0.6         // Medium-high
        genome.genes["ai.batchSize"] = 0.4            // Moderate batching
        genome.genes["ai.concurrency"] = 0.5          // Balanced

        // Network parameters
        genome.genes["network.compression"] = 0.6     // Moderate compression
        genome.genes["network.bufferSize"] = 0.3      // Low latency buffer
        genome.genes["network.retryCount"] = 0.5      // Standard retries

        // UI parameters
        genome.genes["ui.animationSpeed"] = 0.7       // Smooth animations
        genome.genes["ui.hapticIntensity"] = 0.5      // Medium haptics

        return genome
    }
}

// MARK: - Parameter Space

public class ParameterSpace {
    public var parameters: [String: EvolvableParameter] = [:]

    public func register(_ param: EvolvableParameter) {
        parameters[param.name] = param
    }
}

public struct EvolvableParameter {
    public let name: String
    public let category: ParameterCategory
    public let range: ClosedRange<Double>
    public var currentValue: Double
    public let importance: Double
}

public enum ParameterCategory: String, CaseIterable {
    case audio = "Audio"
    case visual = "Visual"
    case ai = "AI"
    case network = "Network"
    case ui = "UI"
    case performance = "Performance"
}

// MARK: - Energy Evaluators

public protocol EnergyEvaluator {
    var weight: Double { get }
    func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double
}

public struct EvaluationContext {
    public var cpuUsage: Double
    public var memoryUsage: Double
    public var gpuUsage: Double
    public var audioLatency: Double
    public var frameRate: Double
    public var userPatterns: [UserPattern]
    public var deviceCapabilities: DeviceCapabilities
}

public struct DeviceCapabilities {
    public var cpuCores: Int
    public var memoryGB: Double
    public var hasGPU: Bool
    public var gpuMemoryGB: Double
    public var isPluggedIn: Bool
}

public struct UserPattern {
    public var featureName: String
    public var usageFrequency: Double
    public var preferredValue: Double
}

public class PerformanceEnergyEvaluator: EnergyEvaluator {
    public var weight: Double = 1.0

    public func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double {
        // Higher CPU/GPU usage = higher energy (worse)
        let cpuEnergy = context.cpuUsage
        let gpuEnergy = context.gpuUsage
        let memoryEnergy = context.memoryUsage

        return (cpuEnergy + gpuEnergy + memoryEnergy) / 3.0
    }
}

public class LatencyEnergyEvaluator: EnergyEvaluator {
    public var weight: Double = 1.5

    public func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double {
        // Target 10ms latency
        let targetLatency = 10.0
        return abs(context.audioLatency - targetLatency) / 100.0
    }
}

public class MemoryEnergyEvaluator: EnergyEvaluator {
    public var weight: Double = 0.8

    public func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double {
        // Penalize high memory usage
        let maxMemory = context.deviceCapabilities.memoryGB * 0.7
        return max(0, context.memoryUsage - maxMemory) / maxMemory
    }
}

public class UserSatisfactionEnergyEvaluator: EnergyEvaluator {
    public var weight: Double = 2.0

    public func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double {
        // Lower energy for parameters closer to user preferences
        var satisfaction: Double = 0

        for pattern in context.userPatterns {
            if let geneValue = genome.genes[pattern.featureName] {
                satisfaction += abs(geneValue - pattern.preferredValue) * pattern.usageFrequency
            }
        }

        return satisfaction
    }
}

public class AudioQualityEnergyEvaluator: EnergyEvaluator {
    public var weight: Double = 1.2

    public func evaluate(_ genome: SystemGenome, context: EvaluationContext) -> Double {
        // Balance quality vs performance
        let quality = genome.genes["audio.quality"] ?? 0.5

        // High quality with good performance = low energy
        if context.cpuUsage < 0.5 {
            return (1.0 - quality) * 0.5 // Can afford high quality
        } else {
            return quality * (context.cpuUsage - 0.5) // Penalize high quality when struggling
        }
    }
}

// MARK: - Metropolis Sampler

public class MetropolisSampler {
    public func sample(from distribution: [Double]) -> Int {
        let total = distribution.reduce(0, +)
        var cumulative: Double = 0
        let random = Double.random(in: 0..<total)

        for (index, prob) in distribution.enumerated() {
            cumulative += prob
            if random < cumulative {
                return index
            }
        }

        return distribution.count - 1
    }
}

// MARK: - Usage Tracker

public class UsageTracker {
    private var interactions: [String: [InteractionRecord]] = [:]

    public func recordInteraction(parameter: String, value: Double) {
        let record = InteractionRecord(value: value, timestamp: Date())

        if interactions[parameter] == nil {
            interactions[parameter] = []
        }
        interactions[parameter]?.append(record)

        // Keep last 1000 interactions per parameter
        if interactions[parameter]?.count ?? 0 > 1000 {
            interactions[parameter]?.removeFirst()
        }
    }

    public func getAverageValue(for parameter: String) -> Double? {
        guard let records = interactions[parameter], !records.isEmpty else {
            return nil
        }
        return records.map { $0.value }.reduce(0, +) / Double(records.count)
    }
}

public struct InteractionRecord {
    public var value: Double
    public var timestamp: Date
}

// MARK: - Pattern Recognizer

public class PatternRecognizer {
    public var patterns: [UserPattern] = []

    public func learnPreference(parameter: String, value: Double) {
        if let index = patterns.firstIndex(where: { $0.featureName == parameter }) {
            // Update existing pattern with exponential moving average
            let alpha = 0.1
            patterns[index].preferredValue = alpha * value + (1 - alpha) * patterns[index].preferredValue
            patterns[index].usageFrequency += 1
        } else {
            patterns.append(UserPattern(
                featureName: parameter,
                usageFrequency: 1,
                preferredValue: value
            ))
        }
    }
}

// MARK: - Performance Monitor

public class PerformanceMonitor {
    public var cpuUsage: Double = 0
    public var memoryUsage: Double = 0
    public var gpuUsage: Double = 0
    public var audioLatency: Double = 0
    public var frameRate: Double = 60

    public init() {
        startMonitoring()
    }

    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }

    private func updateMetrics() {
        // Get actual system metrics
        cpuUsage = getCPUUsage()
        memoryUsage = getMemoryUsage()
        gpuUsage = getGPUUsage()
    }

    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory)
        }
        return 0
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return Double(info.resident_size) / 1_073_741_824 // GB
    }

    private func getGPUUsage() -> Double {
        // GPU usage would require Metal performance counters
        return 0.3 // Placeholder
    }
}

// MARK: - Genome Storage

public class GenomeStorage {
    private let fileURL: URL

    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documentsPath.appendingPathComponent("evolved_genome.json")
    }

    public func save(_ genome: SystemGenome) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(genome.genes) {
            try? data.write(to: fileURL)
        }
    }

    public func load() -> SystemGenome? {
        guard let data = try? Data(contentsOf: fileURL),
              let genes = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return nil
        }

        var genome = SystemGenome()
        genome.genes = genes
        return genome
    }
}

// MARK: - Optimization Record

public struct OptimizationRecord: Identifiable {
    public let id = UUID()
    public var generation: Int
    public var energy: Double
    public var temperature: Double
    public var timestamp: Date
}

// MARK: - Notifications

public extension Notification.Name {
    static let genomeChanged = Notification.Name("genomeChanged")
}
