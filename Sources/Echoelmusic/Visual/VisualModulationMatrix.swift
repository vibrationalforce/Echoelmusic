// VisualModulationMatrix.swift
// Echoelmusic - Synthesizer-Style Modulation Matrix for Visuals
//
// Routes modulation sources (LFOs, envelopes, audio analysis, bio data,
// MIDI) to per-layer visual parameter destinations via configurable
// routes with amount scaling and curve shaping.
//
// Inspired by classic synthesizer modulation matrices (Prophet Rev2,
// Serum, Vital) but applied to visual parameters rather than audio.
//
// Operates at 60 Hz, synchronized with EchoelVisualCompositor.
//
// Architecture:
//   VisualModulationMatrix (60Hz)
//       ├─ 4 LFOs (free-running or BPM-synced oscillators)
//       ├─ 2 Envelope Generators (ADSR, triggered by MIDI/beat)
//       ├─ 4 Audio Modulators (peak detection, band energy)
//       ├─ Bio Sources (coherence, heartRate, breathPhase, hrvRaw)
//       ├─ MIDI Sources (note, velocity, aftertouch, pitchBend, CC)
//       └─ Routes: [Source → Destination × Amount × Curve]
//               ↓
//           per-layer modulation offsets
//               ↓
//           EchoelVisualCompositor.applyModulationOffsets()
//
// Supported Platforms: iOS 15+, macOS 12+, tvOS 15+, visionOS 1+
// Swift 5.9+, Zero external dependencies
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
import Combine

// MARK: - Modulation Source Identifier

/// Uniquely identifies a modulation source within the matrix.
///
/// Modulation sources produce a continuous signal in the range 0-1
/// (unipolar) or -1 to +1 (bipolar) that can be routed to any
/// visual parameter destination.
enum ModulationSourceID: Hashable, Codable, Sendable {
    // LFOs
    case lfo(index: Int)            // 0-3

    // Envelope generators
    case envelope(index: Int)       // 0-1

    // Audio modulators
    case audioModulator(index: Int) // 0-3

    // Bio sources
    case bioCoherence
    case bioHeartRate
    case bioBreathPhase
    case bioHRVRaw

    // MIDI sources
    case midiNote
    case midiVelocity
    case midiAftertouch
    case midiPitchBend
    case midiCC(number: UInt8)

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .lfo(let i):            return "LFO \(i + 1)"
        case .envelope(let i):       return "Envelope \(i + 1)"
        case .audioModulator(let i): return "Audio Mod \(i + 1)"
        case .bioCoherence:          return "Bio: Coherence"
        case .bioHeartRate:          return "Bio: Heart Rate"
        case .bioBreathPhase:        return "Bio: Breath Phase"
        case .bioHRVRaw:             return "Bio: HRV Raw"
        case .midiNote:              return "MIDI: Note"
        case .midiVelocity:          return "MIDI: Velocity"
        case .midiAftertouch:        return "MIDI: Aftertouch"
        case .midiPitchBend:         return "MIDI: Pitch Bend"
        case .midiCC(let n):         return "MIDI: CC \(n)"
        }
    }
}

// MARK: - Modulation Destination

/// Visual parameter destinations that can receive modulation.
///
/// Each destination corresponds to a parameter on a ``VisualLayer``.
/// Modulation values are applied as additive offsets to the base
/// parameter value.
enum ModulationDestination: String, CaseIterable, Identifiable, Codable, Sendable {
    case opacity
    case rotation
    case scale
    case positionX
    case positionY
    case hue
    case saturation
    case brightness
    case speed
    case complexity
    case frequency
    case amplitude

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .opacity:    return "Opacity"
        case .rotation:   return "Rotation"
        case .scale:      return "Scale"
        case .positionX:  return "Position X"
        case .positionY:  return "Position Y"
        case .hue:        return "Hue"
        case .saturation: return "Saturation"
        case .brightness: return "Brightness"
        case .speed:      return "Speed"
        case .complexity: return "Complexity"
        case .frequency:  return "Frequency"
        case .amplitude:  return "Amplitude"
        }
    }

    /// Default range scaling for this destination.
    /// Modulation amount (-1 to +1) is multiplied by this range
    /// to produce the final offset applied to the layer parameter.
    var defaultRange: Float {
        switch self {
        case .opacity:    return 1.0       // 0-1 full range
        case .rotation:   return .pi * 2   // Full rotation
        case .scale:      return 2.0       // Up to 2x scale change
        case .positionX:  return 1.0       // Full screen width
        case .positionY:  return 1.0       // Full screen height
        case .hue:        return 1.0       // Full hue cycle
        case .saturation: return 1.0       // Full saturation range
        case .brightness: return 1.0       // Full brightness range
        case .speed:      return 4.0       // Up to 4x speed change
        case .complexity: return 1.0       // Full complexity range
        case .frequency:  return 10.0      // Up to 10 Hz change
        case .amplitude:  return 2.0       // Up to 2x amplitude change
        }
    }
}

// MARK: - Modulation Curve

/// Curve types that shape the modulation signal before applying
/// it to the destination parameter.
enum ModulationCurve: String, CaseIterable, Identifiable, Codable, Sendable {
    case linear
    case exponential
    case logarithmic
    case sCurve
    case stepped

    var id: String { rawValue }

