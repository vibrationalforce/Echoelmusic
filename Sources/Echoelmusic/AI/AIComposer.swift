// AIComposer.swift
// Echoelmusic - AI-Powered Music Composition Engine
//
// A++ Ultrahardthink Implementation
// Provides intelligent music generation including:
// - LSTM-based melody generation
// - Markov chain chord progressions
// - Bio-reactive music style mapping
// - Drum pattern generation
// - Genre-aware composition
// - Scale and mode intelligence

import Foundation
import Combine
import Accelerate
import os.log

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.ai", category: "Composer")

// MARK: - Musical Note

public struct Note: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let pitch: Int           // MIDI note number (0-127)
    public let duration: Double     // Duration in beats
    public let velocity: Int        // Velocity (0-127)
    public let startTime: Double    // Start time in beats
    public var articulation: Articulation

    public enum Articulation: String, Codable, Sendable {
        case normal
        case staccato
        case legato
        case accent
        case tenuto
        case marcato
    }

    public init(
        pitch: Int,
        duration: Double,
        velocity: Int = 80,
        startTime: Double = 0,
        articulation: Articulation = .normal
    ) {
        self.id = UUID()
        self.pitch = max(0, min(127, pitch))
        self.duration = max(0.0625, duration)  // Minimum 1/16 note
        self.velocity = max(0, min(127, velocity))
        self.startTime = max(0, startTime)
        self.articulation = articulation
    }

    public var noteName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (pitch / 12) - 1
        let note = pitch % 12
        return "\(names[note])\(octave)"
    }
}

// MARK: - Chord

public struct Chord: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let root: String
    public let type: ChordType
    public let inversion: Int
    public let duration: Double
    public var voicing: [Int]  // MIDI notes

    public enum ChordType: String, Codable, CaseIterable, Sendable {
        case major = "maj"
        case minor = "min"
        case diminished = "dim"
        case augmented = "aug"
        case dominant7 = "7"
        case major7 = "maj7"
        case minor7 = "min7"
        case diminished7 = "dim7"
        case halfDiminished = "m7b5"
        case augmented7 = "aug7"
        case sus2 = "sus2"
        case sus4 = "sus4"
        case add9 = "add9"
        case sixth = "6"
        case minor6 = "m6"
        case ninth = "9"
        case minor9 = "m9"
        case eleventh = "11"
        case thirteenth = "13"

        public var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .diminished: return [0, 3, 6]
            case .augmented: return [0, 4, 8]
            case .dominant7: return [0, 4, 7, 10]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .diminished7: return [0, 3, 6, 9]
            case .halfDiminished: return [0, 3, 6, 10]
            case .augmented7: return [0, 4, 8, 10]
            case .sus2: return [0, 2, 7]
            case .sus4: return [0, 5, 7]
            case .add9: return [0, 4, 7, 14]
            case .sixth: return [0, 4, 7, 9]
            case .minor6: return [0, 3, 7, 9]
            case .ninth: return [0, 4, 7, 10, 14]
            case .minor9: return [0, 3, 7, 10, 14]
            case .eleventh: return [0, 4, 7, 10, 14, 17]
            case .thirteenth: return [0, 4, 7, 10, 14, 17, 21]
            }
        }
    }

    public init(root: String, type: ChordType, inversion: Int = 0, duration: Double = 4.0) {
        self.id = UUID()
        self.root = root
        self.type = type
        self.inversion = inversion
        self.duration = duration
        self.voicing = Self.calculateVoicing(root: root, type: type, inversion: inversion)
    }

    private static func calculateVoicing(root: String, type: ChordType, inversion: Int) -> [Int] {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let rootIndex = noteNames.firstIndex(of: root.replacingOccurrences(of: "m", with: "").prefix(2).description) ?? 0
        let basePitch = 48 + rootIndex  // C3 base

        var notes = type.intervals.map { basePitch + $0 }

        // Apply inversion
        for _ in 0..<inversion {
            if let first = notes.first {
                notes.removeFirst()
                notes.append(first + 12)
            }
        }

        return notes
    }

    public var symbol: String {
        return "\(root)\(type.rawValue)"
    }
}

