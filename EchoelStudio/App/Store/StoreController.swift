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
    /// A purchase or a restore is under way: the buttons wait for it, so a second tap cannot
    /// start a second purchase whose message overwrites the first (store review 2026-10-24).
    private(set) var isBusy = false
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

    /// Runs under the store sheet's `.task`, which SwiftUI cancels when the sheet closes. A
    /// cancelled visit must neither report a store error nor record anything: the pass it would
    /// run can end early and empty, and it would be the newest pass, so it would write `false`
    /// for a buyer (store review 2026-10-24).
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [PluginUnlock.productID]).first
            message = product == nil ? "The instruments are not on sale yet." : nil
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            log.error("products failed — \(error.localizedDescription, privacy: .public)")
            message = "The App Store is not available right now. Check the connection and open this page again."
        }
        guard !Task.isCancelled else { return }
        await refreshOwned()
    }

    func buy() async {
        guard let product, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        var unlocked = false
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                unlocked = true
            case .success(.unverified):
                message = "The purchase could not be verified. Tap Restore Purchases; if that finds nothing, try buying again."
            case .pending:
                message = "The purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            log.error("purchase failed — \(error.localizedDescription, privacy: .public)")
            message = "The purchase did not go through. Nothing was charged; try again."
        }
        await refreshOwned()
        if unlocked {
            message = "\(PluginUnlock.name) are unlocked. Reload them in your host to remove the demo."
        }
    }

    /// Asks the App Store for this account's purchases again, and says what it found: a restore
    /// that finds nothing used to end without a word, so the button looked dead.
    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            log.error("restore failed — \(error.localizedDescription, privacy: .public)")
            message = "Could not reach the App Store. Check the connection and try again."
            return
        }
        await refreshOwned()
        message = isOwned
            ? "\(PluginUnlock.name) are restored."
            : "No purchase of \(PluginUnlock.name) was found for this Apple Account."
    }

    private func refreshOwned() async {
        guard !Task.isCancelled else { return }
        pass &+= 1
        let mine = pass
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil,
               transaction.productID == PluginUnlock.productID {
                found = true
            }
        }
        // A pass that was cancelled mid-way may have ended early and empty: it says nothing.
        guard mine == pass, !Task.isCancelled else { return }
        isOwned = found
        // A finished purchase outdates "waiting for approval" and any earlier failure.
        if found { message = nil }
        PluginUnlock.recordOwned(found)
    }
}
