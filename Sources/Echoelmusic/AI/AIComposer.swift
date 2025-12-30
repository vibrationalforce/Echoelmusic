import Foundation
import CoreML

/// AI Composer - CoreML-powered Music Generation
/// Melody generation, chord progression suggestions, drum patterns
/// Bio-Data → Music Style mapping
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class AIComposer {

    var isGenerating: Bool = false
    var generatedMelody: [Note] = []
    var suggestedChords: [Chord] = []

    // MARK: - CoreML Models (placeholders)

    private var melodyModel: MLModel?
    private var chordModel: MLModel?
    private var drumModel: MLModel?

    init() {
        // TODO: Load CoreML models
        #if DEBUG
        debugLog("✅", "AIComposer: Initialized")
        #endif
    }

    // MARK: - Melody Generation

    func generateMelody(key: String, scale: String, bars: Int) async -> [Note] {
        isGenerating = true
        defer { isGenerating = false }

        // TODO: Implement LSTM-based melody generation
        #if DEBUG
        debugLog("🎼", "AIComposer: Generating melody in \(key) \(scale) (\(bars) bars)")
        #endif

        let notes = (0..<bars*4).map { _ in
            Note(pitch: Int.random(in: 60...72), duration: 0.25, velocity: 80)
        }

        generatedMelody = notes
        return notes
    }

    // MARK: - Chord Suggestions

    func suggestChordProgression(key: String, mood: String) async -> [Chord] {
        isGenerating = true
        defer { isGenerating = false }

        #if DEBUG
        debugLog("🎹", "AIComposer: Suggesting chords for \(key) \(mood)")
        #endif

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

// MARK: - ObservableObject Conformance (Backward Compatibility)

/// Allows AIComposer to work with older SwiftUI code expecting ObservableObject
extension AIComposer: ObservableObject { }
