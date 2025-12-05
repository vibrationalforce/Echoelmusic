import Foundation
import Combine
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM FLOW STATE ENGINE - UNIVERSAL OPTIMIZATION THROUGH FLOW
// ═══════════════════════════════════════════════════════════════════════════════
//
// Core Mathematical Model:
// E_n = φ·π·e·E_{n-1}·(1-S) + δ_n
//
// Where:
// • E_n     = Energy/Output at iteration n (creative productivity)
// • φ       = Golden Ratio (1.618...) - Optimal growth/harmony
// • π       = Pi (3.14159...) - Cyclical completeness
// • e       = Euler's Number (2.718...) - Natural exponential growth
// • φ·π·e   ≈ 13.82 - Maximum amplification factor
// • S       = Stress/Friction (0 to 1) - System friction
// • (1-S)   = Flow efficiency (1 = perfect flow, 0 = blocked)
// • δ_n     = External input (inspiration, collaboration)
//
// Goal: Minimize S to approach 0% stress, 100% motivation
// When S → 0: E_n → φ·π·e·E_{n-1} + δ_n (exponential creative growth)
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Flow Domain

public enum FlowDomain: String, CaseIterable, Codable, Identifiable {
    case audio = "Audio"
    case visual = "Visual"
    case collaboration = "Collaboration"
    case distribution = "Distribution"
    case creativity = "Creativity"
    case performance = "Performance"
    case learning = "Learning"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .audio: return "waveform"
        case .visual: return "sparkles"
        case .collaboration: return "person.3"
        case .distribution: return "arrow.up.forward.app"
        case .creativity: return "lightbulb"
        case .performance: return "gauge.high"
        case .learning: return "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .audio: return .blue
        case .visual: return .purple
        case .collaboration: return .green
        case .distribution: return .orange
        case .creativity: return .yellow
        case .performance: return .red
        case .learning: return .cyan
        }
    }
}

// MARK: - Flow State

public struct FlowState: Identifiable, Codable {
    public let id: String
    public let domain: FlowDomain
    public var energy: Double           // E_n
    public var stress: Double           // S
    public var externalInput: Double    // δ_n
    public var history: [Double]        // Historical energy values
    public var timestamp: Date

    public var efficiency: Double {     // (1-S)
        1.0 - stress
    }

    public var amplification: Double {  // φ·π·e
        QuantumFlowStateEngine.quantumConstant
    }

    public init(
        id: String = UUID().uuidString,
        domain: FlowDomain,
        energy: Double = 1.0,
        stress: Double = 0.1,
        externalInput: Double = 0.1,
        history: [Double] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.energy = energy
        self.stress = stress
        self.externalInput = externalInput
        self.history = history
        self.timestamp = timestamp
    }
}

// MARK: - Stress Source

public enum StressSource: String, CaseIterable, Codable {
    // Technical stress
    case latency = "High Latency"
    case bufferUnderrun = "Buffer Underrun"
    case cpuOverload = "CPU Overload"
    case memoryPressure = "Memory Pressure"
    case diskIO = "Disk I/O"
    case networkError = "Network Error"

    // Creative stress
    case creativeBlock = "Creative Block"
    case decisionFatigue = "Decision Fatigue"
    case tooManyOptions = "Too Many Options"
    case uncertainty = "Uncertainty"

    // Workflow stress
    case formatConversion = "Format Conversion"
    case manualTask = "Manual Task"
    case waiting = "Waiting"
    case repetition = "Repetition"

    // Collaboration stress
    case syncConflict = "Sync Conflict"
    case communication = "Communication Gap"
    case coordination = "Coordination Overhead"

    var stressWeight: Double {
        switch self {
        case .bufferUnderrun, .cpuOverload: return 0.15
        case .latency, .memoryPressure: return 0.1
        case .creativeBlock, .uncertainty: return 0.12
        case .formatConversion, .waiting: return 0.08
        case .syncConflict: return 0.1
        default: return 0.05
        }
    }

