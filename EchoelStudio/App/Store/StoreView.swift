import EchoelCore
import StoreKit
import SwiftUI

/// Echoel's own Audio Units: what each is, one price for all, buy or restore. The purchase is for
/// other apps; inside Echoel the same sounds are the built-in instruments.
///
/// The page answers in short lines instead of one long note (A88-4): what the units are, what plays
/// without the purchase, how to load one in another app, and — last and small — what a device has
/// tried and what no device has tried yet. The lines about the units are `OwnPluginGuide`'s, built
/// from the lists the rows show; the lines about the sale are this page's own (`Sale`), because the
/// open packages do not know that anything is sold.
struct StoreView: View {
    @Environment(StoreController.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// What the page says about the units in other apps.
    private let guide = OwnPluginGuide(units: OwnPlugin.instruments, free: OwnPlugin.free)

    var body: some View {
        let sale = Sale(isOnSale: PluginUnlock.isOnSale, isOwned: store.isOwned, isLoading: store.isLoading,
                        price: store.product?.displayPrice)
        NavigationStack {
            List {
                EchoelSection {
                    ParagraphText(guide.what)
                }
                EchoelSection("Instruments", footer: sale.withoutPurchase) {
                    ForEach(OwnPlugin.instruments) { plugin in row(plugin) }
                    if sale.isOn {
                        purchase(sale)
                        // What the App Store says of the product, once it has answered.
                        if store.product?.isFamilyShareable == true {
                            NoteText("With Family Sharing, your family group can use it too.")
                        }
                    }
                }
                EchoelSection("Free") {
                    ForEach(OwnPlugin.free) { plugin in row(plugin) }
                }
                EchoelSection("In Another App") {
                    ParagraphText(guide.howToLoad)
                    NoteText(guide.tried)
                    NoteText(guide.untested)
                }
                // Nothing is sold yet, so there is nothing to restore either. On sale it shows whether
                // or not a price has loaded: a buyer on a second device restores without one.
                if sale.isOn {
                    EchoelSection {
                        Button("Restore Purchases") { Task { await store.restore() } }
                            .buttonStyle(EchoelRowButtonStyle())
                            .disabled(store.isBusy)
                    }
                }
                if let message = store.message {
                    EchoelSection { NoteText(message) }
                }
            }
            .echoelList()
            .navigationTitle("Echoelmusic Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) } }
            .task { await store.load() }
        }
        .preferredColorScheme(.dark)
    }

    /// Where the sale stands, as this page shows it. Off sale nothing is locked, whatever else the
    /// store reports; a purchase outranks a price; a price already read stays while the store asks
    /// again; a price sent empty is nothing to tap. This page says "Not on sale yet" only while the
    /// purchase is off sale — the day the product exists, a price beside it would contradict it
    /// (store review 2026-10-24); a product the App Store does not know is the store's message to
    /// give (`StoreController.message`).
    private enum Sale: Equatable {
        /// Off sale (`PluginUnlock.isOnSale`): nothing locks the instruments, nothing is offered.
        case notOnSale
        /// On sale; the App Store has not answered yet.
        case loading
        /// On sale, but the App Store gave no product: it knows none, or could not be reached
        /// (`StoreController.message` says which).
        case unavailable
        /// On sale at this price, as the App Store writes it; not bought on this account.
        case price(String)
        /// Bought on this account.
        case owned

        init(isOnSale: Bool, isOwned: Bool, isLoading: Bool, price: String?) {
            if !isOnSale {
                self = .notOnSale
            } else if isOwned {
                self = .owned
            } else if let price, !price.isEmpty {
                self = .price(price)
            } else if isLoading {
                self = .loading
            } else {
                self = .unavailable
            }
        }

        /// Whether the purchase is on sale: its row and Restore Purchases show, owned or not.
        var isOn: Bool { self != .notOnSale }

        /// What plays in other apps without the purchase, or, once bought, what to do there. The demo
        /// is the one `DemoGate` plays in the extension. Bought, this page promises no more than the
        /// store's own message after a purchase (`StoreController.buy`): a unit a host loaded before
        /// may keep its demo until it is reloaded, and whether the extension reads the purchase inside
        /// a host is still a device question (`PluginUnlock.sharedGroup`).
        var withoutPurchase: String {
            switch self {
            case .notOnSale:
                "Not on sale yet. Until then they play in full in other apps."
            case .loading, .unavailable, .price:
                "Without the purchase they play in other apps as a demo: two seconds of silence every thirty."
            case .owned:
                "Unlocked on this device. If they still play as a demo in another app, reload them there."
            }
        }
    }

    private func row(_ plugin: OwnPlugin) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(plugin.component.name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Text(plugin.summary)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
    }

    /// One purchase unlocks all of them: the price to tap, "Owned", or the wait for the App Store.
    private func purchase(_ sale: Sale) -> some View {
        HStack {
            Text("All \(OwnPlugin.instruments.count) instruments in other apps")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Spacer()
            switch sale {
            case .owned:
                Text("Owned")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.play)
            case .price(let price):
                if store.isBusy {
                    ProgressView()
                } else {
                    Button(price) { Task { await store.buy() } }
                        .buttonStyle(ToolButtonStyle(isActive: true))
                        .accessibilityLabel("Buy \(PluginUnlock.name) for \(price)")
                }
            case .loading:
                ProgressView()
            case .unavailable, .notOnSale:
                if store.isBusy { ProgressView() }
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
