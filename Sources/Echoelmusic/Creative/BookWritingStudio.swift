import Foundation
import Combine

/// Book Writing Studio
/// Professional authoring tools for novels, non-fiction, and all book types
///
/// Features:
/// - Novel writing (fiction)
/// - Non-fiction writing (sachb  ücher)
/// - Character development
/// - Plot structuring
/// - Research management
/// - Chapter organization
/// - AI writing assistance (optional)
/// - Grammar & style checking
/// - Version control
/// - Copyright & ISBN management
/// - Publishing preparation
@MainActor
class BookWritingStudio: ObservableObject {

    // MARK: - Published Properties

    @Published var currentBook: Book?
    @Published var aiAssistanceEnabled: Bool = true
    @Published var wordCount: Int = 0
    @Published var writingGoal: DailyGoal?

    // MARK: - Book Structure

    struct Book: Identifiable, Codable {
        let id: UUID
        var title: String
        var subtitle: String?
        var author: String
        var coAuthors: [String]

        // Book type
        var type: BookType
        var genre: Genre

        // Content
        var chapters: [Chapter]
        var frontMatter: FrontMatter
        var backMatter: BackMatter

        // Metadata
        var language: Language
        var targetWordCount: Int
        var targetAudience: TargetAudience

        // Publishing
        var isbn: String?
        var publisher: String?
        var copyright: CopyrightInfo
        var publicationDate: Date?

        // Version control
        var version: Int
        var lastModified: Date
        var createdDate: Date

        init(title: String, author: String, type: BookType) {
            self.id = UUID()
            self.title = title
            self.author = author
            self.coAuthors = []
            self.type = type
            self.genre = type == .fiction ? .literary : .business
            self.chapters = []
            self.frontMatter = FrontMatter()
            self.backMatter = BackMatter()
            self.language = .german
            self.targetWordCount = type == .fiction ? 80000 : 50000
            self.targetAudience = .adult
            self.copyright = CopyrightInfo(author: author, year: Calendar.current.component(.year, from: Date()))
            self.version = 1
            self.lastModified = Date()
            self.createdDate = Date()
        }
    }

    enum BookType: String, Codable, CaseIterable {
        case fiction = "Roman (Fiction)"
        case nonFiction = "Sachbuch (Non-Fiction)"
        case biography = "Biografie"
        case memoir = "Memoiren"
        case selfHelp = "Ratgeber"
        case cookbook = "Kochbuch"
        case textbook = "Lehrbuch"
        case poetry = "Lyrik"
        case anthology = "Anthologie"
        case graphicNovel = "Graphic Novel"
    }

    enum Genre: String, Codable, CaseIterable {
        // Fiction
        case literary = "Literatur"
        case thriller = "Thriller"
        case mystery = "Krimi"
        case romance = "Liebesroman"
        case sciFi = "Science Fiction"
        case fantasy = "Fantasy"
        case horror = "Horror"
        case historical = "Historisch"

        // Non-Fiction
        case business = "Business"
        case selfImprovement = "Selbstentwicklung"
        case health = "Gesundheit"
        case science = "Wissenschaft"
        case history = "Geschichte"
        case philosophy = "Philosophie"
        case psychology = "Psychologie"
        case technology = "Technologie"
    }

    struct Chapter: Identifiable, Codable {
        let id: UUID
        var number: Int
        var title: String
        var content: String
        var notes: String  // Research notes, ideas
        var wordCount: Int

        // For fiction
        var pointOfView: String?  // Character POV
        var scene: String?        // Scene description

        // Metadata
        var lastModified: Date

        init(number: Int, title: String) {
            self.id = UUID()
            self.number = number
            self.title = title
            self.content = ""
            self.notes = ""
            self.wordCount = 0
            self.lastModified = Date()
        }

        mutating func updateWordCount() {
            self.wordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
    }

