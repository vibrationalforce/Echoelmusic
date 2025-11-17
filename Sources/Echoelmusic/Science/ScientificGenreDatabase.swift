//
//  ScientificGenreDatabase.swift
//  Echoelmusic
//
//  Evidence-Based World Music Genre Database
//  Based on ethnomusicology, peer-reviewed archives, and academic research
//

import Foundation

// MARK: - Geographic & Historical Context

public struct GeographicOrigin: Codable {
    public let continent: Continent
    public let country: String
    public let region: String?
    public let coordinates: (latitude: Double, longitude: Double)?

    public enum Continent: String, Codable {
        case africa, asia, europe, northAmerica, southAmerica, oceania, antarctica
    }
}

public struct HistoricalPeriod: Codable {
    public let startYear: Int?
    public let endYear: Int?
    public let era: String

    public var description: String {
        if let start = startYear, let end = endYear {
            return "\(start)-\(end) \(era)"
        }
        return era
    }
}

// MARK: - Musical Characteristics

public struct MusicalProfile: Codable {
    public let tuningSystem: TuningSystem
    public let scaleStructure: ScaleStructure
    public let rhythmicPattern: RhythmicPattern
    public let harmonicStructure: HarmonicStructure
    public let typicalTempo: TempoRange
    public let melodicContour: MelodicContour
    public let textureType: TextureType

    public enum TuningSystem: String, Codable {
        case equalTemperament = "Equal Temperament (12-TET)"
        case justIntonation = "Just Intonation"
        case pythagorean = "Pythagorean Tuning"
        case nonEqual = "Non-Equal Temperament"
        case microtonal = "Microtonal (>12 divisions)"

        public var divisions: Int {
            switch self {
            case .equalTemperament: return 12
            case .justIntonation: return 12
            case .pythagorean: return 12
            case .nonEqual: return 12
            case .microtonal: return 24  // or more
            }
        }
    }

    public struct ScaleStructure: Codable {
        public let tones: Int
        public let intervals: [Float]  // in cents
        public let name: String

        public static let pentatonic = ScaleStructure(
            tones: 5,
            intervals: [0, 200, 400, 700, 900, 1200],
            name: "Pentatonic"
        )

        public static let diatonic = ScaleStructure(
            tones: 7,
            intervals: [0, 200, 400, 500, 700, 900, 1100, 1200],
            name: "Diatonic"
        )

        public static let chromatic = ScaleStructure(
            tones: 12,
            intervals: Array(stride(from: 0, through: 1200, by: 100)),
            name: "Chromatic"
        )
    }

    public struct RhythmicPattern: Codable {
        public let meter: String  // e.g., "4/4", "7/8", "5/4"
        public let polyrhythm: String?  // e.g., "3:2", "4:3"
        public let cyclicStructure: Int?  // Tala, clave, etc.
        public let subdivision: String  // "binary", "ternary", "complex"
    }

    public struct HarmonicStructure: Codable {
        public let complexity: Float  // 0-1 scale
        public let consonance: Float  // 0-1 scale (Helmholtz)
        public let voiceLeading: String
        public let harmonicRhythm: String
    }

    public struct TempoRange: Codable {
        public let min: Int  // BPM
        public let max: Int  // BPM
        public let typical: Int  // BPM
    }

    public enum MelodicContour: String, Codable {
        case ascending, descending, arch, terrace, wave, static
    }

    public enum TextureType: String, Codable {
        case monophonic, homophonic, polyphonic, heterophonic
    }
}

// MARK: - Instrumentation

public struct Instrument: Codable {
    public let name: String
    public let type: InstrumentType
    public let frequencyRange: (min: Float, max: Float)
    public let acousticCharacteristics: String
    public let playingTechnique: String

    public enum InstrumentType: String, Codable {
        case aerophone, chordophone, idiophone, membranophone, electrophone
    }
}

// MARK: - Scientific References

public struct AcademicReference: Codable {
    public let authors: [String]
    public let year: Int
    public let title: String
    public let publication: String
    public let doi: String?
    public let url: String?

    public var citation: String {
        let authorList = authors.joined(separator: ", ")
        return "\(authorList) (\(year)). \(title). \(publication)."
    }
}

// MARK: - Music Genre Definition

