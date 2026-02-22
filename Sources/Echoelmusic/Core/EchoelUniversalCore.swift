import SwiftUI
import Combine
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC UNIVERSAL CORE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Flüssiges Licht für deine Musik"
//
// Master Integration Hub - Verbindet ALLE Komponenten auf höchstem Niveau:
// • Bio-Reactive Audio Processing
// • Quantum-Inspired Algorithms
// • Multi-Device Synchronization
// • Analog & Digital Gear Integration
// • AI-Enhanced Creative Processing
// • Video/Visual Synthesis
//
// Wissenschaftliche Grundlagen:
// • HeartMath Institute - Coherence Research
// • Psychoacoustics & ISO 226:2003
// • CIE 1931 Colorimetry
// • Quantum Superposition Principles
// • Fourier Analysis & Spectral Processing
// • Ableton Link Protocol
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Universal Core

@MainActor
final class EchoelUniversalCore: ObservableObject {

    // MARK: - Singleton

    static let shared = EchoelUniversalCore()

    deinit {
        updateTimer?.cancel()
        updateTimer = nil
    }

    // MARK: - Published State

    /// Unified system state
    @Published var systemState = SystemState()

    /// All connected modules
    @Published var connectedModules: Set<ModuleType> = []

    /// Global coherence level (0-1)
    @Published var globalCoherence: Float = 0.5

    /// System energy level
    @Published var systemEnergy: Float = 0.5

    /// Quantum probability field
    @Published var quantumField = QuantumField()

    // MARK: - Sub-Systems

    /// Visual Sound Engine
    let visualEngine = UnifiedVisualSoundEngine()

    /// Bio-Reactive Processor
    private var bioProcessor = BioReactiveProcessor()

    /// Quantum Processor
    private var quantumProcessor = QuantumProcessor()

    /// Device Sync Manager
    private var syncManager = DeviceSyncManager()

    /// Analog Bridge
    private var analogBridge = AnalogGearBridge()

    /// AI Creative Engine
    private var aiEngine = AICreativeEngine()

    /// Self-Healing Engine - lazy to avoid circular singleton deadlock
    private lazy var selfHealing = SelfHealingEngine.shared

    /// Multi-Platform Bridge - lazy to avoid circular singleton deadlock
    private lazy var platformBridge = MultiPlatformBridge.shared

    /// Video AI Hub - lazy to avoid circular singleton deadlock
    private lazy var videoAIHub = VideoAICreativeHub.shared

    /// EchoelTools - lazy to avoid circular singleton deadlock
    private lazy var tools = EchoelTools.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    // LAMBDA LOOP 100%: High-precision universal timer (adaptive: 30–120Hz)
    private var updateTimer: DispatchSourceTimer?
    private let updateQueue = DispatchQueue(label: "com.echoelmusic.universal.core", qos: .userInteractive)
    /// Current tick interval in milliseconds (adaptive based on performance mode + power state)
    private var currentTickIntervalMs: Int = 8

    // MARK: - Initialization

    private init() {
        setupSubsystems()
        startUniversalLoop()
        // Defer cross-system connections to next run loop iteration
        // This ensures EchoelUniversalCore.shared is fully assigned before
        // other singletons (EchoelTools, VideoAICreativeHub) try to access it
        Task { @MainActor [weak self] in
            self?.setupCrossSystemConnections()
        }
    }

    // MARK: - Setup

    private func setupSubsystems() {
        // Connect all subsystems
        bioProcessor.delegate = self
        quantumProcessor.delegate = self
        syncManager.delegate = self
        analogBridge.delegate = self
        aiEngine.delegate = self

        // Register all modules
        connectedModules = [.audio, .visual, .bio, .quantum, .sync, .analog, .ai, .selfHealing, .video, .tools, .workspace, .collaboration]
    }

