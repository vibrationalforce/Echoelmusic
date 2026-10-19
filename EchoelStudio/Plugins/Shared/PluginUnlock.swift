import Foundation
import os

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

    /// The container app and extension share (requested by both since factory job 002; whether the
    /// extension's profile grants it is F17's open half). The extension only
    /// READS the purchase from here: App Review guideline 4.4 keeps purchases out of extensions,
    /// and Apple does not support StoreKit inside them, so the StoreKit read in `PluginLicense`
    /// is a fallback, not the path.
    static let sharedGroup = "group.com.echoelmusic.shared"
    static let unlockedKey = "plugins.unlocked.v1"

    /// The app writes this after every verified pass over its entitlements; nothing else does.
    /// Without the entitlement `UserDefaults(suiteName:)` does not fail: it quietly writes into the
    /// app's own sandbox, where the extension never looks. That case is logged, so a device test can
    /// tell "not entitled" apart from "not bought".
    static func recordOwned(_ owned: Bool) {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedGroup) == nil {
            Logger(subsystem: "com.echoelmusic.studio", category: "store")
                .warning("no App Group container \(sharedGroup, privacy: .public) — the plugins cannot read the purchase")
        }
        UserDefaults(suiteName: sharedGroup)?.set(owned, forKey: unlockedKey)
    }

    /// What the app last recorded on THIS device; `false` when it never ran or the container is
    /// unavailable. A recorded `true` outlives a refund or a change of Apple account until the app
    /// next runs its launch pass, because the extension returns before its own StoreKit check —
    /// a refund path belongs in the app's pass, not in `PluginLicense`.
    static func recordedOwned() -> Bool {
        UserDefaults(suiteName: sharedGroup)?.bool(forKey: unlockedKey) ?? false
    }
}
