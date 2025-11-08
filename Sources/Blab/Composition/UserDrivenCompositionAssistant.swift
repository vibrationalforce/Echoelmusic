import Foundation
import Combine

/// User-Driven Composition Assistant
///
/// Philosophy: Users determine where it goes - AI never takes over
///
/// Features:
/// - Suggests musical ideas (never auto-applies)
/// - All suggestions require user approval
/// - Preview before accepting
/// - Manual control for all parameters
/// - Bio-reactive suggestions (user decides if/when to use)
/// - Transparent confidence scores
@MainActor
class UserDrivenCompositionAssistant: ObservableObject {

    // MARK: - Published State

    /// Whether assistant is listening
    @Published var isListening: Bool = false

    /// Current assistance mode
    @Published var assistanceMode: AssistanceMode = .off

    /// Musical suggestions (NEVER auto-applied)
    @Published var suggestions: [MusicalSuggestion] = []

    /// User can preview suggestions before accepting
    @Published var previewingSuggestion: MusicalSuggestion?

    /// Suggestion acceptance history (for learning user preferences)
    @Published var acceptanceRate: Double = 0.0

    // MARK: - Configuration

    /// Assistance modes - ALL require user approval
    enum AssistanceMode: String, CaseIterable {
        case off                    // No suggestions
        case suggestNext           // Suggest next notes (user picks)
        case suggestHarmonies      // Suggest harmonies (user picks)
        case suggestAccompaniment  // Suggest accompaniment patterns (user picks)
        case suggestVariations     // Suggest variations of user input (user picks)
        case showTheory            // Show music theory info (educational)

        var description: String {
            switch self {
            case .off:
                return "No AI suggestions"
            case .suggestNext:
                return "Suggest next notes (you decide)"
            case .suggestHarmonies:
                return "Suggest harmonies (you decide)"
            case .suggestAccompaniment:
                return "Suggest accompaniment ideas (you decide)"
            case .suggestVariations:
                return "Suggest variations (you decide)"
            case .showTheory:
                return "Show music theory context"
            }
        }
    }

    /// Musical suggestion - requires explicit user approval
    struct MusicalSuggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let notes: [MIDINote]
        let timing: TimeInterval
        let confidence: Double
        let description: String
        let rationale: String  // WHY is this suggested? Transparency!
        var isAccepted: Bool = false
        var isPreviewed: Bool = false

