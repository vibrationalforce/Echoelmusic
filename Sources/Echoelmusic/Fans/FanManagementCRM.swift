import Foundation
import Combine

/// Fan Management & CRM System
/// Professional customer relationship management for artists
///
/// Features:
/// - Fan database with segmentation
/// - Email list management
/// - Fan club with exclusive content
/// - Direct messaging system
/// - Fan analytics & insights
/// - Automated engagement campaigns
/// - VIP & superfan tracking
/// - Lifetime value calculation
@MainActor
class FanManagementCRM: ObservableObject {

    // MARK: - Published Properties

    @Published var fans: [Fan] = []
    @Published var segments: [FanSegment] = []
    @Published var campaigns: [EngagementCampaign] = []
    @Published var fanClub: FanClub?
    @Published var analytics: FanAnalytics

    // MARK: - Fan

    struct Fan: Identifiable {
        let id = UUID()
        var email: String
        var name: String?
        var phoneNumber: String?
        var dateAdded: Date
        var source: AcquisitionSource
        var tier: FanTier
        var tags: [String]
        var customFields: [String: String]
        var engagement: EngagementMetrics
        var purchases: [Purchase]
        var interactions: [Interaction]
        var preferences: Preferences

        enum AcquisitionSource: String {
            case concert, website, social, streaming
            case referral, contest, signup, other
        }

        enum FanTier: String {
            case casual = "Casual Listener"
            case engaged = "Engaged Fan"
            case superfan = "Superfan"
            case vip = "VIP"
            case ambassador = "Brand Ambassador"

            var benefits: [String] {
                switch self {
                case .casual:
                    return ["Email updates"]
                case .engaged:
                    return ["Email updates", "Early access to tickets"]
                case .superfan:
                    return ["All Engaged benefits", "Exclusive content", "Fan club access"]
                case .vip:
                    return ["All Superfan benefits", "Meet & greet", "Backstage access"]
                case .ambassador:
                    return ["All VIP benefits", "Revenue share", "Creative input"]
                }
            }
        }

        struct EngagementMetrics {
            var emailOpenRate: Double
            var emailClickRate: Double
            var lastInteraction: Date?
            var totalInteractions: Int
            var engagementScore: Double  // 0-100

            mutating func calculateEngagementScore() {
                var score = 0.0

                // Recent interaction (0-30 points)
                if let lastInteraction = lastInteraction {
                    let daysSince = Date().timeIntervalSince(lastInteraction) / 86400
                    score += max(0, 30 - daysSince)
                }

                // Email engagement (0-30 points)
                score += emailOpenRate * 15
                score += emailClickRate * 15

                // Interaction frequency (0-40 points)
                score += min(40, Double(totalInteractions) * 2)

                engagementScore = min(100, score)
            }
        }

        struct Purchase {
            let id = UUID()
            let date: Date
            let type: PurchaseType
            let amount: Double
            let items: [String]

            enum PurchaseType {
                case music, merchandise, ticket, donation, other
            }
        }

        struct Interaction {
            let id = UUID()
            let date: Date
            let type: InteractionType
            let details: String?

            enum InteractionType {
                case email, message, comment, attend, stream, share
            }
        }

        struct Preferences {
            var emailFrequency: EmailFrequency
            var interests: [Interest]
            var contentPreferences: [ContentType]
            var timezone: String?

            enum EmailFrequency: String {
                case daily = "Daily"
                case weekly = "Weekly"
                case monthly = "Monthly"
                case majorUpdates = "Major Updates Only"
            }

            enum Interest: String {
                case newMusic, behindTheScenes, tours
                case merchandise, exclusiveContent
            }

            enum ContentType: String {
                case email, sms, push, social
            }
        }

        var lifetimeValue: Double {
            purchases.reduce(0) { $0 + $1.amount }
        }
    }

    // MARK: - Fan Segment

    struct FanSegment: Identifiable {
        let id = UUID()
        var name: String
        var criteria: [SegmentCriteria]
        var fanCount: Int
        var description: String?

        struct SegmentCriteria {
            let field: Field
            let operator: Operator
            let value: String

            enum Field: String {
                case tier, source, tag, lifetimeValue
                case engagementScore, lastInteraction
                case location, age
            }

            enum Operator: String {
                case equals, notEquals, contains
                case greaterThan, lessThan
                case inLast, notInLast
            }
        }

        // Predefined segments
        static let superfans = FanSegment(
            name: "Superfans",
            criteria: [
                SegmentCriteria(field: .tier, operator: .equals, value: "superfan")
            ],
            fanCount: 0,
            description: "Highly engaged fans with strong connection"
        )