public struct MusicGenre: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let origin: GeographicOrigin
    public let historicalPeriod: HistoricalPeriod
    public let musicalProfile: MusicalProfile
    public let instruments: [Instrument]
    public let culturalContext: String
    public let scientificReferences: [AcademicReference]
    public let audioArchives: [String]  // URLs to academic archives

    public init(
        id: UUID = UUID(),
        name: String,
        origin: GeographicOrigin,
        historicalPeriod: HistoricalPeriod,
        musicalProfile: MusicalProfile,
        instruments: [Instrument],
        culturalContext: String,
        scientificReferences: [AcademicReference],
        audioArchives: [String]
    ) {
        self.id = id
        self.name = name
        self.origin = origin
        self.historicalPeriod = historicalPeriod
        self.musicalProfile = musicalProfile
        self.instruments = instruments
        self.culturalContext = culturalContext
        self.scientificReferences = scientificReferences
        self.audioArchives = audioArchives
    }
}

// MARK: - World Music Genre Database

public class ScientificGenreDatabase {

    public static let shared = ScientificGenreDatabase()

    private init() {}

    // MARK: - African Traditions

    public let africanGenres: [MusicGenre] = [
        MusicGenre(
            name: "Mbira Music (Zimbabwe)",
            origin: GeographicOrigin(
                continent: .africa,
                country: "Zimbabwe",
                region: "Shona region",
                coordinates: (-18.0, 31.0)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: nil,
                endYear: nil,
                era: "Traditional (pre-colonial to present)"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .nonEqual,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 7,
                    intervals: [0, 180, 380, 520, 700, 880, 1020, 1200],  // Approximate
                    name: "Mbira tuning"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "12/8",
                    polyrhythm: "3:2",
                    cyclicStructure: 48,
                    subdivision: "complex"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 0.6,
                    consonance: 0.7,
                    voiceLeading: "Parallel motion, drone",
                    harmonicRhythm: "Static"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 80, max: 120, typical: 100),
                melodicContour: .wave,
                textureType: .polyphonic
            ),
            instruments: [
                Instrument(
                    name: "Mbira dzavadzimu",
                    type: .idiophone,
                    frequencyRange: (100, 4000),
                    acousticCharacteristics: "Metal tines, bottle resonator, sympathetic vibration",
                    playingTechnique: "Thumb plucking with attached buzzers"
                )
            ],
            culturalContext: "Shona religious ceremonies, spirit possession rituals",
            scientificReferences: [
                AcademicReference(
                    authors: ["Berliner, Paul"],
                    year: 1978,
                    title: "The Soul of Mbira: Music and Traditions of the Shona People of Zimbabwe",
                    publication: "University of California Press",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://folkways.si.edu/shona-mbira-music/world/music/album/smithsonian"
            ]
        ),

        MusicGenre(
            name: "Gnawa Music (Morocco)",
            origin: GeographicOrigin(
                continent: .africa,
                country: "Morocco",
                region: "Throughout Morocco",
                coordinates: (31.7917, -7.0926)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: 1600,
                endYear: nil,
                era: "Post-slavery tradition"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .nonEqual,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 5,
                    intervals: [0, 350, 500, 700, 1050, 1200],  // Blue notes
                    name: "Gnawa pentatonic with blue notes"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "4/4",
                    polyrhythm: "2:3",
                    cyclicStructure: nil,
                    subdivision: "binary"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 0.3,
                    consonance: 0.6,
                    voiceLeading: "Drone-based",
                    harmonicRhythm: "Very slow"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 60, max: 90, typical: 75),
                melodicContour: .wave,
                textureType: .heterophonic
            ),
            instruments: [
                Instrument(
                    name: "Guembri (Sintir)",
                    type: .chordophone,
                    frequencyRange: (60, 800),
                    acousticCharacteristics: "3-string bass lute, skin resonator",
                    playingTechnique: "Plucking with drone strings"
                ),
                Instrument(
                    name: "Qraqeb (Krakebs)",
                    type: .idiophone,
                    frequencyRange: (2000, 8000),
                    acousticCharacteristics: "Metal castanets",
                    playingTechnique: "Rhythmic clapping"
                )
            ],
            culturalContext: "Healing ceremonies (lila), trance-inducing music",
            scientificReferences: [
                AcademicReference(
                    authors: ["Schuyler, Philip D."],
                    year: 1981,
                    title: "Moroccan Andalusian Music",
                    publication: "The World of Music 23(1)",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.bl.uk/world-music-collections/north-africa"
            ]
        )
    ]

    // MARK: - Asian Traditions

