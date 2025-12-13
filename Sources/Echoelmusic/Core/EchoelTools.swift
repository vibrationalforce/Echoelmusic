import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELTOOLS - ECHOEL CREATIVE INTELLIGENCE SUITE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Ultra Liquid Light Flow - Kreativität auf Quantenebene"
//
// Eine Suite von intelligenten Tools, die:
// • Sich selbst heilen und optimieren
// • Von deinem Bio-Feedback lernen
// • Kreative Entscheidungen mit Quantum-Sampling treffen
// • Über alle Geräte synchronisiert sind
// • Analog und Digital nahtlos verbinden
//
// ECHOEL TOOLS:
// • EchoelSense     - Harmonic resonance intelligence
// • EchoelWeave     - Rhythm patterns from your pulse
// • EchoelSculpture - Frequency sculpting with bio-feedback
// • EchoelAudible   - Transform life data into sound
// • EchoelFold      - Quantum creative decisions
// • EchoelVisible   - Ultra liquid light visual activation
// • EchoelSpace     - Multi-dimensional spatial positioning (3D+Time+Bio)
// • EchoelBreath    - Time manipulation synced to breath
// • EchoelVox       - Scientific Voice Intelligence & Transformation
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - EchoelTools Suite

@MainActor
final class EchoelTools: ObservableObject {

    // MARK: - Singleton

    static let shared = EchoelTools()

    // MARK: - Published Tools

    @Published var activeTool: Tool = .none
    @Published var toolState: ToolState = ToolState()
    @Published var flowMultiplier: Float = 1.0

    // MARK: - Echoel Tool References

    let echoelSense = EchoelSense()         // Harmonic resonance intelligence
    let echoelWeave = EchoelWeave()         // Rhythm patterns from pulse
    let echoelSculpture = EchoelSculpture() // Frequency sculpting
    let echoelAudible = EchoelAudible()     // Life data to sound
    let echoelFold = EchoelFold()           // Quantum creative decisions
    let echoelVisible = EchoelVisible()     // Ultra liquid light visual
    let echoelSpace = EchoelSpace()         // Multi-dimensional spatial
    let echoelBreath = EchoelBreath()       // Time manipulation
    let echoelVox = EchoelVox()             // Scientific voice intelligence

    // MARK: - System References

    private let universalCore = EchoelUniversalCore.shared
    private let selfHealing = SelfHealingEngine.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupToolConnections()
        activateUltraFlow()
    }

    private func setupToolConnections() {
        // Connect all tools to the universal core
        universalCore.$systemState
            .sink { [weak self] state in
                self?.updateToolsWithState(state)
            }
            .store(in: &cancellables)

        // Connect to self-healing
        selfHealing.$flowState
            .sink { [weak self] flowState in
                self?.adjustToolsForFlowState(flowState)
            }
            .store(in: &cancellables)
    }

    private func activateUltraFlow() {
        // Enable ultra liquid light flow mode
        flowMultiplier = 1.5
        toolState.ultraFlowEnabled = true
    }

    // MARK: - Tool Updates

    private func updateToolsWithState(_ state: EchoelUniversalCore.SystemState) {
        let coherence = state.coherence
        let energy = state.energy
        let creativity = state.creativity

        // Scale all Echoel tools based on bio-state
        echoelSense.setCoherence(coherence)
        echoelWeave.setEnergy(energy)
        echoelFold.setCreativity(creativity)
        echoelVisible.setFlowState(coherence: coherence, energy: energy)
        echoelSpace.updateFromBio(coherence: coherence, energy: energy, creativity: creativity)
    }

    private func adjustToolsForFlowState(_ flowState: FlowState) {
        switch flowState {
        case .ultraFlow:
            flowMultiplier = 2.0
            toolState.ultraFlowEnabled = true
            toolState.creativityBoost = 1.5

        case .flow:
            flowMultiplier = 1.5
            toolState.ultraFlowEnabled = true
            toolState.creativityBoost = 1.2

        case .neutral:
            flowMultiplier = 1.0
            toolState.ultraFlowEnabled = false
            toolState.creativityBoost = 1.0

        case .stressed:
            flowMultiplier = 0.8
            toolState.ultraFlowEnabled = false
            toolState.creativityBoost = 0.8

        case .recovery, .emergency:
            flowMultiplier = 0.5
            toolState.ultraFlowEnabled = false
            toolState.creativityBoost = 0.5
        }
    }

    // MARK: - Tool Activation

    func activate(_ tool: Tool) {
        activeTool = tool
        toolState.lastActivated = Date()
    }

    func deactivate() {
        activeTool = .none
    }
}

// MARK: - Tool Types

extension EchoelTools {

    enum Tool: String, CaseIterable, Identifiable {
        case none = "None"
        case echoelSense = "EchoelSense"
        case echoelWeave = "EchoelWeave"
        case echoelSculpture = "EchoelSculpture"
        case echoelAudible = "EchoelAudible"
        case echoelFold = "EchoelFold"
        case echoelVisible = "EchoelVisible"
        case echoelSpace = "EchoelSpace"
        case echoelBreath = "EchoelBreath"
        case echoelVox = "EchoelVox"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .none: return "circle.slash"
            case .echoelSense: return "music.quarternote.3"
            case .echoelWeave: return "heart.circle.fill"
            case .echoelSculpture: return "waveform.path.badge.plus"
            case .echoelAudible: return "waveform.and.person.filled"
            case .echoelFold: return "infinity"
            case .echoelVisible: return "eye.fill"
            case .echoelSpace: return "cube.transparent.fill"
            case .echoelBreath: return "lungs.fill"
            case .echoelVox: return "waveform.badge.mic"
            }
        }

        var description: String {
            switch self {
            case .none: return "No tool active"
            case .echoelSense: return "Harmonic resonance intelligence - suggests chords aligned with your coherence"
            case .echoelWeave: return "Weaves rhythm patterns synchronized to your heartbeat"
            case .echoelSculpture: return "Sculpt the frequency spectrum with bio-feedback"
            case .echoelAudible: return "Transform life data into audible frequencies (octave transposition)"
            case .echoelFold: return "Quantum-field sampling for infinite creative decisions"
            case .echoelVisible: return "Ultra Liquid Light visual activation - see your creativity flow"
            case .echoelSpace: return "Multi-dimensional spatial positioning (3D + Time + Bio dimensions)"
            case .echoelBreath: return "Time manipulation synchronized to your breath"
            case .echoelVox: return "Scientific voice analysis - MFCC, formants, VTL, speech-to-singing"
            }
        }
    }

    struct ToolState {
        var ultraFlowEnabled: Bool = false
        var creativityBoost: Float = 1.0
        var lastActivated: Date = Date()
        var sessionDuration: TimeInterval = 0
    }
}

