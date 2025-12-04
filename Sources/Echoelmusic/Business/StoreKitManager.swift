import Foundation
import StoreKit
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// STOREKIT 2 MANAGER - SUBSCRIPTION & IN-APP PURCHASE SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete StoreKit 2 implementation for monetization:
// • Subscription management (monthly/yearly)
// • In-app purchase handling
// • Entitlement verification
// • Subscription status tracking
// • Family sharing support
// • Promotional offers
// • Refund handling
// • Receipt validation
//
// ═══════════════════════════════════════════════════════════════════════════════

/// StoreKit 2 manager for subscriptions and purchases
@MainActor
final class StoreKitManager: ObservableObject {

    // MARK: - Product IDs

    enum ProductID: String, CaseIterable {
        // Subscriptions
        case proMonthly = "com.echoelmusic.pro.monthly"
        case proYearly = "com.echoelmusic.pro.yearly"
        case studioMonthly = "com.echoelmusic.studio.monthly"
        case studioYearly = "com.echoelmusic.studio.yearly"

        // One-time purchases
        case soundPackBasic = "com.echoelmusic.soundpack.basic"
        case soundPackPremium = "com.echoelmusic.soundpack.premium"
        case instrumentPackOrchestral = "com.echoelmusic.instruments.orchestral"
        case instrumentPackSynth = "com.echoelmusic.instruments.synth"

        var isSubscription: Bool {
            switch self {
            case .proMonthly, .proYearly, .studioMonthly, .studioYearly:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var currentEntitlements: Set<Entitlement> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Entitlements

    enum Entitlement: String {
        case basicFeatures = "basic"
        case proFeatures = "pro"
        case studioFeatures = "studio"
        case soundPackBasic = "soundpack.basic"
        case soundPackPremium = "soundpack.premium"
        case instrumentsOrchestral = "instruments.orchestral"
        case instrumentsSynth = "instruments.synth"
        case unlimitedTracks = "unlimited.tracks"
        case cloudSync = "cloud.sync"
        case collaboration = "collaboration"
        case aiComposer = "ai.composer"
        case advancedEffects = "effects.advanced"
        case streaming = "streaming"
    }

    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(tier: SubscriptionTier, expirationDate: Date, willRenew: Bool)
        case expired(tier: SubscriptionTier, expirationDate: Date)
        case inGracePeriod(tier: SubscriptionTier, expirationDate: Date)
        case inBillingRetry(tier: SubscriptionTier)

        var isActive: Bool {
            switch self {
            case .subscribed, .inGracePeriod, .inBillingRetry:
                return true
            default:
                return false
            }
        }
    }

    enum SubscriptionTier: String, Comparable {
        case free = "Free"
        case pro = "Pro"
        case studio = "Studio"

        static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
            let order: [SubscriptionTier] = [.free, .pro, .studio]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    // MARK: - Private Properties

    private var updateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Start listening for transaction updates
        updateTask = observeTransactionUpdates()

        // Load products
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)

            // Sort: subscriptions first, then by price
            products.sort { product1, product2 in
                if product1.type == .autoRenewable && product2.type != .autoRenewable {
                    return true
                }
                if product1.type != .autoRenewable && product2.type == .autoRenewable {
                    return false
                }
                return product1.price < product2.price
            }

            print("✅ StoreKit: Loaded \(products.count) products")
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ StoreKit: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update purchased products
                await updatePurchasedProducts()

                // Finish transaction
                await transaction.finish()

                print("✅ StoreKit: Purchase successful - \(product.id)")
                return transaction

            case .userCancelled:
                print("ℹ️ StoreKit: User cancelled purchase")
                return nil

            case .pending:
                print("ℹ️ StoreKit: Purchase pending (e.g., Ask to Buy)")
                return nil

            @unknown default:
                print("⚠️ StoreKit: Unknown purchase result")
                return nil
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ StoreKit: Purchase failed - \(error)")
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("✅ StoreKit: Purchases restored")
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ StoreKit: Restore failed - \(error)")
        }
    }

    // MARK: - Transaction Handling

