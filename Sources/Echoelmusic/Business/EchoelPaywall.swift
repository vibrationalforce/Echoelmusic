// EchoelPaywall.swift
// Echoelmusic — Paywall / Subscription View
//
// Clean, Apple-style paywall with no dark patterns.
// Shows value first, then pricing. Easy to dismiss.
//
// Created 2026-02-17
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI
import StoreKit

// MARK: - Paywall View

/// Main paywall for Echoelmusic Pro
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public struct EchoelPaywall: View {
    @ObservedObject private var store: EchoelStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showError = false

    public init(store: EchoelStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Features
                featuresSection

                // Pricing
                pricingSection

                // Session packs (if not Pro)
                if !store.isPro {
                    sessionSection
                }

                // Restore
                restoreButton

                // Legal
                legalSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.black)
        .alert("Error", isPresented: $showError) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "An error occurred")
        }
        .onChange(of: store.errorMessage) { newValue in
            showError = newValue != nil
        }
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Echoelmusic")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .tracking(3)
                .textCase(.uppercase)

            Text("Pro")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Unlock the full bio-reactive experience")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(icon: "waveform.circle.fill", title: "Unlimited Sessions", subtitle: "No time limits on bio-reactive sessions")
            featureRow(icon: "pianokeys", title: "All 7 Synth Engines", subtitle: "DDSP, Modal Bank, Cellular, Quantum, Sampler, EchoelBeat, Breakbeat")
            featureRow(icon: "slider.horizontal.3", title: "All Presets", subtitle: "Full preset library + Hilbert Visualization")
            featureRow(icon: "icloud.fill", title: "CloudKit Sync", subtitle: "Sessions sync across all your devices")
            featureRow(icon: "applewatch", title: "Watch Integration", subtitle: "Real-time bio data from Apple Watch")
            featureRow(icon: "square.and.arrow.up", title: "Export", subtitle: "WAV, MIDI, and session data export")
            featureRow(icon: "light.max", title: "DMX Lighting", subtitle: "Professional lighting control via Art-Net")
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(store.subscriptions, id: \.id) { product in
                SubscriptionButton(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isYearly: product.id == EchoelProduct.proYearly.rawValue
                ) {
                    selectedProduct = product
                }
            }

            if let lifetimeProduct = store.lifetime {
                SubscriptionButton(
                    product: lifetimeProduct,
                    isSelected: selectedProduct?.id == lifetimeProduct.id,
                    isYearly: false,
                    isLifetime: true
                ) {
                    selectedProduct = lifetimeProduct
                }
            }

            // Purchase button
            if let product = selectedProduct {
                Button {
                    Task {
                        let success = await store.purchase(product)
                        if success { dismiss() }
                    }
                } label: {
                    Group {
                        if store.isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Subscribe")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .disabled(store.isPurchasing)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Session Packs

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or buy individual sessions")
                .font(.subheadline)
                .foregroundColor(.gray)

            ForEach(store.sessions, id: \.id) { product in
                Button {
                    Task { _ = await store.purchase(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text(product.description)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await store.restorePurchases() }
        }
        .font(.footnote)
        .foregroundColor(.gray)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Subscriptions auto-renew unless cancelled 24h before the end of the current period. Manage in Settings > Apple ID > Subscriptions.")
                .font(.caption2)
                .foregroundColor(Color.gray.opacity(0.6))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms", destination: URL(string: "https://echoelmusic.com/terms") ?? URL(fileURLWithPath: "/"))
                Link("Privacy", destination: URL(string: "https://echoelmusic.com/privacy") ?? URL(fileURLWithPath: "/"))
            }
            .font(.caption2)
            .foregroundColor(.gray)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Subscription Button

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
private struct SubscriptionButton: View {
    let product: Product
    let isSelected: Bool
    let isYearly: Bool
    var isLifetime: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.white)

                        if isYearly {
                            Text("SAVE 33%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                        }

                        if isLifetime {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
            )
        }
    }
}