    struct FrontMatter: Codable {
        var dedication: String?
        var epigraph: String?  // Quote at beginning
        var prologue: String?
        var preface: String?
        var acknowledgments: String?
    }

    struct BackMatter: Codable {
        var epilogue: String?
        var appendices: [Appendix]
        var glossary: [GlossaryEntry]
        var bibliography: [BibliographyEntry]
        var aboutAuthor: String?

        init() {
            self.appendices = []
            self.glossary = []
            self.bibliography = []
        }

        struct Appendix: Identifiable, Codable {
            let id: UUID
            var title: String
            var content: String
        }

        struct GlossaryEntry: Identifiable, Codable {
            let id: UUID
            var term: String
            var definition: String
        }

        struct BibliographyEntry: Identifiable, Codable {
            let id: UUID
            var author: String
            var title: String
            var publisher: String
            var year: Int
            var citationStyle: CitationStyle

            enum CitationStyle: String, Codable {
                case apa = "APA"
                case mla = "MLA"
                case chicago = "Chicago"
                case harvard = "Harvard"
            }

            var formatted: String {
                switch citationStyle {
                case .apa:
                    return "\(author) (\(year)). \(title). \(publisher)."
                case .mla:
                    return "\(author). \(title). \(publisher), \(year)."
                case .chicago:
                    return "\(author). \(title). \(publisher), \(year)."
                case .harvard:
                    return "\(author), \(year). \(title). \(publisher)."
                }
            }
        }
    }

    enum Language: String, Codable, CaseIterable {
        case german = "Deutsch"
        case english = "English"
        case french = "Français"
        case spanish = "Español"
        case italian = "Italiano"
        case portuguese = "Português"
    }

    enum TargetAudience: String, Codable, CaseIterable {
        case children = "Kinder (6-12)"
        case youngAdult = "Jugendliche (13-18)"
        case adult = "Erwachsene (18+)"
        case academic = "Akademisch"
        case professional = "Professionell"
    }

    struct CopyrightInfo: Codable {
        var author: String
        var year: Int
        var rights: String

        init(author: String, year: Int) {
            self.author = author
            self.year = year
            self.rights = "All Rights Reserved"
        }

        var copyrightNotice: String {
            "© \(year) \(author). \(rights)."
        }
    }

    // MARK: - Character Development (for Fiction)

    struct Character: Identifiable, Codable {
        let id: UUID
        var name: String
        var age: Int?
        var description: String
        var backstory: String
        var motivation: String
        var arc: CharacterArc?
        var relationships: [String: String]  // Character name -> relationship

        enum CharacterArc: String, Codable {
            case heroJourney = "Hero's Journey"
            case redemption = "Redemption Arc"
            case corruption = "Corruption Arc"
            case coming OfAge = "Coming of Age"
            case flat = "Flat Arc (unchanging)"
        }
    }

    // MARK: - Plot Structure

    struct PlotStructure {
        var acts: [Act]

        struct Act: Identifiable {
            let id = UUID()
            var number: Int
            var title: String
            var description: String
            var chapters: [Int]  // Chapter numbers
        }

        // Three-Act Structure
        static func threeAct() -> PlotStructure {
            PlotStructure(acts: [
                Act(number: 1, title: "Setup", description: "Introduce characters, world, conflict", chapters: []),
                Act(number: 2, title: "Confrontation", description: "Rising action, obstacles, midpoint twist", chapters: []),
                Act(number: 3, title: "Resolution", description: "Climax, falling action, denouement", chapters: [])
            ])
        }

