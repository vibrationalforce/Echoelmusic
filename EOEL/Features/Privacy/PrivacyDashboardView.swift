//
//  PrivacyDashboardView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Privacy Dashboard for GDPR/CCPA compliance
//

import SwiftUI

struct PrivacyDashboardView: View {
    @StateObject private var privacyManager = PrivacyComplianceManager.shared
    @State private var showingExportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationView {
            List {
                privacyOverviewSection
                consentManagementSection
                dataRightsSection
                dataCollectionSection
                securitySection
            }
            .navigationTitle("Privacy")
            .alert("Export Complete", isPresented: $showingExportConfirmation) {
                Button("Share") {
                    shareExport()
                }
                Button("OK", role: .cancel) { }
            } message: {
                if let url = exportURL {
                    Text("Your data has been exported to:\n\(url.lastPathComponent)")
                }
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await deleteAllData()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete ALL your data, including recordings, settings, and account. This action cannot be undone.")
            }
        }
    }

    // MARK: - Privacy Overview

    private var privacyOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Privacy Protected")
                        .font(.headline)
                }

                Text("EOEL is designed with privacy-first principles. You have full control over your data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
        } header: {
            Text("Overview")
        }
    }

    // MARK: - Consent Management

    private var consentManagementSection: some View {
        Section {
            ConsentToggle(
                title: "Analytics",
                description: "Help improve EOEL by sharing anonymous usage data",
                status: $privacyManager.analyticsConsent,
                type: .analytics
            )

            ConsentToggle(
                title: "Crash Reporting",
                description: "Send crash reports to help fix bugs",
                status: $privacyManager.crashReportingConsent,
                type: .crashReporting
            )

            ConsentToggle(
                title: "Personalized Content",
                description: "Get personalized gig recommendations",
                status: $privacyManager.personalizedContentConsent,
                type: .personalizedContent
            )
        } header: {
            Text("Consent Management")
        } footer: {
            Text("You can withdraw consent at any time without affecting app functionality.")
                .font(.caption)
        }
    }

    // MARK: - Data Rights (GDPR/CCPA)

    private var dataRightsSection: some View {
        Section {
            Button {
                Task {
                    await exportData()
                }
            } label: {
                Label("Export My Data", systemImage: "arrow.down.doc")
            }

            Button {
                // Navigate to profile edit
            } label: {
                Label("Update My Information", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete All My Data", systemImage: "trash")
                    .foregroundColor(.red)
            }

            Button {
                Task {
                    await restrictProcessing()
                }
            } label: {
                Label("Restrict Data Processing", systemImage: "hand.raised")
            }

        } header: {
            Text("Your Data Rights")
        } footer: {
            Text("Under GDPR and CCPA, you have rights to access, correct, delete, and control your personal data.")
                .font(.caption)
        }
    }

    // MARK: - Data Collection Info

    private var dataCollectionSection: some View {
        Section {
            NavigationLink {
                DataCollectionDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What Data We Collect")
                        .font(.headline)
                    Text("See exactly what information EOEL collects and why")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            NavigationLink {
                ThirdPartyServicesView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Third-Party Services")
                        .font(.headline)
                    Text("Firebase, TelemetryDeck, Stripe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Transparency")
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                Text("AES-256 Encryption")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                Text("TLS 1.3 Secure Connection")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.green)
                Text("SSL Certificate Pinning")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.green)
                Text("Keychain Secure Storage")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        } header: {
            Text("Security Features")
        }
    }

    // MARK: - Actions

    private func exportData() async {
        do {
            let result = try await privacyManager.exerciseRight(.access)

            if case .success(_, let url) = result {
                exportURL = url
                showingExportConfirmation = true
            }
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func deleteAllData() async {
        do {
            _ = try await privacyManager.exerciseRight(.erasure)
            // Would typically log out and return to welcome screen
        } catch {
            print("Deletion failed: \(error)")
        }
    }

    private func restrictProcessing() async {
        do {
            _ = try await privacyManager.exerciseRight(.restriction)
        } catch {
            print("Restriction failed: \(error)")
        }
    }

    private func shareExport() {
        guard let url = exportURL else { return }
        // Would show share sheet
    }
}

// MARK: - Consent Toggle

struct ConsentToggle: View {
    let title: String
    let description: String
    @Binding var status: PrivacyComplianceManager.ConsentStatus
    let type: PrivacyComplianceManager.ConsentType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { status == .granted },
                    set: { newValue in
                        if newValue {
                            PrivacyComplianceManager.shared.grantConsent(for: type)
                        } else {
                            PrivacyComplianceManager.shared.denyConsent(for: type)
                        }
                    }
                ))
            }

            if status == .granted {
                Text("✓ Consent granted")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else if status == .denied {
                Text("Consent denied")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if status == .withdrawn {
                Text("Consent withdrawn")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("Privacy Policy")
                .font(.largeTitle)
                .padding()

            // Load from PRIVACY_POLICY.md
            Text("Full privacy policy would be loaded here from PRIVACY_POLICY.md")
                .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataCollectionDetailView: View {
    var body: some View {
        List {
            dataTypeSection(.healthData)
            dataTypeSection(.audioData)
            dataTypeSection(.usageData)
            dataTypeSection(.deviceInfo)
            dataTypeSection(.locationData)
        }
        .navigationTitle("Data Collection")
    }

    private func dataTypeSection(_ type: PrivacyComplianceManager.DataCollectionInfo.DataType) -> some View {
        let manager = PrivacyComplianceManager.shared
        let info = getInfo(for: type)

        return Section {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Purpose", value: info.purpose)
                LabeledContent("Retention", value: formatRetention(info.retention))
                LabeledContent("Required", value: info.required ? "Yes" : "No")
                LabeledContent("Consent Required", value: info.consentRequired ? "Yes" : "No")

                if !info.thirdParties.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Third Parties:")
                            .font(.caption)
                        ForEach(info.thirdParties, id: \.self) { party in
                            Text("• \(party)")
                                .font(.caption)
                        }
                    }
                }
            }
        } header: {
            Text(type.rawValue.capitalized)
        }
    }

    private func getInfo(for type: PrivacyComplianceManager.DataCollectionInfo.DataType) -> PrivacyComplianceManager.DataCollectionInfo {
        // This would call the actual method from PrivacyComplianceManager
        return PrivacyComplianceManager.DataCollectionInfo(
            dataType: type,
            purpose: "Purpose here",
            retention: 90 * 24 * 3600,
            thirdParties: [],
            required: false,
            consentRequired: true
        )
    }

    private func formatRetention(_ seconds: TimeInterval) -> String {
        if seconds == .infinity {
            return "Until account deletion"
        } else if seconds == 0 {
            return "Not stored (real-time only)"
        } else {
            let days = Int(seconds / (24 * 3600))
            return "\(days) days"
        }
    }
}

struct ThirdPartyServicesView: View {
    var body: some View {
        List {
            thirdPartySection(
                name: "Firebase",
                purpose: "Backend infrastructure",
                data: "Email, user ID, device info",
                policyURL: "https://firebase.google.com/support/privacy"
            )

            thirdPartySection(
                name: "TelemetryDeck",
                purpose: "Privacy-friendly analytics",
                data: "App usage (anonymized)",
                policyURL: "https://telemetrydeck.com/privacy"
            )

            thirdPartySection(
                name: "Stripe",
                purpose: "Payment processing",
                data: "Payment information",
                policyURL: "https://stripe.com/privacy"
            )
        }
        .navigationTitle("Third-Party Services")
    }

    private func thirdPartySection(name: String, purpose: String, data: String, policyURL: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Purpose: \(purpose)")
                    .font(.caption)
                Text("Data Shared: \(data)")
                    .font(.caption)

                Link("Privacy Policy", destination: URL(string: policyURL)!)
                    .font(.caption)
            }
        } header: {
            Text(name)
        }
    }
}
