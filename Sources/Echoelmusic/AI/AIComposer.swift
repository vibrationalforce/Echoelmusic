import Foundation
import CoreML

/// AI Composer - CoreML-powered Music Generation
/// Melody generation, chord progression suggestions, drum patterns
/// Bio-Data → Music Style mapping
///
/// Features:
/// - LSTM-based melody generation
/// - Chord progression suggestions with voice leading
/// - Drum pattern generation (style-aware)
/// - Bio-data to music style mapping
/// - Emotion-driven composition
///
@MainActor
class AIComposer: ObservableObject {

    @Published var isGenerating: Bool = false
    @Published var generatedMelody: [Note] = []
    @Published var suggestedChords: [Chord] = []
    @Published var currentEmotion: EnhancedMLModels.Emotion = .neutral

    // MARK: - AI Engines

    private var melodyGenerator: LSTMMelodyGenerator?
    private var patternGenerator: NeuralPatternGenerator?
    private var mlModels: EnhancedMLModels?

    // MARK: - CoreML Models

    private var melodyModel: MLModel?
    private var chordModel: MLModel?
    private var drumModel: MLModel?

    // MARK: - State

    private var isModelLoaded = false

    init() {
        Task {
            await loadModels()
        }
        print("✅ AIComposer: Initialized")
    }

    private func loadModels() async {
        melodyGenerator = LSTMMelodyGenerator()
        await melodyGenerator?.loadModel()

        patternGenerator = NeuralPatternGenerator()
        mlModels = EnhancedMLModels()

        isModelLoaded = true
        print("✅ AIComposer: All AI models loaded")
    }

    // MARK: - Melody Generation (LSTM-based)

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎼 AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")

        // Parse key and scale
        let musicalKey = parseKey(key)
        let scaleType = parseScale(scale)

        // Get tempo based on current emotion
        let tempo = Int(currentEmotion.recommendedBPM.lowerBound)

        // Generate using LSTM
        guard let generator = melodyGenerator else {
            // Fallback to simple generation
            let notes = (0..<bars*4).map { _ in
                Note(pitch: Int.random(in: 60...72), duration: 0.25, velocity: 80)
            }
            generatedMelody = notes
            return notes
        }

        let lstmMelody = await generator.generateMelody(
            key: musicalKey,
            scale: scaleType,
            bars: bars,
            tempo: tempo,
            emotion: currentEmotion
        )

        // Convert to Note format
        let notes = lstmMelody.map { melodyNote in
            Note(pitch: melodyNote.pitch, duration: melodyNote.duration, velocity: melodyNote.velocity)
        }

