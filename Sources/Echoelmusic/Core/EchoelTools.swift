import SwiftUI
import Combine
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELTOOLS - ULTIMATE CREATIVE INTELLIGENCE SUITE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Liquid Light Creativity Engine - Where Science Meets Soul"
//
// 16 Intelligent Tools + ToolChain + Presets:
//
// ORIGINAL 8 (Enhanced):
// • HarmonicIntelligence  - AI chord/scale suggestions
// • RhythmicIntelligence  - Heart-synced patterns
// • SpectralSculptor      - Frequency shaping
// • BioSonifier           - Biometric → Audio
// • QuantumComposer       - Quantum-inspired decisions
// • FlowEngine            - Ultra flow state detection
// • Spatializer           - 3D audio positioning
// • TimeStretcher         - Breath-synced time
//
// NEW 8 (Wave Alchemy + Warp Inspired):
// • FlowMotion            - Bio-synced motion sequencer
// • PulseForge            - Quantum polyrhythmic engine
// • SoulPrint             - Analog humanization
// • BlendScape            - XY layer morphing
// • BioNexus              - 8 biometric macro controls
// • ChronoWarp            - 8 time-stretch algorithms
// • ChanceField           - Probabilistic sequencing
// • SpectrumWeaver        - Advanced FFT processing
//
// Integration Bridges:
// • AudioBridge           - 50+ DSP effects
// • BioBridge             - HealthKit, HRV, Coherence
// • IntelligenceBridge    - AI Composer, ML Models
// • HardwareBridge        - MIDI 2.0, Push3, OSC
// • VisualBridge          - Visualizers, LED control
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - EchoelTools Main Class

@MainActor
public final class EchoelTools: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelTools()

    // MARK: - Published State

    @Published public var activeTool: Tool = .none
    @Published public var activeTools: Set<Tool> = []
    @Published public var toolState: ToolState = ToolState()
    @Published public var flowMultiplier: Float = 1.0
    @Published public var creativityBoost: Float = 1.0
    @Published public var isToolChainActive: Bool = false
    @Published public var currentPreset: ToolPreset?

    // MARK: - Original 8 Tools (Enhanced)

    public let harmonicIntelligence = HarmonicIntelligence()
    public let rhythmicIntelligence = RhythmicIntelligence()
    public let spectralSculptor = SpectralSculptor()
    public let bioSonifier = BioSonifier()
    public let quantumComposer = QuantumComposer()
    public let flowEngine = FlowEngine()
    public let spatializer = Spatializer()
    public let timeStretcher = TimeStretcher()

    // MARK: - New 8 Tools (Wave Alchemy + Warp Inspired)

    public let flowMotion = FlowMotion()
    public let pulseForge = PulseForge()
    public let soulPrint = SoulPrint()
    public let blendScape = BlendScape()
    public let bioNexus = BioNexus()
    public let chronoWarp = ChronoWarp()
    public let chanceField = ChanceField()
    public let spectrumWeaver = SpectrumWeaver()

    // MARK: - Ultra 8 Tools (Advanced Synthesis & Production)

    public let grainCloud = GrainCloud()
    public let harmoniX = HarmoniX()
    public let drumForge = DrumForge()
    public let synthWeaver = SynthWeaver()
    public let vocalShift = VocalShift()
    public let ambientScape = AmbientScape()
    public let bassArchitect = BassArchitect()
    public let mixMatrix = MixMatrix()

    // MARK: - Tool Chain & Presets

    public let toolChain = ToolChain()
    public let presetManager = PresetManager()

    // MARK: - Integration Bridges

    public let audioBridge = AudioBridge()
    public let bioBridge = BioBridge()
    public let intelligenceBridge = IntelligenceBridge()
    public let hardwareBridge = HardwareBridge()
    public let visualBridge = VisualBridge()

    // MARK: - System References

    private let universalCore = EchoelUniversalCore.shared
    private let selfHealing = SelfHealingEngine.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupToolConnections()
        setupBridgeConnections()
        setupToolChain()
        activateUltraFlow()
        startToolsUpdateLoop()
        print("🎛️ EchoelTools: 24 Creative Tools + ToolChain initialized")
    }

    // MARK: - Cleanup (CRITICAL FIX - Timer Leak Prevention)

    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        deactivateAll()
        print("🧹 EchoelTools: Cleanup complete - All timers invalidated")
    }

    // MARK: - Setup

    private func setupToolConnections() {
        // Connect to Universal Core state
        universalCore.$systemState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateToolsWithState(state)
            }
            .store(in: &cancellables)

        // Connect to Self-Healing flow state
        selfHealing.$flowState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] flowState in
                self?.adjustToolsForFlowState(flowState)
            }
            .store(in: &cancellables)
    }

    private func setupBridgeConnections() {
        // Bio Bridge → All bio-reactive tools
        bioBridge.$currentBioState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bioState in
                self?.propagateBioState(bioState)
            }
            .store(in: &cancellables)

        // Audio Bridge → Spectral tools
        audioBridge.$spectrumData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] spectrum in
                self?.spectrumWeaver.updateSpectrum(spectrum)
                self?.spectralSculptor.updateSpectrum(spectrum)
            }
            .store(in: &cancellables)
    }

    private func setupToolChain() {
        toolChain.onChainUpdated = { [weak self] in
            self?.processToolChain()
        }
    }

    private func activateUltraFlow() {
        flowMultiplier = 1.5
        creativityBoost = 1.2
        toolState.ultraFlowEnabled = true
    }

    private func startToolsUpdateLoop() {
        // 60 Hz update loop for real-time responsiveness
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateToolsRealtime()
            }
        }
    }

    // MARK: - Real-time Updates

    private func updateToolsRealtime() {
        guard !activeTools.isEmpty || isToolChainActive else { return }

        let time = CACurrentMediaTime()

        // Update motion-based tools
        flowMotion.update(time: time)
        pulseForge.update(time: time)
        chanceField.update(time: time)

        // Process tool chain if active
        if isToolChainActive {
            processToolChain()
        }
    }

    // MARK: - State Propagation

    private func updateToolsWithState(_ state: EchoelUniversalCore.SystemState) {
        let coherence = state.coherence
        let energy = state.energy
        let creativity = state.creativity

        // Update original tools
        harmonicIntelligence.setCoherence(coherence)
        rhythmicIntelligence.setEnergy(energy)
        quantumComposer.setCreativity(creativity)
        flowEngine.setFlowState(coherence: coherence, energy: energy)
        spatializer.updateFromCoherence(coherence)

        // Update new tools
        flowMotion.setBioState(coherence: coherence, energy: energy)
        pulseForge.setQuantumInfluence(creativity)
        soulPrint.setHumanization(basedOn: coherence)
        blendScape.setBioPosition(x: coherence, y: energy)
        bioNexus.updateFromBioState(coherence: coherence, energy: energy, creativity: creativity)
        chanceField.setProbabilityField(coherence: coherence)
        spectrumWeaver.setCoherence(coherence)
    }

    private func propagateBioState(_ bioState: BioBridge.BioState) {
        // Deep bio integration for all tools
        bioSonifier.updateFromBio(
            heartRate: bioState.heartRate,
            breathRate: bioState.breathRate,
            hrv: bioState.hrv
        )

        timeStretcher.updateFromBreath(phase: bioState.breathPhase)
        chronoWarp.syncToHeartbeat(bpm: bioState.heartRate)
        bioNexus.setRawBioData(bioState)
        flowMotion.syncToBreath(phase: bioState.breathPhase)
        pulseForge.lockToHeartbeat(bpm: bioState.heartRate)
    }

    private func adjustToolsForFlowState(_ flowState: FlowState) {
        switch flowState {
        case .ultraFlow:
            flowMultiplier = 2.0
            creativityBoost = 1.5
            toolState.ultraFlowEnabled = true
            toolState.performanceMode = .maximum

        case .flow:
            flowMultiplier = 1.5
            creativityBoost = 1.2
            toolState.ultraFlowEnabled = true
            toolState.performanceMode = .high

        case .neutral:
            flowMultiplier = 1.0
            creativityBoost = 1.0
            toolState.ultraFlowEnabled = false
            toolState.performanceMode = .balanced

        case .stressed:
            flowMultiplier = 0.8
            creativityBoost = 0.8
            toolState.ultraFlowEnabled = false
            toolState.performanceMode = .reduced

        case .recovery, .emergency:
            flowMultiplier = 0.5
            creativityBoost = 0.5
            toolState.ultraFlowEnabled = false
            toolState.performanceMode = .minimal
        }

        // Propagate to all tools
        applyFlowMultiplierToAllTools()
    }

    private func applyFlowMultiplierToAllTools() {
        flowMotion.setFlowMultiplier(flowMultiplier)
        pulseForge.setFlowMultiplier(flowMultiplier)
        chanceField.setFlowMultiplier(flowMultiplier)
        spectrumWeaver.setFlowMultiplier(flowMultiplier)
        chronoWarp.setFlowMultiplier(flowMultiplier)
    }

    // MARK: - Tool Chain Processing

    private func processToolChain() {
        guard isToolChainActive else { return }

        var chainData = ToolChainData()

        for tool in toolChain.chain {
            chainData = processToolInChain(tool, data: chainData)
        }

        toolChain.outputData = chainData
    }

    private func processToolInChain(_ tool: Tool, data: ToolChainData) -> ToolChainData {
        var output = data

        switch tool {
        case .flowMotion:
            output.modulationValues = flowMotion.getModulationOutput()
        case .pulseForge:
            output.rhythmPattern = pulseForge.getCurrentPattern()
        case .soulPrint:
            output.humanization = soulPrint.getHumanizationValues()
        case .blendScape:
            output.blendPosition = blendScape.getCurrentPosition()
        case .chronoWarp:
            output.warpFactor = chronoWarp.getCurrentWarpFactor()
        case .chanceField:
            output.probabilityMask = chanceField.getProbabilityMask()
        case .spectrumWeaver:
            output.spectralMask = spectrumWeaver.getSpectralMask()
        case .harmonicIntelligence:
            output.suggestedChord = harmonicIntelligence.suggestedChord
        case .rhythmicIntelligence:
            output.suggestedPattern = rhythmicIntelligence.suggestedPattern
        case .quantumComposer:
            output.quantumChoice = quantumComposer.lastCollapsedChoice
        default:
            break
        }

        return output
    }

    // MARK: - Tool Activation

    public func activate(_ tool: Tool) {
        activeTool = tool
        activeTools.insert(tool)
        toolState.lastActivated = Date()

        // Notify bridges
        hardwareBridge.onToolActivated(tool)
        visualBridge.onToolActivated(tool)
    }

    public func deactivate(_ tool: Tool) {
        activeTools.remove(tool)
        if activeTool == tool {
            activeTool = activeTools.first ?? .none
        }
    }

    public func deactivateAll() {
        activeTools.removeAll()
        activeTool = .none
    }

    public func toggle(_ tool: Tool) {
        if activeTools.contains(tool) {
            deactivate(tool)
        } else {
            activate(tool)
        }
    }

    // MARK: - Preset Management

    public func savePreset(name: String) -> ToolPreset {
        let preset = ToolPreset(
            name: name,
            activeTools: activeTools,
            toolChain: toolChain.chain,
            flowMotionState: flowMotion.getState(),
            pulseForgeState: pulseForge.getState(),
            chronoWarpState: chronoWarp.getState(),
            bioNexusState: bioNexus.getState()
        )
        presetManager.save(preset)
        return preset
    }

    public func loadPreset(_ preset: ToolPreset) {
        activeTools = preset.activeTools
        activeTool = activeTools.first ?? .none
        toolChain.chain = preset.toolChain

        flowMotion.setState(preset.flowMotionState)
        pulseForge.setState(preset.pulseForgeState)
        chronoWarp.setState(preset.chronoWarpState)
        bioNexus.setState(preset.bioNexusState)

        currentPreset = preset
    }
}

// MARK: - Tool Enum (24 Tools)

extension EchoelTools {

    public enum Tool: String, CaseIterable, Identifiable, Codable {
        // None
        case none = "None"

        // Original 8 (Enhanced)
        case harmonicIntelligence = "Harmonic Intelligence"
        case rhythmicIntelligence = "Rhythmic Intelligence"
        case spectralSculptor = "Spectral Sculptor"
        case bioSonifier = "Bio Sonifier"
        case quantumComposer = "Quantum Composer"
        case flowEngine = "Flow Engine"
        case spatializer = "Spatializer"
        case timeStretcher = "Time Stretcher"

        // Wave Alchemy 8 (Creative)
        case flowMotion = "Flow Motion"
        case pulseForge = "Pulse Forge"
        case soulPrint = "Soul Print"
        case blendScape = "Blend Scape"
        case bioNexus = "Bio Nexus"
        case chronoWarp = "Chrono Warp"
        case chanceField = "Chance Field"
        case spectrumWeaver = "Spectrum Weaver"

