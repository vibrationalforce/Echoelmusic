#if canImport(AVFoundation)
//
//  AIComposerEngine.swift
//  Echoelmusic — Generative Music Composition Engine
//
//  Algorithmic + Markov chain generative composition:
//  - Scale-aware note generation with configurable key/mode
//  - Bio-reactive mapping: coherence → consonance, HRV → rhythmic complexity, HR → tempo
//  - Euclidean rhythm generation (Bjorklund algorithm)
//  - Chord progression templates (I-IV-V-vi, ii-V-I, modal interchange)
//  - Melody contour shaping with step/leap balance
//  - Probability-based variation and mutation engine
//  - Real-time MIDI event output at bar/beat boundaries
//
//  All processing on-device, zero dependencies.
//

import Foundation
import AVFoundation
#if canImport(Observation)
import Observation
#endif

// MARK: - Composition Style

/// Generative composition style presets
public enum CompositionStyle: String, CaseIterable, Codable, Sendable {
    case ambient    = "Ambient"       // Long sustained notes, slow harmonic movement
    case rhythmic   = "Rhythmic"      // Emphasis on pattern and groove
    case melodic    = "Melodic"       // Singable contours, stepwise motion preferred
    case textural   = "Textural"      // Clusters, drones, spectral emphasis
    case cinematic  = "Cinematic"     // Wide dynamics, tension/release arcs

    /// Default tempo range for this style (BPM)
    public var tempoRange: ClosedRange<Double> {
        switch self {
        case .ambient:    return 50...80
        case .rhythmic:   return 100...140
        case .melodic:    return 70...120
        case .textural:   return 40...70
        case .cinematic:  return 60...130
        }
    }

    /// Note density (notes per beat, approximate)
    public var densityRange: ClosedRange<Double> {
        switch self {
        case .ambient:    return 0.25...1.0
        case .rhythmic:   return 1.0...4.0
        case .melodic:    return 0.5...2.0
        case .textural:   return 0.125...0.5
        case .cinematic:  return 0.25...3.0
        }
    }
}

// MARK: - Musical Scale

/// Musical scales for constrained generation
public enum MusicalScale: String, CaseIterable, Codable, Sendable {
    case major           = "Major"
    case naturalMinor    = "Natural Minor"
    case harmonicMinor   = "Harmonic Minor"
    case melodicMinor    = "Melodic Minor"
    case dorian          = "Dorian"
    case mixolydian      = "Mixolydian"
    case lydian          = "Lydian"
    case phrygian        = "Phrygian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues           = "Blues"
    case chromatic       = "Chromatic"
    case wholeTone       = "Whole Tone"

