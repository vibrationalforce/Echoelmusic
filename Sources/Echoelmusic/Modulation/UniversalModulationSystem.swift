// UniversalModulationSystem.swift
// Echoelmusic - Universal Modulation for Instruments, Effects & Visuals
// Replaces standalone Binaural Beat Generator with integrated modulation

import Foundation
import Combine
import Accelerate

// MARK: - Modulation LUT (Optimized)

fileprivate enum ModulationLUT {
    static let size: Int = 4096
    static let mask: Int = 4095
    static let twoPi: Float = 2.0 * .pi

    // Sine table
    static let sineTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            t[i] = sin(Float(i) / 4096.0 * 2.0 * .pi)
        }
        return t
    }()

    // Triangle table
    static let triangleTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            let phase = Float(i) / 4096.0
            if phase < 0.25 {
                t[i] = phase * 4.0
            } else if phase < 0.75 {
                t[i] = 2.0 - phase * 4.0
            } else {
                t[i] = phase * 4.0 - 4.0
            }
        }
        return t
    }()

    // Square table (with anti-aliasing)
    static let squareTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            let phase = Float(i) / 4096.0
            // Soft square with slight rounding
            let x = (phase - 0.5) * 20.0
            t[i] = tanh(x)
        }
        return t
    }()

    // Sawtooth table
    static let sawTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            t[i] = (Float(i) / 4096.0) * 2.0 - 1.0
        }
        return t
    }()

    // Exponential table (for envelopes)
    static let expTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            let phase = Float(i) / 4096.0
            t[i] = exp(-phase * 5.0) * 2.0 - 1.0
        }
        return t
    }()

    // Sample and Hold (random values)
    static var sampleHoldValue: Float = 0.0
    static var lastSampleHoldPhase: Float = 0.0

    @inline(__always)
    static func lookup(_ table: [Float], phase: Float) -> Float {
        var p = phase
        p = p - Float(Int(p))
        if p < 0 { p += 1.0 }
        let index = Int(p * Float(size)) & mask
        return table[index]
    }
}

// MARK: - Modulation Waveform

public enum ModulationWaveform: String, CaseIterable, Codable {
    case sine = "Sine"
    case triangle = "Triangle"
    case square = "Square"
    case sawtooth = "Sawtooth"
    case exponential = "Exponential"
    case sampleHold = "Sample & Hold"
    case noise = "Noise"
    case breath = "Breath Sync"      // Synced to breathing rate
    case heartbeat = "Heartbeat"     // Synced to heart rate
    case coherence = "Coherence"     // Driven by HRV coherence
    case custom = "Custom"

    var icon: String {
        switch self {
        case .sine: return "∿"
        case .triangle: return "△"
        case .square: return "⊓"
        case .sawtooth: return "⧋"
        case .exponential: return "⌒"
        case .sampleHold: return "⊏"
        case .noise: return "⚡"
        case .breath: return "🌬️"
        case .heartbeat: return "💓"
        case .coherence: return "🧘"
        case .custom: return "✎"
        }
    }
}

// MARK: - Brainwave State (Entrainment Frequencies)

public enum BrainwaveState: String, CaseIterable, Codable {
    case delta = "Delta"        // 0.5-4 Hz - Deep sleep, healing
    case theta = "Theta"        // 4-8 Hz - Meditation, creativity
    case alpha = "Alpha"        // 8-13 Hz - Relaxation, learning
    case smr = "SMR"            // 12-15 Hz - Sensorimotor rhythm, calm focus
    case beta = "Beta"          // 13-30 Hz - Active thinking, focus
    case gamma = "Gamma"        // 30-100 Hz - Peak cognition, insight

    public var frequencyRange: ClosedRange<Float> {
        switch self {
        case .delta: return 0.5...4.0
        case .theta: return 4.0...8.0
        case .alpha: return 8.0...13.0
        case .smr: return 12.0...15.0
        case .beta: return 13.0...30.0
        case .gamma: return 30.0...100.0
        }
    }

    public var defaultFrequency: Float {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .smr: return 14.0
        case .beta: return 20.0
        case .gamma: return 40.0
        }
    }

    public var description: String {
        switch self {
        case .delta: return "Deep sleep, healing, regeneration"
        case .theta: return "Meditation, creativity, intuition"
        case .alpha: return "Relaxation, calm focus, learning"
        case .smr: return "Calm alertness, motor control"
        case .beta: return "Active thinking, concentration"
        case .gamma: return "Peak cognition, insight, flow state"
        }
    }
}

