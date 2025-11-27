//
//  SubscriptionTests.swift
//  EchoelmusicTests
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Subscription and monetization testing
//

import XCTest
import StoreKit
@testable import Echoelmusic

final class SubscriptionTests: XCTestCase {
    var subscriptionManager: SubscriptionManager!

    override func setUp() async throws {
        subscriptionManager = SubscriptionManager.shared
    }

    // MARK: - Product Loading Tests

    func testProductsLoad() async throws {
        await subscriptionManager.loadProducts()

        XCTAssertFalse(subscriptionManager.availableProducts.isEmpty,
                      "Products should be loaded from StoreKit")
    }

    func testAllProductIDsAvailable() async throws {
        await subscriptionManager.loadProducts()

        let expectedProductIDs = SubscriptionManager.ProductIdentifier.allCases.map { $0.rawValue }
        let loadedProductIDs = subscriptionManager.availableProducts.map { $0.id }

        for expectedID in expectedProductIDs {
            XCTAssertTrue(loadedProductIDs.contains(expectedID),
                         "Product \(expectedID) should be available")
        }
    }

    func testProductsSortedByPrice() async throws {
        await subscriptionManager.loadProducts()

        let prices = subscriptionManager.availableProducts.map { $0.price }

        // Verify sorted
        for i in 0..<(prices.count - 1) {
            XCTAssertLessThanOrEqual(prices[i], prices[i + 1],
                                    "Products should be sorted by price")
        }
    }

    // MARK: - Subscription Status Tests

    func testDefaultStatusIsFree() {
        XCTAssertEqual(subscriptionManager.subscriptionStatus, .free)
        XCTAssertEqual(subscriptionManager.subscriptionStatus.tier, .free)
        XCTAssertFalse(subscriptionManager.subscriptionStatus.isActive)
    }

