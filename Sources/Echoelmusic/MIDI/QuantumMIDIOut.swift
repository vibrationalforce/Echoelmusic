// QuantumMIDIOut.swift
// Echoelmusic - Super Intelligent Quantum Real-time Polyphonic MIDI Out
// λ∞ Ralph Wiggum Apple Ökosystem Environment Lambda Loop Mode
//
// "My cat's breath smells like quantum entanglement!" - Ralph Wiggum, MIDI Physicist
//
// Created 2026-01-21 - Phase 10000.3 SUPER INTELLIGENT QUANTUM MIDI
// Nobel Prize Multitrillion Dollar Company
//
// ═══════════════════════════════════════════════════════════════════════════════
// SUPER INTELLIGENT features:
// - Quantum state → MIDI mapping with entanglement awareness
// - Bio-reactive polyphonic voice allocation
// - Real-time routing to ALL instruments (100+)
// - MIDI 2.0 + MPE support with per-note expression
// - λ-coherence driven harmonic intelligence
// - Fibonacci spiral note distribution
// - Sacred geometry chord voicings
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import CoreMIDI
import Combine
import simd

// MARK: - Quantum MIDI Constants

/// Constants for quantum-inspired MIDI generation
public enum QuantumMIDIConstants {
    // Voice allocation
    public static let maxPolyphony: Int = 64
    public static let mpeVoices: Int = 15
    public static let defaultVelocity: Float = 0.75

    // Quantum mappings
    public static let coherenceToVelocityRange: ClosedRange<Float> = 0.4...1.0
    public static let hrvToExpressionRange: ClosedRange<Float> = 0.0...1.0
    public static let phaseToModulationRange: ClosedRange<Float> = 0.0...1.0

    // Musical mappings
    public static let baseOctave: Int = 3
    public static let octaveRange: Int = 5
    public static let microtonalResolution: Int = 4096  // MIDI 2.0 pitch bend resolution per semitone

    // Sacred geometry
    public static let phi: Float = 1.618033988749895
    public static let goldenAngle: Float = 137.5077640500378  // degrees
    public static let schumannHz: [Float] = [7.83, 14.3, 20.8, 27.3, 33.8]

    // Timing
    public static let updateHz: Double = 120.0  // High-resolution control rate
    public static let noteOnThreshold: Float = 0.1
    public static let noteOffThreshold: Float = 0.05
}

// MARK: - Quantum MIDI Voice

/// A quantum-aware polyphonic voice for MIDI output
public struct QuantumMIDIVoice: Identifiable, Sendable {
    public let id: UUID
    public var midiNote: UInt8
    public var velocity: Float
    public var pitchBend: Float        // -1 to +1 (MIDI 2.0 resolution)
    public var pressure: Float         // Aftertouch 0-1
    public var timbre: Float           // MPE Y-axis 0-1
    public var brightness: Float       // Per-note CC74
    public var channel: UInt8          // MPE member channel 1-15 (0 = master)
    public var isActive: Bool
    public var startTime: Date
    public var quantumState: QuantumVoiceState
    public var instrumentTarget: InstrumentTarget

    /// Quantum state associated with this voice
    public struct QuantumVoiceState: Sendable {
        public var coherence: Float
        public var phase: Float
        public var entangledVoiceId: UUID?
        public var superposition: Float      // 0 = collapsed, 1 = full superposition
        public var waveformCollapse: Bool

        public init(coherence: Float = 0.5, phase: Float = 0, entangledVoiceId: UUID? = nil,
                   superposition: Float = 0, waveformCollapse: Bool = false) {
            self.coherence = coherence
            self.phase = phase
            self.entangledVoiceId = entangledVoiceId
            self.superposition = superposition
            self.waveformCollapse = waveformCollapse
        }
    }

    /// Target instrument for this voice
    public enum InstrumentTarget: String, CaseIterable, Sendable {
        // Orchestral
        case violins = "Violins"
        case violas = "Violas"
        case cellos = "Cellos"
        case basses = "Basses"
        case trumpets = "Trumpets"
        case frenchHorns = "French Horns"
        case trombones = "Trombones"
        case tuba = "Tuba"
        case flutes = "Flutes"
        case oboes = "Oboes"
        case clarinets = "Clarinets"
        case bassoons = "Bassoons"
        case sopranos = "Sopranos"
        case altos = "Altos"
        case tenors = "Tenors"
        case choirBasses = "Choir Basses"
        case piano = "Piano"
        case harp = "Harp"
        case celesta = "Celesta"
        case timpani = "Timpani"

