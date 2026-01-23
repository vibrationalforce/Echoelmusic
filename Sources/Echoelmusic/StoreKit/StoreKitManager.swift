//
//  StoreKitManager.swift
//  Echoelmusic
//
//  StoreKit 2 manager for one-time universal purchase
//  Handles the simple, fair pricing model: Buy once, own forever
//
//  Created: 2026-01-23
//

import Foundation
import StoreKit

/// StoreKit 2 manager for Echoelmusic's one-time purchase model
///
/// Echoelmusic uses a simple, ethical pricing model:
/// - $29.99 one-time purchase
/// - All features unlocked
/// - Lifetime updates included
/// - Family Sharing for up to 6 members
/// - Universal purchase (works on all Apple platforms)
@MainActor
public class StoreKitManager: ObservableObject {

    // MARK: - Product Identifiers

    public enum ProductID: String, CaseIterable {
        case universalPurchase = "com.echoelmusic.app.universal"
        case tipSmall = "com.echoelmusic.tip.small"
        case tipMedium = "com.echoelmusic.tip.medium"
        case tipLarge = "com.echoelmusic.tip.large"

        var displayName: String {
            switch self {
            case .universalPurchase: return "Echoelmusic Full Version"
            case .tipSmall: return "Small Tip"
            case .tipMedium: return "Medium Tip"
            case .tipLarge: return "Large Tip"
            }
        }
    }

    // MARK: - Published State

    /// Whether the user has purchased the full version
    @Published public private(set) var isFullVersionPurchased: Bool = false

    /// Available products from the App Store
    @Published public private(set) var products: [Product] = []

    /// The universal purchase product (if available)
    @Published public private(set) var universalProduct: Product?

    /// Tip products for supporters
    @Published public private(set) var tipProducts: [Product] = []

    /// Current purchase state
    @Published public private(set) var purchaseState: PurchaseState = .idle

    /// Error message if purchase fails
    @Published public private(set) var errorMessage: String?

    // MARK: - Purchase State

    public enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case failed(String)
        case restored
    }

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?
    private let userDefaults = UserDefaults.standard
    private let purchasedKey = "echoelmusic.fullVersionPurchased"

    // MARK: - Initialization

    public init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load cached purchase state
        isFullVersionPurchased = userDefaults.bool(forKey: purchasedKey)

        // Load products and verify purchase state
        Task {
            await loadProducts()
            await updatePurchaseState()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    /// Load products from the App Store
    public func loadProducts() async {
        purchaseState = .loading

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: Set(productIDs))

            // Sort and categorize products
            products = storeProducts.sorted { $0.price < $1.price }

            // Find universal purchase product
            universalProduct = storeProducts.first { $0.id == ProductID.universalPurchase.rawValue }

            // Find tip products
            tipProducts = storeProducts.filter {
                $0.id == ProductID.tipSmall.rawValue ||
                $0.id == ProductID.tipMedium.rawValue ||
                $0.id == ProductID.tipLarge.rawValue
            }.sorted { $0.price < $1.price }

            purchaseState = .idle
            errorMessage = nil

        } catch {
            purchaseState = .failed("Failed to load products: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    /// Purchase the universal full version
    public func purchaseFullVersion() async throws {
        guard let product = universalProduct else {
            throw StoreKitError.productNotFound
        }

        try await purchase(product)
    }

    /// Purchase a tip (for supporters)
    public func purchaseTip(_ productID: ProductID) async throws {
        guard let product = tipProducts.first(where: { $0.id == productID.rawValue }) else {
            throw StoreKitError.productNotFound
        }

        try await purchase(product)
    }

    /// Generic purchase method
    private func purchase(_ product: Product) async throws {
        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Update purchase state
                await updatePurchaseState()

                // Finish the transaction
                await transaction.finish()

                purchaseState = .purchased
                errorMessage = nil

            case .userCancelled:
                purchaseState = .idle
                // User cancelled - not an error

            case .pending:
                purchaseState = .idle
                errorMessage = "Purchase is pending approval"

            @unknown default:
                purchaseState = .failed("Unknown purchase result")
            }

        } catch {
            purchaseState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    public func restorePurchases() async {
        purchaseState = .loading

        do {
            try await AppStore.sync()
            await updatePurchaseState()

            if isFullVersionPurchased {
                purchaseState = .restored
            } else {
                purchaseState = .idle
                errorMessage = "No purchases to restore"
            }

        } catch {
            purchaseState = .failed("Failed to restore: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Purchase State

    /// Check current entitlements and update state
    public func updatePurchaseState() async {
        // Check for the universal purchase
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productID == ProductID.universalPurchase.rawValue {
                    isFullVersionPurchased = true
                    userDefaults.set(true, forKey: purchasedKey)
                    return
                }
            } catch {
                // Transaction verification failed
                continue
            }
        }

        // No valid purchase found - but keep cached state if offline
        // This allows offline use after purchase
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Update purchase state
                    await self.updatePurchaseState()

                    // Finish the transaction
                    await transaction.finish()

                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    // MARK: - Verification

    /// Verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw StoreKitError.verificationFailed(error.localizedDescription)
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helpers

    /// Get formatted price for the universal purchase
    public var formattedPrice: String {
        universalProduct?.displayPrice ?? "$29.99"
    }

    /// Check if products are loaded
    public var areProductsLoaded: Bool {
        !products.isEmpty
    }
}

// MARK: - StoreKit Errors

public enum StoreKitError: LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found. Please try again later."
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        }
    }
}

// MARK: - Preview/Testing Support

#if DEBUG
extension StoreKitManager {
    /// Create a mock manager for previews
    static var preview: StoreKitManager {
        let manager = StoreKitManager()
        manager.isFullVersionPurchased = true
        return manager
    }

    /// Simulate a successful purchase (for testing)
    func simulatePurchase() {
        isFullVersionPurchased = true
        userDefaults.set(true, forKey: purchasedKey)
        purchaseState = .purchased
    }

    /// Reset purchase state (for testing)
    func resetPurchase() {
        isFullVersionPurchased = false
        userDefaults.removeObject(forKey: purchasedKey)
        purchaseState = .idle
    }
}
#endif