// MARK: - Modulation Target

public enum ModulationTarget: String, CaseIterable, Codable {
    // Synthesis Parameters
    case pitch = "Pitch"
    case amplitude = "Amplitude"
    case filterCutoff = "Filter Cutoff"
    case filterResonance = "Filter Resonance"
    case panning = "Panning"
    case detuning = "Detuning"
    case harmonics = "Harmonics"
    case wavefolding = "Wavefolding"

    // Effect Parameters
    case delayTime = "Delay Time"
    case delayFeedback = "Delay Feedback"
    case reverbSize = "Reverb Size"
    case reverbDamping = "Reverb Damping"
    case chorusDepth = "Chorus Depth"
    case chorusRate = "Chorus Rate"
    case flangerDepth = "Flanger Depth"
    case phaserDepth = "Phaser Depth"
    case distortionDrive = "Distortion Drive"
    case compressorThreshold = "Compressor Threshold"
    case tremoloDepth = "Tremolo Depth"
    case vibratoDepth = "Vibrato Depth"

    // Visual Parameters
    case visualIntensity = "Visual Intensity"
    case visualHue = "Visual Hue"
    case visualSaturation = "Visual Saturation"
    case visualBrightness = "Visual Brightness"
    case visualScale = "Visual Scale"
    case visualRotation = "Visual Rotation"
    case particleDensity = "Particle Density"
    case particleSpeed = "Particle Speed"
    case geometryMorph = "Geometry Morph"
    case blurAmount = "Blur Amount"

    // Lighting Parameters
    case lightIntensity = "Light Intensity"
    case lightColor = "Light Color"
    case lightPosition = "Light Position"
    case strobeRate = "Strobe Rate"
    case dmxChannel = "DMX Channel"

    // Bio-Reactive
    case entrainmentStrength = "Entrainment Strength"
    case coherenceMapping = "Coherence Mapping"
}

// MARK: - Modulation Source

public class ModulationSource: Identifiable, ObservableObject {
    public let id: UUID
    public var name: String

    @Published public var waveform: ModulationWaveform
    @Published public var frequency: Float          // Hz (or BPM divisor if tempo-synced)
    @Published public var depth: Float              // 0.0 - 1.0
    @Published public var offset: Float             // -1.0 to 1.0 (DC offset)
    @Published public var phase: Float              // 0.0 - 1.0 (phase offset)
    @Published public var isTempoSynced: Bool
    @Published public var tempoDivision: TempoDivision
    @Published public var isBioSynced: Bool
    @Published public var brainwaveState: BrainwaveState?
    @Published public var isEnabled: Bool

    // Smoothing
    @Published public var smoothing: Float          // 0.0 - 1.0 (low-pass filter amount)

    // Current state
    private var currentPhase: Float = 0.0
    private var smoothedValue: Float = 0.0
    private var sampleHoldValue: Float = 0.0
    private var lastSampleHoldPhase: Float = 0.0

    // Bio data inputs
    public var breathingRate: Float = 6.0       // breaths per minute
    public var heartRate: Float = 60.0          // BPM
    public var coherenceLevel: Float = 0.5      // 0.0 - 1.0
    public var heartbeatPhase: Float = 0.0      // 0.0 - 1.0 (current position in heartbeat cycle)

    public enum TempoDivision: String, CaseIterable, Codable {
        case whole = "1/1"
        case half = "1/2"
        case quarter = "1/4"
        case eighth = "1/8"
        case sixteenth = "1/16"
        case thirtysecond = "1/32"
        case dottedHalf = "1/2."
        case dottedQuarter = "1/4."
        case dottedEighth = "1/8."
        case tripletQuarter = "1/4T"
        case tripletEighth = "1/8T"