    /// NEU: Verbindet alle Systeme bidirektional
    private func setupCrossSystemConnections() {
        // Self-Healing → Universal Core
        selfHealing.$flowState
            .sink { [weak self] flowState in
                self?.handleFlowStateChange(flowState)
            }
            .store(in: &cancellables)

        selfHealing.$systemHealth
            .sink { [weak self] health in
                self?.systemState.systemHealth = health
            }
            .store(in: &cancellables)

        // EnergyEfficiencyManager → Universal Core
        // Adapt performance mode based on battery/power state throttle factor
        EnergyEfficiencyManager.shared.$systemThrottleFactor
            .removeDuplicates()
            .sink { [weak self] throttle in
                self?.handleThrottleFactorChange(throttle)
            }
            .store(in: &cancellables)

        // Tools sind bereits verbunden via EchoelTools.shared

        log.info("✅ EchoelUniversalCore: Alle Systeme bidirektional verbunden", category: .system)
    }

    /// Map energy throttle factor (0.0–1.0) to performance mode
    private func handleThrottleFactorChange(_ throttle: Float) {
        let newMode: PerformanceMode
        switch throttle {
        case ..<0.3:
            newMode = .minimal
        case 0.3..<0.5:
            newMode = .reduced
        case 0.5..<0.75:
            newMode = .balanced
        case 0.75..<0.9:
            newMode = .high
        default:
            newMode = .maximum
        }

        guard newMode != systemState.performanceMode else { return }
        systemState.performanceMode = newMode

        let newInterval = tickIntervalForCurrentMode()
        restartUniversalTimer(intervalMs: newInterval)

        log.info("Throttle factor \(String(format: "%.2f", throttle)) → \(newMode.rawValue) mode", category: .system)
    }

    /// Reagiert auf Flow-State Änderungen vom Self-Healing System
    private func handleFlowStateChange(_ flowState: FlowState) {
        switch flowState {
        case .ultraFlow:
            systemState.performanceMode = .maximum
        case .flow:
            systemState.performanceMode = .high
        case .neutral:
            systemState.performanceMode = .balanced
        case .stressed:
            systemState.performanceMode = .reduced
        case .recovery, .emergency:
            systemState.performanceMode = .minimal
        }

        // Adapt master loop tick rate to new performance mode
        let newInterval = tickIntervalForCurrentMode()
        restartUniversalTimer(intervalMs: newInterval)
    }

    private func startUniversalLoop() {
        let intervalMs = tickIntervalForCurrentMode()
        restartUniversalTimer(intervalMs: intervalMs)
    }

    /// Compute tick interval (ms) based on performance mode and system power state
    private func tickIntervalForCurrentMode() -> Int {
        #if canImport(UIKit) && !os(watchOS)
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        let lowPower = false
        #endif

        switch systemState.performanceMode {
        case .maximum, .high:
            return lowPower ? 16 : 8   // 60Hz / 120Hz
        case .balanced:
            return lowPower ? 33 : 16  // 30Hz / 60Hz
        case .reduced:
            return 33                   // 30Hz
        case .minimal:
            return 66                   // ~15Hz
        }
    }