        // Ultra 8 (Advanced Synthesis & Production)
        case grainCloud = "Grain Cloud"
        case harmoniX = "HarmoniX"
        case drumForge = "Drum Forge"
        case synthWeaver = "Synth Weaver"
        case vocalShift = "Vocal Shift"
        case ambientScape = "Ambient Scape"
        case bassArchitect = "Bass Architect"
        case mixMatrix = "Mix Matrix"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .none: return "circle.slash"
            // Original
            case .harmonicIntelligence: return "music.quarternote.3"
            case .rhythmicIntelligence: return "metronome"
            case .spectralSculptor: return "waveform.path.badge.plus"
            case .bioSonifier: return "heart.text.square"
            case .quantumComposer: return "atom"
            case .flowEngine: return "drop.fill"
            case .spatializer: return "cube.transparent"
            case .timeStretcher: return "clock.arrow.2.circlepath"
            // Wave Alchemy
            case .flowMotion: return "figure.walk.motion"
            case .pulseForge: return "waveform.path.ecg"
            case .soulPrint: return "hand.draw"
            case .blendScape: return "square.on.square.intersection.dashed"
            case .bioNexus: return "link.circle.fill"
            case .chronoWarp: return "timelapse"
            case .chanceField: return "dice"
            case .spectrumWeaver: return "rainbow"
            // Ultra
            case .grainCloud: return "cloud.fill"
            case .harmoniX: return "tuningfork"
            case .drumForge: return "circle.grid.3x3.fill"
            case .synthWeaver: return "waveform"
            case .vocalShift: return "mic.fill"
            case .ambientScape: return "sparkles"
            case .bassArchitect: return "speaker.wave.3.fill"
            case .mixMatrix: return "slider.horizontal.3"
            }
        }

        public var description: String {
            switch self {
            case .none: return "No tool active"
            // Original
            case .harmonicIntelligence: return "AI-powered chord & scale suggestions based on coherence"
            case .rhythmicIntelligence: return "Rhythm patterns synced to your heartbeat"
            case .spectralSculptor: return "Shape frequencies with bio-feedback"
            case .bioSonifier: return "Transform biometrics into sound"
            case .quantumComposer: return "Quantum-inspired creative decisions"
            case .flowEngine: return "Ultra Liquid Light Flow activation"
            case .spatializer: return "3D audio positioning via coherence"
            case .timeStretcher: return "Breath-synced time manipulation"
            // Wave Alchemy
            case .flowMotion: return "Bio-synced parameter animation engine"
            case .pulseForge: return "Quantum polyrhythmic pattern generator"
            case .soulPrint: return "Analog warmth & human feel processor"
            case .blendScape: return "XY morphing between sound layers"
            case .bioNexus: return "8 biometric macro controls"
            case .chronoWarp: return "8 time-stretch algorithms (Akai/Ableton/PaulStretch)"
            case .chanceField: return "Probability-based creative sequencing"
            case .spectrumWeaver: return "Advanced FFT spectral processing"
            // Ultra
            case .grainCloud: return "Real-time granular synthesis engine"
            case .harmoniX: return "Intelligent harmonizer with voice allocation"
            case .drumForge: return "AI-powered drum pattern generator"
            case .synthWeaver: return "Wavetable synthesis with morphing"
            case .vocalShift: return "Real-time pitch correction & harmonies"
            case .ambientScape: return "Generative ambient soundscape creator"
            case .bassArchitect: return "Bass synthesis & sub enhancement"
            case .mixMatrix: return "Intelligent mixing & mastering suite"
            }
        }

        public var category: ToolCategory {
            switch self {
            case .none: return .system
            case .harmonicIntelligence, .rhythmicIntelligence, .quantumComposer, .chanceField, .drumForge:
                return .composition
            case .spectralSculptor, .spectrumWeaver, .bioSonifier:
                return .spectral
            case .flowEngine, .bioNexus:
                return .bioReactive
            case .spatializer, .blendScape, .ambientScape:
                return .spatial
            case .timeStretcher, .chronoWarp:
                return .temporal
            case .flowMotion, .pulseForge:
                return .sequencing
            case .soulPrint:
                return .character
            case .grainCloud, .synthWeaver, .bassArchitect:
                return .synthesis
            case .harmoniX, .vocalShift:
                return .vocal
            case .mixMatrix:
                return .mixing
            }
        }

        public var color: Color {
            switch category {
            case .system: return .gray
            case .composition: return .cyan
            case .spectral: return .purple
            case .bioReactive: return .pink
            case .spatial: return .blue
            case .temporal: return .orange
            case .sequencing: return .green
            case .character: return .yellow
            case .synthesis: return .mint
            case .vocal: return .indigo
            case .mixing: return .red
            }
        }
    }

    public enum ToolCategory: String, CaseIterable {
        case system = "System"
        case composition = "Composition"
        case spectral = "Spectral"
        case bioReactive = "Bio-Reactive"
        case spatial = "Spatial"
        case temporal = "Temporal"
        case sequencing = "Sequencing"
        case character = "Character"
        case synthesis = "Synthesis"
        case vocal = "Vocal"
        case mixing = "Mixing"
    }
}

// MARK: - Tool State

extension EchoelTools {

    public struct ToolState {
        public var ultraFlowEnabled: Bool = false
        public var creativityBoost: Float = 1.0
        public var lastActivated: Date = Date()
        public var sessionDuration: TimeInterval = 0
        public var performanceMode: PerformanceMode = .balanced
        public var toolChainLength: Int = 0

        public enum PerformanceMode: String {
            case maximum = "Maximum"
            case high = "High"
            case balanced = "Balanced"
            case reduced = "Reduced"
            case minimal = "Minimal"
        }
    }

    public struct ToolChainData {
        public var modulationValues: [Float] = []
        public var rhythmPattern: [Bool] = []
        public var humanization: HumanizationValues = HumanizationValues()
        public var blendPosition: SIMD2<Float> = .zero
        public var warpFactor: Float = 1.0
        public var probabilityMask: [Float] = []
        public var spectralMask: [Float] = []
        public var suggestedChord: HarmonicIntelligence.Chord?
        public var suggestedPattern: RhythmicIntelligence.RhythmPattern?
        public var quantumChoice: Int = 0
    }

    public struct HumanizationValues {
        public var timingSlop: Float = 0.0
        public var velocityVariance: Float = 0.0
        public var pitchDrift: Float = 0.0
        public var swingAmount: Float = 0.0
    }
}

// MARK: - Tool Preset

public struct ToolPreset: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public var activeTools: Set<EchoelTools.Tool>
    public var toolChain: [EchoelTools.Tool]
    public var flowMotionState: FlowMotion.State
    public var pulseForgeState: PulseForge.State
    public var chronoWarpState: ChronoWarp.State
    public var bioNexusState: BioNexus.State

    public init(
        name: String,
        activeTools: Set<EchoelTools.Tool> = [],
        toolChain: [EchoelTools.Tool] = [],
        flowMotionState: FlowMotion.State = FlowMotion.State(),
        pulseForgeState: PulseForge.State = PulseForge.State(),
        chronoWarpState: ChronoWarp.State = ChronoWarp.State(),
        bioNexusState: BioNexus.State = BioNexus.State()
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.activeTools = activeTools
        self.toolChain = toolChain
        self.flowMotionState = flowMotionState
        self.pulseForgeState = pulseForgeState
        self.chronoWarpState = chronoWarpState
        self.bioNexusState = bioNexusState
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - ORIGINAL 8 TOOLS (ENHANCED)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Harmonic Intelligence (Enhanced)

public class HarmonicIntelligence: ObservableObject {
    @Published public var suggestedChord: Chord?
    @Published public var suggestedScale: Scale?
    @Published public var harmonicTension: Float = 0.5
    @Published public var voicingStyle: VoicingStyle = .openVoicing
    @Published public var progressionSuggestions: [Chord] = []

    private var coherenceLevel: Float = 0.5
    private var quantumField: QuantumField { EchoelUniversalCore.shared.quantumField }

    public func setCoherence(_ coherence: Float) {
        coherenceLevel = coherence
        harmonicTension = 1.0 - coherence
        suggestHarmony()
    }

    public func suggestHarmony() {
        let choice = quantumField.sampleCreativeChoice(options: availableChords.count)

        let filteredChords = availableChords.filter { chord in
            if coherenceLevel > 0.7 {
                return chord.complexity <= 0.3
            } else if coherenceLevel > 0.4 {
                return chord.complexity <= 0.6
            }
            return true
        }

        if choice < filteredChords.count {
            suggestedChord = filteredChords[choice]
        }

        suggestScale()
        generateProgression()
    }

    public func suggestScale() {
        if coherenceLevel > 0.7 {
            suggestedScale = .major
        } else if coherenceLevel > 0.5 {
            suggestedScale = .mixolydian
        } else if coherenceLevel > 0.3 {
            suggestedScale = .dorian
        } else {
            suggestedScale = .phrygian
        }
    }

    private func generateProgression() {
        // AI-influenced chord progression based on coherence
        let length = coherenceLevel > 0.6 ? 4 : 8
        progressionSuggestions = (0..<length).compactMap { _ in
            let choice = quantumField.sampleCreativeChoice(options: availableChords.count)
            return choice < availableChords.count ? availableChords[choice] : nil
        }
    }

    public struct Chord: Identifiable, Codable {
        public let id = UUID()
        public var name: String
        public var notes: [Int]
        public var complexity: Float
        public var tensions: [Int]

        public init(name: String, notes: [Int], complexity: Float, tensions: [Int] = []) {
            self.name = name
            self.notes = notes
            self.complexity = complexity
            self.tensions = tensions
        }
    }

    public enum Scale: String, CaseIterable, Codable {
        case major = "Major"
        case minor = "Minor"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case lydian = "Lydian"
        case mixolydian = "Mixolydian"
        case locrian = "Locrian"
        case harmonicMinor = "Harmonic Minor"
        case melodicMinor = "Melodic Minor"
        case pentatonicMajor = "Pentatonic Major"
        case pentatonicMinor = "Pentatonic Minor"
        case blues = "Blues"
        case chromatic = "Chromatic"
    }

    public enum VoicingStyle: String, CaseIterable {
        case closeVoicing = "Close"
        case openVoicing = "Open"
        case dropTwo = "Drop 2"
        case dropThree = "Drop 3"
        case quartal = "Quartal"
        case cluster = "Cluster"
    }

    private var availableChords: [Chord] = [
        Chord(name: "C Major", notes: [60, 64, 67], complexity: 0.1),
        Chord(name: "A Minor", notes: [57, 60, 64], complexity: 0.1),
        Chord(name: "F Major", notes: [53, 57, 60], complexity: 0.2),
        Chord(name: "G Major", notes: [55, 59, 62], complexity: 0.2),
        Chord(name: "Dm7", notes: [50, 53, 57, 60], complexity: 0.4),
        Chord(name: "Cmaj7", notes: [48, 52, 55, 59], complexity: 0.5),
        Chord(name: "Em7", notes: [52, 55, 59, 62], complexity: 0.4),
        Chord(name: "Am9", notes: [45, 48, 52, 55, 59], complexity: 0.7),
        Chord(name: "Fmaj9#11", notes: [41, 45, 48, 52, 54, 57], complexity: 0.9),
        Chord(name: "Dm11", notes: [38, 41, 45, 48, 52, 55], complexity: 0.85),
        Chord(name: "G13", notes: [43, 47, 50, 53, 57, 59, 64], complexity: 0.95)
    ]
}

// MARK: - Rhythmic Intelligence (Enhanced)

public class RhythmicIntelligence: ObservableObject {
    @Published public var suggestedPattern: RhythmPattern?
    @Published public var syncedToHeartbeat: Bool = true
    @Published public var patternDensity: Float = 0.5
    @Published public var swingAmount: Float = 0.0
    @Published public var polyrhythmEnabled: Bool = false
    @Published public var currentBPM: Float = 120.0

    private var energyLevel: Float = 0.5
    private var quantumField: QuantumField { EchoelUniversalCore.shared.quantumField }

    public func setEnergy(_ energy: Float) {
        energyLevel = energy
        patternDensity = energy
        suggestPattern()
    }

    public func syncToBPM(_ bpm: Float) {
        currentBPM = bpm
    }

    public func suggestPattern() {
        let patterns = availablePatterns.filter { $0.density <= energyLevel + 0.2 }
        let choice = quantumField.sampleCreativeChoice(options: patterns.count)

        if choice < patterns.count {
            suggestedPattern = patterns[choice]
        }
    }

    public func generatePolyrhythm(ratio: (Int, Int)) -> [RhythmPattern] {
        guard polyrhythmEnabled else { return [] }

        let pattern1 = generatePatternWithSteps(ratio.0)
        let pattern2 = generatePatternWithSteps(ratio.1)

        return [pattern1, pattern2]
    }

    private func generatePatternWithSteps(_ divisions: Int) -> RhythmPattern {
        var steps = [Bool](repeating: false, count: 16)
        let spacing = 16 / divisions
        for i in 0..<divisions {
            let index = i * spacing
            if index < 16 {
                steps[index] = true
            }
        }
        return RhythmPattern(name: "Poly-\(divisions)", steps: steps, density: Float(divisions) / 16.0)
    }

    public struct RhythmPattern: Identifiable, Codable {
        public let id = UUID()
        public var name: String
        public var steps: [Bool]
        public var density: Float
        public var accents: [Float]?
        public var swing: Float

        public init(name: String, steps: [Bool], density: Float, accents: [Float]? = nil, swing: Float = 0.0) {
            self.name = name
            self.steps = steps
            self.density = density
            self.accents = accents
            self.swing = swing
        }
    }

    private var availablePatterns: [RhythmPattern] = [
        RhythmPattern(name: "Four on Floor", steps: [true,false,false,false,true,false,false,false,true,false,false,false,true,false,false,false], density: 0.25),
        RhythmPattern(name: "Breakbeat", steps: [true,false,false,false,false,false,true,false,false,false,true,false,false,false,false,false], density: 0.19),
        RhythmPattern(name: "House", steps: [true,false,true,false,true,false,true,false,true,false,true,false,true,false,true,false], density: 0.5),
        RhythmPattern(name: "Drum & Bass", steps: [true,false,false,true,false,false,true,false,false,true,false,false,true,false,true,false], density: 0.44),
        RhythmPattern(name: "Glitch", steps: [true,true,false,true,false,true,true,false,true,false,true,false,true,true,false,true], density: 0.69),
        RhythmPattern(name: "Half Time", steps: [true,false,false,false,false,false,false,false,true,false,false,false,false,false,false,false], density: 0.125),
        RhythmPattern(name: "Trap", steps: [true,false,false,false,false,false,true,true,false,false,true,false,false,true,false,false], density: 0.31),
        RhythmPattern(name: "Techno", steps: [true,false,true,false,true,false,true,false,true,false,true,false,true,false,true,true], density: 0.56)
    ]
}

// MARK: - Spectral Sculptor (Enhanced)

public class SpectralSculptor: ObservableObject {
    @Published public var frequencyMask: [Float] = Array(repeating: 1.0, count: 64)
    @Published public var coherenceInfluence: Float = 0.5
    @Published public var harmonicEnhancement: Float = 0.0
    @Published public var noiseReduction: Float = 0.0
    @Published public var warmth: Float = 0.5

    private var spectrum: [Float] = []

    public func sculptWithCoherence(_ coherence: Float) {
        coherenceInfluence = coherence

        // SIMD-optimized mask generation
        var mask = [Float](repeating: 1.0, count: 64)

        for i in 0..<64 {
            let isHarmonic = i % 4 == 0

            if coherence > 0.6 {
                // High coherence: boost harmonics, reduce noise
                mask[i] = isHarmonic ? (1.0 + harmonicEnhancement * 0.5) : (1.0 - noiseReduction * 0.3)
            } else if coherence < 0.3 {
                // Low coherence: add warmth (boost lows)
                let lowBoost = Float(64 - i) / 64.0 * warmth * 0.5
                mask[i] = 1.0 + lowBoost
            }
        }

        frequencyMask = mask
    }

    public func updateSpectrum(_ data: [Float]) {
        spectrum = data
    }

    public func applyMask(to spectrum: [Float]) -> [Float] {
        guard spectrum.count == frequencyMask.count else { return spectrum }

        // SIMD-optimized multiplication
        var result = [Float](repeating: 0, count: spectrum.count)
        vDSP_vmul(spectrum, 1, frequencyMask, 1, &result, 1, vDSP_Length(spectrum.count))
        return result
    }

    public func getSpectralBalance() -> SpectralBalance {
        guard !spectrum.isEmpty else { return SpectralBalance() }

        let third = spectrum.count / 3
        let low = spectrum[0..<third].reduce(0, +) / Float(third)
        let mid = spectrum[third..<(2*third)].reduce(0, +) / Float(third)
        let high = spectrum[(2*third)...].reduce(0, +) / Float(spectrum.count - 2*third)

        return SpectralBalance(low: low, mid: mid, high: high)
    }

    public struct SpectralBalance {
        public var low: Float = 0.33
        public var mid: Float = 0.33
        public var high: Float = 0.33
    }
}

// MARK: - Bio Sonifier (Enhanced)

public class BioSonifier: ObservableObject {
    @Published public var heartbeatFrequency: Float = 64
    @Published public var breathFrequency: Float = 51
    @Published public var hrvModulation: Float = 410
    @Published public var coherenceHarmonic: Float = 256

    @Published public var isHeartbeatAudible: Bool = true
    @Published public var isBreathAudible: Bool = true
    @Published public var isHRVAudible: Bool = false
    @Published public var isCoherenceAudible: Bool = true

    @Published public var outputMode: OutputMode = .musical

    public enum OutputMode: String, CaseIterable {
        case raw = "Raw"
        case musical = "Musical"
        case ambient = "Ambient"
        case rhythmic = "Rhythmic"
    }

    public func updateFromBio(heartRate: Float, breathRate: Float, hrv: Float) {
        // Octave transposition to audible range
        heartbeatFrequency = transposeToAudible(heartRate / 60.0, baseOctave: 6)
        breathFrequency = transposeToAudible(breathRate / 60.0, baseOctave: 5)
        hrvModulation = transposeToAudible(hrv / 1000.0, baseOctave: 8)

        // Coherence-based harmonic
        let coherence = min(hrv / 100.0, 1.0)
        coherenceHarmonic = 256 * (1.0 + coherence)
    }

    private func transposeToAudible(_ frequency: Float, baseOctave: Int) -> Float {
        var freq = frequency
        while freq < 20 {
            freq *= 2  // Octave up
        }
        return freq * pow(2, Float(baseOctave - 4))
    }

    public func generateHeartbeatTone() -> ToneParameters {
        ToneParameters(
            frequency: heartbeatFrequency,
            waveform: outputMode == .musical ? .sine : .triangle,
            amplitude: 0.3,
            attack: 0.01,
            decay: 0.1,
            sustain: 0.0,
            release: 0.2
        )
    }

    public func generateBreathTone() -> ToneParameters {
        ToneParameters(
            frequency: breathFrequency,
            waveform: .triangle,
            amplitude: 0.2,
            attack: 0.5,
            decay: 0.0,
            sustain: 1.0,
            release: 0.5
        )
    }

    public func generateCoherenceDrone() -> ToneParameters {
        ToneParameters(
            frequency: coherenceHarmonic,
            waveform: .sine,
            amplitude: 0.15,
            attack: 1.0,
            decay: 0.0,
            sustain: 1.0,
            release: 1.0
        )
    }

    public struct ToneParameters {
        public var frequency: Float
        public var waveform: Waveform
        public var amplitude: Float
        public var attack: Float
        public var decay: Float
        public var sustain: Float
        public var release: Float

        public enum Waveform: String, CaseIterable {
            case sine, triangle, square, sawtooth, noise
        }
    }
}

// MARK: - Quantum Composer (Enhanced)

public class QuantumComposer: ObservableObject {
    @Published public var creativityLevel: Float = 0.5
    @Published public var superpositionStrength: Float = 0.5
    @Published public var lastCollapsedChoice: Int = 0
    @Published public var entanglementDepth: Int = 3
    @Published public var quantumCoherence: Float = 1.0

    private var quantumField: QuantumField { EchoelUniversalCore.shared.quantumField }

    public func setCreativity(_ creativity: Float) {
        creativityLevel = creativity
        quantumCoherence = creativity
    }

    public func compose(options: [CompositionOption]) -> CompositionOption? {
        guard !options.isEmpty else { return nil }

        superpositionStrength = quantumField.superpositionStrength

        // Quantum sampling with entanglement
        var weights = [Float](repeating: 1.0, count: options.count)

        // Apply quantum interference pattern
        for i in 0..<options.count {
            let phase = Float(i) * Float.pi / Float(options.count)
            let interference = cos(phase * Float(entanglementDepth)) * creativityLevel
            weights[i] = 1.0 + interference
        }

        // Normalize and sample
        let total = weights.reduce(0, +)
        let normalized = weights.map { $0 / total }

        let choice = weightedSample(weights: normalized)
        lastCollapsedChoice = choice

        return options[choice]
    }

    public func collapseMultiple(options: [CompositionOption], count: Int) -> [CompositionOption] {
        var results: [CompositionOption] = []
        var remainingOptions = options

        for _ in 0..<min(count, options.count) {
            if let choice = compose(options: remainingOptions) {
                results.append(choice)
                remainingOptions.removeAll { $0.name == choice.name }
            }
        }

        return results
    }

    private func weightedSample(weights: [Float]) -> Int {
        let random = Float.random(in: 0..<1)
        var cumulative: Float = 0

        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if random < cumulative {
                return index
            }
        }

        return weights.count - 1
    }

    public struct CompositionOption: Identifiable {
        public let id = UUID()
        public var name: String
        public var type: OptionType
        public var value: Any
        public var weight: Float

        public init(name: String, type: OptionType, value: Any, weight: Float = 1.0) {
            self.name = name
            self.type = type
            self.value = value
            self.weight = weight
        }

        public enum OptionType: String, Codable {
            case note, chord, rhythm, effect, structure, scale, tempo
        }
    }
}