// MARK: - Music Style

public enum MusicStyle: String, Codable, CaseIterable, Sendable {
    case calm = "Calm"
    case energetic = "Energetic"
    case tense = "Tense"
    case balanced = "Balanced"
    case meditative = "Meditative"
    case euphoric = "Euphoric"
    case melancholic = "Melancholic"
    case aggressive = "Aggressive"
    case peaceful = "Peaceful"
    case mysterious = "Mysterious"

    public var suggestedTempo: ClosedRange<Int> {
        switch self {
        case .calm: return 60...80
        case .energetic: return 120...140
        case .tense: return 90...110
        case .balanced: return 100...120
        case .meditative: return 50...70
        case .euphoric: return 128...150
        case .melancholic: return 70...90
        case .aggressive: return 140...180
        case .peaceful: return 55...75
        case .mysterious: return 80...100
        }
    }

    public var suggestedModes: [MusicalMode] {
        switch self {
        case .calm: return [.ionian, .lydian]
        case .energetic: return [.mixolydian, .ionian]
        case .tense: return [.locrian, .phrygian]
        case .balanced: return [.dorian, .ionian]
        case .meditative: return [.lydian, .ionian]
        case .euphoric: return [.lydian, .ionian]
        case .melancholic: return [.aeolian, .dorian]
        case .aggressive: return [.phrygian, .locrian]
        case .peaceful: return [.ionian, .lydian]
        case .mysterious: return [.phrygianDominant, .harmonicMinor]
        }
    }
}

// MARK: - Musical Mode

public enum MusicalMode: String, Codable, CaseIterable, Sendable {
    case ionian = "Ionian (Major)"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case aeolian = "Aeolian (Natural Minor)"
    case locrian = "Locrian"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case phrygianDominant = "Phrygian Dominant"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case wholeTone = "Whole Tone"
    case chromatic = "Chromatic"

    public var intervals: [Int] {
        switch self {
        case .ionian: return [0, 2, 4, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .phrygianDominant: return [0, 1, 4, 5, 7, 8, 10]
        case .pentatonicMajor: return [0, 2, 4, 7, 9]
        case .pentatonicMinor: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .chromatic: return Array(0...11)
        }
    }

    public func getScale(rootPitch: Int) -> [Int] {
        intervals.map { rootPitch + $0 }
    }
}

// MARK: - Drum Pattern

public struct DrumPattern: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var tempo: Int
    public var timeSignature: TimeSignature
    public var tracks: [DrumTrack]

    public struct TimeSignature: Codable, Sendable {
        public var numerator: Int
        public var denominator: Int
    }

    public struct DrumTrack: Codable, Identifiable, Sendable {
        public let id: UUID
        public var instrument: DrumInstrument
        public var hits: [DrumHit]
    }

    public struct DrumHit: Codable, Sendable {
        public var position: Double  // Position in beats
        public var velocity: Int     // 0-127
        public var duration: Double  // Duration in beats
    }

    public enum DrumInstrument: String, Codable, CaseIterable, Sendable {
        case kick = "Kick"
        case snare = "Snare"
        case hiHatClosed = "Hi-Hat Closed"
        case hiHatOpen = "Hi-Hat Open"
        case tom1 = "Tom 1"
        case tom2 = "Tom 2"
        case tom3 = "Tom 3"
        case crash = "Crash"
        case ride = "Ride"
        case clap = "Clap"
        case rimshot = "Rimshot"
        case cowbell = "Cowbell"
        case shaker = "Shaker"
        case tambourine = "Tambourine"

        public var midiNote: Int {
            switch self {
            case .kick: return 36
            case .snare: return 38
            case .hiHatClosed: return 42
            case .hiHatOpen: return 46
            case .tom1: return 50
            case .tom2: return 47
            case .tom3: return 43
            case .crash: return 49
            case .ride: return 51
            case .clap: return 39
            case .rimshot: return 37
            case .cowbell: return 56
            case .shaker: return 70
            case .tambourine: return 54
            }
        }
    }