        static let recentInactive = FanSegment(
            name: "Recently Inactive",
            criteria: [
                SegmentCriteria(field: .lastInteraction, operator: .notInLast, value: "30")
            ],
            fanCount: 0,
            description: "Fans who haven't engaged in 30+ days"
        )

        static let highValue = FanSegment(
            name: "High Value",
            criteria: [
                SegmentCriteria(field: .lifetimeValue, operator: .greaterThan, value: "100")
            ],
            fanCount: 0,
            description: "Fans who have spent $100+"
        )
    }

    // MARK: - Engagement Campaign

    struct EngagementCampaign: Identifiable {
        let id = UUID()
        var name: String
        var type: CampaignType
        var targetSegment: FanSegment
        var content: CampaignContent
        var schedule: Schedule
        var status: CampaignStatus
        var results: CampaignResults?

        enum CampaignType {
            case email, sms, push, inApp
        }

        struct CampaignContent {
            var subject: String
            var body: String
            var callToAction: String?
            var link: String?
            var media: [URL]
        }

        struct Schedule {
            var startDate: Date
            var frequency: Frequency?
            var endDate: Date?

            enum Frequency {
                case once, daily, weekly, monthly
            }
        }

        enum CampaignStatus {
            case draft, scheduled, active, completed, paused
        }

        struct CampaignResults {
            var sent: Int
            var delivered: Int
            var opened: Int
            var clicked: Int
            var conversions: Int
            var revenue: Double

            var openRate: Double {
                guard delivered > 0 else { return 0 }
                return Double(opened) / Double(delivered) * 100
            }

            var clickRate: Double {
                guard opened > 0 else { return 0 }
                return Double(clicked) / Double(opened) * 100
            }

            var conversionRate: Double {
                guard clicked > 0 else { return 0 }
                return Double(conversions) / Double(clicked) * 100
            }
        }
    }

    // MARK: - Fan Club

    struct FanClub {
        var name: String
        var description: String
        var tiers: [MembershipTier]
        var memberCount: Int
        var content: [ExclusiveContent]
        var benefits: [String]

        struct MembershipTier {
            let name: String
            let price: Double
            let interval: BillingInterval
            let benefits: [String]
            var memberCount: Int

            enum BillingInterval: String {
                case monthly = "Monthly"
                case yearly = "Yearly"
                case lifetime = "Lifetime"
            }
        }

        struct ExclusiveContent {
            let id = UUID()
            let title: String
            let type: ContentType
            let dateAdded: Date
            let url: URL
            let requiredTier: String?

            enum ContentType {
                case audio, video, photo, document, livestream
            }
        }
    }

    // MARK: - Fan Analytics

    struct FanAnalytics {
        var totalFans: Int
        var newFansThisMonth: Int
        var growthRate: Double
        var averageLifetimeValue: Double
        var totalRevenue: Double
        var tierDistribution: [String: Int]
        var sourceDistribution: [String: Int]
        var engagementTrends: [Date: Double]
        var topLocations: [LocationData]
        var churnRate: Double

        struct LocationData {
            let location: String
            let fanCount: Int
            let percentage: Double
        }
    }

    // MARK: - Initialization

    init() {
        print("👥 Fan Management CRM initialized")

        self.analytics = FanAnalytics(
            totalFans: 0,
            newFansThisMonth: 0,
            growthRate: 0,
            averageLifetimeValue: 0,
            totalRevenue: 0,
            tierDistribution: [:],
            sourceDistribution: [:],
            engagementTrends: [:],
            topLocations: [],
            churnRate: 0
        )

        // Load predefined segments
        segments = [
            FanSegment.superfans,
            FanSegment.recentInactive,
            FanSegment.highValue
        ]

        print("   ✅ CRM ready")
    }

    // MARK: - Add Fan

    func addFan(
        email: String,
        name: String?,
        source: Fan.AcquisitionSource,
        tags: [String] = []
    ) -> Fan {
        print("➕ Adding new fan...")
        print("   Email: \(email)")
        print("   Source: \(source.rawValue)")

        let fan = Fan(
            email: email,
            name: name,
            dateAdded: Date(),
            source: source,
            tier: .casual,
            tags: tags,
            customFields: [:],
            engagement: Fan.EngagementMetrics(
                emailOpenRate: 0,
                emailClickRate: 0,
                lastInteraction: Date(),
                totalInteractions: 0,
                engagementScore: 0
            ),
            purchases: [],
            interactions: [],
            preferences: Fan.Preferences(
                emailFrequency: .weekly,
                interests: [],
                contentPreferences: [.email],
                timezone: nil
            )
        )

        fans.append(fan)
        updateAnalytics()

        print("   ✅ Fan added")

        return fan
    }

