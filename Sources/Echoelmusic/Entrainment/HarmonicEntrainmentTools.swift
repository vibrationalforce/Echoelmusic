import Foundation
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// HARMONIC ENTRAINMENT TOOLS FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Advanced musical tools for aesthetic brainwave entrainment through
// harmonic content, rhythmic structures, and musical intelligence.
//
// PHILOSOPHY:
// ───────────────────────────────────────────────────────────────────────────────
// The brain naturally entrains to musical patterns. Rather than using
// artificial tones, we leverage:
//
// • Rhythmic pulse at entrainment frequencies
// • Harmonic series that emphasize target frequencies
// • Melodic contours that guide attention
// • Timbral evolution that breathes with the rhythm
// • Spatial movement that creates immersion
//
// The entrainment becomes indistinguishable from the music itself—
// not an overlay, but the essence of the composition.
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Harmonic Entrainment Generator

/// Generates harmonically rich tones for entrainment
public final class HarmonicEntrainmentGenerator {

    // MARK: Configuration
    public struct Configuration {
        /// Fundamental frequency (Hz)
        public var fundamental: Float = 110.0  // A2

        /// Number of harmonics to generate
        public var harmonicCount: Int = 8

        /// Harmonic decay rate (higher = faster decay of upper harmonics)
        public var harmonicDecay: Float = 0.7

        /// Entrainment frequency (Hz)
        public var entrainmentFrequency: Float = 10.0

        /// Modulation depth for amplitude (0-1)
        public var amplitudeModDepth: Float = 0.3

        /// Modulation depth for harmonics (0-1)
        public var harmonicModDepth: Float = 0.5

        /// Modulation depth for pitch (cents, subtle vibrato)
        public var pitchModDepth: Float = 5.0

        public init() {}
    }

    public var config: Configuration

    private var phases: [Float]
    private var entrainmentPhase: Float = 0
    private var sampleRate: Float = 48000

    // MARK: Initialization
    public init(config: Configuration = Configuration()) {
        self.config = config
        self.phases = [Float](repeating: 0, count: config.harmonicCount)
    }

    // MARK: Audio Generation

    /// Generate audio samples with harmonic entrainment
    public func generate(
        into buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        stereo: Bool = true
    ) {
        let channelCount = stereo ? 2 : 1

        for frame in 0..<frameCount {
            // Update entrainment phase
            entrainmentPhase += config.entrainmentFrequency / sampleRate
            if entrainmentPhase >= 1.0 { entrainmentPhase -= 1.0 }

            // Calculate modulation values
            let entrainmentValue = sin(entrainmentPhase * 2 * .pi)
            let amplitudeMod = 1.0 - config.amplitudeModDepth * (1.0 - entrainmentValue) * 0.5
            let harmonicMod = config.harmonicModDepth * entrainmentValue
            let pitchMod = config.pitchModDepth * entrainmentValue / 1200.0  // cents to ratio

            // Generate harmonics
            var sample: Float = 0

            for h in 0..<config.harmonicCount {
                let harmonicNumber = Float(h + 1)

                // Calculate harmonic amplitude (decays with harmonic number)
                var harmonicAmp = pow(config.harmonicDecay, Float(h))

                // Modulate odd vs even harmonics differently
                if h % 2 == 0 {
                    // Even harmonics: boost on "up" phase
                    harmonicAmp *= 1.0 + harmonicMod * 0.3
                } else {
                    // Odd harmonics: boost on "down" phase
                    harmonicAmp *= 1.0 - harmonicMod * 0.2
                }

                // Calculate frequency with pitch modulation
                let freq = config.fundamental * harmonicNumber * (1.0 + pitchMod)

                // Update phase
                phases[h] += freq / sampleRate
                if phases[h] >= 1.0 { phases[h] -= 1.0 }

                // Add to sample
                sample += sin(phases[h] * 2 * .pi) * harmonicAmp
            }

            // Normalize and apply amplitude modulation
            sample = sample / Float(config.harmonicCount) * amplitudeMod

            // Write to buffer
            if stereo {
                // Subtle stereo spread based on entrainment
                let stereoSpread = entrainmentValue * 0.1
                buffer[frame * 2] = sample * (1.0 + stereoSpread)
                buffer[frame * 2 + 1] = sample * (1.0 - stereoSpread)
            } else {
                buffer[frame] = sample
            }
        }
    }