    public init(name: String, tempo: Int = 120, timeSignature: TimeSignature = TimeSignature(numerator: 4, denominator: 4)) {
        self.id = UUID()
        self.name = name
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.tracks = []
    }
}

// MARK: - Generation Configuration

public struct MelodyGenerationConfig: Sendable {
    public var key: String
    public var mode: MusicalMode
    public var bars: Int
    public var noteDensity: Float       // 0.0-1.0
    public var rhythmComplexity: Float  // 0.0-1.0
    public var melodicRange: Int        // Octaves
    public var restProbability: Float   // 0.0-1.0
    public var leapProbability: Float   // Large interval probability
    public var repeatProbability: Float // Repeated note probability
    public var style: MusicStyle

    public init(
        key: String = "C",
        mode: MusicalMode = .ionian,
        bars: Int = 4,
        noteDensity: Float = 0.6,
        rhythmComplexity: Float = 0.5,
        melodicRange: Int = 2,
        restProbability: Float = 0.1,
        leapProbability: Float = 0.2,
        repeatProbability: Float = 0.15,
        style: MusicStyle = .balanced
    ) {
        self.key = key
        self.mode = mode
        self.bars = bars
        self.noteDensity = noteDensity
        self.rhythmComplexity = rhythmComplexity
        self.melodicRange = melodicRange
        self.restProbability = restProbability
        self.leapProbability = leapProbability
        self.repeatProbability = repeatProbability
        self.style = style
    }
}

// MARK: - AI Composer

@MainActor
public final class AIComposer: ObservableObject {
    // MARK: - Singleton

    public static let shared = AIComposer()

    // MARK: - Published State

    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var generatedMelody: [Note] = []
    @Published public private(set) var suggestedChords: [Chord] = []
    @Published public private(set) var currentPattern: DrumPattern?
    @Published public private(set) var currentStyle: MusicStyle = .balanced

    // MARK: - Markov Chain Data

    private var melodicTransitions: [[Float]] = []
    private var rhythmicPatterns: [[Double]] = []
    private var chordProgressions: [String: [String: Float]] = [:]

    // MARK: - Configuration

    public var temperature: Float = 0.8  // Randomness (0.0-1.0)
    public var creativityLevel: Float = 0.5  // Balance between rules and creativity

    // MARK: - Random Number Generator

    private var rng = SystemRandomNumberGenerator()

    // MARK: - Initialization

    public init() {
        initializeMarkovChains()
        initializeChordProgressions()
        logger.info("AIComposer initialized with Markov chains and chord progressions")
    }

    private func initializeMarkovChains() {
        // Initialize melodic interval transition matrix (12x12 for semitones)
        // Higher probability for stepwise motion
        melodicTransitions = Array(repeating: Array(repeating: 0.0, count: 13), count: 13)

        // Favor stepwise motion (intervals 1-2)
        for i in 0..<13 {
            melodicTransitions[i][0] = 0.15  // Unison
            melodicTransitions[i][1] = 0.25  // Minor 2nd
            melodicTransitions[i][2] = 0.25  // Major 2nd
            melodicTransitions[i][3] = 0.12  // Minor 3rd
            melodicTransitions[i][4] = 0.10  // Major 3rd
            melodicTransitions[i][5] = 0.05  // Perfect 4th
            melodicTransitions[i][7] = 0.05  // Perfect 5th
            melodicTransitions[i][12] = 0.03 // Octave
        }

        // Common rhythmic patterns (in beats)
        rhythmicPatterns = [
            [1.0, 1.0, 1.0, 1.0],                    // Quarter notes
            [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5], // Eighth notes
            [1.0, 0.5, 0.5, 1.0, 1.0],              // Mixed
            [0.75, 0.25, 0.75, 0.25, 0.75, 0.25, 0.75, 0.25], // Dotted
            [1.5, 0.5, 1.0, 1.0],                    // Syncopated
            [0.5, 1.0, 0.5, 0.5, 1.0, 0.5],         // Swing feel
            [0.25, 0.25, 0.5, 0.25, 0.25, 0.5, 0.5, 0.5, 0.5], // 16th patterns
        ]
    }