    /// Restart the master timer at a new interval (no-op if interval unchanged)
    private func restartUniversalTimer(intervalMs: Int) {
        guard intervalMs != currentTickIntervalMs || updateTimer == nil else { return }
        currentTickIntervalMs = intervalMs

        updateTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: updateQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(max(1, intervalMs / 8)))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.universalUpdate()
            }
        }
        timer.resume()
        updateTimer = timer

        log.info("Universal loop tick rate: \(1000 / intervalMs)Hz", category: .system)
    }

    // MARK: - Universal Update

    private func universalUpdate() {
        // 1. Collect all inputs
        let bioData = bioProcessor.currentState
        let visualParams = visualEngine.visualParams
        let audioData = AudioState(
            level: Float(visualParams.energy),
            spectralFlatness: Float(1.0 - visualParams.energy),
            dominantFrequency: 440,
            beatPhase: 0
        )
        let quantumState = quantumProcessor.currentState

        // 2. Calculate global coherence
        globalCoherence = calculateGlobalCoherence(bio: bioData, audio: audioData, quantum: quantumState)

        // 3. Update quantum field
        quantumField.update(coherence: globalCoherence, energy: systemEnergy)

        // 4. Propagate to all subsystems
        propagateUniversalState()

        // 5. Sync across devices
        syncManager.broadcastState(systemState)

        // 6. Update system state
        systemState.update(
            coherence: globalCoherence,
            energy: systemEnergy,
            quantumField: quantumField,
            tickIntervalMs: currentTickIntervalMs
        )
    }

    private func calculateGlobalCoherence(bio: BioState, audio: AudioState, quantum: CoreQuantumState) -> Float {
        // Weighted combination of all coherence sources
        let bioWeight: Float = 0.4
        let audioWeight: Float = 0.3
        let quantumWeight: Float = 0.3

        let bioCoherence = bio.coherence
        let audioCoherence = 1.0 - audio.spectralFlatness  // Tonal = coherent
        let quantumCoherence = quantum.superpositionStrength

        return bioCoherence * bioWeight +
               audioCoherence * audioWeight +
               quantumCoherence * quantumWeight
    }

    private func propagateUniversalState() {
        // Update all subsystems with unified state
        visualEngine.updateBioData(
            hrv: Double(bioProcessor.currentState.hrv),
            coherence: Double(globalCoherence * 100),
            heartRate: Double(bioProcessor.currentState.heartRate)
        )

        quantumProcessor.setCoherence(globalCoherence)
        aiEngine.setCreativeState(systemState)
        analogBridge.setControlVoltages(from: systemState)

        // NEU: Broadcast zu allen externen Plattformen
        platformBridge.broadcastState(systemState)
    }

    // MARK: - Public API für externe Systeme

    /// Wird von HealthKitManager aufgerufen um Bio-Daten zu empfangen
    public func receiveBioData(heartRate: Double, hrv: Double, coherence: Double) {
        bioProcessor.updateFromHealthKit(heartRate: heartRate, hrv: hrv)

        // Direktes Update der globalen Coherence
        globalCoherence = Float(coherence / 100.0)

        // Propagiere sofort
        propagateUniversalState()
    }

    /// Wird von AudioEngine aufgerufen um Audio-Daten zu empfangen
    public func receiveAudioData(buffer: [Float]) {
        visualEngine.processAudioBuffer(buffer)

        // Update system energy basierend auf Audio
        systemEnergy = visualEngine.visualParams.energy
    }

    /// Gibt den aktuellen System-Status für UI zurück
    public func getSystemStatus() -> SystemStatus {
        return SystemStatus(
            health: selfHealing.systemHealth,
            flowState: selfHealing.flowState,
            coherence: globalCoherence,
            energy: systemEnergy,
            connectedModules: connectedModules.count,
            isHealing: selfHealing.systemHealth != .optimal
        )
    }

    public struct SystemStatus {
        var health: SystemHealth
        var flowState: FlowState
        var coherence: Float
        var energy: Float
        var connectedModules: Int
        var isHealing: Bool
    }
}

// MARK: - System State

extension EchoelUniversalCore {

    struct SystemState {
        // Core Parameters
        var coherence: Float = 0.5
        var energy: Float = 0.5
        var flow: Float = 0.5
        var creativity: Float = 0.5

        // Quantum Parameters
        var quantumField: QuantumField = QuantumField()
        var superpositionState: [Float] = []
        var entanglementStrength: Float = 0

        // Timing & Tempo
        var globalTime: Double = 0
        var beatPhase: Float = 0
        var breathPhase: Float = 0
        var bpm: Double = 120.0
        var bioTempo: Double = 0       // Heart rate as tempo suggestion
        var heartRate: Double = 0

        // Device State
        var connectedDevices: Int = 0
        var syncLatency: Double = 0

        // NEU: System Health & Performance
        var systemHealth: SystemHealth = .optimal
        var performanceMode: PerformanceMode = .balanced

        // Creative AI State
        var lastQuantumChoice: Int = 0
        var creativeDirection: CreativeDirection = .harmonic
        var analogFeedback: [Float] = []
        var aiSuggestion: AICreativeEngine.CreativeSuggestion?

        mutating func update(coherence: Float, energy: Float, quantumField: QuantumField, tickIntervalMs: Int = 8) {
            self.coherence = coherence
            self.energy = energy
            self.quantumField = quantumField
            self.flow = (coherence + energy) / 2
            self.creativity = quantumField.creativity
            self.globalTime += Double(tickIntervalMs) / 1000.0
        }
    }

