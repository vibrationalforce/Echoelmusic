// EchoelStore.swift
// Echoelmusic — StoreKit 2 Monetization Engine
//
// Handles subscriptions, consumable sessions, and restore purchases.
// Philosophy: Value first, ethical pricing, no dark patterns.
//
// Products:
//   - echoel_pro_monthly: Pro subscription (monthly)
//   - echoel_pro_yearly: Pro subscription (yearly)
//   - echoel_pro_lifetime: Lifetime unlock (non-consumable)
//   - echoel_session_coherence: Guided Coherence Session (consumable)
//   - echoel_session_sleep: Deep Sleep Session (consumable)
//   - echoel_session_flow: Flow State Session (consumable)
//
// Created 2026-02-17
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import Foundation
import StoreKit
import Combine

// MARK: - Product Identifiers

/// All StoreKit product identifiers for Echoelmusic
public enum EchoelProduct: String, CaseIterable, Sendable {
    // Subscriptions (Auto-Renewable)
    case proMonthly  = "echoel_pro_monthly"
    case proYearly   = "echoel_pro_yearly"

    // Non-Consumable (Lifetime)
    case proLifetime = "echoel_pro_lifetime"

    // Consumable Sessions
    case sessionCoherence = "echoel_session_coherence"
    case sessionSleep     = "echoel_session_sleep"
    case sessionFlow      = "echoel_session_flow"

    /// Subscription group identifier
    public static let subscriptionGroupID = "echoel_pro"

    /// All subscription product IDs
    public static var subscriptions: [EchoelProduct] {
        [.proMonthly, .proYearly]
    }

    /// All consumable product IDs
    public static var consumables: [EchoelProduct] {
        [.sessionCoherence, .sessionSleep, .sessionFlow]
    }
}

// MARK: - Entitlement Level

/// User's current entitlement level
public enum EchoelEntitlement: Int, Comparable, Sendable {
    case free = 0
    case session = 1     // Purchased individual sessions
    case pro = 2         // Active Pro subscription or lifetime

    public static func < (lhs: EchoelEntitlement, rhs: EchoelEntitlement) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - EchoelStore

/// Central StoreKit 2 manager for Echoelmusic
/// Handles product loading, purchases, entitlement verification, and transaction observation.
@MainActor
public final class EchoelStore: ObservableObject {

    // MARK: - Published State

    /// All available products from App Store
    @Published public private(set) var products: [Product] = []

    /// Subscription products sorted by price
    @Published public private(set) var subscriptions: [Product] = []

    /// Consumable session products
    @Published public private(set) var sessions: [Product] = []

    /// Lifetime product
    @Published public private(set) var lifetime: Product?

    /// Current entitlement level
    @Published public private(set) var entitlement: EchoelEntitlement = .free

    /// Whether a purchase is currently in progress
    @Published public private(set) var isPurchasing = false

    /// Number of purchased but unused sessions
    @Published public private(set) var availableSessions: Int = 0

    /// Error message for display
    @Published public var errorMessage: String?

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    private static let sessionsKey = "echoelmusic_purchased_sessions"

    // MARK: - Singleton

    public static let shared = EchoelStore()

    // MARK: - Init

    public init() {
        availableSessions = UserDefaults.standard.integer(forKey: Self.sessionsKey)
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateEntitlement() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    /// Fetch products from App Store
    public func loadProducts() async {
        do {
            let ids = EchoelProduct.allCases.map(\.rawValue)
            let storeProducts = try await Product.products(for: Set(ids))

            products = storeProducts.sorted { $0.price < $1.price }
            subscriptions = storeProducts
                .filter { $0.type == .autoRenewable }
                .sorted { $0.price < $1.price }
            sessions = storeProducts
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
            lifetime = storeProducts.first { $0.type == .nonConsumable }

            log.info("Loaded \(storeProducts.count) products from App Store", category: .system)
        } catch {
            log.error("Failed to load products: \(error.localizedDescription)", category: .system)
            errorMessage = "Could not load products. Please check your connection."
        }
    }

    // MARK: - Purchase

    /// Purchase a product
    public func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction, product: product)
                await transaction.finish()
                log.info("Purchase successful: \(product.id)", category: .system)
                return true

            case .userCancelled:
                log.info("Purchase cancelled by user: \(product.id)", category: .system)
                return false

            case .pending:
                log.info("Purchase pending approval: \(product.id)", category: .system)
                errorMessage = "Purchase is pending approval (e.g. Ask to Buy)."
                return false

            @unknown default:
                return false
            }
        } catch {
            log.error("Purchase failed: \(error.localizedDescription)", category: .system)
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    /// Restore previous purchases
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateEntitlement()
            log.info("Purchases restored", category: .system)
        } catch {
            log.error("Restore failed: \(error.localizedDescription)", category: .system)
            errorMessage = "Could not restore purchases. Please try again."
        }
    }

    // MARK: - Entitlement Check

    /// Check if user has Pro access
    public var isPro: Bool { entitlement >= .pro }

    /// Check if user can access a specific session type
    public func canAccessSession(_ sessionType: EchoelProduct) -> Bool {
        isPro || availableSessions > 0
    }

    /// Consume one session token
    public func consumeSession() -> Bool {
        guard availableSessions > 0 else { return false }
        availableSessions -= 1
        UserDefaults.standard.set(availableSessions, forKey: Self.sessionsKey)
        return true
    }

    /// Update entitlement based on current transactions
    public func updateEntitlement() async {
        var newEntitlement: EchoelEntitlement = .free

        // Check for active subscription
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            switch transaction.productType {
            case .autoRenewable:
                if transaction.revocationDate == nil {
                    newEntitlement = .pro
                }
            case .nonConsumable:
                newEntitlement = .pro
            default:
                break
            }
        }

        // Check for purchased sessions
        if newEntitlement == .free && availableSessions > 0 {
            newEntitlement = .session
        }

        entitlement = newEntitlement
    }

    // MARK: - Transaction Handling

    private func handleTransaction(_ transaction: Transaction, product: Product) async {
        switch product.type {
        case .autoRenewable, .nonConsumable:
            entitlement = .pro
            EngineBus.shared.publish(.custom(
                topic: "store.entitlement_changed",
                payload: ["level": "pro"]
            ))

        case .consumable:
            availableSessions += 1
            UserDefaults.standard.set(availableSessions, forKey: Self.sessionsKey)
            if entitlement == .free {
                entitlement = .session
            }
            EngineBus.shared.publish(.custom(
                topic: "store.session_purchased",
                payload: ["product": product.id, "available": "\(availableSessions)"]
            ))

        default:
            break
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.updateEntitlement()
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Subscription Status

    /// Get the current subscription status
    public func subscriptionStatus() async -> Product.SubscriptionInfo.Status? {
        guard let groupID = subscriptions.first?.subscription?.subscriptionGroupID else {
            return nil
        }
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: groupID)
            return statuses.first { $0.state == .subscribed || $0.state == .inGracePeriod }
        } catch {
            log.error("Could not fetch subscription status: \(error.localizedDescription)", category: .system)
            return nil
        }
    }

    /// Get renewal date for current subscription
    public func renewalDate() async -> Date? {
        guard let status = await subscriptionStatus(),
              case .verified(let renewal) = status.renewalInfo,
              let expirationDate = renewal.expirationDate else {
            return nil
        }
        return expirationDate
    }
}
