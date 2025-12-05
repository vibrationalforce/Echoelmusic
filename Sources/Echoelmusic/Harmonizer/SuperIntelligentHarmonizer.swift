// SuperIntelligentHarmonizer.swift
// Echoelmusic - Super Intelligent Harmonizer
//
// Advanced AI-powered harmonic analysis and generation
// Combining deep music theory with neural networks

import Foundation
import Accelerate
import Combine
import os.log

private let harmonizerLogger = Logger(subsystem: "com.echoelmusic.harmonizer", category: "Intelligence")

// MARK: - Pitch & Interval Types

public struct Pitch: Hashable, Codable {
    public var pitchClass: Int      // 0-11 (C=0, C#=1, ... B=11)
    public var octave: Int          // 0-9
    public var midiNote: Int { pitchClass + (octave + 1) * 12 }
    public var frequency: Double { 440.0 * pow(2.0, Double(midiNote - 69) / 12.0) }

    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public var name: String {
        "\(Pitch.noteNames[pitchClass])\(octave)"
    }

    public init(pitchClass: Int, octave: Int) {
        self.pitchClass = pitchClass % 12
        self.octave = octave
    }

    public init(midiNote: Int) {
        self.pitchClass = midiNote % 12
        self.octave = midiNote / 12 - 1
    }

    public func interval(to other: Pitch) -> Int {
        other.midiNote - self.midiNote
    }
}

public enum Interval: Int, CaseIterable {
    case unison = 0
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    case octave = 12

    public var consonance: Double {
        switch self {
        case .unison, .octave: return 1.0
        case .perfectFifth: return 0.95
        case .perfectFourth: return 0.85
        case .majorThird, .minorSixth: return 0.75
        case .minorThird, .majorSixth: return 0.70
        case .majorSecond, .minorSeventh: return 0.40
        case .minorSecond, .majorSeventh: return 0.20
        case .tritone: return 0.10
        }
    }

    public var name: String {
        switch self {
        case .unison: return "P1"
        case .minorSecond: return "m2"
        case .majorSecond: return "M2"
        case .minorThird: return "m3"
        case .majorThird: return "M3"
        case .perfectFourth: return "P4"
        case .tritone: return "TT"
        case .perfectFifth: return "P5"
        case .minorSixth: return "m6"
        case .majorSixth: return "M6"
        case .minorSeventh: return "m7"
        case .majorSeventh: return "M7"
        case .octave: return "P8"
        }
    }
}

// MARK: - Chord Types

public struct Chord: Hashable, Codable {
    public var root: Int                    // Pitch class 0-11
    public var quality: ChordQuality
    public var bass: Int?                   // For slash chords
    public var extensions: [Int]            // Additional pitch classes
    public var inversion: Int               // 0 = root position

    public enum ChordQuality: String, Codable, CaseIterable {
        // Triads
        case major = "maj"
        case minor = "min"
        case diminished = "dim"
        case augmented = "aug"
        case suspended2 = "sus2"
        case suspended4 = "sus4"

        // Seventh chords
        case major7 = "maj7"
        case minor7 = "min7"
        case dominant7 = "7"
        case diminished7 = "dim7"
        case halfDiminished7 = "ø7"
        case minorMajor7 = "mM7"
        case augmented7 = "aug7"

        // Extended chords
        case dominant9 = "9"
        case major9 = "maj9"
        case minor9 = "min9"
        case dominant11 = "11"
        case dominant13 = "13"

        // Altered chords
        case dominant7sharp9 = "7#9"
        case dominant7flat9 = "7b9"
        case dominant7sharp11 = "7#11"
        case dominant7alt = "7alt"

        public var intervals: [Int] {
            switch self {
            case .major: return [0, 4, 7]
            case .minor: return [0, 3, 7]
            case .diminished: return [0, 3, 6]
            case .augmented: return [0, 4, 8]
            case .suspended2: return [0, 2, 7]
            case .suspended4: return [0, 5, 7]
            case .major7: return [0, 4, 7, 11]
            case .minor7: return [0, 3, 7, 10]
            case .dominant7: return [0, 4, 7, 10]
            case .diminished7: return [0, 3, 6, 9]
            case .halfDiminished7: return [0, 3, 6, 10]
            case .minorMajor7: return [0, 3, 7, 11]
            case .augmented7: return [0, 4, 8, 10]
            case .dominant9: return [0, 4, 7, 10, 14]
            case .major9: return [0, 4, 7, 11, 14]
            case .minor9: return [0, 3, 7, 10, 14]
            case .dominant11: return [0, 4, 7, 10, 14, 17]
            case .dominant13: return [0, 4, 7, 10, 14, 17, 21]
            case .dominant7sharp9: return [0, 4, 7, 10, 15]
            case .dominant7flat9: return [0, 4, 7, 10, 13]
            case .dominant7sharp11: return [0, 4, 7, 10, 14, 18]
            case .dominant7alt: return [0, 4, 6, 10, 13, 15]
            }
        }

