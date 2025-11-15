import Foundation
import SwiftUI

// MARK: - AI Composition Tools
/// Intelligent composition assistance using pattern recognition and music theory
/// Phase 6.2: Smart chord suggestions, melody generation, bassline creation
class CompositionTools: ObservableObject {

    // MARK: - Published Properties
    @Published var suggestedChords: [ChordSuggestion] = []
    @Published var generatedMelody: [Note] = []
    @Published var generatedBassline: [Note] = []
    @Published var isGenerating: Bool = false

    // MARK: - Properties
    private let patternRecognition: PatternRecognition
    private let musicTheory = MusicTheory()

    // MARK: - Initialization
    init(patternRecognition: PatternRecognition) {
        self.patternRecognition = patternRecognition
    }

    // MARK: - Chord Suggestions

    /// Suggests next chord based on current progression
    func suggestNextChord(
        currentProgression: [Chord],
        key: Key,
        style: MusicStyle = .pop
    ) -> [ChordSuggestion] {
        var suggestions: [ChordSuggestion] = []

        // Get chord functions (I, IV, V, etc.)
        let currentFunctions = currentProgression.map { musicTheory.chordFunction($0, in: key) }

        // Common progressions database
        let commonProgressions = musicTheory.commonProgressions(for: style)

        // Match current progression to database
        for progression in commonProgressions {
            if currentFunctions.hasSuffix(progression.prefix(currentFunctions.count)) {
                // Found matching pattern, suggest next chord
                if progression.count > currentFunctions.count {
                    let nextFunction = progression[currentFunctions.count]
                    let nextChord = musicTheory.chordFromFunction(nextFunction, in: key)

                    let suggestion = ChordSuggestion(
                        chord: nextChord,
                        confidence: progression.confidence,
                        reason: "Common \(style.rawValue) progression"
                    )
                    suggestions.append(suggestion)
                }
            }
        }

        // Music theory rules (e.g., V → I, IV → I, ii → V)
        if let lastChord = currentProgression.last {
            let theoryBased = musicTheory.resolutionChords(for: lastChord, in: key)
            suggestions.append(contentsOf: theoryBased.map { chord in
                ChordSuggestion(
                    chord: chord,
                    confidence: 0.8,
                    reason: "Theory-based resolution"
                )
            })
        }

        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }

        // Remove duplicates
        var seen = Set<String>()
        suggestions = suggestions.filter { suggestion in
            let key = suggestion.chord.name
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        DispatchQueue.main.async {
            self.suggestedChords = Array(suggestions.prefix(5))
        }

        return Array(suggestions.prefix(5))
    }

    /// Generates complete chord progression
    func generateChordProgression(
        key: Key,
        style: MusicStyle,
        length: Int = 4
    ) -> [Chord] {
        var progression: [Chord] = []

        // Start with tonic
        let tonicChord = musicTheory.chordFromFunction(.tonic, in: key)
        progression.append(tonicChord)

        // Generate rest of progression
        for _ in 1..<length {
            let suggestions = suggestNextChord(
                currentProgression: progression,
                key: key,
                style: style
            )

            if let best = suggestions.first {
                progression.append(best.chord)
            } else {
                // Fallback: return to tonic
                progression.append(tonicChord)
            }
        }

        return progression
    }

    // MARK: - Melody Generation