// MARK: - EchoelSense (Harmonic Resonance Intelligence)

class EchoelSense: ObservableObject {
    @Published var suggestedChord: Chord?
    @Published var suggestedScale: Scale?
    @Published var harmonicTension: Float = 0.5

    private var coherenceLevel: Float = 0.5

    func setCoherence(_ coherence: Float) {
        coherenceLevel = coherence

        // Higher coherence = more consonant suggestions
        harmonicTension = 1.0 - coherence

        suggestHarmony()
    }

    func suggestHarmony() {
        // Quantum-influenced harmony suggestion
        let quantumField = EchoelUniversalCore.shared.quantumField
        let choice = quantumField.sampleCreativeChoice(options: availableChords.count)

        // Weight by coherence (high coherence = simpler chords)
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
    }

    func suggestScale() {
        if coherenceLevel > 0.6 {
            suggestedScale = .major
        } else if coherenceLevel > 0.3 {
            suggestedScale = .dorian
        } else {
            suggestedScale = .phrygian
        }
    }

    struct Chord {
        var name: String
        var notes: [Int]  // MIDI notes
        var complexity: Float  // 0-1
    }

    enum Scale: String {
        case major = "Major"
        case minor = "Minor"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case lydian = "Lydian"
        case mixolydian = "Mixolydian"
        case locrian = "Locrian"
    }

    private var availableChords: [Chord] = [
        Chord(name: "C Major", notes: [60, 64, 67], complexity: 0.1),
        Chord(name: "A Minor", notes: [57, 60, 64], complexity: 0.1),
        Chord(name: "F Major", notes: [53, 57, 60], complexity: 0.2),
        Chord(name: "G Major", notes: [55, 59, 62], complexity: 0.2),
        Chord(name: "Dm7", notes: [50, 53, 57, 60], complexity: 0.4),
        Chord(name: "Cmaj7", notes: [48, 52, 55, 59], complexity: 0.5),
        Chord(name: "Am9", notes: [45, 48, 52, 55, 59], complexity: 0.7),
        Chord(name: "Fmaj9#11", notes: [41, 45, 48, 52, 54, 57], complexity: 0.9)
    ]
}

// MARK: - EchoelWeave (Rhythm from Heartbeat)

class EchoelWeave: ObservableObject {
    @Published var suggestedPattern: RhythmPattern?
    @Published var syncedToHeartbeat: Bool = true
    @Published var patternDensity: Float = 0.5

    private var energyLevel: Float = 0.5

    func setEnergy(_ energy: Float) {
        energyLevel = energy
        patternDensity = energy

        suggestPattern()
    }

    func suggestPattern() {
        // Higher energy = denser patterns
        let patterns = availablePatterns.filter { $0.density <= energyLevel + 0.2 }

        let quantumField = EchoelUniversalCore.shared.quantumField
        let choice = quantumField.sampleCreativeChoice(options: patterns.count)

        if choice < patterns.count {
            suggestedPattern = patterns[choice]
        }
    }

    struct RhythmPattern {
        var name: String
        var steps: [Bool]  // 16 steps
        var density: Float  // 0-1
    }

    private var availablePatterns: [RhythmPattern] = [
        RhythmPattern(name: "Four on Floor", steps: [true,false,false,false,true,false,false,false,true,false,false,false,true,false,false,false], density: 0.25),
        RhythmPattern(name: "Breakbeat", steps: [true,false,false,false,false,false,true,false,false,false,true,false,false,false,false,false], density: 0.19),
        RhythmPattern(name: "House", steps: [true,false,true,false,true,false,true,false,true,false,true,false,true,false,true,false], density: 0.5),
        RhythmPattern(name: "Drum & Bass", steps: [true,false,false,true,false,false,true,false,false,true,false,false,true,false,true,false], density: 0.44),
        RhythmPattern(name: "Glitch", steps: [true,true,false,true,false,true,true,false,true,false,true,false,true,true,false,true], density: 0.69)
    ]
}

// MARK: - EchoelSculpture (Frequency Sculpting)

class EchoelSculpture: ObservableObject {
    @Published var frequencyMask: [Float] = Array(repeating: 1.0, count: 64)
    @Published var coherenceInfluence: Float = 0.5

    func sculptWithCoherence(_ coherence: Float) {
        coherenceInfluence = coherence

        // High coherence = boost harmonics, reduce noise
        for i in 0..<frequencyMask.count {
            let isHarmonic = i % 4 == 0  // Simplified harmonic detection

            if coherence > 0.6 {
                frequencyMask[i] = isHarmonic ? 1.2 : 0.7
            } else {
                frequencyMask[i] = 1.0
            }
        }
    }

    func applyMask(to spectrum: [Float]) -> [Float] {
        guard spectrum.count == frequencyMask.count else { return spectrum }
        return zip(spectrum, frequencyMask).map { $0 * $1 }
    }
}

// MARK: - EchoelAudible (Life Data to Sound)

class EchoelAudible: ObservableObject {
    @Published var heartbeatFrequency: Float = 64  // Hz (after transposition)
    @Published var breathFrequency: Float = 51     // Hz (after transposition)
    @Published var hrvModulation: Float = 410      // Hz (after transposition)

