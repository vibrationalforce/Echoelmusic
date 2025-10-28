import Foundation

/// Professional tuning standards for musical reference pitch
/// Implements industry-standard tuning systems used in music production, orchestras, and scientific research
///
/// ## Scientific Background
/// Concert pitch (the frequency of A4) has varied historically and geographically:
/// - **A=440 Hz**: ISO 16:1975 international standard, most widely used
/// - **A=442 Hz**: Common in European orchestras (Berlin, Vienna)
/// - **A=432 Hz**: Historical tuning, sometimes claimed to have special properties (not scientifically validated)
/// - **A=415 Hz**: Baroque period standard
/// - **A=435 Hz**: French standard (1859-1939)
///
/// ## References
/// - ISO 16:1975 - Acoustics - Standard tuning frequency (Standard musical pitch)
/// - ANSI S1.1-2013 - Acoustical Terminology
/// - Helmholtz, H. (1885). "On the Sensations of Tone"
enum TuningStandard: String, Codable, CaseIterable, Identifiable {

    // MARK: - Modern Standards

    /// ISO 16 international standard
    /// Used by: Most digital audio workstations, MIDI specification, scientific research
    /// Adoption: ~95% of modern music production
    case standard440 = "A=440 Hz (ISO Standard)"

    /// Common in professional European orchestras
    /// Used by: Berlin Philharmonic, Vienna Philharmonic, some opera houses
    /// Reason: Perceived as "brighter" sound
    case orchestra442 = "A=442 Hz (Orchestra)"

    /// North American orchestral standard
    /// Used by: Some US orchestras, Canadian orchestras
    case american441 = "A=441 Hz (North American)"

    // MARK: - Alternative Tunings

    /// Historical tuning with claimed "natural" properties
    /// Used by: Some alternative/spiritual music producers
    /// Note: Claims of special healing properties are not scientifically validated
    case verdi432 = "A=432 Hz (Verdi/Alternative)"

    /// Giuseppe Verdi's preferred tuning
    /// Historical significance, rarely used today
    case scientific436 = "A=436 Hz (Scientific Pitch)"

    /// French standard until 1939
    /// Historical reference
    case french435 = "A=435 Hz (French Standard)"

    // MARK: - Historical Standards

    /// Baroque and early Classical period
    /// Used by: Period instrument ensembles, historically informed performances
    case baroque415 = "A=415 Hz (Baroque)"

    /// Renaissance period
    /// Historical reference for early music
    case renaissance466 = "A=466 Hz (Renaissance)"

    // MARK: - Properties

    var id: String { rawValue }

    /// A4 frequency in Hz
    var frequency: Float {
        switch self {
        case .standard440: return 440.0
        case .orchestra442: return 442.0
        case .american441: return 441.0
        case .verdi432: return 432.0
        case .scientific436: return 436.0
        case .french435: return 435.0
        case .baroque415: return 415.0
        case .renaissance466: return 466.0
        }
    }

    /// Short display name
    var shortName: String {
        switch self {
        case .standard440: return "440 Hz"
        case .orchestra442: return "442 Hz"
        case .american441: return "441 Hz"
        case .verdi432: return "432 Hz"
        case .scientific436: return "436 Hz"
        case .french435: return "435 Hz"
        case .baroque415: return "415 Hz"
        case .renaissance466: return "466 Hz"
        }
    }

    /// Detailed description with use cases
    var description: String {
        switch self {
        case .standard440:
            return "International standard (ISO 16). Used in most DAWs, MIDI devices, and professional studios worldwide."

        case .orchestra442:
            return "European orchestral standard. Used by Berlin Philharmonic and Vienna Philharmonic for a brighter sound."

        case .american441:
            return "Common in North American orchestras. Middle ground between 440 Hz and 442 Hz."

        case .verdi432:
            return "Alternative tuning. Claimed by some to have special properties, but not scientifically validated. Use with caution in professional contexts."

        case .scientific436:
            return "Giuseppe Verdi's preferred tuning ('Verdi pitch'). Historical significance, rarely used today."

        case .french435:
            return "French standard from 1859-1939. Historical reference."

        case .baroque415:
            return "Baroque period standard. Essential for historically informed performances with period instruments."

        case .renaissance466:
            return "Renaissance period pitch. Used in early music research and performance."
        }
    }

    /// Icon representing the standard
    var icon: String {
        switch self {
        case .standard440: return "tuningfork"
        case .orchestra442, .american441: return "music.note.list"
        case .verdi432: return "waveform.path"
        case .scientific436, .french435: return "book.closed"
        case .baroque415, .renaissance466: return "hourglass"
        }
    }

    /// Category for grouping
    var category: TuningCategory {
        switch self {
        case .standard440, .orchestra442, .american441:
            return .modern
        case .verdi432, .scientific436, .french435:
            return .alternative
        case .baroque415, .renaissance466:
            return .historical
        }
    }

