import Foundation
import Combine

/// WorldMusicBridge - Swift interface to C++ WorldMusicDatabase
///
/// Provides access to 42 global music styles with:
/// - Chord progressions
/// - Scales/modes
/// - Tempo ranges
/// - Rhythmic feel
/// - Typical instruments
/// - Composition rules
///
/// This bridge recreates the WorldMusicDatabase.cpp data in Swift
/// for native iOS integration until full C++ bridging is implemented.
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class WorldMusicBridge {

    // MARK: - Singleton

    static let shared = WorldMusicBridge()

    // MARK: - Observable State

    var availableStyles: [MusicStyle] = []
    var currentStyle: MusicStyle?

    // MARK: - Types

    struct MusicStyle: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let category: StyleCategory
        let chordProgressions: [ChordProgression]
        let scales: [String]
        let tempoRange: ClosedRange<Int>
        let rhythmicFeel: RhythmicFeel
        let typicalInstruments: [String]
        let melodicContour: String
        let compositionRules: CompositionRules

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: MusicStyle, rhs: MusicStyle) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum StyleCategory: String, CaseIterable {
        case modern = "Modern"
        case electronic = "Electronic"
        case classical = "Classical"
        case jazz = "Jazz"
        case latin = "Latin"
        case african = "African"
        case caribbean = "Caribbean"
        case asian = "Asian"
        case middleEastern = "Middle Eastern"
        case europeanFolk = "European Folk"
        case other = "Other"
    }

    struct ChordProgression {
        let name: String
        let numerals: [String]  // Roman numeral notation
        let description: String
    }

    enum RhythmicFeel: String {
        case straight = "Straight"
        case swing = "Swing"
        case shuffle = "Shuffle"
        case triplet = "Triplet"
        case compound = "Compound"
        case polyrhythmic = "Polyrhythmic"
        case rubato = "Rubato"
    }

    struct CompositionRules {
        let chromaticism: Float     // 0-1
        let dissonance: Float       // 0-1
        let complexity: Float       // 0-1
        let syncopation: Float      // 0-1
        let improvisation: Float    // 0-1
    }

    // MARK: - Initialization

    private init() {
        loadMusicStyles()
        #if DEBUG
        debugLog("✅ WorldMusicBridge: Loaded \(availableStyles.count) music styles")
        #endif
    }

    // MARK: - Load Music Styles (Mirror of WorldMusicDatabase.cpp)

    private func loadMusicStyles() {
        availableStyles = [
            // === MODERN (7 styles) ===
            MusicStyle(
                name: "Pop",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Pop Progression", numerals: ["I", "V", "vi", "IV"], description: "The most common pop progression"),
                    ChordProgression(name: "50s Progression", numerals: ["I", "vi", "IV", "V"], description: "Classic doo-wop style")
                ],
                scales: ["Major", "Mixolydian"],
                tempoRange: 100...130,
                rhythmicFeel: .straight,
                typicalInstruments: ["Piano", "Guitar", "Bass", "Drums", "Synth", "Voice"],
                melodicContour: "Stepwise with occasional leaps",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.3, syncopation: 0.3, improvisation: 0.1)
            ),

            MusicStyle(
                name: "Rock",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Power Chord", numerals: ["I", "IV", "V"], description: "Basic rock"),
                    ChordProgression(name: "Blues Rock", numerals: ["I", "I", "IV", "I", "V", "IV", "I", "V"], description: "12-bar blues")
                ],
                scales: ["Minor Pentatonic", "Blues Scale", "Mixolydian"],
                tempoRange: 110...140,
                rhythmicFeel: .straight,
                typicalInstruments: ["Electric Guitar", "Bass", "Drums", "Voice"],
                melodicContour: "Pentatonic riffs with bends",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.3, complexity: 0.4, syncopation: 0.4, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Hip-Hop",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Trap", numerals: ["i", "VI", "III", "VII"], description: "Minor key trap"),
                    ChordProgression(name: "Boom Bap", numerals: ["i", "iv", "i", "v"], description: "Classic hip-hop")
                ],
                scales: ["Minor", "Phrygian Dominant"],
                tempoRange: 70...90,
                rhythmicFeel: .swing,
                typicalInstruments: ["808 Drums", "Synth", "Sampler", "Voice"],
                melodicContour: "Short melodic hooks, repetitive",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.2, complexity: 0.3, syncopation: 0.8, improvisation: 0.7)
            ),

            MusicStyle(
                name: "R&B",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Neo-Soul", numerals: ["IVmaj7", "IIIm7", "VIm7", "V7"], description: "Smooth R&B"),
                    ChordProgression(name: "Classic R&B", numerals: ["I", "vi", "ii", "V"], description: "60s R&B")
                ],
                scales: ["Major", "Dorian", "Mixolydian"],
                tempoRange: 60...80,
                rhythmicFeel: .swing,
                typicalInstruments: ["Piano", "Rhodes", "Bass", "Drums", "Voice", "Strings"],
                melodicContour: "Melismatic, soulful runs",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.2, complexity: 0.5, syncopation: 0.6, improvisation: 0.6)
            ),

            MusicStyle(
                name: "Soul",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Motown", numerals: ["I", "I", "IV", "I", "V", "IV", "I", "V"], description: "Classic Motown"),
                ],
                scales: ["Major", "Minor Pentatonic"],
                tempoRange: 90...120,
                rhythmicFeel: .swing,
                typicalInstruments: ["Piano", "Organ", "Guitar", "Bass", "Drums", "Horns", "Voice"],
                melodicContour: "Gospel-influenced melisma",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.2, complexity: 0.4, syncopation: 0.5, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Funk",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "One Chord Funk", numerals: ["I7"], description: "James Brown style"),
                    ChordProgression(name: "Funky Vamp", numerals: ["i7", "IV7"], description: "Two-chord funk")
                ],
                scales: ["Mixolydian", "Dorian", "Minor Pentatonic"],
                tempoRange: 100...130,
                rhythmicFeel: .swing,
                typicalInstruments: ["Electric Guitar", "Bass", "Drums", "Horns", "Clavinet", "Voice"],
                melodicContour: "Syncopated, rhythmic emphasis",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.3, complexity: 0.5, syncopation: 0.9, improvisation: 0.7)
            ),

            MusicStyle(
                name: "Disco",
                category: .modern,
                chordProgressions: [
                    ChordProgression(name: "Disco Octaves", numerals: ["i", "VII", "VI", "VII"], description: "Classic disco"),
                ],
                scales: ["Minor", "Mixolydian"],
                tempoRange: 110...130,
                rhythmicFeel: .straight,
                typicalInstruments: ["Strings", "Bass", "Drums", "Piano", "Synth", "Voice"],
                melodicContour: "Four-on-the-floor, string stabs",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.1, complexity: 0.3, syncopation: 0.4, improvisation: 0.2)
            ),

            // === ELECTRONIC (7 styles) ===
            MusicStyle(
                name: "House",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Chicago House", numerals: ["i", "VI", "III", "VII"], description: "Classic house"),
                ],
                scales: ["Minor", "Dorian"],
                tempoRange: 118...130,
                rhythmicFeel: .straight,
                typicalInstruments: ["TR-909", "TR-808", "Synth Pads", "Bass Synth", "Piano Stabs"],
                melodicContour: "Four-on-the-floor, filtered sweeps",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.3, syncopation: 0.3, improvisation: 0.2)
            ),

            MusicStyle(
                name: "Techno",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Minimal", numerals: ["i"], description: "Single chord drone"),
                ],
                scales: ["Minor", "Phrygian"],
                tempoRange: 130...150,
                rhythmicFeel: .straight,
                typicalInstruments: ["TR-909", "Roland TB-303", "Modular Synth", "FM Synth"],
                melodicContour: "Hypnotic, repetitive, evolving",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.4, complexity: 0.5, syncopation: 0.3, improvisation: 0.3)
            ),

            MusicStyle(
                name: "Trance",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Anthem", numerals: ["i", "VI", "III", "VII"], description: "Epic trance"),
                ],
                scales: ["Minor", "Harmonic Minor"],
                tempoRange: 135...145,
                rhythmicFeel: .straight,
                typicalInstruments: ["Supersaw Synth", "Pluck Synth", "TR-909", "Pads"],
                melodicContour: "Arpeggiated, building, euphoric",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.2, complexity: 0.4, syncopation: 0.2, improvisation: 0.1)
            ),

            MusicStyle(
                name: "Dubstep",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Wobble", numerals: ["i", "VI"], description: "Half-time bass"),
                ],
                scales: ["Minor", "Phrygian"],
                tempoRange: 138...142,
                rhythmicFeel: .straight,
                typicalInstruments: ["Wobble Bass", "Sub Bass", "Reese Bass", "Breakbeats"],
                melodicContour: "Minimalist melody, heavy bass focus",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.5, complexity: 0.5, syncopation: 0.7, improvisation: 0.3)
            ),

            MusicStyle(
                name: "Drum & Bass",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Liquid", numerals: ["i", "VI", "iv", "VII"], description: "Melodic DnB"),
                ],
                scales: ["Minor", "Dorian"],
                tempoRange: 170...180,
                rhythmicFeel: .swing,
                typicalInstruments: ["Amen Break", "Sub Bass", "Reese Bass", "Pads"],
                melodicContour: "Fast breakbeats, rolling bass",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.3, complexity: 0.6, syncopation: 0.8, improvisation: 0.4)
            ),

            MusicStyle(
                name: "Ambient",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Drone", numerals: ["Imaj7"], description: "Sustained harmonic field"),
                ],
                scales: ["Major", "Lydian", "Whole Tone"],
                tempoRange: 60...80,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Pad Synth", "Granular Synth", "Field Recordings", "Reverb"],
                melodicContour: "Slowly evolving textures",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.2, complexity: 0.4, syncopation: 0.0, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Synthwave",
                category: .electronic,
                chordProgressions: [
                    ChordProgression(name: "Retro", numerals: ["I", "vi", "IV", "V"], description: "80s nostalgia"),
                ],
                scales: ["Major", "Mixolydian"],
                tempoRange: 100...120,
                rhythmicFeel: .straight,
                typicalInstruments: ["Analog Synth", "LinnDrum", "Gated Reverb Snare", "Arpeggios"],
                melodicContour: "Nostalgic 80s melodies",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.1, complexity: 0.4, syncopation: 0.3, improvisation: 0.2)
            ),

            // === CLASSICAL (6 styles) ===
            MusicStyle(
                name: "Baroque",
                category: .classical,
                chordProgressions: [
                    ChordProgression(name: "Circle of Fifths", numerals: ["I", "IV", "vii°", "iii", "vi", "ii", "V", "I"], description: "Bach style"),
                ],
                scales: ["Major", "Minor", "Modes"],
                tempoRange: 60...120,
                rhythmicFeel: .straight,
                typicalInstruments: ["Harpsichord", "Violin", "Viola", "Cello", "Flute", "Organ"],
                melodicContour: "Ornate, contrapuntal",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.2, complexity: 0.8, syncopation: 0.2, improvisation: 0.3)
            ),

            MusicStyle(
                name: "Classical",
                category: .classical,
                chordProgressions: [
                    ChordProgression(name: "Sonata Form", numerals: ["I", "V", "vi", "IV", "ii", "V", "I"], description: "Mozart/Haydn style"),
                ],
                scales: ["Major", "Minor"],
                tempoRange: 60...160,
                rhythmicFeel: .straight,
                typicalInstruments: ["Piano", "Violin", "Viola", "Cello", "Flute", "Clarinet", "Horns"],
                melodicContour: "Balanced phrases, clear structure",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.2, complexity: 0.7, syncopation: 0.1, improvisation: 0.1)
            ),

            MusicStyle(
                name: "Romantic",
                category: .classical,
                chordProgressions: [
                    ChordProgression(name: "Chromatic", numerals: ["I", "V/vi", "vi", "V/V", "V", "I"], description: "Chopin/Liszt style"),
                ],
                scales: ["Major", "Minor", "Chromatic"],
                tempoRange: 40...180,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Piano", "Orchestra", "Voice", "Harp"],
                melodicContour: "Expressive, virtuosic, emotional",
                compositionRules: CompositionRules(chromaticism: 0.7, dissonance: 0.4, complexity: 0.8, syncopation: 0.2, improvisation: 0.3)
            ),

            MusicStyle(
                name: "Impressionist",
                category: .classical,
                chordProgressions: [
                    ChordProgression(name: "Parallel", numerals: ["Imaj9", "IImaj9", "IIImaj9"], description: "Debussy style"),
                ],
                scales: ["Whole Tone", "Pentatonic", "Modes"],
                tempoRange: 50...80,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Piano", "Harp", "Flute", "Strings", "Celeste"],
                melodicContour: "Floating, coloristic, atmospheric",
                compositionRules: CompositionRules(chromaticism: 0.6, dissonance: 0.5, complexity: 0.7, syncopation: 0.3, improvisation: 0.2)
            ),

            // === JAZZ (8 styles) ===
            MusicStyle(
                name: "Bebop",
                category: .jazz,
                chordProgressions: [
                    ChordProgression(name: "ii-V-I", numerals: ["iim7", "V7", "Imaj7"], description: "The jazz standard"),
                    ChordProgression(name: "Rhythm Changes", numerals: ["I", "vi", "ii", "V"], description: "I Got Rhythm"),
                ],
                scales: ["Bebop Dominant", "Bebop Major", "Altered"],
                tempoRange: 180...300,
                rhythmicFeel: .swing,
                typicalInstruments: ["Saxophone", "Trumpet", "Piano", "Bass", "Drums"],
                melodicContour: "Fast, chromatic, virtuosic",
                compositionRules: CompositionRules(chromaticism: 0.8, dissonance: 0.6, complexity: 0.9, syncopation: 0.7, improvisation: 0.95)
            ),

            MusicStyle(
                name: "Cool Jazz",
                category: .jazz,
                chordProgressions: [
                    ChordProgression(name: "Modal", numerals: ["Dm7", "Em7/D"], description: "So What"),
                ],
                scales: ["Dorian", "Lydian", "Mixolydian"],
                tempoRange: 100...140,
                rhythmicFeel: .swing,
                typicalInstruments: ["Trumpet", "Flugelhorn", "Piano", "Bass", "Brushes"],
                melodicContour: "Relaxed, smooth, spacious",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.3, complexity: 0.6, syncopation: 0.4, improvisation: 0.8)
            ),

            MusicStyle(
                name: "Modal Jazz",
                category: .jazz,
                chordProgressions: [
                    ChordProgression(name: "Coltrane Changes", numerals: ["Imaj7", "bIIImaj7", "Vmaj7"], description: "Giant Steps"),
                ],
                scales: ["Dorian", "Mixolydian", "Lydian", "Locrian"],
                tempoRange: 120...200,
                rhythmicFeel: .swing,
                typicalInstruments: ["Saxophone", "Piano", "Bass", "Drums"],
                melodicContour: "Scale-based exploration",
                compositionRules: CompositionRules(chromaticism: 0.5, dissonance: 0.5, complexity: 0.8, syncopation: 0.5, improvisation: 0.9)
            ),

            MusicStyle(
                name: "Fusion",
                category: .jazz,
                chordProgressions: [
                    ChordProgression(name: "Extended", numerals: ["Imaj9#11", "IVmaj13", "V7alt"], description: "Weather Report style"),
                ],
                scales: ["Lydian", "Altered", "Diminished"],
                tempoRange: 100...180,
                rhythmicFeel: .straight,
                typicalInstruments: ["Electric Guitar", "Synth", "Bass", "Drums", "Saxophone"],
                melodicContour: "Complex, electric, hybrid",
                compositionRules: CompositionRules(chromaticism: 0.7, dissonance: 0.6, complexity: 0.9, syncopation: 0.7, improvisation: 0.8)
            ),

            // === LATIN (7 styles) ===
            MusicStyle(
                name: "Salsa",
                category: .latin,
                chordProgressions: [
                    ChordProgression(name: "Montuno", numerals: ["I", "IV", "V", "I"], description: "Cuban montuno"),
                ],
                scales: ["Major", "Mixolydian"],
                tempoRange: 160...210,
                rhythmicFeel: .straight,
                typicalInstruments: ["Piano", "Bass", "Congas", "Timbales", "Horns", "Voice"],
                melodicContour: "Clave-driven, call-and-response",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.2, complexity: 0.6, syncopation: 0.9, improvisation: 0.7)
            ),

            MusicStyle(
                name: "Bossa Nova",
                category: .latin,
                chordProgressions: [
                    ChordProgression(name: "Jobim", numerals: ["Imaj7", "#IVm7b5", "VII7", "IIIm7"], description: "Girl from Ipanema"),
                ],
                scales: ["Major", "Lydian"],
                tempoRange: 120...140,
                rhythmicFeel: .swing,
                typicalInstruments: ["Nylon Guitar", "Piano", "Bass", "Light Percussion", "Voice"],
                melodicContour: "Smooth, sophisticated, understated",
                compositionRules: CompositionRules(chromaticism: 0.5, dissonance: 0.3, complexity: 0.6, syncopation: 0.5, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Tango",
                category: .latin,
                chordProgressions: [
                    ChordProgression(name: "Habanera", numerals: ["i", "V7", "i"], description: "Tango rhythm"),
                ],
                scales: ["Harmonic Minor", "Phrygian Dominant"],
                tempoRange: 60...70,
                rhythmicFeel: .straight,
                typicalInstruments: ["Bandoneon", "Violin", "Piano", "Bass", "Guitar"],
                melodicContour: "Dramatic, passionate, staccato",
                compositionRules: CompositionRules(chromaticism: 0.5, dissonance: 0.4, complexity: 0.6, syncopation: 0.4, improvisation: 0.4)
            ),

            MusicStyle(
                name: "Reggaeton",
                category: .latin,
                chordProgressions: [
                    ChordProgression(name: "Dembow", numerals: ["i", "VI", "III", "VII"], description: "Reggaeton standard"),
                ],
                scales: ["Minor"],
                tempoRange: 85...95,
                rhythmicFeel: .straight,
                typicalInstruments: ["TR-808", "Synth", "Voice"],
                melodicContour: "Dembow rhythm, repetitive hooks",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.2, syncopation: 0.6, improvisation: 0.3)
            ),

            MusicStyle(
                name: "Samba",
                category: .latin,
                chordProgressions: [
                    ChordProgression(name: "Samba", numerals: ["I", "vi", "ii", "V"], description: "Brazilian samba"),
                ],
                scales: ["Major", "Mixolydian"],
                tempoRange: 100...130,
                rhythmicFeel: .swing,
                typicalInstruments: ["Surdo", "Tamborim", "Cuica", "Cavaquinho", "Voice"],
                melodicContour: "Syncopated, festive, polyrhythmic",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.1, complexity: 0.5, syncopation: 0.9, improvisation: 0.5)
            ),

            // === AFRICAN (4 styles) ===
            MusicStyle(
                name: "Afrobeat",
                category: .african,
                chordProgressions: [
                    ChordProgression(name: "Fela Kuti", numerals: ["i7", "IV7"], description: "Extended vamp"),
                ],
                scales: ["Dorian", "Minor Pentatonic"],
                tempoRange: 100...130,
                rhythmicFeel: .polyrhythmic,
                typicalInstruments: ["Horns", "Guitar", "Bass", "Drums", "Congas", "Shekere"],
                melodicContour: "Repetitive, hypnotic, layered",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.2, complexity: 0.7, syncopation: 0.9, improvisation: 0.6)
            ),

            MusicStyle(
                name: "Highlife",
                category: .african,
                chordProgressions: [
                    ChordProgression(name: "Highlife", numerals: ["I", "IV", "V", "I"], description: "West African dance"),
                ],
                scales: ["Major", "Pentatonic"],
                tempoRange: 110...130,
                rhythmicFeel: .swing,
                typicalInstruments: ["Guitar", "Horns", "Bass", "Drums", "Voice"],
                melodicContour: "Joyful, call-and-response",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.4, syncopation: 0.6, improvisation: 0.5)
            ),

            // === ASIAN (6 styles) ===
            MusicStyle(
                name: "Indian Classical",
                category: .asian,
                chordProgressions: [
                    ChordProgression(name: "Drone", numerals: ["I"], description: "Tanpura drone"),
                ],
                scales: ["Raga (72 Melakartas)"],
                tempoRange: 30...200,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Sitar", "Tabla", "Tanpura", "Sarod", "Bansuri"],
                melodicContour: "Raga-based, ornamental, microtonal",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.2, complexity: 0.9, syncopation: 0.5, improvisation: 0.95)
            ),

            MusicStyle(
                name: "Chinese Traditional",
                category: .asian,
                chordProgressions: [
                    ChordProgression(name: "Pentatonic", numerals: ["I", "V"], description: "Gong and Zhi"),
                ],
                scales: ["Pentatonic (Gong, Shang, Jue, Zhi, Yu)"],
                tempoRange: 40...100,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Erhu", "Pipa", "Guzheng", "Dizi", "Yangqin"],
                melodicContour: "Pentatonic, ornamental, flowing",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.6, syncopation: 0.2, improvisation: 0.4)
            ),

            MusicStyle(
                name: "Japanese Traditional",
                category: .asian,
                chordProgressions: [
                    ChordProgression(name: "In Scale", numerals: ["I", "bII", "IV", "V"], description: "Japanese mode"),
                ],
                scales: ["In (Miyako-bushi)", "Yo", "Hirajoshi"],
                tempoRange: 40...80,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Koto", "Shakuhachi", "Shamisen", "Taiko"],
                melodicContour: "Sparse, contemplative, breath-like",
                compositionRules: CompositionRules(chromaticism: 0.2, dissonance: 0.3, complexity: 0.6, syncopation: 0.1, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Gamelan",
                category: .asian,
                chordProgressions: [
                    ChordProgression(name: "Colotomic", numerals: ["I"], description: "Interlocking patterns"),
                ],
                scales: ["Slendro (5-tone)", "Pelog (7-tone)"],
                tempoRange: 40...120,
                rhythmicFeel: .polyrhythmic,
                typicalInstruments: ["Gongs", "Metallophones", "Drums", "Flute", "Voice"],
                melodicContour: "Interlocking, shimmering, cyclical",
                compositionRules: CompositionRules(chromaticism: 0.0, dissonance: 0.3, complexity: 0.8, syncopation: 0.5, improvisation: 0.3)
            ),

            MusicStyle(
                name: "K-Pop",
                category: .asian,
                chordProgressions: [
                    ChordProgression(name: "K-Pop", numerals: ["vi", "IV", "I", "V"], description: "Modern K-Pop"),
                ],
                scales: ["Major", "Minor"],
                tempoRange: 100...140,
                rhythmicFeel: .straight,
                typicalInstruments: ["Synth", "808 Drums", "Guitar", "Voice"],
                melodicContour: "Catchy hooks, key changes",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.2, complexity: 0.5, syncopation: 0.5, improvisation: 0.1)
            ),

            // === MIDDLE EASTERN (3 styles) ===
            MusicStyle(
                name: "Arabic",
                category: .middleEastern,
                chordProgressions: [
                    ChordProgression(name: "Maqam", numerals: ["I"], description: "Modal drone"),
                ],
                scales: ["Maqam (Bayati, Hijaz, Rast, Nahawand)"],
                tempoRange: 60...120,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Oud", "Ney", "Qanun", "Tabla", "Riq", "Voice"],
                melodicContour: "Maqam-based, quarter-tones, ornamented",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.2, complexity: 0.7, syncopation: 0.5, improvisation: 0.8)
            ),

            MusicStyle(
                name: "Persian",
                category: .middleEastern,
                chordProgressions: [
                    ChordProgression(name: "Dastgah", numerals: ["I"], description: "Modal system"),
                ],
                scales: ["Dastgah (Shur, Segah, Chahargah)"],
                tempoRange: 40...100,
                rhythmicFeel: .rubato,
                typicalInstruments: ["Tar", "Setar", "Santur", "Kamancheh", "Tombak"],
                melodicContour: "Poetic, yearning, microtonal",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.2, complexity: 0.8, syncopation: 0.3, improvisation: 0.9)
            ),

            MusicStyle(
                name: "Turkish",
                category: .middleEastern,
                chordProgressions: [
                    ChordProgression(name: "Makam", numerals: ["I"], description: "Turkish modes"),
                ],
                scales: ["Makam (Hicaz, Ussak, Nihavend)"],
                tempoRange: 60...140,
                rhythmicFeel: .compound,
                typicalInstruments: ["Saz", "Ney", "Kanun", "Kemençe", "Darbuka"],
                melodicContour: "Makam-based, 9/8 rhythms, ornamented",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.2, complexity: 0.7, syncopation: 0.6, improvisation: 0.7)
            ),

            // === EUROPEAN FOLK (5 styles) ===
            MusicStyle(
                name: "Celtic",
                category: .europeanFolk,
                chordProgressions: [
                    ChordProgression(name: "Celtic", numerals: ["I", "VII", "VI", "VII"], description: "Irish/Scottish"),
                ],
                scales: ["Mixolydian", "Dorian", "Aeolian"],
                tempoRange: 100...180,
                rhythmicFeel: .compound,
                typicalInstruments: ["Fiddle", "Tin Whistle", "Bodhrán", "Guitar", "Harp", "Uilleann Pipes"],
                melodicContour: "Modal, ornamented, dance rhythms",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.5, syncopation: 0.4, improvisation: 0.5)
            ),

            MusicStyle(
                name: "Flamenco",
                category: .europeanFolk,
                chordProgressions: [
                    ChordProgression(name: "Andalusian Cadence", numerals: ["i", "VII", "VI", "V"], description: "Flamenco descent"),
                ],
                scales: ["Phrygian Dominant", "Phrygian"],
                tempoRange: 60...200,
                rhythmicFeel: .compound,
                typicalInstruments: ["Spanish Guitar", "Cajón", "Palmas", "Voice"],
                melodicContour: "Passionate, ornamental, rhythmic complexity",
                compositionRules: CompositionRules(chromaticism: 0.3, dissonance: 0.3, complexity: 0.8, syncopation: 0.8, improvisation: 0.8)
            ),

            // === OTHER (6 styles) ===
            MusicStyle(
                name: "Gospel",
                category: .other,
                chordProgressions: [
                    ChordProgression(name: "Gospel Turnaround", numerals: ["I", "I7", "IV", "IVm", "I", "V7", "I"], description: "Church gospel"),
                ],
                scales: ["Major", "Blues Scale"],
                tempoRange: 70...140,
                rhythmicFeel: .swing,
                typicalInstruments: ["Piano", "Organ", "Bass", "Drums", "Choir"],
                melodicContour: "Melismatic, call-and-response, emotional",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.2, complexity: 0.5, syncopation: 0.5, improvisation: 0.6)
            ),

            MusicStyle(
                name: "Metal",
                category: .other,
                chordProgressions: [
                    ChordProgression(name: "Power Metal", numerals: ["i", "bVI", "bVII", "i"], description: "Heavy metal"),
                ],
                scales: ["Natural Minor", "Phrygian", "Harmonic Minor"],
                tempoRange: 120...220,
                rhythmicFeel: .straight,
                typicalInstruments: ["Electric Guitar", "Bass", "Double Bass Drums", "Voice"],
                melodicContour: "Palm-muted riffs, shred solos",
                compositionRules: CompositionRules(chromaticism: 0.4, dissonance: 0.5, complexity: 0.7, syncopation: 0.6, improvisation: 0.6)
            ),

            MusicStyle(
                name: "Reggae",
                category: .caribbean,
                chordProgressions: [
                    ChordProgression(name: "One Drop", numerals: ["I", "IV", "V", "I"], description: "Roots reggae"),
                ],
                scales: ["Major", "Minor"],
                tempoRange: 65...80,
                rhythmicFeel: .swing,
                typicalInstruments: ["Guitar", "Bass", "Drums", "Organ", "Horns", "Voice"],
                melodicContour: "Offbeat skank, melodic bass",
                compositionRules: CompositionRules(chromaticism: 0.1, dissonance: 0.1, complexity: 0.3, syncopation: 0.7, improvisation: 0.4)
            ),
        ]

        // Sort by category
        availableStyles.sort { $0.category.rawValue < $1.category.rawValue }
    }

    // MARK: - Query Functions

    func getStyles(byCategory category: StyleCategory) -> [MusicStyle] {
        return availableStyles.filter { $0.category == category }
    }

    func getStyles(byTempo bpm: Int) -> [MusicStyle] {
        return availableStyles.filter { $0.tempoRange.contains(bpm) }
    }

    func getInstrumentsFor(style: MusicStyle) -> [String] {
        return style.typicalInstruments
    }

    func suggestChordProgression(for style: MusicStyle) -> ChordProgression? {
        return style.chordProgressions.randomElement()
    }

    // MARK: - Bio-Reactive Style Selection

    func suggestStyle(coherence: Float, energy: Float, heartRate: Float) -> MusicStyle? {
        // High coherence + low energy → Ambient, Classical
        if coherence > 0.7 && energy < 0.3 {
            return availableStyles.first { $0.category == .electronic && $0.name == "Ambient" }
        }

        // High energy + high heart rate → Techno, Metal
        if energy > 0.7 && heartRate > 100 {
            return availableStyles.first { $0.category == .electronic && $0.name == "Techno" }
        }

        // Balanced → Jazz, R&B
        if coherence > 0.4 && coherence < 0.7 {
            return availableStyles.first { $0.category == .jazz }
        }

        // Low coherence → Hip-Hop, Dubstep
        if coherence < 0.3 {
            return availableStyles.first { $0.name == "Hip-Hop" }
        }

        // Default → Pop
        return availableStyles.first { $0.name == "Pop" }
    }
}

// MARK: - Backward Compatibility

/// Backward compatibility for existing code using @StateObject/@ObservedObject
extension WorldMusicBridge: ObservableObject { }
