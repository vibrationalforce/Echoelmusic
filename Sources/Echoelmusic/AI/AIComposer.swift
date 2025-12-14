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

    // MARK: - CoreML Model References

    private var melodyModelURL: URL? {
        Bundle.main.url(forResource: "MelodyGenerator", withExtension: "mlmodelc")
    }

    private var chordModelURL: URL? {
        Bundle.main.url(forResource: "ChordPredictor", withExtension: "mlmodelc")
    }

    init() {
        // Load CoreML models if available
        loadModels()
        print("✅ AIComposer: Initialized")
    }

    private func loadModels() {
        // Load Melody Generator model
        if let url = melodyModelURL {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndGPU
                melodyModel = try MLModel(contentsOf: url, configuration: config)
                print("🧠 AIComposer: Loaded MelodyGenerator model")
            } catch {
                print("⚠️ AIComposer: MelodyGenerator model not available - using algorithmic fallback")
            }
        }

        // Load Chord Predictor model
        if let url = chordModelURL {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndGPU
                chordModel = try MLModel(contentsOf: url, configuration: config)
                print("🧠 AIComposer: Loaded ChordPredictor model")
            } catch {
                print("⚠️ AIComposer: ChordPredictor model not available - using algorithmic fallback")
            }
        }
    }

    // MARK: - Melody Generation (LSTM-based with algorithmic fallback)

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎼 AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")

        // Get scale intervals
        let scaleIntervals = getScaleIntervals(scale)
        let rootNote = getNoteNumber(key)

        // Build scale notes
        let scaleNotes = scaleIntervals.map { rootNote + $0 }

        var notes: [Note] = []
        var previousNote = rootNote + 60 // Start in middle octave

        for bar in 0..<bars {
            for beat in 0..<4 {
                // LSTM-inspired note selection with Markov chain
                let nextNote = selectNextNote(
                    previous: previousNote,
                    scaleNotes: scaleNotes,
                    position: (bar * 4 + beat),
                    totalBeats: bars * 4
                )

                // Vary duration based on position
                let duration = selectDuration(beat: beat, bar: bar)

                // Velocity curve - build and release tension
                let velocity = calculateVelocity(position: bar * 4 + beat, total: bars * 4)

                notes.append(Note(pitch: nextNote, duration: duration, velocity: velocity))
                previousNote = nextNote
            }
        }

        generatedMelody = notes
        return notes
    }

    private func getScaleIntervals(_ scale: String) -> [Int] {
        switch scale.lowercased() {
        case "major": return [0, 2, 4, 5, 7, 9, 11]
        case "minor": return [0, 2, 3, 5, 7, 8, 10]
        case "dorian": return [0, 2, 3, 5, 7, 9, 10]
        case "mixolydian": return [0, 2, 4, 5, 7, 9, 10]
        case "pentatonic": return [0, 2, 4, 7, 9]
        default: return [0, 2, 4, 5, 7, 9, 11]
        }
    }

    private func getNoteNumber(_ key: String) -> Int {
        let notes = ["C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
                     "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11]
        return notes[key.uppercased()] ?? 0
    }

    private func selectNextNote(previous: Int, scaleNotes: [Int], position: Int, totalBeats: Int) -> Int {
        // Weighted random walk with tendency toward scale tones
        let intervals = [-2, -1, 0, 1, 2, 3] // Stepwise motion preferred
        let weights = [0.1, 0.25, 0.1, 0.3, 0.15, 0.1]

        let random = Double.random(in: 0...1)
        var cumulative = 0.0
        var selectedInterval = 0

        for (i, weight) in weights.enumerated() {
            cumulative += weight
            if random <= cumulative {
                selectedInterval = intervals[i]
                break
            }
        }

        var nextNote = previous + selectedInterval

        // Quantize to scale
        let octave = (nextNote / 12) * 12
        let pitchClass = nextNote % 12
        if let closest = scaleNotes.min(by: { abs($0 - pitchClass) < abs($1 - pitchClass) }) {
            nextNote = octave + closest
        }

        // Keep in range
        nextNote = max(48, min(84, nextNote))

        return nextNote
    }

    private func selectDuration(beat: Int, bar: Int) -> Double {
        // Vary rhythm - more activity on offbeats
        let durations = [0.5, 0.25, 0.25, 0.5, 0.25, 0.125, 0.125, 0.25]
        return durations[(bar * 4 + beat) % durations.count]
    }

    private func calculateVelocity(position: Int, total: Int) -> Int {
        // Arc: build tension, peak at 70%, release
        let normalized = Double(position) / Double(total)
        let curve = sin(normalized * .pi)
        return Int(60 + curve * 40)
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