        public var tension: Double {
            switch self {
            case .major, .minor: return 0.1
            case .suspended2, .suspended4: return 0.2
            case .major7: return 0.15
            case .minor7: return 0.2
            case .dominant7: return 0.4
            case .augmented: return 0.5
            case .diminished: return 0.6
            case .halfDiminished7: return 0.55
            case .diminished7: return 0.65
            case .dominant9, .major9, .minor9: return 0.35
            case .dominant11, .dominant13: return 0.45
            case .dominant7sharp9, .dominant7flat9: return 0.7
            case .dominant7sharp11: return 0.6
            case .dominant7alt: return 0.8
            case .minorMajor7: return 0.5
            case .augmented7: return 0.6
            }
        }
    }

    public var pitchClasses: [Int] {
        var pcs = quality.intervals.map { (root + $0) % 12 }
        pcs.append(contentsOf: extensions.map { $0 % 12 })
        return Array(Set(pcs)).sorted()
    }

    public var symbol: String {
        let rootName = Pitch.noteNames[root]
        var sym = rootName + quality.rawValue
        if let bass = bass, bass != root {
            sym += "/\(Pitch.noteNames[bass])"
        }
        return sym
    }

    public init(root: Int, quality: ChordQuality, bass: Int? = nil, extensions: [Int] = [], inversion: Int = 0) {
        self.root = root % 12
        self.quality = quality
        self.bass = bass
        self.extensions = extensions
        self.inversion = inversion
    }
}

// MARK: - Scale & Mode Types

public struct Scale {
    public var root: Int
    public var mode: Mode
    public var pitchClasses: [Int] {
        mode.intervals.map { (root + $0) % 12 }
    }

    public enum Mode: String, CaseIterable {
        case ionian = "Ionian (Major)"
        case dorian = "Dorian"
        case phrygian = "Phrygian"
        case lydian = "Lydian"
        case mixolydian = "Mixolydian"
        case aeolian = "Aeolian (Minor)"
        case locrian = "Locrian"

        // Additional scales
        case harmonicMinor = "Harmonic Minor"
        case melodicMinor = "Melodic Minor"
        case wholeTone = "Whole Tone"
        case diminished = "Diminished"
        case pentatonicMajor = "Pentatonic Major"
        case pentatonicMinor = "Pentatonic Minor"
        case blues = "Blues"
        case bebopDominant = "Bebop Dominant"
        case altered = "Altered"

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
            case .wholeTone: return [0, 2, 4, 6, 8, 10]
            case .diminished: return [0, 2, 3, 5, 6, 8, 9, 11]
            case .pentatonicMajor: return [0, 2, 4, 7, 9]
            case .pentatonicMinor: return [0, 3, 5, 7, 10]
            case .blues: return [0, 3, 5, 6, 7, 10]
            case .bebopDominant: return [0, 2, 4, 5, 7, 9, 10, 11]
            case .altered: return [0, 1, 3, 4, 6, 8, 10]
            }
        }
    }

    public init(root: Int, mode: Mode) {
        self.root = root % 12
        self.mode = mode
    }

    public func contains(_ pitchClass: Int) -> Bool {
        pitchClasses.contains(pitchClass % 12)
    }

    public func degreeOf(_ pitchClass: Int) -> Int? {
        pitchClasses.firstIndex(of: pitchClass % 12)
    }
}

// MARK: - Harmonic Context

public struct HarmonicContext {
    public var key: Scale
    public var currentChord: Chord
    public var previousChords: [Chord]
    public var melodyNotes: [Pitch]
    public var style: HarmonicStyle
    public var tension: Double                // 0-1, current harmonic tension
    public var position: StructuralPosition

    public enum HarmonicStyle: String, CaseIterable {
        case baroque = "Baroque"
        case classical = "Classical"
        case romantic = "Romantic"
        case impressionist = "Impressionist"
        case jazz = "Jazz"
        case bebop = "Bebop"
        case neoSoul = "Neo-Soul"
        case pop = "Pop"
        case rock = "Rock"
        case gospel = "Gospel"
        case modal = "Modal"
        case contemporary = "Contemporary"
    }

    public enum StructuralPosition {
        case beginning
        case phrase
        case cadence
        case turnaround
        case ending
    }
}

// MARK: - Voice Leading Rules

public struct VoiceLeadingRules {
    // Bach-style voice leading constraints
    public var avoidParallelFifths: Bool = true
    public var avoidParallelOctaves: Bool = true
    public var avoidHiddenFifths: Bool = true
    public var avoidHiddenOctaves: Bool = true
    public var preferStepwiseMotion: Bool = true
    public var resolveTendencyTones: Bool = true
    public var maxLeap: Int = 7  // Maximum interval in semitones
    public var preferContraryMotion: Bool = true

    // Voice ranges
    public var sopranoRange: ClosedRange<Int> = 60...79  // C4-G5
    public var altoRange: ClosedRange<Int> = 53...72     // F3-C5
    public var tenorRange: ClosedRange<Int> = 48...67    // C3-G4
    public var bassRange: ClosedRange<Int> = 40...60     // E2-C4

