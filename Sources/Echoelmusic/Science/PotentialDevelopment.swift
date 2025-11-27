import Foundation
import Combine

/// PotentialDevelopment - Potentialentfaltung (Potential Unfolding) System
/// Scientific tracking of human potential development and self-actualization
///
/// Mission: Help every person discover, develop, and express their unique potential
///
/// Scientific Foundation:
/// - Self-Actualization Theory - Maslow, 1943
/// - Self-Determination Theory - Deci & Ryan, 2000
/// - Flow Theory - Csikszentmihalyi, 1990
/// - Positive Psychology - Seligman, 2011
/// - Character Strengths - VIA Institute (Peterson & Seligman, 2004)
/// - Growth Mindset - Dweck, 2006
/// - Ikigai - Japanese concept of life purpose
///
/// German: "Potentialentfaltung" = The unfolding/development of potential
/// This captures the organic, natural process of becoming who you're meant to be
@MainActor
public final class PotentialDevelopment: ObservableObject {

    // MARK: - Singleton

    public static let shared = PotentialDevelopment()

    // MARK: - Published State

    @Published public var userPotentialProfile: PotentialProfile?
    @Published public var developmentJourney: DevelopmentJourney?
    @Published public var currentGrowthGoals: [GrowthGoal] = []
    @Published public var achievedMilestones: [Milestone] = []
    @Published public var dailyPractices: [DailyPractice] = []
    @Published public var flowSessions: [FlowSession] = []

    // MARK: - Potential Profile

    public struct PotentialProfile: Codable, Identifiable {
        public let id: UUID
        public var createdDate: Date
        public var lastUpdated: Date

        // Maslow's Hierarchy Progress
        public var physiologicalNeeds: Float      // 0-100
        public var safetyNeeds: Float             // 0-100
        public var belongingNeeds: Float          // 0-100
        public var esteemNeeds: Float             // 0-100
        public var selfActualization: Float       // 0-100 (peak)
        public var transcendence: Float           // 0-100 (beyond self)

        // Self-Determination Theory
        public var autonomy: Float                // 0-100
        public var competence: Float              // 0-100
        public var relatedness: Float             // 0-100
        public var intrinsicMotivation: Float     // Aggregate

        // Character Strengths (VIA)
        public var signatureStrengths: [CharacterStrength]
        public var growthStrengths: [CharacterStrength]

        // Flow Capacity
        public var flowFrequency: Float           // 0-100, how often in flow
        public var flowDuration: TimeInterval     // Average duration
        public var flowTriggers: [String]
        public var flowBlockers: [String]

        // Purpose & Meaning (Ikigai)
        public var passions: [String]             // What you love
        public var missions: [String]             // What the world needs
        public var vocations: [String]            // What you can be paid for
        public var professions: [String]          // What you're good at
        public var ikigaiClarity: Float           // 0-100

        // Growth Mindset
        public var growthMindsetScore: Float      // 0-100
        public var learningOrientation: Float     // 0-100
        public var challengeEmbracement: Float    // 0-100
        public var persistenceLevel: Float        // 0-100

        // Overall
        public var potentialRealization: Float    // 0-100, how much potential realized
        public var developmentVelocity: Float     // Rate of growth

        public init() {
            self.id = UUID()
            self.createdDate = Date()
            self.lastUpdated = Date()

            self.physiologicalNeeds = 50
            self.safetyNeeds = 50
            self.belongingNeeds = 50
            self.esteemNeeds = 50
            self.selfActualization = 30
            self.transcendence = 20

            self.autonomy = 50
            self.competence = 50
            self.relatedness = 50
            self.intrinsicMotivation = 50

            self.signatureStrengths = []
            self.growthStrengths = []

            self.flowFrequency = 30
            self.flowDuration = 1800  // 30 minutes
            self.flowTriggers = []
            self.flowBlockers = []

            self.passions = []
            self.missions = []
            self.vocations = []
            self.professions = []
            self.ikigaiClarity = 30

            self.growthMindsetScore = 50
            self.learningOrientation = 50
            self.challengeEmbracement = 50
            self.persistenceLevel = 50

            self.potentialRealization = 30
            self.developmentVelocity = 0
        }
    }

    // MARK: - Character Strength (VIA)

    public struct CharacterStrength: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var virtue: Virtue
        public var currentLevel: Float      // 0-100
        public var growthPotential: Float   // 0-100
        public var usageFrequency: Float    // 0-100, how often used
        public var description: String
        public var developmentTips: [String]
        public var careerApplications: [String]