// MARK: - Flow Engine (Enhanced)

public class FlowEngine: ObservableObject {
    @Published public var flowIntensity: Float = 0.5
    @Published public var liquidLightLevel: Float = 0.5
    @Published public var ultraFlowActive: Bool = false
    @Published public var flowZone: FlowZone = .neutral
    @Published public var flowDuration: TimeInterval = 0
    @Published public var peakFlowAchieved: Bool = false

    private var flowStartTime: Date?

    public enum FlowZone: String, CaseIterable {
        case deep = "Deep Flow"
        case optimal = "Optimal"
        case neutral = "Neutral"
        case anxious = "Anxious"
        case bored = "Bored"
    }

    public func setFlowState(coherence: Float, energy: Float) {
        flowIntensity = (coherence * 0.6 + energy * 0.4)
        liquidLightLevel = coherence

        // Determine flow zone
        if coherence > 0.8 && energy > 0.6 && energy < 0.9 {
            flowZone = .deep
            if !ultraFlowActive {
                flowStartTime = Date()
            }
            ultraFlowActive = true
        } else if coherence > 0.6 && energy > 0.4 {
            flowZone = .optimal
            ultraFlowActive = coherence > 0.7 && energy > 0.6
        } else if energy > 0.8 {
            flowZone = .anxious
            ultraFlowActive = false
        } else if energy < 0.3 {
            flowZone = .bored
            ultraFlowActive = false
        } else {
            flowZone = .neutral
            ultraFlowActive = false
        }

        // Track flow duration
        if ultraFlowActive, let start = flowStartTime {
            flowDuration = Date().timeIntervalSince(start)
            if flowDuration > 300 { // 5 minutes
                peakFlowAchieved = true
            }
        } else {
            flowStartTime = nil
            flowDuration = 0
        }
    }

    public func getFlowMultiplier() -> Float {
        switch flowZone {
        case .deep: return 2.0
        case .optimal: return 1.5
        case .neutral: return 1.0
        case .anxious: return 0.8
        case .bored: return 0.7
        }
    }

    public func getFlowColor() -> Color {
        switch flowZone {
        case .deep: return .cyan
        case .optimal: return .green
        case .neutral: return .gray
        case .anxious: return .orange
        case .bored: return .blue
        }
    }
}

// MARK: - Spatializer (Enhanced)

public class Spatializer: ObservableObject {
    @Published public var position: SIMD3<Float> = SIMD3(0, 0, -1)
    @Published public var rotation: Float = 0
    @Published public var coherenceBasedWidth: Float = 1.0
    @Published public var spatialMode: SpatialMode = .stereo
    @Published public var roomSize: Float = 0.5
    @Published public var sourcePositions: [SIMD3<Float>] = []

    public enum SpatialMode: String, CaseIterable {
        case stereo = "Stereo"
        case binaural = "Binaural"
        case surround = "Surround 5.1"
        case ambisonic = "Ambisonics"
        case immersive = "Immersive 3D"
        case afa = "AFA Field"
    }

    public func updateFromCoherence(_ coherence: Float) {
        coherenceBasedWidth = 1.0 + (1.0 - coherence)
        rotation += 0.01 * (1.0 - coherence)

        // Dynamic room size based on coherence
        roomSize = 0.3 + coherence * 0.7
    }

    public func positionForFrequency(_ frequency: Float) -> SIMD3<Float> {
        let normalizedFreq = log2(frequency / 20) / 10
        let angle = normalizedFreq * Float.pi

        let x = sin(angle) * coherenceBasedWidth
        let y = (normalizedFreq - 0.5) * 0.5 // Slight elevation for high frequencies
        let z = -cos(angle)

        return SIMD3(x, y, z)
    }

    public func createSpatialField(sources: Int) {
        sourcePositions = (0..<sources).map { i in
            let angle = Float(i) / Float(sources) * Float.pi * 2
            return SIMD3(
                cos(angle) * coherenceBasedWidth,
                sin(Float(i) * 0.5) * 0.3,
                sin(angle) * coherenceBasedWidth - 1
            )
        }
    }

    public func getAFAFieldPositions(count: Int) -> [SIMD3<Float>] {
        // Algorithmic Field Array - Fibonacci spiral distribution
        let phi = (1 + sqrt(5)) / 2  // Golden ratio

        return (0..<count).map { i in
            let theta = Float(i) * Float.pi * 2 / Float(phi)
            let r = sqrt(Float(i)) / sqrt(Float(count)) * coherenceBasedWidth
            return SIMD3(
                r * cos(theta),
                Float(i) / Float(count) - 0.5,
                r * sin(theta) - 1
            )
        }
    }
}

// MARK: - Time Stretcher (Enhanced)

public class TimeStretcher: ObservableObject {
    @Published public var stretchFactor: Float = 1.0
    @Published public var breathSynced: Bool = true
    @Published public var currentPhase: Float = 0
    @Published public var grainSize: Float = 0.05
    @Published public var pitchPreserve: Bool = true

    public func updateFromBreath(phase: Float) {
        currentPhase = phase

        if breathSynced {
            if phase < 0.5 {
                // Inhale - accelerate
                stretchFactor = 1.0 + (0.5 - phase) * 0.4
            } else {
                // Exhale - decelerate
                stretchFactor = 1.0 - (phase - 0.5) * 0.4
            }
        }
    }

    public func setManualStretch(_ factor: Float) {
        breathSynced = false
        stretchFactor = max(0.1, min(4.0, factor))
    }