    enum PerformanceMode: String {
        case maximum = "Maximum"
        case high = "High"
        case balanced = "Balanced"
        case reduced = "Reduced"
        case minimal = "Minimal"
    }

    enum CreativeDirection: String {
        case harmonic, rhythmic, textural, structural
    }

    enum ModuleType: String, CaseIterable {
        case audio = "Audio Engine"
        case visual = "Visual Engine"
        case bio = "Bio-Reactive"
        case quantum = "Quantum Processor"
        case sync = "Device Sync"
        case analog = "Analog Bridge"
        case workspace = "Creative Workspace"
        case collaboration = "Collaboration"
        case ai = "AI Creative"
        case selfHealing = "Self-Healing"
        case video = "Video AI"
        case tools = "EchoelTools"
    }
}

// MARK: - Quantum Field

struct QuantumField {
    /// Probability amplitudes for creative states
    var amplitudes: [simd_float4] = Array(repeating: simd_float4(0.5, 0.5, 0.5, 0.5), count: 16)

    /// Current superposition strength
    var superpositionStrength: Float = 0.5

    /// Entanglement with other devices
    var entanglementMatrix: [[Float]] = []

    /// Creativity emergence from quantum fluctuations
    var creativity: Float = 0.5

    /// Wave function collapse probability
    var collapseProbability: Float = 0

    mutating func update(coherence: Float, energy: Float) {
        // Quantum-inspired creative field evolution
        // Based on Schrödinger-like dynamics for creative states

        let dt: Float = 1.0/120.0
        let hbar: Float = 0.1  // Effective Planck constant for creative dynamics

        let time = Float(CACurrentMediaTime())
        let stability = coherence * 0.8 + 0.2
        let fluctuation = (1.0 - coherence) * energy

        for i in 0..<amplitudes.count {
            // Hamiltonian evolution
            let phase = Float(i) * 0.1 + time
            let quantumNoise = sin(phase) * (1.0 - coherence) * 0.1

            amplitudes[i] = simd_float4(
                amplitudes[i].x * stability + quantumNoise,
                amplitudes[i].y * stability + cos(phase * 1.1) * fluctuation * 0.1,
                amplitudes[i].z * stability + sin(phase * 1.2) * fluctuation * 0.1,
                amplitudes[i].w * stability + cos(phase * 1.3) * fluctuation * 0.1
            )

            // Normalize (preserve probability)
            let norm = simd_length(amplitudes[i])
            if norm > 0 {
                amplitudes[i] /= norm
            }
        }

        // Calculate superposition strength — avoid intermediate array allocation
        var sumStrength: Float = 0
        for amplitude in amplitudes {
            sumStrength += simd_length(amplitude)
        }
        superpositionStrength = sumStrength / Float(amplitudes.count)

        // Creativity emerges from quantum fluctuations modulated by coherence
        creativity = superpositionStrength * (1.0 - coherence * 0.5) * energy

        // Collapse probability increases with observation/coherence
        collapseProbability = coherence * coherence
    }

    /// Sample a creative decision from the quantum field
    func sampleCreativeChoice(options: Int) -> Int {
        guard options > 0 else { return 0 }

        // Build probability distribution from amplitudes
        var probabilities = [Float](repeating: 0, count: options)
        for i in 0..<min(options, amplitudes.count) {
            probabilities[i] = simd_length_squared(amplitudes[i])
        }

        // Normalize
        let total = probabilities.reduce(0, +)
        if total > 0 {
            probabilities = probabilities.map { $0 / total }
        } else {
            probabilities = [Float](repeating: 1.0/Float(options), count: options)
        }

        // Sample from distribution
        let random = Float.random(in: 0...1)
        var cumulative: Float = 0
        for i in 0..<options {
            cumulative += probabilities[i]
            if random <= cumulative {
                return i
            }
        }
        return options - 1
    }

    /// Record a wave function collapse event
    mutating func recordCollapse(choice: Int) {
        collapseProbability = 0
        // Reinforce the chosen amplitude, reduce others
        for i in 0..<amplitudes.count {
            if i == choice % amplitudes.count {
                amplitudes[i] = simd_float4(1, 0, 0, 0)
            } else {
                amplitudes[i] *= 0.5
            }
        }
    }
}

