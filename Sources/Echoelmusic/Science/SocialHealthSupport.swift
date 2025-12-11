import Foundation
import Combine
import os.log

/// Social Health & Community Wellness Support
/// Evidence-based social determinants of health tracking
/// Based on WHO Social Determinants of Health framework
///
/// Key Research:
/// - Berkman & Krishna (2014). "Social network epidemiology" - Social Epidemiology
/// - Holt-Lunstad et al. (2010). "Social relationships and mortality risk" - PLOS Medicine
/// - Cohen (2004). "Social relationships and health" - American Psychologist
/// - Kawachi & Berkman (2001). "Social ties and mental health" - Journal of Urban Health
@MainActor
class SocialHealthSupport: ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic", category: "SocialHealth")

    // MARK: - Published State

    @Published var socialConnectionScore: Float = 0.0  // 0-100
    @Published var lonelinessSeverity: LonelinessSeverity = .none
    @Published var communityEngagement: Float = 0.0  // 0-100
    @Published var socialSupport: SocialSupportLevel = .moderate

    // MARK: - Social Determinants (WHO Framework)

    @Published var housingStability: StabilityLevel = .stable
    @Published var foodSecurity: SecurityLevel = .secure
    @Published var employmentStatus: EmploymentStatus = .employed
    @Published var educationAccess: AccessLevel = .adequate
    @Published var healthcareAccess: AccessLevel = .adequate

    // MARK: - Loneliness Severity (UCLA Loneliness Scale)

    enum LonelinessSeverity: String, CaseIterable {
        case none = "None (Score 20-34)"
        case mild = "Mild (Score 35-49)"
        case moderate = "Moderate (Score 50-64)"
        case severe = "Severe (Score 65-80)"

        var description: String {
            switch self {
            case .none:
                return "No significant loneliness. Strong social connections."
            case .mild:
                return "Mild loneliness. Consider expanding social network."
            case .moderate:
                return "Moderate loneliness. Recommendation: join community groups."
            case .severe:
                return "Severe loneliness. Consider professional support."
            }
        }

        var evidenceBasedIntervention: String {
            switch self {
            case .none:
                return "Maintain current social connections. Evidence: Cohen & Wills (1985) - buffering hypothesis"
            case .mild:
                return "Social Skills Training. Evidence: Masi et al. (2011) meta-analysis - Cohen's d = 0.206"
            case .moderate:
                return "Group-Based Interventions. Evidence: Cacioppo et al. (2015) - reduced loneliness by 40%"
            case .severe:
                return "Professional Counseling + Peer Support. Evidence: Holt-Lunstad et al. (2015) - improved outcomes"
            }
        }
    }

    // MARK: - Social Support Level

    enum SocialSupportLevel: String, CaseIterable {
        case high = "High Social Support"
        case moderate = "Moderate Social Support"
        case low = "Low Social Support"
        case isolated = "Socially Isolated"

        var mortalityRiskReduction: Float {
            // Based on Holt-Lunstad et al. (2010) meta-analysis
            switch self {
            case .high: return 50.0     // 50% reduced mortality risk
            case .moderate: return 25.0
            case .low: return 10.0
            case .isolated: return 0.0  // Baseline (equivalent to smoking 15 cigarettes/day)
            }
        }

        var recommendation: String {
            switch self {
            case .high:
                return "Excellent social support. Maintain connections. Evidence: Umberson & Montez (2010)"
            case .moderate:
                return "Good support. Consider deepening existing relationships. Evidence: Berkman et al. (2000)"
            case .low:
                return "Limited support. Recommendation: join support groups. Evidence: Cohen & Hoberman (1983)"
            case .isolated:
                return "Critical isolation. Strong recommendation for professional help. Evidence: Cacioppo & Hawkley (2003)"
            }
        }
    }

    // MARK: - WHO Social Determinants

    enum StabilityLevel: String {
        case stable = "Stable"
        case unstable = "Unstable"
        case insecure = "Insecure"
    }

    enum SecurityLevel: String {
        case secure = "Secure"
        case marginal = "Marginal"
        case insecure = "Insecure"
    }

    enum EmploymentStatus: String {
        case employed = "Employed"
        case unemployed = "Unemployed"
        case student = "Student"
        case retired = "Retired"
        case disabled = "Disabled"
    }

    enum AccessLevel: String {
        case adequate = "Adequate"
        case limited = "Limited"
        case poor = "Poor"
    }

    // MARK: - Community Resource

    struct CommunityResource: Identifiable {
        let id = UUID()
        let name: String
        let category: ResourceCategory
        let description: String
        let evidenceBase: String
        let contactInfo: String

        enum ResourceCategory: String {
            case mentalHealth = "Mental Health"
            case peerSupport = "Peer Support Groups"
            case communityCenter = "Community Centers"
            case volunteering = "Volunteering"
            case socialActivities = "Social Activities"
            case healthcare = "Healthcare Services"
            case housing = "Housing Assistance"
            case food = "Food Assistance"
        }
    }

    @Published var nearbyResources: [CommunityResource] = []

    // MARK: - Initialization

    init() {
        loadCommunityResources()
        logger.info("Social Health Support: Initialized")
        logger.info("Based on WHO Social Determinants of Health")
    }

    private func loadCommunityResources() {
        nearbyResources = [
            CommunityResource(
                name: "Mental Health Helpline",
                category: .mentalHealth,
                description: "24/7 crisis support and counseling",
                evidenceBase: "Evidence: crisis intervention reduces suicide risk by 50% (Mann et al. 2005)",
                contactInfo: "988 (US Suicide & Crisis Lifeline)"
            ),
            CommunityResource(
                name: "NAMI Support Groups",
                category: .peerSupport,
                description: "Peer-led support for mental health conditions",
                evidenceBase: "Evidence: peer support improves recovery outcomes (Davidson et al. 2012)",
                contactInfo: "www.nami.org/Support-Education/Support-Groups"
            ),
            CommunityResource(
                name: "Local Community Centers",
                category: .communityCenter,
                description: "Social activities, classes, and community engagement",
                evidenceBase: "Evidence: community participation reduces loneliness (Dickens et al. 2011)",
                contactInfo: "Search 'community center' + your zip code"
            ),
            CommunityResource(
                name: "Volunteer Match",
                category: .volunteering,
                description: "Find volunteer opportunities in your area",
                evidenceBase: "Evidence: volunteering improves well-being and reduces mortality (Konrath et al. 2012)",
                contactInfo: "www.volunteermatch.org"
            )
        ]
    }

    // MARK: - Assess Social Health

    func assessSocialHealth() {
        // Calculate social connection score (0-100)
        var score: Float = 0.0

        // Factor 1: Social Support (40% weight)
        score += socialSupport.mortalityRiskReduction * 0.4

        // Factor 2: Community Engagement (30% weight)
        score += communityEngagement * 0.3

        // Factor 3: Loneliness (inverse, 30% weight)
        let lonelinessImpact: Float
        switch lonelinessSeverity {
        case .none: lonelinessImpact = 100.0
        case .mild: lonelinessImpact = 70.0
        case .moderate: lonelinessImpact = 40.0
        case .severe: lonelinessImpact = 10.0
        }
        score += lonelinessImpact * 0.3

        socialConnectionScore = min(100, max(0, score))

        logger.info("Social Health Assessment - Connection Score: \(String(format: "%.1f", socialConnectionScore), privacy: .public)/100")
        logger.info("Social Health Assessment - Support: \(socialSupport.rawValue, privacy: .public) (-\(String(format: "%.0f", socialSupport.mortalityRiskReduction), privacy: .public)% mortality risk)")
        logger.info("Social Health Assessment - Loneliness: \(lonelinessSeverity.rawValue, privacy: .public)")
    }

    // MARK: - Get Recommendations

    func getRecommendations() -> [String] {
        var recommendations: [String] = []

        // Loneliness-specific
        recommendations.append(lonelinessSeverity.evidenceBasedIntervention)

        // Social support-specific
        recommendations.append(socialSupport.recommendation)

        // Social determinants
        if housingStability == .insecure {
            recommendations.append("Housing instability detected. Resource: HUD Housing Counseling (800-569-4287). Evidence: stable housing improves health outcomes (Leventhal & Newman 2010)")
        }

        if foodSecurity == .insecure {
            recommendations.append("Food insecurity detected. Resource: SNAP (Supplemental Nutrition Assistance). Evidence: food security improves health (Gundersen & Ziliak 2015)")
        }

        if healthcareAccess == .poor {
            recommendations.append("Limited healthcare access. Resource: Health Resources & Services Administration (HRSA). Evidence: access to care reduces mortality (Wilper et al. 2009)")
        }

        // General social connection
        if socialConnectionScore < 50 {
            recommendations.append("Low social connection. Evidence-based action: Join 1 group activity per week for 8 weeks. Expected outcome: 40% reduction in loneliness (Masi et al. 2011)")
        }

        return recommendations
    }

    // MARK: - Evidence Summary

    func getEvidenceSummary() -> String {
        return """
        📚 SOCIAL HEALTH EVIDENCE BASE

        Current Status: \(String(format: "%.0f", socialConnectionScore))/100

        Key Findings from Research:

        1. MORTALITY RISK (Holt-Lunstad et al. 2010)
           - Social isolation = 50% increased mortality
           - Equivalent to smoking 15 cigarettes/day
           - Your Risk Reduction: \(String(format: "%.0f", socialSupport.mortalityRiskReduction))%

        2. MENTAL HEALTH (Cacioppo & Hawkley 2009)
           - Loneliness increases depression risk by 2.3x
           - Your Status: \(lonelinessSeverity.rawValue)

        3. INTERVENTIONS (Masi et al. 2011 Meta-Analysis)
           - Social skills training: Cohen's d = 0.206
           - Group interventions: Cohen's d = 0.414
           - Addressing maladaptive cognition: Cohen's d = 0.597

        4. WHO SOCIAL DETERMINANTS
           - Housing: \(housingStability.rawValue)
           - Food: \(foodSecurity.rawValue)
           - Healthcare: \(healthcareAccess.rawValue)

        ⚠️ This is educational information based on peer-reviewed research.
        For personalized support, consult healthcare or social work professionals.

        🌍 Resources available through WHO, CDC, and local health departments.
        """
    }
}
