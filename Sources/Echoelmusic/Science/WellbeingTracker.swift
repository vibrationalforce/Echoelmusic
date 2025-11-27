import Foundation
import Combine

/// WellbeingTracker - Scientific Outcome Measurement System
/// Tracking well-being progress with evidence-based metrics
///
/// Mission: Provide scientific validation of well-being progress while
/// honoring the subjective experience of each person's journey.
///
/// Scientific Foundation:
/// - Patient-Reported Outcome Measures (PROMs) - FDA Guidance
/// - Minimal Clinically Important Difference (MCID) - Jaeschke et al., 1989
/// - Goal Attainment Scaling (GAS) - Kiresuk & Sherman, 1968
/// - Reliable Change Index (RCI) - Jacobson & Truax, 1991
/// - WHO Quality of Life (WHOQOL-BREF)
/// - HeartMath Coherence Research
///
/// Accessibility: Visual, audio, and simplified progress tracking
/// Privacy: Local-first, user-controlled data sharing
@MainActor
public final class WellbeingTracker: ObservableObject {

    // MARK: - Singleton

    public static let shared = WellbeingTracker()

    // MARK: - Published State

    @Published public var wellbeingJourney: WellbeingJourney?
    @Published public var currentProtocol: ActiveProtocol?
    @Published public var outcomes: [OutcomeMeasure] = []
    @Published public var milestones: [WellbeingMilestone] = []
    @Published public var dailyLogs: [DailyLog] = []
    @Published public var scientificReport: ScientificReport?

    // MARK: - Well-being Journey

    public struct WellbeingJourney: Codable, Identifiable {
        public let id: UUID
        public var startDate: Date
        public var primaryGoals: [WellbeingGoal]
        public var currentPhase: WellbeingPhase
        public var overallProgress: Float           // 0-100
        public var qualityOfLife: Float             // 0-100 (WHOQOL-BREF mapped)
        public var functioningLevel: Float          // 0-100
        public var symptomReduction: Float          // 0-100
        public var wellbeingIncrease: Float         // 0-100
        public var coherenceProgress: Float         // 0-100
        public var resilienceGrowth: Float          // 0-100
        public var totalSessions: Int
        public var totalMinutes: Int
        public var streakDays: Int
        public var longestStreak: Int

        public init() {
            self.id = UUID()
            self.startDate = Date()
            self.primaryGoals = []
            self.currentPhase = .foundation
            self.overallProgress = 0
            self.qualityOfLife = 50
            self.functioningLevel = 50
            self.symptomReduction = 0
            self.wellbeingIncrease = 0
            self.coherenceProgress = 0
            self.resilienceGrowth = 0
            self.totalSessions = 0
            self.totalMinutes = 0
            self.streakDays = 0
            self.longestStreak = 0
        }
    }

    // MARK: - Well-being Goal

    public struct WellbeingGoal: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var description: String
        public var category: GoalCategory
        public var baseline: Float              // Starting point (0-100)
        public var target: Float                // Target level (0-100)
        public var current: Float               // Current level (0-100)
        public var mcid: Float                  // Minimal Clinically Important Difference
        public var startDate: Date
        public var targetDate: Date
        public var measurements: [Measurement]
        public var isAchieved: Bool
        public var achievedDate: Date?

