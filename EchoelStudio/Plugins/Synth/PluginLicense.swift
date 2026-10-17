import EchoelCore
import StoreKit

/// Whether this device's Apple account bought the plugin in Echoel. The purchase is made in the
/// app; an extension of the same app reads the same transactions.
enum PluginLicense {
    static let productID = OwnPlugin.synth.productID

    static func isUnlocked() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
