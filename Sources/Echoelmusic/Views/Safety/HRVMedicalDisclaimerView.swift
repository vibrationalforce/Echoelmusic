//
//  HRVMedicalDisclaimerView.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Medical disclaimer view required before using HRV/biofeedback features
//

import SwiftUI

/// Medical disclaimer view that must be acknowledged before using HRV features
struct HRVMedicalDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var understoodRisks = false
    @State private var noContraindications = false
    @State private var isOver18 = false
    @State private var notForMedical = false

    var allAcknowledged: Bool {
        understoodRisks && noContraindications && isOver18 && notForMedical
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // Warning Box
                    warningBox

                    // Contraindications
                    contraindicationsSection

                    // Data Usage
                    dataUsageSection

                    // Acknowledgment Checkboxes
                    acknowledgmentSection

                    // Continue Button
                    continueButton
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Medical Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("HRV Biofeedback")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Please read this important information before using heart rate variability (HRV) features.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var warningBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("IMPORTANT NOTICE")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            Text("""
            This app is NOT a medical device and is NOT intended to diagnose, treat, cure, or prevent any disease or medical condition.

            HRV data provided by this app is for INFORMATIONAL and WELLNESS purposes only. Do not use this data to make medical decisions.

            Always consult a qualified healthcare professional for medical advice.
            """)
            .font(.callout)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var contraindicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DO NOT USE IF YOU HAVE:")
                .font(.headline)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 8) {
                contraindicationRow("Epilepsy, seizure disorders, or convulsions")
                contraindicationRow("Heart conditions, pacemakers, or arrhythmia")
                contraindicationRow("Pregnancy or are breastfeeding")
                contraindicationRow("Mental health conditions (without medical supervision)")
                contraindicationRow("History of adverse reactions to biofeedback")
                contraindicationRow("Taking cardiac medications")
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }

    private func contraindicationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }

    private var dataUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATA PRIVACY")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                dataRow("heart.fill", "HRV data is processed locally on your device")
                dataRow("icloud.slash", "Raw biometric data is NEVER uploaded to the cloud")
                dataRow("lock.fill", "Your health data remains private and secure")
                dataRow("trash.fill", "You can delete all data at any time in Settings")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }

    private func dataRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }

    private var acknowledgmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACKNOWLEDGMENT")
                .font(.headline)

            Toggle(isOn: $understoodRisks) {
                Text("I understand HRV data is for wellness purposes only")
                    .font(.callout)
            }
            .toggleStyle(CheckboxToggleStyle())

            Toggle(isOn: $noContraindications) {
                Text("I do not have any of the listed contraindications")
                    .font(.callout)
            }
            .toggleStyle(CheckboxToggleStyle())

            Toggle(isOn: $isOver18) {
                Text("I am 18 years or older (or have parental consent)")
                    .font(.callout)
            }
            .toggleStyle(CheckboxToggleStyle())

            Toggle(isOn: $notForMedical) {
                Text("I will NOT use this data for medical decisions")
                    .font(.callout)
            }
            .toggleStyle(CheckboxToggleStyle())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var continueButton: some View {
        Button(action: {
            healthKitManager.acknowledgeDisclaimer()
            dismiss()
        }) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                Text("I Understand and Accept")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(allAcknowledged ? Color.green : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!allAcknowledged)
        .padding(.top, 8)
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .green : .secondary)
                    .font(.title3)
                configuration.label
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    HRVMedicalDisclaimerView(healthKitManager: HealthKitManager.shared)
}