        public var multiplier: Float {
            switch self {
            case .whole: return 1.0
            case .half: return 2.0
            case .quarter: return 4.0
            case .eighth: return 8.0
            case .sixteenth: return 16.0
            case .thirtysecond: return 32.0
            case .dottedHalf: return 1.333
            case .dottedQuarter: return 2.666
            case .dottedEighth: return 5.333
            case .tripletQuarter: return 6.0
            case .tripletEighth: return 12.0
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "LFO",
        waveform: ModulationWaveform = .sine,
        frequency: Float = 1.0,
        depth: Float = 0.5,
        offset: Float = 0.0,
        phase: Float = 0.0,
        isTempoSynced: Bool = false,
        tempoDivision: TempoDivision = .quarter,
        isBioSynced: Bool = false,
        brainwaveState: BrainwaveState? = nil,
        isEnabled: Bool = true,
        smoothing: Float = 0.0
    ) {
        self.id = id
        self.name = name
        self.waveform = waveform
        self.frequency = frequency
        self.depth = depth
        self.offset = offset
        self.phase = phase
        self.isTempoSynced = isTempoSynced
        self.tempoDivision = tempoDivision
        self.isBioSynced = isBioSynced
        self.brainwaveState = brainwaveState
        self.isEnabled = isEnabled
        self.smoothing = smoothing
    }

    /// Get current modulation value
    /// - Parameters:
    ///   - sampleRate: Audio sample rate
    ///   - tempo: Current tempo in BPM (for tempo sync)
    /// - Returns: Modulation value (-1.0 to 1.0, scaled by depth and offset)
    @inline(__always)
    public func getValue(sampleRate: Float, tempo: Float = 120.0) -> Float {
        guard isEnabled else { return offset }

        // Calculate effective frequency
        var effectiveFrequency = frequency

        if isTempoSynced {
            // Convert tempo division to Hz
            let beatsPerSecond = tempo / 60.0
            effectiveFrequency = beatsPerSecond * tempoDivision.multiplier
        }

        if isBioSynced {
            switch waveform {
            case .breath:
                effectiveFrequency = breathingRate / 60.0
            case .heartbeat:
                effectiveFrequency = heartRate / 60.0
            case .coherence:
                // Coherence doesn't oscillate, it's a direct mapping
                let value = (coherenceLevel * 2.0 - 1.0) * depth + offset
                return applySmoothing(value)
            default:
                if let state = brainwaveState {
                    effectiveFrequency = state.defaultFrequency
                }
            }
        }

        // Advance phase
        let phaseIncrement = effectiveFrequency / sampleRate
        currentPhase += phaseIncrement
        if currentPhase >= 1.0 {
            currentPhase -= 1.0
        }

        // Apply phase offset
        var lookupPhase = currentPhase + phase
        if lookupPhase >= 1.0 {
            lookupPhase -= 1.0
        }

        // Get raw waveform value
        var rawValue: Float

        switch waveform {
        case .sine:
            rawValue = ModulationLUT.lookup(ModulationLUT.sineTable, phase: lookupPhase)

        case .triangle:
            rawValue = ModulationLUT.lookup(ModulationLUT.triangleTable, phase: lookupPhase)

        case .square:
            rawValue = ModulationLUT.lookup(ModulationLUT.squareTable, phase: lookupPhase)

        case .sawtooth:
            rawValue = ModulationLUT.lookup(ModulationLUT.sawTable, phase: lookupPhase)

        case .exponential:
            rawValue = ModulationLUT.lookup(ModulationLUT.expTable, phase: lookupPhase)

        case .sampleHold:
            // Trigger new random value when phase resets
            if lookupPhase < lastSampleHoldPhase {
                sampleHoldValue = Float.random(in: -1.0...1.0)
            }
            lastSampleHoldPhase = lookupPhase
            rawValue = sampleHoldValue

        case .noise:
            rawValue = Float.random(in: -1.0...1.0)

        case .breath:
            // Smooth breath-like wave (modified sine)
            let breathPhase = ModulationLUT.lookup(ModulationLUT.sineTable, phase: lookupPhase)
            rawValue = (breathPhase + 1.0) / 2.0 // 0-1 range for breath (inhale/exhale)
            rawValue = rawValue * 2.0 - 1.0

        case .heartbeat:
            // Double-bump heartbeat pattern (lub-dub)
            if lookupPhase < 0.1 {
                // First beat (lub)
                rawValue = sin(lookupPhase / 0.1 * .pi) * 1.0
            } else if lookupPhase < 0.2 {
                // Decay
                rawValue = sin((lookupPhase - 0.1) / 0.1 * .pi + .pi) * 0.3
            } else if lookupPhase < 0.3 {
                // Second beat (dub)
                rawValue = sin((lookupPhase - 0.2) / 0.1 * .pi) * 0.7
            } else {
                // Rest
                rawValue = 0.0
            }

        case .coherence:
            rawValue = coherenceLevel * 2.0 - 1.0

        case .custom:
            rawValue = ModulationLUT.lookup(ModulationLUT.sineTable, phase: lookupPhase)
        }

        // Apply depth and offset
        let scaledValue = rawValue * depth + offset

        // Apply smoothing
        return applySmoothing(scaledValue)
    }

    @inline(__always)
    private func applySmoothing(_ value: Float) -> Float {
        if smoothing > 0 {
            let alpha = 1.0 - smoothing * 0.99
            smoothedValue = smoothedValue * (1.0 - alpha) + value * alpha
            return smoothedValue
        }
        return value
    }

    /// Configure for brainwave entrainment
    public func configureForEntrainment(_ state: BrainwaveState) {
        brainwaveState = state
        frequency = state.defaultFrequency
        waveform = .sine
        isBioSynced = true
    }

    /// Update bio data from external sources
    public func updateBioData(heartRate: Float? = nil, breathingRate: Float? = nil, coherence: Float? = nil) {
        if let hr = heartRate { self.heartRate = hr }
        if let br = breathingRate { self.breathingRate = br }
        if let c = coherence { self.coherenceLevel = c }
    }
}

// MARK: - Modulation Routing

public struct ModulationRouting: Identifiable, Codable {
    public let id: UUID
    public var sourceId: UUID
    public var target: ModulationTarget
    public var amount: Float               // -1.0 to 1.0 (bipolar)
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        sourceId: UUID,
        target: ModulationTarget,
        amount: Float = 1.0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.sourceId = sourceId
        self.target = target
        self.amount = amount
        self.isEnabled = isEnabled
    }
}

// MARK: - Universal Modulation Matrix

@MainActor
public final class UniversalModulationSystem: ObservableObject {
    public static let shared = UniversalModulationSystem()