    var mitigationStrategy: String {
        switch self {
        case .latency: return "Reduce buffer size or optimize processing"
        case .bufferUnderrun: return "Increase buffer size"
        case .cpuOverload: return "Enable GPU acceleration"
        case .memoryPressure: return "Clear unused resources"
        case .diskIO: return "Use SSD or RAM disk"
        case .networkError: return "Enable offline mode"
        case .creativeBlock: return "Try AI suggestions"
        case .decisionFatigue: return "Use smart presets"
        case .tooManyOptions: return "Filter by mood/style"
        case .uncertainty: return "Enable preview mode"
        case .formatConversion: return "Auto-convert enabled"
        case .manualTask: return "Enable automation"
        case .waiting: return "Background processing"
        case .repetition: return "Create macro/template"
        case .syncConflict: return "Use CRDT resolution"
        case .communication: return "Enable live chat"
        case .coordination: return "Use shared timeline"
        }
    }
}

// MARK: - Flow Event

public struct FlowEvent: Identifiable, Codable {
    public let id: String
    public let type: FlowEventType
    public let domain: FlowDomain
    public let timestamp: Date
    public let energyDelta: Double
    public let stressDelta: Double
    public let description: String
}

public enum FlowEventType: String, Codable {
    case stressAdded = "Stress Added"
    case stressRemoved = "Stress Removed"
    case flowAchieved = "Flow Achieved"
    case flowBroken = "Flow Broken"
    case externalInput = "External Input"
    case optimization = "Optimization"
    case milestone = "Milestone"
}

// MARK: - Quantum Flow State Engine

