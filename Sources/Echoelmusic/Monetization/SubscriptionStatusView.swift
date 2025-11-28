//
//  SubscriptionStatusView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Subscription status and management UI
//

import SwiftUI

struct SubscriptionStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        List {
            currentStatusSection
            featuresSection
            managementSection
        }
        .navigationTitle("Subscription")
        .task {
            await subscriptionManager.updateSubscriptionStatus()
        }
    }

    // MARK: - Current Status

    private var currentStatusSection: some View {
        Section {
            VStack(spacing: 16) {
                // Tier badge
                HStack {
                    Image(systemName: tierIcon)
                        .font(.largeTitle)
                        .foregroundColor(tierColor)

                    VStack(alignment: .leading) {
                        Text(subscriptionManager.subscriptionStatus.tier.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        if subscriptionManager.subscriptionStatus.isActive {
                            Text("Active Subscription")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Free Tier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }

                // Expiry date
                if let expiryDate = subscriptionManager.subscriptionStatus.expiryDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Renewal Date")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(expiryDate, style: .date)
                            .font(.headline)

                        if daysUntilExpiry(expiryDate) <= 7 {
                            Text("Renews in \(daysUntilExpiry(expiryDate)) days")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Current Plan")
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        Section {
            FeatureAccessRow(
                icon: "music.note.list",
                title: "Instruments",
                status: instrumentsStatus
            )

            FeatureAccessRow(
                icon: "waveform",
                title: "Effects",
                status: effectsStatus
            )

            FeatureAccessRow(
                icon: "record.circle",
                title: "Recordings",
                status: recordingsStatus
            )

            FeatureAccessRow(
                icon: "icloud",
                title: "Cloud Sync",
                status: subscriptionManager.hasAccess(to: .cloudSync) ? "Enabled" : "Upgrade to Pro"
            )

            FeatureAccessRow(
                icon: "briefcase",
                title: "EoelWork Platform",
                status: subscriptionManager.hasAccess(to: .eoelWork) ? "Enabled" : "Upgrade to Premium"
            )

            FeatureAccessRow(
                icon: "chart.bar",
                title: "Advanced Analytics",
                status: subscriptionManager.hasAccess(to: .advancedAnalytics) ? "Enabled" : "Upgrade to Premium"
            )
        } header: {
            Text("Features & Access")
        }
    }

    // MARK: - Management

    private var managementSection: some View {
        Section {
            if subscriptionManager.subscriptionStatus.isActive {
                Button {
                    Task {
                        await subscriptionManager.manageSubscriptions()
                        subscriptionManager.trackSubscriptionEvent(.manage_subscription_tapped)
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "gear")
                }

                Button {
                    openCancelInstructions()
                } label: {
                    Label("How to Cancel", systemImage: "info.circle")
                }
            } else {
                NavigationLink {
                    PaywallView()
                } label: {
                    Label("Upgrade to Pro", systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                }

                Button {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Subscription Management")
        } footer: {
            if subscriptionManager.subscriptionStatus.isActive {
                Text("Your subscription will automatically renew unless cancelled at least 24 hours before the end of the current period.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Computed Properties

    private var tierIcon: String {
        switch subscriptionManager.subscriptionStatus.tier {
        case .free:
            return "person.circle"
        case .pro:
            return "star.circle.fill"
        case .premium:
            return "crown.fill"
        }
    }

    private var tierColor: Color {
        switch subscriptionManager.subscriptionStatus.tier {
        case .free:
            return .gray
        case .pro:
            return .blue
        case .premium:
            return .yellow
        }
    }

    private var instrumentsStatus: String {
        if subscriptionManager.hasAccess(to: .allInstruments) {
            return "All 47 instruments"
        } else {
            return "3 instruments (Free)"
        }
    }

    private var effectsStatus: String {
        if subscriptionManager.hasAccess(to: .allEffects) {
            return "All 77 effects"
        } else {
            return "10 effects (Free)"
        }
    }

    private var recordingsStatus: String {
        if subscriptionManager.hasAccess(to: .unlimitedRecordings) {
            return "Unlimited"
        } else {
            return "Max 5 recordings (Free)"
        }
    }

    // MARK: - Helpers

    private func daysUntilExpiry(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day ?? 0
    }

    private func openCancelInstructions() {
        // Open Settings > Apple ID > Subscriptions
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Feature Access Row

struct FeatureAccessRow: View {
    let icon: String
    let title: String
    let status: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(title)
                .font(.body)

            Spacer()

            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SubscriptionStatusView()
    }
}