    func testProStatusIsActive() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 3600) // 30 days
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertEqual(subscriptionManager.subscriptionStatus.tier, .pro)
        XCTAssertTrue(subscriptionManager.subscriptionStatus.isActive)
    }

    func testPremiumStatusIsActive() {
        let expiryDate = Date().addingTimeInterval(365 * 24 * 3600) // 1 year
        subscriptionManager.subscriptionStatus = .premium(expiryDate: expiryDate)

        XCTAssertEqual(subscriptionManager.subscriptionStatus.tier, .premium)
        XCTAssertTrue(subscriptionManager.subscriptionStatus.isActive)
    }

    func testExpiredStatusIsNotActive() {
        let expiryDate = Date().addingTimeInterval(-1) // Past date
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertFalse(subscriptionManager.subscriptionStatus.isActive)
    }

    // MARK: - Feature Access Tests

    func testFreeUserHasBasicAccess() {
        subscriptionManager.subscriptionStatus = .free

        XCTAssertTrue(subscriptionManager.hasAccess(to: .basicInstruments))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .basicEffects))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .basicRecording))

        XCTAssertFalse(subscriptionManager.hasAccess(to: .allInstruments))
        XCTAssertFalse(subscriptionManager.hasAccess(to: .allEffects))
        XCTAssertFalse(subscriptionManager.hasAccess(to: .cloudSync))
        XCTAssertFalse(subscriptionManager.hasAccess(to: .eoelWork))
    }

    func testProUserHasProAccess() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertTrue(subscriptionManager.hasAccess(to: .basicInstruments))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .allInstruments))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .allEffects))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .unlimitedRecordings))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .cloudSync))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .prioritySupport))

        // But not premium features
        XCTAssertFalse(subscriptionManager.hasAccess(to: .eoelWork))
        XCTAssertFalse(subscriptionManager.hasAccess(to: .advancedAnalytics))
    }

    func testPremiumUserHasAllAccess() {
        let expiryDate = Date().addingTimeInterval(365 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .premium(expiryDate: expiryDate)

        // Should have access to everything
        XCTAssertTrue(subscriptionManager.hasAccess(to: .basicInstruments))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .allInstruments))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .allEffects))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .unlimitedRecordings))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .cloudSync))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .prioritySupport))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .eoelWork))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .advancedAnalytics))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .customBranding))
        XCTAssertTrue(subscriptionManager.hasAccess(to: .apiAccess))
    }

    // MARK: - Usage Limits Tests

    func testFreeUserRecordingLimit() {
        subscriptionManager.subscriptionStatus = .free

        XCTAssertTrue(subscriptionManager.canCreateRecording(currentCount: 0))
        XCTAssertTrue(subscriptionManager.canCreateRecording(currentCount: 4))
        XCTAssertFalse(subscriptionManager.canCreateRecording(currentCount: 5))
        XCTAssertFalse(subscriptionManager.canCreateRecording(currentCount: 10))
    }

    func testProUserUnlimitedRecordings() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertTrue(subscriptionManager.canCreateRecording(currentCount: 0))
        XCTAssertTrue(subscriptionManager.canCreateRecording(currentCount: 100))
        XCTAssertTrue(subscriptionManager.canCreateRecording(currentCount: 1000))
    }

    func testFreeUserInstrumentLimit() {
        subscriptionManager.subscriptionStatus = .free

        XCTAssertTrue(subscriptionManager.canUseInstrument(index: 0))
        XCTAssertTrue(subscriptionManager.canUseInstrument(index: 2))
        XCTAssertFalse(subscriptionManager.canUseInstrument(index: 3))
        XCTAssertFalse(subscriptionManager.canUseInstrument(index: 10))
    }

    func testProUserAllInstruments() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertTrue(subscriptionManager.canUseInstrument(index: 0))
        XCTAssertTrue(subscriptionManager.canUseInstrument(index: 10))
        XCTAssertTrue(subscriptionManager.canUseInstrument(index: 46))
    }

    func testFreeUserEffectLimit() {
        subscriptionManager.subscriptionStatus = .free

        XCTAssertTrue(subscriptionManager.canUseEffect(index: 0))
        XCTAssertTrue(subscriptionManager.canUseEffect(index: 9))
        XCTAssertFalse(subscriptionManager.canUseEffect(index: 10))
        XCTAssertFalse(subscriptionManager.canUseEffect(index: 20))
    }

    func testProUserAllEffects() {
        let expiryDate = Date().addingTimeInterval(30 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .pro(expiryDate: expiryDate)

        XCTAssertTrue(subscriptionManager.canUseEffect(index: 0))
        XCTAssertTrue(subscriptionManager.canUseEffect(index: 20))
        XCTAssertTrue(subscriptionManager.canUseEffect(index: 76))
    }

    // MARK: - Product Identifier Tests

    func testProductIdentifierTiers() {
        XCTAssertEqual(SubscriptionManager.ProductIdentifier.proMonthly.tier, .pro)
        XCTAssertEqual(SubscriptionManager.ProductIdentifier.proYearly.tier, .pro)
        XCTAssertEqual(SubscriptionManager.ProductIdentifier.premiumMonthly.tier, .premium)
        XCTAssertEqual(SubscriptionManager.ProductIdentifier.premiumYearly.tier, .premium)
    }

    func testProductIdentifierPeriods() {
        XCTAssertFalse(SubscriptionManager.ProductIdentifier.proMonthly.isYearly)
        XCTAssertTrue(SubscriptionManager.ProductIdentifier.proYearly.isYearly)
        XCTAssertFalse(SubscriptionManager.ProductIdentifier.premiumMonthly.isYearly)
        XCTAssertTrue(SubscriptionManager.ProductIdentifier.premiumYearly.isYearly)
    }

    // MARK: - Pricing Tests

    func testSavingsPercentageCalculation() async throws {
        await subscriptionManager.loadProducts()

        guard let proMonthly = subscriptionManager.product(for: .proMonthly),
              let proYearly = subscriptionManager.product(for: .proYearly) else {
            XCTFail("Products not loaded")
            return
        }

        let savings = subscriptionManager.savingsPercentage(monthly: proMonthly, yearly: proYearly)

        XCTAssertNotNil(savings)
        if let savings = savings {
            XCTAssertGreaterThan(savings, 0, "Yearly plan should have savings")
            XCTAssertLessThanOrEqual(savings, 100, "Savings can't exceed 100%")
        }
    }

    // MARK: - Analytics Tests

    func testAnalyticsEventTracking() {
        // Verify analytics events are properly configured
        let events: [SubscriptionManager.SubscriptionEvent] = [
            .paywall_viewed,
            .purchase_initiated,
            .purchase_completed,
            .purchase_failed,
            .purchase_cancelled,
            .subscription_renewed,
            .subscription_expired,
            .subscription_restored,
            .manage_subscription_tapped
        ]

        for event in events {
            XCTAssertFalse(event.rawValue.isEmpty, "Event \(event) should have raw value")
        }
    }

    // MARK: - Tier Features Tests

    func testFreeTierFeatures() {
        let features = SubscriptionManager.SubscriptionTier.free.features

        XCTAssertTrue(features.contains("3 instruments"))
        XCTAssertTrue(features.contains("10 effects"))
        XCTAssertTrue(features.contains("Basic features"))
        XCTAssertTrue(features.contains("Max 5 recordings"))
    }

    func testProTierFeatures() {
        let features = SubscriptionManager.SubscriptionTier.pro.features

        XCTAssertTrue(features.contains("All 47 instruments"))
        XCTAssertTrue(features.contains("All 77 effects"))
        XCTAssertTrue(features.contains("Unlimited recordings"))
        XCTAssertTrue(features.contains("Cloud sync"))
        XCTAssertTrue(features.contains("Priority support"))
    }

    func testPremiumTierFeatures() {
        let features = SubscriptionManager.SubscriptionTier.premium.features

        XCTAssertTrue(features.contains("Everything in Pro"))
        XCTAssertTrue(features.contains("EoelWork gig platform"))
        XCTAssertTrue(features.contains("Advanced analytics"))
        XCTAssertTrue(features.contains("Custom branding"))
        XCTAssertTrue(features.contains("API access"))
    }

    // MARK: - Subscription Expiry Tests

    func testExpiryDateRetrieval() {
        let futureDate = Date().addingTimeInterval(30 * 24 * 3600)
        subscriptionManager.subscriptionStatus = .pro(expiryDate: futureDate)

        XCTAssertNotNil(subscriptionManager.subscriptionStatus.expiryDate)
        XCTAssertEqual(subscriptionManager.subscriptionStatus.expiryDate, futureDate)
    }

    func testFreeStatusHasNoExpiry() {
        subscriptionManager.subscriptionStatus = .free

        XCTAssertNil(subscriptionManager.subscriptionStatus.expiryDate)
    }

    func testExpiredStatusIdentification() {
        subscriptionManager.subscriptionStatus = .expired(tier: .pro)

        XCTAssertEqual(subscriptionManager.subscriptionStatus.tier, .free)
        XCTAssertFalse(subscriptionManager.subscriptionStatus.isActive)
    }

    // MARK: - Product Retrieval Tests

    func testProductRetrieval() async throws {
        await subscriptionManager.loadProducts()

        let proMonthly = subscriptionManager.product(for: .proMonthly)
        XCTAssertNotNil(proMonthly)
        XCTAssertEqual(proMonthly?.id, SubscriptionManager.ProductIdentifier.proMonthly.rawValue)
    }

    // MARK: - Error Handling Tests

    func testErrorMessageClearing() async {
        subscriptionManager.errorMessage = "Test error"
        XCTAssertNotNil(subscriptionManager.errorMessage)

        await subscriptionManager.loadProducts()
        // Error should be cleared when loading products successfully
        XCTAssertNil(subscriptionManager.errorMessage)
    }

    // MARK: - Loading State Tests

    func testLoadingStateManagement() async {
        XCTAssertFalse(subscriptionManager.isLoading)

        // Start loading
        let loadTask = Task {
            await subscriptionManager.loadProducts()
        }

        // Should be loading
        // (In real implementation, would need to check during async operation)

        await loadTask.value

        // Should be done loading
        XCTAssertFalse(subscriptionManager.isLoading)
    }
}