    /// Apply the curve to a normalized value.
    ///
    /// - Parameter x: Input value (-1 to +1 or 0 to 1)
    /// - Returns: Shaped output value
    func apply(_ x: Float) -> Float {
        let sign: Float = x < 0 ? -1 : 1
        let absX = abs(x)

        switch self {
        case .linear:
            return x

        case .exponential:
            // Quadratic curve preserving sign
            return sign * absX * absX

        case .logarithmic:
            // Square root curve preserving sign
            return sign * sqrt(absX)

        case .sCurve:
            // Smoothstep (3t^2 - 2t^3) preserving sign
            let t = absX
            return sign * (t * t * (3.0 - 2.0 * t))

        case .stepped:
            // 8-step quantization preserving sign
            return sign * (Float(Int(absX * 8.0)) / 7.0)
        }
    }
}

// MARK: - LFO Shape

/// Waveform shapes for the Low Frequency Oscillator modulation sources.
enum LFOShape: String, CaseIterable, Identifiable, Codable, Sendable {
    case sine
    case triangle
    case saw
    case square
    case random

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .sine:     return "Sine"
        case .triangle: return "Triangle"
        case .saw:      return "Saw"
        case .square:   return "Square"
        case .random:   return "Random (S&H)"
        }
    }
}

// MARK: - LFO State

/// Mutable state for a single LFO modulation source.
///
/// Each LFO generates a periodic signal with configurable shape,
/// rate, phase offset, and BPM synchronization.
struct LFOState: Identifiable {
    let id: Int
    let index: Int

    /// Waveform shape
    var shape: LFOShape = .sine

    /// Oscillation rate in Hz (when not BPM-synced)
    var rateHz: Float = 1.0

    /// Whether to sync rate to the detected BPM
    var bpmSync: Bool = false

    /// BPM sync division (1 = whole note, 2 = half, 4 = quarter, etc.)
    var bpmDivision: Float = 4.0

    /// Phase offset (0-1)
    var phaseOffset: Float = 0.0

    /// Current phase accumulator (0-1)
    var phase: Float = 0.0

    /// Current output value (-1 to +1)
    var output: Float = 0.0

    /// Held random value (for sample-and-hold shape)
    var randomValue: Float = 0.0

    /// Whether this LFO is active
    var isEnabled: Bool = true

    init(index: Int) {
        self.id = index
        self.index = index
    }

    /// Advance the LFO phase by one frame and compute output.
    ///
    /// - Parameters:
    ///   - deltaTime: Time since last frame in seconds
    ///   - tempo: Current detected BPM (used when bpmSync is true)
    mutating func tick(deltaTime: Float, tempo: Float) {
        guard isEnabled else {
            output = 0
            return
        }

        // Compute effective rate
        let effectiveRate: Float
        if bpmSync && tempo > 0 {
            // Sync to tempo: bpmDivision beats per cycle
            effectiveRate = (tempo / 60.0) / bpmDivision
        } else {
            effectiveRate = rateHz
        }

        // Advance phase
        let previousPhase = phase
        phase += effectiveRate * deltaTime
        phase = phase - Float(Int(phase)) // Wrap 0-1

        // Apply phase offset for output computation
        var p = phase + phaseOffset
        p = p - Float(Int(p))
        if p < 0 { p += 1.0 }

        // Generate waveform
        switch shape {
        case .sine:
            output = sin(p * 2.0 * .pi)

        case .triangle:
            // Triangle: ramp up 0-0.5, ramp down 0.5-1.0
            output = p < 0.5
                ? (p * 4.0 - 1.0)
                : (3.0 - p * 4.0)

        case .saw:
            // Sawtooth: ramp from -1 to +1
            output = p * 2.0 - 1.0

        case .square:
            // Square: -1 or +1
            output = p < 0.5 ? 1.0 : -1.0

        case .random:
            // Sample and hold: new random value each cycle
            if phase < previousPhase {
                // Phase wrapped around, generate new value
                randomValue = Float.random(in: -1...1)
            }
            output = randomValue
        }
    }
}

// MARK: - Envelope State

/// Mutable state for a single ADSR envelope generator.
///
/// Envelope generators produce a shaped signal in response to
/// gate events (MIDI note on/off, beat detection).
struct VisualEnvelopeState: Identifiable {
    let id: Int
    let index: Int

    /// Attack time in seconds
    var attack: Float = 0.01

    /// Decay time in seconds
    var decay: Float = 0.1

    /// Sustain level (0-1)
    var sustain: Float = 0.7

    /// Release time in seconds
    var release: Float = 0.3

    /// Trigger source for this envelope
    var triggerSource: EnvelopeTrigger = .midiNoteOn

    /// Current envelope stage
    var stage: EnvelopeStage = .idle

    /// Current output value (0-1)
    var output: Float = 0.0

    /// Whether the gate is currently held open
    var gateOpen: Bool = false

    /// Time spent in the current stage
    var stageTime: Float = 0.0

    /// Value at the start of the current stage (for smooth transitions)
    var stageStartValue: Float = 0.0

    /// Whether this envelope is active
    var isEnabled: Bool = true

    /// Envelope stages
    enum EnvelopeStage: String, Sendable {
        case idle
        case attack
        case decay
        case sustaining
        case release
    }

