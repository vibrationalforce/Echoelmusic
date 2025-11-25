//
//  PaywallView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Subscription Paywall UI
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showingRestoreConfirmation = false
    @State private var isPurchasing = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        featuresSection
                        productsSection
                        legalSection
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore") {
                        Task {
                            await restorePurchases()
                        }
                    }
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .alert("Restore Complete", isPresented: $showingRestoreConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchases have been restored.")
            }
            .overlay {
                if subscriptionManager.isLoading || isPurchasing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
        .task {
            await subscriptionManager.loadProducts()
            subscriptionManager.trackSubscriptionEvent(.paywall_viewed)

            // Pre-select Pro Monthly as default
            if let proMonthly = subscriptionManager.product(for: .proMonthly) {
                selectedProduct = proMonthly
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock EOEL Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Professional music production at your fingertips")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                icon: "music.note.list",
                title: "47 Instruments",
                description: "From piano to synthesizers"
            )

            FeatureRow(
                icon: "waveform",
                title: "77 Effects",
                description: "Professional audio effects"
            )

            FeatureRow(
                icon: "infinity",
                title: "Unlimited Recordings",
                description: "No limits on your creativity"
            )

            FeatureRow(
                icon: "icloud",
                title: "Cloud Sync",
                description: "Access projects anywhere"
            )

            FeatureRow(
                icon: "headphones",
                title: "Priority Support",
                description: "Get help when you need it"
            )
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)

            if subscriptionManager.availableProducts.isEmpty {
                Text("Loading...")
                    .foregroundColor(.secondary)
            } else {
                // Pro plans
                VStack(spacing: 12) {
                    Text("Pro")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let proMonthly = subscriptionManager.product(for: .proMonthly),
                       let proYearly = subscriptionManager.product(for: .proYearly) {

                        ProductCard(
                            product: proMonthly,
                            isSelected: selectedProduct?.id == proMonthly.id,
                            onSelect: { selectedProduct = proMonthly }
                        )

                        ProductCard(
                            product: proYearly,
                            isSelected: selectedProduct?.id == proYearly.id,
                            savingsPercentage: subscriptionManager.savingsPercentage(
                                monthly: proMonthly,
                                yearly: proYearly
                            ),
                            onSelect: { selectedProduct = proYearly }
                        )
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                // Premium plans
                VStack(spacing: 12) {
                    HStack {
                        Text("Premium")
                            .font(.title2)
                            .fontWeight(.bold)

                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }

                    Text("Includes EoelWork gig platform + advanced features")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let premiumMonthly = subscriptionManager.product(for: .premiumMonthly),
                       let premiumYearly = subscriptionManager.product(for: .premiumYearly) {

                        ProductCard(
                            product: premiumMonthly,
                            isSelected: selectedProduct?.id == premiumMonthly.id,
                            isPremium: true,
                            onSelect: { selectedProduct = premiumMonthly }
                        )

                        ProductCard(
                            product: premiumYearly,
                            isSelected: selectedProduct?.id == premiumYearly.id,
                            isPremium: true,
                            savingsPercentage: subscriptionManager.savingsPercentage(
                                monthly: premiumMonthly,
                                yearly: premiumYearly
                            ),
                            onSelect: { selectedProduct = premiumYearly }
                        )
                    }
                }
            }

            // Purchase button
            if let product = selectedProduct {
                Button {
                    Task {
                        await purchaseProduct(product)
                    }
                } label: {
                    Text("Subscribe Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isPurchasing || subscriptionManager.isLoading)
            }

            // Error message
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("• Auto-renewable subscription")
            Text("• Cancel anytime in Settings")
            Text("• Payment charged to App Store account")

            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://eoel.app/terms")!)
                    .font(.caption)

                Text("•")
                    .font(.caption)

                Link("Privacy Policy", destination: URL(string: "https://eoel.app/privacy")!)
                    .font(.caption)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        subscriptionManager.trackSubscriptionEvent(.purchase_initiated)

        do {
            let transaction = try await subscriptionManager.purchase(product)

            if transaction != nil {
                // Purchase successful
                subscriptionManager.trackSubscriptionEvent(.purchase_completed)
                dismiss()
            } else {
                // User cancelled
                subscriptionManager.trackSubscriptionEvent(.purchase_cancelled)
            }
        } catch {
            subscriptionManager.trackSubscriptionEvent(.purchase_failed)
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        await subscriptionManager.restorePurchases()
        subscriptionManager.trackSubscriptionEvent(.subscription_restored)
        showingRestoreConfirmation = true
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    var isPremium: Bool = false
    var savingsPercentage: Int?
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)

                        if let savings = savingsPercentage {
                            Text("Save \(savings)%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }

                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isPremium ? .yellow : .blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? (isPremium ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.2)) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? (isPremium ? Color.yellow : Color.blue) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Period Extension

extension Product.SubscriptionPeriod {
    var description: String {
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) years"
        @unknown default:
            return "Subscription"
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