// MARK: - Bio-Reactive Processor

struct BioState {
    var heartRate: Float = 70
    var hrv: Float = 50
    var coherence: Float = 0.5
    var energy: Float = 0.5
    var stress: Float = 0.5
    var breathRate: Float = 12
    var breathPhase: Float = 0
}

struct AudioState {
    var level: Float = 0
    var spectralFlatness: Float = 0.5
    var dominantFrequency: Float = 440
    var beatPhase: Float = 0
}

struct CoreQuantumState {
    var superpositionStrength: Float = 0.5
    var entanglementStrength: Float = 0
    var creativity: Float = 0.5
}

@MainActor
class BioReactiveProcessor {
    weak var delegate: EchoelUniversalCore?
    var currentState = BioState()

    func updateFromHealthKit(heartRate: Double, hrv: Double) {
        currentState.heartRate = Float(heartRate)
        currentState.hrv = Float(hrv)

        // Calculate coherence using HeartMath algorithm
        currentState.coherence = calculateCoherence()
        currentState.stress = 1.0 - currentState.coherence
    }

    func updateState(_ state: BioState) {
        currentState = state
        currentState.coherence = calculateCoherence()
        currentState.stress = 1.0 - currentState.coherence
    }

    private func calculateCoherence() -> Float {
        // Simplified HeartMath coherence calculation
        // Real implementation would use power spectral density in 0.04-0.4 Hz band
        let normalizedHRV = currentState.hrv / 100.0
        let optimalHR: Float = 60
        let hrDeviation = abs(currentState.heartRate - optimalHR) / optimalHR

        return max(0, min(1, normalizedHRV * (1.0 - hrDeviation * 0.5)))
    }
}

// MARK: - Quantum Processor

@MainActor
class QuantumProcessor {
    weak var delegate: EchoelUniversalCore?
    var currentState = CoreQuantumState()

    func setCoherence(_ coherence: Float) {
        // Higher coherence = more classical behavior
        // Lower coherence = more quantum fluctuations
        currentState.superpositionStrength = 1.0 - coherence * 0.5
        currentState.creativity = currentState.superpositionStrength * 0.8
    }
}

// MARK: - Device Sync Manager (Ableton Link Compatible)

@MainActor
class DeviceSyncManager {
    weak var delegate: EchoelUniversalCore?

    /// Broadcast state to all connected devices
    func broadcastState(_ state: EchoelUniversalCore.SystemState) {
        // OSC broadcast to network
        // Ableton Link tempo sync
        // Custom Echoelsync protocol
    }

    /// Get connected device count
    var connectedDeviceCount: Int { 0 }
}

// MARK: - Analog Gear Bridge

@MainActor
class AnalogGearBridge {
    weak var delegate: EchoelUniversalCore?

    /// Convert system state to control voltages
    func setControlVoltages(from state: EchoelUniversalCore.SystemState) {
        // CV outputs (0-10V range)
        let coherenceCV = state.coherence * 10.0
        let energyCV = state.energy * 10.0
        let creativityCV = state.creativity * 10.0

        // Gate outputs (for triggers)
        let beatGate = state.beatPhase < 0.1
        let breathGate = state.breathPhase < 0.1

        // MIDI CC outputs
        let coherenceCC = UInt8(state.coherence * 127)
        let energyCC = UInt8(state.energy * 127)

        // These would be sent via CoreMIDI/CoreAudio to hardware
    }
}

// MARK: - AI Creative Engine

@MainActor
class AICreativeEngine {
    weak var delegate: EchoelUniversalCore?

    func setCreativeState(_ state: EchoelUniversalCore.SystemState) {
        // AI-enhanced creative suggestions based on:
        // - Current coherence (focused vs. exploratory)
        // - Energy level (intensity)
        // - Quantum creativity field
    }

    /// Generate creative suggestion
    func suggestNext(context: CreativeContext) -> CreativeSuggestion {
        // Uses quantum field to sample creative choices
        return CreativeSuggestion(type: .harmonic, confidence: 0.8)
    }

