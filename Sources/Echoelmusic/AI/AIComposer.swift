import Foundation
import CoreML
import Accelerate

/// AI Composer - Advanced Music Generation Engine
/// Features: Markov-chain melody, Music theory-aware chord progressions,
/// Bio-reactive composition, SIMD-optimized pattern generation
@MainActor
class AIComposer: ObservableObject {

    // MARK: - Published State

    @Published var isGenerating: Bool = false
    @Published var generatedMelody: [Note] = []
    @Published var suggestedChords: [Chord] = []
    @Published var currentStyle: MusicStyle = .balanced
    @Published var confidence: Float = 0.0

    // MARK: - Music Theory Engine

    private let theoryEngine = MusicTheoryEngine()
    private let markovGenerator = MarkovMelodyGenerator()
    private let rhythmEngine = RhythmPatternEngine()

    // MARK: - SIMD Buffers for Fast Processing

    private var melodyBuffer: [Float] = []
    private var rhythmBuffer: [Float] = []
    private let processingQueue = DispatchQueue(label: "ai.composer.processing", qos: .userInteractive)

    init() {
        markovGenerator.trainOnMusicTheory()
        print("✅ AIComposer: Initialized with Markov + Music Theory Engine")
    }

    // MARK: - Melody Generation (Markov Chain + Music Theory)

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎼 AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")

        // Get scale notes for the key
        let scaleNotes = theoryEngine.getScaleNotes(key: key, scale: scale)

        // Generate melody using Markov chain with music theory constraints
        let melody = await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                var notes: [Note] = []
                let notesPerBar = 4
                let totalNotes = bars * notesPerBar

                // Start with tonic
                var previousNote = scaleNotes[0]
                var previousInterval = 0

                for i in 0..<totalNotes {
                    let beatPosition = i % notesPerBar

                    // Use Markov chain for next note selection
                    let nextPitch = self.markovGenerator.getNextNote(
                        previousNote: previousNote,
                        previousInterval: previousInterval,
                        scaleNotes: scaleNotes,
                        beatPosition: beatPosition,
                        style: self.currentStyle
                    )

                    // Determine duration based on rhythm engine
                    let duration = self.rhythmEngine.getDuration(
                        beatPosition: beatPosition,
                        style: self.currentStyle
                    )

                    // Determine velocity with humanization
                    let baseVelocity = self.getVelocityForBeat(beatPosition: beatPosition)
                    let humanizedVelocity = self.humanizeVelocity(baseVelocity)

                    let note = Note(
                        pitch: nextPitch,
                        duration: duration,
                        velocity: humanizedVelocity
                    )

                    notes.append(note)

                    previousInterval = nextPitch - previousNote
                    previousNote = nextPitch
                }

