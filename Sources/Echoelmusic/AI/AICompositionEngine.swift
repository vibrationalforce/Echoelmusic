import Foundation
import CoreML
import Combine

/// AI-powered composition and pattern generation engine
///
/// Features:
/// - Bio-reactive melody generation
/// - Harmonic progression suggestions
/// - Rhythm pattern generation
/// - Style transfer and adaptation
/// - Real-time compositional assistance
@MainActor
class AICompositionEngine: ObservableObject {

    // MARK: - Published State

    /// Whether AI composition is active
    @Published var isActive: Bool = false

    /// Current composition mode
    @Published var compositionMode: CompositionMode = .assist

    /// Generated musical suggestions
    @Published var suggestions: [MusicalSuggestion] = []

    /// Confidence score for current suggestions (0-1)
    @Published var confidence: Double = 0.0

    // MARK: - Configuration

    /// Composition modes
    enum CompositionMode: String, CaseIterable {
        case assist         // Suggest notes/chords
        case harmonize      // Auto-harmonization
        case accompany      // Generate accompaniment
        case improvise      // Full improvisation
        case transform      // Style transformation
    }

    /// Musical suggestion types
    struct MusicalSuggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let notes: [MIDINote]
        let timing: TimeInterval
        let confidence: Double
        let description: String

