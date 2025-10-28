import Foundation

/// Microtonal scale definition system compatible with Scala (.scl/.tun) format
/// Supports:
/// - Cents deviation from 12-TET
/// - Frequency ratios (just intonation)
/// - Arbitrary equal divisions (19-TET, 24-TET, 31-TET, etc.)
/// - Historical temperaments (Werckmeister, Kirnberger, Meantone, etc.)
/// - World music systems (Arabic maqam, Indian śruti, Turkish makam)
///
/// More detailed than Omnisphere's tuning - includes exact interval specifications,
/// historical context, and export to industry-standard formats.
struct MicrotonalScale: Codable, Identifiable, Equatable {

    let id: String
    let name: String
    let description: String

    /// Number of notes per octave (e.g., 12 for standard, 19 for 19-TET, 24 for quarter-tones)
    let notesPerOctave: Int

    /// Interval definitions - either cents or ratios
    let intervals: [Interval]

    /// Reference frequency (typically A4 = 440 Hz)
    let referenceFrequency: Double
    let referenceMIDINote: Int  // Typically 69 (A4)

    /// Metadata
    let category: ScaleCategory
    let historicalContext: String?
    let scalaFileFormat: String  // Actual .scl file content


    // MARK: - Initialization

    /// Create scale from cent deviations
    init(
        id: String,
        name: String,
        description: String,
        centsDeviations: [Double],  // Deviations from 12-TET in cents
        referenceFrequency: Double = 440.0,
        category: ScaleCategory,
        historicalContext: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.notesPerOctave = centsDeviations.count
        self.intervals = centsDeviations.map { .cents($0) }
        self.referenceFrequency = referenceFrequency
        self.referenceMIDINote = 69
        self.category = category
        self.historicalContext = historicalContext

        // Generate Scala format
        var scala = "\(name)\n\(description)\n\(centsDeviations.count)\n"
        for cents in centsDeviations {
            scala += String(format: "%.6f\n", cents)
        }
        scala += "1200.0\n"  // Octave
        self.scalaFileFormat = scala
    }

    /// Create scale from frequency ratios (just intonation)
    init(
        id: String,
        name: String,
        description: String,
        ratios: [(numerator: Int, denominator: Int)],
        referenceFrequency: Double = 440.0,
        category: ScaleCategory,
        historicalContext: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.notesPerOctave = ratios.count
        self.intervals = ratios.map { .ratio($0.numerator, $0.denominator) }
        self.referenceFrequency = referenceFrequency
        self.referenceMIDINote = 69
        self.category = category
        self.historicalContext = historicalContext

        // Generate Scala format
        var scala = "\(name)\n\(description)\n\(ratios.count)\n"
        for ratio in ratios {
            scala += "\(ratio.numerator)/\(ratio.denominator)\n"
        }
        scala += "2/1\n"  // Octave
        self.scalaFileFormat = scala
    }

    /// Create equal temperament scale (N-TET)
    static func equalTemperament(
        divisions: Int,
        name: String? = nil,
        referenceFrequency: Double = 440.0
    ) -> MicrotonalScale {
        let scaleName = name ?? "\(divisions) Equal Temperament (\(divisions)-TET)"
        let centsPerStep = 1200.0 / Double(divisions)
        let centsDeviations = (1...divisions).map { Double($0) * centsPerStep }

        return MicrotonalScale(
            id: "\(divisions)tet",
            name: scaleName,
            description: "\(divisions) equal divisions of the octave",
            centsDeviations: centsDeviations,
            referenceFrequency: referenceFrequency,
            category: .equalTemperament,
            historicalContext: "Equal division of octave into \(divisions) steps"
        )
    }


    // MARK: - Frequency Calculation

    /// Get frequency for a given MIDI note using this microtonal scale
    func frequency(forMIDINote midiNote: Int) -> Double {
        let semitoneOffset = midiNote - referenceMIDINote

        // Determine which scale degree and which octave
        let octaveOffset = semitoneOffset / notesPerOctave
        let scaleIndex = semitoneOffset % notesPerOctave

        // Get interval for this scale degree
        let interval = intervals[scaleIndex < 0 ? scaleIndex + notesPerOctave : scaleIndex]

        // Calculate frequency
        let baseFrequency = referenceFrequency * pow(2.0, Double(octaveOffset))
        return baseFrequency * interval.frequencyMultiplier
    }

    /// Get cents deviation from 12-TET for a MIDI note
    func centsDeviation(forMIDINote midiNote: Int) -> Double {
        let frequency = self.frequency(forMIDINote: midiNote)
        let standardFrequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        return 1200.0 * log2(frequency / standardFrequency)
    }


    // MARK: - Export

    /// Export as Scala .scl file content
    func exportScalaScale() -> String {
        return scalaFileFormat
    }

    /// Export as Scala .tun file (keyboard mapping + scale)
    func exportScalaTuning(keyboardMapping: [Int] = Array(0..<128)) -> String {
        var tun = """
        ; \(name)
        ; \(description)
        ;
        ; Reference frequency: \(referenceFrequency) Hz
        ;
        \(notesPerOctave)
        ;
        """

        for (midiNote, scaleMapping) in keyboardMapping.enumerated() {
            let freq = frequency(forMIDINote: midiNote)
            tun += String(format: "note %d\t%.6f\n", midiNote, freq)
        }

        return tun
    }

