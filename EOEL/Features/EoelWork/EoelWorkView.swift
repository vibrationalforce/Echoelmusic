//
//  EoelWorkView.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import SwiftUI

struct EoelWorkView: View {
    @EnvironmentObject var eoelWorkManager: EoelWorkManager
    @State private var selectedIndustry: EoelWorkManager.Industry?
    @State private var showingSignUp = false

    var body: some View {
        NavigationView {
            if eoelWorkManager.currentUser == nil {
                // Welcome / Sign Up
                WelcomeView(showingSignUp: $showingSignUp)
            } else {
                // Main EoelWork Dashboard
                DashboardView()
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var showingSignUp: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image(systemName: "briefcase.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            // Title
            Text("EoelWork")
                .font(.system(size: 48, weight: .bold))

            // Subtitle
            Text("Multi-Industry Gig Platform")
                .font(.title3)
                .foregroundColor(.secondary)

            // Description
            Text("Connect with opportunities across 8+ industries. Zero commission. Fair pricing. AI-powered matching.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)

            Spacer()

            // Industries
            IndustryGrid()

            Spacer()

            // CTA
            Button(action: { showingSignUp = true }) {
                Text("Get Started - $6.99/month")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Button("Sign In") {
                // Sign in
            }
            .padding()
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
    }
}

// MARK: - Industry Grid

struct IndustryGrid: View {
    let industries = EoelWorkManager.Industry.allCases

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(industries, id: \.self) { industry in
                VStack {
                    Image(systemName: industry.icon)
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text(industry.rawValue.components(separatedBy: " ").first ?? "")
                        .font(.caption2)
                }
                .frame(width: 70, height: 70)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var eoelWorkManager: EoelWorkManager

    var body: some View {
        List {
            // Available Gigs
            Section("Available Gigs") {
                if eoelWorkManager.availableGigs.isEmpty {
                    ContentUnavailableView(
                        "No Gigs Available",
                        systemImage: "briefcase",
                        description: Text("Check back soon for new opportunities")
                    )
                } else {
                    ForEach(eoelWorkManager.availableGigs) { gig in
                        GigRow(gig: gig)
                    }
                }
            }

            // Active Contracts
            Section("Active Contracts") {
                ForEach(eoelWorkManager.activeContracts) { contract in
                    ContractRow(contract: contract)
                }
            }
        }
        .navigationTitle("EoelWork")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: searchGigs) {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
        }
    }

    private func searchGigs() {
        Task {
            try? await eoelWorkManager.searchGigs()
        }
    }
}

// MARK: - Gig Row

struct GigRow: View {
    let gig: Gig

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(gig.title)
                    .font(.headline)
                Spacer()
                UrgencyBadge(urgency: gig.urgency)
            }

            Text(gig.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label(gig.industry.rawValue, systemImage: gig.industry.icon)
                    .font(.caption)
                Spacer()
                Text("$\(Int(gig.budget))")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UrgencyBadge: View {
    let urgency: Gig.Urgency

    var body: some View {
        Text(urgency.label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(urgency.color)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

extension Gig.Urgency {
    var label: String {
        switch self {
        case .emergency: return "EMERGENCY"
        case .urgent: return "URGENT"
        case .normal: return "NORMAL"
        case .flexible: return "FLEXIBLE"
        }
    }

    var color: Color {
        switch self {
        case .emergency: return .red
        case .urgent: return .orange
        case .normal: return .blue
        case .flexible: return .green
        }
    }
}

// MARK: - Contract Row

struct ContractRow: View {
    let contract: Contract

    var body: some View {
        VStack(alignment: .leading) {
            Text(contract.gig.title)
                .font(.headline)
            Text("Status: \(contract.status.rawValue.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Profile") {
                    TextField("Name", text: .constant(""))
                    TextEditor(text: .constant(""))
                        .frame(height: 100)
                }
            }
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Account") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EoelWorkView()
        .environmentObject(EoelWorkManager.shared)
}
