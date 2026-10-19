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
}