        public init(name: String, virtue: Virtue, currentLevel: Float, growthPotential: Float = 100) {
            self.id = UUID()
            self.name = name
            self.virtue = virtue
            self.currentLevel = currentLevel
            self.growthPotential = growthPotential
            self.usageFrequency = 50
            self.description = virtue.strengthDescriptions[name] ?? ""
            self.developmentTips = []
            self.careerApplications = []
        }

        /// VIA Classification - 6 Core Virtues, 24 Character Strengths
        public enum Virtue: String, Codable, CaseIterable {
            case wisdom = "Wisdom & Knowledge"
            case courage = "Courage"
            case humanity = "Humanity"
            case justice = "Justice"
            case temperance = "Temperance"
            case transcendence = "Transcendence"

            var strengths: [String] {
                switch self {
                case .wisdom:
                    return ["Creativity", "Curiosity", "Judgment", "Love of Learning", "Perspective"]
                case .courage:
                    return ["Bravery", "Perseverance", "Honesty", "Zest"]
                case .humanity:
                    return ["Love", "Kindness", "Social Intelligence"]
                case .justice:
                    return ["Teamwork", "Fairness", "Leadership"]
                case .temperance:
                    return ["Forgiveness", "Humility", "Prudence", "Self-Regulation"]
                case .transcendence:
                    return ["Appreciation of Beauty", "Gratitude", "Hope", "Humor", "Spirituality"]
                }
            }