        generatedMelody = notes
        return notes
    }

    /// Generate melody with emotion awareness
    func generateEmotionalMelody(
        key: String,
        scale: String,
        bars: Int,
        hrv: Float,
        coherence: Float,
        heartRate: Float
    ) async -> [Note] {
        // First classify emotion
        mlModels?.classifyEmotion(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            variability: 0.2,
            hrvTrend: 0.01,
            coherenceTrend: 0.01
        )

        if let emotion = mlModels?.currentEmotion {
            currentEmotion = emotion
        }

        // Generate melody based on detected emotion
        return await generateMelody(key: key, scale: scale, bars: bars)
    }

    private func parseKey(_ key: String) -> LSTMMelodyGenerator.MusicalKey {
        let keyMap: [String: LSTMMelodyGenerator.MusicalKey] = [
            "C": .cMajor, "Cm": .cMinor,
            "D": .dMajor, "Dm": .dMinor,
            "E": .eMajor, "Em": .eMinor,
            "F": .fMajor, "Fm": .fMinor,
            "G": .gMajor, "Gm": .gMinor,
            "A": .aMajor, "Am": .aMinor,
            "B": .bMajor, "Bm": .bMinor
        ]
        return keyMap[key] ?? .cMajor
    }

    private func parseScale(_ scale: String) -> LSTMMelodyGenerator.ScaleType {
        let scaleMap: [String: LSTMMelodyGenerator.ScaleType] = [
            "Major": .major,
            "Minor": .minor,
            "Harmonic Minor": .harmonicMinor,
            "Melodic Minor": .melodicMinor,
            "Dorian": .dorian,
            "Phrygian": .phrygian,
            "Lydian": .lydian,
            "Mixolydian": .mixolydian,
            "Pentatonic": .pentatonic,
            "Blues": .blues
        ]
        return scaleMap[scale] ?? .major
    }

    // MARK: - Chord Suggestions

    func suggestChordProgression(key: String, mood: String) async -> [Chord] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎹 AIComposer: Suggesting chords for \(key) \(mood)")

        // Get mood-appropriate progressions
        let progressions = getProgressionsForMood(mood, key: key)
        let selectedProgression = progressions.randomElement() ?? progressions[0]

        suggestedChords = selectedProgression
        return selectedProgression
    }

    private func getProgressionsForMood(_ mood: String, key: String) -> [[Chord]] {
        switch mood.lowercased() {
        case "happy", "energetic":
            return [
                [Chord(root: "I", type: .major), Chord(root: "V", type: .major),
                 Chord(root: "vi", type: .minor), Chord(root: "IV", type: .major)],
                [Chord(root: "I", type: .major), Chord(root: "IV", type: .major),
                 Chord(root: "V", type: .major), Chord(root: "I", type: .major)],
                [Chord(root: "I", type: .major), Chord(root: "ii", type: .minor),
                 Chord(root: "IV", type: .major), Chord(root: "V", type: .major)]
            ]
        case "sad", "melancholic":
            return [
                [Chord(root: "i", type: .minor), Chord(root: "iv", type: .minor),
                 Chord(root: "VII", type: .major), Chord(root: "III", type: .major)],
                [Chord(root: "i", type: .minor), Chord(root: "VI", type: .major),
                 Chord(root: "III", type: .major), Chord(root: "VII", type: .major)],
                [Chord(root: "i", type: .minor), Chord(root: "v", type: .minor),
                 Chord(root: "iv", type: .minor), Chord(root: "i", type: .minor)]
            ]
        case "tense", "dramatic":
            return [
                [Chord(root: "i", type: .minor), Chord(root: "bVII", type: .major),
                 Chord(root: "bVI", type: .major), Chord(root: "V", type: .major)],
                [Chord(root: "i", type: .minor), Chord(root: "iv", type: .minor),
                 Chord(root: "v", type: .minor), Chord(root: "i", type: .minor)]
            ]
        case "calm", "relaxed":
            return [
                [Chord(root: "I", type: .major7), Chord(root: "vi", type: .minor),
                 Chord(root: "ii", type: .minor), Chord(root: "V", type: .dominant7)],
                [Chord(root: "I", type: .major7), Chord(root: "IV", type: .major7),
                 Chord(root: "iii", type: .minor), Chord(root: "vi", type: .minor)]
            ]
        default:
            return [
                [Chord(root: "C", type: .major), Chord(root: "Am", type: .minor),
                 Chord(root: "F", type: .major), Chord(root: "G", type: .major)]
            ]
        }
    }

    // MARK: - Drum Pattern Generation

    /// Generate drum pattern based on style
    func generateDrumPattern(style: String, bars: Int, tempo: Int) async -> NeuralPatternGenerator.DrumPattern? {
        isGenerating = true
        defer { isGenerating = false }

        print("🥁 AIComposer: Generating \(style) drum pattern (\(bars) bars @ \(tempo) BPM)")

        guard let generator = patternGenerator else { return nil }

        let musicStyle = parseMusicStyle(style)
        return await generator.generateDrumPattern(style: musicStyle, bars: bars, tempo: tempo)
    }

    private func parseMusicStyle(_ style: String) -> NeuralPatternGenerator.MusicStyle {
        let styleMap: [String: NeuralPatternGenerator.MusicStyle] = [
            "electronic": .electronic,
            "hiphop": .hiphop,
            "hip-hop": .hiphop,
            "rock": .rock,
            "jazz": .jazz,
            "latin": .latin,
            "funk": .funk,
            "reggae": .reggae,
            "dnb": .dnb,
            "drum and bass": .dnb,
            "house": .house,
            "trap": .trap
        ]
        return styleMap[style.lowercased()] ?? .electronic
    }

    // MARK: - Bassline Generation

    /// Generate bassline following chord progression
    func generateBassline(chords: [Chord], style: String, bars: Int) async -> [NeuralPatternGenerator.BassNote] {
        isGenerating = true
        defer { isGenerating = false }

        print("🎸 AIComposer: Generating bassline for \(chords.count) chords")

        guard let generator = patternGenerator else { return [] }

        let chordSymbols = chords.map { chord in
            NeuralPatternGenerator.ChordSymbol(
                root: chord.root,
                type: mapChordType(chord.type)
            )
        }

        let musicStyle = parseMusicStyle(style)
        return await generator.generateBassline(chords: chordSymbols, style: musicStyle, bars: bars)
    }

    private func mapChordType(_ type: Chord.ChordType) -> NeuralPatternGenerator.ChordSymbol.ChordType {
        switch type {
        case .major: return .major
        case .minor: return .minor
        case .dominant7: return .dominant7
        case .major7: return .major7
        }
    }

    // MARK: - Bio-Data → Music Style

    func mapBioToMusicStyle(hrv: Float, coherence: Float, heartRate: Float) -> MusicStyle {
        // Use ML models for more accurate classification
        mlModels?.classifyEmotion(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            variability: 0.2,
            hrvTrend: 0.01,
            coherenceTrend: 0.01
        )

        if let emotion = mlModels?.currentEmotion {
            currentEmotion = emotion
            switch emotion {
            case .calm, .relaxed:
                return .calm
            case .energetic, .happy:
                return .energetic
            case .anxious, .sad:
                return .tense
            default:
                return .balanced
            }
        }

        // Fallback to rule-based
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

    // MARK: - Complete Composition

    /// Generate a complete musical composition
    func composeTrack(
        key: String,
        style: String,
        bars: Int,
        includeDrums: Bool = true,
        includeBass: Bool = true,
        includeMelody: Bool = true
    ) async -> CompositionResult {
        isGenerating = true
        defer { isGenerating = false }

        print("🎵 AIComposer: Composing complete track in \(key) \(style)")

        var result = CompositionResult()

        // Generate chord progression first
        let mood = getMoodForStyle(style)
        result.chords = await suggestChordProgression(key: key, mood: mood)

        // Generate melody
        if includeMelody {
            let scale = getScaleForStyle(style)
            result.melody = await generateMelody(key: key, scale: scale, bars: bars)
        }

        // Generate drums
        if includeDrums {
            result.drumPattern = await generateDrumPattern(style: style, bars: bars, tempo: 120)
        }

        // Generate bassline
        if includeBass {
            result.bassline = await generateBassline(chords: result.chords, style: style, bars: bars)
        }

        return result
    }

    private func getMoodForStyle(_ style: String) -> String {
        switch style.lowercased() {
        case "electronic", "house", "dnb": return "energetic"
        case "jazz", "ambient": return "calm"
        case "hiphop", "trap": return "tense"
        case "rock", "funk": return "energetic"
        default: return "balanced"
        }
    }

    private func getScaleForStyle(_ style: String) -> String {
        switch style.lowercased() {
        case "jazz": return "Dorian"
        case "blues", "rock": return "Blues"
        case "electronic", "house": return "Minor"
        default: return "Major"
        }
    }
}

// MARK: - Composition Result

struct CompositionResult {
    var melody: [Note] = []
    var chords: [Chord] = []
    var drumPattern: NeuralPatternGenerator.DrumPattern?
    var bassline: [NeuralPatternGenerator.BassNote] = []
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