    /// Export as MIDI Tuning Standard (MTS) data
    func exportMTS() -> [UInt8] {
        // MIDI Tuning Standard SysEx format
        // F0 7E <device ID> 08 <tuning program> <tuning name> <data> F7
        var mts: [UInt8] = [0xF0, 0x7E, 0x7F, 0x08, 0x01]  // Header

        // Add name (16 bytes, ASCII)
        let nameBytes = name.data(using: .ascii)?.prefix(16) ?? Data()
        mts += nameBytes + Data(count: 16 - nameBytes.count)

        // Add tuning data for all 128 MIDI notes
        for midiNote in 0..<128 {
            let freq = frequency(forMIDINote: midiNote)
            // Convert to MTS format: semitone + 8192ths of a semitone
            let semitones = 12.0 * log2(freq / 440.0) + 69.0
            let semitoneWhole = UInt8(semitones)
            let semitoneFloat = (semitones - floor(semitones)) * 16384.0
            let semitoneHigh = UInt8(Int(semitoneFloat) >> 7)
            let semitoneLow = UInt8(Int(semitoneFloat) & 0x7F)

            mts += [semitoneWhole, semitoneHigh, semitoneLow]
        }

        mts.append(0xF7)  // End of SysEx
        return mts
    }
}


// MARK: - Interval Definition

enum Interval: Codable, Equatable {
    case cents(Double)                    // Cents (1200 cents = 1 octave)
    case ratio(Int, Int)                  // Frequency ratio (numerator/denominator)

    var frequencyMultiplier: Double {
        switch self {
        case .cents(let cents):
            return pow(2.0, cents / 1200.0)
        case .ratio(let num, let den):
            return Double(num) / Double(den)
        }
    }

    var centsValue: Double {
        switch self {
        case .cents(let cents):
            return cents
        case .ratio(let num, let den):
            return 1200.0 * log2(Double(num) / Double(den))
        }
    }
}


// MARK: - Scale Category

enum ScaleCategory: String, Codable, CaseIterable {
    case equalTemperament = "Equal Temperament"
    case justIntonation = "Just Intonation"
    case historicalTemperament = "Historical Temperament"
    case worldMusic = "World Music"
    case experimental = "Experimental"
}


// MARK: - Predefined Microtonal Scales

extension MicrotonalScale {

