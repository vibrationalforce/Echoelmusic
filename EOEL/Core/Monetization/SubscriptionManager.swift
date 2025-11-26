//
//  SubscriptionManager.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  StoreKit 2 Subscription Management
//

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Subscription Tiers

    enum SubscriptionTier: String, CaseIterable {
        case free = "Free"
        case pro = "Pro"
        case premium = "Premium"

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .pro: return "Pro"
            case .premium: return "Premium"
            }
        }

        var features: [String] {
            switch self {
            case .free:
                return [
                    "3 instruments",
                    "10 effects",
                    "Basic features",
                    "Max 5 recordings"
                ]
            case .pro:
                return [
                    "All 47 instruments",
                    "All 77 effects",
                    "Unlimited recordings",
                    "Cloud sync",
                    "Priority support"
                ]
            case .premium:
                return [
                    "Everything in Pro",
                    "EoelWork gig platform",
                    "Advanced analytics",
                    "Custom branding",
                    "API access"
                ]
            }
        }
    }

    // MARK: - Subscription Status

    enum SubscriptionStatus: Equatable {
        case free
        case pro(expiryDate: Date)
        case premium(expiryDate: Date)
        case expired(tier: SubscriptionTier)

        var tier: SubscriptionTier {
            switch self {
            case .free, .expired:
                return .free
            case .pro:
                return .pro
            case .premium:
                return .premium
            }
        }

        var isActive: Bool {
            switch self {
            case .free, .expired:
                return false
            case .pro(let expiryDate), .premium(let expiryDate):
                return expiryDate > Date()
            }
        }

        var expiryDate: Date? {
            switch self {
            case .pro(let date), .premium(let date):
                return date
            case .free, .expired:
                return nil
            }
        }
    }

    // MARK: - Product Identifiers

    enum ProductIdentifier: String, CaseIterable {
        case proMonthly = "app.eoel.subscription.pro.monthly"
        case proYearly = "app.eoel.subscription.pro.yearly"
        case premiumMonthly = "app.eoel.subscription.premium.monthly"
        case premiumYearly = "app.eoel.subscription.premium.yearly"

        var tier: SubscriptionTier {
            switch self {
            case .proMonthly, .proYearly:
                return .pro
            case .premiumMonthly, .premiumYearly:
                return .premium
            }
        }

        var isYearly: Bool {
            switch self {
            case .proYearly, .premiumYearly:
                return true
            case .proMonthly, .premiumMonthly:
                return false
            }
        }
    }

    // MARK: - Transaction Listener

    private var transactionListener: Task<Void, Error>?

    // MARK: - Initialization

    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductIdentifier.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIDs)

            // Sort by price
            availableProducts = products.sorted { product1, product2 in
                product1.price < product2.price
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                isLoading = false
                return transaction

            case .userCancelled:
                isLoading = false
                return nil

            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval"
                return nil

            @unknown default:
                isLoading = false
                errorMessage = "Unknown purchase result"
                return nil
            }
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Subscription Status Update

    func updateSubscriptionStatus() async {
        var activeSubscriptions: [SubscriptionTier: Date] = [:]

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Add to purchased products
                purchasedProductIDs.insert(transaction.productID)

                // Determine tier and expiry
                if let productID = ProductIdentifier(rawValue: transaction.productID) {
                    let tier = productID.tier

                    // Get expiry date
                    if let expiryDate = transaction.expirationDate {
                        activeSubscriptions[tier] = expiryDate
                    }
                }

            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        // Update subscription status based on active subscriptions
        if let premiumExpiry = activeSubscriptions[.premium], premiumExpiry > Date() {
            subscriptionStatus = .premium(expiryDate: premiumExpiry)
        } else if let proExpiry = activeSubscriptions[.pro], proExpiry > Date() {
            subscriptionStatus = .pro(expiryDate: proExpiry)
        } else if let expiredTier = activeSubscriptions.keys.first {
            subscriptionStatus = .expired(tier: expiredTier)
        } else {
            subscriptionStatus = .free
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transaction updates
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update subscription status
                    await self.updateSubscriptionStatus()

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Feature Access Control

    func hasAccess(to feature: Feature) -> Bool {
        switch feature {
        case .basicInstruments, .basicEffects, .basicRecording:
            return true // Free tier

        case .allInstruments, .allEffects, .unlimitedRecordings, .cloudSync, .prioritySupport:
            return subscriptionStatus.tier == .pro || subscriptionStatus.tier == .premium

        case .eoelWork, .advancedAnalytics, .customBranding, .apiAccess:
            return subscriptionStatus.tier == .premium
        }
    }

    enum Feature {
        // Free
        case basicInstruments
        case basicEffects
        case basicRecording

        // Pro
        case allInstruments
        case allEffects
        case unlimitedRecordings
        case cloudSync
        case prioritySupport

        // Premium
        case eoelWork
        case advancedAnalytics
        case customBranding
        case apiAccess
    }

    // MARK: - Product Helpers

    func product(for identifier: ProductIdentifier) -> Product? {
        availableProducts.first { $0.id == identifier.rawValue }
    }

    func displayPrice(for product: Product) -> String {
        product.displayPrice
    }

    func savingsPercentage(monthly: Product, yearly: Product) -> Int? {
        let monthlyYearlyCost = monthly.price * 12
        let yearlyCost = yearly.price
        let savings = monthlyYearlyCost - yearlyCost
        let percentage = (savings / monthlyYearlyCost) * 100
        return Int(percentage)
    }

    // MARK: - Cancel Subscription

    func manageSubscriptions() async {
        // Open App Store subscription management
        if let scene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                errorMessage = "Failed to open subscription management"
            }
        }
    }
}

// MARK: - Store Errors

enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

// MARK: - Usage Limits (Free Tier)

extension SubscriptionManager {
    enum UsageLimit {
        static let freeRecordingLimit = 5
        static let freeInstrumentLimit = 3
        static let freeEffectLimit = 10
    }

    func canCreateRecording(currentCount: Int) -> Bool {
        if subscriptionStatus.tier == .free {
            return currentCount < UsageLimit.freeRecordingLimit
        }
        return true
    }

    func canUseInstrument(index: Int) -> Bool {
        if subscriptionStatus.tier == .free {
            return index < UsageLimit.freeInstrumentLimit
        }
        return true
    }

    func canUseEffect(index: Int) -> Bool {
        if subscriptionStatus.tier == .free {
            return index < UsageLimit.freeEffectLimit
        }
        return true
    }
}

// MARK: - Analytics Integration

extension SubscriptionManager {
    func trackSubscriptionEvent(_ event: SubscriptionEvent) {
        // Integration with TelemetryDeck
        let signal = TelemetryDeck.Signal(event.rawValue, parameters: [
            "tier": subscriptionStatus.tier.rawValue,
            "isActive": "\(subscriptionStatus.isActive)"
        ])
        TelemetryDeck.send(signal)
    }

    enum SubscriptionEvent: String {
        case paywall_viewed
        case purchase_initiated
        case purchase_completed
        case purchase_failed
        case purchase_cancelled
        case subscription_renewed
        case subscription_expired
        case subscription_restored
        case manage_subscription_tapped
    }
}