    public func getGrainSizeForFactor() -> Float {
        // Larger grains for more stretch
        return grainSize * (1.0 + abs(stretchFactor - 1.0))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - NEW 8 TOOLS (WAVE ALCHEMY + WARP INSPIRED)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - FlowMotion (Bio-Synced Motion Sequencer)

public class FlowMotion: ObservableObject {
    @Published public var lanes: [MotionLane] = []
    @Published public var isPlaying: Bool = false
    @Published public var currentStep: Int = 0
    @Published public var bioSyncEnabled: Bool = true
    @Published public var breathLockEnabled: Bool = true

    private var flowMultiplier: Float = 1.0
    private var coherence: Float = 0.5
    private var energy: Float = 0.5
    private var breathPhase: Float = 0.0
    private var lastUpdateTime: Double = 0

    public init() {
        // Initialize with 4 default lanes
        lanes = [
            MotionLane(name: "Filter", targetParameter: .filterCutoff, shape: .sine),
            MotionLane(name: "Resonance", targetParameter: .filterResonance, shape: .triangle),
            MotionLane(name: "Volume", targetParameter: .volume, shape: .sine),
            MotionLane(name: "Pan", targetParameter: .pan, shape: .sine)
        ]
    }

    public func update(time: Double) {
        guard isPlaying else { return }

        let delta = time - lastUpdateTime
        lastUpdateTime = time

        for i in 0..<lanes.count {
            lanes[i].update(delta: delta, flowMultiplier: flowMultiplier, breathPhase: breathPhase)
        }
    }

    public func setBioState(coherence: Float, energy: Float) {
        self.coherence = coherence
        self.energy = energy

        // Modulate lane rates based on bio state
        if bioSyncEnabled {
            for i in 0..<lanes.count {
                lanes[i].rate *= (0.5 + energy * 0.5)
                lanes[i].depth *= coherence
            }
        }
    }

    public func syncToBreath(phase: Float) {
        breathPhase = phase

        if breathLockEnabled {
            // Sync lane phases to breath
            for i in 0..<lanes.count where lanes[i].breathSync {
                lanes[i].phase = phase
            }
        }
    }

    public func setFlowMultiplier(_ multiplier: Float) {
        flowMultiplier = multiplier
    }

    public func getModulationOutput() -> [Float] {
        lanes.map { $0.currentValue }
    }

    public func addLane(_ lane: MotionLane) {
        lanes.append(lane)
    }

    public func removeLane(at index: Int) {
        guard index < lanes.count else { return }
        lanes.remove(at: index)
    }

    public func getState() -> State {
        State(
            lanes: lanes.map { $0.getState() },
            bioSyncEnabled: bioSyncEnabled,
            breathLockEnabled: breathLockEnabled
        )
    }

    public func setState(_ state: State) {
        lanes = state.lanes.map { MotionLane(from: $0) }
        bioSyncEnabled = state.bioSyncEnabled
        breathLockEnabled = state.breathLockEnabled
    }

    public struct State: Codable {
        public var lanes: [MotionLane.State] = []
        public var bioSyncEnabled: Bool = true
        public var breathLockEnabled: Bool = true

        public init(lanes: [MotionLane.State] = [], bioSyncEnabled: Bool = true, breathLockEnabled: Bool = true) {
            self.lanes = lanes
            self.bioSyncEnabled = bioSyncEnabled
            self.breathLockEnabled = breathLockEnabled
        }
    }

    public class MotionLane: Identifiable, ObservableObject {
        public let id = UUID()
        public var name: String
        public var targetParameter: TargetParameter
        public var shape: WaveShape
        public var rate: Float = 1.0
        public var depth: Float = 1.0
        public var phase: Float = 0.0
        public var offset: Float = 0.0
        public var breathSync: Bool = false
        @Published public var currentValue: Float = 0.0

        public init(name: String, targetParameter: TargetParameter, shape: WaveShape) {
            self.name = name
            self.targetParameter = targetParameter
            self.shape = shape
        }

        public init(from state: State) {
            self.name = state.name
            self.targetParameter = state.targetParameter
            self.shape = state.shape
            self.rate = state.rate
            self.depth = state.depth
            self.offset = state.offset
            self.breathSync = state.breathSync
        }

        public func update(delta: Double, flowMultiplier: Float, breathPhase: Float) {
            phase += Float(delta) * rate * flowMultiplier
            if phase > 1.0 { phase -= 1.0 }

            let effectivePhase = breathSync ? breathPhase : phase
            currentValue = calculateValue(at: effectivePhase) * depth + offset
        }

        private func calculateValue(at phase: Float) -> Float {
            let p = phase * Float.pi * 2

            switch shape {
            case .sine:
                return sin(p)
            case .triangle:
                return 1 - 4 * abs(phase - 0.5)
            case .square:
                return phase < 0.5 ? 1.0 : -1.0
            case .sawtooth:
                return 2 * phase - 1
            case .random:
                return Float.random(in: -1...1)
            case .smooth:
                // Smoothstep
                let t = phase
                return t * t * (3 - 2 * t) * 2 - 1
            }
        }

        public func getState() -> State {
            State(
                name: name,
                targetParameter: targetParameter,
                shape: shape,
                rate: rate,
                depth: depth,
                offset: offset,
                breathSync: breathSync
            )
        }

        public struct State: Codable {
            public var name: String
            public var targetParameter: TargetParameter
            public var shape: WaveShape
            public var rate: Float
            public var depth: Float
            public var offset: Float
            public var breathSync: Bool
        }

        public enum TargetParameter: String, CaseIterable, Codable {
            case filterCutoff = "Filter Cutoff"
            case filterResonance = "Filter Resonance"
            case volume = "Volume"
            case pan = "Pan"
            case reverbMix = "Reverb Mix"
            case delayMix = "Delay Mix"
            case pitch = "Pitch"
            case distortion = "Distortion"
            case spatialWidth = "Spatial Width"
            case grainSize = "Grain Size"
        }

        public enum WaveShape: String, CaseIterable, Codable {
            case sine = "Sine"
            case triangle = "Triangle"
            case square = "Square"
            case sawtooth = "Sawtooth"
            case random = "Random"
            case smooth = "Smooth"
        }
    }
}

// MARK: - PulseForge (Quantum Polyrhythmic Engine)

public class PulseForge: ObservableObject {
    @Published public var layers: [RhythmLayer] = []
    @Published public var masterTempo: Float = 120.0
    @Published public var quantumInfluence: Float = 0.5
    @Published public var isPlaying: Bool = false
    @Published public var currentBeat: Int = 0
    @Published public var heartbeatLock: Bool = true

    private var flowMultiplier: Float = 1.0
    private var lastUpdateTime: Double = 0
    private var beatAccumulator: Double = 0
    private var quantumField: QuantumField { EchoelUniversalCore.shared.quantumField }

    // Prime numbers for polyrhythmic ratios
    private let primes: [Int] = [2, 3, 5, 7, 11, 13]

    public init() {
        // Initialize with default polyrhythmic layers
        layers = [
            RhythmLayer(name: "Kick", steps: 16, hits: generateEuclidean(16, 4)),
            RhythmLayer(name: "Snare", steps: 16, hits: generateEuclidean(16, 2)),
            RhythmLayer(name: "HiHat", steps: 16, hits: generateEuclidean(16, 8)),
            RhythmLayer(name: "Perc", steps: 12, hits: generateEuclidean(12, 5))  // 3:4 polyrhythm
        ]
    }

    public func update(time: Double) {
        guard isPlaying else { return }

        let delta = time - lastUpdateTime
        lastUpdateTime = time

        let beatsPerSecond = Double(masterTempo) / 60.0
        beatAccumulator += delta * beatsPerSecond * Double(flowMultiplier)

        if beatAccumulator >= 1.0 {
            beatAccumulator -= 1.0
            advanceBeat()
        }
    }

    private func advanceBeat() {
        currentBeat += 1

        for i in 0..<layers.count {
            layers[i].currentStep = currentBeat % layers[i].steps

            // Apply quantum probability to trigger
            if layers[i].hits[layers[i].currentStep] {
                let probability = 1.0 - (quantumInfluence * Float.random(in: 0...0.3))
                layers[i].shouldTrigger = Float.random(in: 0...1) < probability
            } else {
                // Quantum can occasionally trigger off-beats
                layers[i].shouldTrigger = quantumInfluence > 0.7 && Float.random(in: 0...1) < quantumInfluence * 0.1
            }
        }
    }

    public func setQuantumInfluence(_ influence: Float) {
        quantumInfluence = influence
    }

    public func lockToHeartbeat(bpm: Float) {
        if heartbeatLock {
            masterTempo = bpm
        }
    }

    public func setFlowMultiplier(_ multiplier: Float) {
        flowMultiplier = multiplier
    }

    public func getCurrentPattern() -> [Bool] {
        layers.map { $0.shouldTrigger }
    }

    public func generatePolyrhythm(ratioA: Int, ratioB: Int) {
        let lcm = (ratioA * ratioB) / gcd(ratioA, ratioB)

        layers = [
            RhythmLayer(name: "Layer A", steps: lcm, hits: generateEuclidean(lcm, ratioA)),
            RhythmLayer(name: "Layer B", steps: lcm, hits: generateEuclidean(lcm, ratioB))
        ]
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }

    private func generateEuclidean(_ steps: Int, _ hits: Int) -> [Bool] {
        guard hits <= steps else { return [Bool](repeating: true, count: steps) }

        var pattern = [Bool](repeating: false, count: steps)
        var bucket: Float = 0

        for i in 0..<steps {
            bucket += Float(hits)
            if bucket >= Float(steps) {
                bucket -= Float(steps)
                pattern[i] = true
            }
        }

        return pattern
    }

    public func getState() -> State {
        State(
            layers: layers.map { $0.getState() },
            masterTempo: masterTempo,
            quantumInfluence: quantumInfluence,
            heartbeatLock: heartbeatLock
        )
    }

    public func setState(_ state: State) {
        layers = state.layers.map { RhythmLayer(from: $0) }
        masterTempo = state.masterTempo
        quantumInfluence = state.quantumInfluence
        heartbeatLock = state.heartbeatLock
    }

    public struct State: Codable {
        public var layers: [RhythmLayer.State] = []
        public var masterTempo: Float = 120.0
        public var quantumInfluence: Float = 0.5
        public var heartbeatLock: Bool = true

        public init(layers: [RhythmLayer.State] = [], masterTempo: Float = 120, quantumInfluence: Float = 0.5, heartbeatLock: Bool = true) {
            self.layers = layers
            self.masterTempo = masterTempo
            self.quantumInfluence = quantumInfluence
            self.heartbeatLock = heartbeatLock
        }
    }

    public class RhythmLayer: Identifiable, ObservableObject {
        public let id = UUID()
        public var name: String
        public var steps: Int
        public var hits: [Bool]
        public var velocity: Float = 1.0
        public var probability: Float = 1.0
        public var swing: Float = 0.0
        public var currentStep: Int = 0
        public var shouldTrigger: Bool = false

        public init(name: String, steps: Int, hits: [Bool]) {
            self.name = name
            self.steps = steps
            self.hits = hits
        }

        public init(from state: State) {
            self.name = state.name
            self.steps = state.steps
            self.hits = state.hits
            self.velocity = state.velocity
            self.probability = state.probability
            self.swing = state.swing
        }

        public func getState() -> State {
            State(
                name: name,
                steps: steps,
                hits: hits,
                velocity: velocity,
                probability: probability,
                swing: swing
            )
        }

        public struct State: Codable {
            public var name: String
            public var steps: Int
            public var hits: [Bool]
            public var velocity: Float
            public var probability: Float
            public var swing: Float
        }
    }
}

// MARK: - SoulPrint (Analog Humanization)

public class SoulPrint: ObservableObject {
    @Published public var timingSlop: Float = 0.0
    @Published public var velocityVariance: Float = 0.0
    @Published public var pitchDrift: Float = 0.0
    @Published public var swingAmount: Float = 0.0
    @Published public var warmth: Float = 0.5
    @Published public var vintageTone: Float = 0.0
    @Published public var tapeWobble: Float = 0.0
    @Published public var humanizationPreset: HumanizationPreset = .subtle

    public enum HumanizationPreset: String, CaseIterable {
        case none = "None"
        case subtle = "Subtle"
        case natural = "Natural"
        case loose = "Loose"
        case drunk = "Drunk"
        case vintage = "Vintage Tape"
        case live = "Live Feel"
    }

    public func setHumanization(basedOn coherence: Float) {
        // High coherence = more precise, low coherence = more human variation
        let humanness = 1.0 - coherence

        timingSlop = humanness * 0.02  // Up to 20ms
        velocityVariance = humanness * 0.15  // Up to 15%
        pitchDrift = humanness * 0.005  // Up to 0.5%
    }

    public func applyPreset(_ preset: HumanizationPreset) {
        humanizationPreset = preset

        switch preset {
        case .none:
            timingSlop = 0
            velocityVariance = 0
            pitchDrift = 0
            swingAmount = 0
            tapeWobble = 0

        case .subtle:
            timingSlop = 0.005
            velocityVariance = 0.05
            pitchDrift = 0.001
            swingAmount = 0.1
            tapeWobble = 0

        case .natural:
            timingSlop = 0.01
            velocityVariance = 0.1
            pitchDrift = 0.002
            swingAmount = 0.15
            tapeWobble = 0

        case .loose:
            timingSlop = 0.02
            velocityVariance = 0.15
            pitchDrift = 0.003
            swingAmount = 0.25
            tapeWobble = 0

        case .drunk:
            timingSlop = 0.04
            velocityVariance = 0.25
            pitchDrift = 0.01
            swingAmount = 0.4
            tapeWobble = 0.02

        case .vintage:
            timingSlop = 0.01
            velocityVariance = 0.1
            pitchDrift = 0.005
            swingAmount = 0.15
            tapeWobble = 0.03
            warmth = 0.7
            vintageTone = 0.5

        case .live:
            timingSlop = 0.015
            velocityVariance = 0.2
            pitchDrift = 0.002
            swingAmount = 0.2
            tapeWobble = 0
        }
    }

    public func getHumanizationValues() -> EchoelTools.HumanizationValues {
        EchoelTools.HumanizationValues(
            timingSlop: timingSlop,
            velocityVariance: velocityVariance,
            pitchDrift: pitchDrift,
            swingAmount: swingAmount
        )
    }

    public func humanize(timing: Float) -> Float {
        timing + Float.random(in: -timingSlop...timingSlop)
    }

    public func humanize(velocity: Float) -> Float {
        let variance = velocity * velocityVariance
        return max(0, min(1, velocity + Float.random(in: -variance...variance)))
    }

    public func humanize(pitch: Float) -> Float {
        pitch * (1.0 + Float.random(in: -pitchDrift...pitchDrift))
    }
}

// MARK: - BlendScape (XY Layer Morphing)

public class BlendScape: ObservableObject {
    @Published public var position: SIMD2<Float> = SIMD2(0.5, 0.5)
    @Published public var layers: [SoundLayer] = []
    @Published public var bioControlled: Bool = true
    @Published public var morphSpeed: Float = 0.1
    @Published public var blendMode: BlendMode = .linear

    private var targetPosition: SIMD2<Float> = SIMD2(0.5, 0.5)

    public enum BlendMode: String, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case sigmoid = "Sigmoid"
        case stepped = "Stepped"
    }

    public init() {
        // Initialize with 4 corner layers
        layers = [
            SoundLayer(name: "A", position: SIMD2(0, 0), color: .cyan),
            SoundLayer(name: "B", position: SIMD2(1, 0), color: .pink),
            SoundLayer(name: "C", position: SIMD2(0, 1), color: .purple),
            SoundLayer(name: "D", position: SIMD2(1, 1), color: .orange)
        ]
    }

    public func setBioPosition(x: Float, y: Float) {
        if bioControlled {
            targetPosition = SIMD2(x, y)
        }
    }

    public func setManualPosition(_ pos: SIMD2<Float>) {
        bioControlled = false
        targetPosition = pos
    }

    public func update() {
        // Smooth interpolation to target
        let diff = targetPosition - position
        position += diff * morphSpeed
    }

    public func getCurrentPosition() -> SIMD2<Float> {
        position
    }

    public func getLayerWeights() -> [Float] {
        layers.map { layer in
            let distance = simd_distance(position, layer.position)
            let maxDistance = sqrt(2.0) // Diagonal of unit square

            switch blendMode {
            case .linear:
                return max(0, 1 - distance / maxDistance)
            case .exponential:
                return exp(-distance * 3)
            case .sigmoid:
                return 1 / (1 + exp((distance - 0.5) * 10))
            case .stepped:
                return distance < 0.5 ? 1.0 : 0.0
            }
        }
    }

    public func normalizedWeights() -> [Float] {
        let weights = getLayerWeights()
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return weights }
        return weights.map { $0 / sum }
    }

    public struct SoundLayer: Identifiable {
        public let id = UUID()
        public var name: String
        public var position: SIMD2<Float>
        public var color: Color
        public var volume: Float = 1.0
        public var parameters: [String: Float] = [:]
    }
}

// MARK: - BioNexus (8 Biometric Macro Controls)

public class BioNexus: ObservableObject {
    @Published public var macros: [BioMacro] = []
    @Published public var autoMapEnabled: Bool = true
    @Published public var smoothingAmount: Float = 0.3

    private var rawBioData: BioBridge.BioState?

    public init() {
        // Initialize 8 bio macros
        macros = [
            BioMacro(index: 0, name: "Heart Pulse", source: .heartRate, color: .red),
            BioMacro(index: 1, name: "HRV Flow", source: .hrv, color: .pink),
            BioMacro(index: 2, name: "Coherence", source: .coherence, color: .cyan),
            BioMacro(index: 3, name: "Breath", source: .breathRate, color: .blue),
            BioMacro(index: 4, name: "Energy", source: .energy, color: .orange),
            BioMacro(index: 5, name: "Creativity", source: .creativity, color: .purple),
            BioMacro(index: 6, name: "Focus", source: .focus, color: .green),
            BioMacro(index: 7, name: "Calm", source: .calm, color: .teal)
        ]
    }

    public func updateFromBioState(coherence: Float, energy: Float, creativity: Float) {
        if autoMapEnabled {
            macros[2].setValue(coherence)
            macros[4].setValue(energy)
            macros[5].setValue(creativity)

            // Derived values
            macros[6].setValue((coherence + energy) / 2)  // Focus
            macros[7].setValue(coherence * (1 - energy * 0.3))  // Calm
        }
    }

    public func setRawBioData(_ data: BioBridge.BioState) {
        rawBioData = data

        if autoMapEnabled {
            macros[0].setValue(data.heartRate / 200)  // Normalize to 0-1
            macros[1].setValue(data.hrv / 100)
            macros[3].setValue(data.breathRate / 30)
        }
    }

    public func getMacroValue(_ index: Int) -> Float {
        guard index < macros.count else { return 0 }
        return macros[index].smoothedValue
    }

    public func getAllMacroValues() -> [Float] {
        macros.map { $0.smoothedValue }
    }

    public func mapMacroToParameter(_ macroIndex: Int, parameter: String, min: Float, max: Float) {
        guard macroIndex < macros.count else { return }
        macros[macroIndex].mappings.append(
            BioMacro.Mapping(parameter: parameter, min: min, max: max)
        )
    }

    public func getState() -> State {
        State(
            macros: macros.map { $0.getState() },
            autoMapEnabled: autoMapEnabled,
            smoothingAmount: smoothingAmount
        )
    }

    public func setState(_ state: State) {
        for (index, macroState) in state.macros.enumerated() where index < macros.count {
            macros[index].setState(macroState)
        }
        autoMapEnabled = state.autoMapEnabled
        smoothingAmount = state.smoothingAmount
    }

    public struct State: Codable {
        public var macros: [BioMacro.State] = []
        public var autoMapEnabled: Bool = true
        public var smoothingAmount: Float = 0.3

        public init(macros: [BioMacro.State] = [], autoMapEnabled: Bool = true, smoothingAmount: Float = 0.3) {
            self.macros = macros
            self.autoMapEnabled = autoMapEnabled
            self.smoothingAmount = smoothingAmount
        }
    }

