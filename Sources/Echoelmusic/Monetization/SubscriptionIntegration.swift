//
//  SubscriptionIntegration.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Helper utilities for integrating subscription checks
//

import SwiftUI

// MARK: - View Extension for Subscription Gates

extension View {
    /// Check if user has access before performing an action
    func requiresSubscription(
        _ feature: SubscriptionManager.Feature,
        gatedFeature: GatedFeature,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(SubscriptionGateModifier(
            feature: feature,
            gatedFeature: gatedFeature,
            action: action
        ))
    }
}

struct SubscriptionGateModifier: ViewModifier {
    let feature: SubscriptionManager.Feature
    let gatedFeature: GatedFeature
    let action: () -> Void

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingGate = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if subscriptionManager.hasAccess(to: feature) {
                    action()
                } else {
                    showingGate = true
                }
            }
            .sheet(isPresented: $showingGate) {
                FeatureGateView(feature: gatedFeature)
            }
    }
}

// MARK: - Subscription Badge Views

struct SubscriptionBadge: View {
    let tier: SubscriptionManager.SubscriptionTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)

            Text(tier.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private var icon: String {
        switch tier {
        case .free: return "person.circle"
        case .pro: return "star.circle.fill"
        case .premium: return "crown.fill"
        }
    }

    private var backgroundColor: Color {
        switch tier {
        case .free: return .gray
        case .pro: return .blue
        case .premium: return .yellow
        }
    }
}

struct LockedFeatureBadge: View {
    let requiredTier: GatedFeature.RequiredTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)

            Text(requiredTier.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(requiredTier.color)
        .cornerRadius(8)
    }
}

// MARK: - Usage Example Views

/*
 USAGE EXAMPLES:

 1. Instrument Selection with Gate:

 ForEach(instruments.indices, id: \.self) { index in
     InstrumentRow(instrument: instruments[index])
         .opacity(subscriptionManager.canUseInstrument(index: index) ? 1.0 : 0.5)
         .overlay(alignment: .topTrailing) {
             if !subscriptionManager.canUseInstrument(index: index) {
                 LockedFeatureBadge(requiredTier: .pro)
             }
         }
         .onTapGesture {
             if subscriptionManager.canUseInstrument(index: index) {
                 selectInstrument(index)
             } else {
                 showFeatureGate(.allInstruments)
             }
         }
 }

 2. Recording Limit Check:

 Button("New Recording") {
     if subscriptionManager.canCreateRecording(currentCount: recordings.count) {
         createNewRecording()
     } else {
         showFeatureGate(.unlimitedRecordings)
     }
 }

 3. EoelWork Access:

 NavigationLink {
     if subscriptionManager.hasAccess(to: .eoelWork) {
         EoelWorkView()
     } else {
         FeatureGateView(feature: .eoelWork)
     }
 } label: {
     Label("Find Gigs", systemImage: "briefcase")
 }

 4. Current Subscription Badge:

 SubscriptionBadge(tier: subscriptionManager.subscriptionStatus.tier)

 5. Cloud Sync Button:

 Button {
     if subscriptionManager.hasAccess(to: .cloudSync) {
         performCloudSync()
     } else {
         showPaywall()
     }
 } label: {
     HStack {
         Image(systemName: "icloud")
         Text("Sync to Cloud")
         if !subscriptionManager.hasAccess(to: .cloudSync) {
             LockedFeatureBadge(requiredTier: .pro)
         }
     }
 }

 6. Settings Section:

 Section {
     NavigationLink {
         SubscriptionStatusView()
     } label: {
         HStack {
             Label("Subscription", systemImage: "star.circle")
             Spacer()
             SubscriptionBadge(tier: subscriptionManager.subscriptionStatus.tier)
         }
     }
 }

 */

// MARK: - Free Trial Helper

struct FreeTrialBanner: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false

    var body: some View {
        if subscriptionManager.subscriptionStatus == .free {
            Button {
                showingPaywall = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try Pro Free for 7 Days")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Unlock all instruments and effects")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Subscription Reminder

struct SubscriptionReminderView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        if let expiryDate = subscriptionManager.subscriptionStatus.expiryDate,
           daysUntilExpiry(expiryDate) <= 7 {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Expiring Soon")
                        .font(.headline)

                    Text("Renews on \(expiryDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await subscriptionManager.manageSubscriptions()
                    }
                } label: {
                    Text("Manage")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func daysUntilExpiry(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day ?? 0
    }
}

// MARK: - Usage Counter

struct UsageLimitIndicator: View {
    let current: Int
    let limit: Int
    let feature: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(feature) Used")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: Double(current), total: Double(limit))
                .progressViewStyle(.linear)

            Text("\(current) / \(limit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Integration with Settings

struct SubscriptionSettingsRow: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationLink {
            SubscriptionStatusView()
        } label: {
            HStack {
                Label("Subscription", systemImage: "star.circle")

                Spacer()

                SubscriptionBadge(tier: subscriptionManager.subscriptionStatus.tier)

                if subscriptionManager.subscriptionStatus.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
    }
}