    /// Generates melody over chord progression
    func generateMelody(
        chords: [Chord],
        key: Key,
        style: MelodyStyle,
        complexity: Float = 0.5
    ) -> [Note] {
        DispatchQueue.main.async {
            self.isGenerating = true
        }

        var melody: [Note] = []
        let scale = Scale(root: key.tonic, type: key.mode == .major ? .major : .naturalMinor)
        let scalePitches = Array(scale.pitchClasses)

        let notesPerChord = Int(4 * (1.0 + complexity)) // 4-8 notes per chord

        for (chordIndex, chord) in chords.enumerated() {
            let chordTones = Array(chord.type.pitchClasses(root: chord.root))

            for noteIndex in 0..<notesPerChord {
                // Calculate note timing
                let beatPosition = Double(chordIndex * notesPerChord + noteIndex) * (1.0 / Double(notesPerChord))

                // Choose pitch based on style
                let pitch: PitchClass

                switch style {
                case .chordTones:
                    // Stick to chord tones
                    pitch = chordTones.randomElement() ?? chord.root

                case .scalic:
                    // Use scale notes, prefer chord tones on strong beats
                    let isStrongBeat = noteIndex % notesPerChord == 0
                    if isStrongBeat {
                        pitch = chordTones.randomElement() ?? chord.root
                    } else {
                        pitch = scalePitches.randomElement() ?? key.tonic
                    }

                case .chromatic:
                    // Use all 12 chromatic notes, but resolve to chord tones
                    let isResolution = (noteIndex + 1) % 2 == 0
                    if isResolution {
                        pitch = chordTones.randomElement() ?? chord.root
                    } else {
                        pitch = PitchClass(rawValue: Int.random(in: 0...11)) ?? key.tonic
                    }
                }

                // Determine octave (middle range for melody)
                let octave = 4 + (Int.random(in: -1...1))
                let midiNote = UInt8(pitch.rawValue + 12 * octave)

                // Determine duration (vary based on complexity)
                let baseDuration: Double = 0.25 // 16th note
                let duration = baseDuration * Double.random(in: 1.0...(1.0 + Double(complexity)))

                // Determine velocity (add dynamics)
                let baseVelocity: UInt8 = 80
                let velocity = UInt8(max(40, min(127, Int(baseVelocity) + Int.random(in: -20...20))))

                let note = Note(
                    pitch: midiNote,
                    velocity: velocity,
                    startTime: beatPosition,
                    duration: duration
                )

                melody.append(note)
            }
        }

        // Apply humanization (slight timing and velocity variations)
        melody = humanize(notes: melody, amount: 0.1)

        DispatchQueue.main.async {
            self.generatedMelody = melody
            self.isGenerating = false
        }

        return melody
    }

    // MARK: - Bassline Generation

    /// Generates bassline following chord progression
    func generateBassline(
        chords: [Chord],
        key: Key,
        style: BasslineStyle,
        complexity: Float = 0.5
    ) -> [Note] {
        var bassline: [Note] = []
        let beatsPerChord = 4

        for (chordIndex, chord) in chords.enumerated() {
            let chordTones = Array(chord.type.pitchClasses(root: chord.root)).sorted { $0.rawValue < $1.rawValue }
            let root = chord.root

            for beat in 0..<beatsPerChord {
                let startTime = Double(chordIndex * beatsPerChord + beat)

                // Choose pitch based on style
                let pitch: PitchClass

                switch style {
                case .roots:
                    // Simple root notes
                    pitch = root

                case .rootFifth:
                    // Alternate root and fifth
                    if beat % 2 == 0 {
                        pitch = root
                    } else {
                        // Fifth
                        let fifthIndex = (root.rawValue + 7) % 12
                        pitch = PitchClass(rawValue: fifthIndex) ?? root
                    }

                case .walking:
                    // Walking bass (stepwise motion through chord tones and scale)
                    if beat == 0 {
                        pitch = root
                    } else {
                        // Use chord tones or chromatic approach
                        let useChordTone = Float.random(in: 0...1) < 0.7
                        if useChordTone {
                            pitch = chordTones.randomElement() ?? root
                        } else {
                            // Chromatic approach to next chord tone
                            pitch = PitchClass(rawValue: Int.random(in: 0...11)) ?? root
                        }
                    }

                case .arpeggio:
                    // Arpeggiate chord tones
                    let toneIndex = beat % chordTones.count
                    pitch = chordTones[toneIndex]
                }

                // Bass octave (low range)
                let octave = 2
                let midiNote = UInt8(pitch.rawValue + 12 * octave)

                // Duration
                let duration: Double
                switch style {
                case .roots, .rootFifth:
                    duration = 1.0 // Quarter note
                case .walking, .arpeggio:
                    duration = 0.5 + Double(complexity) * 0.5 // Vary with complexity
                }

                // Velocity (bass is usually consistent)
                let velocity: UInt8 = beat == 0 ? 90 : 70 // Accent downbeat

                let note = Note(
                    pitch: midiNote,
                    velocity: velocity,
                    startTime: startTime,
                    duration: duration
                )

                bassline.append(note)
            }
        }

        // Apply subtle humanization
        bassline = humanize(notes: bassline, amount: 0.05)

        DispatchQueue.main.async {
            self.generatedBassline = bassline
        }

        return bassline
    }