    /// Trigger sources for the envelope gate
    enum EnvelopeTrigger: String, CaseIterable, Identifiable, Codable, Sendable {
        case midiNoteOn = "MIDI Note On"
        case beatDetection = "Beat Detection"
        case manual = "Manual"

        var id: String { rawValue }
    }

    init(index: Int) {
        self.id = index
        self.index = index
    }

    /// Open the gate (trigger attack phase).
    mutating func gateOn() {
        gateOpen = true
        stageStartValue = output
        stageTime = 0
        stage = .attack
    }

    /// Close the gate (trigger release phase).
    mutating func gateOff() {
        guard gateOpen else { return }
        gateOpen = false
        stageStartValue = output
        stageTime = 0
        stage = .release
    }

    /// Advance the envelope by one frame.
    ///
    /// - Parameter deltaTime: Time since last frame in seconds
    mutating func tick(deltaTime: Float) {
        guard isEnabled else {
            output = 0
            return
        }

        stageTime += deltaTime

        switch stage {
        case .idle:
            output = 0

        case .attack:
            if attack <= 0.001 {
                output = 1.0
                stage = .decay
                stageTime = 0
                stageStartValue = 1.0
            } else {
                let progress = Swift.min(1.0, stageTime / attack)
                output = stageStartValue + (1.0 - stageStartValue) * progress
                if progress >= 1.0 {
                    stage = .decay
                    stageTime = 0
                    stageStartValue = 1.0
                }
            }

        case .decay:
            if decay <= 0.001 {
                output = sustain
                stage = .sustaining
                stageTime = 0
                stageStartValue = sustain
            } else {
                let progress = Swift.min(1.0, stageTime / decay)
                output = stageStartValue + (sustain - stageStartValue) * progress
                if progress >= 1.0 {
                    stage = .sustaining
                    stageTime = 0
                    stageStartValue = sustain
                }
            }

        case .sustaining:
            output = sustain

        case .release:
            if release <= 0.001 {
                output = 0
                stage = .idle
            } else {
                let progress = Swift.min(1.0, stageTime / release)
                output = stageStartValue * (1.0 - progress)
                if progress >= 1.0 {
                    output = 0
                    stage = .idle
                }
            }
        }
    }
}

// MARK: - Audio Modulator Mode

/// Operating mode for audio modulator sources.
enum AudioModulatorMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Peak detection with configurable threshold
    case peak = "Peak"

    /// Frequency band energy extraction
    case frequencyBand = "Frequency Band"

    var id: String { rawValue }
}

// MARK: - Audio Modulator State

/// Mutable state for a single audio modulator source.
///
/// Audio modulators extract amplitude or frequency band information
/// from the incoming audio signal and produce a modulation value.
struct AudioModulatorState: Identifiable {
    let id: Int
    let index: Int

    /// Operating mode
    var mode: AudioModulatorMode = .peak

    /// Threshold for peak mode (0-1). Signal must exceed this to produce output.
    var threshold: Float = 0.1

    /// Low frequency bound for frequency band mode (Hz)
    var bandLowHz: Float = 20

    /// High frequency bound for frequency band mode (Hz)
    var bandHighHz: Float = 200

    /// Attack smoothing time in seconds (how fast the output rises)
    var attackTime: Float = 0.005

    /// Release smoothing time in seconds (how fast the output falls)
    var releaseTime: Float = 0.05

    /// Current output value (0-1)
    var output: Float = 0.0

    /// Whether this audio modulator is active
    var isEnabled: Bool = true

    /// Smoothed envelope follower value
    private var smoothedValue: Float = 0.0

    init(index: Int) {
        self.id = index
        self.index = index

        // Set default band ranges per index
        switch index {
        case 0:
            bandLowHz = 20
            bandHighHz = 200     // Sub-bass + bass
        case 1:
            bandLowHz = 200
            bandHighHz = 2000    // Mids
        case 2:
            bandLowHz = 2000
            bandHighHz = 8000    // Highs
        case 3:
            bandLowHz = 8000
            bandHighHz = 20000   // Air
        default:
            break
        }
    }

    /// Process the current audio analysis data and produce output.
    ///
    /// - Parameters:
    ///   - audioLevel: Overall audio RMS level (0-1)
    ///   - spectrumData: FFT spectrum data (64 bands, 20-20kHz log-spaced)
    ///   - deltaTime: Time since last frame in seconds
    mutating func tick(audioLevel: Float, spectrumData: [Float], deltaTime: Float) {
        guard isEnabled else {
            output = 0
            return
        }

        let rawValue: Float

        switch mode {
        case .peak:
            // Peak detection with threshold
            rawValue = audioLevel > threshold
                ? (audioLevel - threshold) / (1.0 - threshold)
                : 0.0

        case .frequencyBand:
            // Extract energy from frequency band
            rawValue = extractBandEnergy(from: spectrumData)
        }

        // Envelope follower with asymmetric attack/release
        let targetCoeff: Float
        if rawValue > smoothedValue {
            // Attack
            if attackTime > 0 {
                let exponent: Float = -deltaTime / attackTime
                targetCoeff = 1.0 - Foundation.exp(exponent)
            } else {
                targetCoeff = 1.0
            }
        } else {
            // Release
            if releaseTime > 0 {
                let exponent: Float = -deltaTime / releaseTime
                targetCoeff = 1.0 - Foundation.exp(exponent)
            } else {
                targetCoeff = 1.0
            }
        }

        smoothedValue += (rawValue - smoothedValue) * targetCoeff
        output = Swift.max(0, Swift.min(1, smoothedValue))
    }