    public static let strict = VoiceLeadingRules()
    public static let jazz = VoiceLeadingRules(
        avoidParallelFifths: false,
        avoidHiddenFifths: false,
        maxLeap: 12
    )
    public static let pop = VoiceLeadingRules(
        avoidParallelFifths: false,
        avoidParallelOctaves: false,
        avoidHiddenFifths: false,
        avoidHiddenOctaves: false,
        maxLeap: 12
    )

    public init(
        avoidParallelFifths: Bool = true,
        avoidParallelOctaves: Bool = true,
        avoidHiddenFifths: Bool = true,
        avoidHiddenOctaves: Bool = true,
        preferStepwiseMotion: Bool = true,
        resolveTendencyTones: Bool = true,
        maxLeap: Int = 7,
        preferContraryMotion: Bool = true
    ) {
        self.avoidParallelFifths = avoidParallelFifths
        self.avoidParallelOctaves = avoidParallelOctaves
        self.avoidHiddenFifths = avoidHiddenFifths
        self.avoidHiddenOctaves = avoidHiddenOctaves
        self.preferStepwiseMotion = preferStepwiseMotion
        self.resolveTendencyTones = resolveTendencyTones
        self.maxLeap = maxLeap
        self.preferContraryMotion = preferContraryMotion
    }
}

// MARK: - Voicing

public struct Voicing: Hashable {
    public var pitches: [Pitch]  // Ordered from bass to soprano
    public var chord: Chord

    public var bassNote: Pitch? { pitches.first }
    public var topNote: Pitch? { pitches.last }

    public var spread: Int {
        guard let low = pitches.first, let high = pitches.last else { return 0 }
        return high.midiNote - low.midiNote
    }