    public class BioMacro: Identifiable, ObservableObject {
        public let id = UUID()
        public let index: Int
        public var name: String
        public var source: BioSource
        public var color: Color
        @Published public var rawValue: Float = 0.0
        @Published public var smoothedValue: Float = 0.0
        public var mappings: [Mapping] = []
        public var curve: ResponseCurve = .linear
        public var min: Float = 0.0
        public var max: Float = 1.0

        private var smoothingFactor: Float = 0.3

        public init(index: Int, name: String, source: BioSource, color: Color) {
            self.index = index
            self.name = name
            self.source = source
            self.color = color
        }

        public func setValue(_ value: Float) {
            rawValue = value

            // Apply smoothing
            smoothedValue = smoothedValue * (1 - smoothingFactor) + applyCurve(value) * smoothingFactor
        }

        private func applyCurve(_ value: Float) -> Float {
            let normalized = (value - min) / (max - min)

            switch curve {
            case .linear:
                return normalized
            case .exponential:
                return pow(normalized, 2)
            case .logarithmic:
                return log10(1 + normalized * 9) // 0 to 1 range
            case .sCurve:
                return normalized * normalized * (3 - 2 * normalized)
            }
        }

        public func getState() -> State {
            State(name: name, source: source, curve: curve, min: min, max: max)
        }

        public func setState(_ state: State) {
            name = state.name
            source = state.source
            curve = state.curve
            min = state.min
            max = state.max
        }

        public struct State: Codable {
            public var name: String
            public var source: BioSource
            public var curve: ResponseCurve
            public var min: Float
            public var max: Float
        }

        public struct Mapping: Codable {
            public var parameter: String
            public var min: Float
            public var max: Float
        }

        public enum BioSource: String, CaseIterable, Codable {
            case heartRate = "Heart Rate"
            case hrv = "HRV"
            case coherence = "Coherence"
            case breathRate = "Breath Rate"
            case energy = "Energy"
            case creativity = "Creativity"
            case focus = "Focus"
            case calm = "Calm"
        }

        public enum ResponseCurve: String, CaseIterable, Codable {
            case linear = "Linear"
            case exponential = "Exponential"
            case logarithmic = "Logarithmic"
            case sCurve = "S-Curve"
        }
    }
}

// MARK: - ChronoWarp (8 Time-Stretch Algorithms)

public class ChronoWarp: ObservableObject {
    @Published public var algorithm: WarpAlgorithm = .complex
    @Published public var stretchFactor: Float = 1.0
    @Published public var pitchShift: Float = 0.0
    @Published public var formantPreserve: Bool = true
    @Published public var grainSize: Float = 0.05
    @Published public var grainOverlap: Float = 0.5
    @Published public var transientSensitivity: Float = 0.5
    @Published public var heartbeatSync: Bool = false

    private var flowMultiplier: Float = 1.0
    private var targetBPM: Float = 120.0

    public enum WarpAlgorithm: String, CaseIterable, Codable {
        // Ableton-style
        case beats = "Beats"
        case tones = "Tones"
        case texture = "Texture"
        case complex = "Complex"
        case complexPro = "Complex Pro"
        case repitch = "Re-Pitch"
        // Pro algorithms
        case superWarp = "Super Warp"       // Akai MPC FFT
        case paulStretch = "Paul Stretch"   // Extreme spectral

        public var description: String {
            switch self {
            case .beats: return "Transient-preserving, best for drums"
            case .tones: return "Pitch-preserving, best for melodic content"
            case .texture: return "Granular with flux, best for pads/ambience"
            case .complex: return "Full-spectrum, best for mixed content"
            case .complexPro: return "Formant-safe, best for vocals"
            case .repitch: return "Vinyl-style, pitch follows speed"
            case .superWarp: return "Akai FFT-based, high quality"
            case .paulStretch: return "Extreme stretch, spectral freezing"
            }
        }

        public var maxStretch: Float {
            switch self {
            case .beats: return 4.0
            case .tones: return 4.0
            case .texture: return 8.0
            case .complex: return 4.0
            case .complexPro: return 4.0
            case .repitch: return 4.0
            case .superWarp: return 8.0
            case .paulStretch: return 100.0  // Extreme!
            }
        }
    }

    public func setAlgorithm(_ algo: WarpAlgorithm) {
        algorithm = algo

        // Set default parameters for algorithm
        switch algo {
        case .beats:
            grainSize = 0.01
            transientSensitivity = 0.8
            formantPreserve = false

        case .tones:
            grainSize = 0.04
            transientSensitivity = 0.3
            formantPreserve = true

        case .texture:
            grainSize = 0.08
            grainOverlap = 0.7
            formantPreserve = false

        case .complex, .complexPro:
            grainSize = 0.05
            grainOverlap = 0.5
            formantPreserve = algo == .complexPro

        case .repitch:
            formantPreserve = false

        case .superWarp:
            grainSize = 0.04
            grainOverlap = 0.75
            formantPreserve = true

        case .paulStretch:
            grainSize = 0.2
            grainOverlap = 0.9
            formantPreserve = true
        }
    }

    public func syncToHeartbeat(bpm: Float) {
        if heartbeatSync {
            targetBPM = bpm
            // Calculate stretch factor to match heartbeat
            stretchFactor = 120.0 / bpm  // Assuming source is 120 BPM
        }
    }

    public func setFlowMultiplier(_ multiplier: Float) {
        flowMultiplier = multiplier
    }

    public func getCurrentWarpFactor() -> Float {
        stretchFactor * flowMultiplier
    }

    public func getProcessingParameters() -> WarpParameters {
        WarpParameters(
            algorithm: algorithm,
            stretchFactor: stretchFactor,
            pitchShift: pitchShift,
            formantPreserve: formantPreserve,
            grainSize: grainSize,
            grainOverlap: grainOverlap,
            transientSensitivity: transientSensitivity
        )
    }

    public func getState() -> State {
        State(
            algorithm: algorithm,
            stretchFactor: stretchFactor,
            pitchShift: pitchShift,
            formantPreserve: formantPreserve,
            heartbeatSync: heartbeatSync
        )
    }

    public func setState(_ state: State) {
        setAlgorithm(state.algorithm)
        stretchFactor = state.stretchFactor
        pitchShift = state.pitchShift
        formantPreserve = state.formantPreserve
        heartbeatSync = state.heartbeatSync
    }

    public struct State: Codable {
        public var algorithm: WarpAlgorithm = .complex
        public var stretchFactor: Float = 1.0
        public var pitchShift: Float = 0.0
        public var formantPreserve: Bool = true
        public var heartbeatSync: Bool = false

        public init(algorithm: WarpAlgorithm = .complex, stretchFactor: Float = 1.0, pitchShift: Float = 0.0, formantPreserve: Bool = true, heartbeatSync: Bool = false) {
            self.algorithm = algorithm
            self.stretchFactor = stretchFactor
            self.pitchShift = pitchShift
            self.formantPreserve = formantPreserve
            self.heartbeatSync = heartbeatSync
        }
    }

    public struct WarpParameters {
        public var algorithm: WarpAlgorithm
        public var stretchFactor: Float
        public var pitchShift: Float
        public var formantPreserve: Bool
        public var grainSize: Float
        public var grainOverlap: Float
        public var transientSensitivity: Float
    }
}

// MARK: - ChanceField (Probabilistic Sequencing)

public class ChanceField: ObservableObject {
    @Published public var steps: [ProbabilityStep] = []
    @Published public var globalProbability: Float = 1.0
    @Published public var coherenceInfluence: Float = 0.5
    @Published public var mutationRate: Float = 0.1
    @Published public var isPlaying: Bool = false
    @Published public var currentStep: Int = 0

    private var flowMultiplier: Float = 1.0
    private var quantumField: QuantumField { EchoelUniversalCore.shared.quantumField }

    public init() {
        // Initialize 16 probability steps
        steps = (0..<16).map { i in
            ProbabilityStep(
                index: i,
                probability: i % 4 == 0 ? 1.0 : 0.5,
                velocity: 0.8,
                pitch: 0
            )
        }
    }

    public func update(time: Double) {
        guard isPlaying else { return }

        // Apply mutation based on quantum field
        if Float.random(in: 0...1) < mutationRate * flowMultiplier {
            mutateRandomStep()
        }
    }

    public func setProbabilityField(coherence: Float) {
        // High coherence = more deterministic
        // Low coherence = more random
        let randomness = 1.0 - coherence

        for i in 0..<steps.count {
            if coherenceInfluence > 0 {
                let variation = (Float.random(in: -1...1) * randomness * coherenceInfluence)
                steps[i].effectiveProbability = max(0, min(1, steps[i].probability + variation))
            } else {
                steps[i].effectiveProbability = steps[i].probability
            }
        }
    }

    public func setFlowMultiplier(_ multiplier: Float) {
        flowMultiplier = multiplier
    }

    public func shouldTrigger(at step: Int) -> Bool {
        guard step < steps.count else { return false }

        let probability = steps[step].effectiveProbability * globalProbability
        return Float.random(in: 0...1) < probability
    }

    public func getProbabilityMask() -> [Float] {
        steps.map { $0.effectiveProbability }
    }

    private func mutateRandomStep() {
        let index = Int.random(in: 0..<steps.count)
        steps[index].probability = Float.random(in: 0...1)
    }

    public func randomize() {
        for i in 0..<steps.count {
            steps[i].probability = Float.random(in: 0...1)
            steps[i].velocity = Float.random(in: 0.5...1.0)
        }
    }

    public func setPattern(_ pattern: [Float]) {
        for (i, prob) in pattern.enumerated() where i < steps.count {
            steps[i].probability = prob
        }
    }

    public struct ProbabilityStep: Identifiable {
        public let id = UUID()
        public var index: Int
        public var probability: Float
        public var effectiveProbability: Float = 1.0
        public var velocity: Float
        public var pitch: Int
        public var conditions: [Condition] = []

        public struct Condition {
            public var type: ConditionType
            public var threshold: Float

            public enum ConditionType {
                case coherenceAbove
                case coherenceBelow
                case energyAbove
                case energyBelow
                case previousTriggered
                case previousSkipped
            }
        }
    }
}

// MARK: - SpectrumWeaver (Advanced FFT Processing)

public class SpectrumWeaver: ObservableObject {
    @Published public var bands: Int = 64
    @Published public var spectralMask: [Float] = []
    @Published public var spectralFreeze: Bool = false
    @Published public var spectralBlur: Float = 0.0
    @Published public var spectralShift: Float = 0.0
    @Published public var harmonicEnhance: Float = 0.0
    @Published public var spectralGate: Float = 0.0
    @Published public var coherenceModulation: Float = 0.5

    private var spectrum: [Float] = []
    private var frozenSpectrum: [Float] = []
    private var flowMultiplier: Float = 1.0
    private var coherence: Float = 0.5

    public init() {
        spectralMask = [Float](repeating: 1.0, count: bands)
    }

    public func updateSpectrum(_ data: [Float]) {
        spectrum = data

        if spectralFreeze {
            // Blend with frozen spectrum
            if frozenSpectrum.isEmpty {
                frozenSpectrum = data
            }
        } else {
            processSpectrum()
        }
    }

    public func setCoherence(_ coherence: Float) {
        self.coherence = coherence

        if coherenceModulation > 0 {
            applyCoherenceModulation()
        }
    }

    public func setFlowMultiplier(_ multiplier: Float) {
        flowMultiplier = multiplier
    }

    private func processSpectrum() {
        guard !spectrum.isEmpty else { return }

        var processed = spectrum

        // Apply spectral blur (moving average)
        if spectralBlur > 0 {
            let windowSize = Int(spectralBlur * 10) + 1
            processed = applySpectralBlur(processed, windowSize: windowSize)
        }

        // Apply spectral shift
        if spectralShift != 0 {
            processed = applySpectralShift(processed, shift: spectralShift)
        }

        // Apply harmonic enhancement
        if harmonicEnhance > 0 {
            processed = applyHarmonicEnhance(processed, amount: harmonicEnhance)
        }

        // Apply spectral gate
        if spectralGate > 0 {
            let threshold = spectralGate * (processed.max() ?? 1.0)
            processed = processed.map { $0 > threshold ? $0 : 0 }
        }

        spectralMask = processed
    }

    private func applyCoherenceModulation() {
        // High coherence = enhance harmonics
        // Low coherence = add noise/texture
        for i in 0..<spectralMask.count {
            let isHarmonic = i % 4 == 0

            if coherence > 0.6 && isHarmonic {
                spectralMask[i] *= (1.0 + coherenceModulation * 0.5)
            } else if coherence < 0.4 && !isHarmonic {
                spectralMask[i] *= (1.0 + (1 - coherence) * coherenceModulation * 0.3)
            }
        }
    }

    private func applySpectralBlur(_ spectrum: [Float], windowSize: Int) -> [Float] {
        guard windowSize > 1 else { return spectrum }

        var result = [Float](repeating: 0, count: spectrum.count)
        let halfWindow = windowSize / 2

        for i in 0..<spectrum.count {
            var sum: Float = 0
            var count = 0

            for j in max(0, i - halfWindow)..<min(spectrum.count, i + halfWindow + 1) {
                sum += spectrum[j]
                count += 1
            }

            result[i] = sum / Float(count)
        }

        return result
    }

    private func applySpectralShift(_ spectrum: [Float], shift: Float) -> [Float] {
        let shiftBins = Int(shift * Float(spectrum.count))
        guard shiftBins != 0 else { return spectrum }

        var result = [Float](repeating: 0, count: spectrum.count)

        for i in 0..<spectrum.count {
            let sourceIndex = i - shiftBins
            if sourceIndex >= 0 && sourceIndex < spectrum.count {
                result[i] = spectrum[sourceIndex]
            }
        }

        return result
    }

    private func applyHarmonicEnhance(_ spectrum: [Float], amount: Float) -> [Float] {
        var result = spectrum

        // Boost harmonics (every 2nd, 3rd, 4th bin based on fundamental detection)
        for i in stride(from: 0, to: spectrum.count, by: 2) {
            result[i] *= (1.0 + amount * 0.5)
        }

        return result
    }

    public func getSpectralMask() -> [Float] {
        spectralMask
    }

    public func freeze() {
        spectralFreeze = true
        frozenSpectrum = spectrum
    }

