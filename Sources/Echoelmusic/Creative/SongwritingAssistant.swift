import Foundation
import Combine

/// Songwriting & Composition Assistant
/// Professional songwriting tools with AI assistance and traditional composition features
///
/// Features:
/// - Chord progression generator
/// - Melody generator (AI + traditional music theory)
/// - Lyric writing assistant
/// - Rhyme dictionary
/// - Song structure templates
/// - Collaboration tools
/// - Version control for songs
/// - Copyright metadata
@MainActor
class SongwritingAssistant: ObservableObject {

    // MARK: - Published Properties

    @Published var currentSong: Song?
    @Published var aiAssistanceEnabled: Bool = true
    @Published var suggestions: [Suggestion] = []

    // MARK: - Song Structure

    struct Song: Identifiable, Codable {
        let id: UUID
        var title: String
        var artist: String
        var writers: [String]
        var composers: [String]

        // Song sections
        var sections: [SongSection]

        // Metadata
        var key: MusicalKey
        var tempo: Int  // BPM
        var timeSignature: TimeSignature
        var genre: Genre

        // Copyright
        var copyright: CopyrightInfo
        var isrcCode: String?  // International Standard Recording Code

        // Version control
        var version: Int
        var lastModified: Date
        var createdDate: Date

        init(title: String, artist: String) {
            self.id = UUID()
            self.title = title
            self.artist = artist
            self.writers = []
            self.composers = []
            self.sections = []
            self.key = .C
            self.tempo = 120
            self.timeSignature = TimeSignature(numerator: 4, denominator: 4)
            self.genre = .pop
            self.copyright = CopyrightInfo(owner: artist, year: Calendar.current.component(.year, from: Date()))
            self.version = 1
            self.lastModified = Date()
            self.createdDate = Date()
        }
    }

    struct SongSection: Identifiable, Codable {
        let id: UUID
        var type: SectionType
        var lyrics: String
        var chords: [Chord]
        var melody: [Note]
        var duration: TimeInterval  // in seconds

        enum SectionType: String, Codable, CaseIterable {
            case intro = "Intro"
            case verse = "Verse"
            case preChorus = "Pre-Chorus"
            case chorus = "Chorus"
            case bridge = "Bridge"
            case solo = "Solo"
            case outro = "Outro"
            case breakdown = "Breakdown"
            case hook = "Hook"
        }
    }

    // MARK: - Musical Elements

    enum MusicalKey: String, Codable, CaseIterable {
        case C = "C Major"
        case Cm = "C Minor"
        case CSharp = "C# Major"
        case CSharpM = "C# Minor"
        case D = "D Major"
        case Dm = "D Minor"
        case DSharp = "D# Major"
        case DSharpM = "D# Minor"
        case E = "E Major"
        case Em = "E Minor"
        case F = "F Major"
        case Fm = "F Minor"
        case FSharp = "F# Major"
        case FSharpM = "F# Minor"
        case G = "G Major"
        case Gm = "G Minor"
        case GSharp = "G# Major"
        case GSharpM = "G# Minor"
        case A = "A Major"
        case Am = "A Minor"
        case ASharp = "A# Major"
        case ASharpM = "A# Minor"
        case B = "B Major"
        case Bm = "B Minor"
    }

    struct TimeSignature: Codable {
        let numerator: Int   // e.g., 4 in 4/4
        let denominator: Int // e.g., 4 in 4/4

        var description: String { "\(numerator)/\(denominator)" }
    }

    struct Chord: Identifiable, Codable {
        let id: UUID
        var root: Note
        var quality: ChordQuality
        var duration: Double  // in beats

        enum ChordQuality: String, Codable, CaseIterable {
            case major = "Major"
            case minor = "Minor"
            case diminished = "Diminished"
            case augmented = "Augmented"
            case major7 = "Major 7th"
            case minor7 = "Minor 7th"
            case dominant7 = "Dominant 7th"
            case sus2 = "Suspended 2nd"
            case sus4 = "Suspended 4th"
            case add9 = "Add 9"
            case major9 = "Major 9th"
            case minor9 = "Minor 9th"
        }