        enum SuggestionType {
            case nextNote          // Single note continuation
            case melodicPhrase     // Short phrase (2-4 notes)
            case harmony           // Harmonic notes
            case rhythmPattern     // Rhythm suggestion
            case chord             // Chord voicing
        }
    }

    struct MIDINote {
        let pitch: UInt8
        let velocity: UInt8
        let duration: TimeInterval
    }

    // MARK: - User Preferences

    struct UserPreferences {
        var showConfidenceScores: Bool = true
        var showRationale: Bool = true
        var suggestionCount: Int = 3  // Max suggestions to show
        var minConfidence: Double = 0.5  // Filter low-confidence suggestions
        var autoPreview: Bool = false  // If true, play suggestions on hover
    }

    var preferences = UserPreferences()

    // MARK: - Musical Context (User-Set)

    private var userSetKey: MusicalKey = .C
    private var userSetScale: Scale = .major
    private var userSetTempo: Double = 120.0

    // Musical context (what user has played)
    private var userPlayedNotes: [MIDINote] = []
    private let maxContextNotes = 16

    // Bio-feedback (suggestions only, never auto-apply)
    private var bioParameterMapper: BioParameterMapper?

    // Suggestion statistics
    private var suggestionsOffered: Int = 0
    private var suggestionsAccepted: Int = 0

    // MARK: - Initialization

    init() {
        print("🎵 UserDrivenCompositionAssistant initialized (AI-FREE mode)")
    }

    // MARK: - Public API

    /// Start listening for user input (does NOT auto-play anything)
    func startListening() {
        guard !isListening else { return }

        isListening = true
        print("👂 Assistant listening in '\(assistanceMode.rawValue)' mode (suggestions only)")
    }

    /// Stop listening
    func stopListening() {
        isListening = false
        suggestions.removeAll()
        previewingSuggestion = nil
        print("🔇 Assistant stopped listening")
    }

    /// Set assistance mode (user chooses level of help)
    func setMode(_ mode: AssistanceMode) {
        assistanceMode = mode
        suggestions.removeAll()  // Clear old suggestions
        print("🎵 Assistance mode: \(mode.description)")
    }

    /// User played a note - record and optionally generate suggestions
    func userPlayedNote(_ note: MIDINote) {
        guard isListening, assistanceMode != .off else { return }

        // Add to user's played notes
        userPlayedNotes.append(note)
        if userPlayedNotes.count > maxContextNotes {
            userPlayedNotes.removeFirst()
        }

        // Generate suggestions based on mode (NEVER auto-apply)
        generateSuggestions(after: note)
    }

    /// User previews a suggestion (does NOT accept it)
    func previewSuggestion(_ suggestion: MusicalSuggestion) {
        previewingSuggestion = suggestion

        // Mark as previewed
        if let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            suggestions[index].isPreviewed = true
        }

        print("👁️ Previewing: \(suggestion.description)")
        // UI layer should trigger audio preview
    }

    /// User explicitly ACCEPTS a suggestion (only way to use it)
    func acceptSuggestion(_ suggestion: MusicalSuggestion) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else {
            return
        }

        suggestions[index].isAccepted = true
        suggestionsAccepted += 1
        updateAcceptanceRate()

        print("✅ User accepted: \(suggestion.description)")

        // Remove accepted suggestion from list
        suggestions.remove(at: index)

        // Caller should apply the notes to audio engine
    }

    /// User explicitly REJECTS a suggestion
    func rejectSuggestion(_ suggestion: MusicalSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        updateAcceptanceRate()
        print("❌ User rejected: \(suggestion.description)")
    }

    /// Clear all suggestions
    func clearSuggestions() {
        suggestions.removeAll()
        previewingSuggestion = nil
    }

    /// User manually sets musical context (no AI override)
    func setMusicalContext(key: MusicalKey, scale: Scale, tempo: Double) {
        userSetKey = key
        userSetScale = scale
        userSetTempo = tempo
        print("🎼 User set: \(key) \(scale) @ \(tempo) BPM")
    }

    /// Connect bio-feedback (suggestions only, user decides if/when to use)
    func connectBioFeedback(bioMapper: BioParameterMapper) {
        self.bioParameterMapper = bioMapper
        print("💓 Bio-feedback connected (suggestions only, user decides)")
    }

    /// Get music theory information (educational)
    func getMusicTheoryContext(for note: MIDINote) -> MusicTheoryInfo {
        let degree = getScaleDegree(note.pitch, in: userSetKey, scale: userSetScale)
        let interval = getInterval(from: userPlayedNotes.last?.pitch ?? 60, to: note.pitch)
        let chordTones = getChordTones(root: note.pitch)

        return MusicTheoryInfo(
            noteName: noteName(note.pitch),
            scaleDegree: degree,
            interval: interval,
            possibleChords: chordTones,
            inScale: isInScale(note.pitch, key: userSetKey, scale: userSetScale)
        )
    }

    // MARK: - Private Methods

    /// Generate suggestions (NEVER auto-apply)
    private func generateSuggestions(after note: MIDINote) {
        var newSuggestions: [MusicalSuggestion] = []

        switch assistanceMode {
        case .off:
            return

        case .suggestNext:
            newSuggestions = suggestNextNotes(after: note)

        case .suggestHarmonies:
            newSuggestions = suggestHarmonies(for: note)

        case .suggestAccompaniment:
            newSuggestions = suggestAccompaniment(for: note)

        case .suggestVariations:
            newSuggestions = suggestVariations(of: note)

        case .showTheory:
            // Just show theory info, no suggestions
            return
        }

        // Filter by confidence and user preferences
        newSuggestions = newSuggestions.filter { $0.confidence >= preferences.minConfidence }
        newSuggestions = Array(newSuggestions.prefix(preferences.suggestionCount))

        suggestionsOffered += newSuggestions.count
        suggestions = newSuggestions

        print("💡 \(newSuggestions.count) suggestions available (user decides)")
    }

    /// Suggest next notes (user picks one, or ignores all)
    private func suggestNextNotes(after note: MIDINote) -> [MusicalSuggestion] {
        let scaleNotes = userSetScale.notes(in: userSetKey)
        var suggestions: [MusicalSuggestion] = []

        // Suggest melodically logical next notes
        for interval in [-2, -1, 1, 2, 3, 5, 8] {  // Steps, leaps, octave
            let targetPitch = Int(note.pitch) + interval
            guard targetPitch >= 0 && targetPitch <= 127 else { continue }

            let pitchClass = UInt8(targetPitch % 12)
            let isInScale = scaleNotes.contains(pitchClass)

            if isInScale || abs(interval) == 1 {  // In-scale or chromatic neighbor
                let suggestedNote = MIDINote(
                    pitch: UInt8(targetPitch),
                    velocity: note.velocity,
                    duration: 0.25
                )

                let confidence = calculateConfidenceForInterval(interval, inScale: isInScale)
                let rationale = buildRationale(interval: interval, inScale: isInScale)

                suggestions.append(MusicalSuggestion(
                    type: .nextNote,
                    notes: [suggestedNote],
                    timing: 0.0,
                    confidence: confidence,
                    description: "Next: \(noteName(suggestedNote.pitch))",
                    rationale: rationale
                ))
            }
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    /// Suggest harmonies (user picks which harmony to use)
    private func suggestHarmonies(for note: MIDINote) -> [MusicalSuggestion] {
        var suggestions: [MusicalSuggestion] = []

        // Suggest different chord voicings
        let chordTypes: [(ChordType, String)] = [
            (.triad, "Major Triad"),
            (.seventh, "Major 7th"),
            (.ninth, "Major 9th")
        ]

        for (chordType, name) in chordTypes {
            let chord = buildChord(root: note.pitch, type: chordType)

            suggestions.append(MusicalSuggestion(
                type: .harmony,
                notes: chord,
                timing: 0.0,
                confidence: 0.8,
                description: name,
                rationale: "Harmonizes \(noteName(note.pitch)) with \(name.lowercased())"
            ))
        }

        return suggestions
    }

    /// Suggest accompaniment patterns (user picks which pattern)
    private func suggestAccompaniment(for note: MIDINote) -> [MusicalSuggestion] {
        var suggestions: [MusicalSuggestion] = []

        // Pattern 1: Arpeggio
        let chord = buildChord(root: note.pitch, type: .triad)
        let arpeggio = chord.enumerated().map { index, chordNote in
            MIDINote(pitch: chordNote.pitch, velocity: 60, duration: 0.125)
        }

        suggestions.append(MusicalSuggestion(
            type: .rhythmPattern,
            notes: arpeggio,
            timing: 0.0,
            confidence: 0.7,
            description: "Arpeggio Pattern",
            rationale: "Arpeggiated \(noteName(note.pitch)) chord"
        ))

        // Pattern 2: Alberti Bass
        if chord.count >= 3 {
            let alberti = [chord[0], chord[2], chord[1], chord[2]].map {
                MIDINote(pitch: $0.pitch, velocity: 50, duration: 0.125)
            }

            suggestions.append(MusicalSuggestion(
                type: .rhythmPattern,
                notes: alberti,
                timing: 0.0,
                confidence: 0.65,
                description: "Alberti Bass",
                rationale: "Classic accompaniment pattern"
            ))
        }

        return suggestions
    }

    /// Suggest variations (user picks which variation)
    private func suggestVariations(of note: MIDINote) -> [MusicalSuggestion] {
        var suggestions: [MusicalSuggestion] = []

        // Variation 1: Octave transposition
        if note.pitch >= 12 {
            let octaveDown = MIDINote(pitch: note.pitch - 12, velocity: note.velocity, duration: note.duration)
            suggestions.append(MusicalSuggestion(
                type: .nextNote,
                notes: [octaveDown],
                timing: 0.0,
                confidence: 0.8,
                description: "Octave Lower",
                rationale: "Same note, one octave down"
            ))
        }

        if note.pitch <= 115 {
            let octaveUp = MIDINote(pitch: note.pitch + 12, velocity: note.velocity, duration: note.duration)
            suggestions.append(MusicalSuggestion(
                type: .nextNote,
                notes: [octaveUp],
                timing: 0.0,
                confidence: 0.8,
                description: "Octave Higher",
                rationale: "Same note, one octave up"
            ))
        }

        // Variation 2: Rhythmic variation
        let dottedRhythm = MIDINote(pitch: note.pitch, velocity: note.velocity, duration: note.duration * 1.5)
        suggestions.append(MusicalSuggestion(
            type: .nextNote,
            notes: [dottedRhythm],
            timing: 0.0,
            confidence: 0.6,
            description: "Dotted Rhythm",
            rationale: "Same note with dotted rhythm"
        ))

        return suggestions
    }

    // MARK: - Confidence & Rationale

    private func calculateConfidenceForInterval(_ interval: Int, inScale: Bool) -> Double {
        var confidence = 0.5

        // In-scale notes are more confident
        if inScale {
            confidence += 0.3
        }

        // Smaller intervals are more confident (melody tends to move stepwise)
        switch abs(interval) {
        case 1...2:
            confidence += 0.2
        case 3...4:
            confidence += 0.1
        case 5...7:
            confidence += 0.05
        default:
            break
        }

        return min(confidence, 1.0)
    }

    private func buildRationale(interval: Int, inScale: Bool) -> String {
        var rationale = ""

        if abs(interval) == 1 {
            rationale += "Step-wise motion"
        } else if abs(interval) <= 4 {
            rationale += "Small melodic leap"
        } else {
            rationale += "Larger melodic leap"
        }

        if inScale {
            rationale += " (in \(userSetScale) scale)"
        } else {
            rationale += " (chromatic)"
        }

        return rationale
    }

    // MARK: - Music Theory Helpers

    private func buildChord(root: UInt8, type: ChordType) -> [MIDINote] {
        let intervals: [Int]
        switch type {
        case .triad:
            intervals = [0, 4, 7]
        case .seventh:
            intervals = [0, 4, 7, 11]
        case .ninth:
            intervals = [0, 4, 7, 11, 14]
        }

        return intervals.map { interval in
            MIDINote(pitch: root + UInt8(interval), velocity: 80, duration: 1.0)
        }
    }

    private func getScaleDegree(_ pitch: UInt8, in key: MusicalKey, scale: Scale) -> Int {
        let scaleNotes = scale.notes(in: key)
        let pitchClass = pitch % 12

        if let index = scaleNotes.firstIndex(of: pitchClass) {
            return index + 1  // 1-based (I, II, III, etc.)
        }
        return 0  // Not in scale
    }

    private func getInterval(from pitch1: UInt8, to pitch2: UInt8) -> Int {
        return Int(pitch2) - Int(pitch1)
    }

    private func getChordTones(root: UInt8) -> [String] {
        return ["Major", "Minor", "Diminished", "Augmented", "7th", "9th"]
    }

    private func isInScale(_ pitch: UInt8, key: MusicalKey, scale: Scale) -> Bool {
        let scaleNotes = scale.notes(in: key)
        return scaleNotes.contains(pitch % 12)
    }

    private func noteName(_ pitch: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(pitch) / 12 - 1
        return "\(names[Int(pitch) % 12])\(octave)"
    }

    private func updateAcceptanceRate() {
        if suggestionsOffered > 0 {
            acceptanceRate = Double(suggestionsAccepted) / Double(suggestionsOffered)
        }
    }

    // MARK: - Supporting Types

    enum ChordType {
        case triad
        case seventh
        case ninth
    }

    struct MusicTheoryInfo {
        let noteName: String
        let scaleDegree: Int
        let interval: Int
        let possibleChords: [String]
        let inScale: Bool

        var description: String {
            var desc = "\(noteName)"
            if scaleDegree > 0 {
                desc += " (degree \(scaleDegree))"
            }
            if !inScale {
                desc += " [outside scale]"
            }
            return desc
        }
    }

    enum MusicalKey: UInt8, CaseIterable {
        case C = 0, Db = 1, D = 2, Eb = 3, E = 4, F = 5
        case Gb = 6, G = 7, Ab = 8, A = 9, Bb = 10, B = 11

        var description: String {
            switch self {
            case .C: return "C"
            case .Db: return "Db"
            case .D: return "D"
            case .Eb: return "Eb"
            case .E: return "E"
            case .F: return "F"
            case .Gb: return "Gb"
            case .G: return "G"
            case .Ab: return "Ab"
            case .A: return "A"
            case .Bb: return "Bb"
            case .B: return "B"
            }
        }
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

        var description: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            case .dorian: return "Dorian"
            case .phrygian: return "Phrygian"
            case .lydian: return "Lydian"
            case .mixolydian: return "Mixolydian"
            case .pentatonic: return "Pentatonic"
            }
        }
    }
}
