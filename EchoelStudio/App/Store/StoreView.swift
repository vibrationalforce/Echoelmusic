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
                    purchase
                }
                EchoelSection("Free") {
                    ForEach(OwnPlugin.free) { plugin in row(plugin) }
                }
                EchoelSection {
                    Button("Restore Purchases") { Task { await store.restore() } }
                        .buttonStyle(EchoelRowButtonStyle())
                        .disabled(store.isBusy)
                }
                if let message = store.message {
                    EchoelSection { NoteText(message) }
                }
            }
            .echoelList()
            .navigationTitle("Echoel Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await store.load() }
        }
        .preferredColorScheme(.dark)
    }

    /// "Not on sale yet" is true only while the App Store knows no product; the day the product
    /// exists, the price button beside this text would have contradicted it (store review 2026-10-24).
    private var footer: String {
        let sale = store.product == nil
            ? " They are not yet tested in a host app on a device, and they are not on sale yet."
            : " They are not yet tested in a host app on a device."
        return "They are AUv3 instruments for apps that host Audio Units." + sale
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
