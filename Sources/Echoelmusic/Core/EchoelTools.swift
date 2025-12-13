import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELTOOLS - NIARA CREATIVE INTELLIGENCE SUITE
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
// NIARA TOOLS:
// • NiaraSense    - Harmonic resonance intelligence
// • HeartWeave    - Rhythm patterns from your pulse
// • SpectraMorph  - Frequency sculpting with bio-feedback
// • VitalVoice    - Transform life data into sound
// • InfiniFold    - Quantum creative decisions
// • AuroraFlow    - Ultra liquid light activation
// • VoidSphere    - 3D spatial positioning
// • ChronoBreath  - Time manipulation synced to breath
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

    // MARK: - Niara Tool References

    let niaraSense = NiaraSense()           // Harmonic resonance intelligence
    let heartWeave = HeartWeave()           // Rhythm patterns from pulse
    let spectraMorph = SpectraMorph()       // Frequency sculpting
    let vitalVoice = VitalVoice()           // Life data to sound
    let infiniFold = InfiniFold()           // Quantum creative decisions
    let auroraFlow = AuroraFlow()           // Ultra liquid light flow
    let voidSphere = VoidSphere()           // 3D spatial positioning
    let chronoBreath = ChronoBreath()       // Time manipulation

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

        // Scale all Niara tools based on bio-state
        niaraSense.setCoherence(coherence)
        heartWeave.setEnergy(energy)
        infiniFold.setCreativity(creativity)
        auroraFlow.setFlowState(coherence: coherence, energy: energy)
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
        case niaraSense = "NiaraSense"
        case heartWeave = "HeartWeave"
        case spectraMorph = "SpectraMorph"
        case vitalVoice = "VitalVoice"
        case infiniFold = "InfiniFold"
        case auroraFlow = "AuroraFlow"
        case voidSphere = "VoidSphere"
        case chronoBreath = "ChronoBreath"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .none: return "circle.slash"
            case .niaraSense: return "music.quarternote.3"
            case .heartWeave: return "heart.circle.fill"
            case .spectraMorph: return "waveform.path.badge.plus"
            case .vitalVoice: return "waveform.and.person.filled"
            case .infiniFold: return "infinity"
            case .auroraFlow: return "sparkles"
            case .voidSphere: return "cube.transparent.fill"
            case .chronoBreath: return "lungs.fill"
            }
        }

        var description: String {
            switch self {
            case .none: return "No tool active"
            case .niaraSense: return "Harmonic resonance intelligence - suggests chords aligned with your coherence"
            case .heartWeave: return "Weaves rhythm patterns synchronized to your heartbeat"
            case .spectraMorph: return "Sculpt the frequency spectrum with bio-feedback"
            case .vitalVoice: return "Transform life data into audible frequencies (octave transposition)"
            case .infiniFold: return "Quantum-field sampling for infinite creative decisions"
            case .auroraFlow: return "Ultra Liquid Light Flow activation - peak creativity state"
            case .voidSphere: return "3D spatial audio positioning based on coherence"
            case .chronoBreath: return "Time manipulation synchronized to your breath"
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

// MARK: - NiaraSense (Harmonic Resonance Intelligence)

class NiaraSense: ObservableObject {
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

// MARK: - HeartWeave (Rhythm from Heartbeat)

class HeartWeave: ObservableObject {
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

// MARK: - SpectraMorph (Frequency Sculpting)

class SpectraMorph: ObservableObject {
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

// MARK: - VitalVoice (Life Data to Sound)

class VitalVoice: ObservableObject {
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

// MARK: - InfiniFold (Quantum Creative Decisions)

class InfiniFold: ObservableObject {
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

// MARK: - AuroraFlow (Ultra Liquid Light)

class AuroraFlow: ObservableObject {
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

// MARK: - VoidSphere (3D Spatial Positioning)

class VoidSphere: ObservableObject {
    @Published var position: SIMD3<Float> = SIMD3(0, 0, -1)
    @Published var rotation: Float = 0
    @Published var coherenceBasedWidth: Float = 1.0

    func updateFromCoherence(_ coherence: Float) {
        // High coherence = focused center
        // Low coherence = wide stereo spread
        coherenceBasedWidth = 1.0 + (1.0 - coherence)

        // Rotation based on time and coherence
        rotation += 0.01 * (1.0 - coherence)
    }

    func positionForFrequency(_ frequency: Float) -> SIMD3<Float> {
        // Map frequency to spatial position
        // Low = front/center, High = sides/back
        let normalizedFreq = log2(frequency / 20) / 10  // 0-1

        let angle = normalizedFreq * Float.pi  // 0 to π
        let x = sin(angle) * coherenceBasedWidth
        let z = -cos(angle)

        return SIMD3(x, 0, z)
    }
}

// MARK: - ChronoBreath (Time Synced to Breath)

class ChronoBreath: ObservableObject {
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

// MARK: - EchoelTools View

struct EchoelToolsView: View {
    @ObservedObject var tools = EchoelTools.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("NIARA TOOLS")
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