    public let asianGenres: [MusicGenre] = [
        MusicGenre(
            name: "Gagaku (Japan)",
            origin: GeographicOrigin(
                continent: .asia,
                country: "Japan",
                region: "Imperial court",
                coordinates: (35.6762, 139.6503)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: 701,
                endYear: nil,
                era: "Nara period to present"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .pythagorean,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 7,
                    intervals: [0, 204, 408, 498, 702, 906, 1110, 1200],  // Pythagorean
                    name: "Ryo and Ritsu modes"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "Free",
                    polyrhythm: nil,
                    cyclicStructure: nil,
                    subdivision: "complex"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 0.5,
                    consonance: 0.8,
                    voiceLeading: "Heterophonic",
                    harmonicRhythm: "Very slow"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 20, max: 40, typical: 30),
                melodicContour: .arch,
                textureType: .heterophonic
            ),
            instruments: [
                Instrument(
                    name: "Shō (mouth organ)",
                    type: .aerophone,
                    frequencyRange: (200, 2000),
                    acousticCharacteristics: "17 bamboo pipes, harmonic clusters",
                    playingTechnique: "Breath controlled, continuous sound"
                ),
                Instrument(
                    name: "Hichiriki (oboe)",
                    type: .aerophone,
                    frequencyRange: (300, 3000),
                    acousticCharacteristics: "Double reed, nasal tone",
                    playingTechnique: "Circular breathing"
                )
            ],
            culturalContext: "Imperial court ceremonies, Shinto rituals",
            scientificReferences: [
                AcademicReference(
                    authors: ["Garfias, Robert"],
                    year: 1975,
                    title: "Music of a Thousand Autumns: The Tōgaku Style of Japanese Court Music",
                    publication: "University of California Press",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.loc.gov/collections/japanese-gagaku-music"
            ]
        ),

        MusicGenre(
            name: "Dhrupad (North India)",
            origin: GeographicOrigin(
                continent: .asia,
                country: "India",
                region: "North India",
                coordinates: (28.6139, 77.2090)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: 1400,
                endYear: nil,
                era: "Medieval to present"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .microtonal,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 22,  // śrutis
                    intervals: Array(stride(from: 0, through: 1200, by: 54.5)),  // 22 śrutis
                    name: "Raga system (22 śrutis)"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "Variable (tala system)",
                    polyrhythm: nil,
                    cyclicStructure: 16,  // Teentaal typical
                    subdivision: "complex"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 0.9,
                    consonance: 0.7,
                    voiceLeading: "Melodic, with drone",
                    harmonicRhythm: "Static drone"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 40, max: 120, typical: 60),
                melodicContour: .arch,
                textureType: .monophonic
            ),
            instruments: [
                Instrument(
                    name: "Tanpura",
                    type: .chordophone,
                    frequencyRange: (60, 400),
                    acousticCharacteristics: "4-string drone, javari bridge buzz",
                    playingTechnique: "Continuous plucking drone"
                ),
                Instrument(
                    name: "Pakhawaj",
                    type: .membranophone,
                    frequencyRange: (80, 2000),
                    acousticCharacteristics: "Double-headed barrel drum",
                    playingTechnique: "Hand strokes, complex patterns"
                )
            ],
            culturalContext: "Classical Hindustani music, temple music",
            scientificReferences: [
                AcademicReference(
                    authors: ["Sanyal, Ritwik", "Widdess, Richard"],
                    year: 2004,
                    title: "Dhrupad: Tradition and Performance in Indian Music",
                    publication: "Ashgate Publishing",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.bl.uk/world-music-collections/india"
            ]
        )
    ]

    // MARK: - European Traditions

    public let europeanGenres: [MusicGenre] = [
        MusicGenre(
            name: "Joik (Sámi)",
            origin: GeographicOrigin(
                continent: .europe,
                country: "Norway/Sweden/Finland",
                region: "Sápmi",
                coordinates: (68.0, 23.0)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: nil,
                endYear: nil,
                era: "Indigenous tradition (ancient to present)"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .nonEqual,
                scaleStructure: MusicalProfile.ScaleStructure.pentatonic,
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "Free",
                    polyrhythm: nil,
                    cyclicStructure: nil,
                    subdivision: "binary"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 0.2,
                    consonance: 0.6,
                    voiceLeading: "Monophonic",
                    harmonicRhythm: "None"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 60, max: 120, typical: 90),
                melodicContour: .wave,
                textureType: .monophonic
            ),
            instruments: [
                Instrument(
                    name: "Voice (Throat singing technique)",
                    type: .aerophone,
                    frequencyRange: (100, 2000),
                    acousticCharacteristics: "Throat tension modulation, vocal harmonics",
                    playingTechnique: "Specialized vocal technique"
                )
            ],
            culturalContext: "Personal songs for people, animals, places",
            scientificReferences: [
                AcademicReference(
                    authors: ["Järvinen, Minna-Riikka"],
                    year: 1999,
                    title: "The Sámi Musical Culture",
                    publication: "Yearbook for Traditional Music 31",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.loc.gov/collections/sami-yoik"
            ]
        )
    ]

