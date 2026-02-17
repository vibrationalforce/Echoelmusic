import Foundation
import Combine

/// Fair Business Model - Transparent, Ethical, No Dark Patterns
/// Principles: Honesty, user respect, sustainable pricing, no manipulation
///
/// FREEMIUM MODEL:
/// ✓ Free to download and use (basic features)
/// ✓ Optional Pro subscription for full access
/// ✓ Individual session purchases available
/// ✓ No ads
///
/// Anti-Dark Pattern Commitments:
/// ✓ No fake urgency ("Only 2 left!")
/// ✓ No hidden costs or surprise charges
/// ✓ Clear pricing shown before purchase
/// ✓ Easy cancellation via Apple Settings
/// ✓ Export your data anytime
@MainActor
class FairBusinessModel: ObservableObject {

    // MARK: - Published State

    /// Whether the user has Pro access (subscription or lifetime)
    @Published var isFullVersionPurchased: Bool = false

    // MARK: - App Info (Freemium)

    /// Echoelmusic pricing model
    struct AppInfo {
        static let downloadPrice: Decimal = 0
        static let currency = "USD"
        static let displayPrice = "Free"

        static let description = """
        Free to download. Optional Pro upgrade.
        No ads. No data sold. No dark patterns.
        """

        static let freeFeatures: [Feature] = [
            Feature(name: "Bio-Reactive Audio (DDSP engine)", included: true),
            Feature(name: "Apple Watch Integration", included: true),
            Feature(name: "GPU-Accelerated Visuals (Metal)", included: true),
            Feature(name: "3 Curated Presets", included: true),
            Feature(name: "15-Minute Sessions", included: true),
            Feature(name: "Guided Breathing Exercises", included: true),
            Feature(name: "Accessibility Profiles", included: true),
        ]

        static let proFeatures: [Feature] = [
            Feature(name: "Unlimited Session Length", included: true),
            Feature(name: "All 6 Synth Engines", included: true),
            Feature(name: "All Presets + Hilbert Visualization", included: true),
            Feature(name: "CloudKit Sync", included: true),
            Feature(name: "WAV/MIDI Export", included: true),
            Feature(name: "DMX/Art-Net Lighting Control", included: true),
            Feature(name: "AUv3 Audio Unit Plugins", included: true),
            Feature(name: "Spatial Audio with Head Tracking", included: true),
        ]

        struct Feature {
            let name: String
            let included: Bool
        }
    }

    // MARK: - Access Status

    enum AccessStatus {
        case free
        case session
        case pro

        var hasFullAccess: Bool {
            return self == .pro
        }
    }

    @Published var accessStatus: AccessStatus = .free

    // MARK: - Ethical Commitments

    struct EthicalCommitments {
        static let commitments: [String] = [
            "Free to download — no paywall to try it",
            "No ads — ever",
            "No data sold to third parties",
            "No dark patterns — no fake urgency, no hidden costs",
            "Clear pricing before any purchase",
            "Easy cancellation via Apple Settings",
            "Your creations belong to you",
            "Privacy by design — biometric data stays on device",
        ]
    }

    // MARK: - Initialization

    init() {
        log.business("Fair Business Model: Initialized")
        log.business("Pricing: Freemium (free + Pro subscription)")
    }

    // MARK: - App Summary

    func getAppSummary() -> String {
        return """
        ECHOELMUSIC — FREE TO START

        \(AppInfo.description)

        FREE TIER:
        \(AppInfo.freeFeatures.map { "• \($0.name)" }.joined(separator: "\n"))

        PRO (subscription or lifetime):
        \(AppInfo.proFeatures.map { "• \($0.name)" }.joined(separator: "\n"))

        Pro Monthly: $9.99/month (7-day free trial)
        Pro Yearly: $79.99/year (save 33%)
        Pro Lifetime: $149.99 one-time

        ETHICAL COMMITMENTS:
        \(EthicalCommitments.commitments.map { "• \($0)" }.joined(separator: "\n"))
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