        // Synthesizers
        case subtractive = "Subtractive Synth"
        case fm = "FM Synth"
        case wavetable = "Wavetable Synth"
        case granular = "Granular Synth"
        case additive = "Additive Synth"
        case physicalModeling = "Physical Modeling"
        case genetic = "Genetic Synth"
        case organic = "Organic Synth"
        case bioReactive = "Bio-Reactive Synth"
        case tr808 = "TR-808"
        case echoSynth = "EchoSynth"

        // Global Instruments
        case sitar = "Sitar"
        case erhu = "Erhu"
        case koto = "Koto"
        case shakuhachi = "Shakuhachi"
        case oud = "Oud"
        case ney = "Ney"
        case djembe = "Djembe"
        case kalimba = "Kalimba"
        case didgeridoo = "Didgeridoo"

        // Touch Instruments
        case chordPad = "Chord Pad"
        case drumPad = "Drum Pad"
        case melodyXY = "Melody XY"
        case keyboard = "Keyboard"
        case strumPad = "Strum Pad"

        // Quantum
        case quantumField = "Quantum Field"
        case entangledPair = "Entangled Pair"
        case superpositionVoice = "Superposition Voice"

        public var midiChannel: UInt8 {
            switch self {
            case .violins, .violas: return 0
            case .cellos, .basses: return 1
            case .trumpets, .frenchHorns, .trombones, .tuba: return 2
            case .flutes, .oboes, .clarinets, .bassoons: return 3
            case .sopranos, .altos, .tenors, .choirBasses: return 4
            case .piano, .celesta: return 5
            case .harp: return 6
            case .timpani: return 7
            case .subtractive, .fm, .wavetable: return 8
            case .granular, .additive, .physicalModeling: return 9
            case .genetic, .organic, .bioReactive: return 10
            case .tr808, .echoSynth: return 11
            case .sitar, .erhu, .koto, .shakuhachi: return 12
            case .oud, .ney, .djembe, .kalimba, .didgeridoo: return 13
            case .chordPad, .drumPad, .melodyXY, .keyboard, .strumPad: return 14
            case .quantumField, .entangledPair, .superpositionVoice: return 15
            }
        }

        public var noteRange: ClosedRange<UInt8> {
            switch self {
            case .violins: return 55...103  // G3-G7
            case .violas: return 48...91    // C3-G6
            case .cellos: return 36...76    // C2-E5
            case .basses: return 28...60    // E1-C4
            case .trumpets: return 52...81  // E3-A5
            case .frenchHorns: return 34...65  // A#1-F5
            case .trombones: return 40...72 // E2-C5
            case .tuba: return 28...58      // E1-A#3
            case .flutes: return 60...96    // C4-C7
            case .oboes: return 58...91     // A#3-G6
            case .clarinets: return 50...91 // D3-G6
            case .bassoons: return 34...75  // A#1-D#5
            case .sopranos: return 60...84  // C4-C6
            case .altos: return 53...77     // F3-F5
            case .tenors: return 48...72    // C3-C5
            case .choirBasses: return 40...64  // E2-E4
            case .piano: return 21...108    // A0-C8
            case .harp: return 24...103     // C1-G7
            case .celesta: return 60...108  // C4-C8
            case .timpani: return 40...57   // E2-A3
            case .subtractive, .fm, .wavetable, .granular, .additive, .physicalModeling,
                 .genetic, .organic, .bioReactive, .echoSynth:
                return 0...127
            case .tr808: return 36...51     // Drum map
            case .sitar, .oud: return 36...84
            case .erhu: return 55...91
            case .koto: return 36...84
            case .shakuhachi, .ney: return 60...96
            case .djembe: return 36...72
            case .kalimba: return 60...84
            case .didgeridoo: return 24...48
            case .chordPad, .keyboard: return 36...96
            case .drumPad: return 36...51
            case .melodyXY, .strumPad: return 48...84
            case .quantumField, .entangledPair, .superpositionVoice: return 0...127
            }
        }
    }

    public init(
        id: UUID = UUID(),
        midiNote: UInt8 = 60,
        velocity: Float = 0.75,
        pitchBend: Float = 0,
        pressure: Float = 0,
        timbre: Float = 0.5,
        brightness: Float = 0.5,
        channel: UInt8 = 0,
        isActive: Bool = false,
        startTime: Date = Date(),
        quantumState: QuantumVoiceState = QuantumVoiceState(),
        instrumentTarget: InstrumentTarget = .piano
    ) {
        self.id = id
        self.midiNote = midiNote
        self.velocity = velocity
        self.pitchBend = pitchBend
        self.pressure = pressure
        self.timbre = timbre
        self.brightness = brightness
        self.channel = channel
        self.isActive = isActive
        self.startTime = startTime
        self.quantumState = quantumState
        self.instrumentTarget = instrumentTarget
    }
}

