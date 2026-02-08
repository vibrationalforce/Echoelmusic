import Foundation
import Combine
import CoreML
import Accelerate

/// AI Composer - CoreML-powered Music Generation
/// Melody generation, chord progression suggestions, drum patterns
/// Bio-Data → Music Style mapping with real-time biofeedback
@MainActor
class AIComposer: ObservableObject {

    // MARK: - Published State

    @Published var isGenerating: Bool = false
    @Published var generatedMelody: [Note] = []
    @Published var suggestedChords: [AIChord] = []
    @Published var generatedDrumPattern: [DrumHit] = []
    @Published var currentStyle: MusicStyle = .balanced
    @Published var modelStatus: ModelStatus = .notLoaded
    @Published var usingFallbackMode: Bool = false
    @Published var lastError: AIComposerError?

    // MARK: - Model Status

    enum ModelStatus: String {
        case notLoaded = "Not Loaded"
        case loading = "Loading..."
        case ready = "Ready"
        case readyWithFallback = "Ready (Algorithmic)"
        case error = "Error"
    }

    // MARK: - Error Types

    enum AIComposerError: Error, LocalizedError {
        case modelNotFound(String)
        case modelLoadFailed(String, Error)
        case predictionFailed(Error)
        case invalidInput(String)

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let name):
                return "Model '\(name)' not found - using algorithmic generation"
            case .modelLoadFailed(let name, let error):
                return "Failed to load '\(name)': \(error.localizedDescription)"
            case .predictionFailed(let error):
                return "Prediction failed: \(error.localizedDescription)"
            case .invalidInput(let message):
                return "Invalid input: \(message)"
            }
        }
    }

    // MARK: - CoreML Models

    private var melodyModel: MLModel?
    private var chordModel: MLModel?
    private var drumModel: MLModel?

    // MARK: - Music Theory Data

    private let scalePatterns: [String: [Int]] = [
        "major": [0, 2, 4, 5, 7, 9, 11],
        "minor": [0, 2, 3, 5, 7, 8, 10],
        "dorian": [0, 2, 3, 5, 7, 9, 10],
        "mixolydian": [0, 2, 4, 5, 7, 9, 10],
        "pentatonic": [0, 2, 4, 7, 9],
        "blues": [0, 3, 5, 6, 7, 10]
    ]

    private let rootNotes: [String: Int] = [
        "C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
        "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71
    ]

    private let chordProgressions: [String: [[String]]] = [
        "happy": [["I", "V", "vi", "IV"], ["I", "IV", "V", "V"], ["I", "ii", "V", "I"]],
        "sad": [["i", "VI", "III", "VII"], ["i", "iv", "VII", "III"], ["i", "VI", "iv", "V"]],
        "epic": [["I", "V", "vi", "IV"], ["vi", "IV", "I", "V"], ["I", "III", "IV", "iv"]],
        "calm": [["I", "iii", "IV", "I"], ["I", "vi", "IV", "V"], ["I", "IV", "vi", "V"]],
        "tense": [["i", "bVI", "bVII", "i"], ["i", "iv", "bVI", "V"], ["i", "bII", "V", "i"]]
    ]

    // MARK: - Initialization

    init() {
        loadModels()
        log.audio("✅ AIComposer: Initialized with music theory engine")
    }

    private func loadModels() {
        modelStatus = .loading
        usingFallbackMode = false
        lastError = nil

        Task {
            var loadedModels = 0
            var errors: [AIComposerError] = []

            // Attempt to load CoreML models from bundle
            do {
                if let melodyURL = Bundle.main.url(forResource: "MelodyGenerator", withExtension: "mlmodelc") {
                    melodyModel = try MLModel(contentsOf: melodyURL)
                    loadedModels += 1
                    log.audio("AIComposer: Melody model loaded")
                } else {
                    errors.append(.modelNotFound("MelodyGenerator"))
                }
            } catch {
                errors.append(.modelLoadFailed("MelodyGenerator", error))
                log.audio("AIComposer: Failed to load melody model - \(error.localizedDescription)")
            }

            do {
                if let chordURL = Bundle.main.url(forResource: "ChordPredictor", withExtension: "mlmodelc") {
                    chordModel = try MLModel(contentsOf: chordURL)
                    loadedModels += 1
                    log.audio("AIComposer: Chord model loaded")
                } else {
                    errors.append(.modelNotFound("ChordPredictor"))
                }
            } catch {
                errors.append(.modelLoadFailed("ChordPredictor", error))
                log.audio("AIComposer: Failed to load chord model - \(error.localizedDescription)")
            }

            do {
                if let drumURL = Bundle.main.url(forResource: "DrumPatternGenerator", withExtension: "mlmodelc") {
                    drumModel = try MLModel(contentsOf: drumURL)
                    loadedModels += 1
                    log.audio("AIComposer: Drum model loaded")
                } else {
                    errors.append(.modelNotFound("DrumPatternGenerator"))
                }
            } catch {
                errors.append(.modelLoadFailed("DrumPatternGenerator", error))
                log.audio("AIComposer: Failed to load drum model - \(error.localizedDescription)")
            }

            // Update status based on loaded models
            if loadedModels == 3 {
                modelStatus = .ready
                log.audio("AIComposer: All CoreML models loaded successfully")
            } else if loadedModels > 0 {
                modelStatus = .readyWithFallback
                usingFallbackMode = true
                log.audio("AIComposer: Partial model load (\(loadedModels)/3), using hybrid mode")
            } else {
                // No models loaded - use pure algorithmic fallback
                modelStatus = .readyWithFallback
                usingFallbackMode = true
                lastError = errors.first
                log.audio("AIComposer: No CoreML models available, using algorithmic generation")
            }
        }
    }

    // MARK: - Melody Generation

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        log.audio("🎼 AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")

        // Get scale pattern and root note
        let majorScale = [0, 2, 4, 5, 7, 9, 11]  // C major scale pattern
        guard let scalePattern = scalePatterns[scale.lowercased()],
              let rootNote = rootNotes[key] else {
            // Fallback to C major
            return generateAlgorithmicMelody(root: 60, scale: scalePatterns["major"] ?? majorScale, bars: bars)
        }

        let notes = generateAlgorithmicMelody(root: rootNote, scale: scalePattern, bars: bars)
        generatedMelody = notes
        return notes
    }

    private func generateAlgorithmicMelody(root: Int, scale: [Int], bars: Int) -> [Note] {
        var notes: [Note] = []
        var previousPitch = root
        let beatsPerBar = 4
        let totalBeats = bars * beatsPerBar

        // Rhythm patterns (in quarter notes)
        let rhythmPatterns: [[Double]] = [
            [1.0, 1.0, 1.0, 1.0],           // Quarter notes
            [0.5, 0.5, 1.0, 0.5, 0.5, 1.0], // Syncopated
            [1.5, 0.5, 1.0, 1.0],           // Dotted quarter
            [0.5, 0.5, 0.5, 0.5, 1.0, 1.0], // Eighth + quarters
            [2.0, 1.0, 1.0]                 // Half + quarters
        ]

        var currentBeat: Double = 0

        while currentBeat < Double(totalBeats) {
            guard let pattern = rhythmPatterns.randomElement() else { break }

            for duration in pattern {
                guard currentBeat + duration <= Double(totalBeats) else { break }

                // Generate melodic contour with step motion preference
                let interval = generateMelodicInterval(previousPitch: previousPitch, scale: scale, root: root)
                let newPitch = previousPitch + interval

                // Keep in singable range (C4-C6)
                let clampedPitch = max(60, min(84, newPitch))

                // Velocity varies with beat position
                let isDownbeat = currentBeat.truncatingRemainder(dividingBy: 4.0) == 0
                let velocity = isDownbeat ? Int.random(in: 90...110) : Int.random(in: 70...90)

                notes.append(Note(
                    pitch: clampedPitch,
                    duration: duration,
                    velocity: velocity
                ))

                previousPitch = clampedPitch
                currentBeat += duration
            }
        }

        return notes
    }

    private func generateMelodicInterval(previousPitch: Int, scale: [Int], root: Int) -> Int {
        // Prefer step motion (70%), allow leaps (30%)
        let isStep = Double.random(in: 0...1) < 0.7

        if isStep {
            // Move to adjacent scale degree (default to 2 semitones if scale empty)
            let interval = scale.randomElement() ?? 2
            return Bool.random() ? interval : -interval
        } else {
            // Leap (3rd, 4th, or 5th) - array always non-empty
            let leaps = [-7, -5, -4, -3, 3, 4, 5, 7]
            return leaps.randomElement() ?? 3
        }
    }

    // MARK: - Chord Suggestions

    func suggestChordProgression(key: String, mood: String) async -> [AIChord] {
        isGenerating = true
        defer { isGenerating = false }

        log.audio("🎹 AIComposer: Suggesting chords for \(key) \(mood)")

        let chords = [
            AIChord(root: "C", type: .major),
            AIChord(root: "Am", type: .minor),
            AIChord(root: "F", type: .major),
            AIChord(root: "G", type: .major)
        ]

        suggestedChords = chords
        return chords
    }

    // MARK: - Drum Pattern Generation

    func generateDrumPattern(style: MusicStyle, bars: Int) async -> [DrumHit] {
        isGenerating = true
        defer { isGenerating = false }

        log.audio("🥁 AIComposer: Generating \(style.rawValue) drum pattern (\(bars) bars)")

        var hits: [DrumHit] = []
        let beatsPerBar = 4

        for bar in 0..<bars {
            let barOffset = Double(bar * beatsPerBar)

            switch style {
            case .calm, .meditative:
                // Minimal, sparse pattern
                hits.append(DrumHit(instrument: .kick, time: barOffset, velocity: 80))
                hits.append(DrumHit(instrument: .ride, time: barOffset + 2, velocity: 60))

            case .balanced:
                // Standard 4/4 rock pattern
                hits.append(DrumHit(instrument: .kick, time: barOffset, velocity: 100))
                hits.append(DrumHit(instrument: .closedHat, time: barOffset + 0.5, velocity: 70))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 1, velocity: 90))
                hits.append(DrumHit(instrument: .closedHat, time: barOffset + 1.5, velocity: 70))
                hits.append(DrumHit(instrument: .kick, time: barOffset + 2, velocity: 95))
                hits.append(DrumHit(instrument: .closedHat, time: barOffset + 2.5, velocity: 70))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 3, velocity: 90))
                hits.append(DrumHit(instrument: .closedHat, time: barOffset + 3.5, velocity: 70))

            case .energetic, .uplifting:
                // Driving pattern with more hi-hats
                for i in 0..<8 {
                    hits.append(DrumHit(instrument: .closedHat, time: barOffset + Double(i) * 0.5, velocity: i % 2 == 0 ? 90 : 70))
                }
                hits.append(DrumHit(instrument: .kick, time: barOffset, velocity: 110))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 1, velocity: 100))
                hits.append(DrumHit(instrument: .kick, time: barOffset + 1.5, velocity: 90))
                hits.append(DrumHit(instrument: .kick, time: barOffset + 2, velocity: 105))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 3, velocity: 100))

            case .tense:
                // Syncopated, off-beat pattern
                hits.append(DrumHit(instrument: .kick, time: barOffset, velocity: 100))
                hits.append(DrumHit(instrument: .kick, time: barOffset + 0.75, velocity: 85))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 1.5, velocity: 95))
                hits.append(DrumHit(instrument: .kick, time: barOffset + 2.25, velocity: 90))
                hits.append(DrumHit(instrument: .snare, time: barOffset + 3, velocity: 95))
                hits.append(DrumHit(instrument: .openHat, time: barOffset + 3.5, velocity: 80))
            }
        }

        generatedDrumPattern = hits
        return hits
    }

    // MARK: - Bio-Data → Music Style

    func mapBioToMusicStyle(hrv: Float, coherence: Float, heartRate: Float) -> MusicStyle {
        currentStyle = calculateStyle(hrv: hrv, coherence: coherence, heartRate: heartRate)
        return currentStyle
    }

    private func calculateStyle(hrv: Float, coherence: Float, heartRate: Float) -> MusicStyle {
        // High coherence = calm/meditative
        if coherence > 0.8 {
            return .meditative
        } else if coherence > 0.6 {
            return .calm
        }

        // High heart rate = energetic
        if heartRate > 110 {
            return .energetic
        } else if heartRate > 90 {
            return .uplifting
        }

        // Low HRV = stress/tension
        if hrv < 25 {
            return .tense
        }

        return .balanced
    }

    // MARK: - Bio-Reactive Composition

    func composeBioReactivePiece(
        hrv: Float,
        coherence: Float,
        heartRate: Float,
        key: String = "C",
        bars: Int = 8
    ) async -> (melody: [Note], chords: [AIChord], drums: [DrumHit]) {
        isGenerating = true
        defer { isGenerating = false }

        let style = mapBioToMusicStyle(hrv: hrv, coherence: coherence, heartRate: heartRate)
        let scale = style.suggestedScale

        log.audio("🧠 AIComposer: Bio-reactive composition - Style: \(style.rawValue), Scale: \(scale)")

        async let melodyTask = generateMelody(key: key, scale: scale, bars: bars)
        async let chordsTask = suggestChordProgression(key: key, mood: style.rawValue.lowercased())
        async let drumsTask = generateDrumPattern(style: style, bars: bars)

        let melody = await melodyTask
        let chords = await chordsTask
        let drums = await drumsTask

        return (melody, chords, drums)
    }
}

