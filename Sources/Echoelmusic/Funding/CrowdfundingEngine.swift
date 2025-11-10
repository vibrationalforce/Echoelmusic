import Foundation

/// Crowdfunding & Fan Funding Engine
/// Complete system for raising funds through crowdfunding, patronage, and fan support
///
/// Features:
/// - Kickstarter/Indiegogo-style campaigns
/// - Patreon integration & membership tiers
/// - Direct fan support (Tip Jar, Buy Me a Coffee)
/// - Pre-order campaigns
/// - Stretch goals & unlockables
/// - Backer rewards & fulfillment
/// - Campaign analytics & insights
/// - Recurring subscriptions
/// - Virtual tip jar for live streams
@MainActor
class CrowdfundingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var campaigns: [Campaign] = []
    @Published var patronTiers: [PatronTier] = []
    <br />    @Published var backers: [Backer] = []
    @Published var transactions: [Transaction] = []

    // MARK: - Campaign

    struct Campaign: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var type: CampaignType
        var fundingGoal: Double
        var currentFunding: Double
        var startDate: Date
        var endDate: Date
        var rewards: [Reward]
        var stretchGoals: [StretchGoal]
        var updates: [CampaignUpdate]
        var status: CampaignStatus
        var platform: Platform

        enum CampaignType {
            case album, tour, video, equipment, studio, merch, general
        }

        enum CampaignStatus {
            case draft, live, funded, failed, completed, cancelled
        }

        enum Platform: String, CaseIterable {
            case kickstarter = "Kickstarter"
            case indiegogo = "Indiegogo"
            case patreon = "Patreon"
            case gofundme = "GoFundMe"
            case buymeacoffee = "Buy Me a Coffee"
            case kofi = "Ko-fi"
            case direct = "Direct (Echoelmusic)"

            var commissionRate: Double {
                switch self {
                case .kickstarter: return 5.0
                case .indiegogo: return 5.0
                case .patreon: return 8.0
                case .gofundme: return 2.9
                case .buymeacoffee: return 5.0
                case .kofi: return 0.0
                case .direct: return 0.0
                }
            }

            var paymentProcessingFee: Double {
                // Most use Stripe (2.9% + $0.30)
                return 2.9
            }
        }

        var backerCount: Int {
            rewards.reduce(0) { $0 + $1.backerCount }
        }

        var fundingPercentage: Double {
            guard fundingGoal > 0 else { return 0.0 }
            return (currentFunding / fundingGoal) * 100.0
        }

        var isFunded: Bool {
            currentFunding >= fundingGoal
        }

        var daysRemaining: Int {
            let remaining = endDate.timeIntervalSince(Date())
            return max(0, Int(remaining / 86400))
        }

        var isActive: Bool {
            status == .live && Date() >= startDate && Date() <= endDate
        }
    }

    // MARK: - Reward

    struct Reward: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var pledgeAmount: Double
        var estimatedDelivery: Date?
        var limitedQuantity: Int?
        var backerCount: Int
        var items: [RewardItem]
        var shippingRequired: Bool

        struct RewardItem {
            let name: String
            let description: String
            let type: ItemType

            enum ItemType {
                case digital, physical, experience, access
            }
        }

        var isAvailable: Bool {
            guard let limit = limitedQuantity else { return true }
            return backerCount < limit
        }

        var remainingQuantity: Int {
            guard let limit = limitedQuantity else { return Int.max }
            return max(0, limit - backerCount)
        }
    }

    // MARK: - Stretch Goal

    struct StretchGoal: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var targetAmount: Double
        var unlocked: Bool
        var reward: String  // What backers get when unlocked

        func checkUnlock(currentFunding: Double) -> Bool {
            currentFunding >= targetAmount
        }
    }

    // MARK: - Campaign Update

    struct CampaignUpdate: Identifiable {
        let id = UUID()
        var title: String
        var content: String
        var postedDate: Date
        var author: String
        var images: [URL]
        var backersOnly: Bool
    }

    // MARK: - Patron Tier (Subscription-based)

    struct PatronTier: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var monthlyPrice: Double
        var benefits: [Benefit]
        var patronCount: Int
        var limitedSlots: Int?
        var isActive: Bool

        struct Benefit {
            let title: String
            let description: String
            let type: BenefitType

            enum BenefitType {
                case exclusiveContent  // Early access, BTS
                case merchandise  // Physical items
                case communityAccess  // Discord, private forum
                case votingRights  // Poll on creative decisions
                case personalizedContent  // Shoutouts, custom songs
                case meetAndGreet  // Virtual or in-person
                case earlyRelease  // Music before public
            }
        }

        var monthlyRevenue: Double {
            Double(patronCount) * monthlyPrice
        }

        var isAvailable: Bool {
            guard let limit = limitedSlots else { return true }
            return patronCount < limit
        }
    }

    // MARK: - Backer

    struct Backer: Identifiable {
        let id = UUID()
        var name: String
        var email: String
        var pledges: [Pledge]
        var subscriptions: [Subscription]
        var totalContributed: Double
        var joinedDate: Date
        var tier: BackerTier

        enum BackerTier: String {
            case supporter = "Supporter"
            case patron = "Patron"
            case superfan = "Super Fan"
            case vip = "VIP"

            static func fromAmount(_ amount: Double) -> BackerTier {
                if amount >= 500 {
                    return .vip
                } else if amount >= 100 {
                    return .superfan
                } else if amount >= 25 {
                    return .patron
                } else {
                    return .supporter
                }
            }
        }

        struct Pledge {
            let campaignId: UUID
            let rewardId: UUID?
            let amount: Double
            let pledgeDate: Date
            let fulfilled: Bool
        }

        struct Subscription {
            let tierId: UUID
            let startDate: Date
            var endDate: Date?
            var active: Bool
            var monthlyAmount: Double
        }

        var lifetimeValue: Double {
            totalContributed
        }
    }

    // MARK: - Transaction

    struct Transaction: Identifiable {
        let id = UUID()
        var type: TransactionType
        var amount: Double
        var backer: Backer
        var campaignId: UUID?
        var tierIdx: UUID?
        var timestamp: Date
        var paymentMethod: PaymentMethod
        var status: TransactionStatus

        enum TransactionType {
            case oneTime, monthly, tip
        }

        enum PaymentMethod: String {
            case creditCard = "Credit Card"
            case paypal = "PayPal"
            case applePay = "Apple Pay"
            case crypto = "Cryptocurrency"
        }

        enum TransactionStatus {
            case pending, completed, failed, refunded
        }
    }

    // MARK: - Tip Jar

    struct TipJar {
        var totalTips: Double
        var tipCount: Int
        var topTipper: Backer?
        var recentTips: [Tip]

        struct Tip: Identifiable {
            let id = UUID()
            var amount: Double
            var tipper: Backer
            var message: String?
            var timestamp: Date
            var isAnonymous: Bool
        }

        var averageTip: Double {
            guard tipCount > 0 else { return 0.0 }
            return totalTips / Double(tipCount)
        }
    }

    private var tipJar = TipJar(totalTips: 0, tipCount: 0, recentTips: [])

    // MARK: - Initialization

    init() {
        print("💰 Crowdfunding Engine initialized")

        // Load default patron tiers
        loadDefaultPatronTiers()

        print("   ✅ \(patronTiers.count) patron tiers available")
    }

    private func loadDefaultPatronTiers() {
        patronTiers = [
            PatronTier(
                name: "Supporter",
                description: "Help support my music journey!",
                monthlyPrice: 5.00,
                benefits: [
                    PatronTier.Benefit(
                        title: "Exclusive Updates",
                        description: "Monthly behind-the-scenes updates",
                        type: .exclusiveContent
                    ),
                    PatronTier.Benefit(
                        title: "Discord Access",
                        description: "Join the private Discord community",
                        type: .communityAccess
                    ),
                ],
                patronCount: 0,
                isActive: true
            ),
            PatronTier(
                name: "Super Fan",
                description: "Get early access to everything!",
                monthlyPrice: 15.00,
                benefits: [
                    PatronTier.Benefit(
                        title: "All Supporter Benefits",
                        description: "Everything from the Supporter tier",
                        type: .exclusiveContent
                    ),
                    PatronTier.Benefit(
                        title: "Early Music Access",
                        description: "Hear new music 1 week before release",
                        type: .earlyRelease
                    ),
                    PatronTier.Benefit(
                        title: "Voting Rights",
                        description: "Vote on setlists, merch designs, etc.",
                        type: .votingRights
                    ),
                ],
                patronCount: 0,
                isActive: true
            ),
            PatronTier(
                name: "VIP",
                description: "Ultimate supporter with exclusive perks!",
                monthlyPrice: 50.00,
                benefits: [
                    PatronTier.Benefit(
                        title: "All Super Fan Benefits",
                        description: "Everything from lower tiers",
                        type: .exclusiveContent
                    ),
                    PatronTier.Benefit(
                        title: "Monthly Video Call",
                        description: "Join monthly group video hangout",
                        type: .meetAndGreet
                    ),
                    PatronTier.Benefit(
                        title: "Personalized Shoutout",
                        description: "Monthly shoutout in videos/social",
                        type: .personalizedContent
                    ),
                    PatronTier.Benefit(
                        title: "Physical Merch",
                        description: "Exclusive merch item every quarter",
                        type: .merchandise
                    ),
                ],
                patronCount: 0,
                limitedSlots: 20,
                isActive: true
            ),
        ]
    }

    // MARK: - Campaign Management

    func createCampaign(
        title: String,
        description: String,
        type: Campaign.CampaignType,
        fundingGoal: Double,
        durationDays: Int,
        platform: Campaign.Platform
    ) -> Campaign {
        print("🚀 Creating campaign: \(title)")

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate

        let campaign = Campaign(
            title: title,
            description: description,
            type: type,
            fundingGoal: fundingGoal,
            currentFunding: 0,
            startDate: startDate,
            endDate: endDate,
            rewards: [],
            stretchGoals: [],
            updates: [],
            status: .draft,
            platform: platform
        )

        campaigns.append(campaign)

        print("   ✅ Campaign created on \(platform.rawValue)")
        print("   🎯 Goal: $\(String(format: "%.2f", fundingGoal))")
        print("   📅 Duration: \(durationDays) days")

        return campaign
    }

    func addReward(
        campaignId: UUID,
        title: String,
        description: String,
        pledgeAmount: Double,
        items: [Reward.RewardItem],
        limitedQuantity: Int? = nil,
        estimatedDelivery: Date? = nil
    ) {
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        print("🎁 Adding reward: \(title) ($\(pledgeAmount))")

        let reward = Reward(
            title: title,
            description: description,
            pledgeAmount: pledgeAmount,
            estimatedDelivery: estimatedDelivery,
            limitedQuantity: limitedQuantity,
            backerCount: 0,
            items: items,
            shippingRequired: items.contains { $0.type == .physical }
        )

        campaigns[campaignIndex].rewards.append(reward)

        print("   ✅ Reward added")
        if let limit = limitedQuantity {
            print("   📦 Limited: \(limit) available")
        }
    }

    func addStretchGoal(
        campaignId: UUID,
        title: String,
        description: String,
        targetAmount: Double,
        reward: String
    ) {
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        print("🎯 Adding stretch goal: \(title) ($\(targetAmount))")

        let stretchGoal = StretchGoal(
            title: title,
            description: description,
            targetAmount: targetAmount,
            unlocked: false,
            reward: reward
        )

        campaigns[campaignIndex].stretchGoals.append(stretchGoal)

        print("   ✅ Stretch goal added")
    }

    func launchCampaign(campaignId: UUID) {
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        print("🚀 Launching campaign: \(campaigns[campaignIndex].title)")

        campaigns[campaignIndex].status = .live
        campaigns[campaignIndex].startDate = Date()

        print("   ✅ Campaign is now LIVE!")
        print("   📢 Start promoting on social media")
    }

    // MARK: - Backing & Pledges

    func backCampaign(
        campaignId: UUID,
        backer: Backer,
        rewardId: UUID?,
        amount: Double
    ) async -> Bool {
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return false
        }

        print("💰 Processing pledge of $\(amount) from \(backer.name)...")

        // Find reward if specified
        var rewardIndex: Int?
        if let rwdId = rewardId,
           let idx = campaigns[campaignIndex].rewards.firstIndex(where: { $0.id == rwdId }) {
            // Check availability
            if !campaigns[campaignIndex].rewards[idx].isAvailable {
                print("   ❌ Reward sold out")
                return false
            }
            rewardIndex = idx
        }

        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Record transaction
        let transaction = Transaction(
            type: .oneTime,
            amount: amount,
            backer: backer,
            campaignId: campaignId,
            timestamp: Date(),
            paymentMethod: .creditCard,
            status: .completed
        )
        transactions.append(transaction)

        // Update campaign
        campaigns[campaignIndex].currentFunding += amount

        // Update reward backer count
        if let idx = rewardIndex {
            campaigns[campaignIndex].rewards[idx].backerCount += 1
        }

        // Check stretch goals
        checkStretchGoals(campaignIndex: campaignIndex)

        print("   ✅ Pledge successful!")
        print("   📊 Campaign: $\(String(format: "%.0f", campaigns[campaignIndex].currentFunding)) / $\(String(format: "%.0f", campaigns[campaignIndex].fundingGoal)) (\(String(format: "%.1f", campaigns[campaignIndex].fundingPercentage))%)")

        // Check if funded
        if campaigns[campaignIndex].isFunded && campaigns[campaignIndex].status == .live {
            print("   🎉 CAMPAIGN FUNDED!")
            campaigns[campaignIndex].status = .funded
        }

        return true
    }

    private func checkStretchGoals(campaignIndex: Int) {
        let currentFunding = campaigns[campaignIndex].currentFunding

        for (index, goal) in campaigns[campaignIndex].stretchGoals.enumerated() {
            if !goal.unlocked && goal.checkUnlock(currentFunding: currentFunding) {
                campaigns[campaignIndex].stretchGoals[index].unlocked = true
                print("   🌟 STRETCH GOAL UNLOCKED: \(goal.title)!")
            }
        }
    }

    // MARK: - Patron Subscriptions

    func subscribeToTier(
        tier: PatronTier,
        backer: Backer
    ) async -> Bool {
        guard let tierIndex = patronTiers.firstIndex(where: { $0.id == tier.id }) else {
            return false
        }

        print("💳 Subscribing \(backer.name) to \(tier.name) tier...")

        // Check availability
        if !patronTiers[tierIndex].isAvailable {
            print("   ❌ Tier full")
            return false
        }

        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // Record transaction
        let transaction = Transaction(
            type: .monthly,
            amount: tier.monthlyPrice,
            backer: backer,
            tierIdx: tier.id,
            timestamp: Date(),
            paymentMethod: .creditCard,
            status: .completed
        )
        transactions.append(transaction)

        // Update tier
        patronTiers[tierIndex].patronCount += 1

        print("   ✅ Subscription active!")
        print("   💰 Monthly: $\(String(format: "%.2f", tier.monthlyPrice))")
        print("   🎁 \(tier.benefits.count) benefits unlocked")

        return true
    }

    func cancelSubscription(backerId: UUID, tierId: UUID) {
        guard let tierIndex = patronTiers.firstIndex(where: { $0.id == tierId }) else {
            return
        }

        print("❌ Cancelling subscription...")

        patronTiers[tierIndex].patronCount -= 1

        print("   ✅ Subscription cancelled")
    }

    // MARK: - Tip Jar

    func sendTip(
        amount: Double,
        tipper: Backer,
        message: String? = nil,
        isAnonymous: Bool = false
    ) async -> Bool {
        print("☕ Processing tip of $\(amount)...")

        // Simulate payment
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let tip = TipJar.Tip(
            amount: amount,
            tipper: tipper,
            message: message,
            timestamp: Date(),
            isAnonymous: isAnonymous
        )

        tipJar.recentTips.insert(tip, at: 0)
        if tipJar.recentTips.count > 100 {
            tipJar.recentTips.removeLast()
        }

        tipJar.totalTips += amount
        tipJar.tipCount += 1

        // Update top tipper
        if tipJar.topTipper == nil || tipper.totalContributed > (tipJar.topTipper?.totalContributed ?? 0) {
            tipJar.topTipper = tipper
        }

        // Record transaction
        let transaction = Transaction(
            type: .tip,
            amount: amount,
            backer: tipper,
            timestamp: Date(),
            paymentMethod: .creditCard,
            status: .completed
        )
        transactions.append(transaction)

        print("   ✅ Tip received!")
        if let msg = message {
            print("   💬 \"\(msg)\"")
        }

        return true
    }

    // MARK: - Campaign Updates

    func postUpdate(
        campaignId: UUID,
        title: String,
        content: String,
        author: String,
        backersOnly: Bool = false
    ) {
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        print("📢 Posting campaign update: \(title)")

        let update = CampaignUpdate(
            title: title,
            content: content,
            postedDate: Date(),
            author: author,
            images: [],
            backersOnly: backersOnly
        )

        campaigns[campaignIndex].updates.append(update)

        print("   ✅ Update posted")
        if backersOnly {
            print("   🔒 Visible to backers only")
        }
    }

    // MARK: - Analytics

    func generateCampaignReport(campaignId: UUID) -> CampaignReport {
        guard let campaign = campaigns.first(where: { $0.id == campaignId }) else {
            fatalError("Campaign not found")
        }

        print("📊 Generating campaign report...")

        let platformFees = calculatePlatformFees(campaign: campaign)
        let netFunding = campaign.currentFunding - platformFees

        let dailyAverage = campaign.currentFunding / Double(max(1, -campaign.startDate.timeIntervalSinceNow / 86400))

        let projectedFinal: Double
        if campaign.isActive {
            let daysLeft = Double(campaign.daysRemaining)
            projectedFinal = campaign.currentFunding + (dailyAverage * daysLeft)
        } else {
            projectedFinal = campaign.currentFunding
        }

        let report = CampaignReport(
            campaign: campaign,
            backerCount: campaign.backerCount,
            averagePledge: campaign.backerCount > 0 ? campaign.currentFunding / Double(campaign.backerCount) : 0,
            platformFees: platformFees,
            netFunding: netFunding,
            dailyAverage: dailyAverage,
            projectedFinal: projectedFinal,
            topRewards: campaign.rewards.sorted { $0.backerCount > $1.backerCount }.prefix(5).map { $0 },
            unlockedStretchGoals: campaign.stretchGoals.filter { $0.unlocked }.count
        )

        print("   ✅ Report generated")
        print("   👥 Backers: \(campaign.backerCount)")
        print("   💰 Net Funding: $\(String(format: "%.2f", netFunding))")
        print("   📈 Projected: $\(String(format: "%.0f", projectedFinal))")

        return report
    }

    struct CampaignReport {
        let campaign: Campaign
        let backerCount: Int
        let averagePledge: Double
        let platformFees: Double
        let netFunding: Double
        let dailyAverage: Double
        let projectedFinal: Double
        let topRewards: [Reward]
        let unlockedStretchGoals: Int
    }

    private func calculatePlatformFees(campaign: Campaign) -> Double {
        let commission = campaign.currentFunding * (campaign.platform.commissionRate / 100.0)
        let processing = campaign.currentFunding * (campaign.platform.paymentProcessingFee / 100.0)
        return commission + processing
    }

    func generateRevenueReport() -> RevenueReport {
        print("📊 Generating revenue report...")

        let totalCampaignFunding = campaigns.reduce(0) { $0 + $1.currentFunding }
        let totalPatronRevenue = patronTiers.reduce(0) { $0 + $1.monthlyRevenue }
        let totalTips = tipJar.totalTips

        let totalRevenue = totalCampaignFunding + totalTips
        let monthlyRecurring = totalPatronRevenue

        let report = RevenueReport(
            totalCampaignFunding: totalCampaignFunding,
            totalPatronRevenue: totalPatronRevenue,
            totalTips: totalTips,
            totalRevenue: totalRevenue,
            monthlyRecurringRevenue: monthlyRecurring,
            activeCampaigns: campaigns.filter { $0.isActive }.count,
            activePatrons: patronTiers.reduce(0) { $0 + $1.patronCount },
            totalBackers: Set(transactions.map { $0.backer.id }).count
        )

        print("   ✅ Revenue report generated")
        print("   💰 Total Revenue: $\(String(format: "%.2f", totalRevenue))")
        print("   📅 Monthly Recurring: $\(String(format: "%.2f", monthlyRecurring))")
        print("   👥 Total Backers: \(report.totalBackers)")

        return report
    }

    struct RevenueReport {
        let totalCampaignFunding: Double
        let totalPatronRevenue: Double
        let totalTips: Double
        let totalRevenue: Double
        let monthlyRecurringRevenue: Double
        let activeCampaigns: Int
        let activePatrons: Int
        let totalBackers: Int
    }

    // MARK: - Pre-Orders

    func createPreOrderCampaign(
        title: String,
        description: String,
        price: Double,
        estimatedDelivery: Date,
        goal: Int  // Number of pre-orders needed
    ) -> Campaign {
        print("📦 Creating pre-order campaign: \(title)")

        let campaign = createCampaign(
            title: title,
            description: description,
            type: .album,
            fundingGoal: Double(goal) * price,
            durationDays: 30,
            platform: .direct
        )

        // Add main reward
        addReward(
            campaignId: campaign.id,
            title: "Pre-Order",
            description: "Get the album when it's released",
            pledgeAmount: price,
            items: [
                Reward.RewardItem(name: "Digital Album", description: "High-quality download", type: .digital),
            ],
            estimatedDelivery: estimatedDelivery
        )

        print("   ✅ Pre-order campaign created")
        print("   🎯 Goal: \(goal) pre-orders")

        return campaign
    }

    // MARK: - Helper Methods

    func getTotalMonthlyRevenue() -> Double {
        patronTiers.reduce(0) { $0 + $1.monthlyRevenue }
    }

    func getActiveCampaigns() -> [Campaign] {
        campaigns.filter { $0.isActive }
    }

    func getTopBackers(limit: Int = 10) -> [Backer] {
        backers.sorted { $0.totalContributed > $1.totalContributed }
            .prefix(limit)
            .map { $0 }
    }
}