    // MARK: - Drum Pattern Generation

    /// Generates drum pattern
    func generateDrumPattern(
        style: DrumStyle,
        bars: Int = 1,
        complexity: Float = 0.5
    ) -> [DrumHit] {
        var pattern: [DrumHit] = []
        let beatsPerBar = 16 // 16th notes

        for bar in 0..<bars {
            for beat in 0..<beatsPerBar {
                let time = Double(bar * beatsPerBar + beat) * 0.25

                switch style {
                case .fourOnFloor:
                    // Kick on every beat
                    if beat % 4 == 0 {
                        pattern.append(DrumHit(instrument: .kick, time: time, velocity: 100))
                    }
                    // Snare on 2 and 4
                    if beat == 4 || beat == 12 {
                        pattern.append(DrumHit(instrument: .snare, time: time, velocity: 90))
                    }
                    // Hi-hat 8ths or 16ths based on complexity
                    if complexity > 0.5 || beat % 2 == 0 {
                        let velocity = UInt8(70 + Int(complexity * 20))
                        pattern.append(DrumHit(instrument: .hiHat, time: time, velocity: velocity))
                    }

                case .hiphop:
                    // Kick pattern
                    if [0, 6, 12].contains(beat) {
                        pattern.append(DrumHit(instrument: .kick, time: time, velocity: 100))
                    }
                    // Snare on 4 and 12
                    if beat == 4 || beat == 12 {
                        pattern.append(DrumHit(instrument: .snare, time: time, velocity: 95))
                    }
                    // Hi-hat with variations
                    if beat % 2 == 0 {
                        let velocity = (beat % 4 == 0) ? UInt8(80) : UInt8(60)
                        pattern.append(DrumHit(instrument: .hiHat, time: time, velocity: velocity))
                    }
                    // Additional hits based on complexity
                    if complexity > 0.5 && Float.random(in: 0...1) < complexity * 0.3 {
                        pattern.append(DrumHit(instrument: .snare, time: time, velocity: 50))
                    }

                case .dnb:
                    // Complex breakbeat pattern
                    // Kick
                    if [0, 9].contains(beat) {
                        pattern.append(DrumHit(instrument: .kick, time: time, velocity: 100))
                    }
                    // Snare
                    if [4, 12].contains(beat) {
                        pattern.append(DrumHit(instrument: .snare, time: time, velocity: 95))
                    }
                    // Hi-hat on every 16th
                    let velocity = (beat % 4 == 0) ? UInt8(80) : UInt8(50)
                    pattern.append(DrumHit(instrument: .hiHat, time: time, velocity: velocity))
                }
            }
        }

        return pattern
    }

    // MARK: - Humanization

    private func humanize(notes: [Note], amount: Float) -> [Note] {
        return notes.map { note in
            var humanized = note

            // Timing variation (±amount of a 16th note)
            let timingVariation = Double.random(in: -Double(amount)...Double(amount)) * 0.0625
            humanized.startTime += timingVariation

            // Velocity variation
            let velocityVariation = Int(Float.random(in: -amount...amount) * 20)
            let newVelocity = Int(note.velocity) + velocityVariation
            humanized.velocity = UInt8(max(1, min(127, newVelocity)))

            return humanized
        }
    }
}

// MARK: - Music Theory Engine

class MusicTheory {

    // MARK: - Chord Functions

    enum ChordFunction: String {
        case tonic = "I"
        case supertonic = "ii"
        case mediant = "iii"
        case subdominant = "IV"
        case dominant = "V"
        case submediant = "vi"
        case leadingTone = "vii°"
    }

    func chordFunction(_ chord: Chord, in key: Key) -> ChordFunction {
        let interval = (chord.root.rawValue - key.tonic.rawValue + 12) % 12

        switch interval {
        case 0:  return .tonic
        case 2:  return .supertonic
        case 4:  return .mediant
        case 5:  return .subdominant
        case 7:  return .dominant
        case 9:  return .submediant
        case 11: return .leadingTone
        default: return .tonic
        }
    }