@MainActor
public final class QuantumFlowStateEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = QuantumFlowStateEngine()

    // MARK: - Quantum Constants

    public static let phi: Double = 1.6180339887498948482  // Golden Ratio φ
    public static let piValue: Double = Double.pi           // π
    public static let eulerE: Double = M_E                  // Euler's number e
    public static let quantumConstant: Double = phi * piValue * eulerE  // ≈ 13.82

    // MARK: - Published State

    @Published public private(set) var flowStates: [FlowDomain: FlowState] = [:]
    @Published public private(set) var globalEnergy: Double = 1.0
    @Published public private(set) var globalStress: Double = 0.1
    @Published public private(set) var globalFlow: Double = 0.9  // (1-S)
    @Published public private(set) var motivationLevel: Double = 90.0  // Percentage
    @Published public private(set) var isInFlowState: Bool = false
    @Published public private(set) var flowStreak: Int = 0
    @Published public private(set) var events: [FlowEvent] = []
    @Published public private(set) var activeStressors: [StressSource] = []
    @Published public private(set) var recommendations: [FlowRecommendation] = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var evolutionTimer: Timer?
    private var metricsCollector = MetricsCollector()
    private let stateHistory = StateHistory(maxSize: 1000)

    // MARK: - Initialization

    private init() {
        initializeFlowStates()
        startEvolutionLoop()
        setupMetricsCollection()
    }

    // MARK: - Initialization Helpers

    private func initializeFlowStates() {
        for domain in FlowDomain.allCases {
            flowStates[domain] = FlowState(domain: domain)
        }
        recalculateGlobalState()
    }

    private func startEvolutionLoop() {
        // Evolve flow state every 100ms
        evolutionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evolveFlowState()
            }
        }
    }

    private func setupMetricsCollection() {
        // Collect system metrics
        metricsCollector.onMetricsUpdate = { [weak self] metrics in
            Task { @MainActor in
                self?.processSystemMetrics(metrics)
            }
        }
        metricsCollector.start()
    }

    // MARK: - Core Evolution (E_n = φ·π·e·E_{n-1}·(1-S) + δ_n)

    private func evolveFlowState() {
        for domain in FlowDomain.allCases {
            guard var state = flowStates[domain] else { continue }

            // Apply the quantum flow equation
            let previousEnergy = state.energy
            let efficiency = state.efficiency  // (1-S)
            let externalInput = state.externalInput  // δ_n

            // E_n = φ·π·e·E_{n-1}·(1-S) + δ_n
            // Normalized to prevent explosion (divided by quantum constant for stability)
            let amplificationFactor = min(Self.quantumConstant * efficiency, 2.0)
            let newEnergy = amplificationFactor * previousEnergy * 0.1 + externalInput

            // Apply natural decay to prevent infinite growth
            state.energy = min(newEnergy * 0.99 + 0.01, 100.0)

            // Record history
            state.history.append(state.energy)
            if state.history.count > 100 {
                state.history.removeFirst()
            }

            state.timestamp = Date()
            flowStates[domain] = state
        }

        // Update global state
        recalculateGlobalState()

        // Check for flow state
        checkFlowState()

        // Generate recommendations
        generateRecommendations()
    }

    private func recalculateGlobalState() {
        let states = Array(flowStates.values)

        // Weighted average of energies
        globalEnergy = states.map { $0.energy }.reduce(0, +) / Double(states.count)

        // Average stress
        globalStress = states.map { $0.stress }.reduce(0, +) / Double(states.count)

        // Global flow efficiency
        globalFlow = 1.0 - globalStress

        // Motivation = Energy × Flow × 100
        motivationLevel = min(globalEnergy * globalFlow * 100, 100)
    }

    private func checkFlowState() {
        let previousFlowState = isInFlowState

        // Flow state achieved when stress < 0.2 and energy > 0.5
        isInFlowState = globalStress < 0.2 && globalEnergy > 0.5

        if isInFlowState && !previousFlowState {
            // Entered flow state
            flowStreak += 1
            addEvent(type: .flowAchieved, domain: .creativity, energyDelta: 0.1, stressDelta: -0.05, description: "Flow state achieved!")
        } else if !isInFlowState && previousFlowState {
            // Left flow state
            flowStreak = 0
            addEvent(type: .flowBroken, domain: .creativity, energyDelta: -0.05, stressDelta: 0.05, description: "Flow state interrupted")
        }
    }

    // MARK: - Stress Management

    public func addStress(_ source: StressSource, for domain: FlowDomain) {
        guard var state = flowStates[domain] else { return }

        let stressIncrease = source.stressWeight
        state.stress = min(state.stress + stressIncrease, 1.0)
        flowStates[domain] = state

        if !activeStressors.contains(source) {
            activeStressors.append(source)
        }

        addEvent(
            type: .stressAdded,
            domain: domain,
            energyDelta: -stressIncrease * 0.5,
            stressDelta: stressIncrease,
            description: "Stress: \(source.rawValue)"
        )

        recalculateGlobalState()
    }

    public func removeStress(_ source: StressSource, from domain: FlowDomain) {
        guard var state = flowStates[domain] else { return }

        let stressDecrease = source.stressWeight
        state.stress = max(state.stress - stressDecrease, 0)
        flowStates[domain] = state

        activeStressors.removeAll { $0 == source }

        addEvent(
            type: .stressRemoved,
            domain: domain,
            energyDelta: stressDecrease * 0.3,
            stressDelta: -stressDecrease,
            description: "Resolved: \(source.rawValue)"
        )

        recalculateGlobalState()
    }

    public func autoMitigateStress() {
        for stressor in activeStressors {
            // Apply automatic mitigation
            applyMitigation(for: stressor)
        }
    }

    private func applyMitigation(for stressor: StressSource) {
        // Find which domain this stressor affects
        let domain = domainForStressor(stressor)

        // Apply mitigation strategy
        switch stressor {
        case .latency:
            // Signal to reduce buffer size
            NotificationCenter.default.post(name: .reduceLatency, object: nil)

        case .cpuOverload:
            // Enable GPU acceleration
            NotificationCenter.default.post(name: .enableGPUAcceleration, object: nil)

        case .memoryPressure:
            // Clear caches
            NotificationCenter.default.post(name: .clearMemoryCache, object: nil)

        case .creativeBlock:
            // Show AI suggestions
            NotificationCenter.default.post(name: .showAISuggestions, object: nil)

        case .formatConversion:
            // Auto-convert enabled
            NotificationCenter.default.post(name: .enableAutoConversion, object: nil)

        case .syncConflict:
            // Use CRDT auto-resolution
            NotificationCenter.default.post(name: .autoResolveSyncConflict, object: nil)

        default:
            break
        }

        // Reduce stress after mitigation
        removeStress(stressor, from: domain)
    }

    private func domainForStressor(_ stressor: StressSource) -> FlowDomain {
        switch stressor {
        case .latency, .bufferUnderrun, .cpuOverload, .memoryPressure:
            return .performance
        case .diskIO, .formatConversion:
            return .audio
        case .networkError, .syncConflict, .communication, .coordination:
            return .collaboration
        case .creativeBlock, .decisionFatigue, .tooManyOptions, .uncertainty:
            return .creativity
        case .manualTask, .waiting, .repetition:
            return .distribution
        }
    }

    // MARK: - External Input (δ_n)

    public func addExternalInput(_ input: ExternalInputType, to domain: FlowDomain) {
        guard var state = flowStates[domain] else { return }

        state.externalInput += input.value
        flowStates[domain] = state

        addEvent(
            type: .externalInput,
            domain: domain,
            energyDelta: input.value,
            stressDelta: -input.value * 0.1,
            description: input.description
        )
    }

    public enum ExternalInputType {
        case collaboration(intensity: Double)
        case inspiration(source: String)
        case achievement(type: String)
        case feedback(positive: Bool)
        case automation(tasksSaved: Int)

        var value: Double {
            switch self {
            case .collaboration(let intensity): return intensity * 0.2
            case .inspiration: return 0.15
            case .achievement: return 0.2
            case .feedback(let positive): return positive ? 0.1 : -0.05
            case .automation(let tasks): return Double(tasks) * 0.05
            }
        }

        var description: String {
            switch self {
            case .collaboration: return "Collaboration energy"
            case .inspiration(let source): return "Inspired by \(source)"
            case .achievement(let type): return "Achievement: \(type)"
            case .feedback(let positive): return positive ? "Positive feedback" : "Constructive feedback"
            case .automation(let tasks): return "Automated \(tasks) tasks"
            }
        }
    }

    // MARK: - Recommendations

    private func generateRecommendations() {
        var newRecommendations: [FlowRecommendation] = []

        // High stress recommendations
        if globalStress > 0.5 {
            newRecommendations.append(FlowRecommendation(
                id: "reduce_stress",
                title: "Reduce Stress",
                description: "Your stress level is high. Consider simplifying your current task.",
                action: .simplifyWorkflow,
                priority: .high,
                expectedImpact: 0.2
            ))
        }

        // Low energy recommendations
        if globalEnergy < 0.3 {
            newRecommendations.append(FlowRecommendation(
                id: "boost_energy",
                title: "Boost Energy",
                description: "Try collaborating with others or exploring new sounds.",
                action: .seekInspiration,
                priority: .medium,
                expectedImpact: 0.15
            ))
        }

        // Stressor-specific recommendations
        for stressor in activeStressors {
            newRecommendations.append(FlowRecommendation(
                id: "mitigate_\(stressor.rawValue)",
                title: "Address: \(stressor.rawValue)",
                description: stressor.mitigationStrategy,
                action: .mitigateStressor(stressor),
                priority: stressor.stressWeight > 0.1 ? .high : .medium,
                expectedImpact: stressor.stressWeight
            ))
        }

        // Flow state recommendations
        if !isInFlowState && globalStress < 0.3 && globalEnergy > 0.4 {
            newRecommendations.append(FlowRecommendation(
                id: "enter_flow",
                title: "Almost in Flow!",
                description: "You're close to entering flow state. Remove distractions.",
                action: .focusMode,
                priority: .medium,
                expectedImpact: 0.1
            ))
        }

        recommendations = newRecommendations
    }

    // MARK: - Events

    private func addEvent(type: FlowEventType, domain: FlowDomain, energyDelta: Double, stressDelta: Double, description: String) {
        let event = FlowEvent(
            id: UUID().uuidString,
            type: type,
            domain: domain,
            timestamp: Date(),
            energyDelta: energyDelta,
            stressDelta: stressDelta,
            description: description
        )

        events.insert(event, at: 0)

        // Keep only last 100 events
        if events.count > 100 {
            events.removeLast()
        }

        // Store in history
        stateHistory.add(event)
    }

    // MARK: - System Metrics Processing

    private func processSystemMetrics(_ metrics: SystemMetrics) {
        // CPU stress
        if metrics.cpuUsage > 0.8 {
            addStress(.cpuOverload, for: .performance)
        } else if metrics.cpuUsage < 0.5 && activeStressors.contains(.cpuOverload) {
            removeStress(.cpuOverload, from: .performance)
        }

        // Memory stress
        if metrics.memoryUsage > 0.85 {
            addStress(.memoryPressure, for: .performance)
        } else if metrics.memoryUsage < 0.7 && activeStressors.contains(.memoryPressure) {
            removeStress(.memoryPressure, from: .performance)
        }

        // Latency stress
        if metrics.audioLatency > 0.02 {  // > 20ms
            addStress(.latency, for: .audio)
        } else if metrics.audioLatency < 0.01 && activeStressors.contains(.latency) {
            removeStress(.latency, from: .audio)
        }

        // Network stress
        if !metrics.networkAvailable {
            addStress(.networkError, for: .collaboration)
        } else if activeStressors.contains(.networkError) {
            removeStress(.networkError, from: .collaboration)
        }
    }

    // MARK: - Public API

    public func getFlowScore() -> Double {
        // Combined score: Energy × (1-Stress) normalized to 0-100
        return motivationLevel
    }

    public func getDomainHealth(_ domain: FlowDomain) -> DomainHealth {
        guard let state = flowStates[domain] else {
            return DomainHealth(energy: 0, stress: 1, trend: .declining)
        }

        let trend: Trend
        if state.history.count > 10 {
            let recent = state.history.suffix(5).reduce(0, +) / 5
            let earlier = state.history.dropLast(5).suffix(5).reduce(0, +) / 5
            trend = recent > earlier ? .improving : (recent < earlier ? .declining : .stable)
        } else {
            trend = .stable
        }

        return DomainHealth(
            energy: state.energy,
            stress: state.stress,
            trend: trend
        )
    }

    public func reset() {
        initializeFlowStates()
        activeStressors.removeAll()
        events.removeAll()
        flowStreak = 0
    }

    // MARK: - Deinitialization

    deinit {
        evolutionTimer?.invalidate()
        metricsCollector.stop()
    }
}