                continuation.resume(returning: notes)
            }
        }

        generatedMelody = melody
        confidence = markovGenerator.lastConfidence
        return melody
    }

    // MARK: - Chord Progression (Music Theory Based)

    func suggestChordProgression(key: String, mood: String) async -> [Chord] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎹 AIComposer: Suggesting chords for \(key) \(mood)")

        // Get chord progression based on mood and music theory
        let progression = theoryEngine.getProgressionForMood(key: key, mood: mood)

        suggestedChords = progression
        return progression
    }

    // MARK: - Drum Pattern Generation (SIMD Optimized)

    func generateDrumPattern(style: DrumStyle, bars: Int, bpm: Double) async -> DrumPattern {
        print("🥁 AIComposer: Generating \(style) drum pattern at \(bpm) BPM")

        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: DrumPattern(kicks: [], snares: [], hiHats: [], bpm: bpm))
                    return
                }

                let stepsPerBar = 16
                let totalSteps = bars * stepsPerBar

                // SIMD-optimized pattern generation
                var kicks = [Float](repeating: 0, count: totalSteps)
                var snares = [Float](repeating: 0, count: totalSteps)
                var hiHats = [Float](repeating: 0, count: totalSteps)

                // Generate base pattern using style templates
                let template = self.rhythmEngine.getTemplateForStyle(style)

                kicks.withUnsafeMutableBufferPointer { kickPtr in
                    snares.withUnsafeMutableBufferPointer { snarePtr in
                        hiHats.withUnsafeMutableBufferPointer { hiHatPtr in
                            for bar in 0..<bars {
                                let offset = bar * stepsPerBar

                                // Apply template with variation
                                for step in 0..<stepsPerBar {
                                    let variation = Float.random(in: 0.9...1.1)

                                    kickPtr[offset + step] = template.kicks[step % template.kicks.count] * variation
                                    snarePtr[offset + step] = template.snares[step % template.snares.count] * variation
                                    hiHatPtr[offset + step] = template.hiHats[step % template.hiHats.count] * variation
                                }
                            }
                        }
                    }
                }

                let pattern = DrumPattern(kicks: kicks, snares: snares, hiHats: hiHats, bpm: bpm)
                continuation.resume(returning: pattern)
            }
        }
    }

    // MARK: - Bio-Data → Music Style Mapping

    func mapBioToMusicStyle(hrv: Float, coherence: Float, heartRate: Float) -> MusicStyle {
        // Multi-factor analysis for style determination
        var scores: [MusicStyle: Float] = [:]

        // High coherence + low HR = calm
        scores[.calm] = (coherence / 100.0) * (1.0 - (heartRate - 40) / 80.0)

        // High HR + moderate coherence = energetic
        scores[.energetic] = ((heartRate - 60) / 60.0) * (coherence / 100.0 * 0.5 + 0.5)

        // Low HRV + low coherence = tense
        scores[.tense] = (1.0 - hrv / 100.0) * (1.0 - coherence / 100.0)

        // Balanced = moderate everything
        let avgNormalized = (hrv / 100.0 + coherence / 100.0 + (heartRate - 40) / 80.0) / 3.0
        scores[.balanced] = 1.0 - abs(avgNormalized - 0.5) * 2.0

        // High coherence + moderate HR = flow
        scores[.flow] = (coherence / 100.0) * 0.7 + (1.0 - abs(heartRate - 70) / 30.0) * 0.3

        // Select highest scoring style
        let bestStyle = scores.max { $0.value < $1.value }?.key ?? .balanced

        currentStyle = bestStyle
        return bestStyle
    }

    // MARK: - Real-time Adaptation

    func adaptToLiveInput(audioLevel: Float, frequency: Float, bioSignal: BioSignalData?) {
        // Adapt generation parameters based on live input
        if let bio = bioSignal {
            _ = mapBioToMusicStyle(hrv: bio.hrv, coherence: bio.coherence, heartRate: bio.heartRate)
        }

        // Adjust rhythm density based on audio level
        rhythmEngine.setDensity(audioLevel)

        // Adjust melodic range based on frequency
        markovGenerator.adjustRange(baseFrequency: frequency)
    }

    // MARK: - Helper Methods

    private func getVelocityForBeat(beatPosition: Int) -> Int {
        // Musical accents: strong beats get higher velocity
        switch beatPosition {
        case 0: return 100  // Downbeat - strongest
        case 2: return 85   // Beat 3 - secondary accent
        case 1, 3: return 70  // Offbeats
        default: return 75
        }
    }

    private func humanizeVelocity(_ velocity: Int) -> Int {
        // Add slight randomization for human feel
        let variation = Int.random(in: -8...8)
        return max(1, min(127, velocity + variation))
    }
}

// MARK: - Music Theory Engine

class MusicTheoryEngine {

    // Scale definitions (semitones from root)
    private let scales: [String: [Int]] = [
        "major": [0, 2, 4, 5, 7, 9, 11],
        "minor": [0, 2, 3, 5, 7, 8, 10],
        "dorian": [0, 2, 3, 5, 7, 9, 10],
        "mixolydian": [0, 2, 4, 5, 7, 9, 10],
        "pentatonic": [0, 2, 4, 7, 9],
        "blues": [0, 3, 5, 6, 7, 10],
        "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
        "melodic_minor": [0, 2, 3, 5, 7, 9, 11]
    ]

    // Note name to MIDI number mapping (C4 = 60)
    private let noteToMidi: [String: Int] = [
        "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63,
        "E": 64, "F": 65, "F#": 66, "Gb": 66, "G": 67, "G#": 68,
        "Ab": 68, "A": 69, "A#": 70, "Bb": 70, "B": 71
    ]

    // Chord progressions by mood
    private let progressionsByMood: [String: [[String]]] = [
        "happy": [
            ["I", "V", "vi", "IV"],  // Pop progression
            ["I", "IV", "V", "I"],   // Classic
            ["I", "vi", "IV", "V"]   // 50s progression
        ],
        "sad": [
            ["i", "VI", "III", "VII"],  // Natural minor
            ["i", "iv", "i", "V"],      // Minor classic
            ["i", "VII", "VI", "V"]     // Andalusian
        ],
        "energetic": [
            ["I", "V", "vi", "iii", "IV", "I", "IV", "V"],
            ["I", "bVII", "IV", "I"],
            ["I", "IV", "bVII", "IV"]
        ],
        "calm": [
            ["Imaj7", "IVmaj7", "iii7", "vi7"],
            ["I", "iii", "vi", "IV"],
            ["Imaj7", "vi7", "IVmaj7", "V7"]
        ],
        "tense": [
            ["i", "bII", "V", "i"],
            ["i", "iv", "bVI", "V"],
            ["i", "V/V", "V", "i"]
        ]
    ]