    public func unfreeze() {
        spectralFreeze = false
        frozenSpectrum = []
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - ULTRA 8 TOOLS (Advanced Synthesis & Production)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - GrainCloud (Granular Synthesis)

public class GrainCloud: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var grainSize: Float = 50.0      // ms (1-500)
    @Published public var grainDensity: Float = 20.0   // grains per second
    @Published public var grainPitch: Float = 1.0      // pitch ratio (0.25-4.0)
    @Published public var grainSpread: Float = 0.0     // stereo spread (0-100%)
    @Published public var grainPosition: Float = 0.5   // playback position (0-1)
    @Published public var positionRandom: Float = 0.0  // position randomization
    @Published public var pitchRandom: Float = 0.0     // pitch randomization
    @Published public var reverseGrains: Float = 0.0   // % of reversed grains
    @Published public var windowShape: WindowShape = .hann
    @Published public var bioReactivity: Float = 0.0   // bio-feedback influence

    public enum WindowShape: String, CaseIterable {
        case hann = "Hann"
        case hamming = "Hamming"
        case blackman = "Blackman"
        case triangle = "Triangle"
        case rectangle = "Rectangle"
        case gaussian = "Gaussian"
    }

    public struct Grain {
        var position: Float
        var size: Float
        var pitch: Float
        var pan: Float
        var amplitude: Float
        var isReversed: Bool
        var progress: Float
    }

    private var activeGrains: [Grain] = []
    private var sourceBuffer: [Float] = []
    private var lastGrainTime: Double = 0

    public func setSource(_ buffer: [Float]) {
        sourceBuffer = buffer
    }

    public func process(bufferSize: Int, sampleRate: Float, bioCoherence: Float = 0.5) -> [Float] {
        guard isActive, !sourceBuffer.isEmpty else {
            return [Float](repeating: 0, count: bufferSize)
        }

        var output = [Float](repeating: 0, count: bufferSize)
        let grainInterval = 1.0 / Double(grainDensity)

        // Bio-reactive modulation
        let bioMod = 1.0 + (bioCoherence - 0.5) * bioReactivity / 50.0

        // Generate new grains
        let currentGrainSize = grainSize * Float(bioMod)
        let grainSamples = Int(currentGrainSize * sampleRate / 1000.0)

        for i in 0..<bufferSize {
            // Spawn new grain if needed
            let currentTime = Double(i) / Double(sampleRate)
            if currentTime - lastGrainTime > grainInterval {
                spawnGrain(grainSamples: grainSamples)
                lastGrainTime = currentTime
            }

            // Process active grains
            var sample: Float = 0
            for index in (0..<activeGrains.count).reversed() {
                var grain = activeGrains[index]

                // Get source sample
                let sourceIndex = Int(grain.position * Float(sourceBuffer.count))
                let clampedIndex = max(0, min(sourceBuffer.count - 1, sourceIndex))
                var sourceSample = sourceBuffer[clampedIndex]

                if grain.isReversed {
                    sourceSample = -sourceSample
                }

                // Apply window
                let windowValue = applyWindow(progress: grain.progress)
                sample += sourceSample * windowValue * grain.amplitude

                // Advance grain
                grain.progress += 1.0 / Float(grainSamples)
                grain.position += grain.pitch / Float(sourceBuffer.count)

                if grain.progress >= 1.0 {
                    activeGrains.remove(at: index)
                } else {
                    activeGrains[index] = grain
                }
            }

            output[i] = sample
        }

        return output
    }

    private func spawnGrain(grainSamples: Int) {
        let posRand = Float.random(in: -1...1) * positionRandom / 100.0
        let pitchRand = Float.random(in: -1...1) * pitchRandom / 100.0
        let isReversed = Float.random(in: 0...100) < reverseGrains

        let grain = Grain(
            position: grainPosition + posRand,
            size: Float(grainSamples),
            pitch: grainPitch + pitchRand,
            pan: Float.random(in: -1...1) * grainSpread / 100.0,
            amplitude: 1.0,
            isReversed: isReversed,
            progress: 0
        )

        activeGrains.append(grain)
    }

    private func applyWindow(progress: Float) -> Float {
        let x = progress * 2.0 - 1.0  // -1 to 1

        switch windowShape {
        case .hann:
            return 0.5 * (1.0 - cos(Float.pi * (progress * 2.0)))
        case .hamming:
            return 0.54 - 0.46 * cos(Float.pi * 2.0 * progress)
        case .blackman:
            return 0.42 - 0.5 * cos(Float.pi * 2.0 * progress) + 0.08 * cos(Float.pi * 4.0 * progress)
        case .triangle:
            return 1.0 - abs(x)
        case .rectangle:
            return 1.0
        case .gaussian:
            return exp(-0.5 * x * x * 9.0)  // sigma = 1/3
        }
    }
}

// MARK: - HarmoniX (Intelligent Harmonizer)

public class HarmoniX: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var voices: [HarmonyVoice] = []
    @Published public var dryWet: Float = 50.0
    @Published public var masterPitch: Float = 0.0    // semitones
    @Published public var formantPreserve: Bool = true
    @Published public var autoHarmony: Bool = false
    @Published public var key: MusicalKey = .c
    @Published public var scale: Scale = .major
    @Published public var bioReactivity: Float = 0.0

    public enum MusicalKey: String, CaseIterable {
        case c = "C", cSharp = "C#", d = "D", dSharp = "D#"
        case e = "E", f = "F", fSharp = "F#", g = "G"
        case gSharp = "G#", a = "A", aSharp = "A#", b = "B"

        var semitone: Int {
            switch self {
            case .c: return 0
            case .cSharp: return 1
            case .d: return 2
            case .dSharp: return 3
            case .e: return 4
            case .f: return 5
            case .fSharp: return 6
            case .g: return 7
            case .gSharp: return 8
            case .a: return 9
            case .aSharp: return 10
            case .b: return 11
            }
        }
    }

    public enum Scale: String, CaseIterable {
        case major = "Major"
        case minor = "Minor"
        case harmonicMinor = "Harmonic Minor"
        case pentatonic = "Pentatonic"
        case blues = "Blues"
        case dorian = "Dorian"
        case mixolydian = "Mixolydian"
        case chromatic = "Chromatic"

        var intervals: [Int] {
            switch self {
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
            case .pentatonic: return [0, 2, 4, 7, 9]
            case .blues: return [0, 3, 5, 6, 7, 10]
            case .dorian: return [0, 2, 3, 5, 7, 9, 10]
            case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
            case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
            }
        }
    }

    public struct HarmonyVoice: Identifiable {
        public var id = UUID()
        public var interval: Int       // semitones from root
        public var detune: Float       // cents
        public var pan: Float          // -1 to 1
        public var level: Float        // 0-100%
        public var delay: Float        // ms
        public var isActive: Bool

        public init(interval: Int = 0, detune: Float = 0, pan: Float = 0, level: Float = 100, delay: Float = 0, isActive: Bool = true) {
            self.interval = interval
            self.detune = detune
            self.pan = pan
            self.level = level
            self.delay = delay
            self.isActive = isActive
        }
    }

    public init() {
        // Default 4-voice harmony
        voices = [
            HarmonyVoice(interval: -12, pan: -0.5, level: 70),  // Octave down
            HarmonyVoice(interval: 4, pan: 0.3, level: 80),     // Major third
            HarmonyVoice(interval: 7, pan: -0.3, level: 80),    // Perfect fifth
            HarmonyVoice(interval: 12, pan: 0.5, level: 60)     // Octave up
        ]
    }

    public func addVoice(_ voice: HarmonyVoice) {
        guard voices.count < 8 else { return }
        voices.append(voice)
    }

    public func removeVoice(at index: Int) {
        guard index < voices.count else { return }
        voices.remove(at: index)
    }

    public func quantizeToScale(pitchSemitones: Float) -> Float {
        let keyOffset = Float(key.semitone)
        let relativePitch = pitchSemitones - keyOffset
        let octave = floor(relativePitch / 12.0)
        let noteInOctave = Int(relativePitch.truncatingRemainder(dividingBy: 12.0))

        // Find nearest scale degree
        var nearestInterval = 0
        var minDistance = 12

        for interval in scale.intervals {
            let distance = abs(noteInOctave - interval)
            if distance < minDistance {
                minDistance = distance
                nearestInterval = interval
            }
        }

        return keyOffset + octave * 12.0 + Float(nearestInterval)
    }
}

// MARK: - DrumForge (AI Drum Pattern Generator)

public class DrumForge: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var tempo: Double = 120.0
    @Published public var swing: Float = 0.0           // 0-100%
    @Published public var complexity: Float = 50.0     // 0-100%
    @Published public var density: Float = 50.0        // 0-100%
    @Published public var variation: Float = 30.0      // 0-100%
    @Published public var genre: Genre = .electronic
    @Published public var currentPattern: DrumPattern = DrumPattern()
    @Published public var bioReactivity: Float = 0.0

    public enum Genre: String, CaseIterable {
        case electronic = "Electronic"
        case hiphop = "Hip-Hop"
        case house = "House"
        case techno = "Techno"
        case dnb = "Drum & Bass"
        case rock = "Rock"
        case jazz = "Jazz"
        case latin = "Latin"
        case ambient = "Ambient"
    }

    public enum DrumVoice: String, CaseIterable {
        case kick = "Kick"
        case snare = "Snare"
        case hihat = "Hi-Hat"
        case openHat = "Open Hat"
        case clap = "Clap"
        case tom = "Tom"
        case ride = "Ride"
        case crash = "Crash"
        case perc = "Percussion"
    }

    public struct DrumHit: Identifiable {
        public var id = UUID()
        public var voice: DrumVoice
        public var step: Int           // 0-63 (16 steps * 4 = 64 substeps)
        public var velocity: Float     // 0-1
        public var probability: Float  // 0-1
    }

    public struct DrumPattern: Identifiable {
        public var id = UUID()
        public var name: String = "New Pattern"
        public var steps: Int = 16
        public var hits: [DrumHit] = []
    }

    public func generate(bioCoherence: Float = 0.5) {
        var newHits: [DrumHit] = []
        let steps = 16

        // Bio-reactive complexity
        let effectiveComplexity = complexity + (bioCoherence - 0.5) * bioReactivity

        // Genre-specific patterns
        let kickPattern = getKickPattern(genre: genre, complexity: effectiveComplexity)
        let snarePattern = getSnarePattern(genre: genre, complexity: effectiveComplexity)
        let hatPattern = getHatPattern(genre: genre, density: density)

        for step in 0..<steps {
            // Add kick
            if kickPattern.contains(step) {
                newHits.append(DrumHit(
                    voice: .kick,
                    step: step * 4,
                    velocity: Float.random(in: 0.8...1.0),
                    probability: 1.0
                ))
            }

            // Add snare
            if snarePattern.contains(step) {
                newHits.append(DrumHit(
                    voice: .snare,
                    step: step * 4,
                    velocity: Float.random(in: 0.7...0.95),
                    probability: 1.0
                ))
            }

            // Add hi-hats
            if hatPattern.contains(step) {
                let isOpen = Float.random(in: 0...100) < 15
                newHits.append(DrumHit(
                    voice: isOpen ? .openHat : .hihat,
                    step: step * 4,
                    velocity: Float.random(in: 0.5...0.8),
                    probability: 0.9
                ))
            }

            // Add variation hits
            if Float.random(in: 0...100) < variation {
                // CRITICAL FIX: Safe unwrapping for randomElement
                let voice: DrumVoice = [.clap, .tom, .perc].randomElement() ?? .clap
                newHits.append(DrumHit(
                    voice: voice,
                    step: step * 4 + Int.random(in: 0...3),
                    velocity: Float.random(in: 0.4...0.7),
                    probability: 0.5
                ))
            }
        }

        currentPattern.hits = newHits
    }

    private func getKickPattern(genre: Genre, complexity: Float) -> [Int] {
        switch genre {
        case .electronic, .house:
            return [0, 4, 8, 12]  // Four on the floor
        case .hiphop:
            return [0, 6, 10]    // Boom-bap feel
        case .techno:
            return [0, 4, 8, 12] // Four on the floor
        case .dnb:
            return [0, 10]       // Broken beat
        case .rock:
            return [0, 8]        // Standard rock
        case .jazz:
            return complexity > 50 ? [0, 7, 12] : [0, 8]
        case .latin:
            return [0, 3, 6, 10, 14]
        case .ambient:
            return [0]
        }
    }

    private func getSnarePattern(genre: Genre, complexity: Float) -> [Int] {
        switch genre {
        case .electronic, .house, .techno:
            return [4, 12]
        case .hiphop:
            return [4, 12]
        case .dnb:
            return [4, 14]
        case .rock:
            return [4, 12]
        case .jazz:
            return complexity > 60 ? [4, 10, 14] : [4, 12]
        case .latin:
            return [4, 8, 12]
        case .ambient:
            return []
        }
    }

    private func getHatPattern(genre: Genre, density: Float) -> [Int] {
        var pattern: [Int] = []
        let steps = Int(density / 100.0 * 16.0)

        switch genre {
        case .electronic, .house, .techno:
            for i in 0..<min(steps, 16) {
                pattern.append(i)
            }
        case .hiphop:
            pattern = [0, 2, 4, 6, 8, 10, 12, 14]
        case .dnb:
            for i in 0..<16 {
                pattern.append(i)
            }
        default:
            pattern = [0, 2, 4, 6, 8, 10, 12, 14]
        }

        return pattern
    }
}

// MARK: - SynthWeaver (Wavetable Synthesis)

public class SynthWeaver: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var waveform: Waveform = .saw
    @Published public var wavetablePosition: Float = 0.0   // 0-1
    @Published public var morphSpeed: Float = 0.0          // 0-100%
    @Published public var unisonVoices: Int = 1            // 1-16
    @Published public var unisonDetune: Float = 0.0        // cents
    @Published public var unisonSpread: Float = 50.0       // stereo spread
    @Published public var filterCutoff: Float = 20000.0    // Hz
    @Published public var filterResonance: Float = 0.0     // 0-100%
    @Published public var filterEnvAmount: Float = 0.0
    @Published public var attackTime: Float = 10.0         // ms
    @Published public var decayTime: Float = 100.0         // ms
    @Published public var sustainLevel: Float = 70.0       // %
    @Published public var releaseTime: Float = 200.0       // ms
    @Published public var bioReactivity: Float = 0.0

    public enum Waveform: String, CaseIterable {
        case sine = "Sine"
        case triangle = "Triangle"
        case saw = "Saw"
        case square = "Square"
        case pulse = "Pulse"
        case noise = "Noise"
        case superSaw = "Super Saw"
        case wavetable = "Wavetable"
    }

    public struct WavetableFrame {
        var samples: [Float]
    }

    private var wavetable: [WavetableFrame] = []
    private var phase: Float = 0.0

    public init() {
        generateDefaultWavetable()
    }

    private func generateDefaultWavetable() {
        // Generate a basic wavetable with morphing waveforms
        wavetable = []
        let frameSize = 2048

        for frameIndex in 0..<64 {
            var frame = WavetableFrame(samples: [])
            let morphAmount = Float(frameIndex) / 63.0

            for i in 0..<frameSize {
                let phase = Float(i) / Float(frameSize) * 2.0 * Float.pi

                // Morph from sine to saw
                let sine = sin(phase)
                var saw: Float = 0
                for harmonic in 1...32 {
                    saw += sin(phase * Float(harmonic)) / Float(harmonic)
                }
                saw *= 2.0 / Float.pi

                let sample = sine * (1.0 - morphAmount) + saw * morphAmount
                frame.samples.append(sample)
            }

            wavetable.append(frame)
        }
    }

    public func generateSample(frequency: Float, sampleRate: Float, bioCoherence: Float = 0.5) -> Float {
        let phaseIncrement = frequency / sampleRate

        // Bio-reactive wavetable position
        let bioMod = (bioCoherence - 0.5) * bioReactivity / 50.0
        let effectivePosition = max(0, min(1, wavetablePosition + bioMod))

        var sample: Float = 0

        switch waveform {
        case .sine:
            sample = sin(phase * 2.0 * Float.pi)
        case .triangle:
            let t = fmod(phase, 1.0)
            sample = 4.0 * abs(t - 0.5) - 1.0
        case .saw:
            sample = 2.0 * fmod(phase, 1.0) - 1.0
        case .square:
            sample = fmod(phase, 1.0) < 0.5 ? 1.0 : -1.0
        case .pulse:
            sample = fmod(phase, 1.0) < 0.25 ? 1.0 : -1.0
        case .noise:
            sample = Float.random(in: -1...1)
        case .superSaw:
            for voice in 0..<unisonVoices {
                let detuneAmount = Float(voice - unisonVoices / 2) * unisonDetune / 100.0
                let voicePhase = fmod(phase * (1.0 + detuneAmount / 1200.0), 1.0)
                sample += 2.0 * voicePhase - 1.0
            }
            sample /= Float(unisonVoices)
        case .wavetable:
            if !wavetable.isEmpty {
                let frameIndex = Int(effectivePosition * Float(wavetable.count - 1))
                let sampleIndex = Int(fmod(phase, 1.0) * Float(wavetable[frameIndex].samples.count))
                sample = wavetable[frameIndex].samples[sampleIndex]
            }
        }

        phase += phaseIncrement
        if phase >= 1.0 { phase -= 1.0 }

        return sample
    }
}

