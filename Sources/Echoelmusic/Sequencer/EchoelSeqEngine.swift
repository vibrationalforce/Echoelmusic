#if canImport(AVFoundation)
// EchoelSeqEngine.swift — Professional Audio Step Sequencer
// Pattern-based sequencing with bio-reactive modulation, MIDI output,
// Euclidean rhythms, swing, polyrhythm, and pattern chaining.

import Foundation
import AVFoundation
import Observation
import Combine

// MARK: - Audio Step

/// A single step in an audio sequencer pattern
public struct AudioStep: Codable, Equatable, Sendable {
    public var isActive: Bool = false
    public var velocity: Float = 1.0
    public var pitchOffset: Int = 0           // Semitones (-24 to +24)
    public var gateLength: Float = 0.5        // 0-1 (proportion of step duration)
    public var probability: Float = 1.0       // 0-1 (chance of triggering)
    public var microTiming: Float = 0.0       // -0.5 to +0.5 (swing/humanize)
    public var conditionMask: UInt8 = 0xFF    // Step condition (every N, fill, etc.)

    public init() {}

    public init(active: Bool, velocity: Float = 1.0) {
        self.isActive = active
        self.velocity = velocity
    }
}

// MARK: - Audio Pattern

/// A multi-track audio sequencer pattern
public struct AudioPattern: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var tracks: [PatternTrack]
    public var stepCount: Int
    public var swingAmount: Float          // 0 = straight, 1 = full triplet swing
    public var scaleRoot: Int              // MIDI note number (0-11)
    public var scaleType: ScaleType

    public init(
        name: String = "Pattern",
        trackCount: Int = 8,
        stepCount: Int = 16
    ) {
        self.id = UUID()
        self.name = name
        self.stepCount = stepCount
        self.swingAmount = 0.0
        self.scaleRoot = 0 // C
        self.scaleType = .chromatic
        self.tracks = (0..<trackCount).map { i in
            PatternTrack(name: "Track \(i + 1)", steps: Array(repeating: AudioStep(), count: stepCount))
        }
    }

    /// Get step for a track at position
    public func step(track: Int, position: Int) -> AudioStep {
        guard track < tracks.count, position < tracks[track].steps.count else {
            return AudioStep()
        }
        return tracks[track].steps[position]
    }

    /// Set step for a track at position
    public mutating func setStep(track: Int, position: Int, step: AudioStep) {
        guard track < tracks.count, position < tracks[track].steps.count else { return }
        tracks[track].steps[position] = step
    }

    /// Toggle step active state
    public mutating func toggleStep(track: Int, position: Int) {
        guard track < tracks.count, position < tracks[track].steps.count else { return }
        tracks[track].steps[position].isActive.toggle()
    }
}

// MARK: - Pattern Track

/// A single track within a pattern
public struct PatternTrack: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var steps: [AudioStep]
    public var midiChannel: UInt8 = 0
    public var midiNote: UInt8 = 36       // Default: C2 (kick drum)
    public var isMuted: Bool = false
    public var volume: Float = 1.0
    public var pan: Float = 0.0           // -1 left, 0 center, +1 right
    public var polyrhythmLength: Int?     // nil = use pattern stepCount

    public init(name: String, steps: [AudioStep]) {
        self.id = UUID()
        self.name = name
        self.steps = steps
    }

    /// Effective step count (polyrhythm or pattern default)
    public var effectiveStepCount: Int {
        polyrhythmLength ?? steps.count
    }
}

// MARK: - Scale Type

/// Musical scales for pitch quantization
public enum ScaleType: String, CaseIterable, Codable, Sendable {
    case chromatic     = "Chromatic"
    case major         = "Major"
    case minor         = "Minor"
    case dorian        = "Dorian"
    case mixolydian    = "Mixolydian"
    case pentatonic    = "Pentatonic"
    case blues         = "Blues"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor  = "Melodic Minor"
    case wholeTone     = "Whole Tone"
    case phrygian      = "Phrygian"
    case lydian        = "Lydian"