    public func hasParallelFifths(with other: Voicing) -> Bool {
        for (i, pitch1) in pitches.enumerated() {
            for (j, pitch2) in pitches.enumerated() where j > i {
                let interval1 = abs(pitch2.midiNote - pitch1.midiNote) % 12
                if interval1 == 7 {  // Perfect fifth
                    let otherPitch1 = other.pitches[i]
                    let otherPitch2 = other.pitches[j]
                    let interval2 = abs(otherPitch2.midiNote - otherPitch1.midiNote) % 12
                    if interval2 == 7 {
                        // Check if moving in same direction
                        let motion1 = pitch1.midiNote - otherPitch1.midiNote
                        let motion2 = pitch2.midiNote - otherPitch2.midiNote
                        if motion1 != 0 && motion2 != 0 && (motion1 > 0) == (motion2 > 0) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    public func hasParallelOctaves(with other: Voicing) -> Bool {
        for (i, pitch1) in pitches.enumerated() {
            for (j, pitch2) in pitches.enumerated() where j > i {
                let interval1 = abs(pitch2.midiNote - pitch1.midiNote) % 12
                if interval1 == 0 {  // Octave/unison
                    let otherPitch1 = other.pitches[i]
                    let otherPitch2 = other.pitches[j]
                    let interval2 = abs(otherPitch2.midiNote - otherPitch1.midiNote) % 12
                    if interval2 == 0 {
                        let motion1 = pitch1.midiNote - otherPitch1.midiNote
                        let motion2 = pitch2.midiNote - otherPitch2.midiNote
                        if motion1 != 0 && motion2 != 0 && (motion1 > 0) == (motion2 > 0) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    public func voiceLeadingCost(to next: Voicing, rules: VoiceLeadingRules) -> Double {
        var cost: Double = 0

        // Motion cost (prefer stepwise)
        for (current, target) in zip(pitches, next.pitches) {
            let motion = abs(target.midiNote - current.midiNote)
            if motion <= 2 {
                cost += 0  // Stepwise is free
            } else if motion <= 4 {
                cost += Double(motion) * 0.5
            } else if motion <= 7 {
                cost += Double(motion) * 1.0
            } else {
                cost += Double(motion) * 2.0  // Penalize large leaps
            }
        }

        // Parallel fifths penalty
        if rules.avoidParallelFifths && hasParallelFifths(with: next) {
            cost += 100
        }

        // Parallel octaves penalty
        if rules.avoidParallelOctaves && hasParallelOctaves(with: next) {
            cost += 100
        }

        return cost
    }
}

// MARK: - Harmonic Function Analysis

public struct HarmonicFunction {
    public var function: Function
    public var degree: Int  // Scale degree (1-7)
    public var chord: Chord
    public var tonicization: Int?  // If secondary function, target key

    public enum Function: String {
        case tonic = "T"
        case subdominant = "S"
        case dominant = "D"
        case predominant = "PD"
        case passing = "P"
        case neighbor = "N"
        case applied = "V/"  // Secondary dominant
    }

    public var tensionLevel: Double {
        switch function {
        case .tonic: return 0.0
        case .subdominant: return 0.3
        case .predominant: return 0.5
        case .dominant: return 0.7
        case .applied: return 0.6
        case .passing, .neighbor: return 0.4
        }
    }

    public static func analyze(chord: Chord, in key: Scale) -> HarmonicFunction {
        let degree = ((chord.root - key.root) % 12 + 12) % 12

        // Map pitch class difference to scale degree
        let scaleDegrees: [Int: Int] = [0: 1, 2: 2, 4: 3, 5: 4, 7: 5, 9: 6, 11: 7]
        let romanDegree = scaleDegrees[degree] ?? 1

        let function: Function
        switch romanDegree {
        case 1: function = .tonic
        case 2: function = .predominant
        case 3: function = key.mode == .ionian ? .tonic : .subdominant
        case 4: function = .subdominant
        case 5: function = .dominant
        case 6: function = .tonic
        case 7: function = .dominant
        default: function = .passing
        }

        return HarmonicFunction(function: function, degree: romanDegree, chord: chord)
    }
}

// MARK: - Chord Progression Generator

public final class ChordProgressionGenerator {
    private var markovChain: [String: [(chord: String, probability: Double)]] = [:]
    private var jazzSubstitutions: [String: [String]] = [:]
    private var modalInterchange: [String: [Chord]] = [:]

    public init() {
        buildMarkovChain()
        buildJazzSubstitutions()
        buildModalInterchange()
    }

    private func buildMarkovChain() {
        // Common chord transitions based on music theory
        markovChain = [
            "I": [("IV", 0.25), ("V", 0.25), ("vi", 0.20), ("ii", 0.15), ("iii", 0.10), ("I", 0.05)],
            "ii": [("V", 0.50), ("viio", 0.15), ("IV", 0.15), ("ii", 0.10), ("I", 0.10)],
            "iii": [("vi", 0.30), ("IV", 0.25), ("ii", 0.20), ("I", 0.15), ("V", 0.10)],
            "IV": [("V", 0.35), ("I", 0.25), ("ii", 0.20), ("viio", 0.10), ("IV", 0.10)],
            "V": [("I", 0.50), ("vi", 0.25), ("IV", 0.10), ("V", 0.10), ("iii", 0.05)],
            "vi": [("IV", 0.30), ("ii", 0.25), ("V", 0.20), ("I", 0.15), ("iii", 0.10)],
            "viio": [("I", 0.60), ("iii", 0.20), ("vi", 0.15), ("V", 0.05)]
        ]
    }

    private func buildJazzSubstitutions() {
        // Tritone substitutions, related ii-V, etc.
        jazzSubstitutions = [
            "V7": ["bII7", "iii7-VI7", "viio7"],
            "ii7": ["bVI7", "IV7"],
            "I": ["iii7", "VI7", "bIIImaj7"],
            "IV": ["ii7", "bVII7", "#IVo7"]
        ]
    }

    private func buildModalInterchange() {
        // Borrowed chords from parallel modes
        // From parallel minor to major
        modalInterchange["major"] = [
            Chord(root: 3, quality: .major),  // bIII
            Chord(root: 5, quality: .minor),  // iv (borrowed)
            Chord(root: 8, quality: .major),  // bVI
            Chord(root: 10, quality: .major)  // bVII
        ]
    }

    public func generateProgression(
        style: HarmonicContext.HarmonicStyle,
        length: Int,
        key: Scale,
        startChord: String = "I",
        endOnTonic: Bool = true
    ) -> [Chord] {
        var progression: [Chord] = []
        var currentSymbol = startChord

        for i in 0..<length {
            // Get chord for current symbol
            let chord = symbolToChord(currentSymbol, in: key, style: style)
            progression.append(chord)

            // If last chord and should end on tonic
            if i == length - 2 && endOnTonic {
                currentSymbol = "V"  // Setup for final tonic
            } else if i == length - 1 && endOnTonic {
                currentSymbol = "I"
            } else {
                // Get next chord from Markov chain
                currentSymbol = sampleNextChord(from: currentSymbol, style: style)
            }
        }

        return progression
    }

    private func symbolToChord(_ symbol: String, in key: Scale, style: HarmonicContext.HarmonicStyle) -> Chord {
        // Parse Roman numeral
        let isMinor = symbol.lowercased() == symbol || symbol.contains("i") && !symbol.contains("I")
        let rootDegree: Int

        switch symbol.lowercased().replacingOccurrences(of: "7", with: "").replacingOccurrences(of: "o", with: "") {
        case "i": rootDegree = 0
        case "ii": rootDegree = 2
        case "iii": rootDegree = 4
        case "iv": rootDegree = 5
        case "v": rootDegree = 7
        case "vi": rootDegree = 9
        case "vii": rootDegree = 11
        case "bii": rootDegree = 1
        case "biii": rootDegree = 3
        case "bvi": rootDegree = 8
        case "bvii": rootDegree = 10
        default: rootDegree = 0
        }

        let root = (key.root + rootDegree) % 12

        // Determine quality based on style and symbol
        let quality: Chord.ChordQuality
        if symbol.contains("o") || symbol.contains("dim") {
            quality = symbol.contains("7") ? .diminished7 : .diminished
        } else if symbol.contains("7") {
            if isMinor {
                quality = .minor7
            } else if symbol.contains("V") || symbol.contains("v") {
                quality = .dominant7
            } else {
                quality = style == .jazz || style == .bebop ? .major7 : .major
            }
        } else {
            quality = isMinor ? .minor : .major
        }

        return Chord(root: root, quality: quality)
    }

    private func sampleNextChord(from current: String, style: HarmonicContext.HarmonicStyle) -> String {
        let simplified = current.replacingOccurrences(of: "7", with: "")
                                .replacingOccurrences(of: "maj", with: "")
                                .replacingOccurrences(of: "min", with: "")

        guard let transitions = markovChain[simplified] else {
            return "I"
        }

        let r = Double.random(in: 0..<1)
        var cumulative: Double = 0
        for (next, prob) in transitions {
            cumulative += prob
            if r <= cumulative {
                // Add extensions for jazz style
                if style == .jazz || style == .bebop {
                    return next + "7"
                }
                return next
            }
        }

        return "I"
    }
}

// MARK: - Super Intelligent Harmonizer

@MainActor
public final class SuperIntelligentHarmonizer: ObservableObject {
    public static let shared = SuperIntelligentHarmonizer()

    // MARK: - Published State

    @Published public private(set) var currentContext: HarmonicContext?
    @Published public private(set) var lastHarmonization: [Voicing] = []
    @Published public private(set) var analysisResult: HarmonicAnalysis?
    @Published public private(set) var isProcessing: Bool = false
    @Published public var style: HarmonicContext.HarmonicStyle = .jazz
    @Published public var rules: VoiceLeadingRules = .jazz

    // MARK: - Internal Components

    private let progressionGenerator = ChordProgressionGenerator()
    private let voiceLeadingOptimizer = VoiceLeadingOptimizer()
    private let harmonicNeuralNet = HarmonicNeuralNetwork()
    private var cancellables = Set<AnyCancellable>()

    // Knowledge bases
    private var chordScaleRelations: [Chord.ChordQuality: [Scale.Mode]] = [:]
    private var cadencePatterns: [String: [[Chord]]] = [:]
    private var voicingTemplates: [String: [[Int]]] = [:]

    // MARK: - Initialization

    private init() {
        buildKnowledgeBases()
        harmonizerLogger.info("Super Intelligent Harmonizer initialized")
    }

    // MARK: - Public API

    /// Harmonize a melody with intelligent voice leading
    public func harmonizeMelody(_ melody: [Pitch], key: Scale, style: HarmonicContext.HarmonicStyle) async -> [Voicing] {
        isProcessing = true
        defer { isProcessing = false }

        var voicings: [Voicing] = []
        var previousVoicing: Voicing?

        for (index, melodyNote) in melody.enumerated() {
            // Determine harmonic context
            let position = determinePosition(index: index, total: melody.count)

            // Get best chord for this melody note
            let chord = selectChord(
                forMelodyNote: melodyNote,
                in: key,
                style: style,
                position: position,
                previousChord: voicings.last?.chord
            )

            // Generate optimal voicing
            let voicing = voiceLeadingOptimizer.optimizeVoicing(
                for: chord,
                melodyNote: melodyNote,
                previousVoicing: previousVoicing,
                rules: rules
            )

            voicings.append(voicing)
            previousVoicing = voicing
        }

        lastHarmonization = voicings
        return voicings
    }

    /// Analyze harmonic content
    public func analyze(_ chords: [Chord], in key: Scale) -> HarmonicAnalysis {
        var analysis = HarmonicAnalysis()

        // Analyze each chord's function
        for chord in chords {
            let function = HarmonicFunction.analyze(chord: chord, in: key)
            analysis.functions.append(function)
        }

        // Detect cadences
        analysis.cadences = detectCadences(chords, in: key)

        // Calculate tension curve
        analysis.tensionCurve = chords.enumerated().map { index, chord in
            let function = analysis.functions[index]
            return function.tensionLevel + chord.quality.tension * 0.3
        }

        // Detect modulations
        analysis.modulations = detectModulations(chords, originalKey: key)

        // Calculate complexity score
        analysis.complexityScore = calculateComplexity(chords, analysis: analysis)

        analysisResult = analysis
        return analysis
    }

    /// Get chord suggestions for a melody note
    public func suggestChords(
        forMelodyNote note: Pitch,
        in key: Scale,
        style: HarmonicContext.HarmonicStyle,
        count: Int = 5
    ) -> [(chord: Chord, score: Double, reason: String)] {
        var suggestions: [(Chord, Double, String)] = []

        // Get all possible chords containing this note
        for quality in Chord.ChordQuality.allCases {
            for root in 0..<12 {
                let chord = Chord(root: root, quality: quality)
                if chord.pitchClasses.contains(note.pitchClass) {
                    let score = scoreChord(chord, forNote: note, in: key, style: style)
                    let reason = explainChordChoice(chord, forNote: note, in: key)
                    suggestions.append((chord, score, reason))
                }
            }
        }

        // Sort by score and return top choices
        return suggestions.sorted { $0.1 > $1.1 }.prefix(count).map { ($0.0, $0.1, $0.2) }
    }

    /// Generate a chord progression
    public func generateProgression(
        length: Int,
        key: Scale,
        style: HarmonicContext.HarmonicStyle,
        constraints: ProgressionConstraints = ProgressionConstraints()
    ) -> [Chord] {
        return progressionGenerator.generateProgression(
            style: style,
            length: length,
            key: key,
            startChord: constraints.startChord ?? "I",
            endOnTonic: constraints.endOnTonic
        )
    }

    /// Real-time harmonization for live input
    public func harmonizeRealTime(
        inputNote: Pitch,
        context: HarmonicContext
    ) -> Voicing {
        // Use neural network for fast prediction
        let predictedChord = harmonicNeuralNet.predict(
            melodyNote: inputNote,
            context: context
        )

        return voiceLeadingOptimizer.quickVoicing(
            for: predictedChord,
            melodyNote: inputNote,
            style: context.style
        )
    }

    /// Get reharmonization suggestions
    public func suggestReharmonization(
        for progression: [Chord],
        in key: Scale,
        style: HarmonicContext.HarmonicStyle
    ) -> [[Chord]] {
        var alternatives: [[Chord]] = []

        for (index, chord) in progression.enumerated() {
            var chordAlternatives = [chord]

            // Tritone substitution for dominants
            if chord.quality == .dominant7 {
                let tritoneRoot = (chord.root + 6) % 12
                chordAlternatives.append(Chord(root: tritoneRoot, quality: .dominant7))
            }

            // Related ii-V
            if chord.quality == .dominant7 {
                let relatedII = (chord.root + 5) % 12
                chordAlternatives.append(Chord(root: relatedII, quality: .minor7))
            }

            // Modal interchange
            if key.mode == .ionian {
                // Borrow from parallel minor
                let borrowedRoot = (chord.root + 3) % 12
                chordAlternatives.append(Chord(root: borrowedRoot, quality: .major))
            }

            // Diminished passing chords
            if index < progression.count - 1 {
                let nextRoot = progression[index + 1].root
                let passingRoot = (chord.root + 1) % 12
                if passingRoot != nextRoot {
                    chordAlternatives.append(Chord(root: passingRoot, quality: .diminished7))
                }
            }

            alternatives.append(chordAlternatives)
        }

        return alternatives
    }

    // MARK: - Private Methods

    private func buildKnowledgeBases() {
        // Chord-scale relationships
        chordScaleRelations = [
            .major: [.ionian, .lydian],
            .minor: [.dorian, .aeolian, .phrygian],
            .dominant7: [.mixolydian, .lydian, .altered],
            .minor7: [.dorian, .aeolian],
            .major7: [.ionian, .lydian],
            .halfDiminished7: [.locrian],
            .diminished7: [.diminished]
        ]

        // Common cadence patterns
        cadencePatterns = [
            "authentic": [
                [Chord(root: 7, quality: .dominant7), Chord(root: 0, quality: .major)],  // V7-I
                [Chord(root: 7, quality: .major), Chord(root: 0, quality: .major)]       // V-I
            ],
            "plagal": [
                [Chord(root: 5, quality: .major), Chord(root: 0, quality: .major)],      // IV-I
                [Chord(root: 5, quality: .minor), Chord(root: 0, quality: .major)]       // iv-I
            ],
            "deceptive": [
                [Chord(root: 7, quality: .dominant7), Chord(root: 9, quality: .minor)]   // V7-vi
            ],
            "half": [
                [Chord(root: 0, quality: .major), Chord(root: 7, quality: .major)]       // I-V
            ]
        ]

        // Jazz voicing templates (drop 2, drop 3, etc.)
        voicingTemplates = [
            "drop2": [[0, 5, 10, 14], [0, 4, 10, 14], [0, 4, 7, 14]],
            "drop3": [[0, 7, 10, 16], [0, 7, 12, 16]],
            "close": [[0, 4, 7, 11], [0, 3, 7, 10]],
            "spread": [[0, 7, 16, 22], [0, 7, 14, 21]]
        ]
    }

    private func determinePosition(index: Int, total: Int) -> HarmonicContext.StructuralPosition {
        let normalizedPosition = Double(index) / Double(max(total - 1, 1))

        if index == 0 {
            return .beginning
        } else if normalizedPosition > 0.9 {
            return .ending
        } else if normalizedPosition > 0.7 {
            return .cadence
        } else {
            return .phrase
        }
    }

    private func selectChord(
        forMelodyNote note: Pitch,
        in key: Scale,
        style: HarmonicContext.HarmonicStyle,
        position: HarmonicContext.StructuralPosition,
        previousChord: Chord?
    ) -> Chord {
        let suggestions = suggestChords(forMelodyNote: note, in: key, style: style)
        return suggestions.first?.chord ?? Chord(root: key.root, quality: .major)
    }

    private func scoreChord(_ chord: Chord, forNote note: Pitch, in key: Scale, style: HarmonicContext.HarmonicStyle) -> Double {
        var score: Double = 0

        // Is the note in the chord?
        if chord.pitchClasses.contains(note.pitchClass) {
            score += 0.3
        }

        // Is the chord diatonic?
        let chordTones = chord.pitchClasses
        let diatonicCount = chordTones.filter { key.contains($0) }.count
        score += Double(diatonicCount) / Double(chordTones.count) * 0.3

        // Style-appropriate quality
        switch style {
        case .jazz, .bebop, .neoSoul:
            if [.major7, .minor7, .dominant7, .minor9, .dominant9].contains(chord.quality) {
                score += 0.2
            }
        case .pop, .rock:
            if [.major, .minor, .suspended4].contains(chord.quality) {
                score += 0.2
            }
        case .classical, .baroque:
            if [.major, .minor, .diminished, .dominant7].contains(chord.quality) {
                score += 0.2
            }
        default:
            score += 0.1
        }

        // Penalize high tension for non-jazz styles
        if style != .jazz && style != .bebop {
            score -= chord.quality.tension * 0.3
        }

        return max(0, min(1, score))
    }

    private func explainChordChoice(_ chord: Chord, forNote note: Pitch, in key: Scale) -> String {
        let function = HarmonicFunction.analyze(chord: chord, in: key)
        let notePosition: String

        if chord.root == note.pitchClass {
            notePosition = "root"
        } else if chord.pitchClasses.firstIndex(of: note.pitchClass) == 1 {
            notePosition = "third"
        } else if chord.pitchClasses.firstIndex(of: note.pitchClass) == 2 {
            notePosition = "fifth"
        } else {
            notePosition = "extension"
        }

        return "\(chord.symbol) (\(function.function.rawValue)) - melody is \(notePosition)"
    }

    private func detectCadences(_ chords: [Chord], in key: Scale) -> [Cadence] {
        var cadences: [Cadence] = []

        for i in 0..<(chords.count - 1) {
            let current = chords[i]
            let next = chords[i + 1]

            // Authentic cadence: V(7) → I
            if ((current.root - key.root + 12) % 12 == 7) && ((next.root - key.root + 12) % 12 == 0) {
                cadences.append(Cadence(type: .authentic, position: i, strength: 1.0))
            }

            // Plagal cadence: IV → I
            if ((current.root - key.root + 12) % 12 == 5) && ((next.root - key.root + 12) % 12 == 0) {
                cadences.append(Cadence(type: .plagal, position: i, strength: 0.8))
            }

            // Deceptive cadence: V → vi
            if ((current.root - key.root + 12) % 12 == 7) && ((next.root - key.root + 12) % 12 == 9) {
                cadences.append(Cadence(type: .deceptive, position: i, strength: 0.9))
            }
        }

        return cadences
    }

    private func detectModulations(_ chords: [Chord], originalKey: Scale) -> [Modulation] {
        var modulations: [Modulation] = []
        var windowSize = 4

        for i in 0..<(chords.count - windowSize) {
            let window = Array(chords[i..<(i + windowSize)])
            let pitchClasses = window.flatMap { $0.pitchClasses }

            // Check correlation with all possible keys
            var bestKey = originalKey.root
            var bestCorrelation: Double = 0

            for root in 0..<12 {
                let testKey = Scale(root: root, mode: .ionian)
                let correlation = KrumhanslTonalHierarchy.keyCorrelation(
                    pitchClasses: pitchClasses.map { Double($0) / 11.0 },
                    keyRoot: root,
                    isMinor: false
                )

                if correlation > bestCorrelation {
                    bestCorrelation = correlation
                    bestKey = root
                }
            }

            if bestKey != originalKey.root && bestCorrelation > 0.7 {
                modulations.append(Modulation(
                    toKey: Scale(root: bestKey, mode: .ionian),
                    position: i,
                    confidence: bestCorrelation
                ))
            }
        }

        return modulations
    }

    private func calculateComplexity(_ chords: [Chord], analysis: HarmonicAnalysis) -> Double {
        var complexity: Double = 0

        // Chord quality complexity
        let avgTension = chords.map { $0.quality.tension }.reduce(0, +) / Double(chords.count)
        complexity += avgTension * 0.3

        // Harmonic rhythm (changes)
        var changes = 0
        for i in 1..<chords.count {
            if chords[i].root != chords[i-1].root {
                changes += 1
            }
        }
        complexity += Double(changes) / Double(chords.count) * 0.2

        // Modulations
        complexity += Double(analysis.modulations.count) * 0.1

        // Non-diatonic chords
        let nonDiatonic = analysis.functions.filter { $0.function == .passing || $0.function == .applied }.count
        complexity += Double(nonDiatonic) / Double(chords.count) * 0.2

        return min(1, complexity)
    }
}

// MARK: - Supporting Types

public struct HarmonicAnalysis {
    public var functions: [HarmonicFunction] = []
    public var cadences: [Cadence] = []
    public var tensionCurve: [Double] = []
    public var modulations: [Modulation] = []
    public var complexityScore: Double = 0
}

public struct Cadence {
    public var type: CadenceType
    public var position: Int
    public var strength: Double

    public enum CadenceType: String {
        case authentic = "Authentic (V-I)"
        case plagal = "Plagal (IV-I)"
        case deceptive = "Deceptive (V-vi)"
        case half = "Half (I-V)"
        case phrygian = "Phrygian (iv6-V)"
    }
}

public struct Modulation {
    public var toKey: Scale
    public var position: Int
    public var confidence: Double
}

public struct ProgressionConstraints {
    public var startChord: String?
    public var endOnTonic: Bool = true
    public var avoidChords: [String] = []
    public var requireChords: [String] = []
    public var maxTension: Double = 1.0
}

// MARK: - Voice Leading Optimizer

public final class VoiceLeadingOptimizer {
    public func optimizeVoicing(
        for chord: Chord,
        melodyNote: Pitch,
        previousVoicing: Voicing?,
        rules: VoiceLeadingRules
    ) -> Voicing {
        // Generate all possible voicings
        let candidates = generateVoicingCandidates(chord: chord, melodyNote: melodyNote, rules: rules)

        guard let previous = previousVoicing else {
            return candidates.first ?? Voicing(pitches: [], chord: chord)
        }

        // Find voicing with minimum voice leading cost
        var bestVoicing = candidates.first!
        var bestCost = Double.infinity

        for candidate in candidates {
            let cost = candidate.voiceLeadingCost(to: previous, rules: rules)
            if cost < bestCost {
                bestCost = cost
                bestVoicing = candidate
            }
        }

        return bestVoicing
    }

    public func quickVoicing(for chord: Chord, melodyNote: Pitch, style: HarmonicContext.HarmonicStyle) -> Voicing {
        // Fast voicing for real-time use
        var pitches: [Pitch] = []

        // Bass note
        pitches.append(Pitch(pitchClass: chord.root, octave: 2))

        // Inner voices
        for (index, interval) in chord.quality.intervals.enumerated() where index > 0 && index < 3 {
            let pc = (chord.root + interval) % 12
            pitches.append(Pitch(pitchClass: pc, octave: 3))
        }

        // Melody on top
        pitches.append(melodyNote)

        return Voicing(pitches: pitches.sorted { $0.midiNote < $1.midiNote }, chord: chord)
    }

    private func generateVoicingCandidates(chord: Chord, melodyNote: Pitch, rules: VoiceLeadingRules) -> [Voicing] {
        var candidates: [Voicing] = []

        // Generate voicings with melody note on top
        for bassOctave in 2...3 {
            for innerOctave in 3...4 {
                var pitches: [Pitch] = []

                // Bass
                let bassPC = chord.bass ?? chord.root
                let bassPitch = Pitch(pitchClass: bassPC, octave: bassOctave)
                if rules.bassRange.contains(bassPitch.midiNote) {
                    pitches.append(bassPitch)
                }

                // Inner voices
                for interval in chord.quality.intervals.dropFirst() {
                    let pc = (chord.root + interval) % 12
                    let innerPitch = Pitch(pitchClass: pc, octave: innerOctave)
                    if innerPitch.midiNote < melodyNote.midiNote {
                        pitches.append(innerPitch)
                    }
                }

                // Melody
                pitches.append(melodyNote)

                if pitches.count >= 3 {
                    candidates.append(Voicing(
                        pitches: pitches.sorted { $0.midiNote < $1.midiNote },
                        chord: chord
                    ))
                }
            }
        }

        return candidates.isEmpty ? [quickVoicing(for: chord, melodyNote: melodyNote, style: .jazz)] : candidates
    }
}

// MARK: - Harmonic Neural Network

public final class HarmonicNeuralNetwork {
    private var weights: [[Float]] = []

    public init() {
        initializeWeights()
    }

    private func initializeWeights() {
        // Initialize with music theory-informed weights
        let inputSize = 24  // Melody pitch class + context
        let hiddenSize = 64
        let outputSize = 48 // Chord root (12) * quality (4)

        weights.append([Float](repeating: 0, count: inputSize * hiddenSize))
        weights.append([Float](repeating: 0, count: hiddenSize * outputSize))

        // Xavier initialization
        for i in 0..<weights[0].count {
            weights[0][i] = Float.random(in: -0.5...0.5)
        }
        for i in 0..<weights[1].count {
            weights[1][i] = Float.random(in: -0.5...0.5)
        }
    }

    public func predict(melodyNote: Pitch, context: HarmonicContext) -> Chord {
        // Create input features
        var input = [Float](repeating: 0, count: 24)
        input[melodyNote.pitchClass] = 1.0

        // Add context features
        input[12 + context.key.root] = 1.0

        // Simple forward pass (in production: use CoreML)
        // For now, use rule-based fallback
        let suggestions = [
            Chord(root: context.key.root, quality: .major7),
            Chord(root: (context.key.root + 5) % 12, quality: .major7),
            Chord(root: (context.key.root + 7) % 12, quality: .dominant7)
        ]

        // Pick chord that contains melody note
        for chord in suggestions {
            if chord.pitchClasses.contains(melodyNote.pitchClass) {
                return chord
            }
        }

        return suggestions.first!
    }
}

// Reference Krumhansl from the RL module
extension KrumhanslTonalHierarchy {
    // Already defined in PsychoacousticRewards.swift
}