    /// Set fundamental based on musical note
    public func setNote(_ note: MusicalNote) {
        config.fundamental = note.frequency
    }

    /// Set entrainment target
    public func setEntrainmentState(_ state: EntrainmentState) {
        config.entrainmentFrequency = state.targetFrequency

        // Adjust harmonic content based on state
        switch state {
        case .deepSleep, .meditation:
            config.harmonicCount = 4
            config.harmonicDecay = 0.5
        case .relaxation, .flow:
            config.harmonicCount = 6
            config.harmonicDecay = 0.6
        case .focus, .alertness:
            config.harmonicCount = 8
            config.harmonicDecay = 0.7
        case .insight:
            config.harmonicCount = 12
            config.harmonicDecay = 0.75
        }
    }
}

// MARK: - Musical Note Helper

public struct MusicalNote {
    public let name: String
    public let octave: Int
    public let frequency: Float

    public static let A4: Float = 440.0

    public init(name: String, octave: Int) {
        self.name = name
        self.octave = octave

        // Calculate frequency from note name
        let semitones = MusicalNote.semitonesFromA4(name: name, octave: octave)
        self.frequency = MusicalNote.A4 * pow(2.0, Float(semitones) / 12.0)
    }

    private static func semitonesFromA4(name: String, octave: Int) -> Int {
        let noteOffsets: [String: Int] = [
            "C": -9, "C#": -8, "Db": -8,
            "D": -7, "D#": -6, "Eb": -6,
            "E": -5, "F": -4, "F#": -3, "Gb": -3,
            "G": -2, "G#": -1, "Ab": -1,
            "A": 0, "A#": 1, "Bb": 1,
            "B": 2
        ]

        let noteOffset = noteOffsets[name] ?? 0
        let octaveOffset = (octave - 4) * 12

        return noteOffset + octaveOffset
    }

    // Common notes
    public static let C2 = MusicalNote(name: "C", octave: 2)  // 65.41 Hz
    public static let A2 = MusicalNote(name: "A", octave: 2)  // 110 Hz
    public static let C3 = MusicalNote(name: "C", octave: 3)  // 130.81 Hz
    public static let A3 = MusicalNote(name: "A", octave: 3)  // 220 Hz
    public static let C4 = MusicalNote(name: "C", octave: 4)  // 261.63 Hz (Middle C)
    public static let A4 = MusicalNote(name: "A", octave: 4)  // 440 Hz
}

// MARK: - Rhythmic Pulse Generator

/// Generates rhythmic pulses at entrainment frequencies with musical timing
public final class RhythmicPulseGenerator {

    public struct Configuration {
        /// Base tempo (BPM)
        public var tempo: Float = 60

        /// Pulse shape
        public var shape: PulseShape = .softAttack

        /// Swing amount (0 = straight, 0.5 = triplet swing)
        public var swing: Float = 0

        /// Accent pattern (emphasize certain beats)
        public var accentPattern: [Float] = [1.0, 0.5, 0.7, 0.5]

        /// Ghost notes (subtle off-beat pulses)
        public var ghostNoteLevel: Float = 0.2

        public init() {}
    }

    public enum PulseShape: String, CaseIterable {
        case sharp       // Quick attack, quick decay
        case softAttack  // Gradual attack, medium decay
        case sustained   // Quick attack, slow decay
        case breathing   // Very gradual attack and decay
        case heartbeat   // Double-tap pattern

