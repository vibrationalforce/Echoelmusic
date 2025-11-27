import Foundation
import Combine

/// Echoelworks - Creative Audio & Well-being Career Platform
/// Connecting creative talent with opportunities in audio, well-being, and creative industries
///
/// Mission: Every person deserves access to meaningful work that aligns with
/// their talents, respects their abilities, and contributes to wellbeing.
///
/// Career Domains (Not Just Music!):
/// - Audio & Sound (Music, Podcasts, Sound Design, Audio Engineering)
/// - Well-being & Therapeutic (Sound Therapy, Meditation, Biofeedback)
/// - Creative Production (Content Creation, Streaming, Multimedia)
/// - Technology & Development (Audio Tech, App Dev, AI/ML)
/// - Education & Coaching (Teaching, Mentoring, Training)
/// - Business & Management (Artist Management, Booking, Consulting)
///
/// Target Audience:
/// - Musicians & Audio Professionals
/// - Podcasters & Content Creators
/// - Sound Designers & Audio Engineers
/// - Well-being Practitioners & Therapists
/// - Educators & Coaches
/// - Tech Developers & Creatives
/// - Career Changers & New Entrants
///
/// Scientific Foundation:
/// - Holland Occupational Themes (RIASEC) - Holland, 1997
/// - Self-Determination Theory - Deci & Ryan, 2000
/// - Career Construction Theory - Savickas, 2005
/// - Strengths-Based Development - Gallup Research
/// - Vocational Rehabilitation Research - WHO/ILO Guidelines
///
/// Accessibility: Designed for people of ALL abilities
/// - Physical disabilities: Remote work prioritization
/// - Cognitive differences: Neurodiversity-friendly matching
/// - Sensory impairments: Accessible job recommendations
/// - Mental health considerations: Stress-appropriate roles
@MainActor
public final class Echoelworks: ObservableObject {

    // MARK: - Singleton

    public static let shared = Echoelworks()

    // MARK: - Published State

    @Published public var userProfile: WorkerProfile?
    @Published public var jobMatches: [JobOpportunity] = []
    @Published public var savedJobs: [JobOpportunity] = []
    @Published public var applications: [JobApplication] = []
    @Published public var skillDevelopmentPlan: SkillDevelopmentPlan?
    @Published public var careerPath: CareerPath?

    // MARK: - Matching Settings

    @Published public var matchingPreferences: MatchingPreferences = MatchingPreferences()
    @Published public var accessibilityRequirements: AccessibilityRequirements = AccessibilityRequirements()

    // MARK: - Worker Profile

    public struct WorkerProfile: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var email: String
        public var language: String
        public var country: String
        public var timezone: String

        // Skills & Experience
        public var skills: [WorkSkill]
        public var education: [Education]
        public var workHistory: [WorkExperience]
        public var certifications: [Certification]

        // Strengths & Interests (from EchoelScan)
        public var characterStrengths: [String]
        public var hollandCodes: [String]    // RIASEC
        public var values: [WorkValue]

        // Accessibility & Accommodations
        public var accessibilityNeeds: [AccessibilityNeed]
        public var workAccommodations: [String]
        public var preferredWorkStyle: WorkStyle

        // Availability
        public var availability: Availability
        public var willingToRelocate: Bool
        public var remotePreference: RemotePreference

        // Health & Wellbeing Integration
        public var wellbeingScore: Float?    // From EchoelScan
        public var stressCapacity: StressCapacity
        public var idealWorkEnvironment: [String]