    struct CreativeContext {
        var genre: String
        var mood: String
        var energy: Float
        var coherence: Float
    }

    struct CreativeSuggestion {
        var type: SuggestionType
        var confidence: Float

        enum SuggestionType {
            case harmonic, rhythmic, textural, structural
        }
    }
}

// MARK: - Protocol Delegates

extension EchoelUniversalCore: BioReactiveProcessorDelegate,
                                QuantumProcessorDelegate,
                                DeviceSyncDelegate,
                                AnalogBridgeDelegate,
                                AIEngineDelegate {
    func bioDataUpdated(_ state: BioState) {
        // FIXED: Verarbeite Bio-Updates und propagiere
        bioProcessor.updateState(state)
        globalCoherence = state.coherence
        systemEnergy = state.energy
        propagateUniversalState()

        #if DEBUG
        log.info("[UniversalCore] Bio update: Coherence=\(String(format: "%.2f", state.coherence))", category: .system)
        #endif
    }

    func quantumStateCollapsed(to choice: Int) {
        // FIXED: Reagiere auf Quantum-Kollaps
        quantumField.recordCollapse(choice: choice)
        systemState.lastQuantumChoice = choice

        // Nutze Quantum-Entscheidung für kreative Richtung
        if choice % 2 == 0 {
            systemState.creativeDirection = .harmonic
        } else {
            systemState.creativeDirection = .rhythmic
        }

        #if DEBUG
        log.info("[UniversalCore] Quantum collapsed to choice: \(choice)", category: .system)
        #endif
    }

    func deviceConnected(_ device: String) {
        systemState.connectedDevices += 1
        connectedModules.insert(.sync)

        #if DEBUG
        log.info("[UniversalCore] Device connected: \(device) (Total: \(systemState.connectedDevices))", category: .system)
        #endif
    }

    func deviceDisconnected(_ device: String) {
        systemState.connectedDevices = max(0, systemState.connectedDevices - 1)

        #if DEBUG
        log.info("[UniversalCore] Device disconnected: \(device) (Total: \(systemState.connectedDevices))", category: .system)
        #endif
    }

    func analogGearResponded(_ response: [Float]) {
        // FIXED: Integriere Analog-Feedback ins System
        systemState.analogFeedback = response

        // Nutze CV-Feedback für Systemmodulation
        if response.count >= 2 {
            globalCoherence = globalCoherence * 0.9 + response[0] * 0.1
            systemEnergy = systemEnergy * 0.9 + response[1] * 0.1
        }

        propagateUniversalState()

        #if DEBUG
        log.info("[UniversalCore] Analog gear response: \(response.count) channels", category: .system)
        #endif
    }

    func aiSuggestionGenerated(_ suggestion: AICreativeEngine.CreativeSuggestion) {
        // FIXED: Nutze AI-Vorschläge für kreative Richtung
        systemState.aiSuggestion = suggestion

        // Bei hoher Confidence automatisch anwenden
        if suggestion.confidence > 0.8 {
            applyAISuggestion(suggestion)
        }

        #if DEBUG
        log.info("[UniversalCore] AI suggestion: \(suggestion.type) (confidence: \(suggestion.confidence))", category: .system)
        #endif
    }

    private func applyAISuggestion(_ suggestion: AICreativeEngine.CreativeSuggestion) {
        switch suggestion.type {
        case .harmonic:
            systemState.creativeDirection = .harmonic
        case .rhythmic:
            systemState.creativeDirection = .rhythmic
        case .textural:
            systemState.creativeDirection = .textural
        case .structural:
            systemState.creativeDirection = .structural
        }
    }
}

// Protocol definitions
protocol BioReactiveProcessorDelegate: AnyObject {
    func bioDataUpdated(_ state: BioState)
}

protocol QuantumProcessorDelegate: AnyObject {
    func quantumStateCollapsed(to choice: Int)
}

protocol DeviceSyncDelegate: AnyObject {
    func deviceConnected(_ device: String)
    func deviceDisconnected(_ device: String)
}

protocol AnalogBridgeDelegate: AnyObject {
    func analogGearResponded(_ response: [Float])
}