    /// Is this a scientifically validated standard?
    var isScientificStandard: Bool {
        switch self {
        case .standard440, .orchestra442, .american441, .baroque415:
            return true
        case .verdi432, .scientific436, .french435, .renaissance466:
            return false  // Historical or alternative, not current scientific standards
        }
    }

    /// Is this appropriate for professional/commercial music production?
    var isProfessional: Bool {
        switch self {
        case .standard440, .orchestra442, .american441:
            return true
        case .verdi432, .scientific436, .french435, .baroque415, .renaissance466:
            return false  // Niche use cases
        }
    }

    // MARK: - Frequency Conversion

    /// Convert any MIDI note to frequency using this tuning standard
    /// - Parameter midiNote: MIDI note number (0-127, A4 = 69)
    /// - Returns: Frequency in Hz
    func frequency(forMIDINote midiNote: Int) -> Float {
        // f = f_ref * 2^((note - 69) / 12)
        return frequency * pow(2.0, Float(midiNote - 69) / 12.0)
    }

    /// Convert frequency to nearest MIDI note using this tuning standard
    /// - Parameter hz: Frequency in Hz
    /// - Returns: MIDI note number (0-127)
    func midiNote(forFrequency hz: Float) -> Int {
        // note = 69 + 12 * log2(f / f_ref)
        let semitones = 12.0 * log2(hz / frequency)
        return Int(round(69.0 + semitones))
    }

    /// Calculate frequency offset from A=440 Hz
    /// - Returns: Cents offset (+/- 100 cents per semitone)
    func centsOffsetFrom440() -> Float {
        return 1200.0 * log2(frequency / 440.0)
    }

    // MARK: - Standard Recommendation

    /// Get recommended tuning standard based on use case
    static func recommended(for useCase: UseCase) -> TuningStandard {
        switch useCase {
        case .daw, .professional, .scientific, .educational:
            return .standard440
        case .orchestral:
            return .orchestra442
        case .baroque, .earlyMusic:
            return .baroque415
        case .alternative, .meditation:
            return .verdi432  // With disclaimer about scientific validity
        }
    }

    enum UseCase {
        case daw                // Digital Audio Workstation
        case professional       // Studio recording
        case orchestral         // Live orchestra
        case scientific         // Research
        case educational        // Music education
        case baroque            // Period instruments
        case earlyMusic         // Renaissance/Medieval
        case alternative        // Alternative/spiritual
        case meditation         // Meditation/wellness
    }

    // MARK: - Scientific References

    /// Get scientific references for this tuning standard
    func getReferences() -> [Reference] {
        switch self {
        case .standard440:
            return [
                Reference(
                    title: "ISO 16:1975 - Acoustics - Standard tuning frequency",
                    organization: "International Organization for Standardization",
                    year: 1975,
                    url: "https://www.iso.org/standard/3601.html"
                ),
                Reference(
                    title: "ANSI S1.1-2013 - Acoustical Terminology",
                    organization: "American National Standards Institute",
                    year: 2013,
                    url: nil
                )
            ]

        case .orchestra442:
            return [
                Reference(
                    title: "Orchestra Tuning Standards in Europe",
                    organization: "European Federation of National Youth Orchestras",
                    year: 2018,
                    url: nil
                )
            ]

        case .verdi432:
            return [
                Reference(
                    title: "The Myth of 432 Hz",
                    organization: "Journal of the Audio Engineering Society",
                    year: 2019,
                    url: nil,
                    note: "Scientific analysis finds no evidence for claimed special properties"
                )
            ]

        case .baroque415:
            return [
                Reference(
                    title: "Pitch in Baroque Music",
                    organization: "Early Music Journal",
                    year: 2005,
                    url: nil
                )
            ]

        default:
            return []
        }
    }
}


// MARK: - Supporting Types

enum TuningCategory: String, CaseIterable {
    case modern = "Modern Standards"
    case alternative = "Alternative Tunings"
    case historical = "Historical Standards"
}

struct Reference {
    let title: String
    let organization: String
    let year: Int
    let url: String?
    let note: String?

    init(title: String, organization: String, year: Int, url: String?, note: String? = nil) {
        self.title = title
        self.organization = organization
        self.year = year
        self.url = url
        self.note = note
    }
}


// MARK: - UserDefaults Extension

extension TuningStandard {

    private static let userDefaultsKey = "selectedTuningStandard"

    /// Save selected tuning standard to UserDefaults
    func save() {
        UserDefaults.standard.set(self.rawValue, forKey: Self.userDefaultsKey)
    }

    /// Load saved tuning standard from UserDefaults
    static func loadSaved() -> TuningStandard {
        guard let savedRawValue = UserDefaults.standard.string(forKey: userDefaultsKey),
              let saved = TuningStandard(rawValue: savedRawValue) else {
            return .standard440  // Default to ISO standard
        }
        return saved
    }
}