    // MARK: - Segment Fans

    func segmentFans(by segment: FanSegment) -> [Fan] {
        print("🎯 Segmenting fans: \(segment.name)")

        let segmentedFans = fans.filter { fan in
            segment.criteria.allSatisfy { criteria in
                matchesCriteria(fan: fan, criteria: criteria)
            }
        }

        print("   ✅ Found \(segmentedFans.count) fans in segment")

        return segmentedFans
    }

    private func matchesCriteria(fan: Fan, criteria: FanSegment.SegmentCriteria) -> Bool {
        switch criteria.field {
        case .tier:
            return fan.tier.rawValue == criteria.value

        case .source:
            return fan.source.rawValue == criteria.value

        case .tag:
            return fan.tags.contains(criteria.value)

        case .lifetimeValue:
            guard let threshold = Double(criteria.value) else { return false }
            switch criteria.operator {
            case .greaterThan:
                return fan.lifetimeValue > threshold
            case .lessThan:
                return fan.lifetimeValue < threshold
            default:
                return false
            }

        case .engagementScore:
            guard let threshold = Double(criteria.value) else { return false }
            return fan.engagement.engagementScore > threshold

        case .lastInteraction:
            guard let days = Int(criteria.value),
                  let lastInteraction = fan.engagement.lastInteraction else {
                return false
            }

            let daysSince = Date().timeIntervalSince(lastInteraction) / 86400

            switch criteria.operator {
            case .inLast:
                return daysSince <= Double(days)
            case .notInLast:
                return daysSince > Double(days)
            default:
                return false
            }

        default:
            return false
        }
    }

    // MARK: - Create Campaign

    func createCampaign(
        name: String,
        type: EngagementCampaign.CampaignType,
        segment: FanSegment,
        content: EngagementCampaign.CampaignContent,
        schedule: EngagementCampaign.Schedule
    ) -> EngagementCampaign {
        print("📧 Creating engagement campaign: \(name)")

        let campaign = EngagementCampaign(
            name: name,
            type: type,
            targetSegment: segment,
            content: content,
            schedule: schedule,
            status: .draft
        )

        campaigns.append(campaign)

        print("   ✅ Campaign created")

        return campaign
    }

    func launchCampaign(_ campaignId: UUID) async {
        guard let index = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        print("🚀 Launching campaign: \(campaigns[index].name)")

        campaigns[index].status = .active

        // Get target fans
        let targetFans = segmentFans(by: campaigns[index].targetSegment)

        print("   📤 Sending to \(targetFans.count) fans...")

        // Send campaign
        var results = EngagementCampaign.CampaignResults(
            sent: 0,
            delivered: 0,
            opened: 0,
            clicked: 0,
            conversions: 0,
            revenue: 0
        )

        for fan in targetFans {
            let success = await sendCampaignMessage(
                to: fan,
                campaign: campaigns[index]
            )

            if success {
                results.sent += 1
                results.delivered += 1

                // Simulate engagement
                if Double.random(in: 0...1) < fan.engagement.emailOpenRate {
                    results.opened += 1

                    if Double.random(in: 0...1) < fan.engagement.emailClickRate {
                        results.clicked += 1
                    }
                }
            }
        }

        campaigns[index].results = results
        campaigns[index].status = .completed

        print("   ✅ Campaign completed")
        print("      Sent: \(results.sent)")
        print("      Open Rate: \(String(format: "%.1f", results.openRate))%")
        print("      Click Rate: \(String(format: "%.1f", results.clickRate))%")
    }

    private func sendCampaignMessage(to fan: Fan, campaign: EngagementCampaign) async -> Bool {
        // In production: Send via email service (SendGrid, Mailchimp, etc.)
        try? await Task.sleep(nanoseconds: 10_000_000)  // 0.01s
        return true
    }

    // MARK: - Fan Club

    func createFanClub(
        name: String,
        description: String,
        tiers: [FanClub.MembershipTier]
    ) -> FanClub {
        print("🌟 Creating fan club: \(name)")

        let fanClub = FanClub(
            name: name,
            description: description,
            tiers: tiers,
            memberCount: 0,
            content: [],
            benefits: []
        )

        self.fanClub = fanClub

        print("   ✅ Fan club created")
        print("      Tiers: \(tiers.count)")

        return fanClub
    }