            var strengthDescriptions: [String: String] {
                switch self {
                case .wisdom:
                    return [
                        "Creativity": "Thinking of novel ways to do things",
                        "Curiosity": "Taking interest in all ongoing experience",
                        "Judgment": "Thinking things through, examining all sides",
                        "Love of Learning": "Mastering new skills and knowledge",
                        "Perspective": "Providing wise counsel to others"
                    ]
                case .courage:
                    return [
                        "Bravery": "Not shrinking from challenge or difficulty",
                        "Perseverance": "Finishing what you start",
                        "Honesty": "Speaking the truth, presenting yourself genuinely",
                        "Zest": "Approaching life with excitement and energy"
                    ]
                case .humanity:
                    return [
                        "Love": "Valuing close relations with others",
                        "Kindness": "Doing favors and good deeds for others",
                        "Social Intelligence": "Being aware of others' feelings"
                    ]
                case .justice:
                    return [
                        "Teamwork": "Working well as a member of a group",
                        "Fairness": "Treating all people the same according to fairness",
                        "Leadership": "Organizing activities and seeing they happen"
                    ]
                case .temperance:
                    return [
                        "Forgiveness": "Forgiving those who have done wrong",
                        "Humility": "Letting accomplishments speak for themselves",
                        "Prudence": "Being careful about choices",
                        "Self-Regulation": "Regulating feelings and actions"
                    ]
                case .transcendence:
                    return [
                        "Appreciation of Beauty": "Noticing beauty in all domains",
                        "Gratitude": "Being thankful for good things",
                        "Hope": "Expecting the best and working to achieve it",
                        "Humor": "Liking to laugh and bring smiles to others",
                        "Spirituality": "Having beliefs about meaning and purpose"
                    ]
                }
            }
        }
    }

    // MARK: - Development Journey

    public struct DevelopmentJourney: Codable {
        public var startDate: Date
        public var currentPhase: DevelopmentPhase
        public var completedPhases: [DevelopmentPhase]
        public var totalGrowthPoints: Int
        public var streakDays: Int
        public var longestStreak: Int
        public var insights: [Insight]
        public var transformations: [Transformation]

        public init() {
            self.startDate = Date()
            self.currentPhase = .awareness
            self.completedPhases = []
            self.totalGrowthPoints = 0
            self.streakDays = 0
            self.longestStreak = 0
            self.insights = []
            self.transformations = []
        }

        public enum DevelopmentPhase: String, Codable, CaseIterable {
            case awareness = "Awareness"           // Discovering strengths
            case exploration = "Exploration"       // Trying new things
            case foundation = "Foundation"         // Building core skills
            case integration = "Integration"       // Combining strengths
            case mastery = "Mastery"               // Deep expertise
            case contribution = "Contribution"     // Giving back
            case transcendence = "Transcendence"   // Beyond self

            var description: String {
                switch self {
                case .awareness:
                    return "Discovering who you are and what makes you unique"
                case .exploration:
                    return "Experimenting with different paths and possibilities"
                case .foundation:
                    return "Building solid skills and healthy habits"
                case .integration:
                    return "Combining your strengths into your unique expression"
                case .mastery:
                    return "Achieving deep expertise in your chosen areas"
                case .contribution:
                    return "Using your gifts to help others and make a difference"
                case .transcendence:
                    return "Going beyond self-interest to serve something greater"
                }
            }

            var evidenceBase: String {
                switch self {
                case .awareness:
                    return "Self-awareness is foundation of emotional intelligence (Goleman, 1995)"
                case .exploration:
                    return "Exploration leads to crystallization of interests (Super, 1980)"
                case .foundation:
                    return "Deliberate practice builds expertise (Ericsson, 2006)"
                case .integration:
                    return "Integration enables authentic expression (Rogers, 1961)"
                case .mastery:
                    return "10,000 hours for mastery in complex domains (Ericsson)"
                case .contribution:
                    return "Generativity increases wellbeing (Erikson, 1963)"
                case .transcendence:
                    return "Self-transcendence is highest human need (Maslow, 1969)"
                }
            }
        }

        public struct Insight: Codable, Identifiable {
            public let id: UUID
            public var date: Date
            public var content: String
            public var category: String
            public var importance: Int  // 1-5

            public init(content: String, category: String, importance: Int = 3) {
                self.id = UUID()
                self.date = Date()
                self.content = content
                self.category = category
                self.importance = importance
            }
        }

        public struct Transformation: Codable, Identifiable {
            public let id: UUID
            public var date: Date
            public var before: String
            public var after: String
            public var areaOfLife: String
            public var evidenceOfChange: [String]

            public init(before: String, after: String, areaOfLife: String) {
                self.id = UUID()
                self.date = Date()
                self.before = before
                self.after = after
                self.areaOfLife = areaOfLife
                self.evidenceOfChange = []
            }
        }
    }

    // MARK: - Growth Goal

    public struct GrowthGoal: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var description: String
        public var category: GoalCategory
        public var targetStrength: String?
        public var startDate: Date
        public var targetDate: Date
        public var currentProgress: Float    // 0-100
        public var milestones: [GoalMilestone]
        public var practices: [String]
        public var obstacles: [String]
        public var supportNeeded: [String]
        public var evidenceOfProgress: [String]
        public var isCompleted: Bool
        public var completionDate: Date?

        public init(title: String, description: String, category: GoalCategory, targetDate: Date) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.category = category
            self.targetStrength = nil
            self.startDate = Date()
            self.targetDate = targetDate
            self.currentProgress = 0
            self.milestones = []
            self.practices = []
            self.obstacles = []
            self.supportNeeded = []
            self.evidenceOfProgress = []
            self.isCompleted = false
            self.completionDate = nil
        }

        public enum GoalCategory: String, Codable, CaseIterable {
            case strengthDevelopment = "Strength Development"
            case skillBuilding = "Skill Building"
            case habitFormation = "Habit Formation"
            case mindsetShift = "Mindset Shift"
            case relationshipGrowth = "Relationship Growth"
            case careerAdvancement = "Career Advancement"
            case healthImprovement = "Health Improvement"
            case purposeClarity = "Purpose Clarity"
            case creativityExpansion = "Creativity Expansion"
            case spiritualGrowth = "Spiritual Growth"
        }

        public struct GoalMilestone: Codable, Identifiable {
            public let id: UUID
            public var title: String
            public var targetDate: Date
            public var isAchieved: Bool
            public var achievedDate: Date?

            public init(title: String, targetDate: Date) {
                self.id = UUID()
                self.title = title
                self.targetDate = targetDate
                self.isAchieved = false
                self.achievedDate = nil
            }
        }
    }

    // MARK: - Milestone

    public struct Milestone: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var description: String
        public var achievedDate: Date
        public var category: String
        public var celebrationNote: String
        public var growthPoints: Int

        public init(title: String, description: String, category: String, growthPoints: Int = 10) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.achievedDate = Date()
            self.category = category
            self.celebrationNote = ""
            self.growthPoints = growthPoints
        }
    }

    // MARK: - Daily Practice

    public struct DailyPractice: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var description: String
        public var targetStrength: String?
        public var durationMinutes: Int
        public var frequency: Frequency
        public var completionHistory: [Date]
        public var currentStreak: Int
        public var bestStreak: Int
        public var evidenceBase: String
        public var accessibilityNotes: String

        public init(name: String, description: String, durationMinutes: Int, frequency: Frequency, evidenceBase: String = "") {
            self.id = UUID()
            self.name = name
            self.description = description
            self.targetStrength = nil
            self.durationMinutes = durationMinutes
            self.frequency = frequency
            self.completionHistory = []
            self.currentStreak = 0
            self.bestStreak = 0
            self.evidenceBase = evidenceBase
            self.accessibilityNotes = ""
        }

        public enum Frequency: String, Codable, CaseIterable {
            case daily = "Daily"
            case weekdays = "Weekdays"
            case weekly = "Weekly"
            case biweekly = "Twice Weekly"
            case custom = "Custom"
        }
    }

    // MARK: - Flow Session

    public struct FlowSession: Codable, Identifiable {
        public let id: UUID
        public var startTime: Date
        public var endTime: Date?
        public var duration: TimeInterval
        public var activity: String
        public var flowIntensity: Float      // 0-100
        public var challengeLevel: Float     // 0-100
        public var skillLevel: Float         // 0-100
        public var triggers: [String]
        public var distractions: [String]
        public var insights: String
        public var accomplishments: [String]

        public init(activity: String) {
            self.id = UUID()
            self.startTime = Date()
            self.endTime = nil
            self.duration = 0
            self.activity = activity
            self.flowIntensity = 0
            self.challengeLevel = 50
            self.skillLevel = 50
            self.triggers = []
            self.distractions = []
            self.insights = ""
            self.accomplishments = []
        }

        /// Flow Channel: Challenge vs Skill (Csikszentmihalyi)
        public var flowState: FlowState {
            let balance = challengeLevel - skillLevel
            switch balance {
            case -100 ..< -20: return .boredom
            case -20 ..< -5: return .relaxation
            case -5 ..< 5: return .flow
            case 5 ..< 20: return .arousal
            case 20 ..< 100: return .anxiety
            default: return .apathy
            }
        }

        public enum FlowState: String, Codable {
            case anxiety = "Anxiety (Challenge >> Skill)"
            case arousal = "Arousal (Challenge > Skill)"
            case flow = "Flow (Challenge ≈ Skill)"
            case control = "Control (Skill > Challenge)"
            case relaxation = "Relaxation (Skill >> Challenge)"
            case boredom = "Boredom (Very Low Challenge)"
            case apathy = "Apathy (Low Everything)"
            case worry = "Worry (Moderate Imbalance)"

            var recommendation: String {
                switch self {
                case .anxiety:
                    return "Reduce challenge or build skills first"
                case .arousal:
                    return "Good! Slightly increase skills to enter flow"
                case .flow:
                    return "Optimal! Maintain this balance"
                case .control:
                    return "Increase challenge to reach flow"
                case .relaxation:
                    return "Good for recovery, but seek challenges for growth"
                case .boredom:
                    return "Significantly increase challenge level"
                case .apathy:
                    return "Find activities you care about"
                case .worry:
                    return "Balance challenge and skill levels"
                }
            }
        }
    }

    // MARK: - Initialization

    private init() {
        print("==============================================")
        print("   POTENTIALENTFALTUNG - POTENTIAL DEVELOPMENT")
        print("==============================================")
        print("   Helping you become who you're meant to be")
        print("   Based on positive psychology research")
        print("   VIA Character Strengths framework")
        print("==============================================")

        initializeDefaultPractices()
    }

    // MARK: - Update from QuantumLifeScanner

    public func updateFromScan(_ scan: QuantumLifeScanner.LifeScan) async {
        if userPotentialProfile == nil {
            userPotentialProfile = PotentialProfile()
        }

        // Map strengths
        userPotentialProfile?.signatureStrengths = scan.strengths.map { strength in
            CharacterStrength(
                name: strength.name,
                virtue: mapToVirtue(strength.category),
                currentLevel: strength.level,
                growthPotential: 100 - strength.level + 20
            )
        }

        // Map flow state
        userPotentialProfile?.flowFrequency = scan.flowState

        // Map purpose
        userPotentialProfile?.ikigaiClarity = scan.purposeClarity

        // Map self-determination
        userPotentialProfile?.autonomy = scan.selfEfficacy
        userPotentialProfile?.competence = (scan.skillsInventory.map(\.proficiency).reduce(0, +) / Float(max(1, scan.skillsInventory.count)))
        userPotentialProfile?.relatedness = scan.socialWellbeing

        // Calculate intrinsic motivation
        if let profile = userPotentialProfile {
            userPotentialProfile?.intrinsicMotivation = (profile.autonomy + profile.competence + profile.relatedness) / 3
        }

        // Calculate overall potential realization
        userPotentialProfile?.potentialRealization = calculatePotentialRealization()

        userPotentialProfile?.lastUpdated = Date()

        print("   PotentialDev: Profile updated from scan")
        print("   Strengths: \(userPotentialProfile?.signatureStrengths.count ?? 0)")
        print("   Potential Realization: \(String(format: "%.1f", userPotentialProfile?.potentialRealization ?? 0))%")
    }

    // MARK: - Initialize Default Practices

    private func initializeDefaultPractices() {
        dailyPractices = [
            DailyPractice(
                name: "Gratitude Journaling",
                description: "Write 3 things you're grateful for",
                durationMinutes: 5,
                frequency: .daily,
                evidenceBase: "Increases wellbeing by 25% (Emmons & McCullough, 2003)"
            ),
            DailyPractice(
                name: "Strength Spotting",
                description: "Notice when you use your top strength today",
                durationMinutes: 2,
                frequency: .daily,
                evidenceBase: "Using strengths increases happiness (Seligman et al., 2005)"
            ),
            DailyPractice(
                name: "Flow Activity",
                description: "Engage in an activity that challenges you appropriately",
                durationMinutes: 30,
                frequency: .daily,
                evidenceBase: "Flow increases life satisfaction (Csikszentmihalyi, 1990)"
            ),
            DailyPractice(
                name: "Learning Time",
                description: "Learn something new in your area of interest",
                durationMinutes: 15,
                frequency: .daily,
                evidenceBase: "Continuous learning enhances neuroplasticity"
            ),
            DailyPractice(
                name: "Connection Moment",
                description: "Have a meaningful interaction with someone",
                durationMinutes: 10,
                frequency: .daily,
                evidenceBase: "Social connection is top predictor of happiness (Harvard Study)"
            )
        ]
    }

    // MARK: - Add Growth Goal

    public func addGrowthGoal(_ goal: GrowthGoal) {
        currentGrowthGoals.append(goal)
        print("   PotentialDev: Goal added - \(goal.title)")
    }

    // MARK: - Complete Goal

    public func completeGoal(_ goalId: UUID) {
        guard let index = currentGrowthGoals.firstIndex(where: { $0.id == goalId }) else { return }

        var goal = currentGrowthGoals[index]
        goal.isCompleted = true
        goal.completionDate = Date()
        goal.currentProgress = 100

        currentGrowthGoals[index] = goal

        // Create milestone
        let milestone = Milestone(
            title: "Completed: \(goal.title)",
            description: goal.description,
            category: goal.category.rawValue,
            growthPoints: 50
        )
        achievedMilestones.append(milestone)

        // Update journey
        developmentJourney?.totalGrowthPoints += 50

        print("   PotentialDev: Goal completed - \(goal.title)")
    }

    // MARK: - Log Practice

    public func logPractice(_ practiceId: UUID) {
        guard let index = dailyPractices.firstIndex(where: { $0.id == practiceId }) else { return }

        var practice = dailyPractices[index]
        practice.completionHistory.append(Date())

        // Update streak
        let calendar = Calendar.current
        if practice.completionHistory.count > 1 {
            let lastTwo = practice.completionHistory.suffix(2)
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
               let lastCompletion = lastTwo.first,
               calendar.isDate(lastCompletion, inSameDayAs: yesterday) {
                practice.currentStreak += 1
            } else {
                practice.currentStreak = 1
            }
        } else {
            practice.currentStreak = 1
        }

        practice.bestStreak = max(practice.bestStreak, practice.currentStreak)
        dailyPractices[index] = practice

        // Update journey streak
        developmentJourney?.streakDays = dailyPractices.map(\.currentStreak).max() ?? 0
        developmentJourney?.longestStreak = max(developmentJourney?.longestStreak ?? 0, developmentJourney?.streakDays ?? 0)

        print("   PotentialDev: Practice logged - \(practice.name) (Streak: \(practice.currentStreak))")
    }

    // MARK: - Start Flow Session

    public func startFlowSession(activity: String) -> FlowSession {
        var session = FlowSession(activity: activity)
        flowSessions.append(session)
        print("   PotentialDev: Flow session started - \(activity)")
        return session
    }

    // MARK: - End Flow Session

    public func endFlowSession(_ sessionId: UUID, flowIntensity: Float, insights: String) {
        guard let index = flowSessions.firstIndex(where: { $0.id == sessionId }) else { return }

        var session = flowSessions[index]
        session.endTime = Date()
        session.duration = session.endTime!.timeIntervalSince(session.startTime)
        session.flowIntensity = flowIntensity
        session.insights = insights

        flowSessions[index] = session

        // Update average flow duration
        let completedSessions = flowSessions.filter { $0.endTime != nil }
        if !completedSessions.isEmpty {
            userPotentialProfile?.flowDuration = completedSessions.map(\.duration).reduce(0, +) / Double(completedSessions.count)
        }

        print("   PotentialDev: Flow session ended - Duration: \(String(format: "%.0f", session.duration / 60)) min")
    }

    // MARK: - Add Insight

    public func addInsight(_ content: String, category: String, importance: Int = 3) {
        let insight = DevelopmentJourney.Insight(content: content, category: category, importance: importance)
        developmentJourney?.insights.append(insight)
        print("   PotentialDev: Insight recorded")
    }

    // MARK: - Calculate Potential Realization

    private func calculatePotentialRealization() -> Float {
        guard let profile = userPotentialProfile else { return 0 }

        var score: Float = 0

        // Maslow's hierarchy (weighted)
        score += profile.physiologicalNeeds * 0.10
        score += profile.safetyNeeds * 0.10
        score += profile.belongingNeeds * 0.15
        score += profile.esteemNeeds * 0.15
        score += profile.selfActualization * 0.25
        score += profile.transcendence * 0.10

        // Self-determination
        score += profile.intrinsicMotivation * 0.15

        return min(100, score)
    }

    // MARK: - Map to Virtue

    private func mapToVirtue(_ category: QuantumLifeScanner.Strength.StrengthCategory) -> CharacterStrength.Virtue {
        switch category {
        case .wisdom: return .wisdom
        case .courage: return .courage
        case .humanity: return .humanity
        case .justice: return .justice
        case .temperance: return .temperance
        case .transcendence: return .transcendence
        }
    }

    // MARK: - Generate Report

    public func getReport() -> String {
        guard let profile = userPotentialProfile else {
            return "No potential profile created yet. Complete a Quantum Life Scan to begin."
        }

        return """
        =====================================================
        POTENTIALENTFALTUNG - DEVELOPMENT REPORT
        =====================================================

        POTENTIAL REALIZATION: \(String(format: "%.1f", profile.potentialRealization))%

        MASLOW'S HIERARCHY:
        - Physiological: \(String(format: "%.0f", profile.physiologicalNeeds))%
        - Safety: \(String(format: "%.0f", profile.safetyNeeds))%
        - Belonging: \(String(format: "%.0f", profile.belongingNeeds))%
        - Esteem: \(String(format: "%.0f", profile.esteemNeeds))%
        - Self-Actualization: \(String(format: "%.0f", profile.selfActualization))%
        - Transcendence: \(String(format: "%.0f", profile.transcendence))%

        SELF-DETERMINATION:
        - Autonomy: \(String(format: "%.0f", profile.autonomy))%
        - Competence: \(String(format: "%.0f", profile.competence))%
        - Relatedness: \(String(format: "%.0f", profile.relatedness))%
        - Intrinsic Motivation: \(String(format: "%.0f", profile.intrinsicMotivation))%

        SIGNATURE STRENGTHS:
        \(profile.signatureStrengths.map { "  - \($0.name) (\($0.virtue.rawValue)): \(String(format: "%.0f", $0.currentLevel))%" }.joined(separator: "\n"))

        FLOW STATE:
        - Frequency: \(String(format: "%.0f", profile.flowFrequency))%
        - Average Duration: \(String(format: "%.0f", profile.flowDuration / 60)) minutes

        IKIGAI (Purpose) CLARITY: \(String(format: "%.0f", profile.ikigaiClarity))%

        GROWTH MINDSET: \(String(format: "%.0f", profile.growthMindsetScore))%

        CURRENT GOALS: \(currentGrowthGoals.count)
        \(currentGrowthGoals.map { "  - \($0.title): \(String(format: "%.0f", $0.currentProgress))%" }.joined(separator: "\n"))

        MILESTONES ACHIEVED: \(achievedMilestones.count)
        TOTAL GROWTH POINTS: \(developmentJourney?.totalGrowthPoints ?? 0)
        CURRENT STREAK: \(developmentJourney?.streakDays ?? 0) days

        =====================================================
        "The only person you are destined to become is the
        person you decide to be." - Ralph Waldo Emerson
        =====================================================
        """
    }
}
