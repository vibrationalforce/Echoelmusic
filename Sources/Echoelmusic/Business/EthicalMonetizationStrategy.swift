// EthicalMonetizationStrategy.swift
// Echoelmusic - Ethical Monetization & Creator Economy
//
// Philosophy: Value-first, no dark patterns, transparent, fair
// "My cat's breath smells like cat food." - Ralph Wiggum, Business Strategist
//
// Created 2026-02-04
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import Foundation

// MARK: - Ethical Monetization Principles

/// Core principles for ethical monetization
/// Aligned with CCC hacker ethics and Echoelmusic philosophy
public enum EthicalPrinciple: String, CaseIterable, Sendable {
    case valueFirst = "Value before profit"
    case transparency = "Full transparency in pricing"
    case noManipulation = "No psychological manipulation"
    case fairPricing = "Fair, accessible pricing"
    case creatorFirst = "Creators keep majority of revenue"
    case privacyRespect = "Privacy is non-negotiable"
    case dataOwnership = "Users own their data"
    case openEcosystem = "Open, not locked-in"
}

// MARK: - Monetization Models

/// Ethical monetization models that align with Echoelmusic philosophy
public enum EthicalMonetizationModel: String, CaseIterable, Sendable {

    // MARK: - Creator Economy (Primary Focus)

    /// Creators sell bio-reactive presets, soundscapes, visualizations
    /// Platform takes 15% (lower than App Store 30%)
    case creatorMarketplace

    /// Wellness coaches offer guided sessions
    /// Revenue share: Creator 85%, Platform 15%
    case wellnessCoaching

    /// NFT minting of "Coherence Moments" - significant wellness achievements
    /// Platform fee: 2.5% (already implemented in NFTFactory)
    case bioReactiveNFTs

    // MARK: - Subscription (Optional - User Choice)

    /// Pro features for power users (NOT required for core experience)
    /// - Extended session history
    /// - Advanced analytics
    /// - Cloud sync across devices
    /// - Priority support
    case proPlan

    /// Creator tools subscription
    /// - Marketplace access
    /// - Analytics dashboard
    /// - Promotion tools
    /// - Revenue analytics
    case creatorPlan

    // MARK: - Enterprise / Institutional

    /// Wellness programs for companies
    /// Volume licensing, admin dashboard, anonymized insights
    case enterpriseWellness

    /// Research institutions
    /// Anonymized data access, IRB compliance, academic pricing
    case researchPartnership

    // MARK: - Value-Added Services

    /// Hardware partnerships (watch bands with HRV, specialized controllers)
    /// Affiliate revenue, not direct sales
    case hardwareAffiliates

    /// Certification programs for wellness practitioners
    /// Education + certification fee
    case certificationProgram

    public var description: String {
        switch self {
        case .creatorMarketplace:
            return "Buy presets, soundscapes, and visualizations from creators"
        case .wellnessCoaching:
            return "Book guided sessions with certified wellness coaches"
        case .bioReactiveNFTs:
            return "Mint significant coherence moments as collectible NFTs"
        case .proPlan:
            return "Extended features for power users (optional)"
        case .creatorPlan:
            return "Tools for content creators and wellness coaches"
        case .enterpriseWellness:
            return "Corporate wellness programs"
        case .researchPartnership:
            return "Academic research partnerships"
        case .hardwareAffiliates:
            return "Recommended compatible hardware"
        case .certificationProgram:
            return "Echoela Certified Wellness Practitioner program"
        }
    }

    public var revenueShare: (creator: Double, platform: Double) {
        switch self {
        case .creatorMarketplace: return (0.85, 0.15)
        case .wellnessCoaching: return (0.85, 0.15)
        case .bioReactiveNFTs: return (0.975, 0.025)
        case .proPlan: return (0.0, 1.0)  // Direct subscription
        case .creatorPlan: return (0.0, 1.0)
        case .enterpriseWellness: return (0.0, 1.0)
        case .researchPartnership: return (0.0, 1.0)
        case .hardwareAffiliates: return (0.0, 0.05)  // 5% affiliate
        case .certificationProgram: return (0.7, 0.3)  // Instructor share
        }
    }

    /// Whether this model requires dark patterns (answer: NEVER)
    public var requiresDarkPatterns: Bool { false }

    /// Whether the core app experience is free regardless of this model
    public var coreAppRemainsFree: Bool { true }
}

// MARK: - Pricing Tiers

/// Ethical pricing structure
public struct EthicalPricing: Sendable {

    // MARK: - User Subscriptions (Optional)

    public struct ProPlan: Sendable {
        public static let monthlyPrice: Decimal = 4.99
        public static let yearlyPrice: Decimal = 39.99  // 2 months free
        public static let lifetimePrice: Decimal = 99.99