    /// Interval pattern (semitones from root)
    public var intervals: [Int] {
        switch self {
        case .chromatic:     return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .major:         return [0, 2, 4, 5, 7, 9, 11]
        case .minor:         return [0, 2, 3, 5, 7, 8, 10]
        case .dorian:        return [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:    return [0, 2, 4, 5, 7, 9, 10]
        case .pentatonic:    return [0, 2, 4, 7, 9]
        case .blues:         return [0, 3, 5, 6, 7, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:  return [0, 2, 3, 5, 7, 9, 11]
        case .wholeTone:     return [0, 2, 4, 6, 8, 10]
        case .phrygian:      return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:        return [0, 2, 4, 6, 7, 9, 11]
        }
    }

    /// Quantize a MIDI note to the nearest note in this scale
    public func quantize(note: Int, root: Int) -> Int {
        guard self != .chromatic else { return note }
        let octave = (note - root) / 12
        let degree = ((note - root) % 12 + 12) % 12

        // Find nearest scale degree
        var closest = intervals[0]
        var minDist = 12
        for interval in intervals {
            let dist = abs(degree - interval)
            let wrapDist = min(dist, 12 - dist)
            if wrapDist < minDist {
                minDist = wrapDist
                closest = interval
            }
        }

        return root + octave * 12 + closest
    }
}

// MARK: - Pattern Manipulation

/// Operations for transforming patterns
public enum PatternTransform: String, CaseIterable, Sendable {
    case rotateRight   = "Rotate →"
    case rotateLeft    = "Rotate ←"
    case reverse       = "Reverse"
    case invert        = "Invert"
    case doubleSpeed   = "Double Speed"
    case halfSpeed     = "Half Speed"
    case randomize     = "Randomize"
    case euclidean     = "Euclidean"
    case humanize      = "Humanize"
    case clearAll      = "Clear"
}

// MARK: - Pattern Chain

/// A chain of patterns for song arrangement
public struct PatternChain: Codable, Equatable, Sendable {
    public var entries: [ChainEntry]
    public var isLooping: Bool

    public init() {
        self.entries = []
        self.isLooping = true
    }

    public struct ChainEntry: Identifiable, Codable, Equatable, Sendable {
        public let id: UUID
        public var patternID: UUID
        public var repeatCount: Int

        public init(patternID: UUID, repeatCount: Int = 1) {
            self.id = UUID()
            self.patternID = patternID
            self.repeatCount = repeatCount
        }
    }
}

// MARK: - EchoelSeqEngine

/// Professional audio step sequencer with bio-reactive modulation.
///
/// Features:
/// - Multi-track pattern sequencing (up to 16 tracks, 64 steps)
/// - Per-step velocity, pitch, gate, probability, micro-timing
/// - Swing/shuffle with per-step override
/// - Euclidean rhythm generation
/// - Pattern manipulation (rotate, reverse, invert, randomize)
/// - Pattern chaining for song arrangement
/// - Scale-aware pitch quantization (12 scales)
/// - Polyrhythmic tracks (independent step counts)
/// - Bio-reactive modulation (coherence → density, HRV → humanize)
/// - MIDI output via Combine publisher
@preconcurrency @MainActor
@Observable
public final class EchoelSeqEngine {

    // MARK: - Singleton

    @MainActor public static let shared = EchoelSeqEngine()

    // MARK: - State

    public var isPlaying: Bool = false
    public var currentStep: Int = 0
    public var bpm: Double = 120.0
    public var patterns: [AudioPattern] = []
    public var activePatternIndex: Int = 0
    public var chain: PatternChain = PatternChain()
    public var chainPosition: Int = 0
    public var chainRepeatCounter: Int = 0

    // MARK: - Bio-Reactive

    public var bioModulationEnabled: Bool = true
    public var bioCoherence: Float = 0.5
    public var bioHRV: Float = 0.5
    public var bioHeartRate: Float = 72.0
    public var bioBreathPhase: Float = 0.0

    // MARK: - MIDI Output

    /// Published step triggers for MIDI/audio consumers
    public var lastTriggeredSteps: [StepTrigger] = []

    // MARK: - Timing

    private var timer: Timer?
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()

    /// Step interval accounting for swing on even/odd steps
    private func stepInterval(forStep step: Int) -> TimeInterval {
        let baseInterval = 60.0 / max(bpm, 20.0) / 4.0
        guard let pattern = activePattern else { return baseInterval }

        let swing = Double(pattern.swingAmount)
        if step % 2 == 1 && swing > 0 {
            return baseInterval * (1.0 + swing * 0.5)
        } else if step % 2 == 0 && swing > 0 {
            return baseInterval * (1.0 - swing * 0.25)
        }
        return baseInterval
    }

    // MARK: - Computed

    public var activePattern: AudioPattern? {
        guard activePatternIndex < patterns.count else { return nil }
        return patterns[activePatternIndex]
    }

    // MARK: - Init

    private init() {
        // Create default pattern bank
        var kick = AudioPattern(name: "Kick & Snare", trackCount: 4, stepCount: 16)
        kick.tracks[0].name = "Kick"
        kick.tracks[0].midiNote = 36
        kick.tracks[1].name = "Snare"
        kick.tracks[1].midiNote = 38
        kick.tracks[2].name = "Hi-Hat"
        kick.tracks[2].midiNote = 42
        kick.tracks[3].name = "Perc"
        kick.tracks[3].midiNote = 39

        // Four on floor preset
        for step in stride(from: 0, to: 16, by: 4) {
            kick.tracks[0].steps[step].isActive = true
        }
        kick.tracks[1].steps[4].isActive = true
        kick.tracks[1].steps[12].isActive = true
        for step in stride(from: 0, to: 16, by: 2) {
            kick.tracks[2].steps[step].isActive = true
        }

        var ambient = AudioPattern(name: "Ambient", trackCount: 4, stepCount: 32)
        ambient.tracks[0].name = "Pad"
        ambient.tracks[0].midiNote = 60
        ambient.tracks[1].name = "Arp"
        ambient.tracks[1].midiNote = 72
        ambient.tracks[2].name = "Bass"
        ambient.tracks[2].midiNote = 36
        ambient.tracks[3].name = "FX"
        ambient.tracks[3].midiNote = 48
        ambient.tracks[0].steps[0] = AudioStep(active: true)
        ambient.tracks[2].steps[0] = AudioStep(active: true)
        ambient.tracks[2].steps[8] = AudioStep(active: true)

        patterns = [kick, ambient]
    }

    // MARK: - Transport

    public func play() {
        guard !isPlaying else { return }
        isPlaying = true
        scheduleNextStep()
    }

    public func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentStep = 0
        chainPosition = 0
        chainRepeatCounter = 0
    }

    public func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextStep() {
        timer?.invalidate()
        let interval = stepInterval(forStep: currentStep)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceAndTrigger()
            }
        }
    }

    private func advanceAndTrigger() {
        guard isPlaying else { return }

        triggerCurrentStep()
        advanceStep()
        scheduleNextStep()
    }

    // MARK: - Step Triggering

    private func triggerCurrentStep() {
        guard let pattern = activePattern else { return }
        var triggers: [StepTrigger] = []

        for (trackIdx, track) in pattern.tracks.enumerated() {
            guard !track.isMuted else { continue }

            let effectiveStep = currentStep % track.effectiveStepCount
            guard effectiveStep < track.steps.count else { continue }
            let step = track.steps[effectiveStep]
            guard step.isActive else { continue }

            // Probability check
            let prob = bioModulationEnabled
                ? step.probability * (0.5 + bioCoherence * 0.5)
                : step.probability
            guard Float.random(in: 0...1) <= prob else { continue }

            // Velocity with bio modulation
            var velocity = step.velocity * track.volume
            if bioModulationEnabled {
                velocity *= (0.7 + bioCoherence * 0.3)
            }
            velocity = max(0, min(1, velocity))

            // Pitch with scale quantization
            var midiNote = Int(track.midiNote) + step.pitchOffset
            if pattern.scaleType != .chromatic {
                midiNote = pattern.scaleType.quantize(note: midiNote, root: pattern.scaleRoot)
            }
            midiNote = max(0, min(127, midiNote))

            // Micro-timing (applied via humanize bio-modulation)
            var microTiming = step.microTiming
            if bioModulationEnabled {
                microTiming += Float.random(in: -0.05...0.05) * (1.0 - bioHRV)
            }

            triggers.append(StepTrigger(
                trackIndex: trackIdx,
                step: effectiveStep,
                midiNote: UInt8(midiNote),
                midiChannel: track.midiChannel,
                velocity: velocity,
                gateLength: step.gateLength,
                microTiming: microTiming,
                pan: track.pan
            ))
        }

        lastTriggeredSteps = triggers
    }

    private func advanceStep() {
        guard let pattern = activePattern else { return }
        currentStep = (currentStep + 1) % pattern.stepCount

        // Pattern chain advancement
        if currentStep == 0 && !chain.entries.isEmpty {
            advanceChain()
        }
    }

    private func advanceChain() {
        guard !chain.entries.isEmpty else { return }
        guard chainPosition < chain.entries.count else {
            if chain.isLooping {
                chainPosition = 0
                chainRepeatCounter = 0
            } else {
                stop()
            }
            return
        }

        let entry = chain.entries[chainPosition]
        chainRepeatCounter += 1

        if chainRepeatCounter >= entry.repeatCount {
            chainRepeatCounter = 0
            chainPosition += 1

            if chainPosition < chain.entries.count {
                let nextEntry = chain.entries[chainPosition]
                if let idx = patterns.firstIndex(where: { $0.id == nextEntry.patternID }) {
                    activePatternIndex = idx
                }
            } else if chain.isLooping {
                chainPosition = 0
                let firstEntry = chain.entries[0]
                if let idx = patterns.firstIndex(where: { $0.id == firstEntry.patternID }) {
                    activePatternIndex = idx
                }
            }
        }
    }

    // MARK: - Pattern Editing

    /// Apply a transform to a specific track in the active pattern
    public func applyTransform(_ transform: PatternTransform, trackIndex: Int, parameter: Int = 0) {
        guard activePatternIndex < patterns.count,
              trackIndex < patterns[activePatternIndex].tracks.count else { return }

        var steps = patterns[activePatternIndex].tracks[trackIndex].steps

        switch transform {
        case .rotateRight:
            guard !steps.isEmpty else { return }
            let last = steps.removeLast()
            steps.insert(last, at: 0)

        case .rotateLeft:
            guard !steps.isEmpty else { return }
            let first = steps.removeFirst()
            steps.append(first)

        case .reverse:
            steps.reverse()

        case .invert:
            for i in 0..<steps.count {
                steps[i].isActive.toggle()
            }

        case .doubleSpeed:
            var doubled = [AudioStep](repeating: AudioStep(), count: steps.count)
            for i in 0..<steps.count {
                let src = (i * 2) % steps.count
                doubled[i] = steps[src]
            }
            steps = doubled

        case .halfSpeed:
            var halved = [AudioStep](repeating: AudioStep(), count: steps.count)
            for i in stride(from: 0, to: steps.count, by: 2) {
                halved[i] = steps[i / 2]
            }
            steps = halved

        case .randomize:
            let density = Float(parameter) / 100.0
            for i in 0..<steps.count {
                steps[i].isActive = Float.random(in: 0...1) < max(0.1, density)
                if steps[i].isActive {
                    steps[i].velocity = Float.random(in: 0.4...1.0)
                }
            }

        case .euclidean:
            let pulses = max(1, min(parameter, steps.count))
            steps = generateEuclidean(steps: steps.count, pulses: pulses)

        case .humanize:
            let amount = Float(parameter) / 100.0
            for i in 0..<steps.count {
                steps[i].microTiming = Float.random(in: -0.15...0.15) * amount
                if steps[i].isActive {
                    steps[i].velocity = max(0.1, steps[i].velocity + Float.random(in: -0.1...0.1) * amount)
                }
            }

        case .clearAll:
            steps = Array(repeating: AudioStep(), count: steps.count)
        }

        patterns[activePatternIndex].tracks[trackIndex].steps = steps
    }

    // MARK: - Euclidean Rhythm

    /// Generate a Euclidean rhythm (Bjorklund's algorithm)
    /// Reference: Toussaint (2005) "The Euclidean Algorithm Generates Traditional Musical Rhythms"
    public func generateEuclidean(steps: Int, pulses: Int) -> [AudioStep] {
        guard steps > 0 else { return [] }
        let k = min(pulses, steps)

        // Bjorklund's algorithm
        var pattern: [[Bool]] = []
        for i in 0..<steps {
            pattern.append([i < k])
        }

        var level = 0
        var counts = [k, steps - k]

        while counts.count > 1 && counts.last ?? 0 > 0 {
            let minCount = min(counts[0], counts[1])
            var newPattern: [[Bool]] = []

            for i in 0..<minCount {
                var combined = pattern[i]
                combined.append(contentsOf: pattern[counts[0] + i])
                newPattern.append(combined)
            }

            // Remainder
            let startRemainder = minCount
            let endRemainder = counts[0]
            for i in startRemainder..<endRemainder {
                newPattern.append(pattern[i])
            }

            // Leftovers from second group
            let startLeftover = counts[0] + minCount
            for i in startLeftover..<pattern.count {
                newPattern.append(pattern[i])
            }

            pattern = newPattern
            counts = [minCount, max(0, (counts.count > 1 ? counts[1] : 0) - minCount)]
            level += 1

            if counts[0] <= 1 { break }
        }

        // Flatten
        let flat = pattern.flatMap { $0 }
        return flat.prefix(steps).map { active in
            var step = AudioStep()
            step.isActive = active
            step.velocity = active ? Float.random(in: 0.7...1.0) : 1.0
            return step
        }
    }

    // MARK: - Bio-Reactive

    /// Update bio-reactive state from EchoelCreativeWorkspace
    public func updateBioState(coherence: Float, hrv: Float, heartRate: Float, breathPhase: Float) {
        bioCoherence = coherence
        bioHRV = hrv
        bioHeartRate = heartRate
        bioBreathPhase = breathPhase
    }

    // MARK: - Pattern Management

    /// Add a new empty pattern
    public func addPattern(name: String, trackCount: Int = 4, stepCount: Int = 16) {
        let pattern = AudioPattern(name: name, trackCount: trackCount, stepCount: stepCount)
        patterns.append(pattern)
    }

    /// Duplicate the active pattern
    public func duplicateActivePattern() {
        guard let pattern = activePattern else { return }
        var copy = AudioPattern(name: "\(pattern.name) Copy", trackCount: pattern.tracks.count, stepCount: pattern.stepCount)
        for i in 0..<pattern.tracks.count {
            copy.tracks[i] = PatternTrack(name: pattern.tracks[i].name, steps: pattern.tracks[i].steps)
            copy.tracks[i].midiNote = pattern.tracks[i].midiNote
            copy.tracks[i].midiChannel = pattern.tracks[i].midiChannel
            copy.tracks[i].volume = pattern.tracks[i].volume
            copy.tracks[i].pan = pattern.tracks[i].pan
        }
        copy.swingAmount = pattern.swingAmount
        copy.scaleRoot = pattern.scaleRoot
        copy.scaleType = pattern.scaleType
        patterns.append(copy)
    }

    /// Remove a pattern by index
    public func removePattern(at index: Int) {
        guard index < patterns.count, patterns.count > 1 else { return }
        patterns.remove(at: index)
        if activePatternIndex >= patterns.count {
            activePatternIndex = patterns.count - 1
        }
    }
}

// MARK: - Step Trigger

/// A triggered step event for MIDI/audio output
public struct StepTrigger: Sendable {
    public let trackIndex: Int
    public let step: Int
    public let midiNote: UInt8
    public let midiChannel: UInt8
    public let velocity: Float
    public let gateLength: Float
    public let microTiming: Float
    public let pan: Float
}

#endif // canImport(AVFoundation)
