import Foundation

/// Musical style database with tuning recommendations
/// Links musical genres/styles to appropriate tuning systems for historically
/// informed and aesthetically optimal performance.
///
/// Integration with TuningDatabase provides context-aware tuning suggestions.
@MainActor
class MusicalStyleDatabase: ObservableObject {

    /// Singleton instance
    static let shared = MusicalStyleDatabase()

    /// All available musical styles
    @Published var allStyles: [MusicalStyle] = []


    // MARK: - Initialization

    init() {
        loadStyles()
    }


    // MARK: - Public Methods

    /// Get style by ID
    func getStyle(id: String) -> MusicalStyle? {
        return allStyles.first { $0.id == id }
    }

    /// Get styles by category
    func getStyles(category: StyleCategory) -> [MusicalStyle] {
        return allStyles.filter { $0.category == category }
    }

    /// Get styles by era
    func getStyles(era: MusicalEra) -> [MusicalStyle] {
        return allStyles.filter { $0.era == era }
    }

    /// Search styles
    func search(_ query: String) -> [MusicalStyle] {
        let lowercased = query.lowercased()
        return allStyles.filter { style in
            style.name.lowercased().contains(lowercased) ||
            style.description.lowercased().contains(lowercased)
        }
    }

    /// Get recommended tuning IDs for a style
    func getRecommendedTunings(for styleID: String) -> [String] {
        guard let style = getStyle(id: styleID) else { return [] }
        return style.recommendedTunings
    }


    // MARK: - Private Methods