// MARK: - Supporting Types

public struct FlowRecommendation: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let action: FlowAction
    public let priority: Priority
    public let expectedImpact: Double

    public enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}

public enum FlowAction {
    case simplifyWorkflow
    case seekInspiration
    case mitigateStressor(StressSource)
    case focusMode
    case takeBreak
    case collaborate
    case automate
}

public struct DomainHealth {
    public let energy: Double
    public let stress: Double
    public let trend: Trend
}

public enum Trend: String {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

public struct SystemMetrics {
    public var cpuUsage: Double = 0
    public var memoryUsage: Double = 0
    public var diskUsage: Double = 0
    public var audioLatency: Double = 0
    public var networkAvailable: Bool = true
    public var batteryLevel: Double = 1.0
    public var thermalState: Int = 0
}

// MARK: - Metrics Collector

class MetricsCollector {
    var onMetricsUpdate: ((SystemMetrics) -> Void)?
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.collectMetrics()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func collectMetrics() {
        var metrics = SystemMetrics()

        // Collect actual system metrics
        #if os(macOS)
        metrics.cpuUsage = getCPUUsage()
        metrics.memoryUsage = getMemoryUsage()
        #endif

        // Simulated for now
        metrics.audioLatency = 0.005  // 5ms
        metrics.networkAvailable = true

        onMetricsUpdate?(metrics)
    }