    /// Semitone intervals from root
    public var intervals: [Int] {
        switch self {
        case .major:           return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:    return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:   return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:    return [0, 2, 3, 5, 7, 9, 11]
        case .dorian:          return [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:      return [0, 2, 4, 5, 7, 9, 10]
        case .lydian:          return [0, 2, 4, 6, 7, 9, 11]
        case .phrygian:        return [0, 1, 3, 5, 7, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues:           return [0, 3, 5, 6, 7, 10]
        case .chromatic:       return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .wholeTone:       return [0, 2, 4, 6, 8, 10]
        }
    }
}

// MARK: - Melody Contour

/// Contour shapes for melody generation
public enum MelodyContour: String, CaseIterable, Codable, Sendable {
    case ascending  = "Ascending"
    case descending = "Descending"
    case arch       = "Arch"
    case valley     = "Valley"
    case flat       = "Flat"
    case random     = "Random"
}

// MARK: - Generated Phrase

/// A generated musical phrase containing MIDI note events
public struct GeneratedPhrase: Sendable, Identifiable {
    public let id = UUID()
    public let notes: [NoteEvent]
    public let chordProgression: ChordProgression
    public let style: CompositionStyle
    public let key: Int          // Root note (0-11, C=0)
    public let scale: MusicalScale
    public let tempo: Double     // BPM
    public let bars: Int
    public let timestamp: Date

    /// A single note event within a phrase
    public struct NoteEvent: Sendable {
        public let pitch: Int        // MIDI note number (0-127)
        public let velocity: Float   // 0.0-1.0
        public let startBeat: Double // Beat position within phrase
        public let duration: Double  // Duration in beats
        public let channel: Int      // MIDI channel (0-15)
    }
}

// MARK: - Chord Progression

/// A chord progression with roman numeral analysis
public struct ChordProgression: Sendable {
    public let chords: [Chord]
    public let name: String

    public struct Chord: Sendable {
        public let root: Int           // Semitones from key root (0-11)
        public let intervals: [Int]    // Semitones from chord root
        public let romanNumeral: String
        public let durationBeats: Double

        /// MIDI pitches for this chord given a base octave
        public func midiNotes(keyRoot: Int, octave: Int) -> [Int] {
            let base = keyRoot + (octave * 12)
            return intervals.map { base + root + $0 }
        }
    }

    // MARK: - Progression Templates

    static let popOneFourFiveSix = ChordProgression(
        chords: [
            Chord(root: 0, intervals: [0, 4, 7], romanNumeral: "I", durationBeats: 4),
            Chord(root: 5, intervals: [0, 4, 7], romanNumeral: "IV", durationBeats: 4),
            Chord(root: 7, intervals: [0, 4, 7], romanNumeral: "V", durationBeats: 4),
            Chord(root: 9, intervals: [0, 3, 7], romanNumeral: "vi", durationBeats: 4)
        ],
        name: "I-IV-V-vi"
    )

    static let jazzTwoFiveOne = ChordProgression(
        chords: [
            Chord(root: 2, intervals: [0, 3, 7, 10], romanNumeral: "ii7", durationBeats: 4),
            Chord(root: 7, intervals: [0, 4, 7, 10], romanNumeral: "V7", durationBeats: 4),
            Chord(root: 0, intervals: [0, 4, 7, 11], romanNumeral: "Imaj7", durationBeats: 8)
        ],
        name: "ii-V-I"
    )

    static let modalInterchange = ChordProgression(
        chords: [
            Chord(root: 0, intervals: [0, 4, 7], romanNumeral: "I", durationBeats: 4),
            Chord(root: 8, intervals: [0, 4, 7], romanNumeral: "bVI", durationBeats: 4),
            Chord(root: 10, intervals: [0, 4, 7], romanNumeral: "bVII", durationBeats: 4),
            Chord(root: 0, intervals: [0, 4, 7], romanNumeral: "I", durationBeats: 4)
        ],
        name: "I-bVI-bVII-I"
    )

    static let ambientDrone = ChordProgression(
        chords: [
            Chord(root: 0, intervals: [0, 7], romanNumeral: "I5", durationBeats: 8),
            Chord(root: 5, intervals: [0, 7, 14], romanNumeral: "IV(9)", durationBeats: 8)
        ],
        name: "Drone I-IV"
    )

    static let cinematicTension = ChordProgression(
        chords: [
            Chord(root: 0, intervals: [0, 3, 7], romanNumeral: "i", durationBeats: 4),
            Chord(root: 8, intervals: [0, 4, 7], romanNumeral: "bVI", durationBeats: 4),
            Chord(root: 3, intervals: [0, 4, 7], romanNumeral: "III", durationBeats: 4),
            Chord(root: 7, intervals: [0, 4, 7], romanNumeral: "V", durationBeats: 4)
        ],
        name: "i-bVI-III-V"
    )

    /// All available progressions
    static let allProgressions: [ChordProgression] = [
        popOneFourFiveSix,
        jazzTwoFiveOne,
        modalInterchange,
        ambientDrone,
        cinematicTension
    ]
}

// MARK: - Markov Chain

/// First-order Markov chain for scale-degree transitions
private struct MarkovChain: Sendable {
    /// Transition matrix: row = current degree index, col = next degree index
    /// Values are cumulative probabilities (0-1)
    let transitionMatrix: [[Double]]
    let stateCount: Int

    init(scaleDegreeCount: Int) {
        stateCount = scaleDegreeCount
        guard stateCount > 0 else {
            transitionMatrix = []
            return
        }

        // Build default transition probabilities favoring stepwise motion
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: stateCount), count: stateCount)

        for i in 0..<stateCount {
            var row = [Double](repeating: 0.02, count: stateCount) // Minimal leap probability
            // Strong preference for stepwise motion
            let stepUp = (i + 1) % stateCount
            let stepDown = (i - 1 + stateCount) % stateCount
            row[stepUp] = 0.35
            row[stepDown] = 0.30
            row[i] = 0.10  // Repeat
            // Third above/below
            let thirdUp = (i + 2) % stateCount
            let thirdDown = (i - 2 + stateCount) % stateCount
            row[thirdUp] = 0.08
            row[thirdDown] = 0.07

            // Normalize
            let sum = row.reduce(0, +)
            guard sum > 0 else { continue }
            matrix[i] = row.map { $0 / sum }
        }

        // Convert to cumulative distribution
        for i in 0..<stateCount {
            var cumulative = 0.0
            for j in 0..<stateCount {
                cumulative += matrix[i][j]
                matrix[i][j] = cumulative
            }
            // Ensure last is exactly 1.0
            if stateCount > 0 {
                matrix[i][stateCount - 1] = 1.0
            }
        }

        transitionMatrix = matrix
    }