    /// Extract energy from the configured frequency band within the
    /// 64-band log-spaced spectrum data.
    private func extractBandEnergy(from spectrumData: [Float]) -> Float {
        guard !spectrumData.isEmpty else { return 0 }

        let bandCount = spectrumData.count
        let minFreq: Float = 20
        let maxFreq: Float = 20000
        let freqRatio = maxFreq / minFreq

        // Find band indices that correspond to our frequency range
        let lowBand = Float(bandCount) * Foundation.log(bandLowHz / minFreq) / Foundation.log(freqRatio)
        let highBand = Float(bandCount) * Foundation.log(bandHighHz / minFreq) / Foundation.log(freqRatio)

        let lowIndex = Swift.max(0, Int(lowBand))
        let highIndex = Swift.min(bandCount - 1, Int(highBand))

        guard highIndex >= lowIndex else { return 0 }

        // Average the magnitudes in our band range
        var sum: Float = 0
        for i in lowIndex...highIndex {
            sum += spectrumData[i]
        }
        let count = Float(highIndex - lowIndex + 1)
        return count > 0 ? sum / count : 0
    }
}

// MARK: - MIDI State

/// Current MIDI input state used by MIDI modulation sources.
struct MIDIModulationState {
    /// Most recent note number (0-127)
    var note: UInt8 = 60

    /// Most recent velocity (0-1)
    var velocity: Float = 0

    /// Channel aftertouch (0-1)
    var aftertouch: Float = 0

    /// Pitch bend (-1 to +1)
    var pitchBend: Float = 0

    /// Whether a note is currently held
    var noteOn: Bool = false

    /// CC values keyed by controller number (0-1)
    var ccValues: [UInt8: Float] = [:]
}

// MARK: - Modulation Route

/// A single modulation routing from a source to a per-layer destination.
///
/// Multiple routes can target the same destination; their contributions
/// are summed before applying to the layer parameter.
struct ModulationRoute: Identifiable, Equatable {
    /// Unique route identifier
    let id: UUID

    /// The modulation source producing the signal
    var source: ModulationSourceID

    /// The target layer UUID (nil = all layers)
    var targetLayerID: UUID?

    /// The target parameter on the layer
    var destination: ModulationDestination

    /// Modulation amount (-1 to +1).
    /// Positive values map source output directly.
    /// Negative values invert the source signal.
    var amount: Float

    /// Curve shaping applied to the source signal before scaling
    var curve: ModulationCurve

    /// Whether this route is active
    var isEnabled: Bool

    init(
        source: ModulationSourceID,
        targetLayerID: UUID? = nil,
        destination: ModulationDestination,
        amount: Float = 0.5,
        curve: ModulationCurve = .linear,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.source = source
        self.targetLayerID = targetLayerID
        self.destination = destination
        self.amount = Swift.max(-1, Swift.min(1, amount))
        self.curve = curve
        self.isEnabled = isEnabled
    }

    static func == (lhs: ModulationRoute, rhs: ModulationRoute) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Visual Modulation Matrix

/// Synthesizer-style modulation matrix for the visual compositor.
///
/// Manages modulation sources (LFOs, envelopes, audio, bio, MIDI),
/// routes them to per-layer visual parameter destinations with
/// configurable amount and curve shaping, and produces per-layer
/// offset dictionaries at 60 Hz.
///
/// ## Usage
///
/// ```swift
/// let matrix = VisualModulationMatrix()
/// // Route LFO 1 to all layers' hue with sine wave at 0.5 Hz
/// matrix.lfoStates[0].shape = .sine
/// matrix.lfoStates[0].rateHz = 0.5
/// matrix.addRoute(
///     source: .lfo(index: 0),
///     destination: .hue,
///     amount: 0.3
/// )
/// matrix.start()
/// ```
///
/// ## Integration with EchoelVisualCompositor
///
/// Each frame, after processing all routes, the matrix calls
/// ``EchoelVisualCompositor/applyModulationOffsets(_:for:)``
/// for each layer that has active modulation targets.
@MainActor
class VisualModulationMatrix: ObservableObject {

    // MARK: - Published State

    /// The 4 LFO source states
    @Published var lfoStates: [LFOState]

    /// The 2 envelope generator states
    @Published var envelopeStates: [VisualEnvelopeState]

    /// The 4 audio modulator states
    @Published var audioModulatorStates: [AudioModulatorState]

    /// All modulation routes
    @Published var routes: [ModulationRoute] = []

    /// Per-layer computed modulation offsets.
    /// Key: layer UUID, Value: destination name to offset value
    @Published private(set) var modulatedValues: [UUID: [String: Float]] = [:]

    /// Whether the modulation matrix is running
    @Published private(set) var isRunning: Bool = false

    // MARK: - MIDI State

    /// Current MIDI input state
    var midiState = MIDIModulationState()

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: AnyCancellable?
    private var lastTickTime: Date = Date()

    /// Weak reference to the compositor for applying modulation
    private weak var compositor: EchoelVisualCompositor?

