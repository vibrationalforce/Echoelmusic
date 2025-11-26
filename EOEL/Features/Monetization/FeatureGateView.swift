//
//  FeatureGateView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Feature gate for premium features
//

import SwiftUI

struct FeatureGateView: View {
    let feature: GatedFeature
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: feature.icon)
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text(feature.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text(feature.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Required tier badge
            HStack {
                Image(systemName: feature.requiredTier.icon)
                    .foregroundColor(feature.requiredTier.color)

                Text("\(feature.requiredTier.displayName) Required")
                    .font(.headline)
                    .foregroundColor(feature.requiredTier.color)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(feature.requiredTier.color.opacity(0.1))
            )

            Spacer()

            // Upgrade button
            Button {
                showingPaywall = true
            } label: {
                Text("Upgrade to \(feature.requiredTier.displayName)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(feature.requiredTier.color)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            // Close button
            Button("Maybe Later") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Gated Feature

struct GatedFeature {
    let title: String
    let description: String
    let icon: String
    let requiredTier: RequiredTier

    enum RequiredTier {
        case pro
        case premium

        var displayName: String {
            switch self {
            case .pro: return "Pro"
            case .premium: return "Premium"
            }
        }

        var icon: String {
            switch self {
            case .pro: return "star.circle.fill"
            case .premium: return "crown.fill"
            }
        }

        var color: Color {
            switch self {
            case .pro: return .blue
            case .premium: return .yellow
            }
        }
    }

    // Common gated features
    static let allInstruments = GatedFeature(
        title: "All 47 Instruments",
        description: "Unlock the complete instrument library including synthesizers, drums, strings, and more.",
        icon: "music.note.list",
        requiredTier: .pro
    )

    static let allEffects = GatedFeature(
        title: "All 77 Effects",
        description: "Access professional audio effects like reverb, delay, compression, and more.",
        icon: "waveform",
        requiredTier: .pro
    )

    static let unlimitedRecordings = GatedFeature(
        title: "Unlimited Recordings",
        description: "Create as many recordings as you want without limits.",
        icon: "infinity",
        requiredTier: .pro
    )

    static let cloudSync = GatedFeature(
        title: "Cloud Sync",
        description: "Sync your projects across all your devices with iCloud.",
        icon: "icloud",
        requiredTier: .pro
    )

    static let eoelWork = GatedFeature(
        title: "EoelWork Platform",
        description: "Find and post gigs, connect with clients, and manage your freelance work.",
        icon: "briefcase",
        requiredTier: .premium
    )

    static let advancedAnalytics = GatedFeature(
        title: "Advanced Analytics",
        description: "Track your productivity, analyze your music, and get insights.",
        icon: "chart.bar",
        requiredTier: .premium
    )

    static let customBranding = GatedFeature(
        title: "Custom Branding",
        description: "Add your logo and branding to exports and projects.",
        icon: "paintbrush",
        requiredTier: .premium
    )

    static let apiAccess = GatedFeature(
        title: "API Access",
        description: "Integrate EOEL with your existing workflow using our API.",
        icon: "link",
        requiredTier: .premium
    )
}

// MARK: - Feature Gate Modifier

extension View {
    /// Gate a feature behind a subscription tier
    func featureGate(
        _ feature: GatedFeature,
        hasAccess: Bool,
        showGate: Binding<Bool>
    ) -> some View {
        self.sheet(isPresented: showGate) {
            if !hasAccess {
                FeatureGateView(feature: feature)
            }
        }
    }
}

// MARK: - Preview

#Preview("All Instruments") {
    FeatureGateView(feature: .allInstruments)
}

#Preview("EoelWork") {
    FeatureGateView(feature: .eoelWork)
}