        func envelope(phase: Float) -> Float {
            switch self {
            case .sharp:
                return exp(-phase * 10)
            case .softAttack:
                let attack = 1.0 - exp(-phase * 5)
                let decay = exp(-(phase - 0.2) * 3)
                return min(attack, decay)
            case .sustained:
                return exp(-phase * 2)
            case .breathing:
                return sin(phase * .pi) * exp(-phase * 0.5)
            case .heartbeat:
                let beat1 = exp(-pow((phase - 0.1) * 8, 2))
                let beat2 = exp(-pow((phase - 0.3) * 10, 2)) * 0.6
                return beat1 + beat2
            }
        }
    }

    public var config: Configuration

    private var phase: Float = 0
    private var beatIndex: Int = 0
    private var sampleRate: Float = 48000

    public init(config: Configuration = Configuration()) {
        self.config = config
    }

    /// Generate pulse envelope
    public func generate(
        into buffer: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let samplesPerBeat = sampleRate * 60.0 / config.tempo

        for frame in 0..<frameCount {
            // Calculate beat phase
            let beatPhase = phase / samplesPerBeat
            let currentBeat = Int(beatPhase) % config.accentPattern.count
            let phaseInBeat = beatPhase - Float(Int(beatPhase))

            // Apply swing to off-beats
            var adjustedPhase = phaseInBeat
            if currentBeat % 2 == 1 {
                adjustedPhase = phaseInBeat * (1.0 - config.swing * 0.5)
            }

            // Get envelope value
            let envelope = config.shape.envelope(phase: adjustedPhase)

            // Apply accent
            let accent = config.accentPattern[currentBeat]
            buffer[frame] = envelope * accent

            // Add ghost notes (16th notes)
            let sixteenthPhase = (beatPhase * 4).truncatingRemainder(dividingBy: 1.0)
            if sixteenthPhase > 0.5 {
                buffer[frame] += config.shape.envelope(phase: (sixteenthPhase - 0.5) * 2) * config.ghostNoteLevel
            }

            phase += 1
            if phase >= samplesPerBeat * Float(config.accentPattern.count) {
                phase = 0
            }
        }
    }

    /// Set tempo to align with entrainment frequency
    public func alignToEntrainment(_ state: EntrainmentState, subdivision: TempoEntrainment.Subdivision = .eighth) {
        config.tempo = TempoEntrainment.alignedTempo(
            targetBrainwaveHz: state.targetFrequency,
            preferredSubdivision: subdivision
        )
    }
}

// MARK: - Spectral Entrainment Processor

/// Modulates spectral content for entrainment
public final class SpectralEntrainmentProcessor {

    public struct Configuration {
        /// Target entrainment frequency
        public var entrainmentFrequency: Float = 10.0

        /// Spectral modulation depth
        public var modulationDepth: Float = 0.5

        /// Which frequency bands to emphasize
        public var emphasisBands: [FrequencyBand] = [.low, .mid]

        public init() {}
    }

    public enum FrequencyBand {
        case sub       // < 60 Hz
        case low       // 60-250 Hz
        case lowMid    // 250-500 Hz
        case mid       // 500-2000 Hz
        case highMid   // 2000-4000 Hz
        case high      // 4000-8000 Hz
        case air       // > 8000 Hz

        var range: ClosedRange<Float> {
            switch self {
            case .sub: return 0...60
            case .low: return 60...250
            case .lowMid: return 250...500
            case .mid: return 500...2000
            case .highMid: return 2000...4000
            case .high: return 4000...8000
            case .air: return 8000...20000
            }
        }
    }

    public var config: Configuration
    private var phase: Float = 0
    private var sampleRate: Float = 48000

    // Simple multi-band EQ state
    private var bandStates: [FrequencyBand: Float] = [:]

    public init(config: Configuration = Configuration()) {
        self.config = config
    }

    /// Get modulation multipliers for each band
    public func bandModulations() -> [FrequencyBand: Float] {
        // Update phase
        phase += config.entrainmentFrequency / sampleRate
        if phase >= 1.0 { phase -= 1.0 }

        let modValue = sin(phase * 2 * .pi)

        var modulations: [FrequencyBand: Float] = [:]

        for band in FrequencyBand.allCases {
            if config.emphasisBands.contains(band) {
                // Emphasized bands get positive modulation
                modulations[band] = 1.0 + modValue * config.modulationDepth
            } else {
                // Other bands get inverse modulation (subtle)
                modulations[band] = 1.0 - modValue * config.modulationDepth * 0.3
            }
        }

        return modulations
    }
}