    @Published var isHeartbeatAudible: Bool = true
    @Published var isBreathAudible: Bool = true
    @Published var isHRVAudible: Bool = false

    func updateFromBio(heartRate: Float, breathRate: Float, hrv: Float) {
        // Use octave transposition from UnifiedVisualSoundEngine
        heartbeatFrequency = UnifiedVisualSoundEngine.OctaveTransposition.heartRateToAudio(bpm: heartRate)
        breathFrequency = UnifiedVisualSoundEngine.OctaveTransposition.breathToAudio(breathsPerMinute: breathRate)
        hrvModulation = UnifiedVisualSoundEngine.OctaveTransposition.hrvToAudio(hrvFrequency: hrv / 1000)  // HRV in ms to Hz
    }

    func generateHeartbeatTone() -> ToneParameters {
        return ToneParameters(
            frequency: heartbeatFrequency,
            waveform: .sine,
            amplitude: 0.3,
            attack: 0.01,
            decay: 0.1,
            sustain: 0.0,
            release: 0.2
        )
    }

    func generateBreathTone() -> ToneParameters {
        return ToneParameters(
            frequency: breathFrequency,
            waveform: .triangle,
            amplitude: 0.2,
            attack: 0.5,
            decay: 0.0,
            sustain: 1.0,
            release: 0.5
        )
    }

    struct ToneParameters {
        var frequency: Float
        var waveform: Waveform
        var amplitude: Float
        var attack: Float
        var decay: Float
        var sustain: Float
        var release: Float

        enum Waveform {
            case sine, triangle, square, sawtooth
        }
    }
}

// MARK: - EchoelFold (Quantum Creative Decisions)

class EchoelFold: ObservableObject {
    @Published var creativityLevel: Float = 0.5
    @Published var superpositionStrength: Float = 0.5
    @Published var lastCollapsedChoice: Int = 0

    func setCreativity(_ creativity: Float) {
        creativityLevel = creativity
    }

    func compose(options: [CompositionOption]) -> CompositionOption? {
        guard !options.isEmpty else { return nil }

        // Use quantum field for decision
        let quantumField = EchoelUniversalCore.shared.quantumField
        superpositionStrength = quantumField.superpositionStrength

        let choice = quantumField.sampleCreativeChoice(options: options.count)
        lastCollapsedChoice = choice

        return options[choice]
    }

    struct CompositionOption {
        var name: String
        var type: OptionType
        var value: Any

        enum OptionType {
            case note, chord, rhythm, effect, structure
        }
    }
}

// MARK: - EchoelVisible (Ultra Liquid Light Visual)

class EchoelVisible: ObservableObject {
    @Published var flowIntensity: Float = 0.5
    @Published var liquidLightLevel: Float = 0.5
    @Published var ultraFlowActive: Bool = false

    func setFlowState(coherence: Float, energy: Float) {
        // Calculate flow intensity
        flowIntensity = (coherence * 0.6 + energy * 0.4)

        // Liquid light level based on coherence
        liquidLightLevel = coherence

        // Ultra flow activates at high coherence + energy
        ultraFlowActive = coherence > 0.7 && energy > 0.6
    }

    func getFlowMultiplier() -> Float {
        if ultraFlowActive {
            return 2.0
        } else if flowIntensity > 0.7 {
            return 1.5
        } else if flowIntensity > 0.4 {
            return 1.0
        }
        return 0.8
    }
}

// MARK: - EchoelSpace (Multi-Dimensional Spatial Positioning)

class EchoelSpace: ObservableObject {

    // MARK: - 3D Spatial Position
    @Published var position: SIMD3<Float> = SIMD3(0, 0, -1)
    @Published var rotation: Float = 0
    @Published var coherenceBasedWidth: Float = 1.0

    // MARK: - Extended Dimensions
    @Published var timeDimension: Float = 0        // 4th dimension: temporal position
    @Published var bioDimension: Float = 0.5       // 5th dimension: bio-coherence depth
    @Published var creativeDimension: Float = 0.5  // 6th dimension: creative energy field
    @Published var quantumDimension: Float = 0     // 7th dimension: quantum superposition state

    // MARK: - Dimension Blending
    @Published var dimensionBlend: DimensionBlend = DimensionBlend()

    struct DimensionBlend {
        var spatial3D: Float = 0.4      // Weight of XYZ
        var temporal: Float = 0.2       // Weight of time
        var bioField: Float = 0.2       // Weight of bio
        var creative: Float = 0.1       // Weight of creativity
        var quantum: Float = 0.1        // Weight of quantum
    }

    // MARK: - Spatial Modes
    enum SpatialMode: String, CaseIterable {
        case standard3D = "3D Standard"
        case binaural = "Binaural"
        case ambisonics = "Ambisonics"
        case hyperdimensional = "Hyperdimensional"
        case bioReactive = "Bio-Reactive"
    }

    @Published var spatialMode: SpatialMode = .hyperdimensional

    // MARK: - Update from Bio Data

    func updateFromBio(coherence: Float, energy: Float, creativity: Float) {
        // Bio dimension reflects coherence depth
        bioDimension = coherence

        // Creative dimension reflects energy field
        creativeDimension = creativity

        // High coherence = focused center, low = wide spread
        coherenceBasedWidth = 1.0 + (1.0 - coherence)

        // Rotation influenced by energy
        rotation += 0.01 * energy

        // Quantum dimension fluctuates with creativity
        quantumDimension = sin(Float(Date().timeIntervalSince1970) * creativity * 2) * 0.5 + 0.5
    }

    func updateFromCoherence(_ coherence: Float) {
        coherenceBasedWidth = 1.0 + (1.0 - coherence)
        rotation += 0.01 * (1.0 - coherence)
        bioDimension = coherence
    }

    // MARK: - Multi-Dimensional Position Calculation

