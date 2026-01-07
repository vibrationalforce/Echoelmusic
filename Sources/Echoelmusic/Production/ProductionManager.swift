import Foundation
import Combine

// MARK: - Production Manager

/// Comprehensive production management system for Echoelmusic
/// Optimized for Business, Team, Humankind, Environment, and Inclusive Mobility
@MainActor
class ProductionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ProductionManager()

    // MARK: - Published State

    @Published private(set) var activeProjects: [Project] = []
    @Published private(set) var teamMembers: [TeamMember] = []
    @Published private(set) var sustainabilityScore: SustainabilityScore = SustainabilityScore()
    @Published private(set) var accessibilityStatus: AccessibilityStatus = AccessibilityStatus()
    @Published private(set) var businessMetrics: BusinessMetrics = BusinessMetrics()

    // MARK: - Managers

    private let workflowManager = WorkflowManager()
    private let resourceManager = ResourceManager()
    private let collaborationHub = CollaborationHub()
    private let impactTracker = ImpactTracker()

    // MARK: - Initialization

    private init() {
        setupDefaultWorkflows()
        print("✅ ProductionManager: Initialized")
    }

    // MARK: - Project Management

    func createProject(
        name: String,
        type: ProjectType,
        team: [TeamMember],
        deadline: Date? = nil,
        sustainabilityGoals: [SustainabilityGoal] = []
    ) -> Project {
        let project = Project(
            name: name,
            type: type,
            team: team,
            deadline: deadline,
            sustainabilityGoals: sustainabilityGoals
        )

        activeProjects.append(project)
        impactTracker.trackProjectCreation(project)

        print("📁 ProductionManager: Created project '\(name)'")
        return project
    }

    func archiveProject(_ id: UUID) {
        guard let index = activeProjects.firstIndex(where: { $0.id == id }) else { return }
        var project = activeProjects[index]
        project.status = .archived
        project.archivedAt = Date()
        activeProjects[index] = project

        // Calculate final impact
        impactTracker.finalizeProjectImpact(project)
    }

    // MARK: - Team Management

    func addTeamMember(_ member: TeamMember) {
        teamMembers.append(member)
        collaborationHub.registerMember(member)
    }

    func assignToProject(member: TeamMember, project: Project, role: ProjectRole) {
        guard let projectIndex = activeProjects.firstIndex(where: { $0.id == project.id }) else { return }

        let assignment = ProjectAssignment(
            memberId: member.id,
            projectId: project.id,
            role: role,
            assignedAt: Date()
        )

        activeProjects[projectIndex].assignments.append(assignment)
    }

    // MARK: - Workflow

    private func setupDefaultWorkflows() {
        workflowManager.registerWorkflow(ProductionWorkflow.bioReactiveSession)
        workflowManager.registerWorkflow(ProductionWorkflow.studioRecording)
        workflowManager.registerWorkflow(ProductionWorkflow.liveStream)
        workflowManager.registerWorkflow(ProductionWorkflow.collaboration)
        workflowManager.registerWorkflow(ProductionWorkflow.mastering)
    }
}

// MARK: - Project Types

struct Project: Identifiable {
    let id = UUID()
    var name: String
    var type: ProjectType
    var team: [TeamMember]
    var deadline: Date?
    var sustainabilityGoals: [SustainabilityGoal]
    var status: ProjectStatus = .active
    var assignments: [ProjectAssignment] = []
    var createdAt: Date = Date()
    var archivedAt: Date?

    // Production tracking
    var sessions: [ProductionSession] = []
    var exports: [ExportRecord] = []
    var collaborations: [CollaborationEvent] = []

    // Impact metrics
    var carbonFootprint: CarbonFootprint = CarbonFootprint()
    var accessibilityFeatures: [AccessibilityFeature] = []

    var progress: Double {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter { $0.status == .completed }.count
        return Double(completed) / Double(sessions.count)
    }
}

enum ProjectType: String, CaseIterable {
    case bioReactiveAlbum = "Bio-Reactive Album"
    case meditationSeries = "Meditation Series"
    case livePerformance = "Live Performance"
    case collaborativeProject = "Collaborative Project"
    case therapeuticContent = "Therapeutic Content"
    case accessibleMedia = "Accessible Media"
    case environmentalAwareness = "Environmental Awareness"