        enum SuggestionType {
            case melody
            case harmony
            case rhythm
            case chord
        }
    }

    struct MIDINote {
        let pitch: UInt8
        let velocity: UInt8
        let duration: TimeInterval
    }

    // MARK: - Dependencies

    private var healthKitManager: HealthKitManager?
    private var bioParameterMapper: BioParameterMapper?

    // ML Models (when available)
    // private var melodyModel: MLModel?
    // private var harmonyModel: MLModel?

    // MARK: - State

    private var currentKey: MusicalKey = .C
    private var currentScale: Scale = .major
    private var currentTempo: Double = 120.0

    // Musical context
    private var recentNotes: [MIDINote] = []
    private let maxContextNotes = 16

    // MARK: - Initialization

    init() {
        print("🤖 AICompositionEngine initialized")
    }

    // MARK: - Public API

    /// Start AI composition engine
    func start() {
        guard !isActive else { return }

        isActive = true
        print("🤖 AI Composition Engine started in \(compositionMode.rawValue) mode")
    }

    /// Stop AI composition engine
    func stop() {
        isActive = false
        suggestions.removeAll()
        print("🤖 AI Composition Engine stopped")
    }

    /// Set composition mode
    func setMode(_ mode: CompositionMode) {
        compositionMode = mode
        print("🤖 Composition mode: \(mode.rawValue)")
    }

    /// Process input note and generate suggestions
    func processNote(_ note: MIDINote) {
        guard isActive else { return }

        // Add to context
        recentNotes.append(note)
        if recentNotes.count > maxContextNotes {
            recentNotes.removeFirst()
        }

        // Generate suggestions based on mode
        generateSuggestions(for: note)
    }

    /// Set musical context
    func setMusicalContext(key: MusicalKey, scale: Scale, tempo: Double) {
        currentKey = key
        currentScale = scale
        currentTempo = tempo
    }

    /// Connect biofeedback for bio-reactive composition
    func connectBiofeedback(healthKit: HealthKitManager, bioMapper: BioParameterMapper) {
        self.healthKitManager = healthKit
        self.bioParameterMapper = bioMapper
        print("🤖 Biofeedback connected to AI composition")
    }

    // MARK: - Private Methods

    /// Generate musical suggestions based on current mode and context
    private func generateSuggestions(for inputNote: MIDINote) {
        var newSuggestions: [MusicalSuggestion] = []

        switch compositionMode {
        case .assist:
            // Suggest next likely notes based on scale and context
            newSuggestions = generateMelodySuggestions(after: inputNote)

        case .harmonize:
            // Generate harmonic accompaniment
            newSuggestions = generateHarmonization(for: inputNote)

        case .accompany:
            // Generate rhythmic/harmonic accompaniment
            newSuggestions = generateAccompaniment(for: inputNote)

        case .improvise:
            // Full AI improvisation
            newSuggestions = generateImprovisation()

        case .transform:
            // Transform input to different style
            newSuggestions = transformStyle(for: inputNote)
        }

        // Update suggestions and confidence
        suggestions = newSuggestions
        confidence = calculateConfidence(for: newSuggestions)
    }

    /// Generate melody suggestions
    private func generateMelodySuggestions(after note: MIDINote) -> [MusicalSuggestion] {
        // Simple rule-based melody generation
        // TODO: Replace with ML model predictions

        let scaleNotes = currentScale.notes(in: currentKey)
        var suggestions: [MusicalSuggestion] = []

        // Suggest notes in scale that are close to current note
        for interval in [-2, -1, 1, 2, 3, 5] {  // Steps, leaps
            let targetPitch = Int(note.pitch) + interval
            if scaleNotes.contains(UInt8(targetPitch % 12)) {
                let suggestedNote = MIDINote(
                    pitch: UInt8(max(0, min(127, targetPitch))),
                    velocity: note.velocity,
                    duration: 0.25  // Quarter note
                )

                suggestions.append(MusicalSuggestion(
                    type: .melody,
                    notes: [suggestedNote],
                    timing: 0.0,
                    confidence: calculateIntervalProbability(interval),
                    description: "Next note: \(noteName(suggestedNote.pitch))"
                ))
            }
        }

        return suggestions.prefix(3).map { $0 }
    }

    /// Generate harmonization
    private func generateHarmonization(for note: MIDINote) -> [MusicalSuggestion] {
        // Generate chord tones based on current note
        let chord = buildChord(root: note.pitch, type: .triad)

        return [MusicalSuggestion(
            type: .harmony,
            notes: chord,
            timing: 0.0,
            confidence: 0.8,
            description: "Harmonization: \(chordName(root: note.pitch))"
        )]
    }

    /// Generate accompaniment
    private func generateAccompaniment(for note: MIDINote) -> [MusicalSuggestion] {
        // Simple arpeggio pattern
        let chord = buildChord(root: note.pitch, type: .seventh)
        var arpNotes: [MIDINote] = []

        for (i, chordNote) in chord.enumerated() {
            arpNotes.append(MIDINote(
                pitch: chordNote.pitch,
                velocity: 60,
                duration: 0.125
            ))
        }

        return [MusicalSuggestion(
            type: .rhythm,
            notes: arpNotes,
            timing: 0.0,
            confidence: 0.7,
            description: "Arpeggiated accompaniment"
        )]
    }

    /// Generate improvisation
    private func generateImprovisation() -> [MusicalSuggestion] {
        // Bio-reactive improvisation
        guard let bioMapper = bioParameterMapper else {
            return []
        }

        // Use bio-parameters to influence improvisation
        let density = bioMapper.amplitude  // Note density
        let range = Int(bioMapper.filterCutoff / 100.0)  // Pitch range

        // Generate random notes in scale
        let scaleNotes = currentScale.notes(in: currentKey)
        var improv: [MIDINote] = []

        let noteCount = Int(density * 8.0)  // 0-8 notes
        for _ in 0..<noteCount {
            let randomScaleNote = scaleNotes.randomElement() ?? 60
            let octave = (3...5).randomElement() ?? 4
            let pitch = randomScaleNote + UInt8(octave * 12)

            improv.append(MIDINote(
                pitch: pitch,
                velocity: UInt8.random(in: 60...100),
                duration: [0.125, 0.25, 0.5].randomElement() ?? 0.25
            ))
        }

        return [MusicalSuggestion(
            type: .melody,
            notes: improv,
            timing: 0.0,
            confidence: 0.6,
            description: "Bio-reactive improvisation"
        )]
    }

    /// Transform style
    private func transformStyle(for note: MIDINote) -> [MusicalSuggestion] {
        // Placeholder for ML-based style transfer
        // TODO: Implement style transfer model
        return []
    }

    // MARK: - Music Theory Helpers

    /// Build chord from root note
    private func buildChord(root: UInt8, type: ChordType) -> [MIDINote] {
        let intervals: [Int]
        switch type {
        case .triad:
            intervals = [0, 4, 7]  // Major triad
        case .seventh:
            intervals = [0, 4, 7, 11]  // Major 7th
        case .ninth:
            intervals = [0, 4, 7, 11, 14]  // Major 9th
        }

        return intervals.map { interval in
            MIDINote(
                pitch: root + UInt8(interval),
                velocity: 80,
                duration: 1.0
            )
        }
    }

    enum ChordType {
        case triad
        case seventh
        case ninth
    }

    /// Calculate probability for interval
    private func calculateIntervalProbability(_ interval: Int) -> Double {
        // Simple heuristic: smaller intervals are more likely
        switch abs(interval) {
        case 1...2: return 0.9
        case 3...4: return 0.7
        case 5...7: return 0.5
        default: return 0.3
        }
    }

    /// Calculate overall confidence
    private func calculateConfidence(for suggestions: [MusicalSuggestion]) -> Double {
        guard !suggestions.isEmpty else { return 0.0 }
        return suggestions.map { $0.confidence }.reduce(0, +) / Double(suggestions.count)
    }

    /// Get note name from MIDI pitch
    private func noteName(_ pitch: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(pitch) / 12 - 1
        return "\(names[Int(pitch) % 12])\(octave)"
    }

    /// Get chord name
    private func chordName(root: UInt8) -> String {
        return "\(noteName(root)) Major"
    }

    // MARK: - Music Theory Types

    enum MusicalKey: UInt8, CaseIterable {
        case C = 0, Db = 1, D = 2, Eb = 3, E = 4, F = 5
        case Gb = 6, G = 7, Ab = 8, A = 9, Bb = 10, B = 11
    }

    enum Scale {
        case major
        case minor
        case dorian
        case phrygian
        case lydian
        case mixolydian
        case pentatonic

        func notes(in key: MusicalKey) -> [UInt8] {
            let root = key.rawValue
            let intervals: [UInt8]

            switch self {
            case .major:
                intervals = [0, 2, 4, 5, 7, 9, 11]
            case .minor:
                intervals = [0, 2, 3, 5, 7, 8, 10]
            case .dorian:
                intervals = [0, 2, 3, 5, 7, 9, 10]
            case .phrygian:
                intervals = [0, 1, 3, 5, 7, 8, 10]
            case .lydian:
                intervals = [0, 2, 4, 6, 7, 9, 11]
            case .mixolydian:
                intervals = [0, 2, 4, 5, 7, 9, 10]
            case .pentatonic:
                intervals = [0, 2, 4, 7, 9]
            }

            return intervals.map { root + $0 }
        }
    }
}