    /// Library of predefined microtonal scales
    static let library: [MicrotonalScale] = [

        // MARK: - Historical Temperaments

        // Werckmeister III (1691)
        MicrotonalScale(
            id: "werckmeister-iii",
            name: "Werckmeister III",
            description: "Andreas Werckmeister's well-temperament (1691)",
            centsDeviations: [
                0.0,      // C
                90.225,   // C# (tempered)
                192.180,  // D (tempered)
                294.135,  // D# (tempered)
                390.225,  // E (tempered)
                498.045,  // F (pure)
                588.270,  // F# (tempered)
                696.090,  // G (pure)
                792.180,  // G# (tempered)
                888.270,  // A (tempered)
                996.090,  // A# (pure)
                1092.180  // B (tempered)
            ],
            category: .historicalTemperament,
            historicalContext: "One of the first well-temperaments allowing all 24 keys. Each key has unique character."
        ),

        // Quarter-comma meantone
        MicrotonalScale(
            id: "meantone-quarter",
            name: "1/4-Comma Meantone",
            description: "Renaissance/Baroque meantone with pure major thirds",
            centsDeviations: [
                0.0,      // C
                76.049,   // C#
                193.157,  // D
                310.265,  // Eb
                386.314,  // E (pure major third from C)
                503.422,  // F
                579.471,  // F#
                696.578,  // G
                772.627,  // G#
                889.735,  // A
                1006.843, // Bb
                1082.892  // B
            ],
            category: .historicalTemperament,
            historicalContext: "Dominant tuning 1550-1700. Pure major thirds, narrow fifths."
        ),

        // Pythagorean
        MicrotonalScale(
            id: "pythagorean",
            name: "Pythagorean Tuning",
            description: "Ancient Greek tuning, pure 3:2 fifths",
            ratios: [
                (1, 1),      // C (1/1)
                (256, 243),  // C# (Pythagorean minor second)
                (9, 8),      // D (whole tone)
                (32, 27),    // Eb (minor third)
                (81, 64),    // E (Pythagorean major third)
                (4, 3),      // F (perfect fourth)
                (729, 512),  // F# (augmented fourth)
                (3, 2),      // G (perfect fifth)
                (128, 81),   // G# (minor sixth)
                (27, 16),    // A (major sixth)
                (16, 9),     // Bb (minor seventh)
                (243, 128)   // B (major seventh)
            ],
            category: .justIntonation,
            historicalContext: "Attributed to Pythagoras (c. 570-495 BCE). Pure fifths, but thirds are dissonant."
        ),

        // 5-limit Just Intonation (C major)
        MicrotonalScale(
            id: "just-c-major",
            name: "5-Limit Just Intonation (C Major)",
            description: "Pure ratios using primes 2, 3, 5",
            ratios: [
                (1, 1),    // C (1/1)
                (16, 15),  // C# (minor second)
                (9, 8),    // D (major second)
                (6, 5),    // Eb (minor third)
                (5, 4),    // E (major third - pure!)
                (4, 3),    // F (perfect fourth)
                (45, 32),  // F# (augmented fourth)
                (3, 2),    // G (perfect fifth)
                (8, 5),    // G# (minor sixth)
                (5, 3),    // A (major sixth)
                (9, 5),    // Bb (minor seventh)
                (15, 8)    // B (major seventh)
            ],
            category: .justIntonation,
            historicalContext: "Renaissance ideal. Pure major triads in C major, but cannot modulate freely."
        ),

        // MARK: - Equal Temperaments (Non-12)

        // 19-TET
        equalTemperament(
            divisions: 19,
            name: "19 Equal Temperament (19-TET)"
        ),

        // 24-TET (Quarter tones)
        equalTemperament(
            divisions: 24,
            name: "24 Equal Temperament (Quarter Tones)"
        ),

        // 31-TET
        equalTemperament(
            divisions: 31,
            name: "31 Equal Temperament (31-TET)"
        ),

        // 53-TET (Turkish)
        equalTemperament(
            divisions: 53,
            name: "53 Equal Temperament (Turkish Koma)"
        ),

        // 17-TET
        equalTemperament(
            divisions: 17,
            name: "17 Equal Temperament (17-TET)"
        ),

        // MARK: - World Music Scales

        // Arabic Rast Maqam (approximation in 24-TET)
        MicrotonalScale(
            id: "arabic-rast",
            name: "Arabic Maqam Rast",
            description: "Rast maqam with quarter tones",
            centsDeviations: [
                0.0,    // C (Rast)
                200.0,  // D
                350.0,  // E half-flat (neutral third)
                500.0,  // F
                700.0,  // G
                900.0,  // A
                1050.0  // B half-flat
            ],
            category: .worldMusic,
            historicalContext: "One of the primary maqamat in Arabic music. Uses neutral thirds (~350 cents)."
        ),

        // Arabic Bayati Maqam
        MicrotonalScale(
            id: "arabic-bayati",
            name: "Arabic Maqam Bayati",
            description: "Bayati maqam with quarter tones",
            centsDeviations: [
                0.0,    // D (Bayati root)
                150.0,  // E half-flat
                300.0,  // F
                500.0,  // G
                700.0,  // A
                850.0,  // B half-flat
                1000.0  // C
            ],
            category: .worldMusic,
            historicalContext: "Popular maqam in Arabic music. Characteristic 150-cent interval (three-quarter tone)."
        ),

        // Indian Raga Bhairav (approximation)
        MicrotonalScale(
            id: "raga-bhairav",
            name: "Rāga Bhairav",
            description: "North Indian morning raga with distinctive intervals",
            ratios: [
                (1, 1),      // Sa
                (16, 15),    // Re (komal)
                (5, 4),      // Ga
                (4, 3),      // Ma
                (3, 2),      // Pa
                (8, 5),      // Dha (komal)
                (15, 8)      // Ni
            ],
            category: .worldMusic,
            historicalContext: "Serious morning raga in Hindustani classical music. Uses komal (flat) Re and Dha."
        ),

        // MARK: - Experimental Scales

        // Bohlen-Pierce (13 steps per tritave)
        MicrotonalScale(
            id: "bohlen-pierce",
            name: "Bohlen-Pierce Scale",
            description: "13 equal divisions of tritave (3:1 ratio, not octave!)",
            centsDeviations: (1...13).map { Double($0) * (1901.955 / 13.0) },  // 1901.955 cents = tritave
            category: .experimental,
            historicalContext: "Non-octave scale. Uses 3:1 'tritave' instead of 2:1 octave. Entirely alien harmony."
        ),

        // Wendy Carlos Alpha (78.0 cents per step)
        MicrotonalScale(
            id: "carlos-alpha",
            name: "Wendy Carlos Alpha Scale",
            description: "15.385 steps per octave, optimizes major/minor thirds",
            centsDeviations: (1...15).map { Double($0) * 78.0 },
            category: .experimental,
            historicalContext: "Created by Wendy Carlos (1986). Used in album 'Beauty in the Beast'."
        ),

        // Wendy Carlos Beta (63.8 cents)
        MicrotonalScale(
            id: "carlos-beta",
            name: "Wendy Carlos Beta Scale",
            description: "18.809 steps per octave",
            centsDeviations: (1...18).map { Double($0) * 63.8 },
            category: .experimental,
            historicalContext: "Wendy Carlos experimental scale. Optimizes perfect fifths."
        )
    ]

    /// Get scale by ID from library
    static func getScale(id: String) -> MicrotonalScale? {
        return library.first { $0.id == id }
    }

    /// Get all scales of a specific category
    static func getScales(category: ScaleCategory) -> [MicrotonalScale] {
        return library.filter { $0.category == category }
    }
}