    var defaultWorkflow: ProductionWorkflow {
        switch self {
        case .bioReactiveAlbum, .meditationSeries:
            return .bioReactiveSession
        case .livePerformance:
            return .liveStream
        case .collaborativeProject:
            return .collaboration
        case .therapeuticContent, .accessibleMedia:
            return .studioRecording
        case .environmentalAwareness:
            return .bioReactiveSession
        }
    }
}

enum ProjectStatus: String {
    case planning
    case active
    case review
    case completed
    case archived
}

// MARK: - Team Management

struct TeamMember: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var email: String
    var role: TeamRole
    var skills: [Skill]
    var accessibilityNeeds: [AccessibilityNeed]
    var preferredWorkHours: WorkHours
    var timezone: TimeZone

    // Wellness tracking
    var workloadScore: Double = 0.5  // 0-1, target 0.4-0.7
    var lastBreakReminder: Date?

    static func == (lhs: TeamMember, rhs: TeamMember) -> Bool {
        lhs.id == rhs.id
    }
}

enum TeamRole: String, CaseIterable {
    case producer = "Producer"
    case artist = "Artist"
    case engineer = "Audio Engineer"
    case designer = "Visual Designer"
    case developer = "Developer"
    case therapist = "Music Therapist"
    case researcher = "Researcher"
    case communityManager = "Community Manager"
    case accessibilitySpecialist = "Accessibility Specialist"
}

struct Skill: Identifiable {
    let id = UUID()
    var name: String
    var level: SkillLevel
    var certifications: [String]
}

enum SkillLevel: Int, CaseIterable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
}

struct WorkHours {
    var start: Int  // 0-23
    var end: Int    // 0-23
    var days: Set<Weekday>
    var flexibleSchedule: Bool

    enum Weekday: Int, CaseIterable {
        case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday
    }
}

struct ProjectAssignment: Identifiable {
    let id = UUID()
    var memberId: UUID
    var projectId: UUID
    var role: ProjectRole
    var assignedAt: Date
    var completedAt: Date?
}

enum ProjectRole: String, CaseIterable {
    case lead = "Lead"
    case contributor = "Contributor"
    case reviewer = "Reviewer"
    case advisor = "Advisor"
    case observer = "Observer"
}

// MARK: - Production Workflow

enum ProductionWorkflow: String, CaseIterable {
    case bioReactiveSession = "Bio-Reactive Session"
    case studioRecording = "Studio Recording"
    case liveStream = "Live Stream"
    case collaboration = "Collaboration"
    case mastering = "Mastering"

    var stages: [WorkflowStage] {
        switch self {
        case .bioReactiveSession:
            return [.calibration, .capture, .processing, .review, .export]
        case .studioRecording:
            return [.setup, .tracking, .editing, .mixing, .mastering, .export]
        case .liveStream:
            return [.setup, .soundcheck, .broadcast, .postProcessing]
        case .collaboration:
            return [.invitation, .sync, .coCreation, .review, .merge]
        case .mastering:
            return [.analysis, .processing, .loudnessNormalization, .qualityCheck, .export]
        }
    }
}

enum WorkflowStage: String {
    // Common
    case setup = "Setup"
    case review = "Review"
    case export = "Export"

    // Bio-Reactive
    case calibration = "Calibration"
    case capture = "Capture"
    case processing = "Processing"

    // Studio
    case tracking = "Tracking"
    case editing = "Editing"
    case mixing = "Mixing"
    case mastering = "Mastering"

    // Live
    case soundcheck = "Soundcheck"
    case broadcast = "Broadcast"
    case postProcessing = "Post-Processing"

    // Collaboration
    case invitation = "Invitation"
    case sync = "Sync"
    case coCreation = "Co-Creation"
    case merge = "Merge"

    // Mastering
    case analysis = "Analysis"
    case loudnessNormalization = "Loudness Normalization"
    case qualityCheck = "Quality Check"
}

class WorkflowManager {
    private var registeredWorkflows: [ProductionWorkflow] = []

    func registerWorkflow(_ workflow: ProductionWorkflow) {
        if !registeredWorkflows.contains(workflow) {
            registeredWorkflows.append(workflow)
        }
    }
}

// MARK: - Production Session

struct ProductionSession: Identifiable {
    let id = UUID()
    var projectId: UUID
    var type: SessionType
    var status: SessionStatus = .scheduled
    var scheduledStart: Date
    var actualStart: Date?
    var actualEnd: Date?
    var participants: [UUID]

