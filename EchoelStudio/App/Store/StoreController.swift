import EchoelCore
import Observation
import StoreKit
import os

/// Sells Echoel's own Audio Units. A purchase unlocks the plugin in every host on every device of
/// the same Apple account; the plugin itself reads the same transactions.
@MainActor
@Observable
final class StoreController {
    private(set) var products: [String: Product] = [:]
    private(set) var owned: Set<String> = []
    private(set) var isLoading = false
    private(set) var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "store")

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshOwned()
            }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let found = try await Product.products(for: OwnPlugin.all.map(\.productID))
            products = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            message = found.isEmpty ? "The store is not available right now." : nil
        } catch {
            log.error("products failed — \(error.localizedDescription, privacy: .public)")
            message = "The store is not available right now."
        }
        await refreshOwned()
    }

    func buy(_ plugin: OwnPlugin) async {
        guard let product = products[plugin.productID] else { return }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                message = "\(plugin.component.name) is unlocked. Reload it in your host to remove the demo."
            case .success(.unverified):
                message = "The purchase could not be verified."
            case .pending:
                message = "The purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            log.error("purchase failed — \(error.localizedDescription, privacy: .public)")
            message = "The purchase did not go through."
        }
        await refreshOwned()
    }

    /// Asks the App Store for this account's purchases again.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            message = "Could not reach the App Store."
        }
        await refreshOwned()
    }

    private func refreshOwned() async {
        var found: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                found.insert(transaction.productID)
            }
        }
        owned = found
    }
}
