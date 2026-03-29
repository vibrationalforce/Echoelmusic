#if canImport(StoreKit)
import Foundation
import StoreKit
import Observation

/// StoreKit 2 subscription manager for Echoelmusic.
/// Products: monthly ($4.99) and yearly ($39.99).
@MainActor @Observable
final class EchoelStore {

    // MARK: - Product IDs

    static let monthlyID = "com.echoelmusic.app.monthly"
    static let yearlyID = "com.echoelmusic.app.yearly"

    // MARK: - State

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isSubscribed: Bool = false
    var isLoading: Bool = false

    // MARK: - Init

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    nonisolated deinit {
        // Task is self-cancelling when the store is deallocated
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [
                Self.monthlyID,
                Self.yearlyID
            ])
            products.sort { $0.price < $1.price }
            log.log(.info, category: .system, "StoreKit: Loaded \(products.count) products")
        } catch {
            log.log(.error, category: .system, "StoreKit: Failed to load products — \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            log.log(.info, category: .system, "StoreKit: Purchased \(product.id)")
            return true

        case .userCancelled:
            return false

        case .pending:
            log.log(.info, category: .system, "StoreKit: Purchase pending approval")
            return false

        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        var subscribed = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                if transaction.revocationDate == nil {
                    subscribed = true
                    purchasedProductIDs.insert(transaction.productID)
                }
            }
        }

        isSubscribed = subscribed
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Convenience

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyID }
    }
}
#endif