    // Bio-reactive data
    var bioDataCaptured: Bool = false
    var averageCoherence: Double?
    var peakCoherence: Double?

    // Resource tracking
    var energyUsed: Double = 0  // kWh
    var carbonOffset: Double = 0  // kg CO2

    enum SessionType: String {
        case recording
        case mixing
        case mastering
        case bioCapture
        case collaboration
        case liveStream
    }

    enum SessionStatus: String {
        case scheduled
        case inProgress
        case completed
        case cancelled
    }

    var duration: TimeInterval? {
        guard let start = actualStart, let end = actualEnd else { return nil }
        return end.timeIntervalSince(start)
    }
}

// MARK: - Sustainability

struct SustainabilityScore: Equatable {
    var overallScore: Double = 0.0  // 0-100
    var energyEfficiency: Double = 0.0
    var carbonFootprint: Double = 0.0  // Lower is better
    var renewableEnergy: Double = 0.0  // Percentage
    var localResourceUsage: Double = 0.0
    var wasteReduction: Double = 0.0

    var grade: String {
        switch overallScore {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }
}

struct SustainabilityGoal: Identifiable {
    let id = UUID()
    var name: String
    var target: Double
    var current: Double
    var unit: String
    var deadline: Date?

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }

    var isAchieved: Bool {
        current >= target
    }
}

struct CarbonFootprint: Equatable {
    var computeEmissions: Double = 0  // kg CO2
    var storageEmissions: Double = 0
    var networkEmissions: Double = 0
    var offsetCredits: Double = 0

    var netEmissions: Double {
        max(0, computeEmissions + storageEmissions + networkEmissions - offsetCredits)
    }

    var isNeutral: Bool {
        netEmissions <= 0
    }
}

// MARK: - Accessibility

struct AccessibilityStatus: Equatable {
    var overallCompliance: Double = 0.0  // 0-100
    var visualAccessibility: Double = 0.0
    var auditoryAccessibility: Double = 0.0
    var motorAccessibility: Double = 0.0
    var cognitiveAccessibility: Double = 0.0

    var wcagLevel: WCAGLevel {
        switch overallCompliance {
        case 90...100: return .aaa
        case 70..<90: return .aa
        case 50..<70: return .a
        default: return .none
        }
    }

    enum WCAGLevel: String {
        case none = "Non-Compliant"
        case a = "WCAG A"
        case aa = "WCAG AA"
        case aaa = "WCAG AAA"
    }
}

struct AccessibilityNeed: Identifiable, Equatable {
    let id = UUID()
    var type: AccessibilityNeedType
    var severity: Severity
    var accommodations: [String]

    enum Severity: String {
        case mild, moderate, severe
    }

    static func == (lhs: AccessibilityNeed, rhs: AccessibilityNeed) -> Bool {
        lhs.id == rhs.id
    }
}

enum AccessibilityNeedType: String, CaseIterable {
    // Visual
    case lowVision = "Low Vision"
    case colorBlindness = "Color Blindness"
    case blindness = "Blindness"

    // Auditory
    case hardOfHearing = "Hard of Hearing"
    case deafness = "Deafness"
    case auditoryProcessing = "Auditory Processing"

    // Motor
    case limitedMobility = "Limited Mobility"
    case tremors = "Tremors"
    case paralysis = "Paralysis"

    // Cognitive
    case adhd = "ADHD"
    case dyslexia = "Dyslexia"
    case autism = "Autism Spectrum"
    case memoryImpairment = "Memory Impairment"

    var category: AccessibilityCategory {
        switch self {
        case .lowVision, .colorBlindness, .blindness:
            return .visual
        case .hardOfHearing, .deafness, .auditoryProcessing:
            return .auditory
        case .limitedMobility, .tremors, .paralysis:
            return .motor
        case .adhd, .dyslexia, .autism, .memoryImpairment:
            return .cognitive
        }
    }
}

enum AccessibilityCategory: String {
    case visual, auditory, motor, cognitive
}

enum AccessibilityFeature: String, CaseIterable {
    // Visual
    case highContrast = "High Contrast Mode"
    case largeText = "Large Text"
    case screenReader = "Screen Reader Support"
    case colorBlindMode = "Color Blind Mode"
    case reducedMotion = "Reduced Motion"

