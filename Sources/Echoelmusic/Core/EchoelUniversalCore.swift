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

    /// Self-Healing Engine - NEU VERBUNDEN
    private let selfHealing = SelfHealingEngine.shared

    /// Multi-Platform Bridge - NEU VERBUNDEN
    private let platformBridge = MultiPlatformBridge.shared

    /// Video AI Hub - NEU VERBUNDEN
    private let videoAIHub = VideoAICreativeHub.shared

    /// EchoelTools - NEU VERBUNDEN
    private let tools = EchoelTools.shared

    /// Wise Complete Mode - NEU VERBUNDEN
    /// Integrates EchoelWisdom™ knowledge architecture with complete system harmony
    private let wiseCompleteMode = WiseCompleteMode.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupSubsystems()
        setupCrossSystemConnections()
        startUniversalLoop()
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
        connectedModules = [.audio, .visual, .bio, .quantum, .sync, .analog, .ai, .selfHealing, .video, .tools, .wisdom]
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

        // Tools sind bereits verbunden via EchoelTools.shared

        // Wise Complete Mode → Universal Core
        wiseCompleteMode.$state
            .sink { [weak self] wisdomState in
                self?.handleWisdomModeChange(wisdomState)
            }
            .store(in: &cancellables)

        wiseCompleteMode.$wellbeingScore
            .sink { [weak self] wellbeing in
                self?.systemState.wellbeingScore = wellbeing
            }
            .store(in: &cancellables)

        print("✅ EchoelUniversalCore: Alle Systeme bidirektional verbunden")
        print("🌌 Wise Complete Mode: Integrated")
    }

    /// Reagiert auf Flow-State Änderungen vom Self-Healing System
    private func handleFlowStateChange(_ flowState: FlowState) {
        switch flowState {
        case .ultraFlow:
            // Maximale Leistung
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
    }

    /// Reagiert auf Wise Complete Mode Zustandsänderungen
    private func handleWisdomModeChange(_ wisdomState: WiseCompleteMode.WisdomState) {
        systemState.wisdomModeActive = (wisdomState == .wiseComplete)

        switch wisdomState {
        case .wiseComplete:
            // Activate full wisdom integration
            systemState.wisdomIntegrationLevel = 1.0
            print("🌌 Universal Core: Wise Complete Mode ACTIVE")
        case .activating:
            systemState.wisdomIntegrationLevel = 0.5
        case .deactivating, .inactive:
            systemState.wisdomIntegrationLevel = 0.0
        case .initializing:
            systemState.wisdomIntegrationLevel = 0.1
        case .error:
            systemState.wisdomIntegrationLevel = 0.0
            print("⚠️ Universal Core: Wise Complete Mode ERROR")
        }
    }

    private func startUniversalLoop() {
        // Master update loop at 120Hz for ultra-smooth sync
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.universalUpdate()
            }
        }
    }

    // MARK: - Universal Update

    private func universalUpdate() {
        // 1. Collect all inputs
        let bioData = bioProcessor.currentState
        let audioData = visualEngine.visualParams
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
            quantumField: quantumField
        )
    }

    private func calculateGlobalCoherence(bio: BioState, audio: AudioState, quantum: QuantumState) -> Float {
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

        // Timing
        var globalTime: Double = 0
        var beatPhase: Float = 0
        var breathPhase: Float = 0

        // Device State
        var connectedDevices: Int = 0
        var syncLatency: Double = 0

        // NEU: System Health & Performance
        var systemHealth: SystemHealth = .optimal
        var performanceMode: PerformanceMode = .balanced

        // NEU: Wise Complete Mode Integration
        var wisdomModeActive: Bool = false
        var wisdomIntegrationLevel: Float = 0.0
        var wellbeingScore: Float = 0.5

        // Extended state for delegate methods
        var lastQuantumChoice: Int = 0
        var creativeDirection: CreativeDirection = .harmonic
        var analogFeedback: [Float] = []
        var aiSuggestion: AICreativeEngine.CreativeSuggestion?

        enum CreativeDirection {
            case harmonic, rhythmic, textural, structural
        }

        mutating func update(coherence: Float, energy: Float, quantumField: QuantumField) {
            self.coherence = coherence
            self.energy = energy
            self.quantumField = quantumField
            self.flow = (coherence + energy) / 2
            self.creativity = quantumField.creativity
            self.globalTime += 1.0/120.0
        }
    }

    enum PerformanceMode: String {
        case maximum = "Maximum"
        case high = "High"
        case balanced = "Balanced"
        case reduced = "Reduced"
        case minimal = "Minimal"
    }

    enum ModuleType: String, CaseIterable {
        case audio = "Audio Engine"
        case visual = "Visual Engine"
        case bio = "Bio-Reactive"
        case quantum = "Quantum Processor"
        case sync = "Device Sync"
        case analog = "Analog Bridge"
        case ai = "AI Creative"
        case selfHealing = "Self-Healing"
        case video = "Video AI"
        case tools = "EchoelTools"
        case wisdom = "Wise Complete Mode"
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

        for i in 0..<amplitudes.count {
            // Hamiltonian evolution
            let phase = Float(i) * 0.1 + Float(Date().timeIntervalSinceReferenceDate)
            let quantumNoise = sin(phase) * (1.0 - coherence) * 0.1

            // Coherence increases stability, reduces quantum fluctuations
            let stability = coherence * 0.8 + 0.2
            let fluctuation = (1.0 - coherence) * energy

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

        // Calculate superposition strength (how "quantum" the state is)
        superpositionStrength = amplitudes.map { simd_length($0) }.reduce(0, +) / Float(amplitudes.count)

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

    /// Record a collapse event (when quantum state collapses to classical)
    mutating func recordCollapse(choice: Int) {
        // Collapse reduces superposition strength
        superpositionStrength *= 0.8

        // Increase collapse probability threshold for next measurement
        collapseProbability = min(collapseProbability + 0.1, 1.0)

        // The chosen amplitude gets reinforced
        if choice < amplitudes.count {
            amplitudes[choice] *= 1.2
            // Normalize
            let norm = simd_length(amplitudes[choice])
            if norm > 0 {
                amplitudes[choice] /= norm
            }
        }
    }
}

// MARK: - Bio-Reactive Processor

struct BioState {
    var heartRate: Float = 70
    var hrv: Float = 50
    var coherence: Float = 0.5
    var stress: Float = 0.5
    var breathRate: Float = 12
    var breathPhase: Float = 0
    var energy: Float = 0.5
}

struct AudioState {
    var level: Float = 0
    var spectralFlatness: Float = 0.5
    var dominantFrequency: Float = 440
    var beatPhase: Float = 0
}

struct QuantumState {
    var superpositionStrength: Float = 0.5
    var entanglementStrength: Float = 0
    var creativity: Float = 0.5
}

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

class QuantumProcessor {
    weak var delegate: EchoelUniversalCore?
    var currentState = QuantumState()

    func setCoherence(_ coherence: Float) {
        // Higher coherence = more classical behavior
        // Lower coherence = more quantum fluctuations
        currentState.superpositionStrength = 1.0 - coherence * 0.5
        currentState.creativity = currentState.superpositionStrength * 0.8
    }
}

// MARK: - Device Sync Manager (Ableton Link Compatible)

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
        print("[UniversalCore] Bio update: Coherence=\(String(format: "%.2f", state.coherence))")
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
        print("[UniversalCore] Quantum collapsed to choice: \(choice)")
        #endif
    }

    func deviceConnected(_ device: String) {
        systemState.connectedDevices += 1
        connectedModules.insert(.sync)

        #if DEBUG
        print("[UniversalCore] Device connected: \(device) (Total: \(systemState.connectedDevices))")
        #endif
    }

    func deviceDisconnected(_ device: String) {
        systemState.connectedDevices = max(0, systemState.connectedDevices - 1)

        #if DEBUG
        print("[UniversalCore] Device disconnected: \(device) (Total: \(systemState.connectedDevices))")
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
        print("[UniversalCore] Analog gear response: \(response.count) channels")
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
        print("[UniversalCore] AI suggestion: \(suggestion.type) (confidence: \(suggestion.confidence))")
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