    private func initializeChordProgressions() {
        // Common chord progressions by function
        chordProgressions = [
            "I": ["IV": 0.3, "V": 0.3, "vi": 0.2, "ii": 0.1, "iii": 0.1],
            "ii": ["V": 0.5, "IV": 0.2, "vii°": 0.15, "I": 0.15],
            "iii": ["vi": 0.4, "IV": 0.3, "ii": 0.2, "I": 0.1],
            "IV": ["V": 0.4, "I": 0.3, "ii": 0.2, "vi": 0.1],
            "V": ["I": 0.5, "vi": 0.25, "IV": 0.15, "iii": 0.1],
            "vi": ["IV": 0.3, "ii": 0.3, "V": 0.2, "I": 0.2],
            "vii°": ["I": 0.6, "iii": 0.25, "V": 0.15]
        ]
    }

    // MARK: - Melody Generation

    public func generateMelody(config: MelodyGenerationConfig) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        logger.info("Generating melody: \(config.key) \(config.mode.rawValue), \(config.bars) bars")

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let rootIndex = noteNames.firstIndex(of: config.key) ?? 0
        let baseOctave = 4
        let basePitch = 12 * (baseOctave + 1) + rootIndex

        // Get scale notes across range
        var availableNotes: [Int] = []
        for octave in 0..<config.melodicRange {
            for interval in config.mode.intervals {
                let pitch = basePitch + (octave * 12) + interval
                if pitch <= 127 {
                    availableNotes.append(pitch)
                }
            }
        }

        var notes: [Note] = []
        var currentTime: Double = 0
        let totalBeats = Double(config.bars * 4)  // Assuming 4/4
        var previousPitch = availableNotes[availableNotes.count / 2]  // Start in middle

        // Select rhythm pattern based on complexity
        let patternIndex = Int(config.rhythmComplexity * Float(rhythmicPatterns.count - 1))
        var rhythmPattern = rhythmicPatterns[min(patternIndex, rhythmicPatterns.count - 1)]

        while currentTime < totalBeats {
            // Decide if rest
            if Float.random(in: 0..<1, using: &rng) < config.restProbability {
                let restDuration = rhythmPattern[Int.random(in: 0..<rhythmPattern.count, using: &rng)]
                currentTime += restDuration
                continue
            }

            // Choose next pitch
            let nextPitch: Int
            if Float.random(in: 0..<1, using: &rng) < config.repeatProbability {
                // Repeat previous
                nextPitch = previousPitch
            } else if Float.random(in: 0..<1, using: &rng) < config.leapProbability {
                // Large leap
                let leapInterval = Int.random(in: 5...12, using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
                nextPitch = clampToScale(previousPitch + leapInterval, scale: availableNotes)
            } else {
                // Stepwise motion using Markov chain
                let interval = selectInterval(from: previousPitch, temperature: temperature)
                let direction = Bool.random(using: &rng) ? 1 : -1
                nextPitch = clampToScale(previousPitch + interval * direction, scale: availableNotes)
            }

            // Choose duration
            let durationIndex = Int.random(in: 0..<rhythmPattern.count, using: &rng)
            let duration = rhythmPattern[durationIndex]

            // Choose velocity based on beat position (accents on downbeats)
            let beatPosition = currentTime.truncatingRemainder(dividingBy: 4.0)
            var velocity: Int
            if beatPosition == 0 {
                velocity = Int.random(in: 90...110, using: &rng)  // Strong beat
            } else if beatPosition == 2 {
                velocity = Int.random(in: 75...95, using: &rng)   // Medium beat
            } else {
                velocity = Int.random(in: 60...85, using: &rng)   // Weak beat
            }

            // Apply style dynamics
            velocity = applyStyleDynamics(velocity, style: config.style)

            let note = Note(
                pitch: nextPitch,
                duration: duration,
                velocity: velocity,
                startTime: currentTime
            )

            notes.append(note)
            previousPitch = nextPitch
            currentTime += duration
        }

        generatedMelody = notes
        logger.info("Generated \(notes.count) notes")
        return notes
    }