    func positionForFrequency(_ frequency: Float) -> SIMD3<Float> {
        let normalizedFreq = log2(frequency / 20) / 10  // 0-1

        let angle = normalizedFreq * Float.pi
        var x = sin(angle) * coherenceBasedWidth
        var z = -cos(angle)

        // Apply dimension modulations
        switch spatialMode {
        case .hyperdimensional:
            // Fold higher dimensions into 3D
            x += sin(timeDimension * .pi * 2) * bioDimension * 0.3
            z += cos(creativeDimension * .pi) * quantumDimension * 0.3

        case .bioReactive:
            // Bio data directly influences position
            x *= (1.0 + bioDimension * 0.5)
            z *= (1.0 + creativeDimension * 0.5)

        case .ambisonics:
            // Full sphere positioning
            let elevation = (bioDimension - 0.5) * Float.pi
            x *= cos(elevation)
            z *= cos(elevation)

        default:
            break
        }

        return SIMD3(x, bioDimension - 0.5, z)
    }

    // MARK: - Hyperdimensional Vector

    /// Returns a 7-dimensional position vector
    func hyperPosition() -> [Float] {
        return [
            position.x,
            position.y,
            position.z,
            timeDimension,
            bioDimension,
            creativeDimension,
            quantumDimension
        ]
    }

    /// Distance in hyperdimensional space
    func hyperDistance(to other: [Float]) -> Float {
        let selfPos = hyperPosition()
        guard selfPos.count == other.count else { return 0 }

        var sumSquares: Float = 0
        for (i, dim) in dimensionBlend.weights.enumerated() where i < selfPos.count {
            let diff = selfPos[i] - other[i]
            sumSquares += diff * diff * dim
        }
        return sqrt(sumSquares)
    }

    // MARK: - Time Dimension Update

    func updateTimeDimension(bpm: Float, beatPosition: Float) {
        // Sync time dimension to music
        timeDimension = beatPosition
    }
}

extension EchoelSpace.DimensionBlend {
    var weights: [Float] {
        return [spatial3D, spatial3D, spatial3D, temporal, bioField, creative, quantum]
    }
}

// MARK: - EchoelBreath (Time Synced to Breath)

class EchoelBreath: ObservableObject {
    @Published var stretchFactor: Float = 1.0
    @Published var breathSynced: Bool = true
    @Published var currentPhase: Float = 0

    func updateFromBreath(phase: Float) {
        currentPhase = phase

        if breathSynced {
            // Speed up on inhale, slow down on exhale
            if phase < 0.5 {
                // Inhale - accelerate
                stretchFactor = 1.0 + (0.5 - phase) * 0.4  // 1.0 to 1.2
            } else {
                // Exhale - decelerate
                stretchFactor = 1.0 - (phase - 0.5) * 0.4  // 1.0 to 0.8
            }
        }
    }
}

// MARK: - EchoelVox (Scientific Voice Intelligence & Transformation)
// ═══════════════════════════════════════════════════════════════════════════════
// Beyond MicDrop - Realistic & Scientific Voice Analysis
//
// Scientific foundations:
// • MFCC (Mel-Frequency Cepstral Coefficients) - Spectral envelope encoding
// • Formant Tracking (F1-F5) - Vocal tract resonances
// • VTL (Vocal Tract Length) Estimation - Speaker characteristics
// • Source-Filter Model - Glottal excitation + Vocal tract filter
// • LF (Liljencrants-Fant) Model - Glottal pulse modeling
// • Prosody Analysis - Intonation, stress, rhythm for speech-to-singing
//
// References:
// • "YIN" - de Cheveigné & Kawahara (2002) - Pitch detection
// • "MFCC" - Davis & Mermelstein (1980) - Spectral features
// • "LF Model" - Fant et al. (1985) - Glottal source
// • "WORLD" - Morise et al. (2016) - Vocoder system
// ═══════════════════════════════════════════════════════════════════════════════

class EchoelVox: ObservableObject {

    // MARK: - Published Analysis State

    @Published var fundamentalFrequency: Float = 0          // F0 in Hz
    @Published var voicedProbability: Float = 0             // 0-1 voiced/unvoiced
    @Published var formants: FormantSet = FormantSet()      // F1-F5
    @Published var mfcc: [Float] = []                       // 13 MFCC coefficients
    @Published var vocalTractLength: Float = 17.0           // VTL in cm (avg adult)
    @Published var glottalParameters: GlottalLF = GlottalLF()

    // MARK: - Voice Transformation State

    @Published var transformMode: VoiceTransformMode = .natural
    @Published var targetVoiceModel: VoiceModel?
    @Published var morphAmount: Float = 0                   // 0-1 transformation intensity
    @Published var speechToSingingEnabled: Bool = false

    // MARK: - Bio-Voice Fusion

    @Published var bioInfluence: BioVoiceInfluence = BioVoiceInfluence()

    // MARK: - Processing Parameters

    let fftSize: Int = 2048
    let hopSize: Int = 512
    let sampleRate: Float = 48000
    let numMFCC: Int = 13
    let numMelBands: Int = 40

    // MARK: - Pre-allocated Buffers

    private var windowBuffer: [Float] = []
    private var fftRealBuffer: [Float] = []
    private var fftImagBuffer: [Float] = []
    private var magnitudeSpectrum: [Float] = []
    private var melFilterBank: [[Float]] = []
    private var dctMatrix: [[Float]] = []

    // MARK: - Initialization

    init() {
        setupDSP()
        print("=== EchoelVox Initialized ===")
        print("Scientific Voice Intelligence Active")
        print("MFCC + Formants + VTL + Source-Filter Model")
    }

    private func setupDSP() {
        // Initialize Hann window
        windowBuffer = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            windowBuffer[i] = 0.5 * (1 - cos(2 * .pi * Float(i) / Float(fftSize - 1)))
        }

        // Pre-allocate FFT buffers
        fftRealBuffer = [Float](repeating: 0, count: fftSize)
        fftImagBuffer = [Float](repeating: 0, count: fftSize)
        magnitudeSpectrum = [Float](repeating: 0, count: fftSize / 2)