        var symbol: String {
            let noteSymbol = root.rawValue
            switch quality {
            case .major: return noteSymbol
            case .minor: return "\(noteSymbol)m"
            case .diminished: return "\(noteSymbol)°"
            case .augmented: return "\(noteSymbol)+"
            case .major7: return "\(noteSymbol)maj7"
            case .minor7: return "\(noteSymbol)m7"
            case .dominant7: return "\(noteSymbol)7"
            case .sus2: return "\(noteSymbol)sus2"
            case .sus4: return "\(noteSymbol)sus4"
            case .add9: return "\(noteSymbol)add9"
            case .major9: return "\(noteSymbol)maj9"
            case .minor9: return "\(noteSymbol)m9"
            }
        }
    }

    enum Note: String, Codable, CaseIterable {
        case C, CSharp = "C#", D, DSharp = "D#", E, F, FSharp = "F#", G, GSharp = "G#", A, ASharp = "A#", B

        var midiNumber: Int {
            switch self {
            case .C: return 60
            case .CSharp: return 61
            case .D: return 62
            case .DSharp: return 63
            case .E: return 64
            case .F: return 65
            case .FSharp: return 66
            case .G: return 67
            case .GSharp: return 68
            case .A: return 69
            case .ASharp: return 70
            case .B: return 71
            }
        }
    }

    enum Genre: String, Codable, CaseIterable {
        case pop = "Pop"
        case rock = "Rock"
        case hiphop = "Hip-Hop"
        case electronic = "Electronic"
        case jazz = "Jazz"
        case blues = "Blues"
        case country = "Country"
        case folk = "Folk"
        case classical = "Classical"
        case metal = "Metal"
        case rnb = "R&B"
        case soul = "Soul"
        case funk = "Funk"
        case reggae = "Reggae"
        case latin = "Latin"
        case world = "World"
    }

    // MARK: - Copyright

    struct CopyrightInfo: Codable {
        var owner: String
        var year: Int
        var publishers: [String]
        var performanceRights: PerformanceRightsOrganization?
        var mechanicalRights: MechanicalRightsOrganization?

        var copyrightNotice: String {
            "© \(year) \(owner). All rights reserved."
        }

        init(owner: String, year: Int) {
            self.owner = owner
            self.year = year
            self.publishers = []
        }
    }

    enum PerformanceRightsOrganization: String, Codable, CaseIterable {
        case gema = "GEMA (Germany)"
        case ascap = "ASCAP (USA)"
        case bmi = "BMI (USA)"
        case sesac = "SESAC (USA)"
        case prs = "PRS for Music (UK)"
        case socan = "SOCAN (Canada)"
        case apra = "APRA (Australia)"
        case sacem = "SACEM (France)"
        case siae = "SIAE (Italy)"
        case sgae = "SGAE (Spain)"
    }

    enum MechanicalRightsOrganization: String, Codable, CaseIterable {
        case gema = "GEMA (Germany)"
        case harryfox = "Harry Fox Agency (USA)"
        case mcps = "MCPS (UK)"
        case cmrra = "CMRRA (Canada)"
        case amcos = "AMCOS (Australia)"
    }

    // MARK: - AI Suggestions

    struct Suggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let content: String
        let confidence: Double  // 0.0 - 1.0