    // Auditory
    case closedCaptions = "Closed Captions"
    case signLanguage = "Sign Language Support"
    case visualAlerts = "Visual Alerts"
    case monoAudio = "Mono Audio"
    case adjustableVolume = "Per-Element Volume"

    // Motor
    case voiceControl = "Voice Control"
    case switchControl = "Switch Control"
    case dwellControl = "Dwell Control"
    case customGestures = "Custom Gestures"
    case largeTargets = "Large Touch Targets"

    // Cognitive
    case simplifiedUI = "Simplified UI"
    case readingGuides = "Reading Guides"
    case focusMode = "Focus Mode"
    case memoryAids = "Memory Aids"
    case paceControl = "Pace Control"

    var category: AccessibilityCategory {
        switch self {
        case .highContrast, .largeText, .screenReader, .colorBlindMode, .reducedMotion:
            return .visual
        case .closedCaptions, .signLanguage, .visualAlerts, .monoAudio, .adjustableVolume:
            return .auditory
        case .voiceControl, .switchControl, .dwellControl, .customGestures, .largeTargets:
            return .motor
        case .simplifiedUI, .readingGuides, .focusMode, .memoryAids, .paceControl:
            return .cognitive
        }
    }
}

// MARK: - Business Metrics

struct BusinessMetrics: Equatable {
    // Revenue
    var totalRevenue: Double = 0
    var subscriptionRevenue: Double = 0
    var salesRevenue: Double = 0
    var licensingRevenue: Double = 0

    // Costs
    var operatingCosts: Double = 0
    var hostingCosts: Double = 0
    var licensingCosts: Double = 0

    // Growth
    var monthlyGrowthRate: Double = 0
    var userRetention: Double = 0
    var churnRate: Double = 0

    // Impact
    var usersReached: Int = 0
    var sessionsDelivered: Int = 0
    var therapyHoursProvided: Int = 0

    var netRevenue: Double {
        totalRevenue - operatingCosts - hostingCosts - licensingCosts
    }

    var profitMargin: Double {
        guard totalRevenue > 0 else { return 0 }
        return netRevenue / totalRevenue
    }
}

// MARK: - Collaboration

struct CollaborationEvent: Identifiable {
    let id = UUID()
    var type: CollaborationType
    var participants: [UUID]
    var startTime: Date
    var endTime: Date?
    var outcome: CollaborationOutcome?
}

enum CollaborationType: String {
    case realTimeSession = "Real-Time Session"
    case asyncReview = "Async Review"
    case pairProgramming = "Pair Programming"
    case brainstorm = "Brainstorm"
    case feedback = "Feedback Session"
}

enum CollaborationOutcome: String {
    case productive
    case needsFollowUp
    case blocked
    case cancelled
}

class CollaborationHub {
    private var registeredMembers: [TeamMember] = []

    func registerMember(_ member: TeamMember) {
        registeredMembers.append(member)
    }
}

// MARK: - Resource Management

class ResourceManager {
    // Track compute, storage, network resources

    func estimateResourceUsage(for session: ProductionSession) -> ResourceEstimate {
        ResourceEstimate(
            computeHours: 2.0,
            storageGB: 5.0,
            networkGB: 1.0,
            estimatedCost: 0.50,
            carbonFootprint: 0.02
        )
    }
}

struct ResourceEstimate {
    var computeHours: Double
    var storageGB: Double
    var networkGB: Double
    var estimatedCost: Double
    var carbonFootprint: Double  // kg CO2
}

// MARK: - Impact Tracking

class ImpactTracker {
    private var projectImpacts: [UUID: ProjectImpact] = [:]

    func trackProjectCreation(_ project: Project) {
        projectImpacts[project.id] = ProjectImpact(projectId: project.id)
    }

    func finalizeProjectImpact(_ project: Project) {
        guard var impact = projectImpacts[project.id] else { return }
        impact.finalizedAt = Date()
        projectImpacts[project.id] = impact
    }
}

struct ProjectImpact: Identifiable {
    var id: UUID { projectId }
    let projectId: UUID
    var createdAt: Date = Date()
    var finalizedAt: Date?

    // Environmental
    var totalCarbonKg: Double = 0
    var carbonOffsetKg: Double = 0
    var renewableEnergyPercent: Double = 0

    // Social
    var peopleReached: Int = 0
    var accessibleFormats: Int = 0
    var languagesSupported: Int = 0

    // Therapeutic
    var therapySessionsEnabled: Int = 0
    var meditationMinutesProvided: Int = 0
    var wellnessImprovements: Int = 0
}

