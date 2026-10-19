import Foundation

/// The one purchase that unlocks Echoel's instruments in other hosts; the effects are free there
/// too (founder decision 2026-10-18). It lives in the app's existing App Store record
/// (`com.echoelmusic.app`), so selling the plugins needs no new app, no new bundle id and exactly
/// one in-app purchase. Inside Echoel the same instruments and effects are free.
///
/// It lives HERE, not in `EchoelCore`, on purpose (2026-10-19): the open packages (Core · DSP ·
/// Engine) describe the plugins (`OwnPlugin`) but do not know that anything is sold. The product
/// id and the purchase name belong to the two layers that read them — the store (`App/Store`) and
/// the licence check (`PluginLicense`) — so this one file is compiled into both targets
/// (`project.yml`: the app lists it by path, the extension takes all of `Plugins/Shared`).
/// The id keeps the app's prefix (`com.echoelmusic.app.`): one App Store record, one purchase.
enum PluginUnlock {
    static let productID = "com.echoelmusic.app.pro"
    static let name = "Echoel Plugins"

    /// The container app and extension share (both profiles carry it, F17). The extension only
    /// READS the purchase from here: App Review guideline 4.4 keeps purchases out of extensions,
    /// and Apple does not support StoreKit inside them, so the StoreKit read in `PluginLicense`
    /// is a fallback, not the path.
    static let sharedGroup = "group.com.echoelmusic.shared"
    static let unlockedKey = "plugins.unlocked.v1"

    /// The app writes this after every verified pass over its entitlements; nothing else does.
    static func recordOwned(_ owned: Bool) {
        UserDefaults(suiteName: sharedGroup)?.set(owned, forKey: unlockedKey)
    }

    /// What the app last recorded; `false` when it never ran or the container is unavailable.
    static func recordedOwned() -> Bool {
        UserDefaults(suiteName: sharedGroup)?.bool(forKey: unlockedKey) ?? false
    }
}
