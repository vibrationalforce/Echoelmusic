import EchoelCore
import Observation
import StoreKit
import os

/// Sells Echoel's own Audio Units as ONE purchase (`PluginUnlock`). It unlocks every plugin in
/// every host on every device of the same Apple account: after every check of the transactions
/// the app records the result in the shared container, where the plugins read it.
@MainActor
@Observable
final class StoreController {
    private(set) var product: Product?
    private(set) var isOwned = false
    private(set) var isLoading = false
    private(set) var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "store")

    init() {
        // The listener starts first, as Apple asks; the launch pass that records the purchase for
        // the plugins runs beside it, so a purchase from another device arrives without a store visit.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshOwned()
            }
        }
        Task { [weak self] in await self?.refreshOwned() }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [PluginUnlock.productID]).first
            message = product == nil ? "The instruments are not on sale yet." : nil
        } catch {
            log.error("products failed — \(error.localizedDescription, privacy: .public)")
            message = "The store is not available right now."
        }
        await refreshOwned()
    }

    func buy() async {
        guard let product else { return }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                message = "\(PluginUnlock.name) are unlocked. Reload them in your host to remove the demo."
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
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil,
               transaction.productID == PluginUnlock.productID {
                found = true
            }
        }
        isOwned = found
        PluginUnlock.recordOwned(found)
    }
}