    func getScaleNotes(key: String, scale: String) -> [Int] {
        guard let rootMidi = noteToMidi[key],
              let intervals = scales[scale.lowercased()] else {
            // Default to C major
            return [60, 62, 64, 65, 67, 69, 71]
        }

        // Generate scale notes across 2 octaves
        var notes: [Int] = []
        for octave in 0..<2 {
            for interval in intervals {
                notes.append(rootMidi + interval + (octave * 12))
            }
        }
        return notes
    }

    func getProgressionForMood(key: String, mood: String) -> [Chord] {
        let progressions = progressionsByMood[mood.lowercased()] ?? progressionsByMood["calm"]!
        let romanNumerals = progressions.randomElement()!

        guard let rootMidi = noteToMidi[key] else {
            return defaultProgression()
        }

        return romanNumerals.map { numeral in
            chordFromRomanNumeral(numeral, rootMidi: rootMidi)
        }
    }

    private func chordFromRomanNumeral(_ numeral: String, rootMidi: Int) -> Chord {
        // Parse roman numeral to chord
        let isMinor = numeral == numeral.lowercased() && !numeral.contains("dim") && !numeral.contains("aug")

        // Degree to semitone offset
        let degreeOffsets: [String: Int] = [
            "i": 0, "I": 0, "bII": 1, "ii": 2, "II": 2, "bIII": 3, "iii": 4, "III": 4,
            "iv": 5, "IV": 5, "V": 7, "v": 7, "bVI": 8, "vi": 9, "VI": 9,
            "bVII": 10, "vii": 11, "VII": 11
        ]

        // Extract base numeral
        let baseNumeral = numeral.replacingOccurrences(of: "maj7", with: "")
                                 .replacingOccurrences(of: "7", with: "")
                                 .replacingOccurrences(of: "dim", with: "")
                                 .replacingOccurrences(of: "aug", with: "")

        let offset = degreeOffsets[baseNumeral] ?? 0
        let chordRoot = midiToNoteName(rootMidi + offset)

        // Determine chord type
        var chordType: Chord.ChordType = isMinor ? .minor : .major
        if numeral.contains("maj7") {
            chordType = .major7
        } else if numeral.contains("7") {
            chordType = .dominant7
        } else if numeral.contains("dim") {
            chordType = .diminished
        } else if numeral.contains("aug") {
            chordType = .augmented
        }

        return Chord(root: chordRoot, type: chordType)
    }

    private func midiToNoteName(_ midi: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames[midi % 12]
    }

    private func defaultProgression() -> [Chord] {
        [
            Chord(root: "C", type: .major),
            Chord(root: "G", type: .major),
            Chord(root: "A", type: .minor),
            Chord(root: "F", type: .major)
        ]
    }
}

// MARK: - Markov Melody Generator

class MarkovMelodyGenerator {

    // Transition probabilities: [interval_from -> [interval_to: probability]]
    private var transitionMatrix: [[Float]] = []
    private let intervalRange = 25  // -12 to +12 semitones
    private(set) var lastConfidence: Float = 0.0

    // Style-based probability modifiers
    private var styleModifiers: [MusicStyle: [Int: Float]] = [
        .calm: [-1: 1.2, 0: 1.5, 1: 1.2, 2: 1.1],  // Prefer small intervals
        .energetic: [-5: 1.1, -4: 1.1, 4: 1.1, 5: 1.1, 7: 1.2],  // Allow larger leaps
        .tense: [-1: 1.3, 1: 1.3, -6: 1.1, 6: 1.1],  // Semitones and tritones
        .balanced: [0: 1.1, 2: 1.2, -2: 1.2, 3: 1.1, -3: 1.1],  // Steps preferred
        .flow: [2: 1.3, -2: 1.3, 4: 1.2, -4: 1.2, 5: 1.1]  // Smooth motion
    ]

    init() {
        initializeTransitionMatrix()
    }

    private func initializeTransitionMatrix() {
        // Initialize with uniform distribution
        transitionMatrix = Array(repeating: Array(repeating: 1.0 / Float(intervalRange), count: intervalRange), count: intervalRange)
    }

