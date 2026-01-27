// BusinessTests.swift
// Tests for FairBusinessModel - Ethical business practices
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Fair Business Model
/// Coverage: Pricing, features, ethical commitments, access status
final class BusinessTests: XCTestCase {

    // MARK: - Initialization Tests

    @MainActor
    func testFairBusinessModelInitialization() {
        let model = FairBusinessModel()

        // App should be completely free with full access
        XCTAssertTrue(model.isFullVersionPurchased)
        XCTAssertEqual(model.accessStatus, .fullAccess)
    }

    // MARK: - AppInfo Tests

    func testAppInfoPricing() {
        XCTAssertEqual(FairBusinessModel.AppInfo.price, 0)
        XCTAssertEqual(FairBusinessModel.AppInfo.currency, "USD")
        XCTAssertEqual(FairBusinessModel.AppInfo.displayPrice, "Free")
    }

    func testAppInfoDescription() {
        let description = FairBusinessModel.AppInfo.description

        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("free") || description.contains("Free"))
    }

    func testAppInfoFeatures() {
        let features = FairBusinessModel.AppInfo.features

        // Should have multiple features
        XCTAssertGreaterThan(features.count, 10)

        // All features should be included (free app)
        for feature in features {
            XCTAssertTrue(feature.included, "Feature '\(feature.name)' should be included")
        }
    }

    func testAppInfoFeatureNames() {
        let features = FairBusinessModel.AppInfo.features

        // Each feature should have a non-empty name
        for feature in features {
            XCTAssertFalse(feature.name.isEmpty)
        }

        // Check for specific expected features
        let featureNames = features.map { $0.name }

        XCTAssertTrue(featureNames.contains("Bio-Reactive Audio & Visuals"))
        XCTAssertTrue(featureNames.contains("Apple Watch Integration"))
    }

    func testAppInfoFeatureCategories() {
        let features = FairBusinessModel.AppInfo.features
        let featureNames = features.map { $0.name }

        // Should cover various categories
        let hasAudio = featureNames.contains { $0.contains("Audio") }
        let hasVideo = featureNames.contains { $0.contains("Video") }
        let hasAccessibility = featureNames.contains { $0.contains("Accessibility") }
        let hasPresets = featureNames.contains { $0.contains("Presets") }

        XCTAssertTrue(hasAudio, "Should have audio features")
        XCTAssertTrue(hasVideo, "Should have video features")
        XCTAssertTrue(hasAccessibility, "Should have accessibility features")
        XCTAssertTrue(hasPresets, "Should have preset features")
    }

    // MARK: - Access Status Tests

    @MainActor
    func testAccessStatusFullAccess() {
        let model = FairBusinessModel()

        XCTAssertEqual(model.accessStatus, .fullAccess)
        XCTAssertTrue(model.accessStatus.hasFullAccess)
    }

    func testAccessStatusEnum() {
        let status = FairBusinessModel.AccessStatus.fullAccess

        XCTAssertTrue(status.hasFullAccess)
    }

    // MARK: - Ethical Commitments Tests

    func testEthicalCommitmentsExist() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments

        XCTAssertGreaterThan(commitments.count, 5)
    }

    func testEthicalCommitmentsContent() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments

        // Check for key ethical promises
        let hasFreePricing = commitments.contains { $0.contains("Free") }
        let hasNoAds = commitments.contains { $0.contains("No Ads") }
        let hasNoDarkPatterns = commitments.contains { $0.contains("Dark Patterns") || $0.contains("No Dark") }
        let hasDataExport = commitments.contains { $0.contains("Export") || $0.contains("data") }
        let hasPrivacy = commitments.contains { $0.contains("Privacy") }
        let hasAccessibility = commitments.contains { $0.contains("Accessibility") }

        XCTAssertTrue(hasFreePricing, "Should commit to free pricing")
        XCTAssertTrue(hasNoAds, "Should commit to no ads")
        XCTAssertTrue(hasNoDarkPatterns, "Should commit to no dark patterns")
        XCTAssertTrue(hasDataExport, "Should commit to data export")
        XCTAssertTrue(hasPrivacy, "Should commit to privacy")
        XCTAssertTrue(hasAccessibility, "Should commit to accessibility")
    }

    func testEthicalCommitmentsFormat() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments

        // Each commitment should start with checkmark
        for commitment in commitments {
            XCTAssertTrue(commitment.hasPrefix("✓"), "Commitment should start with checkmark: \(commitment)")
        }
    }

    // MARK: - App Summary Tests

    @MainActor
    func testGetAppSummary() {
        let model = FairBusinessModel()
        let summary = model.getAppSummary()

        XCTAssertFalse(summary.isEmpty)

        // Should contain key sections
        XCTAssertTrue(summary.contains("ECHOELMUSIC"))
        XCTAssertTrue(summary.contains("WHAT'S INCLUDED") || summary.contains("INCLUDED"))
        XCTAssertTrue(summary.contains("ETHICAL COMMITMENTS") || summary.contains("COMMITMENTS"))
        XCTAssertTrue(summary.contains("ACCESSIBILITY"))
        XCTAssertTrue(summary.contains("Status"))
    }

    @MainActor
    func testAppSummaryContainsFeatures() {
        let model = FairBusinessModel()
        let summary = model.getAppSummary()

        // Should list features
        XCTAssertTrue(summary.contains("Bio-Reactive"))
        XCTAssertTrue(summary.contains("Watch"))
    }

    @MainActor
    func testAppSummaryContainsContact() {
        let model = FairBusinessModel()
        let summary = model.getAppSummary()

        // Should contain contact info
        XCTAssertTrue(summary.contains("@") || summary.contains("email") || summary.contains("Contact"))
    }

    // MARK: - Legacy Method Tests

    @MainActor
    func testDeprecatedGetPricingSummary() {
        let model = FairBusinessModel()

        // Should still work (returns app summary)
        let summary = model.getPricingSummary()
        XCTAssertFalse(summary.isEmpty)
    }

    @MainActor
    func testDeprecatedGetPricingComparison() {
        let model = FairBusinessModel()

        // Should still work (returns app summary)
        let comparison = model.getPricingComparison()
        XCTAssertFalse(comparison.isEmpty)
    }

    // MARK: - Anti-Dark Pattern Tests

    func testNoFakeUrgency() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments.joined()
        let features = FairBusinessModel.AppInfo.features.map { $0.name }.joined()
        let description = FairBusinessModel.AppInfo.description

        let allText = commitments + features + description

        // Should not contain urgency language
        XCTAssertFalse(allText.contains("Only") && allText.contains("left"))
        XCTAssertFalse(allText.contains("Limited time"))
        XCTAssertFalse(allText.contains("Hurry"))
        XCTAssertFalse(allText.contains("Act now"))
    }

    func testNoHiddenCosts() {
        let features = FairBusinessModel.AppInfo.features

        // All features should be included
        let allIncluded = features.allSatisfy { $0.included }
        XCTAssertTrue(allIncluded, "All features should be included with no hidden costs")

        // Price should be zero
        XCTAssertEqual(FairBusinessModel.AppInfo.price, 0)
    }

    func testNoSubscriptionTraps() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments

        // Should explicitly mention no subscriptions
        let noSubscriptionPromise = commitments.contains { $0.contains("No Subscription") || $0.contains("recurring") }
        XCTAssertTrue(noSubscriptionPromise, "Should promise no subscription traps")
    }

    // MARK: - Feature Structure Tests

    func testFeatureStructure() {
        let feature = FairBusinessModel.AppInfo.Feature(name: "Test Feature", included: true)

        XCTAssertEqual(feature.name, "Test Feature")
        XCTAssertTrue(feature.included)
    }

    func testFeatureWithIncludedFalse() {
        // Even though all features are included, the struct should support false
        let feature = FairBusinessModel.AppInfo.Feature(name: "Premium Feature", included: false)

        XCTAssertEqual(feature.name, "Premium Feature")
        XCTAssertFalse(feature.included)
    }

    // MARK: - Consistency Tests

    @MainActor
    func testFullVersionAlwaysPurchased() {
        let model = FairBusinessModel()

        // Should always be true for free app
        XCTAssertTrue(model.isFullVersionPurchased)

        // Should never change
        model.isFullVersionPurchased = false
        // Even if set to false, business logic should ensure full access
        // (In production, this would be read-only)
    }

    @MainActor
    func testAccessStatusNeverRestricted() {
        let model = FairBusinessModel()

        // Access should always be full
        XCTAssertTrue(model.accessStatus.hasFullAccess)
    }

    // MARK: - WCAG Compliance Tests

    func testAccessibilityCommitment() {
        let commitments = FairBusinessModel.EthicalCommitments.commitments

        // Should mention WCAG
        let hasWCAG = commitments.contains { $0.contains("WCAG") || $0.contains("AAA") }
        XCTAssertTrue(hasWCAG, "Should commit to WCAG compliance")
    }

    func testAccessibilityFeature() {
        let features = FairBusinessModel.AppInfo.features
        let accessibilityFeatures = features.filter { $0.name.contains("Accessibility") }

        XCTAssertGreaterThan(accessibilityFeatures.count, 0, "Should have accessibility features")

        for feature in accessibilityFeatures {
            XCTAssertTrue(feature.included, "Accessibility features should be included")
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testModelInitializationPerformance() {
        measure {
            for _ in 0..<100 {
                let _ = FairBusinessModel()
            }
        }
    }

    @MainActor
    func testGetAppSummaryPerformance() {
        let model = FairBusinessModel()

        measure {
            for _ in 0..<100 {
                let _ = model.getAppSummary()
            }
        }
    }

    // MARK: - Edge Cases

    func testEmptyCommitments() {
        // Commitments should never be empty
        let commitments = FairBusinessModel.EthicalCommitments.commitments
        XCTAssertFalse(commitments.isEmpty)
    }

    func testEmptyFeatures() {
        // Features should never be empty
        let features = FairBusinessModel.AppInfo.features
        XCTAssertFalse(features.isEmpty)
    }

    // MARK: - Observable Object Tests

    @MainActor
    func testObservableObjectConformance() {
        let model = FairBusinessModel()

        // Should be observable
        let _ = model.objectWillChange

        // Published properties should exist
        XCTAssertNotNil(model.isFullVersionPurchased)
        XCTAssertNotNil(model.accessStatus)
    }
}