    // MARK: - Configuration

    /// Target update rate in Hz
    static let targetUpdateRate: Double = 60.0

    /// Maximum number of modulation routes
    static let maxRouteCount: Int = 64

    // MARK: - Initialization

    /// Create a new modulation matrix.
    ///
    /// - Parameter compositor: Optional reference to the visual compositor
    ///   that receives modulation offsets. Can be set later via
    ///   ``attachCompositor(_:)``.
    init(compositor: EchoelVisualCompositor? = nil) {
        self.compositor = compositor

        // Initialize 4 LFOs with staggered default rates
        self.lfoStates = (0..<4).map { i in
            var lfo = LFOState(index: i)
            lfo.rateHz = [0.5, 1.0, 2.0, 0.25][i]
            lfo.shape = [.sine, .triangle, .saw, .sine][i]
            lfo.isEnabled = false // Disabled by default until configured
            return lfo
        }

        // Initialize 2 envelopes
        self.envelopeStates = (0..<2).map { i in
            var env = VisualEnvelopeState(index: i)
            env.triggerSource = i == 0 ? .midiNoteOn : .beatDetection
            env.isEnabled = false
            return env
        }

        // Initialize 4 audio modulators with different frequency bands
        self.audioModulatorStates = (0..<4).map { i in
            var mod = AudioModulatorState(index: i)
            mod.isEnabled = false
            return mod
        }

        log.log(.info, category: .video, "VisualModulationMatrix initialized (4 LFOs, 2 ENVs, 4 Audio Mods)")
    }

    // MARK: - Compositor Binding

    /// Attach a visual compositor to receive modulation offsets.
    ///
    /// - Parameter compositor: The compositor instance
    func attachCompositor(_ compositor: EchoelVisualCompositor) {
        self.compositor = compositor
        log.log(.info, category: .video, "Modulation matrix attached to compositor")
    }

    // MARK: - Lifecycle

    /// Start the 60 Hz modulation processing loop.
    func start() {
        guard !isRunning else { return }

        lastTickTime = Date()
        isRunning = true

        updateTimer = Timer.publish(
            every: 1.0 / Self.targetUpdateRate,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.tick()
        }

        log.log(.info, category: .video, "VisualModulationMatrix started at \(Int(Self.targetUpdateRate)) Hz")
    }

    /// Stop the modulation processing loop.
    func stop() {
        guard isRunning else { return }

        updateTimer?.cancel()
        updateTimer = nil
        isRunning = false

        // Clear all modulation from compositor
        compositor?.clearAllModulation()
        modulatedValues.removeAll()

        log.log(.info, category: .video, "VisualModulationMatrix stopped")
    }

    // MARK: - Route Management

    /// Add a new modulation route.
    ///
    /// - Parameters:
    ///   - source: Modulation source identifier
    ///   - targetLayerID: Target layer UUID (nil = all layers)
    ///   - destination: Target parameter
    ///   - amount: Modulation amount (-1 to +1)
    ///   - curve: Signal shaping curve
    /// - Returns: The created route, or `nil` if the route limit is reached.
    @discardableResult
    func addRoute(
        source: ModulationSourceID,
        targetLayerID: UUID? = nil,
        destination: ModulationDestination,
        amount: Float = 0.5,
        curve: ModulationCurve = .linear
    ) -> ModulationRoute? {
        guard routes.count < Self.maxRouteCount else {
            log.log(.warning, category: .video,
                     "Cannot add route: maximum of \(Self.maxRouteCount) routes reached")
            return nil
        }

        let route = ModulationRoute(
            source: source,
            targetLayerID: targetLayerID,
            destination: destination,
            amount: amount,
            curve: curve
        )
        routes.append(route)

        log.log(.info, category: .video,
                 "Added mod route: \(source.displayName) -> \(destination.displayName) (amount: \(String(format: "%.2f", amount)))")
        return route
    }

    /// Remove a modulation route by its UUID.
    ///
    /// - Parameter id: The route's unique identifier
    /// - Returns: `true` if the route was found and removed
    @discardableResult
    func removeRoute(id: UUID) -> Bool {
        guard let index = routes.firstIndex(where: { $0.id == id }) else {
            return false
        }
        routes.remove(at: index)
        return true
    }

    /// Remove all routes targeting a specific layer.
    ///
    /// - Parameter layerID: The target layer UUID
    func removeRoutesForLayer(_ layerID: UUID) {
        routes.removeAll { $0.targetLayerID == layerID }
    }

    /// Remove all modulation routes.
    func clearAllRoutes() {
        routes.removeAll()
        modulatedValues.removeAll()
        compositor?.clearAllModulation()
        log.log(.info, category: .video, "All modulation routes cleared")
    }

    /// Set the amount for an existing route.
    ///
    /// - Parameters:
    ///   - amount: New amount value (-1 to +1)
    ///   - routeID: UUID of the route to update
    func setRouteAmount(_ amount: Float, for routeID: UUID) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        routes[index].amount = Swift.max(-1, Swift.min(1, amount))
    }