    // MARK: - Published State

    @Published public var sources: [ModulationSource] = []
    @Published public var routings: [ModulationRouting] = []
    @Published public var isEnabled: Bool = true

    // Global settings
    @Published public var globalDepth: Float = 1.0
    @Published public var tempo: Float = 120.0
    @Published public var sampleRate: Float = 48000.0

    // Bio data (shared across all sources)
    @Published public var heartRate: Float = 60.0
    @Published public var breathingRate: Float = 6.0
    @Published public var coherenceLevel: Float = 0.5
    @Published public var hrvValue: Float = 50.0

    // Entrainment state
    @Published public var activeEntrainmentState: BrainwaveState?
    @Published public var entrainmentStrength: Float = 0.5

    // MARK: - Private Properties

    private var targetValues: [ModulationTarget: Float] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupDefaultSources()
    }

    private func setupDefaultSources() {
        // Create default LFO sources
        let lfo1 = ModulationSource(
            name: "LFO 1",
            waveform: .sine,
            frequency: 1.0,
            depth: 0.5
        )

        let lfo2 = ModulationSource(
            name: "LFO 2",
            waveform: .triangle,
            frequency: 0.5,
            depth: 0.3
        )

        let entrainmentLFO = ModulationSource(
            name: "Entrainment",
            waveform: .sine,
            frequency: 10.0,
            depth: 0.5,
            isBioSynced: true,
            brainwaveState: .alpha
        )

        let breathLFO = ModulationSource(
            name: "Breath Sync",
            waveform: .breath,
            frequency: 6.0,
            depth: 0.3,
            isBioSynced: true
        )

        let heartbeatLFO = ModulationSource(
            name: "Heartbeat",
            waveform: .heartbeat,
            frequency: 1.0,
            depth: 0.4,
            isBioSynced: true
        )

        let coherenceMod = ModulationSource(
            name: "Coherence",
            waveform: .coherence,
            frequency: 0.0,
            depth: 1.0,
            isBioSynced: true
        )

        sources = [lfo1, lfo2, entrainmentLFO, breathLFO, heartbeatLFO, coherenceMod]
    }

    // MARK: - Source Management

    /// Add a new modulation source
    public func addSource(_ source: ModulationSource) {
        sources.append(source)
    }

    /// Remove a modulation source
    public func removeSource(id: UUID) {
        sources.removeAll { $0.id == id }
        routings.removeAll { $0.sourceId == id }
    }

    /// Get source by ID
    public func getSource(id: UUID) -> ModulationSource? {
        return sources.first { $0.id == id }
    }

    // MARK: - Routing Management