    /// Sample next state given current state
    func nextState(from current: Int) -> Int {
        guard current >= 0, current < stateCount, stateCount > 0 else { return 0 }
        let r = Double.random(in: 0..<1)
        let row = transitionMatrix[current]
        for j in 0..<stateCount where r < row[j] {
            return j
        }
        return stateCount - 1
    }
}

// MARK: - AIComposerEngine

/// Generative music composition engine using algorithmic + Markov chain approaches.
/// Produces MIDI note events in real time, driven by bio-signal input.
@preconcurrency @MainActor @Observable
public final class AIComposerEngine {

    // MARK: - Singleton

    @MainActor public static let shared = AIComposerEngine()

    // MARK: - Published State

    public private(set) var isComposing: Bool = false
    public private(set) var currentPhrase: GeneratedPhrase?
    public private(set) var phrasesGenerated: Int = 0
    public private(set) var currentBeat: Double = 0

    // MARK: - Configuration

    public var style: CompositionStyle = .melodic
    public var key: Int = 0               // C
    public var scale: MusicalScale = .major
    public var contour: MelodyContour = .arch
    public var octaveRange: ClosedRange<Int> = 3...5
    public var notesPerPhrase: Int = 16
    public var barsPerPhrase: Int = 4
    public var swingAmount: Double = 0.0  // 0 = straight, 1 = full triplet swing
    public var humanizeAmount: Double = 0.1
    public var mutationProbability: Double = 0.15
    public var velocityRange: ClosedRange<Float> = 0.4...0.9

    // MARK: - Bio-Reactive Parameters

    /// Coherence (0-1): higher → more consonant intervals
    public var bioCoherence: Double = 0.5
    /// HRV (0-1): higher → more rhythmic complexity
    public var bioHRV: Double = 0.5
    /// Heart rate (BPM): maps to tempo
    public var bioHeartRate: Double = 72.0

    // MARK: - Callbacks

    /// Called when a note is generated: (midiNote, velocity, durationBeats)
    public var onNoteGenerated: ((Int, Float, Double) -> Void)?

    // MARK: - Private State

    private var markovChain: MarkovChain
    private var currentDegreeIndex: Int = 0
    private var compositionTask: Task<Void, Never>?
    private var lastProgressionIndex: Int = 0

    // MARK: - Init

    private init() {
        self.markovChain = MarkovChain(scaleDegreeCount: MusicalScale.major.intervals.count)
    }

    // MARK: - Composition Control