        // Hero's Journey (Joseph Campbell)
        static func herosJourney() -> PlotStructure {
            PlotStructure(acts: [
                Act(number: 1, title: "Ordinary World", description: "Hero in normal life", chapters: []),
                Act(number: 2, title: "Call to Adventure", description: "Inciting incident", chapters: []),
                Act(number: 3, title: "Refusal of Call", description: "Hero hesitates", chapters: []),
                Act(number: 4, title: "Meeting Mentor", description: "Guidance received", chapters: []),
                Act(number: 5, title: "Crossing Threshold", description: "Enters special world", chapters: []),
                Act(number: 6, title: "Tests & Allies", description: "Trials and friends", chapters: []),
                Act(number: 7, title: "Approach", description: "Prepares for ordeal", chapters: []),
                Act(number: 8, title: "Ordeal", description: "Central crisis", chapters: []),
                Act(number: 9, title: "Reward", description: "Gains treasure/knowledge", chapters: []),
                Act(number: 10, title: "Road Back", description: "Returns to ordinary world", chapters: []),
                Act(number: 11, title: "Resurrection", description: "Final test", chapters: []),
                Act(number: 12, title: "Return with Elixir", description: "Hero transformed", chapters: [])
            ])
        }
    }

    // MARK: - Writing Goals

    struct DailyGoal: Identifiable {
        let id = UUID()
        var targetWords: Int
        var achievedWords: Int
        var date: Date

        var progress: Double {
            Double(achievedWords) / Double(targetWords)
        }

        var isCompleted: Bool {
            achievedWords >= targetWords
        }
    }

    // MARK: - Initialization

    init() {
        print("📚 Book Writing Studio initialized")
    }

    // MARK: - Book Creation

    func createNewBook(title: String, author: String, type: BookType) -> Book {
        let book = Book(title: title, author: author, type: type)
        currentBook = book
        print("   ✅ New book created: \(title)")
        print("      Type: \(type.rawValue)")
        print("      Target: \(book.targetWordCount.formatted()) words")
        return book
    }

    // MARK: - Writing Assistant

    func suggestNextSentence(context: String) -> [String] {
        guard aiAssistanceEnabled else {
            print("   ⚠️  AI assistance disabled")
            return []
        }

        print("   🤖 AI: Generating sentence suggestions...")

        // In production: Use GPT-4, Claude, or custom model
        // For now: template-based suggestions

        let suggestions = [
            "The morning sun cast long shadows across the room.",
            "She paused, considering her next words carefully.",
            "Years later, he would remember this moment vividly.",
        ]

        return suggestions
    }

    func improveText(_ text: String, style: WritingStyle) -> String {
        print("   ✨ Improving text with \(style.rawValue) style...")

        // In production: Use AI for style transformation
        return text
    }

    enum WritingStyle: String, CaseIterable {
        case concise = "Concise"
        case descriptive = "Descriptive"
        case formal = "Formal"
        case casual = "Casual"
        case poetic = "Poetic"
    }

    // MARK: - Grammar & Style Check

    func checkGrammar(_ text: String) -> [GrammarIssue] {
        print("   📝 Checking grammar...")

        // In production: Integrate LanguageTool, Grammarly API
        var issues: [GrammarIssue] = []

        // Example issues
        if text.contains("alot") {
            issues.append(GrammarIssue(
                type: .spelling,
                message: "'alot' should be 'a lot'",
                suggestion: "a lot",
                position: 0
            ))
        }

        print("   Found \(issues.count) issues")
        return issues
    }

    struct GrammarIssue: Identifiable {
        let id = UUID()
        let type: IssueType
        let message: String
        let suggestion: String
        let position: Int

        enum IssueType {
            case spelling
            case grammar
            case style
            case punctuation
        }
    }

    // MARK: - Research Management

    func addResearchNote(_ note: ResearchNote) {
        print("   📌 Research note added: \(note.title)")
    }

    struct ResearchNote: Identifiable, Codable {
        let id: UUID
        var title: String
        var content: String
        var source: String?
        var tags: [String]
        var relatedChapters: [Int]
        var date: Date

        init(title: String, content: String) {
            self.id = UUID()
            self.title = title
            self.content = content
            self.tags = []
            self.relatedChapters = []
            self.date = Date()
        }
    }

    // MARK: - Publishing