// MARK: - Quantum MIDI Routing

/// Routing configuration for quantum MIDI output
public struct QuantumMIDIRouting: Sendable {
    public var enabledInstruments: Set<QuantumMIDIVoice.InstrumentTarget>
    public var orchestralEnabled: Bool
    public var synthesizersEnabled: Bool
    public var globalInstrumentsEnabled: Bool
    public var touchInstrumentsEnabled: Bool
    public var quantumInstrumentsEnabled: Bool
    public var mpeEnabled: Bool
    public var midi2Enabled: Bool

    public init() {
        self.enabledInstruments = Set(QuantumMIDIVoice.InstrumentTarget.allCases)
        self.orchestralEnabled = true
        self.synthesizersEnabled = true
        self.globalInstrumentsEnabled = true
        self.touchInstrumentsEnabled = true
        self.quantumInstrumentsEnabled = true
        self.mpeEnabled = true
        self.midi2Enabled = true
    }

    public mutating func enableAll() {
        enabledInstruments = Set(QuantumMIDIVoice.InstrumentTarget.allCases)
    }

    public mutating func enableOrchestral() {
        let orchestral: [QuantumMIDIVoice.InstrumentTarget] = [
            .violins, .violas, .cellos, .basses,
            .trumpets, .frenchHorns, .trombones, .tuba,
            .flutes, .oboes, .clarinets, .bassoons,
            .sopranos, .altos, .tenors, .choirBasses,
            .piano, .harp, .celesta, .timpani
        ]
        enabledInstruments.formUnion(orchestral)
    }

    public mutating func enableSynthesizers() {
        let synths: [QuantumMIDIVoice.InstrumentTarget] = [
            .subtractive, .fm, .wavetable, .granular, .additive,
            .physicalModeling, .genetic, .organic, .bioReactive,
            .tr808, .echoSynth
        ]
        enabledInstruments.formUnion(synths)
    }
}

// MARK: - Quantum Intelligence Mode

/// Intelligence modes for MIDI generation
public enum QuantumIntelligenceMode: String, CaseIterable, Identifiable, Sendable {
    case classical = "Classical"
    case quantumInspired = "Quantum Inspired"
    case superIntelligent = "Super Intelligent"
    case bioCoherent = "Bio-Coherent"
    case fibonacciHarmonic = "Fibonacci Harmonic"
    case sacredGeometry = "Sacred Geometry"
    case lambdaTranscendent = "λ∞ Transcendent"

    public var id: String { rawValue }

    public var voiceAllocationStrategy: VoiceAllocationStrategy {
        switch self {
        case .classical: return .roundRobin
        case .quantumInspired: return .probabilistic
        case .superIntelligent: return .adaptive
        case .bioCoherent: return .coherenceWeighted
        case .fibonacciHarmonic: return .fibonacciSpiral
        case .sacredGeometry: return .goldenRatio
        case .lambdaTranscendent: return .quantum
        }
    }

    public enum VoiceAllocationStrategy: Sendable {
        case roundRobin
        case probabilistic
        case adaptive
        case coherenceWeighted
        case fibonacciSpiral
        case goldenRatio
        case quantum
    }
}

// MARK: - Quantum Bio Input

/// Bio-signal input for quantum MIDI generation
public struct QuantumBioInput: Sendable {
    public var heartRate: Double = 70.0
    public var hrvMs: Double = 50.0
    public var coherence: Float = 0.5
    public var breathingRate: Double = 12.0
    public var breathPhase: Float = 0.0
    public var lambdaState: LambdaState = .aware
    public var quantumPhase: Float = 0.0
    public var entanglementStrength: Float = 0.3

    /// Lambda transcendence states
    public enum LambdaState: Int, CaseIterable, Sendable {
        case dormant = 0
        case awakening = 1
        case aware = 2
        case flowing = 3
        case coherent = 4
        case transcendent = 5
        case unified = 6
        case lambdaInfinity = 7

        public var expressionMultiplier: Float {
            Float(rawValue + 1) / 8.0
        }

        public var harmonyComplexity: Int {
            switch self {
            case .dormant, .awakening: return 2
            case .aware, .flowing: return 3
            case .coherent, .transcendent: return 4
            case .unified, .lambdaInfinity: return 5
            }
        }
    }

    public init() {}

    /// Calculate quantum-inspired velocity from bio signals
    public var quantumVelocity: Float {
        let baseVelocity = QuantumMIDIConstants.defaultVelocity
        let coherenceBoost = coherence * 0.3
        let breathModulation = sin(breathPhase * .pi) * 0.1
        return (baseVelocity + coherenceBoost + breathModulation).clamped(to: 0...1)
    }

