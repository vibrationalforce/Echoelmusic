import Foundation

/// Story Telling & Dramaturgie Engine
/// Professional story structure and narrative tools for content creation
///
/// Features:
/// - Short-form storytelling (TikTok, Reels, YouTube Shorts)
/// - Long-form storytelling (Films, Series, Documentaries)
/// - Dramaturgical frameworks (Hero's Journey, 3-Act, 5-Act, etc.)
/// - Scene structure & pacing
/// - Character development arcs
/// - Conflict & resolution patterns
/// - Emotional arc mapping
/// - AI-assisted story generation
@MainActor
class StoryTellingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var stories: [Story] = []
    @Published var templates: [StoryTemplate] = []
    @Published var characters: [Character] = []

    // MARK: - Story

    struct Story: Identifiable {
        let id = UUID()
        var title: String
        var format: StoryFormat
        var structure: DramaticStructure
        var acts: [Act]
        var characters: [Character]
        var themes: [Theme]
        var emotionalArc: EmotionalArc
        var targetDuration: TimeInterval
        var actualDuration: TimeInterval?
        var status: StoryStatus

        enum StoryFormat {
            case shortForm(ShortFormType)
            case longForm(LongFormType)

            enum ShortFormType {
                case tiktok          // 15-60 seconds
                case reels           // 15-90 seconds
                case youtubeShorts   // <60 seconds
                case stories         // 15 seconds per slide
                case vine            // 6 seconds (legacy)
            }

            enum LongFormType {
                case shortFilm       // 5-40 minutes
                case feature         // 90-180 minutes
                case episode         // 22-60 minutes
                case series          // Multiple episodes
                case documentary     // 60-120 minutes
                case musicVideo      // 3-8 minutes
                case concert         // 60-180 minutes
            }

            var targetDuration: TimeInterval {
                switch self {
                case .shortForm(let type):
                    switch type {
                    case .tiktok: return 30
                    case .reels: return 45
                    case .youtubeShorts: return 45
                    case .stories: return 15
                    case .vine: return 6
                    }
                case .longForm(let type):
                    switch type {
                    case .shortFilm: return 15 * 60
                    case .feature: return 120 * 60
                    case .episode: return 45 * 60
                    case .series: return 45 * 60 * 8  // 8 episodes
                    case .documentary: return 90 * 60
                    case .musicVideo: return 4 * 60
                    case .concert: return 90 * 60
                    }
                }
            }
        }

        enum StoryStatus {
            case outline, draft, revision, final, published
        }
    }

    // MARK: - Dramatic Structure

    enum DramaticStructure: String, CaseIterable {
        case herosJourney = "Hero's Journey (12 Stages)"
        case threeAct = "Three-Act Structure"
        case fiveAct = "Five-Act Structure"
        case sevenPoint = "Seven-Point Story Structure"
        case freytag = "Freytag's Pyramid"
        case saveTheCat = "Save the Cat! (15 Beats)"
        case kishōtenketsu = "Kishōtenketsu (4 Acts)"
        case viralHook = "Viral Hook Framework (Short-Form)"

        var description: String {
            switch self {
            case .herosJourney:
                return "Joseph Campbell's monomyth: Departure, Initiation, Return"
            case .threeAct:
                return "Setup, Confrontation, Resolution"
            case .fiveAct:
                return "Exposition, Rising Action, Climax, Falling Action, Denouement"
            case .sevenPoint:
                return "Hook, Plot Turn 1, Pinch 1, Midpoint, Pinch 2, Plot Turn 2, Resolution"
            case .freytag:
                return "Exposition, Rising Action, Climax, Falling Action, Catastrophe/Denouement"
            case .saveTheCat:
                return "Blake Snyder's 15-beat structure for screenplays"
            case .kishōtenketsu:
                return "Japanese 4-act structure: Introduction, Development, Twist, Conclusion"
            case .viralHook:
                return "Hook (3s), Build (7s), Payoff (5s), CTA (3s)"
            }
        }

        func generateActStructure(duration: TimeInterval) -> [ActTemplate] {
            switch self {
            case .herosJourney:
                return generateHerosJourneyActs(duration: duration)
            case .threeAct:
                return generateThreeActStructure(duration: duration)
            case .fiveAct:
                return generateFiveActStructure(duration: duration)
            case .sevenPoint:
                return generateSevenPointStructure(duration: duration)
            case .freytag:
                return generateFreytagStructure(duration: duration)
            case .saveTheCat:
                return generateSaveTheCatStructure(duration: duration)
            case .kishōtenketsu:
                return generateKishotenketsuStructure(duration: duration)
            case .viralHook:
                return generateViralHookStructure(duration: duration)
            }
        }
    }

    struct ActTemplate {
        let title: String
        let description: String
        let startTime: TimeInterval
        let duration: TimeInterval
        let beats: [BeatTemplate]

        struct BeatTemplate {
            let title: String
            let description: String
            let relativePosition: Double  // 0-1 within act
        }
    }

    // MARK: - Act

    struct Act: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var scenes: [Scene]
        var startTime: TimeInterval
        var duration: TimeInterval
        var purpose: ActPurpose

        enum ActPurpose {
            case setup, incitingIncident, risingAction, midpoint
            case climax, fallingAction, resolution
        }
    }

    // MARK: - Scene

    struct Scene: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var location: String?
        var timeOfDay: TimeOfDay?
        var characters: [Character]
        var conflict: Conflict?
        var emotion: Emotion
        var shots: [Shot]
        var duration: TimeInterval
        var notes: String?

        enum TimeOfDay: String {
            case dawn, morning, day, afternoon, evening, dusk, night
        }

        struct Shot {
            let type: ShotType
            let description: String
            let duration: TimeInterval

            enum ShotType: String {
                case establishingShot = "Establishing Shot"
                case wideShot = "Wide Shot"
                case mediumShot = "Medium Shot"
                case closeUp = "Close-Up"
                case extremeCloseUp = "Extreme Close-Up"
                case overTheShoulder = "Over-the-Shoulder"
                case pointOfView = "Point of View"
                case insert = "Insert"
                case tracking = "Tracking/Dolly"
                case aerial = "Aerial/Drone"
            }
        }
    }

    // MARK: - Character

    struct Character: Identifiable {
        let id = UUID()
        var name: String
        var role: CharacterRole
        var arc: CharacterArc
        var traits: [String]
        var backstory: String?
        var motivation: String
        var conflicts: [Conflict]
        var relationships: [Relationship]

        enum CharacterRole {
            case protagonist, antagonist, mentor, ally
            case guardian, trickster, herald, shapeshifter
            case supporting, extra
        }

        struct CharacterArc {
            var type: ArcType
            var stages: [Stage]

            enum ArcType {
                case positive      // Growth/Change arc
                case negative      // Fall/Corruption arc
                case flat          // Static/Testing arc
                case transformational
            }

            struct Stage {
                let name: String
                let description: String
                let position: Double  // 0-1 in story
            }
        }

        struct Relationship {
            let characterId: UUID
            let type: RelationType
            let description: String

            enum RelationType {
                case family, romantic, friendship, rivalry
                case mentor, student, employer, enemy
            }
        }
    }

    // MARK: - Conflict

    struct Conflict: Identifiable {
        let id = UUID()
        var type: ConflictType
        var description: String
        var stakes: String
        var resolution: String?

        enum ConflictType {
            case personVsPerson      // Character vs Character
            case personVsSelf        // Internal conflict
            case personVsSociety     // Character vs System
            case personVsNature      // Character vs Environment
            case personVsTechnology  // Character vs Machine/AI
            case personVsFate        // Character vs Destiny
        }
    }

    // MARK: - Emotional Arc

    struct EmotionalArc {
        var peaks: [EmotionalBeat]
        var overallTone: Tone

        struct EmotionalBeat {
            let position: Double  // 0-1 in story
            let emotion: Emotion
            let intensity: Double  // 0-1
        }

        enum Tone {
            case dramatic, comedic, dark, uplifting
            case suspenseful, romantic, inspirational, tragic
        }
    }

    enum Emotion: String, CaseIterable {
        case joy, sadness, anger, fear, surprise, disgust
        case excitement, anticipation, trust, love, hope
        case tension, relief, triumph, despair
    }

    // MARK: - Theme

    struct Theme: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var symbols: [String]
        var motifs: [String]

        static let commonThemes = [
            "Love & Sacrifice",
            "Good vs Evil",
            "Coming of Age",
            "Redemption",
            "Identity & Self-Discovery",
            "Power & Corruption",
            "Family & Belonging",
            "Survival",
            "Justice vs Revenge",
            "Freedom vs Control"
        ]
    }

    // MARK: - Story Template

    struct StoryTemplate: Identifiable {
        let id = UUID()
        var name: String
        var format: Story.StoryFormat
        var structure: DramaticStructure
        var description: String
        var example: String?

        static let viralShortFormTemplates: [StoryTemplate] = [
            StoryTemplate(
                name: "Hook-Build-Payoff",
                format: .shortForm(.tiktok),
                structure: .viralHook,
                description: "Grab attention immediately, build tension, deliver satisfying payoff",
                example: "\"You won't believe what happens next...\""
            ),
            StoryTemplate(
                name: "Before & After",
                format: .shortForm(.reels),
                structure: .threeAct,
                description: "Show transformation or contrast",
                example: "Music production: Raw mix → Final master"
            ),
            StoryTemplate(
                name: "Relatable Problem → Solution",
                format: .shortForm(.youtubeShorts),
                structure: .threeAct,
                description: "Identify common pain point, offer solution",
                example: "Struggling with mixing? Try this one trick..."
            ),
            StoryTemplate(
                name: "POV Storytelling",
                format: .shortForm(.tiktok),
                structure: .viralHook,
                description: "Point-of-view narrative that viewers relate to",
                example: "POV: You're a producer at 3 AM..."
            ),
        ]
    }

    // MARK: - Initialization

    init() {
        print("📖 Story Telling Engine initialized")

        self.templates = StoryTemplate.viralShortFormTemplates

        print("   ✅ \(templates.count) templates loaded")
    }

    // MARK: - Generate Story Structure

    func generateStoryStructure(
        title: String,
        format: Story.StoryFormat,
        structure: DramaticStructure,
        themes: [String] = []
    ) -> Story {
        print("📝 Generating story structure...")
        print("   Title: \(title)")
        print("   Format: \(format)")
        print("   Structure: \(structure.rawValue)")

        let duration = format.targetDuration
        let actTemplates = structure.generateActStructure(duration: duration)

        // Convert templates to acts
        let acts = actTemplates.map { template in
            Act(
                title: template.title,
                description: template.description,
                scenes: [],
                startTime: template.startTime,
                duration: template.duration,
                purpose: .setup  // Simplified
            )
        }

        // Create themes
        let storyThemes = themes.isEmpty ? [Theme.commonThemes[0]] : themes.map { themeName in
            Theme(name: themeName, description: "", symbols: [], motifs: [])
        }

        let story = Story(
            title: title,
            format: format,
            structure: structure,
            acts: acts,
            characters: [],
            themes: storyThemes,
            emotionalArc: generateEmotionalArc(structure: structure),
            targetDuration: duration,
            status: .outline
        )

        stories.append(story)

        print("   ✅ Story structure created with \(acts.count) acts")

        return story
    }

    // MARK: - Structure Generation Functions

    private func generateHerosJourneyActs(duration: TimeInterval) -> [ActTemplate] {
        let actDuration = duration / 12.0

        return [
            ActTemplate(title: "1. Ordinary World", description: "Hero's normal life", startTime: 0, duration: actDuration, beats: []),
            ActTemplate(title: "2. Call to Adventure", description: "Problem/Challenge appears", startTime: actDuration, duration: actDuration, beats: []),
            ActTemplate(title: "3. Refusal of Call", description: "Hero hesitates", startTime: actDuration * 2, duration: actDuration, beats: []),
            ActTemplate(title: "4. Meeting Mentor", description: "Guidance received", startTime: actDuration * 3, duration: actDuration, beats: []),
            ActTemplate(title: "5. Crossing Threshold", description: "Commit to journey", startTime: actDuration * 4, duration: actDuration, beats: []),
            ActTemplate(title: "6. Tests, Allies, Enemies", description: "Face challenges", startTime: actDuration * 5, duration: actDuration, beats: []),
            ActTemplate(title: "7. Approach to Innermost Cave", description: "Prepare for ordeal", startTime: actDuration * 6, duration: actDuration, beats: []),
            ActTemplate(title: "8. Ordeal", description: "Face greatest fear", startTime: actDuration * 7, duration: actDuration, beats: []),
            ActTemplate(title: "9. Reward", description: "Seize the sword", startTime: actDuration * 8, duration: actDuration, beats: []),
            ActTemplate(title: "10. The Road Back", description: "Return journey begins", startTime: actDuration * 9, duration: actDuration, beats: []),
            ActTemplate(title: "11. Resurrection", description: "Final test", startTime: actDuration * 10, duration: actDuration, beats: []),
            ActTemplate(title: "12. Return with Elixir", description: "Hero transformed", startTime: actDuration * 11, duration: actDuration, beats: []),
        ]
    }

    private func generateThreeActStructure(duration: TimeInterval) -> [ActTemplate] {
        return [
            ActTemplate(
                title: "Act 1: Setup",
                description: "Introduce world, characters, and conflict",
                startTime: 0,
                duration: duration * 0.25,
                beats: [
                    ActTemplate.BeatTemplate(title: "Opening Image", description: "First impression", relativePosition: 0.0),
                    ActTemplate.BeatTemplate(title: "Inciting Incident", description: "Catalyst for change", relativePosition: 0.5),
                    ActTemplate.BeatTemplate(title: "First Plot Point", description: "Cross threshold", relativePosition: 1.0),
                ]
            ),
            ActTemplate(
                title: "Act 2: Confrontation",
                description: "Hero faces obstacles and grows",
                startTime: duration * 0.25,
                duration: duration * 0.50,
                beats: [
                    ActTemplate.BeatTemplate(title: "Rising Action", description: "Escalating conflict", relativePosition: 0.25),
                    ActTemplate.BeatTemplate(title: "Midpoint", description: "False victory/defeat", relativePosition: 0.5),
                    ActTemplate.BeatTemplate(title: "All is Lost", description: "Lowest point", relativePosition: 0.75),
                ]
            ),
            ActTemplate(
                title: "Act 3: Resolution",
                description: "Climax and resolution",
                startTime: duration * 0.75,
                duration: duration * 0.25,
                beats: [
                    ActTemplate.BeatTemplate(title: "Climax", description: "Final confrontation", relativePosition: 0.5),
                    ActTemplate.BeatTemplate(title: "Resolution", description: "New equilibrium", relativePosition: 1.0),
                ]
            ),
        ]
    }

    private func generateFiveActStructure(duration: TimeInterval) -> [ActTemplate] {
        let actDuration = duration / 5.0

        return [
            ActTemplate(title: "Act 1: Exposition", description: "Set the scene", startTime: 0, duration: actDuration, beats: []),
            ActTemplate(title: "Act 2: Rising Action", description: "Complications arise", startTime: actDuration, duration: actDuration, beats: []),
            ActTemplate(title: "Act 3: Climax", description: "Turning point", startTime: actDuration * 2, duration: actDuration, beats: []),
            ActTemplate(title: "Act 4: Falling Action", description: "Consequences unfold", startTime: actDuration * 3, duration: actDuration, beats: []),
            ActTemplate(title: "Act 5: Denouement", description: "Resolution", startTime: actDuration * 4, duration: actDuration, beats: []),
        ]
    }

    private func generateSevenPointStructure(duration: TimeInterval) -> [ActTemplate] {
        return [
            ActTemplate(title: "Hook", description: "Grab attention", startTime: 0, duration: duration * 0.05, beats: []),
            ActTemplate(title: "Plot Turn 1", description: "Enter new world", startTime: duration * 0.05, duration: duration * 0.15, beats: []),
            ActTemplate(title: "Pinch 1", description: "Antagonist strikes", startTime: duration * 0.20, duration: duration * 0.15, beats: []),
            ActTemplate(title: "Midpoint", description: "Change strategy", startTime: duration * 0.35, duration: duration * 0.30, beats: []),
            ActTemplate(title: "Pinch 2", description: "Antagonist gains ground", startTime: duration * 0.65, duration: duration * 0.10, beats: []),
            ActTemplate(title: "Plot Turn 2", description: "Final piece of puzzle", startTime: duration * 0.75, duration: duration * 0.15, beats: []),
            ActTemplate(title: "Resolution", description: "Payoff", startTime: duration * 0.90, duration: duration * 0.10, beats: []),
        ]
    }

    private func generateFreytagStructure(duration: TimeInterval) -> [ActTemplate] {
        return [
            ActTemplate(title: "Exposition", description: "Background information", startTime: 0, duration: duration * 0.15, beats: []),
            ActTemplate(title: "Rising Action", description: "Building tension", startTime: duration * 0.15, duration: duration * 0.35, beats: []),
            ActTemplate(title: "Climax", description: "Peak of tension", startTime: duration * 0.50, duration: duration * 0.10, beats: []),
            ActTemplate(title: "Falling Action", description: "Consequences", startTime: duration * 0.60, duration: duration * 0.25, beats: []),
            ActTemplate(title: "Denouement", description: "Resolution", startTime: duration * 0.85, duration: duration * 0.15, beats: []),
        ]
    }

    private func generateSaveTheCatStructure(duration: TimeInterval) -> [ActTemplate] {
        // Blake Snyder's 15-beat structure
        return [
            ActTemplate(title: "Opening Image", description: "Snapshot of hero's flawed life", startTime: 0, duration: duration * 0.01, beats: []),
            ActTemplate(title: "Theme Stated", description: "Hint at story's meaning", startTime: duration * 0.05, duration: duration * 0.01, beats: []),
            ActTemplate(title: "Setup", description: "Establish status quo", startTime: duration * 0.01, duration: duration * 0.09, beats: []),
            ActTemplate(title: "Catalyst", description: "Life-changing event", startTime: duration * 0.10, duration: duration * 0.02, beats: []),
            ActTemplate(title: "Debate", description: "Should I go?", startTime: duration * 0.12, duration: duration * 0.08, beats: []),
            ActTemplate(title: "Break into Two", description: "Commit to journey", startTime: duration * 0.20, duration: duration * 0.05, beats: []),
            // ... 15 beats total
        ]
    }

    private func generateKishotenketsuStructure(duration: TimeInterval) -> [ActTemplate] {
        let actDuration = duration / 4.0

        return [
            ActTemplate(title: "Ki (Introduction)", description: "Introduce elements", startTime: 0, duration: actDuration, beats: []),
            ActTemplate(title: "Shō (Development)", description: "Develop situation", startTime: actDuration, duration: actDuration, beats: []),
            ActTemplate(title: "Ten (Twist)", description: "Unexpected turn", startTime: actDuration * 2, duration: actDuration, beats: []),
            ActTemplate(title: "Ketsu (Conclusion)", description: "Reconcile elements", startTime: actDuration * 3, duration: actDuration, beats: []),
        ]
    }

    private func generateViralHookStructure(duration: TimeInterval) -> [ActTemplate] {
        // Optimized for short-form viral content
        return [
            ActTemplate(
                title: "Hook (First 3 seconds)",
                description: "Stop the scroll - bold statement, question, or visual",
                startTime: 0,
                duration: 3,
                beats: []
            ),
            ActTemplate(
                title: "Build (Next 5-7 seconds)",
                description: "Create tension, curiosity, or anticipation",
                startTime: 3,
                duration: 7,
                beats: []
            ),
            ActTemplate(
                title: "Payoff (Next 5 seconds)",
                description: "Deliver on promise, reveal, transform",
                startTime: 10,
                duration: 5,
                beats: []
            ),
            ActTemplate(
                title: "CTA (Final 3 seconds)",
                description: "Call-to-action: follow, like, comment",
                startTime: 15,
                duration: 3,
                beats: []
            ),
        ]
    }

    // MARK: - Emotional Arc

    private func generateEmotionalArc(structure: DramaticStructure) -> EmotionalArc {
        var peaks: [EmotionalArc.EmotionalBeat] = []

        switch structure {
        case .threeAct, .herosJourney:
            peaks = [
                EmotionalArc.EmotionalBeat(position: 0.0, emotion: .anticipation, intensity: 0.3),
                EmotionalArc.EmotionalBeat(position: 0.25, emotion: .excitement, intensity: 0.5),
                EmotionalArc.EmotionalBeat(position: 0.50, emotion: .tension, intensity: 0.8),
                EmotionalArc.EmotionalBeat(position: 0.75, emotion: .despair, intensity: 0.9),
                EmotionalArc.EmotionalBeat(position: 0.90, emotion: .triumph, intensity: 1.0),
                EmotionalArc.EmotionalBeat(position: 1.0, emotion: .relief, intensity: 0.6),
            ]
        case .viralHook:
            peaks = [
                EmotionalArc.EmotionalBeat(position: 0.0, emotion: .surprise, intensity: 1.0),
                EmotionalArc.EmotionalBeat(position: 0.50, emotion: .tension, intensity: 0.8),
                EmotionalArc.EmotionalBeat(position: 1.0, emotion: .satisfaction, intensity: 0.9),
            ]
        default:
            peaks = [
                EmotionalArc.EmotionalBeat(position: 0.5, emotion: .tension, intensity: 0.8),
                EmotionalArc.EmotionalBeat(position: 1.0, emotion: .relief, intensity: 0.6),
            ]
        }

        return EmotionalArc(peaks: peaks, overallTone: .dramatic)
    }

    // MARK: - AI-Assisted Generation

    func generateStoryIdeas(
        format: Story.StoryFormat,
        genre: String,
        count: Int = 5
    ) -> [StoryIdea] {
        print("💡 Generating story ideas...")
        print("   Format: \(format)")
        print("   Genre: \(genre)")

        var ideas: [StoryIdea] = []

        for i in 0..<count {
            let idea = StoryIdea(
                title: "Story Idea \(i + 1)",
                logline: "A compelling one-sentence summary of the story...",
                hook: "The attention-grabbing opening...",
                themes: [Theme.commonThemes.randomElement() ?? "Adventure"],
                estimatedVirality: Double.random(in: 50...95)
            )
            ideas.append(idea)
        }

        print("   ✅ Generated \(ideas.count) ideas")

        return ideas
    }

    struct StoryIdea {
        let title: String
        let logline: String
        let hook: String
        let themes: [String]
        let estimatedVirality: Double  // AI prediction
    }

    // MARK: - Export

    func exportScript(story: Story, format: ScriptFormat) -> String {
        print("📄 Exporting script...")

        switch format {
        case .fountain:
            return exportFountainScript(story: story)
        case .finalDraft:
            return exportFinalDraftScript(story: story)
        case .plainText:
            return exportPlainTextScript(story: story)
        }
    }

    enum ScriptFormat {
        case fountain      // Markdown-based screenplay format
        case finalDraft    // Industry standard
        case plainText
    }

    private func exportFountainScript(story: Story) -> String {
        var script = """
        Title: \(story.title)
        Credit: Written by
        Author: [Author Name]
        Draft date: \(Date())

        """

        for act in story.acts {
            script += """

            = \(act.title.uppercased())

            """

            for scene in act.scenes {
                script += """

                EXT. \(scene.location ?? "LOCATION") - \(scene.timeOfDay?.rawValue.uppercased() ?? "DAY")

                \(scene.description)

                """
            }
        }

        return script
    }

    private func exportFinalDraftScript(story: Story) -> String {
        // FinalDraft XML format
        return exportPlainTextScript(story: story)
    }

    private func exportPlainTextScript(story: Story) -> String {
        var script = """
        \(story.title.uppercased())
        \(String(repeating: "=", count: story.title.count))

        """

        for (index, act) in story.acts.enumerated() {
            script += """

            ACT \(index + 1): \(act.title.uppercased())
            \(String(repeating: "-", count: 40))

            \(act.description)

            """

            for scene in act.scenes {
                script += """

                SCENE: \(scene.title)
                Location: \(scene.location ?? "Unknown")
                Time: \(scene.timeOfDay?.rawValue ?? "Day")

                \(scene.description)

                """
            }
        }

        return script
    }
}

// MARK: - Emotion Extension

extension StoryTellingEngine.Emotion {
    var emoji: String {
        switch self {
        case .joy: return "😊"
        case .sadness: return "😢"
        case .anger: return "😠"
        case .fear: return "😨"
        case .surprise: return "😲"
        case .disgust: return "🤢"
        case .excitement: return "🤩"
        case .anticipation: return "🤔"
        case .trust: return "🤝"
        case .love: return "❤️"
        case .hope: return "🌟"
        case .tension: return "😰"
        case .relief: return "😌"
        case .triumph: return "🎉"
        case .despair: return "😞"
        }
    }
}