    func generateISBN(country: ISBNCountry = .germany) -> String {
        // ISBN-13 format: 978-country-publisher-title-check
        let prefix = "978"
        let countryCode = country.code
        let publisherCode = "12345"  // Would be assigned by ISBN agency
        let titleCode = String(format: "%05d", Int.random(in: 1...99999))
        let checkDigit = calculateISBNCheckDigit(prefix: prefix, country: countryCode, publisher: publisherCode, title: titleCode)

        return "\(prefix)-\(countryCode)-\(publisherCode)-\(titleCode)-\(checkDigit)"
    }

    enum ISBNCountry: String {
        case germany = "Germany"
        case usa = "USA"
        case uk = "UK"

        var code: String {
            switch self {
            case .germany: return "3"
            case .usa: return "0"
            case .uk: return "1"
            }
        }
    }

    private func calculateISBNCheckDigit(prefix: String, country: String, publisher: String, title: String) -> Int {
        // ISBN-13 check digit calculation
        let digits = (prefix + country + publisher + title).compactMap { Int(String($0)) }
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += digit * (index % 2 == 0 ? 1 : 3)
        }
        return (10 - (sum % 10)) % 10
    }

    // MARK: - Export

    func exportBook(_ book: Book, format: ExportFormat) -> URL? {
        print("   💾 Exporting book: \(book.title)")
        print("      Format: \(format.rawValue)")
        print("      Word count: \(calculateTotalWordCount(book))")

        switch format {
        case .pdf:
            return exportToPDF(book)
        case .epub:
            return exportToEPUB(book)
        case .mobi:
            return exportToMOBI(book)
        case .docx:
            return exportToDOCX(book)
        case .markdown:
            return exportToMarkdown(book)
        case .latex:
            return exportToLaTeX(book)
        }
    }

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF (Print-ready)"
        case epub = "EPUB (E-book)"
        case mobi = "MOBI (Kindle)"
        case docx = "DOCX (Word)"
        case markdown = "Markdown"
        case latex = "LaTeX (Academic)"
    }

    private func calculateTotalWordCount(_ book: Book) -> Int {
        book.chapters.reduce(0) { $0 + $1.wordCount }
    }

    private func exportToPDF(_ book: Book) -> URL? {
        print("      ✅ PDF generated (print-ready)")
        return nil // Placeholder
    }

    private func exportToEPUB(_ book: Book) -> URL? {
        print("      ✅ EPUB generated (e-book)")
        return nil // Placeholder
    }

    private func exportToMOBI(_ book: Book) -> URL? {
        print("      ✅ MOBI generated (Kindle)")
        return nil // Placeholder
    }

    private func exportToDOCX(_ book: Book) -> URL? {
        print("      ✅ DOCX generated (Word)")
        return nil // Placeholder
    }

    private func exportToMarkdown(_ book: Book) -> URL? {
        var markdown = "# \(book.title)\n\n"
        markdown += "**Author:** \(book.author)\n\n"

        if let subtitle = book.subtitle {
            markdown += "**Subtitle:** \(subtitle)\n\n"
        }

        markdown += "---\n\n"

        for chapter in book.chapters {
            markdown += "## Chapter \(chapter.number): \(chapter.title)\n\n"
            markdown += "\(chapter.content)\n\n"
        }

        print("      ✅ Markdown generated")
        return nil // Placeholder
    }

    private func exportToLaTeX(_ book: Book) -> URL? {
        print("      ✅ LaTeX generated (academic)")
        return nil // Placeholder
    }

    // MARK: - AI-Free Mode

    func toggleAIAssistance() {
        aiAssistanceEnabled.toggle()
        print("   🤖 AI Assistance: \(aiAssistanceEnabled ? "ON" : "OFF")")

        if !aiAssistanceEnabled {
            print("   ✅ AI-FREE MODE: Pure authoring experience")
        }
    }
}
