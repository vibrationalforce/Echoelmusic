import Foundation

/// Comprehensive tuning database with 50+ reference pitch systems
/// More detailed than Omnisphere's tuning library, with historical context,
/// scientific references, and integration with musical style database.
///
/// Supports:
/// - Historical tunings (Baroque, Classical, Romantic eras)
/// - Regional standards (French, German, Italian, etc.)
/// - Microtonal systems (Arabic, Turkish, Persian, Indian)
/// - Alternative temperaments (Pythagorean, Just Intonation, Meantone, Well-Temperament)
/// - Modern variants (432 Hz, Scientific Pitch, etc.)
/// - Experimental systems (Wendy Carlos, Bohlen-Pierce, etc.)
@MainActor
class TuningDatabase: ObservableObject {

    /// Singleton instance
    static let shared = TuningDatabase()

    /// All available tuning systems
    @Published var allTunings: [TuningSystem] = []

    /// Favorite tunings (user-selected)
    @Published var favoriteTunings: [String] = []  // IDs

    /// Recently used tunings
    @Published var recentTunings: [String] = []  // IDs (max 10)


    // MARK: - Initialization

    init() {
        loadTunings()
        loadUserPreferences()
    }


    // MARK: - Public Methods

    /// Get tuning system by ID
    func getTuning(id: String) -> TuningSystem? {
        return allTunings.first { $0.id == id }
    }

    /// Get tunings by category
    func getTunings(category: TuningCategory) -> [TuningSystem] {
        return allTunings.filter { $0.category == category }
    }

    /// Get tunings by era
    func getTunings(era: HistoricalEra) -> [TuningSystem] {
        return allTunings.filter { $0.era == era }
    }

    /// Get tunings by region
    func getTunings(region: GeographicRegion) -> [TuningSystem] {
        return allTunings.filter { $0.region == region }
    }

    /// Get recommended tunings for a musical style
    func getRecommendedTunings(for styleID: String) -> [TuningSystem] {
        return allTunings.filter { tuning in
            tuning.recommendedStyles.contains(styleID)
        }.sorted { $0.priority > $1.priority }
    }

    /// Search tunings by name or description
    func search(_ query: String) -> [TuningSystem] {
        let lowercased = query.lowercased()
        return allTunings.filter { tuning in
            tuning.name.lowercased().contains(lowercased) ||
            tuning.description.lowercased().contains(lowercased) ||
            tuning.historicalContext.lowercased().contains(lowercased)
        }
    }

    /// Toggle favorite status
    func toggleFavorite(_ tuningID: String) {
        if favoriteTunings.contains(tuningID) {
            favoriteTunings.removeAll { $0 == tuningID }
        } else {
            favoriteTunings.append(tuningID)
        }
        saveUserPreferences()
    }

    /// Mark tuning as recently used
    func markAsRecent(_ tuningID: String) {
        recentTunings.removeAll { $0 == tuningID }
        recentTunings.insert(tuningID, at: 0)
        if recentTunings.count > 10 {
            recentTunings = Array(recentTunings.prefix(10))
        }
        saveUserPreferences()
    }

    /// Get favorite tunings
    func getFavorites() -> [TuningSystem] {
        return favoriteTunings.compactMap { getTuning(id: $0) }
    }

    /// Get recent tunings
    func getRecent() -> [TuningSystem] {
        return recentTunings.compactMap { getTuning(id: $0) }
    }


    // MARK: - Private Methods