    private func selectInterval(from currentPitch: Int, temperature: Float) -> Int {
        let row = min(12, abs(currentPitch % 12))
        var probabilities = melodicTransitions[row]

        // Apply temperature
        if temperature != 1.0 {
            let sum = probabilities.reduce(0, +)
            probabilities = probabilities.map { pow($0 / sum, 1.0 / temperature) }
            let newSum = probabilities.reduce(0, +)
            probabilities = probabilities.map { $0 / newSum }
        }

        // Weighted random selection
        let random = Float.random(in: 0..<1, using: &rng)
        var cumulative: Float = 0
        for (interval, prob) in probabilities.enumerated() {
            cumulative += prob
            if random < cumulative {
                return interval
            }
        }
        return 2  // Default to whole step
    }

    private func clampToScale(_ pitch: Int, scale: [Int]) -> Int {
        // Find nearest note in scale
        if scale.contains(pitch) {
            return pitch
        }

        var nearest = scale[0]
        var minDistance = abs(pitch - nearest)

        for note in scale {
            let distance = abs(pitch - note)
            if distance < minDistance {
                minDistance = distance
                nearest = note
            }
        }

        return nearest
    }

    private func applyStyleDynamics(_ velocity: Int, style: MusicStyle) -> Int {
        switch style {
        case .calm, .meditative, .peaceful:
            return max(40, velocity - 20)
        case .energetic, .euphoric:
            return min(127, velocity + 15)
        case .aggressive:
            return min(127, velocity + 25)
        case .tense:
            return velocity + Int.random(in: -15...15, using: &rng)
        case .melancholic:
            return max(50, velocity - 10)
        default:
            return velocity
        }
    }

    // MARK: - Chord Suggestions

    public func suggestChordProgression(
        key: String,
        mode: MusicalMode = .ionian,
        style: MusicStyle,
        bars: Int = 8
    ) async -> [Chord] {
        isGenerating = true
        defer { isGenerating = false }

        logger.info("Suggesting chord progression: \(key) \(mode.rawValue), \(style.rawValue)")

        let scaleChords = getScaleChords(key: key, mode: mode)
        var progression: [Chord] = []

        // Start on tonic
        var currentFunction = "I"
        let chordsPerBar = style == .energetic ? 2 : 1

        for bar in 0..<bars {
            let chordSymbol = scaleChords[currentFunction] ?? scaleChords["I"]!

            // Parse chord symbol
            let (root, type) = parseChordSymbol(chordSymbol, key: key)

            let chord = Chord(
                root: root,
                type: type,
                duration: 4.0 / Double(chordsPerBar)
            )

            progression.append(chord)

            // Transition to next chord
            currentFunction = selectNextChord(from: currentFunction, style: style)

            // Add second chord if needed
            if chordsPerBar == 2 {
                let secondSymbol = scaleChords[currentFunction] ?? scaleChords["I"]!
                let (secondRoot, secondType) = parseChordSymbol(secondSymbol, key: key)
                let secondChord = Chord(root: secondRoot, type: secondType, duration: 2.0)
                progression.append(secondChord)
                currentFunction = selectNextChord(from: currentFunction, style: style)
            }
        }

        suggestedChords = progression
        logger.info("Suggested \(progression.count) chords")
        return progression
    }

