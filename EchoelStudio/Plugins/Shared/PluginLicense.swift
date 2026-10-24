import EchoelCore
import StoreKit

/// Whether this device's Apple account bought Echoel's plugins (`PluginUnlock`). The purchase is made in the
/// app, which records it in the shared container; that record is read first. StoreKit is asked only
/// when no record says so, because Apple does not support StoreKit in app extensions — and it is
/// asked for a bounded time: an answer that never comes left the unit locked forever and, before
/// 2026-10-24, the plugin window empty for as long as it took (store review).
enum PluginLicense {
    /// How long the StoreKit fallback may take before it counts as "not found".
    static let storeKitTimeout: Duration = .seconds(5)

    static func isUnlocked() async -> Bool {
        if PluginUnlock.recordedOwned() { return true }
        let owned = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await storeKitOwns() }
            group.addTask {
                try? await Task.sleep(for: storeKitTimeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        // A purchase StoreKit confirmed here is recorded for the next host load, so the five-second
        // race is paid once per device, not once per session.
        if owned { PluginUnlock.recordOwned(true) }
        return owned
    }

    private static func storeKitOwns() async -> Bool {
        let productID = PluginUnlock.productID
        for await result in Transaction.currentEntitlements {
            if Task.isCancelled { return false }
            if case .verified(let transaction) = result, transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