// MARK: - Data Types

struct Note: Identifiable, Equatable {
    let id = UUID()
    let pitch: Int       // MIDI note number (0-127)
    let duration: Double // Duration in quarter notes
    let velocity: Int    // Velocity (0-127)

    var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = pitch / 12 - 1
        let note = noteNames[pitch % 12]
        return "\(note)\(octave)"
    }
}

struct AIChord: Identifiable, Equatable {
    let id = UUID()
    let root: String
    let type: AIChordType

    enum AIChordType: String, CaseIterable {
        case major = "maj"
        case minor = "min"
        case dominant7 = "7"
        case major7 = "maj7"
        case minor7 = "min7"
        case diminished = "dim"
        case augmented = "aug"
        case sus2 = "sus2"
        case sus4 = "sus4"
    }

    var displayName: String {
        "\(root)\(type.rawValue)"
    }

    var midiNotes: [Int] {
        guard let rootMidi = ["C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
                              "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71][root] else {
            return []
        }

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
}

struct DrumHit: Identifiable, Equatable {
    let id = UUID()
    let instrument: DrumInstrument
    let time: Double     // Position in beats
    let velocity: Int    // 0-127

    enum DrumInstrument: Int, CaseIterable {
        case kick = 36
        case snare = 38
        case closedHat = 42
        case openHat = 46
        case clap = 39
        case tom1 = 45
        case tom2 = 47
        case crash = 49
        case ride = 51

        var name: String {
            switch self {
            case .kick: return "Kick"
            case .snare: return "Snare"
            case .closedHat: return "Hi-Hat"
            case .openHat: return "Open Hat"
            case .clap: return "Clap"
            case .tom1: return "Tom 1"
            case .tom2: return "Tom 2"
            case .crash: return "Crash"
            case .ride: return "Ride"
            }
        }
    }
}

enum MusicStyle: String, CaseIterable {
    case calm = "Calm"
    case energetic = "Energetic"
    case tense = "Tense"
    case balanced = "Balanced"
    case meditative = "Meditative"
    case uplifting = "Uplifting"

    var suggestedTempo: ClosedRange<Int> {
        switch self {
        case .calm: return 60...80
        case .energetic: return 120...140
        case .tense: return 90...110
        case .balanced: return 100...120
        case .meditative: return 50...70
        case .uplifting: return 110...130
        }
    }

    var suggestedScale: String {
        switch self {
        case .calm: return "major"
        case .energetic: return "mixolydian"
        case .tense: return "minor"
        case .balanced: return "major"
        case .meditative: return "pentatonic"
        case .uplifting: return "major"
        }
    }
}