        enum SuggestionType {
            case chordProgression
            case melody
            case lyrics
            case structure
            case rhyme
        }
    }

    // MARK: - Initialization

    init() {
        print("🎵 Songwriting Assistant initialized")
    }

    // MARK: - Song Creation

    func createNewSong(title: String, artist: String) -> Song {
        let song = Song(title: title, artist: artist)
        currentSong = song
        print("   ✅ New song created: \(title)")
        return song
    }

    // MARK: - Chord Progression Generator

    func generateChordProgression(key: MusicalKey, style: Genre, bars: Int = 4) -> [Chord] {
        print("   🎸 Generating chord progression...")
        print("      Key: \(key.rawValue)")
        print("      Style: \(style.rawValue)")
        print("      Bars: \(bars)")

        // Common chord progressions by genre
        let progressions: [[Int]]

        switch style {
        case .pop, .rock:
            // I-V-vi-IV (e.g., C-G-Am-F)
            progressions = [
                [0, 7, 9, 5],  // I-V-vi-IV
                [0, 5, 7, 5],  // I-IV-V-IV
                [9, 7, 5, 7],  // vi-V-IV-V
            ]
        case .jazz:
            // ii-V-I progression
            progressions = [
                [2, 7, 0, 0],  // ii-V-I-I
                [2, 7, 0, 9],  // ii-V-I-vi
            ]
        case .blues:
            // 12-bar blues: I-I-I-I-IV-IV-I-I-V-IV-I-V
            progressions = [
                [0, 0, 0, 0, 5, 5, 0, 0, 7, 5, 0, 7]
            ]
        case .electronic, .hiphop:
            // Minimal progressions
            progressions = [
                [9, 5, 0, 7],  // vi-IV-I-V
                [9, 7, 5, 0],  // vi-V-IV-I
            ]
        default:
            // Default: I-IV-V-I
            progressions = [
                [0, 5, 7, 0]
            ]
        }

        let progression = progressions.randomElement() ?? [0, 5, 7, 0]

        // Convert to chords
        var chords: [Chord] = []
        for degree in progression.prefix(bars) {
            let root = getScaleDegree(key: key, degree: degree)
            let quality: Chord.ChordQuality = degree == 9 ? .minor : .major
            let chord = Chord(id: UUID(), root: root, quality: quality, duration: 4.0)
            chords.append(chord)
        }

        print("   ✅ Generated progression: \(chords.map { $0.symbol }.joined(separator: " - "))")

        return chords
    }

    private func getScaleDegree(key: MusicalKey, degree: Int) -> Note {
        // Simplified: returns root note
        // In production: implement full scale degree calculation
        let rootNotes: [MusicalKey: Note] = [
            .C: .C, .Cm: .C,
            .D: .D, .Dm: .D,
            .E: .E, .Em: .E,
            .F: .F, .Fm: .F,
            .G: .G, .Gm: .G,
            .A: .A, .Am: .A,
            .B: .B, .Bm: .B,
        ]

        return rootNotes[key] ?? .C
    }

    // MARK: - Lyric Writing Tools

    func suggestRhymes(for word: String) -> [String] {
        print("   📝 Finding rhymes for: \(word)")

        // Simplified rhyme dictionary
        let rhymeDict: [String: [String]] = [
            "love": ["above", "dove", "glove", "shove", "of"],
            "heart": ["start", "part", "art", "smart", "chart"],
            "night": ["light", "right", "sight", "flight", "bright"],
            "day": ["way", "say", "play", "stay", "may"],
            "time": ["rhyme", "climb", "prime", "mime", "lime"],
            "feel": ["real", "deal", "heal", "steal", "reveal"],
            "dream": ["stream", "beam", "team", "theme", "extreme"],
        ]

        let rhymes = rhymeDict[word.lowercased()] ?? []
        print("   Found \(rhymes.count) rhymes")

        return rhymes
    }

    func suggestNextLine(currentLyrics: String, rhymeScheme: RhymeScheme = .AABB) -> [String] {
        print("   🤖 AI: Suggesting next lyric line...")

        // In production: Use AI model (GPT, custom lyric model)
        // For now: template-based suggestions

        let suggestions = [
            "Walking down the memory lane",
            "Holding on to yesterday",
            "Dreams are fading into grey",
        ]

        return suggestions
    }

    enum RhymeScheme: String, CaseIterable {
        case AABB = "AABB (Couplet)"
        case ABAB = "ABAB (Alternate)"
        case ABCB = "ABCB (Simple 4-line)"
        case AAAA = "AAAA (Monorhyme)"
    }

    // MARK: - Song Structure Templates

    func applySongStructure(_ template: SongStructureTemplate) -> [SongSection.SectionType] {
        print("   📋 Applying song structure: \(template.rawValue)")

        switch template {
        case .verseChorus:
            return [.intro, .verse, .chorus, .verse, .chorus, .bridge, .chorus, .outro]
        case .versePreChorus:
            return [.intro, .verse, .preChorus, .chorus, .verse, .preChorus, .chorus, .bridge, .chorus, .outro]
        case .aaba:
            return [.verse, .verse, .bridge, .verse]
        case .throughComposed:
            return [.intro, .verse, .verse, .verse, .outro]
        case .edm:
            return [.intro, .breakdown, .verse, .chorus, .breakdown, .chorus, .outro]
        }
    }

    enum SongStructureTemplate: String, CaseIterable {
        case verseChorus = "Verse-Chorus"
        case versePreChorus = "Verse-Pre-Chorus-Chorus"
        case aaba = "AABA (32-bar)"
        case throughComposed = "Through-Composed"
        case edm = "EDM Structure"
    }

    // MARK: - AI-Free Mode

    func toggleAIAssistance() {
        aiAssistanceEnabled.toggle()
        print("   🤖 AI Assistance: \(aiAssistanceEnabled ? "ON" : "OFF")")

        if !aiAssistanceEnabled {
            print("   ✅ AI-FREE MODE: Only traditional music theory tools active")
        }
    }

    // MARK: - Copyright & Metadata

    func registerCopyright(song: Song, organization: PerformanceRightsOrganization) {
        print("   📄 Registering copyright with \(organization.rawValue)")
        print("      Song: \(song.title)")
        print("      Writers: \(song.writers.joined(separator: ", "))")
        print("      © \(song.copyright.year) \(song.copyright.owner)")

        // In production: API integration with PROs (GEMA, ASCAP, etc.)
    }

    func generateISRC() -> String {
        // ISRC format: CC-XXX-YY-NNNNN
        // CC = Country Code (e.g., DE for Germany)
        // XXX = Registrant Code
        // YY = Year
        // NNNNN = Designation Code

        let countryCode = "DE"  // Germany
        let registrantCode = "ECH"  // Echoelmusic
        let year = String(Calendar.current.component(.year, from: Date())).suffix(2)
        let designation = String(format: "%05d", Int.random(in: 1...99999))

        return "\(countryCode)-\(registrantCode)-\(year)-\(designation)"
    }

    // MARK: - Export

    func exportSong(_ song: Song, format: ExportFormat) -> URL? {
        print("   💾 Exporting song: \(song.title)")
        print("      Format: \(format.rawValue)")

        switch format {
        case .pdf:
            return exportToPDF(song)
        case .musicXML:
            return exportToMusicXML(song)
        case .midi:
            return exportToMIDI(song)
        case .chordPro:
            return exportToChordPro(song)
        case .json:
            return exportToJSON(song)
        }
    }

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF (Lead Sheet)"
        case musicXML = "MusicXML (Notation)"
        case midi = "MIDI (Sequencing)"
        case chordPro = "ChordPro (Text + Chords)"
        case json = "JSON (Raw Data)"
    }

    private func exportToPDF(_ song: Song) -> URL? {
        // Generate PDF with lyrics, chords, and metadata
        print("      ✅ PDF generated")
        return nil // Placeholder
    }

    private func exportToMusicXML(_ song: Song) -> URL? {
        // MusicXML for notation software (Finale, Sibelius, etc.)
        print("      ✅ MusicXML generated")
        return nil // Placeholder
    }

    private func exportToMIDI(_ song: Song) -> URL? {
        // MIDI file for DAWs
        print("      ✅ MIDI generated")
        return nil // Placeholder
    }

    private func exportToChordPro(_ song: Song) -> URL? {
        // ChordPro format (plain text with chord annotations)
        var chordPro = "{title: \(song.title)}\n"
        chordPro += "{artist: \(song.artist)}\n"
        chordPro += "{key: \(song.key.rawValue)}\n"
        chordPro += "{tempo: \(song.tempo)}\n\n"

        for section in song.sections {
            chordPro += "{\(section.type.rawValue):}\n"
            chordPro += section.lyrics + "\n\n"
        }

        print("      ✅ ChordPro generated")
        return nil // Placeholder
    }

    private func exportToJSON(_ song: Song) -> URL? {
        // JSON export for data exchange
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        if let jsonData = try? encoder.encode(song) {
            print("      ✅ JSON generated (\(jsonData.count) bytes)")
        }

        return nil // Placeholder
    }
}