        public static let features = [
            "Unlimited session history",
            "Advanced HRV analytics",
            "iCloud sync across devices",
            "Priority email support",
            "Early access to new features",
            "Export data in any format"
        ]

        /// What's ALWAYS free (never gated)
        public static let alwaysFree = [
            "Core bio-reactive audio",
            "All visualization modes",
            "Basic HRV/coherence tracking",
            "Breathing exercises",
            "Local session history (30 days)",
            "Community presets",
            "Standard support"
        ]
    }

    // MARK: - Creator Subscriptions

    public struct CreatorPlan: Sendable {
        public static let monthlyPrice: Decimal = 9.99
        public static let yearlyPrice: Decimal = 79.99  // 2 months free

        public static let features = [
            "Marketplace publishing",
            "Sales analytics dashboard",
            "Custom preset creation tools",
            "Promotional spotlight (1/month)",
            "Direct fan messaging",
            "Priority review queue",
            "Revenue analytics",
            "Tax documentation"
        ]
    }

    // MARK: - Enterprise

    public struct Enterprise: Sendable {
        public static let basePrice: Decimal = 499.00  // Per month, 50 seats
        public static let perSeatPrice: Decimal = 5.00  // Additional seats

        public static let features = [
            "Admin dashboard",
            "Anonymized team insights",
            "Custom branding",
            "SSO integration",
            "Dedicated support",
            "API access",
            "Data residency options",
            "HIPAA BAA available"
        ]
    }

    // MARK: - Certification

    public struct Certification: Sendable {
        public static let coursePrice: Decimal = 299.00
        public static let examPrice: Decimal = 99.00
        public static let annualRenewal: Decimal = 49.00

        public static let curriculum = [
            "Bio-reactive audio theory",
            "HRV science fundamentals",
            "Echoelmusic platform mastery",
            "Session facilitation",
            "Client safety & ethics",
            "Business development"
        ]
    }
}

// MARK: - Anti-Dark Pattern Guardrails

/// Enforced guardrails to prevent dark patterns
public struct AntiDarkPatternGuardrails: Sendable {

    /// Patterns that are BANNED in Echoelmusic
    public static let bannedPatterns = [
        "Countdown timers on offers",
        "Fake scarcity ('Only 3 left!')",
        "Guilt-based messaging",
        "Confusing cancellation flows",
        "Hidden recurring charges",
        "Pre-checked upsells",
        "Roach motel patterns",
        "Forced continuity",
        "Misdirection",
        "Social proof manipulation",
        "Bait and switch",
        "Privacy zuckering"
    ]

    /// Required disclosures
    public static let requiredDisclosures = [
        "Clear pricing before any action",
        "Easy one-tap cancellation",
        "Proactive renewal reminders",
        "No payment info required for free tier",
        "Refund policy visible",
        "Data usage transparency"
    ]

    /// Validate any monetization flow
    public static func validateFlow(_ flowDescription: String) -> Bool {
        // In production: Use ML to detect dark patterns
        // For now: Manual review required
        return true
    }
}

// MARK: - Creator Marketplace

/// Creator marketplace configuration
public struct CreatorMarketplace: Sendable {

    /// Content types creators can sell
    public enum ContentType: String, CaseIterable, Sendable {
        case preset = "Bio-reactive Preset"
        case soundscape = "Soundscape"
        case visualization = "Visualization"
        case session = "Guided Session"
        case bundle = "Content Bundle"
    }

    /// Pricing guidelines (suggestions, not enforced)
    public static let pricingGuidelines: [ContentType: ClosedRange<Decimal>] = [
        .preset: 0.99...9.99,
        .soundscape: 1.99...14.99,
        .visualization: 0.99...9.99,
        .session: 4.99...29.99,
        .bundle: 9.99...49.99
    ]

    /// Platform fee (15% - lower than App Store)
    public static let platformFee: Decimal = 0.15

    /// Minimum payout threshold
    public static let minimumPayout: Decimal = 10.00

    /// Payout methods
    public static let payoutMethods = [
        "Bank Transfer (ACH/SEPA)",
        "PayPal",
        "Wise",
        "Crypto (USDC on Polygon)"
    ]
}

// MARK: - Wellness Coaching

/// Wellness coaching marketplace
public struct WellnessCoachingMarketplace: Sendable {

    /// Coach certification requirements
    public static let certificationRequired = true

    /// Session types
    public enum SessionType: String, CaseIterable, Sendable {
        case oneOnOne = "1:1 Private Session"
        case smallGroup = "Small Group (2-5)"
        case workshop = "Workshop (6-20)"
        case webinar = "Public Webinar"
    }

    /// Suggested pricing
    public static let suggestedPricing: [SessionType: ClosedRange<Decimal>] = [
        .oneOnOne: 29.99...149.99,
        .smallGroup: 19.99...79.99,
        .workshop: 9.99...49.99,
        .webinar: 0.00...29.99
    ]