    func addExclusiveContent(
        title: String,
        type: FanClub.ExclusiveContent.ContentType,
        url: URL,
        requiredTier: String?
    ) {
        guard fanClub != nil else {
            print("❌ No fan club exists")
            return
        }

        let content = FanClub.ExclusiveContent(
            title: title,
            type: type,
            dateAdded: Date(),
            url: url,
            requiredTier: requiredTier
        )

        fanClub?.content.append(content)

        print("✅ Exclusive content added: \(title)")
    }

    // MARK: - Track Interaction

    func trackInteraction(
        fanId: UUID,
        type: Fan.Interaction.InteractionType,
        details: String? = nil
    ) {
        guard let index = fans.firstIndex(where: { $0.id == fanId }) else {
            return
        }

        let interaction = Fan.Interaction(
            date: Date(),
            type: type,
            details: details
        )

        fans[index].interactions.append(interaction)
        fans[index].engagement.lastInteraction = Date()
        fans[index].engagement.totalInteractions += 1
        fans[index].engagement.calculateEngagementScore()

        // Auto-upgrade tier based on engagement
        autoUpgradeTier(fanIndex: index)
    }

    private func autoUpgradeTier(fanIndex: Int) {
        let score = fans[fanIndex].engagement.engagementScore
        let ltv = fans[fanIndex].lifetimeValue

        if ltv > 500 && score > 80 {
            fans[fanIndex].tier = .vip
        } else if ltv > 100 && score > 60 {
            fans[fanIndex].tier = .superfan
        } else if score > 40 {
            fans[fanIndex].tier = .engaged
        }
    }

    // MARK: - Analytics

    func updateAnalytics() {
        analytics.totalFans = fans.count

        // Growth rate
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        analytics.newFansThisMonth = fans.filter { $0.dateAdded >= startOfMonth }.count

        // LTV
        let totalLTV = fans.reduce(0) { $0 + $1.lifetimeValue }
        analytics.averageLifetimeValue = analytics.totalFans > 0 ? totalLTV / Double(analytics.totalFans) : 0
        analytics.totalRevenue = totalLTV

        // Tier distribution
        analytics.tierDistribution = Dictionary(grouping: fans) { $0.tier.rawValue }
            .mapValues { $0.count }

        // Source distribution
        analytics.sourceDistribution = Dictionary(grouping: fans) { $0.source.rawValue }
            .mapValues { $0.count }

        print("📊 Analytics updated")
        print("   Total Fans: \(analytics.totalFans)")
        print("   New This Month: \(analytics.newFansThisMonth)")
        print("   Avg LTV: $\(String(format: "%.2f", analytics.averageLifetimeValue))")
    }

    // MARK: - Export

    func exportFans(segment: FanSegment? = nil) -> String {
        let fansToExport = segment != nil ? segmentFans(by: segment!) : fans

        var csv = "Email,Name,Tier,Source,Lifetime Value,Engagement Score\n"

        for fan in fansToExport {
            csv += "\(fan.email),\(fan.name ?? ""),\(fan.tier.rawValue),\(fan.source.rawValue),\(fan.lifetimeValue),\(fan.engagement.engagementScore)\n"
        }

        return csv
    }

    // MARK: - Reports

    func generateFanReport() -> String {
        var report = """
        ═══════════════════════════════════════
        FAN MANAGEMENT REPORT
        ═══════════════════════════════════════

        OVERVIEW
        ───────────────────────────────────────
        Total Fans: \(analytics.totalFans)
        New This Month: \(analytics.newFansThisMonth)
        Growth Rate: \(String(format: "%.1f", analytics.growthRate))%

        REVENUE
        ───────────────────────────────────────
        Total Revenue: $\(String(format: "%.2f", analytics.totalRevenue))
        Average LTV: $\(String(format: "%.2f", analytics.averageLifetimeValue))

        TIER DISTRIBUTION
        ───────────────────────────────────────

        """

        for (tier, count) in analytics.tierDistribution.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(analytics.totalFans) * 100
            report += "\(tier): \(count) (\(String(format: "%.1f", percentage))%)\n"
        }

        report += """


        ACQUISITION SOURCES
        ───────────────────────────────────────

        """

        for (source, count) in analytics.sourceDistribution.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(analytics.totalFans) * 100
            report += "\(source): \(count) (\(String(format: "%.1f", percentage))%)\n"
        }

        report += "\n═══════════════════════════════════════"

        return report
    }
}