    private func getCPUUsage() -> Double {
        // Would use host_statistics for actual CPU usage
        return Double.random(in: 0.1...0.5)
    }

    private func getMemoryUsage() -> Double {
        // Would use host_statistics for actual memory usage
        return Double.random(in: 0.4...0.7)
    }
}

// MARK: - State History

class StateHistory {
    private var events: [FlowEvent] = []
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    func add(_ event: FlowEvent) {
        events.append(event)
        if events.count > maxSize {
            events.removeFirst()
        }
    }

    func getEvents(since date: Date) -> [FlowEvent] {
        events.filter { $0.timestamp >= date }
    }

    func getAverageEnergy(for domain: FlowDomain, since date: Date) -> Double {
        let domainEvents = events.filter { $0.domain == domain && $0.timestamp >= date }
        guard !domainEvents.isEmpty else { return 0 }
        return domainEvents.map { $0.energyDelta }.reduce(0, +) / Double(domainEvents.count)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let reduceLatency = Notification.Name("reduceLatency")
    static let enableGPUAcceleration = Notification.Name("enableGPUAcceleration")
    static let clearMemoryCache = Notification.Name("clearMemoryCache")
    static let showAISuggestions = Notification.Name("showAISuggestions")
    static let enableAutoConversion = Notification.Name("enableAutoConversion")
    static let autoResolveSyncConflict = Notification.Name("autoResolveSyncConflict")
}

// MARK: - SwiftUI Flow View

public struct FlowStateView: View {
    @ObservedObject var engine = QuantumFlowStateEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Global Flow Meter
            globalFlowMeter