// MARK: - VocalShift (Pitch Correction & Harmonies)

public class VocalShift: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var pitchCorrection: Float = 100.0   // 0-100%
    @Published public var correctionSpeed: Float = 50.0    // 0-100%
    @Published public var formantShift: Float = 0.0        // semitones
    @Published public var targetKey: HarmoniX.MusicalKey = .c
    @Published public var targetScale: HarmoniX.Scale = .major
    @Published public var harmonies: [Float] = []          // semitone offsets
    @Published public var naturalness: Float = 70.0        // 0-100%
    @Published public var vibrato: Float = 0.0             // 0-100%
    @Published public var vibratoRate: Float = 5.0         // Hz
    @Published public var bioReactivity: Float = 0.0

    public struct PitchData {
        var detectedPitch: Float       // Hz
        var correctedPitch: Float      // Hz
        var confidence: Float          // 0-1
        var formantRatio: Float
    }

    private var lastPitchData: PitchData?
    private var vibratoPhase: Float = 0.0

    public func process(detectedPitch: Float, confidence: Float, sampleRate: Float, bioCoherence: Float = 0.5) -> PitchData {
        guard detectedPitch > 0 && confidence > 0.5 else {
            return PitchData(detectedPitch: 0, correctedPitch: 0, confidence: 0, formantRatio: 1.0)
        }

        // Convert to semitones
        let pitchSemitones = 12.0 * log2(detectedPitch / 440.0) + 69.0

        // Quantize to scale
        let targetSemitones = quantizeToScale(pitchSemitones)

        // Apply correction with speed
        let correctionAmount = pitchCorrection / 100.0
        let speedFactor = correctionSpeed / 100.0
        let correctedSemitones = pitchSemitones + (targetSemitones - pitchSemitones) * correctionAmount * speedFactor

        // Bio-reactive naturalness
        let bioNaturalness = naturalness + (bioCoherence - 0.5) * bioReactivity
        let naturalVariation = Float.random(in: -1...1) * (100.0 - bioNaturalness) / 1000.0

        // Add vibrato
        var finalSemitones = correctedSemitones + naturalVariation
        if vibrato > 0 {
            vibratoPhase += vibratoRate / sampleRate
            if vibratoPhase >= 1.0 { vibratoPhase -= 1.0 }
            let vibratoAmount = sin(vibratoPhase * 2.0 * Float.pi) * vibrato / 100.0 * 0.5
            finalSemitones += vibratoAmount
        }

        // Convert back to Hz
        let correctedPitch = 440.0 * pow(2.0, (finalSemitones - 69.0) / 12.0)

        // Calculate formant ratio
        let formantRatio = pow(2.0, formantShift / 12.0)

        let data = PitchData(
            detectedPitch: detectedPitch,
            correctedPitch: correctedPitch,
            confidence: confidence,
            formantRatio: formantRatio
        )

        lastPitchData = data
        return data
    }

    private func quantizeToScale(_ pitchSemitones: Float) -> Float {
        let keyOffset = Float(targetKey.semitone)
        let relativePitch = pitchSemitones - keyOffset
        let octave = floor(relativePitch / 12.0)
        let noteInOctave = relativePitch.truncatingRemainder(dividingBy: 12.0)

        var nearestInterval: Float = 0
        var minDistance: Float = 12

        for interval in targetScale.intervals {
            let distance = abs(noteInOctave - Float(interval))
            if distance < minDistance {
                minDistance = distance
                nearestInterval = Float(interval)
            }
        }

        return keyOffset + octave * 12.0 + nearestInterval
    }
}

// MARK: - AmbientScape (Generative Ambient)

public class AmbientScape: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var density: Float = 50.0            // 0-100%
    @Published public var movement: Float = 30.0           // 0-100%
    @Published public var brightness: Float = 50.0         // 0-100%
    @Published public var depth: Float = 70.0              // reverb amount
    @Published public var evolution: Float = 20.0          // change speed
    @Published public var mood: Mood = .peaceful
    @Published public var layers: [AmbientLayer] = []
    @Published public var bioReactivity: Float = 50.0

    public enum Mood: String, CaseIterable {
        case peaceful = "Peaceful"
        case mysterious = "Mysterious"
        case ethereal = "Ethereal"
        case dark = "Dark"
        case uplifting = "Uplifting"
        case meditative = "Meditative"
        case cinematic = "Cinematic"
    }

    public struct AmbientLayer: Identifiable {
        public var id = UUID()
        public var type: LayerType
        public var level: Float
        public var pitch: Float
        public var filter: Float
        public var pan: Float

        public enum LayerType: String, CaseIterable {
            case pad = "Pad"
            case texture = "Texture"
            case drone = "Drone"
            case bell = "Bell"
            case wind = "Wind"
            case water = "Water"
            case shimmer = "Shimmer"
        }
    }

    public init() {
        // Default layers based on mood
        updateLayersForMood()
    }

    public func updateLayersForMood() {
        layers = []

        switch mood {
        case .peaceful:
            layers = [
                AmbientLayer(type: .pad, level: 70, pitch: 0, filter: 60, pan: 0),
                AmbientLayer(type: .shimmer, level: 30, pitch: 12, filter: 80, pan: 0.3),
                AmbientLayer(type: .texture, level: 20, pitch: 0, filter: 50, pan: -0.3)
            ]
        case .mysterious:
            layers = [
                AmbientLayer(type: .drone, level: 60, pitch: -12, filter: 30, pan: 0),
                AmbientLayer(type: .texture, level: 40, pitch: 0, filter: 40, pan: 0.5),
                AmbientLayer(type: .bell, level: 25, pitch: 7, filter: 70, pan: -0.4)
            ]
        case .ethereal:
            layers = [
                AmbientLayer(type: .shimmer, level: 60, pitch: 12, filter: 90, pan: 0),
                AmbientLayer(type: .pad, level: 50, pitch: 0, filter: 70, pan: 0.2),
                AmbientLayer(type: .bell, level: 30, pitch: 19, filter: 85, pan: -0.2)
            ]
        case .dark:
            layers = [
                AmbientLayer(type: .drone, level: 80, pitch: -24, filter: 20, pan: 0),
                AmbientLayer(type: .texture, level: 50, pitch: -12, filter: 30, pan: 0.6),
                AmbientLayer(type: .wind, level: 30, pitch: 0, filter: 25, pan: -0.5)
            ]
        case .uplifting:
            layers = [
                AmbientLayer(type: .pad, level: 70, pitch: 0, filter: 75, pan: 0),
                AmbientLayer(type: .shimmer, level: 50, pitch: 12, filter: 85, pan: 0.3),
                AmbientLayer(type: .bell, level: 35, pitch: 7, filter: 80, pan: -0.3)
            ]
        case .meditative:
            layers = [
                AmbientLayer(type: .drone, level: 50, pitch: 0, filter: 40, pan: 0),
                AmbientLayer(type: .water, level: 30, pitch: 0, filter: 60, pan: 0.4),
                AmbientLayer(type: .bell, level: 20, pitch: 12, filter: 70, pan: -0.4)
            ]
        case .cinematic:
            layers = [
                AmbientLayer(type: .pad, level: 70, pitch: 0, filter: 50, pan: 0),
                AmbientLayer(type: .drone, level: 60, pitch: -12, filter: 35, pan: 0.5),
                AmbientLayer(type: .texture, level: 40, pitch: 7, filter: 55, pan: -0.5),
                AmbientLayer(type: .shimmer, level: 25, pitch: 12, filter: 80, pan: 0)
            ]
        }
    }

    public func evolve(bioCoherence: Float = 0.5) {
        // Bio-reactive evolution
        let evolutionSpeed = evolution + (bioCoherence - 0.5) * bioReactivity

        for index in 0..<layers.count {
            // Slowly evolve parameters
            let change = Float.random(in: -1...1) * evolutionSpeed / 100.0

            layers[index].filter = max(0, min(100, layers[index].filter + change * 10))
            layers[index].pitch += change * 0.5
            layers[index].pan = max(-1, min(1, layers[index].pan + change * 0.1))
        }
    }
}

// MARK: - BassArchitect (Bass Synthesis & Enhancement)

public class BassArchitect: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var subLevel: Float = 50.0           // 0-100%
    @Published public var harmonicLevel: Float = 50.0      // 0-100%
    @Published public var drive: Float = 0.0               // 0-100%
    @Published public var subFrequency: Float = 60.0       // Hz
    @Published public var attackTime: Float = 10.0         // ms
    @Published public var decayTime: Float = 200.0         // ms
    @Published public var sustainLevel: Float = 60.0       // %
    @Published public var releaseTime: Float = 300.0       // ms
    @Published public var filterCutoff: Float = 200.0      // Hz
    @Published public var filterEnvAmount: Float = 50.0    // %
    @Published public var character: Character = .deep
    @Published public var bioReactivity: Float = 0.0

    public enum Character: String, CaseIterable {
        case deep = "Deep"
        case punchy = "Punchy"
        case growl = "Growl"
        case smooth = "Smooth"
        case aggressive = "Aggressive"
        case reese = "Reese"
        case wobble = "Wobble"
        case sub808 = "808 Sub"
    }

    public func process(_ input: [Float], sampleRate: Float, bioCoherence: Float = 0.5) -> [Float] {
        guard isActive else { return input }

        var output = [Float](repeating: 0, count: input.count)

        // Generate sub bass
        var subPhase: Float = 0.0
        let subIncrement = subFrequency / sampleRate

        for i in 0..<input.count {
            // Input signal
            let dry = input[i]

            // Generate sub sine
            let sub = sin(subPhase * 2.0 * Float.pi) * subLevel / 100.0

            // Generate harmonics based on character
            var harmonics: Float = 0.0
            switch character {
            case .deep:
                harmonics = sin(subPhase * 4.0 * Float.pi) * 0.3
            case .punchy:
                harmonics = sin(subPhase * 4.0 * Float.pi) * 0.5 + sin(subPhase * 6.0 * Float.pi) * 0.2
            case .growl:
                harmonics = tanh(sin(subPhase * 4.0 * Float.pi) * 2.0) * 0.6
            case .smooth:
                harmonics = sin(subPhase * 2.0 * Float.pi) * 0.4
            case .aggressive:
                harmonics = tanh(sin(subPhase * 4.0 * Float.pi) * 3.0) * 0.7
            case .reese:
                let detune = sin(Float(i) / sampleRate * 2.0 * Float.pi * 0.5) * 2.0
                harmonics = sin((subPhase + detune / sampleRate) * 4.0 * Float.pi) * 0.5
            case .wobble:
                let wobbleRate = 4.0 + bioCoherence * bioReactivity / 50.0
                let wobble = sin(Float(i) / sampleRate * 2.0 * Float.pi * wobbleRate)
                harmonics = sin(subPhase * 4.0 * Float.pi) * (0.5 + wobble * 0.3)
            case .sub808:
                // 808 pitch envelope
                let pitchEnv = exp(-Float(i) / (sampleRate * 0.05))
                let pitch808 = subFrequency * (1.0 + pitchEnv * 0.5)
                harmonics = sin(subPhase * 2.0 * Float.pi * (pitch808 / subFrequency)) * 0.4
            }

            harmonics *= harmonicLevel / 100.0

            // Apply drive
            var bassSignal = sub + harmonics
            if drive > 0 {
                bassSignal = tanh(bassSignal * (1.0 + drive / 25.0))
            }

            // Mix with input
            output[i] = dry + bassSignal

            subPhase += subIncrement
            if subPhase >= 1.0 { subPhase -= 1.0 }
        }

        return output
    }
}

// MARK: - MixMatrix (Intelligent Mixing & Mastering)

public class MixMatrix: ObservableObject {
    @Published public var isActive: Bool = false
    @Published public var inputGain: Float = 0.0           // dB
    @Published public var outputGain: Float = 0.0          // dB
    @Published public var stereoWidth: Float = 100.0       // %
    @Published public var bassEnhance: Float = 0.0         // dB
    @Published public var presenceEnhance: Float = 0.0     // dB
    @Published public var airEnhance: Float = 0.0          // dB
    @Published public var compressionAmount: Float = 0.0   // %
    @Published public var limiterCeiling: Float = -0.3     // dB
    @Published public var loudnessTarget: Float = -14.0    // LUFS
    @Published public var autoMaster: Bool = false
    @Published public var metering: MeteringData = MeteringData()
    @Published public var bioReactivity: Float = 0.0

    public struct MeteringData {
        var peakL: Float = -60.0
        var peakR: Float = -60.0
        var rmsL: Float = -60.0
        var rmsR: Float = -60.0
        var lufs: Float = -60.0
        var correlation: Float = 1.0
        var dynamicRange: Float = 0.0
    }

    public enum Band: String, CaseIterable {
        case sub = "Sub (20-60Hz)"
        case bass = "Bass (60-250Hz)"
        case lowMid = "Low Mid (250-500Hz)"
        case mid = "Mid (500-2kHz)"
        case highMid = "High Mid (2-4kHz)"
        case presence = "Presence (4-8kHz)"
        case air = "Air (8-20kHz)"
    }

    public struct BandSettings {
        var gain: Float = 0.0
        var compress: Float = 0.0
        var solo: Bool = false
        var mute: Bool = false
    }

    @Published public var bands: [Band: BandSettings] = [:]

    public init() {
        for band in Band.allCases {
            bands[band] = BandSettings()
        }
    }