protocol AIEngineDelegate: AnyObject {
    func aiSuggestionGenerated(_ suggestion: AICreativeEngine.CreativeSuggestion)
}

// MARK: - Universal Protocol Layer

/// Unified protocol for all Echoelmusic communication
struct EchoelProtocol {

    // MARK: - Message Types

    enum MessageType: UInt8 {
        case heartbeat = 0x00
        case bioData = 0x01
        case audioData = 0x02
        case visualData = 0x03
        case quantumState = 0x04
        case syncRequest = 0x05
        case syncResponse = 0x06
        case controlVoltage = 0x07
        case midiData = 0x08
        case oscBundle = 0x09
        case aiSuggestion = 0x0A
    }

    // MARK: - OSC Address Space

    struct OSCAddresses {
        // Bio
        static let bioHeartRate = "/echoelmusic/bio/heartRate"
        static let bioHRV = "/echoelmusic/bio/hrv"
        static let bioCoherence = "/echoelmusic/bio/coherence"
        static let bioBreath = "/echoelmusic/bio/breath"

        // Audio
        static let audioLevel = "/echoelmusic/audio/level"
        static let audioBands = "/echoelmusic/audio/bands"
        static let audioFrequency = "/echoelmusic/audio/frequency"
        static let audioBeat = "/echoelmusic/audio/beat"

        // Visual
        static let visualMode = "/echoelmusic/visual/mode"
        static let visualIntensity = "/echoelmusic/visual/intensity"
        static let visualColor = "/echoelmusic/visual/color"

        // Quantum
        static let quantumCoherence = "/echoelmusic/quantum/coherence"
        static let quantumCreativity = "/echoelmusic/quantum/creativity"
        static let quantumCollapse = "/echoelmusic/quantum/collapse"

        // System
        static let systemState = "/echoelmusic/system/state"
        static let systemSync = "/echoelmusic/system/sync"
    }

    // MARK: - MIDI Mapping

    struct MIDIMapping {
        // CC numbers for core parameters
        static let coherenceCC: UInt8 = 1    // Mod wheel
        static let energyCC: UInt8 = 11      // Expression
        static let creativityCC: UInt8 = 74  // Brightness
        static let flowCC: UInt8 = 71        // Resonance

        // Note triggers
        static let beatNote: UInt8 = 36      // C1 - Kick
        static let breathNote: UInt8 = 38    // D1 - Snare
        static let collapseNote: UInt8 = 42  // F#1 - Hi-hat
    }

    // MARK: - CV Mapping (Eurorack compatible)

    struct CVMapping {
        // Voltage ranges
        static let coherenceRange: ClosedRange<Float> = 0...5   // 0-5V
        static let energyRange: ClosedRange<Float> = 0...5      // 0-5V
        static let pitchRange: ClosedRange<Float> = -5...5      // ±5V 1V/Oct
        static let gateRange: ClosedRange<Float> = 0...10       // 0/10V gate

        // Output channels
        static let coherenceOut = 1
        static let energyOut = 2
        static let creativityOut = 3
        static let pitchOut = 4
        static let beatGateOut = 5
        static let breathGateOut = 6
    }
}

// MARK: - Device Discovery

class EchoelDeviceDiscovery {

    /// Discover all Echoelmusic-compatible devices on the network
    static func discoverDevices(completion: @escaping ([DiscoveredDevice]) -> Void) {
        // Bonjour/mDNS discovery for:
        // - Other Echoelmusic instances
        // - Ableton Link sessions
        // - TouchDesigner instances
        // - Resolume instances
        // - Hardware controllers
    }

    struct DiscoveredDevice {
        var name: String
        var type: DeviceType
        var address: String
        var port: UInt16
        var capabilities: Set<Capability>

        enum DeviceType {
            case echoelmusic
            case abletonLink
            case touchDesigner
            case resolume
            case midiController
            case cvGate
            case oscDevice
        }

        enum Capability {
            case sendBio
            case receiveBio
            case sendAudio
            case receiveAudio
            case sendVisual
            case receiveVisual
            case sendMIDI
            case receiveMIDI
            case sendCV
            case receiveCV
            case sendOSC
            case receiveOSC
        }
    }
}