        // Build Mel filter bank
        buildMelFilterBank()

        // Build DCT matrix for MFCC
        buildDCTMatrix()
    }

    // MARK: - Core Analysis Pipeline

    /// Comprehensive voice analysis from audio buffer
    func analyze(_ samples: UnsafePointer<Float>, count: Int) {
        guard count >= fftSize else { return }

        // 1. Fundamental Frequency (F0) using YIN
        fundamentalFrequency = detectF0(samples, count: count)

        // 2. Voiced/Unvoiced Detection
        voicedProbability = detectVoicing(samples, count: count)

        // 3. Spectral Analysis
        computeSpectrum(samples, count: count)

        // 4. Formant Tracking (F1-F5)
        formants = trackFormants()

        // 5. MFCC Extraction
        mfcc = extractMFCC()

        // 6. Vocal Tract Length Estimation
        vocalTractLength = estimateVTL()

        // 7. Glottal Source Parameters (LF Model)
        glottalParameters = analyzeGlottalSource(samples, count: count)

        // 8. Apply bio-influence
        applyBioInfluence()
    }

    // MARK: - F0 Detection (YIN Algorithm)

    private func detectF0(_ data: UnsafePointer<Float>, count: Int) -> Float {
        let threshold: Float = 0.1
        let minFreq: Float = 60
        let maxFreq: Float = 600  // Typical voice range

        let minLag = Int(sampleRate / maxFreq)
        let maxLag = min(Int(sampleRate / minFreq), count / 2)

        guard maxLag > minLag else { return 0 }

        // Difference function
        var diff = [Float](repeating: 0, count: maxLag)
        for tau in 1..<maxLag {
            var sum: Float = 0
            let compareLength = min(count - tau, fftSize)
            for j in 0..<compareLength {
                let delta = data[j] - data[j + tau]
                sum += delta * delta
            }
            diff[tau] = sum
        }

        // Cumulative Mean Normalized Difference Function (CMNDF)
        var cmndf = [Float](repeating: 1, count: maxLag)
        var runningSum: Float = 0
        for tau in 1..<maxLag {
            runningSum += diff[tau]
            if runningSum > 0 {
                cmndf[tau] = diff[tau] * Float(tau) / runningSum
            }
        }

        // Find first minimum below threshold
        for tau in minLag..<maxLag {
            if cmndf[tau] < threshold {
                // Parabolic interpolation for sub-sample accuracy
                let refinedTau = parabolicInterpolation(cmndf, tau)
                return sampleRate / refinedTau
            }
        }

        return 0
    }

    private func parabolicInterpolation(_ values: [Float], _ index: Int) -> Float {
        guard index > 0 && index < values.count - 1 else {
            return Float(index)
        }

        let s0 = values[index - 1]
        let s1 = values[index]
        let s2 = values[index + 1]

        let denominator = 2.0 * (2.0 * s1 - s2 - s0)
        guard abs(denominator) > 1e-10 else { return Float(index) }

        let adjustment = (s2 - s0) / denominator
        return Float(index) + adjustment
    }

    // MARK: - Voicing Detection

    private func detectVoicing(_ data: UnsafePointer<Float>, count: Int) -> Float {
        // Combine multiple features for robust voicing detection

        // 1. Energy
        var energy: Float = 0
        for i in 0..<min(count, fftSize) {
            energy += data[i] * data[i]
        }
        energy = sqrt(energy / Float(min(count, fftSize)))
        let energyScore = min(1, energy * 10)

        // 2. Zero Crossing Rate (lower = more voiced)
        var zeroCrossings = 0
        for i in 1..<min(count, fftSize) {
            if (data[i-1] >= 0) != (data[i] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcrNormalized = Float(zeroCrossings) / Float(min(count, fftSize))
        let zcrScore = max(0, 1 - zcrNormalized * 5)

        // 3. Autocorrelation peak strength
        let autoScore = fundamentalFrequency > 60 ? 1.0 : 0.0

        // Combine scores
        return Float((energyScore * 0.3 + zcrScore * 0.3 + autoScore * 0.4))
    }

    // MARK: - Spectral Analysis

    private func computeSpectrum(_ data: UnsafePointer<Float>, count: Int) {
        // Apply window
        for i in 0..<min(count, fftSize) {
            fftRealBuffer[i] = data[i] * windowBuffer[i]
        }

        // Zero-pad if necessary
        if count < fftSize {
            for i in count..<fftSize {
                fftRealBuffer[i] = 0
            }
        }

        // Simple DFT for magnitude spectrum (in production use vDSP_fft)
        for k in 0..<fftSize/2 {
            var real: Float = 0
            var imag: Float = 0
            for n in 0..<fftSize {
                let angle = -2 * Float.pi * Float(k * n) / Float(fftSize)
                real += fftRealBuffer[n] * cos(angle)
                imag += fftRealBuffer[n] * sin(angle)
            }
            magnitudeSpectrum[k] = sqrt(real * real + imag * imag)
        }
    }

    // MARK: - Formant Tracking

    private func trackFormants() -> FormantSet {
        // LPC-based formant estimation
        // Find peaks in smoothed spectrum

        var formants = FormantSet()
        var peaks: [(freq: Float, amp: Float)] = []

        // Smooth spectrum and find peaks
        let smoothed = smoothSpectrum(magnitudeSpectrum, windowSize: 5)

        for i in 2..<(smoothed.count - 2) {
            if smoothed[i] > smoothed[i-1] && smoothed[i] > smoothed[i+1] &&
               smoothed[i] > smoothed[i-2] && smoothed[i] > smoothed[i+2] {
                let freq = Float(i) * sampleRate / Float(fftSize)
                if freq > 100 && freq < 5000 {
                    peaks.append((freq: freq, amp: smoothed[i]))
                }
            }
        }

        // Sort by amplitude and extract top 5 as formants
        let sortedPeaks = peaks.sorted { $0.amp > $1.amp }
        let formantPeaks = Array(sortedPeaks.prefix(5)).sorted { $0.freq < $1.freq }

        if formantPeaks.count > 0 {
            formants.f1 = FormantData(frequency: formantPeaks[0].freq, bandwidth: 80, amplitude: formantPeaks[0].amp)
        }
        if formantPeaks.count > 1 {
            formants.f2 = FormantData(frequency: formantPeaks[1].freq, bandwidth: 100, amplitude: formantPeaks[1].amp)
        }
        if formantPeaks.count > 2 {
            formants.f3 = FormantData(frequency: formantPeaks[2].freq, bandwidth: 120, amplitude: formantPeaks[2].amp)
        }
        if formantPeaks.count > 3 {
            formants.f4 = FormantData(frequency: formantPeaks[3].freq, bandwidth: 140, amplitude: formantPeaks[3].amp)
        }
        if formantPeaks.count > 4 {
            formants.f5 = FormantData(frequency: formantPeaks[4].freq, bandwidth: 160, amplitude: formantPeaks[4].amp)
        }

        return formants
    }

    private func smoothSpectrum(_ spectrum: [Float], windowSize: Int) -> [Float] {
        var smoothed = spectrum
        for i in windowSize..<(spectrum.count - windowSize) {
            var sum: Float = 0
            for j in -windowSize...windowSize {
                sum += spectrum[i + j]
            }
            smoothed[i] = sum / Float(windowSize * 2 + 1)
        }
        return smoothed
    }

    // MARK: - MFCC Extraction

    private func extractMFCC() -> [Float] {
        // Apply Mel filter bank
        var melEnergies = [Float](repeating: 0, count: numMelBands)
        for i in 0..<numMelBands {
            for j in 0..<magnitudeSpectrum.count {
                melEnergies[i] += magnitudeSpectrum[j] * melFilterBank[i][j]
            }
            // Log compression
            melEnergies[i] = log(max(1e-10, melEnergies[i]))
        }

        // Apply DCT to get MFCCs
        var mfccCoeffs = [Float](repeating: 0, count: numMFCC)
        for i in 0..<numMFCC {
            for j in 0..<numMelBands {
                mfccCoeffs[i] += melEnergies[j] * dctMatrix[i][j]
            }
        }

        return mfccCoeffs
    }

    private func buildMelFilterBank() {
        melFilterBank = [[Float]](repeating: [Float](repeating: 0, count: fftSize/2), count: numMelBands)

        // Mel frequency range
        let minMel = hzToMel(0)
        let maxMel = hzToMel(sampleRate / 2)
        let melStep = (maxMel - minMel) / Float(numMelBands + 1)

        var melPoints = [Float]()
        for i in 0...(numMelBands + 1) {
            melPoints.append(melToHz(minMel + Float(i) * melStep))
        }

        // Build triangular filters
        for i in 0..<numMelBands {
            let startFreq = melPoints[i]
            let centerFreq = melPoints[i + 1]
            let endFreq = melPoints[i + 2]

            for k in 0..<(fftSize/2) {
                let freq = Float(k) * sampleRate / Float(fftSize)

                if freq >= startFreq && freq <= centerFreq {
                    melFilterBank[i][k] = (freq - startFreq) / (centerFreq - startFreq)
                } else if freq > centerFreq && freq <= endFreq {
                    melFilterBank[i][k] = (endFreq - freq) / (endFreq - centerFreq)
                }
            }
        }
    }

    private func buildDCTMatrix() {
        dctMatrix = [[Float]](repeating: [Float](repeating: 0, count: numMelBands), count: numMFCC)

        for i in 0..<numMFCC {
            for j in 0..<numMelBands {
                dctMatrix[i][j] = cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(numMelBands))
            }
        }
    }

    private func hzToMel(_ hz: Float) -> Float {
        return 2595 * log10(1 + hz / 700)
    }

    private func melToHz(_ mel: Float) -> Float {
        return 700 * (pow(10, mel / 2595) - 1)
    }

    // MARK: - Vocal Tract Length Estimation

    private func estimateVTL() -> Float {
        // VTL estimation from formants using quarter-wavelength resonator model
        // F_n = (2n - 1) * c / (4 * VTL) where c = speed of sound (~35000 cm/s)

        let speedOfSound: Float = 35000  // cm/s

        // Use F1 and F3 for more robust estimation
        guard formants.f1.frequency > 100, formants.f3.frequency > 1000 else {
            return 17.0  // Default adult VTL
        }

        // Estimate from multiple formants and average
        let vtlFromF1 = speedOfSound / (4 * formants.f1.frequency)  // n=1
        let vtlFromF3 = (5 * speedOfSound) / (4 * formants.f3.frequency)  // n=3

        // Average with weighting
        return (vtlFromF1 + vtlFromF3) / 2
    }

    // MARK: - Glottal Source Analysis (LF Model)

    private func analyzeGlottalSource(_ data: UnsafePointer<Float>, count: Int) -> GlottalLF {
        // Estimate Liljencrants-Fant glottal pulse parameters

        var lf = GlottalLF()

        // T0 (fundamental period) from F0
        if fundamentalFrequency > 0 {
            lf.t0 = 1.0 / fundamentalFrequency

            // Estimate other parameters from spectrum characteristics
            // Higher spectral tilt = breathier voice (larger Tl, smaller Tp)

            let spectralTilt = estimateSpectralTilt()

            // Te (excitation time) typically 0.3-0.5 * T0
            lf.te = lf.t0 * (0.35 + spectralTilt * 0.15)

            // Tp (peak time) typically 0.5-0.7 * Te
            lf.tp = lf.te * (0.55 + spectralTilt * 0.15)

            // Ta (return phase) related to voice quality
            lf.ta = lf.t0 * 0.03  // Typically small

            // Estimate open quotient and speed quotient
            lf.oq = lf.te / lf.t0  // Open quotient
            lf.sq = lf.tp / (lf.te - lf.tp)  // Speed quotient
        }

        return lf
    }

    private func estimateSpectralTilt() -> Float {
        // Estimate spectral tilt from harmonics (H1-H2 measure)
        // H1-H2 correlates with OQ and breathiness

        guard fundamentalFrequency > 0 else { return 0.5 }

        let h1Bin = Int(fundamentalFrequency / (sampleRate / Float(fftSize)))
        let h2Bin = h1Bin * 2

        guard h1Bin < magnitudeSpectrum.count && h2Bin < magnitudeSpectrum.count else { return 0.5 }

        let h1Amp = magnitudeSpectrum[h1Bin]
        let h2Amp = magnitudeSpectrum[h2Bin]

        // Normalize to 0-1 range
        let h1h2 = 20 * log10(max(1e-10, h1Amp / max(1e-10, h2Amp)))
        return max(0, min(1, (h1h2 + 10) / 20))  // Map -10 to +10 dB range
    }

    // MARK: - Bio-Voice Influence

    func updateBioState(coherence: Float, energy: Float, hrv: Float, breathPhase: Float) {
        bioInfluence.coherence = coherence
        bioInfluence.energy = energy
        bioInfluence.hrv = hrv
        bioInfluence.breathPhase = breathPhase
    }

    private func applyBioInfluence() {
        // Modulate analysis based on bio-state

        // High coherence = more stable formant tracking
        if bioInfluence.coherence > 0.7 {
            // Smooth formants more
            formants = smoothFormants(formants)
        }

        // Energy affects perceived loudness mapping
        // HRV affects natural vibrato detection sensitivity
    }

    private func smoothFormants(_ f: FormantSet) -> FormantSet {
        // In production, use exponential smoothing with history
        return f
    }

    // MARK: - Voice Transformation

    /// Transform voice to target model
    func transformVoice(_ samples: UnsafePointer<Float>, count: Int, output: UnsafeMutablePointer<Float>) {
        guard let target = targetVoiceModel else {
            // Copy input to output
            for i in 0..<count {
                output[i] = samples[i]
            }
            return
        }

        switch transformMode {
        case .natural:
            // No transformation
            for i in 0..<count {
                output[i] = samples[i]
            }

        case .voiceToVoice:
            // Source-filter transformation
            transformVoiceToVoice(samples, count: count, target: target, output: output)

        case .voiceToInstrument:
            // Convert voice to instrument timbre
            transformVoiceToInstrument(samples, count: count, instrument: target.instrumentType, output: output)

        case .speechToSinging:
            // Convert speech prosody to singing
            transformSpeechToSinging(samples, count: count, output: output)

        case .languageTransposition:
            // Map phonemes to target language
            transformLanguage(samples, count: count, targetLang: target.language, output: output)
        }
    }

    private func transformVoiceToVoice(_ input: UnsafePointer<Float>, count: Int, target: VoiceModel, output: UnsafeMutablePointer<Float>) {
        // Source-filter voice conversion
        // 1. Extract source excitation (inverse filter)
        // 2. Modify spectral envelope to match target
        // 3. Resynthesize with modified envelope

        // Simplified: formant shifting based on VTL ratio
        let vtlRatio = target.vocalTractLength / vocalTractLength

        // Resample to shift formants
        for i in 0..<count {
            let srcIdx = Float(i) * vtlRatio
            let idx0 = Int(srcIdx)
            let frac = srcIdx - Float(idx0)

            if idx0 >= 0 && idx0 < count - 1 {
                output[i] = input[idx0] * (1 - frac) + input[idx0 + 1] * frac
            } else if idx0 >= 0 && idx0 < count {
                output[i] = input[idx0]
            } else {
                output[i] = 0
            }
        }

        // Apply morphing amount
        if morphAmount < 1.0 {
            for i in 0..<count {
                output[i] = input[i] * (1 - morphAmount) + output[i] * morphAmount
            }
        }
    }

    private func transformVoiceToInstrument(_ input: UnsafePointer<Float>, count: Int, instrument: InstrumentType, output: UnsafeMutablePointer<Float>) {
        // Voice-to-instrument conversion
        // Use F0 for pitch, apply instrument's spectral envelope

        let instrumentEnvelope = getInstrumentEnvelope(instrument)

        // Simple spectral shaping (in production, use full vocoder)
        for i in 0..<count {
            output[i] = input[i] * instrumentEnvelope
        }
    }

    private func getInstrumentEnvelope(_ instrument: InstrumentType) -> Float {
        switch instrument {
        case .cello: return 0.8
        case .violin: return 0.7
        case .flute: return 0.6
        case .trumpet: return 1.2
        case .synthesizer: return 1.0
        case .choir: return 0.9
        }
    }

    private func transformSpeechToSinging(_ input: UnsafePointer<Float>, count: Int, output: UnsafeMutablePointer<Float>) {
        // Speech-to-singing conversion
        // 1. Quantize F0 to musical scale
        // 2. Extend vowel durations
        // 3. Add vibrato

        // Simplified: add vibrato to voiced segments
        let vibratoRate: Float = 5.5  // Hz
        let vibratoDepth: Float = 0.02  // Semitones proportion

        for i in 0..<count {
            let time = Float(i) / sampleRate
            let vibrato = sin(2 * .pi * vibratoRate * time) * vibratoDepth

            // Pitch shift would go here (in production, use PSOLA or phase vocoder)
            output[i] = input[i] * (1 + vibrato * voicedProbability)
        }
    }

    private func transformLanguage(_ input: UnsafePointer<Float>, count: Int, targetLang: String, output: UnsafeMutablePointer<Float>) {
        // Language transposition via phoneme mapping
        // (Placeholder - full implementation requires phoneme recognizer + TTS)

        for i in 0..<count {
            output[i] = input[i]
        }
    }

    // MARK: - Voice Model Training

    func trainVoiceModel(from samples: [[Float]], name: String) -> VoiceModel {
        // Analyze multiple samples to create voice model

        var avgF0: Float = 0
        var avgVTL: Float = 0
        var avgFormants = FormantSet()
        var avgMFCC = [Float](repeating: 0, count: numMFCC)

        for sampleBuffer in samples {
            sampleBuffer.withUnsafeBufferPointer { ptr in
                analyze(ptr.baseAddress!, count: sampleBuffer.count)
            }

            avgF0 += fundamentalFrequency
            avgVTL += vocalTractLength
            avgFormants.f1.frequency += formants.f1.frequency
            avgFormants.f2.frequency += formants.f2.frequency
            avgFormants.f3.frequency += formants.f3.frequency

            for i in 0..<numMFCC {
                avgMFCC[i] += mfcc[i]
            }
        }

        let n = Float(samples.count)
        avgF0 /= n
        avgVTL /= n
        avgFormants.f1.frequency /= n
        avgFormants.f2.frequency /= n
        avgFormants.f3.frequency /= n
        for i in 0..<numMFCC {
            avgMFCC[i] /= n
        }

        return VoiceModel(
            name: name,
            averageF0: avgF0,
            vocalTractLength: avgVTL,
            averageFormants: avgFormants,
            mfccTemplate: avgMFCC,
            glottalParams: glottalParameters,
            instrumentType: .choir,
            language: "en"
        )
    }

    // MARK: - Supporting Types

    struct FormantSet {
        var f1 = FormantData(frequency: 500, bandwidth: 80, amplitude: 1.0)
        var f2 = FormantData(frequency: 1500, bandwidth: 100, amplitude: 0.8)
        var f3 = FormantData(frequency: 2500, bandwidth: 120, amplitude: 0.6)
        var f4 = FormantData(frequency: 3500, bandwidth: 140, amplitude: 0.4)
        var f5 = FormantData(frequency: 4500, bandwidth: 160, amplitude: 0.3)

        /// Vowel classification from F1/F2
        var estimatedVowel: String {
            // IPA vowel space mapping
            if f1.frequency < 400 && f2.frequency > 2000 { return "i" }
            if f1.frequency < 400 && f2.frequency < 1000 { return "u" }
            if f1.frequency > 700 && f2.frequency > 1000 && f2.frequency < 1800 { return "a" }
            if f1.frequency > 400 && f1.frequency < 600 && f2.frequency > 1800 { return "e" }
            if f1.frequency > 400 && f1.frequency < 600 && f2.frequency < 1000 { return "o" }
            return "ə"  // Schwa (neutral)
        }
    }

    struct FormantData {
        var frequency: Float
        var bandwidth: Float
        var amplitude: Float
    }

    struct GlottalLF {
        var t0: Float = 0.01      // Fundamental period (1/F0)
        var te: Float = 0.004     // Excitation instant
        var tp: Float = 0.002     // Positive peak time
        var ta: Float = 0.0003    // Return phase duration
        var oq: Float = 0.4       // Open quotient (Te/T0)
        var sq: Float = 2.0       // Speed quotient (Tp/(Te-Tp))

        /// Voice quality estimation from LF parameters
        var voiceQuality: VoiceQuality {
            if oq > 0.6 { return .breathy }
            if oq < 0.35 { return .pressed }
            if sq > 2.5 { return .tense }
            return .modal
        }
    }

    enum VoiceQuality: String {
        case modal = "Modal"
        case breathy = "Breathy"
        case pressed = "Pressed"
        case tense = "Tense"
        case creaky = "Creaky"
    }

    enum VoiceTransformMode: String, CaseIterable {
        case natural = "Natural"
        case voiceToVoice = "Voice-to-Voice"
        case voiceToInstrument = "Voice-to-Instrument"
        case speechToSinging = "Speech-to-Singing"
        case languageTransposition = "Language Transposition"
    }

    enum InstrumentType: String, CaseIterable {
        case cello = "Cello"
        case violin = "Violin"
        case flute = "Flute"
        case trumpet = "Trumpet"
        case synthesizer = "Synthesizer"
        case choir = "Choir"
    }

    struct VoiceModel: Identifiable {
        let id = UUID()
        var name: String
        var averageF0: Float
        var vocalTractLength: Float
        var averageFormants: FormantSet
        var mfccTemplate: [Float]
        var glottalParams: GlottalLF
        var instrumentType: InstrumentType
        var language: String
    }

    struct BioVoiceInfluence {
        var coherence: Float = 0.5
        var energy: Float = 0.5
        var hrv: Float = 50
        var breathPhase: Float = 0

        /// Suggested vocal expression based on bio-state
        var suggestedExpression: String {
            if coherence > 0.7 && energy > 0.6 {
                return "Confident, resonant"
            } else if coherence > 0.7 && energy < 0.4 {
                return "Calm, centered"
            } else if coherence < 0.4 && energy > 0.6 {
                return "Intense, passionate"
            } else if coherence < 0.4 && energy < 0.4 {
                return "Reflective, intimate"
            }
            return "Natural, balanced"
        }
    }
}

// MARK: - EchoelTools View

struct EchoelToolsView: View {
    @ObservedObject var tools = EchoelTools.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("ECHOEL TOOLS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                if tools.toolState.ultraFlowEnabled {
                    Text("ULTRA FLOW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
                }
            }

            // Tool Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(EchoelTools.Tool.allCases.filter { $0 != .none }) { tool in
                    ToolCard(tool: tool, isActive: tools.activeTool == tool) {
                        if tools.activeTool == tool {
                            tools.deactivate()
                        } else {
                            tools.activate(tool)
                        }
                    }
                }
            }

            // Flow Multiplier
            HStack {
                Text("Flow: \(String(format: "%.1fx", tools.flowMultiplier))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                Text("Creativity: \(String(format: "%.0f%%", tools.toolState.creativityBoost * 100))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

struct ToolCard: View {
    let tool: EchoelTools.Tool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? .cyan : .white.opacity(0.7))

                Text(tool.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isActive ? .cyan : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