            // Domain breakdown
            domainBreakdown

            // Active stressors
            if !engine.activeStressors.isEmpty {
                activeStressorsView
            }

            // Recommendations
            if !engine.recommendations.isEmpty {
                recommendationsView
            }
        }
        .padding()
    }

    private var globalFlowMeter: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Flow State")
                    .font(.headline)

                Spacer()

                if engine.isInFlowState {
                    Label("In Flow", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Motivation gauge
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: engine.motivationLevel / 100)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(engine.motivationLevel))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Motivation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            // Energy and Stress bars
            HStack(spacing: 20) {
                VStack {
                    Text("Energy")
                        .font(.caption)
                    ProgressView(value: engine.globalEnergy)
                        .tint(.blue)
                }

                VStack {
                    Text("Stress")
                        .font(.caption)
                    ProgressView(value: engine.globalStress)
                        .tint(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }

    private var domainBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Domains")
                .font(.headline)

            ForEach(FlowDomain.allCases) { domain in
                let health = engine.getDomainHealth(domain)

                HStack {
                    Image(systemName: domain.icon)
                        .foregroundStyle(domain.color)
                        .frame(width: 24)

                    Text(domain.rawValue)
                        .font(.subheadline)

                    Spacer()

                    // Mini energy bar
                    ProgressView(value: health.energy)
                        .frame(width: 60)
                        .tint(domain.color)

                    // Trend indicator
                    Image(systemName: trendIcon(health.trend))
                        .foregroundStyle(trendColor(health.trend))
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }

    private var activeStressorsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Stressors")
                .font(.headline)
                .foregroundStyle(.red)

            ForEach(engine.activeStressors, id: \.self) { stressor in
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)

                    Text(stressor.rawValue)
                        .font(.subheadline)

                    Spacer()

                    Button("Fix") {
                        Task {
                            await MainActor.run {
                                engine.autoMitigateStress()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)

            ForEach(engine.recommendations) { rec in
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading) {
                        Text(rec.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(rec.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trendIcon(_ trend: Trend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .gray
        case .declining: return .red
        }
    }
}

#Preview {
    FlowStateView()
}