// MARK: - Export Record

struct ExportRecord: Identifiable {
    let id = UUID()
    var projectId: UUID
    var format: ExportFormat
    var resolution: String
    var fileSize: Int64
    var exportedAt: Date
    var destination: ExportDestination

    // Accessibility
    var includesClosedCaptions: Bool = false
    var includesAudioDescription: Bool = false
    var includesTranscript: Bool = false
    var languageVariants: [String] = []

    enum ExportFormat: String {
        case wav, aiff, flac, mp3, aac
        case dolbyAtmos, appleSpatial
        case video4k, video1080p, video720p
        case stem, midi
    }

    enum ExportDestination: String {
        case local, cloud, streaming, archive
    }
}

// MARK: - Production Manager Extensions

extension ProductionManager {

    // MARK: - Sustainability Features

    func calculateProjectSustainability(_ project: Project) -> SustainabilityScore {
        var score = SustainabilityScore()

        // Calculate based on sessions
        let totalEnergy = project.sessions.reduce(0) { $0 + $1.energyUsed }
        let totalOffset = project.sessions.reduce(0) { $0 + $1.carbonOffset }

        score.energyEfficiency = min(100, 100 - (totalEnergy * 10))
        score.carbonFootprint = totalEnergy * 0.5 - totalOffset
        score.renewableEnergy = 75  // Assume 75% renewable by default

        // Check sustainability goals
        let goalsAchieved = project.sustainabilityGoals.filter { $0.isAchieved }.count
        let goalProgress = project.sustainabilityGoals.isEmpty ? 1.0 :
            Double(goalsAchieved) / Double(project.sustainabilityGoals.count)

        score.overallScore = (score.energyEfficiency + score.renewableEnergy + goalProgress * 100) / 3

        return score
    }

    func suggestSustainabilityImprovements(_ project: Project) -> [SustainabilityRecommendation] {
        var recommendations: [SustainabilityRecommendation] = []

        // Check energy usage
        let totalEnergy = project.sessions.reduce(0) { $0 + $1.energyUsed }
        if totalEnergy > 10 {
            recommendations.append(SustainabilityRecommendation(
                title: "Optimize Render Settings",
                description: "Use adaptive quality rendering to reduce energy consumption by up to 40%",
                impact: .high,
                category: .energy
            ))
        }

        // Check carbon offset
        let carbon = project.carbonFootprint
        if !carbon.isNeutral {
            recommendations.append(SustainabilityRecommendation(
                title: "Carbon Offset",
                description: "Purchase carbon credits to offset \(String(format: "%.2f", carbon.netEmissions)) kg CO2",
                impact: .medium,
                category: .carbon
            ))
        }

        // Check local processing
        recommendations.append(SustainabilityRecommendation(
            title: "Enable On-Device Processing",
            description: "Process bio-reactive audio locally to reduce network emissions",
            impact: .medium,
            category: .network
        ))

        return recommendations
    }

    // MARK: - Accessibility Features

    func auditAccessibility(_ project: Project) -> AccessibilityAuditResult {
        var result = AccessibilityAuditResult(projectId: project.id)

        // Check exports for accessibility features
        for export in project.exports {
            if export.includesClosedCaptions {
                result.passedChecks.append("Closed captions available")
            } else {
                result.failedChecks.append("Missing closed captions")
            }

            if export.includesAudioDescription {
                result.passedChecks.append("Audio description available")
            }

            if export.includesTranscript {
                result.passedChecks.append("Transcript available")
            }

            if export.languageVariants.count > 1 {
                result.passedChecks.append("Multiple languages: \(export.languageVariants.joined(separator: ", "))")
            }
        }

        // Check for accessibility features enabled
        for feature in project.accessibilityFeatures {
            result.passedChecks.append("\(feature.rawValue) enabled")
        }

        // Calculate compliance
        let total = result.passedChecks.count + result.failedChecks.count
        result.complianceScore = total > 0 ? Double(result.passedChecks.count) / Double(total) * 100 : 0

        return result
    }