    func chordFromFunction(_ function: ChordFunction, in key: Key) -> Chord {
        let intervals: [ChordFunction: Int] = [
            .tonic: 0, .supertonic: 2, .mediant: 4,
            .subdominant: 5, .dominant: 7, .submediant: 9, .leadingTone: 11
        ]

        let interval = intervals[function] ?? 0
        let root = PitchClass(rawValue: (key.tonic.rawValue + interval) % 12) ?? key.tonic

        // Determine chord type based on function and mode
        let type: ChordType
        if key.mode == .major {
            switch function {
            case .tonic, .subdominant, .dominant:
                type = .major
            case .supertonic, .mediant, .submediant:
                type = .minor
            case .leadingTone:
                type = .diminished
            }
        } else {
            // Minor key
            switch function {
            case .tonic, .subdominant:
                type = .minor
            case .mediant, .submediant, .leadingTone:
                type = .major
            case .dominant:
                type = .major // Often major V in minor
            case .supertonic:
                type = .diminished
            }
        }

        return Chord(root: root, type: type, confidence: 1.0)
    }

    // MARK: - Chord Progressions

    struct Progression {
        let functions: [ChordFunction]
        let confidence: Float
    }

    func commonProgressions(for style: MusicStyle) -> [Progression] {
        switch style {
        case .pop:
            return [
                Progression(functions: [.tonic, .dominant, .submediant, .subdominant], confidence: 0.9), // I-V-vi-IV
                Progression(functions: [.tonic, .submediant, .subdominant, .dominant], confidence: 0.85), // I-vi-IV-V
                Progression(functions: [.tonic, .subdominant, .dominant, .tonic], confidence: 0.8)        // I-IV-V-I
            ]

        case .jazz:
            return [
                Progression(functions: [.tonic, .submediant, .supertonic, .dominant], confidence: 0.9), // I-vi-ii-V
                Progression(functions: [.supertonic, .dominant, .tonic], confidence: 0.85)              // ii-V-I
            ]

        case .blues:
            return [
                Progression(functions: [.tonic, .tonic, .tonic, .tonic,
                                       .subdominant, .subdominant, .tonic, .tonic,
                                       .dominant, .subdominant, .tonic, .dominant], confidence: 0.95) // 12-bar blues
            ]

        case .edm, .rock:
            return [
                Progression(functions: [.tonic, .subdominant, .dominant, .subdominant], confidence: 0.8),
                Progression(functions: [.submediant, .subdominant, .tonic, .dominant], confidence: 0.75)
            ]
        }
    }

    func resolutionChords(for chord: Chord, in key: Key) -> [Chord] {
        let function = chordFunction(chord, in: key)

        switch function {
        case .dominant:
            // V resolves to I
            return [chordFromFunction(.tonic, in: key)]

        case .subdominant:
            // IV resolves to I or V
            return [
                chordFromFunction(.tonic, in: key),
                chordFromFunction(.dominant, in: key)
            ]

        case .supertonic:
            // ii resolves to V
            return [chordFromFunction(.dominant, in: key)]

        default:
            // Default: resolve to tonic
            return [chordFromFunction(.tonic, in: key)]
        }
    }
}

// MARK: - Supporting Types

struct ChordSuggestion: Identifiable {
    let id = UUID()
    let chord: Chord
    let confidence: Float
    let reason: String
}

struct Note: Identifiable {
    let id = UUID()
    var pitch: UInt8           // MIDI note number
    var velocity: UInt8        // 0-127
    var startTime: Double      // Beats
    var duration: Double       // Beats
}

struct DrumHit: Identifiable {
    let id = UUID()
    let instrument: DrumInstrument
    let time: Double
    let velocity: UInt8

    enum DrumInstrument {
        case kick, snare, hiHat, crash, tom, ride
    }
}

enum MusicStyle: String {
    case pop, jazz, blues, rock, edm, classical, hiphop
}

enum MelodyStyle {
    case chordTones      // Simple, harmonic
    case scalic          // More melodic movement
    case chromatic       // Complex, tension/release
}

enum BasslineStyle {
    case roots           // Simple root notes
    case rootFifth       // Root-fifth pattern
    case walking         // Walking bass
    case arpeggio        // Arpeggiated chord tones
}

enum DrumStyle {
    case fourOnFloor     // Electronic/Dance
    case hiphop          // Hip-hop
    case dnb             // Drum & Bass
}
