import Foundation
import Combine

/// Fair Business Model - Transparent, Ethical, No Dark Patterns
/// Principles: Honesty, user respect, sustainable pricing, no manipulation
///
/// FREE APP - ALL FEATURES INCLUDED:
/// ✓ Completely free to use
/// ✓ All features unlocked
/// ✓ No in-app purchases
/// ✓ No subscriptions
/// ✓ No ads
///
/// Anti-Dark Pattern Commitments:
/// ✓ No fake urgency ("Only 2 left!")
/// ✓ No hidden costs or surprise charges
/// ✓ No subscription traps
/// ✓ Export your data anytime for free
/// ✓ No artificial feature limitations
/// ✓ Open source core (coming soon)
@MainActor
class FairBusinessModel: ObservableObject {

    // MARK: - Published State

    /// Always true - app is completely free with all features
    @Published var isFullVersionPurchased: Bool = true

    // MARK: - App Info (Free)

    /// Echoelmusic is completely free
    struct AppInfo {
        static let price: Decimal = 0
        static let currency = "USD"
        static let displayPrice = "Free"

        static let description = """
        Completely free to use.
        All features included. No ads. No IAP.
        """

        static let features: [Feature] = [
            // Core Bio-Reactive
            Feature(name: "Bio-Reactive Audio & Visuals", included: true),
            Feature(name: "Apple Watch Integration", included: true),
            Feature(name: "All 10 Quantum Visualization Modes", included: true),
            Feature(name: "4D Spatial Audio & AFA Fields", included: true),

            // Audio & Music
            Feature(name: "Unlimited AI Art/Music Generation", included: true),
            Feature(name: "Cinematic Orchestral Film Scoring", included: true),
            Feature(name: "60+ Audio Interface Presets", included: true),
            Feature(name: "40+ MIDI Controller Mappings", included: true),
            Feature(name: "VST3/AU Plugin Integration", included: true),

            // Video & Streaming
            Feature(name: "16K Video Processing", included: true),
            Feature(name: "1000fps Light-Speed Video", included: true),
            Feature(name: "Multi-Platform Streaming", included: true),

            // Hardware
            Feature(name: "Ableton Push 3 LED Control", included: true),
            Feature(name: "DMX/Art-Net Lighting Control", included: true),

            // Collaboration
            Feature(name: "Collaboration Sessions (100 participants)", included: true),

            // Accessibility
            Feature(name: "All 20+ Accessibility Profiles", included: true),

            // Storage & Presets
            Feature(name: "iCloud Sync", included: true),
            Feature(name: "74+ Curated Engine Presets", included: true),
            Feature(name: "Unlimited Custom Presets", included: true),

            // Support & Updates
            Feature(name: "Lifetime Updates", included: true),
            Feature(name: "Priority Email Support", included: true)
        ]

        struct Feature {
            let name: String
            let included: Bool
        }
    }

    // MARK: - Access Status

    enum AccessStatus {
        case fullAccess

        var hasFullAccess: Bool {
            return true
        }
    }

    @Published var accessStatus: AccessStatus = .fullAccess

    // MARK: - Ethical Commitments

    struct EthicalCommitments {
        static let commitments: [String] = [
            "✓ Completely Free - No cost to download or use",
            "✓ All Features Included - No artificial limitations",
            "✓ No In-App Purchases - Everything is free",
            "✓ No Subscriptions - No recurring fees ever",
            "✓ No Ads - You are not the product",
            "✓ No Dark Patterns - We respect your intelligence",
            "✓ Free Data Export - Your data is yours, export anytime",
            "✓ Accessibility First - WCAG AAA compliant",
            "✓ Open Source Core - Coming 2026",
            "✓ Privacy Focused - Your data stays on your device"
        ]
    }

    // MARK: - Initialization

    init() {
        log.business("✅ Fair Business Model: Initialized")
        log.business("💰 Pricing: Free (no in-app purchases)")
        log.business("🤝 Ethical commitments loaded")
    }

    // MARK: - App Summary

    func getAppSummary() -> String {
        return """
        💰 ECHOELMUSIC - COMPLETELY FREE

        \(AppInfo.description)

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        WHAT'S INCLUDED:

        \(AppInfo.features.map { "✓ \($0.name)" }.joined(separator: "\n"))

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        🤝 ETHICAL COMMITMENTS:

        \(EthicalCommitments.commitments.joined(separator: "\n"))

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        ♿️ ACCESSIBILITY:

        Full WCAG AAA compliance.
        20+ accessibility profiles included.
        Contact: michaelterbuyken@gmail.com

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Status: ✅ All Features Unlocked
        """
    }

    // MARK: - Legacy Support

    @available(*, deprecated, message: "Use getAppSummary() instead")
    func getPricingSummary() -> String {
        return getAppSummary()
    }

    @available(*, deprecated, message: "Use getAppSummary() instead")
    func getPricingComparison() -> String {
        return getAppSummary()
    }
}