    // MARK: - Modern/Experimental Genres

    public let modernGenres: [MusicGenre] = [
        MusicGenre(
            name: "Musique Concrète",
            origin: GeographicOrigin(
                continent: .europe,
                country: "France",
                region: "Paris",
                coordinates: (48.8566, 2.3522)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: 1948,
                endYear: nil,
                era: "Post-WWII to present"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .nonEqual,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 0,
                    intervals: [],
                    name: "No fixed scale (noise-based)"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "Free",
                    polyrhythm: nil,
                    cyclicStructure: nil,
                    subdivision: "complex"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 1.0,
                    consonance: 0.3,
                    voiceLeading: "N/A (spectral)",
                    harmonicRhythm: "N/A"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 0, max: 200, typical: 60),
                melodicContour: .static,
                textureType: .polyphonic
            ),
            instruments: [
                Instrument(
                    name: "Tape Machine",
                    type: .electrophone,
                    frequencyRange: (20, 20000),
                    acousticCharacteristics: "Full spectrum manipulation",
                    playingTechnique: "Tape splicing, speed manipulation"
                )
            ],
            culturalContext: "Academic electroacoustic music, sound art",
            scientificReferences: [
                AcademicReference(
                    authors: ["Schaeffer, Pierre"],
                    year: 1966,
                    title: "Traité des objets musicaux",
                    publication: "Éditions du Seuil",
                    doi: nil,
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.ina-grm.com/en/archives"
            ]
        ),

        MusicGenre(
            name: "Spectral Music",
            origin: GeographicOrigin(
                continent: .europe,
                country: "France",
                region: "Paris (IRCAM)",
                coordinates: (48.8606, 2.3522)
            ),
            historicalPeriod: HistoricalPeriod(
                startYear: 1973,
                endYear: nil,
                era: "Late 20th century to present"
            ),
            musicalProfile: MusicalProfile(
                tuningSystem: .microtonal,
                scaleStructure: MusicalProfile.ScaleStructure(
                    tones: 0,
                    intervals: [],
                    name: "Harmonic series derived"
                ),
                rhythmicPattern: MusicalProfile.RhythmicPattern(
                    meter: "Free",
                    polyrhythm: nil,
                    cyclicStructure: nil,
                    subdivision: "complex"
                ),
                harmonicStructure: MusicalProfile.HarmonicStructure(
                    complexity: 1.0,
                    consonance: 0.7,
                    voiceLeading: "Spectral evolution",
                    harmonicRhythm: "Slow transformation"
                ),
                typicalTempo: MusicalProfile.TempoRange(min: 20, max: 120, typical: 60),
                melodicContour: .wave,
                textureType: .polyphonic
            ),
            instruments: [
                Instrument(
                    name: "Computer (FFT analysis)",
                    type: .electrophone,
                    frequencyRange: (20, 20000),
                    acousticCharacteristics: "Spectral analysis and resynthesis",
                    playingTechnique: "Computer-assisted composition"
                )
            ],
            culturalContext: "Academic contemporary music",
            scientificReferences: [
                AcademicReference(
                    authors: ["Fineberg, Joshua"],
                    year: 2000,
                    title: "Spectral Music: Aesthetics and Techniques",
                    publication: "Contemporary Music Review 19(2)",
                    doi: "10.1080/07494460000640231",
                    url: nil
                )
            ],
            audioArchives: [
                "https://www.ircam.fr/archives"
            ]
        )
    ]

    // MARK: - All Genres

    public var allGenres: [MusicGenre] {
        africanGenres + asianGenres + europeanGenres + modernGenres
    }

    // MARK: - Search & Filter

    public func search(by name: String) -> [MusicGenre] {
        allGenres.filter { $0.name.lowercased().contains(name.lowercased()) }
    }

    public func filter(by continent: GeographicOrigin.Continent) -> [MusicGenre] {
        allGenres.filter { $0.origin.continent == continent }
    }

    public func filter(by era: String) -> [MusicGenre] {
        allGenres.filter { $0.historicalPeriod.era.contains(era) }
    }
}