    public func process(left: [Float], right: [Float], sampleRate: Float, bioCoherence: Float = 0.5) -> (left: [Float], right: [Float]) {
        guard isActive else { return (left, right) }

        var outL = left
        var outR = right

        // Apply input gain
        let inputGainLinear = pow(10.0, inputGain / 20.0)
        for i in 0..<outL.count {
            outL[i] *= inputGainLinear
            outR[i] *= inputGainLinear
        }

        // Stereo width (M/S processing)
        if stereoWidth != 100.0 {
            let widthFactor = stereoWidth / 100.0
            for i in 0..<min(outL.count, outR.count) {
                let mid = (outL[i] + outR[i]) / 2.0
                let side = (outL[i] - outR[i]) / 2.0 * widthFactor
                outL[i] = mid + side
                outR[i] = mid - side
            }
        }

        // Apply compression (simplified)
        if compressionAmount > 0 {
            let threshold: Float = -10.0
            let ratio: Float = 1.0 + compressionAmount / 25.0

            for i in 0..<outL.count {
                let peakDB = 20.0 * log10(max(abs(outL[i]), abs(outR[i])) + 0.0001)
                if peakDB > threshold {
                    let gainReduction = (peakDB - threshold) * (1.0 - 1.0 / ratio)
                    let gainLinear = pow(10.0, -gainReduction / 20.0)
                    outL[i] *= gainLinear
                    outR[i] *= gainLinear
                }
            }
        }

        // Bio-reactive enhancement
        let bioMod = (bioCoherence - 0.5) * bioReactivity / 50.0

        // Apply enhancements with bio-modulation
        // (In production, use proper multi-band EQ)

        // Limiting
        let ceiling = pow(10.0, limiterCeiling / 20.0)
        for i in 0..<outL.count {
            outL[i] = max(-ceiling, min(ceiling, outL[i]))
            outR[i] = max(-ceiling, min(ceiling, outR[i]))
        }

        // Apply output gain
        let outputGainLinear = pow(10.0, outputGain / 20.0)
        for i in 0..<outL.count {
            outL[i] *= outputGainLinear
            outR[i] *= outputGainLinear
        }

        // Update metering
        updateMetering(left: outL, right: outR)

        return (outL, outR)
    }

    private func updateMetering(left: [Float], right: [Float]) {
        // Peak
        metering.peakL = 20.0 * log10(left.map { abs($0) }.max() ?? 0.0001)
        metering.peakR = 20.0 * log10(right.map { abs($0) }.max() ?? 0.0001)

        // RMS
        let rmsL = sqrt(left.map { $0 * $0 }.reduce(0, +) / Float(left.count))
        let rmsR = sqrt(right.map { $0 * $0 }.reduce(0, +) / Float(right.count))
        metering.rmsL = 20.0 * log10(rmsL + 0.0001)
        metering.rmsR = 20.0 * log10(rmsR + 0.0001)

        // Simplified LUFS (actual LUFS requires K-weighting)
        metering.lufs = (metering.rmsL + metering.rmsR) / 2.0 - 0.691

        // Stereo correlation
        var sumProduct: Float = 0
        var sumL2: Float = 0
        var sumR2: Float = 0
        for i in 0..<min(left.count, right.count) {
            sumProduct += left[i] * right[i]
            sumL2 += left[i] * left[i]
            sumR2 += right[i] * right[i]
        }
        let denom = sqrt(sumL2 * sumR2)
        metering.correlation = denom > 0 ? sumProduct / denom : 1.0

        // Dynamic range
        metering.dynamicRange = metering.peakL - metering.rmsL
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - TOOL CHAIN SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

public class ToolChain: ObservableObject {
    @Published public var chain: [EchoelTools.Tool] = []
    @Published public var isActive: Bool = false
    @Published public var outputData: EchoelTools.ToolChainData = EchoelTools.ToolChainData()

    public var onChainUpdated: (() -> Void)?

    public var maxChainLength: Int = 8

    public func add(_ tool: EchoelTools.Tool) {
        guard chain.count < maxChainLength else { return }
        guard tool != .none else { return }

        chain.append(tool)
        onChainUpdated?()
    }

    public func remove(at index: Int) {
        guard index < chain.count else { return }
        chain.remove(at: index)
        onChainUpdated?()
    }

    public func move(from source: Int, to destination: Int) {
        guard source < chain.count && destination < chain.count else { return }
        let tool = chain.remove(at: source)
        chain.insert(tool, at: destination)
        onChainUpdated?()
    }

    public func clear() {
        chain.removeAll()
        onChainUpdated?()
    }

    public func activate() {
        isActive = true
    }

    public func deactivate() {
        isActive = false
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PRESET MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

public class PresetManager: ObservableObject {
    @Published public var presets: [ToolPreset] = []
    @Published public var factoryPresets: [ToolPreset] = []

    private let presetsKey = "EchoelTools.Presets"

    public init() {
        loadPresets()
        createFactoryPresets()
    }

    public func save(_ preset: ToolPreset) {
        presets.append(preset)
        persistPresets()
    }

    public func delete(_ preset: ToolPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    public func update(_ preset: ToolPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            persistPresets()
        }
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let loaded = try? JSONDecoder().decode([ToolPreset].self, from: data) {
            presets = loaded
        }
    }

    private func createFactoryPresets() {
        factoryPresets = [
            ToolPreset(
                name: "Bio Flow",
                activeTools: [.flowEngine, .bioNexus, .flowMotion],
                toolChain: [.bioNexus, .flowMotion, .flowEngine]
            ),
            ToolPreset(
                name: "Quantum Composer",
                activeTools: [.quantumComposer, .chanceField, .harmonicIntelligence],
                toolChain: [.chanceField, .quantumComposer, .harmonicIntelligence]
            ),
            ToolPreset(
                name: "Spectral Master",
                activeTools: [.spectralSculptor, .spectrumWeaver, .chronoWarp],
                toolChain: [.spectrumWeaver, .spectralSculptor, .chronoWarp]
            ),
            ToolPreset(
                name: "Rhythm Lab",
                activeTools: [.rhythmicIntelligence, .pulseForge, .soulPrint],
                toolChain: [.pulseForge, .rhythmicIntelligence, .soulPrint]
            ),
            ToolPreset(
                name: "Spatial Journey",
                activeTools: [.spatializer, .blendScape, .timeStretcher],
                toolChain: [.blendScape, .spatializer, .timeStretcher]
            ),
            ToolPreset(
                name: "Full Creative Suite",
                activeTools: Set(EchoelTools.Tool.allCases.filter { $0 != .none }),
                toolChain: [.bioNexus, .flowMotion, .quantumComposer, .chronoWarp]
            )
        ]
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - INTEGRATION BRIDGES
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Audio Bridge

public class AudioBridge: ObservableObject {
    @Published public var spectrumData: [Float] = []
    @Published public var waveformData: [Float] = []
    @Published public var rmsLevel: Float = 0.0
    @Published public var peakLevel: Float = 0.0
    @Published public var isConnected: Bool = false

    public func connect() {
        isConnected = true
    }

    public func disconnect() {
        isConnected = false
    }

    public func updateSpectrum(_ data: [Float]) {
        spectrumData = data
    }

    public func updateWaveform(_ data: [Float]) {
        waveformData = data
    }

    public func updateLevels(rms: Float, peak: Float) {
        rmsLevel = rms
        peakLevel = peak
    }
}

// MARK: - Bio Bridge

public class BioBridge: ObservableObject {
    @Published public var currentBioState: BioState = BioState()
    @Published public var isConnected: Bool = false
    @Published public var dataQuality: DataQuality = .unknown

    public enum DataQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case unknown = "Unknown"
    }

    public struct BioState {
        public var heartRate: Float = 72
        public var hrv: Float = 50
        public var coherence: Float = 0.5
        public var breathRate: Float = 12
        public var breathPhase: Float = 0
        public var energy: Float = 0.5
        public var stress: Float = 0.3

        public init() {}
    }

    public func connect() {
        isConnected = true
    }

    public func disconnect() {
        isConnected = false
    }

    public func update(_ state: BioState) {
        currentBioState = state
    }
}

// MARK: - Intelligence Bridge

public class IntelligenceBridge: ObservableObject {
    @Published public var suggestions: [Suggestion] = []
    @Published public var isProcessing: Bool = false
    @Published public var confidence: Float = 0.0

    public struct Suggestion: Identifiable {
        public let id = UUID()
        public var type: SuggestionType
        public var description: String
        public var confidence: Float
        public var action: (() -> Void)?

        public enum SuggestionType {
            case chord, scale, rhythm, effect, tempo, structure
        }
    }

    public func requestSuggestion(for context: String) async {
        isProcessing = true
        // AI processing would happen here
        isProcessing = false
    }
}

// MARK: - Hardware Bridge

public class HardwareBridge: ObservableObject {
    @Published public var connectedDevices: [Device] = []
    @Published public var midiActivity: Bool = false
    @Published public var oscActivity: Bool = false

    public struct Device: Identifiable {
        public let id = UUID()
        public var name: String
        public var type: DeviceType
        public var isConnected: Bool

        public enum DeviceType {
            case midiController, midiKeyboard, audioInterface, pushController, oscDevice
        }
    }

    public func onToolActivated(_ tool: EchoelTools.Tool) {
        // Send feedback to connected hardware
        midiActivity = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.midiActivity = false
        }
    }

    public func scanDevices() {
        // Scan for connected hardware
    }
}

// MARK: - Visual Bridge

public class VisualBridge: ObservableObject {
    @Published public var currentVisualization: String = "Liquid Light"
    @Published public var visualIntensity: Float = 1.0
    @Published public var ledPatternActive: Bool = false

    public func onToolActivated(_ tool: EchoelTools.Tool) {
        // Update visualization based on active tool
        switch tool {
        case .spectrumWeaver, .spectralSculptor:
            currentVisualization = "Spectrum"
        case .flowMotion, .flowEngine:
            currentVisualization = "Liquid Light"
        case .spatializer, .blendScape:
            currentVisualization = "3D Field"
        case .pulseForge, .rhythmicIntelligence:
            currentVisualization = "Pulse"
        default:
            break
        }
    }

    public func setLEDPattern(_ pattern: String) {
        ledPatternActive = true
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - SUPER UI WITH VAPORWAVE THEME
// ═══════════════════════════════════════════════════════════════════════════════

public struct EchoelToolsView: View {
    @ObservedObject var tools = EchoelTools.shared
    @State private var selectedCategory: EchoelTools.ToolCategory?
    @State private var showToolChain: Bool = false
    @State private var showPresets: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Category Filter
            categoryFilterView

            // Tools Grid
            ScrollView {
                toolsGridView
            }

            // Footer with Flow Status
            footerView
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.0, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showToolChain) {
            ToolChainView(toolChain: tools.toolChain)
        }
        .sheet(isPresented: $showPresets) {
            PresetsView(presetManager: tools.presetManager)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ECHOELTOOLS")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)

                Text("16 Creative Intelligence Tools")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Ultra Flow Badge
            if tools.toolState.ultraFlowEnabled {
                ultraFlowBadge
            }

            // Tool Chain Button
            Button(action: { showToolChain = true }) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(tools.isToolChainActive ? .cyan : .gray)
            }

            // Presets Button
            Button(action: { showPresets = true }) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }

    private var ultraFlowBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.cyan)
                .frame(width: 6, height: 6)
                .shadow(color: .cyan, radius: 4)

            Text("ULTRA FLOW")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.purple, .cyan, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: .cyan.opacity(0.5), radius: 8)
    }

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    color: .white
                ) {
                    selectedCategory = nil
                }

                ForEach(EchoelTools.ToolCategory.allCases.filter { $0 != .system }, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        color: colorForCategory(category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.3))
    }

    private func colorForCategory(_ category: EchoelTools.ToolCategory) -> Color {
        switch category {
        case .system: return .gray
        case .composition: return .cyan
        case .spectral: return .purple
        case .bioReactive: return .pink
        case .spatial: return .blue
        case .temporal: return .orange
        case .sequencing: return .green
        case .character: return .yellow
        }
    }

    private var toolsGridView: some View {
        let filteredTools = EchoelTools.Tool.allCases.filter { tool in
            tool != .none && (selectedCategory == nil || tool.category == selectedCategory)
        }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(filteredTools) { tool in
                ToolCardView(
                    tool: tool,
                    isActive: tools.activeTools.contains(tool),
                    isInChain: tools.toolChain.chain.contains(tool)
                ) {
                    tools.toggle(tool)
                } onLongPress: {
                    tools.toolChain.add(tool)
                }
            }
        }
        .padding()
    }

    private var footerView: some View {
        HStack {
            // Flow Multiplier
            VStack(alignment: .leading, spacing: 2) {
                Text("FLOW")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text(String(format: "%.1fx", tools.flowMultiplier))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            Spacer()

            // Active Tools Count
            VStack(spacing: 2) {
                Text("ACTIVE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(tools.activeTools.count)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.pink)
            }

            Spacer()

            // Creativity Boost
            VStack(alignment: .trailing, spacing: 2) {
                Text("CREATIVITY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text(String(format: "%.0f%%", tools.creativityBoost * 100))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .purple.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2),
                    alignment: .top
                )
        )
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

struct ToolCardView: View {
    let tool: EchoelTools.Tool
    let isActive: Bool
    let isInChain: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isActive ? tool.color.opacity(0.3) : Color.white.opacity(0.05))
                        .frame(width: 50, height: 50)

                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isActive ? tool.color : .gray)

                    // Chain indicator
                    if isInChain {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "link")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.black)
                            )
                            .offset(x: 18, y: -18)
                    }
                }

                // Name
                Text(tool.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .white : .gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Category tag
                Text(tool.category.rawValue)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(tool.color.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(tool.color.opacity(0.15))
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? tool.color.opacity(0.1) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ? tool.color : Color.white.opacity(0.1),
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .shadow(color: isActive ? tool.color.opacity(0.3) : .clear, radius: 8)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToolChainView: View {
    @ObservedObject var toolChain: ToolChain
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if toolChain.chain.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tools in chain")
                            .foregroundColor(.gray)
                        Text("Long-press tools to add them")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(toolChain.chain.enumerated()), id: \.element) { index, tool in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)

                                Image(systemName: tool.icon)
                                    .foregroundColor(tool.color)

                                Text(tool.rawValue)
                                    .font(.system(.body, design: .monospaced))

                                Spacer()

                                Image(systemName: "arrow.down")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .opacity(index < toolChain.chain.count - 1 ? 1 : 0)
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { from, to in
                            toolChain.chain.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { indexSet in
                            toolChain.chain.remove(atOffsets: indexSet)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Tool Chain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        toolChain.clear()
                    }
                    .disabled(toolChain.chain.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PresetsView: View {
    @ObservedObject var presetManager: PresetManager
    @Environment(\.dismiss) var dismiss
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationView {
            List {
                Section("Factory Presets") {
                    ForEach(presetManager.factoryPresets) { preset in
                        PresetRow(preset: preset) {
                            EchoelTools.shared.loadPreset(preset)
                            dismiss()
                        }
                    }
                }

                Section("User Presets") {
                    if presetManager.presets.isEmpty {
                        Text("No saved presets")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(presetManager.presets) { preset in
                            PresetRow(preset: preset) {
                                EchoelTools.shared.loadPreset(preset)
                                dismiss()
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                presetManager.delete(presetManager.presets[index])
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Save Current") {
                        showingSaveAlert = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Save Preset", isPresented: $showingSaveAlert) {
                TextField("Preset Name", text: $newPresetName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if !newPresetName.isEmpty {
                        _ = EchoelTools.shared.savePreset(name: newPresetName)
                        newPresetName = ""
                    }
                }
            }
        }
    }
}

struct PresetRow: View {
    let preset: ToolPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)

                HStack {
                    Text("\(preset.activeTools.count) tools")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !preset.toolChain.isEmpty {
                        Text("• \(preset.toolChain.count) in chain")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PREVIEWS
// ═══════════════════════════════════════════════════════════════════════════════

#Preview {
    EchoelToolsView()
}
