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
                Section {
                    ForEach(OwnPlugin.instruments) { plugin in row(plugin) }
                    purchase
                } footer: {
                    Text("They are AUv3 instruments for apps that host Audio Units. So far they are tested in AUM; other hosts are not tested yet. Before you buy, the instruments play as a demo: two seconds of silence every thirty. One purchase, no subscription.")
                }
                Section("Free") {
                    ForEach(OwnPlugin.free) { plugin in row(plugin) }
                }
                Section {
                    Button("Restore Purchases") { Task { await store.restore() } }
                }
                if let message = store.message {
                    Section { Text(message).foregroundStyle(Theme.Color.textSecondary) }
                }
            }
            .navigationTitle("Echoel Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await store.load() }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ plugin: OwnPlugin) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(plugin.component.name).font(Theme.Font.body)
            Text(plugin.summary)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Space.xs)
    }

    /// One purchase unlocks all of them.
    private var purchase: some View {
        HStack {
            Text("All \(OwnPlugin.instruments.count) instruments in other apps").font(Theme.Font.body)
            Spacer()
            if store.isOwned {
                Text("Owned")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.play)
            } else if let product = store.product {
                Button(product.displayPrice) { Task { await store.buy() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Buy \(PluginUnlock.name) for \(product.displayPrice)")
            } else if store.isLoading {
                ProgressView()
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