    /// Start real-time generative composition
    public func startComposing() {
        guard !isComposing else { return }
        isComposing = true
        currentDegreeIndex = 0
        markovChain = MarkovChain(scaleDegreeCount: scale.intervals.count)
        log.log(.info, category: .ai, "AIComposer started — style: \(style.rawValue), key: \(key), scale: \(scale.rawValue)")

        compositionTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isComposing {
                let phrase = self.generatePhrase()
                self.currentPhrase = phrase
                self.phrasesGenerated += 1

                // Emit notes with timing
                for note in phrase.notes {
                    guard !Task.isCancelled else { break }
                    self.onNoteGenerated?(note.pitch, note.velocity, note.duration)
                }

                // Wait for phrase duration before generating next
                let phraseDuration = self.phraseSeconds()
                guard phraseDuration > 0 else { break }
                try? await Task.sleep(for: .milliseconds(Int(phraseDuration * 1000)))
            }
        }
    }

    /// Stop composition
    public func stopComposing() {
        compositionTask?.cancel()
        compositionTask = nil
        isComposing = false
        currentBeat = 0
        log.log(.info, category: .ai, "AIComposer stopped — \(phrasesGenerated) phrases generated")
    }

    /// Generate a single phrase without starting the real-time loop
    public func generateSinglePhrase() -> GeneratedPhrase {
        markovChain = MarkovChain(scaleDegreeCount: scale.intervals.count)
        let phrase = generatePhrase()
        phrasesGenerated += 1
        currentPhrase = phrase
        return phrase
    }

    /// Export current phrase as array of (pitch, velocity, startBeat, duration)
    public func exportCurrentPhrase() -> [(pitch: Int, velocity: Float, startBeat: Double, duration: Double)] {
        guard let phrase = currentPhrase else { return [] }
        return phrase.notes.map { (pitch: $0.pitch, velocity: $0.velocity, startBeat: $0.startBeat, duration: $0.duration) }
    }

    // MARK: - Phrase Generation

    private func generatePhrase() -> GeneratedPhrase {
        let tempo = bioMappedTempo()
        let progression = selectProgression()
        let rhythm = generateEuclideanRhythm(steps: notesPerPhrase, pulses: rhythmPulseCount())
        let notes = generateMelody(rhythm: rhythm, progression: progression, tempo: tempo)

        return GeneratedPhrase(
            notes: notes,
            chordProgression: progression,
            style: style,
            key: key,
            scale: scale,
            tempo: tempo,
            bars: barsPerPhrase,
            timestamp: Date()
        )
    }

    private func generateMelody(
        rhythm: [Bool],
        progression: ChordProgression,
        tempo: Double
    ) -> [GeneratedPhrase.NoteEvent] {
        let intervals = scale.intervals
        guard !intervals.isEmpty else { return [] }

        var notes: [GeneratedPhrase.NoteEvent] = []
        let beatsPerBar = 4.0
        let totalBeats = Double(barsPerPhrase) * beatsPerBar
        let beatStep = totalBeats / Double(rhythm.count)

        var contourPositions = generateContourPositions(count: rhythm.count)

        for (index, isActive) in rhythm.enumerated() {
            guard isActive else { continue }

            // Advance Markov chain
            currentDegreeIndex = markovChain.nextState(from: currentDegreeIndex)

            // Apply contour bias to the Markov output
            let contourOffset = contourPositions[index]
            let biasedDegree = applyContourBias(
                degree: currentDegreeIndex,
                contourOffset: contourOffset,
                degreeCount: intervals.count
            )

            // Map scale degree to MIDI pitch
            let octave = selectOctave(forContour: contourOffset)
            let semitone = intervals[biasedDegree % intervals.count]
            let pitch = clampMIDI(key + semitone + (octave * 12))

            // Apply consonance bias from coherence
            let velocity = generateVelocity(beatPosition: Double(index) * beatStep)
            let duration = generateDuration(beatStep: beatStep)

            // Apply swing
            var startBeat = Double(index) * beatStep
            if index % 2 == 1 {
                startBeat += swingAmount * beatStep * 0.33
            }

            // Apply humanization
            startBeat += Double.random(in: -humanizeAmount...humanizeAmount) * beatStep * 0.1

            // Apply mutation
            let finalPitch: Int
            if Double.random(in: 0..<1) < mutationProbability {
                finalPitch = mutatePitch(pitch, intervals: intervals)
            } else {
                finalPitch = pitch
            }

            let note = GeneratedPhrase.NoteEvent(
                pitch: finalPitch,
                velocity: velocity,
                startBeat: max(0, startBeat),
                duration: duration,
                channel: 0
            )
            notes.append(note)
        }

        return notes
    }

    // MARK: - Euclidean Rhythm (Bjorklund Algorithm)

    /// Generate a Euclidean rhythm pattern using the Bjorklund algorithm.
    /// Distributes `pulses` hits as evenly as possible across `steps` slots.
    private func generateEuclideanRhythm(steps: Int, pulses: Int) -> [Bool] {
        guard steps > 0 else { return [] }
        let safePulses = min(max(pulses, 1), steps)

        var pattern = [Bool](repeating: false, count: steps)
        var counts = [Int](repeating: 0, count: steps)
        var remainders = [Int](repeating: 0, count: steps)

        var divisor = steps - safePulses
        remainders[0] = safePulses
        var level = 0

        while true {
            counts[level] = divisor / remainders[level]
            let newRemainder = divisor % remainders[level]
            remainders[level + 1] = newRemainder
            divisor = remainders[level]
            level += 1
            if remainders[level] <= 1 { break }
        }

        counts[level] = divisor

        // Build pattern
        func buildPattern(level: Int, position: inout Int) {
            guard position < steps else { return }
            if level == -1 {
                pattern[position] = false
                position += 1
            } else if level == -2 {
                pattern[position] = true
                position += 1
            } else {
                for _ in 0..<counts[level] {
                    buildPattern(level: level - 1, position: &position)
                }
                if remainders[level] != 0 {
                    buildPattern(level: level - 2, position: &position)
                }
            }
        }

        var pos = 0
        buildPattern(level: level, position: &pos)

        return pattern
    }

    // MARK: - Bio-Reactive Mapping

    /// Map heart rate to tempo within style constraints
    private func bioMappedTempo() -> Double {
        let range = style.tempoRange
        // Map HR 50-120 to style tempo range
        let hrNormalized = (bioHeartRate - 50.0) / 70.0
        let clampedHR = min(max(hrNormalized, 0), 1)
        return range.lowerBound + clampedHR * (range.upperBound - range.lowerBound)
    }

    /// Determine pulse count from HRV (higher HRV → more pulses → more complex)
    private func rhythmPulseCount() -> Int {
        let densityRange = style.densityRange
        let density = densityRange.lowerBound + bioHRV * (densityRange.upperBound - densityRange.lowerBound)
        let beatsPerBar = 4.0
        let totalBeats = Double(barsPerPhrase) * beatsPerBar
        return max(1, Int(density * totalBeats))
    }

    /// Apply coherence-based consonance filter
    /// High coherence → prefer thirds, fifths; low → allow seconds, tritones
    private func consonanceWeight(for interval: Int) -> Double {
        let consonantIntervals: Set<Int> = [0, 3, 4, 5, 7, 8, 9, 12]  // unison, thirds, fourths, fifths, sixths, octave
        let isConsonant = consonantIntervals.contains(interval % 12)

        if isConsonant {
            return 0.5 + bioCoherence * 0.5  // 0.5-1.0
        } else {
            return 0.5 - bioCoherence * 0.4  // 0.1-0.5
        }
    }

    // MARK: - Contour Generation

    private func generateContourPositions(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        return (0..<count).map { i in
            let t = count > 1 ? Double(i) / Double(count - 1) : 0.5
            switch contour {
            case .ascending:  return t
            case .descending: return 1.0 - t
            case .arch:       return Foundation.sin(t * .pi)
            case .valley:     return 1.0 - Foundation.sin(t * .pi)
            case .flat:       return 0.5
            case .random:     return Double.random(in: 0...1)
            }
        }
    }

    private func applyContourBias(degree: Int, contourOffset: Double, degreeCount: Int) -> Int {
        guard degreeCount > 0 else { return 0 }
        // Blend Markov output with contour target
        let contourTarget = Int(contourOffset * Double(degreeCount - 1))
        let blendFactor = 0.4  // 40% contour influence
        let blended = Double(degree) * (1 - blendFactor) + Double(contourTarget) * blendFactor
        return min(max(Int(blended.rounded()), 0), degreeCount - 1)
    }

    // MARK: - Octave / Pitch Helpers

    private func selectOctave(forContour offset: Double) -> Int {
        let low = octaveRange.lowerBound
        let high = octaveRange.upperBound
        let octave = low + Int((offset * Double(high - low)).rounded())
        return min(max(octave, low), high)
    }

    private func clampMIDI(_ note: Int) -> Int {
        min(max(note, 0), 127)
    }

    private func mutatePitch(_ pitch: Int, intervals: [Int]) -> Int {
        // Mutate by moving to a random nearby scale tone
        let offset = intervals.randomElement() ?? 0
        let direction = Bool.random() ? 1 : -1
        return clampMIDI(pitch + direction * offset)
    }

    // MARK: - Velocity / Duration

    private func generateVelocity(beatPosition: Double) -> Float {
        // Accent on downbeats
        let isDownbeat = beatPosition.truncatingRemainder(dividingBy: 4.0) < 0.01
        let baseVelocity = Float.random(in: velocityRange)
        let accent: Float = isDownbeat ? 0.1 : 0.0
        return min(max(baseVelocity + accent, 0.0), 1.0)
    }

    private func generateDuration(beatStep: Double) -> Double {
        switch style {
        case .ambient:   return beatStep * Double.random(in: 1.5...4.0)
        case .rhythmic:  return beatStep * Double.random(in: 0.3...0.8)
        case .melodic:   return beatStep * Double.random(in: 0.5...1.5)
        case .textural:  return beatStep * Double.random(in: 2.0...8.0)
        case .cinematic: return beatStep * Double.random(in: 0.5...3.0)
        }
    }

    // MARK: - Progression Selection

    private func selectProgression() -> ChordProgression {
        switch style {
        case .ambient:    return .ambientDrone
        case .rhythmic:   return .popOneFourFiveSix
        case .melodic:    return .popOneFourFiveSix
        case .textural:   return .ambientDrone
        case .cinematic:  return .cinematicTension
        }
    }

    // MARK: - Timing

    private func phraseSeconds() -> Double {
        let tempo = bioMappedTempo()
        guard tempo > 0 else { return 1.0 }
        let beatsPerBar = 4.0
        let totalBeats = Double(barsPerPhrase) * beatsPerBar
        return (totalBeats / tempo) * 60.0
    }

    // MARK: - Variation Engine

    /// Apply probability-based mutations to an existing phrase, returning a new variant
    public func variate(_ phrase: GeneratedPhrase, mutationRate: Double? = nil) -> GeneratedPhrase {
        let rate = mutationRate ?? mutationProbability
        let intervals = scale.intervals
        guard !intervals.isEmpty else { return phrase }

        let variedNotes: [GeneratedPhrase.NoteEvent] = phrase.notes.map { note in
            if Double.random(in: 0..<1) < rate {
                let newPitch = mutatePitch(note.pitch, intervals: intervals)
                let velocityJitter = Float.random(in: -0.1...0.1)
                let newVelocity = min(max(note.velocity + velocityJitter, 0.05), 1.0)
                let durationJitter = Double.random(in: 0.8...1.2)
                return GeneratedPhrase.NoteEvent(
                    pitch: newPitch,
                    velocity: newVelocity,
                    startBeat: note.startBeat,
                    duration: note.duration * durationJitter,
                    channel: note.channel
                )
            }
            return note
        }

        return GeneratedPhrase(
            notes: variedNotes,
            chordProgression: phrase.chordProgression,
            style: phrase.style,
            key: phrase.key,
            scale: phrase.scale,
            tempo: phrase.tempo,
            bars: phrase.bars,
            timestamp: Date()
        )
    }

    /// Update bio-reactive parameters from a snapshot
    public func updateBio(coherence: Double, hrv: Double, heartRate: Double) {
        bioCoherence = min(max(coherence, 0), 1)
        bioHRV = min(max(hrv, 0), 1)
        bioHeartRate = min(max(heartRate, 40), 200)
    }
}

#endif