extension SpectralEntrainmentProcessor.FrequencyBand: CaseIterable {}

// MARK: - Chord Progression Entrainment

/// Generates chord progressions that breathe with entrainment
public final class ChordEntrainmentEngine {

    public struct Chord {
        public var root: MusicalNote
        public var intervals: [Int]  // Semitones from root
        public var voicing: [Int]    // Octave adjustments for each note

        public var frequencies: [Float] {
            var freqs: [Float] = [root.frequency]
            for (i, interval) in intervals.enumerated() {
                let octaveShift = voicing.count > i ? voicing[i] : 0
                let freq = root.frequency * pow(2.0, Float(interval) / 12.0) * pow(2.0, Float(octaveShift))
                freqs.append(freq)
            }
            return freqs
        }

        // Common chord types
        public static func major(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [4, 7], voicing: [0, 0])
        }

        public static func minor(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [3, 7], voicing: [0, 0])
        }

        public static func major7(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [4, 7, 11], voicing: [0, 0, 0])
        }

        public static func minor7(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [3, 7, 10], voicing: [0, 0, 0])
        }

        public static func sus2(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [2, 7], voicing: [0, 0])
        }

        public static func sus4(root: MusicalNote) -> Chord {
            Chord(root: root, intervals: [5, 7], voicing: [0, 0])
        }
    }

    /// Chord progression optimized for different states
    public static func progressionForState(_ state: EntrainmentState) -> [Chord] {
        switch state {
        case .deepSleep:
            // Simple, consonant, widely spaced
            return [
                .major(root: .C3),
                .sus2(root: .C3),
                .major(root: .C3)
            ]

        case .meditation:
            // Modal, suspended, ambiguous
            return [
                .sus2(root: .A2),
                .sus4(root: .A2),
                .minor7(root: MusicalNote(name: "D", octave: 3)),
                .sus2(root: .A2)
            ]

        case .relaxation:
            // Gentle major/minor movement
            return [
                .major7(root: .C3),
                .minor7(root: MusicalNote(name: "A", octave: 2)),
                .major7(root: MusicalNote(name: "F", octave: 2)),
                .major7(root: MusicalNote(name: "G", octave: 2))
            ]

        case .focus:
            // More rhythmic, clearer harmonies
            return [
                .major(root: .C3),
                .major(root: MusicalNote(name: "G", octave: 2)),
                .minor(root: MusicalNote(name: "A", octave: 2)),
                .major(root: MusicalNote(name: "F", octave: 2))
            ]

        case .flow:
            // Smooth jazz-inspired progressions
            return [
                .major7(root: .C3),
                .minor7(root: MusicalNote(name: "D", octave: 3)),
                .minor7(root: MusicalNote(name: "E", octave: 3)),
                .major7(root: MusicalNote(name: "F", octave: 3))
            ]

        case .alertness:
            // Brighter, more tension
            return [
                .major(root: MusicalNote(name: "E", octave: 3)),
                .major(root: MusicalNote(name: "A", octave: 3)),
                .major(root: MusicalNote(name: "B", octave: 3)),
                .major(root: MusicalNote(name: "E", octave: 3))
            ]

        case .insight:
            // Complex, unexpected
            return [
                .major7(root: MusicalNote(name: "D", octave: 3)),
                .minor7(root: MusicalNote(name: "F#", octave: 3)),
                .major7(root: MusicalNote(name: "A", octave: 3)),
                .minor7(root: MusicalNote(name: "E", octave: 3))
            ]
        }
    }
}

// MARK: - Ambient Texture Generator

/// Generates evolving ambient textures for entrainment backgrounds
public final class AmbientEntrainmentTexture {