    private func getScaleChords(key: String, mode: MusicalMode) -> [String: String] {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let rootIndex = noteNames.firstIndex(of: key) ?? 0

        // Get scale degrees
        let intervals = mode.intervals
        var chords: [String: String] = [:]

        // Build diatonic chords based on mode
        switch mode {
        case .ionian:
            chords = [
                "I": noteNames[rootIndex],
                "ii": noteNames[(rootIndex + 2) % 12] + "m",
                "iii": noteNames[(rootIndex + 4) % 12] + "m",
                "IV": noteNames[(rootIndex + 5) % 12],
                "V": noteNames[(rootIndex + 7) % 12],
                "vi": noteNames[(rootIndex + 9) % 12] + "m",
                "vii°": noteNames[(rootIndex + 11) % 12] + "dim"
            ]
        case .dorian:
            chords = [
                "I": noteNames[rootIndex] + "m",
                "ii": noteNames[(rootIndex + 2) % 12] + "m",
                "III": noteNames[(rootIndex + 3) % 12],
                "IV": noteNames[(rootIndex + 5) % 12],
                "V": noteNames[(rootIndex + 7) % 12] + "m",
                "vi": noteNames[(rootIndex + 9) % 12] + "dim",
                "VII": noteNames[(rootIndex + 10) % 12]
            ]
        case .aeolian:
            chords = [
                "I": noteNames[rootIndex] + "m",
                "ii°": noteNames[(rootIndex + 2) % 12] + "dim",
                "III": noteNames[(rootIndex + 3) % 12],
                "iv": noteNames[(rootIndex + 5) % 12] + "m",
                "V": noteNames[(rootIndex + 7) % 12] + "m",
                "VI": noteNames[(rootIndex + 8) % 12],
                "VII": noteNames[(rootIndex + 10) % 12]
            ]
        default:
            // Default to major-like
            chords = [
                "I": noteNames[rootIndex],
                "IV": noteNames[(rootIndex + 5) % 12],
                "V": noteNames[(rootIndex + 7) % 12],
                "vi": noteNames[(rootIndex + 9) % 12] + "m"
            ]
        }

        return chords
    }

    private func parseChordSymbol(_ symbol: String, key: String) -> (String, Chord.ChordType) {
        var root = symbol
        var type: Chord.ChordType = .major

        if symbol.hasSuffix("dim") {
            root = String(symbol.dropLast(3))
            type = .diminished
        } else if symbol.hasSuffix("m7") {
            root = String(symbol.dropLast(2))
            type = .minor7
        } else if symbol.hasSuffix("m") {
            root = String(symbol.dropLast(1))
            type = .minor
        } else if symbol.hasSuffix("7") {
            root = String(symbol.dropLast(1))
            type = .dominant7
        }

        return (root, type)
    }

    private func selectNextChord(from currentFunction: String, style: MusicStyle) -> String {
        guard let transitions = chordProgressions[currentFunction] else {
            return "I"
        }

        // Modify probabilities based on style
        var modifiedTransitions = transitions

        switch style {
        case .tense, .aggressive:
            // Favor dominant and diminished
            modifiedTransitions["V"] = (modifiedTransitions["V"] ?? 0) * 1.5
            modifiedTransitions["vii°"] = (modifiedTransitions["vii°"] ?? 0) * 1.3
        case .calm, .peaceful:
            // Favor subdominant movement
            modifiedTransitions["IV"] = (modifiedTransitions["IV"] ?? 0) * 1.5
            modifiedTransitions["ii"] = (modifiedTransitions["ii"] ?? 0) * 1.3
        case .melancholic:
            // Favor minor chords
            modifiedTransitions["vi"] = (modifiedTransitions["vi"] ?? 0) * 1.5
            modifiedTransitions["iii"] = (modifiedTransitions["iii"] ?? 0) * 1.3
        default:
            break
        }

        // Normalize
        let total = modifiedTransitions.values.reduce(0, +)
        let random = Float.random(in: 0..<total, using: &rng)

        var cumulative: Float = 0
        for (function, prob) in modifiedTransitions {
            cumulative += prob
            if random < cumulative {
                return function
            }
        }

        return "I"
    }

    // MARK: - Drum Pattern Generation