    /// Set the curve for an existing route.
    ///
    /// - Parameters:
    ///   - curve: New curve type
    ///   - routeID: UUID of the route to update
    func setRouteCurve(_ curve: ModulationCurve, for routeID: UUID) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        routes[index].curve = curve
    }

    /// Enable or disable a route.
    ///
    /// - Parameters:
    ///   - enabled: Whether the route should be active
    ///   - routeID: UUID of the route to update
    func setRouteEnabled(_ enabled: Bool, for routeID: UUID) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        routes[index].isEnabled = enabled
    }

    // MARK: - MIDI Input

    /// Process a MIDI note on event.
    ///
    /// Updates the MIDI state and triggers any envelopes set to
    /// ``VisualEnvelopeState/EnvelopeTrigger/midiNoteOn``.
    ///
    /// - Parameters:
    ///   - note: MIDI note number (0-127)
    ///   - velocity: Velocity (0-127, normalized internally)
    func handleMIDINoteOn(note: UInt8, velocity: UInt8) {
        midiState.note = note
        midiState.velocity = Float(velocity) / 127.0
        midiState.noteOn = true

        // Trigger MIDI-triggered envelopes
        for i in envelopeStates.indices {
            if envelopeStates[i].triggerSource == .midiNoteOn && envelopeStates[i].isEnabled {
                envelopeStates[i].gateOn()
            }
        }
    }

    /// Process a MIDI note off event.
    ///
    /// - Parameter note: MIDI note number (0-127)
    func handleMIDINoteOff(note: UInt8) {
        if midiState.note == note {
            midiState.noteOn = false

            // Release MIDI-triggered envelopes
            for i in envelopeStates.indices {
                if envelopeStates[i].triggerSource == .midiNoteOn && envelopeStates[i].isEnabled {
                    envelopeStates[i].gateOff()
                }
            }
        }
    }

    /// Process a MIDI aftertouch event.
    ///
    /// - Parameter pressure: Aftertouch pressure (0-127, normalized internally)
    func handleMIDIAftertouch(pressure: UInt8) {
        midiState.aftertouch = Float(pressure) / 127.0
    }

    /// Process a MIDI pitch bend event.
    ///
    /// - Parameter value: Pitch bend value (0-16383, 8192 = center)
    func handleMIDIPitchBend(value: UInt16) {
        midiState.pitchBend = (Float(value) - 8192.0) / 8192.0
    }

    /// Process a MIDI CC event.
    ///
    /// - Parameters:
    ///   - controller: CC number (0-127)
    ///   - value: CC value (0-127, normalized internally)
    func handleMIDICC(controller: UInt8, value: UInt8) {
        midiState.ccValues[controller] = Float(value) / 127.0
    }

    // MARK: - Processing

    /// The core 60 Hz tick that processes all modulation sources and routes.
    private func tick() {
        let now = Date()
        let deltaTime = Float(now.timeIntervalSince(lastTickTime))
        lastTickTime = now

        guard let compositor = compositor else { return }

        let bioSnapshot = compositor.bioSnapshot

        // 1. Advance LFOs
        for i in lfoStates.indices {
            lfoStates[i].tick(deltaTime: deltaTime, tempo: bioSnapshot.tempo)
        }

        // 2. Process beat-triggered envelopes
        if bioSnapshot.beatDetected {
            for i in envelopeStates.indices {
                if envelopeStates[i].triggerSource == .beatDetection && envelopeStates[i].isEnabled {
                    envelopeStates[i].gateOn()
                    // Auto-release after a short gate time
                    let envelopeIndex = i
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                        self?.envelopeStates[envelopeIndex].gateOff()
                    }
                }
            }
        }

        // 3. Advance envelopes
        for i in envelopeStates.indices {
            envelopeStates[i].tick(deltaTime: deltaTime)
        }

        // 4. Process audio modulators
        for i in audioModulatorStates.indices {
            audioModulatorStates[i].tick(
                audioLevel: bioSnapshot.audioLevel,
                spectrumData: bioSnapshot.spectrumData,
                deltaTime: deltaTime
            )
        }

        // 5. Evaluate all routes and accumulate per-layer offsets
        var layerOffsets: [UUID: [String: Float]] = [:]

        // Collect layer IDs to process
        let layerIDs = compositor.layers.map(\.id)

        for route in routes {
            guard route.isEnabled else { continue }

            // Get source value
            let sourceValue = getSourceValue(for: route.source, bioSnapshot: bioSnapshot)

            // Apply curve shaping
            let shapedValue = route.curve.apply(sourceValue)

            // Scale by amount and destination range
            let scaledValue = shapedValue * route.amount * route.destination.defaultRange

            // Determine target layers
            let targetIDs: [UUID]
            if let specificID = route.targetLayerID {
                targetIDs = [specificID]
            } else {
                targetIDs = layerIDs
            }

            // Accumulate offset for each target layer
            for layerID in targetIDs {
                let destKey = route.destination.rawValue
                let current = layerOffsets[layerID]?[destKey] ?? 0
                if layerOffsets[layerID] == nil {
                    layerOffsets[layerID] = [:]
                }
                layerOffsets[layerID]?[destKey] = current + scaledValue
            }
        }

        // 6. Apply offsets to compositor
        modulatedValues = layerOffsets

        for (layerID, offsets) in layerOffsets {
            compositor.applyModulationOffsets(offsets, for: layerID)
        }

        // Clear offsets for layers with no active routes
        for layerID in layerIDs where layerOffsets[layerID] == nil {
            compositor.applyModulationOffsets([:], for: layerID)
        }
    }

    /// Retrieve the current output value for a modulation source.
    ///
    /// - Parameters:
    ///   - source: The modulation source identifier
    ///   - bioSnapshot: Current bio-reactive data snapshot
    /// - Returns: Source output value (typically -1 to +1 or 0 to +1)
    private func getSourceValue(for source: ModulationSourceID, bioSnapshot: BioReactiveSnapshot) -> Float {
        switch source {
        // LFOs: bipolar output (-1 to +1)
        case .lfo(let index):
            guard index >= 0, index < lfoStates.count else { return 0 }
            return lfoStates[index].output

        // Envelopes: unipolar output (0 to 1)
        case .envelope(let index):
            guard index >= 0, index < envelopeStates.count else { return 0 }
            return envelopeStates[index].output

        // Audio modulators: unipolar output (0 to 1)
        case .audioModulator(let index):
            guard index >= 0, index < audioModulatorStates.count else { return 0 }
            return audioModulatorStates[index].output

        // Bio sources: unipolar (0 to 1)
        case .bioCoherence:
            return bioSnapshot.coherence

        case .bioHeartRate:
            // Normalize heart rate: 40-200 BPM -> 0-1
            return Swift.max(0, Swift.min(1, (bioSnapshot.heartRate - 40.0) / 160.0))

        case .bioBreathPhase:
            return bioSnapshot.breathPhase

        case .bioHRVRaw:
            // HRV raw maps similarly to coherence for now
            return bioSnapshot.coherence

        // MIDI sources
        case .midiNote:
            // Normalize note: 0-127 -> 0-1
            return Float(midiState.note) / 127.0

        case .midiVelocity:
            return midiState.velocity

        case .midiAftertouch:
            return midiState.aftertouch

        case .midiPitchBend:
            // Already -1 to +1
            return midiState.pitchBend

        case .midiCC(let number):
            return midiState.ccValues[number] ?? 0
        }
    }

    // MARK: - Presets

    /// Apply a modulation preset that configures sources and routes.
    ///
    /// - Parameter preset: The preset to apply
    func applyPreset(_ preset: ModulationPreset) {
        clearAllRoutes()

        switch preset {
        case .subtleBreathing:
            // Gentle breathing modulation on opacity and scale
            lfoStates[0].shape = .sine
            lfoStates[0].rateHz = 0.15
            lfoStates[0].isEnabled = true
            addRoute(source: .lfo(index: 0), destination: .opacity, amount: 0.15, curve: .sCurve)
            addRoute(source: .lfo(index: 0), destination: .scale, amount: 0.05, curve: .sCurve)
            addRoute(source: .bioBreathPhase, destination: .brightness, amount: 0.2, curve: .sCurve)

        case .audioReactive:
            // Full audio reactivity
            audioModulatorStates[0].mode = .peak
            audioModulatorStates[0].isEnabled = true
            audioModulatorStates[1].mode = .frequencyBand
            audioModulatorStates[1].bandLowHz = 20
            audioModulatorStates[1].bandHighHz = 200
            audioModulatorStates[1].isEnabled = true
            audioModulatorStates[2].mode = .frequencyBand
            audioModulatorStates[2].bandLowHz = 2000
            audioModulatorStates[2].bandHighHz = 8000
            audioModulatorStates[2].isEnabled = true

            addRoute(source: .audioModulator(index: 0), destination: .brightness, amount: 0.6, curve: .exponential)
            addRoute(source: .audioModulator(index: 1), destination: .scale, amount: 0.3, curve: .logarithmic)
            addRoute(source: .audioModulator(index: 2), destination: .hue, amount: 0.2, curve: .linear)

            // Beat-triggered envelope
            envelopeStates[0].attack = 0.01
            envelopeStates[0].decay = 0.2
            envelopeStates[0].sustain = 0.0
            envelopeStates[0].release = 0.3
            envelopeStates[0].triggerSource = .beatDetection
            envelopeStates[0].isEnabled = true
            addRoute(source: .envelope(index: 0), destination: .opacity, amount: 0.4, curve: .exponential)

        case .bioCoherenceMapping:
            // Map coherence and heart rate to visual parameters
            addRoute(source: .bioCoherence, destination: .saturation, amount: 0.5, curve: .sCurve)
            addRoute(source: .bioCoherence, destination: .complexity, amount: 0.4, curve: .linear)
            addRoute(source: .bioHeartRate, destination: .speed, amount: 0.3, curve: .logarithmic)
            addRoute(source: .bioBreathPhase, destination: .scale, amount: 0.1, curve: .sCurve)

        case .midiPerformance:
            // MIDI note and velocity drive visuals
            addRoute(source: .midiNote, destination: .hue, amount: 0.8, curve: .linear)
            addRoute(source: .midiVelocity, destination: .brightness, amount: 0.6, curve: .exponential)
            addRoute(source: .midiAftertouch, destination: .complexity, amount: 0.4, curve: .sCurve)
            addRoute(source: .midiPitchBend, destination: .positionX, amount: 0.3, curve: .linear)

            // Velocity envelope
            envelopeStates[0].attack = 0.005
            envelopeStates[0].decay = 0.3
            envelopeStates[0].sustain = 0.5
            envelopeStates[0].release = 0.5
            envelopeStates[0].triggerSource = .midiNoteOn
            envelopeStates[0].isEnabled = true
            addRoute(source: .envelope(index: 0), destination: .opacity, amount: 0.5, curve: .sCurve)

        case .psychedelicLFO:
            // Multiple LFOs creating complex modulation
            lfoStates[0].shape = .sine
            lfoStates[0].rateHz = 0.3
            lfoStates[0].isEnabled = true

            lfoStates[1].shape = .triangle
            lfoStates[1].rateHz = 0.7
            lfoStates[1].phaseOffset = 0.25
            lfoStates[1].isEnabled = true

            lfoStates[2].shape = .saw
            lfoStates[2].rateHz = 0.1
            lfoStates[2].isEnabled = true

            lfoStates[3].shape = .sine
            lfoStates[3].rateHz = 1.5
            lfoStates[3].phaseOffset = 0.5
            lfoStates[3].isEnabled = true

            addRoute(source: .lfo(index: 0), destination: .hue, amount: 0.5, curve: .linear)
            addRoute(source: .lfo(index: 1), destination: .rotation, amount: 0.3, curve: .sCurve)
            addRoute(source: .lfo(index: 2), destination: .positionX, amount: 0.2, curve: .linear)
            addRoute(source: .lfo(index: 2), destination: .positionY, amount: 0.2, curve: .linear)
            addRoute(source: .lfo(index: 3), destination: .scale, amount: 0.15, curve: .sCurve)
            addRoute(source: .lfo(index: 0), destination: .complexity, amount: 0.3, curve: .exponential)
        }

        log.log(.info, category: .video, "Applied modulation preset: \(preset.rawValue)")
    }

    // MARK: - Query

    /// Get all routes targeting a specific layer.
    ///
    /// - Parameter layerID: The layer UUID
    /// - Returns: Array of routes targeting the layer (or all layers)
    func routes(for layerID: UUID) -> [ModulationRoute] {
        routes.filter { $0.targetLayerID == nil || $0.targetLayerID == layerID }
    }

    /// Get the total number of active (enabled) routes.
    var activeRouteCount: Int {
        routes.filter(\.isEnabled).count
    }

    // MARK: - Debug

    /// Multi-line debug summary of the modulation matrix state.
    var debugDescription: String {
        var lines: [String] = []
        lines.append("VisualModulationMatrix (\(isRunning ? "running" : "stopped"))")
        lines.append("  LFOs:")
        for lfo in lfoStates {
            let status = lfo.isEnabled ? "on" : "off"
            lines.append("    [\(lfo.index)] \(lfo.shape.displayName) \(String(format: "%.2f", lfo.rateHz)) Hz "
                       + "| out=\(String(format: "%.3f", lfo.output)) [\(status)]")
        }
        lines.append("  Envelopes:")
        for env in envelopeStates {
            let status = env.isEnabled ? "on" : "off"
            lines.append("    [\(env.index)] \(env.stage.rawValue) "
                       + "ADSR=\(String(format: "%.2f/%.2f/%.2f/%.2f", env.attack, env.decay, env.sustain, env.release)) "
                       + "| out=\(String(format: "%.3f", env.output)) [\(status)]")
        }
        lines.append("  Audio Modulators:")
        for mod in audioModulatorStates {
            let status = mod.isEnabled ? "on" : "off"
            lines.append("    [\(mod.index)] \(mod.mode.rawValue) "
                       + "| out=\(String(format: "%.3f", mod.output)) [\(status)]")
        }
        lines.append("  Routes: \(routes.count) total, \(activeRouteCount) active")
        for route in routes {
            let target = route.targetLayerID?.uuidString.prefix(8) ?? "ALL"
            let status = route.isEnabled ? "on" : "off"
            lines.append("    \(route.source.displayName) -> \(route.destination.displayName) "
                       + "| amt=\(String(format: "%.2f", route.amount)) "
                       + "| curve=\(route.curve.rawValue) "
                       + "| target=\(target) [\(status)]")
        }
        lines.append("  MIDI: note=\(midiState.note) vel=\(String(format: "%.2f", midiState.velocity)) "
                    + "at=\(String(format: "%.2f", midiState.aftertouch)) "
                    + "pb=\(String(format: "%.2f", midiState.pitchBend))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Modulation Preset

/// Built-in modulation presets that configure sources and routes
/// for common visual modulation patterns.
enum ModulationPreset: String, CaseIterable, Identifiable {
    case subtleBreathing = "Subtle Breathing"
    case audioReactive = "Audio Reactive"
    case bioCoherenceMapping = "Bio Coherence Mapping"
    case midiPerformance = "MIDI Performance"
    case psychedelicLFO = "Psychedelic LFO"

    var id: String { rawValue }

    /// Short description of the preset
    var description: String {
        switch self {
        case .subtleBreathing:      return "Gentle breathing modulation on opacity and scale"
        case .audioReactive:        return "Full audio reactivity with beat-triggered envelopes"
        case .bioCoherenceMapping:  return "Coherence and heart rate mapped to visual complexity"
        case .midiPerformance:      return "MIDI note, velocity, and aftertouch drive visuals"
        case .psychedelicLFO:       return "Multiple LFOs creating complex visual motion"
        }
    }
}