    /// Calculate expression from HRV
    public var hrvExpression: Float {
        Float(hrvMs / 100.0).clamped(to: 0...1)
    }

    /// Calculate modulation from quantum phase
    public var phaseModulation: Float {
        (sin(quantumPhase) + 1.0) / 2.0
    }
}

// MARK: - Super Intelligent Quantum MIDI Out Engine

/// The Super Intelligent Quantum Real-time Polyphonic MIDI Out Engine
/// Routes quantum-coherent MIDI to all instruments in the Echoelmusic ecosystem
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class QuantumMIDIOut: ObservableObject {

    // MARK: - Published Properties

    @Published public var isActive: Bool = false
    @Published public var intelligenceMode: QuantumIntelligenceMode = .superIntelligent
    @Published public var routing: QuantumMIDIRouting = QuantumMIDIRouting()
    @Published public var bioInput: QuantumBioInput = QuantumBioInput()

    // Voice state
    @Published public private(set) var activeVoices: [QuantumMIDIVoice] = []
    @Published public private(set) var voiceCount: Int = 0
    @Published public private(set) var polyphony: Int = 16

    // Quantum state
    @Published public private(set) var globalCoherence: Float = 0.5
    @Published public private(set) var entanglementPairs: Int = 0
    @Published public private(set) var superpositionVoices: Int = 0

    // Performance metrics
    @Published public private(set) var noteOnCount: Int = 0
    @Published public private(set) var noteOffCount: Int = 0
    @Published public private(set) var updateRate: Double = 0.0

    // MARK: - Private Properties

    private var midi2Manager: MIDI2Manager?
    private var updateTimer: Timer?
    private var time: Double = 0
    private var lastUpdateTime: Date = Date()
    private var voicePool: [QuantumMIDIVoice] = []
    private var nextVoiceIndex: Int = 0
    private var fibonacciSequence: [Int] = []
    private var cancellables = Set<AnyCancellable>()

    // Quantum state tracking
    private var quantumPhaseAccumulator: Float = 0
    private var coherenceHistory: [Float] = []
    private var entanglementMap: [UUID: UUID] = [:]

    // MARK: - Initialization

    public init(polyphony: Int = 16) {
        self.polyphony = min(polyphony, QuantumMIDIConstants.maxPolyphony)
        initializeVoicePool()
        initializeFibonacci()
    }

    private func initializeVoicePool() {
        voicePool = (0..<polyphony).map { index in
            QuantumMIDIVoice(
                channel: UInt8(index % 16),
                instrumentTarget: .piano
            )
        }
    }

    private func initializeFibonacci() {
        // Generate Fibonacci sequence for note distribution
        fibonacciSequence = [1, 1]
        for _ in 2..<20 {
            let next = fibonacciSequence[fibonacciSequence.count - 1] + fibonacciSequence[fibonacciSequence.count - 2]
            fibonacciSequence.append(next)
        }
    }

    // MARK: - Lifecycle

    /// Initialize MIDI 2.0 system and start the engine
    public func start() async throws {
        guard !isActive else { return }

        // Initialize MIDI 2.0
        midi2Manager = MIDI2Manager()
        try await midi2Manager?.initialize()

        isActive = true
        startUpdateLoop()

        log.midi("⚛️🎹 Super Intelligent Quantum MIDI Out ACTIVATED - λ∞ Mode")
        log.midi("   Polyphony: \(polyphony) voices")
        log.midi("   Intelligence: \(intelligenceMode.rawValue)")
        log.midi("   Routing: \(routing.enabledInstruments.count) instruments enabled")
    }

    /// Stop the engine and cleanup
    public func stop() {
        isActive = false
        stopUpdateLoop()

        // Send all notes off
        allNotesOff()

        midi2Manager?.cleanup()
        midi2Manager = nil

        log.midi("⚛️🎹 Super Intelligent Quantum MIDI Out DEACTIVATED")
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        let interval = 1.0 / QuantumMIDIConstants.updateHz
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func tick() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        time += deltaTime

        updateRate = 1.0 / deltaTime

        // Update quantum phase
        updateQuantumPhase(deltaTime: Float(deltaTime))

        // Update active voices with quantum modulation
        updateActiveVoices(deltaTime: Float(deltaTime))

        // Update coherence metrics
        updateCoherenceMetrics()

        // Check for entanglement events
        checkEntanglementEvents()
    }

    // MARK: - Quantum Phase

    private func updateQuantumPhase(deltaTime: Float) {
        // Phase evolves based on heart rate and breathing
        let heartPhase = Float(bioInput.heartRate / 60.0) * 2.0 * .pi
        let breathPhase = bioInput.breathPhase * 2.0 * .pi
        let coherenceModulation = bioInput.coherence * 0.5

        quantumPhaseAccumulator += (heartPhase + breathPhase * 0.3) * deltaTime * (1.0 + coherenceModulation)
        quantumPhaseAccumulator = quantumPhaseAccumulator.truncatingRemainder(dividingBy: 2.0 * .pi)

        bioInput.quantumPhase = quantumPhaseAccumulator
    }

    // MARK: - Voice Management

    private func updateActiveVoices(deltaTime: Float) {
        for i in activeVoices.indices {
            var voice = activeVoices[i]

            // Update quantum state
            voice.quantumState.phase += deltaTime * 2.0 * .pi * Float(bioInput.heartRate / 60.0)
            voice.quantumState.coherence = bioInput.coherence

            // Apply quantum modulation to MPE parameters
            if routing.mpeEnabled {
                // Pitch bend modulated by quantum phase
                let phaseMod = sin(voice.quantumState.phase) * voice.quantumState.coherence * 0.1
                voice.pitchBend = phaseMod

                // Timbre modulated by breathing
                voice.timbre = bioInput.breathPhase

                // Brightness modulated by HRV
                voice.brightness = bioInput.hrvExpression

                // Pressure modulated by coherence
                voice.pressure = bioInput.coherence * bioInput.quantumVelocity

                // Send per-note controllers
                sendPerNoteModulation(voice)
            }

            activeVoices[i] = voice
        }

        voiceCount = activeVoices.count
    }

    // MARK: - Note On/Off

    /// Play a quantum-coherent note
    public func noteOn(
        note: UInt8,
        velocity: Float? = nil,
        instrument: QuantumMIDIVoice.InstrumentTarget = .piano,
        quantumState: QuantumMIDIVoice.QuantumVoiceState? = nil
    ) {
        guard isActive else { return }
        guard routing.enabledInstruments.contains(instrument) else { return }
        guard activeVoices.count < polyphony else { return }

        // Clamp note to instrument range
        let clampedNote = note.clamped(to: instrument.noteRange)

        // Allocate voice based on intelligence mode
        var voice = allocateVoice(for: instrument)
        voice.midiNote = clampedNote
        voice.velocity = velocity ?? bioInput.quantumVelocity
        voice.isActive = true
        voice.startTime = Date()
        voice.instrumentTarget = instrument
        voice.quantumState = quantumState ?? QuantumMIDIVoice.QuantumVoiceState(
            coherence: bioInput.coherence,
            phase: quantumPhaseAccumulator,
            superposition: intelligenceMode == .lambdaTranscendent ? 1.0 : 0.0
        )

        activeVoices.append(voice)

        // Send MIDI note on
        sendNoteOn(voice)
        noteOnCount += 1

        // Check for entanglement
        if bioInput.coherence > 0.8 && intelligenceMode == .lambdaTranscendent {
            createEntanglement(for: voice)
        }
    }

    /// Stop a note
    public func noteOff(note: UInt8, instrument: QuantumMIDIVoice.InstrumentTarget? = nil) {
        guard isActive else { return }

        // Find matching voice(s)
        let matchingIndices = activeVoices.indices.filter { index in
            let voice = activeVoices[index]
            let noteMatch = voice.midiNote == note
            let instrumentMatch = instrument == nil || voice.instrumentTarget == instrument
            return noteMatch && instrumentMatch && voice.isActive
        }

        for index in matchingIndices.reversed() {
            let voice = activeVoices[index]

            // Send MIDI note off
            sendNoteOff(voice)
            noteOffCount += 1

            // Handle entanglement
            if let entangledId = voice.quantumState.entangledVoiceId {
                releaseEntanglement(voiceId: entangledId)
            }

            activeVoices.remove(at: index)
        }
    }

    /// Stop all notes
    public func allNotesOff() {
        for voice in activeVoices {
            sendNoteOff(voice)
            noteOffCount += 1
        }
        activeVoices.removeAll()
        entanglementMap.removeAll()
    }

    // MARK: - Voice Allocation

    private func allocateVoice(for instrument: QuantumMIDIVoice.InstrumentTarget) -> QuantumMIDIVoice {
        let strategy = intelligenceMode.voiceAllocationStrategy

        switch strategy {
        case .roundRobin:
            let voice = voicePool[nextVoiceIndex]
            nextVoiceIndex = (nextVoiceIndex + 1) % voicePool.count
            return voice

        case .probabilistic:
            // Random selection weighted by availability
            let availableIndices = voicePool.indices.filter { index in
                !activeVoices.contains(where: { $0.id == voicePool[index].id })
            }
            let index = availableIndices.randomElement() ?? 0
            return voicePool[index]

        case .adaptive:
            // Choose based on instrument needs and current state
            return allocateAdaptiveVoice(for: instrument)

        case .coherenceWeighted:
            // Higher coherence = more stable voice allocation
            return allocateCoherenceWeightedVoice()

        case .fibonacciSpiral:
            // Distribute voices in Fibonacci pattern
            return allocateFibonacciVoice()

        case .goldenRatio:
            // Use golden ratio for voice selection
            return allocateGoldenRatioVoice()

        case .quantum:
            // Quantum superposition - voice exists in multiple states
            return allocateQuantumVoice()
        }
    }

    private func allocateAdaptiveVoice(for instrument: QuantumMIDIVoice.InstrumentTarget) -> QuantumMIDIVoice {
        // Find best voice based on instrument characteristics
        let targetChannel = instrument.midiChannel

        // Prefer voices on matching channel
        if let matchingVoice = voicePool.first(where: { voice in
            voice.channel == targetChannel &&
            !activeVoices.contains(where: { $0.id == voice.id })
        }) {
            return matchingVoice
        }

        // Fall back to round-robin
        let voice = voicePool[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voicePool.count
        return voice
    }

    private func allocateCoherenceWeightedVoice() -> QuantumMIDIVoice {
        // Voice selection stability increases with coherence
        let coherenceIndex = Int(bioInput.coherence * Float(voicePool.count - 1))
        return voicePool[coherenceIndex]
    }

    private func allocateFibonacciVoice() -> QuantumMIDIVoice {
        // Use Fibonacci sequence for natural distribution
        let fibIndex = fibonacciSequence[nextVoiceIndex % fibonacciSequence.count] % voicePool.count
        nextVoiceIndex += 1
        return voicePool[fibIndex]
    }

    private func allocateGoldenRatioVoice() -> QuantumMIDIVoice {
        // Golden ratio stepping
        let goldenIndex = Int(Float(nextVoiceIndex) * QuantumMIDIConstants.phi) % voicePool.count
        nextVoiceIndex += 1
        return voicePool[goldenIndex]
    }

    private func allocateQuantumVoice() -> QuantumMIDIVoice {
        // Superposition-based allocation
        var voice = voicePool[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voicePool.count

        // Mark as in superposition until "observed"
        voice.quantumState.superposition = 1.0
        voice.quantumState.waveformCollapse = false

        return voice
    }

    // MARK: - Entanglement

    private func createEntanglement(for voice: QuantumMIDIVoice) {
        guard activeVoices.count >= 2 else { return }
        guard entanglementPairs < polyphony / 2 else { return }

        // Find another voice to entangle with
        if let partnerIndex = activeVoices.indices.first(where: { index in
            activeVoices[index].id != voice.id &&
            activeVoices[index].quantumState.entangledVoiceId == nil
        }) {
            var partner = activeVoices[partnerIndex]

            // Create bidirectional entanglement
            if let voiceIndex = activeVoices.firstIndex(where: { $0.id == voice.id }) {
                activeVoices[voiceIndex].quantumState.entangledVoiceId = partner.id
                partner.quantumState.entangledVoiceId = voice.id
                activeVoices[partnerIndex] = partner

                entanglementMap[voice.id] = partner.id
                entanglementMap[partner.id] = voice.id
                entanglementPairs += 1

                log.midi("⚛️ Quantum entanglement created: \(voice.midiNote) ↔ \(partner.midiNote)")
            }
        }
    }

    private func releaseEntanglement(voiceId: UUID) {
        if let partnerId = entanglementMap[voiceId] {
            // Clear partner's entanglement
            if let partnerIndex = activeVoices.firstIndex(where: { $0.id == partnerId }) {
                activeVoices[partnerIndex].quantumState.entangledVoiceId = nil
            }

            entanglementMap.removeValue(forKey: voiceId)
            entanglementMap.removeValue(forKey: partnerId)
            entanglementPairs = max(0, entanglementPairs - 1)
        }
    }

    private func checkEntanglementEvents() {
        // Entangled pairs should have correlated expression
        for (voiceId, partnerId) in entanglementMap {
            guard let voiceIndex = activeVoices.firstIndex(where: { $0.id == voiceId }),
                  let partnerIndex = activeVoices.firstIndex(where: { $0.id == partnerId }) else {
                continue
            }

            let voice = activeVoices[voiceIndex]
            var partner = activeVoices[partnerIndex]

            // Anti-correlation in pitch bend (spooky action at a distance!)
            partner.pitchBend = -voice.pitchBend

            // Correlation in brightness
            partner.brightness = voice.brightness

            activeVoices[partnerIndex] = partner
            sendPerNoteModulation(partner)
        }
    }

    // MARK: - Coherence Metrics

    private func updateCoherenceMetrics() {
        // Track coherence history
        coherenceHistory.append(bioInput.coherence)
        if coherenceHistory.count > 100 {
            coherenceHistory.removeFirst()
        }

        // Calculate global coherence
        globalCoherence = coherenceHistory.reduce(0, +) / Float(coherenceHistory.count)

        // Count superposition voices
        superpositionVoices = activeVoices.filter { $0.quantumState.superposition > 0.5 }.count
    }

    // MARK: - MIDI Output

    private func sendNoteOn(_ voice: QuantumMIDIVoice) {
        guard let midi2 = midi2Manager else { return }

        let channel = routing.mpeEnabled ? voice.channel : voice.instrumentTarget.midiChannel

        midi2.sendNoteOn(
            channel: channel,
            note: voice.midiNote,
            velocity: voice.velocity
        )

        // Send initial expression values for MPE
        if routing.mpeEnabled {
            sendPerNoteModulation(voice)
        }
    }

    private func sendNoteOff(_ voice: QuantumMIDIVoice) {
        guard let midi2 = midi2Manager else { return }

        let channel = routing.mpeEnabled ? voice.channel : voice.instrumentTarget.midiChannel

        midi2.sendNoteOff(
            channel: channel,
            note: voice.midiNote,
            velocity: 0
        )
    }

    private func sendPerNoteModulation(_ voice: QuantumMIDIVoice) {
        guard let midi2 = midi2Manager, routing.mpeEnabled else { return }

        // Per-note pitch bend
        midi2.sendPerNotePitchBend(
            channel: voice.channel,
            note: voice.midiNote,
            bend: voice.pitchBend
        )

        // Per-note pressure (CC74 for brightness in MPE)
        midi2.sendPerNoteController(
            channel: voice.channel,
            note: voice.midiNote,
            controller: .brightness,
            value: voice.brightness
        )
    }

    // MARK: - Super Intelligent Features

    /// Generate a quantum chord based on current state
    public func playQuantumChord(
        root: UInt8,
        type: QuantumChordType,
        instrument: QuantumMIDIVoice.InstrumentTarget = .piano
    ) {
        let intervals = type.intervals(for: intelligenceMode)

        for (index, interval) in intervals.enumerated() {
            let note = root + UInt8(interval)
            let velocityVariation = Float(index) / Float(intervals.count) * 0.2

            // Stagger notes for arpeggiated feel in transcendent mode
            if intelligenceMode == .lambdaTranscendent {
                let delay = Double(index) * 0.02
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    noteOn(
                        note: note,
                        velocity: bioInput.quantumVelocity - velocityVariation,
                        instrument: instrument
                    )
                }
            } else {
                noteOn(
                    note: note,
                    velocity: bioInput.quantumVelocity - velocityVariation,
                    instrument: instrument
                )
            }
        }
    }

    /// Play notes distributed across all enabled instruments
    public func playAcrossAllInstruments(note: UInt8, velocity: Float? = nil) {
        for instrument in routing.enabledInstruments {
            noteOn(note: note, velocity: velocity, instrument: instrument)
        }
    }

    /// Generate bio-reactive melody phrase
    public func generateBioReactivePhrase(length: Int = 8, instrument: QuantumMIDIVoice.InstrumentTarget = .piano) {
        let scale = bioReactiveScale()
        let baseNote: UInt8 = 60  // Middle C

        for i in 0..<length {
            let scaleIndex = selectNoteFromCoherence(scaleLength: scale.count)
            let note = baseNote + UInt8(scale[scaleIndex])
            let velocity = bioInput.quantumVelocity * (0.8 + Float(i % 4) * 0.05)

            // Schedule note with bio-reactive timing
            let beatDuration = 60.0 / bioInput.heartRate
            let delay = Double(i) * beatDuration * 0.5

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                noteOn(note: note, velocity: velocity, instrument: instrument)

                // Note duration based on breathing
                let noteDuration = beatDuration * Double(0.5 + bioInput.breathPhase * 0.5)
                try? await Task.sleep(nanoseconds: UInt64(noteDuration * 1_000_000_000))
                noteOff(note: note, instrument: instrument)
            }
        }
    }

    private func bioReactiveScale() -> [Int] {
        // Select scale based on coherence level
        let coherence = bioInput.coherence

        if coherence > 0.8 {
            return [0, 2, 4, 7, 9]  // Major pentatonic - bright
        } else if coherence > 0.6 {
            return [0, 2, 4, 5, 7, 9, 11]  // Major - stable
        } else if coherence > 0.4 {
            return [0, 2, 3, 5, 7, 9, 10]  // Dorian - contemplative
        } else if coherence > 0.2 {
            return [0, 3, 5, 7, 10]  // Minor pentatonic - introspective
        } else {
            return [0, 1, 3, 5, 7, 8, 10]  // Phrygian - mysterious
        }
    }

    private func selectNoteFromCoherence(scaleLength: Int) -> Int {
        // Coherence affects note selection probability
        let coherence = bioInput.coherence

        if intelligenceMode == .fibonacciHarmonic {
            // Fibonacci-weighted selection
            let fibIndex = Int(coherence * Float(fibonacciSequence.count - 1))
            return fibonacciSequence[fibIndex] % scaleLength
        } else if intelligenceMode == .sacredGeometry {
            // Golden ratio selection
            return Int(Float(scaleLength) * QuantumMIDIConstants.phi.truncatingRemainder(dividingBy: 1.0))
        } else {
            // Coherence-weighted random
            let weightedIndex = Int(coherence * Float(scaleLength - 1))
            let randomOffset = Int.random(in: -1...1)
            return (weightedIndex + randomOffset).clamped(to: 0...(scaleLength - 1))
        }
    }

    // MARK: - Bio Input Update

    /// Update bio-signals
    public func updateBioInput(
        heartRate: Double? = nil,
        hrv: Double? = nil,
        coherence: Float? = nil,
        breathingRate: Double? = nil,
        breathPhase: Float? = nil,
        lambdaState: QuantumBioInput.LambdaState? = nil
    ) {
        if let hr = heartRate { bioInput.heartRate = hr }
        if let hrvVal = hrv { bioInput.hrvMs = hrvVal }
        if let coh = coherence { bioInput.coherence = coh }
        if let br = breathingRate { bioInput.breathingRate = br }
        if let bp = breathPhase { bioInput.breathPhase = bp }
        if let lambda = lambdaState { bioInput.lambdaState = lambda }
    }

    // MARK: - Presets

    /// Load meditation preset
    public func loadMeditationPreset() {
        intelligenceMode = .bioCoherent
        polyphony = 8
        routing.enableSynthesizers()
        routing.mpeEnabled = true
    }

    /// Load orchestral preset
    public func loadOrchestralPreset() {
        intelligenceMode = .superIntelligent
        polyphony = 32
        routing.enableOrchestral()
        routing.mpeEnabled = true
    }

    /// Load quantum transcendent preset
    public func loadQuantumTranscendentPreset() {
        intelligenceMode = .lambdaTranscendent
        polyphony = 64
        routing.enableAll()
        routing.mpeEnabled = true
        routing.midi2Enabled = true
    }

    /// Load sacred geometry preset
    public func loadSacredGeometryPreset() {
        intelligenceMode = .sacredGeometry
        polyphony = 16
        routing.enableSynthesizers()
        routing.quantumInstrumentsEnabled = true
    }
}

