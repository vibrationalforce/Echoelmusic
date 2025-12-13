import Foundation
import CoreML

/// AI Composer - CoreML-powered Music Generation
/// Melody generation, chord progression suggestions, drum patterns
/// Bio-Data → Music Style mapping
@MainActor
class AIComposer: ObservableObject {

    @Published var isGenerating: Bool = false
    @Published var generatedMelody: [Note] = []
    @Published var suggestedChords: [Chord] = []

    // MARK: - CoreML Models (placeholders)

    private var melodyModel: MLModel?
    private var chordModel: MLModel?
    private var drumModel: MLModel?

    // Scale patterns (semitones from root)
    private let scalePatterns: [String: [Int]] = [
        "major": [0, 2, 4, 5, 7, 9, 11],
        "minor": [0, 2, 3, 5, 7, 8, 10],
        "dorian": [0, 2, 3, 5, 7, 9, 10],
        "mixolydian": [0, 2, 4, 5, 7, 9, 10],
        "pentatonic": [0, 2, 4, 7, 9],
        "blues": [0, 3, 5, 6, 7, 10]
    ]

    // Root note MIDI values
    private let rootNotes: [String: Int] = [
        "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63,
        "E": 64, "F": 65, "F#": 66, "Gb": 66, "G": 67, "G#": 68,
        "Ab": 68, "A": 69, "A#": 70, "Bb": 70, "B": 71
    ]

    init() {
        // Rule-based generation (CoreML can be added later for enhanced quality)
        // Current implementation uses Markov-chain-style transitions
        print("✅ AIComposer: Initialized with rule-based generation")
    }

    // MARK: - Melody Generation

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎼 AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")

        let rootNote = rootNotes[key] ?? 60
        let scaleIntervals = scalePatterns[scale.lowercased()] ?? scalePatterns["major"]!

        // Build scale notes across 2 octaves
        var scaleNotes: [Int] = []
        for octave in 0..<2 {
            for interval in scaleIntervals {
                scaleNotes.append(rootNote + interval + (octave * 12))
            }
        }

        // Generate melodic contour using Markov-style transitions
        var notes: [Note] = []
        var currentIndex = scaleNotes.count / 2  // Start in middle
        let notesPerBar = 4
        let totalNotes = bars * notesPerBar

        for i in 0..<totalNotes {
            // Melodic motion preferences (step-wise more likely than leaps)
            let motionProbabilities: [(Int, Double)] = [
                (-2, 0.1),   // Down 2 scale steps
                (-1, 0.25),  // Down 1 step
                (0, 0.3),    // Same note
                (1, 0.25),   // Up 1 step
                (2, 0.1)     // Up 2 steps
            ]

            // Choose motion based on weighted random
            let motion = weightedRandomChoice(motionProbabilities)
            currentIndex = max(0, min(scaleNotes.count - 1, currentIndex + motion))

            // Rhythmic variety
            let duration: Double
            if i % notesPerBar == 0 {
                duration = 0.5  // Longer on beat 1
            } else if i % 2 == 0 {
                duration = 0.25  // Quarter notes on beats
            } else {
                duration = Double.random(in: 0.125...0.25)  // Eighth or sixteenth
            }

            // Velocity variation (accents on beats)
            let velocity = (i % notesPerBar == 0) ? Int.random(in: 90...110) : Int.random(in: 70...90)

            notes.append(Note(pitch: scaleNotes[currentIndex], duration: duration, velocity: velocity))
        }

        generatedMelody = notes
        return notes
    }

    private func weightedRandomChoice(_ choices: [(Int, Double)]) -> Int {
        let total = choices.reduce(0.0) { $0 + $1.1 }
        var random = Double.random(in: 0..<total)

        for (value, weight) in choices {
            random -= weight
            if random <= 0 {
                return value
            }
        }
        return choices.first?.0 ?? 0
    }

    // MARK: - Chord Suggestions

    func suggestChordProgression(key: String, mood: String) async -> [Chord] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎹 AIComposer: Suggesting chords for \(key) \(mood)")

        let chords = [
            Chord(root: "C", type: .major),
            Chord(root: "Am", type: .minor),
            Chord(root: "F", type: .major),
            Chord(root: "G", type: .major)
        ]

        suggestedChords = chords
        return chords
    }

    // MARK: - Bio-Data → Music Style

    func mapBioToMusicStyle(hrv: Float, coherence: Float, heartRate: Float) -> MusicStyle {
        if coherence > 0.7 {
            return .calm
        } else if heartRate > 100 {
            return .energetic
        } else if hrv < 30 {
            return .tense
        } else {
            return .balanced
        }
    }
}

struct Note {
    let pitch: Int  // MIDI note number
    let duration: Double  // Quarter notes
    let velocity: Int  // 0-127
}

struct Chord {
    let root: String
    let type: ChordType

    enum ChordType {
        case major
        case minor
        case dominant7
        case major7
    }
}

enum MusicStyle {
    case calm
    case energetic
    case tense
    case balanced
}
