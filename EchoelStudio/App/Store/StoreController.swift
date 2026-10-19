import EchoelCore
import Observation
import StoreKit
import os

/// Sells Echoel's own Audio Units as ONE purchase (`PluginUnlock`). It lifts the demo pause of
/// Echoel's instruments (the effects are free) in every host on a device of the same Apple account,
/// once the app has run on that device: after every check of the transactions the app records the
/// result in the shared container, where the plugins read it.
@MainActor
@Observable
final class StoreController {
    private(set) var product: Product?
    private(set) var isOwned = false
    private(set) var isLoading = false
    private(set) var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    /// Raised at the start of every entitlement pass. Passes overlap on the main actor (the launch
    /// pass, the update listener, a store visit) and interleave at each `await`; only the newest may
    /// write, or an older pass that finishes last would put back an answer a refund already replaced.
    @ObservationIgnored private var pass = 0
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
        pass &+= 1
        let mine = pass
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil,
               transaction.productID == PluginUnlock.productID {
                found = true
            }
        }
        guard mine == pass else { return }
        isOwned = found
        PluginUnlock.recordOwned(found)
    }
}