    /// Add a modulation routing
    public func addRouting(_ routing: ModulationRouting) {
        routings.append(routing)
    }

    /// Remove a routing
    public func removeRouting(id: UUID) {
        routings.removeAll { $0.id == id }
    }

    /// Route a source to a target
    public func route(sourceId: UUID, to target: ModulationTarget, amount: Float = 1.0) {
        let routing = ModulationRouting(
            sourceId: sourceId,
            target: target,
            amount: amount
        )
        routings.append(routing)
    }

    // MARK: - Value Processing

    /// Get the total modulation value for a target
    /// Combines all sources routed to this target
    public func getModulationValue(for target: ModulationTarget) -> Float {
        guard isEnabled else { return 0.0 }

        var totalModulation: Float = 0.0

        for routing in routings where routing.target == target && routing.isEnabled {
            if let source = getSource(id: routing.sourceId), source.isEnabled {
                let value = source.getValue(sampleRate: sampleRate, tempo: tempo)
                totalModulation += value * routing.amount
            }
        }

        return totalModulation * globalDepth
    }

    /// Process all modulation sources (call once per audio block)
    public func processBlock(blockSize: Int) {
        // Update bio data for all sources
        for source in sources {
            source.updateBioData(
                heartRate: heartRate,
                breathingRate: breathingRate,
                coherence: coherenceLevel
            )
        }

        // Pre-calculate values for all targets
        for target in ModulationTarget.allCases {
            targetValues[target] = getModulationValue(for: target)
        }
    }

    /// Get pre-calculated value (faster, for audio thread)
    @inline(__always)
    public func getCachedValue(for target: ModulationTarget) -> Float {
        return targetValues[target] ?? 0.0
    }

    // MARK: - Entrainment

    /// Set brainwave entrainment state
    public func setEntrainmentState(_ state: BrainwaveState) {
        activeEntrainmentState = state

        // Update entrainment source
        if let entrainmentSource = sources.first(where: { $0.name == "Entrainment" }) {
            entrainmentSource.configureForEntrainment(state)
        }
    }

    /// Auto-adjust entrainment based on coherence
    public func autoEntrainment() {
        let state: BrainwaveState
        if coherenceLevel < 0.3 {
            state = .alpha // Need relaxation
        } else if coherenceLevel < 0.5 {
            state = .smr // Calm focus
        } else if coherenceLevel < 0.7 {
            state = .beta // Active focus
        } else {
            state = .gamma // Peak state
        }

        setEntrainmentState(state)
    }

    // MARK: - Bio Data Updates

    /// Update all bio-reactive data
    public func updateBioData(heartRate: Float? = nil, breathingRate: Float? = nil, coherence: Float? = nil, hrv: Float? = nil) {
        if let hr = heartRate { self.heartRate = hr }
        if let br = breathingRate { self.breathingRate = br }
        if let c = coherence { self.coherenceLevel = c }
        if let h = hrv { self.hrvValue = h }

        // Propagate to all sources
        for source in sources {
            source.updateBioData(
                heartRate: self.heartRate,
                breathingRate: self.breathingRate,
                coherence: self.coherenceLevel
            )
        }
    }

    // MARK: - Presets

    /// Create preset for meditation
    public func applyMeditationPreset() {
        setEntrainmentState(.theta)

        // Route entrainment to multiple targets
        if let entrainmentId = sources.first(where: { $0.name == "Entrainment" })?.id {
            route(sourceId: entrainmentId, to: .filterCutoff, amount: 0.3)
            route(sourceId: entrainmentId, to: .visualIntensity, amount: 0.5)
            route(sourceId: entrainmentId, to: .lightIntensity, amount: 0.4)
        }

        // Add breath sync
        if let breathId = sources.first(where: { $0.name == "Breath Sync" })?.id {
            route(sourceId: breathId, to: .amplitude, amount: 0.2)
            route(sourceId: breathId, to: .reverbSize, amount: 0.3)
        }
    }

    /// Create preset for focus
    public func applyFocusPreset() {
        setEntrainmentState(.beta)

        if let entrainmentId = sources.first(where: { $0.name == "Entrainment" })?.id {
            route(sourceId: entrainmentId, to: .filterCutoff, amount: 0.2)
            route(sourceId: entrainmentId, to: .visualBrightness, amount: 0.3)
        }
    }