    private func observeTransactionUpdates() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    print("❌ StoreKit: Transaction update verification failed")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw StoreKitError.verificationFailed(error)
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var entitlements: Set<Entitlement> = [.basicFeatures] // Everyone gets basic
        var highestTier: SubscriptionTier = .free
        var subStatus: SubscriptionStatus = .notSubscribed

        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)

                // Determine entitlements from product
                if let productEntitlements = entitlementsForProduct(transaction.productID) {
                    entitlements.formUnion(productEntitlements)
                }

                // Track subscription status
                if let productID = ProductID(rawValue: transaction.productID),
                   productID.isSubscription {
                    let tier = tierForProduct(productID)
                    if tier > highestTier {
                        highestTier = tier
                    }

                    // Get subscription status
                    if let status = await getSubscriptionStatus(for: transaction) {
                        subStatus = status
                    }
                }

            } catch {
                print("⚠️ StoreKit: Failed to verify entitlement")
            }
        }

        // Update state on main actor
        purchasedProductIDs = purchased
        currentEntitlements = entitlements
        subscriptionStatus = subStatus

        print("✅ StoreKit: Updated entitlements - \(entitlements.count) active")
    }

    private func getSubscriptionStatus(for transaction: Transaction) async -> SubscriptionStatus? {
        guard let productID = ProductID(rawValue: transaction.productID),
              productID.isSubscription else {
            return nil
        }

        let tier = tierForProduct(productID)

        // Get subscription info
        guard let subscriptionGroupID = transaction.subscriptionGroupID else {
            return nil
        }

        do {
            let statuses = try await Product.SubscriptionInfo.status(for: subscriptionGroupID)

            guard let status = statuses.first else {
                return .notSubscribed
            }

            switch status.state {
            case .subscribed:
                if let renewalInfo = try? status.renewalInfo.payloadValue {
                    return .subscribed(
                        tier: tier,
                        expirationDate: transaction.expirationDate ?? Date(),
                        willRenew: renewalInfo.willAutoRenew
                    )
                }
                return .subscribed(tier: tier, expirationDate: transaction.expirationDate ?? Date(), willRenew: true)

            case .expired:
                return .expired(tier: tier, expirationDate: transaction.expirationDate ?? Date())

            case .inGracePeriod:
                return .inGracePeriod(tier: tier, expirationDate: transaction.expirationDate ?? Date())

            case .inBillingRetryPeriod:
                return .inBillingRetry(tier: tier)

            case .revoked:
                return .notSubscribed

            default:
                return .notSubscribed
            }
        } catch {
            print("⚠️ StoreKit: Failed to get subscription status")
            return nil
        }
    }

    private func entitlementsForProduct(_ productID: String) -> Set<Entitlement>? {
        guard let product = ProductID(rawValue: productID) else { return nil }

        switch product {
        case .proMonthly, .proYearly:
            return [.proFeatures, .unlimitedTracks, .cloudSync, .advancedEffects]

        case .studioMonthly, .studioYearly:
            return [.proFeatures, .studioFeatures, .unlimitedTracks, .cloudSync,
                    .collaboration, .aiComposer, .advancedEffects, .streaming]

        case .soundPackBasic:
            return [.soundPackBasic]

        case .soundPackPremium:
            return [.soundPackBasic, .soundPackPremium]

        case .instrumentPackOrchestral:
            return [.instrumentsOrchestral]

        case .instrumentPackSynth:
            return [.instrumentsSynth]
        }
    }

    private func tierForProduct(_ productID: ProductID) -> SubscriptionTier {
        switch productID {
        case .proMonthly, .proYearly:
            return .pro
        case .studioMonthly, .studioYearly:
            return .studio
        default:
            return .free
        }
    }

    // MARK: - Entitlement Checks

    func hasEntitlement(_ entitlement: Entitlement) -> Bool {
        return currentEntitlements.contains(entitlement)
    }

    func hasProAccess() -> Bool {
        return currentEntitlements.contains(.proFeatures) || currentEntitlements.contains(.studioFeatures)
    }

    func hasStudioAccess() -> Bool {
        return currentEntitlements.contains(.studioFeatures)
    }

    // MARK: - Subscription Management

    func manageSubscriptions() async {
        if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
            try? await AppStore.showManageSubscriptions(in: windowScene)
        }
    }

    func requestRefund(for transaction: Transaction) async {
        if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                let status = try await transaction.beginRefundRequest(in: windowScene)
                switch status {
                case .userCancelled:
                    print("ℹ️ User cancelled refund request")
                case .success:
                    print("✅ Refund request submitted")
                @unknown default:
                    break
                }
            } catch {
                print("❌ Failed to request refund: \(error)")
            }
        }
    }

    // MARK: - Promotional Offers

    func isEligibleForIntroductoryOffer(for product: Product) async -> Bool {
        guard product.type == .autoRenewable else { return false }
        return await product.subscription?.isEligibleForIntroOffer ?? false
    }

    func getPromotionalOffers(for product: Product) -> [Product.SubscriptionOffer] {
        guard let subscription = product.subscription else { return [] }
        return subscription.promotionalOffers
    }

    // MARK: - Price Formatting

    func formattedPrice(for product: Product) -> String {
        return product.displayPrice
    }

    func formattedPricePerMonth(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        let price = product.price
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        let monthlyPrice: Decimal
        switch unit {
        case .year:
            monthlyPrice = price / Decimal(12 * value)
        case .month:
            monthlyPrice = price / Decimal(value)
        case .week:
            monthlyPrice = price * Decimal(52 / 12) / Decimal(value)
        case .day:
            monthlyPrice = price * Decimal(365 / 12) / Decimal(value)
        @unknown default:
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale

        return formatter.string(from: monthlyPrice as NSNumber)
    }

    // MARK: - Helpers

    func product(for id: ProductID) -> Product? {
        return products.first { $0.id == id.rawValue }
    }

    func isPurchased(_ productID: ProductID) -> Bool {
        return purchasedProductIDs.contains(productID.rawValue)
    }
}

// MARK: - Errors

enum StoreKitError: LocalizedError {
    case verificationFailed(Error)
    case productNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed(let error):
            return "Verification failed: \(error.localizedDescription)"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

// MARK: - UIKit Import for Scene Access

#if canImport(UIKit)
import UIKit
#endif