    func recommendAccessibilityFeatures(for member: TeamMember) -> [AccessibilityFeature] {
        var features: [AccessibilityFeature] = []

        for need in member.accessibilityNeeds {
            switch need.type {
            case .lowVision:
                features.append(contentsOf: [.highContrast, .largeText])
            case .colorBlindness:
                features.append(.colorBlindMode)
            case .blindness:
                features.append(contentsOf: [.screenReader, .voiceControl])
            case .hardOfHearing:
                features.append(contentsOf: [.closedCaptions, .visualAlerts])
            case .deafness:
                features.append(contentsOf: [.closedCaptions, .signLanguage, .visualAlerts])
            case .auditoryProcessing:
                features.append(contentsOf: [.closedCaptions, .paceControl])
            case .limitedMobility:
                features.append(contentsOf: [.voiceControl, .largeTargets])
            case .tremors:
                features.append(contentsOf: [.dwellControl, .largeTargets])
            case .paralysis:
                features.append(contentsOf: [.voiceControl, .switchControl])
            case .adhd:
                features.append(contentsOf: [.focusMode, .simplifiedUI])
            case .dyslexia:
                features.append(contentsOf: [.readingGuides, .largeText])
            case .autism:
                features.append(contentsOf: [.reducedMotion, .simplifiedUI, .paceControl])
            case .memoryImpairment:
                features.append(contentsOf: [.memoryAids, .simplifiedUI])
            }
        }

        return Array(Set(features))  // Remove duplicates
    }

    // MARK: - Team Wellness

    func checkTeamWellness() -> [WellnessAlert] {
        var alerts: [WellnessAlert] = []

        for member in teamMembers {
            // Check workload
            if member.workloadScore > 0.8 {
                alerts.append(WellnessAlert(
                    memberId: member.id,
                    type: .overwork,
                    message: "\(member.name) has high workload (\(Int(member.workloadScore * 100))%). Consider redistributing tasks.",
                    severity: .warning
                ))
            }

            // Check break reminders
            if let lastBreak = member.lastBreakReminder,
               Date().timeIntervalSince(lastBreak) > 7200 {  // 2 hours
                alerts.append(WellnessAlert(
                    memberId: member.id,
                    type: .breakNeeded,
                    message: "It's been 2+ hours since \(member.name)'s last break.",
                    severity: .info
                ))
            }
        }

        return alerts
    }

    func suggestOptimalScheduling(for project: Project) -> SchedulingSuggestion {
        // Consider team timezones, work hours, and accessibility needs
        let members = teamMembers.filter { member in
            project.team.contains(where: { $0.id == member.id })
        }

        // Find overlapping work hours
        var overlappingHours: [Int] = []
        for hour in 0..<24 {
            let available = members.filter { member in
                hour >= member.preferredWorkHours.start && hour < member.preferredWorkHours.end
            }
            if available.count == members.count {
                overlappingHours.append(hour)
            }
        }

        return SchedulingSuggestion(
            recommendedHours: overlappingHours,
            timezone: TimeZone.current,
            accommodations: members.flatMap { $0.accessibilityNeeds.flatMap { $0.accommodations } }
        )
    }
}

// MARK: - Supporting Types

struct SustainabilityRecommendation: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var impact: Impact
    var category: Category

    enum Impact: String {
        case low, medium, high
    }

    enum Category: String {
        case energy, carbon, water, waste, network
    }
}

struct AccessibilityAuditResult {
    var projectId: UUID
    var passedChecks: [String] = []
    var failedChecks: [String] = []
    var recommendations: [String] = []
    var complianceScore: Double = 0

    var wcagLevel: AccessibilityStatus.WCAGLevel {
        switch complianceScore {
        case 90...100: return .aaa
        case 70..<90: return .aa
        case 50..<70: return .a
        default: return .none
        }
    }
}

struct WellnessAlert: Identifiable {
    let id = UUID()
    var memberId: UUID
    var type: AlertType
    var message: String
    var severity: Severity
    var createdAt: Date = Date()

    enum AlertType: String {
        case overwork = "Overwork"
        case breakNeeded = "Break Needed"
        case scheduleConflict = "Schedule Conflict"
        case accessibilityBarrier = "Accessibility Barrier"
    }

    enum Severity: String {
        case info, warning, critical
    }
}

struct SchedulingSuggestion {
    var recommendedHours: [Int]
    var timezone: TimeZone
    var accommodations: [String]

    var formattedHours: String {
        guard let start = recommendedHours.first,
              let end = recommendedHours.last else {
            return "No overlapping hours found"
        }
        return "\(start):00 - \(end + 1):00 \(timezone.abbreviation() ?? "UTC")"
    }
}