    /// Create preset for creativity
    public func applyCreativityPreset() {
        setEntrainmentState(.alpha)

        if let entrainmentId = sources.first(where: { $0.name == "Entrainment" })?.id {
            route(sourceId: entrainmentId, to: .chorusDepth, amount: 0.4)
            route(sourceId: entrainmentId, to: .visualHue, amount: 0.6)
            route(sourceId: entrainmentId, to: .particleDensity, amount: 0.5)
        }

        if let coherenceId = sources.first(where: { $0.name == "Coherence" })?.id {
            route(sourceId: coherenceId, to: .reverbSize, amount: 0.4)
        }
    }

    /// Create preset for sleep
    public func applySleepPreset() {
        setEntrainmentState(.delta)

        if let entrainmentId = sources.first(where: { $0.name == "Entrainment" })?.id {
            route(sourceId: entrainmentId, to: .filterCutoff, amount: -0.3) // Lower filter
            route(sourceId: entrainmentId, to: .visualBrightness, amount: -0.5) // Dim visuals
        }

        if let breathId = sources.first(where: { $0.name == "Breath Sync" })?.id {
            route(sourceId: breathId, to: .amplitude, amount: 0.15)
        }
    }
}

// MARK: - Modulation Extensions for Instruments

public protocol Modulatable: AnyObject {
    var modulationInputs: [ModulationTarget: Float] { get set }

    func applyModulation(_ target: ModulationTarget, value: Float)
    func getModulatedValue(base: Float, target: ModulationTarget, range: ClosedRange<Float>) -> Float
}

extension Modulatable {
    public func getModulatedValue(base: Float, target: ModulationTarget, range: ClosedRange<Float>) -> Float {
        let modulation = modulationInputs[target] ?? 0.0
        let modulated = base + modulation * (range.upperBound - range.lowerBound) / 2.0
        return max(range.lowerBound, min(range.upperBound, modulated))
    }
}

// MARK: - Visual Modulation Bridge

public class VisualModulationBridge: ObservableObject {
    public static let shared = VisualModulationBridge()

    @Published public var intensity: Float = 0.5
    @Published public var hue: Float = 0.5
    @Published public var saturation: Float = 0.7
    @Published public var brightness: Float = 0.8
    @Published public var scale: Float = 1.0
    @Published public var rotation: Float = 0.0
    @Published public var particleDensity: Float = 0.5
    @Published public var particleSpeed: Float = 0.5
    @Published public var geometryMorph: Float = 0.0
    @Published public var blurAmount: Float = 0.0

    private let modSystem = UniversalModulationSystem.shared

    public func update() {
        intensity = 0.5 + modSystem.getCachedValue(for: .visualIntensity)
        hue = 0.5 + modSystem.getCachedValue(for: .visualHue) * 0.5
        saturation = 0.7 + modSystem.getCachedValue(for: .visualSaturation) * 0.3
        brightness = 0.8 + modSystem.getCachedValue(for: .visualBrightness) * 0.2
        scale = 1.0 + modSystem.getCachedValue(for: .visualScale) * 0.5
        rotation = modSystem.getCachedValue(for: .visualRotation) * 360.0
        particleDensity = 0.5 + modSystem.getCachedValue(for: .particleDensity) * 0.5
        particleSpeed = 0.5 + modSystem.getCachedValue(for: .particleSpeed) * 0.5
        geometryMorph = modSystem.getCachedValue(for: .geometryMorph)
        blurAmount = max(0, modSystem.getCachedValue(for: .blurAmount))
    }
}

// MARK: - Lighting Modulation Bridge

public class LightingModulationBridge: ObservableObject {
    public static let shared = LightingModulationBridge()

    @Published public var intensity: Float = 0.5
    @Published public var colorHue: Float = 0.5
    @Published public var strobeRate: Float = 0.0

    private let modSystem = UniversalModulationSystem.shared

    public func update() {
        intensity = 0.5 + modSystem.getCachedValue(for: .lightIntensity) * 0.5
        colorHue = 0.5 + modSystem.getCachedValue(for: .lightColor) * 0.5
        strobeRate = max(0, modSystem.getCachedValue(for: .strobeRate))
    }

    public func getDMXValue(channel: Int) -> UInt8 {
        let baseValue = intensity * 255.0
        let modulation = modSystem.getCachedValue(for: .dmxChannel) * 127.0
        return UInt8(max(0, min(255, baseValue + modulation)))
    }
}