    public struct Configuration {
        /// Number of oscillators
        public var oscillatorCount: Int = 6

        /// Base frequency range
        public var frequencyRange: ClosedRange<Float> = 80...400

        /// Detuning amount (cents)
        public var detune: Float = 10

        /// Entrainment frequency
        public var entrainmentFrequency: Float = 10

        /// Texture density (0-1)
        public var density: Float = 0.5

        public init() {}
    }

    private struct Oscillator {
        var frequency: Float
        var phase: Float = 0
        var amplitude: Float = 1.0
        var pan: Float = 0
    }

    public var config: Configuration
    private var oscillators: [Oscillator] = []
    private var entrainmentPhase: Float = 0
    private var sampleRate: Float = 48000

    public init(config: Configuration = Configuration()) {
        self.config = config
        initializeOscillators()
    }

    private func initializeOscillators() {
        oscillators = (0..<config.oscillatorCount).map { i in
            let t = Float(i) / Float(config.oscillatorCount - 1)
            let freq = config.frequencyRange.lowerBound +
                       t * (config.frequencyRange.upperBound - config.frequencyRange.lowerBound)

            return Oscillator(
                frequency: freq + Float.random(in: -config.detune...config.detune),
                phase: Float.random(in: 0...1),
                amplitude: 1.0 / Float(config.oscillatorCount),
                pan: t * 2 - 1  // Spread across stereo field
            )
        }
    }

    /// Generate ambient texture
    public func generate(
        into buffer: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Clear buffer
        memset(buffer, 0, frameCount * 2 * MemoryLayout<Float>.size)

        for frame in 0..<frameCount {
            // Update entrainment
            entrainmentPhase += config.entrainmentFrequency / sampleRate
            if entrainmentPhase >= 1.0 { entrainmentPhase -= 1.0 }

            let entrainmentMod = sin(entrainmentPhase * 2 * .pi)

            var leftSample: Float = 0
            var rightSample: Float = 0

            for i in 0..<oscillators.count {
                // Modulate amplitude with entrainment (phase-shifted per oscillator)
                let phaseOffset = Float(i) / Float(oscillators.count)
                let oscEntrainment = sin((entrainmentPhase + phaseOffset) * 2 * .pi)
                let ampMod = 0.7 + oscEntrainment * 0.3 * config.density

                // Generate oscillator
                oscillators[i].phase += oscillators[i].frequency / sampleRate
                if oscillators[i].phase >= 1.0 { oscillators[i].phase -= 1.0 }

                let sample = sin(oscillators[i].phase * 2 * .pi) * oscillators[i].amplitude * ampMod

                // Pan
                let leftGain = sqrt(0.5 * (1.0 - oscillators[i].pan))
                let rightGain = sqrt(0.5 * (1.0 + oscillators[i].pan))

                leftSample += sample * leftGain
                rightSample += sample * rightGain
            }

            buffer[frame * 2] = leftSample
            buffer[frame * 2 + 1] = rightSample
        }
    }

    /// Adapt to entrainment state
    public func adaptToState(_ state: EntrainmentState) {
        config.entrainmentFrequency = state.targetFrequency

        // Adjust texture based on state
        switch state {
        case .deepSleep:
            config.frequencyRange = 40...150
            config.density = 0.3
            config.oscillatorCount = 3

        case .meditation:
            config.frequencyRange = 60...200
            config.density = 0.4
            config.oscillatorCount = 4

        case .relaxation:
            config.frequencyRange = 80...300
            config.density = 0.5
            config.oscillatorCount = 5

        case .focus:
            config.frequencyRange = 100...400
            config.density = 0.6
            config.oscillatorCount = 6

        case .flow:
            config.frequencyRange = 100...350
            config.density = 0.55
            config.oscillatorCount = 6

        case .alertness:
            config.frequencyRange = 150...500
            config.density = 0.7
            config.oscillatorCount = 7

        case .insight:
            config.frequencyRange = 200...600
            config.density = 0.8
            config.oscillatorCount = 8
        }

        initializeOscillators()
    }
}