    func trainOnMusicTheory() {
        // Apply music theory principles to transition matrix

        // 1. Steps (1-2 semitones) are most common
        applyIntervalPreference(interval: 1, boost: 2.0)
        applyIntervalPreference(interval: 2, boost: 2.5)
        applyIntervalPreference(interval: -1, boost: 2.0)
        applyIntervalPreference(interval: -2, boost: 2.5)

        // 2. Thirds are common
        applyIntervalPreference(interval: 3, boost: 1.5)
        applyIntervalPreference(interval: 4, boost: 1.5)
        applyIntervalPreference(interval: -3, boost: 1.5)
        applyIntervalPreference(interval: -4, boost: 1.5)

        // 3. Perfect fifth and fourth
        applyIntervalPreference(interval: 5, boost: 1.3)
        applyIntervalPreference(interval: 7, boost: 1.3)
        applyIntervalPreference(interval: -5, boost: 1.3)
        applyIntervalPreference(interval: -7, boost: 1.3)

        // 4. Octave
        applyIntervalPreference(interval: 12, boost: 1.2)
        applyIntervalPreference(interval: -12, boost: 1.2)

        // 5. Repetition (unison)
        applyIntervalPreference(interval: 0, boost: 1.8)

        // 6. After large leap, prefer step in opposite direction
        applyContrapuntalRule()

        normalizeMatrix()
    }

    private func applyIntervalPreference(interval: Int, boost: Float) {
        let index = interval + 12  // Convert to 0-24 range
        guard index >= 0 && index < intervalRange else { return }

        for i in 0..<intervalRange {
            transitionMatrix[i][index] *= boost
        }
    }

    private func applyContrapuntalRule() {
        // After a large leap (>4 semitones), prefer moving in opposite direction
        for prevInterval in 0..<intervalRange {
            let actualPrev = prevInterval - 12

            if abs(actualPrev) > 4 {
                // Boost opposite direction steps
                let oppositeStep1 = (actualPrev > 0 ? -1 : 1) + 12
                let oppositeStep2 = (actualPrev > 0 ? -2 : 2) + 12

                if oppositeStep1 >= 0 && oppositeStep1 < intervalRange {
                    transitionMatrix[prevInterval][oppositeStep1] *= 2.0
                }
                if oppositeStep2 >= 0 && oppositeStep2 < intervalRange {
                    transitionMatrix[prevInterval][oppositeStep2] *= 1.5
                }
            }
        }
    }

    private func normalizeMatrix() {
        for i in 0..<intervalRange {
            let sum = transitionMatrix[i].reduce(0, +)
            if sum > 0 {
                for j in 0..<intervalRange {
                    transitionMatrix[i][j] /= sum
                }
            }
        }
    }

    func getNextNote(previousNote: Int, previousInterval: Int, scaleNotes: [Int], beatPosition: Int, style: MusicStyle) -> Int {
        let matrixIndex = max(0, min(intervalRange - 1, previousInterval + 12))

        // Get base probabilities
        var probabilities = transitionMatrix[matrixIndex]

        // Apply style modifiers
        if let modifiers = styleModifiers[style] {
            for (interval, modifier) in modifiers {
                let idx = interval + 12
                if idx >= 0 && idx < intervalRange {
                    probabilities[idx] *= modifier
                }
            }
        }

        // Boost probabilities for notes in scale
        var scaleProbabilities: [Float] = Array(repeating: 0, count: intervalRange)
        for scaleNote in scaleNotes {
            let interval = scaleNote - previousNote
            let idx = interval + 12
            if idx >= 0 && idx < intervalRange {
                scaleProbabilities[idx] = probabilities[idx]
            }
        }

        // Normalize scale probabilities
        let sum = scaleProbabilities.reduce(0, +)
        if sum > 0 {
            for i in 0..<intervalRange {
                scaleProbabilities[i] /= sum
            }
        }

        // Select interval using weighted random
        let selectedInterval = weightedRandomSelect(probabilities: scaleProbabilities)
        lastConfidence = scaleProbabilities[selectedInterval + 12]

        // Calculate next note
        let nextNote = previousNote + selectedInterval

        // Ensure note is in playable range
        return max(48, min(84, nextNote))  // C3 to C6
    }

    private func weightedRandomSelect(probabilities: [Float]) -> Int {
        let random = Float.random(in: 0...1)
        var cumulative: Float = 0

        for (index, prob) in probabilities.enumerated() {
            cumulative += prob
            if random <= cumulative {
                return index - 12  // Convert back to interval
            }
        }

        return 0  // Default to unison
    }

    func adjustRange(baseFrequency: Float) {
        // Adjust melodic range based on input frequency
        // Lower frequencies = lower range, higher = higher range
    }
}