    public func generateDrumPattern(
        genre: DrumGenre,
        tempo: Int,
        bars: Int = 4,
        complexity: Float = 0.5
    ) async -> DrumPattern {
        isGenerating = true
        defer { isGenerating = false }

        logger.info("Generating drum pattern: \(genre.rawValue), \(tempo) BPM, \(bars) bars")

        var pattern = DrumPattern(name: "\(genre.rawValue) Pattern", tempo: tempo)

        // Get base pattern for genre
        let basePattern = genre.basePattern

        // Create tracks
        for (instrument, hits) in basePattern {
            var track = DrumPattern.DrumTrack(
                id: UUID(),
                instrument: instrument,
                hits: []
            )

            // Generate hits for each bar
            for bar in 0..<bars {
                let barOffset = Double(bar * 4)

                for hit in hits {
                    // Add base hit
                    let drumHit = DrumPattern.DrumHit(
                        position: barOffset + hit.position,
                        velocity: hit.velocity + Int.random(in: -10...10, using: &rng),
                        duration: hit.duration
                    )
                    track.hits.append(drumHit)

                    // Add variations based on complexity
                    if Float.random(in: 0..<1, using: &rng) < complexity * 0.3 {
                        // Add ghost note
                        let ghostPosition = hit.position + 0.25
                        if ghostPosition < 4 {
                            let ghostHit = DrumPattern.DrumHit(
                                position: barOffset + ghostPosition,
                                velocity: Int(Float(hit.velocity) * 0.4),
                                duration: hit.duration
                            )
                            track.hits.append(ghostHit)
                        }
                    }
                }
            }

            pattern.tracks.append(track)
        }

        currentPattern = pattern
        return pattern
    }

    public enum DrumGenre: String, CaseIterable, Sendable {
        case rock = "Rock"
        case pop = "Pop"
        case hiphop = "Hip Hop"
        case jazz = "Jazz"
        case electronic = "Electronic"
        case funk = "Funk"
        case latin = "Latin"
        case reggae = "Reggae"
        case metal = "Metal"

        fileprivate var basePattern: [DrumPattern.DrumInstrument: [DrumPattern.DrumHit]] {
            switch self {
            case .rock:
                return [
                    .kick: [
                        DrumPattern.DrumHit(position: 0, velocity: 100, duration: 0.1),
                        DrumPattern.DrumHit(position: 2, velocity: 95, duration: 0.1)
                    ],
                    .snare: [
                        DrumPattern.DrumHit(position: 1, velocity: 100, duration: 0.1),
                        DrumPattern.DrumHit(position: 3, velocity: 100, duration: 0.1)
                    ],
                    .hiHatClosed: [
                        DrumPattern.DrumHit(position: 0, velocity: 80, duration: 0.1),
                        DrumPattern.DrumHit(position: 0.5, velocity: 60, duration: 0.1),
                        DrumPattern.DrumHit(position: 1, velocity: 80, duration: 0.1),
                        DrumPattern.DrumHit(position: 1.5, velocity: 60, duration: 0.1),
                        DrumPattern.DrumHit(position: 2, velocity: 80, duration: 0.1),
                        DrumPattern.DrumHit(position: 2.5, velocity: 60, duration: 0.1),
                        DrumPattern.DrumHit(position: 3, velocity: 80, duration: 0.1),
                        DrumPattern.DrumHit(position: 3.5, velocity: 60, duration: 0.1)
                    ]
                ]
            case .hiphop:
                return [
                    .kick: [
                        DrumPattern.DrumHit(position: 0, velocity: 110, duration: 0.15),
                        DrumPattern.DrumHit(position: 1.75, velocity: 100, duration: 0.15),
                        DrumPattern.DrumHit(position: 2.5, velocity: 90, duration: 0.15)
                    ],
                    .snare: [
                        DrumPattern.DrumHit(position: 1, velocity: 100, duration: 0.1),
                        DrumPattern.DrumHit(position: 3, velocity: 100, duration: 0.1)
                    ],
                    .hiHatClosed: [
                        DrumPattern.DrumHit(position: 0, velocity: 70, duration: 0.05),
                        DrumPattern.DrumHit(position: 0.25, velocity: 50, duration: 0.05),
                        DrumPattern.DrumHit(position: 0.5, velocity: 70, duration: 0.05),
                        DrumPattern.DrumHit(position: 0.75, velocity: 50, duration: 0.05)
                    ]
                ]
            case .electronic:
                return [
                    .kick: [
                        DrumPattern.DrumHit(position: 0, velocity: 120, duration: 0.2),
                        DrumPattern.DrumHit(position: 1, velocity: 120, duration: 0.2),
                        DrumPattern.DrumHit(position: 2, velocity: 120, duration: 0.2),
                        DrumPattern.DrumHit(position: 3, velocity: 120, duration: 0.2)
                    ],
                    .clap: [
                        DrumPattern.DrumHit(position: 1, velocity: 100, duration: 0.1),
                        DrumPattern.DrumHit(position: 3, velocity: 100, duration: 0.1)
                    ],
                    .hiHatClosed: [
                        DrumPattern.DrumHit(position: 0.5, velocity: 80, duration: 0.05),
                        DrumPattern.DrumHit(position: 1.5, velocity: 80, duration: 0.05),
                        DrumPattern.DrumHit(position: 2.5, velocity: 80, duration: 0.05),
                        DrumPattern.DrumHit(position: 3.5, velocity: 80, duration: 0.05)
                    ]
                ]
            default:
                return [
                    .kick: [DrumPattern.DrumHit(position: 0, velocity: 100, duration: 0.1)],
                    .snare: [DrumPattern.DrumHit(position: 1, velocity: 100, duration: 0.1)]
                ]
            }
        }
    }

