import EchoelCore
import StoreKit
import SwiftUI

/// Echoel's own Audio Units: what each is, one price for all, buy or restore. The purchase is for
/// other apps; inside Echoel the same sounds are the built-in instruments.
struct StoreView: View {
    @Environment(StoreController.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                EchoelSection("Instruments", footer: footer) {
                    ForEach(OwnPlugin.instruments) { plugin in row(plugin) }
                    if PluginUnlock.isOnSale { purchase }
                }
                EchoelSection("Free") {
                    ForEach(OwnPlugin.free) { plugin in row(plugin) }
                }
                // Nothing is sold yet, so there is nothing to restore either.
                if PluginUnlock.isOnSale {
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await store.load() }
        }
        .preferredColorScheme(.dark)
    }

    /// "Not on sale yet" is true only while the App Store knows no product; the day the product
    /// exists, the price button beside this text would have contradicted it (store review 2026-10-24).
    private var footer: String {
        let units = "They are AUv3 instruments for apps that host Audio Units."
        // What a device has shown, and nothing wider: one instrument in one host.
        let tried = " The synthesizer has been tried in AUM on an iPhone; the drums, the sampler and other host apps are not yet tested."
        // Nothing to buy: nothing is locked (`PluginUnlock.isOnSale`).
        guard PluginUnlock.isOnSale else {
            return units + tried + " They are not on sale yet. Until they are, they play in full in other apps."
        }
        let sale = store.product == nil ? " They are not on sale yet." : ""
        return units + tried + sale
            + " Until they are unlocked, they play as a demo: two seconds of silence every thirty."
            + " One purchase, no subscription."
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

    /// One purchase unlocks all of them.
    private var purchase: some View {
        HStack {
            Text("All \(OwnPlugin.instruments.count) instruments in other apps")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Spacer()
            if store.isOwned {
                Text("Owned")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.play)
            } else if store.isBusy {
                ProgressView()
            } else if let product = store.product {
                Button(product.displayPrice) { Task { await store.buy() } }
                    .buttonStyle(ToolButtonStyle(isActive: true))
                    .accessibilityLabel("Buy \(PluginUnlock.name) for \(product.displayPrice)")
            } else if store.isLoading {
                ProgressView()
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
