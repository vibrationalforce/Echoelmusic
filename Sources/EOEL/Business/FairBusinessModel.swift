import Foundation
import StoreKit
import Combine

/// Fair Business Model - Transparent, Ethical, No Dark Patterns
/// Principles: Honesty, user respect, sustainable pricing, no manipulation
///
/// Anti-Dark Pattern Commitments:
/// ✓ No fake urgency ("Only 2 left!")
/// ✓ No hidden costs or surprise charges
/// ✓ Easy cancellation (no retention tactics)
/// ✓ Clear feature comparison
/// ✓ No subscription traps
/// ✓ Export your data anytime for free
/// ✓ No artificial feature limitations
/// ✓ Lifetime purchase option available
/// ✓ Student & accessibility discounts
/// ✓ Open source core (coming soon)
@MainActor
class FairBusinessModel: ObservableObject {

    // MARK: - Published State

    @Published var currentTier: PricingTier = .free
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var lifetimePurchased: Bool = false

    // MARK: - Pricing Tiers

    enum PricingTier: String, CaseIterable {
        case free = "Free"
        case creator = "Creator"
        case professional = "Professional"
        case lifetime = "Lifetime"

        var displayName: String {
            return rawValue
        }

        var monthlyPrice: Decimal {
            switch self {
            case .free: return 0.00
            case .creator: return 4.99
            case .professional: return 9.99
            case .lifetime: return 79.99  // One-time
            }
        }

        var annualPrice: Decimal {
            switch self {
            case .free: return 0.00
            case .creator: return 49.99  // 2 months free
            case .professional: return 99.99  // 2 months free
            case .lifetime: return 79.99  // One-time
            }
        }

        var description: String {
            switch self {
            case .free:
                return "Full bio-reactive experience. No time limits. No ads. Forever free."
            case .creator:
                return "Advanced features for creative professionals. Cloud sync, export, collaboration."
            case .professional:
                return "Everything in Creator + pro tools. Unlimited cloud storage, AI composer, priority support."
            case .lifetime:
                return "Pay once, own forever. All current and future features. No subscriptions."
            }
        }

        var features: [Feature] {
            switch self {
            case .free:
                return [
                    Feature(name: "Bio-Reactive Audio & Visuals", included: true),
                    Feature(name: "HRV Training Protocols", included: true),
                    Feature(name: "6 Quick-Start Presets", included: true),
                    Feature(name: "Local Storage (5 GB)", included: true),
                    Feature(name: "Export Sessions (JSON)", included: true),
                    Feature(name: "Basic Spatial Audio", included: true),
                    Feature(name: "No Time Limits", included: true),
                    Feature(name: "No Ads", included: true),
                    Feature(name: "Cloud Sync", included: false),
                    Feature(name: "Advanced Export (4K Video)", included: false),
                    Feature(name: "AI Music Composer", included: false),
                    Feature(name: "Collaboration (Multiplayer)", included: false),
                    Feature(name: "Priority Support", included: false)
                ]

            case .creator:
                return [
                    Feature(name: "Everything in Free", included: true),
                    Feature(name: "Cloud Sync (2 GB)", included: true),
                    Feature(name: "Advanced Export (4K Video, ProRes)", included: true),
                    Feature(name: "Collaboration (Up to 4 people)", included: true),
                    Feature(name: "Streaming Integration", included: true),
                    Feature(name: "Custom Presets Library", included: true),
                    Feature(name: "Email Support", included: true),
                    Feature(name: "AI Music Composer", included: false),
                    Feature(name: "Unlimited Cloud Storage", included: false),
                    Feature(name: "Priority Support", included: false)
                ]

            case .professional:
                return [
                    Feature(name: "Everything in Creator", included: true),
                    Feature(name: "AI Music Composer", included: true),
                    Feature(name: "Unlimited Cloud Storage", included: true),
                    Feature(name: "Collaboration (Unlimited)", included: true),
                    Feature(name: "Advanced Scripting Engine", included: true),
                    Feature(name: "Custom Integrations API", included: true),
                    Feature(name: "Priority Support (24h response)", included: true),
                    Feature(name: "Early Access to Features", included: true),
                    Feature(name: "Commercial Use License", included: true)
                ]

            case .lifetime:
                return [
                    Feature(name: "Everything in Professional", included: true),
                    Feature(name: "All Current Features", included: true),
                    Feature(name: "All Future Features", included: true),
                    Feature(name: "Lifetime Updates", included: true),
                    Feature(name: "No Recurring Payments", included: true),
                    Feature(name: "Priority Support Forever", included: true),
                    Feature(name: "Transferable License", included: true),
                    Feature(name: "Early Beta Access", included: true)
                ]
            }
        }

        struct Feature {
            let name: String
            let included: Bool
        }
    }