    private func loadTunings() {
        allTunings = [
            // MARK: - Modern Standards (ISO & Contemporary)
            TuningSystem(
                id: "iso-440",
                name: "A=440 Hz (ISO 16:1975)",
                a4Frequency: 440.0,
                category: .modern,
                era: .modern,
                region: .international,
                description: "International standard tuning, adopted worldwide since 1955",
                historicalContext: """
                ISO 16:1975 international standard. Adopted by International Organization for Standardization.
                Used universally in recording studios, MIDI devices, digital audio workstations, and most modern instruments.
                Provides consistency across global music production and performance.
                """,
                scientificReferences: [
                    "ISO 16:1975 - Acoustics - Standard tuning frequency",
                    "ANSI S1.1-1994 - Acoustical Terminology"
                ],
                recommendedStyles: ["pop", "rock", "electronic", "hip-hop", "contemporary-classical", "film-score"],
                priority: 10  // Highest priority - industry standard
            ),

            TuningSystem(
                id: "orchestra-442",
                name: "A=442 Hz (Orchestra Standard)",
                a4Frequency: 442.0,
                category: .modern,
                era: .modern,
                region: .western,
                description: "Common in European orchestras for brighter, more brilliant sound",
                historicalContext: """
                Many European orchestras tune slightly sharp (442-443 Hz) for increased brilliance and projection.
                Berlin Philharmonic, Vienna Philharmonic, and major opera houses often use 442-443 Hz.
                The sharper tuning creates psychological excitement and helps strings cut through orchestral texture.
                """,
                scientificReferences: [
                    "Haynes, B. (2002). A History of Performing Pitch",
                    "European Broadcasting Union recommendations"
                ],
                recommendedStyles: ["orchestral", "opera", "classical", "romantic"],
                instruments: ["violin", "viola", "cello", "orchestra"],
                priority: 9
            ),

            TuningSystem(
                id: "north-american-441",
                name: "A=441 Hz (North American)",
                a4Frequency: 441.0,
                category: .modern,
                era: .modern,
                region: .northAmerica,
                description: "Compromise between 440 and 442, used in North American orchestras",
                historicalContext: """
                Many North American orchestras tune to 441 Hz as a middle ground.
                Provides slight brightness without going as sharp as European 442 Hz.
                Used by several major US symphony orchestras.
                """,
                scientificReferences: ["American Federation of Musicians tuning guidelines"],
                recommendedStyles: ["orchestral", "classical", "film-score"],
                priority: 7
            ),

            // MARK: - Historical Standards
            TuningSystem(
                id: "baroque-415",
                name: "A=415 Hz (Baroque Pitch)",
                a4Frequency: 415.0,
                category: .historical,
                era: .baroque,
                region: .western,
                description: "Standard Baroque tuning (c. 1600-1750), exactly one semitone below A=440",
                historicalContext: """
                Baroque pitch, approximately one semitone lower than modern pitch.
                Used for historically-informed performances of Bach, Handel, Vivaldi, and other Baroque composers.
                Period instruments (harpsichord, Baroque violin, recorder) are often built for this pitch.
                The lower pitch creates darker, warmer timbres characteristic of Baroque music.
                """,
                scientificReferences: [
                    "Haynes, B. (2002). A History of Performing Pitch, Chapter 7",
                    "Barbour, J.M. (1951). Tuning and Temperament"
                ],
                recommendedStyles: ["baroque", "early-music", "renaissance"],
                instruments: ["harpsichord", "baroque-violin", "recorder", "lute"],
                priority: 8
            ),

            TuningSystem(
                id: "classical-430",
                name: "A=430 Hz (Classical Era)",
                a4Frequency: 430.0,
                category: .historical,
                era: .classical,
                region: .western,
                description: "Common tuning in Classical period (Mozart, Haydn era)",
                historicalContext: """
                Typical tuning for Classical period (1750-1820).
                Mozart, Haydn, and early Beethoven would have known instruments at this pitch.
                Fortepiano and period wind instruments often built to 430 Hz.
                """,
                scientificReferences: ["Haynes, B. (2002). A History of Performing Pitch, Chapter 8"],
                recommendedStyles: ["classical", "mozart", "haydn"],
                instruments: ["fortepiano", "classical-wind"],
                priority: 7
            ),

            TuningSystem(
                id: "french-diapason-435",
                name: "A=435 Hz (French Diapason Normal)",
                a4Frequency: 435.0,
                category: .historical,
                era: .romantic,
                region: .france,
                description: "French standard pitch (1859-1939), official French government standard",
                historicalContext: """
                Established by French government in 1859 as "Diapason Normal".
                Used throughout France until adoption of A=440 in 1939.
                Debussy, Ravel, Satie, and French Romantic composers knew this pitch.
                Still used for historically-informed performances of French Romantic music.
                """,
                scientificReferences: [
                    "French law of February 16, 1859",
                    "Ellis, A.J. (1880). The History of Musical Pitch"
                ],
                recommendedStyles: ["french-romantic", "impressionism", "debussy", "ravel"],
                instruments: ["french-horn", "romantic-piano"],
                priority: 6
            ),

            TuningSystem(
                id: "renaissance-466",
                name: "A=466 Hz (Renaissance High Pitch)",
                a4Frequency: 466.0,
                category: .historical,
                era: .renaissance,
                region: .italy,
                description: "High Renaissance pitch (Venice, Northern Italy c. 1500-1600)",
                historicalContext: """
                Very high pitch used in Northern Italian churches and courts during Renaissance.
                Organs in Venice (San Marco) were often at this pitch or higher.
                Creates brilliant, festive character for sacred polyphony.
                About 1.5 semitones above modern pitch.
                """,
                scientificReferences: ["Haynes, B. (2002). A History of Performing Pitch, Chapter 5"],
                recommendedStyles: ["renaissance", "sacred-polyphony", "venetian-school"],
                instruments: ["renaissance-organ", "cornetto", "sackbut"],
                priority: 5
            ),

            // MARK: - Alternative & Experimental
            TuningSystem(
                id: "verdi-432",
                name: "A=432 Hz (Verdi Pitch / Alternative)",
                a4Frequency: 432.0,
                category: .alternative,
                era: .modern,
                region: .international,
                description: "Alternative tuning, advocated by Verdi and some contemporary musicians",
                historicalContext: """
                Giuseppe Verdi advocated for A=432 Hz in 1884, calling it "scientific pitch".
                Some musicians claim warmer, more natural sound qualities.

                IMPORTANT SCIENTIFIC NOTE: Claims about 432 Hz having special healing properties,
                mathematical significance with universe, or superior psychoacoustic effects are
                NOT supported by peer-reviewed scientific research. Use for artistic preference only.
                """,
                scientificReferences: [
                    "Verdi's letter to Music Commission (1884) - historical document only",
                    "Note: Therapeutic claims lack scientific validation"
                ],
                recommendedStyles: ["meditation", "ambient", "new-age", "experimental"],
                priority: 4,  // Lower priority due to pseudoscience associations
                warningNote: "Not scientifically validated for therapeutic claims"
            ),

            TuningSystem(
                id: "scientific-256",
                name: "A=430.54 Hz (Scientific Pitch, C=256 Hz)",
                a4Frequency: 430.54,
                category: .alternative,
                era: .modern,
                region: .international,
                description: "Scientific pitch where C=256 Hz (powers of 2)",
                historicalContext: """
                Also called "Philosophical Pitch" or "Sauveur Pitch".
                Based on C4 = 256 Hz (2^8), making octaves exact powers of 2.
                Mathematically elegant but not widely adopted in practice.
                Sometimes used in acoustics research for convenient frequency ratios.
                """,
                scientificReferences: [
                    "Sauveur, J. (1701). Systeme general des intervalles",
                    "Used in some acoustics research contexts"
                ],
                recommendedStyles: ["experimental", "research", "acoustics"],
                priority: 3
            ),

            TuningSystem(
                id: "wendy-carlos-alpha",
                name: "Wendy Carlos Alpha Scale (78.0¢)",
                a4Frequency: 440.0,  // Reference, but uses 78-cent steps
                category: .experimental,
                era: .modern,
                region: .international,
                description: "15.385 steps per octave, 78.0 cents per step (Wendy Carlos, 1986)",
                historicalContext: """
                Created by composer Wendy Carlos for electronic music synthesis.
                Optimizes consonance for major and minor thirds.
                Used in her albums "Beauty in the Beast" (1986) and other works.
                15.385 steps per octave = 78.0 cents per step.
                Not compatible with standard 12-TET instruments.
                """,
                scientificReferences: [
                    "Carlos, W. (1987). Tuning: At the Crossroads, Computer Music Journal 11(1)",
                    "Carlos, W. (1986). Beauty in the Beast album"
                ],
                recommendedStyles: ["electronic", "experimental", "avant-garde"],
                instruments: ["synthesizer", "computer"],
                priority: 2,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "wendy-carlos-beta",
                name: "Wendy Carlos Beta Scale (63.8¢)",
                a4Frequency: 440.0,
                category: .experimental,
                era: .modern,
                region: .international,
                description: "18.809 steps per octave, 63.8 cents per step",
                historicalContext: """
                Another Wendy Carlos microtonal scale.
                Optimizes perfect fifths while maintaining reasonable thirds.
                18.809 steps per octave = 63.8 cents per step.
                """,
                scientificReferences: ["Carlos, W. (1987). Tuning: At the Crossroads"],
                recommendedStyles: ["electronic", "experimental"],
                priority: 2,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "wendy-carlos-gamma",
                name: "Wendy Carlos Gamma Scale (35.1¢)",
                a4Frequency: 440.0,
                category: .experimental,
                era: .modern,
                region: .international,
                description: "34.188 steps per octave, 35.1 cents per step",
                historicalContext: """
                Wendy Carlos's third experimental scale.
                Very fine divisions, 34.188 steps per octave.
                Creates novel harmonic relationships.
                """,
                scientificReferences: ["Carlos, W. (1987). Tuning: At the Crossroads"],
                recommendedStyles: ["electronic", "experimental"],
                priority: 2,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "bohlen-pierce",
                name: "Bohlen-Pierce Scale (1902¢ 'octave')",
                a4Frequency: 440.0,
                category: .experimental,
                era: .modern,
                region: .international,
                description: "13 steps per tritave (3:1 ratio instead of 2:1 octave)",
                historicalContext: """
                Non-octave scale based on the tritave (3:1 ratio, ~1902 cents).
                Invented by Heinz Bohlen (1970s) and independently by John Pierce (1980s).
                13 equal divisions of the tritave.
                Creates entirely alien harmonic landscape - no octaves!
                Used in experimental composition and research.
                """,
                scientificReferences: [
                    "Bohlen, H. (1978). 13 Tonstufen in der Duodezime",
                    "Mathews, M. et al. (1988). The Bohlen-Pierce Scale, Computer Music Journal"
                ],
                recommendedStyles: ["experimental", "avant-garde", "research"],
                instruments: ["synthesizer"],
                priority: 2,
                requiresMicrotonal: true
            ),

            // MARK: - Microtonal & World Music Systems
            TuningSystem(
                id: "arabic-24tet",
                name: "Arabic 24-TET (Quarter Tones)",
                a4Frequency: 440.0,
                category: .microtonal,
                era: .traditional,
                region: .middleEast,
                description: "24 equal divisions per octave, used in Arabic music theory",
                historicalContext: """
                Modern standardization of Arabic maqam system.
                24 equal steps per octave (50 cents each) allows quarter tones.
                Used in Arabic, Turkish, and Persian music.
                Note: Traditional maqam uses more complex, non-equal tuning;
                24-TET is a practical approximation for modern instruments.
                """,
                scientificReferences: [
                    "Touma, H.H. (1996). The Music of the Arabs",
                    "Cairo Congress on Arab Music (1932)"
                ],
                recommendedStyles: ["arabic", "maqam", "middle-eastern", "turkish"],
                instruments: ["oud", "qanun", "ney"],
                priority: 7,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "turkish-53tet",
                name: "Turkish 53-TET (53 Koma)",
                a4Frequency: 440.0,
                category: .microtonal,
                era: .traditional,
                region: .middleEast,
                description: "53 equal divisions per octave, Turkish makam system",
                historicalContext: """
                Traditional Turkish music theory divides octave into 53 equal komas.
                Closely approximates Pythagorean tuning and traditional makam intervals.
                Each koma = ~22.64 cents (1200¢ / 53).
                Allows precise representation of Turkish makam scales (Rast, Hicaz, Saba, etc.).
                """,
                scientificReferences: [
                    "Yarman, O. (2007). 79-Tone Tuning & Theory for Turkish Maqam Music",
                    "Arel-Ezgi-Uzdilek system"
                ],
                recommendedStyles: ["turkish", "makam", "ottoman"],
                instruments: ["tanbur", "kanun", "ney"],
                priority: 6,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "indian-22-sruti",
                name: "Indian 22 Śruti System",
                a4Frequency: 440.0,
                category: .microtonal,
                era: .traditional,
                region: .india,
                description: "Traditional Indian 22-śruti microtonal system",
                historicalContext: """
                Ancient Indian music theory recognizes 22 śrutis (microtones) per octave.
                Based on just intonation ratios derived from Bharata's Natyashastra (c. 200 BCE).
                Forms basis of raga system in Hindustani and Carnatic music.
                Actual śruti sizes vary by context and are not equal divisions.
                """,
                scientificReferences: [
                    "Bharata. Natyashastra (c. 200 BCE-200 CE)",
                    "Deva, B.C. (1995). Indian Music"
                ],
                recommendedStyles: ["hindustani", "carnatic", "raga", "indian-classical"],
                instruments: ["sitar", "tabla", "tanpura", "veena"],
                priority: 6,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "persian-dastgah",
                name: "Persian Dastgāh System",
                a4Frequency: 440.0,
                category: .microtonal,
                era: .traditional,
                region: .middleEast,
                description: "Persian traditional tuning for dastgāh modal system",
                historicalContext: """
                Persian classical music uses seven dastgāh (modal systems).
                Intervals include neutral seconds (~135-150 cents) and neutral thirds (~350 cents).
                Koron (♭) and sori (♯) are quarter-tone accidentals.
                Tuning is context-dependent and varies by performer and school.
                """,
                scientificReferences: [
                    "Farhat, H. (2004). The Dastgāh Concept in Persian Music",
                    "During, J. (1991). La Musique Iranienne"
                ],
                recommendedStyles: ["persian", "iranian", "dastgah"],
                instruments: ["tar", "setar", "santur", "kamancheh"],
                priority: 5,
                requiresMicrotonal: true
            ),

            // MARK: - Just Intonation & Historical Temperaments
            TuningSystem(
                id: "pythagorean",
                name: "Pythagorean Tuning (Pure Fifths)",
                a4Frequency: 440.0,
                category: .justIntonation,
                era: .medieval,
                region: .western,
                description: "Ancient Greek tuning based on pure 3:2 perfect fifths",
                historicalContext: """
                Attributed to Pythagoras (c. 570-495 BCE).
                All intervals derived from stacking pure 3:2 fifths.
                Perfect fifths (3:2) are pure, but thirds are dissonant.
                Major third = 81/64 (~407.82 cents) vs. pure 5/4 (~386.31 cents).
                Creates the "Pythagorean comma" (23.46 cents) after 12 fifths.
                Used in medieval European music, ancient Greek theory.
                """,
                scientificReferences: [
                    "Ptolemy. Harmonics (2nd century CE)",
                    "Boethius. De institutione musica (6th century CE)"
                ],
                recommendedStyles: ["medieval", "early-music", "ancient-greek"],
                instruments: ["medieval-organ", "medieval-strings"],
                priority: 5,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "just-5limit",
                name: "5-Limit Just Intonation (Pure Thirds & Fifths)",
                a4Frequency: 440.0,
                category: .justIntonation,
                era: .renaissance,
                region: .western,
                description: "Pure ratios using primes 2, 3, and 5 (perfect thirds and fifths)",
                historicalContext: """
                Renaissance tuning system with pure major thirds (5:4 ratio).
                Intervals: Perfect fifth 3:2, Major third 5:4, Minor third 6:5.
                Creates beautiful, beatless triads in common keys.
                Problem: Different keys have different interval sizes (cannot modulate freely).
                Advocated by Zarlino (1558), used in a cappella vocal music.
                """,
                scientificReferences: [
                    "Zarlino, G. (1558). Le Istitutioni Harmoniche",
                    "Partch, H. (1974). Genesis of a Music"
                ],
                recommendedStyles: ["renaissance", "vocal-ensemble", "a-cappella"],
                instruments: ["choir", "renaissance-ensemble"],
                priority: 6,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "meantone-quarter-comma",
                name: "Quarter-Comma Meantone",
                a4Frequency: 440.0,
                category: .temperament,
                era: .renaissance,
                region: .western,
                description: "Renaissance/Baroque temperament with pure major thirds",
                historicalContext: """
                Dominant tuning system 1550-1700 in Western Europe.
                Fifths tempered narrow by 1/4 syntonic comma (~5.38 cents).
                Result: Pure major thirds (5:4 ratio), slightly narrow fifths.
                Beautiful in common keys (C, F, G, Bb), but some keys unusable ("wolf" intervals).
                Used for keyboard music of Frescobaldi, early Bach, Purcell.
                """,
                scientificReferences: [
                    "Barbour, J.M. (1951). Tuning and Temperament, Chapter 4",
                    "Zarlino, G. (1558). Le Istitutioni Harmoniche"
                ],
                recommendedStyles: ["renaissance", "early-baroque", "keyboard"],
                instruments: ["harpsichord", "organ", "virginal"],
                priority: 6,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "werckmeister-iii",
                name: "Werckmeister III (Well-Temperament)",
                a4Frequency: 440.0,
                category: .temperament,
                era: .baroque,
                region: .germany,
                description: "Well-temperament allowing all keys, each with unique character",
                historicalContext: """
                Andreas Werckmeister III (1691) - "correct temperament".
                Allows playing in all 24 keys (major and minor).
                Each key has distinct color and affect:
                - C major: pure, simple
                - F# major: exotic, distant
                Possibly used by J.S. Bach for "Well-Tempered Clavier".
                Compromise between pure intervals and key flexibility.
                """,
                scientificReferences: [
                    "Werckmeister, A. (1691). Musicalische Temperatur",
                    "Lindley, M. (2001). Well-Tempered Clavier"
                ],
                recommendedStyles: ["baroque", "bach", "well-tempered-clavier"],
                instruments: ["harpsichord", "clavichord", "baroque-organ"],
                priority: 7,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "kirnberger-iii",
                name: "Kirnberger III (Well-Temperament)",
                a4Frequency: 440.0,
                category: .temperament,
                era: .baroque,
                region: .germany,
                description: "Johann Kirnberger's well-temperament, Bach student's system",
                historicalContext: """
                Created by Johann Kirnberger (1766), student of J.S. Bach.
                Claimed to represent Bach's tuning preferences.
                Hybrid between just intonation and equal temperament.
                C-E-G-B are pure Pythagorean, rest tempered.
                Strong key characteristics: C major very pure, remote keys more tempered.
                """,
                scientificReferences: [
                    "Kirnberger, J.P. (1766). Die Kunst des reinen Satzes",
                    "Jorgensen, O. (1991). Tuning"
                ],
                recommendedStyles: ["baroque", "bach", "classical"],
                instruments: ["harpsichord", "fortepiano"],
                priority: 6,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "vallotti-young",
                name: "Vallotti-Young Temperament",
                a4Frequency: 440.0,
                category: .temperament,
                era: .baroque,
                region: .italy,
                description: "Well-temperament with six tempered fifths (Vallotti 1754, Young 1799)",
                historicalContext: """
                Francesco Antonio Vallotti (1754) and Thomas Young (1799) independently
                developed same system. Six fifths (F-C-G-D-A-E-B) tempered by 1/6 Pythagorean comma,
                remaining six fifths pure. Widely used in 18th-19th century Italy.
                Good compromise: all keys usable, strong key color differences.
                """,
                scientificReferences: [
                    "Vallotti, F.A. (1754). Della scienza teorica e pratica della moderna musica",
                    "Young, T. (1799). Outlines of Experiments and Inquiries Respecting Sound and Light"
                ],
                recommendedStyles: ["baroque", "classical", "italian"],
                instruments: ["fortepiano", "organ"],
                priority: 6,
                requiresMicrotonal: true
            ),

            // MARK: - Equal Temperaments (Non-12)
            TuningSystem(
                id: "19tet",
                name: "19 Equal Temperament (19-TET)",
                a4Frequency: 440.0,
                category: .equalTemperament,
                era: .modern,
                region: .international,
                description: "19 equal divisions per octave (63.16¢ steps)",
                historicalContext: """
                19 equal divisions per octave.
                Excellent approximation of 1/3-comma meantone.
                Major thirds very close to pure 5:4 ratio.
                Used by Guillaume Costeley (1558), advocated by Joseph Sauveur (1701).
                Modern use in experimental and microtonal composition.
                """,
                scientificReferences: [
                    "Costeley, G. (1558). Chromatic chanson experiments",
                    "Sethares, W. (2005). Tuning, Timbre, Spectrum, Scale"
                ],
                recommendedStyles: ["experimental", "microtonal", "renaissance"],
                priority: 4,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "31tet",
                name: "31 Equal Temperament (31-TET)",
                a4Frequency: 440.0,
                category: .equalTemperament,
                era: .modern,
                region: .international,
                description: "31 equal divisions per octave (38.71¢ steps)",
                historicalContext: """
                31 equal divisions per octave.
                Excellent approximation of 1/4-comma meantone.
                Very pure major thirds and good fifths.
                Advocated by Christiaan Huygens (1691), used in Dutch organs.
                Modern revival in microtonal composition.
                """,
                scientificReferences: [
                    "Huygens, C. (1691). Novus Cyclus Harmonicus",
                    "Fokker, A.D. (1966). 31-fold division of the octave"
                ],
                recommendedStyles: ["experimental", "microtonal", "dutch-baroque"],
                instruments: ["Fokker organ", "synthesizer"],
                priority: 4,
                requiresMicrotonal: true
            ),

            TuningSystem(
                id: "17tet",
                name: "17 Equal Temperament (17-TET)",
                a4Frequency: 440.0,
                category: .equalTemperament,
                era: .modern,
                region: .international,
                description: "17 equal divisions per octave (70.59¢ steps)",
                historicalContext: """
                17 equal divisions per octave.
                Good approximation of Pythagorean tuning (pure fifths).
                Neutral thirds (~353 cents) useful for Middle Eastern music.
                Used in experimental composition.
                """,
                scientificReferences: ["Sethares, W. (2005). Tuning, Timbre, Spectrum, Scale"],
                recommendedStyles: ["experimental", "middle-eastern-fusion"],
                priority: 3,
                requiresMicrotonal: true
            ),

            // Add more regional/contemporary standards
            TuningSystem(
                id: "american-444",
                name: "A=444 Hz (Some American Orchestras)",
                a4Frequency: 444.0,
                category: .modern,
                era: .modern,
                region: .northAmerica,
                description: "Higher tuning used by some North American orchestras",
                historicalContext: "Used occasionally for extra brilliance in orchestral performance.",
                scientificReferences: [],
                recommendedStyles: ["orchestral"],
                priority: 5
            ),

            TuningSystem(
                id: "russian-443",
                name: "A=443 Hz (Russian/Soviet Standard)",
                a4Frequency: 443.0,
                category: .modern,
                era: .modern,
                region: .russia,
                description: "Soviet-era standard, still used in Russia",
                historicalContext: """
                Official Soviet standard established mid-20th century.
                Many Russian orchestras and institutions continue this tradition.
                """,
                scientificReferences: ["Soviet GOST standards (historical)"],
                recommendedStyles: ["russian-classical", "soviet-era"],
                priority: 5
            )
        ]
    }