    private func loadStyles() {
        allStyles = [

            // MARK: - Classical & Art Music

            MusicalStyle(
                id: "baroque",
                name: "Baroque Music",
                category: .classical,
                era: .baroque,
                description: "European art music c. 1600-1750 (Bach, Handel, Vivaldi)",
                characteristics: [
                    "Ornamentation and improvisation",
                    "Terraced dynamics",
                    "Basso continuo",
                    "Affekt theory (emotional expression)"
                ],
                recommendedTunings: [
                    "baroque-415",          // Primary choice
                    "meantone-quarter",     // Keyboard music
                    "werckmeister-iii",     // Well-Tempered Clavier
                    "vallotti-young"
                ],
                recommendedInstruments: ["harpsichord", "baroque-violin", "recorder", "organ"],
                keyComposers: ["J.S. Bach", "Handel", "Vivaldi", "Corelli", "Purcell"],
                historicalContext: """
                Baroque pitch (A=415 Hz) is standard for period performance.
                Quarter-comma meantone for keyboard works 1600-1700.
                Well-temperaments (Werckmeister, Vallotti) for late Baroque.
                """
            ),

            MusicalStyle(
                id: "classical",
                name: "Classical Era",
                category: .classical,
                era: .classical,
                description: "European art music c. 1750-1820 (Mozart, Haydn, Beethoven)",
                characteristics: [
                    "Clarity and balance",
                    "Homophonic texture",
                    "Sonata form",
                    "Symphony and string quartet"
                ],
                recommendedTunings: [
                    "classical-430",
                    "kirnberger-iii",
                    "vallotti-young",
                    "iso-440"  // Modern performance
                ],
                recommendedInstruments: ["fortepiano", "classical-wind", "string-quartet"],
                keyComposers: ["Mozart", "Haydn", "Beethoven (early)", "Clementi"],
                historicalContext: "A=430 Hz typical. Fortepiano and period winds built to this pitch."
            ),

            MusicalStyle(
                id: "romantic",
                name: "Romantic Music",
                category: .classical,
                era: .romantic,
                description: "European art music c. 1820-1900 (Chopin, Brahms, Wagner)",
                characteristics: [
                    "Emotional expression",
                    "Expanded harmony",
                    "Virtuosity",
                    "Program music"
                ],
                recommendedTunings: [
                    "french-diapason-435",  // French Romantic
                    "iso-440",
                    "orchestra-442"
                ],
                recommendedInstruments: ["romantic-piano", "full-orchestra", "french-horn"],
                keyComposers: ["Chopin", "Brahms", "Wagner", "Tchaikovsky", "Liszt"],
                historicalContext: "French Diapason Normal (A=435) for French Romantic works. Modern performances use 440-442 Hz."
            ),

            MusicalStyle(
                id: "contemporary-classical",
                name: "Contemporary Classical",
                category: .classical,
                era: .contemporary,
                description: "Modern art music (20th-21st century)",
                characteristics: [
                    "Extended techniques",
                    "Atonality/serialism",
                    "Minimalism",
                    "Electronic integration"
                ],
                recommendedTunings: [
                    "iso-440",
                    "19tet",
                    "31tet",
                    "carlos-alpha",
                    "bohlen-pierce"
                ],
                recommendedInstruments: ["synthesizer", "prepared-piano", "extended-technique"],
                keyComposers: ["John Cage", "Steve Reich", "Philip Glass", "Kaija Saariaho"],
                historicalContext: "Standard A=440, but many composers explore microtonality and alternative tunings."
            ),

            // MARK: - Popular Music

            MusicalStyle(
                id: "pop",
                name: "Pop Music",
                category: .popular,
                era: .contemporary,
                description: "Popular mainstream music",
                characteristics: [
                    "Verse-chorus structure",
                    "Catchy melodies",
                    "Accessible production",
                    "Commercial appeal"
                ],
                recommendedTunings: [
                    "iso-440"  // ONLY 440 Hz for pop
                ],
                recommendedInstruments: ["synthesizer", "electric-guitar", "drums", "vocals"],
                keyComposers: [],  // Contemporary artists
                historicalContext: "Always A=440 Hz (ISO standard). Essential for DAW integration and MIDI compatibility."
            ),

            MusicalStyle(
                id: "rock",
                name: "Rock Music",
                category: .popular,
                era: .contemporary,
                description: "Rock and roll, alternative, indie rock",
                characteristics: [
                    "Electric guitars",
                    "Strong backbeat",
                    "Power chords",
                    "Energetic performance"
                ],
                recommendedTunings: [
                    "iso-440"
                ],
                recommendedInstruments: ["electric-guitar", "bass-guitar", "drums"],
                keyComposers: [],
                historicalContext: "A=440 Hz standard. Some bands experiment with alternative tunings (drop D, etc.) but reference pitch stays 440."
            ),

            MusicalStyle(
                id: "electronic",
                name: "Electronic Music",
                category: .popular,
                era: .contemporary,
                description: "EDM, techno, house, ambient",
                characteristics: [
                    "Synthesized sounds",
                    "Digital production",
                    "Beat-driven or atmospheric",
                    "Studio-based composition"
                ],
                recommendedTunings: [
                    "iso-440",
                    "19tet",
                    "carlos-alpha",
                    "carlos-beta",
                    "verdi-432"  // Some ambient producers use this
                ],
                recommendedInstruments: ["synthesizer", "sampler", "drum-machine"],
                keyComposers: [],
                historicalContext: "Primarily A=440 for compatibility. Experimental artists explore microtonality."
            ),

            MusicalStyle(
                id: "hip-hop",
                name: "Hip Hop",
                category: .popular,
                era: .contemporary,
                description: "Rap, hip hop, trap",
                characteristics: [
                    "Rhythmic vocals (rap)",
                    "Sampling",
                    "Beat production",
                    "Cultural expression"
                ],
                recommendedTunings: [
                    "iso-440"
                ],
                recommendedInstruments: ["sampler", "drum-machine", "turntables", "synthesizer"],
                keyComposers: [],
                historicalContext: "A=440 Hz exclusively. Sample-based production requires standard tuning."
            ),

            // MARK: - Jazz & Blues

            MusicalStyle(
                id: "jazz",
                name: "Jazz",
                category: .jazz,
                era: .modern,
                description: "Jazz (swing, bebop, modal, fusion)",
                characteristics: [
                    "Improvisation",
                    "Swing rhythm",
                    "Complex harmony",
                    "Blue notes"
                ],
                recommendedTunings: [
                    "iso-440",
                    "orchestra-442"  // Some jazz orchestras
                ],
                recommendedInstruments: ["saxophone", "trumpet", "piano", "double-bass", "drums"],
                keyComposers: ["Duke Ellington", "Miles Davis", "John Coltrane", "Thelonious Monk"],
                historicalContext: "A=440 Hz standard. Some big bands use 442 Hz."
            ),

            MusicalStyle(
                id: "blues",
                name: "Blues",
                category: .jazz,
                era: .modern,
                description: "Traditional and electric blues",
                characteristics: [
                    "12-bar blues form",
                    "Blue notes (bent pitches)",
                    "Call and response",
                    "Emotional expression"
                ],
                recommendedTunings: [
                    "iso-440"
                ],
                recommendedInstruments: ["harmonica", "electric-guitar", "piano"],
                keyComposers: ["Robert Johnson", "Muddy Waters", "B.B. King"],
                historicalContext: "A=440 Hz. Blue notes are microtonal pitch bends, not fixed tuning changes."
            ),

            // MARK: - World Music

            MusicalStyle(
                id: "arabic",
                name: "Arabic Music",
                category: .world,
                era: .traditional,
                description: "Traditional and classical Arabic music",
                characteristics: [
                    "Maqam modal system",
                    "Quarter tones",
                    "Improvisation (taqsim)",
                    "Complex rhythmic cycles"
                ],
                recommendedTunings: [
                    "arabic-24tet",
                    "arabic-rast",
                    "arabic-bayati"
                ],
                recommendedInstruments: ["oud", "qanun", "ney", "riq"],
                keyComposers: ["Umm Kulthum", "Fairuz", "Mohammed Abdel Wahab"],
                historicalContext: "Traditional maqam uses non-equal intervals. 24-TET is modern approximation."
            ),

            MusicalStyle(
                id: "turkish",
                name: "Turkish Music",
                category: .world,
                era: .traditional,
                description: "Turkish classical and folk music",
                characteristics: [
                    "Makam modal system",
                    "53-koma tuning",
                    "Ornamentation",
                    "Usul (rhythmic cycles)"
                ],
                recommendedTunings: [
                    "turkish-53tet"
                ],
                recommendedInstruments: ["tanbur", "kanun", "ney", "kemençe"],
                keyComposers: ["Dede Efendi", "Tanburi Cemil Bey"],
                historicalContext: "53 equal divisions (koma) per octave is traditional Turkish theory."
            ),

            MusicalStyle(
                id: "indian-classical",
                name: "Indian Classical Music",
                category: .world,
                era: .traditional,
                description: "Hindustani and Carnatic music",
                characteristics: [
                    "Raga melodic framework",
                    "Tala rhythmic cycles",
                    "Improvisation",
                    "Drone (tanpura)"
                ],
                recommendedTunings: [
                    "indian-22-sruti",
                    "just-c-major"  // Approximation
                ],
                recommendedInstruments: ["sitar", "tabla", "tanpura", "veena", "sarangi"],
                keyComposers: ["Ravi Shankar", "Ali Akbar Khan", "M.S. Subbulakshmi"],
                historicalContext: "22 śruti system. Just intonation with context-dependent intervals."
            ),

            MusicalStyle(
                id: "persian",
                name: "Persian Music",
                category: .world,
                era: .traditional,
                description: "Persian classical music (dastgāh system)",
                characteristics: [
                    "Seven dastgāh modes",
                    "Neutral intervals",
                    "Improvisation (āvāz)",
                    "Poetry integration"
                ],
                recommendedTunings: [
                    "persian-dastgah"
                ],
                recommendedInstruments: ["tar", "setar", "santur", "kamancheh", "tombak"],
                keyComposers: ["Mohammad Reza Shajarian", "Hossein Alizadeh"],
                historicalContext: "Uses neutral seconds (~135¢) and neutral thirds (~350¢). Koron and sori quarter-tone accidentals."
            ),

            // MARK: - Experimental & New Age

            MusicalStyle(
                id: "meditation",
                name: "Meditation Music",
                category: .newAge,
                era: .contemporary,
                description: "Music for meditation and mindfulness",
                characteristics: [
                    "Slow tempo or no pulse",
                    "Sustained tones",
                    "Minimal harmonic movement",
                    "Calm atmosphere"
                ],
                recommendedTunings: [
                    "iso-440",
                    "verdi-432",  // Popular in meditation community (with caveats)
                    "just-c-major"
                ],
                recommendedInstruments: ["singing-bowl", "synthesizer", "nature-sounds"],
                keyComposers: [],
                historicalContext: "A=440 Hz is standard, but some practitioners prefer 432 Hz (aesthetic choice, not scientific)."
            ),

            MusicalStyle(
                id: "ambient",
                name: "Ambient Music",
                category: .experimental,
                era: .contemporary,
                description: "Atmospheric, environmental music",
                characteristics: [
                    "Textural focus",
                    "Non-rhythmic or subtle pulse",
                    "Timbral exploration",
                    "Background listening"
                ],
                recommendedTunings: [
                    "iso-440",
                    "just-c-major",
                    "19tet",
                    "carlos-alpha",
                    "verdi-432"
                ],
                recommendedInstruments: ["synthesizer", "field-recordings", "effects"],
                keyComposers: ["Brian Eno", "Harold Budd", "Stars of the Lid"],
                historicalContext: "Flexible tuning choices. Microtonal exploration common."
            ),

            MusicalStyle(
                id: "experimental",
                name: "Experimental Music",
                category: .experimental,
                era: .contemporary,
                description: "Avant-garde and experimental composition",
                characteristics: [
                    "Unconventional techniques",
                    "Extended tunings",
                    "Sound exploration",
                    "Conceptual approaches"
                ],
                recommendedTunings: [
                    "bohlen-pierce",
                    "carlos-alpha",
                    "carlos-beta",
                    "carlos-gamma",
                    "19tet",
                    "31tet",
                    "pythagorean",
                    "just-c-major"
                ],
                recommendedInstruments: ["synthesizer", "prepared-piano", "electronics"],
                keyComposers: ["Karlheinz Stockhausen", "Iannis Xenakis", "La Monte Young"],
                historicalContext: "Open to all tuning systems. Exploration of uncharted harmonic territories."
            ),

            // MARK: - Orchestral & Ensemble

            MusicalStyle(
                id: "orchestral",
                name: "Orchestral Music",
                category: .classical,
                era: .modern,
                description: "Full symphony orchestra (modern performance)",
                characteristics: [
                    "Large ensemble",
                    "Wide dynamic range",
                    "Orchestration",
                    "Professional performance"
                ],
                recommendedTunings: [
                    "orchestra-442",     // European standard
                    "north-american-441",
                    "iso-440",
                    "russian-443"
                ],
                recommendedInstruments: ["full-orchestra"],
                keyComposers: ["Mahler", "Strauss", "Shostakovich", "John Williams"],
                historicalContext: "European orchestras typically 442-443 Hz. North American 440-441 Hz."
            ),

            MusicalStyle(
                id: "opera",
                name: "Opera",
                category: .classical,
                era: .romantic,
                description: "Operatic voice with orchestra",
                characteristics: [
                    "Dramatic vocal performance",
                    "Orchestral accompaniment",
                    "Theatrical presentation",
                    "Extended vocal technique"
                ],
                recommendedTunings: [
                    "orchestra-442",
                    "french-diapason-435",  // French opera
                    "verdi-432"  // Verdi advocated this
                ],
                recommendedInstruments: ["opera-singer", "full-orchestra"],
                keyComposers: ["Verdi", "Puccini", "Wagner", "Mozart"],
                historicalContext: "Verdi famously advocated A=432 Hz. Modern opera houses use 442-443 Hz."
            ),

            // MARK: - Film & Media

            MusicalStyle(
                id: "film-score",
                name: "Film Score",
                category: .media,
                era: .contemporary,
                description: "Music for film and television",
                characteristics: [
                    "Synchronized to picture",
                    "Emotional storytelling",
                    "Orchestral or electronic",
                    "Thematic development"
                ],
                recommendedTunings: [
                    "iso-440"  // ONLY 440 Hz for film/media
                ],
                recommendedInstruments: ["full-orchestra", "synthesizer", "hybrid"],
                keyComposers: ["John Williams", "Hans Zimmer", "Ennio Morricone", "Alexandre Desplat"],
                historicalContext: "A=440 Hz exclusively. Essential for sync with digital audio post-production."
            )
        ]
    }
}


// MARK: - Data Models

struct MusicalStyle: Identifiable, Codable {
    let id: String
    let name: String
    let category: StyleCategory
    let era: MusicalEra
    let description: String
    let characteristics: [String]
    let recommendedTunings: [String]  // IDs from TuningDatabase
    let recommendedInstruments: [String]
    let keyComposers: [String]
    let historicalContext: String
}


// MARK: - Enums

enum StyleCategory: String, Codable, CaseIterable {
    case classical = "Classical & Art Music"
    case popular = "Popular Music"
    case jazz = "Jazz & Blues"
    case world = "World Music"
    case newAge = "New Age & Meditation"
    case experimental = "Experimental"
    case media = "Film & Media"
}

enum MusicalEra: String, Codable, CaseIterable {
    case medieval = "Medieval"
    case renaissance = "Renaissance"
    case baroque = "Baroque"
    case classical = "Classical"
    case romantic = "Romantic"
    case modern = "Modern (20th century)"
    case contemporary = "Contemporary (21st century)"
    case traditional = "Traditional (timeless)"
}
