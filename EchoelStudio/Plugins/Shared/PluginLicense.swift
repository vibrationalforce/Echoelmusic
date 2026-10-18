import EchoelCore
import StoreKit

/// Whether this device's Apple account bought Echoel's plugins (`PluginUnlock`). The purchase is made in the
/// app; an extension of the same app reads the same transactions.
enum PluginLicense {
    static func isUnlocked() async -> Bool {
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