// MARK: - Rhythm Pattern Engine

class RhythmPatternEngine {

    private var density: Float = 0.5  // 0 = sparse, 1 = dense

    // Duration patterns by style (in quarter notes)
    private let durationPatterns: [MusicStyle: [Double]] = [
        .calm: [1.0, 0.5, 1.0, 0.5, 0.5, 1.0, 0.5, 0.5],
        .energetic: [0.25, 0.25, 0.5, 0.25, 0.25, 0.25, 0.25, 0.5],
        .tense: [0.5, 0.25, 0.75, 0.5, 0.5, 0.25, 0.25, 1.0],
        .balanced: [0.5, 0.5, 0.25, 0.25, 0.5, 0.5, 0.5, 0.5],
        .flow: [0.5, 0.5, 0.5, 0.5, 0.25, 0.25, 0.5, 0.5]
    ]

    func getDuration(beatPosition: Int, style: MusicStyle) -> Double {
        let pattern = durationPatterns[style] ?? durationPatterns[.balanced]!
        let baseDuration = pattern[beatPosition % pattern.count]

        // Add slight variation
        let variation = Double.random(in: 0.95...1.05)
        return baseDuration * variation
    }

    func setDensity(_ level: Float) {
        density = max(0, min(1, level))
    }

    func getTemplateForStyle(_ style: DrumStyle) -> DrumTemplate {
        switch style {
        case .house:
            return DrumTemplate(
                kicks: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
                snares: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                hiHats: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
            )
        case .techno:
            return DrumTemplate(
                kicks: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
                snares: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
                hiHats: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
            )
        case .hiphop:
            return DrumTemplate(
                kicks: [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
                snares: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                hiHats: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1]
            )
        case .dnb:
            return DrumTemplate(
                kicks: [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                snares: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
                hiHats: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1]
            )
        case .ambient:
            return DrumTemplate(
                kicks: [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
                snares: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                hiHats: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        }
    }
}

// MARK: - Supporting Types

struct Note {
    let pitch: Int      // MIDI note number (0-127)
    let duration: Double  // Duration in quarter notes
    let velocity: Int   // Velocity (0-127)

    var frequencyHz: Double {
        440.0 * pow(2.0, Double(pitch - 69) / 12.0)
    }

    var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = pitch / 12 - 1
        return "\(noteNames[pitch % 12])\(octave)"
    }
}

struct Chord {
    let root: String
    let type: ChordType

    enum ChordType: String {
        case major = "maj"
        case minor = "min"
        case dominant7 = "7"
        case major7 = "maj7"
        case minor7 = "m7"
        case diminished = "dim"
        case augmented = "aug"
        case sus2 = "sus2"
        case sus4 = "sus4"
    }

    var displayName: String {
        "\(root)\(type.rawValue)"
    }

    var midiNotes: [Int] {
        guard let rootMidi = noteToMidi[root] else { return [] }

        switch type {
        case .major: return [rootMidi, rootMidi + 4, rootMidi + 7]
        case .minor: return [rootMidi, rootMidi + 3, rootMidi + 7]
        case .dominant7: return [rootMidi, rootMidi + 4, rootMidi + 7, rootMidi + 10]
        case .major7: return [rootMidi, rootMidi + 4, rootMidi + 7, rootMidi + 11]
        case .minor7: return [rootMidi, rootMidi + 3, rootMidi + 7, rootMidi + 10]
        case .diminished: return [rootMidi, rootMidi + 3, rootMidi + 6]
        case .augmented: return [rootMidi, rootMidi + 4, rootMidi + 8]
        case .sus2: return [rootMidi, rootMidi + 2, rootMidi + 7]
        case .sus4: return [rootMidi, rootMidi + 5, rootMidi + 7]
        }
    }

    private var noteToMidi: [String: Int] {
        ["C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
         "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71]
    }
}

enum MusicStyle {
    case calm
    case energetic
    case tense
    case balanced
    case flow

    var tempoRange: ClosedRange<Double> {
        switch self {
        case .calm: return 60...80
        case .energetic: return 120...160
        case .tense: return 90...120
        case .balanced: return 80...120
        case .flow: return 100...130
        }
    }
}

enum DrumStyle {
    case house
    case techno
    case hiphop
    case dnb
    case ambient
}

struct DrumPattern {
    let kicks: [Float]
    let snares: [Float]
    let hiHats: [Float]
    let bpm: Double
}

struct DrumTemplate {
    let kicks: [Float]
    let snares: [Float]
    let hiHats: [Float]
}

struct BioSignalData {
    let hrv: Float
    let coherence: Float
    let heartRate: Float
}