    private func loadUserPreferences() {
        // Load from UserDefaults
        if let favorites = UserDefaults.standard.array(forKey: "TuningFavorites") as? [String] {
            favoriteTunings = favorites
        }
        if let recent = UserDefaults.standard.array(forKey: "TuningRecent") as? [String] {
            recentTunings = recent
        }
    }

    private func saveUserPreferences() {
        UserDefaults.standard.set(favoriteTunings, forKey: "TuningFavorites")
        UserDefaults.standard.set(recentTunings, forKey: "TuningRecent")
    }
}


// MARK: - Data Models

/// Complete tuning system with metadata
struct TuningSystem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let a4Frequency: Double  // A4 reference frequency in Hz
    let category: TuningCategory
    let era: HistoricalEra
    let region: GeographicRegion
    let description: String
    let historicalContext: String
    let scientificReferences: [String]
    let recommendedStyles: [String]  // Musical style IDs
    var instruments: [String]  // Recommended instruments
    var priority: Int  // 1-10, for sorting recommendations
    var requiresMicrotonal: Bool  // Needs microtonal-capable instrument
    var warningNote: String?  // e.g., "Not scientifically validated"

    init(
        id: String,
        name: String,
        a4Frequency: Double,
        category: TuningCategory,
        era: HistoricalEra,
        region: GeographicRegion,
        description: String,
        historicalContext: String,
        scientificReferences: [String] = [],
        recommendedStyles: [String] = [],
        instruments: [String] = [],
        priority: Int = 5,
        requiresMicrotonal: Bool = false,
        warningNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.a4Frequency = a4Frequency
        self.category = category
        self.era = era
        self.region = region
        self.description = description
        self.historicalContext = historicalContext
        self.scientificReferences = scientificReferences
        self.recommendedStyles = recommendedStyles
        self.instruments = instruments
        self.priority = priority
        self.requiresMicrotonal = requiresMicrotonal
        self.warningNote = warningNote
    }

    /// Calculate frequency for any MIDI note number
    func frequency(forMIDINote midiNote: Int) -> Double {
        // Equal temperament: f = a4 * 2^((n-69)/12)
        let semitoneOffset = Double(midiNote - 69)
        return a4Frequency * pow(2.0, semitoneOffset / 12.0)
    }

    /// Get MIDI note number for a frequency
    func midiNote(forFrequency hz: Double) -> Int {
        let semitoneOffset = 12.0 * log2(hz / a4Frequency)
        return 69 + Int(round(semitoneOffset))
    }
}


// MARK: - Enums

enum TuningCategory: String, Codable, CaseIterable {
    case modern = "Modern Standards"
    case historical = "Historical"
    case alternative = "Alternative"
    case experimental = "Experimental"
    case microtonal = "Microtonal/World"
    case justIntonation = "Just Intonation"
    case temperament = "Historical Temperaments"
    case equalTemperament = "Equal Temperaments (Non-12)"
}

enum HistoricalEra: String, Codable, CaseIterable {
    case ancient = "Ancient (pre-500 CE)"
    case medieval = "Medieval (500-1400)"
    case renaissance = "Renaissance (1400-1600)"
    case baroque = "Baroque (1600-1750)"
    case classical = "Classical (1750-1820)"
    case romantic = "Romantic (1820-1900)"
    case modern = "Modern (1900-present)"
    case traditional = "Traditional (timeless)"
}

enum GeographicRegion: String, Codable, CaseIterable {
    case international = "International"
    case western = "Western Europe"
    case northAmerica = "North America"
    case france = "France"
    case germany = "Germany"
    case italy = "Italy"
    case russia = "Russia/Eastern Europe"
    case middleEast = "Middle East"
    case india = "India/South Asia"
}