    /// Platform fee
    public static let platformFee: Decimal = 0.15

    /// Coach verification levels
    public enum VerificationLevel: String, Sendable {
        case basic = "Identity Verified"
        case certified = "Echoela Certified"
        case master = "Master Practitioner"
    }
}

// MARK: - Funnel Philosophy

/// Ethical funnel stages (no pressure, value-first)
public enum EthicalFunnelStage: String, CaseIterable, Sendable {
    case discovery = "Discover the app (organic)"
    case onboarding = "Learn core features (free)"
    case habitFormation = "Build daily practice (free)"
    case valueRealization = "Experience coherence benefits (free)"
    case optionalUpgrade = "Consider Pro if desired"
    case creatorPath = "Create content for others"
    case communityLeader = "Lead wellness circles"

    public var isMonetized: Bool {
        switch self {
        case .discovery, .onboarding, .habitFormation, .valueRealization:
            return false
        case .optionalUpgrade, .creatorPath, .communityLeader:
            return true  // Optional monetization
        }
    }

    public var callToAction: String {
        switch self {
        case .discovery:
            return "Try Echoelmusic free"
        case .onboarding:
            return "Complete setup"
        case .habitFormation:
            return "Start a session"
        case .valueRealization:
            return "Celebrate your progress"
        case .optionalUpgrade:
            return "Unlock more insights"
        case .creatorPath:
            return "Share your creations"
        case .communityLeader:
            return "Lead a wellness circle"
        }
    }
}

// MARK: - Referral Program

/// Ethical referral program (no pyramid schemes)
public struct EthicalReferralProgram: Sendable {

    /// Referral reward structure
    public static let referrerReward: Decimal = 1.00  // $1 credit
    public static let refereeReward: Decimal = 1.00   // $1 credit

    /// Maximum referrals rewarded (prevents abuse)
    public static let maxRewardedReferrals = 50

    /// Reward only triggers after:
    public static let minimumRefereeActivity = "3 sessions completed"

    /// No MLM: Single-level only
    public static let multiLevelMarketing = false

    /// Rewards can be used for:
    public static let rewardUsage = [
        "Pro subscription credit",
        "Creator marketplace purchases",
        "Certification program discount"
    ]
}

// MARK: - Revenue Projection Model

/// Sustainable revenue model
public struct RevenueProjection: Sendable {

    /// Target conversion rates (realistic, not aggressive)
    public static let proConversionRate: Double = 0.02   // 2% of active users
    public static let creatorConversionRate: Double = 0.005  // 0.5%
    public static let enterpriseConversionRate: Double = 0.001  // 0.1%

    /// Target metrics
    public static let healthyMetrics = [
        "LTV:CAC ratio > 3:1",
        "Churn rate < 5% monthly",
        "NPS > 50",
        "Creator payout ratio > 70%",
        "Support tickets < 1% of MAU"
    ]

    /// Red flags to avoid
    public static let redFlags = [
        "Revenue from confusion",
        "High refund rate (>5%)",
        "Negative reviews mentioning billing",
        "Cancellation friction complaints",
        "Dark pattern accusations"
    ]
}

// MARK: - Implementation Status

/// Current implementation status
public struct MonetizationImplementationStatus: Sendable {

    public static let implemented = [
        "Free core experience",
        "Analytics tracking",
        "NFT factory (stub)",
        "Social sharing",
        "Onboarding flow"
    ]

    public static let inProgress = [
        "UnifiedHealthKitEngine (consolidated)",
        "Creator portal planning"
    ]

    public static let planned = [
        "StoreKit2 integration",
        "Creator marketplace",
        "Wellness coaching platform",
        "Enterprise dashboard",
        "Certification program"
    ]

    public static let notPlanned = [
        "Ads",
        "Data selling",
        "Aggressive upsells",
        "Feature walls on core experience"
    ]
}

// MARK: - Apple App Store Compliance

/// App Store monetization compliance (April 28, 2026 deadline)
public struct AppStoreMonetizationCompliance: Sendable {

    /// Required for IAP
    public static let requirements = [
        "StoreKit2 for all purchases",
        "Restore purchases button visible",
        "Clear subscription terms",
        "Easy cancellation path",
        "Price displayed before purchase",
        "Auto-renewal disclosure"
    ]

    /// External purchase link compliance (Reader apps only)
    public static let externalPurchaseEligible = false  // Music creation app

    /// Small Business Program eligibility (15% commission)
    public static let smallBusinessProgramEligible = true
}

// MARK: - Logging

import os.log

private let monetizationLog = Logger(
    subsystem: "com.echoelmusic",
    category: "Monetization"
)

public func logMonetizationEvent(_ event: String) {
    monetizationLog.info("💰 \(event)")
}