    // MARK: - Subscription Status

    enum SubscriptionStatus {
        case notSubscribed
        case active(tier: PricingTier, renewalDate: Date)
        case cancelled(expiresOn: Date)
        case expired
        case lifetime

        var isActive: Bool {
            switch self {
            case .active, .lifetime: return true
            case .cancelled(let expiresOn): return Date() < expiresOn
            case .notSubscribed, .expired: return false
            }
        }
    }

    // MARK: - Discounts

    enum Discount: String {
        case student = "Student (50% off)"
        case accessibility = "Accessibility (Free Professional)"
        case nonprofit = "Non-Profit (40% off)"
        case educator = "Educator (60% off)"

        var discountPercentage: Decimal {
            switch self {
            case .student: return 0.50
            case .accessibility: return 1.00  // 100% off = free
            case .nonprofit: return 0.40
            case .educator: return 0.60
            }
        }

        var verificationRequired: Bool {
            return true  // All discounts require verification
        }

        var description: String {
            switch self {
            case .student:
                return "50% off for students. Verify with your .edu email or student ID."
            case .accessibility:
                return "Free Professional tier for users with disabilities. No questions asked."
            case .nonprofit:
                return "40% off for registered non-profit organizations."
            case .educator:
                return "60% off for teachers and educators. Bring creativity to your classroom."
            }
        }
    }

    // MARK: - Trial Period

    struct TrialInfo {
        let tier: PricingTier
        let durationDays: Int
        let startDate: Date
        let endDate: Date
        let features: [PricingTier.Feature]

        var daysRemaining: Int {
            let remaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
            return max(0, remaining)
        }

        var isActive: Bool {
            return Date() < endDate
        }
    }

    @Published var activeTrial: TrialInfo?

    // MARK: - Ethical Commitments

    struct EthicalCommitments {
        static let commitments: [String] = [
            "✓ No Dark Patterns - We respect your intelligence",
            "✓ No Hidden Costs - Price you see is price you pay",
            "✓ Easy Cancellation - Cancel anytime, no retention tactics",
            "✓ No Subscription Traps - Clear renewal dates, proactive reminders",
            "✓ Free Data Export - Your data is yours, export anytime for free",
            "✓ No Artificial Limits - Free tier is genuinely useful, not crippled",
            "✓ Student Discounts - 50% off for students",
            "✓ Accessibility Commitment - Free Professional for users with disabilities",
            "✓ Transparent Pricing - No psychological pricing tricks",
            "✓ Open Source Core - Core features will be open sourced (coming 2026)",
            "✓ Sustainable Business - Fair pricing for long-term viability",
            "✓ No Ads, Ever - You're the customer, not the product"
        ]
    }

    // MARK: - Initialization

    init() {
        loadSubscriptionStatus()
        print("✅ Fair Business Model: Initialized")
        print("💰 Current Tier: \(currentTier.rawValue)")
        print("🤝 Ethical commitments loaded")
    }

    // MARK: - Load Subscription Status

    private func loadSubscriptionStatus() {
        // Load from local storage
        lifetimePurchased = UserDefaults.standard.bool(forKey: "lifetimePurchased")

        if lifetimePurchased {
            currentTier = .lifetime
            subscriptionStatus = .lifetime
            return
        }

        // Check StoreKit for active subscriptions
        // In production, use StoreKit 2 async APIs
        currentTier = .free
        subscriptionStatus = .notSubscribed
    }

    // MARK: - Start Free Trial