        public init(title: String, description: String, category: GoalCategory, baseline: Float, target: Float, targetDate: Date) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.category = category
            self.baseline = baseline
            self.target = target
            self.current = baseline
            self.mcid = category.typicalMCID
            self.startDate = Date()
            self.targetDate = targetDate
            self.measurements = []
            self.isAchieved = false
            self.achievedDate = nil
        }

        public var progress: Float {
            guard target != baseline else { return 0 }
            return min(100, max(0, (current - baseline) / (target - baseline) * 100))
        }

        public var hasReachedMCID: Bool {
            return abs(current - baseline) >= mcid
        }

        public struct Measurement: Codable, Identifiable {
            public let id: UUID
            public var date: Date
            public var value: Float
            public var notes: String

            public init(value: Float, notes: String = "") {
                self.id = UUID()
                self.date = Date()
                self.value = value
                self.notes = notes
            }
        }

        public enum GoalCategory: String, Codable, CaseIterable {
            case anxiety = "Anxiety Reduction"
            case depression = "Depression Relief"
            case stress = "Stress Management"
            case sleep = "Sleep Improvement"
            case pain = "Pain Management"
            case energy = "Energy Enhancement"
            case coherence = "Coherence Building"
            case resilience = "Resilience Building"
            case focus = "Focus & Concentration"
            case emotional = "Emotional Regulation"
            case social = "Social Connection"
            case purpose = "Purpose & Meaning"

            var typicalMCID: Float {
                // Minimal Clinically Important Difference (research-based)
                switch self {
                case .anxiety: return 5.0        // GAD-7: 5 points
                case .depression: return 5.0     // PHQ-9: 5 points
                case .stress: return 10.0        // PSS: 10%
                case .sleep: return 7.0          // PSQI: 3 points mapped to %
                case .pain: return 15.0          // VAS: 15mm/15%
                case .energy: return 10.0        // Fatigue scales: ~10%
                case .coherence: return 10.0     // HeartMath research
                case .resilience: return 8.0     // CD-RISC: ~8%
                case .focus: return 10.0         // Attention measures
                case .emotional: return 10.0     // DERS mapped
                case .social: return 10.0        // UCLA Loneliness mapped
                case .purpose: return 10.0       // MLQ: 10%
                }
            }

            var validatedInstrument: String {
                switch self {
                case .anxiety: return "GAD-7 (Generalized Anxiety Disorder-7)"
                case .depression: return "PHQ-9 (Patient Health Questionnaire-9)"
                case .stress: return "PSS-10 (Perceived Stress Scale)"
                case .sleep: return "PSQI (Pittsburgh Sleep Quality Index)"
                case .pain: return "VAS (Visual Analog Scale)"
                case .energy: return "FSS (Fatigue Severity Scale)"
                case .coherence: return "HeartMath Coherence Score"
                case .resilience: return "CD-RISC (Connor-Davidson Resilience Scale)"
                case .focus: return "ASRS (Adult ADHD Self-Report Scale)"
                case .emotional: return "DERS (Difficulties in Emotion Regulation Scale)"
                case .social: return "UCLA Loneliness Scale"
                case .purpose: return "MLQ (Meaning in Life Questionnaire)"
                }
            }
        }
    }

    // MARK: - Well-being Phase

    public enum WellbeingPhase: String, Codable, CaseIterable {
        case assessment = "Assessment"
        case foundation = "Foundation"
        case development = "Development"
        case integration = "Integration"
        case growth = "Growth"
        case maintenance = "Maintenance"
        case thriving = "Thriving"

        var description: String {
            switch self {
            case .assessment:
                return "Understanding your current state and needs"
            case .foundation:
                return "Building safety, routine, and basic coping skills"
            case .development:
                return "Working through challenges with new tools"
            case .integration:
                return "Combining learnings into daily life"
            case .growth:
                return "Expanding beyond baseline to new capabilities"
            case .maintenance:
                return "Sustaining gains and preventing setbacks"
            case .thriving:
                return "Living fully with resilience and purpose"
            }
        }

        var typicalDuration: String {
            switch self {
            case .assessment: return "1-2 weeks"
            case .foundation: return "2-4 weeks"
            case .development: return "4-12 weeks"
            case .integration: return "4-8 weeks"
            case .growth: return "Ongoing"
            case .maintenance: return "Ongoing"
            case .thriving: return "Ongoing"
            }
        }

        var evidenceBase: String {
            switch self {
            case .assessment:
                return "Based on biopsychosocial assessment model (Engel, 1977)"
            case .foundation:
                return "Phase-based treatment (Herman, 1992)"
            case .development:
                return "Cognitive processing models (Beck, 1976)"
            case .integration:
                return "Integration in learning theory (Kolb, 1984)"
            case .growth:
                return "Post-traumatic growth (Tedeschi & Calhoun, 2004)"
            case .maintenance:
                return "Relapse prevention (Marlatt & Gordon, 1985)"
            case .thriving:
                return "Flourishing model (Seligman, 2011)"
            }
        }
    }

    // MARK: - Active Protocol

    public struct ActiveProtocol: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var description: String
        public var interventions: [ProtocolIntervention]
        public var startDate: Date
        public var endDate: Date?
        public var totalSessions: Int
        public var completedSessions: Int
        public var adherenceRate: Float             // 0-100
        public var effectiveness: Float             // 0-100
        public var evidenceLevel: String
        public var adaptations: [String]            // Accessibility/cultural adaptations

        public init(name: String, description: String, totalSessions: Int) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.interventions = []
            self.startDate = Date()
            self.endDate = nil
            self.totalSessions = totalSessions
            self.completedSessions = 0
            self.adherenceRate = 0
            self.effectiveness = 0
            self.evidenceLevel = "Level 1a"
            self.adaptations = []
        }

        public var progress: Float {
            guard totalSessions > 0 else { return 0 }
            return Float(completedSessions) / Float(totalSessions) * 100
        }
    }

    // MARK: - Protocol Intervention

    public struct ProtocolIntervention: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var type: InterventionType
        public var frequency: String
        public var duration: TimeInterval
        public var instructions: String
        public var completions: [InterventionCompletion]
        public var accessibilityVersion: String

        public init(name: String, type: InterventionType, frequency: String, duration: TimeInterval, instructions: String) {
            self.id = UUID()
            self.name = name
            self.type = type
            self.frequency = frequency
            self.duration = duration
            self.instructions = instructions
            self.completions = []
            self.accessibilityVersion = ""
        }

        public enum InterventionType: String, Codable, CaseIterable {
            case breathing = "Breathing Exercise"
            case meditation = "Meditation"
            case biofeedback = "Biofeedback"
            case movement = "Movement"
            case cognitive = "Cognitive Exercise"
            case behavioral = "Behavioral Activation"
            case social = "Social Connection"
            case creative = "Creative Expression"
            case nature = "Nature Exposure"
            case sleep = "Sleep Hygiene"
            case music = "Music Therapy"
            case relaxation = "Relaxation"
        }

        public struct InterventionCompletion: Codable, Identifiable {
            public let id: UUID
            public var date: Date
            public var duration: TimeInterval
            public var rating: Float            // 0-100, how helpful
            public var notes: String
            public var biometrics: BiometricData?

            public init(duration: TimeInterval, rating: Float, notes: String = "") {
                self.id = UUID()
                self.date = Date()
                self.duration = duration
                self.rating = rating
                self.notes = notes
                self.biometrics = nil
            }

            public struct BiometricData: Codable {
                public var hrvBefore: Float?
                public var hrvAfter: Float?
                public var coherenceBefore: Float?
                public var coherenceAfter: Float?
                public var stressBefore: Float?
                public var stressAfter: Float?
            }
        }
    }

    // MARK: - Outcome Measure

    public struct OutcomeMeasure: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var instrument: String           // Validated instrument name
        public var category: HealingGoal.GoalCategory
        public var baseline: Float
        public var measurements: [TimedMeasurement]
        public var targetImprovement: Float     // % improvement goal
        public var mcid: Float                  // Minimal Clinically Important Difference
        public var reliableChangeIndex: Float   // RCI threshold

        public init(name: String, instrument: String, category: HealingGoal.GoalCategory, baseline: Float) {
            self.id = UUID()
            self.name = name
            self.instrument = instrument
            self.category = category
            self.baseline = baseline
            self.measurements = []
            self.targetImprovement = 30         // Default 30% improvement
            self.mcid = category.typicalMCID
            self.reliableChangeIndex = calculateRCI(mcid: category.typicalMCID)
        }

        public var currentValue: Float {
            measurements.last?.value ?? baseline
        }

        public var changeFromBaseline: Float {
            currentValue - baseline
        }

        public var percentImprovement: Float {
            guard baseline != 0 else { return 0 }
            return (baseline - currentValue) / baseline * 100  // Lower is better for symptoms
        }

        public var hasReliableChange: Bool {
            return abs(changeFromBaseline) >= reliableChangeIndex
        }

        public var hasClinicallySignificantChange: Bool {
            return abs(changeFromBaseline) >= mcid
        }

        public struct TimedMeasurement: Codable, Identifiable {
            public let id: UUID
            public var date: Date
            public var value: Float
            public var context: String          // What was happening

            public init(value: Float, context: String = "") {
                self.id = UUID()
                self.date = Date()
                self.value = value
                self.context = context
            }
        }

        private func calculateRCI(mcid: Float) -> Float {
            // Simplified RCI calculation
            // In production: Use actual reliability coefficients
            return mcid * 1.96 * sqrt(2 * (1 - 0.85))  // Assuming r = 0.85
        }
    }

    // MARK: - Well-being Milestone

    public struct WellbeingMilestone: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var description: String
        public var achievedDate: Date
        public var category: MilestoneCategory
        public var significance: String
        public var celebrationNote: String

        public init(title: String, description: String, category: MilestoneCategory, significance: String = "") {
            self.id = UUID()
            self.title = title
            self.description = description
            self.achievedDate = Date()
            self.category = category
            self.significance = significance
            self.celebrationNote = ""
        }

        public enum MilestoneCategory: String, Codable, CaseIterable {
            case firstSession = "First Session"
            case weekStreak = "Week Streak"
            case monthStreak = "Month Streak"
            case mcidReached = "Clinically Significant Improvement"
            case goalAchieved = "Goal Achieved"
            case phaseCompleted = "Phase Completed"
            case breakthrough = "Personal Breakthrough"
            case skillMastered = "Skill Mastered"
            case setbackOvercome = "Setback Overcome"
        }
    }

    // MARK: - Daily Log

    public struct DailyLog: Codable, Identifiable {
        public let id: UUID
        public var date: Date
        public var overallWellbeing: Float      // 0-100
        public var mood: Float                  // 0-100
        public var energy: Float                // 0-100
        public var sleep: Float                 // 0-100
        public var stress: Float                // 0-100 (lower better)
        public var practicesCompleted: [String]
        public var insights: String
        public var gratitudes: [String]
        public var challenges: [String]
        public var wins: [String]
        public var biometrics: DailyBiometrics?

        public init() {
            self.id = UUID()
            self.date = Date()
            self.overallWellbeing = 50
            self.mood = 50
            self.energy = 50
            self.sleep = 50
            self.stress = 50
            self.practicesCompleted = []
            self.insights = ""
            self.gratitudes = []
            self.challenges = []
            self.wins = []
            self.biometrics = nil
        }

        public struct DailyBiometrics: Codable {
            public var avgHRV: Float?
            public var avgCoherence: Float?
            public var peakCoherence: Float?
            public var totalCoherenceMinutes: Int?
            public var restingHeartRate: Float?
        }
    }

    // MARK: - Scientific Report

    public struct ScientificReport: Codable {
        public var generatedDate: Date
        public var reportPeriod: DateInterval
        public var participantId: String        // Anonymous ID

        // Summary Statistics
        public var baselineAssessment: [String: Float]
        public var currentAssessment: [String: Float]
        public var changeScores: [String: Float]
        public var effectSizes: [String: Float]     // Cohen's d

        // Clinical Significance
        public var clinicallySignificantChanges: [String]
        public var reliableChanges: [String]
        public var goalsAchieved: Int
        public var goalsInProgress: Int

        // Engagement Metrics
        public var totalSessions: Int
        public var totalMinutes: Int
        public var adherenceRate: Float
        public var streakDays: Int

        // Intervention Effectiveness
        public var interventionRatings: [String: Float]
        public var mostEffectiveInterventions: [String]
        public var recommendedAdjustments: [String]

        // Trends
        public var weeklyTrends: [WeeklyTrend]
        public var overallTrajectory: String

        public init(reportPeriod: DateInterval) {
            self.generatedDate = Date()
            self.reportPeriod = reportPeriod
            self.participantId = UUID().uuidString.prefix(8).description

            self.baselineAssessment = [:]
            self.currentAssessment = [:]
            self.changeScores = [:]
            self.effectSizes = [:]

            self.clinicallySignificantChanges = []
            self.reliableChanges = []
            self.goalsAchieved = 0
            self.goalsInProgress = 0

            self.totalSessions = 0
            self.totalMinutes = 0
            self.adherenceRate = 0
            self.streakDays = 0

            self.interventionRatings = [:]
            self.mostEffectiveInterventions = []
            self.recommendedAdjustments = []

            self.weeklyTrends = []
            self.overallTrajectory = "Improving"
        }

        public struct WeeklyTrend: Codable, Identifiable {
            public let id: UUID
            public var weekNumber: Int
            public var startDate: Date
            public var avgWellbeing: Float
            public var avgCoherence: Float
            public var sessionsCompleted: Int
            public var keyEvent: String?

            public init(weekNumber: Int, startDate: Date) {
                self.id = UUID()
                self.weekNumber = weekNumber
                self.startDate = startDate
                self.avgWellbeing = 50
                self.avgCoherence = 50
                self.sessionsCompleted = 0
                self.keyEvent = nil
            }
        }
    }

    // MARK: - Initialization

    private init() {
        print("==============================================")
        print("   WELLBEING TRACKER")
        print("==============================================")
        print("   Scientific outcome measurement")
        print("   Evidence-based progress tracking")
        print("   MCID & RCI validated changes")
        print("==============================================")
    }

    // MARK: - Record Scan

    public func recordScan(_ scan: EchoelScan.LifeScan) async {
        if wellbeingJourney == nil {
            wellbeingJourney = WellbeingJourney()
        }

        // Update journey metrics
        wellbeingJourney?.qualityOfLife = scan.overallWellbeing
        wellbeingJourney?.functioningLevel = (scan.physicalWellbeing + scan.mentalWellbeing) / 2
        wellbeingJourney?.coherenceProgress = scan.coherenceLevel * 100
        wellbeingJourney?.resilienceGrowth = scan.resilience

        // Record outcome measurements
        recordOutcome(name: "Anxiety", category: .anxiety, value: scan.anxietyLevel)
        recordOutcome(name: "Stress", category: .stress, value: scan.stressIndex)
        recordOutcome(name: "Social Connection", category: .social, value: scan.socialWellbeing)
        recordOutcome(name: "Energy", category: .energy, value: scan.energyLevel)
        recordOutcome(name: "Sleep", category: .sleep, value: scan.sleepQuality)
        recordOutcome(name: "Coherence", category: .coherence, value: scan.coherenceLevel * 100)

        // Check for milestones
        checkMilestones()

        // Update phase if needed
        updatePhase()

        print("   WellbeingTracker: Scan recorded")
        print("   Quality of Life: \(String(format: "%.1f", scan.overallWellbeing))%")
    }

    // MARK: - Record Outcome

    private func recordOutcome(name: String, category: HealingGoal.GoalCategory, value: Float) {
        if let index = outcomes.firstIndex(where: { $0.name == name }) {
            outcomes[index].measurements.append(
                OutcomeMeasure.TimedMeasurement(value: value)
            )
        } else {
            var outcome = OutcomeMeasure(
                name: name,
                instrument: category.validatedInstrument,
                category: category,
                baseline: value
            )
            outcomes.append(outcome)
        }
    }

    // MARK: - Start Protocol

    public func startProtocol(name: String, description: String, sessions: Int) -> ActiveProtocol {
        let protocol_ = ActiveProtocol(name: name, description: description, totalSessions: sessions)
        currentProtocol = protocol_
        print("   WellbeingTracker: Protocol started - \(name)")
        return protocol_
    }

    // MARK: - Log Session

    public func logSession(interventionId: UUID?, duration: TimeInterval, rating: Float, notes: String = "") {
        // Update protocol
        currentProtocol?.completedSessions += 1

        // Update journey
        wellbeingJourney?.totalSessions += 1
        wellbeingJourney?.totalMinutes += Int(duration / 60)

        // Update streak
        updateStreak()

        // Calculate adherence
        if let protocol_ = currentProtocol {
            currentProtocol?.adherenceRate = Float(protocol_.completedSessions) / Float(protocol_.totalSessions) * 100
        }

        print("   WellbeingTracker: Session logged (\(String(format: "%.0f", duration/60)) min, Rating: \(String(format: "%.0f", rating)))")
    }

    // MARK: - Log Daily

    public func logDaily(_ log: DailyLog) {
        dailyLogs.append(log)
        updateStreak()
        print("   WellbeingTracker: Daily log recorded")
    }

    // MARK: - Generate Report

    public func generateScientificReport(periodDays: Int = 30) -> ScientificReport {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -periodDays, to: endDate)!
        let period = DateInterval(start: startDate, end: endDate)

        var report = ScientificReport(reportPeriod: period)

        // Calculate baseline and current for each outcome
        for outcome in outcomes {
            report.baselineAssessment[outcome.name] = outcome.baseline
            report.currentAssessment[outcome.name] = outcome.currentValue
            report.changeScores[outcome.name] = outcome.changeFromBaseline

            // Calculate effect size (Cohen's d)
            // Simplified: using 10 as standard deviation approximation
            let effectSize = outcome.changeFromBaseline / 10
            report.effectSizes[outcome.name] = effectSize

            // Check significance
            if outcome.hasClinicallySignificantChange {
                report.clinicallySignificantChanges.append(outcome.name)
            }
            if outcome.hasReliableChange {
                report.reliableChanges.append(outcome.name)
            }
        }

        // Goals
        if let journey = healingJourney {
            report.goalsAchieved = journey.primaryGoals.filter { $0.isAchieved }.count
            report.goalsInProgress = journey.primaryGoals.filter { !$0.isAchieved }.count
            report.totalSessions = journey.totalSessions
            report.totalMinutes = journey.totalMinutes
            report.streakDays = journey.streakDays
        }

        // Adherence
        report.adherenceRate = currentProtocol?.adherenceRate ?? 0

        // Weekly trends
        report.weeklyTrends = generateWeeklyTrends(for: period)

        // Determine trajectory
        report.overallTrajectory = determineTrajectory()

        scientificReport = report
        print("   WellbeingTracker: Scientific report generated")

        return report
    }

    // MARK: - Helper Methods

    private func checkMilestones() {
        guard let journey = wellbeingJourney else { return }

        // First session
        if journey.totalSessions == 1 && !milestones.contains(where: { $0.category == .firstSession }) {
            addMilestone(title: "First Step", description: "Completed your first well-being session", category: .firstSession)
        }

        // Week streak
        if journey.streakDays >= 7 && !milestones.contains(where: { $0.category == .weekStreak && $0.achievedDate > Date().addingTimeInterval(-86400 * 7) }) {
            addMilestone(title: "One Week Strong", description: "Maintained practice for 7 consecutive days", category: .weekStreak)
        }

        // MCID reached
        for outcome in outcomes where outcome.hasClinicallySignificantChange {
            if !milestones.contains(where: { $0.title.contains(outcome.name) && $0.category == .mcidReached }) {
                addMilestone(
                    title: "Breakthrough: \(outcome.name)",
                    description: "Achieved clinically significant improvement in \(outcome.name)",
                    category: .mcidReached,
                    significance: "Change of \(String(format: "%.1f", outcome.changeFromBaseline)) exceeds MCID threshold"
                )
            }
        }
    }

    private func addMilestone(title: String, description: String, category: WellbeingMilestone.MilestoneCategory, significance: String = "") {
        let milestone = WellbeingMilestone(
            title: title,
            description: description,
            category: category,
            significance: significance
        )
        milestones.append(milestone)
        print("   Milestone achieved: \(title)")
    }

    private func updateStreak() {
        guard let journey = wellbeingJourney else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if logged yesterday or today
        let recentLogs = dailyLogs.filter { log in
            let logDay = calendar.startOfDay(for: log.date)
            let daysDiff = calendar.dateComponents([.day], from: logDay, to: today).day ?? 0
            return daysDiff <= 1
        }

        if recentLogs.isEmpty {
            wellbeingJourney?.streakDays = 0
        } else {
            wellbeingJourney?.streakDays += 1
        }

        wellbeingJourney?.longestStreak = max(journey.longestStreak, wellbeingJourney?.streakDays ?? 0)
    }

    private func updatePhase() {
        guard let journey = wellbeingJourney else { return }

        // Simple phase progression based on progress
        let progress = journey.overallProgress
        let newPhase: WellbeingPhase

        switch progress {
        case 0..<10: newPhase = .assessment
        case 10..<25: newPhase = .foundation
        case 25..<50: newPhase = .development
        case 50..<70: newPhase = .integration
        case 70..<85: newPhase = .growth
        case 85..<95: newPhase = .maintenance
        default: newPhase = .thriving
        }

        if newPhase != journey.currentPhase {
            wellbeingJourney?.currentPhase = newPhase
            addMilestone(
                title: "Phase: \(newPhase.rawValue)",
                description: "Advanced to the \(newPhase.rawValue) phase",
                category: .phaseCompleted
            )
        }
    }

    private func generateWeeklyTrends(for period: DateInterval) -> [ScientificReport.WeeklyTrend] {
        var trends: [ScientificReport.WeeklyTrend] = []
        let calendar = Calendar.current
        var weekStart = period.start

        var weekNumber = 1
        while weekStart < period.end {
            var trend = ScientificReport.WeeklyTrend(weekNumber: weekNumber, startDate: weekStart)

            // Filter logs for this week
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let weekLogs = dailyLogs.filter { $0.date >= weekStart && $0.date < weekEnd }

            if !weekLogs.isEmpty {
                trend.avgWellbeing = weekLogs.map(\.overallWellbeing).reduce(0, +) / Float(weekLogs.count)
                trend.sessionsCompleted = weekLogs.reduce(0) { $0 + $1.practicesCompleted.count }
            }

            trends.append(trend)

            weekStart = weekEnd
            weekNumber += 1
        }

        return trends
    }

    private func determineTrajectory() -> String {
        guard let report = scientificReport, report.weeklyTrends.count >= 2 else {
            return "Insufficient data"
        }

        let recentWeeks = report.weeklyTrends.suffix(4)
        let wellbeingValues = recentWeeks.map(\.avgWellbeing)

        // Simple linear trend
        var increasing = 0
        var decreasing = 0

        for i in 1..<wellbeingValues.count {
            if wellbeingValues[i] > wellbeingValues[i-1] { increasing += 1 }
            else if wellbeingValues[i] < wellbeingValues[i-1] { decreasing += 1 }
        }

        if increasing > decreasing { return "Improving" }
        else if decreasing > increasing { return "Needs attention" }
        else { return "Stable" }
    }

    // MARK: - Report

    public func getReport() -> String {
        guard let journey = wellbeingJourney else {
            return "No well-being journey started. Complete an EchoelScan to begin."
        }

        return """
        =====================================================
        WELLBEING PROGRESS REPORT
        =====================================================

        CURRENT PHASE: \(journey.currentPhase.rawValue)
        \(journey.currentPhase.description)

        OVERALL PROGRESS: \(String(format: "%.1f", journey.overallProgress))%

        KEY METRICS:
        - Quality of Life: \(String(format: "%.1f", journey.qualityOfLife))%
        - Functioning Level: \(String(format: "%.1f", journey.functioningLevel))%
        - Symptom Reduction: \(String(format: "%.1f", journey.symptomReduction))%
        - Coherence Progress: \(String(format: "%.1f", journey.coherenceProgress))%
        - Resilience Growth: \(String(format: "%.1f", journey.resilienceGrowth))%

        ENGAGEMENT:
        - Total Sessions: \(journey.totalSessions)
        - Total Time: \(journey.totalMinutes) minutes
        - Current Streak: \(journey.streakDays) days
        - Longest Streak: \(journey.longestStreak) days

        OUTCOME MEASURES:
        \(outcomes.map { "  - \($0.name): \(String(format: "%.1f", $0.currentValue)) (Change: \(String(format: "%.1f", $0.changeFromBaseline)))" }.joined(separator: "\n"))

        CLINICALLY SIGNIFICANT IMPROVEMENTS:
        \(outcomes.filter { $0.hasClinicallySignificantChange }.map { "  - \($0.name)" }.joined(separator: "\n"))

        MILESTONES ACHIEVED: \(milestones.count)
        \(milestones.suffix(5).map { "  - \($0.title) (\($0.achievedDate.formatted(date: .abbreviated, time: .omitted)))" }.joined(separator: "\n"))

        =====================================================
        "Every step forward is progress. Be kind to yourself."
        =====================================================
        """
    }
}
