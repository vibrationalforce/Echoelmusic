import EchoelCore
import StoreKit

/// Whether this device's Apple account bought Echoel's plugins (`PluginUnlock`). The purchase is made in the
/// app, which records it in the shared container; that record is read first. StoreKit is asked only
/// when no record says so, because Apple does not support StoreKit in app extensions.
enum PluginLicense {
    static func isUnlocked() async -> Bool {
        if PluginUnlock.recordedOwned() { return true }
        let productID = PluginUnlock.productID
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