    func startFreeTrial(tier: PricingTier) {
        guard tier != .free && tier != .lifetime else { return }
        guard activeTrial == nil else {
            print("⚠️ Trial already active")
            return
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!

        activeTrial = TrialInfo(
            tier: tier,
            durationDays: 14,
            startDate: startDate,
            endDate: endDate,
            features: tier.features
        )

        currentTier = tier

        print("🎉 Free trial started: \(tier.rawValue)")
        print("📅 Trial ends: \(endDate.formatted(date: .long, time: .omitted))")
        print("💡 No credit card required. No auto-renewal.")
    }

    // MARK: - Purchase Subscription

    func purchaseSubscription(tier: PricingTier, billingPeriod: BillingPeriod) async throws {
        guard tier != .free else { return }

        // In production, use StoreKit 2
        print("💳 Purchasing: \(tier.rawValue) (\(billingPeriod.rawValue))")

        // Simulate purchase
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        currentTier = tier

        if tier == .lifetime {
            lifetimePurchased = true
            UserDefaults.standard.set(true, forKey: "lifetimePurchased")
            subscriptionStatus = .lifetime
            print("✅ Lifetime purchase complete!")
        } else {
            let renewalDate = Calendar.current.date(
                byAdding: billingPeriod == .monthly ? .month : .year,
                value: 1,
                to: Date()
            )!
            subscriptionStatus = .active(tier: tier, renewalDate: renewalDate)
            print("✅ Subscription active until: \(renewalDate.formatted(date: .long, time: .omitted))")
        }
    }

    enum BillingPeriod: String {
        case monthly = "Monthly"
        case annual = "Annual"
    }

    // MARK: - Cancel Subscription

    func cancelSubscription() async throws {
        guard case .active(let tier, let renewalDate) = subscriptionStatus else {
            print("⚠️ No active subscription to cancel")
            return
        }

        // In production, use StoreKit 2 to cancel
        print("🚫 Cancelling subscription...")

        // No retention tactics, no "are you sure?" spam
        subscriptionStatus = .cancelled(expiresOn: renewalDate)

        print("✅ Subscription cancelled")
        print("📅 Access continues until: \(renewalDate.formatted(date: .long, time: .omitted))")
        print("💾 Your data remains accessible. Export anytime.")
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        print("🔄 Restoring purchases...")

        // In production, use StoreKit 2 to restore
        try await Task.sleep(nanoseconds: 500_000_000)

        if lifetimePurchased {
            currentTier = .lifetime
            subscriptionStatus = .lifetime
            print("✅ Lifetime purchase restored")
        } else {
            print("ℹ️ No purchases to restore")
        }
    }

    // MARK: - Apply Discount

    func applyDiscount(_ discount: Discount, verificationToken: String? = nil) -> Bool {
        // In production, verify token with backend
        guard discount.verificationRequired else { return false }

        print("🎓 Discount applied: \(discount.rawValue)")

        if discount == .accessibility {
            currentTier = .professional
            subscriptionStatus = .lifetime  // Free forever
            print("♿️ Accessibility tier activated. Free Professional forever.")
        }

        return true
    }

    // MARK: - Pricing Comparison

    func getPricingComparison() -> String {
        var comparison = """
        💰 ECHOELMUSIC PRICING - Transparent & Fair

        """

        for tier in PricingTier.allCases {
            comparison += "\n\(tier.displayName.uppercased())\n"

            if tier == .free {
                comparison += "Price: FREE (forever)\n"
            } else if tier == .lifetime {
                comparison += "Price: $\(tier.monthlyPrice) (one-time payment)\n"
            } else {
                comparison += "Price: $\(tier.monthlyPrice)/month or $\(tier.annualPrice)/year\n"
            }

            comparison += "\(tier.description)\n"
            comparison += "\nFeatures:\n"

            for feature in tier.features {
                let symbol = feature.included ? "✓" : "✗"
                comparison += "\(symbol) \(feature.name)\n"
            }

            comparison += "\n" + String(repeating: "-", count: 50) + "\n"
        }

        comparison += """

        🎓 DISCOUNTS AVAILABLE:
        • Students: 50% off
        • Educators: 60% off
        • Non-Profits: 40% off
        • Accessibility: FREE Professional tier

        🤝 ETHICAL COMMITMENTS:
        """

        for commitment in EthicalCommitments.commitments {
            comparison += "\n\(commitment)"
        }

        comparison += """


        ⏱️ FREE TRIAL:
        • 14 days, any paid tier
        • No credit card required
        • No auto-renewal
        • Full access to all features

        ❓ WHY THESE PRICES?
        • Sustainable business model
        • Fair compensation for development
        • No investor pressure for unsustainable growth
        • Long-term viability > short-term profit

        🌍 COMMITMENT TO ACCESS:
        We believe creativity and wellbeing tools should be accessible.
        That's why our free tier is genuinely useful, not a "freemium trap."
        If our paid plans are still out of reach, contact us: fairness@echoelmusic.com

        Current Tier: \(currentTier.rawValue)
        """

        return comparison
    }

    // MARK: - Cancellation Flow (No Dark Patterns)

    func getCancellationInfo() -> String {
        guard case .active(let tier, let renewalDate) = subscriptionStatus else {
            return "No active subscription"
        }

        return """
        🚫 CANCEL SUBSCRIPTION

        We're sorry to see you go! Here's what happens:

        ✓ Your subscription continues until \(renewalDate.formatted(date: .long, time: .omitted))
        ✓ You keep all features until expiration
        ✓ No partial refunds (sorry, industry standard)
        ✓ Your data remains accessible
        ✓ You can export all data for free (always)
        ✓ You can resubscribe anytime

        Why are you leaving? (Optional feedback)
        [ ] Too expensive
        [ ] Not using enough
        [ ] Missing features
        [ ] Found alternative
        [ ] Other: ____________

        Your honest feedback helps us improve!

        [Cancel My Subscription] [Keep Subscription]

        No retention tactics. No guilt trips. Your choice.
        """
    }
}