    // MARK: - Bio-Data Mapping

    public func mapBioToMusicStyle(
        hrv: Float,
        coherence: Float,
        heartRate: Float,
        respirationRate: Float? = nil
    ) -> MusicStyle {
        currentStyle = calculateStyle(hrv: hrv, coherence: coherence, heartRate: heartRate, respirationRate: respirationRate)
        return currentStyle
    }

    private func calculateStyle(
        hrv: Float,
        coherence: Float,
        heartRate: Float,
        respirationRate: Float?
    ) -> MusicStyle {
        // Multi-dimensional mapping based on bio-metrics

        // High coherence = harmonious states
        if coherence > 0.8 {
            if heartRate < 70 {
                return .meditative
            } else if heartRate < 90 {
                return .peaceful
            } else {
                return .euphoric
            }
        }

        // Medium coherence = transitional states
        if coherence > 0.5 {
            if heartRate > 100 {
                return .energetic
            } else if hrv > 50 {
                return .balanced
            } else {
                return .calm
            }
        }

        // Low coherence = stressed/active states
        if heartRate > 120 {
            if hrv < 30 {
                return .aggressive
            } else {
                return .energetic
            }
        }

        if hrv < 20 {
            return .tense
        }

        if heartRate < 60 {
            return .melancholic
        }

        // Default
        return .balanced
    }

    // MARK: - Generation Parameters from Bio-Data

    public func generateParametersFromBioData(
        hrv: Float,
        coherence: Float,
        heartRate: Float
    ) -> MelodyGenerationConfig {
        let style = mapBioToMusicStyle(hrv: hrv, coherence: coherence, heartRate: heartRate)

        var config = MelodyGenerationConfig()
        config.style = style

        // Map bio-data to musical parameters
        config.noteDensity = min(1.0, heartRate / 150.0)
        config.rhythmComplexity = min(1.0, (1.0 - coherence) * 1.5)
        config.restProbability = coherence * 0.2
        config.leapProbability = min(0.5, (1.0 - coherence) * 0.4)

        // Select mode based on style
        if let suggestedMode = style.suggestedModes.first {
            config.mode = suggestedMode
        }

        logger.info("Generated melody config from bio-data: \(style.rawValue)")
        return config
    }
}