        public init() {
            self.id = UUID()
            self.name = ""
            self.email = ""
            self.language = "en"
            self.country = ""
            self.timezone = TimeZone.current.identifier
            self.skills = []
            self.education = []
            self.workHistory = []
            self.certifications = []
            self.characterStrengths = []
            self.hollandCodes = []
            self.values = []
            self.accessibilityNeeds = []
            self.workAccommodations = []
            self.preferredWorkStyle = .hybrid
            self.availability = Availability()
            self.willingToRelocate = false
            self.remotePreference = .remotePreferred
            self.wellbeingScore = nil
            self.stressCapacity = .moderate
            self.idealWorkEnvironment = []
        }
    }

    // MARK: - Work Skill

    public struct WorkSkill: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var category: SkillCategory
        public var proficiency: ProficiencyLevel
        public var yearsExperience: Float
        public var isVerified: Bool
        public var verificationSource: String?
        public var marketDemand: MarketDemand

        public init(name: String, category: SkillCategory, proficiency: ProficiencyLevel, yearsExperience: Float = 0) {
            self.id = UUID()
            self.name = name
            self.category = category
            self.proficiency = proficiency
            self.yearsExperience = yearsExperience
            self.isVerified = false
            self.verificationSource = nil
            self.marketDemand = .moderate
        }

        public enum SkillCategory: String, Codable, CaseIterable {
            case technical = "Technical"
            case creative = "Creative"
            case analytical = "Analytical"
            case interpersonal = "Interpersonal"
            case leadership = "Leadership"
            case administrative = "Administrative"
            case physical = "Physical"
            case digital = "Digital"
            case language = "Language"
            case healthcare = "Healthcare"
            case education = "Education"
            case trade = "Trade/Craft"
        }

        public enum ProficiencyLevel: String, Codable, CaseIterable {
            case beginner = "Beginner"
            case intermediate = "Intermediate"
            case advanced = "Advanced"
            case expert = "Expert"
            case master = "Master"

            var score: Float {
                switch self {
                case .beginner: return 20
                case .intermediate: return 40
                case .advanced: return 60
                case .expert: return 80
                case .master: return 100
                }
            }
        }

        public enum MarketDemand: String, Codable {
            case veryHigh = "Very High Demand"
            case high = "High Demand"
            case moderate = "Moderate Demand"
            case low = "Low Demand"
            case emerging = "Emerging Field"
            case declining = "Declining Field"
        }
    }

    // MARK: - Education

    public struct Education: Codable, Identifiable {
        public let id: UUID
        public var institution: String
        public var degree: String
        public var field: String
        public var completionYear: Int?
        public var isCompleted: Bool

        public init(institution: String, degree: String, field: String, completionYear: Int? = nil, isCompleted: Bool = true) {
            self.id = UUID()
            self.institution = institution
            self.degree = degree
            self.field = field
            self.completionYear = completionYear
            self.isCompleted = isCompleted
        }
    }

    // MARK: - Work Experience

    public struct WorkExperience: Codable, Identifiable {
        public let id: UUID
        public var company: String
        public var title: String
        public var description: String
        public var startDate: Date
        public var endDate: Date?
        public var isCurrent: Bool
        public var skillsUsed: [String]
        public var achievements: [String]

        public init(company: String, title: String, description: String, startDate: Date, endDate: Date? = nil, isCurrent: Bool = false) {
            self.id = UUID()
            self.company = company
            self.title = title
            self.description = description
            self.startDate = startDate
            self.endDate = endDate
            self.isCurrent = isCurrent
            self.skillsUsed = []
            self.achievements = []
        }
    }

    // MARK: - Certification

    public struct Certification: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var issuer: String
        public var dateObtained: Date
        public var expirationDate: Date?
        public var verificationURL: String?

        public init(name: String, issuer: String, dateObtained: Date, expirationDate: Date? = nil) {
            self.id = UUID()
            self.name = name
            self.issuer = issuer
            self.dateObtained = dateObtained
            self.expirationDate = expirationDate
            self.verificationURL = nil
        }
    }

    // MARK: - Work Values

    public enum WorkValue: String, Codable, CaseIterable {
        case achievement = "Achievement"
        case independence = "Independence"
        case recognition = "Recognition"
        case relationships = "Relationships"
        case support = "Support"
        case workingConditions = "Working Conditions"
        case creativity = "Creativity"
        case security = "Security"
        case variety = "Variety"
        case compensation = "Compensation"
        case workLifeBalance = "Work-Life Balance"
        case socialImpact = "Social Impact"
        case learning = "Continuous Learning"
        case leadership = "Leadership"

        var description: String {
            switch self {
            case .achievement: return "Sense of accomplishment and mastery"
            case .independence: return "Autonomy and self-direction"
            case .recognition: return "Appreciation and acknowledgment"
            case .relationships: return "Positive workplace connections"
            case .support: return "Guidance and assistance available"
            case .workingConditions: return "Safe and comfortable environment"
            case .creativity: return "Opportunity for creative expression"
            case .security: return "Stable and predictable employment"
            case .variety: return "Diverse tasks and challenges"
            case .compensation: return "Fair pay and benefits"
            case .workLifeBalance: return "Time for personal life"
            case .socialImpact: return "Making a difference in the world"
            case .learning: return "Growth and development opportunities"
            case .leadership: return "Opportunity to guide others"
            }
        }
    }

    // MARK: - Accessibility Need

    public enum AccessibilityNeed: String, Codable, CaseIterable {
        // Physical
        case wheelchairAccessible = "Wheelchair Accessible"
        case limitedMobility = "Limited Mobility Accommodations"
        case ergonomicEquipment = "Ergonomic Equipment"
        case flexibleBreaks = "Flexible Break Schedule"

        // Sensory
        case visualImpairment = "Visual Impairment Support"
        case screenReader = "Screen Reader Compatible"
        case hearingImpairment = "Hearing Impairment Support"
        case signLanguage = "Sign Language Interpretation"

        // Cognitive
        case neurodivergent = "Neurodivergent-Friendly"
        case clearInstructions = "Clear Written Instructions"
        case quietEnvironment = "Quiet Work Environment"
        case structuredSchedule = "Structured Schedule"

        // Mental Health
        case mentalHealthSupport = "Mental Health Support"
        case reducedHours = "Reduced Hours Option"
        case flexibleSchedule = "Flexible Schedule"
        case remoteOption = "Remote Work Option"

        var category: String {
            switch self {
            case .wheelchairAccessible, .limitedMobility, .ergonomicEquipment, .flexibleBreaks:
                return "Physical"
            case .visualImpairment, .screenReader, .hearingImpairment, .signLanguage:
                return "Sensory"
            case .neurodivergent, .clearInstructions, .quietEnvironment, .structuredSchedule:
                return "Cognitive"
            case .mentalHealthSupport, .reducedHours, .flexibleSchedule, .remoteOption:
                return "Mental Health"
            }
        }
    }

    // MARK: - Work Style

    public enum WorkStyle: String, Codable, CaseIterable {
        case onsite = "On-site"
        case remote = "Fully Remote"
        case hybrid = "Hybrid"
        case flexible = "Flexible"

        var description: String {
            switch self {
            case .onsite: return "Work at employer's location"
            case .remote: return "Work from anywhere"
            case .hybrid: return "Mix of remote and on-site"
            case .flexible: return "Varies based on needs"
            }
        }
    }

    // MARK: - Remote Preference

    public enum RemotePreference: String, Codable, CaseIterable {
        case remoteOnly = "Remote Only"
        case remotePreferred = "Remote Preferred"
        case noPreference = "No Preference"
        case onsitePreferred = "On-site Preferred"
        case onsiteOnly = "On-site Only"
    }

    // MARK: - Availability

    public struct Availability: Codable {
        public var availableNow: Bool
        public var startDate: Date?
        public var hoursPerWeek: Int
        public var preferredSchedule: ScheduleType
        public var availableDays: [Int]  // 0 = Sunday, 6 = Saturday
        public var timezoneFriendly: [String]  // Timezones can work with

        public init() {
            self.availableNow = true
            self.startDate = nil
            self.hoursPerWeek = 40
            self.preferredSchedule = .fullTime
            self.availableDays = [1, 2, 3, 4, 5]  // Mon-Fri
            self.timezoneFriendly = []
        }

        public enum ScheduleType: String, Codable, CaseIterable {
            case fullTime = "Full-Time (35-40 hrs)"
            case partTime = "Part-Time (20-34 hrs)"
            case partTimeLight = "Part-Time Light (10-19 hrs)"
            case freelance = "Freelance/Contract"
            case seasonal = "Seasonal"
            case internship = "Internship"
        }
    }

    // MARK: - Stress Capacity

    public enum StressCapacity: String, Codable, CaseIterable {
        case low = "Low Stress Only"
        case moderate = "Moderate Stress OK"
        case high = "Can Handle High Stress"
        case variable = "Depends on Support"

        var recommendedJobTypes: [String] {
            switch self {
            case .low:
                return ["Administrative", "Data Entry", "Research", "Librarian", "Archivist"]
            case .moderate:
                return ["Most roles", "Customer Service", "Teaching", "Healthcare Support"]
            case .high:
                return ["Management", "Emergency Services", "Trading", "Startups"]
            case .variable:
                return ["Supportive environments", "Team-based roles", "Mentored positions"]
            }
        }
    }

    // MARK: - Job Opportunity

    public struct JobOpportunity: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var company: String
        public var companyDescription: String
        public var description: String
        public var location: String
        public var isRemote: Bool
        public var workStyle: WorkStyle
        public var employmentType: EmploymentType
        public var salaryRange: SalaryRange?
        public var requiredSkills: [String]
        public var preferredSkills: [String]
        public var requiredEducation: String?
        public var experienceYears: Int

        // Accessibility
        public var accessibilityFeatures: [AccessibilityNeed]
        public var accommodationsAvailable: [String]
        public var inclusivityRating: Float  // 0-100

        // Matching
        public var matchScore: Float  // 0-100
        public var skillMatch: Float  // 0-100
        public var valueMatch: Float  // 0-100
        public var cultureMatch: Float  // 0-100
        public var wellbeingMatch: Float  // 0-100, how suitable for user's health

        // Company Info
        public var companySize: CompanySize
        public var industry: String
        public var companyValues: [String]
        public var diversityCommitment: String
        public var mentalHealthSupport: Bool

        // Application
        public var applicationURL: String?
        public var applicationDeadline: Date?
        public var postedDate: Date
        public var isActive: Bool

        public init(title: String, company: String, description: String, location: String, isRemote: Bool = false) {
            self.id = UUID()
            self.title = title
            self.company = company
            self.companyDescription = ""
            self.description = description
            self.location = location
            self.isRemote = isRemote
            self.workStyle = isRemote ? .remote : .onsite
            self.employmentType = .fullTime
            self.salaryRange = nil
            self.requiredSkills = []
            self.preferredSkills = []
            self.requiredEducation = nil
            self.experienceYears = 0

            self.accessibilityFeatures = []
            self.accommodationsAvailable = []
            self.inclusivityRating = 50

            self.matchScore = 0
            self.skillMatch = 0
            self.valueMatch = 0
            self.cultureMatch = 0
            self.wellbeingMatch = 0

            self.companySize = .medium
            self.industry = ""
            self.companyValues = []
            self.diversityCommitment = ""
            self.mentalHealthSupport = false

            self.applicationURL = nil
            self.applicationDeadline = nil
            self.postedDate = Date()
            self.isActive = true
        }

        public enum EmploymentType: String, Codable, CaseIterable {
            case fullTime = "Full-Time"
            case partTime = "Part-Time"
            case contract = "Contract"
            case freelance = "Freelance"
            case internship = "Internship"
            case temporary = "Temporary"
            case volunteer = "Volunteer"
        }

        public struct SalaryRange: Codable {
            public var min: Int
            public var max: Int
            public var currency: String
            public var period: String  // hourly, monthly, yearly

            public init(min: Int, max: Int, currency: String = "USD", period: String = "yearly") {
                self.min = min
                self.max = max
                self.currency = currency
                self.period = period
            }
        }

        public enum CompanySize: String, Codable, CaseIterable {
            case startup = "Startup (1-10)"
            case small = "Small (11-50)"
            case medium = "Medium (51-200)"
            case large = "Large (201-1000)"
            case enterprise = "Enterprise (1000+)"
        }
    }

    // MARK: - Job Application

    public struct JobApplication: Codable, Identifiable {
        public let id: UUID
        public var jobId: UUID
        public var jobTitle: String
        public var company: String
        public var appliedDate: Date
        public var status: ApplicationStatus
        public var notes: String
        public var nextSteps: [String]
        public var interviewDates: [Date]

        public init(jobId: UUID, jobTitle: String, company: String) {
            self.id = UUID()
            self.jobId = jobId
            self.jobTitle = jobTitle
            self.company = company
            self.appliedDate = Date()
            self.status = .applied
            self.notes = ""
            self.nextSteps = []
            self.interviewDates = []
        }

        public enum ApplicationStatus: String, Codable, CaseIterable {
            case saved = "Saved"
            case applied = "Applied"
            case underReview = "Under Review"
            case interview = "Interview Scheduled"
            case interviewed = "Interviewed"
            case offered = "Offer Received"
            case accepted = "Accepted"
            case rejected = "Not Selected"
            case withdrawn = "Withdrawn"
        }
    }

    // MARK: - Matching Preferences

    public struct MatchingPreferences: Codable {
        public var prioritizeRemote: Bool
        public var prioritizeAccessibility: Bool
        public var prioritizeWellbeing: Bool
        public var minimumSalary: Int?
        public var preferredIndustries: [String]
        public var excludedIndustries: [String]
        public var preferredCompanySize: [JobOpportunity.CompanySize]
        public var mustHaveValues: [WorkValue]

        public init() {
            self.prioritizeRemote = true
            self.prioritizeAccessibility = true
            self.prioritizeWellbeing = true
            self.minimumSalary = nil
            self.preferredIndustries = []
            self.excludedIndustries = []
            self.preferredCompanySize = []
            self.mustHaveValues = []
        }
    }

    // MARK: - Accessibility Requirements

    public struct AccessibilityRequirements: Codable {
        public var mustBeRemote: Bool
        public var requiredAccommodations: [AccessibilityNeed]
        public var preferredAccommodations: [AccessibilityNeed]
        public var maxCommute: Int?  // minutes
        public var requiresMentalHealthSupport: Bool
        public var requiresFlexibleSchedule: Bool

        public init() {
            self.mustBeRemote = false
            self.requiredAccommodations = []
            self.preferredAccommodations = []
            self.maxCommute = nil
            self.requiresMentalHealthSupport = false
            self.requiresFlexibleSchedule = false
        }
    }

    // MARK: - Skill Development Plan

    public struct SkillDevelopmentPlan: Codable {
        public var targetRole: String
        public var currentSkillLevel: Float
        public var targetSkillLevel: Float
        public var skillGaps: [SkillGap]
        public var learningPath: [LearningStep]
        public var estimatedTimeToReady: TimeInterval  // seconds
        public var resources: [LearningResource]

        public struct SkillGap: Codable, Identifiable {
            public let id: UUID
            public var skillName: String
            public var currentLevel: Float
            public var requiredLevel: Float
            public var priority: Int
            public var learningResources: [String]

            public init(skillName: String, currentLevel: Float, requiredLevel: Float, priority: Int = 1) {
                self.id = UUID()
                self.skillName = skillName
                self.currentLevel = currentLevel
                self.requiredLevel = requiredLevel
                self.priority = priority
                self.learningResources = []
            }

            public var gap: Float {
                return max(0, requiredLevel - currentLevel)
            }
        }

        public struct LearningStep: Codable, Identifiable {
            public let id: UUID
            public var title: String
            public var description: String
            public var skillsGained: [String]
            public var estimatedHours: Int
            public var resources: [String]
            public var isCompleted: Bool
            public var accessibilityNotes: String

            public init(title: String, description: String, skillsGained: [String], estimatedHours: Int) {
                self.id = UUID()
                self.title = title
                self.description = description
                self.skillsGained = skillsGained
                self.estimatedHours = estimatedHours
                self.resources = []
                self.isCompleted = false
                self.accessibilityNotes = ""
            }
        }

        public struct LearningResource: Codable, Identifiable {
            public let id: UUID
            public var name: String
            public var type: ResourceType
            public var url: String?
            public var cost: String
            public var duration: String
            public var accessibilityRating: Float
            public var languages: [String]

            public init(name: String, type: ResourceType, url: String? = nil, cost: String = "Free", duration: String = "", accessibilityRating: Float = 50) {
                self.id = UUID()
                self.name = name
                self.type = type
                self.url = url
                self.cost = cost
                self.duration = duration
                self.accessibilityRating = accessibilityRating
                self.languages = ["en"]
            }

            public enum ResourceType: String, Codable {
                case onlineCourse = "Online Course"
                case book = "Book"
                case video = "Video"
                case podcast = "Podcast"
                case workshop = "Workshop"
                case certification = "Certification"
                case mentorship = "Mentorship"
                case practice = "Hands-on Practice"
            }
        }

        public init(targetRole: String) {
            self.targetRole = targetRole
            self.currentSkillLevel = 0
            self.targetSkillLevel = 100
            self.skillGaps = []
            self.learningPath = []
            self.estimatedTimeToReady = 0
            self.resources = []
        }
    }

    // MARK: - Career Path

    public struct CareerPath: Codable {
        public var currentPosition: String
        public var targetPosition: String
        public var milestones: [CareerMilestone]
        public var estimatedYears: Float
        public var alternativePaths: [String]

        public struct CareerMilestone: Codable, Identifiable {
            public let id: UUID
            public var title: String
            public var description: String
            public var requiredSkills: [String]
            public var typicalSalary: String
            public var timeToReach: String
            public var isAchieved: Bool

            public init(title: String, description: String, requiredSkills: [String] = [], typicalSalary: String = "", timeToReach: String = "") {
                self.id = UUID()
                self.title = title
                self.description = description
                self.requiredSkills = requiredSkills
                self.typicalSalary = typicalSalary
                self.timeToReach = timeToReach
                self.isAchieved = false
            }
        }

        public init(currentPosition: String, targetPosition: String) {
            self.currentPosition = currentPosition
            self.targetPosition = targetPosition
            self.milestones = []
            self.estimatedYears = 0
            self.alternativePaths = []
        }
    }

    // MARK: - Initialization

    private init() {
        print("==============================================")
        print("   ECHOELWORKS - CREATIVE CAREERS")
        print("==============================================")
        print("   Connecting creative talent with opportunity")
        print("   Audio, well-being, creative industries")
        print("   Accessibility-first job matching")
        print("==============================================")
    }

    // MARK: - Update from EchoelScan

    public func updateFromScan(_ scan: EchoelScan.LifeScan) async {
        // Update or create profile with scan data
        if userProfile == nil {
            userProfile = WorkerProfile()
        }

        // Map strengths
        userProfile?.characterStrengths = scan.strengths.map(\.name)

        // Map skills
        userProfile?.skills = scan.skillsInventory.map { skill in
            WorkSkill(
                name: skill.name,
                category: mapSkillCategory(skill.category),
                proficiency: mapProficiency(skill.proficiency),
                yearsExperience: skill.yearsExperience
            )
        }

        // Map interests to Holland codes
        userProfile?.hollandCodes = scan.interestAreas.map(\.hollandCode.rawValue)

        // Map wellbeing
        userProfile?.wellbeingScore = scan.overallWellbeing
        userProfile?.stressCapacity = mapStressCapacity(scan.stressIndex)

        // Update job matches
        jobMatches = scan.jobMatches.map { match in
            var job = JobOpportunity(
                title: match.jobTitle,
                company: "Various Employers",
                description: match.description,
                location: "Various",
                isRemote: match.remoteWorkPossible
            )
            job.matchScore = match.matchScore
            job.skillMatch = match.skillAlignment
            job.valueMatch = match.valueAlignment
            job.wellbeingMatch = match.accessibilityRating
            job.requiredSkills = match.requiredSkills
            return job
        }

        print("   Echoelworks: Profile updated from scan")
        print("   Skills: \(userProfile?.skills.count ?? 0)")
        print("   Job Matches: \(jobMatches.count)")
    }

    // MARK: - Find Jobs

    public func findJobs(limit: Int = 20) async -> [JobOpportunity] {
        guard let profile = userProfile else {
            print("   Echoelworks: No profile - cannot match jobs")
            return []
        }

        print("\n--- ECHOELWORKS JOB SEARCH ---")
        print("Skills: \(profile.skills.count)")
        print("Accessibility needs: \(profile.accessibilityNeeds.count)")
        print("Remote preference: \(profile.remotePreference.rawValue)")

        // In production: API call to job boards, company databases
        // For now: Generate matched opportunities

        var opportunities: [JobOpportunity] = []

        // Generate diverse job opportunities
        let jobTemplates = generateJobTemplates()

        for template in jobTemplates.prefix(limit) {
            var job = template
            job.matchScore = calculateMatchScore(job: job, profile: profile)
            job.skillMatch = calculateSkillMatch(job: job, profile: profile)
            job.valueMatch = calculateValueMatch(job: job, profile: profile)
            job.wellbeingMatch = calculateWellbeingMatch(job: job, profile: profile)

            // Filter by accessibility requirements
            if meetsAccessibilityRequirements(job: job) {
                opportunities.append(job)
            }
        }

        // Sort by match score
        opportunities.sort { $0.matchScore > $1.matchScore }

        jobMatches = opportunities

        print("Jobs found: \(opportunities.count)")
        print("Top match: \(opportunities.first?.title ?? "None") (\(String(format: "%.0f", opportunities.first?.matchScore ?? 0))%)")
        print("----------------------------\n")

        return opportunities
    }

    // MARK: - Create Skill Development Plan

    public func createSkillDevelopmentPlan(targetRole: String) async -> SkillDevelopmentPlan {
        guard let profile = userProfile else {
            return SkillDevelopmentPlan(targetRole: targetRole)
        }

        var plan = SkillDevelopmentPlan(targetRole: targetRole)

        // Identify skill gaps
        let requiredSkills = getRequiredSkillsForRole(targetRole)
        for required in requiredSkills {
            let currentLevel = profile.skills.first { $0.name == required.name }?.proficiency.score ?? 0
            if currentLevel < required.level {
                plan.skillGaps.append(SkillDevelopmentPlan.SkillGap(
                    skillName: required.name,
                    currentLevel: currentLevel,
                    requiredLevel: required.level,
                    priority: required.priority
                ))
            }
        }

        // Create learning path
        for gap in plan.skillGaps.sorted(by: { $0.priority < $1.priority }) {
            plan.learningPath.append(SkillDevelopmentPlan.LearningStep(
                title: "Learn \(gap.skillName)",
                description: "Develop \(gap.skillName) from \(String(format: "%.0f", gap.currentLevel))% to \(String(format: "%.0f", gap.requiredLevel))%",
                skillsGained: [gap.skillName],
                estimatedHours: Int(gap.gap * 2)  // 2 hours per percentage point
            ))
        }

        // Add resources
        plan.resources = getAccessibleLearningResources(for: plan.skillGaps.map(\.skillName))

        // Calculate time
        plan.estimatedTimeToReady = TimeInterval(plan.learningPath.reduce(0) { $0 + $1.estimatedHours } * 3600)

        skillDevelopmentPlan = plan
        return plan
    }

    // MARK: - Career Path Planning

    public func planCareerPath(from current: String, to target: String) async -> CareerPath {
        var path = CareerPath(currentPosition: current, targetPosition: target)

        // Generate milestones
        let milestones = generateCareerMilestones(from: current, to: target)
        path.milestones = milestones
        path.estimatedYears = Float(milestones.count) * 1.5  // Average 1.5 years per step

        // Alternative paths
        path.alternativePaths = generateAlternativePaths(to: target)

        careerPath = path
        return path
    }

    // MARK: - Apply for Job

    public func applyForJob(_ job: JobOpportunity) -> JobApplication {
        let application = JobApplication(
            jobId: job.id,
            jobTitle: job.title,
            company: job.company
        )
        applications.append(application)

        print("   Echoelworks: Applied to \(job.title) at \(job.company)")
        return application
    }

    // MARK: - Helper Methods

    private func mapSkillCategory(_ category: EchoelScan.Skill.SkillCategory) -> WorkSkill.SkillCategory {
        switch category {
        case .technical: return .technical
        case .creative: return .creative
        case .analytical: return .analytical
        case .interpersonal: return .interpersonal
        case .leadership: return .leadership
        case .organizational: return .administrative
        case .communication: return .interpersonal
        case .physical: return .physical
        case .digital: return .digital
        case .linguistic: return .language
        }
    }

    private func mapProficiency(_ level: Float) -> WorkSkill.ProficiencyLevel {
        switch level {
        case 0..<30: return .beginner
        case 30..<50: return .intermediate
        case 50..<70: return .advanced
        case 70..<90: return .expert
        default: return .master
        }
    }

    private func mapStressCapacity(_ stressIndex: Float) -> StressCapacity {
        switch stressIndex {
        case 0..<30: return .high
        case 30..<60: return .moderate
        case 60..<80: return .low
        default: return .variable
        }
    }

    private func calculateMatchScore(job: JobOpportunity, profile: WorkerProfile) -> Float {
        var score: Float = 0

        // Skill match (40%)
        score += calculateSkillMatch(job: job, profile: profile) * 0.4

        // Value match (25%)
        score += calculateValueMatch(job: job, profile: profile) * 0.25

        // Wellbeing match (20%)
        score += calculateWellbeingMatch(job: job, profile: profile) * 0.2

        // Remote/accessibility match (15%)
        if job.isRemote && profile.remotePreference == .remoteOnly { score += 15 }
        else if job.isRemote && profile.remotePreference == .remotePreferred { score += 12 }

        return min(100, score)
    }

    private func calculateSkillMatch(job: JobOpportunity, profile: WorkerProfile) -> Float {
        guard !job.requiredSkills.isEmpty else { return 50 }

        let profileSkillNames = Set(profile.skills.map { $0.name.lowercased() })
        let matchedSkills = job.requiredSkills.filter { profileSkillNames.contains($0.lowercased()) }

        return Float(matchedSkills.count) / Float(job.requiredSkills.count) * 100
    }

    private func calculateValueMatch(job: JobOpportunity, profile: WorkerProfile) -> Float {
        guard !profile.values.isEmpty, !job.companyValues.isEmpty else { return 50 }

        let profileValueStrings = Set(profile.values.map { $0.rawValue.lowercased() })
        let matchedValues = job.companyValues.filter { profileValueStrings.contains($0.lowercased()) }

        return Float(matchedValues.count) / Float(profile.values.count) * 100
    }

    private func calculateWellbeingMatch(job: JobOpportunity, profile: WorkerProfile) -> Float {
        var score: Float = 50

        // Remote work for stress reduction
        if job.isRemote && (profile.stressCapacity == .low || profile.stressCapacity == .variable) {
            score += 20
        }

        // Mental health support
        if job.mentalHealthSupport && profile.accessibilityNeeds.contains(.mentalHealthSupport) {
            score += 20
        }

        // Accessibility features
        let matchedAccessibility = profile.accessibilityNeeds.filter { job.accessibilityFeatures.contains($0) }
        score += Float(matchedAccessibility.count) * 5

        return min(100, score)
    }

    private func meetsAccessibilityRequirements(job: JobOpportunity) -> Bool {
        // If must be remote
        if accessibilityRequirements.mustBeRemote && !job.isRemote {
            return false
        }

        // Check required accommodations
        for required in accessibilityRequirements.requiredAccommodations {
            if !job.accessibilityFeatures.contains(required) {
                return false
            }
        }

        return true
    }

    private func generateJobTemplates() -> [JobOpportunity] {
        // Diverse creative, audio, and wellness jobs through Echoelmusic platform
        return [
            // === AUDIO & SOUND (Music + Beyond) ===
            createCreativeJob("Music Producer", "Echoelmusic Studios", "Produce tracks, oversee recording sessions, mix and master audio", remote: true, category: .audioProduction, accessibility: [.flexibleSchedule, .remoteOption]),
            createCreativeJob("Podcast Producer", "Audio Stories Network", "Produce, edit, and publish podcasts on any topic", remote: true, category: .audioProduction, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Audiobook Narrator", "VoiceWorks Publishing", "Record and produce audiobook narrations", remote: true, category: .audioProduction, accessibility: [.remoteOption, .flexibleSchedule, .quietEnvironment]),
            createCreativeJob("Sound Designer", "Immersive Audio Co", "Create sound effects for games, films, and VR experiences", remote: true, category: .soundDesign, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Foley Artist", "Film Sound Studios", "Create and record sound effects for visual media", remote: false, category: .soundDesign, accessibility: [.ergonomicEquipment, .flexibleBreaks]),
            createCreativeJob("Audio Engineer", "SoundWave Studios", "Record, mix, and master audio for various media", remote: false, category: .audioProduction, accessibility: [.ergonomicEquipment, .flexibleBreaks]),

            // === WELLNESS & THERAPEUTIC ===
            createCreativeJob("Sound Therapist", "Therapeutic Sound Center", "Use sound and vibration for therapeutic wellbeing", remote: true, category: .wellness, accessibility: [.flexibleSchedule, .mentalHealthSupport, .remoteOption]),
            createCreativeJob("Meditation Guide", "Mindful Audio", "Create and guide meditation sessions with sound", remote: true, category: .wellness, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),
            createCreativeJob("Biofeedback Coach", "Echoelmusic Wellness", "Guide clients using bio-reactive audio technology", remote: true, category: .wellness, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Breathwork Facilitator", "Breath & Sound Institute", "Lead breathwork sessions with audio guidance", remote: true, category: .wellness, accessibility: [.remoteOption, .mentalHealthSupport]),
            createCreativeJob("Wellness Content Creator", "Mindful Media", "Create wellness and self-care audio/video content", remote: true, category: .wellness, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),

            // === CREATIVE PRODUCTION ===
            createCreativeJob("Content Creator", "Echoelmusic Media", "Create tutorials, reviews, and educational content", remote: true, category: .content, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),
            createCreativeJob("Video Editor", "Creative Studios", "Edit video content with audio synchronization", remote: true, category: .content, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Livestream Producer", "Stream Networks", "Produce and manage live streaming shows", remote: true, category: .content, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Social Media Manager", "Brand Audio Agency", "Manage brand presence with audio-visual content", remote: true, category: .content, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),

            // === TECHNOLOGY & DEVELOPMENT ===
            createCreativeJob("Audio Plugin Developer", "Echoelmusic Tech", "Develop VST/AU plugins for audio production", remote: true, category: .technology, accessibility: [.remoteOption, .flexibleSchedule, .quietEnvironment]),
            createCreativeJob("iOS/Android Developer", "SoundApp Studios", "Build mobile apps for audio and wellness", remote: true, category: .technology, accessibility: [.remoteOption, .flexibleSchedule, .ergonomicEquipment]),
            createCreativeJob("AI/ML Engineer", "Audio AI Labs", "Develop AI models for audio processing and generation", remote: true, category: .technology, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("UX Designer", "Creative Tech Co", "Design intuitive interfaces for audio applications", remote: true, category: .technology, accessibility: [.remoteOption, .flexibleSchedule, .screenReader]),

            // === EDUCATION & COACHING ===
            createCreativeJob("Online Instructor", "Echoelmusic Academy", "Teach audio production, music, or wellness online", remote: true, category: .education, accessibility: [.remoteOption, .flexibleSchedule, .screenReader]),
            createCreativeJob("Career Coach", "Creative Careers Hub", "Guide creative professionals in career development", remote: true, category: .education, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),
            createCreativeJob("Workshop Facilitator", "Skill Share Co", "Lead workshops on creative and wellness topics", remote: true, category: .education, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Mentorship Coordinator", "Echoelmusic Mentors", "Connect mentors with mentees in creative fields", remote: true, category: .education, accessibility: [.remoteOption, .flexibleSchedule]),

            // === BUSINESS & MANAGEMENT ===
            createCreativeJob("Talent Manager", "Echoelmusic Management", "Guide creative careers, negotiate deals, coordinate projects", remote: true, category: .management, accessibility: [.flexibleSchedule, .remoteOption]),
            createCreativeJob("Project Manager", "Creative Projects Inc", "Manage audio/visual production projects", remote: true, category: .management, accessibility: [.remoteOption, .flexibleSchedule]),
            createCreativeJob("Community Manager", "Creator Community Hub", "Build and nurture creative communities online", remote: true, category: .management, accessibility: [.remoteOption, .flexibleSchedule, .mentalHealthSupport]),
            createCreativeJob("Business Consultant", "Creative Biz Advisors", "Advise creative professionals on business strategy", remote: true, category: .management, accessibility: [.remoteOption, .flexibleSchedule]),

            // === LIVE & EVENTS ===
            createCreativeJob("Live Sound Engineer", "Event Audio Pro", "Operate sound systems for live events", remote: false, category: .liveEvents, accessibility: [.ergonomicEquipment, .flexibleBreaks]),
            createCreativeJob("Event Coordinator", "Creative Events Co", "Coordinate creative and wellness events", remote: false, category: .liveEvents, accessibility: [.clearInstructions, .structuredSchedule]),
            createCreativeJob("Virtual Event Host", "Online Events Hub", "Host and moderate virtual creative events", remote: true, category: .liveEvents, accessibility: [.remoteOption, .flexibleSchedule])
        ]
    }

    /// Broad creative career categories (not just music!)
    public enum CreativeJobCategory: String, Codable {
        case audioProduction = "Audio Production"
        case soundDesign = "Sound Design"
        case wellbeing = "Well-being & Therapeutic"
        case content = "Content Creation"
        case technology = "Technology & Development"
        case education = "Education & Coaching"
        case management = "Business & Management"
        case liveEvents = "Live & Events"
    }

    private func createCreativeJob(_ title: String, _ company: String, _ description: String, remote: Bool, category: CreativeJobCategory, accessibility: [AccessibilityNeed]) -> JobOpportunity {
        var job = JobOpportunity(title: title, company: company, description: description, location: remote ? "Remote" : "Various", isRemote: remote)
        job.accessibilityFeatures = accessibility
        job.mentalHealthSupport = accessibility.contains(.mentalHealthSupport)
        job.inclusivityRating = Float(accessibility.count) * 15 + 40
        job.industry = category.rawValue
        job.companyValues = ["Creativity", "Accessibility", "Personal Growth", "Wellbeing"]
        return job
    }


    private func getRequiredSkillsForRole(_ role: String) -> [(name: String, level: Float, priority: Int)] {
        // Simplified: In production, this would be a comprehensive database
        return [
            (name: "Communication", level: 70, priority: 1),
            (name: "Problem Solving", level: 60, priority: 2),
            (name: "Teamwork", level: 65, priority: 3)
        ]
    }

    private func getAccessibleLearningResources(for skills: [String]) -> [SkillDevelopmentPlan.LearningResource] {
        return [
            SkillDevelopmentPlan.LearningResource(
                name: "Coursera - Accessible Learning",
                type: .onlineCourse,
                url: "https://coursera.org",
                cost: "Free with financial aid",
                duration: "4-6 weeks",
                accessibilityRating: 90
            ),
            SkillDevelopmentPlan.LearningResource(
                name: "LinkedIn Learning",
                type: .onlineCourse,
                url: "https://linkedin.com/learning",
                cost: "Subscription",
                duration: "Self-paced",
                accessibilityRating: 85
            ),
            SkillDevelopmentPlan.LearningResource(
                name: "Local Library Resources",
                type: .book,
                cost: "Free",
                duration: "Varies",
                accessibilityRating: 80
            )
        ]
    }

    private func generateCareerMilestones(from current: String, to target: String) -> [CareerPath.CareerMilestone] {
        return [
            CareerPath.CareerMilestone(
                title: "Entry Level",
                description: "Build foundational skills",
                requiredSkills: ["Basic skills"],
                typicalSalary: "$35,000 - $50,000",
                timeToReach: "Current"
            ),
            CareerPath.CareerMilestone(
                title: "Intermediate",
                description: "Develop specialized expertise",
                requiredSkills: ["Intermediate skills", "Specialization"],
                typicalSalary: "$50,000 - $75,000",
                timeToReach: "1-2 years"
            ),
            CareerPath.CareerMilestone(
                title: "Senior",
                description: "Lead projects and mentor others",
                requiredSkills: ["Advanced skills", "Leadership"],
                typicalSalary: "$75,000 - $100,000",
                timeToReach: "3-5 years"
            ),
            CareerPath.CareerMilestone(
                title: target,
                description: "Achieve target role",
                requiredSkills: ["Expert skills", "Strategic thinking"],
                typicalSalary: "$100,000+",
                timeToReach: "5-7 years"
            )
        ]
    }

    private func generateAlternativePaths(to target: String) -> [String] {
        return [
            "Traditional corporate ladder",
            "Freelance/consulting path",
            "Entrepreneurship",
            "Non-profit sector",
            "Government/public sector"
        ]
    }

    // MARK: - Report

    public func getReport() -> String {
        return """
        =====================================================
        ECHOELWORKS - CREATIVE CAREER REPORT
        =====================================================

        PROFILE STATUS: \(userProfile != nil ? "Complete" : "Incomplete")

        YOUR SKILLS:
        \(userProfile?.skills.map { "  - \($0.name): \($0.proficiency.rawValue)" }.joined(separator: "\n") ?? "  None recorded")

        ACCESSIBILITY NEEDS:
        \(userProfile?.accessibilityNeeds.map { "  - \($0.rawValue)" }.joined(separator: "\n") ?? "  None specified")

        JOB MATCHES: \(jobMatches.count)
        \(jobMatches.prefix(5).map { "  - \($0.title) at \($0.company) (\(String(format: "%.0f", $0.matchScore))% match)" }.joined(separator: "\n"))

        APPLICATIONS: \(applications.count)
        \(applications.map { "  - \($0.jobTitle) at \($0.company): \($0.status.rawValue)" }.joined(separator: "\n"))

        SKILL DEVELOPMENT:
        \(skillDevelopmentPlan != nil ? "  Target: \(skillDevelopmentPlan!.targetRole)" : "  No plan created")
        \(skillDevelopmentPlan?.skillGaps.map { "  - Gap: \($0.skillName) (\(String(format: "%.0f", $0.gap))%)" }.joined(separator: "\n") ?? "")

        =====================================================
        "Connecting creative talent with meaningful careers"
        Audio • Wellness • Creative • Technology
        Powered by Echoelmusic
        =====================================================
        """
    }
}