// MARK: - Quantum Chord Types

/// Quantum-inspired chord voicings
public enum QuantumChordType: String, CaseIterable, Identifiable, Sendable {
    case majorTriad = "Major"
    case minorTriad = "Minor"
    case diminished = "Diminished"
    case augmented = "Augmented"
    case major7 = "Major 7"
    case minor7 = "Minor 7"
    case dominant7 = "Dominant 7"
    case halfDiminished = "Half-Diminished"
    case fibonacci = "Fibonacci"
    case goldenRatio = "Golden Ratio"
    case quantumSuperposition = "Quantum Superposition"
    case sacredGeometry = "Sacred Geometry"
    case schumannResonance = "Schumann Resonance"

    public var id: String { rawValue }

    public func intervals(for mode: QuantumIntelligenceMode) -> [Int] {
        switch self {
        case .majorTriad: return [0, 4, 7]
        case .minorTriad: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .dominant7: return [0, 4, 7, 10]
        case .halfDiminished: return [0, 3, 6, 10]
        case .fibonacci: return [0, 1, 2, 3, 5, 8, 13].map { $0 % 12 }
        case .goldenRatio: return [0, 2, 4, 6, 9, 11]  // Roughly golden ratio intervals
        case .quantumSuperposition:
            // All notes exist until measured
            return mode == .lambdaTranscendent ? [0, 2, 4, 5, 7, 9, 11] : [0, 4, 7]
        case .sacredGeometry:
            // Flower of Life inspired - 6-fold symmetry
            return [0, 2, 4, 6, 8, 10]
        case .schumannResonance:
            // Based on Schumann frequencies mapped to notes
            return [0, 3, 5, 7, 10]  // Approximate mapping of 7.83, 14.3, 20.8, 27.3, 33.8 Hz ratios
        }
    }
}

// MARK: - Extensions

private extension UInt8 {
    func clamped(to range: ClosedRange<UInt8>) -> UInt8 {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}
